import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final String priority; // "High", "Med", "Low", "None"
  final String energyLevel; // "Low energy", "Medium energy", "High energy"
  final String
  category; // "Personal", "Home", "Health", "Finance", "Errands, "Work"
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

  // Convert TodoModel to Map for Firebase
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

  // Create TodoModel from Firebase document
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

  // Helper method to get due date display text
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
// USER MODEL
// ============================================================================

class UserModel {
  final String userId;
  final String name;
  final String? profileImage;

  UserModel({required this.userId, required this.name, this.profileImage});

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['uid'] ?? '', // Changed from 'userId' to 'uid'
      name: map['fullName'] ?? 'User', // Changed from 'name' to 'fullName'
      profileImage:
          map['photoURL'], // Changed from 'profileImage' to 'photoURL'
    );
  }
}

// ============================================================================
// TODO SERVICE
// ============================================================================

class TodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _todosCollection => _firestore.collection('todos');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    if (currentUserId == null) return null;

    try {
      final doc = await _usersCollection.doc(currentUserId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Stream current user data
  Stream<UserModel?> getCurrentUserStream() {
    if (currentUserId == null) return Stream.value(null);

    return _usersCollection.doc(currentUserId).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // Add new todo
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

  // Update todo completion status
  Future<void> toggleTodoCompletion(String todoId, bool isCompleted) async {
    await _todosCollection.doc(todoId).update({'isCompleted': isCompleted});
  }

  // Update todo
  Future<void> updateTodo(TodoModel todo) async {
    await _todosCollection.doc(todo.todoId).update(todo.toMap());
  }

  // Delete todo
  Future<void> deleteTodo(String todoId) async {
    await _todosCollection.doc(todoId).delete();
  }

  // Stream all todos for current user
  Stream<List<TodoModel>> getTodosStream() {
    if (currentUserId == null) return Stream.value([]);

    return _todosCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TodoModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Stream active todos (not completed)
  Stream<List<TodoModel>> getActiveTodosStream() {
    if (currentUserId == null) return Stream.value([]);

    return _todosCollection
        .where('userId', isEqualTo: currentUserId)
        .where('isCompleted', isEqualTo: false)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TodoModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Stream completed todos
  Stream<List<TodoModel>> getCompletedTodosStream() {
    if (currentUserId == null) return Stream.value([]);

    return _todosCollection
        .where('userId', isEqualTo: currentUserId)
        .where('isCompleted', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TodoModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Calculate progress percentage
  double calculateProgress(List<TodoModel> allTodos) {
    if (allTodos.isEmpty) return 0.0;

    final completedCount = allTodos.where((todo) => todo.isCompleted).length;
    return (completedCount / allTodos.length) * 100;
  }

  // Get high priority count
  int getHighPriorityCount(List<TodoModel> todos) {
    return todos
        .where((todo) => todo.priority == 'High' && !todo.isCompleted)
        .length;
  }

  // Get greeting based on time of day
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
