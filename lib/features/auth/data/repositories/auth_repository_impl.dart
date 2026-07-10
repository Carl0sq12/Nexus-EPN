import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementación del repositorio de autenticación que usa el datasource
/// remoto para realizar las operaciones.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remote;

  const AuthRepositoryImpl({required this.remote});

  @override
  Future<AuthUser> signIn(String email, String password) async {
    final model = await remote.signIn(email, password);
    return model;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String role,
    String? fullName,
  }) async {
    final model = await remote.signUp(
      email: email,
      password: password,
      role: role,
      fullName: fullName,
    );
    return model;
  }

  @override
  Future<void> signOut() async {
    return remote.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    return remote.resetPassword(email);
  }
}
