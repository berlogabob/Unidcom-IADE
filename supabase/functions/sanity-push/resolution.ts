import { Row, slugify } from "./mutations.ts";

export const normalizeTitle = (v: string) => v.normalize("NFKD").replace(/\p{M}/gu, "")
  .toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
export function normalizeLink(value?: string | null): string {
  let v = (value ?? "").trim();
  try { v = decodeURIComponent(v); } catch { /* Keep malformed escapes literal. */ }
  const doi = v.match(/^(?:doi:\s*|https?:\/\/(?:dx\.)?doi\.org\/)?(10\.\d{4,9}\/\S+)$/i);
  if (doi) return `doi:${doi[1].toLowerCase()}`;
  try {
    const url = new URL(v);
    if (!["http:", "https:"].includes(url.protocol)) return "";
    return `//${url.host.toLowerCase()}${url.pathname.replace(/\/+$/, "")}${url.search}`;
  } catch { return ""; }
}
const orcidKey = (v?: string | null) => (v ?? "").trim().replace(/^https?:\/\/(?:www\.)?orcid.org\//i, "").toUpperCase();
const emailKey = (v?: string | null) => (v ?? "").trim().toLowerCase();

type Doc = { _id: string; orcid?: string; email?: string; slug?: string; link?: string; title?: string; year?: number };
export type Query = (query: string, params?: Record<string, string>) => Promise<any>;
export type Match = { portal: string; sanity: string; by: string };

// Fetch from the configured target project, never from a local dump or agency ids.
export function resolver(query: Query) {
  const docs = new Map<string, Promise<Doc[]>>();
  const claims = new Map<string, string>();
  const cache = new Map<string, { id: string; existing: boolean }>();
  const matched: Match[] = [];
  const wouldCreate: { portal: string; sanity: string }[] = [];
  function load(type: string) {
    if (!docs.has(type)) docs.set(type, query(
      `*[_type == "${type}" && !(_id in path("drafts.**"))]{_id, orcid, email, "slug": slug.current, link, title, year}`,
    ));
    return docs.get(type)!;
  }
  async function resolve(type: string, row: { id: string; sanity_id: string | null },
    criteria: { by: string; matches: (doc: Doc) => boolean }[]) {
    const key = `${type}:${row.id}`;
    if (cache.has(key)) return cache.get(key)!;
    let id = row.sanity_id;
    let by = "";
    if (!id) {
      const documents = await load(type);
      for (const criterion of criteria) {
        const candidates = [...new Set(documents.filter(criterion.matches).map((d) => d._id))];
        if (candidates.length > 1) throw new Error(`Ambiguous ${type} ${row.id} by ${criterion.by}: ${candidates.join(", ")}`);
        if (candidates.length) { id = candidates[0]; by = criterion.by; break; }
      }
    }
    const result = { id: id || `rims-${row.id}`, existing: !!id };
    const owner = claims.get(result.id);
    if (owner && owner !== key) throw new Error(`Multiple portal rows resolve to Sanity ${result.id}`);
    claims.set(result.id, key);
    if (by) matched.push({ portal: row.id, sanity: result.id, by });
    if (!id) wouldCreate.push({ portal: row.id, sanity: result.id });
    cache.set(key, result);
    return result;
  }
  return {
    matched, wouldCreate,
    member: (p: Row) => resolve("member", p, [
      { by: "orcid", matches: (d) => !!orcidKey(p.orcid) && orcidKey(p.orcid) === orcidKey(d.orcid) },
      { by: "email", matches: (d) => !!emailKey(p.email) && emailKey(p.email) === emailKey(d.email) },
      { by: "slug", matches: (d) => !!slugify(p.preferred_name) && slugify(p.preferred_name) === d.slug },
    ]),
    output: (o: { id: string; sanity_id: string | null; url: string | null; doi: string | null; title: string; reporting_year: number | null }) => {
      const links = new Set([normalizeLink(o.url), normalizeLink(o.doi)].filter(Boolean));
      return resolve("researchOutput", o, [
        { by: "link/doi", matches: (d) => !!normalizeLink(d.link) && links.has(normalizeLink(d.link)) },
        { by: "title+year", matches: (d) => o.reporting_year != null && d.year != null &&
          String(o.reporting_year) === String(d.year) && !!normalizeTitle(o.title) && normalizeTitle(o.title) === normalizeTitle(d.title ?? "") },
      ]);
    },
  };
}

export function memberTypeTitle(p: Row): string | undefined {
  switch (p.membership_type) {
    case "integrated":
      return p.phd === false ? "Non-Doctorate Researcher" : p.phd === true ? "Doctorate Researcher" : undefined;
    case "external": return "Visiting researcher";
    case "collaborator": return undefined;
    default: return undefined;
  }
}
