import 'package:equatable/equatable.dart';

/// Local authentication preferences.
///
/// Business rules:
/// - Remember account stores only the institutional email and preference.
/// - Passwords are never stored locally.
/// - Biometrics only store a local opt-in flag, never credentials.
class AuthPreferences extends Equatable {
  final bool rememberAccount;
  final String? rememberedEmail;
  final bool biometricEnabled;
  final bool biometricPrompted;

  const AuthPreferences({
    required this.rememberAccount,
    required this.biometricEnabled,
    required this.biometricPrompted,
    this.rememberedEmail,
  });

  const AuthPreferences.empty()
    : rememberAccount = false,
      rememberedEmail = null,
      biometricEnabled = false,
      biometricPrompted = false;

  @override
  List<Object?> get props => [
    rememberAccount,
    rememberedEmail,
    biometricEnabled,
    biometricPrompted,
  ];
}
