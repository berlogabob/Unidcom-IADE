import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/data/supabase.dart';
import 'package:unidcom_iade/public/person/sanity_push.dart';
import 'package:unidcom_iade/public/person_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <Map<String, dynamic>>[];
  var failure = false;
  var failPush = false;
  Completer<void>? pending;
  final preview = {
    'project': 'ld5jhf23',
    'counts': {'members': 2, 'outputs': 2},
    'dropped': [
      {'outputId': 'output-1', 'personId': null},
      {'outputId': 'output-2', 'personId': 'merged-person'},
    ],
    'warnings': ['Cannot resolve memberType'],
    'mutations': <dynamic>[],
  };

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
        var status = 200;
        if (request.url.path.endsWith('/sanity-push')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          calls.add(body);
          if (pending != null) await pending!.future;
          if (failure || (failPush && body['dryRun'] == false)) {
            status = 403;
            result = {'error': 'admins only'};
          } else {
            result = body['dryRun'] == false
                ? {
                    'project': 'ld5jhf23',
                    'counts': {'members': 3, 'outputs': 2},
                    'dropped': <dynamic>[],
                    'warnings': ['Push warning'],
                  }
                : preview;
          }
        } else if (request.url.path.endsWith('/people')) {
          result = {
            'id': 'person-1',
            'preferred_name': 'Ana Silva',
            'output_authors': [
              {
                'outputs': {'id': 'output-1'},
              },
              {
                'outputs': {'id': 'output-2', 'affiliation': 'external'},
              },
              {
                'outputs': {'id': 'output-1'},
              },
              {'outputs': null},
            ],
          };
        }
        return http.Response(
          jsonEncode(result),
          status,
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
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    calls.clear();
    failure = false;
    failPush = false;
    pending = null;
  });

  Future<void> pumpButton(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: PersonSanityPushButton(
          personId: 'person-1',
          outputIds: ['output-1', 'output-2'],
        ),
      ),
    ),
  );

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    // Supabase encodes/decodes function payloads on a real isolate.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(finder, findsOneWidget);
  }

  final requestResult = find.byWidgetPredicate(
    (widget) => widget is AlertDialog || widget is SnackBar,
  );

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.text('Push to test Sanity'));
    await waitFor(tester, requestResult);
  }

  test(
    'selected method preserves preview and real push payloads and results',
    () async {
      final result = await runPersonSanityPush(
        personId: 'person-1',
        outputIds: ['output-1', 'output-2'],
      );
      expect(result, preview);
      await runPersonSanityPush(
        personId: 'person-1',
        outputIds: [],
        dryRun: false,
      );
      expect(calls, [
        {
          'personId': 'person-1',
          'outputIds': ['output-1', 'output-2'],
          'dryRun': true,
        },
        {'personId': 'person-1', 'outputIds': <String>[], 'dryRun': false},
      ]);
    },
  );

  test('existing website push still sends types and returns counts', () async {
    expect(await runSanityPush(types: ['members']), {
      'members': 2,
      'outputs': 2,
    });
    expect(calls.single, {
      'types': ['members'],
    });
  });

  testWidgets(
    'preview shows counts, dropped authors and warnings; cancel stops',
    (tester) async {
      await pumpButton(tester);
      await openPreview(tester);
      expect(calls.single['dryRun'], true);
      expect(find.text('members: 2'), findsOneWidget);
      expect(find.text('outputs: 2'), findsOneWidget);
      expect(find.text('Dropped authors: 2'), findsOneWidget);
      expect(find.text('Output output-1: unknown author'), findsOneWidget);
      expect(find.text('Output output-2: merged-person'), findsOneWidget);
      expect(find.text('Cannot resolve memberType'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(find.text('Push to test Sanity'), findsOneWidget);
    },
  );

  testWidgets('confirm sends same selection and shows the actual push result', (
    tester,
  ) async {
    await pumpButton(tester);
    await openPreview(tester);
    await tester.tap(find.text('Confirm push'));
    await waitFor(tester, find.text('Pushed to test Sanity'));
    expect(calls, [
      {
        'personId': 'person-1',
        'outputIds': ['output-1', 'output-2'],
        'dryRun': true,
      },
      {
        'personId': 'person-1',
        'outputIds': ['output-1', 'output-2'],
        'dryRun': false,
      },
    ]);
    expect(find.text('Pushed to test Sanity'), findsOneWidget);
    expect(find.text('members: 3'), findsOneWidget);
    expect(find.text('Dropped authors: 0'), findsOneWidget);
    expect(find.text('Push warning'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Push to test Sanity'), findsOneWidget);
  });

  for (final onPush in [false, true]) {
    testWidgets(
      'surfaces ${onPush ? 'push' : 'preview'} errors and allows retry',
      (tester) async {
        failure = !onPush;
        failPush = onPush;
        await pumpButton(tester);
        await openPreview(tester);
        if (onPush) {
          await tester.tap(find.text('Confirm push'));
          await waitFor(tester, find.byType(SnackBar));
        }
        expect(find.textContaining('admins only'), findsOneWidget);
        expect(find.text('Pushed to test Sanity'), findsNothing);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull,
        );
        expect(calls, hasLength(onPush ? 2 : 1));
      },
    );
  }

  testWidgets('disables the action while preview is in flight', (tester) async {
    pending = Completer<void>();
    await pumpButton(tester);
    await tester.tap(find.text('Push to test Sanity'));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    pending!.complete();
    await waitFor(tester, find.byType(AlertDialog));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
  });

  testWidgets(
    'person detail gates action and sends all linked output IDs once',
    (tester) async {
      for (final admin in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PersonPageScreen(
                key: ValueKey(admin),
                id: 'person-1',
                admin: admin,
                sections: const {PersonSection.personal},
              ),
            ),
          ),
        );
        await waitFor(tester, find.text('Ana Silva'));
        expect(
          find.text('Push to test Sanity'),
          admin ? findsOneWidget : findsNothing,
        );
      }
      await tester.ensureVisible(find.text('Push to test Sanity'));
      await openPreview(tester);
      expect(calls.single['personId'], 'person-1');
      expect(calls.single['outputIds'], ['output-1', 'output-2']);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
}
