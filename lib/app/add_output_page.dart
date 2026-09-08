import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../public/output_page.dart';
import '../widgets/detail_scaffold.dart';

/// Add Scientific Output IA leaf — its own URL for the same dialog My
/// Outputs opens with its "+ Add output" button, so the leaf doesn't need
/// to duplicate OutputEditDialog's form.
class AddOutputPage extends StatelessWidget {
  const AddOutputPage({super.key});

  Future<void> _add(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const OutputEditDialog(asResearcher: true),
    );
    if (saved ?? false) {
      if (context.mounted) context.go('/app/outputs');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailBody(
      children: [
        const Text(
          'Add a publication, conference paper, or other scientific output '
          'you authored. It is saved as pending until UNIDCOM reviews it.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: const Text('Add output'),
        ),
      ],
    );
  }
}
