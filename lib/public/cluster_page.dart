import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';

class ClusterPageScreen extends StatefulWidget {
  const ClusterPageScreen({super.key, required this.id});

  final String id;

  @override
  State<ClusterPageScreen> createState() => _ClusterPageScreenState();
}

class _ClusterPageScreenState extends State<ClusterPageScreen> {
  late Future<Map<String, dynamic>> _cluster = fetchCluster(widget.id);

  void _refresh() => setState(() => _cluster = fetchCluster(widget.id));

  Future<void> _edit(Map<String, dynamic> cluster) async {
    if (await showEntityEditor(
      context,
      title: 'cluster',
      entity: cluster,
      fields: const [
        EntityField('code', 'Code'),
        EntityField('name', 'Name'),
        EntityField('concern', 'Concern', maxLines: 2),
        EntityField('notes', 'Notes', maxLines: 4),
      ],
      create: createCluster,
      update: updateCluster,
    )) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _cluster,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final cluster = snapshot.data ?? {};
        final admin = isAdmin;
        final objectives =
            embedded(cluster, 'objective_clusters', 'objectives');
        final projects = embedded(cluster, 'project_clusters', 'projects');

        return DetailBody(
          children: [
            EntityHeaderCard(
              code: cluster['code'] as String?,
              title: cluster['name'] as String? ?? 'Unnamed cluster',
              subtitle: cluster['concern'] as String?,
              body: cluster['notes'] as String?,
              onEdit: admin ? () => _edit(cluster) : null,
            ),
            const SizedBox(height: 24),
            linkChipsSection(
              context,
              title: 'Objectives',
              items: objectives,
              basePath: '/objectives',
              admin: false,
            ),
            const SizedBox(height: 16),
            sectionHeader(context, 'Projects · ${projects.length}', null, ''),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              mutedText(context, 'No projects yet')
            else
              for (final project in projects)
                Card(
                  child: ListTile(
                    title: Text(project['title'] as String? ?? 'Untitled'),
                    subtitle: Text(project['status'] as String? ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/projects/${project['id']}'),
                  ),
                ),
          ],
        );
      },
    );
  }
}
