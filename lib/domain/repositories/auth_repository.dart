import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/models/auth_challenge.dart';
import 'package:file_cast/domain/models/auth_login_result.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthLoginResult>> login({
    required String usuario,
    required String password,
  });
  Future<Either<Failure, AuthChallenge>> sendLoginCode(
    AuthChallenge challenge,
    int medio,
  );
  Future<Either<Failure, UserEntity>> confirmLoginCode({
    required AuthChallenge challenge,
    required String code,
    required bool trustedDevice,
  });
  Future<bool> openTelegram(String? address);
  Future<String?> listenForLoginSmsCode();
  Future<void> stopLoginSmsCodeListener();
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> getCurrentUser();
  Future<bool> isLoggedIn();
}
