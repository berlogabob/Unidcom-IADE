import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';
import '../widgets/queue_list.dart';
import '../widgets/suggestion_tile.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  late Future<List<Map<String, dynamic>>> _pendingPeople = fetchPendingPeople();
  late Future<List<Map<String, dynamic>>> _pendingOutputs =
      fetchPendingOutputs();
  late Future<List<Map<String, dynamic>>> _stalePeople = fetchStalePeople();
  late Future<List<Map<String, dynamic>>> _pendingSuggestions =
      fetchPendingSuggestions();
  late Future<List<Map<String, dynamic>>> _changeLog = fetchChangeLog();

  void _refresh() {
    setState(() {
      _pendingPeople = fetchPendingPeople();
      _pendingOutputs = fetchPendingOutputs();
      _stalePeople = fetchStalePeople();
      _pendingSuggestions = fetchPendingSuggestions();
      _changeLog = fetchChangeLog();
    });
  }

  Future<void> _approvePerson(String id) async {
    await approvePerson(id);
    _refresh();
  }

  Future<void> _approveOutput(String id) async {
    await approveOutput(id);
    _refresh();
  }

  Future<void> _acceptSuggestion(String id) async {
    await acceptSuggestion(id);
    _refresh();
  }

  Future<void> _rejectSuggestion(String id) async {
    await rejectSuggestion(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Profiles to approve'),
              Tab(text: 'Outputs to approve'),
              Tab(text: 'Needs re-verification'),
              Tab(text: 'Suggestions'),
              Tab(text: 'Activity'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                QueueList(
                  future: _pendingPeople,
                  emptyText: 'No profiles waiting for approval',
                  searchOf: (p) => p['preferred_name'] as String? ?? '',
                  timeOf: (p) => p['created_at'] as String? ?? '',
                  filters: [
                    QueueFilter(
                      label: 'Profile',
                      valueOf: (p) => p['profile_status'] as String?,
                    ),
                  ],
                  itemBuilder: (person) => ListTile(
                    title: Text(
                      person['preferred_name'] as String? ?? 'Unnamed',
                    ),
                    subtitle: Text(person['profile_status'] as String? ?? ''),
                    trailing: FilledButton(
                      onPressed: () => _approvePerson(person['id'] as String),
                      child: const Text('Approve'),
                    ),
                  ),
                ),
                QueueList(
                  future: _pendingOutputs,
                  emptyText: 'No outputs waiting for approval',
                  searchOf: (o) => o['title'] as String? ?? '',
                  timeOf: (o) => o['created_at'] as String? ?? '',
                  filters: [
                    QueueFilter(
                      label: 'Type',
                      valueOf: (o) => o['type'] as String?,
                    ),
                  ],
                  itemBuilder: (output) => OutputRow(
                    title: output['title'] as String? ?? 'Untitled',
                    year: output['reporting_year'] as int?,
                    type: output['type'] as String?,
                    detail: output['approval_status'] as String?,
                    trailing: FilledButton(
                      onPressed: () => _approveOutput(output['id'] as String),
                      child: const Text('Approve'),
                    ),
                  ),
                ),
                QueueList(
                  future: _stalePeople,
                  emptyText: 'No profiles need re-verification',
                  searchOf: (p) => p['preferred_name'] as String? ?? '',
                  timeOf: (p) => p['last_verified_at'] as String? ?? '',
                  filters: [
                    QueueFilter(
                      label: 'Membership',
                      valueOf: (p) => p['membership_type'] as String?,
                    ),
                  ],
                  // test mode: reminder emails intentionally disabled
                  itemBuilder: (person) => ListTile(
                    title: Text(
                      person['preferred_name'] as String? ?? 'Unnamed',
                    ),
                    subtitle: Text(
                      person['last_verified_at'] as String? ?? 'Never verified',
                    ),
                  ),
                ),
                QueueList(
                  future: _pendingSuggestions,
                  emptyText: 'No enrichment suggestions waiting for review',
                  searchOf: (s) => s['subject_name'] as String? ?? '',
                  timeOf: (s) => s['created_at'] as String? ?? '',
                  confidenceOf: (s) => s['confidence'] == null
                      ? null
                      : num.parse(s['confidence'].toString()),
                  filters: [
                    QueueFilter(
                      label: 'Source',
                      valueOf: (s) => s['source'] as String?,
                    ),
                  ],
                  groups: [
                    QueueGroup(
                      label: 'Person',
                      keyOf: (s) => s['subject_name'] as String? ?? '—',
                    ),
                    QueueGroup(
                      label: 'Field',
                      keyOf: (s) => s['field'] as String? ?? '—',
                    ),
                  ],
                  itemBuilder: (suggestion) => SuggestionTile(
                    suggestion: suggestion,
                    onAccept: () =>
                        _acceptSuggestion(suggestion['id'] as String),
                    onReject: () =>
                        _rejectSuggestion(suggestion['id'] as String),
                  ),
                ),
                QueueList(
                  future: _changeLog,
                  emptyText: 'No changes recorded yet',
                  searchOf: (c) =>
                      '${c['subject_name'] ?? ''} ${c['field'] ?? ''}',
                  timeOf: (c) => c['changed_at'] as String? ?? '',
                  filters: [
                    QueueFilter(
                      label: 'Source',
                      valueOf: (c) => c['source'] as String?,
                    ),
                  ],
                  groups: [
                    QueueGroup(
                      label: 'Person',
                      keyOf: (c) => c['subject_name'] as String? ?? '—',
                    ),
                    QueueGroup(
                      label: 'Source',
                      keyOf: (c) => c['source'] as String? ?? '—',
                    ),
                  ],
                  itemBuilder: _changeTile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeTile(Map<String, dynamic> change) {
    final field = change['field'] as String? ?? '?';
    final oldValue = change['old_value'] as String? ?? '∅';
    final newValue = change['new_value'] as String? ?? '∅';
    final subject = change['subject_name'] as String?;
    final actor = change['actor_name'] as String?;
    final source = change['source'] as String? ?? 'manual';
    final when = (change['changed_at'] as String? ?? '').split('T').first;
    return ListTile(
      title: Text('$field: $oldValue → $newValue'),
      subtitle: Text(
        [
          if (subject != null && subject.isNotEmpty) subject,
          source,
          if (actor != null && actor.isNotEmpty) 'by $actor',
          when,
        ].join(' · '),
      ),
      isThreeLine: false,
    );
  }
}

