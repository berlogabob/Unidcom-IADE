import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../widgets/panels.dart';
import 'welcome_pack_content.dart';

const _sectionGroups = [
  ('Start', [('start', 'Welcome Pack 2026')]),
  (
    'Communication',
    [('signature', 'Email signature'), ('social', 'Social media')],
  ),
  (
    'Support',
    [
      ('docs', 'Documents & forms'),
      ('conf', 'Conferences'),
      ('oa', 'Open Access'),
      ('missions', 'Missions'),
    ],
  ),
  (
    'Obligations',
    [('affiliation', 'Affiliation statement'), ('report', 'Report activity')],
  ),
  ('Resources', [('logos', 'Logos & brand'), ('contacts', 'Contacts')]),
];

class WelcomePackPage extends StatelessWidget {
  const WelcomePackPage({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: SingleChildScrollView(child: _desktopNav(context)),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: welcomeSectionBody(context, section),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final group in _sectionGroups)
                      for (final item in group.$2) ...[
                        FilterPill(
                          item.$2,
                          selected: section == item.$1,
                          onTap: () => _go(context, item.$1),
                        ),
                        const SizedBox(width: 8),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              welcomeSectionBody(context, section),
            ],
          ),
        );
      },
    );
  }

  Widget _desktopNav(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (
            var groupIndex = 0;
            groupIndex < _sectionGroups.length;
            groupIndex++
          ) ...[
            if (groupIndex > 0) const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Text(
                _sectionGroups[groupIndex].$1.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final item in _sectionGroups[groupIndex].$2)
              _desktopLink(context, item.$1, item.$2),
          ],
        ],
      ),
    );
  }

  Widget _desktopLink(BuildContext context, String slug, String title) {
    final active = section == slug;
    return Material(
      color: active ? AppColors.sandHover : Colors.transparent,
      child: InkWell(
        onTap: () => _go(context, slug),
        hoverColor: AppColors.sandHover,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? AppColors.teal : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: active ? AppColors.navy : AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String slug) {
    context.go('/app/welcome/$slug');
  }
}
