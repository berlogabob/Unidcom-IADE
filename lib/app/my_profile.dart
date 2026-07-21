import 'package:flutter/material.dart';

import '../data/supabase.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late Future<Map<String, dynamic>?> _person = fetchMyPerson();
  late Future<List<Map<String, dynamic>>> _people = fetchPeople();

  void _refresh() {
    setState(() => _person = fetchMyPerson());
  }

  Future<void> _link(String id) async {
    await linkPersonToMe(id);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile linked')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _person,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final person = snapshot.data;
          if (person != null) {
            return _MyProfileForm(person: person);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  title: Text(
                    'No researcher profile is linked to your account.',
                  ),
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
                            onTap: () => _link(person['id'] as String),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MyProfileForm extends StatefulWidget {
  const _MyProfileForm({required this.person});

  final Map<String, dynamic> person;

  @override
  State<_MyProfileForm> createState() => _MyProfileFormState();
}

class _MyProfileFormState extends State<_MyProfileForm> {
  late final _preferredName = _controller('preferred_name');
  late final _bio = _controller('bio');
  late final _photoUrl = _controller('photo_url');
  late final _email = _controller('email');
  late final _orcid = _controller('orcid');
  late final _cienciaId = _controller('ciencia_id');
  bool _saving = false;

  TextEditingController _controller(String key) =>
      TextEditingController(text: widget.person[key] as String? ?? '');

  @override
  void dispose() {
    for (final controller in [
      _preferredName,
      _bio,
      _photoUrl,
      _email,
      _orcid,
      _cienciaId,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await updateMyProfile({
        'preferred_name': _preferredName.text.trim(),
        'bio': _text(_bio),
        'photo_url': _text(_photoUrl),
        'email': _text(_email),
        'orcid': _text(_orcid),
        'ciencia_id': _text(_cienciaId),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(_preferredName, 'Preferred name'),
        _field(_bio, 'Bio', maxLines: 5),
        _field(_photoUrl, 'Photo URL'),
        _field(_email, 'Email'),
        _field(_orcid, 'ORCID'),
        _field(_cienciaId, 'Ciencia ID'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ).copyWith(labelText: label),
      ),
    );
  }
}
