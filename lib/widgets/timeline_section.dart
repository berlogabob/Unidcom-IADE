import 'package:flutter/material.dart';

import 'detail_scaffold.dart';
import 'queue_list.dart';

/// Year-grouped timeline of already-loaded rows, with an optional second
/// grouping (tags/types/roles), auto-derived filter dropdowns and a
/// newest/oldest toggle. Renders as a Column — it lives inside a
/// [DetailBody] ListView, so it does not scroll on its own.
class TimelineSection extends StatefulWidget {
  const TimelineSection({
    super.key,
    required this.title,
    required this.items,
    required this.yearOf,
    required this.itemBuilder,
    this.groupOf,
    this.groupLabel = 'By type',
    this.filters = const [],
    this.emptyText = 'Nothing yet',
    this.onAdd,
    this.addLabel = 'Add',
    this.headerTrailing,
  });

  final String title;
  final List<Map<String, dynamic>> items;

  /// Year bucket for an item; null lands in an 'Undated' bucket.
  final int? Function(Map<String, dynamic>) yearOf;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  /// Second grouping key. When set, a [By year | groupLabel] switch appears.
  final String Function(Map<String, dynamic>)? groupOf;
  final String groupLabel;
  final List<QueueFilter> filters;
  final String emptyText;
  final VoidCallback? onAdd;
  final String addLabel;

  /// Extra widget next to the section header (e.g. a year picker for adds).
  final Widget? headerTrailing;

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  bool _byGroup = false;
  bool _newestFirst = true;
  final Map<String, String?> _filterValues = {};

  List<Map<String, dynamic>> _filtered() {
    var result = widget.items;
    for (final filter in widget.filters) {
      final selected = _filterValues[filter.label];
      if (selected != null) {
        result = result.where((r) {
          if (filter.valuesOf != null) {
            return filter.valuesOf!(r).contains(selected);
          }
          return filter.valueOf!(r) == selected;
        }).toList();
      }
    }
    return result;
  }

  List<Widget> _byYearView(List<Map<String, dynamic>> items) {
    final byYear = <int?, List<Map<String, dynamic>>>{};
    for (final item in items) {
      (byYear[widget.yearOf(item)] ??= []).add(item);
    }
    final years = byYear.keys.toList()
      ..sort((a, b) => _newestFirst
          ? (b ?? -1).compareTo(a ?? -1)
          : (a ?? -1).compareTo(b ?? -1));
    return [
      for (final year in years) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            year?.toString() ?? 'Undated',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final item in byYear[year]!) widget.itemBuilder(item),
      ],
    ];
  }

  List<Widget> _byGroupView(List<Map<String, dynamic>> items) {
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final key = widget.groupOf!(item);
      (byKey[key.isEmpty ? '—' : key] ??= []).add(item);
    }
    final keys = byKey.keys.toList()..sort();
    return [
      for (final key in keys) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '$key · ${byKey[key]!.length}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final item in byKey[key]!) widget.itemBuilder(item),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: sectionHeader(
                context,
                widget.title,
                onAdd: widget.onAdd,
                addLabel: widget.addLabel,
              ),
            ),
            if (widget.headerTrailing != null) widget.headerTrailing!,
          ],
        ),
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.groupOf != null)
                SegmentedButton<bool>(
                  segments: [
                    const ButtonSegment(value: false, label: Text('By year')),
                    ButtonSegment(value: true, label: Text(widget.groupLabel)),
                  ],
                  selected: {_byGroup},
                  onSelectionChanged: (s) =>
                      setState(() => _byGroup = s.first),
                ),
              if (!_byGroup)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _newestFirst = !_newestFirst),
                  icon: const Icon(Icons.swap_vert),
                  label: Text(_newestFirst ? 'Newest first' : 'Oldest first'),
                ),
              for (final filter in widget.filters)
                () {
                  final options = filterOptions(filter, widget.items);
                  final selected = _filterValues[filter.label];
                  return filterDropdown(
                    filter.label,
                    options.contains(selected) ? selected : null,
                    options,
                    (v) => setState(() => _filterValues[filter.label] = v),
                  );
                }(),
            ],
          ),
        ],
        const SizedBox(height: 4),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: mutedText(context, widget.emptyText),
          )
        else
          ..._byGroup ? _byGroupView(items) : _byYearView(items),
      ],
    );
  }
}
