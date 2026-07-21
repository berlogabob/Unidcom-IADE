import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';

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

  void _refresh() {
    setState(() {
      _pendingPeople = fetchPendingPeople();
      _pendingOutputs = fetchPendingOutputs();
      _stalePeople = fetchStalePeople();
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

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const Center(child: Text('Admin access required'));

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Profiles to approve'),
              Tab(text: 'Outputs to approve'),
              Tab(text: 'Needs re-verification'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AsyncList(
                  future: _pendingPeople,
                  emptyText: 'No profiles waiting for approval',
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
                _AsyncList(
                  future: _pendingOutputs,
                  emptyText: 'No outputs waiting for approval',
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
                _AsyncList(
                  future: _stalePeople,
                  emptyText: 'No profiles need re-verification',
                  itemBuilder: (person) {
                    // test mode: reminder emails intentionally disabled
                    return ListTile(
                      title: Text(
                        person['preferred_name'] as String? ?? 'Unnamed',
                      ),
                      subtitle: Text(
                        person['last_verified_at'] as String? ??
                            'Never verified',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AsyncList extends StatelessWidget {
  const _AsyncList({
    required this.future,
    required this.emptyText,
    required this.itemBuilder,
  });

  final Future<List<Map<String, dynamic>>> future;
  final String emptyText;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return Center(child: Text(emptyText));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) => itemBuilder(rows[index]),
        );
      },
    );
  }
}
