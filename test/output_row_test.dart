import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/public/person/output_row.dart';
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

  testWidgets('a status passed as detail is shown once, as the pill', (
    tester,
  ) async {
    // The review queue passes 'pending' as detail; after F-009 the pill took
    // over and the meta text repeated it. Regression seen in the 2026-09-09
    // re-audit (flow_review_queue after_reject).
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OutputRow(title: 'Queued output', detail: 'pending'),
        ),
      ),
    );
    expect(find.text('Submitted'), findsOneWidget);
  });

  testWidgets('pending timeline output renders its status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {
                'id': '1',
                'title': 'Pending output',
                'approval_status': 'pending',
              },
            },
            isFeatured: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Submitted'), findsOneWidget);
  });

  testWidgets('approved timeline output has no status pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {
                'id': '1',
                'title': 'Approved output',
                'approval_status': 'approved',
              },
            },
            isFeatured: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('approved'), findsNothing);
  });

  testWidgets('rejected timeline output shows the rejection reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {
                'id': '1',
                'title': 'Rejected output',
                'approval_status': 'rejected',
                'rejection_reason': 'Please add the missing DOI.',
              },
            },
            isFeatured: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Please add the missing DOI.'), findsOneWidget);
  });

  testWidgets('person output detail includes subtype and DOI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {
                'id': 'out-1',
                'title': 'Output',
                'subtype': 'Q1 journal',
                'doi': '10.1234/example',
              },
            },
            isFeatured: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('2025'), findsNothing);
    expect(
      find.text('Author · Q1 journal · DOI 10.1234/example'),
      findsOneWidget,
    );
  });

  testWidgets('showStates renders ORCID and website pills', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {
                'id': 'out-1',
                'title': 'Output',
                'source': 'orcid',
                'website_status': 'published',
              },
            },
            isFeatured: false,
            onTap: (_) {},
            showStates: true,
          ),
        ),
      ),
    );

    expect(find.text('ORCID ✓'), findsOneWidget);
    expect(find.text('Website · Published'), findsOneWidget);
  });

  testWidgets('showStates labels a missing website as not published', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {'id': 'out-1', 'title': 'Output'},
            },
            isFeatured: false,
            onTap: (_) {},
            showStates: true,
          ),
        ),
      ),
    );

    expect(find.text('Website · Not published'), findsOneWidget);
  });

  testWidgets('edit action fires with output id', (tester) async {
    String? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {'id': 'out-1', 'title': 'Output'},
            },
            isFeatured: false,
            onTap: (_) {},
            onEdit: (id) => edited = id,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Edit output'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit output'));
    expect(edited, 'out-1');
  });

  testWidgets('no edit action renders without onEdit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonOutputRow(
            author: {
              'role': 'Author',
              'outputs': {'id': 'out-1', 'title': 'Output'},
            },
            isFeatured: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Edit output'), findsNothing);
  });
}
