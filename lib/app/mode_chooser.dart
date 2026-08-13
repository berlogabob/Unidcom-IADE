import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/supabase.dart';
import '../theme/tokens.dart';

/// Asked once per session, of admin accounts only.
///
/// Rui holds both jobs and the portal used to hand him both at once:
/// "this page I see is the unidcom admin or researcher admin?" / "im both" /
/// "its same page for 2 things" / "well need ot change that" (2026-08-10).
/// One question up front is what lets every screen after it be unambiguous.
///
/// A plain researcher never sees this — [needsModeChoice] is false for them and
/// they land on the Welcome pack exactly as before.
class ModeChooserScreen extends StatelessWidget {
  const ModeChooserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How do you want to continue?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can switch at any time from your name, top right.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _ModeCard(
                      icon: Icons.person_outline,
                      title: 'As a researcher',
                      body: 'Your profile, your outputs and the welcome pack. '
                          'Nothing else.',
                      onTap: () => _choose(context, ViewMode.researcher),
                    ),
                    _ModeCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'As an administrator',
                      body: 'The whole centre — people, outputs, structure, '
                          'review queues and reports.',
                      onTap: () => _choose(context, ViewMode.admin),
                    ),
                  ];
                  if (constraints.maxWidth < 560) {
                    return Column(
                      children: [
                        for (final card in cards) ...[
                          card,
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  // IntrinsicHeight, not a bare stretch: the Row sits in a
                  // scroll view, so its cross axis is unbounded and stretch
                  // alone asks a child to lay out against infinity.
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Setting [viewMode] wakes the router's refreshListenable, which re-evaluates
/// the redirect — so the `go` below only has to name the landing, and the shell
/// swaps itself. Same one-decision-point rule the sign-in path follows.
void _choose(BuildContext context, ViewMode mode) {
  viewMode.value = mode;
  modeChosen = true;
  context.go(mode == ViewMode.admin ? '/app/dashboard' : '/app/welcome/start');
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(AppDims.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDims.radius),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(AppDims.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: AppColors.tealDark),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
