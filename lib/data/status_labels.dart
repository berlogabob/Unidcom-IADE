/// Labels from the UNIDCOM RIMS status vocabulary specification.
String reviewLabel(String? status) => switch (status) {
  'to_validate' => 'To be validated by you',
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
  (_, _, true) => 'Import error',
  (_, true, _) => 'Changes available',
  _ => 'Connected',
};

/// Output issue code -> the words a researcher sees (Rui: 'Missing DOI', not 'Issue').
String issueLabel(String code) => switch (code) {
  'missing_doi' => 'Missing DOI',
  'missing_year' => 'Missing year',
  'missing_type' => 'Missing type',
  'missing_reference' => 'Missing reference',
  'missing_authors' => 'Missing authors',
  'affiliation_mismatch' => 'Affiliation mismatch',
  'not_on_orcid' => 'Not on ORCID',
  _ => code.replaceAll('_', ' '),
};
