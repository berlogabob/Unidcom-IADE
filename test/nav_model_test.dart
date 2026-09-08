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
    '/app/outputs',
    '/app/requests',
    '/app/home',
    '/app/welcome/start',
    '/app/welcome/signature',
    '/app/welcome/social',
    '/app/welcome/affiliation',
    '/app/welcome/report',
    '/app/welcome/logos',
    '/app/welcome/contacts',
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
      expect(welcomeSlugsM2.any((s) => i.route.endsWith('/$s')), isFalse);
    }
  });
  test('a child wins over its parent', () {
    expect(
      navSelected(researcherNav(signedIn: true), '/app/welcome/start')!.label,
      'Getting started',
    );
    expect(navSelected(adminNav(), '/labs/abc')!.label, 'Structure');
    expect(
      navSelected(adminNav(), '/outputs/123')!.label,
      'Scientific outputs',
    );
  });
  test('v1 researcher nav is exactly the IA items that exist', () {
    expect(flat(researcherNav(signedIn: true)).map((i) => i.label).toList(), [
      'Overview',
      'Getting started',
      'My profile',
      'Scientific outputs',
      'Affiliation & FCT',
      'Report activity',
      'Email signature',
      'Social media',
      'Logos & brand',
      'Contacts',
    ]);
  });
}
