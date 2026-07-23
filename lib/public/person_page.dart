import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/orcid_update.dart';
import '../data/enrich_client.dart';
import '../data/supabase.dart';
import '../widgets/output_row.dart';
import '../widgets/suggestion_tile.dart';

Future<bool> showPersonEditor(
  BuildContext context, {
  Map<String, dynamic>? person,
  bool canEditGovernance = true,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => _PersonEditDialog(
          person: person,
          canEditGovernance: canEditGovernance,
        ),
      ) ??
      false;
}

class PersonPageScreen extends StatefulWidget {
  const PersonPageScreen({super.key, required this.id});

  final String id;

  @override
  State<PersonPageScreen> createState() => _PersonPageScreenState();
}

class _PersonPageScreenState extends State<PersonPageScreen> {
  late Future<Map<String, dynamic>> _person = fetchPerson(widget.id);
  late Future<List<Map<String, dynamic>>> _suggestions =
      fetchSuggestionsForPerson(widget.id);
  late Future<List<Map<String, dynamic>>> _mentorships = fetchMentorships(
    widget.id,
  );
  late Future<List<Map<String, dynamic>>> _roles = fetchPersonRoles(widget.id);
  bool _rolesByTag = false; // false = group by year, true = group by tag/kind
  bool _enriching = false;
  bool _syncing = false;

  void _refresh() {
    setState(() {
      _person = fetchPerson(widget.id);
      _suggestions = fetchSuggestionsForPerson(widget.id);
      _mentorships = fetchMentorships(widget.id);
      _roles = fetchPersonRoles(widget.id);
    });
  }

  Future<void> _acceptSuggestion(String id) async {
    await acceptSuggestion(id);
    _refresh();
  }

  Future<void> _rejectSuggestion(String id) async {
    await rejectSuggestion(id);
    _refresh();
  }

  Future<void> _approve() async {
    await approvePerson(widget.id);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile approved')));
  }

  Future<void> _edit(
    Map<String, dynamic> person, {
    required bool canEditGovernance,
  }) async {
    final saved = await showPersonEditor(
      context,
      person: person,
      canEditGovernance: canEditGovernance,
    );
    if (saved == true) _refresh();
  }

