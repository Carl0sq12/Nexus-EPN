/// Excepción lanzada cuando ocurre un error en el servidor.
class ServerException implements Exception {
  final String message;
  const ServerException([this.message = '']);
  @override
  String toString() => 'ServerException: $message';
}

/// Excepción lanzada cuando hay problemas de red (sin conexión, timeout).
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = '']);
  @override
  String toString() => 'NetworkException: $message';
}

/// Excepción relacionada con autenticación (credenciales inválidas, token expirado).
class AuthException implements Exception {
  final String message;
  const AuthException([this.message = '']);
  @override
  String toString() => message.isEmpty ? 'AuthException' : message;
}

/// Excepción lanzada al fallar operaciones de caché/local storage.
class CacheException implements Exception {
  final String message;
  const CacheException([this.message = '']);
  @override
  String toString() => 'CacheException: $message';
}
