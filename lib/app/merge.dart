import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/merge_matrix.dart';
import '../widgets/search_bar.dart';

enum _MergeSection { people, outputs }

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
            _MergeSection.people => _MergeSectionView(
              key: const ValueKey('people'),
              title: 'Merge people',
              searchLabel: 'Search people',
              candidates: fetchMergeCandidates,
              search: (query) => fetchPeople(query: query),
              fields: personMergeFields,
              nameOf: _personName,
              subtitleOf: (p) => p['email'] as String? ?? '',
              onMerge: mergePeople,
            ),
            _MergeSection.outputs => _MergeSectionView(
              key: const ValueKey('outputs'),
              title: 'Merge outputs',
              searchLabel: 'Search outputs',
              candidates: fetchOutputDuplicateGroups,
              search: (query) => fetchOutputs(query: query),
              fields: outputMergeFields,
              nameOf: _outputName,
              subtitleOf: (o) => [
                o['reporting_year']?.toString(),
                o['type'] as String?,
              ].whereType<String>().join(' · '),
              onMerge: mergeOutputs,
            ),
          },
        ),
      ],
    );
  }
}

/// Suggested/Manual merge tabs, parameterized by record type — people and
/// outputs share the exact same interaction.
class _MergeSectionView extends StatefulWidget {
  const _MergeSectionView({
    super.key,
    required this.title,
    required this.searchLabel,
    required this.candidates,
    required this.search,
    required this.fields,
    required this.nameOf,
    required this.subtitleOf,
    required this.onMerge,
  });

  final String title;
  final String searchLabel;
  final Future<List<List<Map<String, dynamic>>>> Function() candidates;
  final Future<List<Map<String, dynamic>>> Function(String query) search;
  final List<MergeFieldSpec> fields;
  final String Function(Map<String, dynamic>) nameOf;
  final String Function(Map<String, dynamic>) subtitleOf;
  final Future<void> Function(
    String survivorId,
    List<String> loserIds,
    Map<String, dynamic> fields,
  )
  onMerge;

  @override
  State<_MergeSectionView> createState() => _MergeSectionViewState();
}

class _MergeSectionViewState extends State<_MergeSectionView> {
  late Future<List<List<Map<String, dynamic>>>> _candidates =
      widget.candidates();
  late Future<List<Map<String, dynamic>>> _rows = widget.search('');
  final _selected = <String, Map<String, dynamic>>{};

  void _refreshCandidates() {
    setState(() => _candidates = widget.candidates());
  }

  void _search(String query) {
    setState(() => _rows = widget.search(query));
  }

  Future<void> _openMatrix(List<Map<String, dynamic>> records) async {
    final merged = await showDialog<bool>(
      context: context,
      builder: (context) => MergeMatrixDialog(
        title: widget.title,
        records: records,
        fields: widget.fields,
        nameOf: widget.nameOf,
        onMerge: widget.onMerge,
      ),
    );
    if (merged != true || !mounted) return;
    setState(() {
      _selected.clear();
      _candidates = widget.candidates();
      _rows = widget.search('');
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
    return AsyncView<List<List<Map<String, dynamic>>>>(
      future: _candidates,
      builder: (context, groups) {
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
                      for (final record in group) Text(widget.nameOf(record)),
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
          SearchBarField(label: widget.searchLabel, onChanged: _search),
          const SizedBox(height: 12),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final record in _selected.values)
                    InputChip(
                      label: Text(widget.nameOf(record)),
                      onDeleted: () =>
                          setState(() => _selected.remove(record['id'])),
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
            child: AsyncView<List<Map<String, dynamic>>>(
              future: _rows,
              builder: (context, rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No results'));
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final record = rows[index];
                    final id = record['id'] as String;
                    final selected = _selected.containsKey(id);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(widget.nameOf(record)),
                      subtitle: Text(widget.subtitleOf(record)),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selected[id] = record;
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
