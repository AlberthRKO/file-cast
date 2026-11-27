// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LoginState {

 LoginPhase get phase; String get documentNumber; String get password; String? get documentError; String? get passwordError; String? get errorMessage; AuthChallenge? get challenge; bool get trustedDevice; int get challengeRevision; bool get verifyingCode; bool get sendingCode;
/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginStateCopyWith<LoginState> get copyWith => _$LoginStateCopyWithImpl<LoginState>(this as LoginState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.documentNumber, documentNumber) || other.documentNumber == documentNumber)&&(identical(other.password, password) || other.password == password)&&(identical(other.documentError, documentError) || other.documentError == documentError)&&(identical(other.passwordError, passwordError) || other.passwordError == passwordError)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.challenge, challenge) || other.challenge == challenge)&&(identical(other.trustedDevice, trustedDevice) || other.trustedDevice == trustedDevice)&&(identical(other.challengeRevision, challengeRevision) || other.challengeRevision == challengeRevision)&&(identical(other.verifyingCode, verifyingCode) || other.verifyingCode == verifyingCode)&&(identical(other.sendingCode, sendingCode) || other.sendingCode == sendingCode));
}


@override
int get hashCode => Object.hash(runtimeType,phase,documentNumber,password,documentError,passwordError,errorMessage,challenge,trustedDevice,challengeRevision,verifyingCode,sendingCode);

@override
String toString() {
  return 'LoginState(phase: $phase, documentNumber: $documentNumber, password: $password, documentError: $documentError, passwordError: $passwordError, errorMessage: $errorMessage, challenge: $challenge, trustedDevice: $trustedDevice, challengeRevision: $challengeRevision, verifyingCode: $verifyingCode, sendingCode: $sendingCode)';
}


}

/// @nodoc
abstract mixin class $LoginStateCopyWith<$Res>  {
  factory $LoginStateCopyWith(LoginState value, $Res Function(LoginState) _then) = _$LoginStateCopyWithImpl;
@useResult
$Res call({
 LoginPhase phase, String documentNumber, String password, String? documentError, String? passwordError, String? errorMessage, AuthChallenge? challenge, bool trustedDevice, int challengeRevision, bool verifyingCode, bool sendingCode
});


$AuthChallengeCopyWith<$Res>? get challenge;

}
/// @nodoc
class _$LoginStateCopyWithImpl<$Res>
    implements $LoginStateCopyWith<$Res> {
  _$LoginStateCopyWithImpl(this._self, this._then);

  final LoginState _self;
  final $Res Function(LoginState) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? documentNumber = null,Object? password = null,Object? documentError = freezed,Object? passwordError = freezed,Object? errorMessage = freezed,Object? challenge = freezed,Object? trustedDevice = null,Object? challengeRevision = null,Object? verifyingCode = null,Object? sendingCode = null,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LoginPhase,documentNumber: null == documentNumber ? _self.documentNumber : documentNumber // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,documentError: freezed == documentError ? _self.documentError : documentError // ignore: cast_nullable_to_non_nullable
as String?,passwordError: freezed == passwordError ? _self.passwordError : passwordError // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,challenge: freezed == challenge ? _self.challenge : challenge // ignore: cast_nullable_to_non_nullable
as AuthChallenge?,trustedDevice: null == trustedDevice ? _self.trustedDevice : trustedDevice // ignore: cast_nullable_to_non_nullable
as bool,challengeRevision: null == challengeRevision ? _self.challengeRevision : challengeRevision // ignore: cast_nullable_to_non_nullable
as int,verifyingCode: null == verifyingCode ? _self.verifyingCode : verifyingCode // ignore: cast_nullable_to_non_nullable
as bool,sendingCode: null == sendingCode ? _self.sendingCode : sendingCode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthChallengeCopyWith<$Res>? get challenge {
    if (_self.challenge == null) {
    return null;
  }

  return $AuthChallengeCopyWith<$Res>(_self.challenge!, (value) {
    return _then(_self.copyWith(challenge: value));
  });
}
}


