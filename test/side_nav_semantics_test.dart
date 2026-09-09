import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/widgets/app_shell.dart';
import 'package:unidcom_iade/widgets/nav_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (_) async => <String, Object>{},
        );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json', 'content-range': '*/0'},
        ),
      ),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'refresh_token': 'test-refresh-token',
        'user': {
          'id': 'test-user',
          'app_metadata': {'role': 'admin'},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
          'email': 'researcher@example.com',
        },
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('desktop sidebar survives the nested route semantics barrier', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    collapsedGroups.value = {};
    final router = GoRouter(
      initialLocation: '/app/home',
      routes: [
        ShellRoute(
          builder: (_, _, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/app/home',
              builder: (_, _) => const Text('Page content'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      for (final label in [
        'Research Activity Summary',
        'OVERVIEW',
        'Switch to admin',
        'Public site',
        'Sign out',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
          reason: '$label must expose its tap action',
        );
      }
      expect(find.bySemanticsLabel('Page content'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
}
