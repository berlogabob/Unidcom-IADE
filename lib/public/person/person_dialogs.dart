import 'package:flutter/material.dart';

import '../../data/supabase.dart';
import '../../widgets/detail_scaffold.dart';

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

Future<bool?> showPersonRoleDialog(BuildContext context, String personId) =>
    showDialog<bool>(
      context: context,
      builder: (context) => _RoleDialog(personId: personId),
    );

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
  static const _membershipTypes =
      membershipTypes; // canonical list (supabase.dart)
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
      showSnack(context, error.toString());
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
              editField(_preferredName, 'Preferred name'),
              editField(_legalName, 'Legal name'),
              editField(_bio, 'Bio', maxLines: 4),
              editField(_photoUrl, 'Photo URL'),
              editField(_email, 'Email'),
              editField(_orcid, 'ORCID'),
              editField(_cienciaId, 'Ciencia ID'),
              editField(_phd, 'PhD'),
              // ponytail: ISO text fields; swap to showDatePicker if typos bite.
              editField(_joinDate, 'Join date (YYYY-MM-DD)'),
              editField(_exitDate, 'Exit date (YYYY-MM-DD)'),
              editField(_integrationYear, 'Integration year'),
              if (widget.canEditGovernance) ...[
                editDropdown(
                  'Membership type',
                  _membershipType,
                  _membershipTypes,
                  (value) => setState(() => _membershipType = value!),
                ),
                editDropdown(
                  'Status',
                  _status,
                  _statuses,
                  (value) => setState(() => _status = value!),
                ),
                editDropdown(
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
      actions: editorActions(context, saving: _saving, onSave: _save),
    );
  }
}

/// Adds one logbook entry — a membership (Layer 1), or an optional role / tag /
/// mentorship (Layer 2) — for an optional year. Role/tag labels autocomplete
/// from existing values (add-new allowed); a mentorship student autocompletes
/// from people (or a new name). Owner adds land as pending; admin adds approved.
class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.personId});

  final String personId;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  String _kind = 'membership';
  String _membership = membershipTypes.first;
  String _value = ''; // typed/selected label for role/tag/mentorship
  final _year = TextEditingController(text: '${DateTime.now().year}');
  final _notes = TextEditingController();
  bool _saving = false;

  List<String> _roleVocab = const [];
  List<String> _tagVocab = const [];
  List<Map<String, dynamic>> _people = const [];

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    try {
      final results = await Future.wait([
        fetchRoleVocabulary('role'),
        fetchRoleVocabulary('tag'),
        fetchAllActivePeople(),
      ]);
      if (!mounted) return;
      setState(() {
        _roleVocab = results[0] as List<String>;
        _tagVocab = results[1] as List<String>;
        _people = results[2] as List<Map<String, dynamic>>;
      });
    } catch (_) {
      // Autocomplete just falls back to free text if vocab fails to load.
    }
  }

  @override
  void dispose() {
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _kind == 'membership' ? _membership : _value.trim();
    if (label.isEmpty) {
      showSnack(context, 'A value is required');
      return;
    }
    final yearText = _year.text.trim();
    final year = yearText.isEmpty ? null : int.tryParse(yearText);
    if (yearText.isNotEmpty && year == null) {
      showSnack(context, 'Year must be a number');
      return;
    }
    // For a mentorship, link the student to a person if the name matches one.
    String? linkId;
    if (_kind == 'mentorship') {
      for (final person in _people) {
        if ((person['preferred_name'] as String?)?.trim() == label) {
          linkId = person['id'] as String?;
          break;
        }
      }
    }
    setState(() => _saving = true);
    try {
      await addPersonRole(
        personId: widget.personId,
        kind: _kind,
        label: label,
        year: year,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        linkId: linkId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showSnack(context, error.toString());
      setState(() => _saving = false);
    }
  }

  InputDecoration _deco(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  /// A search-as-you-type field over [options], allowing a typed new value.
  Widget _autocomplete(String label, List<String> options) {
    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((option) => option.toLowerCase().contains(query));
      },
      onSelected: (selection) => _value = selection,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: _deco('$label (type to search or add new)'),
          onChanged: (text) => _value = text,
          onSubmitted: (_) => onSubmitted(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add role or tag'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: _deco('Kind'),
              items: const [
                DropdownMenuItem(
                  value: 'membership',
                  child: Text('Membership'),
                ),
                DropdownMenuItem(value: 'role', child: Text('Role')),
                DropdownMenuItem(value: 'tag', child: Text('Tag')),
                DropdownMenuItem(
                  value: 'mentorship',
                  child: Text('Mentorship'),
                ),
              ],
              onChanged: (value) => setState(() {
                _kind = value ?? 'membership';
                _value = '';
              }),
            ),
            const SizedBox(height: 12),
            if (_kind == 'membership')
              DropdownButtonFormField<String>(
                initialValue: _membership,
                decoration: _deco('Membership'),
                items: [
                  for (final type in membershipTypes)
                    DropdownMenuItem(
                      value: type,
                      child: Text(membershipLabels[type] ?? type),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _membership = value ?? membershipTypes.first,
                ),
              )
            else if (_kind == 'role')
              _autocomplete('Role', _roleVocab)
            else if (_kind == 'tag')
              _autocomplete('Tag', _tagVocab)
            else
              _autocomplete('Student', [
                for (final person in _people)
                  if (person['preferred_name'] != null)
                    person['preferred_name'] as String,
              ]),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: _deco('Year (blank = undated)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: _deco('Notes (optional)'),
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
