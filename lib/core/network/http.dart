import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/utils/constants.dart';
import 'package:file_cast/data/models/error_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

class Http {
  Http({
    required Client client,
    required String baseUrl,
    required String userAgent,
    required String ip,
    String? uniqueDeviceId,
  }) : _client = client,
       _baseUrl = baseUrl,
       _userAgent = userAgent,
       _ip = ip,
       _uniqueDeviceId = uniqueDeviceId;

  final Client _client;
  final String _baseUrl;
  final String _userAgent;
  final String _ip;
  //final IpServices _ipServices;
  final String? _uniqueDeviceId;

  String get xAplicacion => appMp;

  //static Function()? onUnauthorized;

  Future<Either<ErrorModel, R>> request<R>(
    String path, {
    required R Function(dynamic responseBody) onSucces,
    HttpMethod method = HttpMethod.get,
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    Map<String, dynamic> body = const {},
    Duration timeOut = const Duration(seconds: 60),
    bool isImage = false,
    bool isFile = false,
    bool isFileV2 = false,
    bool isAppStatic = false,
  }) async {
    // final ipServer = await _ipServices.ipServer;
    // Haremos que imprima logs para saber lso errores
    Map<String, dynamic> logs = {};
    StackTrace? stackTrace;

    try {
      Uri url;
      /* if (ipServer != null) {
        url = Uri.parse(
          path.startsWith('http') ? path : '$ipServer$path',
        );
      } else {
        url = Uri.parse(
          path.startsWith('http') ? path : '$_baseUrl$path',
        );
      } */
      url = Uri.parse(
        path.startsWith('http') || path.startsWith('https')
            ? path
            : '$_baseUrl$path',
      );
      if (queryParameters.isNotEmpty) {
        url = url.replace(
          queryParameters: queryParameters,
        );
      }

      final Map<String, String> requestHeaders = {
        'x-aplicacion': isAppStatic ? 'roma' : xAplicacion,
        'x-user-ip': _ip,
        'user-agent': _userAgent,
        if (_uniqueDeviceId != null) 'x-dispositivo-unico': _uniqueDeviceId,
        if (isImage)
          'Accept': 'image/*'
        else if (isFile)
          'Accept': 'application/pdf'
        else if (isFileV2)
          'Accept': '*/*'
        else
          'Content-Type': 'application/json',
        ...headers,
      };

      late final Response response;

      final bodyString = json.encode(body);

      // antes de hacer la solicitud mandamos a log la url
      logs = {
        'url': url.toString(),
        'headers': requestHeaders,
        'method': method.name,
        'body': body,
        'startTime': DateTime.now().toString(),
      };

      switch (method) {
        case HttpMethod.get:
          response = await _client
              .get(
                url,
                headers: requestHeaders,
              )
              .timeout(timeOut);
        case HttpMethod.post:
          response = await _client
              .post(
                url,
                headers: requestHeaders,
                body: bodyString,
              )
              .timeout(timeOut);
        case HttpMethod.put:
          response = await _client
              .put(
                url,
                headers: requestHeaders,
                body: bodyString,
              )
              .timeout(timeOut);
        case HttpMethod.patch:
          response = await _client
              .patch(
                url,
                headers: requestHeaders,
                body: bodyString,
              )
              .timeout(timeOut);
        case HttpMethod.delete:
          response = await _client
              .delete(
                url,
                headers: requestHeaders,
                body: bodyString,
              )
              .timeout(timeOut);
      }

      final statusCode = response.statusCode;
      final responseBody = isImage
          ? response
          : isFile
          ? response
          : isFileV2
          ? response.bodyBytes
          : parserResponseBody(response.body);
      //print("Aqui muestra lo que devuelve el responseBody: $responseBody");
      logs = {
        ...logs,
        'statusCode': statusCode,
        'responseBody': responseBody,
      };

      if (statusCode >= 200 && statusCode < 300) {
        // aqui le pasamos el valor retornado de la funcion
        // print('Respuesta Exitosa');
        return Either.right(
          onSucces(responseBody),
        );
      }

      if (statusCode == 401) {
        /* if (onUnauthorized != null) {
          onUnauthorized!();
        } */
        return Either.left(
          ErrorModel.fromJson(responseBody as Map<String, dynamic>),
        );
      }

      return Either.left(
        ErrorModel.fromJson(responseBody as Map<String, dynamic>),
      );
    } catch (e, s) {
      stackTrace = s;
      logs = {
        ...logs,
        'exception': e.runtimeType.toString(),
        // 'stacktrace': s.toString(),
      };
      if (e is SocketException || e is ClientException) {
        logs = {
          ...logs,
          'exception': 'NetworkException',
        };
        // Si entra aqui es por error de conexion
        return Either.left(ErrorModel(message: 'Error de conexion'));
      }

      return Either.left(ErrorModel(message: 'Error desconocido'));
    } finally {
      logs = {
        ...logs,
        'endTime': DateTime.now().toString(),
      };
      if (kDebugMode && !isImage && !isFile && !isFileV2) {
        log(
          '''------------------------------------------------
          ${const JsonEncoder.withIndent('  ').convert(logs)}
          ---------------------------------------------''',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<Either<ErrorModel, R>> multipartRequest<R>(
    String path, {
    required R Function(dynamic responseBody) onSuccess,
    HttpMethod method = HttpMethod.post,
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    Map<String, String> fields = const {},
    MultipartFile? files,
    Duration timeOut = const Duration(seconds: 60),
  }) async {
    Map<String, dynamic> logs = {};
    StackTrace? stackTrace;

    try {
      Uri url = Uri.parse(
        path.startsWith('http') || path.startsWith('https')
            ? path
            : '$_baseUrl$path',
      );

      if (queryParameters.isNotEmpty) {
        url = url.replace(queryParameters: queryParameters);
      }

      final request = MultipartRequest(method.name, url);

      // Configurar headers
      request.headers.addAll({
        'x-aplicacion': xAplicacion,
        ...headers,
      });

      // Añadir campos del formulario
      request.fields.addAll(fields);

      // Añadir archivos
      // request.files.addAll(files);
      if (files != null) request.files.add(files);

      logs = {
        'url': url.toString(),
        'headers': request.headers,
        'method': method.name,
        'fields': fields,
        'file': files?.field,
        'startTime': DateTime.now().toString(),
      };

      final response = await request.send().timeout(timeOut);
      final responseBody = await response.stream.bytesToString();
      final parsedBody = parserResponseBody(responseBody);
      final statusCode = response.statusCode;

      logs = {
        ...logs,
        'statusCode': statusCode,
        'responseBody': parsedBody,
      };

      if (statusCode >= 200 && statusCode < 300) {
        return Either.right(onSuccess(parsedBody));
      }

      if (statusCode == 401) {
        /* if (onUnauthorized != null) {
          onUnauthorized!();
        } */
        return Either.left(
          ErrorModel.fromJson(parsedBody as Map<String, dynamic>),
        );
      }

      return Either.left(
        ErrorModel.fromJson(parsedBody as Map<String, dynamic>),
      );
    } catch (e, s) {
      stackTrace = s;
      logs = {
        ...logs,
        'exception': e.runtimeType.toString(),
      };

      if (e is SocketException || e is ClientException) {
        return Either.left(ErrorModel(message: 'Error de conexión'));
      }

      return Either.left(ErrorModel(message: 'Error en multipart request: $e'));
    } finally {
      logs = {
        ...logs,
        'endTime': DateTime.now().toString(),
      };
      if (kDebugMode) {
        log(
          '''------------------------------------------------
          ${const JsonEncoder.withIndent('  ').convert(logs)}
          ---------------------------------------------''',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<Either<ErrorModel, R>> multipartRequestList<R>(
    String path, {
    required R Function(dynamic responseBody) onSuccess,
    HttpMethod method = HttpMethod.post,
    Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {},
    Map<String, String> fields = const {},
    List<MultipartFile>? files,
    Duration timeOut = const Duration(seconds: 60),
  }) async {
    Map<String, dynamic> logs = {};
    StackTrace? stackTrace;

    try {
      Uri url = Uri.parse(
        path.startsWith('http') || path.startsWith('https')
            ? path
            : '$_baseUrl$path',
      );

      if (queryParameters.isNotEmpty) {
        url = url.replace(queryParameters: queryParameters);
      }

      final request = MultipartRequest(method.name, url);

      // Configurar headers
      request.headers.addAll({
        'x-aplicacion': xAplicacion,
        ...headers,
      });

      // Añadir campos del formulario
      request.fields.addAll(fields);

      // Añadir archivos
      // request.files.addAll(files);
      if (files != null) {
        request.files.addAll(files);
      }

      logs = {
        'url': url.toString(),
        'headers': request.headers,
        'method': method.name,
        'fields': fields,
        'files': files?.map((f) => f.field).toList(), // ⭐ Para un log más claro
        'startTime': DateTime.now().toString(),
      };

      final response = await request.send().timeout(timeOut);
      final responseBody = await response.stream.bytesToString();
      final parsedBody = parserResponseBody(responseBody);
      final statusCode = response.statusCode;

      logs = {
        ...logs,
        'statusCode': statusCode,
        'responseBody': parsedBody,
      };

      if (statusCode >= 200 && statusCode < 300) {
        return Either.right(onSuccess(parsedBody));
      }

      if (statusCode == 401) {
        /* if (onUnauthorized != null) {
          onUnauthorized!();
        } */
        return Either.left(
          ErrorModel.fromJson(parsedBody as Map<String, dynamic>),
        );
      }

      return Either.left(
        ErrorModel.fromJson(parsedBody as Map<String, dynamic>),
      );
    } catch (e, s) {
      stackTrace = s;
      logs = {
        ...logs,
        'exception': e.runtimeType.toString(),
      };

      if (e is SocketException || e is ClientException) {
        return Either.left(ErrorModel(message: 'Error de conexión'));
      }

      return Either.left(ErrorModel(message: 'Error en multipart request: $e'));
    } finally {
      logs = {
        ...logs,
        'endTime': DateTime.now().toString(),
      };
      if (kDebugMode) {
        log(
          '''------------------------------------------------
          ${const JsonEncoder.withIndent('  ').convert(logs)}
          ---------------------------------------------''',
          stackTrace: stackTrace,
        );
      }
    }
  }

  static Future<MultipartFile> multipartFileFromPath({
    required String field,
    required String filePath,
    String? filename,
    MediaType? contentType,
  }) async {
    return MultipartFile.fromPath(
      field,
      filePath,
      filename: filename,
      contentType: contentType,
    );
  }

  static MultipartFile multipartFileFromBytes({
    required String field,
    required List<int> bytes,
    required String filename,
    MediaType? contentType,
  }) {
    return MultipartFile.fromBytes(
      field,
      bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  static MultipartFile multipartFileFromString({
    required String field,
    required String value,
  }) {
    return MultipartFile.fromString(field, value);
  }
}

// casos de Error

class HttpFailure {
  HttpFailure({
    this.statusCode,
    this.exception,
  });

  final int? statusCode;
  final Object? exception;
}

class NewtworkException {}

enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
}

// parseamos el response.body para el log
dynamic parserResponseBody(String responseBody) {
  try {
    return jsonDecode(responseBody);
  } catch (_) {
    return responseBody;
  }
}
