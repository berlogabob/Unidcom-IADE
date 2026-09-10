class AttentionItem {
  const AttentionItem(this.text, this.route);

  final String text;
  final String route;
}

/// Only actionable items, each with a destination. Order as listed.
List<AttentionItem> attentionItems({
  required Map<String, dynamic> person,
  required List<Map<String, dynamic>> outputs,
  required List<Map<String, dynamic>> candidates,
  required List<Map<String, dynamic>> suggestions,
}) {
  final fresh = candidates
      .where(
        (candidate) =>
            candidate['status'] == 'pending' &&
            candidate['matched_output_id'] == null,
      )
      .length;
  final duplicates = candidates
      .where(
        (candidate) =>
            candidate['status'] == 'pending' &&
            candidate['matched_output_id'] != null,
      )
      .length;
  final rejected = outputs
      .where((output) => output['approval_status'] == 'rejected')
      .length;
  final incomplete = outputs
      .where((output) => (output['error_count'] as num? ?? 0) > 0)
      .length;
  final declined = suggestions
      .where(
        (suggestion) =>
            suggestion['status'] == 'rejected' &&
            suggestion['source'] == 'researcher',
      )
      .length;

  String plural(int count, String singular, String plural) =>
      count == 1 ? singular : plural;

  return [
    if (person['profile_status'] == 'draft')
      const AttentionItem(
        'Your profile is not confirmed yet → Confirm it',
        '/app/profile',
      ),
    if (fresh > 0)
      AttentionItem(
        '$fresh ORCID ${plural(fresh, 'publication needs', 'publications need')} your review',
        '/app/outputs/import',
      ),
    if (duplicates > 0)
      AttentionItem(
        '$duplicates possible ${plural(duplicates, 'duplicate', 'duplicates')} detected',
        '/app/outputs/import',
      ),
    if (rejected > 0)
      AttentionItem(
        '$rejected ${plural(rejected, 'output needs', 'outputs need')} changes (UNIDCOM feedback)',
        '/app/outputs',
      ),
    if (incomplete > 0)
      AttentionItem(
        '$incomplete ${plural(incomplete, 'output is', 'outputs are')} missing required information',
        '/app/outputs',
      ),
    if (declined > 0)
      AttentionItem(
        '$declined of your proposed ${plural(declined, 'change was', 'changes were')} declined',
        '/app/profile',
      ),
  ];
}

int pendingProposals(List<Map<String, dynamic>> suggestions) => suggestions
    .where(
      (suggestion) =>
          suggestion['status'] == 'pending' &&
          suggestion['source'] == 'researcher',
    )
    .length;
