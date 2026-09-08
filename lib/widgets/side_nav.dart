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
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: collapsedGroups,
              builder: (context, collapsed, _) => ListView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                children: [
                  for (final group in groups) ...[
                    // Rui, 8 Sep (D4): headers must read as headers; a group
                    // with no label (the top one, in both navs) gets none
                    // and is never collapsible.
                    if (group.label.isNotEmpty)
                      _groupHeader(
                        context,
                        group,
                        isCollapsed: collapsed.contains(group.label),
                        isActive: _ownsActive(group, active),
                      ),
                    if (group.label.isEmpty || !collapsed.contains(group.label))
                      ..._items(context, group, active),
                  ],
                ],
              ),
            ),
          ),
          footer,
        ],
      ),
    );
  }

  bool _ownsActive(NavGroup group, NavItem? active) {
    if (active == null) return false;
    return group.items.contains(active) ||
        group.items.any((i) => i.children.contains(active));
  }

  List<Widget> _items(BuildContext context, NavGroup group, NavItem? active) =>
      [
        for (final item in group.items) ...[
          _row(context, item, item == active, indent: 16),
          // Always rendered, not just when active or an ancestor of the active
          // route — the admin IA is small enough (max one level) that hiding
          // them would cost more than it saves.
          for (final child in item.children)
            _row(context, child, child == active, indent: 28, fontSize: 13),
        ],
      ];

  /// A collapsible section header: uppercase label (tap → the section's
  /// landing route when it has one, else just toggle) plus a chevron that
  /// always toggles. When its group is collapsed the header itself takes the
  /// active styling, so the user can still see which section they're in.
  Widget _groupHeader(
    BuildContext context,
    NavGroup group, {
    required bool isCollapsed,
    required bool isActive,
  }) {
    final showActive = isActive && isCollapsed;
    final color = showActive ? AppColors.textOnDark : AppColors.textOnDarkMuted;
    return Container(
      key: Key('nav-group-${group.label}'),
      decoration: BoxDecoration(
        color: showActive ? Colors.white.withValues(alpha: 0.06) : null,
        border: showActive
            ? const Border(left: BorderSide(color: AppColors.teal, width: 3))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => group.route != null
                  ? context.go(group.route!)
                  : toggleGroup(group.label),
              child: Padding(
                padding: EdgeInsets.fromLTRB(showActive ? 13 : 16, 14, 0, 6),
                child: Text(
                  group.label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: Key('nav-toggle-${group.label}'),
            icon: Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              color: AppColors.textOnDarkMuted,
              size: 18,
            ),
            tooltip: isCollapsed ? 'Show section' : 'Hide section',
            onPressed: () => toggleGroup(group.label),
          ),
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
