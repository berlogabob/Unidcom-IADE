import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/candidate_tile.dart';
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
  late Future<List<Map<String, dynamic>>> _flaggedOutputs =
      fetchFlaggedOutputs();
  late Future<List<Map<String, dynamic>>> _candidates = fetchOutputCandidates();

  void _refresh() {
    setState(() {
      _pendingPeople = fetchPendingPeople();
      _pendingOutputs = fetchPendingOutputs();
      _stalePeople = fetchStalePeople();
      _pendingSuggestions = fetchPendingSuggestions();
      _changeLog = fetchChangeLog();
      _flaggedOutputs = fetchFlaggedOutputs();
      _candidates = fetchOutputCandidates();
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
    // A suggested DOI can collide with outputs.doi's unique constraint. Without
    // this catch the write throws, the suggestion stays pending, and the admin
    // sees nothing at all.
    try {
      await acceptSuggestion(id);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _rejectSuggestion(String id) async {
    await rejectSuggestion(id);
    _refresh();
  }

  Future<void> _promoteCandidate(String id, String affiliation) async {
    try {
      await promoteCandidate(id, affiliation: affiliation);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _rejectCandidate(String id) async {
    await rejectCandidate(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));

    return DefaultTabController(
      length: 7,
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
              Tab(text: 'Needs attention'),
              Tab(text: 'ORCID works'),
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
                QueueList(
                  future: _flaggedOutputs,
                  emptyText: 'No outputs need attention',
                  searchOf: (o) => o['title'] as String? ?? '',
                  timeOf: (o) => o['created_at'] as String? ?? '',
                  filters: [
                    QueueFilter(
                      label: 'Type',
                      valueOf: (o) => o['type'] as String?,
                    ),
                    QueueFilter(
                      label: 'Issue',
                      valuesOf: (o) => (o['issue_codes'] as List<dynamic>? ?? [])
                          .cast<String>(),
                    ),
                    QueueFilter(
                      label: 'Severity',
                      valueOf: (o) => (o['error_count'] as int? ?? 0) > 0
                          ? 'Errors'
                          : (o['warning_count'] as int? ?? 0) > 0
                          ? 'Warnings'
                          : null,
                    ),
                  ],
                  groups: [
                    QueueGroup(
                      label: 'Issue',
                      keyOf: (o) =>
                          ((o['issue_codes'] as List<dynamic>? ?? [])
                                  .cast<String>()
                                  .firstOrNull) ??
                          '—',
                    ),
                    QueueGroup(
                      label: 'Type',
                      keyOf: (o) => o['type'] as String? ?? '—',
                    ),
                  ],
                  itemBuilder: (output) => OutputRow(
                    title: output['title'] as String? ?? 'Untitled',
                    year: output['reporting_year'] as int?,
                    type: output['type'] as String?,
                    issueCodes: (output['issue_codes'] as List<dynamic>? ?? [])
                        .cast<String>(),
                    errorCount: output['error_count'] as int? ?? 0,
                    warningCount: output['warning_count'] as int? ?? 0,
                    onTap: () => context.go('/outputs/${output['id']}'),
                  ),
                ),
                QueueList(
                  future: _candidates,
                  emptyText: 'No ORCID works waiting for review',
                  searchOf: (c) =>
                      '${c['person_name'] ?? ''} ${c['title'] ?? ''}',
                  timeOf: (c) => c['created_at'] as String? ?? '',
                  confidenceOf: (c) =>
                      num.parse(c['affiliation_score'].toString()),
                  filters: [
                    QueueFilter(
                      label: 'Affiliation',
                      valueOf: (c) => c['affiliation'] as String?,
                    ),
                    QueueFilter(
                      label: 'Researcher',
                      valueOf: (c) => c['person_name'] as String?,
                    ),
                  ],
                  groups: [
                    QueueGroup(
                      label: 'Researcher',
                      keyOf: (c) => c['person_name'] as String? ?? '—',
                    ),
                    QueueGroup(
                      label: 'Affiliation',
                      keyOf: (c) => c['affiliation'] as String? ?? '—',
                    ),
                  ],
                  itemBuilder: (candidate) => CandidateTile(
                    candidate: candidate,
                    onImport: (affiliation) =>
                        _promoteCandidate(candidate['id'] as String, affiliation),
                    onDismiss: () => _rejectCandidate(candidate['id'] as String),
                  ),
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

