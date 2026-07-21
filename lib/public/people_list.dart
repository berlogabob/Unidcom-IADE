import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../widgets/person_card.dart';
import '../widgets/search_bar.dart';

class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key});

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  Timer? _debounce;
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _people = fetchPeople(query: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SearchBarField(onChanged: _search),
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
                if (people.isEmpty) {
                  return const Center(child: Text('No people found'));
                }

                return ListView.builder(
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return PersonCard(
                      name: person['preferred_name'] as String? ?? 'Unnamed',
                      membershipType: person['membership_type'] as String?,
                      status: person['status'] as String?,
                      onTap: () => context.go('/people/${person['id']}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
