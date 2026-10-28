import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:unidcom_iade/app/review_publish.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/data/supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pushes = <Map<String, dynamic>>[];
  var failPush = false;
  var published = false;

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
        switch (request.url.path) {
          case '/rest/v1/people':
            result = [
              {'id': 'person-1', 'preferred_name': 'Alice'},
              {'id': 'person-2', 'preferred_name': 'Bob'},
            ];
          case '/rest/v1/output_authors':
            expect(published, isFalse);
            expect(request.url.queryParameters['person_id'], startsWith('eq.'));
            if (request.url.queryParameters['person_id'] == 'eq.person-2') {
              result = [];
              break;
            }
            result = [
              for (final entry in {
                'new-output': 'ready',
                'retry-output': 'error',
                'edited-output': 'published',
                'old-output': 'published',
                'pending-output': 'pending',
              }.entries)
                {
                  'output_id': entry.key,
                  'outputs': {
                    'website_status': entry.value,
                    'approval_status': 'approved',
                  },
                },
            ];
          case '/rest/v1/enrichment_suggestions':
            expect(published, isFalse);
            expect(
              request.url.queryParameters,
              containsPair('status', 'eq.ready'),
            );
            expect(
              request.url.queryParameters,
              containsPair('source', 'eq.researcher'),
            );
            expect(
              request.url.queryParameters,
              containsPair('subject_type', 'eq.output'),
            );
            result = [
              {'subject_id': 'edited-output'},
            ];
          case '/rest/v1/rpc/publish_researchers':
            expect(jsonDecode(request.body), {
              'p_ids': ['person-1', 'person-2', 'failed'],
            });
            published = true;
            result = [
              {'id': 'person-1', 'ok': true},
              {'id': 'person-2', 'ok': true},
              {'id': 'failed', 'ok': false, 'error': 'invalid field'},
            ];
          case '/functions/v1/sanity-push':
            expect(published, isTrue);
            pushes.add(jsonDecode(request.body) as Map<String, dynamic>);
            status = failPush ? 500 : 200;
            result = failPush
                ? {'error': 'Sanity unavailable'}
                : {'counts': {}};
          default:
            fail('Unexpected request: ${request.url}');
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
    pushes.clear();
    failPush = false;
    published = false;
  });

  test('ready rows count only outputs included in the publish batch', () async {
    final rows = await fetchReadyToPublish();
    expect(rows.map((r) => r['output_count']), [3, 0]);
    expect(pushes, isEmpty);
  });

  for (final failure in [false, true]) {
    test(
      'publish succeeds when Sanity ${failure ? 'fails' : 'succeeds'}',
      () async {
        failPush = failure;
        final results = await publishResearchers([
          'person-1',
          'person-2',
          'failed',
        ]);
        expect(results, [
          {
            'id': 'person-1',
            'ok': true,
            'output_ids': ['new-output', 'retry-output', 'edited-output'],
            'sanity_ok': !failure,
            if (failure) 'sanity_error': contains('Sanity unavailable'),
          },
          {
            'id': 'person-2',
            'ok': true,
            'output_ids': <String>[],
            'sanity_ok': !failure,
            if (failure) 'sanity_error': contains('Sanity unavailable'),
          },
          {'id': 'failed', 'ok': false, 'error': 'invalid field'},
        ]);
        expect(pushes, [
          {
            'personId': 'person-1',
            'outputIds': ['new-output', 'retry-output', 'edited-output'],
            'dryRun': false,
          },
          {'personId': 'person-2', 'outputIds': <String>[], 'dryRun': false},
        ]);
      },
    );
  }
  testWidgets(
    'one click reports both targets, retries Sanity, and undoes batch',
    (tester) async {
      final batches = <List<String>>[];
      final unpublished = <String>[];
      final retries = <String>[];
      var syncs = 0;
      var retryFails = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadyToPublishTab(
              fetchRows: () async => batches.isEmpty
                  ? [
                      {'id': 'a', 'preferred_name': 'Alice', 'output_count': 2},
                      {'id': 'b', 'preferred_name': 'Bob', 'output_count': 1},
                      {
                        'id': 'c',
                        'preferred_name': 'Charlie',
                        'output_count': 0,
                      },
                    ]
                  : [],
              publish: (ids) async {
                batches.add(List.of(ids));
                return [
                  {
                    'id': 'a',
                    'ok': true,
                    'sanity_ok': true,
                    'output_ids': ['o1', 'o2'],
                  },
                  {
                    'id': 'b',
                    'ok': true,
                    'sanity_ok': false,
                    'sanity_error': 'offline',
                    'output_ids': ['bob-output'],
                  },
                  {'id': 'c', 'ok': false, 'error': 'invalid field'},
                ];
              },
              setPublished: (id, value) async {
                expect(value, isFalse);
                unpublished.add(id);
              },
              pushSanity:
                  ({
                    required personId,
                    required outputIds,
                    dryRun = true,
                  }) async {
                    expect(dryRun, isFalse);
                    expect(outputIds, ['bob-output']);
                    retries.add(personId);
                    if (retryFails) throw Exception('still offline');
                    return {};
                  },
              syncWebsite: () async {
                syncs++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('+2 outputs'), findsOneWidget);
      expect(find.textContaining('+0 outputs'), findsOneWidget);
      await tester.tap(find.text('Publish selected (3)'));
      await tester.pumpAndSettle();
      expect(batches, [
        ['a', 'b', 'c'],
      ]);
      expect(find.textContaining('Confirm:'), findsNothing);
      expect(find.text('Publish'), findsNothing);
      expect(
        find.text(
          '2 published. Website: updates within ~15 min. Sanity: 1 ok, 1 failed',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bob: Sanity failed: offline'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Charlie: Publish failed: invalid field'),
        findsOneWidget,
      );
      expect(syncs, 1);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('still offline'), findsOneWidget);
      retryFails = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retries, ['b', 'b']);
      expect(find.textContaining('Sanity: 2 ok, 0 failed'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(unpublished, ['a', 'b']);
      expect(syncs, 2);
      expect(find.textContaining('2 unpublished.'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    },
  );
}
