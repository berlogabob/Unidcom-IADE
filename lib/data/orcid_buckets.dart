/// ORCID reconciliation buckets from Rui's 10 Sep 2026 spec, §16–§18
/// (Doc 2 §L/§M).
enum CandidateBucket { fresh, possibleDuplicate, notMine }

Map<CandidateBucket, List<Map<String, dynamic>>> bucketCandidates(
  List<Map<String, dynamic>> candidates,
) {
  final buckets = {
    for (final bucket in CandidateBucket.values)
      bucket: <Map<String, dynamic>>[],
  };
  for (final candidate in candidates) {
    final bucket = switch (candidate['status']) {
      'pending' =>
        candidate['matched_output_id'] == null
            ? CandidateBucket.fresh
            : CandidateBucket.possibleDuplicate,
      'rejected' => CandidateBucket.notMine,
      _ => null,
    };
    if (bucket != null) buckets[bucket]!.add(candidate);
  }
  for (final rows in buckets.values) {
    rows.sort((a, b) {
      final years = _year(b).compareTo(_year(a));
      return years != 0
          ? years
          : (a['title']?.toString() ?? '').compareTo(
              b['title']?.toString() ?? '',
            );
    });
  }
  return buckets;
}

List<Map<String, dynamic>> unambiguous(List<Map<String, dynamic>> candidates) =>
    bucketCandidates(candidates)[CandidateBucket.fresh]!
        .where((candidate) => candidate['affiliation'] == 'unidcom')
        .toList();

String? reviewReason(Map<String, dynamic> candidate) {
  if (candidate['matched_output_id'] != null) return 'Possible duplicate';
  return switch (candidate['affiliation']) {
    'external' => 'Published outside IADE',
    'unknown' => 'Affiliation uncertain',
    _ => null,
  };
}

int _year(Map<String, dynamic> candidate) => candidate['reporting_year'] is int
    ? candidate['reporting_year'] as int
    : int.tryParse(candidate['reporting_year']?.toString() ?? '') ?? -1;
