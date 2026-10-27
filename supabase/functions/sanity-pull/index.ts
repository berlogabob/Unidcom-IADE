// Read-only: anonymous published Sanity documents + unmerged portal records.
import { compare, type RecordRow } from "./compare.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
async function isAdmin(authorization: string) {
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    },
  });
  return res.ok && (await res.json())?.app_metadata?.role === "admin";
}
async function rows(query: string): Promise<RecordRow[]> {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const all: RecordRow[] = [];
  // PostgREST caps responses; page to avoid false website-only issues.
  for (let offset = 0;; offset += 500) {
    const res = await fetch(
      `${
        Deno.env.get("SUPABASE_URL")
      }/rest/v1/${query}&order=id&limit=500&offset=${offset}`,
      {
        headers: { apikey: key, Authorization: `Bearer ${key}` },
      },
    );
    if (!res.ok) {
      throw new Error(`database ${res.status} (${query.split("?")[0]})`);
    }
    const page: RecordRow[] = await res.json();
    all.push(...page);
    if (page.length < 500) return all;
  }
}
export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  try {
    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization || !(await isAdmin(authorization))) {
      return json({ error: "admins only" }, 403);
    }
    const project = Deno.env.get("SANITY_PULL_PROJECT") ?? "vj0axykv";
    const query = `{
      "members": *[_type == "member" && !(_id in path("drafts.**"))]{_id,name,"slug":slug.current,orcid,email,shortBio,"memberType":type->title,"memberTypeId":type._ref},
      "outputs": *[_type == "researchOutput" && !(_id in path("drafts.**"))]{_id,title,year,link,citation,members[]{_ref}}
    }`;
    const [sanity, people, outputs] = await Promise.all([
      fetch(
        `https://${project}.api.sanity.io/v2025-02-19/data/query/production?query=${
          encodeURIComponent(query)
        }`,
      ),
      rows(
        "people?select=id,sanity_id,preferred_name,orcid,email,bio,membership_type&merged_into=is.null",
      ),
      rows(
        "outputs?select=id,sanity_id,title,reporting_year,doi,url,full_reference,output_authors(person_id)&merged_into=is.null",
      ),
    ]);
    if (!sanity.ok) throw new Error(`Sanity ${sanity.status}`);
    const result = (await sanity.json()).result;
    if (!Array.isArray(result?.members) || !Array.isArray(result?.outputs)) {
      throw new Error("Invalid Sanity response");
    }
    return json(compare(people, outputs, result.members, result.outputs));
  } catch (error) {
    return json({ error: String(error) }, 502);
  }
}

if (import.meta.main) Deno.serve(handleRequest);
