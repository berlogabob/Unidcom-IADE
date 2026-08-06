import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';

class PortalShell extends StatefulWidget {
  const PortalShell({super.key, required this.child});

  final Widget child;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  late final Future<Map<String, dynamic>?> _person = _loadPerson();

  Future<Map<String, dynamic>?> _loadPerson() async {
    final mine = await fetchMyPerson();
    return mine == null ? null : fetchPerson(mine['id'] as String);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) return widget.child;

        final path = GoRouterState.of(context).uri.path;
        // Signed out, the Welcome pack is the only one of these a visitor can
        // open — the other three are auth-gated, so offering them would be
        // three tabs that bounce straight to /login.
        final hasSession =
            Supabase.instance.client.auth.currentSession != null;
        final tabs = [
          if (hasSession) ...[
            ('Overview', '/app/home', path.startsWith('/app/home')),
            ('Outputs', '/app/profile', path == '/app/profile'),
            (
              'Support requests',
              '/app/requests',
              path.startsWith('/app/requests'),
            ),
          ],
          (
            'Welcome pack',
            '/app/welcome/start',
            path.startsWith('/app/welcome'),
          ),
        ];

        return Column(
          children: [
            if (!hasSession)
              _profileBand()
            else
              FutureBuilder<Map<String, dynamic>?>(
                future: _person,
                builder: (context, snapshot) => _profileBand(snapshot.data),
              ),
            Material(
              color: AppColors.cardBg,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const SizedBox(width: 28),
                        for (final tab in tabs)
                          InkWell(
                            onTap: () => context.go(tab.$2),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: tab.$3
                                        ? AppColors.teal
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                tab.$1,
                                style: TextStyle(
                                  color: tab.$3
                                      ? AppColors.navy
                                      : AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: tab.$3
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }

  Widget _profileBand([Map<String, dynamic>? person]) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.profileBand,
        border: Border(bottom: BorderSide(color: AppColors.teal, width: 2)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: person == null
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Researcher portal',
                        style: TextStyle(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : _profile(person),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profile(Map<String, dynamic> person) {
    final name = (person['preferred_name'] as String? ?? 'Researcher').trim();
    final role = switch (person['membership_type']) {
      'integrated' => 'Integrated researcher',
      'collaborator' => 'Collaborator',
      'external' => 'External researcher',
      _ => 'Researcher',
    };
    Map<String, dynamic>? currentLab;
    var currentYear = -1;
    for (final membership
        in person['lab_members'] as List<dynamic>? ?? const []) {
      if (membership is! Map || membership['labs'] is! Map) continue;
      final year = membership['year'] as int? ?? 0;
      if (year < currentYear) continue;
      currentYear = year;
      currentLab = Map<String, dynamic>.from(membership['labs'] as Map);
    }
    final code = (currentLab?['code'] as String? ?? '').trim();
    final labName = (currentLab?['name'] as String? ?? '').trim();
    final unit = [
      code,
      labName,
    ].where((value) => value.isNotEmpty).join(' — ');

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.teal,
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppColors.profileBand,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textOnDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$role · ${unit.isEmpty ? 'UNIDCOM / IADE' : unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textOnDarkMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
