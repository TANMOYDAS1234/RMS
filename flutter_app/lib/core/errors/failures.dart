// ─── Failure Types ───────────────────────────────────────────────────────────

abstract class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Check your connection.']);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class VersionConflictFailure extends Failure {
  final int serverVersion;
  const VersionConflictFailure(this.serverVersion)
      : super('Order was modified by another user. Please refresh.');
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
