import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/panels.dart';

/// Pure: the signature text for the Copy button and the preview.
String signatureText({
  required String name,
  required String role,
  required String email,
  required String phone,
}) => [
  name.isEmpty ? 'Name Surname' : name,
  role.isEmpty ? 'Role' : role,
  'IADE – Faculty of Design, Technology and Communication, Universidade Europeia',
  'Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide, Portugal',
  'E ${email.isEmpty ? 'email@universidadeeuropeia.pt' : email}${phone.isEmpty ? '' : ' · M $phone'} · iade.europeia.pt',
  'This work is supported by FCT, project UID/00711/2025 – UNIDCOM/IADE (DOI: 10.54499/UID/00711/2025)',
].join('\n');

class SignatureForm extends StatefulWidget {
  /// Null = anonymous visitor: empty form.
  const SignatureForm({super.key, required this.person});
  final Map<String, dynamic>? person;

  @override
  State<SignatureForm> createState() => _SignatureFormState();
}

class _SignatureFormState extends State<SignatureForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _sending = false;
  Map<String, String>? _sentSnapshot;
  late final Map<String, String?> _initialPerson;

  @override
  void initState() {
    super.initState();
    _initialPerson = {
      'preferred_name': widget.person?['preferred_name'] as String?,
      'job_title': widget.person?['job_title'] as String?,
      'email': widget.person?['email'] as String?,
      'phone': widget.person?['phone'] as String?,
    };
    _nameController = TextEditingController(
      text: _initialPerson['preferred_name'] ?? '',
    );
    _roleController = TextEditingController(
      text: _initialPerson['job_title'] ?? '',
    );
    _emailController = TextEditingController(
      text: _initialPerson['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: _initialPerson['phone'] ?? '',
    );

    _nameController.addListener(() => setState(() {}));
    _roleController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // After a send, the sent values are the baseline: a second send stages
  // only what changed since, not everything that differs from the DB row.
  Map<String, String?> get _current => _sentSnapshot ?? _initialPerson;

  Map<String, String> get _proposed => {
    'preferred_name': _nameController.text,
    'job_title': _roleController.text,
    'email': _emailController.text,
    'phone': _phoneController.text,
  };

  bool get _dirty {
    final baseline = _sentSnapshot ?? _current;
    return _nameController.text.trim() !=
            (baseline['preferred_name'] ?? '').trim() ||
        _roleController.text.trim() != (baseline['job_title'] ?? '').trim() ||
        _emailController.text.trim() != (baseline['email'] ?? '').trim() ||
        _phoneController.text.trim() != (baseline['phone'] ?? '').trim();
  }

  Future<void> _sendChanges() async {
    if (!mounted) return;
    final person = widget.person;
    if (person == null) return;

    setState(() => _sending = true);
    try {
      final n = await proposeMyChanges(
        person['id'] as String,
        _current,
        _proposed,
      );
      if (mounted) {
        showSnack(
          context,
          '$n change${n == 1 ? '' : 's'} sent to UNIDCOM for approval',
        );
        setState(() => _sentSnapshot = Map.from(_proposed));
      }
    } catch (error) {
      if (mounted) {
        showSnack(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Personalise your signature'),
      TextField(
        key: const Key('sig-name'),
        controller: _nameController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Full name',
          hintText: 'Name Surname',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('sig-role'),
        controller: _roleController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Role',
          hintText: 'e.g. Associate Professor',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('sig-email'),
        controller: _emailController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'name@universidadeeuropeia.pt',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('sig-phone'),
        controller: _phoneController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Mobile (optional)',
          hintText: '+351 …',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      if (widget.person != null) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('sig-send'),
          onPressed: _dirty && !_sending ? _sendChanges : null,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Send changes for approval'),
        ),
        const SizedBox(height: 8),
        mutedText(
          context,
          'Changes are applied to your profile once UNIDCOM approves them.',
        ),
      ],
      _heading('Preview'),
      Panel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nameController.text.isEmpty
                  ? 'Name Surname'
                  : _nameController.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _roleController.text.isEmpty ? 'Role' : _roleController.text,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [_brandTag('IADE', dark: true), _brandTag('UNIDCOM')],
            ),
            const SizedBox(height: 10),
            const Divider(color: AppColors.cardBorder, height: 1),
            const SizedBox(height: 10),
            SelectableText(
              'IADE – Faculty of Design, Technology and Communication, Universidade Europeia\n'
              'Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2 – 1885-081 Moscavide, Portugal\n'
              'E ${_emailController.text.isEmpty ? 'email@universidadeeuropeia.pt' : _emailController.text}${_phoneController.text.isEmpty ? '' : ' · M ${_phoneController.text}'} · iade.europeia.pt',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This work is supported by FCT, project UID/00711/2025 – UNIDCOM/IADE (DOI: 10.54499/UID/00711/2025)',
              style: TextStyle(
                color: AppColors.textFaint,
                fontSize: 10,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _copyButton(
                context,
                signatureText(
                  name: _nameController.text,
                  role: _roleController.text,
                  email: _emailController.text,
                  phone: _phoneController.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _heading(String text) => Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 10),
  child: Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  ),
);

Widget _copyButton(BuildContext context, String text, {String label = 'Copy'}) {
  return FilledButton(
    onPressed: () {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied')));
    },
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label),
  );
}

Widget _brandTag(String text, {bool dark = false}) => Padding(
  padding: const EdgeInsets.only(right: 10),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: dark ? AppColors.profileBand : AppColors.tealTint,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: dark ? AppColors.cardBg : AppColors.tealDark,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
);
