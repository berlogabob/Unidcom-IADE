import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/my_profile.dart';

void main() {
  test('maps profile statuses to researcher-facing labels', () {
    expect(profileStatusLabel('draft'), 'Profile not confirmed');
    expect(profileStatusLabel('pending_review'), 'Awaiting UNIDCOM approval');
    expect(profileStatusLabel('approved'), 'Approved');
  });

  test('formats candidate metadata without null separators', () {
    expect(
      candidateSubtitle({'reporting_year': 2025, 'type': 'article'}),
      '2025 · article',
    );
    expect(candidateSubtitle({'reporting_year': null, 'type': 'book'}), 'book');
    expect(candidateSubtitle({'reporting_year': 2024, 'type': null}), '2024');
    expect(candidateSubtitle({}), '');
  });
}
