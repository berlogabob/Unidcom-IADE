import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/news_wizard.dart';

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).hitTestable().last);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? article,
  bool allowed = true,
  Future<void> Function(Map<String, dynamic>, String?)? save,
  Future<void> Function()? push,
  Future<String?> Function()? pickImage,
}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NewsWizard(
          article: article,
          canEdit: () => allowed,
          loadSlugs: () async => {'existing', 'my-news'},
          save: save ?? (_, _) async {},
          push: push ?? () async {},
          pickImage: pickImage ?? () async => null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton _continue(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Continue').hitTestable(),
);

void main() {
  testWidgets('admin gate loads no data for other roles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewsWizard(
          canEdit: () => false,
          loadSlugs: () async => throw StateError('must not load'),
        ),
      ),
    );
    expect(find.text('Admin access required'), findsOneWidget);
  });

  testWidgets(
    'step validation, real calendar dates, excerpt counter and back preserve input',
    (tester) async {
      await _pump(tester);
      expect(_continue(tester).onPressed, isNull);
      await _tap(tester, 'Unclassified');
      expect(find.textContaining('You can still continue'), findsOneWidget);
      await _tap(tester, 'Continue');
      expect(_continue(tester).onPressed, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'My news',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Date (YYYY-MM-DD)'),
        '2026-02-30',
      );
      await tester.pumpAndSettle();
      expect(_continue(tester).onPressed, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Date (YYYY-MM-DD)'),
        '2026-02-28',
      );
      await _tap(tester, 'Continue');
      await tester.enterText(
        find.widgetWithText(TextField, 'Excerpt'),
        'a' * 151,
      );
      await tester.pumpAndSettle();
      expect(find.text('151/150'), findsOneWidget);
      expect(_continue(tester).onPressed, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Excerpt'),
        'a' * 150,
      );
      await _tap(tester, 'Continue');
      expect(find.text('Slug: my-news-2'), findsOneWidget);
      expect(find.text('Warning: missing lab.'), findsOneWidget);
      await _tap(tester, 'Back');
      expect(find.text('150/150'), findsOneWidget);
      await _tap(tester, 'Back');
      expect(find.widgetWithText(TextField, 'My news'), findsOneWidget);
    },
  );

  for (final published in [false, true]) {
    testWidgets(
      'edit saves ${published ? 'published' : 'draft'} with precision and stable slug',
      (tester) async {
        Map<String, dynamic>? fields;
        String? id;
        var pushes = 0;
        await _pump(
          tester,
          article: {
            'id': 'article-1',
            'title': 'Old title',
            'date': '2025-01-01',
            'date_precision': 'year',
            'news_type': '[collaboration]',
            'slug': 'existing',
            'lab': ['BID'],
            'scientific_areas': ['Design'],
            'member_types': ['Integrated'],
            'body': 'Body',
            'excerpt': 'Excerpt',
            'published': true,
          },
          save: (data, savedId) async {
            fields = data;
            id = savedId;
          },
          push: () async {
            pushes++;
            throw StateError('bridge unavailable');
          },
        );
        await _tap(tester, 'Continue');
        expect(find.widgetWithText(TextField, 'Date (YYYY)'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Title'),
          'Changed title',
        );
        await _tap(tester, 'Continue');
        await _tap(tester, 'Continue');
        await _tap(tester, published ? 'Publish' : 'Save draft');
        expect(id, 'article-1');
        expect(fields!['slug'], 'existing');
        expect(fields!['year'], 2025);
        expect(fields!['date'], '2025-01-01');
        expect(fields!['date_precision'], 'year');
        expect(fields!['published'], published);
        expect(fields!['lab'], ['BID']);
        expect(pushes, published ? 1 : 0);
        expect(
          find.text(
            published
                ? 'News published. The website updates in a few minutes.'
                : 'Draft saved.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('save errors retain review and allow retry', (tester) async {
    await _pump(
      tester,
      article: {
        'id': 'a',
        'title': 'News',
        'date': '2026-04-01',
        'news_type': 'Unclassified',
        'slug': 'news',
      },
      save: (_, _) async => throw StateError('Save failed'),
    );
    await _tap(tester, 'Continue');
    await _tap(tester, 'Continue');
    await _tap(tester, 'Continue');
    await _tap(tester, 'Save draft');
    expect(find.textContaining('Save failed'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save draft').hitTestable(),
          )
          .onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'month precision normalizes date and new saves refresh slug collisions',
    (tester) async {
      Map<String, dynamic>? saved;
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 760,
                height: 720,
                child: NewsWizard(
                  canEdit: () => true,
                  loadSlugs: () async =>
                      ++loads == 1 ? <String>{} : {'new-news'},
                  save: (data, id) async {
                    saved = data;
                    expect(id, isNull);
                  },
                  push: () async => fail('Draft must not push'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('[calls] presentation'));
      await tester.tap(find.text('[calls] presentation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue').last);
      await _tap(tester, 'Continue');
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'New news',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('month').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Date (YYYY-MM)'),
        '2026-13',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue').last,
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Date (YYYY-MM)'),
        '2026-03',
      );
      await tester.ensureVisible(find.text('Continue').last);
      await _tap(tester, 'Continue');
      await tester.ensureVisible(find.text('Continue').last);
      await _tap(tester, 'Continue');
      await tester.ensureVisible(find.text('Save draft').last);
      await _tap(tester, 'Save draft');
      expect(saved!['slug'], 'new-news-2');
      expect(saved!['date'], '2026-03-01');
      expect(saved!['date_precision'], 'month');
      expect(loads, 2);
    },
  );
}
