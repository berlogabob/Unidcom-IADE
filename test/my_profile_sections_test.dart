import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:unidcom_iade/app/my_profile.dart';

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

  testWidgets('ORCID panel explains when no ORCID iD is on file', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrcidCandidatesPanel(
            orcid: null,
            candidates: const [],
            addingAll: false,
            onAddAll: () async {},
            onReviewCandidate: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('Add your ORCID iD'), findsOneWidget);
    expect(
      find.text('No ORCID iD is on file for you, so nothing can be synchronised yet.'),
      findsOneWidget,
    );
  });

  testWidgets('ORCID panel explains the Monday check when there are no candidates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrcidCandidatesPanel(
            orcid: '0000-0001-2345-6789',
            candidates: const [],
            addingAll: false,
            onAddAll: () async {},
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
  });
}
