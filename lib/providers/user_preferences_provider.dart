import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_prefs_provider.dart';

final userPreferencesProvider =
    NotifierProvider<UserPreferencesNotifier, UserPreferencesState>(() {
  return UserPreferencesNotifier();
});

class UserPreferencesState {
  final bool disclaimerAccepted;
  final bool behavioralNudgesEnabled;
  final bool savingsPredictionsEnabled;
  final bool comparativeInsightsEnabled;
  final bool recurringTemplatesEnabled;
  final bool goalsTrackingEnabled;

  UserPreferencesState({
    required this.disclaimerAccepted,
    required this.behavioralNudgesEnabled,
    required this.savingsPredictionsEnabled,
    required this.comparativeInsightsEnabled,
    required this.recurringTemplatesEnabled,
    required this.goalsTrackingEnabled,
  });

  UserPreferencesState copyWith({
    bool? disclaimerAccepted,
    bool? behavioralNudgesEnabled,
    bool? savingsPredictionsEnabled,
    bool? comparativeInsightsEnabled,
    bool? recurringTemplatesEnabled,
    bool? goalsTrackingEnabled,
  }) {
    return UserPreferencesState(
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      behavioralNudgesEnabled:
          behavioralNudgesEnabled ?? this.behavioralNudgesEnabled,
      savingsPredictionsEnabled:
          savingsPredictionsEnabled ?? this.savingsPredictionsEnabled,
      comparativeInsightsEnabled:
          comparativeInsightsEnabled ?? this.comparativeInsightsEnabled,
      recurringTemplatesEnabled:
          recurringTemplatesEnabled ?? this.recurringTemplatesEnabled,
      goalsTrackingEnabled: goalsTrackingEnabled ?? this.goalsTrackingEnabled,
    );
  }
}

class UserPreferencesNotifier extends Notifier<UserPreferencesState> {
  late SharedPreferences _prefs;

  @override
  UserPreferencesState build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    final disclaimerAccepted =
        _prefs.getBool('disclaimerAccepted') ?? false;
    final behavioralNudgesEnabled =
        _prefs.getBool('behavioralNudgesEnabled') ?? true;
    final savingsPredictionsEnabled =
        _prefs.getBool('savingsPredictionsEnabled') ?? true;
    final comparativeInsightsEnabled =
        _prefs.getBool('comparativeInsightsEnabled') ?? true;
    final recurringTemplatesEnabled =
        _prefs.getBool('recurringTemplatesEnabled') ?? true;
    final goalsTrackingEnabled = _prefs.getBool('goalsTrackingEnabled') ?? true;

    return UserPreferencesState(
      disclaimerAccepted: disclaimerAccepted,
      behavioralNudgesEnabled: behavioralNudgesEnabled,
      savingsPredictionsEnabled: savingsPredictionsEnabled,
      comparativeInsightsEnabled: comparativeInsightsEnabled,
      recurringTemplatesEnabled: recurringTemplatesEnabled,
      goalsTrackingEnabled: goalsTrackingEnabled,
    );
  }

  void acceptDisclaimer() {
    _prefs.setBool('disclaimerAccepted', true);
    state = state.copyWith(disclaimerAccepted: true);
  }

  void toggleBehavioralNudges(bool enabled) {
    _prefs.setBool('behavioralNudgesEnabled', enabled);
    state = state.copyWith(behavioralNudgesEnabled: enabled);
  }

  void toggleSavingsPredictions(bool enabled) {
    _prefs.setBool('savingsPredictionsEnabled', enabled);
    state = state.copyWith(savingsPredictionsEnabled: enabled);
  }

  void toggleComparativeInsights(bool enabled) {
    _prefs.setBool('comparativeInsightsEnabled', enabled);
    state = state.copyWith(comparativeInsightsEnabled: enabled);
  }

  void toggleRecurringTemplates(bool enabled) {
    _prefs.setBool('recurringTemplatesEnabled', enabled);
    state = state.copyWith(recurringTemplatesEnabled: enabled);
  }

  void toggleGoalsTracking(bool enabled) {
    _prefs.setBool('goalsTrackingEnabled', enabled);
    state = state.copyWith(goalsTrackingEnabled: enabled);
  }
}
