import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/widgets/nav_model.dart';

void main() {
  const routerPaths = [
    '/people',
    '/projects',
    '/outputs',
    '/conferences',
    '/structure',
    '/app/mode',
    '/app/dashboard',
    '/app/admin',
    '/app/admin/requests',
    '/app/admin/review',
    '/app/admin/reports',
    '/app/admin/merge',
    '/app/admin/data',
    '/app/profile',
    '/app/profile/identifiers',
    '/app/profile/bio',
    '/app/profile/areas',
    '/app/profile/interests',
    '/app/profile/status',
    '/app/outputs',
    '/app/outputs/add',
    '/app/outputs/edit',
    '/app/outputs/import',
    '/app/outputs/validation',
    '/app/requests',
    '/app/home',
    '/app/home/summary',
    '/app/home/recent',
    '/app/home/alerts',
    '/app/home/status',
    '/app/welcome/start',
    '/app/welcome/signature',
    '/app/welcome/social',
    '/app/welcome/affiliation',
    '/app/welcome/fct',
    '/app/welcome/report',
    '/app/welcome/logos',
    '/app/welcome/contacts',
    '/app/help/links',
    '/app/help/docs',
    '/app/help/faq',
    '/app/settings',
    '/login',
  ];
  Iterable<NavItem> flat(List<NavGroup> g) =>
      g.expand((x) => x.items).expand((i) => [i, ...i.children]);
  test('every nav route exists in the router', () {
    for (final i in [
      ...flat(researcherNav(signedIn: true)),
      ...flat(adminNav()),
    ]) {
      expect(routerPaths, contains(i.route), reason: i.route);
    }
  });
  test('anonymous nav offers only anonymous routes', () {
    for (final i in flat(researcherNav(signedIn: false))) {
      expect(i.route.startsWith('/app/welcome/'), isTrue, reason: i.route);
    }
  });
  test('M2 welcome sections are not in any nav', () {
    for (final i in flat(researcherNav(signedIn: true))) {
      final isWelcomeRoute = i.route.startsWith('/app/welcome/');
      expect(
        isWelcomeRoute && welcomeSlugsM2.contains(i.route.split('/').last),
        isFalse,
        reason: i.route,
      );
    }
  });
  test('a child wins over its parent', () {
    expect(
      navSelected(researcherNav(signedIn: true), '/app/welcome/start')!.label,
      'Getting Started',
    );
    expect(navSelected(adminNav(), '/labs/abc')!.label, 'Structure');
    expect(
      navSelected(adminNav(), '/outputs/123')!.label,
      'Scientific outputs',
    );
  });
  test('researcher nav is one-to-one with the IA tree', () {
    final groups = researcherNav(signedIn: true);
    expect(groups.map((g) => g.label).toList(), [
      'Overview',
      'My Profile',
      'Scientific Outputs',
      'Research Administration',
      'Communication',
      'Help & Contacts',
    ]);
    expect(
      groups.firstWhere((g) => g.label == 'Overview').items.map((i) => i.label),
      [
        'Research Activity Summary',
        'Recent Scientific Outputs',
        'Alerts & Notifications',
        'Profile Status',
        'Getting Started',
      ],
    );
    expect(
      groups
          .firstWhere((g) => g.label == 'My Profile')
          .items
          .map((i) => i.label),
      [
        'Personal Information',
        'Researcher Identifiers',
        'Biography',
        'Research Areas',
        'Research Interests',
        'Profile Status',
      ],
    );
    expect(
      groups
          .firstWhere((g) => g.label == 'Scientific Outputs')
          .items
          .map((i) => i.label),
      [
        'My Outputs',
        'Add Scientific Output',
        'Edit Scientific Outputs',
        'Import & Synchronisation',
        'Validation & Duplicates',
      ],
    );
    expect(
      groups
          .firstWhere((g) => g.label == 'Research Administration')
          .items
          .map((i) => i.label),
      [
        'Affiliation Guidelines',
        'FCT Information',
        'Research Activity Reporting',
      ],
    );
    expect(
      groups
          .firstWhere((g) => g.label == 'Communication')
          .items
          .map((i) => i.label),
      ['Email Signature', 'Social Media', 'Logos & Brand'],
    );
    expect(
      groups
          .firstWhere((g) => g.label == 'Help & Contacts')
          .items
          .map((i) => i.label),
      ['Key Contacts', 'Quick Links', 'Documentation', 'FAQs'],
    );
  });
  test('group landing routes', () {
    final groups = researcherNav(signedIn: true);
    expect(groups.firstWhere((g) => g.label == 'Overview').route, '/app/home');
    expect(
      groups.firstWhere((g) => g.label == 'My Profile').route,
      '/app/profile',
    );
    expect(
      groups.firstWhere((g) => g.label == 'Scientific Outputs').route,
      '/app/outputs',
    );
    expect(
      groups.firstWhere((g) => g.label == 'Research Administration').route,
      '/app/welcome/affiliation',
    );
    expect(
      groups.firstWhere((g) => g.label == 'Communication').route,
      '/app/welcome/signature',
    );
    expect(
      groups.firstWhere((g) => g.label == 'Help & Contacts').route,
      '/app/welcome/contacts',
    );
  });
  test('anonymous nav is Getting Started plus the welcome-only groups', () {
    final groups = researcherNav(signedIn: false);
    expect(groups.map((g) => g.label).toList(), [
      '',
      'Research Administration',
      'Communication',
      'Help & Contacts',
    ]);
    expect(groups.first.items.map((i) => i.label), ['Getting Started']);
    expect(
      groups
          .firstWhere((g) => g.label == 'Help & Contacts')
          .items
          .map((i) => i.label),
      ['Key Contacts'],
    );
  });
  test('decodeCollapsed round-trips through toggleGroup', () {
    expect(collapsedGroups.value, isEmpty);
    toggleGroup('My Profile');
    expect(collapsedGroups.value, {'My Profile'});
    toggleGroup('My Profile');
    expect(collapsedGroups.value, isEmpty);
  });
  test('decodeCollapsed parses the stored pipe-delimited set', () {
    expect(decodeCollapsed(null), isEmpty);
    expect(decodeCollapsed(''), isEmpty);
    expect(decodeCollapsed('My Profile|Overview'), {'My Profile', 'Overview'});
  });
  test('navGroupOf finds the owning group', () {
    final groups = researcherNav(signedIn: true);
    expect(navGroupOf(groups, '/app/profile/bio')?.label, 'My Profile');
    expect(navGroupOf(groups, '/app/outputs/add')?.label, 'Scientific Outputs');
    expect(navGroupOf(groups, '/nope'), isNull);
  });
  test('NavGroup route defaults to null when not given', () {
    expect(const NavGroup('x', []).route, isNull);
  });
  test(
    'researcher nav leaves carry no children — one level, one route each',
    () {
      for (final g in [
        ...researcherNav(signedIn: true),
        ...researcherNav(signedIn: false),
      ]) {
        for (final i in g.items) {
          expect(i.children, isEmpty, reason: '${g.label} > ${i.label}');
        }
      }
    },
  );
  test('the bare top group has no label and no landing route', () {
    final bare = researcherNav(signedIn: false).first;
    expect(bare.label, '');
    expect(bare.route, isNull);
  });
}
