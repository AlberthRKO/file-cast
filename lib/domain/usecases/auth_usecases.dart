import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call({
    required String usuario,
    required String password,
  }) =>
      _repository.login(usuario: usuario, password: password);
}

class LogoutUseCase {
  LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, void>> call() => _repository.logout();
}

class GetCurrentUserUseCase {
  GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call() => _repository.getCurrentUser();
}
