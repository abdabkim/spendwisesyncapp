import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:spendwisesyncapp/services/calendar_service.dart';
import 'package:spendwisesyncapp/screen/budget/calendar_sync_screen.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // App Colors - DARK MODE
  static const Color backgroundDark = Color(0xFF0f1115);
  static const Color cardDark = Color(0xFF1a1d24);
  static const Color cardSurface = Color(0xFF23262e);
  static const Color borderDark = Color(0xFF2d3542);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFd1d5db);

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
  static const Color yellowWarning = Color(0xFFf59e0b);
  static const Color redError = Color(0xFFef4444);

  // Budget data
  double _payAmount = 0;
  double _bankAmount = 0;
  double _cashAmount = 0;

  // Monthly deductions list (current month)
  List<Map<String, dynamic>> _monthlyDeductions = [];

  // Historical deductions grouped by month
  List<Map<String, dynamic>> _deductionHistory = [];

  // Daily limit
  double _dailyLimit = 0;
  double _dailySpent = 0;

  // Weekly limit
  double _weeklyLimit = 0;
  double _weeklySpent = 0;

  // Monthly limit
  double _monthlyLimit = 0;
  double _monthlySpent = 0;

  bool _isLoading = true;
  String _currencySymbol = '\$';

  List<CalendarEvent> _calendarEvents = [];
  final CalendarService _calendarService = CalendarService();

  String get _currentMonthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String get _previousMonthKey {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  String get _currentMonthLabel {
    return DateFormat('MMMM yyyy').format(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadBudgetData();
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
    prefs.getBool('isDarkMode') ?? true;
    // Theme is controlled by main.dart
  }

  Future<void> _loadBudgetData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = user.uid;

      // Daily budget
      final dailyDocId = '${userId}_daily';
      final dailyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(dailyDocId)
          .get();

      // Weekly budget
      final weeklyDocId = '${userId}_weekly';
      final weeklyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(weeklyDocId)
          .get();

      // Monthly budget
      final monthlyDocId = '${userId}_monthly';
      final monthlyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(monthlyDocId)
          .get();

      List<Map<String, dynamic>> loadedDeductions = [];
      List<Map<String, dynamic>> loadedHistory = [];
      String? lastActiveMonth;
      double loadedBankAmount = _bankAmount;

      // Extract values first so we can mutate them before setState
      if (dailyDoc.exists) {
        final data = dailyDoc.data()!;
        _dailyLimit = (data['limitAmount'] ?? _dailyLimit).toDouble();
        _dailySpent = (data['amountSpent'] ?? _dailySpent).toDouble();
      }
      if (weeklyDoc.exists) {
        final data = weeklyDoc.data()!;
        _weeklyLimit = (data['limitAmount'] ?? _weeklyLimit).toDouble();
        _weeklySpent = (data['amountSpent'] ?? _weeklySpent).toDouble();
      }
      if (monthlyDoc.exists) {
        final data = monthlyDoc.data()!;
        _monthlyLimit = (data['limitAmount'] ?? _monthlyLimit).toDouble();
        _monthlySpent = (data['amountSpent'] ?? _monthlySpent).toDouble();
        _payAmount = (data['payAmount'] ?? _payAmount).toDouble();
        loadedBankAmount = (data['bankAmount'] ?? _bankAmount).toDouble();
        _cashAmount = (data['cashAmount'] ?? _cashAmount).toDouble();
        _currencySymbol = data['currency'] ?? '\$';

        if (data['monthlyDeductions'] != null) {
          loadedDeductions = List<Map<String, dynamic>>.from(
            data['monthlyDeductions'].map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }
        if (data['deductionHistory'] != null) {
          loadedHistory = List<Map<String, dynamic>>.from(
            data['deductionHistory'].map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
        }
        lastActiveMonth = data['lastActiveMonth'] as String?;
      }

      final monthlyDocRef = FirebaseFirestore.instance
          .collection('budgets')
          .doc('${userId}_monthly');

      double deductionTotal(List<Map<String, dynamic>> deductions) =>
          deductions
              .where((d) => d['enabled'] as bool? ?? true)
              .fold<double>(
                0.0,
                (acc, d) => acc + (d['amount'] as num).toDouble(),
              );

      // Step 1 — one-time migration: legacy undated deductions → previous month.
      final hasLegacyDeductions = loadedDeductions.isNotEmpty &&
          loadedDeductions.any((d) => d['date'] == null);

      if (hasLegacyDeductions) {
        final prevKey = _previousMonthKey;
        final alreadyArchived =
            loadedHistory.any((h) => h['monthKey'] == prevKey);
        if (!alreadyArchived) {
          loadedHistory.insert(0, {
            'monthKey': prevKey,
            'monthLabel': _labelForMonthKey(prevKey),
            'deductions': loadedDeductions,
            'totalDeductions': deductionTotal(loadedDeductions),
            'bankAdjusted': false, // will be handled in step 2 below
          });
        }
        loadedDeductions = [];
        if (monthlyDoc.exists) {
          await monthlyDocRef.update({
            'monthlyDeductions': [],
            'deductionHistory': loadedHistory,
            'lastActiveMonth': _currentMonthKey,
          });
        }
      } else if (lastActiveMonth != null &&
          lastActiveMonth != _currentMonthKey &&
          loadedDeductions.isNotEmpty) {
        // Normal month rollover: archive current deductions under the old month.
        final alreadyArchived = loadedHistory.any(
          (h) => h['monthKey'] == lastActiveMonth,
        );
        if (!alreadyArchived) {
          loadedHistory.insert(0, {
            'monthKey': lastActiveMonth,
            'monthLabel': _labelForMonthKey(lastActiveMonth),
            'deductions': loadedDeductions,
            'totalDeductions': deductionTotal(loadedDeductions),
            'bankAdjusted': false,
          });
        }
        loadedDeductions = [];
        await monthlyDocRef.update({
          'monthlyDeductions': [],
          'deductionHistory': loadedHistory,
          'lastActiveMonth': _currentMonthKey,
        });
      } else if (lastActiveMonth == null && monthlyDoc.exists) {
        await monthlyDocRef.update({'lastActiveMonth': _currentMonthKey});
      }

      // Step 2 — apply any history entries not yet reflected in bankAmount.
      // Each entry is stamped bankAdjusted:true exactly once so this is safe
      // to run on every load without double-subtracting.
      bool needsBankUpdate = false;
      for (final entry in loadedHistory) {
        if (!(entry['bankAdjusted'] as bool? ?? false)) {
          final entryTotal =
              (entry['totalDeductions'] as num?)?.toDouble() ?? 0.0;
          loadedBankAmount -= entryTotal;
          entry['bankAdjusted'] = true;
          needsBankUpdate = true;
        }
      }
      if (needsBankUpdate && monthlyDoc.exists) {
        await monthlyDocRef.update({
          'bankAmount': loadedBankAmount,
          'deductionHistory': loadedHistory,
        });
      }

      final calendarEvents = await _calendarService.getEvents(userId);

      setState(() {
        _bankAmount = loadedBankAmount;
        _monthlyDeductions = loadedDeductions;
        _deductionHistory = loadedHistory;
        _calendarEvents = calendarEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading budget data: $e');
    }
  }

  String _labelForMonthKey(String monthKey) {
    try {
      final parts = monthKey.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return monthKey;
    }
  }

  String _formatCurrency(double amount, {int decimals = 2}) {
    final formatter = NumberFormat('#,##0.${'0' * decimals}', 'en_US');
    return formatter.format(amount);
  }

  double get _totalDeductions {
    return _monthlyDeductions
        .where((item) => item['enabled'] as bool? ?? true)
        .fold(0.0, (acc, item) => acc + (item['amount'] as num).toDouble());
  }

  double get _netBankBalance => _bankAmount - _totalDeductions;

  double get _totalAvailableMoney => _netBankBalance;

  Future<void> _saveBudgetConfiguration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('Please login to save budget configuration');
        return;
      }

      final now = DateTime.now();
      final dailyStart = DateTime(now.year, now.month, now.day);
      final dailyEnd = dailyStart.add(const Duration(days: 1));

      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weeklyStart = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final weeklyEnd = weeklyStart.add(const Duration(days: 7));

      final monthlyStart = DateTime(now.year, now.month, 1);
      final monthlyEnd = DateTime(now.year, now.month + 1, 1);

      await _saveBudget(
        userId: user.uid,
        type: 'daily',
        limit: _dailyLimit,
        spent: _dailySpent,
        periodStart: dailyStart,
        periodEnd: dailyEnd,
      );

      await _saveBudget(
        userId: user.uid,
        type: 'weekly',
        limit: _weeklyLimit,
        spent: _weeklySpent,
        periodStart: weeklyStart,
        periodEnd: weeklyEnd,
      );

      await _saveBudget(
        userId: user.uid,
        type: 'monthly',
        limit: _monthlyLimit,
        spent: _monthlySpent,
        periodStart: monthlyStart,
        periodEnd: monthlyEnd,
      );

      _showSuccessSnackBar('Configuration saved successfully!');
    } catch (e) {
      _showErrorSnackBar('Error saving configuration: $e');
    }
  }

  Future<void> _saveBudget({
    required String userId,
    required String type,
    required double limit,
    required double spent,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final docId = '${userId}_$type';
    final docRef = FirebaseFirestore.instance.collection('budgets').doc(docId);

    final totalAvailable = _totalAvailableMoney;
    final remaining = totalAvailable - spent;
    const alertThreshold = 0.8;

    final budgetData = {
      'budgetId': docId,
      'userId': userId,
      'type': type,
      'limitAmount': limit,
      'currency': _currencySymbol,
      'totalAvailableAmount': totalAvailable,
      'amountSpent': spent,
      'remainingAmount': remaining,
      'periodStartDate': Timestamp.fromDate(periodStart),
      'periodEndDate': Timestamp.fromDate(periodEnd),
      'alertThreshold': alertThreshold,
      'payAmount': _payAmount,
      'bankAmount': _bankAmount,
      'cashAmount': _cashAmount,
      'monthlyDeductions': _monthlyDeductions,
      'totalDeductions': _totalDeductions,
      'deductionHistory': _deductionHistory,
      'lastActiveMonth': _currentMonthKey,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      await docRef.update(budgetData);
    } else {
      budgetData['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(budgetData);
    }
  }

  void _showMoneyInputModal(String title, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final controller = TextEditingController(
      text: type == 'pay'
          ? ''
          : type == 'bank'
          ? _formatCurrency(_bankAmount)
          : _formatCurrency(_cashAmount),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textLight,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: textLight, fontSize: 24),
          autofocus: true,
          decoration: InputDecoration(
            prefixText: _currencySymbol,
            prefixStyle: TextStyle(color: textGrey, fontSize: 24),
            hintText: '0.00',
            hintStyle: TextStyle(color: textGrey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? 0;
              setState(() {
                if (type == 'pay') {
                  _bankAmount += value;
                  _payAmount = 0;
                } else if (type == 'bank') {
                  _bankAmount = value;
                } else {
                  _cashAmount = value;
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeductionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          'Add Deduction',
          style: TextStyle(
            color: textLight,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: textLight, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Deduction Name',
                labelStyle: TextStyle(color: textGrey),
                hintText: 'e.g., Rent, Tithe, Internet',
                hintStyle: TextStyle(color: textGrey, fontSize: 14),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: textLight, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(color: textGrey),
                prefixText: _currencySymbol,
                prefixStyle: TextStyle(color: textGrey, fontSize: 18),
                hintText: '0.00',
                hintStyle: TextStyle(color: textGrey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text) ?? 0;

              if (name.isNotEmpty && amount > 0) {
                setState(() {
                  _monthlyDeductions.add({
                    'name': name,
                    'amount': amount,
                    'enabled': true,
                    'date': DateTime.now().toIso8601String(),
                  });
                });
                Navigator.pop(context);
              } else {
                _showErrorSnackBar('Please enter valid name and amount');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDeductionModal(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final deduction = _monthlyDeductions[index];
    final nameController = TextEditingController(text: deduction['name']);
    final amountController = TextEditingController(
      text: _formatCurrency(deduction['amount'].toDouble()),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          'Edit Deduction',
          style: TextStyle(
            color: textLight,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: textLight, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Deduction Name',
                labelStyle: TextStyle(color: textGrey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: textLight, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(color: textGrey),
                prefixText: _currencySymbol,
                prefixStyle: TextStyle(color: textGrey, fontSize: 18),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _monthlyDeductions.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: redError)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text) ?? 0;

              if (name.isNotEmpty && amount > 0) {
                setState(() {
                  _monthlyDeductions[index] = {
                    'name': name,
                    'amount': amount,
                    'enabled': deduction['enabled'] ?? true,
                    // preserve original date if it exists
                    'date': deduction['date'] ?? DateTime.now().toIso8601String(),
                  };
                });
                Navigator.pop(context);
              } else {
                _showErrorSnackBar('Please enter valid name and amount');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLimitEditModal(String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    double currentLimit = 0;
    double currentSpent = 0;

    if (type == 'daily') {
      currentLimit = _dailyLimit;
      currentSpent = _dailySpent;
    } else if (type == 'weekly') {
      currentLimit = _weeklyLimit;
      currentSpent = _weeklySpent;
    } else {
      currentLimit = _monthlyLimit;
      currentSpent = _monthlySpent;
    }

    final limitController = TextEditingController(
      text: _formatCurrency(currentLimit),
    );
    final spentController = TextEditingController(
      text: _formatCurrency(currentSpent),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          'Edit ${type.substring(0, 1).toUpperCase()}${type.substring(1)} Limit',
          style: TextStyle(
            color: textLight,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: limitController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: textLight, fontSize: 20),
              decoration: InputDecoration(
                labelText: 'Limit Amount',
                labelStyle: TextStyle(color: textGrey),
                prefixText: _currencySymbol,
                prefixStyle: TextStyle(color: textGrey, fontSize: 20),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: spentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: textLight, fontSize: 20),
              decoration: InputDecoration(
                labelText: 'Amount Spent',
                labelStyle: TextStyle(color: textGrey),
                prefixText: _currencySymbol,
                prefixStyle: TextStyle(color: textGrey, fontSize: 20),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final limit = double.tryParse(limitController.text) ?? 0;
              final spent = double.tryParse(spentController.text) ?? 0;

              setState(() {
                if (type == 'daily') {
                  _dailyLimit = limit;
                  _dailySpent = spent;
                } else if (type == 'weekly') {
                  _weeklyLimit = limit;
                  _weeklySpent = spent;
                } else {
                  _monthlyLimit = limit;
                  _monthlySpent = spent;
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textGrey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: primary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Deduction History',
                          style: TextStyle(
                            color: textLight,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: textGrey, size: 22),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  Divider(color: borderColor, height: 1),

                  // History list
                  Expanded(
                    child: _deductionHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  color: textGrey,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No history yet',
                                  style: TextStyle(
                                    color: textGrey,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Past months will appear here',
                                  style: TextStyle(
                                    color: textGrey.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _deductionHistory.length,
                            itemBuilder: (context, i) {
                              final entry = _deductionHistory[i];
                              final monthLabel =
                                  entry['monthLabel'] as String? ??
                                  entry['monthKey'] as String? ??
                                  'Unknown';
                              final deductions =
                                  (entry['deductions'] as List?)
                                      ?.map(
                                        (d) =>
                                            Map<String, dynamic>.from(d as Map),
                                      )
                                      .toList() ??
                                  [];
                              final total =
                                  (entry['totalDeductions'] as num?)
                                      ?.toDouble() ??
                                  0.0;

                              return _HistoryMonthTile(
                                monthLabel: monthLabel,
                                total: total,
                                deductions: deductions,
                                currencySymbol: _currencySymbol,
                                cardColor: cardColor,
                                cardSurfaceColor: cardSurfaceColor,
                                borderColor: borderColor,
                                textGrey: textGrey,
                                textLight: textLight,
                                primary: primary,
                                redError: redError,
                                formatCurrency: _formatCurrency,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: greenSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: redError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getBudgetStatus(double spent, double limit) {
    if (limit == 0) return 'not_set';
    final percentage = (spent / limit) * 100;
    if (percentage >= 100) return 'exceeded';
    if (percentage >= 80) return 'near_limit';
    return 'on_track';
  }

  Color _getProgressColor(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;

    switch (status) {
      case 'exceeded':
        return redError;
      case 'near_limit':
        return yellowWarning;
      case 'on_track':
        return primary;
      default:
        return textGrey;
    }
  }

  Widget _buildPredictiveSpendBanner() {
    if (_calendarEvents.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEvents = _calendarEvents.where((e) {
      final weekEnd = weekStart.add(const Duration(days: 7));
      return e.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(weekEnd) &&
          e.projectedCost > 0;
    }).toList();

    if (weekEvents.isEmpty) return const SizedBox.shrink();

    final totalProjected = weekEvents.fold<double>(
      0,
      (acc, e) => acc + e.projectedCost,
    );
    final primaryEvent = weekEvents.first;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFf59e0b).withValues(alpha: 0.12),
              const Color(0xFF8b5cf6).withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFf59e0b).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFf59e0b).withValues(alpha: 0.03),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Color(0xFFf59e0b), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'SMART CALENDAR PREDICTOR',
                  style: TextStyle(
                    color: Color(0xFFf59e0b),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalendarSyncScreen(),
                      ),
                    ).then((_) => _loadBudgetData());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf59e0b).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'MANAGE',
                      style: TextStyle(
                        color: Color(0xFFf59e0b),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your calendar predicts a scaling demand this week! "${primaryEvent.title}" is on ${DateFormat('EEEE').format(primaryEvent.date)}.',
              style: TextStyle(
                color: textLight,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your usual \$100.00 weekend limit is recommended to scale up to \$${(100.00 + totalProjected).toStringAsFixed(0)} to accommodate this. We advise trimming non-essential daily limits to prepare.',
              style: TextStyle(color: textGrey, fontSize: 12, height: 1.4),
            ),
          ],
        ),
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

    final dailyStatus = _getBudgetStatus(_dailySpent, _dailyLimit);
    final weeklyStatus = _getBudgetStatus(_weeklySpent, _weeklyLimit);
    final monthlyStatus = _getBudgetStatus(_monthlySpent, _monthlyLimit);

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
          'Budget Setup',
          style: TextStyle(
            color: textLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: textLight),
            tooltip: 'Deduction History',
            onPressed: _showHistoryBottomSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPredictiveSpendBanner(),
            const SizedBox(height: 20),

            // Total Available Money Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL AVAILABLE MONEY',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_currencySymbol${_formatCurrency(_totalAvailableMoney)}',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Icons.trending_up, color: greenSuccess, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '+2.5% from last month',
                          style: TextStyle(
                            color: greenSuccess,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Money Sources Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildMoneySourceCard(
                    icon: Icons.wallet,
                    label: 'PAY',
                    amount: _payAmount,
                    color: const Color(0xFF3b82f6),
                    onAdd: () =>
                        _showMoneyInputModal('Enter Pay Amount', 'pay'),
                  ),
                  const SizedBox(width: 12),
                  _buildMoneySourceCard(
                    icon: Icons.account_balance,
                    label: 'BANK',
                    amount: _netBankBalance,
                    color: const Color(0xFF3b82f6),
                    onAdd: () =>
                        _showMoneyInputModal('Enter Bank Balance', 'bank'),
                  ),
                  const SizedBox(width: 12),
                  _buildMoneySourceCard(
                    icon: Icons.payments,
                    label: 'CASH',
                    amount: _cashAmount,
                    color: const Color(0xFF3b82f6),
                    onAdd: () =>
                        _showMoneyInputModal('Enter Cash Amount', 'cash'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Monthly Deductions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Deductions',
                              style: TextStyle(
                                color: textLight,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentMonthLabel,
                              style: TextStyle(
                                color: primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Add Deduction Button
                  GestureDetector(
                    onTap: _showAddDeductionModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? primary : const Color(0xFF0066cc),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: isDark ? primary : const Color(0xFF0066cc),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add Deduction',
                            style: TextStyle(
                              color:
                                  isDark ? primary : const Color(0xFF0066cc),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Deductions List
                  if (_monthlyDeductions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Center(
                        child: Text(
                          'No deductions added yet',
                          style: TextStyle(color: textGrey, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ..._monthlyDeductions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final deduction = entry.value;
                      final name = deduction['name'] as String;
                      final amount = (deduction['amount'] as num).toDouble();
                      final enabled = deduction['enabled'] as bool? ?? true;
                      final dateStr = deduction['date'] as String?;

                      String? formattedDate;
                      if (dateStr != null) {
                        try {
                          final dt = DateTime.parse(dateStr);
                          formattedDate = DateFormat('MMM d, yyyy').format(dt);
                        } catch (_) {}
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardSurfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _monthlyDeductions[index]['enabled'] =
                                        !enabled;
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: enabled ? primary : borderDark,
                                      width: 2,
                                    ),
                                  ),
                                  child: enabled
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Name + date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: enabled ? textLight : textGrey,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        decoration: enabled
                                            ? null
                                            : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    if (formattedDate != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          color: textGrey.withValues(alpha: 0.7),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Amount
                              Text(
                                '$_currencySymbol${_formatCurrency(amount)}',
                                style: TextStyle(
                                  color: enabled ? textLight : textGrey,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Menu button
                              GestureDetector(
                                onTap: () => _showEditDeductionModal(index),
                                child: Icon(
                                  Icons.more_vert,
                                  color: textGrey,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Daily Limit
            _buildLimitSection(
              title: 'Daily Limit',
              status: dailyStatus,
              spent: _dailySpent,
              limit: _dailyLimit,
              color: _getProgressColor(dailyStatus),
              onEdit: () => _showLimitEditModal('daily'),
            ),

            const SizedBox(height: 24),

            // Weekly Limit
            _buildLimitSection(
              title: 'Weekly Limit',
              status: weeklyStatus,
              spent: _weeklySpent,
              limit: _weeklyLimit,
              color: _getProgressColor(weeklyStatus),
              onEdit: () => _showLimitEditModal('weekly'),
            ),

            const SizedBox(height: 24),

            // Monthly Limit
            _buildLimitSection(
              title: 'Monthly Limit',
              status: monthlyStatus,
              spent: _monthlySpent,
              limit: _monthlyLimit,
              color: _getProgressColor(monthlyStatus),
              onEdit: () => _showLimitEditModal('monthly'),
            ),
            const SizedBox(height: 40),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _saveBudgetConfiguration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Budget Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneySourceCard({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required VoidCallback onAdd,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(icon, color: color, size: 32),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: primary, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$_currencySymbol${_formatCurrency(amount, decimals: 0)}',
                style: TextStyle(
                  color: textLight,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
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
    );
  }

  Widget _buildLimitSection({
    required String title,
    required String status,
    required double spent,
    required double limit,
    required Color color,
    required VoidCallback onEdit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final remaining = limit - spent;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textLight,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent vs Limit',
                style: TextStyle(color: textGrey, fontSize: 14),
              ),
              Text(
                '$_currencySymbol${_formatCurrency(spent)} / $_currencySymbol${_formatCurrency(limit)}',
                style: TextStyle(
                  color: textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: cardSurfaceColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status == 'exceeded'
                    ? '-$_currencySymbol${_formatCurrency(-remaining)} Over Budget'
                    : '$_currencySymbol${_formatCurrency(remaining)} Remaining',
                style: TextStyle(
                  color: status == 'exceeded' ? redError : textGrey,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Row(
                  children: const [
                    Text(
                      'Edit Limit',
                      style: TextStyle(
                        color: primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.edit, color: primary, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;

    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'exceeded':
        bgColor = redError.withValues(alpha: 0.2);
        textColor = redError;
        label = 'Exceeded';
        icon = Icons.error;
        break;
      case 'near_limit':
        bgColor = yellowWarning.withValues(alpha: 0.2);
        textColor = yellowWarning;
        label = 'Near Limit';
        icon = Icons.warning;
        break;
      case 'on_track':
        bgColor = greenSuccess.withValues(alpha: 0.2);
        textColor = greenSuccess;
        label = 'On Track';
        icon = Icons.check_circle;
        break;
      default:
        bgColor = textGrey.withValues(alpha: 0.2);
        textColor = textGrey;
        label = 'Not Set';
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History month tile — collapsible row for a past month
// ---------------------------------------------------------------------------

class _HistoryMonthTile extends StatefulWidget {
  final String monthLabel;
  final double total;
  final List<Map<String, dynamic>> deductions;
  final String currencySymbol;
  final Color cardColor;
  final Color cardSurfaceColor;
  final Color borderColor;
  final Color textGrey;
  final Color textLight;
  final Color primary;
  final Color redError;
  final String Function(double, {int decimals}) formatCurrency;

  const _HistoryMonthTile({
    required this.monthLabel,
    required this.total,
    required this.deductions,
    required this.currencySymbol,
    required this.cardColor,
    required this.cardSurfaceColor,
    required this.borderColor,
    required this.textGrey,
    required this.textLight,
    required this.primary,
    required this.redError,
    required this.formatCurrency,
  });

  @override
  State<_HistoryMonthTile> createState() => _HistoryMonthTileState();
}

class _HistoryMonthTileState extends State<_HistoryMonthTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        children: [
          // Month header row
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: widget.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.monthLabel,
                          style: TextStyle(
                            color: widget.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.deductions.length} deduction${widget.deductions.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: widget.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.currencySymbol}${widget.formatCurrency(widget.total)}',
                    style: TextStyle(
                      color: widget.redError,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.textGrey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Deductions list (shown when expanded)
          if (_expanded) ...[
            Divider(color: widget.borderColor, height: 1),
            ...widget.deductions.map((d) {
              final name = d['name'] as String? ?? '';
              final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final enabled = d['enabled'] as bool? ?? true;
              final dateStr = d['date'] as String?;

              String? formattedDate;
              if (dateStr != null) {
                try {
                  final dt = DateTime.parse(dateStr);
                  formattedDate = DateFormat('MMM d, yyyy').format(dt);
                } catch (_) {}
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: enabled
                            ? widget.primary
                            : widget.textGrey.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: enabled
                                  ? widget.textLight
                                  : widget.textGrey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: enabled
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          if (formattedDate != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: widget.textGrey.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${widget.currencySymbol}${widget.formatCurrency(amount)}',
                      style: TextStyle(
                        color: enabled ? widget.textLight : widget.textGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
