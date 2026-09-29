import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/status_labels.dart';

void main() {
  test('maps review statuses', () {
    expect(reviewLabel('draft'), 'Draft');
    expect(reviewLabel('pending'), 'Submitted');
    expect(reviewLabel('pending_review'), 'Submitted');
    expect(reviewLabel('under_review'), 'Under review');
    expect(reviewLabel('to_validate'), 'To be validated by you');
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
    expect(orcidLabel(connected: true, error: true), 'Import error');
    expect(orcidLabel(connected: true), 'Connected');
  });

  test('issueLabel names each issue in full', () {
    expect(issueLabel('missing_doi'), 'Missing DOI');
    expect(issueLabel('missing_year'), 'Missing year');
    expect(issueLabel('missing_type'), 'Missing type');
    expect(issueLabel('missing_reference'), 'Missing reference');
    expect(issueLabel('missing_authors'), 'Missing authors');
    expect(issueLabel('affiliation_mismatch'), 'Affiliation mismatch');
    expect(issueLabel('not_on_orcid'), 'Not on ORCID');
    expect(issueLabel('odd_thing'), 'odd thing');
  });
}
