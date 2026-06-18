import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BehavioralInsight {
  final String type; // 'nudge', 'prediction', 'insight'
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? action;
  final DateTime timestamp;

  BehavioralInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.action,
    required this.timestamp,
  });
}

typedef VoidCallback = void Function();

class BehavioralInsightsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user is approaching daily limit and return nudge if so
  Future<BehavioralInsight?> checkDailyLimitNudge() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final dailyDoc = await _firestore
          .collection('budgets')
          .doc('${user.uid}_daily')
          .get();

      if (!dailyDoc.exists) return null;

      final data = dailyDoc.data()!;
      final spent = (data['amountSpent'] as num?)?.toDouble() ?? 0.0;
      final limit = (data['limitAmount'] as num?)?.toDouble() ?? 0.0;

      if (limit == 0) return null;

      final percentage = (spent / limit) * 100;

      if (percentage >= 90) {
        return BehavioralInsight(
          type: 'nudge',
          title: 'Daily Limit Alert',
          message:
              'You\'re at ${percentage.toStringAsFixed(0)}% of your daily limit. Slow down on spending!',
          actionLabel: 'View Budget',
          timestamp: DateTime.now(),
        );
      } else if (percentage >= 75) {
        return BehavioralInsight(
          type: 'nudge',
          title: 'Approaching Daily Limit',
          message:
              'You\'ve spent ${percentage.toStringAsFixed(0)}% of your daily budget. Consider pausing non-essential purchases.',
          actionLabel: 'Review Spending',
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error checking daily limit: $e');
    }

    return null;
  }

  /// Predict if user will overshoot their monthly budget
  Future<BehavioralInsight?> checkMonthlySavingsPrediction() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final monthlyDoc = await _firestore
          .collection('budgets')
          .doc('${user.uid}_monthly')
          .get();

      if (!monthlyDoc.exists) return null;

      final data = monthlyDoc.data()!;
      final spent = (data['amountSpent'] as num?)?.toDouble() ?? 0.0;
      final limit = (data['limitAmount'] as num?)?.toDouble() ?? 0.0;

      if (limit == 0) return null;

      // Simple linear projection: if spent X% of the month, will spend X% of limit
      final now = DateTime.now();
      final dayOfMonth = now.day;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysRemaining = daysInMonth - dayOfMonth;
      final dailyAverage = spent / dayOfMonth;
      final projectedTotal = spent + (dailyAverage * daysRemaining);
      final overshootAmount = projectedTotal - limit;

      if (overshootAmount > 0) {
        final overshootPercentage =
            ((overshootAmount / limit) * 100).toStringAsFixed(0);
        return BehavioralInsight(
          type: 'prediction',
          title: 'Monthly Budget Alert',
          message:
              'At current pace, you\'ll overshoot by ${overshootPercentage}%. Consider cutting ${overshootPercentage}% from non-essentials.',
          actionLabel: 'View Plan',
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error checking monthly savings: $e');
    }

    return null;
  }

  /// Compare spending to previous month and return insight
  Future<BehavioralInsight?> checkComparativeInsight() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final monthlyDoc = await _firestore
          .collection('budgets')
          .doc('${user.uid}_monthly')
          .get();

      if (!monthlyDoc.exists) return null;

      final data = monthlyDoc.data()!;
      final currentSpent = (data['amountSpent'] as num?)?.toDouble() ?? 0.0;
      final history =
          (data['deductionHistory'] as List?)?.cast<Map<String, dynamic>>() ??
          [];

      if (history.isEmpty) return null;

      // Get the last month's total spending
      // This is a simplified approach; you might want to track actual spending by category
      final lastEntry = history.first;
      final lastTotal = (lastEntry['totalDeductions'] as num?)?.toDouble() ?? 0.0;

      if (lastTotal == 0) return null;

      final difference = currentSpent - lastTotal;
      final percentChange = ((difference / lastTotal) * 100).toStringAsFixed(1);

      if (difference > 0) {
        return BehavioralInsight(
          type: 'insight',
          title: 'Spending Comparison',
          message:
              'You\'re spending $percentChange% more this month than last month. Where can you trim?',
          actionLabel: 'Analyze Expenses',
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error checking comparative insight: $e');
    }

    return null;
  }

  /// Get all available insights
  Future<List<BehavioralInsight>> getAllInsights() async {
    final insights = <BehavioralInsight>[];

    final dailyNudge = await checkDailyLimitNudge();
    if (dailyNudge != null) insights.add(dailyNudge);

    final savingsPrediction = await checkMonthlySavingsPrediction();
    if (savingsPrediction != null) insights.add(savingsPrediction);

    final comparative = await checkComparativeInsight();
    if (comparative != null) insights.add(comparative);

    return insights;
  }
}

void debugPrint(String message) {
  // Replace with actual debug print if needed
  print(message);
}
