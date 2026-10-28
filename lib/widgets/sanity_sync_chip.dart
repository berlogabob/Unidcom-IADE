import 'package:flutter/material.dart';

import 'panels.dart';

class SanitySyncChip extends StatefulWidget {
  const SanitySyncChip({super.key, this.syncedAt, this.error, this.onRetry});

  final String? syncedAt;
  final String? error;
  final Future<void> Function()? onRetry;

  @override
  State<SanitySyncChip> createState() => _SanitySyncChipState();
}

class _SanitySyncChipState extends State<SanitySyncChip> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await widget.onRetry!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.error?.isNotEmpty == true;
    final date = DateTime.tryParse(widget.syncedAt ?? '');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final label = failed
        ? 'Sanity failed'
        : date == null
        ? 'Not on Sanity'
        : 'On Sanity · ${date.day} ${months[date.month - 1]}';
    final pill = StatusPill(
      label,
      tone: failed
          ? PillTone.red
          : date == null
          ? PillTone.grey
          : PillTone.green,
    );
    if (!failed) return pill;
    return Tooltip(
      message: widget.error!,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: pill),
          if (widget.onRetry != null)
            TextButton(
              onPressed: _busy ? null : _retry,
              child: Text(_busy ? 'Retrying…' : 'Retry'),
            ),
        ],
      ),
    );
  }
}
