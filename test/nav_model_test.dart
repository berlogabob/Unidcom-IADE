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
  test('WIP leaves match the routes whose builders return WipPage', () {
    // Verified against the WipPage(title: ...) builders in lib/main.dart;
    // importing main.dart here would initialize Supabase.
    const wipRoutes = {
      '/app/profile/areas',
      '/app/profile/interests',
      '/app/outputs/edit',
      '/app/outputs/validation',
      '/app/help/docs',
      '/app/help/faq',
    };
    final actual = flat(researcherNav(signedIn: true))
        .where((i) => i.wip)
        .map((i) => i.route)
        .toSet();
    expect(actual, wipRoutes);
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
  test('nav selection prefers exact and longest matching routes', () {
    final researcher = researcherNav(signedIn: true);
    expect(navSelected(researcher, '/app/outputs/add')?.label, 'Add Scientific Output');
    expect(navSelected(researcher, '/app/profile/identifiers')?.label, 'Researcher Identifiers');
    expect(navSelected(researcher, '/app/profile')?.label, 'Personal Information');
    expect(navSelected(researcher, '/app/outputs')?.label, 'My Outputs');
    expect(navSelected(researcher, '/app/home/alerts')?.label, 'Alerts & Notifications');

    final admin = adminNav();
    expect(navSelected(admin, '/people/abc')?.label, 'People');
    expect(navSelected(admin, '/app/admin/merge')?.label, 'Merge duplicates');
    expect(navSelected(admin, '/app/admin/review')?.label, 'Pending approval');
  });
  test('nav group selection prefers exact and longest matching routes', () {
    final researcher = researcherNav(signedIn: true);
    expect(navGroupOf(researcher, '/app/outputs/add')?.label, 'Scientific Outputs');
    expect(navGroupOf(researcher, '/app/profile/identifiers')?.label, 'My Profile');

    final admin = adminNav();
    expect(navGroupOf(admin, '/app/admin/merge')?.label, '');
    expect(navGroupOf(admin, '/app/admin/review')?.label, 'Research');
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
  test('accordion: the open section follows the active route until toggled', () {
    expandedGroup.value = null;
    final groups = researcherNav(signedIn: true);
    expect(openGroup(groups, '/app/home'), 'Overview');
    expect(openGroup(groups, '/app/outputs/import'), 'Scientific Outputs');
    toggleGroup('My Profile', groups: groups, path: '/app/home');
    expect(openGroup(groups, '/app/home'), 'My Profile');
    toggleGroup('My Profile', groups: groups, path: '/app/home');
    expect(openGroup(groups, '/app/home'), isNull, reason: 'toggling the open one closes all');
    expect(openGroup(groups, '/app/profile'), 'My Profile', reason: 'other paths ignore the stored choice');
    expandedGroup.value = null;
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
