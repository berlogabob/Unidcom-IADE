import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/request_status.dart';

void main() {
  test('requestStatuses lists the full pipeline in order', () {
    expect(requestStatuses, [
      'draft',
      'submitted',
      'approved',
      'rejected',
      'completed',
    ]);
  });

  test('ownerCanEdit is true only for draft and submitted', () {
    for (final status in requestStatuses) {
      expect(
        ownerCanEdit(status),
        status == 'draft' || status == 'submitted',
        reason: 'status=$status',
      );
    }
  });

  test('ownerCanSubmit is true only for draft', () {
    for (final status in requestStatuses) {
      expect(ownerCanSubmit(status), status == 'draft', reason: 'status=$status');
    }
  });

  test('adminNextStatuses offers approve/reject from submitted', () {
    expect(adminNextStatuses('submitted'), ['approved', 'rejected']);
  });

  test('adminNextStatuses offers complete/reject from approved', () {
    expect(adminNextStatuses('approved'), ['completed', 'rejected']);
  });

  test('adminNextStatuses is empty once out of the review pipeline', () {
    for (final status in ['draft', 'rejected', 'completed']) {
      expect(adminNextStatuses(status), isEmpty, reason: 'status=$status');
    }
  });

  test('adminNextStatuses is empty for an unknown status', () {
    expect(adminNextStatuses('bogus'), isEmpty);
  });
}
