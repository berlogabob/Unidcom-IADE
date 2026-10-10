// POST {} -> { pushed: n } — admin-only. Pushes every published RIMS profile to the Sanity
// TEST project (default ld5jhf23; the agency's vj0axykv is refused), like scripts/sanity_push.py.
// Secret: SANITY_TOKEN (editor token for the test project). Photo/email/etc. are never touched.
import { mutations, published, Row, slugify } from "./mutations.ts";

const AGENCY = "vj0axykv";
const PROJECT = Deno.env.get("SANITY_PROJECT") ?? "ld5jhf23";
const DATASET = Deno.env.get("SANITY_DATASET") ?? "production";
const COLUMNS = "id,preferred_name,bio,orcid,ciencia_id,membership_type,public_visibility,merged_into,sanity_id";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...CORS, "Content-Type": "application/json" } });

async function isAdmin(authorization: string) {
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "" },
  });
  return res.ok && (await res.json())?.app_metadata?.role === "admin";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization || !(await isAdmin(authorization))) return json({ error: "admins only" }, 403);
  if (PROJECT === AGENCY) return json({ error: "refusing the agency project" }, 400);
  const token = Deno.env.get("SANITY_TOKEN");
  if (!token) return json({ error: "SANITY_TOKEN is not set" }, 501);

  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const res = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/people?select=${COLUMNS}&public_visibility=eq.true&merged_into=is.null`,
    { headers: { apikey: key, Authorization: `Bearer ${key}` } },
  );
  if (!res.ok) return json({ error: `database ${res.status}` }, 502);
  const people = ((await res.json()) as Row[]).filter(published);

  const q = encodeURIComponent('*[_type=="member" && defined(slug.current)]{_id, "slug": slug.current}');
  const found = await fetch(`https://${PROJECT}.api.sanity.io/v2025-02-19/data/query/${DATASET}?query=${q}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!found.ok) return json({ error: `Sanity ${found.status}` }, 502);
  const bySlug = new Map<string, string>(
    ((await found.json()).result as { _id: string; slug: string }[]).map((m) => [m.slug, m._id]),
  );
  const all = people.flatMap((p) => mutations(p, bySlug.get(slugify(p.preferred_name))));
  for (let i = 0; i < all.length; i += 100) {
    const r = await fetch(`https://${PROJECT}.api.sanity.io/v2025-02-19/data/mutate/${DATASET}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ mutations: all.slice(i, i + 100) }),
    });
    if (!r.ok) return json({ error: `Sanity ${r.status}`, pushed: Math.floor(i / 2) }, 502);
  }
  return json({ pushed: people.length, project: PROJECT });
});
