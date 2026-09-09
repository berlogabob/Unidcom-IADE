import 'package:flutter/material.dart';
import '../data/features.dart';
import '../view_mode_store.dart';

class NavItem {
  const NavItem(
    this.label,
    this.route, {
    this.icon,
    List<String>? prefixes,
    this.children = const [],
  }) : prefixes = prefixes ?? const [];
  final String label;
  final String route;
  final IconData? icon; // top-level items carry one; children don't
  final List<String> prefixes; // extra path prefixes that select this item
  final List<NavItem> children;
  bool matches(String path) =>
      path == route ||
      path.startsWith('$route/') ||
      prefixes.any(path.startsWith);
}

class NavGroup {
  const NavGroup(this.label, this.items, {this.route});
  final String label; // '' = no header, not collapsible
  final List<NavItem> items; // the leaves (one sidebar level under the header)
  final String? route; // header tap lands here (section landing page)
}

/// Accordion: exactly one section is open at a time (Rui, 9 Sep briefing).
/// Stored per browser tab as `"<label>|<path>"` (sessionStorage, see
/// view_mode_store) — an empty label means "all closed". The stored choice
/// only applies while the path it was made on is current; on any other path
/// the open section is the one that owns the active route, so navigating to
/// a leaf in another section opens that section.
final expandedGroup = ValueNotifier<String?>(loadStored('nav_expanded'));

String? openGroup(List<NavGroup> groups, String path) {
  final raw = expandedGroup.value;
  if (raw != null) {
    final i = raw.lastIndexOf('|');
    if (i >= 0 && raw.substring(i + 1) == path) {
      final label = raw.substring(0, i);
      return label.isEmpty ? null : label;
    }
  }
  return navGroupOf(groups, path)?.label ??
      groups.firstWhere((g) => g.label.isNotEmpty, orElse: () => groups.first).label;
}

void toggleGroup(String label, {required List<NavGroup> groups, required String path}) {
  final next = openGroup(groups, path) == label ? '' : label;
  expandedGroup.value = '$next|$path';
  store('nav_expanded', expandedGroup.value!);
}

/// M2 (milestone 2) welcome sections — hidden in v1, not deleted.
const welcomeSlugsM2 = {'docs', 'conf', 'oa', 'missions'};

/// Researcher portal. `signedIn == false` is the anonymous visitor from the
/// public site: only the Welcome-pack material and a way to sign in.
///
/// One-to-one with the IA tree: every header below is a real section landing
/// page and every leaf a real route — no more "extra" children folded under
/// a top-level item the way the admin nav still does.
List<NavGroup> researcherNav({required bool signedIn}) => signedIn
    ? [
        NavGroup('Overview', [
          NavItem('Research Activity Summary', '/app/home/summary'),
          NavItem('Recent Scientific Outputs', '/app/home/recent'),
          NavItem('Alerts & Notifications', '/app/home/alerts'),
          NavItem('Profile Status', '/app/home/status'),
          NavItem('Getting Started', '/app/welcome/start'),
        ], route: '/app/home'),
        NavGroup('My Profile', [
          NavItem('Personal Information', '/app/profile'),
          NavItem('Researcher Identifiers', '/app/profile/identifiers'),
          NavItem('Biography', '/app/profile/bio'),
          NavItem('Research Areas', '/app/profile/areas'),
          NavItem('Research Interests', '/app/profile/interests'),
          NavItem('Profile Status', '/app/profile/status'),
        ], route: '/app/profile'),
        NavGroup('Scientific Outputs', [
          NavItem('My Outputs', '/app/outputs'),
          NavItem('Add Scientific Output', '/app/outputs/add'),
          NavItem('Edit Scientific Outputs', '/app/outputs/edit'),
          NavItem('Import & Synchronisation', '/app/outputs/import'),
          NavItem('Validation & Duplicates', '/app/outputs/validation'),
        ], route: '/app/outputs'),
        ..._welcomeGroups(signedIn: true),
      ]
    : [
        NavGroup('', [NavItem('Getting Started', '/app/welcome/start')]),
        ..._welcomeGroups(signedIn: false),
      ];

