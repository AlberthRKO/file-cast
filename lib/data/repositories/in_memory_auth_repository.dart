import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';

class InMemoryAuthRepository implements AuthRepository {
  UserEntity? _currentUser;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String usuario,
    required String password,
  }) async {
    final user = UserEntity(
      id: 1,
      usuario: usuario,
      nombreCompleto: 'Operador Demo',
      dobleAutenticacion: 0,
      estado: 1,
      roles: const ['inspector'],
      permisos: const ['requisitions.read', 'requisitions.write'],
    );

    _currentUser = user;
    return Either<Failure, UserEntity>.right(user);
  }

  @override
  Future<Either<Failure, void>> logout() async {
    _currentUser = null;
    return const Either<Failure, void>.right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    final user = _currentUser;
    if (user == null) {
      return const Either.left(
        Failure.unauthorized(message: 'No hay una sesión activa.'),
      );
    }

    return Either<Failure, UserEntity>.right(user);
  }

  @override
  Future<bool> isLoggedIn() async => _currentUser != null;
}
