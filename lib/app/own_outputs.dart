import 'package:flutter/material.dart';

import '../data/output_filters.dart';
import '../data/status_labels.dart';
import '../data/supabase.dart';
import '../data/taxonomy.dart';
import '../public/person/featured_outputs.dart';
import '../public/person/output_row.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';
import '../widgets/search_bar.dart';
import '../widgets/taxonomy_picker.dart';

class OwnOutputsSection extends StatefulWidget {
  const OwnOutputsSection({
    super.key,
    required this.authors,
    required this.featured,
    required this.onToggleFeatured,
    required this.onOpenOutput,
    this.onEditOutput,
    this.loadTaxonomy = fetchOutputTaxonomy,
    this.loadKinds = fetchTaxonomyKinds,
    this.loadQuality = mergeOutputQuality,
  });

  final List<Map<String, dynamic>> authors;
  final List<String> featured;
  final ValueChanged<String> onToggleFeatured;
  final ValueChanged<String> onOpenOutput;
  final ValueChanged<Map<String, dynamic>>? onEditOutput;
  final Future<List<TaxonomyNode>> Function() loadTaxonomy;
  final Future<Map<String, String>> Function() loadKinds;
  final Future<void> Function(List<Map<String, dynamic>>) loadQuality;

  @override
  State<OwnOutputsSection> createState() => _OwnOutputsSectionState();
}

class _OwnOutputsSectionState extends State<OwnOutputsSection> {
  OutputFilter _filter = const OutputFilter();
  OutputGroup _group = OutputGroup.year;
  final _search = TextEditingController();
  final _outputs = <Map<String, dynamic>>[];
  final _authorByOutputId = <String, Map<String, dynamic>>{};
  late final Future<List<TaxonomyNode>> _taxonomy;
  late final Future<Map<String, String>> _kinds;
  late final Future<(List<TaxonomyNode>, Map<String, String>)> _metadata;

  @override
  void initState() {
    super.initState();
    for (final author in widget.authors) {
      final output = author['outputs'];
      if (output is! Map<String, dynamic>) continue;
      final id = output['id']?.toString();
      if (id == null) continue;
      _outputs.add(output);
      _authorByOutputId[id] = author;
    }
    _taxonomy = widget.loadTaxonomy();
    _kinds = widget.loadKinds();
    _metadata = (() async => (await _taxonomy, await _kinds))();
    _loadQuality();
  }

