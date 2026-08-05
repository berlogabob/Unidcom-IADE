import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase.dart' as data;

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final admin = data.isAdmin;
    final hasSession = Supabase.instance.client.auth.currentSession != null;
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
        actions: hasSession
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
              ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => context.go(destinations[value].path),
        destinations: [
          for (final item in destinations)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
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
