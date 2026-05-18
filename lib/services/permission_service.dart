import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Requests all core permissions necessary for the app to function properly.
  /// If the user has already granted or permanently denied them, the OS will automatically
  /// handle skipping the prompt.
  Future<void> requestAllPermissions() async {
    // Collect the necessary permissions based on platform
    List<Permission> permissions = [
      Permission.notification,
      Permission.camera,
    ];

    // Android 13+ (API 33) uses photos instead of storage
    if (Platform.isAndroid) {
      // In Flutter, permission_handler maps Permission.storage to older Android versions
      // and Permission.photos to Android 13+. It's safest to request both.
      permissions.add(Permission.storage);
      permissions.add(Permission.photos);
    } else if (Platform.isIOS) {
      permissions.add(Permission.photos);
    }

    // Request them simultaneously
    await permissions.request();
  }
}
