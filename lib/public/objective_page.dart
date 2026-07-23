import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';

class ObjectivePageScreen extends StatefulWidget {
  const ObjectivePageScreen({super.key, required this.id});

  final String id;

  @override
  State<ObjectivePageScreen> createState() => _ObjectivePageScreenState();
}

class _ObjectivePageScreenState extends State<ObjectivePageScreen> {
  late Future<Map<String, dynamic>> _objective = fetchObjective(widget.id);

  void _refresh() => setState(() => _objective = fetchObjective(widget.id));

  Future<void> _edit(Map<String, dynamic> objective) async {
    if (await showEntityEditor(
      context,
      title: 'objective',
      entity: objective,
      fields: const [
        EntityField('code', 'Code'),
        EntityField('name', 'Name'),
        EntityField('description', 'Description', maxLines: 4),
        EntityField('kpis', 'KPIs', maxLines: 3),
        EntityField('source', 'Source'),
      ],
      create: createObjective,
      update: updateObjective,
    )) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _objective,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final objective = snapshot.data ?? {};
        final admin = isAdmin;
        final clusters = embedded(objective, 'objective_clusters', 'clusters');
        final labs = embedded(objective, 'lab_objectives', 'labs');
        final projects = embedded(objective, 'project_objectives', 'projects');
        final kpis = (objective['kpis'] as String? ?? '').trim();

        return DetailBody(
          children: [
            EntityHeaderCard(
              code: objective['code'] as String?,
              title: objective['name'] as String? ?? 'Unnamed objective',
              body: objective['description'] as String?,
              onEdit: admin ? () => _edit(objective) : null,
            ),
            if (kpis.isNotEmpty) ...[
              const SizedBox(height: 24),
              sectionHeader(context, 'KPIs', null, ''),
              const SizedBox(height: 8),
              Text(kpis),
            ],
            const SizedBox(height: 24),
            linkChipsSection(
              context,
              title: 'Clusters',
              items: clusters,
              basePath: '/clusters',
              admin: false,
            ),
            const SizedBox(height: 16),
            linkChipsSection(
              context,
              title: 'Labs',
              items: labs,
              basePath: '/labs',
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
