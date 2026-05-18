import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwisesyncapp/screen/budget/analyticsscreen.dart';
import 'package:spendwisesyncapp/screen/budget/expensescreen.dart';
import 'package:spendwisesyncapp/screen/budget/receiptsscreen.dart';
import 'dart:math' as math;
import 'package:spendwisesyncapp/screen/calculator/shoppingcalculator.dart';
import 'package:spendwisesyncapp/screen/profile/profilescreen.dart';
import 'package:spendwisesyncapp/screen/settings/settingsscreen.dart';
import 'package:spendwisesyncapp/tododashboard/todo_dashboard.dart';
import 'package:spendwisesyncapp/services/notification_service.dart';
import 'package:spendwisesyncapp/services/permission_service.dart';
import 'package:spendwisesyncapp/screen/advisor/financial_advisor_screen.dart';
import 'package:spendwisesyncapp/screen/budget/calendar_sync_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _pulseController;

  // Caching and Stream Subscriptions
  List<Map<String, dynamic>> _cachedReceipts = [];
  List<Map<String, dynamic>> _cachedTodos = [];
  bool _receiptsLoading = true;
  bool _todosLoading = true;
  StreamSubscription<QuerySnapshot>? _receiptsSubscription;
  StreamSubscription<QuerySnapshot>? _todosSubscription;

  // User data
  String _userName = 'Loading...';
  String _userEmail = '';
  String? _userPhotoUrl;
  bool _isLoading = true;

  // Budget data from Firestore
  double _dailySpent = 0;
  double _dailyLimit = 0;
  String _currencySymbol = '\$';
  bool _budgetLoading = true;

  // Notification service
  final NotificationService _notificationService = NotificationService();

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

  // Shared colors
  static const Color primary = Color(0xFF3b82f6);
  static const Color secondary = Color(0xFF8b5cf6);
  static const Color accentPink = Color(0xFFec4899);
  static const Color accentTeal = Color(0xFF14b8a6);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadCachedData(); // Load cached data first for instant display
    _loadUserData();
    _requestNotificationPermissions();
    _loadBudgetData();

    // Request necessary core permissions asynchronously
    PermissionService().requestAllPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  // Load cached data from SharedPreferences for instant display
  Future<void> _loadCachedData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      List<Map<String, dynamic>> cachedReceiptsList = [];
      List<Map<String, dynamic>> cachedTodosList = [];
      bool receiptsLoaded = false;
      bool todosLoaded = false;

      final receiptsJson = prefs.getString('cachedReceipts');
      if (receiptsJson != null) {
        cachedReceiptsList = List<Map<String, dynamic>>.from(json.decode(receiptsJson));
        receiptsLoaded = true;
      }

      final todosJson = prefs.getString('cachedTodos');
      if (todosJson != null) {
        cachedTodosList = List<Map<String, dynamic>>.from(json.decode(todosJson));
        todosLoaded = true;
      }

      setState(() {
        _userName = prefs.getString('userName') ?? 'Loading...';
        _userEmail = prefs.getString('userEmail') ?? '';
        _userPhotoUrl = prefs.getString('userPhotoUrl');
        _dailySpent = prefs.getDouble('dailySpent') ?? 0;
        _dailyLimit = prefs.getDouble('dailyLimit') ?? 0;
        _currencySymbol = prefs.getString('currencySymbol') ?? '\$';
        _cachedReceipts = cachedReceiptsList;
        _cachedTodos = cachedTodosList;
        _isLoading = false;
        _budgetLoading = false;
        if (receiptsLoaded) _receiptsLoading = false;
        if (todosLoaded) _todosLoading = false;
      });
    } catch (e) {
      // If loading cached data fails, continue with normal loading
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Initialize background streams and load cache immediately
        _initStreams(user.uid);

        String userName = user.displayName ?? 'User';
        String userEmail = user.email ?? '';
        String? userPhotoUrl = user.photoURL;

        // Try to fetch profile from Firestore, but catch any errors so it doesn't block the app/streams
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            userName = userDoc.data()?['fullName'] ?? user.displayName ?? 'User';
            userEmail = userDoc.data()?['email'] ?? user.email ?? '';
            userPhotoUrl = userDoc.data()?['photoURL'] ?? user.photoURL;
          }
        } catch (e) {
          print("Error fetching user profile from Firestore: $e");
        }

        // Save to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', userName);
        await prefs.setString('userEmail', userEmail);
        if (userPhotoUrl != null) {
          await prefs.setString('userPhotoUrl', userPhotoUrl);
        } else {
          await prefs.remove('userPhotoUrl');
        }

        setState(() {
          _userName = userName;
          _userEmail = userEmail;
          _userPhotoUrl = userPhotoUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _userName = 'User';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBudgetData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _budgetLoading = false);
        return;
      }

      // Load daily budget from Firestore
      final dailyDoc = await FirebaseFirestore.instance
          .collection('budgets')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'daily')
          .limit(1)
          .get();

      if (dailyDoc.docs.isNotEmpty) {
        final data = dailyDoc.docs.first.data();
        final dailySpent = (data['amountSpent'] ?? 0).toDouble();
        final dailyLimit = (data['limitAmount'] ?? 0).toDouble();
        final currencySymbol = data['currency'] ?? '\$';

        // Save to SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('dailySpent', dailySpent);
        await prefs.setDouble('dailyLimit', dailyLimit);
        await prefs.setString('currencySymbol', currencySymbol);

        setState(() {
          _dailySpent = dailySpent;
          _dailyLimit = dailyLimit;
          _currencySymbol = currencySymbol;
          _budgetLoading = false;
        });
      } else {
        setState(() => _budgetLoading = false);
      }
    } catch (e) {
      setState(() => _budgetLoading = false);
    }
  }

  void _initStreams(String userId) {
    _receiptsSubscription?.cancel();
    _todosSubscription?.cancel();

    // 1. Receipts Stream subscription
    final receiptsQuery = FirebaseFirestore.instance
        .collection('receipts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(5);

    _receiptsSubscription = receiptsQuery.snapshots().listen((snapshot) async {
      final List<Map<String, dynamic>> receiptsList = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final activityData = await _getReceiptActivityData(doc.id, data);
        receiptsList.add({
          'id': doc.id,
          'merchantName': activityData['merchantName'] ?? 'Store',
          'totalAmount': activityData['totalAmount'] ?? 0.0,
          'imageUrl': activityData['imageUrl'],
          'isToday': activityData['isToday'] ?? false,
        });
      }

      if (mounted) {
        setState(() {
          _cachedReceipts = receiptsList;
          _receiptsLoading = false;
        });
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedReceipts', json.encode(receiptsList));
      } catch (e) {
        print('Error saving cached receipts: $e');
      }
    }, onError: (error) {
      print('Error in receipts stream: $error');
      if (mounted) {
        setState(() => _receiptsLoading = false);
      }
    });

    // 2. Todos Stream subscription
    final todosQuery = FirebaseFirestore.instance
        .collection('todos')
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .orderBy('dueDate')
        .limit(3);

    _todosSubscription = todosQuery.snapshots().listen((snapshot) {
      final List<Map<String, dynamic>> todosList = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dueDate = data['dueDate'] as Timestamp?;
        todosList.add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Task',
          'category': data['category'] ?? 'Personal',
          'priority': data['priority'] ?? 'Medium',
          'dueDateMillis': dueDate?.millisecondsSinceEpoch,
          'isCompleted': data['isCompleted'] ?? false,
        });
      }

      if (mounted) {
        setState(() {
          _cachedTodos = todosList;
          _todosLoading = false;
        });
      }

      try {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('cachedTodos', json.encode(todosList));
        });
      } catch (e) {
        print('Error saving cached todos: $e');
      }
    }, onError: (error) {
      print('Error in todos stream: $error');
      if (mounted) {
        setState(() => _todosLoading = false);
      }
    });
  }

  Future<void> _requestNotificationPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Request notification permissions
    final hasPermission = await _notificationService.requestPermissions();

    if (hasPermission) {
      // Schedule notifications for upcoming todos
      await _notificationService.scheduleTodoNotifications(user.uid);
    } else {
      // Show dialog to explain why notifications are important
      if (mounted) {
        _showNotificationPermissionDialog();
      }
    }
  }

  void _showNotificationPermissionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Enable Notifications',
              style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Get notified about your upcoming tasks and never miss an important deadline. You can enable notifications in your device settings.',
          style: TextStyle(color: textGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later', style: TextStyle(color: textGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _notificationService.requestPermissions();
            },
            style: TextButton.styleFrom(
              backgroundColor: primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Enable',
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _receiptsSubscription?.cancel();
    _todosSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _showNotificationCenter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: borderColor, height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('todos')
                    .where(
                      'userId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                    )
                    .where('isCompleted', isEqualTo: false)
                    .orderBy('dueDate')
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primary),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: textGrey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No upcoming notifications',
                            style: TextStyle(color: textGrey, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Task';
                      final dueDate = (data['dueDate'] as Timestamp).toDate();
                      final priority = data['priority'] ?? 'None';

                      final now = DateTime.now();
                      final difference = dueDate.difference(now);
                      final isOverdue = difference.isNegative;
                      final isDueToday = difference.inDays == 0 && !isOverdue;

                      String timeText;
                      Color timeColor;

                      if (isOverdue) {
                        timeText = 'Overdue';
                        timeColor = accentPink;
                      } else if (isDueToday) {
                        timeText = 'Due today';
                        timeColor = primary;
                      } else if (difference.inDays < 7) {
                        timeText =
                            'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
                        timeColor = textGrey;
                      } else {
                        timeText =
                            '${dueDate.month}/${dueDate.day}/${dueDate.year}';
                        timeColor = textGrey;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardSurfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_active,
                                color: primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: textLight,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: timeColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeText,
                                        style: TextStyle(
                                          color: timeColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (priority != 'None') ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(
                                              priority,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            priority,
                                            style: TextStyle(
                                              color: _getPriorityColor(
                                                priority,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return accentPink;
      case 'Medium':
        return const Color(0xFFf59e0b);
      case 'Low':
        return accentTeal;
      default:
        return textGreyDark;
    }
  }

  void _showComingSoon(String feature) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          '🚀 Coming Soon',
          style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$feature feature is under development. Stay tuned!',
          style: TextStyle(color: textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            _buildHomePage(),
            // Floating Bottom Navigation Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildBottomNav(cardColor),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: _buildCenterNavButton(backgroundColor),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return AnalyticsPage();
  }

  Widget _buildReceiptsPage(String title, IconData icon) {
    return ReceiptsPage();
  }

  Widget _buildProfilePage(String title, IconData icon) {
    return ProfilePage();
  }

  Widget _buildSettingsPage(String title, IconData icon) {
    return SettingsPage();
  }

  Widget _buildHomePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 130),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildDailySpendCard(),
                  const SizedBox(height: 32),
                  _buildQuickActions(),
                  const SizedBox(height: 32),
                  _buildRecentActivity(),
                  const SizedBox(height: 32),
                  _buildUpcomingTasks(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: _buildHeader(),
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'GOOD MORNING';
    } else if (hour < 17) {
      return 'GOOD AFTERNOON';
    } else {
      return 'GOOD EVENING';
    }
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: BoxDecoration(color: backgroundColor.withOpacity(0.8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Profile Picture
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2),
                    gradient: const LinearGradient(colors: [primary, secondary]),
                  ),
                  child: _userPhotoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _userPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              );
                            },
                          ),
                        )
                      : Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        textScaler: TextScaler.noScaling,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoading ? 'Loading...' : _userName.trim().split(' ').first,
                        style: TextStyle(
                          color: textLight,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right side buttons
          Row(
            children: [
              // Notification Button
              GestureDetector(
                onTap: _showNotificationCenter,
                child: Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: textLight,
                        size: 24,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FadeTransition(
                        opacity: _pulseController,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            // Changed from BoxShadow to BoxDecoration
                            color: accentPink,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentPink.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // AI Advisor Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FinancialAdvisorScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardSurfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00d4ff).withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00d4ff).withOpacity(0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Color(0xFF00d4ff),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Logout Button
              GestureDetector(
                onTap: _handleLogout,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          'Logout',
          style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Logout',
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    // If user confirmed logout
    if (shouldLogout == true && mounted) {
      try {
        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Navigate to login page and clear navigation stack
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        // Show error if logout fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: ${e.toString()}'),
              backgroundColor: accentPink,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Widget _buildDailySpendCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get available width
        final availableWidth = constraints.maxWidth;

        // Calculate responsive sizing
        final isSmallScreen = availableWidth < 360;
        final isMediumScreen = availableWidth >= 360 && availableWidth < 400;

        // Adjust font sizes based on screen width
        final amountFontSize = isSmallScreen
            ? 36.0
            : (isMediumScreen ? 42.0 : 48.0);
        final currencyFontSize = isSmallScreen
            ? 20.0
            : (isMediumScreen ? 22.0 : 24.0);
        final circleSize = isSmallScreen
            ? 100.0
            : (isMediumScreen ? 114.0 : 128.0);

        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Spend',
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _currencySymbol,
                            style: TextStyle(
                              color: textGrey,
                              fontSize: currencyFontSize,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            _dailySpent.toStringAsFixed(2),
                            style: TextStyle(
                              color: textLight,
                              fontSize: amountFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.trending_down, color: primary, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'UNDER BUDGET',
                            style: TextStyle(
                              color: primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildCircularProgress(circleSize),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircularProgress(double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    final remaining = _dailyLimit - _dailySpent;
    final progress = _dailyLimit > 0
        ? (_dailySpent / _dailyLimit).clamp(0.0, 1.0)
        : 0.00;

    // Adjust inner circle and font sizes based on outer circle size
    final innerCircleSize = size * 0.75;
    final leftFontSize = size * 0.07;
    final amountFontSize = size * 0.14;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: CircularProgressPainter(progress: progress),
          ),
          Center(
            child: Container(
              width: innerCircleSize,
              height: innerCircleSize,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'LEFT',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: leftFontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$_currencySymbol${remaining.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: textLight,
                          fontSize: amountFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
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

  Widget _buildQuickActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;

    final backgroundColor = isDark ? backgroundDark : backgroundLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.receipt_long_outlined,
          label: 'Scan',
          color: primary,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ReceiptsPage(),
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
        _buildActionButton(
          icon: Icons.add,
          label: 'Expense',
          color: accentTeal,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ExpenseScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return child;
                    },
                transitionDuration: const Duration(milliseconds: 0),
                barrierColor: backgroundColor,
              ),
            ).then((_) => _loadBudgetData());
          },
        ),
        _buildActionButton(
          icon: Icons.edit_note_outlined,
          label: 'Todo',
          color: accentPink,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const TodoDashboard(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return child;
                    },
                transitionDuration: const Duration(milliseconds: 0),
                barrierColor: backgroundColor,
              ),
            ).then((_) {
              // Reschedule notifications when returning from todo dashboard
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                _notificationService.scheduleTodoNotifications(user.uid);
              }
            });
          },
        ),
        // Added Calculator Button
        _buildActionButton(
          icon: Icons.calculate_outlined,
          label: 'Calc',
          color: secondary,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ShoppingCalculator(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return child;
                    },
                transitionDuration: const Duration(milliseconds: 0),
                barrierColor: backgroundColor,
              ),
            );
          },
        ),
        // Added Calendar Sync Predictor Button
        _buildActionButton(
          icon: Icons.calendar_month_outlined,
          label: 'Calendar',
          color: accentPink,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const CalendarSyncScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return child;
                    },
                transitionDuration: const Duration(milliseconds: 0),
                barrierColor: backgroundColor,
              ),
            ).then((_) => _loadBudgetData());
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19.2),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cardSurfaceColor,
              borderRadius: BorderRadius.circular(19.2),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFef4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showComingSoon('View History'),
                child: Text(
                  'VIEW HISTORY',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 240,
          child: _receiptsLoading && _cachedReceipts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: primary),
                )
              : (_cachedReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 48,
                            color: textGrey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No recent activity',
                            style: TextStyle(color: textGrey, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cachedReceipts.length,
                      itemBuilder: (context, index) {
                        final receipt = _cachedReceipts[index];
                        final totalAmount = (receipt['totalAmount'] ?? 0.0) as double;

                        return _buildActivityCard(
                          imageUrl: receipt['imageUrl'],
                          amount: '$_currencySymbol${totalAmount.toStringAsFixed(2)}',
                          merchant: receipt['merchantName'] ?? 'Store',
                          showBadge: receipt['isToday'] ?? false,
                        );
                      },
                    )),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getReceiptActivityData(
    String receiptId,
    Map<String, dynamic> receiptData,
  ) async {
    try {
      // Get all items in the receipt_items subcollection
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('receipts')
          .doc(receiptId)
          .collection('receipt_items')
          .get();

      double totalAmount = 0.0;
      String? firstImageUrl;

      if (itemsSnapshot.docs.isNotEmpty) {
        // Calculate total from all items
        for (var item in itemsSnapshot.docs) {
          final itemData = item.data();
          totalAmount += (itemData['totalPrice'] ?? 0).toDouble();

          // Get the first item's image if available
          if (firstImageUrl == null && itemData['imageUrl'] != null) {
            firstImageUrl = itemData['imageUrl'];
          }
        }
      }

      // Check if receipt is from today
      final timestamp = receiptData['timestamp'] as Timestamp?;
      bool isToday = false;
      if (timestamp != null) {
        final receiptDate = timestamp.toDate();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final receiptDay = DateTime(
          receiptDate.year,
          receiptDate.month,
          receiptDate.day,
        );
        isToday = receiptDay == today;
      }

      return {
        'merchantName': receiptData['merchantName'] ?? 'Store',
        'totalAmount': totalAmount,
        'imageUrl': firstImageUrl,
        'isToday': isToday,
      };
    } catch (e) {
      print('Error getting receipt activity data: $e');
      return {
        'merchantName': 'Store',
        'totalAmount': 0.0,
        'imageUrl': null,
        'isToday': false,
      };
    }
  }

  Widget _buildActivityCard({
    required String? imageUrl,
    required String amount,
    required String merchant,
    bool showBadge = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? borderDark : borderLight;
    final textLight = isDark ? textLightDark : textLightLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;

    return Container(
      width: 144,
      margin: const EdgeInsets.only(right: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or color
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: cardSurfaceColor,
                      child: Icon(
                        Icons.receipt,
                        size: 48,
                        color: primary.withOpacity(0.3),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: cardSurfaceColor,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  color: cardSurfaceColor,
                  child: Icon(
                    Icons.receipt,
                    size: 48,
                    color: primary.withOpacity(0.3),
                  ),
                ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
              // Badge
              if (showBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              // Content
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        color: textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      merchant,
                      style: TextStyle(
                        color: textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingTasks() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Tasks',
                style: TextStyle(
                  color: textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const TodoDashboard(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return child;
                          },
                      transitionDuration: const Duration(milliseconds: 0),
                      barrierColor: backgroundColor,
                    ),
                  ).then((_) {
                    // Reschedule notifications when returning from todo dashboard
                    _notificationService.scheduleTodoNotifications(user.uid);
                  });
                },
                child: Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_todosLoading && _cachedTodos.isEmpty)
          const Center(
            child: CircularProgressIndicator(color: primary),
          )
        else if (_cachedTodos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: textGrey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No upcoming tasks',
                    style: TextStyle(
                      color: textGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Todo" to add a new task',
                    style: TextStyle(
                      color: textGrey.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _cachedTodos.map((todo) {
              final title = todo['title'] ?? 'Untitled Task';
              final priority = todo['priority'] ?? 'Medium';
              final isCompleted = todo['isCompleted'] ?? false;
              final todoId = todo['id'];

              // Format due date from millis
              String dueDateText = 'No Date';
              bool showUrgent = false;

              final dueDateMillis = todo['dueDateMillis'] as int?;
              if (dueDateMillis != null) {
                final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMillis);
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final tomorrow = today.add(const Duration(days: 1));
                final taskDate = DateTime(
                  dueDate.year,
                  dueDate.month,
                  dueDate.day,
                );

                if (taskDate == today) {
                  dueDateText = 'Due Today';
                  showUrgent = true;
                } else if (taskDate == tomorrow) {
                  dueDateText = 'Tomorrow';
                } else if (taskDate.isBefore(today)) {
                  dueDateText = 'Overdue';
                  showUrgent = true;
                } else if (taskDate.difference(today).inDays <= 7) {
                  dueDateText = 'In ${taskDate.difference(today).inDays} days';
                } else {
                  dueDateText =
                      '${dueDate.month}/${dueDate.day}/${dueDate.year}';
                }
              }

              // Determine gradient colors based on priority
              List<Color> gradientColors;
              switch (priority) {
                case 'High':
                  gradientColors = [accentPink, const Color(0xFFbe185d)];
                  break;
                case 'Medium':
                  gradientColors = [
                    const Color(0xFFf59e0b),
                    const Color(0xFFd97706),
                  ];
                  break;
                case 'Low':
                  gradientColors = [accentTeal, const Color(0xFF0d9488)];
                  break;
                default:
                  gradientColors = [primary, const Color(0xFF2563eb)];
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTaskItem(
                  title: title,
                  subtitle: dueDateText,
                  gradientColors: gradientColors,
                  showUrgent: showUrgent,
                  isCompleted: isCompleted,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder:
                            (context, animation, secondaryAnimation) =>
                                const TodoDashboard(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return child;
                        },
                        transitionDuration: const Duration(milliseconds: 0),
                        barrierColor: backgroundColor,
                      ),
                    ).then((_) {
                      // Reschedule notifications when returning
                      _notificationService.scheduleTodoNotifications(
                        user.uid,
                      );
                    });
                  },
                  onCheckboxChanged: (bool? value) async {
                    if (value != null && todoId != null) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('todos')
                            .doc(todoId)
                            .update({'isCompleted': value});

                        _notificationService.scheduleTodoNotifications(
                          user.uid,
                        );

                        if (value && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 12),
                                  Text('Task completed!'),
                                ],
                              ),
                              backgroundColor: accentTeal,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating task: $e'),
                              backgroundColor: accentPink,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTaskItem({
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    bool showUrgent = false,
    bool isCompleted = false,
    required VoidCallback onTap,
    required ValueChanged<bool?> onCheckboxChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors.map((c) => c.withOpacity(0.2)).toList(),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onCheckboxChanged(!isCompleted),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isCompleted ? primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? primary
                              : const Color(0xFF475569),
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Color(0xFF64748b), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'URGENT',
                    style: TextStyle(
                      color: accentPink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                )
              else
                Icon(Icons.arrow_forward, color: Color(0xFF64748b), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color cardColor) {
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
          _buildNavItem(Icons.home_outlined, 0),
          _buildNavItem(Icons.bar_chart_outlined, 1),
          const SizedBox(width: 60), // Space for center button
          _buildNavItem(Icons.person, 3),
          _buildNavItem(Icons.settings_outlined, 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final isSelected = index == 0; // Home is always index 0 and selected on this page
    return GestureDetector(
      onTap: () {
        if (index == 0) return; // Already on Home page

        final Widget nextPage;
        switch (index) {
          case 1:
            nextPage = const AnalyticsPage();
            break;
          case 3:
            nextPage = const ProfilePage();
            break;
          case 4:
            nextPage = const SettingsPage();
            break;
          default:
            return;
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextPage,
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
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

  Widget _buildCenterNavButton(Color backgroundColor) {
    return Container(
      width: 70,
      height: 70,
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
          // Push receipts page directly as a separate route
          Navigator.pushNamed(context, '/receipts');
        },
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;

  CircularProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = const Color(0xFF272a33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius - 4, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = const Color(0xFF3b82f6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
