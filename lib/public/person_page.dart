import 'package:flutter/material.dart';

import '../data/supabase.dart';
import '../widgets/output_row.dart';

class PersonPageScreen extends StatefulWidget {
  const PersonPageScreen({super.key, required this.id});

  final String id;

  @override
  State<PersonPageScreen> createState() => _PersonPageScreenState();
}

class _PersonPageScreenState extends State<PersonPageScreen> {
  late Future<Map<String, dynamic>> _person = fetchPerson(widget.id);

  void _refresh() {
    setState(() => _person = fetchPerson(widget.id));
  }

  Future<void> _approve() async {
    await approvePerson(widget.id);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile approved')));
  }

  Future<void> _edit(Map<String, dynamic> person) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PersonEditDialog(person: person),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _person,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        final person = snapshot.data ?? {};
        final admin = isAdmin;
        final outputAuthors = (person['output_authors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final tags = (person['person_tags'] as List<dynamic>? ?? [])
            .map(
              (tag) =>
                  (tag as Map<String, dynamic>)['tags']
                      as Map<String, dynamic>?,
            )
            .map((tag) => tag?['name'] as String?)
            .whereType<String>()
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              person['preferred_name'] as String? ?? 'Unnamed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (admin) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _edit(person),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  FilledButton.icon(
                    onPressed: _approve,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (person['membership_type'] != null)
                  Chip(label: Text(person['membership_type'] as String)),
                if (person['status'] != null)
                  Chip(label: Text(person['status'] as String)),
              ],
            ),
            if (person['email'] != null) ...[
              const SizedBox(height: 8),
              Text(person['email'] as String),
            ],
            if (person['bio'] != null &&
                (person['bio'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(person['bio'] as String),
            ],
            const SizedBox(height: 24),
            Text('Outputs', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (outputAuthors.isEmpty)
              const Text('No outputs found')
            else
              for (final author in outputAuthors)
                OutputRow(
                  title:
                      (author['outputs'] as Map<String, dynamic>?)?['title']
                          as String? ??
                      'Untitled',
                  year:
                      (author['outputs']
                              as Map<String, dynamic>?)?['reporting_year']
                          as int?,
                  type:
                      (author['outputs'] as Map<String, dynamic>?)?['type']
                          as String?,
                  detail: author['role'] as String?,
                ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Tags', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in tags) Chip(label: Text(tag))],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PersonEditDialog extends StatefulWidget {
  const _PersonEditDialog({required this.person});

  final Map<String, dynamic> person;

  @override
  State<_PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<_PersonEditDialog> {
  static const _membershipTypes = [
    'integrated',
    'collaborator',
    'external',
    'staff',
    'advisory_board',
  ];
  static const _statuses = ['a_confirmar', 'active', 'inactive'];
  static const _profileStatuses = ['draft', 'pending_review', 'approved'];

  late final _preferredName = _controller('preferred_name');
  late final _legalName = _controller('legal_name');
  late final _bio = _controller('bio');
  late final _photoUrl = _controller('photo_url');
  late final _email = _controller('email');
  late final _orcid = _controller('orcid');
  late final _cienciaId = _controller('ciencia_id');
  late String _membershipType =
      widget.person['membership_type'] as String? ?? _membershipTypes.first;
  late String _status = widget.person['status'] as String? ?? _statuses.first;
  late String _profileStatus =
      widget.person['profile_status'] as String? ?? _profileStatuses.first;
  late bool _publicVisibility =
      widget.person['public_visibility'] as bool? ?? false;
  bool _saving = false;

  TextEditingController _controller(String key) =>
      TextEditingController(text: widget.person[key] as String? ?? '');

  @override
  void dispose() {
    for (final controller in [
      _preferredName,
      _legalName,
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
      await updatePerson(widget.person['id'] as String, {
        'preferred_name': _preferredName.text.trim(),
        'legal_name': _text(_legalName),
        'bio': _text(_bio),
        'photo_url': _text(_photoUrl),
        'email': _text(_email),
        'orcid': _text(_orcid),
        'ciencia_id': _text(_cienciaId),
        'membership_type': _membershipType,
        'status': _status,
        'profile_status': _profileStatus,
        'public_visibility': _publicVisibility,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit researcher'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_preferredName, 'Preferred name'),
              _field(_legalName, 'Legal name'),
              _field(_bio, 'Bio', maxLines: 4),
              _field(_photoUrl, 'Photo URL'),
              _field(_email, 'Email'),
              _field(_orcid, 'ORCID'),
              _field(_cienciaId, 'Ciencia ID'),
              _dropdown(
                'Membership type',
                _membershipType,
                _membershipTypes,
                (value) => setState(() => _membershipType = value!),
              ),
              _dropdown(
                'Status',
                _status,
                _statuses,
                (value) => setState(() => _status = value!),
              ),
              _dropdown(
                'Profile status',
                _profileStatus,
                _profileStatuses,
                (value) => setState(() => _profileStatus = value!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Public visibility'),
                value: _publicVisibility,
                onChanged: (value) => setState(() => _publicVisibility = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
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
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : values.first,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
