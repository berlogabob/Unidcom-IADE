import 'package:flutter/material.dart';
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
    // Signed out, there is no person to band for — the Welcome pack is the
    // only route reachable, and SideNav (in AppShell) is the whole nav now.
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    return Column(
      children: [
        if (!hasSession)
          _profileBand()
        else
          FutureBuilder<Map<String, dynamic>?>(
            future: _person,
            builder: (context, snapshot) => _profileBand(snapshot.data),
          ),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _profileBand([Map<String, dynamic>? person]) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.profileBand,
        border: Border(bottom: BorderSide(color: AppColors.tealDark, width: 2)),
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
    // Rui, 14 Aug: "add bio picture".
    final photo = (person['photo_url'] as String? ?? '').trim();
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
    final unit = [code, labName].where((value) => value.isNotEmpty).join(' — ');

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.teal,
          foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
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
