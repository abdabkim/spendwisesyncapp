// lib/tododashboard/todo_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendwisesyncapp/screen/todoscreen/add_todo_screen.dart';

// ============================================================================
// TODO MODEL
// ============================================================================

class TodoModel {
  final String todoId;
  final String userId;
  final String title;
  final String? description;
  final String? linkedReceiptItemId;
  final DateTime dueDate;
  final String? dueTime;
  final String priority;
  final String energyLevel;
  final String category;
  final bool isCompleted;
  final DateTime createdAt;

  TodoModel({
    required this.todoId,
    required this.userId,
    required this.title,
    this.description,
    this.linkedReceiptItemId,
    required this.dueDate,
    this.dueTime,
    required this.priority,
    required this.energyLevel,
    required this.category,
    required this.isCompleted,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'todoId': todoId,
      'userId': userId,
      'title': title,
      'description': description,
      'linkedReceiptItemId': linkedReceiptItemId,
      'dueDate': Timestamp.fromDate(dueDate),
      'dueTime': dueTime,
      'priority': priority,
      'energyLevel': energyLevel,
      'category': category,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TodoModel.fromMap(Map<String, dynamic> map) {
    return TodoModel(
      todoId: map['todoId'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      linkedReceiptItemId: map['linkedReceiptItemId'],
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      dueTime: map['dueTime'],
      priority: map['priority'] ?? 'None',
      energyLevel: map['energyLevel'] ?? 'Medium energy',
      category: map['category'] ?? 'Personal',
      isCompleted: map['isCompleted'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  String getDueDateDisplay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todoDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (todoDate == today) {
      return 'Due Today';
    } else if (todoDate == tomorrow) {
      return 'Tomorrow';
    } else if (todoDate.isBefore(today)) {
      return 'Overdue';
    } else if (todoDate.difference(today).inDays <= 7) {
      return 'This Week';
    } else {
      return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
  }
}

// ============================================================================
// TODO SERVICE
// ============================================================================

class TodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference get _todosCollection => _firestore.collection('todos');

  Future<void> addTodo({
    required String title,
    String? description,
    String? linkedReceiptItemId,
    required DateTime dueDate,
    String? dueTime,
    required String priority,
    required String energyLevel,
    required String category,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final todoId = _todosCollection.doc().id;

    final todo = TodoModel(
      todoId: todoId,
      userId: currentUserId!,
      title: title,
      description: description,
      linkedReceiptItemId: linkedReceiptItemId,
      dueDate: dueDate,
      dueTime: dueTime,
      priority: priority,
      energyLevel: energyLevel,
      category: category,
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    await _todosCollection.doc(todoId).set(todo.toMap());
  }

  Future<void> toggleTodoCompletion(String todoId, bool isCompleted) async {
    await _todosCollection.doc(todoId).update({'isCompleted': isCompleted});
  }

  Future<void> updateTodo(TodoModel todo) async {
    await _todosCollection.doc(todo.todoId).update(todo.toMap());
  }

  Future<void> deleteTodo(String todoId) async {
    await _todosCollection.doc(todoId).delete();
  }

  Stream<List<TodoModel>> getTodosStream() {
    if (currentUserId == null) return Stream.value([]);

    return _todosCollection
        .where('userId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final todos = snapshot.docs
              .map(
                (doc) => TodoModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
          todos.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return todos;
        });
  }

  Stream<List<TodoModel>> getActiveTodosStream() {
    if (currentUserId == null) return Stream.value([]);

    return _todosCollection
        .where('userId', isEqualTo: currentUserId)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final todos = snapshot.docs
              .map(
                (doc) => TodoModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
          todos.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return todos;
        });
  }

  Stream<List<TodoModel>> getCompletedTodosStream() {
    if (currentUserId == null) return Stream.value([]);

    return _todosCollection
        .where('userId', isEqualTo: currentUserId)
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final todos = snapshot.docs
              .map(
                (doc) => TodoModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
          todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return todos;
        });
  }

  double calculateProgress(List<TodoModel> allTodos) {
    if (allTodos.isEmpty) return 0.0;
    final completedCount = allTodos.where((todo) => todo.isCompleted).length;
    return (completedCount / allTodos.length) * 100;
  }

  int getHighPriorityCount(List<TodoModel> todos) {
    return todos
        .where((todo) => todo.priority == 'High' && !todo.isCompleted)
        .length;
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
}

// ============================================================================
// APP COLORS
// ============================================================================

class AppColors {
  static const Color primary = Color(0xFF13A4EC);
  static const Color backgroundDark = Color(0xFF101C22);
  static const Color surfaceDark = Color(0xFF19252B);
  static const Color surfaceHighlight = Color(0xFF283339);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9DB0B9);
  static const Color borderDark = Color(0xFF283339);
}

// ============================================================================
// TODO DASHBOARD SCREEN
// ============================================================================

class TodoDashboard extends StatefulWidget {
  const TodoDashboard({Key? key}) : super(key: key);

  @override
  State<TodoDashboard> createState() => _TodoDashboardState();
}

class _TodoDashboardState extends State<TodoDashboard> {
  // App Colors - DARK MODE
  static const Color backgroundDark = Color(0xFF0f1419);
  static const Color cardDark = Color(0xFF1a1d24);
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
  static const Color greenSuccess = Color(0xFF10b981);
  static const Color yellowWarning = Color(0xFFf59e0b);
  static const Color redError = Color(0xFFef4444);

  final TodoService _todoService = TodoService();
  int _selectedTab = 0;

  String _userName = 'User';
  String? _userPhotoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    print('✅ TodoDashboard initState called');
    _loadUserData();
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

  Future<void> _loadUserData() async {
    try {
      print('🔄 Loading user data...');
      final user = FirebaseAuth.instance.currentUser;
      print('👤 Current user: ${user?.uid}');

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        print('📄 User doc exists: ${userDoc.exists}');

        if (mounted) {
          setState(() {
            if (userDoc.exists) {
              _userName =
                  userDoc.data()?['fullName'] ?? user.displayName ?? 'User';
              _userPhotoUrl = userDoc.data()?['photoURL'] ?? user.photoURL;
              print('✅ Loaded user: $_userName');
            } else {
              _userName = user.displayName ?? 'User';
              _userPhotoUrl = user.photoURL;
              print('⚠️ No Firestore doc, using auth data');
            }
            _isLoading = false;
          });
        }
      } else {
        print('❌ No user logged in');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _isLoading = false;
        });
      }
    }
  }

  void _showEditTodoBottomSheet(TodoModel todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _EditTodoBottomSheet(todo: todo, todoService: _todoService),
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

    print('🎨 TodoDashboard building...');

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildHeader(),
                  _buildGreetingSection(),
                  _buildProgressCard(),
                  _buildSegmentedControl(),
                  _selectedTab == 0
                      ? _buildActiveTodos()
                      : _buildCompletedTodos(),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddTodoScreen(),
                      ),
                    );
                  },
                  backgroundColor: primary,
                  elevation: 8,
                  child: Icon(Icons.add, size: 32, color: textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final profileImage =
        _userPhotoUrl ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_userName)}&background=13a4ec&color=fff';

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(color: backgroundColor.withOpacity(0.8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2),
                    gradient: LinearGradient(
                      colors: [primary, Color(0xFF8b5cf6)],
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      profileImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person, color: textLight, size: 24);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName,
                      style: TextStyle(
                        color: textLight,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: IconButton(
                icon: Icon(Icons.search, size: 24),
                color: textLight,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return SliverToBoxAdapter(
      child: StreamBuilder<List<TodoModel>>(
        stream: _todoService.getTodosStream(),
        builder: (context, snapshot) {
          print('📊 Greeting stream state: ${snapshot.connectionState}');
          if (snapshot.hasError) {
            print('❌ Greeting stream error: ${snapshot.error}');
          }

          final allTodos = snapshot.data ?? [];
          final highPriorityCount = _todoService.getHighPriorityCount(allTodos);
          final greeting = _todoService.getGreeting();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $_userName',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textLight,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  highPriorityCount > 0
                      ? 'You have $highPriorityCount high-priority financial task${highPriorityCount == 1 ? '' : 's'} today.'
                      : 'You have no high-priority tasks today.',
                  style: TextStyle(fontSize: 14, color: textGrey, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return SliverToBoxAdapter(
      child: StreamBuilder<List<TodoModel>>(
        stream: _todoService.getTodosStream(),
        builder: (context, snapshot) {
          print('📊 Progress stream state: ${snapshot.connectionState}');
          if (snapshot.hasError) {
            print('❌ Progress stream error: ${snapshot.error}');
          }

          final allTodos = snapshot.data ?? [];
          final progress = _todoService.calculateProgress(allTodos);
          final completedCount = allTodos.where((t) => t.isCompleted).length;
          final totalCount = allTodos.length;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textLight,
                      ),
                    ),
                    Text(
                      '${progress.toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: totalCount == 0 ? 0 : progress / 100,
                    minHeight: 10,
                    backgroundColor: cardSurfaceColor,
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    totalCount == 0
                        ? 'No tasks yet'
                        : '$completedCount/$totalCount Tasks Completed',
                    style: TextStyle(fontSize: 14, color: textGrey),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentedControl() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: cardSurfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: ['Active', 'Completed'].asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isSelected = _selectedTab == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? cardColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? textLight : textGrey,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTodos() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return StreamBuilder<List<TodoModel>>(
      stream: _todoService.getActiveTodosStream(),
      builder: (context, snapshot) {
        print('📊 Active todos stream state: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          print('❌ Active todos error: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          print('📝 Active todos count: ${snapshot.data!.length}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: primary)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: textGrey),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: textGrey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final todos = snapshot.data ?? [];

        if (todos.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.all(40),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: textGrey),
                    SizedBox(height: 16),
                    Text(
                      'No active tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textGrey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to add a new task',
                      style: TextStyle(fontSize: 14, color: textGrey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final highPriorityTodos = todos
            .where((t) => t.priority == 'High')
            .toList();
        final otherTodos = todos.where((t) => t.priority != 'High').toList();

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (highPriorityTodos.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'HIGH PRIORITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...highPriorityTodos.map(
                  (todo) => _TodoCard(
                    todo: todo,
                    onChanged: (value) => _todoService.toggleTodoCompletion(
                      todo.todoId,
                      value ?? false,
                    ),
                    onTap: () => _showEditTodoBottomSheet(todo),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (otherTodos.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'UPCOMING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ...otherTodos.map(
                  (todo) => _TodoCard(
                    todo: todo,
                    onChanged: (value) => _todoService.toggleTodoCompletion(
                      todo.todoId,
                      value ?? false,
                    ),
                    onTap: () => _showEditTodoBottomSheet(todo),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ]),
          ),
        );
      },
    );
  }

  Widget _buildCompletedTodos() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? backgroundDark : backgroundLight;
    final cardColor = isDark ? cardDark : cardLight;
    final cardSurfaceColor = isDark ? cardSurface : cardSurfaceLight;
    final borderColor = isDark ? borderDark : borderLight;
    final textGrey = isDark ? textGreyDark : textGreyLight;
    final textLight = isDark ? textLightDark : textLightLight;

    return StreamBuilder<List<TodoModel>>(
      stream: _todoService.getCompletedTodosStream(),
      builder: (context, snapshot) {
        print('📊 Completed todos stream state: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          print('❌ Completed todos error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Container(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: primary)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: textGrey),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading completed tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: textGrey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final todos = snapshot.data ?? [];

        if (todos.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.all(40),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: textGrey),
                    SizedBox(height: 16),
                    Text(
                      'No completed tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final todo = todos[index];
              return _TodoCard(
                todo: todo,
                onChanged: (value) => _todoService.toggleTodoCompletion(
                  todo.todoId,
                  value ?? false,
                ),
                onTap: () => _showEditTodoBottomSheet(todo),
              );
            }, childCount: todos.length),
          ),
        );
      },
    );
  }
}

// ============================================================================
// TODO CARD
// ============================================================================

class _TodoCard extends StatelessWidget {
  final TodoModel todo;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTap;

  const _TodoCard({
    required this.todo,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? _TodoDashboardState.cardDark
        : _TodoDashboardState.cardLight;
    final borderColor = isDark
        ? _TodoDashboardState.borderDark
        : _TodoDashboardState.borderLight;
    final textGrey = isDark
        ? _TodoDashboardState.textGreyDark
        : _TodoDashboardState.textGreyLight;
    final textLight = isDark
        ? _TodoDashboardState.textLightDark
        : _TodoDashboardState.textLightLight;
    final primary = _TodoDashboardState.primary;

    final pillStyle = _PriorityPill.getStyle(todo.priority, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: todo.isCompleted,
                onChanged: onChanged,
                shape: const CircleBorder(),
                side: BorderSide(color: textGrey.withOpacity(0.6), width: 1.6),
                activeColor: primary,
                checkColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: todo.isCompleted ? textGrey : textLight,
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        todo.linkedReceiptItemId != null
                            ? Icons.attach_money
                            : Icons.calendar_today,
                        size: 14,
                        color: textGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        todo.linkedReceiptItemId != null
                            ? _formatCurrency(todo)
                            : _formatDueDate(todo.dueDate),
                        style: TextStyle(fontSize: 14, color: textGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PriorityPill(style: pillStyle),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit_outlined, size: 16, color: primary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Due Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return 'Overdue';
    if (diff <= 7) return 'This Week';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatCurrency(TodoModel todo) {
    final regex = RegExp(r'\$?\s*([0-9]+(\.[0-9]{1,2})?)');
    final match = regex.firstMatch(todo.title);
    if (match == null) return '\$0.00';
    final amount = double.tryParse(match.group(1) ?? '') ?? 0.0;
    return '\${amount.toStringAsFixed(2)}';
  }
}

// ============================================================================
// PRIORITY PILL
// ============================================================================

class _PriorityPill extends StatelessWidget {
  final Map<String, Object> style;

  const _PriorityPill({required this.style});

  static Map<String, Object> getStyle(String priority, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark
        ? _TodoDashboardState.textGreyDark
        : _TodoDashboardState.textGreyLight;
    final cardSurfaceColor = isDark
        ? _TodoDashboardState.cardSurface
        : _TodoDashboardState.cardSurfaceLight;
    final borderColor = isDark
        ? _TodoDashboardState.borderDark
        : _TodoDashboardState.borderLight;

    switch (priority) {
      case 'High':
        return {
          'label': 'High',
          'color': const Color(0xFFE25B5B),
          'bg': const Color(0x1AE25B5B),
          'ringColor': const Color(0x33E25B5B),
        };
      case 'Med':
        return {
          'label': 'Med',
          'color': const Color(0xFFF1C54C),
          'bg': const Color(0x1AF1C54C),
          'ringColor': const Color(0x33F1C54C),
        };
      case 'Low':
        return {
          'label': 'Low',
          'color': const Color(0xFF2BC6D8),
          'bg': const Color(0x1A2BC6D8),
          'ringColor': const Color(0x332BC6D8),
        };
      default:
        return {
          'label': 'None',
          'color': textGrey,
          'bg': cardSurfaceColor,
          'ringColor': borderColor,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style['bg'] as Color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['ringColor'] as Color, width: 1),
      ),
      child: Text(
        style['label'] as String,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style['color'] as Color,
          height: 1.2,
        ),
      ),
    );
  }
}

// ============================================================================
// EDIT TODO BOTTOM SHEET
// ============================================================================

class _EditTodoBottomSheet extends StatefulWidget {
  final TodoModel todo;
  final TodoService todoService;

  const _EditTodoBottomSheet({required this.todo, required this.todoService});

  @override
  State<_EditTodoBottomSheet> createState() => _EditTodoBottomSheetState();
}

class _EditTodoBottomSheetState extends State<_EditTodoBottomSheet> {
  late TextEditingController _taskController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  late String _selectedPriority;
  late String _selectedEnergyLevel;
  late String _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(
      text: widget.todo.description ?? '',
    );
    _selectedDate = widget.todo.dueDate;

    // Parse time if exists
    if (widget.todo.dueTime != null && widget.todo.dueTime!.isNotEmpty) {
      final parts = widget.todo.dueTime!.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    _selectedPriority = widget.todo.priority;
    _selectedEnergyLevel = widget.todo.energyLevel;
    _selectedCategory = widget.todo.category;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? _TodoDashboardState.backgroundDark
        : _TodoDashboardState.backgroundLight;
    final cardColor = isDark
        ? _TodoDashboardState.cardDark
        : _TodoDashboardState.cardLight;
    final primary = _TodoDashboardState.primary;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: primary,
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? _TodoDashboardState.backgroundDark
        : _TodoDashboardState.backgroundLight;
    final cardColor = isDark
        ? _TodoDashboardState.cardDark
        : _TodoDashboardState.cardLight;
    final primary = _TodoDashboardState.primary;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: primary,
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

  Future<void> _saveChanges() async {
    final primary = _TodoDashboardState.primary;

    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task title cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Format time if selected
      String? timeString;
      if (_selectedTime != null) {
        timeString =
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
      }

      final updatedTodo = TodoModel(
        todoId: widget.todo.todoId,
        userId: widget.todo.userId,
        title: _taskController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        linkedReceiptItemId: widget.todo.linkedReceiptItemId,
        dueDate: _selectedDate,
        dueTime: timeString,
        priority: _selectedPriority,
        energyLevel: _selectedEnergyLevel,
        category: _selectedCategory,
        isCompleted: widget.todo.isCompleted,
        createdAt: widget.todo.createdAt,
      );

      await widget.todoService.updateTodo(updatedTodo);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task updated successfully'),
            backgroundColor: primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? _TodoDashboardState.cardDark
        : _TodoDashboardState.cardLight;
    final textGrey = isDark
        ? _TodoDashboardState.textGreyDark
        : _TodoDashboardState.textGreyLight;
    final textLight = isDark
        ? _TodoDashboardState.textLightDark
        : _TodoDashboardState.textLightLight;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Delete Task', style: TextStyle(color: textLight)),
        content: Text(
          'Are you sure you want to delete this task? This action cannot be undone.',
          style: TextStyle(color: textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.todoService.deleteTodo(widget.todo.todoId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting task: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? _TodoDashboardState.backgroundDark
        : _TodoDashboardState.backgroundLight;
    final cardColor = isDark
        ? _TodoDashboardState.cardDark
        : _TodoDashboardState.cardLight;
    final cardSurfaceColor = isDark
        ? _TodoDashboardState.cardSurface
        : _TodoDashboardState.cardSurfaceLight;
    final borderColor = isDark
        ? _TodoDashboardState.borderDark
        : _TodoDashboardState.borderLight;
    final textGrey = isDark
        ? _TodoDashboardState.textGreyDark
        : _TodoDashboardState.textGreyLight;
    final textLight = isDark
        ? _TodoDashboardState.textLightDark
        : _TodoDashboardState.textLightLight;
    final primary = _TodoDashboardState.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Task',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textLight,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: textGrey),
                ),
              ],
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title
                  Text(
                    'Task Title',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _taskController,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      hintText: 'Enter task title',
                      hintStyle: TextStyle(color: textGrey),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Description (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      hintText: 'Add notes or details...',
                      hintStyle: TextStyle(color: textGrey),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Due Date
                  Text(
                    'Due Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                            style: TextStyle(color: textLight, fontSize: 16),
                          ),
                          Icon(Icons.calendar_today, color: primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time
                  Text(
                    'Time (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedTime != null
                                ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                : 'None',
                            style: TextStyle(
                              color: _selectedTime != null
                                  ? textLight
                                  : textGrey,
                              fontSize: 16,
                            ),
                          ),
                          Icon(Icons.access_time, color: primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Priority
                  Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['None', 'Low', 'Med', 'High'].map((priority) {
                      final isSelected = _selectedPriority == priority;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedPriority = priority),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? primary : cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              priority,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : textGrey,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Energy Level
                  Text(
                    'Energy Level',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Low', 'Medium', 'High'].map((level) {
                      final energyLevel = '$level energy';
                      final isSelected = _selectedEnergyLevel == energyLevel;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _selectedEnergyLevel = energyLevel,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? primary : cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              level,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : textGrey,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                          'Personal',
                          'Home',
                          'Health',
                          'Finance',
                          'Errands',
                        ].map((category) {
                          final isSelected = _selectedCategory == category;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = category),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? primary : cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : textGrey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _deleteTask,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: textLight,
                                  ),
                                )
                              : Text(
                                  'Save',
                                  style: TextStyle(
                                    color: textLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
