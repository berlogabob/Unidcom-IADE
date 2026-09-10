import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/orcid_buckets.dart';

void main() {
  final candidates = <Map<String, dynamic>>[
    _candidate('old', 'Zulu', 2024),
    _candidate('new-b', 'Beta', 2026),
    _candidate('new-a', 'Alpha', 2026),
    _candidate('duplicate', 'Duplicate', 2025, matched: 'output-1'),
    _candidate('external', 'External', 2025, affiliation: 'external'),
    _candidate('unknown', 'Unknown', 2025, affiliation: 'unknown'),
    _candidate('rejected', 'Rejected', 2023, status: 'rejected'),
    _candidate('promoted', 'Promoted', 2027, status: 'promoted'),
  ];

  test('buckets candidates and drops promoted rows', () {
    final buckets = bucketCandidates(candidates);

    expect(buckets[CandidateBucket.fresh]!.map((row) => row['id']), [
      'new-a',
      'new-b',
      'external',
      'unknown',
      'old',
    ]);
    expect(
      buckets[CandidateBucket.possibleDuplicate]!.single['id'],
      'duplicate',
    );
    expect(buckets[CandidateBucket.notMine]!.single['id'], 'rejected');
    expect(
      buckets.values.expand((rows) => rows).map((row) => row['id']),
      isNot(contains('promoted')),
    );
  });

  test('unambiguous keeps only unmatched pending UNIDCOM rows', () {
    expect(unambiguous(candidates).map((row) => row['id']), [
      'new-a',
      'new-b',
      'old',
    ]);
  });

  test('reviewReason explains every ambiguous case', () {
    expect(reviewReason(candidates[3]), 'Possible duplicate');
    expect(reviewReason(candidates[4]), 'Published outside IADE');
    expect(reviewReason(candidates[5]), 'Affiliation uncertain');
    expect(reviewReason(candidates[0]), isNull);
  });
}

Map<String, dynamic> _candidate(
  String id,
  String title,
  int year, {
  String status = 'pending',
  String affiliation = 'unidcom',
  String? matched,
}) => {
  'id': id,
  'title': title,
  'reporting_year': year,
  'status': status,
  'affiliation': affiliation,
  'matched_output_id': matched,
};
