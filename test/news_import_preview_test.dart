import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/news_import.dart';
import 'package:unidcom_iade/data/news_template.dart';

Future<void> _pump(
  WidgetTester tester,
  NewsParseResult result,
  Future<int> Function(List<NewsImportRow>) insert,
) async {
  tester.view.physicalSize = const Size(2200, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NewsImportPreview(
          result: result,
          canEdit: () => true,
          importRows: insert,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'groups valid, warning, invalid and duplicate rows; inline fixes and skips feed confirmation',
    (tester) async {
      final parsed = parseNewsFile(
        utf8.encode(
          'title,year,type,scientific area,type of member,lab\nGood,2026,[collaboration],Design,Integrated,BID\nWarning,2026,unknown,,,\nInvalid,,,,,\nGood,2026,[collaboration],Design,Integrated,BID\n',
        ),
        'news.csv',
      );
      List<NewsImportRow>? imported;
      await _pump(tester, parsed, (rows) async {
        imported = rows;
        return rows.length;
      });
      expect(
        find.text('OK: 1 · Warnings: 1 · Errors: 1 · Duplicates: 1'),
        findsOneWidget,
      );
      expect(find.textContaining('duplicate title+year'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Import 3 drafts'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('skip-4')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButton<String>, 'Unclassified').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('[collaboration]').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButton<String>, 'Missing lab').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BID').last);
      await tester.pumpAndSettle();
      expect(
        find.text('OK: 2 · Warnings: 0 · Errors: 1 · Duplicates: 1'),
        findsOneWidget,
      );
      await tester.tap(find.text('Import 2 drafts'));
      await tester.pumpAndSettle();
      expect(imported, isNull);
      await tester.tap(find.text('Import drafts'));
      await tester.pumpAndSettle();
      expect(imported, hasLength(2));
      expect(imported!.last.data['news_type'], '[collaboration]');
      expect(imported!.last.data['lab'], ['BID']);
      expect(imported!.every((r) => r.data['published'] == false), isTrue);
      expect(find.text('Inserted: 2 unpublished drafts.'), findsOneWidget);
    },
  );

  testWidgets('file-level errors block import', (tester) async {
    await _pump(
      tester,
      const NewsParseResult([], {
        1: ['Missing header'],
      }),
      (_) async => throw StateError('must not insert'),
    );
    expect(find.text('Missing header'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Import 0 drafts'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'partial batch failure reports successful count and prevents accidental retry',
    (tester) async {
      final rows = List.generate(
        101,
        (i) => NewsImportRow(
          i + 2,
          {
            'title': 'News $i',
            'year': 2026,
            'news_type': '[collaboration]',
            'lab': ['BID'],
            'published': false,
          },
          [],
          [],
        ),
      );
      var calls = 0;
      await _pump(tester, NewsParseResult(rows, {}), (batch) async {
        calls++;
        if (calls == 2) throw StateError('batch unavailable');
        return batch.length;
      });
      await tester.tap(find.text('Import 101 drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import drafts'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Inserted: 100 unpublished drafts.'), findsOneWidget);
      expect(find.textContaining('Earlier batches remain'), findsOneWidget);
      expect(find.text('Import 101 drafts'), findsNothing);
    },
  );
}
