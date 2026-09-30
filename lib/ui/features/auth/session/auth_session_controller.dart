import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

enum AuthSessionStatus { unknown, unauthenticated, authenticated }

class AuthSessionController extends ChangeNotifier {
  AuthSessionController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthSessionStatus _status = AuthSessionStatus.unknown;
  UserEntity? _user;
  bool _restoring = false;

  AuthSessionStatus get status => _status;
  UserEntity? get user => _user;

  bool get isAuthenticated => _status == AuthSessionStatus.authenticated;

  Future<void> restore() async {
    if (_restoring || _status != AuthSessionStatus.unknown) return;
    _restoring = true;

    final result = await _authRepository.getCurrentUser();
    switch (result) {
      case Left(leftValue: _):
        unauthenticated();
      case Right(rightValue: final user):
        authenticated(user);
    }

    _restoring = false;
  }

  void authenticated(UserEntity user) {
    _status = AuthSessionStatus.authenticated;
    _user = user;
    notifyListeners();
  }

  void unauthenticated() {
    _status = AuthSessionStatus.unauthenticated;
    _user = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    unauthenticated();
  }
}
