import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import 'nav_model.dart';

/// The one dark left-hand navigation every shell renders now — the desktop
/// column and the phone drawer are the same widget, just wrapped differently
/// by [AppShell]. Replaces the old top bar, the admin-only sidebar, the
/// bottom NavigationBar, the researcher tab strip and the Welcome pack's own
/// nav: one list, one look, everywhere.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.groups,
    required this.path,
    required this.header,
    required this.footer,
    this.badges = const {},
    this.onNavigate,
  });

  final List<NavGroup> groups;
  final String path;
  final Widget header; // wordmark + mode label
  final Widget footer; // account block + actions
  final Map<String, Future<int>> badges; // route → count (People, Requests)
  final VoidCallback? onNavigate; // drawer: pop after go

  @override
  Widget build(BuildContext context) {
    final active = navSelected(groups, path);
    return ColoredBox(
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                for (final group in groups) ...[
                  // Rui, 8 Sep (D4): headers must read as headers; a group
                  // with no label (the top one, in both navs) gets none.
                  if (group.label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        group.label.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  for (final item in group.items) ...[
                    _row(context, item, item == active, indent: 16),
                    // Always rendered, not just when active or an ancestor of
                    // the active route — the IA is small enough (max one
                    // level) that hiding them would cost more than it saves.
                    for (final child in item.children)
                      _row(
                        context,
                        child,
                        child == active,
                        indent: 28,
                        fontSize: 13,
                      ),
                  ],
                ],
              ],
            ),
          ),
          footer,
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    NavItem item,
    bool isActive, {
    required double indent,
    double fontSize = 14,
  }) {
    final color = isActive ? AppColors.textOnDark : AppColors.textOnDarkMuted;
    return InkWell(
      onTap: () {
        context.go(item.route);
        onNavigate?.call();
      },
      child: Container(
        key: isActive ? const Key('nav-active') : null,
        height: 44,
        padding: EdgeInsets.only(
          left: isActive ? indent - 3 : indent,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.06) : null,
          border: isActive
              ? const Border(left: BorderSide(color: AppColors.teal, width: 3))
              : null,
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, color: color, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (badges.containsKey(item.route))
              FutureBuilder<int>(
                future: badges[item.route],
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 18,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
