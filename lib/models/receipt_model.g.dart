// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReceiptModel _$ReceiptModelFromJson(Map<String, dynamic> json) =>
    _ReceiptModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      merchantName: json['merchantName'] as String,
      totalCost: (json['totalCost'] as num).toDouble(),
      date: const TimestampConverter().fromJson(json['date'] as Timestamp),
      items:
          (json['items'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
    );

Map<String, dynamic> _$ReceiptModelToJson(_ReceiptModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'merchantName': instance.merchantName,
      'totalCost': instance.totalCost,
      'date': const TimestampConverter().toJson(instance.date),
      'items': instance.items,
    };
