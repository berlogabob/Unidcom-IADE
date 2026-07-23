import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';
import '../widgets/person_card.dart';
import '../widgets/search_picker.dart';

Future<bool> showProjectEditor(
  BuildContext context, {
  Map<String, dynamic>? project,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => _ProjectEditDialog(project: project),
      ) ??
      false;
}

class ProjectPageScreen extends StatefulWidget {
  const ProjectPageScreen({super.key, required this.id});

  final String id;

  @override
  State<ProjectPageScreen> createState() => _ProjectPageScreenState();
}

class _ProjectPageScreenState extends State<ProjectPageScreen> {
  late Future<Map<String, dynamic>> _project = fetchProject(widget.id);

  void _refresh() => setState(() => _project = fetchProject(widget.id));

  Future<void> _edit(Map<String, dynamic> project) async {
    final saved = await showProjectEditor(context, project: project);
    if (saved) _refresh();
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
    await addProjectMember(widget.id, person['id'] as String);
    _refresh();
  }

  Future<void> _linkOutput() async {
    final output = await showSearchPicker(
      context,
      title: 'Link output',
      search: (q) => fetchOutputs(query: q),
      label: (o) => o['title'] as String? ?? 'Untitled',
      subtitle: (o) => [
        o['reporting_year'],
        o['type'],
      ].where((v) => v != null).join(' · '),
    );
    if (output == null) return;
    await linkProjectOutput(widget.id, output['id'] as String);
    _refresh();
  }

