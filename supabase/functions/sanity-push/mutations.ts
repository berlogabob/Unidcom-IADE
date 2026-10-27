// Member mapping originated in scripts/sanity_push.py; schema alignment lives here.
// One pure function per Sanity type; each returns [createIfNotExists, patch]. Only mapped fields
// are set (empty ones unset); everything else on the Sanity document (seo, CV arrays, ...) is untouched.
export type Row = {
  id: string;
  preferred_name: string;
  bio: string | null;
  orcid: string | null;
  ciencia_id: string | null;
  membership_type: string | null;
  public_visibility: boolean | null;
  merged_into: string | null;
  sanity_id: string | null;
  research_interests?: string | null;
  board_role?: string[] | null;
  photo_url?: string | null;
  email?: string | null;
  phd?: boolean | string | null;
};

// Legacy Integrated id used by sanity-pull comparisons; push resolves titles in its target.
export const MEMBER_TYPES: Record<string, string> = { integrated: "bc4e4611-3a0b-4480-8f76-d85fb8eefa9d" };

export const slugify = (v: string) =>
  v.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 80).replace(/-+$/, "");

export const published = (r: Row) => r.merged_into === null && r.public_visibility === true;

type Mutation = Record<string, unknown>;
type Fields = Record<string, unknown>;

const ref = (id: string) => ({ _type: "reference", _ref: id });
const empty = (v: unknown) => v == null || v === "" || (Array.isArray(v) && v.length === 0);

const SLUGGED = new Set(["member", "project", "lab", "article", "event"]);

// Shared tail: create the doc if missing, then set the owned fields and unset the empty ones.
function build(id: string, type: string, name: string, owned: Fields, extra: Fields = {}): Mutation[] {
  const set: Fields = {};
  const unset: string[] = [];
  for (const [k, v] of Object.entries(owned)) empty(v) ? unset.push(k) : (set[k] = v);
  return [
    { createIfNotExists: { _id: id, _type: type, ...extra, ...(SLUGGED.has(type) && { slug: { _type: "slug", current: slugify(name) } }) } },
    { patch: { id, set, unset } },
  ];
}

// Plain paragraphs (blank-line separated) -> minimal Portable Text.
export const portable = (text: string | null) =>
  (text ?? "").split(/\n{2,}/).map((p) => p.trim()).filter(Boolean).map((p, i) => ({
    _type: "block", _key: `p${i}`, style: "normal", markDefs: [],
    children: [{ _type: "span", _key: `s${i}`, text: p, marks: [] }],
  }));

// flexibleDate: { precision, date | month }.
export function flexibleDate(d: string | null, precision: string | null) {
  if (!d) return null;
  const p = precision ?? "day";
  return p === "day" ? { precision: p, date: d } : { precision: p, month: d.slice(0, p === "year" ? 4 : 7) };
}

// Existing members own their Sanity type, regardless of the portal membership label.
export function mutations(r: Row, existing?: string, memberType?: string) {
  if (r.sanity_id || existing) memberType = undefined;
  const id = r.sanity_id || existing || `rims-${r.id}`;
  const extra: Fields = { name: r.preferred_name };
  if (memberType) extra.type = ref(memberType);
  const result = build(id, "member", r.preferred_name, {
    ...(memberType && { type: ref(memberType) }),
    name: r.preferred_name,
    shortBio: r.bio,
    orcid: r.orcid,
    cienciaId: r.ciencia_id,
    researchInterests: r.research_interests,
    boardRole: r.board_role?.[0],
  }, extra);
  // Studio locks published slugs; fill missing slugs without changing existing URLs.
  (result[1].patch as Fields).setIfMissing = { slug: { _type: "slug", current: slugify(r.preferred_name) } };
  return result;
}

export type Project = {
  id: string; sanity_id: string | null; title: string; slug: string | null; description: string | null;
  status: string | null; start_date: string | null; end_date: string | null;
  start_precision: string | null; end_precision: string | null; total_budget: number | null;
  keywords: string[] | null; location: string | null; reference_number: string | null;
  website: string | null; partners: { name: string }[] | null; results: string | null;
  funder: string | null; // sanity id of the funder
  clusters: string[]; // sanity ids
  team: Record<string, string[]>; // pi/coPi/members/... -> person sanity ids
};

// Portal statuses are planned/active/completed/cancelled; Sanity has ongoing/completed.
const PROJECT_STATUS: Record<string, string> = { planned: "ongoing", active: "ongoing", completed: "completed" };

