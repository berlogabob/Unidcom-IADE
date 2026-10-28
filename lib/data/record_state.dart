/// Display state only: publishing takes precedence over the review stage.
/// Legacy and returned-for-changes records belong to Draft.
String recordState(Map<String, dynamic> record) {
  if (record['website_status'] == 'published') return 'On site';
  final status = record['approval_status'] ?? record['profile_status'];
  return switch (status) {
    'approved' => 'Approved',
    'submitted' ||
    'pending' ||
    'pending_review' ||
    'under_review' ||
    'under review' => 'In review',
    _ => 'Draft',
  };
}
