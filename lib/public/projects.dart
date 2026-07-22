import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isAdmin)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add project'),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _projects,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final projects = snapshot.data ?? [];
                if (projects.isEmpty) {
                  return const Center(child: Text('No projects yet'));
                }
                return ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return ListTile(
                      title: Text(project['title'] as String? ?? 'Untitled'),
                      subtitle: Text(project['status'] as String? ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/projects/${project['id']}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
