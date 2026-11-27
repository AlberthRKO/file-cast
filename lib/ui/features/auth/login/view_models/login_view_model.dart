import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/models/auth_login_result.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/ui/features/auth/login/view_models/login_state.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required AuthRepository authRepository,
    required AuthSessionController sessionController,
  }) : _authRepository = authRepository,
       _sessionController = sessionController;

  final AuthRepository _authRepository;
  final AuthSessionController _sessionController;

  LoginState _state = const LoginState();
  LoginState get state => _state;

  UserEntity? _pendingAuthenticatedUser;

  bool get isSubmitting => _state.phase == LoginPhase.submitting;

  void updateDocument(String value) {
    _pendingAuthenticatedUser = null;
    _state = _state.copyWith(challenge: null);
    _state = _state.copyWith(
      documentNumber: value,
      documentError: null,
      errorMessage: null,
      phase: LoginPhase.editing,
    );
    notifyListeners();
  }

  void updatePassword(String value) {
    _pendingAuthenticatedUser = null;
    _state = _state.copyWith(challenge: null);
    _state = _state.copyWith(
      password: value,
      passwordError: null,
      errorMessage: null,
      phase: LoginPhase.editing,
    );
    notifyListeners();
  }

  String? validateDocument(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Número de Documento vacío';
    }
    if (text.contains(' ')) {
      return 'El número de documento no debe contener espacios.';
    }
    return null;
  }

  String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Contraseña Vacía';
    }
    if (text.startsWith(' ') || text.endsWith(' ')) {
      return 'No debe haber espacios en blanco al principio ni al final de la contraseña.';
    }
    return null;
  }

  Future<void> submit() async {
    if (isSubmitting || _pendingAuthenticatedUser != null) return;

    final documentError = validateDocument(_state.documentNumber);
    final passwordError = validatePassword(_state.password);
    if (documentError != null || passwordError != null) {
      _state = _state.copyWith(
        documentError: documentError,
        passwordError: passwordError,
        errorMessage: null,
        phase: LoginPhase.error,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      documentError: null,
      passwordError: null,
      errorMessage: null,
      phase: LoginPhase.submitting,
    );
    notifyListeners();

    final result = await _authRepository.login(
      usuario: _state.documentNumber,
      password: _state.password,
    );

    switch (result) {
      case Left(leftValue: final failure):
        _pendingAuthenticatedUser = null;
        _state = _state.copyWith(
          errorMessage: _messageFromFailure(failure),
          phase: LoginPhase.error,
        );
      case Right(rightValue: final loginResult):
        switch (loginResult) {
          case AuthenticatedLogin(user: final user):
            _pendingAuthenticatedUser = user;
            _state = _state.copyWith(phase: LoginPhase.success);
          case ChallengedLogin(challenge: final challenge):
            _state = _state.copyWith(
              phase: LoginPhase.challenge,
              challenge: challenge,
              trustedDevice: true,
              challengeRevision: _state.challengeRevision + 1,
            );
        }
    }
    notifyListeners();
  }

  void setTrustedDevice(bool value) {
    _state = _state.copyWith(trustedDevice: value);
    notifyListeners();
  }

  Future<String?> listenForSmsCode() => _authRepository.listenForLoginSmsCode();

  Future<void> stopSmsCodeListener() =>
      _authRepository.stopLoginSmsCodeListener();

  Future<void> openTelegram() async {
    final challenge = _state.challenge;
    if (challenge?.medio != 2) return;
    try {
      final opened = await _authRepository.openTelegram(challenge?.url);
      if (!opened) {
        _state = _state.copyWith(
          errorMessage: 'No se pudo abrir Telegram en este dispositivo.',
        );
        notifyListeners();
      }
    } on Object {
      _state = _state.copyWith(
        errorMessage: 'No se pudo abrir Telegram en este dispositivo.',
      );
      notifyListeners();
    }
  }

  void cancelChallenge() {
    _state = _state.copyWith(
      phase: LoginPhase.editing,
      challenge: null,
      errorMessage: null,
    );
    notifyListeners();
  }

  Future<void> sendCode(int medio) async {
    final challenge = _state.challenge;
    if (challenge == null || _state.sendingCode || _state.verifyingCode) return;
    _state = _state.copyWith(sendingCode: true, errorMessage: null);
    notifyListeners();
    final result = await _authRepository.sendLoginCode(challenge, medio);
    switch (result) {
      case Left(leftValue: final failure):
        _state = _state.copyWith(errorMessage: _messageFromFailure(failure));
      case Right(rightValue: final next):
        _state = _state.copyWith(
          challenge: next,
          challengeRevision: _state.challengeRevision + 1,
          errorMessage: null,
        );
    }
    _state = _state.copyWith(sendingCode: false);
    notifyListeners();
  }

  Future<void> confirmCode(String code) async {
    final challenge = _state.challenge;
    if (challenge == null || _state.verifyingCode || _state.sendingCode) return;
    if (challenge.medio == null) {
      _state = _state.copyWith(
        errorMessage: 'Selecciona un medio de verificación.',
      );
      notifyListeners();
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _state = _state.copyWith(
        errorMessage: 'Ingresa un código de seis dígitos.',
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(verifyingCode: true, errorMessage: null);
    notifyListeners();
    final result = await _authRepository.confirmLoginCode(
      challenge: challenge,
      code: code,
      trustedDevice: _state.trustedDevice,
    );
    switch (result) {
      case Left(leftValue: final failure):
        _state = _state.copyWith(errorMessage: _messageFromFailure(failure));
      case Right(rightValue: final user):
        _pendingAuthenticatedUser = user;
        _state = _state.copyWith(phase: LoginPhase.success, challenge: null);
    }
    _state = _state.copyWith(verifyingCode: false);
    notifyListeners();
  }

  /// Completes the session after the UI has presented the successful response.
  ///
  /// Keeping this transition separate lets the login View show the global
  /// feedback sheet before the router redirects to the protected area.
  void completeAuthentication() {
    final user = _pendingAuthenticatedUser;
    if (user == null) return;
    _pendingAuthenticatedUser = null;
    _sessionController.authenticated(user);
  }

  String _messageFromFailure(Failure failure) {
    return switch (failure) {
      ServerFailure(message: final message) =>
        message ?? 'No pudimos iniciar sesión. Intenta nuevamente.',
      NetworkFailure(message: final message) =>
        message ?? 'Revisa tu conexión e intenta nuevamente.',
      UnauthorizedFailure(message: final message) =>
        message ?? 'Credenciales incorrectas.',
      NotFoundFailure(message: final message) =>
        message ?? 'Usuario no encontrado.',
      UnknownFailure(message: final message) =>
        message ?? 'Ocurrió un error inesperado.',
    };
  }
}
