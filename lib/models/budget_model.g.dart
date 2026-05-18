// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BudgetModel _$BudgetModelFromJson(Map<String, dynamic> json) => _BudgetModel(
  limitAmount: (json['limitAmount'] as num?)?.toDouble() ?? 0.0,
  amountSpent: (json['amountSpent'] as num?)?.toDouble() ?? 0.0,
  payAmount: (json['payAmount'] as num?)?.toDouble() ?? 0.0,
  bankAmount: (json['bankAmount'] as num?)?.toDouble() ?? 0.0,
  cashAmount: (json['cashAmount'] as num?)?.toDouble() ?? 0.0,
  currency: json['currency'] as String? ?? '\$',
  monthlyDeductions:
      (json['monthlyDeductions'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
);

Map<String, dynamic> _$BudgetModelToJson(_BudgetModel instance) =>
    <String, dynamic>{
      'limitAmount': instance.limitAmount,
      'amountSpent': instance.amountSpent,
      'payAmount': instance.payAmount,
      'bankAmount': instance.bankAmount,
      'cashAmount': instance.cashAmount,
      'currency': instance.currency,
      'monthlyDeductions': instance.monthlyDeductions,
    };
