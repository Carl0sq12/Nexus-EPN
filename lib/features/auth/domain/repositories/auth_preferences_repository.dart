import '../entities/auth_preferences.dart';

/// Repository contract for local auth preferences.
abstract class AuthPreferencesRepository {
  Future<AuthPreferences> getPreferences();

  Future<void> saveRememberedAccount({
    required bool remember,
    required String? email,
  });

  Future<void> setBiometricEnabled(bool enabled);

  Future<void> setBiometricPrompted(bool prompted);
}
