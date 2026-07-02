import 'package:file_cast/app.dart';
import 'package:file_cast/bootstrap.dart';
import 'package:file_cast/core/config/config.dart';

Future<void> main() async {
  Config.appFlavor = Flavor.cliente2;
  await bootstrap(() => const App());
}
