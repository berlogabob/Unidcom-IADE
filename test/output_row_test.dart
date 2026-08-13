import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/output_row.dart';

// The UNIDCOM taxonomy is Portuguese and verbose. Its longest label is 77
// characters, and an unconstrained badge carrying one squeezed the Expanded
// title beside it down to a single character per line — the title rendered
// vertically, one letter per row. Caught on the deployed build, not by a test,
// which is why this one exists.
const _longestTaxonomyLabel =
    'Valorizações de atividades ou outros outputs no âmbito de projetos '
    'científicos';

void main() {
  Future<void> pumpRow(WidgetTester tester, {String? type}) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutputRow(
            title: 'Navigating Visual Complexity in Urban Wayfinding Systems',
            year: 2025,
            type: type,
          ),
        ),
      ),
    );
  }

  testWidgets('a very long category label does not starve the title', (
    tester,
  ) async {
    await pumpRow(tester, type: _longestTaxonomyLabel);

    final title = tester.getSize(
      find.text('Navigating Visual Complexity in Urban Wayfinding Systems'),
    );
    // Anything near zero means the title is being rendered one glyph per line.
    expect(
      title.width,
      greaterThan(300),
      reason: 'title should keep most of a 900px row, not a single column',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the badge itself stays within its cap', (tester) async {
    await pumpRow(tester, type: _longestTaxonomyLabel);
    expect(
      tester.getSize(find.text(_longestTaxonomyLabel.toUpperCase())).width,
      lessThanOrEqualTo(220),
    );
  });

  testWidgets('a short type is unaffected', (tester) async {
    await pumpRow(tester, type: 'Journal article');
    expect(find.text('JOURNAL ARTICLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no type renders no badge at all', (tester) async {
    await pumpRow(tester);
    expect(find.text('2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
