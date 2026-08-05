import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/panels.dart';
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
              QueueFilter(
                label: 'Category',
                valueOf: (p) => p['category'] as String?,
              ),
              QueueFilter(
                label: 'Funding',
                valueOf: (p) => p['funding'] as String?,
              ),
            ],
            itemBuilder: (project) {
              final status = (project['status'] as String? ?? '').trim();
              final meta = [project['category'], project['funding']]
                  .map((v) => (v as String?)?.trim())
                  .where((v) => v != null && v.isNotEmpty)
                  .join(' · ');
              return Panel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  tileColor: AppColors.cardBg,
                  shape: const Border(
                    bottom: BorderSide(color: AppColors.cardBorder),
                  ),
                  titleTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  subtitleTextStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  title: Text(project['title'] as String? ?? 'Untitled'),
                  subtitle: meta.isEmpty ? null : Text(meta),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status.isNotEmpty) ...[
                        StatusPill(
                          status,
                          tone: switch (status) {
                            'active' => PillTone.teal,
                            'planned' => PillTone.amber,
                            _ => PillTone.grey,
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  onTap: () => context.go('/projects/${project['id']}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
