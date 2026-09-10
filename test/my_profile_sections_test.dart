import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:unidcom_iade/app/my_profile.dart';
import 'package:unidcom_iade/public/person/profile_sections.dart';
import 'package:unidcom_iade/public/person_page.dart';

void main() {
  group('mySlots', () {
    test('personal section shows confirm button only', () {
      final slots = mySlots(MySection.personal);
      expect(slots.confirm, true);
      expect(slots.addOutput, false);
      expect(slots.orcidCandidates, false);
    });

    test('identifiers section shows no extra slots', () {
      final slots = mySlots(MySection.identifiers);
      expect(slots.confirm, false);
      expect(slots.addOutput, false);
      expect(slots.orcidCandidates, false);
    });

    test('biography section shows no extra slots', () {
      final slots = mySlots(MySection.biography);
      expect(slots.confirm, false);
      expect(slots.addOutput, false);
      expect(slots.orcidCandidates, false);
    });

    test('outputs section shows addOutput only', () {
      final slots = mySlots(MySection.outputs);
      expect(slots.addOutput, true);
      expect(slots.confirm, false);
      expect(slots.orcidCandidates, false);
    });

    test('importSync section shows orcidCandidates only', () {
      final slots = mySlots(MySection.importSync);
      expect(slots.addOutput, false);
      expect(slots.confirm, false);
      expect(slots.orcidCandidates, true);
    });
  });

  test('personal section renders all profile sections', () {
    expect(personSectionsFor(MySection.personal), {
      PersonSection.personal,
      PersonSection.identifiers,
      PersonSection.biography,
    });
    expect(personSectionsFor(MySection.outputs), {PersonSection.outputs});
  });

  testWidgets('ORCID panel explains when no ORCID iD is on file', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrcidCandidatesPanel(
            orcid: null,
            candidates: const [],
            addingAll: false,
            onAddAll: (_) async {},
            onReviewCandidate: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('Add your ORCID iD'), findsOneWidget);
    expect(
      find.text(
        'No ORCID iD is on file for you, so nothing can be synchronised yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'ORCID panel explains the Monday check when there are no candidates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrcidCandidatesPanel(
              orcid: '0000-0001-2345-6789',
              candidates: const [],
              addingAll: false,
              onAddAll: (_) async {},
              onReviewCandidate: (_, _) {},
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Works are checked every Monday morning; anything you add on ORCID '
          'appears here after the next check.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('ORCID panel renders reconciliation buckets and match title', (
    tester,
  ) async {
    await _pumpOrcidPanel(tester, candidates: _mixedCandidates);

    expect(
      find.text('2 new · 1 possible duplicates · 1 not mine'),
      findsOneWidget,
    );
    expect(find.text('New in ORCID · 2'), findsOneWidget);
    expect(find.text('Possible duplicates · 1'), findsOneWidget);
    expect(find.text('Not mine · 1'), findsOneWidget);
    expect(find.text('Already recorded as: Existing work'), findsOneWidget);
  });

  testWidgets('Add all confirmation can be cancelled', (tester) async {
    var calls = 0;
    await _pumpOrcidPanel(
      tester,
      candidates: _mixedCandidates,
      onAddAll: (_) async => calls++,
    );

    await tester.tap(find.text('Add all unambiguous (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Add 1 publications from ORCID?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('Add all sends exactly the unambiguous rows', (tester) async {
    List<Map<String, dynamic>>? added;
    await _pumpOrcidPanel(
      tester,
      candidates: _mixedCandidates,
      onAddAll: (rows) async => added = rows,
    );

    await tester.tap(find.text('Add all unambiguous (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(added!.map((row) => row['id']), ['fresh']);
  });

  testWidgets('renders human-readable profile status chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => personHeader(
            context,
            {
              'preferred_name': 'Researcher',
              'membership_type': 'external',
              'status': 'inactive',
              'profile_status': 'pending_review',
            },
            admin: false,
            isOwner: true,
            hasLinkedOrcid: true,
            enriching: false,
            syncing: false,
            onEdit: () {},
            onConnectOrcid: () {},
            onAutoFill: () {},
            onCheckOrcidSync: () {},
            onApprove: () {},
          ),
        ),
      ),
    );

    expect(find.text('External researcher'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .every((text) => !(text.data?.contains('_') ?? false)),
      isTrue,
    );
  });
}

Future<void> _pumpOrcidPanel(
  WidgetTester tester, {
  required List<Map<String, dynamic>> candidates,
  Future<void> Function(List<Map<String, dynamic>> rows)? onAddAll,
}) async {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrcidCandidatesPanel(
            orcid: '0000-0001-2345-6789',
            candidates: candidates,
            addingAll: false,
            onAddAll: onAddAll ?? (_) async {},
            onReviewCandidate: (_, _) {},
          ),
        ),
      ),
    ),
  );
}

final _mixedCandidates = <Map<String, dynamic>>[
  {
    'id': 'fresh',
    'title': 'Fresh work',
    'reporting_year': 2026,
    'type': 'journal-article',
    'status': 'pending',
    'affiliation': 'unidcom',
  },
  {
    'id': 'uncertain',
    'title': 'Uncertain work',
    'reporting_year': 2025,
    'type': 'book',
    'status': 'pending',
    'affiliation': 'unknown',
  },
  {
    'id': 'duplicate',
    'title': 'Duplicate work',
    'reporting_year': 2024,
    'type': 'journal-article',
    'status': 'pending',
    'affiliation': 'unidcom',
    'matched_output_id': 'output-1',
    'matched': {'id': 'output-1', 'title': 'Existing work'},
  },
  {
    'id': 'rejected',
    'title': 'Not my work',
    'reporting_year': 2023,
    'status': 'rejected',
    'affiliation': 'unidcom',
  },
];
