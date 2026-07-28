import 'package:flutter/material.dart';

/// Enrichment-suggestion row, e.g. "orcid: empty -> 0000-... · 40%" with
/// Accept/Reject actions. Shared by the review queue and the person page
/// (which hides the redundant subject title via [showTitle]).
class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onReject,
    this.showTitle = true,
    this.onOpenClash,
    this.clashTitle,
  });

  final Map<String, dynamic> suggestion;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool showTitle;

  /// Set for a `duplicate_of` suggestion: the found DOI already belongs to
  /// another output, so there is nothing to accept — the admin goes and merges.
  final VoidCallback? onOpenClash;
  final String? clashTitle;

  @override
  Widget build(BuildContext context) {
    final current = suggestion['current_value'] as String?;
    final value = suggestion['suggested_value'] as String? ?? '';
    final confidence = suggestion['confidence'];
    final confidenceText = confidence == null
        ? ''
        : ' · ${(num.parse(confidence.toString()) * 100).round()}%';
    final isClash = suggestion['field'] == 'duplicate_of';
    final detail = isClash
        ? 'DOI already belongs to: ${clashTitle ?? value}\n'
              'possible duplicate — merge instead${confidenceText.isEmpty ? '' : confidenceText}'
        : '${suggestion['field']}: ${current ?? 'empty'} -> $value\n'
              '${suggestion['source']}$confidenceText';

    return ListTile(
      title: showTitle
          ? Text(suggestion['subject_name'] as String? ?? 'Missing subject')
          : Text(detail),
      subtitle: showTitle ? Text(detail) : null,
      isThreeLine: showTitle,
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: onReject,
            child: Text(isClash ? 'Dismiss' : 'Reject'),
          ),
          if (isClash)
            if (onOpenClash != null)
              FilledButton(
                onPressed: onOpenClash,
                child: const Text('Open duplicate'),
              )
            else
              const SizedBox.shrink()
          else
            FilledButton(onPressed: onAccept, child: const Text('Accept')),
        ],
      ),
    );
  }
}
