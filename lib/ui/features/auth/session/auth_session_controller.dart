import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:flutter/foundation.dart';

enum AuthSessionStatus { unknown, unauthenticated, authenticated }

class AuthSessionController extends ChangeNotifier {
  AuthSessionStatus _status = AuthSessionStatus.unauthenticated;
  UserEntity? _user;

  AuthSessionStatus get status => _status;
  UserEntity? get user => _user;

  bool get isAuthenticated => _status == AuthSessionStatus.authenticated;

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
}
