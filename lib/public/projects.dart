import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchProjects(),
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
          padding: const EdgeInsets.all(16),
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
    );
  }
}
