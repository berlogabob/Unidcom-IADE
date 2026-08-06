import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/main.dart';

void main() {
  group('needsAuth: public routes', () {
    test('public routes do not require auth', () {
      final publicRoutes = [
        '/',
        '/people',
        '/outputs',
        '/projects',
        '/structure',
        '/conferences',
        '/login',
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

  group('needsAuth: welcome pack is public', () {
    test('welcome pack routes do not require auth', () {
      final welcomeRoutes = [
        '/app/welcome',
        '/app/welcome/start',
        '/app/welcome/oa',
        '/app/welcome/affiliation',
      ];

      for (final location in welcomeRoutes) {
        expect(
          needsAuth(location),
          false,
          reason: 'location=$location (welcome pack) should not require auth',
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
    test('routes that look similar but do not match pattern', () {
      final nearMisses = [
        '/appfoo',           // /app prefix but no slash after
        '/app',              // /app with no trailing slash
        '/welcome/start',    // welcome but not under /app/
      ];

      for (final location in nearMisses) {
        expect(
          needsAuth(location),
          false,
          reason: 'location=$location should not require auth (near-miss)',
        );
      }
    });
  });
}
