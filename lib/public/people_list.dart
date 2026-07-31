import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import 'person_page.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/person_card.dart';
import '../widgets/queue_list.dart';
import '../widgets/search_bar.dart';

class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key});

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  String _query = '';
  String? _membershipType;
  String? _status;
  String? _profileStatus;
  bool _missingOrcid = false;
  bool _needsVerification = false;
  bool _hasOutputs = false;
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();

  void _search(String value) {
    _query = value;
    _load();
  }

  void _load() {
    setState(
      () => _people = fetchPeople(
        query: _query,
        membershipType: _membershipType,
        status: _status,
        profileStatus: _profileStatus,
        missingOrcid: _missingOrcid,
        needsVerification: _needsVerification,
        hasOutputs: _hasOutputs,
      ),
    );
  }

  void _refresh() {
    _load();
  }

  Future<void> _addPerson() async {
    final saved = await showPersonEditor(context);
    if (saved) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: SearchBarField(onChanged: _search)),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addPerson,
                  icon: const Icon(Icons.add),
                  label: const Text('Add person'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView<List<Map<String, dynamic>>>(
              future: _people,
              builder: (context, people) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${people.length} people',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: people.isEmpty
                          ? const Center(child: Text('No people found'))
                          : ListView.builder(
                              itemCount: people.length,
                              itemBuilder: (context, index) {
                                final person = people[index];
                                return PersonCard(
                                  name:
                                      person['preferred_name'] as String? ??
                                      'Unnamed',
                                  membershipType:
                                      person['membership_type'] as String?,
                                  status: person['status'] as String?,
                                  onTap: () =>
                                      context.go('/people/${person['id']}'),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        filterDropdown(
          'Membership',
          _membershipType,
          membershipTypes, // Layer-1 values (integrated/collaborator/external)
          (value) {
            _membershipType = value;
            _load();
          },
        ),
        filterDropdown(
          'Status',
          _status,
          const ['a_confirmar', 'active', 'inactive'],
          (value) {
            _status = value;
            _load();
          },
        ),
        filterDropdown(
          'Profile',
          _profileStatus,
          const ['draft', 'pending_review', 'approved'],
          (value) {
            _profileStatus = value;
            _load();
          },
        ),
        FilterChip(
          label: const Text('Missing ORCID'),
          selected: _missingOrcid,
          onSelected: (value) {
            _missingOrcid = value;
            _load();
          },
        ),
        FilterChip(
          label: const Text('Needs verification'),
          selected: _needsVerification,
          onSelected: (value) {
            _needsVerification = value;
            _load();
          },
        ),
        FilterChip(
          label: const Text('Has outputs'),
          selected: _hasOutputs,
          onSelected: (value) {
            _hasOutputs = value;
            _load();
          },
        ),
      ],
    );
  }
}
