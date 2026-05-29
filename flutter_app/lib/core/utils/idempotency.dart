import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One stable Idempotency-Key per logical user action.
///
/// Use it once per action and reuse across retries — that is the whole point.
/// Old code generated a fresh `millisecondsSinceEpoch` per retry, defeating
/// the dedup guarantee on the server.
String newIdempotencyKey([String? prefix]) {
  final id = _uuid.v4();
  return prefix == null || prefix.isEmpty ? id : '$prefix-$id';
}