  Future<void> _autoFill(Map<String, dynamic> person) async {
    setState(() => _enriching = true);
    try {
      final incoming = await fetchOrcidValues(widget.id);
      if (!mounted) return;
      if (incoming == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ORCID profile found to pull from')),
        );
        return;
      }
      final applied = await showOrcidUpdateDialog(
        context,
        personId: widget.id,
        current: person,
        incoming: incoming,
      );
      if (applied && mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _checkOrcidSync() async {
    setState(() => _syncing = true);
    try {
      final status = await fetchOrcidSyncStatus(widget.id);
      if (!mounted) return;
      if (status == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ORCID on this profile to check')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => _OrcidSyncDialog(status: status),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Couldn't open link")));
    }
  }

  Widget _suggestionsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _suggestions,
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('Suggestions', style: Theme.of(context).textTheme.titleLarge),
            for (final suggestion in suggestions)
              SuggestionTile(
                suggestion: suggestion,
                showTitle: false,
                onAccept: () => _acceptSuggestion(suggestion['id'] as String),
                onReject: () => _rejectSuggestion(suggestion['id'] as String),
              ),
          ],
        );
      },
    );
  }

  static const _kindLabels = {
    'membership': 'Membership',
    'tag': 'Tag',
    'role': 'Role',
  };

  String _roleValue(Map<String, dynamic> role) {
    final label = role['label'] as String? ?? '';
    if (role['kind'] == 'membership') return membershipLabels[label] ?? label;
    return label;
  }

  Widget _rolesSection(bool admin, bool isOwner) {
    final canEdit = admin || isOwner;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _roles,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('Roles & tags · ${roles.length}')),
                if (canEdit)
                  TextButton.icon(
                    onPressed: _addRole,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (roles.isNotEmpty)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('By year')),
                  ButtonSegment(value: true, label: Text('By tag')),
                ],
                selected: {_rolesByTag},
                onSelectionChanged: (s) =>
                    setState(() => _rolesByTag = s.first),
              ),
            const SizedBox(height: 8),
            if (roles.isEmpty)
              _muted('No roles or tags recorded')
            else if (_rolesByTag)
              ..._rolesByTagView(roles, admin, isOwner)
            else
              ..._rolesByYearView(roles, admin, isOwner),
          ],
        );
      },
    );
  }

  List<Widget> _rolesByYearView(
    List<Map<String, dynamic>> roles,
    bool admin,
    bool isOwner,
  ) {
    final byYear = <int?, List<Map<String, dynamic>>>{};
    for (final role in roles) {
      (byYear[role['year'] as int?] ??= []).add(role);
    }
    final years = byYear.keys.toList()
      ..sort((a, b) => (b ?? -1).compareTo(a ?? -1));
    return [
      for (final year in years) ...[
        Text(
          year?.toString() ?? 'Undated',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final role in byYear[year]!) _roleRow(role, admin, isOwner),
      ],
    ];
  }

  List<Widget> _rolesByTagView(
    List<Map<String, dynamic>> roles,
    bool admin,
    bool isOwner,
  ) {
    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final role in roles) {
      final key = '${_kindLabels[role['kind']] ?? role['kind']} · '
          '${_roleValue(role)}';
      (byKey[key] ??= []).add(role);
    }
    final keys = byKey.keys.toList()..sort();
    return [
      for (final key in keys) ...[
        Text(key, style: Theme.of(context).textTheme.titleSmall),
        for (final role in byKey[key]!) _roleRow(role, admin, isOwner),
      ],
    ];
  }

  Widget _roleRow(Map<String, dynamic> role, bool admin, bool isOwner) {
    final pending = role['status'] == 'pending';
    final kind = _kindLabels[role['kind']] ?? role['kind'] as String? ?? '';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('$kind · ${_roleValue(role)}'),
      subtitle: (role['notes'] as String?)?.isNotEmpty == true
          ? Text(role['notes'] as String)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending)
            const Chip(
              label: Text('pending'),
              visualDensity: VisualDensity.compact,
            ),
          if (admin && pending)
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check),
              onPressed: () async {
                await approvePersonRole(role['id'] as String);
                _refresh();
              },
            ),
          if (admin || isOwner)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () async {
                await removePersonRole(role['id'] as String);
                _refresh();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _addRole() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => _RoleDialog(personId: widget.id),
    );
    if (added == true && mounted) _refresh();
  }

  Widget _mentorshipsSection(Map<String, dynamic> person, bool admin) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _mentorships,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        // Group by year, newest first, so counts read per-year (2 in 2024, 4 in 2026…).
        final byYear = <int, List<Map<String, dynamic>>>{};
        for (final row in rows) {
          (byYear[row['year'] as int? ?? 0] ??= []).add(row);
        }
        final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('Mentorships · ${rows.length}')),
                if (admin)
                  TextButton.icon(
                    onPressed: _addMentorship,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              _muted('No mentorships recorded')
            else
              for (final year in years) ...[
                Text(
                  '$year · ${byYear[year]!.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final m in byYear[year]!)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(m['student_name'] as String? ?? 'Unnamed'),
                    subtitle: (m['notes'] as String?)?.isNotEmpty == true
                        ? Text(m['notes'] as String)
                        : null,
                    trailing: admin
                        ? IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await removeMentorship(m['id'] as String);
                              _refresh();
                            },
                          )
                        : null,
                  ),
              ],
          ],
        );
      },
    );
  }

  Future<void> _addMentorship() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => _MentorshipDialog(mentorId: widget.id),
    );
    if (added == true && mounted) _refresh();
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
        final isOwner =
            person['auth_user_id'] != null &&
            person['auth_user_id'] == db.auth.currentUser?.id;
        final outputAuthors = (person['output_authors'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final labMemberships = (person['lab_members'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .where((m) => m['labs'] is Map)
            .toList();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(person, admin, isOwner),
                if (admin) _suggestionsSection(),
                const SizedBox(height: 24),
                _sectionTitle('Identifiers'),
                const SizedBox(height: 8),
                _identifiers(person),
                const SizedBox(height: 24),
                _sectionTitle('About'),
                const SizedBox(height: 8),
                _bio(person),
                const SizedBox(height: 24),
                if (labMemberships.isNotEmpty) ...[
                  _sectionTitle('Labs'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in labMemberships)
                        () {
                          final lab = m['labs'] as Map<String, dynamic>;
                          final coordinator =
                              m['is_coordinator'] as bool? ?? false;
                          final year = m['year'] as int?;
                          final code =
                              lab['code'] as String? ??
                              lab['name'] as String? ??
                              '—';
                          return InputChip(
                            avatar: coordinator
                                ? const Icon(Icons.star, size: 16)
                                : null,
                            label: Tooltip(
                              message: coordinator
                                  ? '${lab['name']} (coordinator, $year)'
                                  : '${lab['name']} ($year)',
                              child: Text(year == null ? code : '$code · $year'),
                            ),
                            onPressed: () => context.go('/labs/${lab['id']}'),
                          );
                        }(),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                _sectionTitle('Outputs · ${outputAuthors.length}'),
                const SizedBox(height: 8),
                if (outputAuthors.isEmpty)
                  _muted('No outputs found')
                else
                  for (final author in outputAuthors) _outputRow(author),
                const SizedBox(height: 24),
                _rolesSection(admin, isOwner),
                const SizedBox(height: 24),
                _mentorshipsSection(person, admin),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Map<String, dynamic> person, bool admin, bool isOwner) {
    final name = person['preferred_name'] as String? ?? 'Unnamed';
    final legal = person['legal_name'] as String?;
    final photo = (person['photo_url'] as String? ?? '').trim();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
                  child: Text(
                    _initials(name),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.headlineSmall),
                      if (legal != null && legal.trim().isNotEmpty)
                        Text(
                          legal,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in [
                            person['membership_type'],
                            person['status'],
                            person['profile_status'],
                          ])
                            if (value != null)
                              Chip(
                                label: Text(value as String),
                                visualDensity: VisualDensity.compact,
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (admin || isOwner) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _edit(person, canEditGovernance: admin),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                  if (admin)
                    FilledButton.icon(
                      onPressed: _enriching ? null : () => _autoFill(person),
                      icon: _enriching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: Text(_enriching ? 'Loading...' : 'Auto-fill'),
                    ),
                  if (admin)
                    OutlinedButton.icon(
                      onPressed: _syncing ? null : _checkOrcidSync,
                      icon: _syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_syncing ? 'Checking...' : 'ORCID sync'),
                    ),
                  if (admin)
                    FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _identifiers(Map<String, dynamic> person) {
    final email = (person['email'] as String? ?? '').trim();
    final orcid = (person['orcid'] as String? ?? '').trim();
    final ciencia = (person['ciencia_id'] as String? ?? '').trim();
    final verified = person['last_verified_at'] as String?;
    final joined = (person['join_date'] as String? ?? '').trim();
    final left = (person['exit_date'] as String? ?? '').trim();

    return Column(
      children: [
        _InfoRow(
          icon: Icons.mail_outline,
          label: 'Email',
          child: email.isEmpty
              ? _muted('Not set')
              : _link(email, 'mailto:$email'),
        ),
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'ORCID',
          child: orcid.isEmpty
              ? _muted('Not set')
              : _link(orcid, 'https://orcid.org/$orcid'),
        ),
        _InfoRow(
          icon: Icons.fingerprint,
          label: 'Ciência ID',
          child: ciencia.isEmpty
              ? _muted('Not set')
              : _link(ciencia, 'https://www.cienciavitae.pt/portal/$ciencia'),
        ),
        if ((person['phd'] as String? ?? '').trim().isNotEmpty)
          _InfoRow(
            icon: Icons.school_outlined,
            label: 'PhD',
            child: Text(person['phd'] as String),
          ),
        _InfoRow(
          icon: Icons.login,
          label: 'Member since',
          child: _muted(
            joined.isNotEmpty
                ? joined
                : (person['integration_year']?.toString() ?? '—'),
          ),
        ),
        if (left.isNotEmpty)
          _InfoRow(icon: Icons.logout, label: 'Left', child: _muted(left)),
        _InfoRow(
          icon: Icons.verified_outlined,
          label: 'Last verified',
          child: _muted(verified == null ? 'Never' : verified.split('T').first),
        ),
      ],
    );
  }

  Widget _bio(Map<String, dynamic> person) {
    final bio = (person['bio'] as String? ?? '').trim();
    final notes = (person['notes'] as String? ?? '').trim();
    if (bio.isEmpty && notes.isEmpty) return _muted('No bio yet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bio.isNotEmpty) Text(bio),
        if (notes.isNotEmpty) ...[
          if (bio.isNotEmpty) const SizedBox(height: 8),
          _muted(notes),
        ],
      ],
    );
  }

  Widget _outputRow(Map<String, dynamic> author) {
    final output = author['outputs'] as Map<String, dynamic>?;
    if (output == null) return const SizedBox.shrink();
    return OutputRow(
      title: output['title'] as String? ?? 'Untitled',
      year: output['reporting_year'] as int?,
      type: output['type'] as String?,
      detail: author['role'] as String?,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.go('/outputs/${output['id']}'),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);

  Widget _muted(String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _link(String text, String url) => InkWell(
    onTap: () => _open(url),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    ),
  );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PersonEditDialog extends StatefulWidget {
  const _PersonEditDialog({this.person, this.canEditGovernance = true});

  final Map<String, dynamic>? person;

  // Owners (non-admins) edit their own profile but not governance/visibility;
  // those columns are also protected by a DB trigger for non-admins.
  final bool canEditGovernance;

  @override
  State<_PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<_PersonEditDialog> {
  static const _membershipTypes = membershipTypes; // canonical list (supabase.dart)
  static const _statuses = ['a_confirmar', 'active', 'inactive'];
  static const _profileStatuses = ['draft', 'pending_review', 'approved'];

  bool get _creating => widget.person?['id'] == null;

  late final _preferredName = _controller('preferred_name');
  late final _legalName = _controller('legal_name');
  late final _bio = _controller('bio');
  late final _photoUrl = _controller('photo_url');
  late final _email = _controller('email');
  late final _orcid = _controller('orcid');
  late final _cienciaId = _controller('ciencia_id');
  late final _phd = _controller('phd');
  late final _joinDate = _controller('join_date');
  late final _exitDate = _controller('exit_date');
  late final _integrationYear = _controller('integration_year');
  late String _membershipType =
      widget.person?['membership_type'] as String? ?? _membershipTypes.first;
  late String _status = widget.person?['status'] as String? ?? _statuses.first;
  late String _profileStatus =
      widget.person?['profile_status'] as String? ?? _profileStatuses.first;
  late bool _publicVisibility =
      widget.person?['public_visibility'] as bool? ?? false;
  bool _linkToMe = false;
  bool _saving = false;

  TextEditingController _controller(String key) =>
      TextEditingController(text: widget.person?[key]?.toString() ?? '');

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
      _phd,
      _joinDate,
      _exitDate,
      _integrationYear,
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
      final year = _integrationYear.text.trim();
      final fields = <String, dynamic>{
        'preferred_name': _preferredName.text.trim(),
        'legal_name': _text(_legalName),
        'bio': _text(_bio),
        'photo_url': _text(_photoUrl),
        'email': _text(_email),
        'orcid': _text(_orcid),
        'ciencia_id': _text(_cienciaId),
        'phd': _text(_phd),
        'join_date': _text(_joinDate),
        'exit_date': _text(_exitDate),
        'integration_year': year.isEmpty ? null : int.tryParse(year),
      };
      if (widget.canEditGovernance) {
        fields.addAll({
          'membership_type': _membershipType,
          'status': _status,
          'profile_status': _profileStatus,
          'public_visibility': _publicVisibility,
        });
      }
      if (_creating) {
        final id = await createPerson(fields);
        if (_linkToMe) await linkPersonToMe(id);
      } else {
        final id = widget.person!['id'] as String;
        await updatePerson(id, fields);
        await logChanges('person', id, widget.person!, fields);
        if (widget.canEditGovernance) {
          await upsertCurrentMembership(id, _membershipType);
        }
      }
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
      title: Text(_creating ? 'Add researcher' : 'Edit researcher'),
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
              _field(_phd, 'PhD'),
              // ponytail: ISO text fields; swap to showDatePicker if typos bite.
              _field(_joinDate, 'Join date (YYYY-MM-DD)'),
              _field(_exitDate, 'Exit date (YYYY-MM-DD)'),
              _field(_integrationYear, 'Integration year'),
              if (widget.canEditGovernance) ...[
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
                  onChanged: (value) =>
                      setState(() => _publicVisibility = value),
                ),
                if (_creating)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This is my profile (link to my login)'),
                    value: _linkToMe,
                    onChanged: (value) =>
                        setState(() => _linkToMe = value ?? false),
                  ),
              ],
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

/// Adds one mentorship for a given year. Student is a free-text name (a person
/// link can be added later); year defaults to the current year.
class _MentorshipDialog extends StatefulWidget {
  const _MentorshipDialog({required this.mentorId});

  final String mentorId;

  @override
  State<_MentorshipDialog> createState() => _MentorshipDialogState();
}

class _MentorshipDialogState extends State<_MentorshipDialog> {
  final _student = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year}');
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _student.dispose();
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _student.text.trim();
    final year = int.tryParse(_year.text.trim());
    if (name.isEmpty || year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student name and a valid year required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await addMentorship(
        mentorId: widget.mentorId,
        studentName: name,
        year: year,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
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
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return AlertDialog(
      title: const Text('Add mentorship'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _student, decoration: deco('Student name')),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: deco('Year'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: deco('Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Add'),
        ),
      ],
    );
  }
}

/// Adds one logbook entry: a membership (enum), a tag, or a custom role, for an
/// optional year. Owner adds land as pending; admin adds are approved.
class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.personId});

  final String personId;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  String _kind = 'membership';
  String _membership = membershipTypes.first;
  final _label = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year}');
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _kind == 'membership' ? _membership : _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A label is required')));
      return;
    }
    final yearText = _year.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);
    if (yearText.isNotEmpty && year == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Year must be a number')));
      return;
    }
    setState(() => _saving = true);
    try {
      await addPersonRole(
        personId: widget.personId,
        kind: _kind,
        label: label,
        year: year,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
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
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return AlertDialog(
      title: const Text('Add role or tag'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: deco('Kind'),
              items: const [
                DropdownMenuItem(value: 'membership', child: Text('Membership')),
                DropdownMenuItem(value: 'tag', child: Text('Tag')),
                DropdownMenuItem(value: 'role', child: Text('Role')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'membership'),
            ),
            const SizedBox(height: 12),
            if (_kind == 'membership')
              DropdownButtonFormField<String>(
                initialValue: _membership,
                decoration: deco('Membership'),
                items: [
                  for (final t in membershipTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(membershipLabels[t] ?? t),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _membership = v ?? membershipTypes.first),
              )
            else
              TextField(
                controller: _label,
                decoration: deco(_kind == 'tag' ? 'Tag' : 'Role'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: deco('Year (blank = undated)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: deco('Notes (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Add'),
        ),
      ],
    );
  }
}

/// Read-only ORCID drift preview: shows whether the person lists an IADE
/// affiliation on their public ORCID and how many works are on it — i.e. what a
/// future sync would push. The actual push is gated on ORCID membership +
/// per-researcher OAuth, so the push button is disabled with an explanation.
class _OrcidSyncDialog extends StatelessWidget {
  const _OrcidSyncDialog({required this.status});

  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    final affiliation = status['affiliationOnOrcid'] == true;
    final orgs = (status['orgNames'] as List?)?.cast<String>() ?? const [];
    final works = status['worksCount'] as int? ?? 0;
    final theme = Theme.of(context);

    Widget row(bool ok, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.green : theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return AlertDialog(
      title: const Text('ORCID sync'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('ORCID ${status['orcid']}'),
            const SizedBox(height: 12),
            row(
              affiliation,
              affiliation
                  ? 'IADE / UNIDCOM affiliation is on their ORCID record.'
                  : 'No IADE / UNIDCOM affiliation on ORCID — a sync would add it.',
            ),
            row(works > 0, 'Works on ORCID: $works'),
            if (orgs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Employers on ORCID', style: theme.textTheme.labelMedium),
              Text(orgs.join(', '), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Pushing to ORCID needs ORCID membership + the researcher to '
                'connect their ORCID (OAuth). Bio/name are never writable — only '
                'affiliation, works, funding and keywords. Not enabled yet.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        const FilledButton(
          onPressed: null, // gated until ORCID membership + OAuth are configured
          child: Text('Push to ORCID'),
        ),
      ],
    );
  }
}
