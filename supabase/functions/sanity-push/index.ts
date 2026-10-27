// POST { types?: string[], personId?: string, outputIds?: string[], dryRun?: boolean } — admin-only.
// Pushes the portal's website content
// (members, clusters, outputs, projects, labs, funders, articles, events) to Sanity, one way (portal wins
// on mapped fields only). Default target is the TEST project ld5jhf23; the agency's vj0axykv is refused
// unless ALLOW_PROD=true. Secret: SANITY_TOKEN. Like scripts/sanity_push.py for members.
import {
  articleMutations, articleReferences, clusterMutations, eventMutations, funderMutations, labMutations, mutations, outputMutations,
  outputType, projectMutations, published, Row, singleEntityMutations,
} from "./mutations.ts";

import { memberTypeTitle, resolver } from "./resolution.ts";

const AGENCY = "vj0axykv";
const PROJECT = Deno.env.get("SANITY_PROJECT") ?? "ld5jhf23";
const DATASET = Deno.env.get("SANITY_DATASET") ?? "production";
const API = `https://${PROJECT}.api.sanity.io/v2025-02-19`;
const ORDER = ["funders", "members", "clusters", "outputs", "projects", "labs", "articles", "events"];

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

const key = () => Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dbHeaders = () => ({ apikey: key(), Authorization: `Bearer ${key()}` });
async function rows<T>(query: string): Promise<T[]> {
  const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/${query}`, { headers: dbHeaders() });
  if (!res.ok) throw new Error(`database ${res.status} (${query.split("?")[0]})`);
  return await res.json();
}

type Mut = Record<string, any>;
const idOf = (r: { id: string; sanity_id: string | null }) => r.sanity_id || `rims-${r.id}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization || !(await isAdmin(authorization))) return json({ error: "admins only" }, 403);
  if (PROJECT === AGENCY && Deno.env.get("ALLOW_PROD") !== "true") return json({ error: "refusing the agency project" }, 400);
  const token = Deno.env.get("SANITY_TOKEN");
  if (!token) return json({ error: "SANITY_TOKEN is not set" }, 501);
  const auth = { Authorization: `Bearer ${token}` };

  const body = await req.json().catch(() => ({}));
  if (!body || typeof body !== "object" ||
    (body.personId !== undefined && (typeof body.personId !== "string" || !body.personId.trim())) ||
    (body.outputIds !== undefined && (!Array.isArray(body.outputIds) || body.outputIds.some((id: unknown) => typeof id !== "string" || !id.trim()))) ||
    (body.dryRun !== undefined && typeof body.dryRun !== "boolean")) {
    return json({ error: "invalid personId, outputIds or dryRun" }, 400);
  }
  const selected = body.personId !== undefined || body.outputIds !== undefined;
  const dryRun = body.dryRun === true;
  const want: string[] = Array.isArray(body.types) && body.types.length ? body.types : ORDER;
  const unknown = want.filter((t) => !ORDER.includes(t));
  if (unknown.length) return json({ error: `unknown types: ${unknown.join(", ")}` }, 400);

  // Sanity dedupes identical uploads by content hash, so re-pushing a photo returns the same asset.
  async function image(url: string | null | undefined) {
    if (!url || dryRun) return null;
    const src = await fetch(url);
    if (!src.ok) return null;
    const up = await fetch(`${API}/assets/images/${DATASET}`, {
      method: "POST",
      headers: { ...auth, "Content-Type": src.headers.get("content-type") ?? "image/jpeg" },
      body: await src.arrayBuffer(),
    });
    const id = up.ok ? (await up.json())?.document?._id : null;
    return id ? { _type: "image", asset: { _type: "reference", _ref: id } } : null;
  }
  // Add an uploaded image to a [create, patch] pair when the portal row has one.
  async function withImage(m: Mut[], field: string, url: string | null | undefined) {
    const img = await image(url);
    if (img) { m[1].patch.set[field] = img; m[1].patch.unset = m[1].patch.unset.filter((k: string) => k !== field); }
    return m;
  }

  const warnings: string[] = [];
  async function query(groq: string, params: Record<string, string> = {}) {
    const search = new URLSearchParams({ query: groq });
    for (const [k, v] of Object.entries(params)) search.set(`$${k}`, JSON.stringify(v));
    const response = await fetch(`${API}/data/query/${DATASET}?${search}`, { headers: auth });
    if (!response.ok) throw new Error(`Sanity ${response.status}`);
    const body = await response.json();
    if (!("result" in body)) throw new Error("Sanity query returned no result");
    return body.result;
  }
  const resolve = resolver(query);
  const { matched, wouldCreate } = resolve;
  const memberTypes = new Map<string, string | undefined>();
  async function memberMutation(p: Row) {
    const found = await resolve.member(p);
    let type: string | undefined;
    if (!found.existing) {
      const title = memberTypeTitle(p);
      if (title && !memberTypes.has(title)) {
        try {
          const ids: string[] = await query('*[_type == "memberType" && !(_id in path("drafts.**")) && lower(title) == $title]._id', { title: title.toLowerCase() });
          memberTypes.set(title, ids.length === 1 ? ids[0] : undefined);
        } catch (e) {
          memberTypes.set(title, undefined);
          warnings.push(`Member ${p.id}: memberType lookup failed: ${String(e)}`);
        }
      }
      type = title ? memberTypes.get(title) : undefined;
      if (!type) warnings.push(`Member ${p.id}: cannot resolve memberType for ${p.membership_type ?? "missing membership_type"}${title ? ` (${title})` : "; no certain mapping (phd must be explicitly true/false for integrated members)"}`);
    }
    return withImage(mutations(p, found.existing ? found.id : undefined, type), "photo", p.photo_url);
  }
  async function outputsWhere(filter: string) {
    const outputs = await rows<any>(
      `outputs?select=*,output_authors(person_id),project_outputs(projects(project_clusters(clusters(sanity_id))))&${filter}&merged_into=is.null`,
    );
    return outputs.map((o) => {
      if (!outputType(o)) warnings.push(`Output ${o.id}: cannot map output type ${o.type ?? o.macro_type ?? "(missing)"}`);
      const clusters = (o.project_outputs ?? []).flatMap((link: any) =>
        (link.projects?.project_clusters ?? []).flatMap((c: any) => c.clusters ? [c.clusters] : [])
      );
      return { ...o, ...(clusters.length && { clusters: [...(o.clusters ?? []), ...clusters] }) };
    });
  }

  try {
    const people = await rows<Row & { id: string }>(
      "people?select=id,preferred_name,bio,orcid,email,phd,ciencia_id,membership_type,public_visibility,merged_into,sanity_id,research_interests,board_role,photo_url&merged_into=is.null",
    );
    const pubPeople = people.filter(published);

    if (selected) {
      const ids = [...new Set<string>(body.outputIds ?? [])];
      const outputs = ids.length ? await outputsWhere(
        `id=in.${encodeURIComponent(`(${ids.map((id) => JSON.stringify(id)).join(",")})`)}`,
      ) : [];
      const needed = new Set<string>(body.personId ? [body.personId] : []);
      for (const o of outputs) for (const a of o.output_authors) if (a.person_id) needed.add(a.person_id);
      // Explicit selection includes private people, but never merged rows.
      const members = people.filter((p) => needed.has(p.id));
      const memberMutations: Mut[][] = [];
      for (const p of members) memberMutations.push(await memberMutation(p));
      const memberIds = new Map(members.map((p, i) => [p.id, memberMutations[i][0].createIfNotExists._id as string]));
      const dropped: { outputId: string; personId: string | null }[] = [];
      const mappedOutputs: any[] = [];
      for (const o of outputs) {
        const found = await resolve.output(o);
        mappedOutputs.push({ ...o, sanity_id: found.existing ? found.id : null,
          members: o.output_authors.flatMap((a: any) => {
            const id = memberIds.get(a.person_id);
            if (id) return [id];
            dropped.push({ outputId: o.id, personId: a.person_id ?? null });
            return [];
          }),
        });
      }
      const all = singleEntityMutations(mappedOutputs, memberMutations);
      const counts = { outputs: outputs.length, members: members.length };
      if (dryRun) return json({ project: PROJECT, counts, dropped, warnings, matched, wouldCreate, mutations: all });
      for (let i = 0; i < all.length; i += 100) {
        const r = await fetch(`${API}/data/mutate/${DATASET}`, {
          method: "POST", headers: { ...auth, "Content-Type": "application/json" },
          body: JSON.stringify({ mutations: all.slice(i, i + 100) }),
        });
        if (!r.ok) return json({ error: `Sanity ${r.status}: ${(await r.text()).slice(0, 300)}`, dropped, warnings, matched, wouldCreate }, 502);
      }
      for (const [table, items] of [["outputs", outputs], ["people", members]] as const) {
        await Promise.all(items.filter((r) => !r.sanity_id).map((r) =>
          fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/${table}?id=eq.${r.id}`, {
            method: "PATCH", headers: { ...dbHeaders(), "Content-Type": "application/json" },
            body: JSON.stringify({ sanity_id: table === "people" ? memberIds.get(r.id) : mappedOutputs.find((o) => o.id === r.id)?.sanity_id || idOf(r) }),
          })
        ));
      }
      return json({ project: PROJECT, counts, dropped, warnings, matched, wouldCreate });
    }
    // sanity id each published person will have, for references from projects/labs/outputs
    const personId = new Map<string, string>();
    if (want.some((t) => ["members", "outputs", "projects", "labs"].includes(t))) {
      for (const p of pubPeople) personId.set(p.id, (await resolve.member(p)).id);
    }
    const refs = (ids: (string | null)[]) => ids.filter((x): x is string => !!x && personId.has(x)).map((x) => personId.get(x)!);

    const built: Record<string, { table: string; items: { row: any; m: Mut[] }[] }> = {};
    const add = (type: string, table: string, row: any, m: Mut[]) => (built[type] ??= { table, items: [] }).items.push({ row, m });

    if (want.includes("funders")) {
      for (const f of await rows<any>("funders?select=*")) add("funders", "funders", f, await withImage(funderMutations(f), "logo", f.logo_url));
    }
    if (want.includes("members")) {
      for (const p of pubPeople) {
        add("members", "people", p, await memberMutation(p));
      }
    }
    if (want.includes("clusters")) {
      for (const c of await rows<any>("clusters?select=*")) add("clusters", "clusters", c, clusterMutations(c));
    }
    const clusterIds = new Map((await rows<any>("clusters?select=id,sanity_id")).map((c) => [c.id, idOf(c)]));
    const funderIds = new Map((await rows<any>("funders?select=id,sanity_id")).map((f) => [f.id, idOf(f)]));

    if (want.includes("outputs")) {
      const outs = await outputsWhere("website_status=eq.published");
      for (const o of outs) {
        const found = await resolve.output(o);
        add("outputs", "outputs", o, outputMutations({ ...o, sanity_id: found.existing ? found.id : null, members: refs(o.output_authors.map((a: any) => a.person_id)) }));
      }
    }
    // Sanity ids of the pushed (or existing) projects/labs, for lab.projects.
    const projects = await rows<any>(
      "projects?select=*,project_members(person_id,role),project_clusters(cluster_id)&public_visibility=eq.true",
    );
    if (want.includes("projects")) {
      for (const p of projects) {
        const team: Record<string, string[]> = {};
        for (const m of p.project_members) {
          const k = ({ pi: "pi", "co-pi": "coPi", supervisor: "supervisors", mentor: "mentors", phd: "phdStudents" } as Record<string, string>)[(m.role ?? "").toLowerCase()] ?? "members";
          (team[k] ??= []).push(...refs([m.person_id]));
        }
        add("projects", "projects", p, await withImage(projectMutations({
          ...p, funder: p.funder_id ? funderIds.get(p.funder_id) ?? null : null,
          clusters: p.project_clusters.map((c: any) => clusterIds.get(c.cluster_id)).filter(Boolean), team,
        }), "coverImage", p.cover_image_url));
      }
    }
    if (want.includes("labs")) {
      const projectIds = new Map(projects.map((p) => [p.id, idOf(p)]));
      for (const l of await rows<any>("labs?select=*,lab_members(person_id,is_coordinator),project_labs(project_id)")) {
        const coord = refs(l.lab_members.filter((m: any) => m.is_coordinator).map((m: any) => m.person_id));
        let m = labMutations({
          ...l, coordinators: coord, members: refs(l.lab_members.map((x: any) => x.person_id)),
          projects: l.project_labs.map((x: any) => projectIds.get(x.project_id)).filter(Boolean),
        });
        m = await withImage(await withImage(m, "logo", l.logo_url), "coverImage", l.cover_image_url);
        add("labs", "labs", l, m);
      }
    }
    if (want.includes("articles")) {
      for (const a of await rows<any>("articles?select=*&published=eq.true")) add("articles", "articles", a, await withImage(articleMutations(a, await articleReferences(a, query, warnings)), "image", a.image_url));
    }
    if (want.includes("events")) {
      for (const e of await rows<any>("events?select=*&published=eq.true")) add("events", "events", e, await withImage(eventMutations(e), "coverImage", e.cover_image_url));
    }

    // References can resolve members even when this request does not push them.
    const plannedIds = new Set(Object.values(built).flatMap((group) => group.items.map((i) => i.m[0].createIfNotExists._id)));
    wouldCreate.splice(0, wouldCreate.length, ...wouldCreate.filter((r) => plannedIds.has(r.sanity)));
    const counts: Record<string, number> = {};
    if (dryRun) {
      for (const type of ORDER) if (built[type]) counts[type] = built[type].items.length;
      return json({ project: PROJECT, counts, warnings, matched, wouldCreate, mutations: ORDER.flatMap((type) => built[type]?.items.flatMap((i) => i.m) ?? []) });
    }
    for (const type of ORDER) {
      const group = built[type];
      if (!group) continue;
      const all = group.items.flatMap((i) => i.m);
      for (let i = 0; i < all.length; i += 100) {
        const r = await fetch(`${API}/data/mutate/${DATASET}`, {
          method: "POST",
          headers: { ...auth, "Content-Type": "application/json" },
          body: JSON.stringify({ mutations: all.slice(i, i + 100) }),
        });
        if (!r.ok) return json({ error: `Sanity ${r.status} on ${type}: ${(await r.text()).slice(0, 300)}`, counts, warnings, matched, wouldCreate }, 502);
      }
      counts[type] = group.items.length;
      // remember the document id so the next push updates the same document
      await Promise.all(group.items.filter((i) => !i.row.sanity_id).map((i) =>
        fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/${group.table}?id=eq.${i.row.id}`, {
          method: "PATCH",
          headers: { ...dbHeaders(), "Content-Type": "application/json" },
          body: JSON.stringify({ sanity_id: i.m[0].createIfNotExists._id }),
        })
      ));
    }
    return json({ project: PROJECT, counts, warnings, matched, wouldCreate });
  } catch (e) {
    return json({ error: String(e), warnings, matched, wouldCreate }, 502);
  }
});
