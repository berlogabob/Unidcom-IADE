import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/my_profile.dart';

void main() {
  group('mySlots', () {
    test('profile section shows confirm button only', () {
      final slots = mySlots(MySection.profile);
      expect(slots.confirm, true);
      expect(slots.addOutput, false);
      expect(slots.orcidCandidates, false);
    });

    test('outputs section shows addOutput and orcidCandidates', () {
      final slots = mySlots(MySection.outputs);
      expect(slots.addOutput, true);
      expect(slots.confirm, false);
      expect(slots.orcidCandidates, true);
    });
  });
}
