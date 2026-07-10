import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/auth_preferences_local_datasource.dart';
import '../../data/repositories/auth_preferences_repository_impl.dart';
import '../../domain/entities/auth_preferences.dart';
import '../../domain/repositories/auth_preferences_repository.dart';
import '../../domain/usecases/get_auth_preferences_usecase.dart';
import '../../domain/usecases/save_remembered_account_usecase.dart';
import '../../domain/usecases/set_biometric_enabled_usecase.dart';
import '../../domain/usecases/set_biometric_prompted_usecase.dart';

final authPreferencesDatasourceProvider =
    Provider<AuthPreferencesLocalDatasource>(
      (ref) => AuthPreferencesLocalDatasource(),
    );

final authPreferencesRepositoryProvider = Provider<AuthPreferencesRepository>(
  (ref) => AuthPreferencesRepositoryImpl(
    ref.watch(authPreferencesDatasourceProvider),
  ),
);

final getAuthPreferencesUseCaseProvider = Provider<GetAuthPreferencesUseCase>(
  (ref) =>
      GetAuthPreferencesUseCase(ref.watch(authPreferencesRepositoryProvider)),
);

final saveRememberedAccountUseCaseProvider =
    Provider<SaveRememberedAccountUseCase>(
      (ref) => SaveRememberedAccountUseCase(
        ref.watch(authPreferencesRepositoryProvider),
      ),
    );

final setBiometricEnabledUseCaseProvider = Provider<SetBiometricEnabledUseCase>(
  (ref) =>
      SetBiometricEnabledUseCase(ref.watch(authPreferencesRepositoryProvider)),
);

final setBiometricPromptedUseCaseProvider =
    Provider<SetBiometricPromptedUseCase>(
      (ref) => SetBiometricPromptedUseCase(
        ref.watch(authPreferencesRepositoryProvider),
      ),
    );

class AuthPreferencesNotifier
    extends StateNotifier<AsyncValue<AuthPreferences>> {
  final Ref ref;

  AuthPreferencesNotifier(this.ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final preferences = await ref.read(getAuthPreferencesUseCaseProvider)();
      state = AsyncValue.data(preferences);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveRememberedAccount({
    required bool remember,
    required String? email,
  }) async {
    await ref.read(saveRememberedAccountUseCaseProvider)(
      remember: remember,
      email: email,
    );
    await load();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await ref.read(setBiometricEnabledUseCaseProvider)(enabled);
    await ref.read(setBiometricPromptedUseCaseProvider)(true);
    await load();
  }

  Future<void> markBiometricPrompted() async {
    await ref.read(setBiometricPromptedUseCaseProvider)(true);
    await load();
  }
}

final authPreferencesProvider =
    StateNotifierProvider<AuthPreferencesNotifier, AsyncValue<AuthPreferences>>(
      (ref) => AuthPreferencesNotifier(ref),
    );
