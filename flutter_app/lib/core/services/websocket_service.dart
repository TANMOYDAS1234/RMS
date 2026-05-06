// ─── WebSocket Service ───────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

enum SocketState { connecting, connected, disconnected, error }

class WebSocketService {
  late io.Socket _socket;
  final _stateController = StreamController<SocketState>.broadcast();
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SocketState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  SocketState _state = SocketState.disconnected;
  SocketState get state => _state;

  void connect(String token) {
    _socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket
      ..onConnect((_) => _setState(SocketState.connected))
      ..onDisconnect((_) => _setState(SocketState.disconnected))
      ..onConnectError((_) => _setState(SocketState.error))
      ..on('order:updated', (data) => _emit('order:updated', data))
      ..on('order:created', (data) => _emit('order:created', data))
      ..on('kitchen:progress', (data) => _emit('kitchen:progress', data))
      ..on('table:updated', (data) => _emit('table:updated', data));
  }

  void emit(String event, Map<String, dynamic> data) {
    if (_state == SocketState.connected) {
      _socket.emit(event, data);
    }
  }

  void _setState(SocketState s) {
    _state = s;
    _stateController.add(s);
  }

  void _emit(String event, dynamic data) {
    _eventController.add({'event': event, 'data': data});
  }

  void disconnect() => _socket.disconnect();

  void dispose() {
    _socket.dispose();
    _stateController.close();
    _eventController.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});
