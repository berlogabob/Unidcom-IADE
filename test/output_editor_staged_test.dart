import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unidcom_iade/public/output_page.dart';

void main() {
  final output = {
    'id': 'output-1',
    'title': 'Old title',
    'doi': '10.1234/old',
    'url': 'https://example.com/old',
    'full_reference': 'Old reference',
    'reporting_year': 2024,
    'output_status': 'published',
    'category_path': 'Artigos em revistas',
  };

  Future<void> pumpDialog(
    WidgetTester tester, {
    bool asResearcher = true,
    Future<int> Function(String, Map<String, String?>, Map<String, String>)?
    stage,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutputEditDialog(
            output: output,
            asResearcher: asResearcher,
            stage: stage,
            lookup: (_) async => null,
            findSimilar: ({doi, title}) async => const [],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('staged edit has review title and action', (tester) async {
    await pumpDialog(tester, stage: (_, _, _) async => 1);

    expect(find.text('Propose changes to this output'), findsOneWidget);
    expect(find.text('Submit for review'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('staged edit sends current and proposed values', (tester) async {
    Map<String, String?>? current;
    Map<String, String>? proposed;
    await pumpDialog(
      tester,
      stage: (_, gotCurrent, gotProposed) async {
        current = gotCurrent;
        proposed = gotProposed;
        return 1;
      },
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'New title',
    );
    await tester.tap(find.text('Submit for review'));
    await tester.pump();

    expect(current!['title'], 'Old title');
    expect(proposed!['title'], 'New title');
  });

  testWidgets('zero staged changes keeps the dialog open', (tester) async {
    await pumpDialog(tester, stage: (_, _, _) async => 0);

    await tester.tap(find.text('Submit for review'));
    await tester.pump();

    expect(find.text('No changes'), findsOneWidget);
    expect(find.byType(OutputEditDialog), findsOneWidget);
  });

  testWidgets('without stage an existing researcher edit stays unchanged', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Edit output'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
