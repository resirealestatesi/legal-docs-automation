class AppException implements Exception {
  final String message;
  final int? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class ServerException extends AppException {
  const ServerException({required super.message, super.code});
}

class CacheException extends AppException {
  const CacheException({required super.message, super.code});
}

class ValidationException extends AppException {
  const ValidationException({required super.message});
}

class SyncException extends AppException {
  const SyncException({required super.message, super.code});
}
