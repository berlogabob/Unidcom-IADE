import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/status_labels.dart';

void main() {
  test('maps review statuses', () {
    expect(reviewLabel('draft'), 'Draft');
    expect(reviewLabel('pending'), 'Submitted');
    expect(reviewLabel('pending_review'), 'Submitted');
    expect(reviewLabel('under_review'), 'Under review');
    expect(reviewLabel('approved'), 'Approved');
    expect(reviewLabel('rejected'), 'Changes requested');
    expect(reviewLabel(null), '—');
    expect(reviewLabel('new_status'), 'new status');
  });

  test('maps website statuses', () {
    expect(websiteLabel('not_published'), 'Not published');
    expect(websiteLabel(null), 'Not published');
    expect(websiteLabel('pending'), 'Pending publication');
    expect(websiteLabel('published'), 'Published');
    expect(websiteLabel('error'), 'Publication error');
    expect(websiteLabel('new_status'), 'new status');
  });

  test('maps ORCID statuses', () {
    expect(orcidLabel(connected: false), 'Not connected');
    expect(
      orcidLabel(connected: true, changesAvailable: true),
      'Changes available',
    );
    expect(orcidLabel(connected: true, error: true), 'Sync error');
    expect(orcidLabel(connected: true), 'Connected');
  });
}
