// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:math';

const _key = 'orcid_signin_nonce';

/// Mint a nonce for an ORCID sign-in and remember it in this tab.
///
/// sessionStorage, not localStorage: the nonce is meaningful only for the
/// sign-in currently in flight, and the ORCID round trip stays in the same tab
/// (`webOnlyWindowName: '_self'`).
String issueOrcidNonce() {
  final rng = Random.secure();
  final nonce = List.generate(16, (_) => rng.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  html.window.sessionStorage[_key] = nonce;
  return nonce;
}

/// Consume the nonce this tab issued. Returns null if there isn't one.
String? takeOrcidNonce() {
  final nonce = html.window.sessionStorage[_key];
  html.window.sessionStorage.remove(_key);
  return nonce;
}
