import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/supabase.dart' show slugify;
import 'package:unidcom_iade/widgets/detail_scaffold.dart';

void main() {
  test('parseList splits on commas and newlines, empty -> null', () {
    expect(parseList('a, b\nc,, '), ['a', 'b', 'c']);
    expect(parseList('  '), isNull);
  });

  test('slugify matches sanity-push for Latin text', () {
    expect(slugify('Zé Árvore'), 'ze-arvore');
    expect(slugify('  Hello,  World! '), 'hello-world');
    expect(slugify('x' * 100).length, 80);
  });

  Future<void> open(
    WidgetTester tester, {
    required Map<String, dynamic>? entity,
    required List<EntityField> fields,
    required Future<String> Function(Map<String, dynamic>) create,
    String requiredKey = 'name',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEntityEditor(
                context,
                title: 'thing',
                entity: entity,
                fields: fields,
                create: create,
                update: (_, _) async {},
                requiredKey: requiredKey,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('list field round-trips as an array; required key blocks save', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await open(
      tester,
      entity: null,
      fields: const [
        EntityField('title', 'Title'),
        EntityField('keywords', 'Keywords', kind: EntityKind.list),
      ],
      requiredKey: 'title',
      create: (data) async {
        saved = data;
        return 'id';
      },
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Title is required'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'T');
    await tester.enterText(find.byType(TextField).at(1), 'a, b');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, {
      'title': 'T',
      'keywords': ['a', 'b'],
    });
  });

  testWidgets('limit blocks an over-long value', (tester) async {
    var created = false;
    await open(
      tester,
      entity: null,
      fields: const [
        EntityField('name', 'Name'),
        EntityField('short_intro', 'Short intro', limit: 5),
      ],
      create: (_) async {
        created = true;
        return 'id';
      },
    );
    await tester.enterText(find.byType(TextField).at(0), 'N');
    await tester.enterText(find.byType(TextField).at(1), 'toolong');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      find.text('Short intro must be 5 characters or fewer'),
      findsOneWidget,
    );
    expect(created, isFalse);
  });

  testWidgets('existing array value shows comma-joined', (tester) async {
    await open(
      tester,
      entity: {
        'id': '1',
        'name': 'N',
        'keywords': ['x', 'y'],
      },
      fields: const [
        EntityField('name', 'Name'),
        EntityField('keywords', 'Keywords', kind: EntityKind.list),
      ],
      create: (_) async => 'id',
    );
    expect(find.widgetWithText(TextField, 'x, y'), findsOneWidget);
  });
}
