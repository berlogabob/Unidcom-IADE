// Port of scripts/sanity_push.py (mutations / published / slugify) — keep the two in step.
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
};

// memberType documents in the dump; collaborator/external have no counterpart.
const MEMBER_TYPES: Record<string, string> = { integrated: "bc4e4611-3a0b-4480-8f76-d85fb8eefa9d" };

export const slugify = (v: string) =>
  v.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 80).replace(/-+$/, "");

export const published = (r: Row) => r.merged_into === null && r.public_visibility === true;

// `existing`: the Sanity member with the same slug, so a profile updates its document
// instead of creating a duplicate beside it (people.sanity_id is not filled in yet).
export function mutations(r: Row, existing?: string) {
  const id = r.sanity_id || existing || `rims-${r.id}`;
  const created: Record<string, unknown> = {
    _id: id,
    _type: "member",
    name: r.preferred_name,
    slug: { _type: "slug", current: slugify(r.preferred_name) },
  };
  if (r.membership_type && MEMBER_TYPES[r.membership_type]) {
    created.type = { _type: "reference", _ref: MEMBER_TYPES[r.membership_type] };
  }
  const owned: Record<string, string | null> = {
    name: r.preferred_name,
    shortBio: r.bio,
    orcid: r.orcid,
    cienciaId: r.ciencia_id,
  };
  const set: Record<string, string> = {};
  const unset: string[] = [];
  for (const [k, v] of Object.entries(owned)) v ? (set[k] = v) : unset.push(k);
  return [{ createIfNotExists: created }, { patch: { id, set, unset } }];
}
