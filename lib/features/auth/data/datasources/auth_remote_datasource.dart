import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/errors/exceptions.dart' show ServerException;
import '../models/auth_user_model.dart';

/// Datasource remoto que realiza llamadas a Supabase Auth y a la tabla
/// `profiles` para obtener/crear información del usuario.
class AuthRemoteDatasource {
  final SupabaseClient _client = supabaseClient;

  // URLs de redirección para los flujos de confirmación de correo y
  // recuperación de contraseña. Deben coincidir EXACTO con las URLs
  // agregadas en Supabase Dashboard > Authentication > URL Configuration.
  static const String _confirmSignUpRedirect =
      'https://nexus-five-chi.vercel.app/auth-callback';
  static const String _resetPasswordRedirect =
      'https://nexus-five-chi.vercel.app/reset-password';

  /// Inicia sesión y devuelve el usuario con su perfil si existe.
  Future<AuthUserModel> signIn(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) throw ServerException('No user returned from auth');

      // Try to fetch profile from `profiles` table
      final profileResp = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profileResp != null) {
        return AuthUserModel.fromJson(profileResp);
      }
      return AuthUserModel(
        id: user.id,
        email: user.email ?? email,
        role: 'passenger',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Registra usuario en Supabase Auth.
  ///
  /// IMPORTANTE: la fila en `profiles` NO se crea manualmente acá.
  /// Existe un trigger `on_auth_user_created` en `auth.users` (función
  /// `handle_new_user`) que crea la fila automáticamente leyendo
  /// `role` y `full_name` desde `raw_user_meta_data`. Por eso es
  /// obligatorio mandar esos valores en el parámetro `data` de
  /// `signUp`. Si además se hiciera un insert manual acá, se rompería
  /// por llave duplicada (el trigger ya insertó esa fila).
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String role,
    String? fullName,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _confirmSignUpRedirect,
        data: {'role': role, 'full_name': fullName},
      );
      final user = res.user;
      if (user == null) throw ServerException('Failed to create auth user');

      // El trigger on_auth_user_created ya creó la fila en profiles.
      // Solo la leemos para devolver el modelo completo.
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Fallback por si el trigger aún no terminó de commitear
        // (poco probable, pero evita romper el flujo de la UI).
        return AuthUserModel(
          id: user.id,
          email: email,
          fullName: fullName,
          role: role,
        );
      }
      return AuthUserModel.fromJson(profile);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Cierra la sesión actual.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Solicita restablecimiento de contraseña por correo.
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _resetPasswordRedirect,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
