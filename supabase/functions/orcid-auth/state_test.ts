// Tests for the ORCID broker's state handling.
//
//   deno test supabase/functions/orcid-auth/
//
// This file exists because the broker is the most security-sensitive code in
// the system — it is unauthenticated (verify_jwt = false), it holds the
// service-role key, and a slip in the return allowlist is an open redirect
// carrying a session token. It had no tests at all until 2026-08-07.

import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import {
  buildSignInState,
  isAllowedReturn,
  parseLinkState,
  parseSignInState,
  timingSafeEqual,
  withNonce,
} from "./state.ts";

const PROD = "https://nmghxkhstlnxypmfmfhk.supabase.co";
const LOCAL = "http://localhost:54321";
const APP = "https://berlogabob.github.io/Unidcom-IADE/";

Deno.test("return allowlist accepts exactly the deployed app URL", () => {
  assert(isAllowedReturn(APP, PROD));
});

Deno.test("return allowlist rejects open-redirect attempts", () => {
  for (
    const evil of [
      "https://evil.example/",
      "https://berlogabob.github.io.evil.example/Unidcom-IADE/",
      "https://berlogabob.github.io/Unidcom-IADE/../other/",
      "https://berlogabob.github.io/OtherRepo/",
      "http://berlogabob.github.io/Unidcom-IADE/", // http, not https
      "https://berlogabob.github.io/Unidcom-IADE", // no trailing slash
      "javascript:alert(1)",
      "",
    ]
  ) {
    assertFalse(isAllowedReturn(evil, PROD), `should reject ${evil}`);
  }
});

Deno.test("localhost is allowed only when the broker itself is local", () => {
  // Previously localhost was allowlisted on the deployed function, so a
  // chosen-state sign-in could be steered at whatever listened on the
  // victim's own machine — with a magic-link token attached.
  assertFalse(isAllowedReturn("http://localhost:9999/", PROD));
  assertFalse(isAllowedReturn("http://127.0.0.1:3000/", PROD));
  assert(isAllowedReturn("http://localhost:9999/", LOCAL));
  assert(isAllowedReturn("http://127.0.0.1:3000/", LOCAL));
});

Deno.test("sign-in state round-trips a nonce", () => {
  const state = buildSignInState("abc123", APP);
  assertEquals(parseSignInState(state), { nonce: "abc123", returnTo: APP });
});

Deno.test("a bare URL parses as the legacy nonce-less form", () => {
  // Kept so a browser on a cached build is not locked out mid-deploy.
  assertEquals(parseSignInState(APP), { nonce: "", returnTo: APP });
});

Deno.test("malformed sign-in state is rejected, not coerced", () => {
  for (const bad of ["", "signin|", "signin|only-two", "signin|a|b|c"]) {
    assertEquals(parseSignInState(bad), null, `should reject ${bad}`);
  }
});

Deno.test("the return URL is still checked after parsing a nonce state", () => {
  // The nonce must not become a way to smuggle a return URL past the allowlist.
  const parsed = parseSignInState(buildSignInState("n", "https://evil.example/"));
  assert(parsed);
  assertFalse(isAllowedReturn(parsed.returnTo, PROD));
});

Deno.test("withNonce appends correctly and escapes", () => {
  assertEquals(withNonce(`${APP}?token_hash=t`, "n1"), `${APP}?token_hash=t&orcid_nonce=n1`);
  assertEquals(withNonce(APP, "n1"), `${APP}?orcid_nonce=n1`);
  assertEquals(withNonce(APP, ""), APP, "legacy callers get no param");
  assertEquals(withNonce(APP, "a b&c"), `${APP}?orcid_nonce=a%20b%26c`);
});

// --- link state ---

/// Stand-in for the HMAC. Must be pipe-free like the real hex digest, or the
/// fixture itself breaks the `split("|")` and the test proves nothing.
const fakeSign = (data: string) =>
  Promise.resolve(
    [...data].reduce((h, c) => (h * 31 + c.charCodeAt(0)) >>> 0, 7).toString(16),
  );
const future = Math.floor(Date.now() / 1000) + 600;
const past = Math.floor(Date.now() / 1000) - 1;

async function linkState(
  userId: string,
  exp: number,
  returnTo: string,
  sig?: string,
) {
  const body = `link|${userId}|${exp}|${returnTo}`;
  return `${body}|${sig ?? await fakeSign(body)}`;
}

Deno.test("valid link state parses", async () => {
  const parsed = await parseLinkState(await linkState("u1", future, APP), fakeSign);
  assertEquals(parsed, { userId: "u1", returnTo: APP });
});

Deno.test("tampered link state is rejected", async () => {
  // Swap the user id but keep the original signature — the classic attempt to
  // link someone else's ORCID iD to your account.
  const original = await linkState("u1", future, APP);
  const stolenSig = original.split("|").at(-1)!;
  const forged = await linkState("attacker", future, APP, stolenSig);
  assertEquals(await parseLinkState(forged, fakeSign), null);
});

Deno.test("expired link state is rejected", async () => {
  assertEquals(await parseLinkState(await linkState("u1", past, APP), fakeSign), null);
});

Deno.test("non-numeric expiry is rejected rather than treated as 0", async () => {
  const body = `link|u1|not-a-number|${APP}`;
  assertEquals(
    await parseLinkState(`${body}|${await fakeSign(body)}`, fakeSign),
    null,
  );
});

Deno.test("a sign-in state is not accepted as a link state", async () => {
  assertEquals(await parseLinkState(buildSignInState("n", APP), fakeSign), null);
  assertEquals(await parseLinkState(APP, fakeSign), null);
});

Deno.test("timingSafeEqual behaves like equality", () => {
  assert(timingSafeEqual("abc", "abc"));
  assertFalse(timingSafeEqual("abc", "abd"));
  assertFalse(timingSafeEqual("abc", "abcd"));
  assertFalse(timingSafeEqual("", "a"));
  assert(timingSafeEqual("", ""));
});
