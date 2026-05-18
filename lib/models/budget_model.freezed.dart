// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'budget_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BudgetModel {

 double get limitAmount; double get amountSpent; double get payAmount; double get bankAmount; double get cashAmount; String get currency; List<Map<String, dynamic>> get monthlyDeductions;
/// Create a copy of BudgetModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BudgetModelCopyWith<BudgetModel> get copyWith => _$BudgetModelCopyWithImpl<BudgetModel>(this as BudgetModel, _$identity);

  /// Serializes this BudgetModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BudgetModel&&(identical(other.limitAmount, limitAmount) || other.limitAmount == limitAmount)&&(identical(other.amountSpent, amountSpent) || other.amountSpent == amountSpent)&&(identical(other.payAmount, payAmount) || other.payAmount == payAmount)&&(identical(other.bankAmount, bankAmount) || other.bankAmount == bankAmount)&&(identical(other.cashAmount, cashAmount) || other.cashAmount == cashAmount)&&(identical(other.currency, currency) || other.currency == currency)&&const DeepCollectionEquality().equals(other.monthlyDeductions, monthlyDeductions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,limitAmount,amountSpent,payAmount,bankAmount,cashAmount,currency,const DeepCollectionEquality().hash(monthlyDeductions));

@override
String toString() {
  return 'BudgetModel(limitAmount: $limitAmount, amountSpent: $amountSpent, payAmount: $payAmount, bankAmount: $bankAmount, cashAmount: $cashAmount, currency: $currency, monthlyDeductions: $monthlyDeductions)';
}


}

