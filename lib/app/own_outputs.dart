import 'package:flutter/material.dart';

import '../data/output_filters.dart';
import '../data/status_labels.dart';
import '../data/supabase.dart';
import '../data/taxonomy.dart';
import '../data/features.dart';
import '../public/person/featured_outputs.dart';
import '../public/person/output_row.dart';
import '../theme/tokens.dart';
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
    this.orcidPanel,
    this.newOrcidPublications = 0,
    this.onReviewOrcid,
    this.loadTaxonomy = fetchOutputTaxonomy,
    this.loadKinds = fetchTaxonomyKinds,
    this.loadQuality = mergeOutputQuality,
    this.submitOutputs = submitMyOutputs,
  });

  final List<Map<String, dynamic>> authors;
  final List<String> featured;
  final ValueChanged<String> onToggleFeatured;
  final ValueChanged<String> onOpenOutput;
  final ValueChanged<Map<String, dynamic>>? onEditOutput;
  final Widget? orcidPanel;
  final int newOrcidPublications;
  final VoidCallback? onReviewOrcid;
  final Future<List<TaxonomyNode>> Function() loadTaxonomy;
  final Future<Map<String, String>> Function() loadKinds;
  final Future<void> Function(List<Map<String, dynamic>>) loadQuality;
  final Future<int> Function(List<String>) submitOutputs;

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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (!v2) _filter = const OutputFilter(kind: 'publication');
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

  Future<void> _submitOutputs() async {
    final outputsToValidate = _outputs
        .where(
          (output) =>
              output['approval_status'] == 'to_validate' ||
              output['approval_status'] == 'rejected',
        )
        .toList();
    if (outputsToValidate.isEmpty || _submitting) return;

    final ids = outputsToValidate
        .map((output) => output['id'].toString())
        .toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit ${ids.length} outputs for UNIDCOM review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;
    setState(() => _submitting = true);

    try {
      await widget.submitOutputs(ids);

      if (!mounted) return;
      for (final output in _outputs) {
        if (ids.contains(output['id'].toString())) {
          output['approval_status'] = 'pending';
        }
      }

      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submitted ${ids.length} outputs for review')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting outputs: ${e.toString()}')),
      );
    }
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
        final tabRows = filterOutputs(
          _outputs,
          _filter.copyWith(
            category: const <String>[],
            year: null,
            issuesOnly: false,
          ),
          featuredIds: widget.featured.toSet(),
          kindByRoot: kinds,
        );
        final roots = [
          for (final node in taxonomy)
            if (tabRows.any((output) => rootOf(output) == node.label)) node,
        ];
        final children = _filter.category.length == 1
            ? childrenAt(taxonomy, _filter.category)
            : const <TaxonomyNode>[];
        final visibleRows = v2
            ? filtered
            : groupOutputs(
                filtered,
                OutputGroup.year,
              ).values.expand((rows) => rows).toList();
        final outputsToValidate = _outputs
            .where(
              (output) =>
                  output['approval_status'] == 'to_validate' ||
                  output['approval_status'] == 'rejected',
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (v2) ...[
              sectionHeader(context, featuredHeader(widget.featured.length)),
              const SizedBox(height: 8),
              if (highlights.isEmpty)
                mutedText(
                  context,
                  'No featured outputs yet — star outputs below',
                )
              else
                for (final author in highlights)
                  PersonOutputRow(
                    author: author,
                    isFeatured:
                        kinds[rootOf(
                          author['outputs'] as Map<String, dynamic>,
                        )] ==
                        'publication',
                    featurable:
                        kinds[rootOf(
                          author['outputs'] as Map<String, dynamic>,
                        )] ==
                        'publication',
                    onToggle: widget.onToggleFeatured,
                    onTap: widget.onOpenOutput,
                  ),
              const SizedBox(height: 24),
            ],
            sectionHeader(context, 'Scientific Outputs · ${_outputs.length}'),
            const SizedBox(height: 8),
            if (outputsToValidate.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warnTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${outputsToValidate.length} outputs to be validated by you. Check them, then submit.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _submitting ? null : _submitOutputs,
                      child: Text(
                        'Submit for UNIDCOM review (${outputsToValidate.length})',
                      ),
                    ),
                  ],
                ),
              ),
            if (!v2 && widget.newOrcidPublications > 0)
              TextButton(
                onPressed: widget.onReviewOrcid,
                child: Text(
                  '${widget.newOrcidPublications} new publications in ORCID → Review',
                ),
              ),
            if (v2)
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
            if (v2)
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
            if (v2) const SizedBox(height: 16),
            if (v2)
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
                    (OutputView.orcid, 'ORCID reconciliation'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter.view == view,
                      onSelected: (_) => setState(
                        () => _filter = _filter.copyWith(view: view),
                      ),
                    ),
                  SegmentedButton<OutputGroup>(
                    segments: const [
                      ButtonSegment(
                        value: OutputGroup.year,
                        label: Text('Year'),
                      ),
                      ButtonSegment(
                        value: OutputGroup.type,
                        label: Text('Type'),
                      ),
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
            if (!v2) ...[
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Publications'),
                    selected: _filter.kind == 'publication',
                    onSelected: (_) => setState(() {
                      _filter = _filter.copyWith(
                        kind: 'publication',
                        category: const <String>[],
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Other activities'),
                    selected: _filter.kind == 'activity',
                    onSelected: (_) => setState(() {
                      _filter = _filter.copyWith(
                        kind: 'activity',
                        category: const <String>[],
                      );
                    }),
                  ),
                  const Spacer(),
                  Text('Featured ${widget.featured.length}/5'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All types'),
                    selected: _filter.category.isEmpty,
                    onSelected: (_) => setState(
                      () => _filter = _filter.copyWith(
                        category: const <String>[],
                      ),
                    ),
                  ),
                  for (final node in roots)
                    ChoiceChip(
                      label: Text(node.label),
                      selected: _filter.category.firstOrNull == node.label,
                      onSelected: (_) => setState(
                        () =>
                            _filter = _filter.copyWith(category: [node.label]),
                      ),
                    ),
                ],
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final node in children)
                      ChoiceChip(
                        label: Text(node.label),
                        selected:
                            _filter.category.length > 1 &&
                            _filter.category[1] == node.label,
                        onSelected: (_) => setState(
                          () => _filter = _filter.copyWith(
                            category: [_filter.category.first, node.label],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All years'),
                    selected: _filter.year == null,
                    onSelected: (_) =>
                        setState(() => _filter = _filter.copyWith(year: null)),
                  ),
                  for (final year in yearsOf(tabRows))
                    ChoiceChip(
                      label: Text('$year'),
                      selected: _filter.year == year,
                      onSelected: (_) => setState(
                        () => _filter = _filter.copyWith(year: year),
                      ),
                    ),
                  FilterChip(
                    label: const Text('Issues only'),
                    selected: _filter.issuesOnly,
                    onSelected: (selected) => setState(
                      () => _filter = _filter.copyWith(issuesOnly: selected),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(countsLine(visibleRows)),
            ],
            const SizedBox(height: 16),
            if (v2 &&
                _filter.view == OutputView.orcid &&
                widget.orcidPanel != null) ...[
              widget.orcidPanel!,
              const SizedBox(height: 24),
              sectionHeader(
                context,
                'Already imported from ORCID · ${filtered.length}',
              ),
              const SizedBox(height: 8),
            ],
            if (!v2 && visibleRows.isEmpty)
              mutedText(
                context,
                _outputs.isEmpty
                    ? 'No outputs yet'
                    : 'No outputs match these filters',
              )
            else if (!v2)
              for (final output in visibleRows)
                PersonOutputRow(
                  author: _authorByOutputId[output['id'].toString()]!,
                  featurable: kinds[rootOf(output)] == 'publication',
                  isFeatured:
                      kinds[rootOf(output)] == 'publication' &&
                      widget.featured.contains(output['id'].toString()),
                  onToggle: widget.onToggleFeatured,
                  onTap: widget.onOpenOutput,
                  onEdit: widget.onEditOutput == null
                      ? null
                      : (_) => widget.onEditOutput!(output),
                  showStates: true,
                )
            else if (groups.isEmpty)
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
                    featurable: kinds[rootOf(output)] == 'publication',
                    isFeatured:
                        kinds[rootOf(output)] == 'publication' &&
                        widget.featured.contains(output['id'].toString()),
                    onToggle: widget.onToggleFeatured,
                    onTap: widget.onOpenOutput,
                    onEdit: widget.onEditOutput == null
                        ? null
                        : (_) => widget.onEditOutput!(output),
                    showStates: true,
                  ),
                const SizedBox(height: 12),
              ],
            // Simpler v1 behavior: keep the injected panel visible when there is no new banner.
            if (!v2 &&
                widget.orcidPanel != null &&
                widget.newOrcidPublications == 0) ...[
              const SizedBox(height: 24),
              widget.orcidPanel!,
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
