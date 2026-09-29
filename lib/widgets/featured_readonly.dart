import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Rui 25 Sep (B3·8): featured outputs on My Profile, read only; chosen in Scientific Outputs.
class FeaturedReadOnly extends StatelessWidget {
  const FeaturedReadOnly({super.key, required this.featured, this.max = 5});

  final List<Map<String, dynamic>> featured;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured outputs (${featured.length}/$max)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (featured.isEmpty)
          Text('Choose up to 5 publications to feature in Scientific Outputs.')
        else
          ...featured
              .take(max)
              .map(
                (row) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(row['title'] as String? ?? 'Untitled'),
                  subtitle: Text(
                    [
                      row['type'],
                      row['reporting_year'],
                    ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                  ),
                ),
              ),
        TextButton(
          onPressed: () => context.go('/app/outputs?view=featured'),
          child: const Text('Manage in Scientific Outputs →'),
        ),
      ],
    );
  }
}
