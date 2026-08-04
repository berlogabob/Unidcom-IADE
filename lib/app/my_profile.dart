import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/supabase.dart';
import '../public/person_page.dart';
import '../widgets/detail_scaffold.dart';

String profileStatusLabel(String? status) => switch (status) {
  'pending_review' => 'Awaiting UNIDCOM approval',
  'approved' => 'Approved',
  _ => 'Profile not confirmed',
};

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();
  Map<String, dynamic>? _person;
  bool _resolved = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      // Self-heals when an admin fills people.orcid after first ORCID login.
      await claimPersonByOrcid();
      final person = await fetchMyPerson();
      if (!mounted) return;
      setState(() {
        _person = person;
        _resolved = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _refresh() => _resolve();

  Future<void> _submitProfile() async {
    final person = _person;
    if (person == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await submitMyProfileForReview(person['id'] as String);
      if (!mounted) return;
      setState(() {
        _person = {...person, 'profile_status': 'pending_review'};
      });
      showSnack(context, 'Profile submitted for approval');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Adds ORCID as a login method for the signed-in account; if the person
  /// registry lists this iD, the profile is claimed server-side too.
  Future<void> _connectOrcid() async {
    try {
      final returnTo = kIsWeb
          ? '${Uri.base.origin}${Uri.base.path}'
          : 'https://berlogabob.github.io/Unidcom-IADE/';
      final url = await startOrcidLink(returnTo);
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

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

    final person = _person;
    if (person != null) {
      final status = person['profile_status'] as String? ?? 'draft';
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(profileStatusLabel(status)),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (status == 'draft') ...[
                    const Text('Check your data below, then confirm'),
                    FilledButton(
                      onPressed: _submitting ? null : _submitProfile,
                      child: const Text('Confirm my profile'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ponytail: reuse the detail page; split only if own-profile UI diverges.
          Expanded(
            child: PersonPageScreen(
              key: ValueKey(status),
              id: person['id'] as String,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            title: Text('No researcher profile is linked to your account.'),
          ),
        ),
        if (!hasLinkedOrcid) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _connectOrcid,
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Connect ORCID'),
            ),
          ),
        ],
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
          AsyncView<List<Map<String, dynamic>>>(
            future: _people,
            builder: (context, people) {
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
