import '../repositories/auth_preferences_repository.dart';

class SaveRememberedAccountUseCase {
  final AuthPreferencesRepository repository;

  const SaveRememberedAccountUseCase(this.repository);

  Future<void> call({required bool remember, required String? email}) {
    return repository.saveRememberedAccount(remember: remember, email: email);
  }
}
