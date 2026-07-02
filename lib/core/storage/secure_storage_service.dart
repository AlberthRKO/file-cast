import 'package:file_cast/core/constants/storage_keys.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> getToken() => _storage.read(key: StorageKeys.token);
  Future<void> saveToken(String token) =>
      _storage.write(key: StorageKeys.token, value: token);
  Future<void> deleteToken() => _storage.delete(key: StorageKeys.token);

  Future<String?> getTokenAgetic() =>
      _storage.read(key: StorageKeys.tokenAgetic);
  Future<void> saveTokenAgetic(String token) =>
      _storage.write(key: StorageKeys.tokenAgetic, value: token);
  Future<void> deleteTokenAgetic() =>
      _storage.delete(key: StorageKeys.tokenAgetic);

  Future<String?> getBinacle() => _storage.read(key: StorageKeys.binacle);
  Future<void> saveBinacle(String value) =>
      _storage.write(key: StorageKeys.binacle, value: value);
  Future<void> deleteBinacle() => _storage.delete(key: StorageKeys.binacle);

  Future<String?> getIpServer() => _storage.read(key: StorageKeys.ipServer);
  Future<void> saveIpServer(String value) =>
      _storage.write(key: StorageKeys.ipServer, value: value);
  Future<void> deleteIpServer() => _storage.delete(key: StorageKeys.ipServer);

  Future<String?> getAlmuerzo() => _storage.read(key: StorageKeys.isAlmuerzo);
  Future<void> saveAlmuerzo(String value) =>
      _storage.write(key: StorageKeys.isAlmuerzo, value: value);
  Future<void> deleteAlmuerzo() => _storage.delete(key: StorageKeys.isAlmuerzo);

  Future<void> clearAll() async => _storage.deleteAll();
}
