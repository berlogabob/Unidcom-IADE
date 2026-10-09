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
    final lastSyncText = _getLastSyncText();
    final lastSyncDate = _getLastSyncDate();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Last sync info
        Text(lastSyncText, style: const TextStyle(fontSize: 16)),
        if (lastSyncDate != null)
          Text(
            lastSyncDate,
            style: const TextStyle(color: AppColors.textMuted),
          ),
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
        const Text(
          'Waiting for the next sync',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (waiting.isEmpty)
          const Text(
            'Nothing is waiting for the sync.',
            style: TextStyle(color: AppColors.textMuted),
          )
        else
          ...waiting.map((item) {
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

        // Sync button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _showSyncConfirmation(context),
            child: const Text('Sync to website'),
          ),
        ),
      ],
    );
  }

  String _getLastSyncText() {
    // Handle the case where last might be null
    if (last == null) {
      return 'Last sync: never run';
    }

    // Use safe access to map values
    final status = last!['status'];
    if (status == 'completed') {
      final conclusion = last!['conclusion'];
      if (conclusion == 'success') {
        return 'Last sync: succeeded';
      } else {
        return 'Last sync: failed';
      }
    }
    // GitHub reports queued | in_progress while a run is on its way.
    return 'Last sync: running';
  }

  String? _getLastSyncDate() {
    if (last == null) return null;

    final updatedAt = last!['updated_at'];
    if (updatedAt == null) return null;

    try {
      final date = DateTime.parse(updatedAt.toString()).toLocal();
      return dayLabel(date);
    } catch (e) {
      return null;
    }
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
