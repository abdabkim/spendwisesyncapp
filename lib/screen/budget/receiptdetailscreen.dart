import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReceiptDetailPage extends StatefulWidget {
  final String receiptId;

  const ReceiptDetailPage({Key? key, required this.receiptId})
    : super(key: key);

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage> {
  // App Colors - DARK MODE
  static const Color backgroundDark = Color(0xFF0f1419);
  static const Color cardDark = Color(0xFF1a1f26);
  static const Color cardSurface = Color(0xFF1e2730);
  static const Color borderDark = Color(0xFF2d3542);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFe2e8f0);

  // App Colors - LIGHT MODE
  static const Color backgroundLight = Color(0xFFf6f7f8);
  static const Color cardLight = Color(0xFFffffff);
  static const Color cardSurfaceLight = Color(0xFFf1f5f9);
  static const Color borderLight = Color(0xFFe2e8f0);
  static const Color textGreyLight = Color(0xFF64748b);
  static const Color textLightLight = Color(0xFF0f172a);

  // Shared colors
  static const Color primary = Color(0xFF00d4ff);
  static const Color greenSuccess = Color(0xFF10b981);

  Map<String, dynamic>? _receiptData;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadReceiptData();
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

  Future<void> _loadReceiptData() async {
    try {
      // Get receipt document
      final receiptDoc = await FirebaseFirestore.instance
          .collection('receipts')
          .doc(widget.receiptId)
          .get();

      if (!receiptDoc.exists) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Get receipt items from subcollection
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .doc(widget.receiptId)
          .collection('receipt_items')
          .get();

      final items = itemsSnapshot.docs.map((doc) {
        return doc.data();
      }).toList();

      setState(() {
        _receiptData = receiptDoc.data();
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading receipt: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '\$${formatter.format(amount)}';
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    return DateFormat('MMM dd, yyyy, hh:mm a').format(dateTime);
  }

  double get _subtotal {
    return _items.fold(
      0.0,
      (sum, item) => sum + (item['totalPrice'] ?? 0).toDouble(),
    );
  }

  double get _tax {
    // Calculate 8.5% tax
    return _subtotal * 0.085;
  }

  double get _total {
    return _subtotal + _tax;
  }

  Future<void> _saveAsImage() async {
    try {
      // TODO: Implement save as image functionality
      // This would require screenshot capability
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image save functionality coming soon'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error saving image: $e');
    }
  }

  Future<void> _saveAsPDF() async {
    try {
      final pdf = pw.Document();

      // Create PDF document
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Text(
                      _receiptData?['merchantName'] ?? 'Receipt',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      _formatDateTime(_receiptData?['timestamp']),
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Divider(),
                  pw.SizedBox(height: 20),

                  // Items Header
                  pw.Text(
                    'ITEMS PURCHASED',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Items List
                  ..._items.map((item) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 16),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  item['name'] ?? '',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  '${item['quantity']} units x ${_formatCurrency((item['unitPrice'] ?? 0).toDouble())}',
                                  style: const pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Text(
                            _formatCurrency(
                              (item['totalPrice'] ?? 0).toDouble(),
                            ),
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 16),

                  // Totals
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Subtotal',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                      pw.Text(
                        _formatCurrency(_subtotal),
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Tax (8.5%)',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                      pw.Text(
                        _formatCurrency(_tax),
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Amount',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(_total),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/receipt_${widget.receiptId}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share the PDF
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Receipt from ${_receiptData?['merchantName'] ?? 'Store'}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully!'),
            backgroundColor: greenSuccess,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error saving PDF: $e');
    }
  }

  Future<void> _printReceipt() async {
    try {
      final pdf = pw.Document();

      // Create PDF document (same as save PDF)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Text(
                      _receiptData?['merchantName'] ?? 'Receipt',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      _formatDateTime(_receiptData?['timestamp']),
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Divider(),
                  pw.SizedBox(height: 20),

                  // Items Header
                  pw.Text(
                    'ITEMS PURCHASED',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // Items List
                  ..._items.map((item) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 16),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  item['name'] ?? '',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  '${item['quantity']} units x ${_formatCurrency((item['unitPrice'] ?? 0).toDouble())}',
                                  style: const pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Text(
                            _formatCurrency(
                              (item['totalPrice'] ?? 0).toDouble(),
                            ),
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.SizedBox(height: 16),

                  // Totals
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Subtotal',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                      pw.Text(
                        _formatCurrency(_subtotal),
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Tax (8.5%)',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                      pw.Text(
                        _formatCurrency(_tax),
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Amount',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _formatCurrency(_total),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showErrorSnackBar('Error printing receipt: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

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
          'Receipt Detail',
          style: TextStyle(
            color: textLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: textLight),
            onPressed: _saveAsPDF,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Receipt Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // Merchant Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: cardSurfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(Icons.store, color: textLight, size: 28),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Merchant Name
                    Text(
                      _receiptData?['merchantName'] ?? 'Unknown Store',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12),

                    // Date & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, color: primary, size: 16),
                        SizedBox(width: 8),
                        Text(
                          _formatDateTime(_receiptData?['timestamp']),
                          style: TextStyle(
                            color: primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Reference Number
                    Text(
                      'REF: #${widget.receiptId.substring(0, 8).toUpperCase()}',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            borderDark,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Items Purchased Header
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ITEMS PURCHASED',
                        style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Items List
                    ..._items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: TextStyle(
                                      color: textLight,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${item['quantity']} units x ${_formatCurrency((item['unitPrice'] ?? 0).toDouble())}',
                                    style: TextStyle(
                                      color: textGrey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(
                                (item['totalPrice'] ?? 0).toDouble(),
                              ),
                              style: TextStyle(
                                color: textLight,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    SizedBox(height: 16),

                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            borderDark,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Subtotal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(color: textGrey, fontSize: 15),
                        ),
                        Text(
                          _formatCurrency(_subtotal),
                          style: TextStyle(
                            color: textLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Tax
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tax (8.5%)',
                          style: TextStyle(color: textGrey, fontSize: 15),
                        ),
                        Text(
                          _formatCurrency(_tax),
                          style: TextStyle(
                            color: textLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    // Total Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            color: textLight,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatCurrency(_total),
                          style: TextStyle(
                            color: primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Payment Method (placeholder)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardSurfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.credit_card,
                              color: primary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visa Card',
                                  style: TextStyle(
                                    color: textLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '•••• 4242',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: greenSuccess,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveAsImage,
                      icon: Icon(Icons.image, size: 20),
                      label: Text('Save Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveAsPDF,
                      icon: Icon(Icons.picture_as_pdf, size: 20),
                      label: Text('Save PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Print Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _printReceipt,
                  icon: Icon(Icons.print, size: 20),
                  label: Text(
                    'Print Receipt',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Map Placeholder (optional)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: cardSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Stack(
                  children: [
                    // Map placeholder
                    Center(
                      child: Icon(
                        Icons.map,
                        size: 60,
                        color: textGrey.withOpacity(0.3),
                      ),
                    ),
                    // Location Badge
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, color: primary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'LOCATION NOT AVAILABLE',
                                style: TextStyle(
                                  color: textGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
