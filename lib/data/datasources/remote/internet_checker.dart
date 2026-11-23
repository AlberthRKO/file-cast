import 'dart:async';

import 'package:http/http.dart' as http;

enum BackendReachability { reachable, degraded, unreachable }

/// Comprueba el servicio institucional, no un DNS o proveedor público.
class InternetChecker {
  InternetChecker({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUri = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _baseUri;

  Future<BackendReachability> checkBackend() async {
    try {
      final response = await _client
          .get(
            _baseUri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 500
          ? BackendReachability.degraded
          : BackendReachability.reachable;
    } on Object {
      return BackendReachability.unreachable;
    }
  }
}
