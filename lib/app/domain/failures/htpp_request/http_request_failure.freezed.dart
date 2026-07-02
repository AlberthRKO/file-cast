// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'http_request_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HttpRequestFailure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRequestFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HttpRequestFailure()';
}


}

/// @nodoc
class $HttpRequestFailureCopyWith<$Res>  {
$HttpRequestFailureCopyWith(HttpRequestFailure _, $Res Function(HttpRequestFailure) __);
}


/// Adds pattern-matching-related methods to [HttpRequestFailure].
extension HttpRequestFailurePatterns on HttpRequestFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( HttpRequestFailureNotFound value)?  notFound,TResult Function( HttpRequestFailureNetwork value)?  network,TResult Function( HttpRequestFailureUnauthorized value)?  unauthorized,TResult Function( HttpRequestFailureUnknow value)?  unknow,required TResult orElse(),}){
final _that = this;
switch (_that) {
case HttpRequestFailureNotFound() when notFound != null:
return notFound(_that);case HttpRequestFailureNetwork() when network != null:
return network(_that);case HttpRequestFailureUnauthorized() when unauthorized != null:
return unauthorized(_that);case HttpRequestFailureUnknow() when unknow != null:
return unknow(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( HttpRequestFailureNotFound value)  notFound,required TResult Function( HttpRequestFailureNetwork value)  network,required TResult Function( HttpRequestFailureUnauthorized value)  unauthorized,required TResult Function( HttpRequestFailureUnknow value)  unknow,}){
final _that = this;
switch (_that) {
case HttpRequestFailureNotFound():
return notFound(_that);case HttpRequestFailureNetwork():
return network(_that);case HttpRequestFailureUnauthorized():
return unauthorized(_that);case HttpRequestFailureUnknow():
return unknow(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( HttpRequestFailureNotFound value)?  notFound,TResult? Function( HttpRequestFailureNetwork value)?  network,TResult? Function( HttpRequestFailureUnauthorized value)?  unauthorized,TResult? Function( HttpRequestFailureUnknow value)?  unknow,}){
final _that = this;
switch (_that) {
case HttpRequestFailureNotFound() when notFound != null:
return notFound(_that);case HttpRequestFailureNetwork() when network != null:
return network(_that);case HttpRequestFailureUnauthorized() when unauthorized != null:
return unauthorized(_that);case HttpRequestFailureUnknow() when unknow != null:
return unknow(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  notFound,TResult Function()?  network,TResult Function()?  unauthorized,TResult Function()?  unknow,required TResult orElse(),}) {final _that = this;
switch (_that) {
case HttpRequestFailureNotFound() when notFound != null:
return notFound();case HttpRequestFailureNetwork() when network != null:
return network();case HttpRequestFailureUnauthorized() when unauthorized != null:
return unauthorized();case HttpRequestFailureUnknow() when unknow != null:
return unknow();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  notFound,required TResult Function()  network,required TResult Function()  unauthorized,required TResult Function()  unknow,}) {final _that = this;
switch (_that) {
case HttpRequestFailureNotFound():
return notFound();case HttpRequestFailureNetwork():
return network();case HttpRequestFailureUnauthorized():
return unauthorized();case HttpRequestFailureUnknow():
return unknow();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  notFound,TResult? Function()?  network,TResult? Function()?  unauthorized,TResult? Function()?  unknow,}) {final _that = this;
switch (_that) {
case HttpRequestFailureNotFound() when notFound != null:
return notFound();case HttpRequestFailureNetwork() when network != null:
return network();case HttpRequestFailureUnauthorized() when unauthorized != null:
return unauthorized();case HttpRequestFailureUnknow() when unknow != null:
return unknow();case _:
  return null;

}
}

}

/// @nodoc


class HttpRequestFailureNotFound implements HttpRequestFailure {
   HttpRequestFailureNotFound();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRequestFailureNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HttpRequestFailure.notFound()';
}


}




/// @nodoc


class HttpRequestFailureNetwork implements HttpRequestFailure {
   HttpRequestFailureNetwork();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRequestFailureNetwork);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HttpRequestFailure.network()';
}


}




/// @nodoc


class HttpRequestFailureUnauthorized implements HttpRequestFailure {
   HttpRequestFailureUnauthorized();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRequestFailureUnauthorized);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HttpRequestFailure.unauthorized()';
}


}




/// @nodoc


class HttpRequestFailureUnknow implements HttpRequestFailure {
   HttpRequestFailureUnknow();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HttpRequestFailureUnknow);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HttpRequestFailure.unknow()';
}


}




// dart format on
