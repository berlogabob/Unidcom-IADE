import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../widgets/ds_page.dart';
import '../../widgets/featured_readonly.dart';
import '../../widgets/info_tip.dart';
import '../../widgets/orcid_block.dart';
import '../../widgets/panels.dart';
import '../../widgets/status_line.dart';

class MyProfileView extends StatefulWidget {
  const MyProfileView({
    super.key,
    required this.person,
    required this.labs,
    required this.featured,
    this.orcid,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onConnectOrcid,
    required this.onUploadPhoto,
    required this.onManageFeatured,
    this.readOnly = false,
  });

  final Map<String, dynamic> person;
  final List<String> labs;
  final List<Map<String, dynamic>> featured;
  final Map<String, String>? orcid;
  final Future<void> Function(Map<String, String>) onSaveDraft;
  final Future<void> Function(Map<String, String>) onSubmit;
  final VoidCallback onConnectOrcid;
  final VoidCallback onUploadPhoto;
  final VoidCallback onManageFeatured;
  final bool readOnly;

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> {
  late final _name = TextEditingController(text: _value('preferred_name'));
  late final _ciencia = TextEditingController(text: _value('ciencia_id'));
  late final _email = TextEditingController(text: _value('email'));
  late final _bio = TextEditingController(text: _value('bio'));

  String _value(String key) => widget.person[key] as String? ?? '';

  @override
  void dispose() {
    _name.dispose();
    _ciencia.dispose();
    _email.dispose();
    _bio.dispose();
    super.dispose();
  }

  Map<String, String> _changed() {
    final values = {
      'preferred_name': _name.text.trim(),
      'ciencia_id': _ciencia.text.trim(),
      'email': _email.text.trim(),
      'bio': _bio.text.trim(),
    };
    return {
      for (final entry in values.entries)
        if (entry.value != _value(entry.key).trim()) entry.key: entry.value,
    };
  }

  Future<void> _save(
    Future<void> Function(Map<String, String>) action,
    String message,
  ) async {
    await action(_changed());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _importOrcid() async {
    var count = 0;
    final fields = {
      'preferred_name': _name,
      'ciencia_id': _ciencia,
      'email': _email,
      'bio': _bio,
    };
    for (final MapEntry(:key, value: controller) in fields.entries) {
      final value = widget.orcid?[key]?.trim() ?? '';
      if (value.isEmpty || value == controller.text.trim()) continue;
      controller.text = value;
      count++;
    }
    setState(() {});

    final message = count == 0
        ? 'Your profile already matches ORCID.'
        : '$count ${count == 1 ? 'field' : 'fields'} filled in from ORCID — check them, then Submit for UNIDCOM review.';

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orcid = _value('orcid').trim();
    final role = _value('job_title').trim().isNotEmpty
        ? _value('job_title').trim()
        : memberLabel(widget.person['membership_type'] as String?);
    final photo = _value('photo_url').trim();
    final synced = DateTime.tryParse(_value('orcid_synced_at'));
    final bioDiffers =
        widget.orcid?['bio'] != null &&
        widget.orcid!['bio']!.trim() != _bio.text.trim();

    final action = widget.readOnly
        ? null
        : Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => _save(
                  widget.onSaveDraft,
                  'Draft saved — not sent to UNIDCOM yet',
                ),
                child: const Text('Save draft'),
              ),
              const InfoTip(
                text:
                    'Keeps your changes here without sending them to UNIDCOM.',
              ),
              FilledButton(
                onPressed: () =>
                    _save(widget.onSubmit, 'Sent for UNIDCOM review'),
                child: const Text('Submit for UNIDCOM review'),
              ),
              const InfoTip(
                text: 'Saved changes will be re-submitted for UNIDCOM review.',
              ),
            ],
          );

    return DsPage(
      title: 'My Profile',
      subtitle:
          'Your public researcher profile on the UNIDCOM website. UNIDCOM reviews before publishing.',
      action: action,
      children: [
        OrcidBlock(
          connected: orcid.isNotEmpty,
          lastImported: synced,
          onImport: _importOrcid,
          onConnect: widget.onConnectOrcid,
        ),
        DsRow(
          left: Panel(
            title: 'Identity & bio',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: photo.isEmpty
                          ? null
                          : NetworkImage(photo),
                      child: photo.isEmpty
                          ? Text(_initials(_value('preferred_name')))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: widget.readOnly ? null : widget.onUploadPhoto,
                      child: const Text('Upload photo'),
                    ),
                    const SizedBox(width: 6),
                    const InfoTip(text: 'Upload a photo for UNIDCOM review.'),
                  ],
                ),
                const SizedBox(height: 10),
                WithInfo(
                  info: 'Your public name and role.',
                  child: Text(
                    [
                      _value('preferred_name').trim(),
                      role.isEmpty ? 'Researcher' : role,
                    ].where((value) => value.isNotEmpty).join(' · '),
                  ),
                ),
                const SizedBox(height: 8),
                _field('Name', _name, 'The name shown on your public profile.'),
                _field('Ciência ID', _ciencia, 'Your Ciência ID identifier.'),
                DsField(
                  label: 'Lab / cluster',
                  info: 'Your current UNIDCOM lab or cluster memberships.',
                  child: Text(
                    widget.labs.isEmpty ? '—' : widget.labs.join(', '),
                  ),
                ),
                _field(
                  'Email',
                  _email,
                  'The contact email shown on your profile.',
                ),
                DsField(
                  label: 'ORCID iD',
                  info:
                      'Your ORCID identifier. It is set when you connect ORCID.',
                  child: Text(orcid.isEmpty ? 'Not connected' : orcid),
                ),
                DsField(
                  label: 'Bio',
                  info:
                      'Shown on your public page. Changes go to UNIDCOM review.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _bio,
                        readOnly: widget.readOnly,
                        minLines: 4,
                        maxLines: null,
                        maxLength: 300,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) {
                              final over = currentLength > 300;
                              return Text(
                                '$currentLength / 300${over ? ' · the website shows the first 300' : ''}',
                                style: TextStyle(
                                  color: over ? AppColors.amberDark : null,
                                ),
                              );
                            },
                      ),
                      if (bioDiffers)
                        TextButton(
                          onPressed: widget.readOnly
                              ? null
                              : () => setState(
                                  () => _bio.text = widget.orcid!['bio']!,
                                ),
                          child: const Text('Import bio from ORCID →'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          right: Panel(
            title: 'Featured outputs (${widget.featured.length}/5)',
            child: FeaturedReadOnly(
              featured: widget.featured,
              showHeader: false,
              onManage: widget.onManageFeatured,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, String info) =>
      DsField(
        label: label,
        info: info,
        child: TextField(
          controller: controller,
          readOnly: widget.readOnly,
          decoration: const InputDecoration(isDense: true),
        ),
      );

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final list = words.toList();
    return list.isEmpty
        ? '?'
        : list.take(2).map((word) => word[0].toUpperCase()).join();
  }
}
