import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case para solicitar restablecimiento de contraseña.
class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  final AuthRepository repository;

  const ResetPasswordUseCase(this.repository);

  @override
  Future<void> call(ResetPasswordParams params) async {
    return repository.resetPassword(params.email);
  }
}

class ResetPasswordParams extends Equatable {
  final String email;

  const ResetPasswordParams({required this.email});

  @override
  List<Object?> get props => [email];
}
