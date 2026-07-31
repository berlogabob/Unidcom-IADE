import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/output_row.dart';
import '../widgets/person_card.dart';
import '../widgets/queue_list.dart';
import '../widgets/timeline_section.dart';

/// Conferences are virtual entities: conference-type outputs grouped by a
/// normalized title key ([conferenceKeyOf]). No table behind this — fix a bad
/// grouping by editing the output's title.
class ConferencesScreen extends StatefulWidget {
  const ConferencesScreen({super.key});

  @override
  State<ConferencesScreen> createState() => _ConferencesScreenState();
}

class _ConferencesScreenState extends State<ConferencesScreen> {
  late final Future<List<Map<String, dynamic>>> _groups = _fetchGroups();

  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    final outputs = await fetchConferenceOutputs();
    final groups = <String, Map<String, dynamic>>{};
    for (final output in outputs) {
      final key = conferenceKeyOf(output);
      final group = groups.putIfAbsent(
        key,
        () => {
          'key': key,
          'name': conferenceNameOf(output),
          'count': 0,
          'years': <int>{},
        },
      );
      group['count'] = (group['count'] as int) + 1;
      final year = output['reporting_year'] as int?;
      if (year != null) (group['years'] as Set<int>).add(year);
    }
    return groups.values.toList();
  }

  String _yearsLabel(Map<String, dynamic> group) {
    final years = (group['years'] as Set<int>).toList()..sort();
    return years.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return QueueList(
      future: _groups,
      emptyText: 'No conferences found',
      searchOf: (g) => g['name'] as String,
      timeOf: (g) {
        final years = g['years'] as Set<int>;
        return years.isEmpty ? 0 : years.reduce((a, b) => a > b ? a : b);
      },
      itemBuilder: (group) => Card(
        child: ListTile(
          leading: const Icon(Icons.event),
          title: Text(group['name'] as String),
          subtitle: Text(
            [
              '${group['count']} output${group['count'] == 1 ? '' : 's'}',
              if ((group['years'] as Set<int>).isNotEmpty) _yearsLabel(group),
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
            '/conferences/${Uri.encodeComponent(group['key'] as String)}',
          ),
        ),
      ),
    );
  }
}

class ConferencePageScreen extends StatefulWidget {
  const ConferencePageScreen({super.key, required this.confKey});

  final String confKey;

  @override
  State<ConferencePageScreen> createState() => _ConferencePageScreenState();
}

class _ConferencePageScreenState extends State<ConferencePageScreen> {
  late final Future<List<Map<String, dynamic>>> _outputs =
      fetchConferenceOutputs().then(
        (all) => all.where((o) => conferenceKeyOf(o) == widget.confKey).toList(),
      );

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Map<String, dynamic>>>(
      future: _outputs,
      builder: (context, outputs) {
        if (outputs.isEmpty) {
          return const Center(child: Text('Conference not found'));
        }
        final years = outputs
            .map((o) => o['reporting_year'] as int?)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        // Union of authors across the grouped outputs, deduped by person id.
        final people = <String, Map<String, dynamic>>{};
        for (final output in outputs) {
          for (final author
              in (output['output_authors'] as List<dynamic>? ?? [])) {
            final person =
                (author as Map<String, dynamic>)['people']
                    as Map<String, dynamic>?;
            if (person != null) people[person['id'] as String] = person;
          }
        }

        return DetailBody(
          children: [
            EntityHeaderCard(
              leading: const CircleAvatar(radius: 24, child: Icon(Icons.event)),
              title: conferenceNameOf(outputs.first),
              subtitle: 'Conference',
              chips: statusChips(years),
            ),
            const SizedBox(height: 24),
            TimelineSection(
              title: 'Outputs · ${outputs.length}',
              items: outputs,
              yearOf: (o) => o['reporting_year'] as int?,
              groupOf: (o) => o['type'] as String? ?? '',
              itemBuilder: (o) => OutputRow(
                title: o['title'] as String? ?? 'Untitled',
                year: o['reporting_year'] as int?,
                type: o['type'] as String?,
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.go('/outputs/${o['id']}'),
              ),
              emptyText: 'No outputs',
            ),
            const SizedBox(height: 24),
            sectionHeader(context, 'People · ${people.length}'),
            const SizedBox(height: 8),
            if (people.isEmpty)
              mutedText(context, 'No linked people')
            else
              for (final person in people.values)
                PersonCard(
                  name: person['preferred_name'] as String? ?? 'Unnamed',
                  membershipType: person['membership_type'] as String?,
                  status: person['status'] as String?,
                  onTap: () => context.go('/people/${person['id']}'),
                ),
          ],
        );
      },
    );
  }
}
