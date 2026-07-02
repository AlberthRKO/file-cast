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
        return 'Development App';
      case Flavor.production:
        return 'Production App';
      case Flavor.staging:
        return 'Staging App';
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
        return 'https://dev-api.example.com';
      case Flavor.staging:
        return 'https://staging-api.example.com';
      case Flavor.production:
        return 'https://api.example.com';
      case Flavor.cliente1:
        return 'https://api-cliente1.example.com';
      case Flavor.cliente2:
        return 'https://api-cliente2.example.com';
    }
  }
}
