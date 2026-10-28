import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../widgets/suggestion_tile.dart';

class WebsiteSyncView extends StatelessWidget {
  final Map<String, dynamic>? last;
  final int readyCount;
  final List<Map<String, dynamic>> waiting;
  final Future<void> Function() onSync;
  final VoidCallback onOpenReady;

  const WebsiteSyncView({
    super.key,
    required this.last,
    required this.readyCount,
    required this.waiting,
    required this.onSync,
    required this.onOpenReady,
  });

  @override
  Widget build(BuildContext context) {
    final lastSyncTime = DateTime.tryParse(
      '${last?['started_at'] ?? last?['updated_at']}',
    );
    final lastSyncDate = DateTime.tryParse(
      '${last?['updated_at'] ?? last?['started_at']}',
    );
    final lastSyncText = last == null
        ? 'The website syncs by itself every 10 minutes; use Retry only if a change does not appear.'
        : 'Last sync: ${lastSyncDate == null ? 'unknown' : dayLabel(lastSyncDate.toLocal())}';
    final pending = lastSyncTime == null
        ? <Map<String, dynamic>>[]
        : waiting.where((item) {
            final publishedAt = DateTime.tryParse('${item['published_at']}');
            return publishedAt != null && publishedAt.isAfter(lastSyncTime);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Last sync info
        Text(lastSyncText, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),

        // Ready count
        Text(
          '$readyCount researchers are accepted but not published',
          style: const TextStyle(fontSize: 16),
        ),
        TextButton(
          onPressed: onOpenReady,
          child: const Text('Open Ready to publish'),
        ),
        const SizedBox(height: 16),

        // Waiting section
        if (lastSyncTime != null) ...[
          const Text(
            'Waiting for the next sync',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Text(
              'Nothing is waiting for the sync.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            ...pending.map((item) {
              final preferredName = item['preferred_name'] as String?;
              final publishedAt = item['published_at'] as String?;
              final publishedDate = publishedAt != null
                  ? dayLabel(DateTime.parse(publishedAt).toLocal())
                  : '';

              return ListTile(
                title: Text(preferredName ?? 'Missing name'),
                subtitle: Text('Published: $publishedDate'),
              );
            }),
          const SizedBox(height: 16),
        ],

        // Recovery action
        const Text('Retry if published changes have not reached the website.'),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _showSyncConfirmation(context),
            child: const Text('Retry website sync'),
          ),
        ),
      ],
    );
  }

  void _showSyncConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update the UNIDCOM website now?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await onSync();
              },
              child: const Text('Sync'),
            ),
          ],
        );
      },
    );
  }
}
