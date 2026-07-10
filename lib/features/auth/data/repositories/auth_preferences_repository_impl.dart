import '../../domain/entities/auth_preferences.dart';
import '../../domain/repositories/auth_preferences_repository.dart';
import '../datasources/auth_preferences_local_datasource.dart';

class AuthPreferencesRepositoryImpl implements AuthPreferencesRepository {
  final AuthPreferencesLocalDatasource datasource;

  const AuthPreferencesRepositoryImpl(this.datasource);

  @override
  Future<AuthPreferences> getPreferences() {
    return datasource.getPreferences();
  }

  @override
  Future<void> saveRememberedAccount({
    required bool remember,
    required String? email,
  }) {
    return datasource.saveRememberedAccount(remember: remember, email: email);
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) {
    return datasource.setBiometricEnabled(enabled);
  }

  @override
  Future<void> setBiometricPrompted(bool prompted) {
    return datasource.setBiometricPrompted(prompted);
  }
}
