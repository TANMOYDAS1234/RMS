// ─── WebSocket Service ───────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

enum SocketState { connecting, connected, disconnected, error }

class WsEvent {
  final String event;
  final dynamic data;
  const WsEvent(this.event, this.data);
}

class WebSocketService {
  io.Socket? _socket;
  final _stateController = StreamController<SocketState>.broadcast();
  final _eventController = StreamController<WsEvent>.broadcast();

  Stream<SocketState> get stateStream => _stateController.stream;
  Stream<WsEvent> get eventStream => _eventController.stream;
  SocketState _state = SocketState.disconnected;
  SocketState get state => _state;

  void connect(String token) {
    // Tear down any previous socket — calling connect twice used to leak.
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    _setState(SocketState.connecting);
    final socket = io.io(
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
    _socket = socket;

    socket
      ..onConnect((_) => _setState(SocketState.connected))
      ..onDisconnect((_) => _setState(SocketState.disconnected))
      ..onConnectError((_) => _setState(SocketState.error))
      ..on('order:updated', (data) => _handle('order:updated', data))
      ..on('order:created', (data) => _handle('order:created', data))
      ..on('kitchen:progress', (data) => _handle('kitchen:progress', data))
      ..on('table:updated', (data) => _handle('table:updated', data));
  }

  void emit(String event, Map<String, dynamic> data) {
    if (_state == SocketState.connected) {
      _socket?.emit(event, data);
    }
  }

  void _handle(String event, dynamic data) {
    // Send back an ack so the server stops retrying the same event.
    if (data is Map && data['_eventId'] != null) {
      _socket?.emit('ack', {'eventId': data['_eventId']});
    }
    _eventController.add(WsEvent(event, data));
  }

  void _setState(SocketState s) {
    _state = s;
    _stateController.add(s);
  }

  void disconnect() => _socket?.disconnect();

  void dispose() {
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _stateController.close();
    _eventController.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Live stream of WS events, exposed for ref.listen in screens.
final wsEventsProvider = StreamProvider<WsEvent>((ref) {
  return ref.watch(webSocketServiceProvider).eventStream;
});
