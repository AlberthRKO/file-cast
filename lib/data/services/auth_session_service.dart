import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/core/storage/secure_storage_service.dart';
import 'package:file_cast/core/utils/constants.dart';
import 'package:file_cast/data/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cliente de sesión para la fachada de autenticación de file-cast-back.
///
/// El backend reenvía estas operaciones a ms-auth. Este servicio mantiene el
/// detalle HTTP y la persistencia de tokens fuera del dominio y evita que las
/// llamadas de login/refresh entren al interceptor de peticiones autenticadas.
class AuthSessionService {
  AuthSessionService({
    required http.Client client,
    required SecureStorageService storage,
    String? baseUrl,
  }) : _client = client,
       _storage = storage,
       _baseUrl = baseUrl ?? Config.baseUrl;

  static const _loginPath = '/api/v1/auth/login';
  static const _refreshPath = '/api/v1/auth/refresh-token';
  static const _logoutPath = '/api/v1/auth/logout';
  static const _mePath = '/api/v1/auth/me';
  static const _userAgent = 'FileCast';

  final http.Client _client;
  final SecureStorageService _storage;
  final String _baseUrl;
  final Random _random = Random.secure();

  Future<bool>? _refreshInFlight;

  Future<bool> hasStoredSession() async {
    final accessToken = await _storage.getToken();
    final refreshToken = await _storage.getRefreshToken();
    final hasSession =
        (accessToken?.isNotEmpty ?? false) ||
        (refreshToken?.isNotEmpty ?? false);
    _debugLog(
      'session.storage_state',
      details: {
        'hasAccessToken': accessToken?.isNotEmpty ?? false,
        'hasRefreshToken': refreshToken?.isNotEmpty ?? false,
        'hasSession': hasSession,
      },
    );
    return hasSession;
  }

  /// Proporciona el token actual y renueva anticipadamente cuando el backend
  /// informa una expiración próxima. Si no hay `expiresAt`, se mantiene el
  /// comportamiento reactivo y el refresh se realizará ante un `401`.
  Future<String?> getValidAccessToken() async {
    final accessToken = await _storage.getToken();
    if (accessToken == null || accessToken.isEmpty) return null;

    final expiresAt = await _storage.getTokenExpiresAt();
    if (expiresAt == null || expiresAt.isEmpty) return accessToken;

    final expiration = DateTime.tryParse(expiresAt);
    if (expiration == null ||
        expiration.difference(DateTime.now()) > const Duration(minutes: 3)) {
      return accessToken;
    }

    if (await refreshTokenIfNeeded()) return _storage.getToken();
    return accessToken;
  }

  Future<UserModel> login({
    required String numeroDocumento,
    required String password,
  }) async {
    final uri = _uri(_loginPath);
    _debugLog(
      'login.start',
      details: {
        'method': 'POST',
        'url': uri.toString(),
        'hasNumeroDocumento': numeroDocumento.trim().isNotEmpty,
        'hasPassword': password.isNotEmpty,
      },
    );
    await _storage.clearAuthSession();

    try {
      final deviceId = await _getOrCreateDeviceId();
      final body = await _requestJson(
        _loginPath,
        method: 'POST',
        body: {
          'numeroDocumento': numeroDocumento,
          'password': password,
          'deviceId': deviceId,
          'aplicacion': appMp,
        },
      );
      await _persistTokenResponse(body);

      _debugLog('login.profile_request');
      final user = await _fetchCurrentUser();
      await _persistAuthenticatedUser(user);
      _debugLog('login.success');
      return user;
    } catch (error, stackTrace) {
      _debugLog(
        'login.failure',
        details: {
          'errorType': error.runtimeType.toString(),
          'message': _safeErrorMessage(error),
        },
        error: error,
        stackTrace: stackTrace,
      );
      await _storage.clearAuthSession();
      rethrow;
    }
  }

