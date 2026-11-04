import 'dart:io';

import 'package:flutter/foundation.dart';

/// Permite certificados no confiables únicamente en builds debug.
///
/// No se configura en profile/release porque desactiva completamente la
/// validación de la cadena TLS.
void configureDebugHttpOverrides() {
  if (!kDebugMode) return;
  HttpOverrides.global = _AllowAllCertificatesOverrides();
}

class _AllowAllCertificatesOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (certificate, host, port) => true;
    return client;
  }
}
