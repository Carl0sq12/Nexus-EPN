import '../entities/auth_user.dart';

/// Interfaz del repositorio de autenticación — define las operaciones de auth
/// sin exponer detalles de implementación (datasources/supabase).
abstract class AuthRepository {
  /// Inicia sesión con correo y contraseña.
  Future<AuthUser> signIn(String email, String password);

  /// Registra un nuevo usuario con rol y datos opcionales.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String role,
    String? fullName,
  });

  /// Cierra la sesión del usuario actual.
  Future<void> signOut();

  /// Envía una solicitud de restablecimiento de contraseña para el correo.
  Future<void> resetPassword(String email);
}
