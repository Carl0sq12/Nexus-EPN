import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/providers/session_data_provider.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Datasource provider for auth remote datasource.
final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(
    account: ref.watch(accountProvider),
    databases: ref.watch(databasesProvider),
  ),
);

/// Repository provider for auth.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(remote: ref.read(authRemoteDatasourceProvider)),
);

/// StateNotifier that manages authentication actions and exposes `AsyncValue<AuthUser?>`
class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AsyncValue.data(null));

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signIn(email, password);
      await ref.read(authSessionControllerProvider.notifier).refresh();
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<AuthUser?> signUp(
    String email,
    String password,
    String role, [
    String? fullName,
  ]) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        role: role,
        fullName: fullName,
      );
      await ref.read(authSessionControllerProvider.notifier).refresh();
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut();
      await ref.read(authSessionControllerProvider.notifier).clear();
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _repo.resetPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> resendVerification() async {
    await _repo.resendVerification();
  }
}

/// Public provider for authentication state and actions.
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>(
  (ref) {
    return AuthNotifier(ref);
  },
);
