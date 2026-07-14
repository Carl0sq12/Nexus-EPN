import 'package:equatable/equatable.dart';

/// Clase base que representa una falla en la capa de dominio/data.
abstract class Failure extends Equatable {
  /// Mensaje legible para depuración o UI.
  final String message;

  const Failure([this.message = '']);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => message.isEmpty ? runtimeType.toString() : message;
}

/// Representa errores del servidor (500, respuestas inválidas, etc.).
class ServerFailure extends Failure {
  const ServerFailure([String message = '']) : super(message);
}

/// Representa errores de red (sin conexión, timeouts).
class NetworkFailure extends Failure {
  const NetworkFailure([String message = '']) : super(message);
}

/// Representa fallos relacionados con la autenticación.
class AuthFailure extends Failure {
  const AuthFailure([String message = '']) : super(message);
}

/// Representa fallos en la caché/local storage.
class CacheFailure extends Failure {
  const CacheFailure([String message = '']) : super(message);
}
