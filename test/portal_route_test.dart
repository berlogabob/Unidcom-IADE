import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/app/researcher_home.dart';

void main() {
  test('researcher links pass through when no one else is being viewed', () {
    for (final route in [
      '/app/outputs',
      '/app/profile',
      '/app/outputs/import',
    ]) {
      expect(portalRoute(route, null), route);
    }
  });

  test("an admin's view of a researcher keeps links inside /people/:id", () {
    expect(portalRoute('/app/outputs/import', 'p1'), '/people/p1/import');
    expect(portalRoute('/app/outputs', 'p1'), '/people/p1/outputs');
    expect(portalRoute('/app/profile', 'p1'), '/people/p1/profile');
    expect(portalRoute('/app/home', 'p1'), '/people/p1');
  });
}
