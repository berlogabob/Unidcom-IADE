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

  void _refresh() {
    setState(() {
      _pendingPeople = fetchPendingPeople();
      _pendingOutputs = fetchPendingOutputs();
      _stalePeople = fetchStalePeople();
      _pendingSuggestions = fetchPendingSuggestions();
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
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Profiles to approve'),
              Tab(text: 'Outputs to approve'),
              Tab(text: 'Needs re-verification'),
              Tab(text: 'Suggestions'),
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
                  itemBuilder: (suggestion) => SuggestionTile(
                    suggestion: suggestion,
                    onAccept: () =>
                        _acceptSuggestion(suggestion['id'] as String),
                    onReject: () =>
                        _rejectSuggestion(suggestion['id'] as String),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

