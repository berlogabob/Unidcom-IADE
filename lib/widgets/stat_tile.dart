import 'package:flutter/material.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(label, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
