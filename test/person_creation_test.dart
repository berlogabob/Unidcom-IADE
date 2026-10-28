import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/data/supabase.dart';
import 'package:unidcom_iade/public/people_list.dart';
import 'package:unidcom_iade/public/person/person_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final writes = <http.Request>[];
  var failCreate = false;
  var failLink = false;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (_) async => <String, Object>{},
        );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      httpClient: MockClient((request) async {
        Object? result = [];
        if (request.method != 'GET') writes.add(request);
        if (request.url.path == '/rest/v1/people' && request.method == 'POST') {
          if (failCreate) {
            return http.Response(
              '{"message":"Create failed"}',
              500,
              request: request,
            );
          }
          result = {'id': 'new-person'};
        } else if (request.url.path == '/rest/v1/people' &&
            request.method == 'PATCH' &&
            failLink) {
          return http.Response(
            '{"message":"Link failed"}',
            500,
            request: request,
          );
        } else if (request.url.path == '/rest/v1/person_roles' &&
            request.method == 'GET') {
          result = null;
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    await db.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'refresh_token': 'test-refresh-token',
        'user': {
          'id': 'admin-user',
          'app_metadata': {'role': 'admin'},
          'user_metadata': <String, dynamic>{},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    viewMode.value = ViewMode.admin;
  });

  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      1200,
      2000,
    );
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio =
        1;
    writes.clear();
    failCreate = false;
    failLink = false;
  });

  tearDownAll(() async {
    viewMode.value = ViewMode.researcher;
    await Supabase.instance.dispose();
  });

  Future<void> open(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) show,
    void Function(Object?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await show(context)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Preferred name'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Preferred name'),
      'New researcher',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('create returns the id after linking to the current login', (
    tester,
  ) async {
    Object? result;
    await open(tester, showPersonCreator, (value) => result = value);
    final link = find.text('This is my profile (link to my login)');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await save(tester);

    expect(result, 'new-person');
    expect(writes.map((r) => r.method), ['POST', 'PATCH']);
    expect(
      jsonDecode(writes.first.body),
      containsPair('preferred_name', 'New researcher'),
    );
    expect(jsonDecode(writes.last.body), {'auth_user_id': 'admin-user'});
    expect(writes.last.url.queryParameters['id'], 'eq.new-person');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('legacy create caller still receives true', (tester) async {
    Object? result;
    await open(
      tester,
      (context) => showPersonEditor(context),
      (value) => result = value,
    );
    await save(tester);
    expect(result, isTrue);
  });

  testWidgets('update still returns true', (tester) async {
    Object? result;
    await open(
      tester,
      (context) => showPersonEditor(
        context,
        person: const {'id': 'existing-person', 'preferred_name': 'Old name'},
      ),
      (value) => result = value,
    );
    await save(tester);
    expect(result, isTrue);
    final update = writes.first;
    expect(update.method, 'PATCH');
    expect(update.url.queryParameters['id'], 'eq.existing-person');
    expect(
      writes.where(
        (r) => r.url.path == '/rest/v1/people' && r.method == 'POST',
      ),
      isEmpty,
    );
  });

  testWidgets(
    'failed link keeps the create dialog open without returning an id',
    (tester) async {
      failLink = true;
      var returned = false;
      await open(tester, showPersonCreator, (_) => returned = true);
      final link = find.text('This is my profile (link to my login)');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await save(tester);
      expect(returned, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Link failed'), findsOneWidget);
    },
  );

  Future<GoRouter> openList(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/people',
      routes: [
        GoRoute(
          path: '/people',
          builder: (_, _) => const Scaffold(body: PeopleListScreen()),
        ),
        GoRoute(
          path: '/people/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Person ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Add person navigates straight to the created person', (
    tester,
  ) async {
    final router = await openList(tester);
    await save(tester);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/people/new-person',
    );
    expect(find.text('Person new-person'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel and failed create keep the list route', (tester) async {
    final router = await openList(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/people');
    expect(writes, isEmpty);

    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    failCreate = true;
    await save(tester);
    expect(router.routeInformationProvider.value.uri.path, '/people');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      writes.single.method,
      'POST',
    ); // the failed create was attempted once
  });
}
