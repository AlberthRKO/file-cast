// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'requisition.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Requisition {

 String get id; String get caseName; DateTime get registeredAt; RequisitionStatus get status; int get imageEvidenceCount; int get videoEvidenceCount; bool get isSynchronized; String? get cud; String? get subjectName;
/// Create a copy of Requisition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequisitionCopyWith<Requisition> get copyWith => _$RequisitionCopyWithImpl<Requisition>(this as Requisition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Requisition&&(identical(other.id, id) || other.id == id)&&(identical(other.caseName, caseName) || other.caseName == caseName)&&(identical(other.registeredAt, registeredAt) || other.registeredAt == registeredAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageEvidenceCount, imageEvidenceCount) || other.imageEvidenceCount == imageEvidenceCount)&&(identical(other.videoEvidenceCount, videoEvidenceCount) || other.videoEvidenceCount == videoEvidenceCount)&&(identical(other.isSynchronized, isSynchronized) || other.isSynchronized == isSynchronized)&&(identical(other.cud, cud) || other.cud == cud)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName));
}


@override
int get hashCode => Object.hash(runtimeType,id,caseName,registeredAt,status,imageEvidenceCount,videoEvidenceCount,isSynchronized,cud,subjectName);

@override
String toString() {
  return 'Requisition(id: $id, caseName: $caseName, registeredAt: $registeredAt, status: $status, imageEvidenceCount: $imageEvidenceCount, videoEvidenceCount: $videoEvidenceCount, isSynchronized: $isSynchronized, cud: $cud, subjectName: $subjectName)';
}


}

/// @nodoc
abstract mixin class $RequisitionCopyWith<$Res>  {
  factory $RequisitionCopyWith(Requisition value, $Res Function(Requisition) _then) = _$RequisitionCopyWithImpl;
@useResult
$Res call({
 String id, String caseName, DateTime registeredAt, RequisitionStatus status, int imageEvidenceCount, int videoEvidenceCount, bool isSynchronized, String? cud, String? subjectName
});




}
/// @nodoc
class _$RequisitionCopyWithImpl<$Res>
    implements $RequisitionCopyWith<$Res> {
  _$RequisitionCopyWithImpl(this._self, this._then);

  final Requisition _self;
  final $Res Function(Requisition) _then;

/// Create a copy of Requisition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? caseName = null,Object? registeredAt = null,Object? status = null,Object? imageEvidenceCount = null,Object? videoEvidenceCount = null,Object? isSynchronized = null,Object? cud = freezed,Object? subjectName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,caseName: null == caseName ? _self.caseName : caseName // ignore: cast_nullable_to_non_nullable
as String,registeredAt: null == registeredAt ? _self.registeredAt : registeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RequisitionStatus,imageEvidenceCount: null == imageEvidenceCount ? _self.imageEvidenceCount : imageEvidenceCount // ignore: cast_nullable_to_non_nullable
as int,videoEvidenceCount: null == videoEvidenceCount ? _self.videoEvidenceCount : videoEvidenceCount // ignore: cast_nullable_to_non_nullable
as int,isSynchronized: null == isSynchronized ? _self.isSynchronized : isSynchronized // ignore: cast_nullable_to_non_nullable
as bool,cud: freezed == cud ? _self.cud : cud // ignore: cast_nullable_to_non_nullable
as String?,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Requisition].
extension RequisitionPatterns on Requisition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Requisition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Requisition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Requisition value)  $default,){
final _that = this;
switch (_that) {
case _Requisition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Requisition value)?  $default,){
final _that = this;
switch (_that) {
case _Requisition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String caseName,  DateTime registeredAt,  RequisitionStatus status,  int imageEvidenceCount,  int videoEvidenceCount,  bool isSynchronized,  String? cud,  String? subjectName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Requisition() when $default != null:
return $default(_that.id,_that.caseName,_that.registeredAt,_that.status,_that.imageEvidenceCount,_that.videoEvidenceCount,_that.isSynchronized,_that.cud,_that.subjectName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String caseName,  DateTime registeredAt,  RequisitionStatus status,  int imageEvidenceCount,  int videoEvidenceCount,  bool isSynchronized,  String? cud,  String? subjectName)  $default,) {final _that = this;
switch (_that) {
case _Requisition():
return $default(_that.id,_that.caseName,_that.registeredAt,_that.status,_that.imageEvidenceCount,_that.videoEvidenceCount,_that.isSynchronized,_that.cud,_that.subjectName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String caseName,  DateTime registeredAt,  RequisitionStatus status,  int imageEvidenceCount,  int videoEvidenceCount,  bool isSynchronized,  String? cud,  String? subjectName)?  $default,) {final _that = this;
switch (_that) {
case _Requisition() when $default != null:
return $default(_that.id,_that.caseName,_that.registeredAt,_that.status,_that.imageEvidenceCount,_that.videoEvidenceCount,_that.isSynchronized,_that.cud,_that.subjectName);case _:
  return null;

}
}

}

/// @nodoc


class _Requisition implements Requisition {
  const _Requisition({required this.id, required this.caseName, required this.registeredAt, required this.status, required this.imageEvidenceCount, required this.videoEvidenceCount, required this.isSynchronized, this.cud, this.subjectName});
  

@override final  String id;
@override final  String caseName;
@override final  DateTime registeredAt;
@override final  RequisitionStatus status;
@override final  int imageEvidenceCount;
@override final  int videoEvidenceCount;
@override final  bool isSynchronized;
@override final  String? cud;
@override final  String? subjectName;

/// Create a copy of Requisition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequisitionCopyWith<_Requisition> get copyWith => __$RequisitionCopyWithImpl<_Requisition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Requisition&&(identical(other.id, id) || other.id == id)&&(identical(other.caseName, caseName) || other.caseName == caseName)&&(identical(other.registeredAt, registeredAt) || other.registeredAt == registeredAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageEvidenceCount, imageEvidenceCount) || other.imageEvidenceCount == imageEvidenceCount)&&(identical(other.videoEvidenceCount, videoEvidenceCount) || other.videoEvidenceCount == videoEvidenceCount)&&(identical(other.isSynchronized, isSynchronized) || other.isSynchronized == isSynchronized)&&(identical(other.cud, cud) || other.cud == cud)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName));
}


@override
int get hashCode => Object.hash(runtimeType,id,caseName,registeredAt,status,imageEvidenceCount,videoEvidenceCount,isSynchronized,cud,subjectName);

@override
String toString() {
  return 'Requisition(id: $id, caseName: $caseName, registeredAt: $registeredAt, status: $status, imageEvidenceCount: $imageEvidenceCount, videoEvidenceCount: $videoEvidenceCount, isSynchronized: $isSynchronized, cud: $cud, subjectName: $subjectName)';
}


}

