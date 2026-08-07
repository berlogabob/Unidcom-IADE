import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What went wrong, in terms a researcher can act on.
///
/// Before this existed, every failure reached the screen as
/// `snapshot.error.toString()` — so a researcher whose session had expired read
/// `Exception: JWT expired`, and one on a train read
/// `Failed host lookup: nmghxkhstlnxypmfmfhk.supabase.co`. Both are true and
/// neither tells them what to do.
enum FailureKind { offline, timedOut, signedOut, notAllowed, server, unknown }

class DataFailure implements Exception {
  const DataFailure(this.kind, this.message, {this.detail});

  final FailureKind kind;

  /// Shown to the user. Never contains an exception class, a table name, a
  /// policy name or the project ref.
  final String message;

  /// The original text, for the error report and for `flutter run` output.
  /// Never rendered.
  final String? detail;

  /// True when trying again might plausibly work.
  bool get retryable =>
      kind == FailureKind.offline ||
      kind == FailureKind.timedOut ||
      kind == FailureKind.server;

  static DataFailure from(Object error) {
    if (error is DataFailure) return error;
    final detail = error.toString();

    if (error is TimeoutException) {
      return DataFailure(
        FailureKind.timedOut,
        'The server took too long to answer.',
        detail: detail,
      );
    }
    if (error is SocketException || _looksOffline(detail)) {
      return DataFailure(
        FailureKind.offline,
        "Can't reach UNIDCOM. Check your connection and try again.",
        detail: detail,
      );
    }
    if (error is AuthException || _mentions(detail, ['jwt', 'token is expired'])) {
      return DataFailure(
        FailureKind.signedOut,
        'Your session has expired. Sign in again to continue.',
        detail: detail,
      );
    }
    if (error is PostgrestException) {
      // 42501 = insufficient_privilege, PGRST301 = JWT problem. RLS denials
      // arrive as "new row violates row-level security policy for table X",
      // which names the table — never show it.
      final code = error.code ?? '';
      if (code == 'PGRST301') {
        return DataFailure(
          FailureKind.signedOut,
          'Your session has expired. Sign in again to continue.',
          detail: detail,
        );
      }
      if (code == '42501' || _mentions(detail, ['row-level security', 'permission denied'])) {
        return DataFailure(
          FailureKind.notAllowed,
          "You don't have permission to do that. If you think you should, "
              'contact a UNIDCOM administrator.',
          detail: detail,
        );
      }
      return DataFailure(
        FailureKind.server,
        'UNIDCOM could not complete that request.',
        detail: detail,
      );
    }
    return DataFailure(
      FailureKind.unknown,
      'Something went wrong.',
      detail: detail,
    );
  }

  static bool _mentions(String text, List<String> needles) {
    final lower = text.toLowerCase();
    return needles.any(lower.contains);
  }

  static bool _looksOffline(String detail) => _mentions(detail, [
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection closed',
    'clientexception',
  ]);

  @override
  String toString() => message;
}

/// Where unexpected failures go.
///
/// There was no logging, error reporting or alerting anywhere in this system:
/// if the portal broke at 09:00 the detection mechanism was a researcher
/// emailing someone. This is the single seam for that. It deliberately does not
/// pull in an SDK — swap the body for Sentry (or anything else) and every call
/// site is already in place.
///
/// ponytail: console + a best-effort row. Add a hosted reporter when someone is
/// actually on call to receive it.
typedef ErrorReporter = void Function(Object error, StackTrace? stack, {String? context});

ErrorReporter reportError = _defaultReporter;

void _defaultReporter(Object error, StackTrace? stack, {String? context}) {
  final failure = error is DataFailure ? error : DataFailure.from(error);
  debugPrint(
    '[unidcom] ${context ?? 'error'}: ${failure.kind.name} — '
    '${failure.detail ?? failure.message}',
  );
  if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
}
