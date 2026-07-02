import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _token = 'token';
const _tokenAgetic = 'tokenAgetic';
const _binacle = 'binacle';
const _ipServer = 'ipServer';
const _isAlmuerzo = 'isAlmuerzo';

class TokenServices {
  TokenServices(this._flutterSecureStorage);

  final FlutterSecureStorage _flutterSecureStorage;

  Future<String?> get token async {
    final token = await _flutterSecureStorage.read(key: _token);
    return token;
  }

  Future<void> saveToken(String token) {
    return _flutterSecureStorage.write(key: _token, value: token);
  }

  Future<void> deleteToken() {
    return _flutterSecureStorage.delete(key: _token);
  }
}

class TokenAgeticServices {
  TokenAgeticServices(this._flutterSecureStorage);

  final FlutterSecureStorage _flutterSecureStorage;

  Future<String?> get tokenAgetic async {
    final tokenAgetic = await _flutterSecureStorage.read(key: _tokenAgetic);
    return tokenAgetic;
  }

  Future<void> saveTokenAgetic(String tokenAgetic) {
    return _flutterSecureStorage.write(key: _tokenAgetic, value: tokenAgetic);
  }

  Future<void> deleteTokenAgetic() {
    return _flutterSecureStorage.delete(key: _tokenAgetic);
  }
}

class BinacleServices {
  BinacleServices(this._flutterSecureStorage);

  final FlutterSecureStorage _flutterSecureStorage;

  Future<String?> get binacle async {
    final binacle = await _flutterSecureStorage.read(key: _binacle);
    return binacle;
  }

  Future<void> saveBinacle(String binacle) {
    return _flutterSecureStorage.write(key: _binacle, value: binacle);
  }

  Future<void> deleteBinacle() {
    return _flutterSecureStorage.delete(key: _binacle);
  }
}

class IpServices {
  IpServices(this._flutterSecureStorage);

  final FlutterSecureStorage _flutterSecureStorage;

  Future<String?> get ipServer async {
    final ipServer = await _flutterSecureStorage.read(key: _ipServer);
    return ipServer;
  }

  Future<void> saveIp(String ipServer) {
    return _flutterSecureStorage.write(key: _ipServer, value: ipServer);
  }

  Future<void> deleteIp() {
    return _flutterSecureStorage.delete(key: _ipServer);
  }
}

class AlmuerzoServices {
  AlmuerzoServices(this._flutterSecureStorage);

  final FlutterSecureStorage _flutterSecureStorage;

  Future<String?> get almuerzo async {
    final almuerzo = await _flutterSecureStorage.read(key: _isAlmuerzo);
    return almuerzo;
  }

  Future<void> saveAlmuerzo(String almuerzo) {
    return _flutterSecureStorage.write(key: _isAlmuerzo, value: almuerzo);
  }

  Future<void> deleteAlmuerzo() {
    return _flutterSecureStorage.delete(key: _isAlmuerzo);
  }
}
