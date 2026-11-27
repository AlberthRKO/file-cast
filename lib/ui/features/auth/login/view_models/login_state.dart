import 'package:file_cast/domain/models/auth_challenge.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

enum LoginPhase { editing, submitting, challenge, success, error }

@freezed
abstract class LoginState with _$LoginState {
  const factory LoginState({
    @Default(LoginPhase.editing) LoginPhase phase,
    @Default('') String documentNumber,
    @Default('') String password,
    String? documentError,
    String? passwordError,
    String? errorMessage,
    AuthChallenge? challenge,
    @Default(true) bool trustedDevice,
    @Default(0) int challengeRevision,
    @Default(false) bool verifyingCode,
    @Default(false) bool sendingCode,
  }) = _LoginState;
}
