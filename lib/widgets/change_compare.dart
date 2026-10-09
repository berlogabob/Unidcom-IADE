import 'package:flutter/material.dart';

class ChangeCompare extends StatefulWidget {
  final String field;
  final String? now;
  final String proposed;

  const ChangeCompare({
    super.key,
    required this.field,
    required this.now,
    required this.proposed,
  });

  @override
  State<ChangeCompare> createState() => _ChangeCompareState();
}

class _ChangeCompareState extends State<ChangeCompare> {
  bool _showFullText = false;

  @override
  Widget build(BuildContext context) {
    if (widget.field == 'photo_url') {
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Now'),
                if (widget.now != null && widget.now!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Image.network(
                      widget.now!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.person, color: Colors.grey),
                        );
                      },
                    ),
                  )
                else
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.person, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                const Text('Proposed'),
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(
                    widget.proposed,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.person, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final nowText = widget.now ?? '';
      final proposedText = widget.proposed;
      final showToggle = nowText.length > 140 || proposedText.length > 140;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Now: ${nowText.isEmpty ? "empty" : nowText}',
            maxLines: _showFullText ? null : 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Proposed: $proposedText',
            maxLines: _showFullText ? null : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (showToggle)
            TextButton(
              onPressed: () {
                setState(() {
                  _showFullText = !_showFullText;
                });
              },
              child: Text(_showFullText ? 'Hide full text' : 'Show full text'),
            ),
        ],
      );
    }
  }
}
