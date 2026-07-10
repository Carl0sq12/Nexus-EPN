import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_campus/app.dart';
import 'package:nexus_campus/core/router/app_router.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Test')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: const NexusCampusApp(),
      ),
    );

    expect(find.byType(NexusCampusApp), findsOneWidget);
  });
}
