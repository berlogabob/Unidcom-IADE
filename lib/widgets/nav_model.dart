import 'package:flutter/material.dart';
import '../data/features.dart';

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
  const NavGroup(this.label, this.items); // label '' = no header
  final String label;
  final List<NavItem> items;
}

/// M2 (milestone 2) welcome sections — hidden in v1, not deleted.
const welcomeSlugsM2 = {'docs', 'conf', 'oa', 'missions'};

/// Researcher portal. `signedIn == false` is the anonymous visitor from the
/// public site: only the Welcome-pack material and a way to sign in.
List<NavGroup> researcherNav({required bool signedIn}) => [
  if (signedIn)
    NavGroup('', [
      NavItem(
        'Overview',
        '/app/home',
        icon: Icons.space_dashboard_outlined,
        children: [NavItem('Getting started', '/app/welcome/start')],
      ),
      NavItem('My profile', '/app/profile', icon: Icons.person_outline),
      NavItem(
        'Scientific outputs',
        '/app/outputs',
        icon: Icons.article_outlined,
      ),
    ])
  else
    NavGroup('', [
      NavItem(
        'Getting started',
        '/app/welcome/start',
        icon: Icons.flag_outlined,
      ),
    ]),
  NavGroup('Research administration', [
    NavItem(
      'Affiliation & FCT',
      '/app/welcome/affiliation',
      icon: Icons.verified_outlined,
    ),
    NavItem(
      'Report activity',
      '/app/welcome/report',
      icon: Icons.campaign_outlined,
    ),
    if (v2 && signedIn)
      NavItem('Support requests', '/app/requests', icon: Icons.inbox_outlined),
  ]),
  NavGroup('Communication', [
    NavItem(
      'Email signature',
      '/app/welcome/signature',
      icon: Icons.mail_outline,
    ),
    NavItem('Social media', '/app/welcome/social', icon: Icons.share_outlined),
    NavItem(
      'Logos & brand',
      '/app/welcome/logos',
      icon: Icons.palette_outlined,
    ),
  ]),
  NavGroup('Help & contacts', [
    NavItem(
      'Contacts',
      '/app/welcome/contacts',
      icon: Icons.contact_mail_outlined,
    ),
  ]),
  // M2 from the IA (not built): Research areas/interests, Ciência Vitae sync,
  // Validation & duplicates, Documentation, FAQ.
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
