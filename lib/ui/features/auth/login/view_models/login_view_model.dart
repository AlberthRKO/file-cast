import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/ui/features/auth/login/view_models/login_state.dart';
import 'package:file_cast/ui/features/auth/session/auth_session_controller.dart';
import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required AuthRepository? authRepository,
    required AuthSessionController sessionController,
  }) : _authRepository = authRepository,
       _sessionController = sessionController;

  final AuthRepository? _authRepository;
  final AuthSessionController _sessionController;

  LoginState _state = const LoginState();
  LoginState get state => _state;

  bool get isSubmitting => _state.phase == LoginPhase.submitting;

  void updateDocument(String value) {
    _state = _state.copyWith(
      documentNumber: value,
      documentError: null,
      errorMessage: null,
      phase: LoginPhase.editing,
    );
    notifyListeners();
  }

  void updatePassword(String value) {
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
    if (isSubmitting) return;

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

    final repository = _authRepository;
    if (repository == null) {
      _state = _state.copyWith(
        errorMessage: 'La autenticación todavía no está configurada.',
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

    final result = await repository.login(
      usuario: _state.documentNumber,
      password: _state.password,
    );

    switch (result) {
      case Left(leftValue: final failure):
        _state = _state.copyWith(
          errorMessage: _messageFromFailure(failure),
          phase: LoginPhase.error,
        );
      case Right(rightValue: final user):
        _sessionController.authenticated(user);
        _state = _state.copyWith(phase: LoginPhase.success);
    }
    notifyListeners();
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
