import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase.dart' as data;
import '../theme/tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final admin = data.isAdmin;
    final session = Supabase.instance.client.auth.currentSession;
    final hasSession = session != null;
    final destinations = [
      _NavItem('/people', Icons.people, 'People'),
      _NavItem(
        '/outputs',
        Icons.article,
        'Outputs',
        prefixes: ['/outputs', '/conferences'],
      ),
      _NavItem('/projects', Icons.work, 'Projects'),
      _NavItem(
        '/structure',
        Icons.account_tree,
        'Structure',
        prefixes: ['/structure', '/labs', '/clusters', '/objectives'],
      ),
      _NavItem('/app/dashboard', Icons.dashboard, 'Dashboard'),
      if (admin) _NavItem('/app/admin', Icons.admin_panel_settings, 'Admin'),
    ];
    final index = destinations.indexWhere(
      (item) => item.prefixes.any(path.startsWith),
    );
    final selectedIndex = index < 0 ? 0 : index;
    final sessionActions = hasSession
        ? [
            IconButton(
              tooltip: 'My profile',
              icon: const Icon(Icons.account_circle),
              onPressed: () => context.go('/app/profile'),
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          ]
        : [
            IconButton(
              tooltip: 'Sign in',
              icon: const Icon(Icons.login),
              onPressed: () => context.go('/login'),
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Scaffold(
            appBar: AppBar(
              title: Text(switch (destinations[selectedIndex].path) {
                '/outputs' => 'Outputs',
                '/projects' => 'Projects',
                '/structure' => 'Structure',
                '/app/dashboard' => 'Dashboard',
                '/app/admin' => 'Admin',
                _ => 'People',
              }),
              actions: sessionActions,
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) =>
                  context.go(destinations[value].path),
              destinations: [
                for (final item in destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
          );
        }

        if (path == '/app/dashboard' ||
            path.startsWith('/app/admin') ||
            path == '/app/settings') {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _adminSidebar(context, path, session),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 56,
            titleSpacing: 28,
            backgroundColor: AppColors.sidebar,
            foregroundColor: AppColors.textOnDark,
            title: Row(
              children: [
                InkWell(
                  onTap: () => context.go('/people'),
                  child: Row(
                    children: [
                      Text(
                        'UNIDCOM',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textOnDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        ' IADE',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 36),
                for (final item in destinations.take(4))
                  Builder(
                    builder: (context) {
                      final active = item.prefixes.any(path.startsWith);
                      return InkWell(
                        onTap: () => context.go(item.path),
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: active
                              ? const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.teal,
                                      width: 2,
                                    ),
                                  ),
                                )
                              : null,
                          child: Text(
                            item.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: active
                                      ? AppColors.textOnDark
                                      : AppColors.textOnDarkMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Dashboard',
                icon: const Icon(Icons.dashboard),
                onPressed: () => context.go('/app/dashboard'),
              ),
              if (admin)
                IconButton(
                  tooltip: 'Admin',
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () => context.go('/app/admin'),
                ),
              ...sessionActions,
            ],
          ),
          body: child,
        );
      },
    );
  }

  Widget _adminSidebar(BuildContext context, String path, Session? session) {
    final items = [
      _NavItem('/app/dashboard', Icons.dashboard, 'Dashboard'),
      _NavItem('/people', Icons.people, 'People'),
      _NavItem('/app/admin/requests', Icons.inbox, 'Requests'),
      _NavItem('/outputs', Icons.article, 'Outputs'),
      _NavItem('/structure', Icons.account_tree, 'Structure'),
      _NavItem('/app/settings', Icons.settings, 'Settings'),
    ];

    return SizedBox(
      width: 220,
      child: ColoredBox(
        color: AppColors.sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UNIDCOM',
                    style: TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: AppColors.textOnDarkMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                children: [
                  for (final item in items)
                    Builder(
                      builder: (context) {
                        final active = path.startsWith(item.path);
                        final color = active
                            ? AppColors.textOnDark
                            : AppColors.textOnDarkMuted;
                        return InkWell(
                          onTap: () => context.go(item.path),
                          child: Container(
                            height: 44,
                            padding: EdgeInsets.only(
                              left: active ? 13 : 16,
                              right: 16,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : null,
                              border: active
                                  ? const Border(
                                      left: BorderSide(
                                        color: AppColors.teal,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, color: color, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (item.path == '/app/admin/requests')
                                  FutureBuilder<int>(
                                    future: data.countPendingRequests(),
                                    builder: (context, snapshot) {
                                      final count = snapshot.data ?? 0;
                                      if (count <= 0) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 22,
                                          minHeight: 18,
                                        ),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.amber,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
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
                      },
                    ),
                ],
              ),
            ),
            if (session != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  session.user.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textOnDarkMuted,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  _NavItem(this.path, this.icon, this.label, {List<String>? prefixes})
    : prefixes = prefixes ?? [path];

  final String path;
  final IconData icon;
  final String label;

  /// Path prefixes that map to this tab (detail routes included). Defaults to
  /// [path] so single-section tabs keep their existing startsWith behavior.
  final List<String> prefixes;
}
