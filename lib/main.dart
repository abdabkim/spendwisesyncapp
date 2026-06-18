import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwisesyncapp/screen/budget/analyticsscreen.dart';
import 'package:spendwisesyncapp/screen/budget/expensescreen.dart';
import 'package:spendwisesyncapp/screen/budget/receiptsscreen.dart';
import 'package:spendwisesyncapp/screen/calculator/shoppingcalculator.dart';
import 'package:spendwisesyncapp/screen/profile/profilescreen.dart';
import 'package:spendwisesyncapp/screen/settings/settingsscreen.dart';
import 'package:spendwisesyncapp/tododashboard/todo_dashboard.dart';
import 'package:spendwisesyncapp/services/notification_service.dart';
import 'package:spendwisesyncapp/providers/shared_prefs_provider.dart';
import 'package:spendwisesyncapp/providers/settings_provider.dart';
import 'package:spendwisesyncapp/providers/user_preferences_provider.dart';
import 'firebase_options.dart';
import 'onboarding_screen.dart';
import 'package:spendwisesyncapp/screen/auth/login_page.dart';
import 'package:spendwisesyncapp/screen/auth/signup_page.dart';
import 'package:spendwisesyncapp/screen/auth/financial_disclaimer_screen.dart';
import 'package:spendwisesyncapp/screen/home/homepage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  SharedPreferences? sharedPreferences;

  try {
    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Error loading .env file: $e");
    }

    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Initialize Firebase App Check
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    } catch (e) {
      debugPrint("Error activating App Check: $e");
    }

    // Initialize Notification Service
    await NotificationService().initialize();

    // Initialize SharedPreferences
    sharedPreferences = await SharedPreferences.getInstance();
  } catch (e, stackTrace) {
    debugPrint("Critical startup error: $e\n$stackTrace");
    startupError = e;
  }

  if (startupError != null) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Startup Error:\n\n$startupError',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        overrides: [
          if (sharedPreferences != null)
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the global settings provider for theme changes
    final settingsState = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'SpendWise Sync',
      debugShowCheckedModeBanner: false,
      // Light Theme Configuration
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF13A4EC),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(
          0xFFF6F7F8,
        ), // Matches _kBackgroundLight
      ),

      // Dark Theme Configuration
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF13A4EC),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(
          0xFF101C22,
        ), // Matches your requested background
      ),

      // Toggle this variable based on the Settings state
      themeMode: settingsState.themeMode,
      // Initial route
      initialRoute: '/',
      // Define all routes
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
        '/calculator': (context) => const ShoppingCalculator(),
        '/todo': (context) => const TodoDashboard(),
        '/budget': (context) => const ExpenseScreen(),
        '/receipts': (context) => const ReceiptsPage(),
        '/profile': (context) => const ProfilePage(),
        '/analytics': (context) => const AnalyticsPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Main animation controller (3 seconds)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Progress bar animation (0% to 100%)
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.95, curve: Curves.easeInOut),
      ),
    );

    // Fade in animation for text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Scale animation for logo
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Pulse animation for glow effect
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start the animation
    _controller.forward();

    // Check authentication and navigate after animation completes
    Timer(const Duration(milliseconds: 3100), () {
      _checkAuthAndNavigate();
    });
  }

  // Check if user is logged in and navigate accordingly
  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    // Check if user is already logged in
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, check if they've accepted disclaimer
      final prefs = await SharedPreferences.getInstance();
      final disclaimerAccepted = prefs.getBool('disclaimerAccepted') ?? false;

      if (!disclaimerAccepted) {
        // Show disclaimer first
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => const FinancialDisclaimerDialog(),
          ).whenComplete(() {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          });
        }
      } else {
        // Disclaimer already accepted, go to home
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } else {
      // User is not logged in, navigate to onboarding
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF040B16);
    const accentBlue = Color(0xFF00B4ED);
    const textGrey = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF0A192F), Color(0xFF040B16)],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              children: [
                const Spacer(flex: 5),
                // Animated Logo Container
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(45),
                        boxShadow: [
                          BoxShadow(
                            color: accentBlue.withOpacity(
                              _pulseAnimation.value,
                            ),
                            blurRadius: 60,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF334155), Color(0xFF0F172A)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 85,
                        color: accentBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                // Animated Title
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'SpendWise ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Sync',
                          style: TextStyle(color: accentBlue),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Animated Tagline
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: const Text(
                    'Your finances, perfectly aligned.',
                    style: TextStyle(color: textGrey, fontSize: 16),
                  ),
                ),
                const Spacer(flex: 4),
                // Animated Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progressAnimation.value,
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            accentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SYNCING ASSETS',
                            style: TextStyle(
                              color: textGrey,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(_progressAnimation.value * 100).toInt()}%',
                            style: const TextStyle(
                              color: accentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                // Version Text
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Text(
                    'V1.2.0',
                    style: TextStyle(
                      color: textGrey.withOpacity(0.4),
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            );
          },
        ),
      ),
    );
  }
}
