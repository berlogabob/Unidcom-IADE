import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';

class PersonPageScreen extends StatelessWidget {
  const PersonPageScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchPerson(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final person = snapshot.data ?? {};
        final outputAuthors = (person['output_authors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final tags = (person['person_tags'] as List<dynamic>? ?? [])
            .map(
              (tag) =>
                  (tag as Map<String, dynamic>)['tags']
                      as Map<String, dynamic>?,
            )
            .map((tag) => tag?['name'] as String?)
            .whereType<String>()
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              person['preferred_name'] as String? ?? 'Unnamed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (person['membership_type'] != null)
                  Chip(label: Text(person['membership_type'] as String)),
                if (person['status'] != null)
                  Chip(label: Text(person['status'] as String)),
              ],
            ),
            if (person['email'] != null) ...[
              const SizedBox(height: 8),
              Text(person['email'] as String),
            ],
            const SizedBox(height: 24),
            Text('Outputs', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (outputAuthors.isEmpty)
              const Text('No outputs found')
            else
              for (final author in outputAuthors)
                OutputRow(
                  title:
                      (author['outputs'] as Map<String, dynamic>?)?['title']
                          as String? ??
                      'Untitled',
                  year:
                      (author['outputs']
                              as Map<String, dynamic>?)?['reporting_year']
                          as int?,
                  type:
                      (author['outputs'] as Map<String, dynamic>?)?['type']
                          as String?,
                  detail: author['role'] as String?,
                ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Tags', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in tags) Chip(label: Text(tag))],
              ),
            ],
          ],
        );
      },
    );
  }
}
