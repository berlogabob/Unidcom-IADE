import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unidcom_iade/data/failure.dart';

// DataFailure decides what a researcher reads when something breaks, so the
// mapping is worth pinning — especially the rule that nothing internal leaks.
void main() {
  group('classification', () {
    test('a lost connection reads as offline, not as a host lookup', () {
      final f = DataFailure.from(
        const SocketException("Failed host lookup: 'nmghxkhstlnxypmfmfhk.supabase.co'"),
      );
      expect(f.kind, FailureKind.offline);
      expect(f.retryable, isTrue);
    });

    test('a ClientException string is recognised without the type', () {
      // supabase_flutter wraps network errors, so the type is often gone by
      // the time it reaches us — only the message survives.
      final f = DataFailure.from(
        Exception('ClientException with SocketException: Connection refused'),
      );
      expect(f.kind, FailureKind.offline);
    });

    test('a timeout is its own kind and is retryable', () {
      final f = DataFailure.from(TimeoutException('x', const Duration(seconds: 20)));
      expect(f.kind, FailureKind.timedOut);
      expect(f.retryable, isTrue);
    });

    test('an expired session asks the user to sign in, and is not retryable', () {
      final f = DataFailure.from(const AuthException('JWT expired'));
      expect(f.kind, FailureKind.signedOut);
      expect(f.retryable, isFalse, reason: 'retrying cannot fix an expired session');
    });

    test('PGRST301 is an expired session, not a server fault', () {
      final f = DataFailure.from(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );
      expect(f.kind, FailureKind.signedOut);
    });

    test('an RLS denial reads as a permission problem', () {
      final f = DataFailure.from(
        const PostgrestException(
          message: 'new row violates row-level security policy for table "people"',
          code: '42501',
        ),
      );
      expect(f.kind, FailureKind.notAllowed);
      expect(f.retryable, isFalse);
    });

    test('any other Postgrest error is a server fault', () {
      final f = DataFailure.from(
        const PostgrestException(message: 'boom', code: 'PGRST100'),
      );
      expect(f.kind, FailureKind.server);
      expect(f.retryable, isTrue);
    });

    test('an unknown error still produces something sayable', () {
      final f = DataFailure.from(StateError('bad state'));
      expect(f.kind, FailureKind.unknown);
      expect(f.message, isNotEmpty);
    });

    test('classifying is idempotent', () {
      final once = DataFailure.from(const AuthException('JWT expired'));
      expect(DataFailure.from(once), same(once));
    });
  });

  group('nothing internal reaches the screen', () {
    final leaky = <Object>[
      const SocketException("Failed host lookup: 'nmghxkhstlnxypmfmfhk.supabase.co'"),
      const PostgrestException(
        message: 'new row violates row-level security policy for table "people"',
        code: '42501',
      ),
      const PostgrestException(message: 'relation "output_authors" does not exist'),
      const AuthException('JWT expired'),
      Exception('Exception: something raw'),
    ];

    test('messages name no table, project, policy or exception class', () {
      for (final error in leaky) {
        final message = DataFailure.from(error).message.toLowerCase();
        for (final forbidden in [
          'nmghxkhstlnxypmfmfhk',
          'row-level security',
          'postgrest',
          'exception',
          'jwt',
          'people',
          'output_authors',
          'supabase',
        ]) {
          expect(
            message.contains(forbidden),
            isFalse,
            reason: '"$forbidden" leaked into: $message',
          );
        }
      }
    });

    test('the original text is kept for the report, just never shown', () {
      final f = DataFailure.from(const AuthException('JWT expired'));
      expect(f.detail, contains('JWT expired'));
      expect(f.message, isNot(contains('JWT')));
    });
  });

  test('reportError is a swappable seam', () {
    final seen = <String>[];
    final original = reportError;
    reportError = (error, stack, {String? context}) => seen.add('$context');
    addTearDown(() => reportError = original);

    reportError(StateError('x'), null, context: 'unit');
    expect(seen, ['unit']);
  });
}