/// @nodoc
abstract mixin class _$RequisitionCopyWith<$Res> implements $RequisitionCopyWith<$Res> {
  factory _$RequisitionCopyWith(_Requisition value, $Res Function(_Requisition) _then) = __$RequisitionCopyWithImpl;
@override @useResult
$Res call({
 String id, String caseName, DateTime registeredAt, RequisitionStatus status, int imageEvidenceCount, int videoEvidenceCount, bool isSynchronized, String? cud, String? subjectName
});




}
/// @nodoc
class __$RequisitionCopyWithImpl<$Res>
    implements _$RequisitionCopyWith<$Res> {
  __$RequisitionCopyWithImpl(this._self, this._then);

  final _Requisition _self;
  final $Res Function(_Requisition) _then;

/// Create a copy of Requisition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? caseName = null,Object? registeredAt = null,Object? status = null,Object? imageEvidenceCount = null,Object? videoEvidenceCount = null,Object? isSynchronized = null,Object? cud = freezed,Object? subjectName = freezed,}) {
  return _then(_Requisition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,caseName: null == caseName ? _self.caseName : caseName // ignore: cast_nullable_to_non_nullable
as String,registeredAt: null == registeredAt ? _self.registeredAt : registeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RequisitionStatus,imageEvidenceCount: null == imageEvidenceCount ? _self.imageEvidenceCount : imageEvidenceCount // ignore: cast_nullable_to_non_nullable
as int,videoEvidenceCount: null == videoEvidenceCount ? _self.videoEvidenceCount : videoEvidenceCount // ignore: cast_nullable_to_non_nullable
as int,isSynchronized: null == isSynchronized ? _self.isSynchronized : isSynchronized // ignore: cast_nullable_to_non_nullable
as bool,cud: freezed == cud ? _self.cud : cud // ignore: cast_nullable_to_non_nullable
as String?,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
