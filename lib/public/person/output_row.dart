import 'package:flutter/material.dart';

import '../../widgets/output_row.dart';

class PersonOutputRow extends StatelessWidget {
  const PersonOutputRow({
    super.key,
    required this.author,
    required this.isFeatured,
    required this.onTap,
    this.onToggle,
  });

  final Map<String, dynamic> author;
  final bool isFeatured;
  final ValueChanged<String> onTap;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final output = author['outputs'] as Map<String, dynamic>?;
    if (output == null) return const SizedBox.shrink();
    final id = output['id'] as String;
    return OutputRow(
      title: output['title'] as String? ?? 'Untitled',
      year: output['reporting_year'] as int?,
      type: output['type'] as String?,
      detail: author['role'] as String?,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggle != null)
            IconButton(
              // The tooltip doubles as the UI-test handle: it reaches the web
              // semantics tree as text, and encodes which state we're in.
              tooltip: isFeatured ? 'Remove highlight' : 'Highlight on profile',
              icon: Icon(isFeatured ? Icons.star : Icons.star_border, size: 20),
              onPressed: () => onToggle!(id),
            )
          else if (isFeatured)
            const Tooltip(
              message: 'Highlighted',
              child: Icon(Icons.star, size: 20),
            ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
      onTap: () => onTap(id),
    );
  }
}
