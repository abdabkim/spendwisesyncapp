import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class FinancialReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Compiles all Firestore segments into a single, clean state map
  Future<Map<String, dynamic>> fetchReportData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }
    final userId = user.uid;
    final email = user.email ?? 'user@spendwise.com';

    // 1. Fetch budgets
    double dailyLimit = 0;
    double dailySpent = 0;
    double weeklyLimit = 0;
    double weeklySpent = 0;
    double monthlyLimit = 0;
    double monthlySpent = 0;
    double payAmount = 0;
    double bankAmount = 0;
    double cashAmount = 0;
    String currencySymbol = '\$';
    List<Map<String, dynamic>> deductions = [];

    final dailyDoc = await _firestore.collection('budgets').doc('${userId}_daily').get();
    final weeklyDoc = await _firestore.collection('budgets').doc('${userId}_weekly').get();
    final monthlyDoc = await _firestore.collection('budgets').doc('${userId}_monthly').get();

    if (dailyDoc.exists) {
      final data = dailyDoc.data()!;
      dailyLimit = (data['limitAmount'] ?? 0.0).toDouble();
      dailySpent = (data['amountSpent'] ?? 0.0).toDouble();
    }
    if (weeklyDoc.exists) {
      final data = weeklyDoc.data()!;
      weeklyLimit = (data['limitAmount'] ?? 0.0).toDouble();
      weeklySpent = (data['amountSpent'] ?? 0.0).toDouble();
    }
    if (monthlyDoc.exists) {
      final data = monthlyDoc.data()!;
      monthlyLimit = (data['limitAmount'] ?? 0.0).toDouble();
      monthlySpent = (data['amountSpent'] ?? 0.0).toDouble();
      payAmount = (data['payAmount'] ?? 0.0).toDouble();
      bankAmount = (data['bankAmount'] ?? 0.0).toDouble();
      cashAmount = (data['cashAmount'] ?? 0.0).toDouble();
      currencySymbol = data['currency'] ?? '\$';

      if (data['monthlyDeductions'] != null) {
        deductions = List<Map<String, dynamic>>.from(
          data['monthlyDeductions'].map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    // 2. Fetch calendar events
    final calendarSnapshot = await _firestore
        .collection('calendar_events')
        .where('userId', isEqualTo: userId)
        .get();

    final List<Map<String, dynamic>> calendarEvents = [];
    for (var doc in calendarSnapshot.docs) {
      final data = doc.data();
      final title = data['title'] ?? 'Event';
      final timestamp = data['date'] as Timestamp?;
      final date = timestamp?.toDate() ?? DateTime.now();
      final projectedCost = (data['projectedCost'] ?? 0.0).toDouble();
      calendarEvents.add({
        'title': title,
        'date': date,
        'projectedCost': projectedCost,
      });
    }
    // Sort in-memory defensively
    calendarEvents.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // 3. Fetch receipts
    final receiptsSnapshot = await _firestore
        .collection('receipts')
        .where('userId', isEqualTo: userId)
        .get();

    final List<Map<String, dynamic>> receiptsList = [];
    for (var doc in receiptsSnapshot.docs) {
      final data = doc.data();
      final merchant = data['merchantName'] ?? 'Merchant';
      final timestamp = data['date'] as Timestamp?;
      final date = timestamp?.toDate() ?? DateTime.now();
      final total = (data['totalCost'] ?? 0.0).toDouble();
      final items = List<String>.from(data['items'] ?? []);

      receiptsList.add({
        'merchant': merchant,
        'date': date,
        'total': total,
        'items': items,
      });
    }
    receiptsList.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return {
      'email': email,
      'currencySymbol': currencySymbol,
      'payAmount': payAmount,
      'bankAmount': bankAmount,
      'cashAmount': cashAmount,
      'dailyLimit': dailyLimit,
      'dailySpent': dailySpent,
      'weeklyLimit': weeklyLimit,
      'weeklySpent': weeklySpent,
      'monthlyLimit': monthlyLimit,
      'monthlySpent': monthlySpent,
      'deductions': deductions,
      'calendarEvents': calendarEvents,
      'receipts': receiptsList,
    };
  }

  // Generates the PDF Document using pdf/widgets
  Future<pw.Document> generatePDFReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final email = data['email'] as String;
    final currency = data['currencySymbol'] as String;
    final pay = data['payAmount'] as double;
    final bank = data['bankAmount'] as double;
    final cash = data['cashAmount'] as double;
    final dailyLimit = data['dailyLimit'] as double;
    final dailySpent = data['dailySpent'] as double;
    final weeklyLimit = data['weeklyLimit'] as double;
    final weeklySpent = data['weeklySpent'] as double;
    final monthlyLimit = data['monthlyLimit'] as double;
    final monthlySpent = data['monthlySpent'] as double;
    final deductions = data['deductions'] as List<Map<String, dynamic>>;
    final calendarEvents = data['calendarEvents'] as List<Map<String, dynamic>>;
    // ignore: unused_local_variable
    final receipts = data['receipts'] as List<Map<String, dynamic>>;

    // Calculations
    final totalDeductions = deductions.fold<double>(0, (acc, d) => acc + (d['amount'] as num).toDouble());
    final totalAssets = bank + cash + pay;
    final totalLiabilities = totalDeductions +
        (dailyLimit - dailySpent).clamp(0, double.infinity) +
        (weeklyLimit - weeklySpent).clamp(0, double.infinity) +
        (monthlyLimit - monthlySpent).clamp(0, double.infinity);
    final netEquity = totalAssets - totalLiabilities;

    final totalSpentOutflows = dailySpent + weeklySpent + monthlySpent + totalDeductions;
    final netIncome = pay - totalSpentOutflows;

    final primaryNavy = PdfColor.fromHex('#1e3a8a');
    final accentCyan = PdfColor.fromHex('#0284c7');
    final textDark = PdfColor.fromHex('#0f172a');
    final textMuted = PdfColor.fromHex('#64748b');
    final dividerColor = PdfColor.fromHex('#e2e8f0');
    final zebraBg = PdfColor.fromHex('#f8fafc');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Page Header Title Card
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: primaryNavy, width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SPENDWISE FINANCIAL STATEMENT',
                        style: pw.TextStyle(
                          color: primaryNavy,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Comprehensive Audit & Spending Report',
                        style: pw.TextStyle(
                          color: textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(color: textMuted, fontSize: 9),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Account: $email',
                        style: pw.TextStyle(color: textMuted, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // BALANCE SHEET SECTION
            pw.Text(
              '1. BALANCE SHEET',
              style: pw.TextStyle(
                color: primaryNavy,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Divider(color: dividerColor, thickness: 1),
            pw.SizedBox(height: 6),

            // Balance Sheet Table
            pw.Table(
              border: pw.TableBorder.all(color: dividerColor, width: 0.5),
              children: [
                // Assets Category
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('ASSETS (Liquid Resources)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Amount ($currency)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Bank Account Balance', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(bank.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Cash on Hand', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(cash.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Monthly Income / Pay Amount', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pay.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL ASSETS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryNavy))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalAssets.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryNavy), textAlign: pw.TextAlign.right)),
                  ],
                ),

                // Liabilities Category
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('LIABILITIES & OUTSTANDING COMMITMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('', style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Fixed Monthly Deductions', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalDeductions.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Remaining Budget Allocation / Commitments', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        ((dailyLimit - dailySpent).clamp(0, double.infinity) +
                                (weeklyLimit - weeklySpent).clamp(0, double.infinity) +
                                (monthlyLimit - monthlySpent).clamp(0, double.infinity))
                            .toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL LIABILITIES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentCyan))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalLiabilities.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentCyan), textAlign: pw.TextAlign.right)),
                  ],
                ),

                // Net Equity Summary
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryNavy),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('NET FINANCIAL EQUITY / LIQUIDITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(netEquity.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // INCOME STATEMENT SECTION
            pw.Text(
              '2. INCOME STATEMENT (PROFIT & LOSS)',
              style: pw.TextStyle(
                color: primaryNavy,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Divider(color: dividerColor, thickness: 1),
            pw.SizedBox(height: 6),

            // Income Statement Details
            pw.Table(
              border: pw.TableBorder.all(color: dividerColor, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Revenue & Inflows', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount ($currency)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Monthly Income (Pay Amount)', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(pay.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Expenses & Outflows', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: const pw.TextStyle(fontSize: 10))),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Fixed Monthly Deductions', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalDeductions.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Actual Variable Spending (Daily/Weekly/Monthly Spent)', style: const pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((dailySpent + weeklySpent + monthlySpent).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL EXPENSES / OUTFLOWS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentCyan))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(totalSpentOutflows.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accentCyan), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: netIncome >= 0 ? PdfColor.fromHex('#e6f4ea') : PdfColor.fromHex('#fce8e6')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        netIncome >= 0 ? 'NET FINANCIAL SURPLUS (SAVINGS)' : 'NET FINANCIAL DEFICIT (OVERSPEND)',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: netIncome >= 0 ? PdfColor.fromHex('#137333') : PdfColor.fromHex('#c5221f'),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        netIncome.toStringAsFixed(2),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: netIncome >= 0 ? PdfColor.fromHex('#137333') : PdfColor.fromHex('#c5221f'),
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // BUDGET DIAGNOSTIC PERFORMANCE
            pw.Text(
              '3. BUDGET LIMITS PERFORMANCE',
              style: pw.TextStyle(
                color: primaryNavy,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Divider(color: dividerColor, thickness: 1),
            pw.SizedBox(height: 6),

            // Budget limits table
            pw.Table(
              border: pw.TableBorder.all(color: dividerColor, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: zebraBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Budget Period', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Limit ($currency)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Spent ($currency)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Remaining ($currency)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Usage %', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Daily Limit', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dailyLimit.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dailySpent.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((dailyLimit - dailySpent).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        dailyLimit > 0 ? '${((dailySpent / dailyLimit) * 100).toStringAsFixed(0)}%' : '0%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: (dailySpent > dailyLimit) ? PdfColor.fromHex('#ef4444') : textDark,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Weekly Limit', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(weeklyLimit.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(weeklySpent.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((weeklyLimit - weeklySpent).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        weeklyLimit > 0 ? '${((weeklySpent / weeklyLimit) * 100).toStringAsFixed(0)}%' : '0%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: (weeklySpent > weeklyLimit) ? PdfColor.fromHex('#ef4444') : textDark,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Monthly Limit', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(monthlyLimit.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(monthlySpent.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((monthlyLimit - monthlySpent).toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        monthlyLimit > 0 ? '${((monthlySpent / monthlyLimit) * 100).toStringAsFixed(0)}%' : '0%',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: (monthlySpent > monthlyLimit) ? PdfColor.fromHex('#ef4444') : textDark,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // CALENDAR FORECASTING SECTION
            pw.Text(
              '4. SMART CALENDAR FORECASTING (UPCOMING SPEND)',
              style: pw.TextStyle(
                color: primaryNavy,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Divider(color: dividerColor, thickness: 1),
            pw.SizedBox(height: 6),

            if (calendarEvents.isEmpty)
              pw.Text('No high-spend upcoming calendar events synced.', style: pw.TextStyle(color: textMuted, fontSize: 9))
            else
              pw.Table(
                border: pw.TableBorder.all(color: dividerColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: zebraBg),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Event Name / Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Scheduled Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Projected Inflow/Outflow Impact', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...calendarEvents.map((event) {
                    final title = event['title'] as String;
                    final date = event['date'] as DateTime;
                    final cost = event['projectedCost'] as double;
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(title, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('yyyy-MM-dd').format(date), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            cost > 0 ? '+\$${cost.toStringAsFixed(2)}' : 'Standard (\$0.00)',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: cost > 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                              color: cost > 0 ? PdfColor.fromHex('#ef4444') : textMuted,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

            pw.SizedBox(height: 24),

            // SIGN-OFF CERTIFICATION
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: zebraBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: dividerColor, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AUDIT & RECORD CERTIFICATION',
                    style: pw.TextStyle(
                      color: primaryNavy,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'This document compiles real-time synced accounts and receipt scan records stored inside SpendWise Sync secure cloud databases. It represents a verified copy of assets, fixed deductions, limits, and smart predicted budgets, intended for personal accounting and budget reviews.',
                    style: pw.TextStyle(color: textMuted, fontSize: 8, height: 1.3),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(width: 120, height: 0.5, color: textMuted),
                          pw.SizedBox(height: 2),
                          pw.Text('Client / User Sign-off', style: pw.TextStyle(color: textMuted, fontSize: 7)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(width: 120, height: 0.5, color: textMuted),
                          pw.SizedBox(height: 2),
                          pw.Text('SpendWise Sync General Auditor', style: pw.TextStyle(color: textMuted, fontSize: 7)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  // Generates the CSV report contents
  String generateCSVReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    final currency = data['currencySymbol'] as String;
    final pay = data['payAmount'] as double;
    final bank = data['bankAmount'] as double;
    final cash = data['cashAmount'] as double;
    final dailyLimit = data['dailyLimit'] as double;
    final dailySpent = data['dailySpent'] as double;
    final weeklyLimit = data['weeklyLimit'] as double;
    final weeklySpent = data['weeklySpent'] as double;
    final monthlyLimit = data['monthlyLimit'] as double;
    final monthlySpent = data['monthlySpent'] as double;
    final deductions = data['deductions'] as List<Map<String, dynamic>>;
    final calendarEvents = data['calendarEvents'] as List<Map<String, dynamic>>;
    final receipts = data['receipts'] as List<Map<String, dynamic>>;

    // General Title
    buffer.writeln('==================================================');
    buffer.writeln('SPENDWISE SYNC - COMPREHENSIVE FINANCIAL REPORT');
    buffer.writeln('Generated On,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('Account Owner,${data['email']}');
    buffer.writeln('==================================================');
    buffer.writeln();

    // 1. Balance Sheet
    buffer.writeln('1. BALANCE SHEET');
    buffer.writeln('Asset Category,Amount ($currency)');
    buffer.writeln('Bank Account Balance,${bank.toStringAsFixed(2)}');
    buffer.writeln('Cash on Hand,${cash.toStringAsFixed(2)}');
    buffer.writeln('Monthly Pay/Income,${pay.toStringAsFixed(2)}');
    final totalAssets = bank + cash + pay;
    buffer.writeln('TOTAL ASSETS,${totalAssets.toStringAsFixed(2)}');
    buffer.writeln();

    final totalDeductions = deductions.fold<double>(0, (acc, d) => acc + (d['amount'] as num).toDouble());
    final totalCommitments = (dailyLimit - dailySpent).clamp(0, double.infinity) +
        (weeklyLimit - weeklySpent).clamp(0, double.infinity) +
        (monthlyLimit - monthlySpent).clamp(0, double.infinity);
    final totalLiabilities = totalDeductions + totalCommitments;

    buffer.writeln('Liability Category,Amount ($currency)');
    buffer.writeln('Fixed Monthly Deductions,${totalDeductions.toStringAsFixed(2)}');
    buffer.writeln('Outstanding Budget Commitments,${totalCommitments.toStringAsFixed(2)}');
    buffer.writeln('TOTAL LIABILITIES,${totalLiabilities.toStringAsFixed(2)}');
    buffer.writeln('NET LIQUID EQUITY / LIQUIDITY,${(totalAssets - totalLiabilities).toStringAsFixed(2)}');
    buffer.writeln();

    // 2. Income Statement
    buffer.writeln('2. INCOME STATEMENT (P&L)');
    buffer.writeln('Line Item,Amount ($currency)');
    buffer.writeln('Total Monthly Revenue,${pay.toStringAsFixed(2)}');
    buffer.writeln('Fixed Monthly Deductions,${totalDeductions.toStringAsFixed(2)}');
    buffer.writeln('Variable Spent (All Periods),${(dailySpent + weeklySpent + monthlySpent).toStringAsFixed(2)}');
    final totalOutflows = dailySpent + weeklySpent + monthlySpent + totalDeductions;
    buffer.writeln('TOTAL EXPENSES & OUTFLOWS,${totalOutflows.toStringAsFixed(2)}');
    buffer.writeln('NET FINANCIAL SURPLUS/DEFICIT,${(pay - totalOutflows).toStringAsFixed(2)}');
    buffer.writeln();

    // 3. Budgets Breakdown
    buffer.writeln('3. BUDGET PERIOD BREAKDOWN');
    buffer.writeln('Period,Limit ($currency),Spent ($currency),Remaining ($currency),Usage %');
    buffer.writeln('Daily Budget,${dailyLimit.toStringAsFixed(2)},${dailySpent.toStringAsFixed(2)},${(dailyLimit - dailySpent).toStringAsFixed(2)},${dailyLimit > 0 ? ((dailySpent / dailyLimit) * 100).toStringAsFixed(0) : 0}%');
    buffer.writeln('Weekly Budget,${weeklyLimit.toStringAsFixed(2)},${weeklySpent.toStringAsFixed(2)},${(weeklyLimit - weeklySpent).toStringAsFixed(2)},${weeklyLimit > 0 ? ((weeklySpent / weeklyLimit) * 100).toStringAsFixed(0) : 0}%');
    buffer.writeln('Monthly Budget,${monthlyLimit.toStringAsFixed(2)},${monthlySpent.toStringAsFixed(2)},${(monthlyLimit - monthlySpent).toStringAsFixed(2)},${monthlyLimit > 0 ? ((monthlySpent / monthlyLimit) * 100).toStringAsFixed(0) : 0}%');
    buffer.writeln();

    // 4. Calendar Sync Forecast
    buffer.writeln('4. SMART CALENDAR FORECAST');
    buffer.writeln('Event Description,Date,Projected High-Spend Cost ($currency)');
    if (calendarEvents.isEmpty) {
      buffer.writeln('No synced calendar events scheduled,N/A,0.00');
    } else {
      for (var event in calendarEvents) {
        final title = event['title'] as String;
        final date = event['date'] as DateTime;
        final cost = event['projectedCost'] as double;
        buffer.writeln('"${title.replaceAll('"', '""')}",${DateFormat('yyyy-MM-dd').format(date)},${cost.toStringAsFixed(2)}');
      }
    }
    buffer.writeln();

    // 5. Scanned Receipts Log
    buffer.writeln('5. SCANNED RECEIPTS LOG');
    buffer.writeln('Merchant/Vendor,Date,Total Paid ($currency),Items Extracted');
    if (receipts.isEmpty) {
      buffer.writeln('No receipts scanned yet,N/A,0.00,N/A');
    } else {
      for (var rec in receipts) {
        final merchant = rec['merchant'] as String;
        final date = rec['date'] as DateTime;
        final total = rec['total'] as double;
        final items = rec['items'] as List<String>;
        final itemsStr = items.join(' | ').replaceAll('"', '""');
        buffer.writeln('"${merchant.replaceAll('"', '""')}",${DateFormat('yyyy-MM-dd').format(date)},${total.toStringAsFixed(2)},"$itemsStr"');
      }
    }

    return buffer.toString();
  }

  // Orchestrates native PDF printing and preview dialogs
  Future<void> exportPDF() async {
    final reportData = await fetchReportData();
    final pdfDoc = await generatePDFReport(reportData);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfDoc.save(),
      name: 'SpendWise_Financial_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // Compiles, saves to a temporary file, and triggers standard sharing options
  Future<void> exportCSV() async {
    final reportData = await fetchReportData();
    final csvContent = generateCSVReport(reportData);

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/SpendWise_Financial_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(csvContent);

    // Share using share_plus
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Here is my curated SpendWise Sync Financial Report & Balance Sheet.',
    );
  }
}