/// Research Administration, Communication and Help & Contacts — shared by
/// both visitor types, but Help & Contacts drops its signed-in-only leaves
/// (Quick Links, Documentation, FAQs live under `/app/help/*`, not the
/// public Welcome pack) for the anonymous visitor.
List<NavGroup> _welcomeGroups({required bool signedIn}) => [
  NavGroup('Research Administration', [
    NavItem('Affiliation Guidelines', '/app/welcome/affiliation'),
    NavItem('FCT Information', '/app/welcome/fct'),
    NavItem('Research Activity Reporting', '/app/welcome/report'),
    if (v2 && signedIn) NavItem('Support Requests', '/app/requests'),
  ], route: '/app/welcome/affiliation'),
  NavGroup('Communication', [
    NavItem('Email Signature', '/app/welcome/signature'),
    NavItem('Social Media', '/app/welcome/social'),
    NavItem('Logos & Brand', '/app/welcome/logos'),
  ], route: '/app/welcome/signature'),
  NavGroup('Help & Contacts', [
    NavItem('Key Contacts', '/app/welcome/contacts'),
    if (signedIn) NavItem('Quick Links', '/app/help/links'),
    if (signedIn) NavItem('Documentation', '/app/help/docs'),
    if (signedIn) NavItem('FAQs', '/app/help/faq'),
  ], route: '/app/welcome/contacts'),
];

/// Admin — "UNIDCOM Research Management".
List<NavGroup> adminNav() => [
  NavGroup('', [
    NavItem('Dashboard', '/app/dashboard', icon: Icons.dashboard_outlined),
    NavItem(
      'People',
      '/people',
      icon: Icons.people_outline,
      children: [NavItem('Merge duplicates', '/app/admin/merge')],
    ),
  ]),
  NavGroup('Research', [
    NavItem(
      'Scientific outputs',
      '/outputs',
      icon: Icons.article_outlined,
      prefixes: ['/conferences'],
      children: [NavItem('Pending approval', '/app/admin/review')],
    ),
    NavItem('Projects', '/projects', icon: Icons.work_outline),
    NavItem(
      'Structure',
      '/structure',
      icon: Icons.account_tree_outlined,
      prefixes: ['/labs', '/clusters', '/objectives'],
    ),
  ]),
  NavGroup('Data & reporting', [
    NavItem('Reports', '/app/admin/reports', icon: Icons.summarize_outlined),
    NavItem(
      'Data browser',
      '/app/admin/data',
      icon: Icons.table_chart_outlined,
    ),
    if (v2)
      NavItem(
        'Support requests',
        '/app/admin/requests',
        icon: Icons.inbox_outlined,
      ),
  ]),
  NavGroup('', [
    NavItem('Settings', '/app/settings', icon: Icons.settings_outlined),
  ]),
  // M2 from the IA (not built): Research activities, Planning & monitoring,
  // Data export page, Settings sub-pages (centre info, users & roles, ...).
];

/// The item (top-level or child) that owns [path], for highlighting and the
/// mobile app-bar title. Children win over their parent.
int? _navMatchScore(NavItem item, String path) {
  if (path == item.route) return 1000000 + item.route.length;
  var score = path.startsWith('${item.route}/') ? item.route.length : 0;
  for (final prefix in item.prefixes) {
    if (path.startsWith(prefix) && prefix.length > score) score = prefix.length;
  }
  return score == 0 ? null : score;
}

NavItem? navSelected(List<NavGroup> groups, String path) {
  NavItem? best;
  int? bestScore;
  for (final g in groups) {
    for (final i in g.items) {
      for (final item in [...i.children, i]) {
        final score = _navMatchScore(item, path);
        if (score != null && (bestScore == null || score > bestScore)) {
          best = item;
          bestScore = score;
        }
      }
    }
  }
  return best;
}

/// The group that owns [path] — the header a collapsed active row should
/// still surface itself under.
NavGroup? navGroupOf(List<NavGroup> groups, String path) {
  NavGroup? best;
  int? bestScore;
  for (final g in groups) {
    for (final i in g.items) {
      for (final item in [...i.children, i]) {
        final score = _navMatchScore(item, path);
        if (score != null && (bestScore == null || score > bestScore)) {
          best = g;
          bestScore = score;
        }
      }
    }
  }
  return best;
}
