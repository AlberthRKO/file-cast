import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/domain/failures/http_request_failure.dart';

Either<HttpRequestFailure, R> handleHttpFailure<R>(HttpFailure httpFailure) {
  final failure = () {
    final statusCode = httpFailure.statusCode;
    switch (statusCode) {
      case 404:
        return HttpRequestFailure.notFound();
      case 401:
        return HttpRequestFailure.unauthorized();
    }
    return httpFailure.exception is NewtworkException
        ? HttpRequestFailure.network()
        : HttpRequestFailure.unknow();
  }();
  return Either.left(failure);
}
