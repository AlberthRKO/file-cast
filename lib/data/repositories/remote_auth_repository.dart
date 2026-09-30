import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/data/models/user_model.dart';
import 'package:file_cast/data/services/auth_session_service.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({required AuthSessionService sessionService})
    : _sessionService = sessionService;

  final AuthSessionService _sessionService;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String usuario,
    required String password,
  }) async {
    try {
      final user = await _sessionService.login(
        numeroDocumento: usuario,
        password: password,
      );
      return Either.right(_toEntity(user));
    } on AuthSessionException catch (error) {
      return Either.left(_toFailure(error));
    } on Object catch (error) {
      return Either.left(Failure.unknown(message: error.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _sessionService.logout();
      return const Either.right(null);
    } on AuthSessionException catch (error) {
      return Either.left(_toFailure(error));
    } on Object catch (error) {
      return Either.left(Failure.unknown(message: error.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _sessionService.restoreCurrentUser();
      return Either.right(_toEntity(user));
    } on AuthSessionException catch (error) {
      return Either.left(_toFailure(error));
    } on Object catch (error) {
      return Either.left(Failure.unknown(message: error.toString()));
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return _sessionService.hasStoredSession();
  }

  UserEntity _toEntity(UserModel user) {
    return UserEntity(
      id: user.id,
      usuario: user.usuario,
      numeroDocumento: user.usuario,
      nombreCompleto: user.nombreCompleto,
      dobleAutenticacion: user.dobleAutenticacion,
      estado: user.estado,
      roles: user.roles,
      permisos: user.permisos,
    );
  }

  Failure _toFailure(AuthSessionException error) {
    if (error.isNetwork) {
      return Failure.network(
        message: 'No se pudo conectar con el servicio de autenticación.',
      );
    }

    return switch (error.statusCode) {
      401 || 403 => Failure.unauthorized(
        message: error.message ?? 'Las credenciales no son válidas.',
      ),
      404 => Failure.notFound(
        message:
            error.message ?? 'No se encontró el servicio de autenticación.',
      ),
      final statusCode when statusCode != null => Failure.server(
        message:
            error.message ??
            'El servicio de autenticación no respondió correctamente.',
        statusCode: statusCode,
      ),
      _ => Failure.unknown(
        message: error.message ?? 'Ocurrió un error de autenticación.',
      ),
    };
  }
}
