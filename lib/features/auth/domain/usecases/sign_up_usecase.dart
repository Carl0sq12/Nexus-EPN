import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

/// Use case para registrar un nuevo usuario.
class SignUpUseCase implements UseCase<AuthUser, SignUpParams> {
  final AuthRepository repository;

  const SignUpUseCase(this.repository);

  @override
  Future<AuthUser> call(SignUpParams params) async {
    return repository.signUp(
      email: params.email,
      password: params.password,
      role: params.role,
      fullName: params.fullName,
    );
  }
}

/// Parámetros para `SignUpUseCase`.
class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String role;
  final String? fullName;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.role,
    this.fullName,
  });

  @override
  List<Object?> get props => [email, password, role, fullName];
}