  Future<UserModel> restoreCurrentUser() async {
    final accessToken = await _storage.getToken();
    final refreshToken = await _storage.getRefreshToken();
    if ((accessToken == null || accessToken.isEmpty) &&
        (refreshToken == null || refreshToken.isEmpty)) {
      _debugLog('session.restore_skipped', details: {'reason': 'no_tokens'});
      throw const AuthSessionException(
        statusCode: 401,
        message: 'No hay una sesión activa.',
      );
    }

    _debugLog(
      'session.restore_start',
      details: {
        'hasAccessToken': accessToken?.isNotEmpty ?? false,
        'hasRefreshToken': refreshToken?.isNotEmpty ?? false,
      },
    );

    try {
      if (accessToken == null || accessToken.isEmpty) {
        if (!await refreshTokenIfNeeded()) {
          throw const AuthSessionException(
            statusCode: 401,
            message: 'La sesión ya no es válida.',
          );
        }
      }

      final user = await _fetchCurrentUser();
      await _persistAuthenticatedUser(user);
      _debugLog('session.restore_success');
      return user;
    } on AuthSessionException catch (error) {
      if (error.isNetwork) {
        final cachedUser = await _readCachedUser();
        if (cachedUser != null) {
          _debugLog('session.restore_cached_user');
          return cachedUser;
        }
      }

      if (error.statusCode == 401 && await refreshTokenIfNeeded()) {
        _debugLog('session.restore_after_refresh');
        final user = await _fetchCurrentUser();
        await _persistAuthenticatedUser(user);
        return user;
      }
      _debugLog(
        'session.restore_failure',
        details: {
          'statusCode': error.statusCode,
          'isNetwork': error.isNetwork,
          'message': error.message,
        },
      );
      rethrow;
    }
  }

