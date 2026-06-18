import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwisesyncapp/services/behavioral_insights_service.dart';

final behavioralInsightsProvider =
    FutureProvider.autoDispose<List<BehavioralInsight>>((ref) async {
  final service = BehavioralInsightsService();
  return await service.getAllInsights();
});
