import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/supabase.dart' as data;
import '../theme/tokens.dart';
import 'nav_model.dart';
import 'side_nav.dart';

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
    // The chooser decides the mode; there is no nav yet to show while it does.
    if (path == '/app/mode') return Scaffold(body: widget.child);

    final session = Supabase.instance.client.auth.currentSession;
    final hasSession = session != null;
    final admin = data.isAdmin;
    final groups = !hasSession
        ? researcherNav(signedIn: false)
        : admin
        ? adminNav()
        : researcherNav(signedIn: true);

    return LayoutBuilder(
      builder: (context, constraints) {
        final nav = SideNav(
          groups: groups,
          path: path,
          header: _header(context, admin: admin, hasSession: hasSession),
          footer: _footer(context, admin: admin, hasSession: hasSession),
          badges: {
            '/people': _pendingPeople,
            '/app/admin/requests': _pendingRequests,
          },
        );

        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 240, child: nav),
                Expanded(child: widget.child),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(navSelected(groups, path)?.label ?? 'UNIDCOM'),
            backgroundColor: AppColors.sidebar,
            foregroundColor: AppColors.textOnDark,
          ),
          drawer: Drawer(
            width: 280,
            child: SideNav(
              groups: groups,
              path: path,
              header: _header(context, admin: admin, hasSession: hasSession),
              footer: _footer(context, admin: admin, hasSession: hasSession),
              badges: {
                '/people': _pendingPeople,
                '/app/admin/requests': _pendingRequests,
              },
              onNavigate: () => Navigator.of(context).pop(),
            ),
          ),
          body: widget.child,
        );
      },
    );
  }

  /// Wordmark + mode label. Tapping it goes home for whichever mode is
  /// current, or back to the public site for an anonymous visitor — the
  /// same three destinations the old top bar and admin sidebar each used.
  Widget _header(
    BuildContext context, {
    required bool admin,
    required bool hasSession,
  }) {
    final subtitle = !hasSession
        ? 'Welcome pack'
        : admin
        ? 'Admin'
        : 'Researcher portal';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => hasSession
            ? context.go(admin ? '/app/dashboard' : '/app/home')
            : _openPublicSite(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textOnDarkMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Account block + the actions that used to live in `handlePortalMenu`'s
  /// popup menu. Anonymous callers get only the two links that make sense for
  /// them: back to the public site, or on to /login.
  Widget _footer(
    BuildContext context, {
    required bool admin,
    required bool hasSession,
  }) {
    if (!hasSession) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: _openPublicSite,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textOnDarkMuted,
              ),
              child: const Text('Public site'),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textOnDarkMuted,
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;
    void handleSignOut() {
      data.forgetMode();
      Supabase.instance.client.auth.signOut();
    }

    void handleModeSwitch() {
      // chooseMode wakes the router; `go` only names the landing.
      data.chooseMode(admin ? data.ViewMode.researcher : data.ViewMode.admin);
      context.go(admin ? '/app/welcome/start' : '/app/dashboard');
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _person,
            builder: (context, snapshot) {
              final personName =
                  (snapshot.data?['preferred_name'] as String? ?? '').trim();
              final email =
                  (snapshot.data?['email'] as String? ??
                          session?.user.email ??
                          '')
                      .trim();
              final name = personName.isEmpty
                  ? email.split('@').first
                  : personName;
              return Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.teal,
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        // Navy on teal is 6.60:1; white was 2.62:1.
                        color: AppColors.profileBand,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textOnDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textOnDarkMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            children: [
              if (data.isAdminAccount)
                TextButton(
                  onPressed: handleModeSwitch,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textOnDarkMuted,
                  ),
                  child: Text(
                    admin ? 'Switch to researcher' : 'Switch to admin',
                  ),
                ),
              TextButton(
                onPressed: _openPublicSite,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textOnDarkMuted,
                ),
                child: const Text('Public site'),
              ),
              TextButton(
                onPressed: handleSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textOnDarkMuted,
                ),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
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
