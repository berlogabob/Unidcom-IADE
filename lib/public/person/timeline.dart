import 'package:flutter/material.dart';

import '../../data/supabase.dart';
import '../../widgets/queue_list.dart';
import '../../widgets/timeline_section.dart';
import 'featured_outputs.dart';
import 'output_row.dart';

class PersonTimelineSection extends StatelessWidget {
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
    final canEdit = admin || isOwner;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: roles,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? [];
        // Roles first (membership pinned), then outputs, then labs — the
        // year buckets keep this insertion order.
        final items = <Map<String, dynamic>>[
          for (final role in [
            ...roles,
          ]..sort((a, b) => _order(a).compareTo(_order(b))))
            {...role, '_kind': _kindLabels[role['kind']] ?? 'Role'},
          for (final author in authors) {...author, '_kind': 'Output'},
          for (final membership in labMemberships)
            {...membership, '_kind': 'Lab'},
        ];
        return TimelineSection(
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
              isFeatured: featured.contains(outputIdOf(item)),
              onToggle: canEdit ? onToggleFeatured : null,
              onTap: onOpenOutput,
            ),
            'Lab' => _labRow(context, item),
            _ => _roleRow(item, showValue: true),
          },
          emptyText: 'Nothing recorded yet',
          onAdd: canEdit ? onAddRole : null,
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
      onTap: () => onOpenLab(lab['id'].toString()),
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
          if (admin && pending)
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check),
              onPressed: () async {
                await approvePersonRole(role['id'] as String);
                onRefresh();
              },
            ),
          if (admin || isOwner)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () async {
                await removePersonRole(role['id'] as String);
                onRefresh();
              },
            ),
        ],
      ),
    );
  }
}
