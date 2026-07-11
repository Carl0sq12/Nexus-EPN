import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/appwrite_client.dart';

/// Current Appwrite auth session snapshot used across the app.
class AppAuthSession {
  final String userId;
  final String email;
  final bool emailVerified;

  const AppAuthSession({
    required this.userId,
    required this.email,
    required this.emailVerified,
  });

  factory AppAuthSession.fromUser(models.User user) {
    return AppAuthSession(
      userId: user.$id,
      email: user.email,
      emailVerified: user.emailVerification,
    );
  }
}

final appwriteClientProvider = Provider<Client>((ref) {
  return AppwriteClientHolder.instance;
});

final accountProvider = Provider<Account>((ref) {
  return Account(ref.watch(appwriteClientProvider));
});

final databasesProvider = Provider<Databases>((ref) {
  return Databases(ref.watch(appwriteClientProvider));
});

final storageProvider = Provider<Storage>((ref) {
  return Storage(ref.watch(appwriteClientProvider));
});

final realtimeProvider = Provider<Realtime>((ref) {
  return Realtime(ref.watch(appwriteClientProvider));
});

/// Holds the current auth session and refreshes on login/logout.
class AuthSessionController
    extends StateNotifier<AsyncValue<AppAuthSession?>> {
  AuthSessionController(this._account) : super(const AsyncValue.loading()) {
    refresh();
  }

  /// Test/helper constructor that skips the initial network refresh.
  AuthSessionController.seeded(AsyncValue<AppAuthSession?> initial)
      : _account = null,
        super(initial);

  final Account? _account;

  Future<void> refresh() async {
    final account = _account;
    if (account == null) return;
    try {
      final user = await account.get();
      state = AsyncValue.data(AppAuthSession.fromUser(user));
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setSession(AppAuthSession? session) {
    state = AsyncValue.data(session);
  }

  Future<void> clear() async {
    state = const AsyncValue.data(null);
  }
}

final authSessionControllerProvider =
    StateNotifierProvider<AuthSessionController, AsyncValue<AppAuthSession?>>((
      ref,
    ) {
      return AuthSessionController(ref.watch(accountProvider));
    });

/// Auth state as [AsyncValue] of the current [AppAuthSession].
final authStateProvider = Provider<AsyncValue<AppAuthSession?>>((ref) {
  return ref.watch(authSessionControllerProvider);
});

/// ID of the authenticated user, if any.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).asData?.value?.userId;
});
