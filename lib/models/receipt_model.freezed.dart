// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'receipt_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReceiptModel {

 String get id; String get userId; String get merchantName; double get totalCost;@TimestampConverter() DateTime get date; List<String> get items;
/// Create a copy of ReceiptModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceiptModelCopyWith<ReceiptModel> get copyWith => _$ReceiptModelCopyWithImpl<ReceiptModel>(this as ReceiptModel, _$identity);

  /// Serializes this ReceiptModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReceiptModel&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.merchantName, merchantName) || other.merchantName == merchantName)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,merchantName,totalCost,date,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'ReceiptModel(id: $id, userId: $userId, merchantName: $merchantName, totalCost: $totalCost, date: $date, items: $items)';
}


}

/// @nodoc
abstract mixin class $ReceiptModelCopyWith<$Res>  {
  factory $ReceiptModelCopyWith(ReceiptModel value, $Res Function(ReceiptModel) _then) = _$ReceiptModelCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String merchantName, double totalCost,@TimestampConverter() DateTime date, List<String> items
});




}
/// @nodoc
class _$ReceiptModelCopyWithImpl<$Res>
    implements $ReceiptModelCopyWith<$Res> {
  _$ReceiptModelCopyWithImpl(this._self, this._then);

  final ReceiptModel _self;
  final $Res Function(ReceiptModel) _then;

/// Create a copy of ReceiptModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? merchantName = null,Object? totalCost = null,Object? date = null,Object? items = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,merchantName: null == merchantName ? _self.merchantName : merchantName // ignore: cast_nullable_to_non_nullable
as String,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReceiptModel].
extension ReceiptModelPatterns on ReceiptModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReceiptModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReceiptModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReceiptModel value)  $default,){
final _that = this;
switch (_that) {
case _ReceiptModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReceiptModel value)?  $default,){
final _that = this;
switch (_that) {
case _ReceiptModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String merchantName,  double totalCost, @TimestampConverter()  DateTime date,  List<String> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReceiptModel() when $default != null:
return $default(_that.id,_that.userId,_that.merchantName,_that.totalCost,_that.date,_that.items);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String merchantName,  double totalCost, @TimestampConverter()  DateTime date,  List<String> items)  $default,) {final _that = this;
switch (_that) {
case _ReceiptModel():
return $default(_that.id,_that.userId,_that.merchantName,_that.totalCost,_that.date,_that.items);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String merchantName,  double totalCost, @TimestampConverter()  DateTime date,  List<String> items)?  $default,) {final _that = this;
switch (_that) {
case _ReceiptModel() when $default != null:
return $default(_that.id,_that.userId,_that.merchantName,_that.totalCost,_that.date,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReceiptModel implements ReceiptModel {
  const _ReceiptModel({required this.id, required this.userId, required this.merchantName, required this.totalCost, @TimestampConverter() required this.date, final  List<String> items = const []}): _items = items;
  factory _ReceiptModel.fromJson(Map<String, dynamic> json) => _$ReceiptModelFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String merchantName;
@override final  double totalCost;
@override@TimestampConverter() final  DateTime date;
 final  List<String> _items;
@override@JsonKey() List<String> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of ReceiptModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceiptModelCopyWith<_ReceiptModel> get copyWith => __$ReceiptModelCopyWithImpl<_ReceiptModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceiptModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReceiptModel&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.merchantName, merchantName) || other.merchantName == merchantName)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,merchantName,totalCost,date,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'ReceiptModel(id: $id, userId: $userId, merchantName: $merchantName, totalCost: $totalCost, date: $date, items: $items)';
}


}

/// @nodoc
abstract mixin class _$ReceiptModelCopyWith<$Res> implements $ReceiptModelCopyWith<$Res> {
  factory _$ReceiptModelCopyWith(_ReceiptModel value, $Res Function(_ReceiptModel) _then) = __$ReceiptModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String merchantName, double totalCost,@TimestampConverter() DateTime date, List<String> items
});




}
/// @nodoc
class __$ReceiptModelCopyWithImpl<$Res>
    implements _$ReceiptModelCopyWith<$Res> {
  __$ReceiptModelCopyWithImpl(this._self, this._then);

  final _ReceiptModel _self;
  final $Res Function(_ReceiptModel) _then;

/// Create a copy of ReceiptModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? merchantName = null,Object? totalCost = null,Object? date = null,Object? items = null,}) {
  return _then(_ReceiptModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,merchantName: null == merchantName ? _self.merchantName : merchantName // ignore: cast_nullable_to_non_nullable
as String,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
