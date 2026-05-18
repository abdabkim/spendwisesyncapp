// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CalendarEventModel _$CalendarEventModelFromJson(Map<String, dynamic> json) =>
    _CalendarEventModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      date: const TimestampConverter().fromJson(json['date'] as Timestamp),
      projectedCost: (json['projectedCost'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$CalendarEventModelToJson(_CalendarEventModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'date': const TimestampConverter().toJson(instance.date),
      'projectedCost': instance.projectedCost,
    };
