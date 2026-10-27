import 'package:flutter/material.dart';

import '../../data/supabase.dart';

/// Mounted only on the admin person detail page.
class PersonSanityPushButton extends StatefulWidget {
  const PersonSanityPushButton({
    super.key,
    required this.personId,
    required this.outputIds,
  });

  final String personId;
  final List<String> outputIds;

  @override
  State<PersonSanityPushButton> createState() => _PersonSanityPushButtonState();
}

class _PersonSanityPushButtonState extends State<PersonSanityPushButton> {
  bool _busy = false;

  Future<void> _push() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Keep the selection identical between preview and confirmation.
    final personId = widget.personId;
    final outputIds = List<String>.of(widget.outputIds);
    try {
      final preview = await runPersonSanityPush(
        personId: personId,
        outputIds: outputIds,
      );
      if (!mounted) return;
      final confirmed = await _showResult(preview, preview: true);
      if (confirmed != true || !mounted) return;
      final result = await runPersonSanityPush(
        personId: personId,
        outputIds: outputIds,
        dryRun: false,
      );
      if (!mounted) return;
      await _showResult(result, preview: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sanity push failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showResult(
    Map<String, dynamic> result, {
    required bool preview,
  }) => showDialog<bool>(
    context: context,
    builder: (context) {
      final counts = result['counts'] as Map;
      final dropped = result['dropped'] as List? ?? [];
      final warnings = result['warnings'] as List? ?? [];
      return AlertDialog(
        title: Text(preview ? 'Preview Sanity push' : 'Pushed to test Sanity'),
        scrollable: true,
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sanity project: ${result['project']}'),
              if (preview)
                const Text(
                  'Includes this researcher, their outputs and coauthors, '
                  'including private profiles. Preview does not upload images.',
                ),
              const SizedBox(height: 12),
              for (final entry in counts.entries)
                Text('${entry.key}: ${entry.value}'),
              const SizedBox(height: 12),
              Text('Dropped authors: ${dropped.length}'),
              for (final author in dropped)
                SelectableText(
                  'Output ${author['outputId']}: '
                  '${author['personId'] ?? 'unknown author'}',
                ),
              const SizedBox(height: 12),
              Text('Warnings: ${warnings.length}'),
              for (final warning in warnings) SelectableText('$warning'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(preview ? 'Cancel' : 'Close'),
          ),
          if (preview)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm push'),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _push,
    icon: const Icon(Icons.upload_outlined),
    label: Text(_busy ? 'Pushing…' : 'Push to test Sanity'),
  );
}
