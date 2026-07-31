import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/timeline_section.dart';

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
    return AsyncView<Map<String, dynamic>>(
      future: _objective,
      builder: (context, objective) {
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
              sectionHeader(context, 'KPIs'),
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
            TimelineSection(
              title: 'Projects · ${projects.length}',
              items: projects,
              yearOf: projectStartYear,
              groupOf: (p) => p['status'] as String? ?? '',
              groupLabel: 'By status',
              itemBuilder: (p) => ProjectTile(project: p),
              emptyText: 'No projects yet',
            ),
          ],
        );
      },
    );
  }
}
