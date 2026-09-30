import 'package:flutter/foundation.dart';

enum Flavor { development, production, staging, cliente1, cliente2 }

class Config {
  static Flavor appFlavor = Flavor.development;

  static String get appName {
    switch (appFlavor) {
      case Flavor.cliente1:
        return 'Cliente 1 App';
      case Flavor.cliente2:
        return 'Cliente 2 App';
      case Flavor.development:
        return 'Dev File Cast';
      case Flavor.production:
        return 'File Cast';
      case Flavor.staging:
        return 'Stage File Cast';
    }
  }

  static String get companyName {
    switch (appFlavor) {
      case Flavor.cliente1:
        return 'Cliente 1 Company';
      case Flavor.cliente2:
        return 'Cliente 2 Company';
      case Flavor.development:
        return 'Dev File Cast';
      case Flavor.staging:
        return 'Stage File Cast';
      case Flavor.production:
        return 'File Cast';
    }
  }

  static String get logoAsset {
    switch (appFlavor) {
      case Flavor.cliente1:
        return 'assets/cliente1/logos/logo_cliente1.png';
      case Flavor.cliente2:
        return 'assets/cliente2/logos/logo_cliente2.png';
      case Flavor.development:
        return 'assets/common/logos/logo_default.png';
      case Flavor.staging:
        return 'assets/common/logos/logo_default.png';
      case Flavor.production:
        return 'assets/common/logos/logo_default.png';
    }
  }

  static String get baseUrl {
    switch (appFlavor) {
      case Flavor.development:
        return _developmentBaseUrl;
      case Flavor.staging:
        return const String.fromEnvironment(
          'BASE_URL_FILE_CAST',
          defaultValue: 'https://staging-api.example.com',
        );
      case Flavor.production:
        return const String.fromEnvironment(
          'BASE_URL_FILE_CAST',
          defaultValue: 'https://api.example.com',
        );
      case Flavor.cliente1:
        return const String.fromEnvironment(
          'BASE_URL_FILE_CAST',
          defaultValue: 'https://api-cliente1.example.com',
        );
      case Flavor.cliente2:
        return const String.fromEnvironment(
          'BASE_URL_FILE_CAST',
          defaultValue: 'https://api-cliente2.example.com',
        );
    }
  }

  static String get _developmentBaseUrl {
    const configuredBaseUrl = String.fromEnvironment('BASE_URL_FILE_CAST');
    if (configuredBaseUrl.isNotEmpty) return configuredBaseUrl;

    // Desde Android Emulator, localhost apunta al propio emulador. La
    // dirección especial 10.0.2.2 apunta al equipo anfitrión.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'https://0dpchkdj-3000.brs.devtunnels.ms';
    }

    return 'https://0dpchkdj-3000.brs.devtunnels.ms';
  }
}
