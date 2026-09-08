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

/// Which group headers are collapsed, keyed by [NavGroup.label]. Persisted
/// per browser tab (sessionStorage on web, see view_mode_store) so a
/// researcher's open/closed sections survive navigating around but not a
/// shared machine's next visitor.
final collapsedGroups = ValueNotifier<Set<String>>(
  decodeCollapsed(loadStored('nav_collapsed')),
);

Set<String> decodeCollapsed(String? raw) =>
    raw == null || raw.isEmpty ? {} : raw.split('|').toSet();

void toggleGroup(String label) {
  final next = {...collapsedGroups.value};
  next.contains(label) ? next.remove(label) : next.add(label);
  collapsedGroups.value = next;
  store('nav_collapsed', next.join('|'));
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
NavItem? navSelected(List<NavGroup> groups, String path) {
  for (final g in groups) {
    for (final i in g.items) {
      for (final c in i.children) {
        if (c.matches(path)) {
          return c;
        }
      }
    }
  }
  for (final g in groups) {
    for (final i in g.items) {
      if (i.matches(path)) {
        return i;
      }
    }
  }
  return null;
}

/// The group that owns [path] — the header a collapsed active row should
/// still surface itself under.
NavGroup? navGroupOf(List<NavGroup> groups, String path) {
  for (final g in groups) {
    for (final i in g.items) {
      if (i.matches(path)) {
        return g;
      }
      for (final c in i.children) {
        if (c.matches(path)) {
          return g;
        }
      }
    }
  }
  return null;
}
