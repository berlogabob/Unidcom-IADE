import 'package:flutter/material.dart';

/// One ORCID work waiting for review, e.g. "Andrey Dyakov · 2018 · external · 5%"
/// with the classifier's reason underneath and Import/Dismiss actions.
class CandidateTile extends StatelessWidget {
  const CandidateTile({
    super.key,
    required this.candidate,
    required this.onImport,
    required this.onDismiss,
  });

  final Map<String, dynamic> candidate;
  final ValueChanged<String> onImport;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final affiliation = candidate['affiliation'] as String? ?? 'unknown';
    final score = candidate['affiliation_score'];
    final scoreText = score == null
        ? ''
        : ' · ${(num.parse(score.toString()) * 100).round()}%';
    final year = candidate['reporting_year']?.toString() ?? 'undated';
    // Non-null means the work is already in the directory, so importing only
    // adds the missing author link rather than creating a second row.
    final matched = candidate['matched_output_id'] != null;

    return ListTile(
      isThreeLine: true,
      title: Text(candidate['title'] as String? ?? 'Untitled'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${candidate['person_name']} · $year · $affiliation$scoreText'),
          Text(
            candidate['reason'] as String? ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (matched)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Chip(
                label: Text('Already in directory'),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton(onPressed: onDismiss, child: const Text('Dismiss')),
          // The reviewer can overrule the classifier at the moment of import,
          // which is the only place they have the full context to judge.
          PopupMenuButton<String>(
            tooltip: 'Import as…',
            onSelected: onImport,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'unidcom', child: Text('Import as UNIDCOM')),
              PopupMenuItem(value: 'external', child: Text('Import as external')),
            ],
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: theme.colorScheme.primary,
                disabledForegroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text(matched ? 'Link author' : 'Import'),
            ),
          ),
        ],
      ),
    );
  }
}
