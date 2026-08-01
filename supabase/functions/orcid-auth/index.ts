// ORCID OAuth broker: sign-in AND authenticated account-linking.
//
// Identity model: app_metadata.orcid (server-set only) marks which auth
// account owns an ORCID login method. people.orcid is an admin-curated
// registry — it gates WHO may get a session, never WHICH account they get.
// Linking a new login method is something the authenticated account does to
// itself (?action=start), never inferred during sign-in.
//
// GET ?action=start&return_to=…  (Authorization: user JWT)
//   -> {url}: ORCID authorize URL whose state is an HMAC-bound link token.
// GET ?code&state                (ORCID browser redirect)
//   state = plain return URL          -> sign-in flow
//   state = link|user|exp|return|sig  -> link flow
//
// verify_jwt = false (config.toml): ORCID's redirect carries no JWT; the
// start action validates its JWT itself. CORS applies only to the start
// action — it is called via fetch from the app origin; the OAuth callback
// is a top-level navigation and needs none.

const ALLOWED_RETURN = [
  /^https:\/\/berlogabob\.github\.io\/Unidcom-IADE\/$/,
  /^http:\/\/localhost(:\d+)?\/$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?\/$/,
];

const ALLOWED_ORIGIN = [
  /^https:\/\/berlogabob\.github\.io$/,
  /^http:\/\/localhost(:\d+)?$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
];

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  if (!ALLOWED_ORIGIN.some((re) => re.test(origin))) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
  };
}

const SB = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  "Content-Type": "application/json",
};

// Env first (supabase secrets set), else Vault via the service-role-only
// public.orcid_credentials() RPC.
async function orcidCredentials(): Promise<{ id: string; secret: string }> {
  const id = Deno.env.get("ORCID_CLIENT_ID");
  const secret = Deno.env.get("ORCID_CLIENT_SECRET");
  if (id && secret) return { id, secret };
  const res = await fetch(`${SB}/rest/v1/rpc/orcid_credentials`, {
    method: "POST",
    headers: admin,
    body: "{}",
  });
  const [row] = await res.json();
  return { id: row.client_id, secret: row.client_secret };
}