  Future<void> _linkEntity({
    required String title,
    required Future<List<Map<String, dynamic>>> Function() fetch,
    required Future<void> Function(String projectId, String id) link,
  }) async {
    final chosen = await showSearchPicker(
      context,
      title: title,
      search: (q) async {
        final all = await fetch();
        if (q.trim().isEmpty) return all;
        final needle = q.toLowerCase();
        return all
            .where((e) => (e['name'] as String? ?? '').toLowerCase().contains(needle))
            .toList();
      },
      label: (e) => e['name'] as String? ?? e['code'] as String? ?? 'Unnamed',
    );
    if (chosen == null) return;
    await link(widget.id, chosen['id'] as String);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _project,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final project = snapshot.data ?? {};
        final admin = isAdmin;
        final members = (project['project_members'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final outputs = (project['project_outputs'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final clusters = _embedded(project, 'project_clusters', 'clusters');
        final labs = _embedded(project, 'project_labs', 'labs');
        final objectives =
            _embedded(project, 'project_objectives', 'objectives');

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(project, admin),
                const SizedBox(height: 24),
                _linkChips(
                  'Clusters',
                  clusters,
                  '/clusters',
                  admin,
                  onAdd: () => _linkEntity(
                    title: 'Link cluster',
                    fetch: fetchClusters,
                    link: linkProjectCluster,
                  ),
                  onRemove: (id) async {
                    await unlinkProjectCluster(widget.id, id);
                    _refresh();
                  },
                ),
                _linkChips(
                  'Labs',
                  labs,
                  '/labs',
                  admin,
                  onAdd: () => _linkEntity(
                    title: 'Link lab',
                    fetch: fetchLabs,
                    link: linkProjectLab,
                  ),
                  onRemove: (id) async {
                    await unlinkProjectLab(widget.id, id);
                    _refresh();
                  },
                ),
                _linkChips(
                  'Objectives',
                  objectives,
                  '/objectives',
                  admin,
                  onAdd: () => _linkEntity(
                    title: 'Link objective',
                    fetch: fetchObjectives,
                    link: linkProjectObjective,
                  ),
                  onRemove: (id) async {
                    await unlinkProjectObjective(widget.id, id);
                    _refresh();
                  },
                ),
                const SizedBox(height: 24),
                _sectionHeader(
                  'Members · ${members.length}',
                  admin ? _addMember : null,
                  'Add member',
                ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  _muted('No members yet')
                else
                  for (final member in members) _memberRow(member, admin),
                const SizedBox(height: 24),
                _sectionHeader(
                  'Outputs · ${outputs.length}',
                  admin ? _linkOutput : null,
                  'Link output',
                ),
                const SizedBox(height: 8),
                if (outputs.isEmpty)
                  _muted('No outputs linked')
                else
                  for (final link in outputs) _outputRow(link, admin),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Map<String, dynamic> project, bool admin) {
    final theme = Theme.of(context);
    final acronym = (project['acronym'] as String? ?? '').trim();
    final description = (project['description'] as String? ?? '').trim();
    final category = (project['category'] as String? ?? '').trim();
    final funding = (project['funding'] as String? ?? '').trim();
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
                if (category.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.category_outlined, size: 16),
                    label: Text(category),
                    visualDensity: VisualDensity.compact,
                  ),
                if (funding.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.euro, size: 16),
                    label: Text(funding),
                    visualDensity: VisualDensity.compact,
                  ),
                if (dates.isNotEmpty) _muted(dates),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description),
            ],
            if (admin) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _edit(project),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> member, bool admin) {
    final person = member['people'] as Map<String, dynamic>?;
    if (person == null) return const SizedBox.shrink();
    final personId = person['id'] as String;
    return Row(
      children: [
        Expanded(
          child: PersonCard(
            name: person['preferred_name'] as String? ?? 'Unnamed',
            membershipType: person['membership_type'] as String?,
            status: member['role'] as String? ?? person['status'] as String?,
            onTap: () => context.go('/people/$personId'),
          ),
        ),
        if (admin)
          IconButton(
            tooltip: 'Remove member',
            icon: const Icon(Icons.close),
            onPressed: () async {
              await removeProjectMember(widget.id, personId);
              _refresh();
            },
          ),
      ],
    );
  }

  Widget _outputRow(Map<String, dynamic> link, bool admin) {
    final output = link['outputs'] as Map<String, dynamic>?;
    if (output == null) return const SizedBox.shrink();
    final outputId = output['id'] as String;
    return Row(
      children: [
        Expanded(
          child: OutputRow(
            title: output['title'] as String? ?? 'Untitled',
            year: output['reporting_year'] as int?,
            type: output['type'] as String?,
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.go('/outputs/$outputId'),
          ),
        ),
        if (admin)
          IconButton(
            tooltip: 'Unlink output',
            icon: const Icon(Icons.close),
            onPressed: () async {
              await unlinkProjectOutput(widget.id, outputId);
              _refresh();
            },
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _embedded(
    Map<String, dynamic> row,
    String join,
    String embed,
  ) {
    return (row[join] as List<dynamic>? ?? [])
        .map((e) => (e as Map<String, dynamic>)[embed] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Widget _linkChips(
    String title,
    List<Map<String, dynamic>> items,
    String basePath,
    bool admin, {
    required VoidCallback onAdd,
    required Future<void> Function(String id) onRemove,
  }) {
    if (items.isEmpty && !admin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, admin ? onAdd : null, 'Add'),
          const SizedBox(height: 8),
          if (items.isEmpty)
            _muted('None linked')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  InputChip(
                    label: Tooltip(
                      message: item['name'] as String? ?? '',
                      child: Text(
                        item['code'] as String? ??
                            item['name'] as String? ??
                            '—',
                      ),
                    ),
                    onPressed: () => context.go('$basePath/${item['id']}'),
                    onDeleted: admin
                        ? () => onRemove(item['id'] as String)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, VoidCallback? onAdd, String addLabel) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
      ],
    );
  }

  Widget _muted(String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ProjectEditDialog extends StatefulWidget {
  const _ProjectEditDialog({this.project});

  final Map<String, dynamic>? project;

  @override
  State<_ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<_ProjectEditDialog> {
  static const _statuses = ['planned', 'active', 'completed', 'cancelled'];
  static const _approvalStatuses = ['pending', 'approved', 'rejected'];
  static const _categories = [
    'Labs',
    'Operação',
    'Eventos',
    'Estratégia',
    'Outputs',
  ];

  bool get _creating => widget.project?['id'] == null;

  late final _title = _controller('title');
  late final _acronym = _controller('acronym');
  late final _description = _controller('description');
  late final _startDate = _controller('start_date');
  late final _endDate = _controller('end_date');
  late final _budget = _controller('total_budget');
  late final _funding = _controller('funding');
  late String? _category = widget.project?['category'] as String?;
  late final _currency = TextEditingController(
    text: widget.project?['currency'] as String? ?? 'EUR',
  );
  late String _status =
      widget.project?['status'] as String? ?? _statuses[1]; // active
  late String _approvalStatus =
      widget.project?['approval_status'] as String? ?? _approvalStatuses.first;
  late bool _publicVisibility =
      widget.project?['public_visibility'] as bool? ?? false;
  bool _saving = false;

  TextEditingController _controller(String key) => TextEditingController(
    text: widget.project?[key]?.toString() ?? '',
  );

  @override
  void dispose() {
    for (final c in [
      _title,
      _acronym,
      _description,
      _startDate,
      _endDate,
      _budget,
      _currency,
      _funding,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = {
        'title': _title.text.trim(),
        'acronym': _text(_acronym),
        'description': _text(_description),
        'start_date': _text(_startDate),
        'end_date': _text(_endDate),
        'total_budget': _budget.text.trim().isEmpty
            ? null
            : num.tryParse(_budget.text.trim()),
        'currency': _text(_currency) ?? 'EUR',
        'funding': _text(_funding),
        'category': _category,
        'status': _status,
        'approval_status': _approvalStatus,
        'public_visibility': _publicVisibility,
      };
      if (_creating) {
        await createProject(fields);
      } else {
        await updateProject(widget.project!['id'] as String, fields);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_creating ? 'Add project' : 'Edit project'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_title, 'Title'),
              _field(_acronym, 'Acronym'),
              _field(_description, 'Description', maxLines: 4),
              _field(_startDate, 'Start date (YYYY-MM-DD)'),
              _field(_endDate, 'End date (YYYY-MM-DD)'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _budget,
                      'Total budget',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 120, child: _field(_currency, 'Currency')),
                ],
              ),
              _field(_funding, 'Funding (e.g. FCT, Interno, Outro)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String?>(
                  initialValue: _categories.contains(_category)
                      ? _category
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final item in _categories)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              _dropdown(
                'Status',
                _status,
                _statuses,
                (v) => setState(() => _status = v!),
              ),
              _dropdown(
                'Approval status',
                _approvalStatus,
                _approvalStatuses,
                (v) => setState(() => _approvalStatus = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Public visibility'),
                value: _publicVisibility,
                onChanged: (v) => setState(() => _publicVisibility = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : values.first,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
