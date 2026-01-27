import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:spendwisesyncapp/screen/budget/receiptdetailscreen.dart';
import 'dart:io';

// App Colors - DARK MODE (moved to top level so they're accessible by all classes)
const Color backgroundDark = Color(0xFF0f1419);
const Color cardDark = Color(0xFF1a1f26);
const Color cardSurface = Color(0xFF1e2730);
const Color borderDark = Color(0xFF2d3542);
const Color textGreyDark = Color(0xFF94a3b8);
const Color textLightDark = Color(0xFFe2e8f0);

// App Colors - LIGHT MODE
const Color backgroundLight = Color(0xFFf6f7f8);
const Color cardLight = Color(0xFFffffff);
const Color cardSurfaceLight = Color(0xFFf1f5f9);
const Color borderLight = Color(0xFFe2e8f0);
const Color textGreyLight = Color(0xFF64748b);
const Color textLightLight = Color(0xFF0f172a);

// Shared colors
const Color primary = Color(0xFF00d4ff);
const Color greenSuccess = Color(0xFF10b981);

class AddReceiptPage extends StatefulWidget {
  const AddReceiptPage({Key? key}) : super(key: key);

  @override
  State<AddReceiptPage> createState() => _AddReceiptPageState();
}

class _AddReceiptPageState extends State<AddReceiptPage> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;
  String _processingFileName = '';
  double _processingProgress = 0.0;

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
    // Theme is controlled by main.dart
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

        // Perform actual OCR processing
        final extractedData = await _performOCR(image.path);

        setState(() {
          _isProcessing = false;
        });

        // Navigate to manual correction page with extracted data
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManualCorrectionPage(
                imagePath: image.path,
                fileName: image.name,
                extractedData: extractedData,
              ),
            ),
          );
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

        // Perform actual OCR processing
        final extractedData = await _performOCR(image.path);

        setState(() {
          _isProcessing = false;
        });

        // Navigate to manual correction page with extracted data
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManualCorrectionPage(
                imagePath: image.path,
                fileName: image.name,
                extractedData: extractedData,
              ),
            ),
          );
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

        // Note: PDF OCR would require additional processing (convert PDF to image first)
        // For now, go directly to manual correction
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManualCorrectionPage(
                imagePath: file.path!,
                fileName: file.name,
                extractedData: {
                  'merchantName': '',
                  'totalAmount': 0.0,
                  'items': [],
                  'rawText': '',
                },
              ),
            ),
          );
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

      // Create InputImage with proper orientation handling
      final inputImage = InputImage.fromFilePath(imagePath);

      // Initialize TextRecognizer with Latin script for better accuracy
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      setState(() {
        _processingProgress = 0.3;
      });

      // Process image with text recognition
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        _processingProgress = 0.6;
      });

      // Extract and process text with enhanced accuracy
      String fullText = _extractEnhancedText(recognizedText);

      // Parse the text to extract receipt information with improved algorithms
      Map<String, dynamic> extractedData = _parseReceiptText(fullText);

      setState(() {
        _processingProgress = 1.0;
      });

      // Close the text recognizer
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
    // Build text with enhanced confidence filtering and spatial awareness
    StringBuffer enhancedText = StringBuffer();
    List<String> lines = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        // Filter by confidence if available (ML Kit provides this implicitly through quality)
        String lineText = line.text.trim();

        if (lineText.isNotEmpty) {
          // Clean up common OCR errors
          lineText = _cleanOCRText(lineText);
          lines.add(lineText);
        }
      }
    }

    // Sort lines by vertical position for proper reading order
    recognizedText.blocks.sort((a, b) {
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });

    // Rebuild text with spatial awareness
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
    // Remove common OCR artifacts and fix typical recognition errors
    String cleaned = text;

    // Fix common character confusions
    cleaned = cleaned.replaceAll(RegExp(r'[|]'), 'I');
    cleaned = cleaned.replaceAll(RegExp(r'[¡]'), 'i');
    cleaned = cleaned.replaceAll(RegExp(r'[º°]'), '0');
    cleaned = cleaned.replaceAll(RegExp(r'[òóôõö]'), 'o');
    cleaned = cleaned.replaceAll(RegExp(r'[ÒÓÔÕÖ]'), 'O');

    // Fix currency symbols that might be misread
    cleaned = cleaned.replaceAll(RegExp(r'[\$§]'), '\$');

    // Remove excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Fix common word errors in receipts
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

    // Enhanced merchant name detection (first non-empty, non-numeric line)
    for (int i = 0; i < lines.length && i < 5; i++) {
      String line = lines[i].trim();
      // Skip lines that are mostly numbers or symbols
      if (!RegExp(r'^[\d\s\$\.\,\-\:]+$').hasMatch(line) && line.length > 2) {
        merchantName = line;
        break;
      }
    }

    // Enhanced total amount detection with multiple patterns
    totalAmount = _extractTotalAmount(text);

    // Enhanced item extraction with better pattern matching
    items = _extractLineItems(lines, totalAmount);

    return {
      'merchantName': merchantName,
      'totalAmount': totalAmount,
      'items': items,
      'rawText': text,
    };
  }

  double _extractTotalAmount(String text) {
    // Multiple patterns to catch different receipt formats
    List<RegExp> totalPatterns = [
      // Standard TOTAL patterns
      RegExp(
        r'(?:TOTAL|Total|GRAND\s*TOTAL|Grand\s*Total)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      // AMOUNT patterns
      RegExp(
        r'(?:AMOUNT|Amount|TOTAL\s*AMOUNT|Total\s*Amount)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      // DUE patterns
      RegExp(
        r'(?:AMOUNT\s*DUE|Amount\s*Due|BALANCE\s*DUE|Balance\s*Due)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      // SUBTOTAL as fallback
      RegExp(
        r'(?:SUBTOTAL|Subtotal|SUB\s*TOTAL|Sub\s*Total)[:\s]*\$?\s*([\d,]+\.?\d{0,2})',
        caseSensitive: false,
      ),
      // Patterns with currency at the end
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
        // Take the highest reasonable amount found
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

    // Enhanced patterns for item detection
    List<RegExp> itemPatterns = [
      // Pattern: Item Name ... Price (with dots/spaces between)
      RegExp(r'^(.+?)\s{2,}([\d,]+\.?\d{0,2})\s*$'),
      // Pattern: Item Name $Price or Item Name Price
      RegExp(r'^(.+?)\s+\$?\s*([\d,]+\.\d{2})\s*$'),
      // Pattern: Qty x Item Name Price
      RegExp(r'^(\d+)\s*[xX×]\s*(.+?)\s+([\d,]+\.?\d{0,2})\s*$'),
      // Pattern: Item Name Qty Price
      RegExp(r'^(.+?)\s+(\d+)\s+([\d,]+\.?\d{0,2})\s*$'),
    ];

    for (String line in lines) {
      line = line.trim();

      // Skip header lines, totals, tax lines, etc.
      if (_isHeaderOrFooterLine(line)) {
        continue;
      }

      // Try each pattern
      for (var pattern in itemPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          String itemName = '';
          int quantity = 1;
          double price = 0.0;

          if (match.groupCount == 2) {
            // Simple name + price pattern
            itemName = match.group(1)?.trim() ?? '';
            price =
                double.tryParse(match.group(2)?.replaceAll(',', '') ?? '0') ??
                0.0;
          } else if (match.groupCount == 3) {
            // Check if first group is quantity
            final firstGroup = match.group(1)?.trim() ?? '';
            if (RegExp(r'^\d+$').hasMatch(firstGroup)) {
              // Qty x Item Name Price pattern
              quantity = int.tryParse(firstGroup) ?? 1;
              itemName = match.group(2)?.trim() ?? '';
              price =
                  double.tryParse(match.group(3)?.replaceAll(',', '') ?? '0') ??
                  0.0;
            } else {
              // Item Name Qty Price pattern
              itemName = firstGroup;
              quantity = int.tryParse(match.group(2) ?? '1') ?? 1;
              price =
                  double.tryParse(match.group(3)?.replaceAll(',', '') ?? '0') ??
                  0.0;
            }
          }

          // Validate item
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
            break; // Found a match, don't try other patterns for this line
          }
        }
      }
    }

    return items;
  }

  bool _isHeaderOrFooterLine(String line) {
    // Check if line is a header, footer, or metadata line
    final headerFooterPatterns = [
      RegExp(
        r'(?:TOTAL|SUBTOTAL|TAX|AMOUNT|CHANGE|CASH|CREDIT|DEBIT)',
        caseSensitive: false,
      ),
      RegExp(
        r'^\s*[\-=\*]+\s*$',
      ), // Lines with only dashes, equals, or asterisks
      RegExp(r'(?:RECEIPT|INVOICE|BILL|THANK\s*YOU)', caseSensitive: false),
      RegExp(r'(?:DATE|TIME|CASHIER|SERVER|TABLE)', caseSensitive: false),
      RegExp(r'^\s*\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}'), // Date patterns
      RegExp(r'^\s*\d{1,2}:\d{2}'), // Time patterns
      RegExp(r'(?:www\.|http|\.com|\.net)', caseSensitive: false), // URLs
      RegExp(r'^\s*#+\s*\d+'), // Transaction/Receipt numbers
    ];

    for (var pattern in headerFooterPatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }

    return false;
  }

  bool _isInvalidItemName(String name) {
    // Filter out invalid item names
    final invalidPatterns = [
      RegExp(r'^\s*[\d\.\,\$\-]+\s*$'), // Only numbers and symbols
      RegExp(r'^[A-Z]{1,2}$'), // Single or double letters only
      RegExp(r'(?:TOTAL|SUBTOTAL|TAX|CHANGE)', caseSensitive: false),
    ];

    for (var pattern in invalidPatterns) {
      if (pattern.hasMatch(name)) {
        return true;
      }
    }

    return name.length < 2; // Too short
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Receipt',
          style: TextStyle(
            color: textLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: textLight),
            onPressed: () {
              // TODO: Show help dialog
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upload Receipt Section
              Text(
                'Upload Receipt',
                style: TextStyle(
                  color: textLight,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a method to digitize your document for smart OCR extraction.',
                style: TextStyle(color: textGrey, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Upload Options Grid
              Row(
                children: [
                  Expanded(
                    child: _buildUploadCard(
                      icon: Icons.camera_alt,
                      label: 'Camera Upload',
                      color: primary,
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
                      color: primary,
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
                  // Empty space to maintain grid alignment
                  const Expanded(child: SizedBox()),
                ],
              ),

              const SizedBox(height: 32),

              // OCR Extraction Status
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
                              color: primary,
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
                                  'Our AI is extracting merchant, date, and total amount...',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _processingProgress,
                                    backgroundColor: borderDark,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          primary,
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

              const SizedBox(height: 24),

              // Manual Correction Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManualCorrectionPage(
                          imagePath: '',
                          fileName: 'Manual Entry',
                          extractedData: {
                            'merchantName': '',
                            'totalAmount': 0.0,
                            'items': [],
                            'rawText': '',
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Manual Correction',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Can\'t wait? You can enter details manually anytime.',
                  style: TextStyle(color: textGrey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Recent Uploads
              StreamBuilder<QuerySnapshot>(
                stream: _getRecentUploadsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECENT UPLOADS',
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...snapshot.data!.docs.take(5).map((doc) {
                        return _buildRecentUploadItem(
                          doc,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textGrey: textGrey,
                          textLight: textLight,
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
        height: 180,
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: textLight,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentUploadItem(
    DocumentSnapshot doc, {
    required Color cardColor,
    required Color borderColor,
    required Color textGrey,
    required Color textLight,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final merchantName = data['merchantName'] ?? 'Unknown';
    final timestamp = data['timestamp'] as Timestamp?;

    String dateText = 'Recently';
    if (timestamp != null) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final receiptDate = DateTime(date.year, date.month, date.day);

      if (receiptDate == today) {
        dateText = 'Today';
      } else if (receiptDate == yesterday) {
        dateText = 'Yesterday';
      } else {
        dateText = '${date.month}/${date.day}';
      }
    }

    return FutureBuilder<double>(
      future: _getReceiptTotal(doc.id),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0.0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ReceiptDetailPage(receiptId: doc.id),
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: greenSuccess.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: greenSuccess,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchantName,
                        style: TextStyle(
                          color: textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateText • \$${total.toStringAsFixed(2)}',
                        style: TextStyle(color: textGrey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textGrey, size: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getRecentUploadsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('receipts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
  }

  Future<double> _getReceiptTotal(String receiptId) async {
    try {
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .doc(receiptId)
          .collection('receipt_items')
          .get();

      double total = 0.0;
      for (var item in itemsSnapshot.docs) {
        final itemData = item.data();
        total += (itemData['totalPrice'] ?? 0).toDouble();
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }
}

// Manual Correction Page
class ManualCorrectionPage extends StatefulWidget {
  final String imagePath;
  final String fileName;
  final Map<String, dynamic>? extractedData;

  const ManualCorrectionPage({
    Key? key,
    required this.imagePath,
    required this.fileName,
    this.extractedData,
  }) : super(key: key);

  @override
  State<ManualCorrectionPage> createState() => _ManualCorrectionPageState();
}

class _ManualCorrectionPageState extends State<ManualCorrectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _dateController = TextEditingController();
  final _categoryController = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill with extracted data if available
    if (widget.extractedData != null) {
      _merchantController.text = widget.extractedData!['merchantName'] ?? '';

      // Pre-populate items if extracted
      if (widget.extractedData!['items'] != null) {
        _items = List<Map<String, dynamic>>.from(
          widget.extractedData!['items'],
        );
      }
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        onAdd: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate() || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and add at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Create receipt document with auto-generated ID
      final receiptRef = FirebaseFirestore.instance
          .collection('receipts')
          .doc();
      final receiptId = receiptRef.id;

      // Create receipt document
      await receiptRef.set({
        'receiptId': receiptId,
        'userId': user.uid,
        'merchantName': _merchantController.text.trim(),
        'timestamp': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add items to subcollection
      final batch = FirebaseFirestore.instance.batch();
      for (var item in _items) {
        // Auto-generate item ID
        final itemRef = receiptRef.collection('receipt_items').doc();
        final itemId = itemRef.id;

        batch.set(itemRef, {
          'itemId': itemId,
          'name': item['name'],
          'quantity': item['quantity'],
          'unitPrice': item['unitPrice'],
          'totalPrice': item['totalPrice'],
          'category': item['category'] ?? 'Other',
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved successfully!'),
            backgroundColor: greenSuccess,
          ),
        );
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manual Correction',
          style: TextStyle(
            color: textLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _merchantController,
                style: TextStyle(color: textLight),
                decoration: InputDecoration(
                  labelText: 'Merchant Name',
                  labelStyle: TextStyle(color: textGrey),
                  filled: true,
                  fillColor: cardSurfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                style: TextStyle(color: textLight),
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: textGrey),
                  filled: true,
                  fillColor: cardSurfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._items
                  .map(
                    (item) => Card(
                      color: cardSurfaceColor,
                      child: ListTile(
                        title: Text(
                          item['name'],
                          style: TextStyle(color: textLight),
                        ),
                        subtitle: Text(
                          'Qty: ${item['quantity']} × \$${item['unitPrice']}',
                          style: TextStyle(color: textGrey),
                        ),
                        trailing: Text(
                          '\$${item['totalPrice']}',
                          style: TextStyle(
                            color: textLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveReceipt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Save Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddItemDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const AddItemDialog({Key? key, required this.onAdd}) : super(key: key);

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return AlertDialog(
      backgroundColor: cardColor,
      title: Text('Add Item', style: TextStyle(color: textLight)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
              labelText: 'Item Name',
              labelStyle: TextStyle(color: textGrey),
            ),
          ),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
              labelText: 'Quantity',
              labelStyle: TextStyle(color: textGrey),
            ),
          ),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
              labelText: 'Unit Price',
              labelStyle: TextStyle(color: textGrey),
            ),
          ),
          TextField(
            controller: _categoryController,
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: textGrey),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final qty = int.tryParse(_qtyController.text) ?? 1;
            final price = double.tryParse(_priceController.text) ?? 0;
            widget.onAdd({
              'name': _nameController.text,
              'quantity': qty,
              'unitPrice': price,
              'totalPrice': qty * price,
              'category': _categoryController.text.isEmpty
                  ? 'Other'
                  : _categoryController.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
