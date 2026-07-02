// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sign_in_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SignInFailure {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SignInFailure()';
}


}

/// @nodoc
class $SignInFailureCopyWith<$Res>  {
$SignInFailureCopyWith(SignInFailure _, $Res Function(SignInFailure) __);
}


/// Adds pattern-matching-related methods to [SignInFailure].
extension SignInFailurePatterns on SignInFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SignInFailureNotFound value)?  notFound,TResult Function( SignInFailureNetwork value)?  network,TResult Function( SignInFailureUnathorized value)?  unathorized,TResult Function( SignInFailureUnknown value)?  unknown,TResult Function( SignInFailureIpServices value)?  ip,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SignInFailureNotFound() when notFound != null:
return notFound(_that);case SignInFailureNetwork() when network != null:
return network(_that);case SignInFailureUnathorized() when unathorized != null:
return unathorized(_that);case SignInFailureUnknown() when unknown != null:
return unknown(_that);case SignInFailureIpServices() when ip != null:
return ip(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SignInFailureNotFound value)  notFound,required TResult Function( SignInFailureNetwork value)  network,required TResult Function( SignInFailureUnathorized value)  unathorized,required TResult Function( SignInFailureUnknown value)  unknown,required TResult Function( SignInFailureIpServices value)  ip,}){
final _that = this;
switch (_that) {
case SignInFailureNotFound():
return notFound(_that);case SignInFailureNetwork():
return network(_that);case SignInFailureUnathorized():
return unathorized(_that);case SignInFailureUnknown():
return unknown(_that);case SignInFailureIpServices():
return ip(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SignInFailureNotFound value)?  notFound,TResult? Function( SignInFailureNetwork value)?  network,TResult? Function( SignInFailureUnathorized value)?  unathorized,TResult? Function( SignInFailureUnknown value)?  unknown,TResult? Function( SignInFailureIpServices value)?  ip,}){
final _that = this;
switch (_that) {
case SignInFailureNotFound() when notFound != null:
return notFound(_that);case SignInFailureNetwork() when network != null:
return network(_that);case SignInFailureUnathorized() when unathorized != null:
return unathorized(_that);case SignInFailureUnknown() when unknown != null:
return unknown(_that);case SignInFailureIpServices() when ip != null:
return ip(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  notFound,TResult Function()?  network,TResult Function()?  unathorized,TResult Function()?  unknown,TResult Function()?  ip,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SignInFailureNotFound() when notFound != null:
return notFound();case SignInFailureNetwork() when network != null:
return network();case SignInFailureUnathorized() when unathorized != null:
return unathorized();case SignInFailureUnknown() when unknown != null:
return unknown();case SignInFailureIpServices() when ip != null:
return ip();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  notFound,required TResult Function()  network,required TResult Function()  unathorized,required TResult Function()  unknown,required TResult Function()  ip,}) {final _that = this;
switch (_that) {
case SignInFailureNotFound():
return notFound();case SignInFailureNetwork():
return network();case SignInFailureUnathorized():
return unathorized();case SignInFailureUnknown():
return unknown();case SignInFailureIpServices():
return ip();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  notFound,TResult? Function()?  network,TResult? Function()?  unathorized,TResult? Function()?  unknown,TResult? Function()?  ip,}) {final _that = this;
switch (_that) {
case SignInFailureNotFound() when notFound != null:
return notFound();case SignInFailureNetwork() when network != null:
return network();case SignInFailureUnathorized() when unathorized != null:
return unathorized();case SignInFailureUnknown() when unknown != null:
return unknown();case SignInFailureIpServices() when ip != null:
return ip();case _:
  return null;

}
}

}

/// @nodoc


class SignInFailureNotFound implements SignInFailure {
   SignInFailureNotFound();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInFailureNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SignInFailure.notFound()';
}


}




/// @nodoc


class SignInFailureNetwork implements SignInFailure {
   SignInFailureNetwork();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInFailureNetwork);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SignInFailure.network()';
}


}




/// @nodoc


class SignInFailureUnathorized implements SignInFailure {
   SignInFailureUnathorized();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInFailureUnathorized);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SignInFailure.unathorized()';
}


}




/// @nodoc


class SignInFailureUnknown implements SignInFailure {
   SignInFailureUnknown();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInFailureUnknown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SignInFailure.unknown()';
}


}




/// @nodoc


class SignInFailureIpServices implements SignInFailure {
   SignInFailureIpServices();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignInFailureIpServices);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SignInFailure.ip()';
}


}




// dart format on
