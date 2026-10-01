import 'package:flutter/material.dart';

Future<void> showOrcidSyncDialog(
  BuildContext context,
  Map<String, dynamic> status,
) => showDialog<void>(
  context: context,
  builder: (context) => _OrcidSyncDialog(status: status),
);

/// Read-only ORCID check: does the person list an IADE affiliation on their
/// public ORCID, and how many works are on it. v1.0 is import-only (Rui's brief
/// G-5): no push, no sync button — two-way sync is v2.0.
class _OrcidSyncDialog extends StatelessWidget {
  const _OrcidSyncDialog({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final affiliation = status['affiliationOnOrcid'] == true;
    final orgs = (status['orgNames'] as List?)?.cast<String>() ?? const [];
    final works = status['worksCount'] as int? ?? 0;
    final theme = Theme.of(context);

    Widget row(bool ok, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return AlertDialog(
      title: const Text('ORCID check'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('ORCID ${status['orcid']}'),
            const SizedBox(height: 12),
            row(
              affiliation,
              affiliation
                  ? 'IADE / UNIDCOM affiliation is on their ORCID record.'
                  : 'No IADE / UNIDCOM affiliation on their ORCID record.',
            ),
            row(works > 0, 'Works on ORCID: $works'),
            if (orgs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Employers on ORCID', style: theme.textTheme.labelMedium),
              Text(orgs.join(', '), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Text(
              'This only reads ORCID. New works appear under Import from ORCID '
              'as candidates to add; profile fields found on ORCID appear as '
              'suggestions for UNIDCOM.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
