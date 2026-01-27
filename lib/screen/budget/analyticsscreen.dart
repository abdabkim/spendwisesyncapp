import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  // App Colors - DARK MODE
  static const Color backgroundDark = Color(0xFF0f1115);
  static const Color cardDark = Color(0xFF16181d);
  static const Color cardSurface = Color(0xFF1e2128);
  static const Color borderDark = Color(0xFF272a33);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFd1d5db);

  // App Colors - LIGHT MODE
  static const Color backgroundLight = Color(0xFFf6f7f8);
  static const Color cardLight = Color(0xFFffffff);
  static const Color cardSurfaceLight = Color(0xFFf1f5f9);
  static const Color borderLight = Color(0xFFe2e8f0);
  static const Color textGreyLight = Color(0xFF64748b);
  static const Color textLightLight = Color(0xFF0f172a);

  // Shared colors (same in both themes)
  static const Color primary = Color(0xFF3b82f6);
  static const Color secondary = Color(0xFF8b5cf6);
  static const Color accentTeal = Color(0xFF14b8a6);
  static const Color accentOrange = Color(0xFFf97316);
  static const Color greenSuccess = Color(0xFF10b981);

  String _selectedPeriod = 'Monthly';
  bool _isLoading = true;
  String _currencySymbol = '\$';

  // Analytics data
  double _dailySpendingTotal = 0.0;
  double _weeklySpending = 0.0;
  double _monthlyVsAvg = 0.0;
  double _weeklyPercentage = 0.0;
  double _monthlyPercentage = 0.0;
  List<FlSpot> _trendData = [];

  // Category data
  Map<String, double> _categorySpending = {
    'Food': 0.0,
    'Shopping': 0.0,
    'Bills': 0.0,
    'Travel': 0.0,
  };

  // Payment method data
  double _cardSpending = 0.0;
  double _cashSpending = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadAnalyticsData();
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

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _dailySpendingTotal =
              prefs.getDouble('analytics_daily_spending') ?? 0.0;
          _weeklySpending = prefs.getDouble('analytics_weekly_spending') ?? 0.0;
          _monthlyVsAvg = prefs.getDouble('analytics_monthly_vs_avg') ?? 0.0;
          _weeklyPercentage =
              prefs.getDouble('analytics_weekly_percentage') ?? 0.0;
          _monthlyPercentage =
              prefs.getDouble('analytics_monthly_percentage') ?? 0.0;
          _currencySymbol =
              prefs.getString('analytics_currency_symbol') ?? '\$';
          _cardSpending = prefs.getDouble('analytics_card_spending') ?? 0.0;
          _cashSpending = prefs.getDouble('analytics_cash_spending') ?? 0.0;

          final foodSpending =
              prefs.getDouble('analytics_category_food') ?? 0.0;
          final shoppingSpending =
              prefs.getDouble('analytics_category_shopping') ?? 0.0;
          final billsSpending =
              prefs.getDouble('analytics_category_bills') ?? 0.0;
          final travelSpending =
              prefs.getDouble('analytics_category_travel') ?? 0.0;

          _categorySpending = {
            'Food': foodSpending,
            'Shopping': shoppingSpending,
            'Bills': billsSpending,
            'Travel': travelSpending,
          };
        });
      }
    } catch (e) {
      print('Error loading cached analytics data: $e');
    }
  }

  Future<void> _cacheAnalyticsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('analytics_daily_spending', _dailySpendingTotal);
      await prefs.setDouble('analytics_weekly_spending', _weeklySpending);
      await prefs.setDouble('analytics_monthly_vs_avg', _monthlyVsAvg);
      await prefs.setDouble('analytics_weekly_percentage', _weeklyPercentage);
      await prefs.setDouble('analytics_monthly_percentage', _monthlyPercentage);
      await prefs.setString('analytics_currency_symbol', _currencySymbol);
      await prefs.setDouble('analytics_card_spending', _cardSpending);
      await prefs.setDouble('analytics_cash_spending', _cashSpending);

      await prefs.setDouble(
        'analytics_category_food',
        _categorySpending['Food'] ?? 0.0,
      );
      await prefs.setDouble(
        'analytics_category_shopping',
        _categorySpending['Shopping'] ?? 0.0,
      );
      await prefs.setDouble(
        'analytics_category_bills',
        _categorySpending['Bills'] ?? 0.0,
      );
      await prefs.setDouble(
        'analytics_category_travel',
        _categorySpending['Travel'] ?? 0.0,
      );

      await prefs.setString(
        'analytics_last_update',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('Error caching analytics data: $e');
    }
  }

  Future<void> _loadAnalyticsData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = user.uid;

      // Load monthly budget data
      final monthlyDocId = '${userId}_monthly';
      final monthlyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(monthlyDocId)
          .get();

      if (monthlyDoc.exists) {
        final data = monthlyDoc.data()!;
        _currencySymbol = data['currency'] ?? '\$';
        final monthlySpent = (data['amountSpent'] ?? 0).toDouble();

        // Calculate monthly vs average (mock calculation)
        _monthlyVsAvg = monthlySpent * 0.15; // 15% above average
        _monthlyPercentage = 0.15;
      }

      // Load weekly budget data
      final weeklyDocId = '${userId}_weekly';
      final weeklyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(weeklyDocId)
          .get();

      if (weeklyDoc.exists) {
        final data = weeklyDoc.data()!;
        _weeklySpending = (data['amountSpent'] ?? 0).toDouble();
        _weeklyPercentage = 0.70; // 70% of last week
      }

      // Load daily budget data
      final dailyDocId = '${userId}_daily';
      final dailyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .doc(dailyDocId)
          .get();

      if (dailyDoc.exists) {
        final data = dailyDoc.data()!;
        _dailySpendingTotal = (data['amountSpent'] ?? 0).toDouble();
      }

      // Generate trend data (mock data for the chart)
      _trendData = _generateTrendData();

      // Load receipts for category analysis
      await _loadReceiptsData(userId);

      await _cacheAnalyticsData();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReceiptsData(String userId) async {
    try {
      // Get receipts from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final receiptsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
          )
          .get();

      Map<String, double> categoryTotals = {
        'Food': 0.0,
        'Shopping': 0.0,
        'Bills': 0.0,
        'Travel': 0.0,
      };

      double cardTotal = 0.0;
      double cashTotal = 0.0;

      for (var receiptDoc in receiptsSnapshot.docs) {
        // Get items from receipt
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('receipts')
            .doc(receiptDoc.id)
            .collection('receipt_items')
            .get();

        for (var item in itemsSnapshot.docs) {
          final itemData = item.data();
          final category = itemData['category'] ?? 'Other';
          final totalPrice = (itemData['totalPrice'] ?? 0).toDouble();

          // Map categories
          if (category.toLowerCase().contains('food') ||
              category.toLowerCase().contains('grocery') ||
              category.toLowerCase().contains('dining')) {
            categoryTotals['Food'] = (categoryTotals['Food'] ?? 0) + totalPrice;
          } else if (category.toLowerCase().contains('shopping') ||
              category.toLowerCase().contains('electronics')) {
            categoryTotals['Shopping'] =
                (categoryTotals['Shopping'] ?? 0) + totalPrice;
          } else if (category.toLowerCase().contains('bill') ||
              category.toLowerCase().contains('utilities')) {
            categoryTotals['Bills'] =
                (categoryTotals['Bills'] ?? 0) + totalPrice;
          } else if (category.toLowerCase().contains('travel') ||
              category.toLowerCase().contains('transport')) {
            categoryTotals['Travel'] =
                (categoryTotals['Travel'] ?? 0) + totalPrice;
          }

          // For demo: split between card and cash (80/20)
          cardTotal += totalPrice * 0.78;
          cashTotal += totalPrice * 0.22;
        }
      }

      setState(() {
        _categorySpending = categoryTotals;
        _cardSpending = cardTotal;
        _cashSpending = cashTotal;
      });
    } catch (e) {
      print('Error loading receipts data: $e');
    }
  }

  List<FlSpot> _generateTrendData() {
    // Generate sample trend data for the chart
    return [
      const FlSpot(0, 1800),
      const FlSpot(5, 2200),
      const FlSpot(10, 1900),
      const FlSpot(15, 2400),
      const FlSpot(20, 2100),
      const FlSpot(25, 2600),
      const FlSpot(30, 2840),
    ];
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '$_currencySymbol${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textLight),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Analytics & Stats',
            style: TextStyle(
              color: textLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.download, color: textGrey),
              onPressed: () {},
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
              children: [
                const SizedBox(height: 24),
                _buildPeriodSelector(
                  isDark,
                  cardColor,
                  borderColor,
                  textGrey,
                  textLight,
                ),
                const SizedBox(height: 24),
                _buildSpendingOverview(
                  isDark,
                  cardColor,
                  borderColor,
                  textGrey,
                  textLight,
                ),
                const SizedBox(height: 16),
                _buildTrendChart(isDark, cardColor, borderColor, textGrey),
                const SizedBox(height: 16),
                _buildCategoryBreakdown(
                  isDark,
                  cardColor,
                  borderColor,
                  textLight,
                ),
                const SizedBox(height: 16),
                _buildCashVsCard(
                  isDark,
                  cardColor,
                  borderColor,
                  textGrey,
                  textLight,
                ),
                const SizedBox(height: 24),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  _buildBottomNav(isDark, cardColor),
                  Positioned(
                    bottom: 15,
                    child: _buildCenterNavButton(isDark, backgroundColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textGrey,
    Color textLight,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: ['Weekly', 'Monthly', 'Yearly'].map((period) {
          final isSelected = period == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  period,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textGrey,
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpendingOverview(
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textGrey,
    Color textLight,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Daily Total',
            _formatCurrency(_dailySpendingTotal),
            Icons.today,
            greenSuccess,
            isDark,
            cardColor,
            borderColor,
            textGrey,
            textLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Week',
            _formatCurrency(_weeklySpending),
            Icons.calendar_today,
            accentTeal,
            isDark,
            cardColor,
            borderColor,
            textGrey,
            textLight,
            percentage: _weeklyPercentage,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textGrey,
    Color textLight, {
    double? percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              if (percentage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: percentage > 0
                        ? greenSuccess.withOpacity(0.2)
                        : accentOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${percentage > 0 ? '+' : ''}${(percentage * 100).toInt()}%',
                    style: TextStyle(
                      color: percentage > 0 ? greenSuccess : accentOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: textGrey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textLight,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textGrey,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending Trend',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: greenSuccess.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: greenSuccess, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+${(_monthlyPercentage * 100).toInt()}%',
                      style: const TextStyle(
                        color: greenSuccess,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_monthlyVsAvg),
            style: TextStyle(color: textGrey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: borderColor, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(color: textGrey, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 500,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${(value / 1000).toStringAsFixed(1)}k',
                          style: TextStyle(color: textGrey, fontSize: 11),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 30,
                minY: 1500,
                maxY: 3000,
                lineBarsData: [
                  LineChartBarData(
                    spots: _trendData,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [primary, accentTeal],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primary.withOpacity(0.3),
                          accentTeal.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textLight,
  ) {
    final total = _categorySpending.values.fold(0.0, (a, b) => a + b);

    return Container(
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
            'Category Breakdown',
            style: TextStyle(
              color: textLight,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildCategoryItem(
            'Food',
            _categorySpending['Food']!,
            total > 0 ? (_categorySpending['Food']! / total * 100).toInt() : 0,
            accentOrange,
            textLight,
          ),
          const SizedBox(height: 16),
          _buildCategoryItem(
            'Shopping',
            _categorySpending['Shopping']!,
            total > 0
                ? (_categorySpending['Shopping']! / total * 100).toInt()
                : 0,
            primary,
            textLight,
          ),
          const SizedBox(height: 16),
          _buildCategoryItem(
            'Bills',
            _categorySpending['Bills']!,
            total > 0 ? (_categorySpending['Bills']! / total * 100).toInt() : 0,
            secondary,
            textLight,
          ),
          const SizedBox(height: 16),
          _buildCategoryItem(
            'Travel',
            _categorySpending['Travel']!,
            total > 0
                ? (_categorySpending['Travel']! / total * 100).toInt()
                : 0,
            accentTeal,
            textLight,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    String label,
    double amount,
    int percentage,
    Color color,
    Color textLight,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: textLight, fontSize: 15)),
              ],
            ),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCashVsCard(
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textGrey,
    Color textLight,
  ) {
    final total = _cardSpending + _cashSpending;
    final cardPercentage = total > 0 ? (_cardSpending / total) : 0.78;
    final cashPercentage = total > 0 ? (_cashSpending / total) : 0.22;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      color: primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Card',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Cash',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: textGrey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.attach_money, color: textGrey, size: 20),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    flex: (cardPercentage * 100).toInt(),
                    child: Container(
                      color: primary,
                      alignment: Alignment.center,
                      child: Text(
                        '${(cardPercentage * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: (cashPercentage * 100).toInt(),
                    child: Container(
                      color: borderColor,
                      alignment: Alignment.center,
                      child: Text(
                        '${(cashPercentage * 100).toInt()}%',
                        style: TextStyle(
                          color: textGrey,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIGITAL PREFERRED',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${_formatCurrency(_cardSpending)} VS ${_formatCurrency(_cashSpending)}',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark, Color cardColor) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_outlined, 0, isDark),
          _buildNavItem(Icons.bar_chart_outlined, 1, isDark),
          const SizedBox(width: 60), // Space for center button
          _buildNavItem(Icons.person, 3, isDark),
          _buildNavItem(Icons.settings_outlined, 4, isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, bool isDark) {
    final isSelected = index == 1; // Analytics page is index 1
    final textGrey = isDark ? textGreyDark : textGreyLight;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          // Navigate back to home
          Navigator.pushNamed(context, '/home');
        } else if (index != 1) {
          // Navigate to other page
          Navigator.pushNamed(
            context,
            '/${index == 0
                ? 'home'
                : index == 1
                ? 'analytics'
                : index == 2
                ? 'receipts'
                : index == 3
                ? 'profile'
                : index == 4
                ? 'settings'
                : 'home'}',
          );
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isSelected ? primary : textGrey, size: 24),
      ),
    );
  }

  Widget _buildCenterNavButton(bool isDark, Color backgroundColor) {
    return Container(
      width: 70,
      height: 120,
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary,
        border: Border.all(color: backgroundColor, width: 6),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
        onPressed: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/receipts');
        },
      ),
    );
  }
}
