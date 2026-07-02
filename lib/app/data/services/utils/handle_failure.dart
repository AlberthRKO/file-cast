import 'package:file_cast/app/data/http/http.dart';
import 'package:file_cast/app/domain/either/either.dart';
import 'package:file_cast/app/domain/failures/htpp_request/http_request_failure.dart';

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
