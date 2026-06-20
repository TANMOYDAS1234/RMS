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
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  String? _lastToken;
  String? _lastTableId;
  String? _lastBranchId;
  String? _lastRole;

  Stream<SocketState> get stateStream => _stateController.stream;
  Stream<WsEvent> get eventStream => _eventController.stream;
  SocketState _state = SocketState.disconnected;
  SocketState get state => _state;

  /// Connect with either a staff JWT or QR customer routing keys.
  ///
  /// Staff: pass [token] only. The gateway joins the socket to a `role:X`
  /// room based on what's in the JWT.
  ///
  /// QR customer: pass an empty token and supply [tableId] + [branchId].
  /// The gateway joins us to `table:<tableId>` + `branch:<branchId>` so
  /// the customer only sees events for their own table — no cross-tenant
  /// leak of strangers' orders.
  void connect(String token, {String? tableId, String? branchId, String? role}) {
    _lastToken = token;
    _lastTableId = tableId;
    _lastBranchId = branchId;
    _lastRole = role;
    _reconnectTimer?.cancel();
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    _setState(SocketState.connecting);
    final auth = <String, dynamic>{
      if (token.isNotEmpty) 'token': token,
      if (tableId != null) 'tableId': tableId,
      if (branchId != null) 'branchId': branchId,
      if (role != null) 'role': role,
    };
    final socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth(auth)
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );
    _socket = socket;

    socket
      ..onConnect((_) {
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
        _setState(SocketState.connected);
      })
      ..onDisconnect((_) {
        _setState(SocketState.disconnected);
        _scheduleReconnect();
      })
      ..onConnectError((_) {
        _setState(SocketState.disconnected);
        _setState(SocketState.error);
        _scheduleReconnect();
      })
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

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    final attempt = _reconnectAttempt.clamp(0, 5);
    final delaySecs = (1 << attempt).clamp(1, 30);
    if (_reconnectAttempt < 5) _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySecs), () {
      if (_lastToken == null) return;
      connect(
        _lastToken!,
        tableId: _lastTableId,
        branchId: _lastBranchId,
        role: _lastRole,
      );
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _lastToken = null;
    _socket?.disconnect();
  }

  void dispose() {
    _reconnectTimer?.cancel();
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
