// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TodoModel _$TodoModelFromJson(Map<String, dynamic> json) => _TodoModel(
  id: json['id'] as String,
  userId: json['userId'] as String,
  title: json['title'] as String,
  description: json['description'] as String? ?? '',
  isCompleted: json['isCompleted'] as bool? ?? false,
  dueDate: const NullableTimestampConverter().fromJson(
    json['dueDate'] as Timestamp?,
  ),
  dueTime: json['dueTime'] as String?,
  category: json['category'] as String? ?? '',
  priority: json['priority'] as String? ?? '',
);

Map<String, dynamic> _$TodoModelToJson(_TodoModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'isCompleted': instance.isCompleted,
      'dueDate': const NullableTimestampConverter().toJson(instance.dueDate),
      'dueTime': instance.dueTime,
      'category': instance.category,
      'priority': instance.priority,
    };
