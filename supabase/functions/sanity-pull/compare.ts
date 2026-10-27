import { MEMBER_TYPES, slugify } from "../sanity-push/mutations.ts";

export type RecordRow = Record<string, unknown>;
export type Kind = "same" | "website_only" | "portal_only" | "differs";
export type Issue = {
  kind: Kind;
  entity: "people" | "outputs";
  key: string;
  label: string;
  fields: { name: string; portal: unknown; website: unknown }[];
  note?: string;
};
type Item = {
  id: string;
  linked?: string;
  label: string;
  keys: string[];
  values: RecordRow;
};
const text = (v: unknown) => String(v ?? "").trim().replace(/\s+/g, " ");
// Same accent/whitespace folding as scripts/common.py; no fuzzy auto-matches.
const normalized = (v: unknown) =>
  text(v).normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
const orcid = (v: unknown) =>
  text(v).replace(/^https?:\/\/(www\.)?orcid\.org\//i, "").toUpperCase();
const doi = (v: unknown) =>
  text(v).match(/10\.\d{4,9}\/[^\s"<>]+/i)?.[0].replace(/[).,;]+$/, "")
    .toLowerCase() ?? "";
const link = (v: unknown) => {
  const value = text(v);
  if (!value) return "";
  if (doi(value)) return `https://doi.org/${doi(value)}`;
  try {
    const u = new URL(value);
    u.hash = "";
    return u.toString().replace(/\/$/, "");
  } catch {
    return value;
  }
};
const refs = (v: unknown, field: string) =>
  (Array.isArray(v) ? v : []).flatMap((r) => {
    const id = (r as RecordRow)?.[field];
    return typeof id === "string" ? [id] : [];
  });
const sorted = (v: string[]) => [...new Set(v)].sort();
const canonical = (v: unknown): unknown =>
  Array.isArray(v) ? sorted(v.map(text)) : text(v);

// Resolve each strength globally before trying weaker keys. Duplicate identities
// stay unpaired rather than allowing input order to choose a person or output.
function pair(portal: Item[], website: Item[]) {
  const matches = new Map<Item, Item>();
  const used = new Set<Item>();
  for (let tier = -1; tier < (portal[0]?.keys.length ?? 0); tier++) {
    const pKey = (p: Item) =>
      tier === -1 ? p.linked : p.linked ? "" : p.keys[tier];
    const wKey = (w: Item) => tier === -1 ? w.id : w.keys[tier];
    for (const p of portal) {
      const key = pKey(p);
      if (!key || matches.has(p)) continue;
      const candidates = website.filter((w) => !used.has(w) && wKey(w) === key);
      const peers = portal.filter((other) =>
        !matches.has(other) && pKey(other) === key
      );
      if (candidates.length === 1 && peers.length === 1) {
        matches.set(p, candidates[0]);
        used.add(candidates[0]);
      }
    }
  }
  return { matches, used };
}

export function compare(
  people: RecordRow[],
  outputs: RecordRow[],
  members: RecordRow[],
  research: RecordRow[],
) {
  const person = (r: RecordRow, website: boolean): Item => {
    const name = text(website ? r.name : r.preferred_name);
    const slug = website ? text(r.slug) : slugify(name);
    const type = website ? r.memberType : r.membership_type;
    // Reuse the bridge's known mapping; retain unknown titles for human review.
    const memberType = website && r.memberTypeId === MEMBER_TYPES.integrated
      ? "integrated"
      : normalized(type).replace(/_/g, " ");
    return {
      id: text(website ? r._id : r.id),
      linked: website ? undefined : text(r.sanity_id),
      label: name,
      keys: [slug, orcid(r.orcid), normalized(name)],
      values: {
        name,
        slug,
        orcid: orcid(r.orcid),
        email: text(r.email).toLowerCase(),
        shortBio: text(website ? r.shortBio : r.bio),
        memberType,
      },
    };
  };
  const pp = people.map((r) => person(r, false));
  const wp = members.map((r) => person(r, true));
  const personPairs = pair(pp, wp);
  const memberIds = new Map(
    pp.map((p) => [p.id, personPairs.matches.get(p)?.id ?? `portal:${p.id}`]),
  );
  const output = (r: RecordRow, website: boolean): Item => {
    const title = text(r.title);
    const year = text(website ? r.year : r.reporting_year);
    const url = website
      ? r.link
      : r.url || (r.doi ? `https://doi.org/${r.doi}` : "");
    return {
      id: text(website ? r._id : r.id),
      linked: website ? undefined : text(r.sanity_id),
      label: title,
      keys: [
        doi(website ? r.link : r.doi) || doi(url),
        link(url),
        normalized(title) && year ? `${normalized(title)}|${year}` : "",
      ],
      values: {
        title,
        year,
        link: link(url),
        citation: text(website ? r.citation : r.full_reference),
        members: sorted(
          website
            ? refs(r.members, "_ref")
            : refs(r.output_authors, "person_id").map((id) =>
              memberIds.get(id) ?? `portal:${id}`
            ),
        ),
      },
    };
  };
  const issues: Issue[] = [];
  function collect(
    entity: Issue["entity"],
    portal: Item[],
    website: Item[],
    pairs = pair(portal, website),
  ) {
    const add = (p?: Item, w?: Item) => {
      const fields = Object.keys((p ?? w)!.values).map((name) => ({
        name,
        portal: p?.values[name] ?? null,
        website: w?.values[name] ?? null,
      }))
        .filter((f) =>
          !p || !w ||
          JSON.stringify(canonical(f.portal)) !==
            JSON.stringify(canonical(f.website))
        );
      const kind = !p
        ? "website_only"
        : !w
        ? "portal_only"
        : fields.length
        ? "differs"
        : "same";
      issues.push({
        kind,
        entity,
        key: w?.id ?? p!.id,
        label: (w ?? p)!.label,
        fields,
        ...(kind === "website_only" &&
          {
            note:
              "Website record missing from portal (or ambiguous match). Review before adding to portal; no import performed.",
          }),
        ...(kind === "portal_only" &&
          {
            note:
              "No unique website match. May be unpublished, explicitly linked elsewhere, or ambiguous.",
          }),
      });
    };
    for (const p of portal) add(p, pairs.matches.get(p));
    for (const w of website) if (!pairs.used.has(w)) add(undefined, w);
  }
  collect("people", pp, wp, personPairs);
  collect(
    "outputs",
    outputs.map((r) => output(r, false)),
    research.map((r) => output(r, true)),
  );
  issues.sort((a, b) =>
    a.entity.localeCompare(b.entity) || a.key.localeCompare(b.key)
  );
  const counts = { same: 0, website_only: 0, portal_only: 0, differs: 0 };
  for (const i of issues) counts[i.kind]++;
  return { counts, issues };
}
