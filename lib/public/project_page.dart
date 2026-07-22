import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';
import '../widgets/person_card.dart';

class ProjectPageScreen extends StatelessWidget {
  const ProjectPageScreen({super.key, required this.id});

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
      future: fetchProject(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final project = snapshot.data ?? {};
        final members = (project['project_members'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final outputs = (project['project_outputs'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(context, project),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Members · ${members.length}'),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  _muted(context, 'No members yet')
                else
                  for (final member in members) _memberCard(context, member),
                const SizedBox(height: 24),
                _sectionTitle(context, 'Outputs · ${outputs.length}'),
                const SizedBox(height: 8),
                if (outputs.isEmpty)
                  _muted(context, 'No outputs linked')
                else
                  for (final link in outputs) _outputRow(context, link),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Map<String, dynamic> project) {
    final theme = Theme.of(context);
    final acronym = (project['acronym'] as String? ?? '').trim();
    final description = (project['description'] as String? ?? '').trim();
    final dates = [project['start_date'], project['end_date']]
        .map((d) => (d as String?)?.trim())
        .where((d) => d != null && d.isNotEmpty)
        .join(' – ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project['title'] as String? ?? 'Untitled',
              style: theme.textTheme.headlineSmall,
            ),
            if (acronym.isNotEmpty)
              Text(
                acronym,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (project['status'] != null)
                  Chip(
                    label: Text(project['status'] as String),
                    visualDensity: VisualDensity.compact,
                  ),
                if (dates.isNotEmpty) _muted(context, dates),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberCard(BuildContext context, Map<String, dynamic> member) {
    final person = member['people'] as Map<String, dynamic>?;
    if (person == null) return const SizedBox.shrink();
    return PersonCard(
      name: person['preferred_name'] as String? ?? 'Unnamed',
      membershipType: person['membership_type'] as String?,
      status: member['role'] as String? ?? person['status'] as String?,
      onTap: () => context.go('/people/${person['id']}'),
    );
  }

  Widget _outputRow(BuildContext context, Map<String, dynamic> link) {
    final output = link['outputs'] as Map<String, dynamic>?;
    if (output == null) return const SizedBox.shrink();
    final url = resolveOutputUrl(
      output['url'] as String?,
      output['doi'] as String?,
    );
    return OutputRow(
      title: output['title'] as String? ?? 'Untitled',
      year: output['reporting_year'] as int?,
      type: output['type'] as String?,
      trailing: url == null ? null : const Icon(Icons.open_in_new, size: 18),
      onTap: url == null ? null : () => _open(context, url),
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
