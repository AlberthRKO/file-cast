import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_cast/app/data/services/remote/internet_checker.dart';
import 'package:file_cast/app/domain/repositories/connectivity_repository.dart';

class ConnectivyRespositoryImpl implements ConnectivyRespository {
  ConnectivyRespositoryImpl(this._connectivity, this._internetChecker);
  // cuando implementamos una clase abstracta tenemos que sobreescribir todas las funciones que no tienen cuerpo

  final Connectivity _connectivity;

  // injectamos la clase de checcker internet
  final InternetChecker _internetChecker;

  @override
  Future<bool> get hasInternet async {
    // Preguntamos si estamos conectados a una red, ya sea wifi mobile vpn
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      return false;
    }
    return _internetChecker.hasInternet();
  }
}
