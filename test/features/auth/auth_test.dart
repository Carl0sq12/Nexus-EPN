import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_campus/features/auth/domain/entities/auth_user.dart';
import 'package:nexus_campus/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexus_campus/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('AuthNotifier', () {
    test('signIn stores the authenticated user on success', () async {
      final user = AuthUser(
        id: 'user-1',
        email: 'user@epn.edu.ec',
        fullName: 'Test User',
        role: 'passenger',
      );
      final repository = _FakeAuthRepository(signInResult: user);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn('user@epn.edu.ec', 'secret123');

      final state = container.read(authProvider);
      expect(state.asData?.value, user);
      expect(repository.signInEmail, 'user@epn.edu.ec');
    });

    test('signIn stores an AsyncError when the repository fails', () async {
      final repository = _FakeAuthRepository(error: Exception('invalid'));
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn('user@epn.edu.ec', 'bad-pass');

      final state = container.read(authProvider);
      expect(state.hasError, isTrue);
      expect(state, isA<AsyncError<AuthUser?>>());
    });

    test('signOut clears the authenticated user', () async {
      final repository = _FakeAuthRepository(
        signInResult: const AuthUser(
          id: 'user-1',
          email: 'user@epn.edu.ec',
          role: 'driver',
        ),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signIn('user@epn.edu.ec', 'secret123');
      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).asData?.value, isNull);
      expect(repository.signOutCalled, isTrue);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  final AuthUser? signInResult;
  final Object? error;
  String? signInEmail;
  bool signOutCalled = false;

  _FakeAuthRepository({this.signInResult, this.error});

  @override
  Future<AuthUser> signIn(String email, String password) async {
    signInEmail = email;
    if (error != null) throw error!;
    return signInResult!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String role,
    String? fullName,
  }) async {
    if (error != null) throw error!;
    return AuthUser(
      id: 'new-user',
      email: email,
      fullName: fullName,
      role: role,
    );
  }

  @override
  Future<void> signOut() async {
    if (error != null) throw error!;
    signOutCalled = true;
  }

  @override
  Future<void> resetPassword(String email) async {
    if (error != null) throw error!;
  }
}
