import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;

  AuthStatus get status => _status;

  void _setLoading() {
    _status = AuthStatus.loading;
    notifyListeners();
  }

  void _setAuthenticated() {
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> login({
    required String usuario,
    required String password,
  }) async {
    _setLoading();
    _setUnauthenticated();
  }

  Future<void> logout() async {
    _setUnauthenticated();
  }

  Future<void> checkAuthStatus() async {
    _setLoading();
    _setUnauthenticated();
  }
}

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }
