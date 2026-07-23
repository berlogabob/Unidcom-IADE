import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/queue_list.dart';

/// One tab hosting Labs / Clusters / Objectives via a segmented switch.
/// Each segment is a filterable [QueueList]; rows link to the detail pages.
class StructureScreen extends StatefulWidget {
  const StructureScreen({super.key});

  @override
  State<StructureScreen> createState() => _StructureScreenState();
}

enum _Seg { labs, clusters, objectives }

class _StructureScreenState extends State<StructureScreen> {
  _Seg _seg = _Seg.labs;
  late final Future<List<Map<String, dynamic>>> _labs = fetchLabs();
  late final Future<List<Map<String, dynamic>>> _clusters = fetchClusters();
  late final Future<List<Map<String, dynamic>>> _objectives = fetchObjectives();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SegmentedButton<_Seg>(
            segments: const [
              ButtonSegment(value: _Seg.labs, label: Text('Labs')),
              ButtonSegment(value: _Seg.clusters, label: Text('Clusters')),
              ButtonSegment(
                value: _Seg.objectives,
                label: Text('Objectives'),
              ),
            ],
            selected: {_seg},
            onSelectionChanged: (s) => setState(() => _seg = s.first),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    switch (_seg) {
      case _Seg.labs:
        return QueueList(
          future: _labs,
          emptyText: 'No labs',
          searchOf: (l) => '${l['code']} ${l['name']}',
          itemBuilder: (lab) => _tile(
            code: lab['code'] as String?,
            name: lab['name'] as String? ?? 'Unnamed lab',
            subtitle: [
              _plural(_count(lab, 'lab_members'), 'member'),
              _plural(_count(lab, 'lab_objectives'), 'objective'),
              _plural(_count(lab, 'project_labs'), 'project'),
            ].join(' · '),
            onTap: () => context.go('/labs/${lab['id']}'),
          ),
        );
      case _Seg.clusters:
        return QueueList(
          future: _clusters,
          emptyText: 'No clusters',
          searchOf: (c) => '${c['code']} ${c['name']} ${c['concern']}',
          itemBuilder: (cluster) => _tile(
            code: cluster['code'] as String?,
            name: cluster['name'] as String? ?? 'Unnamed cluster',
            subtitle: [
              if ((cluster['concern'] as String? ?? '').trim().isNotEmpty)
                cluster['concern'] as String,
              _plural(_count(cluster, 'objective_clusters'), 'objective'),
              _plural(_count(cluster, 'project_clusters'), 'project'),
            ].join(' · '),
            onTap: () => context.go('/clusters/${cluster['id']}'),
          ),
        );
      case _Seg.objectives:
        return QueueList(
          future: _objectives,
          emptyText: 'No objectives',
          searchOf: (o) => '${o['code']} ${o['name']}',
          itemBuilder: (obj) => _tile(
            code: obj['code'] as String?,
            name: obj['name'] as String? ?? 'Unnamed objective',
            subtitle: [
              if (_clusterCodes(obj).isNotEmpty) _clusterCodes(obj),
              _plural(_count(obj, 'project_objectives'), 'project'),
            ].join(' · '),
            onTap: () => context.go('/objectives/${obj['id']}'),
          ),
        );
    }
  }

  Widget _tile({
    String? code,
    required String name,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: code == null
            ? null
            : CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: code.length > 3 ? 9 : 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
        title: Text(name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

int _count(Map<String, dynamic> row, String key) {
  final list = row[key] as List<dynamic>?;
  if (list == null || list.isEmpty) return 0;
  return (list.first as Map<String, dynamic>)['count'] as int? ?? 0;
}

String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

String _clusterCodes(Map<String, dynamic> objective) {
  return (objective['objective_clusters'] as List<dynamic>? ?? [])
      .map((e) => (e as Map<String, dynamic>)['clusters'] as Map<String, dynamic>?)
      .map((c) => c?['code'] as String?)
      .whereType<String>()
      .join(', ');
}