  Future<void> _loadQuality() async {
    await widget.loadQuality(_outputs);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _filter.query.trim().isNotEmpty ||
      _filter.year != null ||
      _filter.category.isNotEmpty ||
      _filter.projectId != null ||
      _filter.review != null ||
      _filter.website != null ||
      _filter.featuredOnly ||
      _filter.kind != null ||
      _filter.view != OutputView.all;

  void _clearFilters() {
    _search.clear();
    setState(() => _filter = const OutputFilter());
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<(List<TaxonomyNode>, Map<String, String>)>(
      future: _metadata,
      builder: (context, metadata) {
        final taxonomy = metadata.$1;
        final kinds = metadata.$2;
        final highlights = orderByFeatured(widget.authors, widget.featured)
            .where((author) => widget.featured.contains(outputIdOf(author)))
            .toList();
        final counts = countByType(_outputs);
        final years = yearsOf(_outputs);
        final projects = projectsOf(_outputs);
        final filtered = filterOutputs(
          _outputs,
          _filter,
          featuredIds: widget.featured.toSet(),
          kindByRoot: kinds,
        );
        final groups = groupOutputs(filtered, _group);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(context, featuredHeader(widget.featured.length)),
            const SizedBox(height: 8),
            if (highlights.isEmpty)
              mutedText(context, 'No featured outputs yet — star outputs below')
            else
              for (final author in highlights)
                PersonOutputRow(
                  author: author,
                  isFeatured: true,
                  onToggle: widget.onToggleFeatured,
                  onTap: widget.onOpenOutput,
                ),
            const SizedBox(height: 24),
            sectionHeader(context, 'Scientific Outputs · ${_outputs.length}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in counts.entries)
                  FilterPill(
                    '${entry.key} ${entry.value}',
                    selected:
                        _filter.category.length == 1 &&
                        _filter.category.single == entry.key,
                    onTap: () => setState(() {
                      _filter = _filter.copyWith(
                        category:
                            _filter.category.length == 1 &&
                                _filter.category.single == entry.key
                            ? <String>[]
                            : [entry.key],
                      );
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: SearchBarField(
                    controller: _search,
                    label: 'Search title or DOI',
                    onChanged: (query) => setState(
                      () => _filter = _filter.copyWith(query: query),
                    ),
                  ),
                ),
                _dropdown<int>(
                  label: 'Year',
                  allLabel: 'All years',
                  value: _filter.year,
                  items: [for (final year in years) (year, '$year')],
                  onChanged: (year) =>
                      setState(() => _filter = _filter.copyWith(year: year)),
                ),
                TaxonomyPicker(
                  key: ValueKey(_filter.category.join('\u0000')),
                  roots: taxonomy,
                  value: _filter.category,
                  onChanged: (category) => setState(
                    () => _filter = _filter.copyWith(category: category),
                  ),
                  labels: const ['Type', 'Subtype', 'Detail', 'Role'],
                ),
                if (projects.isNotEmpty)
                  _dropdown<String>(
                    label: 'Project',
                    allLabel: 'All projects',
                    value: _filter.projectId,
                    items: [
                      for (final project in projects)
                        (project.id, project.title),
                    ],
                    onChanged: (project) => setState(
                      () => _filter = _filter.copyWith(projectId: project),
                    ),
                  ),
                _dropdown<String>(
                  label: 'Activity',
                  value: _filter.kind,
                  items: const [
                    ('publication', 'Publications'),
                    ('activity', 'Activities'),
                  ],
                  onChanged: (kind) =>
                      setState(() => _filter = _filter.copyWith(kind: kind)),
                ),
                _dropdown<String>(
                  label: 'Review',
                  value: _filter.review,
                  items: [
                    ('pending', reviewLabel('pending')),
                    ('approved', reviewLabel('approved')),
                    ('rejected', reviewLabel('rejected')),
                  ],
                  onChanged: (review) => setState(
                    () => _filter = _filter.copyWith(review: review),
                  ),
                ),
                _dropdown<String>(
                  label: 'Website',
                  value: _filter.website,
                  items: [
                    ('published', websiteLabel('published')),
                    ('not_published', websiteLabel('not_published')),
                  ],
                  onChanged: (website) => setState(
                    () => _filter = _filter.copyWith(website: website),
                  ),
                ),
                FilterChip(
                  label: const Text('Featured'),
                  selected: _filter.featuredOnly,
                  onSelected: (selected) => setState(
                    () => _filter = _filter.copyWith(featuredOnly: selected),
                  ),
                ),
                if (_hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (view, label) in const [
                  (OutputView.all, 'All'),
                  (OutputView.recent, 'Recent'),
                  (OutputView.featured, 'Featured'),
                  (OutputView.attention, 'Needs attention'),
                  (OutputView.orcid, 'ORCID'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter.view == view,
                    onSelected: (_) =>
                        setState(() => _filter = _filter.copyWith(view: view)),
                  ),
                SegmentedButton<OutputGroup>(
                  segments: const [
                    ButtonSegment(value: OutputGroup.year, label: Text('Year')),
                    ButtonSegment(value: OutputGroup.type, label: Text('Type')),
                    ButtonSegment(
                      value: OutputGroup.project,
                      label: Text('Project'),
                    ),
                  ],
                  selected: {_group},
                  onSelectionChanged: (selection) =>
                      setState(() => _group = selection.single),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              mutedText(
                context,
                _hasFilters
                    ? 'No outputs match these filters'
                    : 'No outputs yet',
              )
            else
              for (final entry in groups.entries) ...[
                sectionHeader(context, '${entry.key} · ${entry.value.length}'),
                const SizedBox(height: 4),
                for (final output in entry.value)
                  PersonOutputRow(
                    author: _authorByOutputId[output['id'].toString()]!,
                    isFeatured: widget.featured.contains(
                      output['id'].toString(),
                    ),
                    onToggle: widget.onToggleFeatured,
                    onTap: widget.onOpenOutput,
                    onEdit: widget.onEditOutput == null
                        ? null
                        : (_) => widget.onEditOutput!(output),
                    showStates: true,
                  ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

Widget _dropdown<T>({
  required String label,
  String allLabel = 'All',
  required T? value,
  required List<(T, String)> items,
  required ValueChanged<T?> onChanged,
}) => SizedBox(
  width: 180,
  child: DropdownButtonFormField<T>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      DropdownMenuItem(value: null, child: Text(allLabel)),
      for (final (itemValue, itemLabel) in items)
        DropdownMenuItem(value: itemValue, child: Text(itemLabel)),
    ],
    onChanged: onChanged,
  ),
);
