final class RemoteRequestException implements Exception {
  const RemoteRequestException({
    required this.message,
    this.statusCode,
    this.isTransportFailure = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransportFailure;

  bool get allowsOfflineFallback {
    final status = statusCode;
    return isTransportFailure ||
        status == 408 ||
        status == 429 ||
        (status != null && status >= 500);
  }

  @override
  String toString() => message;
}
