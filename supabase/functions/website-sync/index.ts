// POST { action: "status" | "run" } -> { last: {...} } | { ok: true }
//
// Admin-only bridge to the site repo's "Sync content from Supabase" workflow
// (unidcom-site/.github/workflows/sync.yml). The GitHub token never reaches the
// browser: set it once with
//   supabase secrets set GITHUB_SYNC_TOKEN=<fine-grained PAT, repo unidcom-site, Actions: read & write>
// "run" always sends preview=false, so approval gates cannot be skipped from here.

const REPO = Deno.env.get("SITE_REPO") ?? "berlogabob/unidcom-site";
const WORKFLOW = "sync.yml";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

async function isAdmin(authorization: string): Promise<boolean> {
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "" },
  });
  if (!res.ok) return false;
  const user = await res.json();
  return user?.app_metadata?.role === "admin";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization || !(await isAdmin(authorization))) {
    return json({ error: "admins only" }, 403);
  }
  const token = Deno.env.get("GITHUB_SYNC_TOKEN");
  if (!token) return json({ error: "GITHUB_SYNC_TOKEN is not set" }, 501);

  const { action } = await req.json().catch(() => ({}));
  const gh = (path: string, init?: RequestInit) =>
    fetch(`https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });

  if (action === "status") {
    const res = await gh("runs?per_page=1");
    if (!res.ok) return json({ error: `GitHub ${res.status}` }, 502);
    const run = (await res.json()).workflow_runs?.[0];
    return json({
      last: run && {
        status: run.status, // queued | in_progress | completed
        conclusion: run.conclusion, // success | failure | ...
        started_at: run.run_started_at,
        updated_at: run.updated_at,
        url: run.html_url,
      },
    });
  }
  if (action === "run") {
    const res = await gh("dispatches", {
      method: "POST",
      body: JSON.stringify({ ref: "main", inputs: { preview: "false" } }),
    });
    if (res.status !== 204) return json({ error: `GitHub ${res.status}` }, 502);
    return json({ ok: true });
  }
  return json({ error: "unknown action" }, 400);
});