  /// Renueva el par de tokens una sola vez aunque varias peticiones expiren
  /// al mismo tiempo.
  Future<bool> refreshTokenIfNeeded() {
    final current = _refreshInFlight;
    if (current != null) {
      _debugLog('refresh.wait_existing');
      return current;
    }

    _debugLog('refresh.start');
    final operation = _refreshTokenInternal();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
      _debugLog('refresh.finish');
    });
  }

  Future<void> logout() async {
    final accessToken = await _storage.getToken();
    _debugLog(
      'logout.start',
      details: {'hasAccessToken': accessToken?.isNotEmpty ?? false},
    );
    try {
      if (accessToken != null && accessToken.isNotEmpty) {
        await _requestJson(
          _logoutPath,
          method: 'POST',
          accessToken: accessToken,
        );
      }
    } on AuthSessionException {
      // Logout remoto es best-effort; la sesión local siempre se elimina.
    } finally {
      await _storage.clearAuthSession();
      _debugLog('logout.local_session_cleared');
    }
  }

  Future<bool> _refreshTokenInternal() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      _debugLog('refresh.skipped', details: {'reason': 'no_refresh_token'});
      return false;
    }

    try {
      final body = await _requestJson(
        _refreshPath,
        method: 'POST',
        body: {
          'refreshToken': refreshToken,
          'deviceId': await _getOrCreateDeviceId(),
          'aplicacion': appMp,
        },
      );
      await _persistTokenResponse(body, preserveUser: true);
      _debugLog('refresh.success');
      return true;
    } on AuthSessionException catch (error) {
      if (!error.isNetwork &&
          (error.statusCode == null ||
              error.statusCode == 400 ||
              error.statusCode == 401 ||
              error.statusCode == 403)) {
        await _storage.clearAuthSession();
      }
      _debugLog(
        'refresh.failure',
        details: {
          'statusCode': error.statusCode,
          'isNetwork': error.isNetwork,
          'message': error.message,
        },
      );
      return false;
    }
  }

  Future<UserModel> _fetchCurrentUser() async {
    final accessToken = await _storage.getToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthSessionException(
        statusCode: 401,
        message: 'No hay access token disponible.',
      );
    }

    final body = await _requestJson(
      _mePath,
      method: 'GET',
      accessToken: accessToken,
    );
    final user = _userFromResponse(body);
    _debugLog(
      'profile.loaded',
      details: {
        'hasUserId': user.id != null,
        'hasDocument': user.usuario?.isNotEmpty ?? false,
        'hasNombreCompleto': user.nombreCompleto?.isNotEmpty ?? false,
        'permissionCount': _permissionCount(user),
        'hasFinalizePermission': _hasPermission(user, 'requisitions.finalize'),
      },
    );
    return user;
  }

  Future<void> _persistAuthenticatedUser(UserModel user) async {
    await _storage.saveAuthenticatedUser(user.toJson());
    _debugLog(
      'profile.persisted',
      details: {
        'hasUserId': user.id != null,
        'hasDocument': user.usuario?.isNotEmpty ?? false,
        'hasNombreCompleto': user.nombreCompleto?.isNotEmpty ?? false,
        'permissionCount': _permissionCount(user),
        'hasFinalizePermission': _hasPermission(user, 'requisitions.finalize'),
      },
    );
  }

  Future<void> _persistTokenResponse(
    dynamic body, {
    bool preserveUser = false,
  }) async {
    final payload = _payload(body);
    final accessToken = _firstString([
      payload['accessToken'],
      payload['token'],
    ]);
    final refreshToken = _firstString([payload['refreshToken']]);
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthSessionException(
        message: 'ms-auth no devolvió un access token válido.',
      );
    }

    await _storage.saveToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(refreshToken);
    }

    final expiresAt = _firstString([payload['expiresAt']]);
    if (expiresAt != null && expiresAt.isNotEmpty) {
      await _storage.saveTokenExpiresAt(expiresAt);
    } else if (!preserveUser) {
      await _storage.deleteTokenExpiresAt();
    }

    _debugLog(
      'token.persisted',
      details: {
        'hasAccessToken': true,
        'hasRefreshToken': refreshToken?.isNotEmpty ?? false,
        'hasExpiresAt': expiresAt?.isNotEmpty ?? false,
        'preservedUser': preserveUser,
      },
    );
  }

  UserModel _userFromResponse(dynamic body) {
    final payload = _payload(body);
    final normalized = <String, dynamic>{...payload};

    final userId = _firstInt([
      normalized['id'],
      normalized['usuarioId'],
      normalized['idUsuario'],
      normalized['userId'],
    ]);
    if (userId != null) normalized['id'] = userId;

    final documentNumber = _profileString(
      payload,
      directKeys: const ['numeroDocumento', 'documento', 'ci'],
      nestedKeys: const ['perfilPersona', 'persona', 'profile'],
      nestedValueKeys: const ['numeroDocumento', 'documento', 'ci'],
    );
    final username = _firstString([normalized['usuario']]);
    normalized['usuario'] = documentNumber ?? username;

    final fullName = _profileString(
      payload,
      directKeys: const ['nombreCompleto', 'fullName'],
      nestedKeys: const ['perfilPersona', 'persona', 'profile'],
      nestedValueKeys: const ['nombreCompleto', 'fullName'],
    );
    if (fullName != null) normalized['nombreCompleto'] = fullName;

    normalized['roles'] = _stringList(normalized['roles']);
    normalized['permisos'] = _stringList(normalized['permisos']);

    return UserModel.fromJson(normalized);
  }

  Future<UserModel?> _readCachedUser() async {
    final raw = await _storage.getAuthenticatedUser();
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UserModel.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  Future<dynamic> _requestJson(
    String path, {
    required String method,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = _uri(path);
    final deviceId = await _getOrCreateDeviceId();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'user-agent': _userAgent,
      'x-aplicacion': appMp,
      'x-dispositivo-unico': deviceId,
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    _debugLog(
      'http.request',
      details: {
        'method': method,
        'url': uri.toString(),
        'headers': headers,
        'body': body ?? const <String, dynamic>{},
      },
    );

    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _client
          .send(request)
          .timeout(
            const Duration(seconds: 30),
          );
      final response = await http.Response.fromStream(streamed);
      final responseBody = _decode(response.body);

      _debugLog(
        'http.response',
        details: {
          'method': method,
          'url': uri.toString(),
          'statusCode': response.statusCode,
          'body': _responseSummary(responseBody),
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthSessionException(
          statusCode: response.statusCode,
          message: _messageFrom(responseBody),
        );
      }

      return responseBody;
    } on AuthSessionException {
      rethrow;
    } on SocketException catch (error, stackTrace) {
      _debugNetworkFailure(uri, method, error, stackTrace);
      throw AuthSessionException.network(error.toString());
    } on http.ClientException catch (error, stackTrace) {
      _debugNetworkFailure(uri, method, error, stackTrace);
      throw AuthSessionException.network(error.toString());
    } on TimeoutException catch (error, stackTrace) {
      _debugNetworkFailure(uri, method, error, stackTrace);
      throw AuthSessionException.network(error.toString());
    } on FormatException catch (error, stackTrace) {
      _debugNetworkFailure(uri, method, error, stackTrace);
      throw AuthSessionException(
        message: 'La URL del servicio de autenticación no es válida.',
      );
    }
  }

  void _debugNetworkFailure(
    Uri uri,
    String method,
    Object error,
    StackTrace stackTrace,
  ) {
    _debugLog(
      'http.failure',
      details: {
        'method': method,
        'url': uri.toString(),
        'errorType': error.runtimeType.toString(),
        'message': _safeErrorMessage(error),
      },
      error: error,
      stackTrace: stackTrace,
    );
  }

  Uri _uri(String path) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse('$base$path');
  }

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _storage.getDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;

    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final value = base64UrlEncode(bytes);
    await _storage.saveDeviceId(value);
    return value;
  }

  dynamic _decode(String value) {
    if (value.trim().isEmpty) return const <String, dynamic>{};
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  Map<String, dynamic> _payload(dynamic body) {
    if (body is! Map) {
      throw const AuthSessionException(
        message: 'Respuesta inválida de ms-auth.',
      );
    }

    final root = Map<String, dynamic>.from(body);
    final response = _mapValue(root['response']);
    final responseData = _mapValue(response?['data']);
    if (responseData != null) return responseData;
    if (response != null) return response;
    final data = _mapValue(root['data']);
    return data ?? root;
  }

  String? _messageFrom(dynamic body) {
    if (body is String && body.isNotEmpty) return body;
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final direct = map['message'];
    if (direct is String && direct.isNotEmpty) return direct;
    final response = _mapValue(map['response']);
    final nested = response?['message'];
    return nested is String && nested.isNotEmpty ? nested : null;
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  String? _firstString(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  int? _firstInt(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? _profileString(
    Map<String, dynamic> payload, {
    required List<String> directKeys,
    required List<String> nestedKeys,
    required List<String> nestedValueKeys,
  }) {
    final direct = _firstString(directKeys.map((key) => payload[key]));
    if (direct != null) return direct;

    for (final nestedKey in nestedKeys) {
      final nested = _mapValue(payload[nestedKey]);
      if (nested == null) continue;
      final nestedValue = _firstString(
        nestedValueKeys.map((key) => nested[key]),
      );
      if (nestedValue != null) return nestedValue;
    }

    return null;
  }

  List<String?> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map<String?>((item) {
          if (item is String) return item;
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final code = map['codigo'] ?? map['code'] ?? map['nombre'];
            return code is String ? code : null;
          }
          return null;
        })
        .toList(growable: false);
  }

  void _debugLog(
    String event, {
    Map<String, dynamic>? details,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final payload = <String, dynamic>{
      'event': event,
      if (details != null) ...details,
    };
    developer.log(
      jsonEncode(_valueForLog(payload)),
      name: 'FileCast.AuthSession',
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _permissionCount(UserModel user) =>
      user.permisos
          ?.where((permission) => permission?.trim().isNotEmpty == true)
          .length ??
      0;

  bool _hasPermission(UserModel user, String requiredPermission) =>
      user.permisos?.any(
        (permission) => permission?.trim().toLowerCase() == requiredPermission,
      ) ??
      false;

  dynamic _valueForLog(dynamic value, {String? key}) {
    if (_isSensitiveKey(key)) return _maskedSecret(value?.toString() ?? '');
    if (value is Map) {
      return value.map(
        (nestedKey, nestedValue) => MapEntry(
          nestedKey.toString(),
          _valueForLog(nestedValue, key: nestedKey.toString()),
        ),
      );
    }
    if (value is Iterable) {
      return value.map((item) => _valueForLog(item)).toList(growable: false);
    }
    return value;
  }

  bool _isSensitiveKey(String? key) {
    final normalized = key?.toLowerCase().replaceAll(RegExp(r'[_-]'), '') ?? '';
    return normalized.contains('authorization') ||
        normalized.contains('password') ||
        normalized.contains('token') ||
        normalized.contains('deviceid') ||
        normalized.contains('dispositivounico') ||
        normalized.contains('numerodocumento');
  }

  String _maskedSecret(String value) {
    if (value.isEmpty) return '(vacío)';
    if (value.length <= 10) return '***';
    return '${value.substring(0, 4)}...${value.substring(value.length - 3)}';
  }

  Map<String, dynamic> _responseSummary(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final message = _messageFrom(value);
      return {
        'type': 'json_object',
        'keys': map.keys.toList(growable: false),
        if (message != null) 'message': message,
      };
    }
    if (value is List) {
      return {'type': 'json_array', 'length': value.length};
    }
    if (value is String) {
      final preview = value.length > 160
          ? '${value.substring(0, 160)}...'
          : value;
      return {
        'type': 'text',
        'length': value.length,
        if (preview.isNotEmpty) 'preview': preview,
      };
    }
    return {'type': value.runtimeType.toString()};
  }

  String _safeErrorMessage(Object error) {
    final message = error.toString();
    return message.length > 240 ? '${message.substring(0, 240)}...' : message;
  }
}

class AuthSessionException implements Exception {
  const AuthSessionException({
    this.statusCode,
    this.message,
    this.isNetwork = false,
  });

  const AuthSessionException.network(String message)
    : this(message: message, isNetwork: true);

  final int? statusCode;
  final String? message;
  final bool isNetwork;

  @override
  String toString() => message ?? 'Error de autenticación';
}
