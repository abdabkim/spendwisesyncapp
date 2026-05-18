import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'calendar_event_model.freezed.dart';
part 'calendar_event_model.g.dart';

@freezed
abstract class CalendarEventModel with _$CalendarEventModel {
  const factory CalendarEventModel({
    required String id,
    required String userId,
    required String title,
    @TimestampConverter() required DateTime date,
    @Default(0.0) double projectedCost,
  }) = _CalendarEventModel;

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) => _$CalendarEventModelFromJson(json);
}
