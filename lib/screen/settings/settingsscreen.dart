import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // New Import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwisesyncapp/providers/settings_provider.dart';
import 'package:spendwisesyncapp/screen/home/homepage.dart';
import 'package:spendwisesyncapp/screen/budget/analyticsscreen.dart';
import 'package:spendwisesyncapp/screen/profile/profilescreen.dart';
import 'package:spendwisesyncapp/services/financial_report_service.dart';
import 'package:spendwisesyncapp/screen/settings/support_chat_screen.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // State variables for interactive elements
  bool _notificationsEnabled = true;

  // State variables for expansion logic
  bool _showPrivacy = false;
  bool _showTerms = false;

  // Financial report states
  bool _isExporting = false;
  final FinancialReportService _reportService = FinancialReportService();

  // --- DESIGN TOKENS (From your HTML/Tailwind) ---
  final Color _kPrimary = const Color(0xFF13a4ec);
  final Color _kBackgroundLight = const Color(0xFFf6f7f8);
  final double _kCornerRadius = 12.0;

  // Navigation colors matching analytics
  static const Color primary = Color(0xFF3b82f6);
  static const Color textGrey = Color(0xFF94a3b8);

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Load saved preferences on startup
    _updateSystemUI();
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _updateSystemUI() {
    final settings = ref.read(settingsProvider);
    bool isDarkMode;
    if (settings.themeMode == ThemeMode.system) {
      isDarkMode =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    } else {
      isDarkMode = settings.themeMode == ThemeMode.dark;
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bool _isDarkMode = settings.themeMode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : settings.themeMode == ThemeMode.dark;

    final Color bgColor = _isDarkMode
        ? const Color(0xFF101C22)
        : _kBackgroundLight;
    final Color cardColor = _isDarkMode
        ? const Color(0xFF101C22)
        : Colors.white;

    // Text colors responding to toggle
    final Color textColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF0F172A);
    final Color subTextColor = _isDarkMode
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black54;

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: bgColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
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
          title: Text(
            'Settings',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.015,
            ),
            textScaler: TextScaler.noScaling,
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
              height: 1,
              color: _isDarkMode ? Colors.white10 : Colors.black12,
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        children: [
                          // --- APP PREFERENCES SECTION ---
                          _buildSectionTitle('App Preferences', textColor),
                          const SizedBox(height: 8),
                          _buildSettingsGroup(cardColor, _isDarkMode, [
                            _buildThemeSelectorTile(
                              currentMode: settings.themeMode,
                              onChanged: (mode) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setThemeMode(mode);
                                _updateSystemUI();
                              },
                              textColor: textColor,
                              isDark: _isDarkMode,
                            ),
                            _buildSwitchTile(
                              icon: Icons.notifications,
                              title: 'Notifications',
                              value: _notificationsEnabled,
                              onChanged: (val) {
                                setState(() => _notificationsEnabled = val);
                                _savePreference('notificationsEnabled', val);
                              },
                              textColor: textColor,
                              isDark: _isDarkMode,
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 32),

                          // --- FINANCIAL REPORT SECTION ---
                          _buildSectionTitle('Financial Statements', textColor),
                          const SizedBox(height: 8),
                          _buildSettingsGroup(cardColor, _isDarkMode, [
                            _buildNavigationTile(
                              icon: Icons.picture_as_pdf_outlined,
                              title: 'Export PDF Statement',
                              subtitle:
                                  'Download printable Balance Sheet & P&L',
                              onTap: () async {
                                setState(() => _isExporting = true);
                                try {
                                  await _reportService.exportPDF();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to export PDF: $e',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isExporting = false);
                                  }
                                }
                              },
                              textColor: textColor,
                              isDark: _isDarkMode,
                            ),
                            _buildNavigationTile(
                              icon: Icons.grid_on_outlined,
                              title: 'Export CSV Ledger',
                              subtitle: 'Download Excel-ready spreadsheets',
                              onTap: () async {
                                setState(() => _isExporting = true);
                                try {
                                  await _reportService.exportCSV();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to export CSV: $e',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isExporting = false);
                                  }
                                }
                              },
                              textColor: textColor,
                              isDark: _isDarkMode,
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 32),

                          // --- SUPPORT SECTION ---
                          _buildSectionTitle('Support', textColor),
                          const SizedBox(height: 8),
                          _buildSettingsGroup(cardColor, _isDarkMode, [
                            _buildNavigationTile(
                              icon: Icons.support_agent,
                              title: 'AI Support Chat',
                              subtitle: 'Ask about app features & FAQs',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SupportChatScreen(),
                                  ),
                                );
                              },
                              textColor: textColor,
                              isDark: _isDarkMode,
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 32),

                          // --- LEGAL SECTION ---
                          _buildSectionTitle('Legal and Privacy', textColor),
                          const SizedBox(height: 8),
                          _buildSettingsGroup(cardColor, _isDarkMode, [
                            _buildNavigationTile(
                              icon: Icons.policy,
                              title: 'Privacy Policy',
                              subtitle: 'Data usage, storage, and user rights',
                              onTap: () =>
                                  setState(() => _showPrivacy = !_showPrivacy),
                              textColor: textColor,
                              isDark: _isDarkMode,
                              isExpanded: _showPrivacy,
                            ),
                            _buildExpandableContent(
                              isVisible: _showPrivacy,
                              textColor: subTextColor,
                              content:
                                  "We value your privacy. Your transaction data is encrypted locally and only synced with your authorized accounts. We do not sell your personal financial information to third parties.",
                            ),
                            _buildNavigationTile(
                              icon: Icons.gavel,
                              title: 'Terms & Conditions',
                              subtitle: 'App usage and responsibilities',
                              onTap: () =>
                                  setState(() => _showTerms = !_showTerms),
                              textColor: textColor,
                              isDark: _isDarkMode,
                              isExpanded: _showTerms,
                              showDivider: false,
                            ),
                            _buildExpandableContent(
                              isVisible: _showTerms,
                              textColor: subTextColor,
                              content:
                                  "By using SpendWise Sync, you agree to manage your financial data responsibly. The app is a tool for tracking and analysis; users are responsible for the accuracy of their manual entries.",
                            ),
                          ]),

                          // --- FOOTER ---
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Column(
                              children: [
                                Text(
                                  'SpendWise Sync',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version 2.4.1 (Build 108)',
                                  style: TextStyle(
                                    color: subTextColor.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 100),
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
                  _buildBottomNav(cardColor),
                  Positioned(bottom: 15, child: _buildCenterNavButton(bgColor)),
                ],
              ),
            ),
            if (_isExporting)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF13a4ec),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Compiling Financial Report...',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Structuring Balance Sheets & Forecasts',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE COMPONENT BUILDERS ---

  Widget _buildExpandableContent({
    required bool isVisible,
    required Color textColor,
    required String content,
  }) {
    return AnimatedCrossFade(
      firstChild: Container(width: double.infinity),
      secondChild: Padding(
        padding: const EdgeInsets.fromLTRB(68, 0, 24, 16),
        child: Text(
          content,
          style: TextStyle(color: textColor, fontSize: 13, height: 1.5),
        ),
      ),
      crossFadeState: isVisible
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    Color cardColor,
    bool isDark,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_kCornerRadius),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _kPrimary, size: 24),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 12,
      endIndent: 12,
      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required bool isDark,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        SwitchListTile(
          secondary: _buildIcon(icon),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: _kPrimary,
        ),
        if (showDivider) _buildDivider(isDark),
      ],
    );
  }

  Widget _buildThemeSelectorTile({
    required ThemeMode currentMode,
    required ValueChanged<ThemeMode> onChanged,
    required Color textColor,
    required bool isDark,
  }) {
    return Column(
      children: [
        ListTile(
          leading: _buildIcon(Icons.palette_outlined),
          title: Text(
            'App Theme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 16),
                    label: Text(
                      'Light',
                      style: TextStyle(fontSize: 12),
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 16),
                    label: Text(
                      'Dark',
                      style: TextStyle(fontSize: 12),
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_system_daydream, size: 16),
                    label: Text(
                      'System',
                      style: TextStyle(fontSize: 12),
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ],
                selected: {currentMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  onChanged(newSelection.first);
                },
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          ),
        ),
        _buildDivider(isDark),
      ],
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
    required Color textColor,
    required bool isDark,
    bool showDivider = true,
    bool isExpanded = false, // Added to handle arrow rotation
  }) {
    return Column(
      children: [
        ListTile(
          leading: _buildIcon(icon),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.chevron_right,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          onTap: onTap,
        ),
        if (showDivider) _buildDivider(isDark),
      ],
    );
  }

  Widget _buildBottomNav(Color cardColor) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
    final isSelected = index == 4; // Settings page is index 4
    return GestureDetector(
      onTap: () {
        if (index == 4) return; // Already on Settings page

        final Widget nextPage;
        switch (index) {
          case 0:
            nextPage = HomePage();
            break;
          case 1:
            nextPage = AnalyticsPage();
            break;
          case 3:
            nextPage = ProfilePage();
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isSelected ? primary : textGrey, size: 24),
      ),
    );
  }

  Widget _buildCenterNavButton(Color backgroundColor) {
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
            color: primary.withValues(alpha: 0.3),
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
