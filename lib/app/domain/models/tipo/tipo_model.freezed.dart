// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tipo_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TipoModel {

 int? get id; String? get codigo; String? get nombre;
/// Create a copy of TipoModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TipoModelCopyWith<TipoModel> get copyWith => _$TipoModelCopyWithImpl<TipoModel>(this as TipoModel, _$identity);

  /// Serializes this TipoModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TipoModel&&(identical(other.id, id) || other.id == id)&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,codigo,nombre);

@override
String toString() {
  return 'TipoModel(id: $id, codigo: $codigo, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class $TipoModelCopyWith<$Res>  {
  factory $TipoModelCopyWith(TipoModel value, $Res Function(TipoModel) _then) = _$TipoModelCopyWithImpl;
@useResult
$Res call({
 int? id, String? codigo, String? nombre
});




}
/// @nodoc
class _$TipoModelCopyWithImpl<$Res>
    implements $TipoModelCopyWith<$Res> {
  _$TipoModelCopyWithImpl(this._self, this._then);

  final TipoModel _self;
  final $Res Function(TipoModel) _then;

/// Create a copy of TipoModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? codigo = freezed,Object? nombre = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,nombre: freezed == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TipoModel].
extension TipoModelPatterns on TipoModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TipoModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TipoModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TipoModel value)  $default,){
final _that = this;
switch (_that) {
case _TipoModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TipoModel value)?  $default,){
final _that = this;
switch (_that) {
case _TipoModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String? codigo,  String? nombre)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TipoModel() when $default != null:
return $default(_that.id,_that.codigo,_that.nombre);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String? codigo,  String? nombre)  $default,) {final _that = this;
switch (_that) {
case _TipoModel():
return $default(_that.id,_that.codigo,_that.nombre);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String? codigo,  String? nombre)?  $default,) {final _that = this;
switch (_that) {
case _TipoModel() when $default != null:
return $default(_that.id,_that.codigo,_that.nombre);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TipoModel implements TipoModel {
   _TipoModel({this.id, this.codigo, this.nombre});
  factory _TipoModel.fromJson(Map<String, dynamic> json) => _$TipoModelFromJson(json);

@override final  int? id;
@override final  String? codigo;
@override final  String? nombre;

/// Create a copy of TipoModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TipoModelCopyWith<_TipoModel> get copyWith => __$TipoModelCopyWithImpl<_TipoModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TipoModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TipoModel&&(identical(other.id, id) || other.id == id)&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,codigo,nombre);

@override
String toString() {
  return 'TipoModel(id: $id, codigo: $codigo, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class _$TipoModelCopyWith<$Res> implements $TipoModelCopyWith<$Res> {
  factory _$TipoModelCopyWith(_TipoModel value, $Res Function(_TipoModel) _then) = __$TipoModelCopyWithImpl;
@override @useResult
$Res call({
 int? id, String? codigo, String? nombre
});




}
/// @nodoc
class __$TipoModelCopyWithImpl<$Res>
    implements _$TipoModelCopyWith<$Res> {
  __$TipoModelCopyWithImpl(this._self, this._then);

  final _TipoModel _self;
  final $Res Function(_TipoModel) _then;

/// Create a copy of TipoModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? codigo = freezed,Object? nombre = freezed,}) {
  return _then(_TipoModel(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,nombre: freezed == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
