import 'package:freezed_annotation/freezed_annotation.dart';

// generaremos clases que extiendan de esta clase

part 'sign_in_failure.freezed.dart';

// esto nos permitira trabajar con programacion funcional con unionTypes y seeler class
@freezed
class SignInFailure with _$SignInFailure {
  factory SignInFailure.notFound() = SignInFailureNotFound;
  factory SignInFailure.network() = SignInFailureNetwork;
  factory SignInFailure.unathorized() = SignInFailureUnathorized;
  factory SignInFailure.unknown() = SignInFailureUnknown;
  factory SignInFailure.ip() = SignInFailureIpServices;
}
