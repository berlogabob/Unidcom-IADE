import 'package:flutter/material.dart';

/// A radio-style cell for pick matrices (merge people, ORCID update). Shows a
/// filled/hollow radio, optionally with a value label beside it.
class RadioChoice extends StatelessWidget {
  const RadioChoice({
    super.key,
    required this.selected,
    required this.onTap,
    this.child,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? Theme.of(context).colorScheme.primary : null,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: child == null
            ? icon
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Expanded(child: child!),
                ],
              ),
      ),
    );
  }
}

/// Live "Result" side panel listing the currently-chosen value per field.
class ResultPreview extends StatelessWidget {
  const ResultPreview({
    super.key,
    required this.fields,
    required this.values,
    this.tallField,
  });

  final List<(String, String)> fields;
  final Map<String, String> values;

  /// Field key rendered with more lines (e.g. 'bio').
  final String? tallField;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Result', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final field in fields) ...[
                Text(field.$2, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  values[field.$1]?.isEmpty ?? true ? '-' : values[field.$1]!,
                  maxLines: field.$1 == tallField ? 6 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
