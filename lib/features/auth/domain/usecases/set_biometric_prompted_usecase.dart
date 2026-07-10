import '../repositories/auth_preferences_repository.dart';

class SetBiometricPromptedUseCase {
  final AuthPreferencesRepository repository;

  const SetBiometricPromptedUseCase(this.repository);

  Future<void> call(bool prompted) {
    return repository.setBiometricPrompted(prompted);
  }
}
