/* import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  late WebSocketChannel _channel;
  final StreamController<dynamic> _eventController =
      StreamController.broadcast();
  bool _isConnected = false;
  String? _currentUrl;

  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Stream<dynamic> get messageStream => _eventController.stream;

  Future<void> connect(String url) async {
    String wsBaseUrl =
        url.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');

    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    print('wsBaseUrl: $wsBaseUrl');
    // final uri = Uri.parse(wsBaseUrl).replace(path: '/chat', queryParameters: {
    //   'usuarioId': userId,
    //   'aplicacion': app,
    // });
    // print('URI final: $uri');
    /*  final headers = {
      'Authorization': 'Bearer $token',
    }; */
    final headers = {
      'Authorization':
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOnsidXN1YXJpb0lkIjoxNiwiYXBsaWNhY2lvbklkIjo3NSwiZnVuY2lvbmFyaW9JZCI6MTA0LCJtc1BlcnNvbmFJZCI6MTYsImluc3RpdHVjaW9uSWQiOjEsIm9maWNpbmFJZCI6MSwibXVuaWNpcGlvSWQiOjEsImRlcGFydGFtZW50b0lkIjoxLCJwZXJmaWxQZXJzb25hSWQiOjExOSwiY2kiOiI3NDg0OTE5Iiwibm9tYnJlQ29tcGxldG8iOiJBUklFTCBCRU5KQU1JTiBUT1JSSUNPUyBQQURJTExBIiwiYXBsaWNhY2lvblRhZyI6Imp1c3RpY2lhLWxpYnJlIn0sImlhdCI6MTc0Nzc0OTQ2NCwiZXhwIjoxNzQ3NzcxMDY0fQ.-KoaL-mQM3w3MxuwXA9yApsuPfc1UA7jhzl7St4gWrk',
      // 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOnsidXN1YXJpb0lkIjoxNiwiYXBsaWNhY2lvbklkIjo2OCwiZnVuY2lvbmFyaW9JZCI6MTA0LCJtc1BlcnNvbmFJZCI6MTYsImluc3RpdHVjaW9uSWQiOjEsIm9maWNpbmFJZCI6MSwibXVuaWNpcGlvSWQiOjEsImRlcGFydGFtZW50b0lkIjoxLCJwZXJmaWxQZXJzb25hSWQiOjExOSwiY2kiOiI3NDg0OTE5Iiwibm9tYnJlQ29tcGxldG8iOiJBUklFTCBCRU5KQU1JTiBUT1JSSUNPUyBQQURJTExBIiwiYXBsaWNhY2lvblRhZyI6Imp1c3RpY2lhLWxpYnJlIn0sImlhdCI6MTc0Nzc1MDc4OSwiZXhwIjoxNzQ3NzY1MTg5fQ.qEHXimJdc6ly8nWcyfSEoJHr7AP66B4sKaUDIQ6879E',
    };

    // print(uri);
    print('Bearer $headers');
    await disconnect();

    try {
      _channel = IOWebSocketChannel.connect(
        wsBaseUrl,
        headers: headers,
        customClient: httpClient,
      );
      /*  print('_channel1');
      final webSocket = await WebSocket.connect(
        uri.toString(),
        headers: headers,
        customClient: httpClient,
      );
      print('_channel2');
      print('_channel3');
      _channel = IOWebSocketChannel(webSocket); */
      _currentUrl =
          'ws://172.27.38.52:3001/chat/?usuarioId=104&aplicacion=webchat';
      print('_channel4');
      _isConnected = true;

      _channel.stream.listen(
        (message) => _hadleMessage(message),
        onError: (error) => _hadleError(error),
        onDone: () => _handleDisconnection(),
      );
    } catch (e) {
      throw Exception('No se pudo conectar al WebSocket: $e');
    }
  }

  void _hadleMessage(dynamic message) {
    try {
      final parsedMessage = message;
      print('Mensaje recibido: $parsedMessage');
      _eventController.add(parsedMessage);
    } catch (e) {
      print('Error al manejar el mensaje: $e');
    }
  }

  void _hadleError(dynamic error) {
    print('Error en el WebSocket: $error');
    _reconnect();
  }

  void _handleDisconnection() {
    print('WebSocket disconnected');
    _reconnect();
  }

  Future<void> _reconnect() async {
    if (!_isConnected || _currentUrl == null) return;

    _isConnected = false;
    print('asdasd111');
    await Future.delayed(const Duration(seconds: 2));
    if (_currentUrl != null) {
      await connect(_currentUrl!);
    }
  }

  Future<void> disconnect() async {
    print('Mensaje recibidoasdadkbslkasd');
    if (_isConnected) {
      await _channel.sink.close();
      _isConnected = false;
      _currentUrl = null;
    }
  }

  void sendMessage(dynamic message) {
    if (_isConnected) {
      _channel.sink.add(message);
    }
  }
}
 */

/* import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebSocketService {
  late IO.Socket _socket;
  final StreamController<dynamic> _eventController =
      StreamController.broadcast();
  bool _isConnected = false;
  String? _currentUrl;

  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  /// Stream of incoming messages
  Stream<dynamic> get messageStream => _eventController.stream;

  /// Connect to the Socket.IO server at [url]
  ///
  /// [url] should include the protocol and any query parameters:
  /// e.g. 'http://172.27.38.52:39547/chat?usuarioId=104&aplicacion=webchat'
  Future<void> connect(String url, {String? authToken}) async {
    // If already connected to the same URL, skip
    if (_isConnected && _currentUrl == url) return;

    // Disconnect previous socket if any
    await disconnect();

    _currentUrl = url;

    // Initialize Socket.IO client
    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket']) // for WebSocket transport only
          .disableAutoConnect() // we'll call connect manually
          // add auth token if provided
          .setExtraHeaders(authToken != null
              ? {
                  'Authorization': 'Bearer $authToken',
                }
              : {})
          .build(),
    );

    // Register event handlers
    _socket.on('connect', (_) {
      _isConnected = true;
      print('Socket.IO connected to $_currentUrl');
    });

    _socket.on('disconnect', (_) {
      _isConnected = false;
      print('Socket.IO disconnected');
      // Optionally attempt reconnection
      _reconnect();
    });

    _socket.on('error', (err) {
      print('Socket.IO error:\n $err');
      _eventController.addError(err);
      // Optionally attempt reconnection
      _reconnect();
    });

    // Listen for a generic message event; adjust the event name as needed
    _socket.on('mensaje', (data) {
      print('Mensaje recibido: \$data');
      _eventController.add(data);
    });

    // Finally, connect
    _socket.connect();
  }

  void _reconnect() async {
    if (_currentUrl == null) return;
    // small delay before reconnect
    await Future.delayed(const Duration(seconds: 2));
    if (!_isConnected && _currentUrl != null) {
      print('Reconnecting to \$_currentUrl...');
      _socket.connect();
    }
  }

  /// Disconnect the socket
  Future<void> disconnect() async {
    if (_isConnected) {
      _socket.disconnect();
      _socket.dispose();
      _isConnected = false;
      _currentUrl = null;
    }
  }

  /// Send a message using [event] name and [message] payload
  ///
  /// e.g. sendMessage('mensaje', {'text': 'Hola'});
  void sendMessage(String event, dynamic message) {
    if (_isConnected) {
      _socket.emit(event, message);
    } else {
      print('Cannot send message, socket not connected');
    }
  }
} */