async function rpc(name: string, args: Record<string, unknown>) {
  const res = await fetch(`${SB}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: admin,
    body: JSON.stringify(args),
  });
  if (!res.ok) throw new Error(`${name} failed: ${await res.text()}`);
  return res.json();
}

// --- HMAC-bound link state (stateless CSRF protection for the link flow) ---
const enc = new TextEncoder();
let hmacKey: CryptoKey | undefined;
async function sign(data: string): Promise<string> {
  hmacKey ??= await crypto.subtle.importKey(
    "raw",
    enc.encode(KEY),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", hmacKey, enc.encode(data));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

type LinkState = { userId: string; returnTo: string };

async function parseLinkState(state: string): Promise<LinkState | null> {
  const parts = state.split("|");
  if (parts.length !== 5 || parts[0] !== "link") return null;
  const [, userId, exp, returnTo, sig] = parts;
  if (await sign(`link|${userId}|${exp}|${returnTo}`) !== sig) return null;
  if (Number(exp) < Date.now() / 1000) return null;
  return { userId, returnTo };
}

function authorizeUrl(clientId: string, state: string): string {
  const u = new URL("https://orcid.org/oauth/authorize");
  u.search = new URLSearchParams({
    client_id: clientId,
    response_type: "code",
    scope: "openid",
    redirect_uri: `${SB}/functions/v1/orcid-auth`, // must byte-match ORCID registration
    state,
  }).toString();
  return u.toString();
}

// --- action=start: authenticated user asks for a link-mode authorize URL ---
async function handleStart(req: Request, url: URL): Promise<Response> {
  const json = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json", ...corsHeaders(req) },
    });
  const returnTo = url.searchParams.get("return_to") ?? "";
  if (!ALLOWED_RETURN.some((re) => re.test(returnTo))) {
    return json(400, { error: "bad return_to" });
  }
  // The caller's JWT proves which account is linking.
  const who = await fetch(`${SB}/auth/v1/user`, {
    headers: {
      apikey: KEY,
      Authorization: req.headers.get("Authorization") ?? "",
    },
  });
  if (!who.ok) return json(401, { error: "not signed in" });
  const user = await who.json();
  const exp = Math.floor(Date.now() / 1000) + 600; // 10 min
  const body = `link|${user.id}|${exp}|${returnTo}`;
  const creds = await orcidCredentials();
  return json(200, { url: authorizeUrl(creds.id, `${body}|${await sign(body)}`) });
}

// --- link flow: attach the verified iD to the signed-in account ---
async function handleLink(
  link: LinkState,
  orcid: string,
  fail: (msg: string) => Response,
): Promise<Response> {
  // One account per iD.
  const holders = await rpc("auth_user_for_orcid", { p_orcid: orcid });
  if (holders.some((h: { id: string }) => h.id !== link.userId)) {
    return fail("This ORCID iD is already connected to another account");
  }
  // Merge explicitly — never clobber existing app_metadata (e.g. role).
  const got = await fetch(`${SB}/auth/v1/admin/users/${link.userId}`, {
    headers: admin,
  });
  if (!got.ok) return fail("account not found");
  const user = await got.json();
  const updated = await fetch(`${SB}/auth/v1/admin/users/${link.userId}`, {
    method: "PUT",
    headers: admin,
    body: JSON.stringify({
      app_metadata: { ...(user.app_metadata ?? {}), orcid, provider: "orcid" },
    }),
  });
  if (!updated.ok) return fail("could not link ORCID to the account");
  // Claim the person row (no-op if already claimed by this account; audited).
  await rpc("link_orcid_account", { p_orcid: orcid, p_user_id: link.userId });
  return Response.redirect(`${link.returnTo}?orcid_linked=1`, 302);
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (url.searchParams.get("action") === "start") return handleStart(req, url);

  const state = url.searchParams.get("state") ?? "";
  const link = await parseLinkState(state);
  const returnTo = link?.returnTo ?? state;
  // Hard allowlist so this can't be an open redirector.
  if (!ALLOWED_RETURN.some((re) => re.test(returnTo))) {
    return new Response("bad state", { status: 400 });
  }
  const fail = (msg: string) =>
    Response.redirect(
      `${returnTo}?orcid_error=${encodeURIComponent(msg)}`,
      302,
    );

  const code = url.searchParams.get("code");
  if (!code) {
    return fail(
      url.searchParams.get("error_description") ?? "ORCID sign-in cancelled",
    );
  }

  // 1. code -> verified iD. The `orcid` field of the token response IS the proof.
  const creds = await orcidCredentials();
  const tok = await fetch("https://orcid.org/oauth/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams({
      client_id: creds.id,
      client_secret: creds.secret,
      grant_type: "authorization_code",
      redirect_uri: `${SB}/functions/v1/orcid-auth`, // must byte-match ORCID registration
      code,
    }),
  });
  if (!tok.ok) return fail("ORCID token exchange failed");
  const { orcid, name } = await tok.json();

  if (link) return handleLink(link, orcid, fail);

  // --- sign-in flow: deterministic resolution ---
  // 2. Registry gate: only known researchers get a session.
  const rows = await (await fetch(
    `${SB}/rest/v1/people?select=id,auth_user_id&orcid=eq.${orcid}`,
    { headers: admin },
  )).json();
  if (!Array.isArray(rows) || rows.length === 0) {
    return fail(
      `No UNIDCOM profile is registered for ORCID iD ${orcid}. Contact an admin.`,
    );
  }

  // 3. An account that linked this iD signs in as itself.
  const holders = await rpc("auth_user_for_orcid", { p_orcid: orcid });
  let email: string;
  if (holders.length > 0) {
    email = holders[0].email;
    // Self-heal the person link (no-op unless the row is unclaimed).
    await rpc("link_orcid_account", { p_orcid: orcid, p_user_id: holders[0].id });
  } else if (rows[0].auth_user_id) {
    // 4. Profile claimed by an account that never linked ORCID: no implicit
    // merge — the account itself must add the login method.
    return fail(
      "This profile is already linked to an account. Sign in with your usual " +
        "credentials and use Connect ORCID on your profile.",
    );
  } else {
    // 5. First login of an unclaimed researcher: provision an alias account.
    email = `${orcid.toLowerCase()}@orcid.unidcom.local`;
    const created = await fetch(`${SB}/auth/v1/admin/users`, {
      method: "POST",
      headers: admin,
      body: JSON.stringify({
        email,
        email_confirm: true,
        app_metadata: { orcid, provider: "orcid" },
        user_metadata: { full_name: name },
      }),
    });
    // 422 = already exists (older GoTrue answers 400 with the same meaning).
    if (!created.ok && created.status !== 422 && created.status !== 400) {
      return fail("could not create account");
    }
    if (created.ok) {
      const newUser = await created.json();
      await rpc("link_orcid_account", { p_orcid: orcid, p_user_id: newUser.id });
    }
  }

  // 6. Mint a session token; we carry hashed_token back ourselves.
  const linkRes = await fetch(`${SB}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: admin,
    body: JSON.stringify({ type: "magiclink", email }),
  });
  if (!linkRes.ok) return fail("could not create sign-in link");
  const { hashed_token } = await linkRes.json();
  return Response.redirect(`${returnTo}?token_hash=${hashed_token}`, 302);
});