export function projectMutations(p: Project) {
  const id = p.sanity_id || `rims-${p.id}`;
  const team: Fields = {};
  for (const [k, ids] of Object.entries(p.team)) if (ids.length) team[k] = ids.map((x, i) => ({ ...ref(x), _key: `${k}${i}` }));
  return build(id, "project", p.slug || p.title, {
    title: p.title,
    slug: { _type: "slug", current: p.slug || slugify(p.title) },
    abstract: p.description,
    status: p.status ? PROJECT_STATUS[p.status] : null,
    startingDate: flexibleDate(p.start_date, p.start_precision),
    endingDate: flexibleDate(p.end_date, p.end_precision),
    fundingValue: p.total_budget,
    keywords: p.keywords,
    location: p.location,
    referenceNumber: p.reference_number,
    website: p.website,
    results: p.results ? portable(p.results) : null,
    funder: p.funder ? ref(p.funder) : null,
    clusters: p.clusters.map((x, i) => ({ ...ref(x), _key: `c${i}` })),
    team: Object.keys(team).length ? team : null,
  }, { title: p.title });
}

export type Lab = {
  id: string; sanity_id: string | null; name: string; slug: string | null; short_intro: string | null;
  overview: string | null; website: string | null; coordinators: string[]; members: string[]; projects: string[];
};

export function labMutations(l: Lab) {
  const id = l.sanity_id || `rims-${l.id}`;
  const refs = (ids: string[], k: string) => ids.map((x, i) => ({ ...ref(x), _key: `${k}${i}` }));
  return build(id, "lab", l.slug || l.name, {
    title: l.name,
    slug: { _type: "slug", current: l.slug || slugify(l.name) },
    shortIntro: l.short_intro,
    description: l.overview,
    website: l.website,
    coordinators: refs(l.coordinators, "co"),
    members: refs(l.members, "m"),
    projects: refs(l.projects, "p"),
  }, { title: l.name });
}

export type Cluster = { id: string; sanity_id: string | null; code: string | null; name: string; concern: string | null; description: string | null };

export function clusterMutations(c: Cluster) {
  const id = c.sanity_id || `rims-${c.id}`;
  return build(id, "cluster", c.name, {
    title: c.name, code: c.code, concern: c.concern, description: c.description,
  }, { title: c.name });
}

export type Output = {
  id: string; sanity_id: string | null; title: string; reporting_year: number | null; full_reference: string | null;
  url: string | null; doi: string | null; keywords: string[] | null; members: string[];
  type?: string | null; subtype?: string | null; macro_type?: string | null; category_path?: string | null;
  clusters?: { sanity_id: string | null }[] | null;
  scientific_areas?: { sanity_id: string | null }[] | null;
};

// ORCID work kinds and the portal's Portuguese reporting taxonomy.
const OUTPUT_TYPES: Record<string, string> = {
  book: "book", "book-chapter": "book", livros: "book", "autoria-de-livro": "book",
  "edicao-de-livro": "book", "capitulos-de-livros": "book",
  journalarticle: "journalArticle", "journal-article": "journalArticle", "artigos-em-revistas": "journalArticle",
  conferencepaper: "conferencePaper", "conference-paper": "conferencePaper",
  abstract: "abstract", "conference-abstract": "abstract", resumo: "abstract", resumos: "abstract",
  patentmodels: "patentModels", patent: "patentModels", patentes: "patentModels", "utility-model": "patentModels",
  exhibition: "exhibition", exposicoes: "exhibition",
};

export function outputType(o: Output): string | undefined {
  const kinds = [o.type, o.subtype, ...(o.category_path?.split(" › ") ?? []), o.macro_type];
  // Proceedings live under Books in the reporting taxonomy.
  if (kinds.some((k) => k && slugify(k).startsWith("atas-de-congressos"))) return "conferencePaper";
  for (const kind of kinds) {
    if (kind && OUTPUT_TYPES[slugify(kind)]) return OUTPUT_TYPES[slugify(kind)];
  }
}

// Only existing Sanity ids may become taxonomy references; never fabricate documents.
const taxonomyRefs = (items: { sanity_id: string | null }[], prefix: string) =>
  [...new Set(items.map((r) => r.sanity_id).filter((id): id is string => !!id))]
    .map((id, i) => ({ ...ref(id), _key: `${prefix}${i}` }));

