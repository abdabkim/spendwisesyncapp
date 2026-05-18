import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spendwisesyncapp/screen/home/homepage.dart';
import 'signup_page.dart';

// App Colors
class AppColors {
  // DARK MODE
  static const Color backgroundDark = Color(0xFF0f1419);
  static const Color cardDark = Color(0xFF1a1d24);
  static const Color cardSurface = Color(0xFF232930);
  static const Color borderDark = Color(0xFF2d3542);
  static const Color textGreyDark = Color(0xFF94a3b8);
  static const Color textLightDark = Color(0xFFe2e8f0);

  // LIGHT MODE
  static const Color backgroundLight = Color(0xFFf6f7f8);
  static const Color cardLight = Color(0xFFffffff);
  static const Color cardSurfaceLight = Color(0xFFf1f5f9);
  static const Color borderLight = Color(0xFFe2e8f0);
  static const Color textGreyLight = Color(0xFF64748b);
  static const Color textLightLight = Color(0xFF0f172a);

  // SHARED
  static const Color primary = Color(0xFF00d4ff);
  static const Color errorColor = Color(0xFFEF4444);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Handle email/password sign in
  Future<void> _handleSignIn() async {
    // Enable auto-validation
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });

    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        // Sign in with Firebase
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Get user data from Firestore
        String userName = 'there';
        if (userCredential.user != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (userDoc.exists) {
            userName =
                userDoc.data()?['fullName'] ??
                userCredential.user!.displayName ??
                'there';
          } else {
            userName = userCredential.user!.displayName ?? 'there';
          }
        }

        if (mounted) {
          setState(() => _isLoading = false);

          // Show success modal with user name
          _showSuccessModal(userName, isReturningUser: true);
        }
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);

        String errorMessage = 'An error occurred. Please try again.';

        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email address.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled.';
            break;
          case 'invalid-credential':
            errorMessage = 'Invalid email or password. Please try again.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection.';
            break;
          default:
            errorMessage = e.message ?? 'Login failed. Please try again.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
            final textLight = isDark ? AppColors.textLightDark : AppColors.textLightLight;
            final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Reset Password', style: TextStyle(color: textLight, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter your email to receive a password reset link.', style: TextStyle(color: textGrey, fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textLight),
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      hintStyle: TextStyle(color: textGrey.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: isDark ? AppColors.cardSurface : AppColors.cardSurfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isResetting ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: textGrey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isResetting
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an email address'), backgroundColor: AppColors.errorColor, behavior: SnackBarBehavior.floating),
                            );
                            return;
                          }

                          setState(() => isResetting = true);
                          try {
                            await _auth.sendPasswordResetEmail(email: email);
                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Reset link sent to $email'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            setState(() => isResetting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message ?? 'An error occurred'), backgroundColor: AppColors.errorColor, behavior: SnackBarBehavior.floating),
                              );
                            }
                          } catch (e) {
                             setState(() => isResetting = false);
                             if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorColor, behavior: SnackBarBehavior.floating),
                                );
                             }
                          }
                        },
                  child: isResetting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Link', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Handle Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // Check if this is a new user or existing user
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        bool isNewUser = !userDoc.exists;
        String userName = user.displayName ?? 'there';

        if (!userDoc.exists) {
          // Create new user document in Firestore for first-time Google sign-in
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'fullName': userName,
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'authProvider': 'google',
          });
        } else {
          // Get the stored name from Firestore
          userName = userDoc.data()?['fullName'] ?? userName;
        }

        setState(() {
          _isGoogleLoading = false;
        });

        // Show success modal with personalized message
        if (mounted) {
          _showSuccessModal(userName, isReturningUser: !isNewUser);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isGoogleLoading = false;
      });

      String errorMessage = 'Google sign-in failed. Please try again.';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with the same email address but different sign-in credentials.';
          break;
        case 'invalid-credential':
          errorMessage = 'The credential received is malformed or has expired.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google sign-in is not enabled.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this credential.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        default:
          errorMessage =
              e.message ?? 'Google sign-in failed. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGoogleLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // Show success modal with personalized greeting
  void _showSuccessModal(String userName, {bool isReturningUser = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: backgroundColor.withOpacity(0.95),
      builder: (BuildContext dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: LoginSuccessModal(
          userName: userName,
          isReturningUser: isReturningUser,
          onComplete: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const HomePage(),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardSurfaceColor = isDark
        ? AppColors.cardSurface
        : AppColors.cardSurfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Add padding for status bar manually
          SizedBox(height: MediaQuery.of(context).padding.top),

          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button
                            IconButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupPage(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.arrow_back),
                              color: textLight,
                              iconSize: 24,
                            ),
                            // Help Text
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Help feature coming soon'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Text(
                                'Help',
                                style: TextStyle(
                                  color: textGrey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 20),
                              // Header Section
                              _buildHeader(),

                              SizedBox(height: 40),

                              // Login Form
                              _buildLoginForm(),

                              const Spacer(),

                              // Footer
                              _buildFooter(),
                              SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

    return Column(
      children: [
        // Logo/Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFF60A5FA)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.account_balance_wallet, color: textLight, size: 32),
        ),
        SizedBox(height: 24),

        // Title
        Text(
          'Sync your spending.',
          style: TextStyle(
            color: textLight,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),

        // Subtitle
        Text(
          'Log in to SpendWise Sync to continue.',
          style: TextStyle(color: textGrey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark
        ? AppColors.borderDark
        : AppColors.borderLight; // ADD THIS LINE
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email Field
          Text(
            'Email Address',
            style: TextStyle(
              color: textLight,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            style: TextStyle(color: textLight, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: TextStyle(
                color: textGrey.withOpacity(0.6),
                fontSize: 15,
              ),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.errorColor,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.errorColor,
                  width: 2,
                ),
              ),
              errorStyle: TextStyle(color: AppColors.errorColor, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          SizedBox(height: 20),

          // Password Field
          Text(
            'Password',
            style: TextStyle(
              color: textLight,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            validator: _validatePassword,
            style: TextStyle(color: textLight, fontSize: 16),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: TextStyle(
                color: textGrey.withOpacity(0.6),
                fontSize: 15,
              ),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.errorColor,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.errorColor,
                  width: 2,
                ),
              ),
              errorStyle: TextStyle(color: AppColors.errorColor, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: textGrey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: 8),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: textLight,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                disabledForegroundColor: textLight.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textLight),
                      ),
                    )
                  : Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 32),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: borderColor, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR CONTINUE WITH',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: Divider(color: borderColor, thickness: 1)),
            ],
          ),
          SizedBox(height: 24),

          // Google Sign-In Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
              style: OutlinedButton.styleFrom(
                backgroundColor: cardColor,
                disabledBackgroundColor: cardColor.withOpacity(0.6),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isGoogleLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textLight),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/google.png', width: 24, height: 24),
                        SizedBox(width: 12),
                        Text(
                          'Google',
                          style: TextStyle(
                            color: textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Widget _buildFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

    return RichText(
      text: TextSpan(
        style: TextStyle(color: textGrey, fontSize: 14),
        children: [
          const TextSpan(text: 'Don\'t have an account? '),
          TextSpan(
            text: 'Sign up',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
          ),
        ],
      ),
    );
  }
}

// Success Modal Widget
class LoginSuccessModal extends StatefulWidget {
  final String userName;
  final bool isReturningUser;
  final VoidCallback onComplete;

  const LoginSuccessModal({
    super.key,
    required this.userName,
    required this.isReturningUser,
    required this.onComplete,
  });

  @override
  State<LoginSuccessModal> createState() => _LoginSuccessModalState();
}

class _LoginSuccessModalState extends State<LoginSuccessModal> {
  @override
  void initState() {
    super.initState();
    // Auto-redirect after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textLight = isDark
        ? AppColors.textLightDark
        : AppColors.textLightLight;
    final textGrey = isDark ? AppColors.textGreyDark : AppColors.textGreyLight;

    // Extract first name from full name
    String firstName = widget.userName.split(' ').first;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.check, color: textLight, size: 32),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Title with personalized greeting
            Text(
              widget.isReturningUser
                  ? 'Welcome back, $firstName!'
                  : 'Welcome, $firstName!',
              style: TextStyle(
                color: textLight,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),

            // Subtitle
            Text(
              'Syncing your wallet...',
              style: TextStyle(color: textGrey, fontSize: 14),
            ),
            SizedBox(height: 24),

            // Loading indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Redirecting',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
