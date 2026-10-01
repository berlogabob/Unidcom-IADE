import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/own_outputs.dart';
import 'package:unidcom_iade/data/taxonomy.dart';

// E5.2 + E5.4 (Rui 25 Sep, Scientific Outputs A4·4-7, B4·4, SO-5..SO-9).
Map<String, dynamic> row(
  String id,
  String title,
  int year,
  String path, {
  int warnings = 0,
}) => {
  'role': 'Autor',
  'outputs': {
    'id': id,
    'title': title,
    'reporting_year': year,
    'category_path': path,
    'type': path.split(' › ').first,
    'approval_status': 'approved',
    'website_status': 'not_published',
    'source': 'manual',
    'error_count': 0,
    'warning_count': warnings,
    'issue_codes': warnings > 0 ? ['missing_doi'] : <String>[],
  },
};

final rows = [
  row('1', 'Book One', 2024, 'Livros › Autor'),
  row('2', 'Book Two', 2025, 'Livros › Editor', warnings: 1),
  row('3', 'Paper', 2025, 'Artigos em revistas'),
  row('4', 'Workshop', 2024, 'Formação avançada'),
];

Future<({List<String> reviews})> pump(WidgetTester tester, {int newOrcid = 0}) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final reviews = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OwnOutputsSection(
            authors: rows,
            featured: const ['1'],
            onToggleFeatured: (_) {},
            onOpenOutput: (_) {},
            newOrcidPublications: newOrcid,
            onReviewOrcid: () => reviews.add('review'),
            loadTaxonomy: () async => const [
              TaxonomyNode('Livros', [TaxonomyNode('Autor', []), TaxonomyNode('Editor', [])]),
              TaxonomyNode('Artigos em revistas', []),
              TaxonomyNode('Formação avançada', []),
            ],
            loadKinds: () async => const {
              'Livros': 'publication',
              'Artigos em revistas': 'publication',
              'Formação avançada': 'activity',
            },
            loadQuality: (_) async {},
            submitOutputs: (_) async => 0,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (reviews: reviews);
}

void main() {
  testWidgets('v1 has chips, not dropdowns', (tester) async {
    await pump(tester);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('All by default; Publications and Other activities split it', (tester) async {
    await pump(tester);
    expect(find.text('Book One'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    await tester.tap(find.text('Publications'));
    await tester.pumpAndSettle();
    expect(find.text('Workshop'), findsNothing);
    await tester.tap(find.text('Other activities'));
    await tester.pumpAndSettle();
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('Book One'), findsNothing);
  });

  testWidgets('counters follow the filters', (tester) async {
    await pump(tester);
    expect(find.text('4 outputs · 2 Books · 1 Journal articles · 1 Advanced training · 1 with issues'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '2024'));
    await tester.pumpAndSettle();
    expect(find.text('2 outputs · 1 Advanced training · 1 Books'), findsOneWidget);
  });

  testWidgets('a type chip opens its subtypes', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Books'));
    await tester.pumpAndSettle();
    expect(find.text('Paper'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Editor'));
    await tester.pumpAndSettle();
    expect(find.text('Book Two'), findsOneWidget);
    expect(find.text('Book One'), findsNothing);
  });

  testWidgets('Issues only', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Issues only'));
    await tester.pumpAndSettle();
    expect(find.text('Book Two'), findsOneWidget);
    expect(find.text('Book One'), findsNothing);
  });

  testWidgets('Featured X/5 and stars only on publications', (tester) async {
    await pump(tester);
    expect(find.text('Featured 1/5'), findsOneWidget);
    await tester.tap(find.text('Other activities'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('ORCID banner opens the reconciliation view', (tester) async {
    final r = await pump(tester, newOrcid: 8);
    await tester.tap(find.text('8 new publications in ORCID → Review'));
    expect(r.reviews, ['review']);
  });

  testWidgets('no banner when nothing new', (tester) async {
    await pump(tester);
    expect(find.textContaining('new publications in ORCID'), findsNothing);
  });
}
