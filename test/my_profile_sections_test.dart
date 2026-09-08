import 'package:flutter_test/flutter_test.dart';
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
}
