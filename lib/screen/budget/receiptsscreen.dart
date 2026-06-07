import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwisesyncapp/screen/budget/addreceiptscreen.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({Key? key}) : super(key: key);

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  // App Colors - DARK MODE
  static const Color backgroundDark = Color(0xFF0f1419);
  static const Color cardDark = Color(0xFF1a1f26);
  static const Color cardSurface = Color(0xFF232930);
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

  String _selectedPeriod = 'Week'; // Day, Week, Month
  String _selectedSort = 'Date';
  String _selectedStore = 'Store';
  String _selectedCategory = 'Category';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    // Theme is controlled by main.dart, this just loads the preference
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '\$${formatter.format(amount)}';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'coffee & snacks':
      case 'dining out':
        return const Color(0xFF92400e);
      case 'groceries':
        return const Color(0xFF1e3a8a);
      case 'transport':
        return const Color(0xFF581c87);
      case 'electronics':
        return const Color(0xFF065f46);
      case 'health':
        return const Color(0xFF854d0e);
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'coffee & snacks':
        return Icons.local_cafe;
      case 'dining out':
        return Icons.restaurant;
      case 'groceries':
        return Icons.shopping_cart;
      case 'transport':
        return Icons.local_gas_station;
      case 'electronics':
        return Icons.shopping_bag;
      case 'health':
        return Icons.medical_services;
      default:
        return Icons.receipt;
    }
  }

  Widget _buildPeriodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Row(
      children: [
        _buildPeriodButton('Day'),
        const SizedBox(width: 8),
        _buildPeriodButton('Week'),
        const SizedBox(width: 8),
        _buildPeriodButton('Month'),
      ],
    );
  }

  Widget _buildPeriodButton(String period) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? primary : cardSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary : borderColor,
              width: isSelected ? 0 : 1,
            ),
          ),
          child: Center(
            child: Text(
              period,
              style: TextStyle(
                color: isSelected ? Colors.black : textGrey,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final isDefault = value == label;
    return GestureDetector(
      onTap: () {
        // TODO: Implement filter dropdown
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: cardSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDefault ? label : value,
              style: TextStyle(
                color: isDefault ? textGrey : primary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDefault ? textGrey : primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSpentCard(double totalSpent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL SPENT THIS ${_selectedPeriod.toUpperCase()}',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(totalSpent),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.trending_up, color: Colors.black87, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard({
    required String merchantName,
    required String category,
    required String time,
    required double amount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 28),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchantName,
                    style: TextStyle(
                      color: textLight,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$category • $time',
                    style: TextStyle(color: textGrey, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Amount and Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    color: textLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: textGrey, size: 20),
              ],
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
          'Receipts',
          style: TextStyle(
            color: textLight,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.camera_alt, color: textLight),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const AddReceiptPage(),
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: textGrey, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textLight, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search receipts...',
                        hintStyle: TextStyle(color: textGrey, fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Period Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildPeriodSelector(),
          ),

          const SizedBox(height: 16),

          // Filter Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterButton('Sort: Date', _selectedSort),
                const SizedBox(width: 12),
                _buildFilterButton('Store', _selectedStore),
                const SizedBox(width: 12),
                _buildFilterButton('Category', _selectedCategory),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Spent Card
                    FutureBuilder<double>(
                      future: _calculateTotalSpent(),
                      builder: (context, snapshot) {
                        final totalSpent = snapshot.data ?? 0.0;
                        return _buildTotalSpentCard(totalSpent);
                      },
                    ),

                    const SizedBox(height: 32),

                    // Receipts List
                    StreamBuilder<QuerySnapshot>(
                      stream: _getReceiptsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(color: primary),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        final receipts = snapshot.data!.docs;

                        // Group receipts by date
                        final groupedReceipts = _groupReceiptsByDate(receipts);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: groupedReceipts.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${entry.value.length} Receipt${entry.value.length > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        color: textGrey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...entry.value.map((doc) {
                                  return FutureBuilder<Map<String, dynamic>>(
                                    future: _getReceiptDetails(doc.id),
                                    builder: (context, detailSnapshot) {
                                      if (!detailSnapshot.hasData ||
                                          detailSnapshot.data!.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      final details = detailSnapshot.data!;

                                      return _buildReceiptCard(
                                        merchantName:
                                            details['merchantName'] ??
                                            'Unknown',
                                        category:
                                            details['category'] ?? 'Other',
                                        time: _formatTime(details['timestamp']),
                                        amount: details['totalAmount'] ?? 0.0,
                                        onTap: () {
                                          // TODO: Navigate to receipt details page
                                        },
                                      );
                                    },
                                  );
                                }).toList(),
                                const SizedBox(height: 24),
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),

                    SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: textGrey.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No receipts yet',
              style: TextStyle(
                color: textLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the camera icon to add your first receipt',
              style: TextStyle(color: textGrey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getReceiptsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // Calculate date range based on selected period
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    // Query receipts collection filtered by userId and date
    var query = FirebaseFirestore.instance
        .collection('receipts')
        .where('userId', isEqualTo: user.uid)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .orderBy('timestamp', descending: true);

    return query.snapshots();
  }

  Future<Map<String, dynamic>> _getReceiptDetails(String receiptId) async {
    try {
      // Get the receipt document
      final receiptDoc = await FirebaseFirestore.instance
          .collection('receipts')
          .doc(receiptId)
          .get();

      if (!receiptDoc.exists) {
        return {};
      }

      final receiptData = receiptDoc.data() as Map<String, dynamic>;

      // Get all items in the receipt_items subcollection
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .doc(receiptId)
          .collection('receipt_items')
          .get();

      // Calculate total from items and determine main category
      double totalAmount = 0.0;
      String mainCategory = 'Other';

      if (itemsSnapshot.docs.isNotEmpty) {
        // Calculate total from all items
        for (var item in itemsSnapshot.docs) {
          final itemData = item.data();
          totalAmount += (itemData['totalPrice'] ?? 0).toDouble();

          // Use the first item's category as the main category
          if (mainCategory == 'Other' && itemData['category'] != null) {
            mainCategory = itemData['category'];
          }
        }
      }

      return {
        'merchantName': receiptData['merchantName'] ?? 'Unknown Store',
        'category': mainCategory,
        'timestamp': receiptData['timestamp'],
        'totalAmount': totalAmount,
        'itemCount': itemsSnapshot.docs.length,
      };
    } catch (e) {
      print('Error getting receipt details: $e');
      return {};
    }
  }

  Map<String, List<DocumentSnapshot>> _groupReceiptsByDate(
    List<DocumentSnapshot> receipts,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var receipt in receipts) {
      final data = receipt.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final receiptDate = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
      );

      String dateLabel;
      if (receiptDate == today) {
        dateLabel = 'Today';
      } else if (receiptDate == yesterday) {
        dateLabel = 'Yesterday';
      } else {
        dateLabel = DateFormat('MMMM d, yyyy').format(receiptDate);
      }

      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
      }
      grouped[dateLabel]!.add(receipt);
    }

    return grouped;
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final DateTime dateTime = (timestamp as Timestamp).toDate();
    return DateFormat('h:mm a').format(dateTime);
  }

  Future<double> _calculateTotalSpent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    try {
      // Get all receipts for the user in the selected period
      final receiptsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .where('userId', isEqualTo: user.uid)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .get();

      double total = 0.0;

      // For each receipt, get all items from receipt_items subcollection
      for (var receiptDoc in receiptsSnapshot.docs) {
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('receipts')
            .doc(receiptDoc.id)
            .collection('receipt_items')
            .get();

        // Sum up all item totalPrices
        for (var item in itemsSnapshot.docs) {
          final itemData = item.data();
          total += (itemData['totalPrice'] ?? 0).toDouble();
        }
      }

      return total;
    } catch (e) {
      print('Error calculating total spent: $e');
      return 0.0;
    }
  }
}
