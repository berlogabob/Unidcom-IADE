import 'package:flutter/material.dart';

import 'search_bar.dart';

/// A per-tab filter dropdown. Options are auto-derived from the distinct
/// non-null values of [valueOf] across the loaded rows.
class QueueFilter {
  const QueueFilter({required this.label, required this.valueOf});

  final String label;
  final String? Function(Map<String, dynamic>) valueOf;
}

/// A "Group by" option: rows sharing the same [keyOf] value get a section header.
class QueueGroup {
  const QueueGroup({required this.label, required this.keyOf});

  final String label;
  final String Function(Map<String, dynamic>) keyOf;
}

/// A FutureBuilder list with a client-side search box, sort dropdown
/// (A–Z / Time / Confidence %) and optional per-tab filter dropdowns.
/// Client-side is fine — the review queues are small.
class QueueList extends StatefulWidget {
  const QueueList({
    super.key,
    required this.future,
    required this.emptyText,
    required this.itemBuilder,
    required this.searchOf,
    this.timeOf,
    this.confidenceOf,
    this.filters = const [],
    this.groups = const [],
  });

  final Future<List<Map<String, dynamic>>> future;
  final String emptyText;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final String Function(Map<String, dynamic>) searchOf;
  final Comparable Function(Map<String, dynamic>)? timeOf;
  final num? Function(Map<String, dynamic>)? confidenceOf;
  final List<QueueFilter> filters;
  final List<QueueGroup> groups;

  @override
  State<QueueList> createState() => _QueueListState();
}

enum _Sort { az, time, confidence }

class _QueueListState extends State<QueueList> {
  String _query = '';
  _Sort _sort = _Sort.az;
  final Map<String, String?> _filterValues = {};
  QueueGroup? _group;

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> rows) {
    var result = rows;

    for (final filter in widget.filters) {
      final selected = _filterValues[filter.label];
      if (selected != null) {
        result = result.where((r) => filter.valueOf(r) == selected).toList();
      }
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((r) => widget.searchOf(r).toLowerCase().contains(q))
          .toList();
    }

    result = [...result];
    switch (_sort) {
      case _Sort.az:
        result.sort(
          (a, b) => widget
              .searchOf(a)
              .toLowerCase()
              .compareTo(widget.searchOf(b).toLowerCase()),
        );
      case _Sort.time:
        // Newest first.
        result.sort((a, b) => widget.timeOf!(b).compareTo(widget.timeOf!(a)));
      case _Sort.confidence:
        // Highest confidence first.
        result.sort(
          (a, b) => (widget.confidenceOf!(b) ?? 0).compareTo(
            widget.confidenceOf!(a) ?? 0,
          ),
        );
    }
    return result;
  }

  Widget _controls(List<Map<String, dynamic>> rows) {
    final sortItems = [
      const DropdownMenuItem(value: _Sort.az, child: Text('Sort: A–Z')),
      if (widget.timeOf != null)
        const DropdownMenuItem(value: _Sort.time, child: Text('Sort: Time')),
      if (widget.confidenceOf != null)
        const DropdownMenuItem(
          value: _Sort.confidence,
          child: Text('Sort: Confidence %'),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: SearchBarField(
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<_Sort>(
              initialValue: _sort,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: sortItems,
              onChanged: (value) => setState(() => _sort = value ?? _Sort.az),
            ),
          ),
          for (final filter in widget.filters)
            () {
              final options = _optionsFor(filter, rows);
              final selected = _filterValues[filter.label];
              // Selection may have vanished after a refresh — fall back to All.
              final value = options.contains(selected) ? selected : null;
              return SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: value,
                  decoration: InputDecoration(
                    labelText: filter.label,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final option in options)
                      DropdownMenuItem(value: option, child: Text(option)),
                  ],
                  onChanged: (v) =>
                      setState(() => _filterValues[filter.label] = v),
                ),
              );
            }(),
          if (widget.groups.isNotEmpty)
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<QueueGroup?>(
                initialValue: _group,
                decoration: const InputDecoration(
                  labelText: 'Group by',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final group in widget.groups)
                    DropdownMenuItem(value: group, child: Text(group.label)),
                ],
                onChanged: (v) => setState(() => _group = v),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _optionsFor(
    QueueFilter filter,
    List<Map<String, dynamic>> rows,
  ) {
    final values = rows
        .map(filter.valueOf)
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  /// Buckets [rows] by the group key (first-seen order preserved) and emits a
  /// section header with a count before each group's items.
  List<Widget> _groupedChildren(
    List<Map<String, dynamic>> rows,
    QueueGroup group,
  ) {
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = group.keyOf(row);
      buckets.putIfAbsent(key.isEmpty ? '—' : key, () => []).add(row);
    }
    return [
      for (final entry in buckets.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '${entry.key} · ${entry.value.length}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final row in entry.value) widget.itemBuilder(row),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final rows = snapshot.data ?? [];
        final visible = _apply(rows);
        return Column(
          children: [
            _controls(rows),
            Expanded(
              child: visible.isEmpty
                  ? Center(child: Text(widget.emptyText))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _group == null
                          ? [for (final row in visible) widget.itemBuilder(row)]
                          : _groupedChildren(visible, _group!),
                    ),
            ),
          ],
        );
      },
    );
  }
}
