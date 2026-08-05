import 'package:flutter/material.dart';

Future<void> showOrcidSyncDialog(
  BuildContext context,
  Map<String, dynamic> status,
) => showDialog<void>(
  context: context,
  builder: (context) => _OrcidSyncDialog(status: status),
);

/// Read-only ORCID drift preview: shows whether the person lists an IADE
/// affiliation on their public ORCID and how many works are on it — i.e. what a
/// future sync would push. The actual push is gated on ORCID membership +
/// per-researcher OAuth, so the push button is disabled with an explanation.
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
      title: const Text('ORCID sync'),
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
                  : 'No IADE / UNIDCOM affiliation on ORCID — a sync would add it.',
            ),
            row(works > 0, 'Works on ORCID: $works'),
            if (orgs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Employers on ORCID', style: theme.textTheme.labelMedium),
              Text(orgs.join(', '), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Pushing to ORCID needs ORCID membership + the researcher to '
                'connect their ORCID (OAuth). Bio/name are never writable — only '
                'affiliation, works, funding and keywords. Not enabled yet.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        const FilledButton(
          onPressed:
              null, // gated until ORCID membership + OAuth are configured
          child: Text('Push to ORCID'),
        ),
      ],
    );
  }
}
