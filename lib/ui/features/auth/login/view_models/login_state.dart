import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_state.freezed.dart';

enum LoginPhase { editing, submitting, success, error }

@freezed
abstract class LoginState with _$LoginState {
  const factory LoginState({
    @Default(LoginPhase.editing) LoginPhase phase,
    @Default('') String documentNumber,
    @Default('') String password,
    String? documentError,
    String? passwordError,
    String? errorMessage,
  }) = _LoginState;
}
