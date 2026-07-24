import 'dart:async';

import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/merge_matrix.dart';
import '../widgets/search_bar.dart';

enum _MergeSection { people, outputs }

const _personFields = <MergeFieldSpec>[
  (key: 'preferred_name', label: 'Preferred name', tall: false),
  (key: 'legal_name', label: 'Legal name', tall: false),
  (key: 'email', label: 'Email', tall: false),
  (key: 'orcid', label: 'ORCID', tall: false),
  (key: 'ciencia_id', label: 'Ciencia ID', tall: false),
  (key: 'membership_type', label: 'Membership type', tall: false),
  (key: 'status', label: 'Status', tall: false),
  (key: 'bio', label: 'Bio', tall: true),
  (key: 'photo_url', label: 'Photo URL', tall: false),
];

const _outputFields = <MergeFieldSpec>[
  (key: 'title', label: 'Title', tall: true),
  (key: 'doi', label: 'DOI', tall: false),
  (key: 'url', label: 'URL', tall: false),
  (key: 'type', label: 'Type', tall: false),
  (key: 'subtype', label: 'Subtype', tall: false),
  (key: 'reporting_year', label: 'Reporting year', tall: false),
  (key: 'macro_type', label: 'Macro type', tall: false),
  (key: 'output_status', label: 'Output status', tall: false),
  (key: 'full_reference', label: 'Full reference', tall: true),
];

String _personName(Map<String, dynamic> person) =>
    person['preferred_name'] as String? ?? 'Unnamed';

String _outputName(Map<String, dynamic> output) =>
    output['title'] as String? ?? 'Untitled';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  _MergeSection _section = _MergeSection.people;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<_MergeSection>(
            segments: const [
              ButtonSegment(
                value: _MergeSection.people,
                label: Text('People'),
                icon: Icon(Icons.people_outline),
              ),
              ButtonSegment(
                value: _MergeSection.outputs,
                label: Text('Outputs'),
                icon: Icon(Icons.article_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (selection) =>
                setState(() => _section = selection.first),
          ),
        ),
        Expanded(
          child: switch (_section) {
            _MergeSection.people => const _PeopleMergeSection(),
            _MergeSection.outputs => const _OutputMergeSection(),
          },
        ),
      ],
    );
  }
}

class _PeopleMergeSection extends StatefulWidget {
  const _PeopleMergeSection();

  @override
  State<_PeopleMergeSection> createState() => _PeopleMergeSectionState();
}

class _PeopleMergeSectionState extends State<_PeopleMergeSection> {
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
      builder: (context) => MergeMatrixDialog(
        title: 'Merge people',
        records: people,
        fields: _personFields,
        nameOf: _personName,
        onMerge: mergePeople,
      ),
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
                      for (final person in group) Text(_personName(person)),
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
                      label: Text(_personName(person)),
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
                      title: Text(_personName(person)),
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

class _OutputMergeSection extends StatefulWidget {
  const _OutputMergeSection();

  @override
  State<_OutputMergeSection> createState() => _OutputMergeSectionState();
}

class _OutputMergeSectionState extends State<_OutputMergeSection> {
  late Future<List<List<Map<String, dynamic>>>> _candidates =
      fetchOutputDuplicateGroups();
  late Future<List<Map<String, dynamic>>> _outputs = fetchOutputs();
  final _selected = <String, Map<String, dynamic>>{};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _refreshCandidates() {
    setState(() => _candidates = fetchOutputDuplicateGroups());
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _outputs = fetchOutputs(query: query)),
    );
  }

  Future<void> _openMatrix(List<Map<String, dynamic>> outputs) async {
    final merged = await showDialog<bool>(
      context: context,
      builder: (context) => MergeMatrixDialog(
        title: 'Merge outputs',
        records: outputs,
        fields: _outputFields,
        nameOf: _outputName,
        onMerge: mergeOutputs,
      ),
    );
    if (merged != true || !mounted) return;
    setState(() {
      _selected.clear();
      _candidates = fetchOutputDuplicateGroups();
      _outputs = fetchOutputs();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      for (final output in group) Text(_outputName(output)),
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
          SearchBarField(label: 'Search outputs', onChanged: _search),
          const SizedBox(height: 12),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final output in _selected.values)
                    InputChip(
                      label: Text(_outputName(output)),
                      onDeleted: () =>
                          setState(() => _selected.remove(output['id'])),
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
              future: _outputs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final outputs = snapshot.data ?? [];
                if (outputs.isEmpty) {
                  return const Center(child: Text('No outputs found'));
                }
                return ListView.builder(
                  itemCount: outputs.length,
                  itemBuilder: (context, index) {
                    final output = outputs[index];
                    final id = output['id'] as String;
                    final selected = _selected.containsKey(id);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(_outputName(output)),
                      subtitle: Text(
                        [
                          output['reporting_year']?.toString(),
                          output['type'] as String?,
                        ].whereType<String>().join(' · '),
                      ),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selected[id] = output;
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
