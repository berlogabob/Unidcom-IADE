import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/mode_chooser.dart';
import 'package:unidcom_iade/data/taxonomy.dart';
import 'package:unidcom_iade/data/enrich_client.dart';
import 'package:unidcom_iade/public/output_page.dart';
import 'package:unidcom_iade/widgets/taxonomy_picker.dart';

// Widget-level checks for the two pieces of new UI a researcher meets first.
// Neither touches Supabase: the chooser only reads/writes the view-mode
// notifier, and the picker is fed its tree by the caller.
void main() {
  group('mode chooser', () {
    testWidgets('offers both jobs, and says the choice is reversible', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ModeChooserScreen())),
      );

      expect(find.text('How do you want to continue?'), findsOneWidget);
      expect(find.text('As a researcher'), findsOneWidget);
      expect(find.text('As an administrator'), findsOneWidget);
      expect(
        find.text('You can switch at any time from the bottom of the sidebar.'),
        findsOneWidget,
      );
    });

    testWidgets('stacks the cards on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ModeChooserScreen())),
      );
      await tester.pumpAndSettle();

      // Both still reachable, nothing clipped off the side.
      expect(find.text('As a researcher'), findsOneWidget);
      expect(find.text('As an administrator'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('taxonomy picker', () {
    final roots = buildTaxonomy([
      ['Livros', 'Capítulos de livros', 'Indexados', 'Co-autor'],
      ['Livros', 'Autoria de Livro'],
      ['Missões de internacionalização'],
    ]);

    Future<void> pump(
      WidgetTester tester,
      List<String> value,
      ValueChanged<List<String>> onChanged,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaxonomyPicker(
              roots: roots,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('starts as one box — not thirteen pills', (tester) async {
      await pump(tester, const [], (_) {});
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Subcategory'), findsNothing);
    });

    testWidgets('the next level appears only once a branch is chosen', (
      tester,
    ) async {
      await pump(tester, const ['Livros'], (_) {});
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Subcategory'), findsOneWidget);
      expect(find.text('Detail'), findsNothing);
    });

    testWidgets('a branch that ends stops asking', (tester) async {
      // Depth-1 leaf: one box and no more. This is the ragged case that a
      // fixed "three comboboxes" would have shown as two dead dropdowns.
      await pump(tester, const ['Missões de internacionalização'], (_) {});
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Subcategory'), findsNothing);
    });

    testWidgets('a full branch shows every level it has', (tester) async {
      await pump(tester, const ['Livros', 'Capítulos de livros', 'Indexados'], (
        _,
      ) {});
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Subcategory'), findsOneWidget);
      expect(find.text('Detail'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
    });

    testWidgets('changing an upper level truncates the ones below it', (
      tester,
    ) async {
      List<String>? got;
      await pump(tester, const ['Livros', 'Autoria de Livro'], (v) => got = v);

      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await tester.pumpAndSettle();
      // The menu lists both roots plus "All"; pick the other root.
      await tester.tap(find.text('Missões de internacionalização').last);
      await tester.pumpAndSettle();

      // Not ['Livros', 'Autoria de Livro'] with the head swapped — the stale
      // subcategory would select nothing at all.
      expect(got, ['Missões de internacionalização']);
    });

    testWidgets('choosing All at a level clears it and everything under it', (
      tester,
    ) async {
      List<String>? got;
      await pump(tester, const ['Livros', 'Autoria de Livro'], (v) => got = v);

      await tester.tap(find.byType(DropdownButtonFormField<String?>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();

      // Back to the whole Livros subtree, which is a real filter.
      expect(got, ['Livros']);
    });

    testWidgets('renders nothing rather than throwing before the tree loads', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaxonomyPicker(
              roots: const [],
              value: const [],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Category'), findsNothing);
    });
  });

  // The dialog reaches Supabase only on save, so everything up to that point —
  // which is all of this — pumps fine without a client.
  group('output editor in create mode', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      bool asResearcher = false,
    }) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutputEditDialog(asResearcher: asResearcher),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('is titled Add, not Edit', (tester) async {
      await pumpDialog(tester);
      expect(find.text('Add output'), findsOneWidget);
      expect(find.text('Edit output'), findsNothing);
    });

    testWidgets('has a Title field — the one NOT NULL column', (tester) async {
      // The dialog only ever edited existing rows before, so nothing had to
      // supply a title and there was no field for it.
      await pumpDialog(tester);
      expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    });

    testWidgets('refuses to save without a title, without a round trip', (
      tester,
    ) async {
      await pumpDialog(tester, asResearcher: true);
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('A title is required'), findsOneWidget);
      // If it had reached Supabase.instance the test would have thrown.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the error clears as soon as you type', (tester) async {
      await pumpDialog(tester, asResearcher: true);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('A title is required'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Navigating Visual Complexity',
      );
      await tester.pump();
      expect(find.text('A title is required'), findsNothing);
    });

    testWidgets('offers no Find DOI or Merge on a record that does not exist', (
      tester,
    ) async {
      await pumpDialog(tester);
      expect(find.text('Find DOI'), findsNothing);
      expect(find.text('Merge duplicates'), findsNothing);
    });

    testWidgets('a researcher is not asked to curate, and is told about review', (
      tester,
    ) async {
      await pumpDialog(tester, asResearcher: true);
      // "Verified online" is a curator's assertion, not the author's.
      expect(find.text('Verified online'), findsNothing);
      expect(find.textContaining('UNIDCOM reviews'), findsOneWidget);
    });

    testWidgets('an admin still gets the curation switch', (tester) async {
      await pumpDialog(tester);
      expect(find.text('Verified online'), findsOneWidget);
      expect(find.textContaining('UNIDCOM reviews'), findsNothing);
    });
  });
  group('DOI-first output', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      DoiWork? work,
      List<Map<String, dynamic>> matches = const [],
      required List<Map<String, dynamic>> created,
      bool asResearcher = true,
    }) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: OutputEditDialog(
          asResearcher: asResearcher,
          lookup: (_) async => work,
          findSimilar: ({doi, title}) async {
            expect(title, isNotEmpty);
            return matches;
          },
          create: (fields) async {
            created.add(fields);
            return 'new-output';
          },
        )),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('DOI hit fills title, year, DOI and reference', (tester) async {
      await pumpDialog(tester, created: [], work: DoiWork(
        title: 'Design research', year: 2025, type: 'journal-article',
        containerTitle: 'Design Journal', authors: ['A Researcher'],
        doi: '10.1234/design',
      ));
      await tester.enterText(find.widgetWithText(TextField,
          'DOI (or paste the doi.org link)'), 'https://doi.org/10.1234/design');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(find.text('Design research'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(tester.widget<TaxonomyPicker>(find.byType(TaxonomyPicker)).value,
          ['Artigos em revistas']);
      expect(find.text('10.1234/design'), findsOneWidget);
      expect(find.text('A Researcher · Design Journal · 2025'), findsOneWidget);
    });

    testWidgets('DOI miss preserves manual details', (tester) async {
      await pumpDialog(tester, created: []);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Manual title');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(find.text('No record found for that DOI — fill in the details below.'),
          findsOneWidget);
      expect(find.text('Manual title'), findsOneWidget);
    });

    testWidgets('DOI duplicate blocks creation', (tester) async {
      final created = <Map<String, dynamic>>[];
      await pumpDialog(tester, created: created, matches: [
        {'id': 'existing', 'title': 'Existing output',
          'approval_status': 'pending', 'match': 'doi', 'score': 1.0},
      ]);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'New title');
      await tester.enterText(find.widgetWithText(TextField,
          'DOI (or paste the doi.org link)'), 'https://doi.org/10.1234/design');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Already in the directory: Existing output (pending)'),
          findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(created, isEmpty);
    });

    testWidgets('title warning requires save anyway, including admin', (tester) async {
      final created = <Map<String, dynamic>>[];
      await pumpDialog(tester, created: created, asResearcher: false, matches: [
        {'id': 'existing', 'title': 'Similar output', 'reporting_year': 2024,
          'match': 'title', 'score': 0.8},
      ]);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'New title');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Looks like Similar output (2024)'), findsOneWidget);
      expect(created, isEmpty);
      await tester.tap(find.text("It's different — save anyway"));
      await tester.pumpAndSettle();
      expect(created.single['title'], 'New title');
    });

    testWidgets('manual path focuses title and saves without matches', (tester) async {
      final created = <Map<String, dynamic>>[];
      await pumpDialog(tester, created: created);
      await tester.tap(find.text('No DOI? Enter the details manually'));
      await tester.pump();
      final title = find.widgetWithText(TextField, 'Title');
      expect(tester.widget<TextField>(title).focusNode!.hasFocus, isTrue);
      await tester.enterText(title, 'Manual output');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(created.single['title'], 'Manual output');
      expect(created.single['doi'], isNull);
    });
  });

}
