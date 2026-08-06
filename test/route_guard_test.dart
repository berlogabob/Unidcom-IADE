import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/main.dart';

// The gate is inverted from what it used to be: the Hugo site is the public
// face, so this app is anonymous ONLY on /login and the Welcome pack. The
// directory (/people, /outputs, …) is now the live internal view.
void main() {
  group('needsAuth: anonymous surfaces', () {
    test('login and the welcome pack stay public', () {
      final publicRoutes = [
        '/login',
        '/app/welcome',
        '/app/welcome/start',
        '/app/welcome/oa',
        '/app/welcome/affiliation',
      ];

      for (final location in publicRoutes) {
        expect(
          needsAuth(location),
          false,
          reason: 'location=$location should not require auth',
        );
      }
    });
  });

  group('needsAuth: the directory is internal now', () {
    test('former public routes require auth', () {
      final gatedRoutes = [
        '/',
        '/people',
        '/people/abc-123',
        '/outputs',
        '/outputs/abc-123',
        '/projects',
        '/projects/abc-123',
        '/structure',
        '/conferences',
        '/conferences/some-key',
        '/labs/abc-123',
        '/clusters/abc-123',
        '/objectives/abc-123',
      ];

      for (final location in gatedRoutes) {
        expect(
          needsAuth(location),
          true,
          reason: 'location=$location should require auth',
        );
      }
    });
  });

  group('needsAuth: portal routes need auth', () {
    test('gated routes require auth', () {
      final gatedRoutes = [
        '/app/home',
        '/app/requests',
        '/app/requests/new',
        '/app/requests/abc-123',
        '/app/profile',
        '/app/dashboard',
        '/app/admin',
        '/app/admin/requests',
        '/app/settings',
      ];

      for (final location in gatedRoutes) {
        expect(
          needsAuth(location),
          true,
          reason: 'location=$location should require auth',
        );
      }
    });
  });

  group('needsAuth: near misses', () {
    test('routes that look public but are not', () {
      final nearMisses = [
        '/appfoo', // /app prefix but no slash after
        '/app', // /app with no trailing slash
        '/welcome/start', // welcome but not under /app/
        '/login/', // trailing slash is not the login route
        '/loginx', // prefix of nothing
      ];

      for (final location in nearMisses) {
        expect(
          needsAuth(location),
          true,
          reason: 'location=$location should require auth (near-miss)',
        );
      }
    });
  });
}
