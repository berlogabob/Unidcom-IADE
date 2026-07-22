import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';
import '../widgets/person_card.dart';

class OutputPageScreen extends StatelessWidget {
  const OutputPageScreen({super.key, required this.id});

  final String id;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't open link")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchOutput(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final output = snapshot.data ?? {};
        final authors = (output['output_authors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => (a['author_position'] as int? ?? 0).compareTo(
              b['author_position'] as int? ?? 0,
            ),
          );
        final projects = (output['project_outputs'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(context, output),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Authors · ${authors.length}'),
                const SizedBox(height: 8),
                if (authors.isEmpty)
                  _muted(context, 'No authors listed')
                else
                  for (final author in authors) _authorCard(context, author),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Projects · ${projects.length}'),
                const SizedBox(height: 8),
                if (projects.isEmpty)
                  _muted(context, 'Not linked to a project')
                else
                  for (final link in projects) _projectTile(context, link),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Map<String, dynamic> output) {
    final theme = Theme.of(context);
    final category = (output['category_path'] as String? ?? '').trim();
    final link = resolveOutputUrl(
      output['url'] as String?,
      output['doi'] as String?,
    );
    final chips = [
      output['reporting_year']?.toString(),
      output['type'] as String?,
      output['subtype'] as String?,
      output['approval_status'] as String?,
    ].whereType<String>().where((v) => v.isNotEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              output['title'] as String? ?? 'Untitled',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips)
                  Chip(
                    label: Text(chip),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 8),
              _muted(context, category),
            ],
            if (link != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _open(context, link),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open paper'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _authorCard(BuildContext context, Map<String, dynamic> author) {
    final person = author['people'] as Map<String, dynamic>?;
    if (person == null) return const SizedBox.shrink();
    final personId = person['id'] as String;
    return PersonCard(
      name: person['preferred_name'] as String? ?? 'Unnamed',
      membershipType: person['membership_type'] as String?,
      status: author['role'] as String? ?? person['status'] as String?,
      onTap: () => context.go('/people/$personId'),
    );
  }

  Widget _projectTile(BuildContext context, Map<String, dynamic> link) {
    final project = link['projects'] as Map<String, dynamic>?;
    if (project == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        title: Text(project['title'] as String? ?? 'Untitled'),
        subtitle: Text(project['status'] as String? ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/projects/${project['id']}'),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);

  Widget _muted(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
