// GET ?code&state — ORCID OAuth broker.
//
// ORCID is not a Supabase auth provider, so: exchange the authorization code
// here, require a matching people.orcid row (only known researchers get a
// session — `authenticated` sees unapproved rows under current RLS), find-or-
// create an auth user keyed by a deterministic alias email, mint a magic-link
// hashed_token via the Admin API, and 302 back to the app, which verifies it
// client-side. Nothing is ever emailed.
//
// verify_jwt = false (config.toml): ORCID's browser redirect carries no JWT.
// No CORS: only top-level navigations reach this function, never XHR.

const ALLOWED_RETURN = [
  /^https:\/\/berlogabob\.github\.io\/Unidcom-IADE\/$/,
  /^http:\/\/localhost(:\d+)?\/$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?\/$/,
];

const SB = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  "Content-Type": "application/json",
};

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const state = url.searchParams.get("state") ?? "";
  // state is the return URL; hard allowlist so this can't be an open redirector.
  if (!ALLOWED_RETURN.some((re) => re.test(state))) {
    return new Response("bad state", { status: 400 });
  }
  const fail = (msg: string) =>
    Response.redirect(`${state}?orcid_error=${encodeURIComponent(msg)}`, 302);

  const code = url.searchParams.get("code");
  if (!code) {
    return fail(
      url.searchParams.get("error_description") ?? "ORCID sign-in cancelled",
    );
  }

  // 1. code -> verified iD. The `orcid` field of the token response IS the proof.
  const tok = await fetch("https://orcid.org/oauth/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams({
      client_id: Deno.env.get("ORCID_CLIENT_ID")!,
      client_secret: Deno.env.get("ORCID_CLIENT_SECRET")!,
      grant_type: "authorization_code",
      redirect_uri: `${SB}/functions/v1/orcid-auth`, // must byte-match ORCID registration
      code,
    }),
  });
  if (!tok.ok) return fail("ORCID token exchange failed");
  const { orcid, name } = await tok.json();

  // 2. Only known researchers get a session; people.orcid is admin-curated.
  const rows = await (await fetch(
    `${SB}/rest/v1/people?select=id&orcid=eq.${orcid}`,
    { headers: admin },
  )).json();
  if (!Array.isArray(rows) || rows.length === 0) {
    return fail(
      `No UNIDCOM profile is registered for ORCID iD ${orcid}. Contact an admin.`,
    );
  }

  // 3. Find-or-create via deterministic alias email — makes lookup free.
  const email = `${orcid.toLowerCase()}@orcid.unidcom.local`;
  const created = await fetch(`${SB}/auth/v1/admin/users`, {
    method: "POST",
    headers: admin,
    body: JSON.stringify({
      email,
      email_confirm: true,
      app_metadata: { orcid, provider: "orcid" }, // claim RPC trusts this
      user_metadata: { full_name: name },
    }),
  });
  // 422 = already exists (older GoTrue answers 400 with the same meaning).
  if (!created.ok && created.status !== 422 && created.status !== 400) {
    return fail("could not create account");
  }

  // 4. Mint a session token; we carry hashed_token back ourselves.
  const link = await fetch(`${SB}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: admin,
    body: JSON.stringify({ type: "magiclink", email }),
  });
  if (!link.ok) return fail("could not create sign-in link");
  const { hashed_token } = await link.json();
  return Response.redirect(`${state}?token_hash=${hashed_token}`, 302);
});
