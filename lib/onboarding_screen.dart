import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screen/auth/signup_page.dart';

// Color Constants matching the HTML design
class OnboardingColors {
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
  static const Color indicatorInactive = Color(0xFF334155);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Onboarding data for all 5 pages
  final List<OnboardingData> _pages = [
    // Page 1: Effortless Expense Tracking
    OnboardingData(
      imageUrl: 'assets/images/onboarding1.png',
      title: 'Effortless Expense Tracking',
      description:
          'Say goodbye to manual spreadsheets. Sync your accounts and let SpendWise organize your financial life automatically.',
    ),
    // Page 2: Upload & Store Receipts
    OnboardingData(
      imageUrl: 'assets/images/onboarding2.png',
      title: 'Upload & Store Receipts',
      description:
          'Never lose a receipt again. Snap a photo, upload it instantly, and let SpendWise organize your spending for tax time.',
    ),
    // Page 3: Smart Todo + Budget Limits
    OnboardingData(
      imageUrl: 'assets/images/onboarding3.png',
      title: 'Smart Todo + Budget Limits',
      description:
          'Set spending limits on your tasks. We\'ll alert you before you overspend on your grocery run or project.',
      hasSpecialTitle: true, // Flag to use custom title formatting
    ),
    // Page 4: Export, Share & Analyze
    OnboardingData(
      imageUrl: 'assets/images/onboarding4.png',
      title: 'Export, Share & Analyze',
      description:
          'Instantly export your spending reports to PDF or CSV. Dive deep into your financial trends offline.',
    ),
    // Page 5: Privacy-First & Secure
    OnboardingData(
      imageUrl: 'assets/images/onboarding5.png',
      title: 'Privacy-First & Secure',
      description:
          'We use 256-bit encryption to keep your financial data safe. We never sell your personal information to third parties.',
    ),
  ];

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
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _skipToSignup() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignupPage()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to Sign Up Page'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _skipToSignup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? OnboardingColors.backgroundDark
        : OnboardingColors.backgroundLight;
    final textGrey = isDark
        ? OnboardingColors.textGreyDark
        : OnboardingColors.textGreyLight;
    final textLight = isDark
        ? OnboardingColors.textLightDark
        : OnboardingColors.textLightLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),

          // Top App Bar with Skip Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: _skipToSignup,
                    style: TextButton.styleFrom(
                      foregroundColor: textGrey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // PageView with Onboarding Pages
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return OnboardingPage(data: _pages[index]);
              },
            ),
          ),

          // Footer with Page Indicators and Button
          Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                // Page Indicators
                PageIndicators(
                  currentPage: _currentPage,
                  pageCount: _pages.length,
                ),
                const SizedBox(height: 32),

                // Primary CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OnboardingColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      shadowColor: OnboardingColors.primary.withOpacity(0.25),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Onboarding Page Widget
class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? OnboardingColors.backgroundDark
        : OnboardingColors.backgroundLight;
    final textGrey = isDark
        ? OnboardingColors.textGreyDark
        : OnboardingColors.textGreyLight;
    final textLight = isDark
        ? OnboardingColors.textLightDark
        : OnboardingColors.textLightLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Hero Image with Gradient Effects
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                // Gradient Backdrop Blur Effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          OnboardingColors.primary.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                // Main Image Container
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image
                          Image.asset(
                            data.imageUrl, // This now points to your 'assets/images/...' path
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: OnboardingColors.indicatorInactive,
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 64,
                                  color: textGrey,
                                ),
                              );
                            },
                          ),

                          // Bottom Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  backgroundColor.withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Headline Text (with special formatting for page 3)
          (data.hasSpecialTitle ?? false)
              ? RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: textLight,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(text: 'Smart Todo +\n'),
                      TextSpan(
                        text: 'Budget Limits',
                        style: TextStyle(color: OnboardingColors.primary),
                      ),
                    ],
                  ),
                )
              : Text(
                  data.title,
                  style: TextStyle(
                    color: textLight,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

          const SizedBox(height: 16),

          // Body Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              data.description,
              style: TextStyle(
                color: textGrey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// Page Indicators Widget
class PageIndicators extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const PageIndicators({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentPage ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == currentPage
                ? OnboardingColors.primary
                : OnboardingColors.indicatorInactive,
            borderRadius: BorderRadius.circular(4),
            boxShadow: index == currentPage
                ? [
                    BoxShadow(
                      color: OnboardingColors.primary.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

// Data Model for Onboarding Pages
class OnboardingData {
  final String imageUrl;
  final String title;
  final String description;
  final bool? hasSpecialTitle;

  OnboardingData({
    required this.imageUrl,
    required this.title,
    required this.description,
    this.hasSpecialTitle,
  });
}
