import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/supabase.dart' as data;
import '../theme/tokens.dart';

/// The public UNIDCOM site. This app is the portal you arrive at *from* there,
/// so every shell offers the way back.
// ponytail: one const, one call site. Promote to --dart-define if the Hugo
// site ever moves off github.io.
const _publicSiteUrl = 'https://berlogabob.github.io/unidcom-site/';

void _openPublicSite() {
  launchUrl(Uri.parse(_publicSiteUrl), webOnlyWindowName: '_self');
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Fetched once per shell mount (not on every rebuild/navigation) — see M2.
  late final Future<int> _pendingPeople = data.fetchPendingPeople().then(
    (people) => people.length,
  );
  late final Future<int> _pendingRequests = data.countPendingRequests();
  late final Future<Map<String, dynamic>?> _person = data.fetchMyPerson();

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
    // Portal menu items & handler — shared between mobile and desktop (portal
    // pages (/app/home, /app/requests*, /app/welcome/*, ...) now reachable
    // on mobile via PopupMenuButton; see I1 fix).
    final portalMenuItems = const [
      PopupMenuItem(value: 'overview', child: Text('Overview')),
      PopupMenuItem(value: 'requests', child: Text('Support requests')),
      PopupMenuItem(value: 'welcome', child: Text('Welcome pack')),
      PopupMenuItem(value: 'profile', child: Text('My profile')),
      PopupMenuItem(value: 'site', child: Text('Public site')),
      PopupMenuItem(value: 'signout', child: Text('Sign out')),
    ];
    void handlePortalMenu(String value) {
      if (value == 'overview') context.go('/app/home');
      if (value == 'requests') context.go('/app/requests');
      if (value == 'welcome') context.go('/app/welcome/start');
      if (value == 'profile') context.go('/app/profile');
      if (value == 'site') _openPublicSite();
      if (value == 'signout') {
        Supabase.instance.client.auth.signOut();
      }
    }
    // Mobile app bar + bottom nav — now includes researcher portal via
    // PopupMenuButton (I1).
    final sessionActions = hasSession
        ? [
            PopupMenuButton<String>(
              tooltip: 'My profile',
              icon: const Icon(Icons.account_circle),
              onSelected: handlePortalMenu,
              itemBuilder: (context) => portalMenuItems,
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          ]
        : [
            IconButton(
              tooltip: 'Public site',
              icon: const Icon(Icons.public),
              onPressed: _openPublicSite,
            ),
            IconButton(
              tooltip: 'Sign in',
              icon: const Icon(Icons.login),
              onPressed: () => context.go('/login'),
            ),
          ];
    // Desktop wide top-nav account area — adds the researcher portal entry
    // points (I1): Overview/Support requests/Welcome pack/My profile/Public
    // site/Sign out behind one menu when signed in. Signed out, the only
    // screen here is the Welcome pack itself, so the useful links are the way
    // back to the public site and the way forward into the portal.
    final desktopAccountActions = hasSession
        ? [
            PopupMenuButton<String>(
              tooltip: 'My profile',
              onSelected: handlePortalMenu,
              itemBuilder: (context) => portalMenuItems,
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _person,
                builder: (context, snapshot) {
                  final personName =
                      (snapshot.data?['preferred_name'] as String? ?? '')
                          .trim();
                  final email =
                      (snapshot.data?['email'] as String? ??
                              session.user.email ??
                              '')
                          .trim();
                  final name = personName.isEmpty
                      ? email.split('@').first
                      : personName;
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.teal,
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textOnDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]
        : [
            TextButton(
              onPressed: _openPublicSite,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textOnDarkMuted,
              ),
              child: const Text('Public site'),
            ),
            IconButton(
              tooltip: 'Sign in',
              icon: const Icon(Icons.login),
              onPressed: () => context.go('/login'),
            ),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          // Portal pages (/app/home, /app/requests*, /app/welcome/*, ...)
          // aren't in `destinations`, so give them their own titles instead
          // of falling through to "People" (M4).
          final title = path.startsWith('/app/requests')
              ? 'Support requests'
              : path == '/app/home'
              ? 'Overview'
              : path.startsWith('/app/welcome')
              ? 'Welcome pack'
              : path == '/app/profile'
              ? 'My profile'
              : path == '/app/settings'
              ? 'Settings'
              : switch (destinations[selectedIndex].path) {
                  '/outputs' => 'Outputs',
                  '/projects' => 'Projects',
                  '/structure' => 'Structure',
                  '/app/dashboard' => 'Dashboard',
                  '/app/admin' => 'Admin',
                  _ => 'People',
                };
          return Scaffold(
            appBar: AppBar(title: Text(title), actions: sessionActions),
            body: widget.child,
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

        if (admin &&
            (path == '/app/dashboard' ||
                path.startsWith('/app/admin') ||
                path == '/app/settings')) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _adminSidebar(context, path, session),
                Expanded(child: widget.child),
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
              ...desktopAccountActions,
            ],
          ),
          body: widget.child,
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
                                if (item.path == '/people' ||
                                    item.path == '/app/admin/requests')
                                  FutureBuilder<int>(
                                    future: item.path == '/people'
                                        ? _pendingPeople
                                        : _pendingRequests,
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
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _person,
                  builder: (context, snapshot) => Text(
                    snapshot.data?['email'] as String? ??
                        session.user.email ??
                        '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textOnDarkMuted,
                      fontSize: 12,
                    ),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}
