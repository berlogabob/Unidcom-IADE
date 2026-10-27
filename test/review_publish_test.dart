import 'dart:convert';

import 'package:flutter/services.dart';
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
          {'id': 'person-1', 'ok': true},
          {'id': 'person-2', 'ok': true},
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
}
