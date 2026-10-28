import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/record_state.dart';

void main() {
  // Every supported review value crossed with every existing website value.
  const reviews = <String?, String>{
    null: 'Draft',
    '': 'Draft',
    'none': 'Draft',
    'draft': 'Draft',
    'to_validate': 'Draft',
    'rejected': 'Draft',
    'change_requested': 'Draft',
    'submitted': 'In review',
    'pending': 'In review',
    'pending_review': 'In review',
    'under_review': 'In review',
    'under review': 'In review',
    'approved': 'Approved',
    'unknown': 'Draft',
  };
  const websites = [
    null,
    '',
    'not_published',
    'pending',
    'ready',
    'published',
    'error',
  ];
  for (final column in ['profile_status', 'approval_status']) {
    for (final review in reviews.entries) {
      for (final website in websites) {
        test('$column=${review.key}, website=$website', () {
          expect(
            recordState({column: review.key, 'website_status': website}),
            website == 'published' ? 'On site' : review.value,
          );
        });
      }
    }
  }
  test('legacy visibility and membership status do not imply publication', () {
    expect(
      recordState({'public_visibility': true, 'status': 'active'}),
      'Draft',
    );
    expect(recordState({}), 'Draft');
  });
}