/// @nodoc
abstract mixin class $BudgetModelCopyWith<$Res>  {
  factory $BudgetModelCopyWith(BudgetModel value, $Res Function(BudgetModel) _then) = _$BudgetModelCopyWithImpl;
@useResult
$Res call({
 double limitAmount, double amountSpent, double payAmount, double bankAmount, double cashAmount, String currency, List<Map<String, dynamic>> monthlyDeductions
});




}
/// @nodoc
class _$BudgetModelCopyWithImpl<$Res>
    implements $BudgetModelCopyWith<$Res> {
  _$BudgetModelCopyWithImpl(this._self, this._then);

  final BudgetModel _self;
  final $Res Function(BudgetModel) _then;

/// Create a copy of BudgetModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? limitAmount = null,Object? amountSpent = null,Object? payAmount = null,Object? bankAmount = null,Object? cashAmount = null,Object? currency = null,Object? monthlyDeductions = null,}) {
  return _then(_self.copyWith(
limitAmount: null == limitAmount ? _self.limitAmount : limitAmount // ignore: cast_nullable_to_non_nullable
as double,amountSpent: null == amountSpent ? _self.amountSpent : amountSpent // ignore: cast_nullable_to_non_nullable
as double,payAmount: null == payAmount ? _self.payAmount : payAmount // ignore: cast_nullable_to_non_nullable
as double,bankAmount: null == bankAmount ? _self.bankAmount : bankAmount // ignore: cast_nullable_to_non_nullable
as double,cashAmount: null == cashAmount ? _self.cashAmount : cashAmount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,monthlyDeductions: null == monthlyDeductions ? _self.monthlyDeductions : monthlyDeductions // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [BudgetModel].
extension BudgetModelPatterns on BudgetModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BudgetModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BudgetModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BudgetModel value)  $default,){
final _that = this;
switch (_that) {
case _BudgetModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BudgetModel value)?  $default,){
final _that = this;
switch (_that) {
case _BudgetModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double limitAmount,  double amountSpent,  double payAmount,  double bankAmount,  double cashAmount,  String currency,  List<Map<String, dynamic>> monthlyDeductions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BudgetModel() when $default != null:
return $default(_that.limitAmount,_that.amountSpent,_that.payAmount,_that.bankAmount,_that.cashAmount,_that.currency,_that.monthlyDeductions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double limitAmount,  double amountSpent,  double payAmount,  double bankAmount,  double cashAmount,  String currency,  List<Map<String, dynamic>> monthlyDeductions)  $default,) {final _that = this;
switch (_that) {
case _BudgetModel():
return $default(_that.limitAmount,_that.amountSpent,_that.payAmount,_that.bankAmount,_that.cashAmount,_that.currency,_that.monthlyDeductions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double limitAmount,  double amountSpent,  double payAmount,  double bankAmount,  double cashAmount,  String currency,  List<Map<String, dynamic>> monthlyDeductions)?  $default,) {final _that = this;
switch (_that) {
case _BudgetModel() when $default != null:
return $default(_that.limitAmount,_that.amountSpent,_that.payAmount,_that.bankAmount,_that.cashAmount,_that.currency,_that.monthlyDeductions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BudgetModel implements BudgetModel {
  const _BudgetModel({this.limitAmount = 0.0, this.amountSpent = 0.0, this.payAmount = 0.0, this.bankAmount = 0.0, this.cashAmount = 0.0, this.currency = '\$', final  List<Map<String, dynamic>> monthlyDeductions = const []}): _monthlyDeductions = monthlyDeductions;
  factory _BudgetModel.fromJson(Map<String, dynamic> json) => _$BudgetModelFromJson(json);

@override@JsonKey() final  double limitAmount;
@override@JsonKey() final  double amountSpent;
@override@JsonKey() final  double payAmount;
@override@JsonKey() final  double bankAmount;
@override@JsonKey() final  double cashAmount;
@override@JsonKey() final  String currency;
 final  List<Map<String, dynamic>> _monthlyDeductions;
@override@JsonKey() List<Map<String, dynamic>> get monthlyDeductions {
  if (_monthlyDeductions is EqualUnmodifiableListView) return _monthlyDeductions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_monthlyDeductions);
}


/// Create a copy of BudgetModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BudgetModelCopyWith<_BudgetModel> get copyWith => __$BudgetModelCopyWithImpl<_BudgetModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BudgetModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BudgetModel&&(identical(other.limitAmount, limitAmount) || other.limitAmount == limitAmount)&&(identical(other.amountSpent, amountSpent) || other.amountSpent == amountSpent)&&(identical(other.payAmount, payAmount) || other.payAmount == payAmount)&&(identical(other.bankAmount, bankAmount) || other.bankAmount == bankAmount)&&(identical(other.cashAmount, cashAmount) || other.cashAmount == cashAmount)&&(identical(other.currency, currency) || other.currency == currency)&&const DeepCollectionEquality().equals(other._monthlyDeductions, _monthlyDeductions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,limitAmount,amountSpent,payAmount,bankAmount,cashAmount,currency,const DeepCollectionEquality().hash(_monthlyDeductions));

@override
String toString() {
  return 'BudgetModel(limitAmount: $limitAmount, amountSpent: $amountSpent, payAmount: $payAmount, bankAmount: $bankAmount, cashAmount: $cashAmount, currency: $currency, monthlyDeductions: $monthlyDeductions)';
}


}

/// @nodoc
abstract mixin class _$BudgetModelCopyWith<$Res> implements $BudgetModelCopyWith<$Res> {
  factory _$BudgetModelCopyWith(_BudgetModel value, $Res Function(_BudgetModel) _then) = __$BudgetModelCopyWithImpl;
@override @useResult
$Res call({
 double limitAmount, double amountSpent, double payAmount, double bankAmount, double cashAmount, String currency, List<Map<String, dynamic>> monthlyDeductions
});




}
/// @nodoc
class __$BudgetModelCopyWithImpl<$Res>
    implements _$BudgetModelCopyWith<$Res> {
  __$BudgetModelCopyWithImpl(this._self, this._then);

  final _BudgetModel _self;
  final $Res Function(_BudgetModel) _then;

/// Create a copy of BudgetModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? limitAmount = null,Object? amountSpent = null,Object? payAmount = null,Object? bankAmount = null,Object? cashAmount = null,Object? currency = null,Object? monthlyDeductions = null,}) {
  return _then(_BudgetModel(
limitAmount: null == limitAmount ? _self.limitAmount : limitAmount // ignore: cast_nullable_to_non_nullable
as double,amountSpent: null == amountSpent ? _self.amountSpent : amountSpent // ignore: cast_nullable_to_non_nullable
as double,payAmount: null == payAmount ? _self.payAmount : payAmount // ignore: cast_nullable_to_non_nullable
as double,bankAmount: null == bankAmount ? _self.bankAmount : bankAmount // ignore: cast_nullable_to_non_nullable
as double,cashAmount: null == cashAmount ? _self.cashAmount : cashAmount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,monthlyDeductions: null == monthlyDeductions ? _self._monthlyDeductions : monthlyDeductions // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}

// dart format on
