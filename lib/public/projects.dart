import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/queue_list.dart';
import 'project_page.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<List<Map<String, dynamic>>> _projects = fetchProjects();

  void _refresh() => setState(() => _projects = fetchProjects());

  Future<void> _add() async {
    final saved = await showProjectEditor(context);
    if (saved) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add project'),
              ),
            ),
          ),
        Expanded(
          child: QueueList(
            future: _projects,
            emptyText: 'No projects yet',
            searchOf: (p) => p['title'] as String? ?? '',
            timeOf: (p) => p['created_at'] as String? ?? '',
            filters: [
              QueueFilter(
                label: 'Status',
                valueOf: (p) => p['status'] as String?,
              ),
            ],
            itemBuilder: (project) => ListTile(
              title: Text(project['title'] as String? ?? 'Untitled'),
              subtitle: Text(project['status'] as String? ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/projects/${project['id']}'),
            ),
          ),
        ),
      ],
    );
  }
}
