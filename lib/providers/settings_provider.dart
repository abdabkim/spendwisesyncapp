import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_prefs_provider.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

class SettingsState {
  final ThemeMode themeMode;
  final String currency;

  SettingsState({required this.themeMode, required this.currency});

  SettingsState copyWith({ThemeMode? themeMode, String? currency}) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  SettingsState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    
    // Load saved preferences or default to Light / $
    final savedTheme = _prefs.getString('themeMode') ?? 'system';
    ThemeMode themeMode;
    switch (savedTheme) {
      case 'light': themeMode = ThemeMode.light; break;
      case 'dark': themeMode = ThemeMode.dark; break;
      default: themeMode = ThemeMode.system;
    }

    final currency = _prefs.getString('currency') ?? '\$';

    return SettingsState(themeMode: themeMode, currency: currency);
  }

  void setThemeMode(ThemeMode mode) {
    String modeString = 'system';
    if (mode == ThemeMode.light) modeString = 'light';
    if (mode == ThemeMode.dark) modeString = 'dark';
    
    _prefs.setString('themeMode', modeString);
    state = state.copyWith(themeMode: mode);
  }

  void setCurrency(String currency) {
    _prefs.setString('currency', currency);
    state = state.copyWith(currency: currency);
  }
}
