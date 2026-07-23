import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/person_card.dart';
import '../widgets/search_picker.dart';

class LabPageScreen extends StatefulWidget {
  const LabPageScreen({super.key, required this.id});

  final String id;

  @override
  State<LabPageScreen> createState() => _LabPageScreenState();
}

class _LabPageScreenState extends State<LabPageScreen> {
  late Future<Map<String, dynamic>> _lab = fetchLab(widget.id);

  void _refresh() => setState(() => _lab = fetchLab(widget.id));

  Future<void> _edit(Map<String, dynamic> lab) async {
    if (await showEntityEditor(
      context,
      title: 'lab',
      entity: lab,
      fields: const [
        EntityField('code', 'Code'),
        EntityField('name', 'Name'),
        EntityField('overview', 'Overview', maxLines: 4),
        EntityField('notes', 'Notes', maxLines: 3),
      ],
      create: createLab,
      update: updateLab,
    )) {
      _refresh();
    }
  }

  Future<void> _addMember() async {
    final person = await showSearchPicker(
      context,
      title: 'Add member',
      search: (q) => fetchPeople(query: q),
      label: (p) => p['preferred_name'] as String? ?? 'Unnamed',
      subtitle: (p) => p['email'] as String? ?? '',
    );
    if (person == null) return;
    await addLabMember(widget.id, person['id'] as String);
    _refresh();
  }

  Future<void> _linkObjective() async {
    final objective = await showSearchPicker(
      context,
      title: 'Link objective',
      search: (q) async {
        final all = await fetchObjectives();
        if (q.trim().isEmpty) return all;
        final needle = q.toLowerCase();
        return all
            .where((o) => (o['name'] as String? ?? '').toLowerCase().contains(needle))
            .toList();
      },
      label: (o) => o['name'] as String? ?? o['code'] as String? ?? 'Unnamed',
    );
    if (objective == null) return;
    await linkLabObjective(widget.id, objective['id'] as String);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _lab,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final lab = snapshot.data ?? {};
        final admin = isAdmin;
        final members = (lab['lab_members'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final objectives = embedded(lab, 'lab_objectives', 'objectives');
        final projects = embedded(lab, 'project_labs', 'projects');

        return DetailBody(
          children: [
            EntityHeaderCard(
              code: lab['code'] as String?,
              title: lab['name'] as String? ?? 'Unnamed lab',
              body: lab['overview'] as String?,
              onEdit: admin ? () => _edit(lab) : null,
            ),
            const SizedBox(height: 24),
            sectionHeader(
              context,
              'Members · ${members.length}',
              admin ? _addMember : null,
              'Add member',
            ),
            const SizedBox(height: 8),
            if (members.isEmpty)
              mutedText(context, 'No members yet')
            else
              for (final member in members) _memberRow(member, admin),
            const SizedBox(height: 24),
            linkChipsSection(
              context,
              title: 'Objectives',
              items: objectives,
              basePath: '/objectives',
              admin: admin,
              onAdd: _linkObjective,
              onRemove: (id) async {
                await unlinkLabObjective(widget.id, id);
                _refresh();
              },
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

  Widget _memberRow(Map<String, dynamic> member, bool admin) {
    final person = member['people'] as Map<String, dynamic>?;
    if (person == null) return const SizedBox.shrink();
    final personId = person['id'] as String;
    final isCoordinator = member['is_coordinator'] as bool? ?? false;
    return Row(
      children: [
        Expanded(
          child: PersonCard(
            name: person['preferred_name'] as String? ?? 'Unnamed',
            membershipType: person['membership_type'] as String?,
            status: isCoordinator
                ? 'Coordinator'
                : person['status'] as String?,
            onTap: () => context.go('/people/$personId'),
          ),
        ),
        if (admin) ...[
          IconButton(
            tooltip: isCoordinator ? 'Unset coordinator' : 'Set coordinator',
            icon: Icon(isCoordinator ? Icons.star : Icons.star_border),
            onPressed: () async {
              await addLabMember(
                widget.id,
                personId,
                isCoordinator: !isCoordinator,
              );
              _refresh();
            },
          ),
          IconButton(
            tooltip: 'Remove member',
            icon: const Icon(Icons.close),
            onPressed: () async {
              await removeLabMember(widget.id, personId);
              _refresh();
            },
          ),
        ],
      ],
    );
  }
}
