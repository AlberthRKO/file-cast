import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/errors/failures.dart';
import 'package:file_cast/data/models/user_model.dart';
import 'package:file_cast/data/services/auth_external_link_service.dart';
import 'package:file_cast/data/services/auth_sms_code_service.dart';
import 'package:file_cast/data/services/auth_session_service.dart';
import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/models/auth_challenge.dart';
import 'package:file_cast/domain/models/auth_login_result.dart';
import 'package:file_cast/domain/repositories/auth_repository.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required AuthSessionService sessionService,
    required ConnectivityRepository connectivity,
    required AuthExternalLinkService externalLinkService,
    required AuthSmsCodeService smsCodeService,
  }) : _sessionService = sessionService,
       _connectivity = connectivity,
       _externalLinkService = externalLinkService,
       _smsCodeService = smsCodeService;

  final AuthSessionService _sessionService;
  final ConnectivityRepository _connectivity;
  final AuthExternalLinkService _externalLinkService;
  final AuthSmsCodeService _smsCodeService;

  @override
  Future<String?> listenForLoginSmsCode() => _smsCodeService.listen();

  @override
  Future<void> stopLoginSmsCodeListener() => _smsCodeService.stop();

  @override
  Future<bool> openTelegram(String? address) =>
      _externalLinkService.openTelegram(address);

  @override
  Future<Either<Failure, AuthLoginResult>> login({
    required String usuario,
    required String password,
  }) async {
    try {
      final result = await _sessionService.login(
        numeroDocumento: usuario,
        password: password,
      );
      return switch (result) {
        Map<String, dynamic> body => Either<Failure, AuthLoginResult>.right(
          AuthLoginResult.challenge(_challengeFrom(body, usuario)),
        ),
        UserModel user => Either<Failure, AuthLoginResult>.right(
          AuthLoginResult.authenticated(_toEntity(user)),
        ),
        _ => const Either<Failure, AuthLoginResult>.left(
          Failure.unknown(message: 'Respuesta de login inválida.'),
        ),
      };
    } on AuthSessionException catch (error) {
      return Either.left(_toFailure(error));
    } on Object catch (error) {
      return Either.left(Failure.unknown(message: error.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthChallenge>> sendLoginCode(
    AuthChallenge challenge,
    int medio,
  ) async {
    final isCurrent = challenge.medio == medio;
    final isVerified = challenge.mediosVerificados.any(
      (item) => item.medio == medio && item.verificado && !item.observado,
    );
    if (!isCurrent && !isVerified) {
      return const Either<Failure, AuthChallenge>.left(
        Failure.unknown(message: 'El medio seleccionado no está verificado.'),
      );
    }
    try {
      final body = await _sessionService.sendLoginCode(
        challenge.usuarioId,
        medio,
      );
      return Either<Failure, AuthChallenge>.right(
        _challengeFrom(
          body,
          challenge.usuario,
          previous: challenge,
          requestedMedium: medio,
        ),
      );
    } on AuthSessionException catch (error) {
      return Either.left(_toFailure(error));
    } on Object catch (error) {
      return Either.left(Failure.unknown(message: error.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> confirmLoginCode({
    required AuthChallenge challenge,
    required String code,
    required bool trustedDevice,
  }) async {
    try {
      final user = await _sessionService.confirmLoginCode(
        usuario: challenge.usuario,
        code: code,
        trustedDevice: trustedDevice,
      );
      return Either<Failure, UserEntity>.right(_toEntity(user));
    } on AuthSessionException catch (error) {
      return Either.left(_toFailure(error));
    } on Object catch (error) {
      return Either.left(Failure.unknown(message: error.toString()));
    }
  }

  AuthChallenge _challengeFrom(
    Map<String, dynamic> body,
    String fallbackUsuario, {
    AuthChallenge? previous,
    int? requestedMedium,
  }) {
    final response = _map(body['response']);
    final data = _map(response?['data']);
    final userId = _int(data?['usuarioId']) ?? previous?.usuarioId;
    if (data == null || userId == null) {
      throw const AuthSessionException(
        message: 'El desafío 2FA no tiene usuario válido.',
      );
    }
    final rawMedia = data['mediosVerificados'];
    final media = rawMedia is List
        ? rawMedia
              .whereType<Map>()
              .map((item) {
                final value = Map<String, dynamic>.from(item);
                final id = _int(value['medio']);
                if (id == null) return null;
                return AuthMedium(
                  medio: id,
                  contacto: _string(value['contacto']),
                  nombre: _string(value['nombre']),
                  verificado: value['verificado'] == true,
                  observado: value['observado'] == true,
                  porDefecto: value['porDefecto'] == true,
                );
              })
              .whereType<AuthMedium>()
              .toList(growable: false)
        : previous?.mediosVerificados ?? <AuthMedium>[];
    return AuthChallenge(
      usuarioId: userId,
      usuario: _string(data['usuario']) ?? fallbackUsuario,
      medio: _int(data['medio']) ?? requestedMedium,
      message: _string(body['message']) ?? _string(response?['message']),
      mensajeServicio: _string(data['mensajeServicio']),
      url: _string(data['url']),
      tiempoVigencia: _int(data['tiempoVigencia']),
      mediosVerificados: media,
    );
  }

  Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  int? _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      if (_connectivity.currentStatus == ConnectivityStatus.offline ||
          _connectivity.currentStatus == ConnectivityStatus.limited) {
        await _sessionService.logoutLocally();
      } else {
        await _sessionService.logout();
      }
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
      if (_connectivity.currentStatus == ConnectivityStatus.checking) {
        await _connectivity.refresh();
      }
      final user = switch (_connectivity.currentStatus) {
        ConnectivityStatus.offline || ConnectivityStatus.limited =>
          await _sessionService.restoreCachedCurrentUser(),
        ConnectivityStatus.checking ||
        ConnectivityStatus.online => await _sessionService.restoreCurrentUser(),
      };
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
