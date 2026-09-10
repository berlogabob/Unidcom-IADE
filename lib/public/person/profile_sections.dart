import 'package:flutter/material.dart';

import '../../app/my_profile.dart' show profileStatusLabel;
import '../../data/features.dart';
import '../../theme/tokens.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/queue_list.dart' show queueStatusLabel;

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
  final subtitle = (person['legal_name'] as String? ?? '').trim();
  final identifiers = [
    ('ORCID', (person['orcid'] as String? ?? '').trim()),
    ('Ciência ID', (person['ciencia_id'] as String? ?? '').trim()),
    ('Email', (person['email'] as String? ?? '').trim()),
  ];
  final membershipType = person['membership_type'] as String?;
  final status = person['status'] as String?;
  final profileStatus = person['profile_status'] as String?;
  final chips = statusChips([
    switch (membershipType) {
      'integrated' => 'Integrated researcher',
      'collaborator' => 'Collaborator',
      'external' => 'External researcher',
      final value? => queueStatusLabel(value),
      _ => null,
    },
    if (status != null && status != 'active') queueStatusLabel(status),
    if (profileStatus != null) profileStatusLabel(profileStatus),
  ]);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.profileBand,
          borderRadius: BorderRadius.all(Radius.circular(AppDims.radius)),
        ),
        child: Row(
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
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textOnDarkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (identifiers.any(
                    (identifier) => identifier.$2.isNotEmpty,
                  )) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, value) in identifiers)
                          if (value.isNotEmpty) _identifierPill(label, value),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      if (chips.isNotEmpty || admin || isOwner) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...chips,
            if (admin || isOwner)
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            if (isOwner && !hasLinkedOrcid)
              OutlinedButton.icon(
                onPressed: onConnectOrcid,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Connect ORCID'),
              ),
            // v2, all three. Rui, seeing them on his own profile band:
            // "you have three things that i think make noise - connect ORCID,
            // auto-fill, ORCID sync ... the approve button should not be
            // visible - we in UNIDCOM ADMIN make it visible every 6 months for
            // instance ... i would take it off at this stage - make it
            // invisible."
            //
            // Approve is doubly moot for now: every person row is already
            // approved, so the button's only effect is to look like unfinished
            // business. Nothing is deleted — person_page.dart still wires all
            // three handlers and a V2 build restores them.
            if (v2 && admin)
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
            if (v2 && admin)
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
            if (v2 && admin)
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
          ],
        ),
      ],
    ],
  );
}

Widget _identifierPill(String label, String value) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(AppDims.radiusSm),
  ),
  child: Text(
    '$label $value',
    style: const TextStyle(color: AppColors.textOnDark, fontSize: 12),
  ),
);

/// Researcher Identifiers leaf: ORCID, Ciência ID and the rest each get their
/// own heading, so the IA page and the ORCID Connect action both land under
/// the right one instead of one flat list.
List<Widget> personIdentifiersSections(
  BuildContext context,
  Map<String, dynamic> person, {
  required ValueChanged<String> onOpen,
  required VoidCallback onConnectOrcid,
  required bool showConnect,
}) => [
  sectionHeader(context, 'ORCID'),
  const SizedBox(height: 8),
  _orcidSection(context, person, onOpen, onConnectOrcid, showConnect),
  const SizedBox(height: 24),
  sectionHeader(context, 'Ciência ID'),
  const SizedBox(height: 8),
  _cienciaSection(context, person, onOpen),
  const SizedBox(height: 24),
  sectionHeader(context, 'Other Identifiers'),
  const SizedBox(height: 8),
  _otherIdentifiers(context, person, onOpen),
];

/// Biography leaf: the About heading plus bio/notes.
List<Widget> personBioSection(
  BuildContext context,
  Map<String, dynamic> person, {
  String? orcidBio,
  VoidCallback? onImportOrcid,
}) {
  final trimmedOrcidBio = orcidBio?.trim();
  if (trimmedOrcidBio == null || trimmedOrcidBio.isEmpty) {
    return [
      sectionHeader(context, 'About'),
      const SizedBox(height: 8),
      _bio(context, person),
    ];
  }
  if (trimmedOrcidBio == (person['bio'] as String? ?? '').trim()) {
    return [
      sectionHeader(context, 'About'),
      const SizedBox(height: 8),
      _bio(context, person),
      const SizedBox(height: 8),
      mutedText(context, 'Matches ORCID'),
    ];
  }

  Widget column(String heading, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionHeader(context, heading),
      const SizedBox(height: 8),
      child,
    ],
  );

  return [
    LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          column(
            'UNIDCOM biography',
            ((person['bio'] as String? ?? '').trim().isEmpty)
                ? mutedText(context, 'No bio yet')
                : Text((person['bio'] as String).trim()),
          ),
          column('ORCID biography', Text(trimmedOrcidBio)),
        ];
        return constraints.maxWidth >= 600
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: columns[0]),
                  const SizedBox(width: 24),
                  Expanded(child: columns[1]),
                ],
              )
            : Column(
                children: [columns[0], const SizedBox(height: 16), columns[1]],
              );
      },
    ),
    if (onImportOrcid != null) ...[
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onImportOrcid,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Import ORCID version'),
      ),
      mutedText(
        context,
        'Importing proposes the ORCID text to UNIDCOM; nothing changes until it is approved.',
      ),
    ],
  ];
}

/// Lab chips, grouped with Personal Information rather than the identifiers
/// list — membership is who-you-are, not an identifier to look someone up by.
List<Widget> personLabsSection(
  BuildContext context,
  List<Map<String, dynamic>> labMemberships, {
  required ValueChanged<String> onOpenLab,
}) => labMemberships.isEmpty
    ? const []
    : [
        const SizedBox(height: 24),
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
      ];

Widget _orcidSection(
  BuildContext context,
  Map<String, dynamic> person,
  ValueChanged<String> onOpen,
  VoidCallback onConnectOrcid,
  bool showConnect,
) {
  final orcid = (person['orcid'] as String? ?? '').trim();
  final syncedAt = (person['orcid_synced_at'] as String? ?? '').trim();
  final synced = syncedAt.isEmpty ? null : DateTime.tryParse(syncedAt);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoRow(
        icon: Icons.badge_outlined,
        label: 'ORCID',
        child: orcid.isEmpty
            ? mutedText(context, 'Not set')
            : _link(context, orcid, 'https://orcid.org/$orcid', onOpen),
      ),
      if (synced != null)
        _InfoRow(
          icon: Icons.sync,
          label: 'Last synchronised',
          child: mutedText(
            context,
            '${synced.day} ${months[synced.month - 1]} ${synced.year}',
          ),
        ),
      if (showConnect) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onConnectOrcid,
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Connect ORCID'),
        ),
      ],
    ],
  );
}

Widget _cienciaSection(
  BuildContext context,
  Map<String, dynamic> person,
  ValueChanged<String> onOpen,
) {
  final ciencia = (person['ciencia_id'] as String? ?? '').trim();
  return _InfoRow(
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
  );
}

Widget _otherIdentifiers(
  BuildContext context,
  Map<String, dynamic> person,
  ValueChanged<String> onOpen,
) {
  final email = (person['email'] as String? ?? '').trim();
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
      // M2 — Rui, 14 Aug: "Last verified → hide"
      if (v2)
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
