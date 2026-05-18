import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'receipt_model.freezed.dart';
part 'receipt_model.g.dart';

@freezed
abstract class ReceiptModel with _$ReceiptModel {
  const factory ReceiptModel({
    required String id,
    required String userId,
    required String merchantName,
    required double totalCost,
    @TimestampConverter() required DateTime date,
    @Default([]) List<String> items,
  }) = _ReceiptModel;

  factory ReceiptModel.fromJson(Map<String, dynamic> json) => _$ReceiptModelFromJson(json);
}
