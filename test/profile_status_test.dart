import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/my_profile.dart';

void main() {
  test('maps profile statuses to researcher-facing labels', () {
    expect(profileStatusLabel('draft'), 'Profile not confirmed');
    expect(profileStatusLabel('pending_review'), 'Awaiting UNIDCOM approval');
    expect(profileStatusLabel('approved'), 'Approved');
  });
}
