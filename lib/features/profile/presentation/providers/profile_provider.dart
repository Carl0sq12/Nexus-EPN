import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../../../core/providers/session_data_provider.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';

/// Provider for the profile remote datasource.
final profileDatasourceProvider = Provider<ProfileRemoteDatasource>((ref) {
  return ProfileRemoteDatasource(
    ref.watch(databasesProvider),
    ref.watch(storageProvider),
  );
});

/// Provider for the profile repository.
final profileRepositoryProvider = Provider<ProfileRepositoryImpl>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileDatasourceProvider));
});

/// Provider for the get profile use case.
final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});

/// Provider for the update profile use case.
final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

/// Fetches a [Profile] by [userId] using [GetProfileUseCase].
final profileProvider = FutureProvider.family<Profile, String>((ref, userId) {
  return ref.watch(getProfileUseCaseProvider)(GetProfileParams(userId: userId));
});

/// State notifier that manages profile update actions.
class ProfileNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ProfileNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateProfile(
    String userId, {
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? cedula,
    String? role,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(updateProfileUseCaseProvider)(
        UpdateProfileParams(
          userId: userId,
          fullName: fullName,
          avatarUrl: avatarUrl,
          phone: phone,
          cedula: cedula,
          role: role,
        ),
      );
      ref.invalidate(profileProvider(userId));
      ref.read(sessionDataVersionProvider.notifier).state++;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [ProfileNotifier] that exposes update actions.
final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<void>>((ref) {
      return ProfileNotifier(ref);
    });
