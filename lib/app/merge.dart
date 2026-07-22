import 'dart:async';

import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/search_bar.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  late Future<List<List<Map<String, dynamic>>>> _candidates =
      fetchMergeCandidates();
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();
  final _selected = <String, Map<String, dynamic>>{};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _refreshCandidates() {
    setState(() => _candidates = fetchMergeCandidates());
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _people = fetchPeople(query: query)),
    );
  }

  Future<void> _openMatrix(List<Map<String, dynamic>> people) async {
    final merged = await showDialog<bool>(
      context: context,
      builder: (context) => _MergeMatrixDialog(people: people),
    );
    if (merged != true || !mounted) return;
    setState(() {
      _selected.clear();
      _candidates = fetchMergeCandidates();
      _people = fetchPeople();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Suggested'),
              Tab(text: 'Manual'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [_suggestedTab(), _manualTab()]),
          ),
        ],
      ),
    );
  }

  Widget _suggestedTab() {
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: _candidates,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return const Center(child: Text('No duplicate candidates found'));
        }
        return RefreshIndicator(
          onRefresh: () async => _refreshCandidates(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.length} possible duplicates',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final person in group)
                        Text(person['preferred_name'] as String? ?? 'Unnamed'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => _openMatrix(group),
                          child: const Text('Review & merge'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _manualTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SearchBarField(label: 'Search people', onChanged: _search),
          const SizedBox(height: 12),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final person in _selected.values)
                    InputChip(
                      label: Text(person['preferred_name'] as String? ?? ''),
                      onDeleted: () =>
                          setState(() => _selected.remove(person['id'])),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _selected.length < 2
                  ? null
                  : () => _openMatrix(_selected.values.toList()),
              icon: const Icon(Icons.merge),
              label: const Text('Merge selected'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _people,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final people = snapshot.data ?? [];
                if (people.isEmpty) {
                  return const Center(child: Text('No people found'));
                }
                return ListView.builder(
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final id = person['id'] as String;
                    final selected = _selected.containsKey(id);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(
                        person['preferred_name'] as String? ?? 'Unnamed',
                      ),
                      subtitle: Text(person['email'] as String? ?? ''),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selected[id] = person;
                        } else {
                          _selected.remove(id);
                        }
                      }),
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

class _MergeMatrixDialog extends StatefulWidget {
  const _MergeMatrixDialog({required this.people});

  final List<Map<String, dynamic>> people;

  @override
  State<_MergeMatrixDialog> createState() => _MergeMatrixDialogState();
}

class _MergeMatrixDialogState extends State<_MergeMatrixDialog> {
  static const _fields = [
    ('preferred_name', 'Preferred name'),
    ('legal_name', 'Legal name'),
    ('email', 'Email'),
    ('orcid', 'ORCID'),
    ('ciencia_id', 'Ciencia ID'),
    ('membership_type', 'Membership type'),
    ('status', 'Status'),
    ('bio', 'Bio'),
    ('photo_url', 'Photo URL'),
  ];

  late String _survivorId = widget.people.first['id'] as String;
  late final _choice = {
    for (final field in _fields) field.$1: _defaultChoice(field.$1),
  };
  bool _saving = false;

  String _defaultChoice(String field) {
    final survivor = widget.people.firstWhere((p) => p['id'] == _survivorId);
    if (_value(survivor, field).isNotEmpty) return _survivorId;
    return (widget.people.firstWhere(
          (person) => _value(person, field).isNotEmpty,
          orElse: () => survivor,
        )['id']
        as String);
  }

  String _value(Map<String, dynamic> person, String field) =>
      (person[field] as String?)?.trim() ?? '';

  String _name(Map<String, dynamic> person) =>
      person['preferred_name'] as String? ?? 'Unnamed';

  void _setSurvivor(String id) {
    setState(() {
      _survivorId = id;
      for (final field in _fields) {
        _choice[field.$1] = _defaultChoice(field.$1);
      }
    });
  }

  Future<void> _merge() async {
    final survivor = widget.people.firstWhere((p) => p['id'] == _survivorId);
    final losers = widget.people.where((p) => p['id'] != _survivorId).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge records?'),
        content: Text(
          'This merges ${losers.map(_name).join(', ')} into ${_name(survivor)}. '
          'The others become hidden (reversible). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final fields = {
        for (final field in _fields)
          field.$1: _value(
            widget.people.firstWhere((p) => p['id'] == _choice[field.$1]),
            field.$1,
          ),
      };
      await mergePeople(
        _survivorId,
        losers.map((p) => p['id'] as String).toList(),
        fields,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merged ${widget.people.length} records into ${_name(survivor)}',
          ),
        ),
      );
      Navigator.of(context).pop(true);
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Merge people',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('Field')),
                                for (final person in widget.people)
                                  DataColumn(
                                    label: SizedBox(
                                      width: 180,
                                      child: Text(
                                        _name(person),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                              rows: [
                                DataRow(
                                  cells: [
                                    const DataCell(Text('SURVIVOR')),
                                    for (final person in widget.people)
                                      DataCell(
                                        _RadioChoice(
                                          selected:
                                              person['id'] as String ==
                                              _survivorId,
                                          onTap: _saving
                                              ? null
                                              : () => _setSurvivor(
                                                  person['id'] as String,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                                for (final field in _fields)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(field.$2)),
                                      for (final person in widget.people)
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: _RadioChoice(
                                              selected:
                                                  person['id'] as String ==
                                                  _choice[field.$1],
                                              onTap: _saving
                                                  ? null
                                                  : () => setState(
                                                      () => _choice[field.$1] =
                                                          person['id']
                                                              as String,
                                                    ),
                                              child: Text(
                                                _value(person, field.$1).isEmpty
                                                    ? '-'
                                                    : _value(person, field.$1),
                                                maxLines: field.$1 == 'bio'
                                                    ? 4
                                                    : 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: _ResultPreview(
                        fields: _fields,
                        values: {
                          for (final field in _fields)
                            field.$1: _value(
                              widget.people.firstWhere(
                                (p) => p['id'] == _choice[field.$1],
                              ),
                              field.$1,
                            ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _merge,
                    child: Text(
                      _saving
                          ? 'Merging...'
                          : 'Merge ${widget.people.length} records',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioChoice extends StatelessWidget {
  const _RadioChoice({required this.selected, required this.onTap, this.child});

  final bool selected;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? Theme.of(context).colorScheme.primary : null,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: child == null
            ? icon
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Expanded(child: child!),
                ],
              ),
      ),
    );
  }
}

class _ResultPreview extends StatelessWidget {
  const _ResultPreview({required this.fields, required this.values});

  final List<(String, String)> fields;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Result', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final field in fields) ...[
                Text(field.$2, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  values[field.$1]?.isEmpty ?? true ? '-' : values[field.$1]!,
                  maxLines: field.$1 == 'bio' ? 6 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