/// Adds pattern-matching-related methods to [LoginState].
extension LoginStatePatterns on LoginState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginState value)  $default,){
final _that = this;
switch (_that) {
case _LoginState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginState value)?  $default,){
final _that = this;
switch (_that) {
case _LoginState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoginPhase phase,  String documentNumber,  String password,  String? documentError,  String? passwordError,  String? errorMessage,  AuthChallenge? challenge,  bool trustedDevice,  int challengeRevision,  bool verifyingCode,  bool sendingCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginState() when $default != null:
return $default(_that.phase,_that.documentNumber,_that.password,_that.documentError,_that.passwordError,_that.errorMessage,_that.challenge,_that.trustedDevice,_that.challengeRevision,_that.verifyingCode,_that.sendingCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoginPhase phase,  String documentNumber,  String password,  String? documentError,  String? passwordError,  String? errorMessage,  AuthChallenge? challenge,  bool trustedDevice,  int challengeRevision,  bool verifyingCode,  bool sendingCode)  $default,) {final _that = this;
switch (_that) {
case _LoginState():
return $default(_that.phase,_that.documentNumber,_that.password,_that.documentError,_that.passwordError,_that.errorMessage,_that.challenge,_that.trustedDevice,_that.challengeRevision,_that.verifyingCode,_that.sendingCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoginPhase phase,  String documentNumber,  String password,  String? documentError,  String? passwordError,  String? errorMessage,  AuthChallenge? challenge,  bool trustedDevice,  int challengeRevision,  bool verifyingCode,  bool sendingCode)?  $default,) {final _that = this;
switch (_that) {
case _LoginState() when $default != null:
return $default(_that.phase,_that.documentNumber,_that.password,_that.documentError,_that.passwordError,_that.errorMessage,_that.challenge,_that.trustedDevice,_that.challengeRevision,_that.verifyingCode,_that.sendingCode);case _:
  return null;

}
}

}

/// @nodoc


class _LoginState implements LoginState {
  const _LoginState({this.phase = LoginPhase.editing, this.documentNumber = '', this.password = '', this.documentError, this.passwordError, this.errorMessage, this.challenge, this.trustedDevice = true, this.challengeRevision = 0, this.verifyingCode = false, this.sendingCode = false});
  

@override@JsonKey() final  LoginPhase phase;
@override@JsonKey() final  String documentNumber;
@override@JsonKey() final  String password;
@override final  String? documentError;
@override final  String? passwordError;
@override final  String? errorMessage;
@override final  AuthChallenge? challenge;
@override@JsonKey() final  bool trustedDevice;
@override@JsonKey() final  int challengeRevision;
@override@JsonKey() final  bool verifyingCode;
@override@JsonKey() final  bool sendingCode;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginStateCopyWith<_LoginState> get copyWith => __$LoginStateCopyWithImpl<_LoginState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.documentNumber, documentNumber) || other.documentNumber == documentNumber)&&(identical(other.password, password) || other.password == password)&&(identical(other.documentError, documentError) || other.documentError == documentError)&&(identical(other.passwordError, passwordError) || other.passwordError == passwordError)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.challenge, challenge) || other.challenge == challenge)&&(identical(other.trustedDevice, trustedDevice) || other.trustedDevice == trustedDevice)&&(identical(other.challengeRevision, challengeRevision) || other.challengeRevision == challengeRevision)&&(identical(other.verifyingCode, verifyingCode) || other.verifyingCode == verifyingCode)&&(identical(other.sendingCode, sendingCode) || other.sendingCode == sendingCode));
}


@override
int get hashCode => Object.hash(runtimeType,phase,documentNumber,password,documentError,passwordError,errorMessage,challenge,trustedDevice,challengeRevision,verifyingCode,sendingCode);

@override
String toString() {
  return 'LoginState(phase: $phase, documentNumber: $documentNumber, password: $password, documentError: $documentError, passwordError: $passwordError, errorMessage: $errorMessage, challenge: $challenge, trustedDevice: $trustedDevice, challengeRevision: $challengeRevision, verifyingCode: $verifyingCode, sendingCode: $sendingCode)';
}


}

/// @nodoc
abstract mixin class _$LoginStateCopyWith<$Res> implements $LoginStateCopyWith<$Res> {
  factory _$LoginStateCopyWith(_LoginState value, $Res Function(_LoginState) _then) = __$LoginStateCopyWithImpl;
@override @useResult
$Res call({
 LoginPhase phase, String documentNumber, String password, String? documentError, String? passwordError, String? errorMessage, AuthChallenge? challenge, bool trustedDevice, int challengeRevision, bool verifyingCode, bool sendingCode
});


@override $AuthChallengeCopyWith<$Res>? get challenge;

}
/// @nodoc
class __$LoginStateCopyWithImpl<$Res>
    implements _$LoginStateCopyWith<$Res> {
  __$LoginStateCopyWithImpl(this._self, this._then);

  final _LoginState _self;
  final $Res Function(_LoginState) _then;

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? documentNumber = null,Object? password = null,Object? documentError = freezed,Object? passwordError = freezed,Object? errorMessage = freezed,Object? challenge = freezed,Object? trustedDevice = null,Object? challengeRevision = null,Object? verifyingCode = null,Object? sendingCode = null,}) {
  return _then(_LoginState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LoginPhase,documentNumber: null == documentNumber ? _self.documentNumber : documentNumber // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,documentError: freezed == documentError ? _self.documentError : documentError // ignore: cast_nullable_to_non_nullable
as String?,passwordError: freezed == passwordError ? _self.passwordError : passwordError // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,challenge: freezed == challenge ? _self.challenge : challenge // ignore: cast_nullable_to_non_nullable
as AuthChallenge?,trustedDevice: null == trustedDevice ? _self.trustedDevice : trustedDevice // ignore: cast_nullable_to_non_nullable
as bool,challengeRevision: null == challengeRevision ? _self.challengeRevision : challengeRevision // ignore: cast_nullable_to_non_nullable
as int,verifyingCode: null == verifyingCode ? _self.verifyingCode : verifyingCode // ignore: cast_nullable_to_non_nullable
as bool,sendingCode: null == sendingCode ? _self.sendingCode : sendingCode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LoginState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthChallengeCopyWith<$Res>? get challenge {
    if (_self.challenge == null) {
    return null;
  }

  return $AuthChallengeCopyWith<$Res>(_self.challenge!, (value) {
    return _then(_self.copyWith(challenge: value));
  });
}
}

// dart format on
