import 'package:file_cast/app.dart';
import 'package:file_cast/bootstrap.dart';
import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/di/dependency_injection.dart';
import 'package:provider/provider.dart';

void main() {
  Config.appFlavor = Flavor.staging;
  bootstrap(
    () => MultiProvider(
      providers: DependencyInjection.providers(),
      child: const App(),
    ),
  );
}
