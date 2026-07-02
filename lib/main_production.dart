import 'package:file_cast/app/app.dart';
import 'package:file_cast/bootstrap.dart';
import 'package:file_cast/core/clients_config/config.dart';

Future<void> main() async {
  Config.appFlavor = Flavor.production;
  await bootstrap(() => const App());
}
