import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String usuario,
    required String password,
  });
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> getCurrentUser();
  Future<bool> isLoggedIn();
}
