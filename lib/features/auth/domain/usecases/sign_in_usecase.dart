import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

/// Use case para iniciar sesión con correo y contraseña.
class SignInUseCase implements UseCase<AuthUser, SignInParams> {
  final AuthRepository repository;

  const SignInUseCase(this.repository);

  @override
  Future<AuthUser> call(SignInParams params) async {
    return repository.signIn(params.email, params.password);
  }
}

/// Parámetros para `SignInUseCase`.
class SignInParams extends Equatable {
  final String email;
  final String password;

  const SignInParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
