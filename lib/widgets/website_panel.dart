import 'package:flutter/material.dart';

import '../data/status_labels.dart';
import 'detail_scaffold.dart';
import 'panels.dart';

class WebsitePanel extends StatefulWidget {
  const WebsitePanel({super.key, required this.output, required this.onChange});

  final Map<String, dynamic> output;
  final Future<void> Function(String id, String status) onChange;

  @override
  State<WebsitePanel> createState() => _WebsitePanelState();
}

class _WebsitePanelState extends State<WebsitePanel> {
  late String? _status = widget.output['website_status'] as String?;
  bool _busy = false;

  Future<void> _change(String status) async {
    setState(() => _busy = true);
    try {
      await widget.onChange(widget.output['id'] as String, status);
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
      });
      showSnack(context, 'Website: ${websiteLabel(status)}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final published = _status == 'published';
    final approved = widget.output['approval_status'] == 'approved';
    return Panel(
      title: 'Website',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            'Website · ${websiteLabel(_status)}',
            tone: published
                ? PillTone.teal
                : _status == 'error'
                ? PillTone.red
                : PillTone.grey,
          ),
          const SizedBox(height: 12),
          if (!approved)
            mutedText(
              context,
              'Approve the output first; publication is a separate decision.',
            )
          else if (published)
            OutlinedButton(
              onPressed: _busy ? null : () => _change('not_published'),
              child: const Text('Unpublish'),
            )
          else
            FilledButton(
              onPressed: _busy ? null : () => _change('published'),
              child: const Text('Publish to website'),
            ),
          if (published) ...[
            const SizedBox(height: 8),
            mutedText(
              context,
              'Appears on the public site at the next nightly build.',
            ),
          ],
        ],
      ),
    );
  }
}
