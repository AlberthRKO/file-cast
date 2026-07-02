sealed class Failure {
  const Failure._();

  const factory Failure.server({String? message, int? statusCode}) =
      ServerFailure;
  const factory Failure.network({String? message}) = NetworkFailure;
  const factory Failure.unauthorized({String? message}) = UnauthorizedFailure;
  const factory Failure.notFound({String? message}) = NotFoundFailure;
  const factory Failure.unknown({String? message}) = UnknownFailure;
}

class ServerFailure extends Failure {
  const ServerFailure({this.message, this.statusCode}) : super._();
  final String? message;
  final int? statusCode;
}

class NetworkFailure extends Failure {
  const NetworkFailure({this.message}) : super._();
  final String? message;
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({this.message}) : super._();
  final String? message;
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({this.message}) : super._();
  final String? message;
}

class UnknownFailure extends Failure {
  const UnknownFailure({this.message}) : super._();
  final String? message;
}
