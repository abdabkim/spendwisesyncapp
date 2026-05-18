import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../services/todo_service.dart';

// ============================================================================
// APP COLORS
// ============================================================================

class AppColors {
  // DARK MODE
  static const Color backgroundDark = Color(0xFF0f1419);
  static const Color cardDark = Color(0xFF1a1d24);
  static const Color cardSurface = Color(0xFF232930);
  static const Color borderDark = Color(0xFF2d3542);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFe2e8f0);

  // LIGHT MODE
  static const Color backgroundLight = Color(0xFFf6f7f8);
  static const Color cardLight = Color(0xFFffffff);
  static const Color cardSurfaceLight = Color(0xFFf1f5f9);
  static const Color borderLight = Color(0xFFe2e8f0);
  static const Color textGreyLight = Color(0xFF64748b);
  static const Color textLightLight = Color(0xFF0f172a);

  // SHARED
  static const Color primary = Color(0xFF00d4ff);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color iconBgOrange = Color(0xFFF97316);
  static const Color iconBgEmerald = Color(0xFF10B981);
}

// ============================================================================
// ADD TODO SCREEN
// ============================================================================

class AddTodoScreen extends StatefulWidget {
  const AddTodoScreen({Key? key}) : super(key: key);

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  final TodoService _todoService = TodoService();
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  int _inputMethod = 0; // 0: Manual, 1: From Receipt
  int _receiptDataType = 0; // 0: Text Information, 1: Cost Information
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = false;
  String _selectedPriority = 'None';
  String _selectedEnergyLevel = 'Medium energy';
  String _selectedCategory = 'Personal';
  bool _isProcessing = false;
  String _processingFileName = '';
  double _processingProgress = 0.0;
  Map<String, dynamic>? _extractedData;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemUI();
  }

  void _updateSystemUI() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? true;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCameraUpload() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        setState(() {
          _isProcessing = true;
          _processingFileName = image.name;
          _processingProgress = 0.0;
        });

        final extractedData = await _performOCR(image.path);

        setState(() {
          _isProcessing = false;
          _extractedData = extractedData;
        });

        if (mounted) {
          _populateFieldsFromExtractedData(extractedData);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error accessing camera: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleGalleryUpload() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          _isProcessing = true;
          _processingFileName = image.name;
          _processingProgress = 0.0;
        });

        final extractedData = await _performOCR(image.path);

        setState(() {
          _isProcessing = false;
          _extractedData = extractedData;
        });

        if (mounted) {
          _populateFieldsFromExtractedData(extractedData);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error accessing gallery: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handlePDFUpload() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;

        if (mounted) {
          _showErrorSnackBar('PDF OCR processing requires additional setup');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error accessing files: $e');
    }
  }

  Future<Map<String, dynamic>> _performOCR(String imagePath) async {
    try {
      setState(() {
        _processingProgress = 0.1;
      });

      final inputImage = InputImage.fromFilePath(imagePath);

      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      setState(() {
        _processingProgress = 0.3;
      });

      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        _processingProgress = 0.6;
      });

      String fullText = _extractEnhancedText(recognizedText);

      Map<String, dynamic> extractedData = _parseReceiptText(fullText);

      setState(() {
        _processingProgress = 1.0;
      });

      textRecognizer.close();

      return extractedData;
    } catch (e) {
      print('Error performing OCR: $e');
      return {
        'merchantName': '',
        'totalAmount': 0.0,
        'items': [],
        'rawText': '',
      };
    }
  }

  String _extractEnhancedText(RecognizedText recognizedText) {
    StringBuffer enhancedText = StringBuffer();
    List<String> lines = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text.trim();

        if (lineText.isNotEmpty) {
          lineText = _cleanOCRText(lineText);
          lines.add(lineText);
        }
      }
    }

    recognizedText.blocks.sort((a, b) {
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = _cleanOCRText(line.text.trim());
        if (lineText.isNotEmpty) {
          enhancedText.writeln(lineText);
        }
      }
    }

    return enhancedText.toString();
  }

  String _cleanOCRText(String text) {
    String cleaned = text;

    cleaned = cleaned.replaceAll(RegExp(r'[|]'), 'I');
    cleaned = cleaned.replaceAll(RegExp(r'[¡]'), 'i');
    cleaned = cleaned.replaceAll(RegExp(r'[º°]'), '0');
    cleaned = cleaned.replaceAll(RegExp(r'[òóôõö]'), 'o');
    cleaned = cleaned.replaceAll(RegExp(r'[ÒÓÔÕÖ]'), 'O');

    cleaned = cleaned.replaceAll(RegExp(r'[\$§]'), '\$');

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bTOTAL\b', caseSensitive: false),
      (match) => 'TOTAL',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bSUBTOTAL\b', caseSensitive: false),
      (match) => 'SUBTOTAL',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bTAX\b', caseSensitive: false),
      (match) => 'TAX',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\bAMOUNT\b', caseSensitive: false),
      (match) => 'AMOUNT',
    );

    return cleaned.trim();
  }

  Map<String, dynamic> _parseReceiptText(String text) {
    String merchantName = '';
    double totalAmount = 0.0;
    List<Map<String, dynamic>> items = [];

    final lines = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length && i < 5; i++) {
      String line = lines[i].trim();
      if (!RegExp(r'^[\d\s\$\.\,\-\:]+$').hasMatch(line) && line.length > 2) {
        merchantName = line;
        break;
      }
    }

    totalAmount = _extractTotalAmount(text);

    items = _extractLineItems(lines, totalAmount);

    return {
      'merchantName': merchantName,
      'totalAmount': totalAmount,
      'items': items,
      'rawText': text,
    };
  }

  double _extractTotalAmount(String text) {
    List<RegExp> totalPatterns = [
      RegExp(
        r'(?:TOTAL|Total|GRAND\s*TOTAL|Grand\s*Total)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:AMOUNT|Amount|TOTAL\s*AMOUNT|Total\s*Amount)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:AMOUNT\s*DUE|Amount\s*Due|BALANCE\s*DUE|Balance\s*Due)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:SUBTOTAL|Subtotal|SUB\s*TOTAL|Sub\s*Total)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:TOTAL|Total)[:\s]*([\d,]+\.?\d{0,2})\s*\$?',
        caseSensitive: false,
      ),
    ];

    double maxAmount = 0.0;

    for (var pattern in totalPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
        final amount = double.tryParse(amountStr) ?? 0.0;
        if (amount > maxAmount && amount < 100000) {
          maxAmount = amount;
        }
      }
    }

    return maxAmount;
  }

  List<Map<String, dynamic>> _extractLineItems(
    List<String> lines,
    double totalAmount,
  ) {
    List<Map<String, dynamic>> items = [];

    List<RegExp> itemPatterns = [
      RegExp(r'^(.+?)\s{2,}([\d,]+\.?\d{0,2})\s*$'),
      RegExp(r'^(.+?)\s+\$?\s*([\d,]+\.\d{2})\s*$'),
      RegExp(r'^(\d+)\s*[xX×]\s*(.+?)\s+([\d,]+\.?\d{0,2})\s*$'),
      RegExp(r'^(.+?)\s+(\d+)\s+([\d,]+\.?\d{0,2})\s*$'),
    ];

    for (String line in lines) {
      line = line.trim();

      if (_isHeaderOrFooterLine(line)) {
        continue;
      }

      for (var pattern in itemPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          String itemName = '';
          int quantity = 1;
          double price = 0.0;

          if (match.groupCount == 2) {
            itemName = match.group(1)?.trim() ?? '';
            price =
                double.tryParse(match.group(2)?.replaceAll(',', '') ?? '0') ??
                0.0;
          } else if (match.groupCount == 3) {
            final firstGroup = match.group(1)?.trim() ?? '';
            if (RegExp(r'^\d+$').hasMatch(firstGroup)) {
              quantity = int.tryParse(firstGroup) ?? 1;
              itemName = match.group(2)?.trim() ?? '';
              price =
                  double.tryParse(match.group(3)?.replaceAll(',', '') ?? '0') ??
                  0.0;
            } else {
              itemName = firstGroup;
              quantity = int.tryParse(match.group(2) ?? '1') ?? 1;
              price =
                  double.tryParse(match.group(3)?.replaceAll(',', '') ?? '0') ??
                  0.0;
            }
          }

          if (itemName.isNotEmpty &&
              itemName.length > 1 &&
              price > 0 &&
              price < totalAmount * 2 &&
              !_isInvalidItemName(itemName)) {
            items.add({
              'name': itemName,
              'quantity': quantity,
              'unitPrice': price / quantity,
              'totalPrice': price,
              'category': 'Other',
            });
            break;
          }
        }
      }
    }

    return items;
  }

  bool _isHeaderOrFooterLine(String line) {
    final headerFooterPatterns = [
      RegExp(
        r'(?:TOTAL|SUBTOTAL|TAX|AMOUNT|CHANGE|CASH|CREDIT|DEBIT)',
        caseSensitive: false,
      ),
      RegExp(r'^\s*[\-=\*]+\s*$'),
      RegExp(r'(?:RECEIPT|INVOICE|BILL|THANK\s*YOU)', caseSensitive: false),
      RegExp(r'(?:DATE|TIME|CASHIER|SERVER|TABLE)', caseSensitive: false),
      RegExp(r'^\s*\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}'),
      RegExp(r'^\s*\d{1,2}:\d{2}'),
      RegExp(r'(?:www\.|http|\.com|\.net)', caseSensitive: false),
      RegExp(r'^\s*#+\s*\d+'),
    ];

    for (var pattern in headerFooterPatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }

    return false;
  }

  bool _isInvalidItemName(String name) {
    final invalidPatterns = [
      RegExp(r'^\s*[\d\.\,\$\-]+\s*$'),
      RegExp(r'^[A-Z]{1,2}$'),
      RegExp(r'(?:TOTAL|SUBTOTAL|TAX|CHANGE)', caseSensitive: false),
    ];

    for (var pattern in invalidPatterns) {
      if (pattern.hasMatch(name)) {
        return true;
      }
    }

    return name.length < 2;
  }

  void _populateFieldsFromExtractedData(Map<String, dynamic> extractedData) {
    if (_receiptDataType == 0) {
      // Text Information - populate merchant name and items as text
      if (extractedData['merchantName'] != null &&
          extractedData['merchantName'].toString().isNotEmpty) {
        _taskController.text = extractedData['merchantName'];
      }

      if (extractedData['items'] != null &&
          (extractedData['items'] as List).isNotEmpty) {
        final items = extractedData['items'] as List<Map<String, dynamic>>;
        String itemsText = items.map((item) => item['name']).join(', ');
        _descriptionController.text = itemsText;
      }
    } else {
      // Cost Information - populate with total amount
      if (extractedData['merchantName'] != null &&
          extractedData['merchantName'].toString().isNotEmpty) {
        _taskController.text = extractedData['merchantName'];
      }

      if (extractedData['totalAmount'] != null &&
          extractedData['totalAmount'] > 0) {
        final totalAmount = extractedData['totalAmount'] as double;
        _descriptionController.text =
            'Total Cost: \$${totalAmount.toStringAsFixed(2)}';

        // Optionally add itemized breakdown
        if (extractedData['items'] != null &&
            (extractedData['items'] as List).isNotEmpty) {
          final items = extractedData['items'] as List<Map<String, dynamic>>;
          String itemsBreakdown = items
              .map((item) {
                return '${item['name']}: \$${item['totalPrice'].toStringAsFixed(2)}';
              })
              .join('\n');
          _descriptionController.text += '\n\nItemized:\n$itemsBreakdown';
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: cardColor,
                    background: backgroundColor,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    surface: cardColor,
                    background: backgroundColor,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: cardColor,
                    background: backgroundColor,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    surface: cardColor,
                    background: backgroundColor,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectPriority() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Priority',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                  ),
                ),
                SizedBox(height: 20),
                ..._buildPriorityOptions(),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedPriority = result;
      });
    }
  }

  List<Widget> _buildPriorityOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

    final priorities = ['High', 'Med', 'Low', 'None'];
    return priorities.map((priority) {
      return ListTile(
        title: Text(
          priority,
          style: TextStyle(color: textLight, fontWeight: FontWeight.w500),
        ),
        trailing: _selectedPriority == priority
            ? Icon(Icons.check, color: AppColors.primary)
            : null,
        onTap: () {
          Navigator.pop(context, priority);
        },
      );
    }).toList();
  }

  Future<void> _selectEnergyLevel() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Energy Level',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'How much mental or physical energy will this take?',
                  style: TextStyle(fontSize: 14, color: textGrey),
                ),
                SizedBox(height: 20),
                ..._buildEnergyLevelOptions(),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedEnergyLevel = result;
      });
    }
  }

  List<Widget> _buildEnergyLevelOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;

    final energyLevels = ['Low energy', 'Medium energy', 'High energy'];
    return energyLevels.map((level) {
      return ListTile(
        title: Text(
          level,
          style: TextStyle(color: textLight, fontWeight: FontWeight.w500),
        ),
        trailing: _selectedEnergyLevel == level
            ? Icon(Icons.check, color: AppColors.primary)
            : null,
        onTap: () {
          Navigator.pop(context, level);
        },
      );
    }).toList();
  }

  Future<void> _selectCategory() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Which part of your life is this?',
                  style: TextStyle(fontSize: 14, color: textGrey),
                ),
                SizedBox(height: 20),
                ..._buildCategoryOptions(),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result;
      });
    }
  }

  List<Widget> _buildCategoryOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

    final categories = [
      'Personal',
      'Home',
      'Health',
      'Finance',
      'Errands',
      'Work',
    ];
    ;
    return categories.map((category) {
      return ListTile(
        title: Text(
          category,
          style: TextStyle(color: textLight, fontWeight: FontWeight.w500),
        ),
        trailing: _selectedCategory == category
            ? Icon(Icons.check, color: AppColors.primary)
            : null,
        onTap: () {
          Navigator.pop(context, category);
        },
      );
    }).toList();
  }

  String _getDateDisplay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (selectedDay == today) {
      return 'Today';
    } else if (selectedDay == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    }
  }

  Future<void> _createTask() async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a task name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      String? timeString;
      if (_selectedTime != null) {
        timeString =
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
      }

      await _todoService.addTodo(
        title: _taskController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _selectedDate,
        dueTime: timeString,
        priority: _selectedPriority,
        energyLevel: _selectedEnergyLevel,
        category: _selectedCategory,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _SegmentedControl(
                    options: const ['Manual', 'From Receipt'],
                    selectedIndex: _inputMethod,
                    onChanged: (index) {
                      setState(() {
                        _inputMethod = index;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_inputMethod == 0) ...[
                          _buildTaskNameInput(),
                          SizedBox(height: 24),
                          _buildDescriptionField(),
                          SizedBox(height: 24),
                          _buildSettings(),
                        ] else ...[
                          _buildReceiptUploadSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptUploadSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Receipt',
          style: TextStyle(
            color: textLight,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Choose a method to digitize your receipt for smart OCR extraction.',
          style: TextStyle(color: textGrey, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Extract Data Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textGrey,
            ),
          ),
        ),
        _SegmentedControl(
          options: const ['Text Information', 'Cost Information'],
          selectedIndex: _receiptDataType,
          onChanged: (index) {
            setState(() {
              _receiptDataType = index;
              // Re-populate fields if data already extracted
              if (_extractedData != null) {
                _populateFieldsFromExtractedData(_extractedData!);
              }
            });
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _receiptDataType == 0
                ? 'Extract merchant name and item descriptions'
                : 'Extract merchant name and total cost with breakdown',
            style: TextStyle(
              fontSize: 12,
              color: textGrey.withOpacity(0.8),
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildUploadCard(
                icon: Icons.camera_alt,
                label: 'Camera Upload',
                color: AppColors.primary,
                onTap: _handleCameraUpload,
                cardSurfaceColor: cardSurfaceColor,
                borderColor: borderColor,
                textLight: textLight,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildUploadCard(
                icon: Icons.image,
                label: 'Gallery Upload',
                color: AppColors.primary,
                onTap: _handleGalleryUpload,
                cardSurfaceColor: cardSurfaceColor,
                borderColor: borderColor,
                textLight: textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildUploadCard(
                icon: Icons.picture_as_pdf,
                label: 'PDF Upload',
                color: const Color(0xFF0891b2),
                onTap: _handlePDFUpload,
                cardSurfaceColor: cardSurfaceColor,
                borderColor: borderColor,
                textLight: textLight,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 24),
        if (_isProcessing)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardSurfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OCR Extraction Status',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF92400e).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt,
                        color: Color(0xFF92400e),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scanning',
                            style: TextStyle(
                              color: textLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"$_processingFileName"',
                            style: TextStyle(
                              color: textLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _receiptDataType == 0
                                ? 'Extracting merchant name and item details...'
                                : 'Extracting merchant name and cost information...',
                            style: TextStyle(color: textGrey, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _processingProgress,
                              backgroundColor: borderColor,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (!_isProcessing) ...[
          _buildTaskNameInput(),
          SizedBox(height: 24),
          _buildDescriptionField(),
          SizedBox(height: 24),
          _buildSettings(),
        ],
      ],
    );
  }

  Widget _buildUploadCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Color cardSurfaceColor,
    required Color borderColor,
    required Color textLight,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: textLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: 0.015,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'New Todo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textLight,
                  letterSpacing: -0.015,
                ),
              ),
            ),
          ),
          SizedBox(width: 70),
        ],
      ),
    );
  }

  Widget _buildTaskNameInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Task Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textGrey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _taskController,
            autofocus: true,
            style: TextStyle(fontSize: 18, color: textLight),
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle: TextStyle(color: textGrey.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: Icon(
                Icons.edit_note,
                color: textGrey.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Description / Notes (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textGrey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: TextStyle(fontSize: 16, color: textLight),
            decoration: InputDecoration(
              hintText: 'Add additional details or notes about this task...',
              hintStyle: TextStyle(
                color: textGrey.withOpacity(0.6),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Settings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textGrey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.calendar_month,
                iconBg: AppColors.primary.withOpacity(0.1),
                iconColor: AppColors.primary,
                title: 'Due Date',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getDateDisplay(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textGrey, size: 18),
                  ],
                ),
                onTap: _selectDate,
                showDivider: true,
              ),
              _buildSettingItem(
                icon: Icons.access_time,
                iconBg: AppColors.primary.withOpacity(0.1),
                iconColor: AppColors.primary,
                title: 'Time',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedTime != null
                          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'None',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedTime != null
                            ? AppColors.primary
                            : textGrey,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textGrey, size: 18),
                  ],
                ),
                onTap: _selectTime,
                showDivider: true,
              ),
              _buildSettingItem(
                icon: Icons.notifications,
                iconBg: AppColors.iconBgOrange.withOpacity(0.1),
                iconColor: AppColors.iconBgOrange,
                title: 'Remind me',
                trailing: Switch(
                  value: _reminderEnabled,
                  onChanged: (value) {
                    setState(() {
                      _reminderEnabled = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveTrackColor: cardSurfaceColor,
                ),
                onTap: null,
                showDivider: true,
              ),
              _buildSettingItem(
                icon: Icons.flag,
                iconBg: AppColors.iconBgEmerald.withOpacity(0.1),
                iconColor: AppColors.iconBgEmerald,
                title: 'Priority',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedPriority,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textGrey,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textGrey, size: 18),
                  ],
                ),
                onTap: _selectPriority,
                showDivider: true,
              ),
              _buildSettingItem(
                icon: Icons.battery_charging_full,
                iconBg: AppColors.iconBgOrange.withOpacity(0.1),
                iconColor: AppColors.iconBgOrange,
                title: 'Energy Level',
                subtitle: 'How much effort will this take?',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedEnergyLevel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textGrey,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textGrey, size: 18),
                  ],
                ),
                onTap: _selectEnergyLevel,
                showDivider: true,
              ),
              _buildSettingItem(
                icon: Icons.label,
                iconBg: AppColors.primary.withOpacity(0.1),
                iconColor: AppColors.primary,
                title: 'Category',
                subtitle: 'Which part of your life is this?',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCategory,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textGrey,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: textGrey, size: 18),
                  ],
                ),
                onTap: _selectCategory,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textLight,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: textGrey.withOpacity(0.7),
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            if (showDivider)
              Container(
                margin: const EdgeInsets.only(top: 16, left: 56),
                height: 1,
                color: borderColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final primary = AppColors.primary;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundColor.withOpacity(0),
              backgroundColor,
              backgroundColor,
            ],
          ),
        ),
        child: ElevatedButton(
          onPressed: _createTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: AppColors.primary.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check, size: 20),
              SizedBox(width: 8),
              Text(
                'Create Task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SEGMENTED CONTROL WIDGET
// ============================================================================

class _SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final Function(int) onChanged;

  const _SegmentedControl({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cardSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 1 / options.length,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(
              options.length,
              (index) => Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      options[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selectedIndex == index
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selectedIndex == index ? textLight : textGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
