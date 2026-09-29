import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/own_outputs.dart';
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
    List<Map<String, dynamic>>? rows,
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
              authors: rows ?? authors,
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

  // Removed 29 Sep: search, view chips, group-by and count pills are v2-only (Rui 25 Sep, SO-9); v1 is covered by outputs_page_e52_test.dart.
  testWidgets('Edit is optional and returns the output map', (tester) async {
    Map<String, dynamic>? edited;
    await pumpOutputs(tester, onEdit: (output) => edited = output);

    // v1 opens on the Publications tab (Rui 25 Sep): 4 of the 6 fixtures.
    expect(find.byTooltip('Edit output'), findsNWidgets(4));
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

  testWidgets('submits outputs needing validation', (tester) async {
    final authorsWithToValidate = <Map<String, dynamic>>[
      _author('1', 'Featured Book', 2026, 'Livros › Autor'),
      _author(
        '2',
        'To Validate Paper',
        2026,
        'Livros › Autor',
        approval: 'to_validate',
      ),
      _author('3', 'Approved Paper', 2025, 'Livros › Autor'),
    ];
    List<String>? submittedIds;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OwnOutputsSection(
              authors: authorsWithToValidate,
              featured: const ['1'],
              onToggleFeatured: (_) {},
              onOpenOutput: (_) {},
              onEditOutput: null,
              orcidPanel: null,
              loadTaxonomy: () async => const [
                TaxonomyNode('Livros', [TaxonomyNode('Autor', [])]),
                TaxonomyNode('Formação avançada', []),
              ],
              loadKinds: () async => const {'Livros': 'publication'},
              loadQuality: (_) async {},
              submitOutputs: (ids) async {
                submittedIds = ids;
                return 1;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('1 outputs to be validated by you. Check them, then submit.'),
      findsOneWidget,
    );
    expect(find.text('Submit for UNIDCOM review (1)'), findsOneWidget);

    await tester.tap(find.text('Submit for UNIDCOM review (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Submit 1 outputs for UNIDCOM review?'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(submittedIds, ['2']);
    expect(find.text('Submit for UNIDCOM review (1)'), findsNothing);
  });

  testWidgets('does not show submit button when no outputs need validation', (
    tester,
  ) async {
    await pumpOutputs(tester, rows: [_author('9', 'Checked', 2024, 'Livros')]);

    expect(find.textContaining('Submit for UNIDCOM review'), findsNothing);
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
