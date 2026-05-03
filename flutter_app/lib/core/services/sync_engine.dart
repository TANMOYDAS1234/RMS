// ─── Sync Engine ─────────────────────────────────────────────────────────────
// Queues offline mutations, replays on reconnect, handles conflicts

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import '../network/dio_client.dart';

class PendingOperation {
  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  int retryCount;

  PendingOperation({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'payload': payload,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingOperation.fromJson(Map<String, dynamic> json) =>
      PendingOperation(
        id: json['id'],
        endpoint: json['endpoint'],
        method: json['method'],
        payload: Map<String, dynamic>.from(json['payload']),
        idempotencyKey: json['idempotencyKey'],
        createdAt: DateTime.parse(json['createdAt']),
        retryCount: json['retryCount'] ?? 0,
      );
}

class SyncEngine {
  static const _boxName = 'sync_queue';
  late Box<String> _box;
  final _uuid = const Uuid();
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      if (result != ConnectivityResult.none) {
        flushQueue();
      }
    });
  }

  Future<void> enqueue({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    final op = PendingOperation(
      id: _uuid.v4(),
      endpoint: endpoint,
      method: method,
      payload: payload,
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      createdAt: DateTime.now(),
    );
    await _box.put(op.id, jsonEncode(op.toJson()));
  }

  Future<void> flushQueue() async {
    if (_isSyncing || _box.isEmpty) return;
    _isSyncing = true;

    final dio = createDioClient(null); // inject token in real impl
    final keys = _box.keys.toList();

    for (final key in keys) {
      final raw = _box.get(key as String);
      if (raw == null) continue;

      final op = PendingOperation.fromJson(jsonDecode(raw));

      try {
        await _executeOperation(dio, op);
        await _box.delete(key);
      } catch (e) {
        op.retryCount++;
        if (op.retryCount >= AppConfig.maxRetries) {
          await _box.delete(key); // dead-letter — log to analytics
        } else {
          await _box.put(key, jsonEncode(op.toJson()));
        }
      }
    }

    _isSyncing = false;
  }

  Future<void> _executeOperation(dynamic dio, PendingOperation op) async {
    final headers = {'Idempotency-Key': op.idempotencyKey};
    switch (op.method.toUpperCase()) {
      case 'POST':
        await dio.post(op.endpoint, data: op.payload, options: _opts(headers));
      case 'PATCH':
        await dio.patch(op.endpoint, data: op.payload, options: _opts(headers));
      case 'PUT':
        await dio.put(op.endpoint, data: op.payload, options: _opts(headers));
      case 'DELETE':
        await dio.delete(op.endpoint, options: _opts(headers));
    }
  }

  dynamic _opts(Map<String, String> headers) => Options(headers: headers);

  int get pendingCount => _box.length;

  void dispose() {
    _connectivitySub?.cancel();
    _box.close();
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
