import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_challenge.freezed.dart';

@freezed
abstract class AuthMedium with _$AuthMedium {
  const factory AuthMedium({
    required int medio,
    String? contacto,
    String? nombre,
    @Default(false) bool verificado,
    @Default(false) bool observado,
    @Default(false) bool porDefecto,
  }) = _AuthMedium;
}

@freezed
abstract class AuthChallenge with _$AuthChallenge {
  const factory AuthChallenge({
    required int usuarioId,
    required String usuario,
    int? medio,
    String? message,
    String? mensajeServicio,
    String? url,
    int? tiempoVigencia,
    @Default([]) List<AuthMedium> mediosVerificados,
  }) = _AuthChallenge;
}
