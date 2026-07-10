import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_campus/features/auth/domain/entities/auth_user.dart';
import 'package:nexus_campus/features/auth/domain/repositories/auth_repository.dart';
import 'package:nexus_campus/features/auth/presentation/pages/login_page.dart';
import 'package:nexus_campus/features/auth/presentation/providers/auth_provider.dart';

void main() {
  testWidgets('LoginPage validates required email and password fields', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.ensureVisible(find.text('INICIAR SESIÓN'));
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Campo requerido'), findsOneWidget);
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres'),
      findsOneWidget,
    );
    expect(repository.signInCalls, 0);
  });

  testWidgets('LoginPage rejects an invalid email before calling auth', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.ensureVisible(find.text('INICIAR SESIÓN'));
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Ingresá un correo válido'), findsOneWidget);
    expect(repository.signInCalls, 0);
  });
}

class _RecordingAuthRepository implements AuthRepository {
  int signInCalls = 0;

  @override
  Future<AuthUser> signIn(String email, String password) async {
    signInCalls++;
    return AuthUser(id: 'user-1', email: email, role: 'passenger');
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String role,
    String? fullName,
  }) async {
    return AuthUser(id: 'user-1', email: email, role: role);
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {}
}
