import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/output_wizard.dart';
import 'package:unidcom_iade/data/enrich_client.dart';
import 'package:unidcom_iade/data/taxonomy.dart';

const _taxonomy = [
  TaxonomyNode('Livros', [
    TaxonomyNode('Livro (autor)', []),
    TaxonomyNode('Livro (editor)', []),
  ]),
  TaxonomyNode('Formação avançada', []),
];

void main() {
  test('wizardSteps omits empty steps', () {
    expect(wizardSteps(typeHasChildren: false, hasProjects: false), [
      WizardStep.doi,
      WizardStep.type,
      WizardStep.metadata,
      WizardStep.review,
    ]);
    expect(
      wizardSteps(typeHasChildren: true, hasProjects: true),
      WizardStep.values,
    );
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    Future<List<Map<String, dynamic>>> Function({String? doi, String? title})?
    findSimilar,
    Future<String> Function(
      Map<String, dynamic> fields, {
      List<String> projectIds,
    })?
    create,
    ValueChanged<bool?>? onResult,
  }) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final result = await showOutputWizard(
                  context,
                  lookup: (doi) async => doi == '10.1/x'
                      ? DoiWork(
                          title: 'A found title',
                          year: 2025,
                          type: 'book',
                          containerTitle: 'Design Press',
                          authors: ['A Researcher'],
                          doi: doi,
                        )
                      : null,
                  findSimilar: findSimilar ?? ({doi, title}) async => const [],
                  loadTaxonomy: () async => _taxonomy,
                  loadKinds: () async => const {'Livros': 'publication'},
                  loadPerson: () async => {'id': 'person-1'},
                  loadProjects: (_) async => [(id: 'p1', title: 'Project One')],
                  create:
                      create ??
                      (fields, {projectIds = const []}) async => 'new-id',
                );
                onResult?.call(result);
              },
              child: const Text('Open wizard'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open wizard'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).hitTestable().last);
    await tester.pumpAndSettle();
  }

  testWidgets('manual entry requires a type and handles ragged taxonomy', (
    tester,
  ) async {
    await pumpWizard(tester);
    await tapVisible(tester, 'No DOI — enter manually');
    expect(find.text('Publications'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue').hitTestable(),
          )
          .onPressed,
      isNull,
    );

    await tapVisible(tester, 'Livros');
    await tapVisible(tester, 'Continue');
    expect(find.text('Livro (autor)'), findsOneWidget);
    expect(find.text('Livro (editor)'), findsOneWidget);

    await tapVisible(tester, 'Back');
    await tapVisible(tester, 'Formação avançada');
    await tapVisible(tester, 'Continue');
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
  });

  testWidgets('DOI lookup prefills metadata title', (tester) async {
    await pumpWizard(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'DOI (or paste the doi.org link)'),
      'https://doi.org/10.1/x',
    );
    await tapVisible(tester, 'Look up');
    await tapVisible(tester, 'Continue');
    await tapVisible(tester, 'Formação avançada');
    await tapVisible(tester, 'Continue');
    expect(find.widgetWithText(TextField, 'A found title'), findsOneWidget);
  });

  testWidgets('an exact DOI duplicate blocks Continue', (tester) async {
    await pumpWizard(
      tester,
      findSimilar: ({doi, title}) async => [
        {'match': 'doi', 'id': 'dup', 'title': 'Dup'},
      ],
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'DOI (or paste the doi.org link)'),
      '10.1/x',
    );
    await tapVisible(tester, 'Look up');
    expect(find.text('This output is already recorded'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue').hitTestable(),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('happy path submits fields and selected project', (tester) async {
    final calls = <({Map<String, dynamic> fields, List<String> projectIds})>[];
    bool? result;
    await pumpWizard(
      tester,
      onResult: (value) => result = value,
      create: (fields, {projectIds = const []}) async {
        calls.add((fields: fields, projectIds: projectIds));
        return 'new-id';
      },
    );
    await tapVisible(tester, 'No DOI — enter manually');
    await tapVisible(tester, 'Livros');
    await tapVisible(tester, 'Continue');
    await tapVisible(tester, 'Livro (autor)');
    await tapVisible(tester, 'Continue');
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'My book');
    await tester.enterText(
      find.widgetWithText(TextField, 'Reporting year'),
      '2025',
    );
    await tapVisible(tester, 'Continue');
    await tapVisible(tester, 'Project One');
    await tapVisible(tester, 'Continue');
    await tapVisible(tester, 'Submit for UNIDCOM review');

    expect(calls, hasLength(1));
    expect(calls.single.fields['category_path'], 'Livros › Livro (autor)');
    expect(calls.single.fields['reporting_year'], 2025);
    expect(calls.single.projectIds, ['p1']);
    expect(result, isTrue);
  });
}
