import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // New Import
import 'package:spendwisesyncapp/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // State variables for interactive elements
  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  double _fontSizeValue = 0.5;

  // State variables for expansion logic
  bool _showPrivacy = false;
  bool _showTerms = false;

  // --- DESIGN TOKENS (From your HTML/Tailwind) ---
  final Color _kPrimary = const Color(0xFF13a4ec);
  final Color _kBackgroundLight = const Color(0xFFf6f7f8);
  final Color _kBackgroundDark = const Color(0xFF101c22);
  final Color _kCardDark = const Color(0xFF101c22);
  final double _kCornerRadius = 12.0;

  // Navigation colors matching analytics
  static const Color backgroundDark = Color(0xFF101C22);
  static const Color cardDark = Color(0xFF101C22);
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
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
    _updateSystemUI();
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize _isDarkMode from the app's current theme mode
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }

  void _updateSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Logic to toggle colors based on the _isDarkMode switch state
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
        ? Colors.white.withOpacity(0.7)
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
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.015,
            ),
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
                            _buildSwitchTile(
                              icon: Icons.dark_mode,
                              title: 'Dark Mode',
                              value: _isDarkMode,
                              onChanged: (val) {
                                setState(() {
                                  _isDarkMode = val;
                                  _updateSystemUI();
                                });
                                _savePreference('isDarkMode', val);
                                // Update the app-wide theme
                                MyApp.of(context).toggleTheme(val);
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
                                    color: subTextColor.withOpacity(0.5),
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
        color: _kPrimary.withOpacity(0.1),
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
      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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
          activeColor: Colors.white,
          activeTrackColor: _kPrimary,
        ),
        if (showDivider) _buildDivider(isDark),
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
                    color: textColor.withOpacity(0.5),
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
                    color: textColor.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.chevron_right,
                  color: textColor.withOpacity(0.5),
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
    final isSelected = index == 4; // Settings page is index 4
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          // Navigate back to home
          Navigator.pushNamed(context, '/home');
        } else if (index != 4) {
          // Navigate to other page
          Navigator.pushNamed(
            context,
            '/${index == 1
                ? 'analytics'
                : index == 2
                ? 'receipts'
                : index == 3
                ? 'profile'
                : index == 0
                ? 'home'
                : 'home'}',
          );
        }
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
          Navigator.pop(context);
          Navigator.pushNamed(context, '/receipts');
        },
      ),
    );
  }
}
