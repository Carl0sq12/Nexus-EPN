import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case para cerrar la sesión del usuario actual.
class SignOutUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;

  const SignOutUseCase(this.repository);

  @override
  Future<void> call(NoParams params) async {
    return repository.signOut();
  }
}
