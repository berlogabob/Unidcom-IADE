import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/data/news_template.dart';
import 'package:unidcom_iade/data/supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final batches = <List<dynamic>>[];
  final offsets = <int>[];
  var failBatch = false;
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
        expect(request.url.path, '/rest/v1/articles');
        if (request.method == 'GET') {
          expect(request.url.queryParameters['select'], 'slug');
          final offset = int.parse(request.url.queryParameters['offset']!);
          offsets.add(offset);
          return http.Response(
            jsonEncode([
              for (var i = offset; i < (offset == 0 ? 1000 : 1002); i++)
                {'slug': 'news-$i'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.method, 'POST');
        batches.add(jsonDecode(request.body) as List<dynamic>);
        if (failBatch && batches.length == 2) {
          return http.Response(
            '{"message":"slug conflict","code":"23505"}',
            409,
            request: request,
          );
        }
        return http.Response('', 201, request: request);
      }),
    );
  });
  setUp(() {
    batches.clear();
    offsets.clear();
    failBatch = false;
  });
  tearDownAll(() async => Supabase.instance.dispose());

  List<NewsImportRow> rows(int count) => [
    for (var i = 0; i < count; i++)
      NewsImportRow(
        i + 2,
        {
          'title': 'T$i',
          'slug': 't$i',
          'year': 2026,
          'date': '2026-01-01',
          'source': 'import:news.xlsx',
          'import_note': 'missing lab',
          'published': true,
        },
        [],
        [],
      ),
  ];
  test('slugs are fetched beyond PostgREST first page', () async {
    final slugs = await fetchArticleSlugs();
    expect(slugs, hasLength(1002));
    expect(slugs, contains('news-1001'));
    expect(offsets, [0, 1000]);
  });
  test('inserts draft batches and preserves provenance', () async {
    expect(await importNewsDrafts(rows(201)), 201);
    expect(batches.map((b) => b.length), [100, 100, 1]);
    for (final row in batches.expand((b) => b)) {
      expect(row['published'], false);
      expect(row['source'], 'import:news.xlsx');
      expect(row['import_note'], 'missing lab');
    }
  });
  test(
    'invalid rows rejected before any insertion; empty list is no-op',
    () async {
      await expectLater(
        importNewsDrafts([
          ...rows(1),
          const NewsImportRow(3, {}, ['Missing year'], []),
        ]),
        throwsArgumentError,
      );
      expect(await importNewsDrafts([]), 0);
      expect(batches, isEmpty);
    },
  );
  test(
    'later failure reports partial count without retry or overwrite',
    () async {
      failBatch = true;
      await expectLater(
        importNewsDrafts(rows(201)),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('after 100 drafts') &&
                e.toString().contains('slug conflict'),
          ),
        ),
      );
      expect(batches, hasLength(2));
    },
  );
}
