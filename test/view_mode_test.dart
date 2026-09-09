import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/supabase.dart' show ViewMode, modeFromStored;
import 'package:unidcom_iade/main.dart';

// modeRedirect is the whole "researcher sees only their own things" rule, and
// the whole "ask an admin which job they are doing" rule. Pure, so it is
// testable without a session — same reason needsAuth is a bare function.
//
// It is ergonomics, not access control: RLS and the anon grant revocation
// decide what anyone can read. These tests assert what is *offered*.
String? redirect(
  String location, {
  bool adminAccount = false,
  bool adminMode = false,
  bool chosen = true,
}) => modeRedirect(
  location,
  adminAccount: adminAccount,
  adminMode: adminMode,
  chosen: chosen,
);

void main() {
  group('the chooser', () {
    test('an admin who has not chosen is asked, wherever they were going', () {
      for (final location in [
        '/app/home',
        '/people',
        '/app/admin',
        '/outputs',
      ]) {
        expect(
          redirect(location, adminAccount: true, chosen: false),
          '/app/mode',
          reason: 'a bookmark must not decide the mode for them: $location',
        );
      }
    });

    test('the chooser itself is not a redirect loop', () {
      expect(redirect('/app/mode', adminAccount: true, chosen: false), isNull);
    });

    test('a plain researcher is never asked, even by typing the URL', () {
      expect(redirect('/app/mode'), '/app/welcome/start');
    });

    test('once answered, the chooser sends you on rather than re-asking', () {
      expect(
        redirect('/app/mode', adminAccount: true, adminMode: true),
        '/app/dashboard',
      );
      expect(redirect('/app/mode', adminAccount: true), '/app/welcome/start');
    });
  });

  group('researcher mode shows only your own things', () {
    test('the unit-wide directory is not reachable', () {
      final directory = [
        '/people',
        '/people/abc-123',
        '/outputs',
        '/outputs/abc-123',
        '/projects',
        '/structure',
        '/conferences',
        '/labs/abc-123',
        '/clusters/abc-123',
        '/objectives/abc-123',
        '/app/dashboard',
        '/app/admin',
        '/app/admin/requests',
        '/app/admin/data',
        '/app/settings',
      ];
      for (final location in directory) {
        expect(
          redirect(location),
          '/app/home',
          reason: 'researcher mode should not offer $location',
        );
      }
    });

    test('your own portal stays open', () {
      for (final location in [
        '/app/home',
        '/app/profile',
        '/app/welcome/start',
      ]) {
        expect(redirect(location), isNull, reason: location);
      }
    });

    test('an admin in researcher mode is treated as a researcher', () {
      // The point of the whole split: holding the role is not the same as
      // using it. This is what stopped Approve appearing on Rui's own profile.
      expect(redirect('/people', adminAccount: true), '/app/home');
    });

    test('M2 welcome sections redirect to start in v1', () {
      for (final slug in ['docs', 'conf', 'oa', 'missions']) {
        expect(redirect('/app/welcome/$slug'), '/app/welcome/start');
      }
      expect(redirect('/app/welcome/affiliation'), isNull);
    });
  });

  group('admin mode', () {
    test('the directory and the admin screens open', () {
      for (final location in [
        '/people',
        '/outputs',
        '/structure',
        '/app/dashboard',
        '/app/admin',
        '/app/settings',
      ]) {
        expect(
          redirect(location, adminAccount: true, adminMode: true),
          isNull,
          reason: location,
        );
      }
    });
  });

  group('v2 routes are refused, not merely unlinked', () {
    // Tests compile without --dart-define=V2, so this is the pilot build.
    test('support requests are closed in v1 for both modes', () {
      for (final location in [
        '/app/requests',
        '/app/requests/new',
        '/app/requests/abc-123',
      ]) {
        expect(redirect(location), '/app/home', reason: location);
        expect(
          redirect(location, adminAccount: true, adminMode: true),
          '/app/home',
          reason: 'a demo-build bookmark must not walk in behind the flag',
        );
      }
    });

    test('admin requests open the review queue in v1 admin mode', () {
      expect(
        redirect(
          '/app/admin/requests',
          adminAccount: true,
          adminMode: true,
        ),
        '/app/admin/review',
      );
    });
  });

  group('restoring the mode after a refresh', () {
    // The tab's sessionStorage survives F5; modeFromStored decides whether
    // that counts as "already answered". Junk must mean "ask again", never
    // "silently admin".
    test('the two real values round-trip', () {
      expect(modeFromStored('admin'), ViewMode.admin);
      expect(modeFromStored('researcher'), ViewMode.researcher);
    });

    test('anything else means the chooser is asked again', () {
      for (final stored in [null, '', 'Admin', 'superuser']) {
        expect(modeFromStored(stored), isNull, reason: '$stored');
      }
    });
  });

  group('near misses', () {
    test('a longer path that merely starts the same is still admin-only', () {
      // Intentional: /peoplex does not exist, and sending it to /app/home is a
      // better outcome than a blank screen.
      expect(redirect('/people-directory'), '/app/home');
    });

    test('paths outside the admin list are left alone', () {
      expect(redirect('/login'), isNull);
      expect(redirect('/'), isNull);
    });
  });
}
