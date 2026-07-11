import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/appwrite_provider.dart';
import '../../domain/usecases/send_sos_usecase.dart';
import '../../data/datasources/sos_remote_datasource.dart';
import '../../data/repositories/sos_repository_impl.dart';

/// Provider for the SOS remote datasource.
final sosDatasourceProvider = Provider<SosRemoteDatasource>((ref) {
  return SosRemoteDatasource(ref.watch(databasesProvider));
});

/// Provider for the SOS repository.
final sosRepositoryProvider = Provider<SosRepositoryImpl>((ref) {
  return SosRepositoryImpl(ref.watch(sosDatasourceProvider));
});

/// Provider for [SendSosUseCase].
final sendSosUseCaseProvider = Provider<SendSosUseCase>((ref) {
  return SendSosUseCase(ref.watch(sosRepositoryProvider));
});

/// State notifier that manages sending an SOS alert.
class SosNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  SosNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> sendSosAlert(
    String userId,
    double latitude,
    double longitude,
    String message,
    String type,
  ) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(sendSosUseCaseProvider)(
        SendSosParams(
          userId: userId,
          latitude: latitude,
          longitude: longitude,
          message: message,
          type: type,
        ),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for [SosNotifier] that exposes the send SOS alert action.
final sosNotifierProvider =
    StateNotifierProvider<SosNotifier, AsyncValue<void>>((ref) {
      return SosNotifier(ref);
    });
