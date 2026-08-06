// Non-web builds have no ORCID browser round trip yet (mobile deep links are a
// follow-up), so there is nothing to bind a nonce to.
String issueOrcidNonce() => '';

String? takeOrcidNonce() => null;
