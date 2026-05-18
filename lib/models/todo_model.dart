import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'converters.dart';

part 'todo_model.freezed.dart';
part 'todo_model.g.dart';

@freezed
abstract class TodoModel with _$TodoModel {
  const factory TodoModel({
    required String id,
    required String userId,
    required String title,
    @Default('') String description,
    @Default(false) bool isCompleted,
    @NullableTimestampConverter() DateTime? dueDate,
    String? dueTime,
    @Default('') String category,
    @Default('') String priority,
  }) = _TodoModel;

  factory TodoModel.fromJson(Map<String, dynamic> json) => _$TodoModelFromJson(json);
}
