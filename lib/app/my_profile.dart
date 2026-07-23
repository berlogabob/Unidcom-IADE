import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';

// Resolver: the profile icon lands here, then redirects to the signed-in
// user's own public person page (/people/:id). Only the "no profile linked"
// fallback renders on-screen; editing lives on the person page itself.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();
  bool _resolved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final person = await fetchMyPerson();
      if (!mounted) return;
      if (person != null) {
        context.go('/people/${person['id']}');
      } else {
        setState(() => _resolved = true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _refresh() => _resolve();

  Future<void> _link(Map<String, dynamic> person) async {
    final name = person['preferred_name'] as String? ?? 'this profile';
    // ponytail: one-tap claim caused accidental mis-links ("checking" someone
    // else's account bound it to you). A confirm dialog is the whole fix.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link this profile to YOUR login?'),
        content: Text(
          'Your account will show "$name" as your own profile. '
          'Only do this to claim your OWN researcher profile — '
          'not to view or check someone else\'s account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Link to me'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await linkPersonToMe(person['id'] as String);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile linked')));
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped by AppShell (Scaffold + app bar + bottom nav) — no Scaffold here.
    if (_error != null) return Center(child: Text(_error!));
    if (!_resolved) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            title: Text('No researcher profile is linked to your account.'),
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 16),
          Text(
            'Link a profile',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search people',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _people = fetchPeople(query: value));
            },
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _people,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              }
              final people = snapshot.data ?? [];
              return Column(
                children: [
                  for (final person in people.take(20))
                    ListTile(
                      title: Text(
                        person['preferred_name'] as String? ?? 'Unnamed',
                      ),
                      subtitle: Text(person['email'] as String? ?? ''),
                      trailing: const Icon(Icons.link),
                      onTap: () => _link(person),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
