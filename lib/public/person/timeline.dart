import 'package:flutter/material.dart';

import '../../data/supabase.dart';
import '../../data/taxonomy.dart';
import '../../widgets/queue_list.dart';
import '../../widgets/taxonomy_picker.dart';
import '../../widgets/timeline_section.dart';
import 'featured_outputs.dart';
import 'output_row.dart';

class PersonTimelineSection extends StatefulWidget {
  const PersonTimelineSection({
    super.key,
    required this.roles,
    required this.authors,
    required this.labMemberships,
    required this.featured,
    required this.admin,
    required this.isOwner,
    required this.onToggleFeatured,
    required this.onRefresh,
    required this.onAddRole,
    required this.onOpenOutput,
    required this.onOpenLab,
  });

  final Future<List<Map<String, dynamic>>> roles;
  final List<Map<String, dynamic>> authors;
  final List<Map<String, dynamic>> labMemberships;
  final List<String> featured;
  final bool admin;
  final bool isOwner;
  final ValueChanged<String> onToggleFeatured;
  final VoidCallback onRefresh;
  final VoidCallback onAddRole;
  final ValueChanged<String> onOpenOutput;
  final ValueChanged<String> onOpenLab;

  @override
  State<PersonTimelineSection> createState() => _PersonTimelineSectionState();
}

class _PersonTimelineSectionState extends State<PersonTimelineSection> {
  /// The cascade selection — "for both filtering my outputs as well as when i
  /// click +add". Empty = All.
  List<String> _category = const [];
  late final Future<List<TaxonomyNode>> _taxonomy = fetchOutputTaxonomy();

  static const _kindLabels = {
    'membership': 'Membership',
    'role': 'Role',
    'tag': 'Tag',
    'mentorship': 'Mentorship',
  };
  static const _kindOrder = {
    'membership': 0,
    'role': 1,
    'tag': 2,
    'mentorship': 3,
  };

  String _roleValue(Map<String, dynamic> role) {
    final label = role['label'] as String? ?? '';
    if (role['kind'] == 'membership') return membershipLabels[label] ?? label;
    return label;
  }

  int _order(Map<String, dynamic> role) => _kindOrder[role['kind']] ?? 9;

  /// One merged year-grouped timeline: roles/tags/mentorships, UNIDCOM
  /// outputs (star toggles intact) and lab memberships.
  @override
  Widget build(BuildContext context) {
    final canEdit = widget.admin || widget.isOwner;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.roles,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? [];
        // A picked category names outputs, so it narrows the timeline to the
        // matching ones — roles and labs have no category and drop out, the
        // same "unclassified matches only All" rule the admin list applies.
        final items = <Map<String, dynamic>>[
          if (_category.isEmpty) ...[
            // Roles first (membership pinned), then outputs, then labs — the
            // year buckets keep this insertion order.
            for (final role in [
              ...roles,
            ]..sort((a, b) => _order(a).compareTo(_order(b))))
              {...role, '_kind': _kindLabels[role['kind']] ?? 'Role'},
          ],
          for (final author in widget.authors)
            if (matchesCategory(
              (author['outputs'] as Map<String, dynamic>?)?['category_path']
                  as String?,
              _category,
            ))
              {...author, '_kind': 'Output'},
          if (_category.isEmpty)
            for (final membership in widget.labMemberships)
              {...membership, '_kind': 'Lab'},
        ];
        final timeline = TimelineSection(
          title: 'Timeline · ${items.length}',
          items: items,
          yearOf: (item) => switch (item['_kind']) {
            'Output' =>
              (item['outputs'] as Map<String, dynamic>?)?['reporting_year']
                  as int?,
            _ => item['year'] as int?,
          },
          groupOf: (item) => switch (item['_kind']) {
            'Output' =>
              (item['outputs'] as Map<String, dynamic>?)?['type'] as String? ??
                  'Output',
            'Lab' =>
              'Lab · ${(item['labs'] as Map<String, dynamic>?)?['code'] ?? '—'}',
            _ => '${item['_kind']} · ${_roleValue(item)}',
          },
          groupLabel: 'By tag',
          filters: [
            QueueFilter(label: 'Kind', valueOf: (i) => i['_kind'] as String?),
          ],
          itemBuilder: (item) => switch (item['_kind']) {
            'Output' => PersonOutputRow(
              author: item,
              isFeatured: widget.featured.contains(outputIdOf(item)),
              onToggle: canEdit ? widget.onToggleFeatured : null,
              onTap: widget.onOpenOutput,
            ),
            'Lab' => _labRow(context, item),
            _ => _roleRow(item, showValue: true),
          },
          emptyText: _category.isEmpty
              ? 'Nothing recorded yet'
              : 'No outputs in this category',
          onAdd: canEdit ? widget.onAddRole : null,
        );
        // The cascade sits outside TimelineSection: the section hides its
        // filter row whenever its items come up empty, and a picker that
        // vanishes on a zero-result selection could never be undone.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.authors.isNotEmpty)
              FutureBuilder<List<TaxonomyNode>>(
                future: _taxonomy,
                builder: (context, taxonomy) {
                  final roots = taxonomy.data ?? const <TaxonomyNode>[];
                  if (roots.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TaxonomyPicker(
                      roots: roots,
                      value: _category,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                  );
                },
              ),
            timeline,
          ],
        );
      },
    );
  }

  Widget _labRow(BuildContext context, Map<String, dynamic> membership) {
    final lab = membership['labs'] as Map<String, dynamic>?;
    if (lab == null) return const SizedBox.shrink();
    final coordinator = membership['is_coordinator'] as bool? ?? false;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        coordinator ? Icons.star : Icons.science_outlined,
        size: 20,
      ),
      title: Text(
        'Lab · ${lab['code'] ?? lab['name'] ?? '—'}'
        '${coordinator ? ' (coordinator)' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => widget.onOpenLab(lab['id'].toString()),
    );
  }

  Widget _roleRow(Map<String, dynamic> role, {required bool showValue}) {
    final pending = role['status'] == 'pending';
    final kind = _kindLabels[role['kind']] ?? role['kind'] as String? ?? '';
    final title = showValue
        ? '$kind · ${_roleValue(role)}'
        : (role['year']?.toString() ?? 'Undated');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: (role['notes'] as String?)?.isNotEmpty == true
          ? Text(role['notes'] as String)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending)
            const Chip(
              label: Text('pending'),
              visualDensity: VisualDensity.compact,
            ),
          if (widget.admin && pending)
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check),
              onPressed: () async {
                await approvePersonRole(role['id'] as String);
                widget.onRefresh();
              },
            ),
          if (widget.admin || widget.isOwner)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () async {
                await removePersonRole(role['id'] as String);
                widget.onRefresh();
              },
            ),
        ],
      ),
    );
  }
}
