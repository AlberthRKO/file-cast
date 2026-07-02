// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErrorModel {

 dynamic get error; String? get message; dynamic get response; int? get status;
/// Create a copy of ErrorModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorModelCopyWith<ErrorModel> get copyWith => _$ErrorModelCopyWithImpl<ErrorModel>(this as ErrorModel, _$identity);

  /// Serializes this ErrorModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorModel&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.response, response)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(error),message,const DeepCollectionEquality().hash(response),status);

@override
String toString() {
  return 'ErrorModel(error: $error, message: $message, response: $response, status: $status)';
}


}

/// @nodoc
abstract mixin class $ErrorModelCopyWith<$Res>  {
  factory $ErrorModelCopyWith(ErrorModel value, $Res Function(ErrorModel) _then) = _$ErrorModelCopyWithImpl;
@useResult
$Res call({
 dynamic error, String? message, dynamic response, int? status
});




}
/// @nodoc
class _$ErrorModelCopyWithImpl<$Res>
    implements $ErrorModelCopyWith<$Res> {
  _$ErrorModelCopyWithImpl(this._self, this._then);

  final ErrorModel _self;
  final $Res Function(ErrorModel) _then;

/// Create a copy of ErrorModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = freezed,Object? message = freezed,Object? response = freezed,Object? status = freezed,}) {
  return _then(_self.copyWith(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as dynamic,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,response: freezed == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as dynamic,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ErrorModel].
extension ErrorModelPatterns on ErrorModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ErrorModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ErrorModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ErrorModel value)  $default,){
final _that = this;
switch (_that) {
case _ErrorModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ErrorModel value)?  $default,){
final _that = this;
switch (_that) {
case _ErrorModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( dynamic error,  String? message,  dynamic response,  int? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ErrorModel() when $default != null:
return $default(_that.error,_that.message,_that.response,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( dynamic error,  String? message,  dynamic response,  int? status)  $default,) {final _that = this;
switch (_that) {
case _ErrorModel():
return $default(_that.error,_that.message,_that.response,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( dynamic error,  String? message,  dynamic response,  int? status)?  $default,) {final _that = this;
switch (_that) {
case _ErrorModel() when $default != null:
return $default(_that.error,_that.message,_that.response,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ErrorModel implements ErrorModel {
   _ErrorModel({this.error, this.message, this.response, this.status});
  factory _ErrorModel.fromJson(Map<String, dynamic> json) => _$ErrorModelFromJson(json);

@override final  dynamic error;
@override final  String? message;
@override final  dynamic response;
@override final  int? status;

/// Create a copy of ErrorModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorModelCopyWith<_ErrorModel> get copyWith => __$ErrorModelCopyWithImpl<_ErrorModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ErrorModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ErrorModel&&const DeepCollectionEquality().equals(other.error, error)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.response, response)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(error),message,const DeepCollectionEquality().hash(response),status);

@override
String toString() {
  return 'ErrorModel(error: $error, message: $message, response: $response, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ErrorModelCopyWith<$Res> implements $ErrorModelCopyWith<$Res> {
  factory _$ErrorModelCopyWith(_ErrorModel value, $Res Function(_ErrorModel) _then) = __$ErrorModelCopyWithImpl;
@override @useResult
$Res call({
 dynamic error, String? message, dynamic response, int? status
});




}
/// @nodoc
class __$ErrorModelCopyWithImpl<$Res>
    implements _$ErrorModelCopyWith<$Res> {
  __$ErrorModelCopyWithImpl(this._self, this._then);

  final _ErrorModel _self;
  final $Res Function(_ErrorModel) _then;

/// Create a copy of ErrorModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = freezed,Object? message = freezed,Object? response = freezed,Object? status = freezed,}) {
  return _then(_ErrorModel(
error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as dynamic,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,response: freezed == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as dynamic,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
