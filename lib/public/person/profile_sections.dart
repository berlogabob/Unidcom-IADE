import 'package:flutter/material.dart';

import '../../widgets/detail_scaffold.dart';

Widget personHeader(
  BuildContext context,
  Map<String, dynamic> person, {
  required bool admin,
  required bool isOwner,
  required bool hasLinkedOrcid,
  required bool enriching,
  required bool syncing,
  required VoidCallback onEdit,
  required VoidCallback onConnectOrcid,
  required VoidCallback onAutoFill,
  required VoidCallback onCheckOrcidSync,
  required VoidCallback onApprove,
}) {
  final name = person['preferred_name'] as String? ?? 'Unnamed';
  final photo = (person['photo_url'] as String? ?? '').trim();
  final theme = Theme.of(context);

  return EntityHeaderCard(
    leading: CircleAvatar(
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
    title: name,
    subtitle: person['legal_name'] as String?,
    chips: statusChips([
      person['membership_type'],
      person['status'],
      person['profile_status'],
    ]),
    onEdit: (admin || isOwner) ? onEdit : null,
    actions: [
      if (isOwner && !hasLinkedOrcid)
        OutlinedButton.icon(
          onPressed: onConnectOrcid,
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Connect ORCID'),
        ),
      if (admin)
        FilledButton.icon(
          onPressed: enriching ? null : onAutoFill,
          icon: enriching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high),
          label: Text(enriching ? 'Loading...' : 'Auto-fill'),
        ),
      if (admin)
        OutlinedButton.icon(
          onPressed: syncing ? null : onCheckOrcidSync,
          icon: syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(syncing ? 'Checking...' : 'ORCID sync'),
        ),
      if (admin)
        FilledButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
        ),
    ],
  );
}

List<Widget> personInfoSections(
  BuildContext context,
  Map<String, dynamic> person,
  List<Map<String, dynamic>> labMemberships, {
  required ValueChanged<String> onOpen,
  required ValueChanged<String> onOpenLab,
}) => [
  const SizedBox(height: 24),
  sectionHeader(context, 'Identifiers'),
  const SizedBox(height: 8),
  _identifiers(context, person, onOpen),
  const SizedBox(height: 24),
  sectionHeader(context, 'About'),
  const SizedBox(height: 8),
  _bio(context, person),
  const SizedBox(height: 24),
  if (labMemberships.isNotEmpty) ...[
    sectionHeader(context, 'Labs'),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final membership in labMemberships)
          _labChip(membership, onOpenLab),
      ],
    ),
    const SizedBox(height: 24),
  ],
];

Widget _identifiers(
  BuildContext context,
  Map<String, dynamic> person,
  ValueChanged<String> onOpen,
) {
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
            ? mutedText(context, 'Not set')
            : _link(context, email, 'mailto:$email', onOpen),
      ),
      _InfoRow(
        icon: Icons.badge_outlined,
        label: 'ORCID',
        child: orcid.isEmpty
            ? mutedText(context, 'Not set')
            : _link(context, orcid, 'https://orcid.org/$orcid', onOpen),
      ),
      _InfoRow(
        icon: Icons.fingerprint,
        label: 'Ciência ID',
        child: ciencia.isEmpty
            ? mutedText(context, 'Not set')
            : _link(
                context,
                ciencia,
                'https://www.cienciavitae.pt/portal/$ciencia',
                onOpen,
              ),
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
        child: mutedText(
          context,
          joined.isNotEmpty
              ? joined
              : (person['integration_year']?.toString() ?? '—'),
        ),
      ),
      if (left.isNotEmpty)
        _InfoRow(
          icon: Icons.logout,
          label: 'Left',
          child: mutedText(context, left),
        ),
      _InfoRow(
        icon: Icons.verified_outlined,
        label: 'Last verified',
        child: mutedText(
          context,
          verified == null ? 'Never' : verified.split('T').first,
        ),
      ),
    ],
  );
}

Widget _bio(BuildContext context, Map<String, dynamic> person) {
  final bio = (person['bio'] as String? ?? '').trim();
  final notes = (person['notes'] as String? ?? '').trim();
  if (bio.isEmpty && notes.isEmpty) return mutedText(context, 'No bio yet');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (bio.isNotEmpty) Text(bio),
      if (notes.isNotEmpty) ...[
        if (bio.isNotEmpty) const SizedBox(height: 8),
        mutedText(context, notes),
      ],
    ],
  );
}

Widget _labChip(
  Map<String, dynamic> membership,
  ValueChanged<String> onOpenLab,
) {
  final lab = membership['labs'] as Map<String, dynamic>;
  final coordinator = membership['is_coordinator'] as bool? ?? false;
  final year = membership['year'] as int?;
  final code = lab['code'] as String? ?? lab['name'] as String? ?? '—';
  return InputChip(
    avatar: coordinator ? const Icon(Icons.star, size: 16) : null,
    label: Tooltip(
      message: coordinator
          ? '${lab['name']} (coordinator, $year)'
          : '${lab['name']} ($year)',
      child: Text(year == null ? code : '$code · $year'),
    ),
    onPressed: () => onOpenLab(lab['id'].toString()),
  );
}

Widget _link(
  BuildContext context,
  String text,
  String url,
  ValueChanged<String> onOpen,
) => InkWell(
  onTap: () => onOpen(url),
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
