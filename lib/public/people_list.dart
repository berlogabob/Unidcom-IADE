import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import 'person_page.dart';
import '../widgets/person_card.dart';
import '../widgets/search_bar.dart';

class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key});

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  Timer? _debounce;
  String _query = '';
  String? _membershipType;
  String? _status;
  String? _profileStatus;
  bool _missingOrcid = false;
  bool _needsVerification = false;
  bool _hasOutputs = false;
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _people,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final people = snapshot.data ?? [];

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
        _dropdown(
          'Membership',
          _membershipType,
          membershipTypes, // Layer-1 values (integrated/collaborator/external)
          (value) {
            _membershipType = value;
            _load();
          },
        ),
        _dropdown(
          'Status',
          _status,
          const ['a_confirmar', 'active', 'inactive'],
          (value) {
            _status = value;
            _load();
          },
        ),
        _dropdown(
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

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All')),
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
