import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@android:drawable/ic_dialog_info');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Combined initialization settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - you can navigate to specific screens here
    print('Notification tapped: ${response.payload}');
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Schedule a notification for a todo item
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if the scheduled date is in the future
    if (scheduledDate.isBefore(DateTime.now())) {
      return; // Don't schedule notifications for past dates
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'todo_channel',
          'Todo Notifications',
          channelDescription: 'Notifications for upcoming todo items',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Combined notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule the notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Schedule notifications for upcoming todos
  Future<void> scheduleTodoNotifications(String userId) async {
    try {
      // Cancel all existing notifications first
      await cancelAllNotifications();

      // Get all pending todos from Firestore
      final todosSnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      for (var doc in todosSnapshot.docs) {
        final data = doc.data();
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final dueTime =
            data['dueTime'] as String?; // Time stored as string (e.g., "14:30")
        final title = data['title'] as String? ?? 'Todo Reminder';
        final category = data['category'] as String? ?? '';
        final priority = data['priority'] as String? ?? '';

        if (dueDate != null) {
          // Combine dueDate and dueTime to create exact DateTime
          DateTime exactDueDateTime;

          if (dueTime != null && dueTime.isNotEmpty) {
            // Parse the time string (format: "HH:mm")
            try {
              final timeParts = dueTime.split(':');
              if (timeParts.length == 2) {
                final hour = int.parse(timeParts[0]);
                final minute = int.parse(timeParts[1]);

                // Create exact due date with time
                exactDueDateTime = DateTime(
                  dueDate.year,
                  dueDate.month,
                  dueDate.day,
                  hour,
                  minute,
                );
              } else {
                // If time format is invalid, use end of day
                exactDueDateTime = DateTime(
                  dueDate.year,
                  dueDate.month,
                  dueDate.day,
                  23,
                  59,
                );
              }
            } catch (e) {
              // If parsing fails, use end of day
              exactDueDateTime = DateTime(
                dueDate.year,
                dueDate.month,
                dueDate.day,
                23,
                59,
              );
            }
          } else {
            // No time specified, use end of day
            exactDueDateTime = DateTime(
              dueDate.year,
              dueDate.month,
              dueDate.day,
              23,
              59,
            );
          }

          // Only schedule if the due date/time is in the future
          if (exactDueDateTime.isAfter(DateTime.now())) {
            // Schedule notification 1 hour before due time
            final notificationTime = exactDueDateTime.subtract(
              const Duration(hours: 1),
            );

            if (notificationTime.isAfter(DateTime.now())) {
              String notificationBody = 'Due in 1 hour';
              if (category.isNotEmpty) notificationBody += ' · $category';
              if (priority.isNotEmpty)
                notificationBody += ' · $priority Priority';

              await scheduleNotification(
                id: doc.id.hashCode, // Use doc ID hash as notification ID
                title: 'Upcoming Task: $title',
                body: notificationBody,
                scheduledDate: notificationTime,
              );
            }

            // Also schedule a notification at the exact due time
            String dueNotificationBody = 'This task is due now';
            if (category.isNotEmpty) dueNotificationBody += ' · $category';
            if (priority.isNotEmpty)
              dueNotificationBody += ' · $priority Priority';

            await scheduleNotification(
              id: doc.id.hashCode + 1, // Different ID for due time notification
              title: 'Task Due Now: $title',
              body: dueNotificationBody,
              scheduledDate: exactDueDateTime,
            );
          }
        }
      }
    } catch (e) {
      print('Error scheduling todo notifications: $e');
    }
  }

  /// Show an immediate notification
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'todo_channel',
          'Todo Notifications',
          channelDescription: 'Notifications for todo items',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}
