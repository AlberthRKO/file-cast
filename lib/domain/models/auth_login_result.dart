import 'package:file_cast/domain/entities/user_entity.dart';
import 'package:file_cast/domain/models/auth_challenge.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_login_result.freezed.dart';

@freezed
sealed class AuthLoginResult with _$AuthLoginResult {
  const factory AuthLoginResult.authenticated(UserEntity user) =
      AuthenticatedLogin;
  const factory AuthLoginResult.challenge(AuthChallenge challenge) =
      ChallengedLogin;
}
