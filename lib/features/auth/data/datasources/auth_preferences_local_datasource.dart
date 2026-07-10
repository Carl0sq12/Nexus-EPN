import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/auth_preferences.dart';

/// Local datasource for authentication preferences.
///
/// Business rule: never persist passwords. Only email, remember flag and
/// biometric opt-in are stored.
class AuthPreferencesLocalDatasource {
  static const _rememberAccountKey = 'auth_remember_account';
  static const _rememberedEmailKey = 'auth_remembered_email';
  static const _biometricEnabledKey = 'auth_biometric_enabled';
  static const _biometricPromptedKey = 'auth_biometric_prompted';

  Future<AuthPreferences> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberAccount = prefs.getBool(_rememberAccountKey) ?? false;
    return AuthPreferences(
      rememberAccount: rememberAccount,
      rememberedEmail: rememberAccount
          ? prefs.getString(_rememberedEmailKey)
          : null,
      biometricEnabled: prefs.getBool(_biometricEnabledKey) ?? false,
      biometricPrompted: prefs.getBool(_biometricPromptedKey) ?? false,
    );
  }

  Future<void> saveRememberedAccount({
    required bool remember,
    required String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberAccountKey, remember);
    if (remember && email != null && email.trim().isNotEmpty) {
      await prefs.setString(_rememberedEmailKey, email.trim());
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
    await prefs.remove('auth_password');
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  Future<void> setBiometricPrompted(bool prompted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPromptedKey, prompted);
  }
}
