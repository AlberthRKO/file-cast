// Configuration file to manage different app flavors
// ignore_for_file: no_default_cases
enum Flavor { development, production, staging, cliente1, cliente2 }

class Config {
  static Flavor appFlavor = Flavor.development;

  //
  // APP VARIABLES
  //

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
      default:
        return 'Default Company';
    }
  }

  //
  // APP ASSETS
  //
  static String get logoAsset {
    switch (appFlavor) {
      case Flavor.cliente1:
        return 'assets/cliente1/logos/logo_cliente1.png';
      case Flavor.cliente2:
        return 'assets/cliente2/logos/logo_cliente2.png';
      default:
        return 'assets/common/logos/logo_default.png';
    }
  }
}
