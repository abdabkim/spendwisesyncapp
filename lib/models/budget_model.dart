import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget_model.freezed.dart';
part 'budget_model.g.dart';

@freezed
abstract class BudgetModel with _$BudgetModel {
  const factory BudgetModel({
    @Default(0.0) double limitAmount,
    @Default(0.0) double amountSpent,
    @Default(0.0) double payAmount,
    @Default(0.0) double bankAmount,
    @Default(0.0) double cashAmount,
    @Default('\$') String currency,
    @Default([]) List<Map<String, dynamic>> monthlyDeductions,
  }) = _BudgetModel;

  factory BudgetModel.fromJson(Map<String, dynamic> json) => _$BudgetModelFromJson(json);
}
