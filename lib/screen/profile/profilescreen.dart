import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spendwisesyncapp/screen/budget/analyticsscreen.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:spendwisesyncapp/screen/budget/receiptsscreen.dart';
import 'package:spendwisesyncapp/screen/home/homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendwisesyncapp/screen/settings/settingsscreen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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

  final ImagePicker _imagePicker = ImagePicker();
  String _userName = '';
  String _userEmail = '';
  String? _userPhotoUrl;
  Uint8List? _localImageBytes;
  DateTime? _lastPasswordChange;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedPhotoUrl = prefs.getString('userPhotoUrl');

      if (cachedPhotoUrl != null && cachedPhotoUrl.isNotEmpty) {
        setState(() {
          _userPhotoUrl = cachedPhotoUrl;
        });
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          setState(() {
            _userName = data['fullName'] ?? '';
            _userEmail = data['email'] ?? user.email ?? '';
            _userPhotoUrl = data['photoURL'] ?? _userPhotoUrl ?? '';

            if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
              _lastPasswordChange = (data['createdAt'] as Timestamp).toDate();
            }
          });

          if (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty) {
            await prefs.setString('userPhotoUrl', _userPhotoUrl!);
          }
        }
      } else {
        setState(() {
          _userName = '';
          _userEmail = user.email ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        setState(() {
          _userEmail = user.email ?? '';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadPhoto() async {
    XFile? image;
    try {
      image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image == null) return;

      final Uint8List imageBytes = await image.readAsBytes();
      
      // Instantly update the avatar UI optimistically
      if (mounted) {
        setState(() {
          _localImageBytes = imageBytes;
        });
      }

      final int fileSizeInBytes = imageBytes.length;
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > 5) {
        if (mounted) {
          setState(() {
            _localImageBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image size must be less than 5MB'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final String fileExtension = image.path.split('.').last.toLowerCase();
      final List<String> allowedExtensions = [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif',
      ];

      if (!allowedExtensions.contains(fileExtension)) {
        if (mounted) {
          setState(() {
            _localImageBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please select a valid image file (PNG, JPG, JPEG, WebP, GIF)',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _localImageBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to upload photo'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator(color: primary)),
        ),
      );

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'profile_$timestamp.$fileExtension';

      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child(fileName);

      String contentType = 'image/jpeg';
      switch (fileExtension) {
        case 'png':
          contentType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
      }

      final metadata = SettableMetadata(
        contentType: contentType,
        cacheControl: 'public, max-age=31536000',
        customMetadata: {'userId': user.uid, 'uploadTime': timestamp},
      );

      try {
        final UploadTask uploadTask = storageRef.putFile(File(image.path), metadata);

        final TaskSnapshot taskSnapshot = await uploadTask;

        if (taskSnapshot.state != TaskState.success) {
          throw FirebaseException(
            plugin: 'firebase_storage',
            message: 'Upload failed with state: ${taskSnapshot.state}',
          );
        }

        final String downloadURL = await taskSnapshot.ref.getDownloadURL();

        if (downloadURL.isEmpty) {
          throw FirebaseException(
            plugin: 'firebase_storage',
            message: 'Failed to get download URL',
          );
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'photoURL': downloadURL,
        }, SetOptions(merge: true));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userPhotoUrl', downloadURL);

        if (mounted) {
          setState(() {
            _userPhotoUrl = downloadURL;
            _localImageBytes = null; // Clear local picked image, fall back to newly loaded URL
          });

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await _loadUserData();
        }
      } on FirebaseException catch (e) {
        if (mounted) {
          setState(() {
            _localImageBytes = null; // Revert back to original on failure
          });
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          String errorMessage = 'Upload failed';
          if (e.code == 'unauthorized') {
            errorMessage =
                'Permission denied. Please check Firebase Storage rules.';
          } else if (e.code == 'canceled' || e.code == '-13040') {
            errorMessage =
                'Upload was cancelled. Please check your Firebase Storage rules, internet connection, and App Check console settings.';
          } else if (e.message != null) {
            errorMessage = 'Upload error: ${e.message}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localImageBytes = null; // Revert back to original on failure
        });
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _editFullName() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : cardLight;
    final textLight = isDark ? textLightDark : textLightLight;

    final TextEditingController controller = TextEditingController(
      text: _userName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Edit Name', style: TextStyle(color: textLight)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: textLight),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && controller.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'fullName': controller.text});
                setState(() => _userName = controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_userEmail.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _userEmail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cardDark : Colors.white;
    final textLight = isDark ? textLightDark : const Color(0xFF0f172a);
    final textGrey = isDark ? textGreyDark : const Color(0xFF64748b);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 26),
            const SizedBox(width: 10),
            Text(
              'Delete Account',
              style: TextStyle(
                color: textLight,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you like to delete?',
              style: TextStyle(color: textGrey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Option 1 – Profile only
            _buildDeleteOption(
              icon: Icons.person_remove_outlined,
              title: 'Profile Only',
              subtitle: 'Removes your login account.\nYour saved data stays.',
              color: Colors.orange,
              textLight: textLight,
              textGrey: textGrey,
              cardColor: cardColor,
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndDelete(deleteData: false);
              },
            ),
            const SizedBox(height: 12),
            // Option 2 – Everything
            _buildDeleteOption(
              icon: Icons.delete_sweep_outlined,
              title: 'Everything',
              subtitle:
                  'Permanently deletes your account\nand all your data. Cannot be undone.',
              color: Colors.red,
              textLight: textLight,
              textGrey: textGrey,
              cardColor: cardColor,
              onTap: () {
                Navigator.pop(ctx);
                _confirmAndDelete(deleteData: true);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textLight,
    required Color textGrey,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: textGrey, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete({required bool deleteData}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? textGreyDark : const Color(0xFF64748b);
    final label = deleteData ? 'Everything' : 'Profile Only';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Are you sure?',
          style: TextStyle(
            color: isDark ? textLightDark : const Color(0xFF0f172a),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          deleteData
              ? 'This will permanently erase your account and all associated data. This cannot be undone.'
              : 'Your login account will be removed but your saved data will remain.',
          style: TextStyle(color: textGrey, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Delete $label'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid = user.uid;

      if (deleteData) {
        await _deleteAllUserData(uid);
      }

      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please log out and log back in, then try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAllUserData(String uid) async {
    final db = FirebaseFirestore.instance;
    final collections = ['budgets', 'receipts', 'todos', 'calendar_events'];

    for (final col in collections) {
      final query = await db
          .collection(col)
          .where('userId', isEqualTo: uid)
          .get();
      final batch = db.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      if (query.docs.isNotEmpty) await batch.commit();
    }
  }

  String _getPasswordChangeText() {
    if (_lastPasswordChange == null) return 'Never changed';
    final now = DateTime.now();
    final difference = now.difference(_lastPasswordChange!);
    if (difference.inDays < 30)
      return 'Last changed ${difference.inDays} days ago';
    final months = (difference.inDays / 30).floor();
    return 'Last changed $months month${months == 1 ? '' : 's'} ago';
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

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 50),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: textGrey,
                                  size: 24,
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          HomePage(),
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
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Profile',
                                    style: TextStyle(
                                      color: textLight,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Stack(
                            children: [
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: borderColor,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _localImageBytes != null
                                      ? Image.memory(
                                          _localImageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : _userPhotoUrl != null &&
                                              _userPhotoUrl!.isNotEmpty
                                          ? Image.network(
                                              _userPhotoUrl!,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  color: cardSurfaceColor,
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      color: primary,
                                                      value:
                                                          loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                          : null,
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      color: cardSurfaceColor,
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 70,
                                                        color: textGrey,
                                                      ),
                                                    );
                                                  },
                                            )
                                          : Container(
                                              color: cardSurfaceColor,
                                              child: Icon(
                                                Icons.person,
                                                size: 70,
                                                color: textGrey,
                                              ),
                                            ),
                                ),
                              ),
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: GestureDetector(
                                  onTap: _uploadPhoto,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isLoading
                                ? 'Loading...'
                                : (_userName.isEmpty ? 'User' : _userName),
                            style: TextStyle(
                              color: textLight,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: TextStyle(color: textGrey, fontSize: 16),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                _buildField(
                                  icon: Icons.person,
                                  label: 'FULL NAME',
                                  value: _userName,
                                  onTap: _editFullName,
                                  textGrey: textGrey,
                                  textLight: textLight,
                                ),
                                _buildField(
                                  icon: Icons.email,
                                  label: 'EMAIL',
                                  value: _userEmail,
                                  onTap: null,
                                  textGrey: textGrey,
                                  textLight: textLight,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _buildField(
                              icon: Icons.history,
                              label: 'Reset Password',
                              value: _getPasswordChangeText(),
                              onTap: _resetPassword,
                              isSecurity: true,
                              textGrey: textGrey,
                              textLight: textLight,
                            ),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: OutlinedButton(
                              onPressed: _showDeleteAccountDialog,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.red.withOpacity(0.2),
                                ),
                                backgroundColor: Colors.red.withOpacity(0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.delete_forever, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text(
                                    'Delete Account',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'SpendWise Sync v2.4.1',
                            style: TextStyle(
                              color: textGrey.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 180),
                        ],
                      ),
                    ),
                  ),
                ),
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
                  _buildBottomNav(isDark, cardColor, textGrey),
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

  Widget _buildField({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
    required Color textGrey,
    required Color textLight,
    bool isSecurity = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primary, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: textGrey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          value.isEmpty && _isLoading ? 'Loading...' : value,
          style: TextStyle(
            color: isSecurity ? textGrey : textLight,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: textGrey, size: 22),
    );
  }

  Widget _buildBottomNav(bool isDark, Color cardColor, Color textGrey) {
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
    final isSelected = index == 3; // Profile page is index 3
    return GestureDetector(
      onTap: () {
        if (index == 3) return; // Already on Profile page

        final Widget nextPage;
        switch (index) {
          case 0:
            nextPage = HomePage();
            break;
          case 1:
            nextPage = AnalyticsPage();
            break;
          case 4:
            nextPage = SettingsPage();
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
          Navigator.pushNamed(context, '/receipts');
        },
      ),
    );
  }
}
