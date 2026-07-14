import 'dart:io';

import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite_config.dart';
import '../../../../core/errors/exceptions.dart' show ServerException, AuthException;
import '../../../../core/network/appwrite_helpers.dart';
import '../models/auth_user_model.dart';

/// Remote datasource for Appwrite Account + profiles collection.
class AuthRemoteDatasource {
  AuthRemoteDatasource({
    required Account account,
    required Databases databases,
  })  : _account = account,
        _databases = databases;

  final Account _account;
  final Databases _databases;

  static const String _confirmSignUpRedirect =
      'https://nexus-campus-auth.vercel.app/auth-callback.html';
  static const String _resetPasswordRedirect =
      'https://nexus-campus-auth.vercel.app/reset-password.html';

  static const String _networkErrorMessage =
      'Sin conexión a internet. Revisa Wi‑Fi o datos móviles e inténtalo de nuevo.';

  Never _throwMapped(Object e) {
    if (_isNetworkFailure(e)) {
      throw const AuthException(_networkErrorMessage);
    }
    if (e is AppwriteException) {
      throw AuthException(_mapAppwriteAuthMessage(e));
    }
    throw ServerException(e.toString());
  }

  String _mapAppwriteAuthMessage(AppwriteException e) {
    final text = '${e.message ?? ''} ${e.type ?? ''} ${e.code ?? ''}'.toLowerCase();
    if (text.contains('user_already_exists') ||
        text.contains('already exists') ||
        text.contains('user with the same id') ||
        text.contains('a user with the same')) {
      return 'Ese correo ya tiene una cuenta en Auth (no basta borrar el perfil '
          'en la base de datos). En Appwrite Console → Auth → Users bórralo '
          'y vuelve a registrarte.';
    }
    return e.message ?? e.toString();
  }

  bool _isNetworkFailure(Object e) {
    if (e is SocketException) return true;
    final text = e.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('timed out') ||
        text.contains('clientexception');
  }

  Future<AuthUserModel> signIn(String email, String password) async {
    try {
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      final user = await _account.get();

      try {
        final doc = await _databases.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.collectionProfiles,
          documentId: user.$id,
        );
        return AuthUserModel.fromJson(normalizeDocument(doc));
      } on AppwriteException {
        return AuthUserModel(
          id: user.$id,
          email: user.email.isNotEmpty ? user.email : email,
          role: 'passenger',
        );
      }
    } catch (e) {
      _throwMapped(e);
    }
  }

  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String role,
    String? fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final epnEmail = RegExp(
      r'^[\w.+-]+@epn\.edu\.ec$',
      caseSensitive: false,
    );
    if (!epnEmail.hasMatch(normalizedEmail)) {
      throw const AuthException(
        'Usa tu correo institucional @epn.edu.ec',
      );
    }

    try {
      final user = await _account.create(
        userId: ID.unique(),
        email: normalizedEmail,
        password: password,
        name: fullName,
      );

      await _account.createEmailPasswordSession(
        email: normalizedEmail,
        password: password,
      );

      final profileData = <String, dynamic>{
        'email': normalizedEmail,
        'role': role,
        if (fullName != null) 'full_name': fullName,
      };

      final doc = await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.collectionProfiles,
        documentId: user.$id,
        data: profileData,
        permissions: ownerPermissions(user.$id),
      );

      try {
        await _sendVerificationEmail();
      } catch (_) {
        // Account already exists; user can resend from verify-email screen.
      }

      return AuthUserModel.fromJson(normalizeDocument(doc));
    } catch (e) {
      _throwMapped(e);
    }
  }

  /// Resends the Appwrite email-verification link for the current session.
  Future<void> resendVerification() async {
    try {
      await _sendVerificationEmail();
    } catch (e) {
      throw AuthException(_mapVerificationError(e));
    }
  }

  Future<void> _sendVerificationEmail() async {
    await _account.createVerification(url: _confirmSignUpRedirect);
  }

  String _mapVerificationError(Object e) {
    if (_isNetworkFailure(e)) {
      return _networkErrorMessage;
    }
    final text = e.toString().toLowerCase();
    if (text.contains('url') ||
        text.contains('host must be') ||
        text.contains('invalid `url`') ||
        text.contains('invalid url')) {
      return 'Appwrite rechazó la URL de verificación. En Console → Platforms '
          'agrega Web: nexus-campus-auth.vercel.app y en Auth → Settings las '
          'Redirect URLs del proyecto.';
    }
    if (e is AppwriteException) {
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  Future<void> signOut() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (e) {
      _throwMapped(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _account.createRecovery(
        email: email,
        url: _resetPasswordRedirect,
      );
    } catch (e) {
      _throwMapped(e);
    }
  }
}
