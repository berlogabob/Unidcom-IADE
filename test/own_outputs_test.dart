import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/own_outputs.dart';
import 'package:unidcom_iade/data/output_filters.dart';
import 'package:unidcom_iade/data/taxonomy.dart';

void main() {
  final authors = <Map<String, dynamic>>[
    _author('1', 'Featured Book', 2026, 'Livros › Autor'),
    _author('2', 'Searchable Paper', 2026, 'Livros › Autor'),
    _author(
      '3',
      'Rejected Training',
      2025,
      'Formação avançada',
      approval: 'rejected',
    ),
    _author('4', 'ORCID Book', 2025, 'Livros › Autor', source: 'orcid'),
    _author(
      '5',
      'Project Activity',
      2024,
      'Formação avançada',
      project: {'id': 'p1', 'title': 'Design Futures'},
    ),
    _author('6', 'Flagged Book', 2024, 'Livros › Autor'),
  ];

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpOutputs(
    WidgetTester tester, {
    ValueChanged<Map<String, dynamic>>? onEdit,
    Widget? orcidPanel,
  }) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OwnOutputsSection(
              authors: authors,
              featured: const ['1'],
              onToggleFeatured: (_) {},
              onOpenOutput: (_) {},
              onEditOutput: onEdit,
              orcidPanel: orcidPanel,
              loadTaxonomy: () async => const [
                TaxonomyNode('Livros', [TaxonomyNode('Autor', [])]),
                TaxonomyNode('Formação avançada', []),
              ],
              loadKinds: () async => const {
                'Livros': 'publication',
                'Formação avançada': 'activity',
              },
              loadQuality: (outputs) async {
                for (final output in outputs) {
                  output['error_count'] = output['id'] == '6' ? 1 : 0;
                  output['warning_count'] = 0;
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders total and type counts', (tester) async {
    await pumpOutputs(tester);

    expect(find.text('Scientific Outputs · 6'), findsOneWidget);
    expect(find.text('Livros 4'), findsOneWidget);
    expect(find.text('Formação avançada 2'), findsOneWidget);
  });

  testWidgets('search narrows output rows', (tester) async {
    await pumpOutputs(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search title or DOI'),
      'Searchable',
    );
    await tester.pump(const Duration(milliseconds: 301));

    expect(find.text('Searchable Paper'), findsOneWidget);
    expect(find.text('Project Activity'), findsNothing);
  });

  testWidgets('featured, attention and ORCID views filter outputs', (
    tester,
  ) async {
    await pumpOutputs(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Featured'));
    await tester.pump();
    expect(find.text('Featured Book'), findsNWidgets(2));
    expect(find.text('Searchable Paper'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Needs attention'));
    await tester.pump();
    expect(find.text('Rejected Training'), findsOneWidget);
    expect(find.text('Flagged Book'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'ORCID reconciliation'));
    await tester.pump();
    expect(find.text('ORCID Book'), findsOneWidget);
    expect(find.text('Rejected Training'), findsNothing);
  });

  testWidgets('ORCID reconciliation view renders its injected panel', (
    tester,
  ) async {
    await pumpOutputs(
      tester,
      orcidPanel: const Text('Injected ORCID candidates'),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'ORCID reconciliation'));
    await tester.pump();

    expect(find.text('Injected ORCID candidates'), findsOneWidget);
    expect(find.text('Already imported from ORCID · 1'), findsOneWidget);
  });

  testWidgets('groups by year by default and by type on request', (
    tester,
  ) async {
    await pumpOutputs(tester);

    expect(find.text('2026 · 2'), findsOneWidget);
    expect(find.text('2025 · 2'), findsOneWidget);
    expect(find.text('2024 · 2'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<OutputGroup>),
        matching: find.text('Type'),
      ),
    );
    await tester.pump();
    expect(find.text('Livros · 4'), findsOneWidget);
    expect(find.text('Formação avançada · 2'), findsOneWidget);
  });

  testWidgets('Edit is optional and returns the output map', (tester) async {
    Map<String, dynamic>? edited;
    await pumpOutputs(tester, onEdit: (output) => edited = output);

    expect(find.byTooltip('Edit output'), findsNWidgets(6));
    await tester.tap(find.byTooltip('Edit output').first);
    expect(edited?['id'], '1');

    await pumpOutputs(tester);
    expect(find.byTooltip('Edit output'), findsNothing);
  });

  testWidgets('contains outputs only', (tester) async {
    await pumpOutputs(tester);

    expect(find.textContaining('Membership'), findsNothing);
    expect(find.textContaining('Lab ·'), findsNothing);
    expect(find.textContaining('Role ·'), findsNothing);
  });
}

Map<String, dynamic> _author(
  String id,
  String title,
  int year,
  String category, {
  String approval = 'approved',
  String source = 'manual',
  Map<String, String>? project,
}) => {
  'outputs': {
    'id': id,
    'title': title,
    'reporting_year': year,
    'category_path': category,
    'approval_status': approval,
    'website_status': id == '1' ? 'published' : 'not_published',
    'source': source,
    'project_outputs': [
      if (project != null) {'projects': project},
    ],
  },
};
