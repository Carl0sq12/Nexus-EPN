import '../entities/auth_preferences.dart';
import '../repositories/auth_preferences_repository.dart';

class GetAuthPreferencesUseCase {
  final AuthPreferencesRepository repository;

  const GetAuthPreferencesUseCase(this.repository);

  Future<AuthPreferences> call() {
    return repository.getPreferences();
  }
}
