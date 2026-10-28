import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/app/output_wizard.dart';
import 'package:unidcom_iade/data/supabase.dart';
import 'package:unidcom_iade/public/output_page.dart';
import 'package:unidcom_iade/public/outputs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final authors = <Map<String, dynamic>>[];
  final outputs = <Map<String, dynamic>>[];
  final searches = <String?>[];

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
        Object result = [];
        switch (request.url.path) {
          case '/rest/v1/outputs':
            if (request.method == 'POST') {
              outputs.add(jsonDecode(request.body) as Map<String, dynamic>);
              result = {'id': 'new-output'};
            }
          case '/rest/v1/output_taxonomy':
            result = [
              {
                'segments': ['Livros'],
                'sort_order': 1,
                'kind': 'publication',
              },
            ];
          case '/rest/v1/people':
            searches.add(request.url.queryParameters['preferred_name']);
            result = [
              {
                'id': 'person-bob',
                'preferred_name': 'Bob',
                'email': 'bob@test.pt',
              },
            ];
          case '/rest/v1/output_authors':
            authors.add(jsonDecode(request.body) as Map<String, dynamic>);
          default:
            fail('Unexpected request: ${request.url}');
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
  tearDownAll(() async {
    viewMode.value = ViewMode.researcher;
    await Supabase.instance.dispose();
  });

  testWidgets('Outputs Add opens wizard and saves for the searched person', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OutputsScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add output'));
    await tester.pumpAndSettle();
    expect(find.byType(OutputWizard), findsOneWidget);
    expect(find.byType(OutputEditDialog), findsNothing);
    expect(find.text('For whom'), findsOneWidget);

    Future<void> tapVisible(String text) async {
      await tester.ensureVisible(find.text(text).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).hitTestable().last);
      await tester.pumpAndSettle();
    }

    await tapVisible('Choose person');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Bob',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(searches.last, 'ilike.%Bob%');
    await tapVisible('Bob');
    await tapVisible('Continue');
    await tapVisible('No DOI — enter manually');
    await tapVisible('Livros');
    await tapVisible('Continue');
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Bob’s book',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Reporting year'),
      '2026',
    );
    await tapVisible('Continue');
    expect(find.text('For: Bob').hitTestable(), findsOneWidget);
    await tapVisible('Submit for UNIDCOM review');
    expect(authors, [
      {'output_id': 'new-output', 'person_id': 'person-bob'},
    ]);
    expect(outputs.single, containsPair('source', 'manual'));
    expect(outputs.single, containsPair('approval_status', 'pending'));
    expect(outputs.single, containsPair('affiliation', 'unidcom'));
    expect(find.byType(OutputWizard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
