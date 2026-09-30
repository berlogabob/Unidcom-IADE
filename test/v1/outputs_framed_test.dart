import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/own_outputs.dart';
import 'package:unidcom_iade/data/taxonomy.dart';
import 'package:unidcom_iade/widgets/ds_page.dart';
import 'package:unidcom_iade/widgets/panels.dart';

// Rui 25 Sep, Scientific Outputs TARGET LAYOUT (A4): title card with
// "+ Add output" · ORCID banner · filters block · rows block — all Panels.
void main() {
  testWidgets('framed section renders its blocks as Panels inside DsPage', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DsPage(
            title: 'Scientific Outputs',
            subtitle: 'All your research outputs. Click an output to see details or fix issues.',
            action: FilledButton(onPressed: () {}, child: const Text('+ Add output')),
            children: [
              OwnOutputsSection(
                framed: true,
                authors: const [
                  {
                    'role': 'Autor',
                    'outputs': {
                      'id': '1',
                      'title': 'Book One',
                      'reporting_year': 2024,
                      'category_path': 'Livros › Autor',
                      'type': 'Livros',
                      'approval_status': 'approved',
                      'website_status': 'published',
                      'source': 'manual',
                      'error_count': 0,
                      'warning_count': 0,
                      'issue_codes': <String>[],
                    },
                  },
                ],
                featured: const [],
                onToggleFeatured: (_) {},
                onOpenOutput: (_) {},
                newOrcidPublications: 3,
                onReviewOrcid: () {},
                loadTaxonomy: () async => const [TaxonomyNode('Livros', [TaxonomyNode('Autor', [])])],
                loadKinds: () async => const {'Livros': 'publication'},
                loadQuality: (_) async {},
                submitOutputs: (_) async => 0,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Scientific Outputs ·'), findsNothing,
        reason: 'the page title card replaces the section header');
    final title = tester.getTopLeft(find.text('Scientific Outputs')).dy;
    final banner = tester.getTopLeft(find.text('3 new publications in ORCID → Review')).dy;
    final filters = tester.getTopLeft(find.text('Publications')).dy;
    final row = tester.getTopLeft(find.text('Book One')).dy;
    expect(title < banner && banner < filters && filters < row, isTrue);
    // banner, filters and rows are three separate Panels (+ the title card)
    expect(find.byType(Panel), findsAtLeastNWidgets(4));
    expect(
      find.ancestor(of: find.text('Book One'), matching: find.byType(Panel)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Publications'), matching: find.byType(Panel)),
      findsOneWidget,
    );
  });
}
