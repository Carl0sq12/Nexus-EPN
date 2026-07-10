import '../repositories/auth_preferences_repository.dart';

class SetBiometricEnabledUseCase {
  final AuthPreferencesRepository repository;

  const SetBiometricEnabledUseCase(this.repository);

  Future<void> call(bool enabled) {
    return repository.setBiometricEnabled(enabled);
  }
}