export function outputMutations(o: Output, includeMembers = true) {
  const id = o.sanity_id || `rims-${o.id}`;
  return build(id, "researchOutput", o.title, {
    title: o.title,
    ...(!o.sanity_id && { type: outputType(o) }),
    migrated: true,
    year: o.reporting_year,
    citation: o.full_reference?.trim() || o.title.trim() || "Untitled output",
    link: o.url || (o.doi ? `https://doi.org/${o.doi}` : null),
    keywords: o.keywords?.slice(0, 6),
    ...(o.clusters != null && { clusters: taxonomyRefs(o.clusters, "c") }),
    ...(o.scientific_areas != null && { scientificAreas: taxonomyRefs(o.scientific_areas, "s") }),
    ...(includeMembers && { members: o.members.map((x, i) => ({ ...ref(x), _key: `m${i}` })) }),
  }, { title: o.title, migrated: true });
}

// Strong references are attached only after all selected documents exist.
export function singleEntityMutations(outputs: Output[], members: Mutation[][]): Mutation[] {
  return [
    ...outputs.flatMap((o) => outputMutations(o, false)),
    ...members.flat(),
    ...outputs.map((o) => ({ patch: {
      id: o.sanity_id || `rims-${o.id}`,
      set: { members: o.members.map((x, i) => ({ ...ref(x), _key: `m${i}` })) },
    } })),
  ];
}

export type Funder = { id: string; sanity_id: string | null; title: string };
export const funderMutations = (f: Funder) =>
  build(f.sanity_id || `rims-${f.id}`, "funder", f.title, { title: f.title });

export type Article = {
  id: string; sanity_id: string | null; title: string; slug: string; date: string;
  excerpt: string | null; body: string | null; category?: string | null;
  news_type?: string | null; scientific_areas?: string[] | null;
};

// Resolve in the target dataset, never send portal taxonomy strings as references.
// Missing/ambiguous values warn and preserve the existing Sanity field.
export async function articleReferences(
  a: Article,
  query: (groq: string, params: Record<string, string>) => Promise<unknown>,
  warnings: string[],
): Promise<{ category?: string; scientificAreas?: string[] }> {
  async function lookup(type: string, field: string, value: string) {
    try {
      const ids = await query(`*[_type == "${type}" && !(_id in path("drafts.**")) && lower(${field}) == $value]._id`, { value: value.trim().toLowerCase() });
      if (Array.isArray(ids) && ids.length === 1 && typeof ids[0] === "string") return ids[0];
    } catch (error) {
      warnings.push(`Article ${a.id}: ${type} lookup failed: ${String(error)}`);
    }
    warnings.push(`Article ${a.id}: cannot resolve ${type} (${value || "missing"})`);
    return undefined;
  }
  const category = await lookup("articleCategory", "name", a.news_type?.trim() || a.category || "");
  let scientificAreas: string[] | undefined;
  if (a.scientific_areas != null) {
    const ids = await Promise.all(a.scientific_areas.map((title) => lookup("scientificArea", "title", title)));
    // An unresolved selection must not silently erase existing associations.
    if (ids.every((id) => id !== undefined)) scientificAreas = [...new Set(ids as string[])];
  }
  return { category, scientificAreas };
}

export function articleMutations(a: Article, resolved: { category?: string; scientificAreas?: string[] } = {}) {
  return build(a.sanity_id || `rims-${a.id}`, "article", a.slug, {
    title: a.title, slug: { _type: "slug", current: a.slug }, date: a.date, excerpt: a.excerpt,
    body: a.body ? portable(a.body) : null,
    ...(resolved.category && { category: ref(resolved.category) }),
    ...(resolved.scientificAreas !== undefined && {
      scientificAreas: resolved.scientificAreas.map((id, i) => ({ ...ref(id), _key: `s${i}` })),
    }),
  }, { title: a.title });
}

export type Event = {
  id: string; sanity_id: string | null; title: string; slug: string; location: string | null;
  start_date: string | null; end_date: string | null; start_time: string | null; end_time: string | null;
  external_link: string | null; language: string | null; cost: string | null; registration_url: string | null;
  format: string | null; modality: string | null;
};
export function eventMutations(e: Event) {
  return build(e.sanity_id || `rims-${e.id}`, "event", e.slug, {
    title: e.title, slug: { _type: "slug", current: e.slug }, location: e.location,
    startDate: e.start_date, endDate: e.end_date, startTime: e.start_time?.slice(0, 5), endTime: e.end_time?.slice(0, 5),
    externalLink: e.external_link, language: e.language, cost: e.cost, registrationUrl: e.registration_url,
    format: e.format, modality: e.modality,
  }, { title: e.title });
}
