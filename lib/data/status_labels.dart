/// Labels from the UNIDCOM RIMS status vocabulary specification.
String reviewLabel(String? status) => switch (status) {
  'draft' => 'Draft',
  'pending' || 'pending_review' => 'Submitted',
  'under_review' => 'Under review',
  'approved' => 'Approved',
  'rejected' => 'Changes requested',
  null => '—',
  _ => status.replaceAll('_', ' '),
};

String websiteLabel(String? status) => switch (status) {
  null || 'not_published' => 'Not published',
  'pending' => 'Pending publication',
  'published' => 'Published',
  'error' => 'Publication error',
  _ => status.replaceAll('_', ' '),
};

String orcidLabel({
  required bool connected,
  bool changesAvailable = false,
  bool error = false,
}) => switch ((connected, changesAvailable, error)) {
  (false, _, _) => 'Not connected',
  (_, _, true) => 'Sync error',
  (_, true, _) => 'Changes available',
  _ => 'Connected',
};
