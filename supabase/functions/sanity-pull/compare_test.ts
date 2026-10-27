import { assert, assertEquals } from "jsr:@std/assert@1";
import { compare, type RecordRow } from "./compare.ts";
const p = {
  id: "p",
  preferred_name: "Zé Árvore",
  membership_type: "integrated",
};
const w = {
  _id: "w",
  name: "Zé Árvore",
  slug: "ze-arvore",
  memberType: "Integrated",
};
const run = (people: RecordRow[] = [p], members: RecordRow[] = [w]) =>
  compare(people, [], members, []);

Deno.test("same, website-only note, portal-only and field differences", () => {
  assertEquals(run().counts, {
    same: 1,
    website_only: 0,
    portal_only: 0,
    differs: 0,
  });
  const result = run([p, { id: "other", preferred_name: "Other" }], [{
    ...w,
    email: "hello@example.org",
  }, { _id: "new", name: "New" }]);
  assertEquals(result.counts, {
    same: 0,
    website_only: 1,
    portal_only: 1,
    differs: 1,
  });
  assertEquals(result.issues.find((i) => i.kind === "differs")?.fields, [{
    name: "email",
    portal: "",
    website: "hello@example.org",
  }]);
  assert(
    result.issues.find((i) => i.kind === "website_only")?.note?.includes(
      "no import",
    ),
  );
});
Deno.test("explicit ids take priority and never fall back to a different document", () => {
  assertEquals(
    run([{ ...p, sanity_id: "w" }], [{
      ...w,
      name: "Changed",
      slug: "changed",
    }]).counts.differs,
    1,
  );
  assertEquals(run([{ ...p, sanity_id: "absent" }]).counts.website_only, 1);
  const result = run([p, { ...p, id: "strong", sanity_id: "w" }]);
  assertEquals(result.issues.find((i) => i.key === "w")?.kind, "same");
  assertEquals(result.counts.portal_only, 1);
});
Deno.test("slug, ORCID URL, normalized name, blanks and duplicates", () => {
  assertEquals(
    run([p], [{ ...w, slug: "custom", name: "ze arvore" }]).counts.differs,
    1,
  );
  assertEquals(
    run([{ ...p, orcid: "https://orcid.org/0000-0000-0000-000X" }], [{
      ...w,
      slug: "other",
      name: "Other",
      orcid: "0000-0000-0000-000x",
    }]).counts.differs,
    1,
  );
  assertEquals(run([p, { ...p, id: "duplicate" }]).counts.same, 0);
  assertEquals(run([{ id: "p" }], [{ _id: "w" }]).counts.same, 0);
  assertEquals(run([], []).issues, []);
});
Deno.test("outputs match DOI, link, title/year; compare mapped author sets and citation", () => {
  const output = {
    id: "o",
    title: "Paper",
    reporting_year: 2026,
    doi: "10.1234/ABC",
    full_reference: "Citation",
    output_authors: [{ person_id: "p" }],
  };
  const research = {
    _id: "r",
    title: "Paper",
    year: 2026,
    link: "https://doi.org/10.1234/abc",
    citation: "Citation",
    members: [{ _ref: "w" }, { _ref: "w" }],
  };
  assertEquals(compare([p], [output], [w], [research]).counts.same, 2);
  const changed = compare([p], [output], [w], [{
    ...research,
    members: [{ _ref: "unknown" }],
    citation: "Different",
  }]);
  assertEquals(
    changed.issues.find((i) => i.entity === "outputs")?.fields.map((f) =>
      f.name
    ),
    ["citation", "members"],
  );
  assertEquals(
    compare([], [{ ...output, doi: null, url: "https://example.org/" }], [], [{
      ...research,
      link: "https://example.org",
    }]).counts.differs,
    1,
  );
  assertEquals(
    compare([], [{ ...output, doi: null }], [], [{
      ...research,
      title: "Páper",
      link: null,
    }]).counts.differs,
    1,
  );
  assertEquals(
    compare([], [{ ...output, sanity_id: "r", title: "Changed" }], [], [
      research,
    ]).counts.differs,
    1,
  );
  assertEquals(
    compare([], [{ ...output, sanity_id: "elsewhere" }], [], [research]).counts
      .website_only,
    1,
  );
});
Deno.test("comparison is deterministic, does not mutate inputs or conflate absent years", () => {
  const people = [p];
  const members = [w];
  const before = JSON.stringify({ people, members });
  run(people, members);
  assertEquals(JSON.stringify({ people, members }), before);
  assertEquals(
    compare([], [{ id: "o", title: "Paper" }], [], [{
      _id: "r",
      title: "Paper",
    }]).counts,
    { same: 0, differs: 0, portal_only: 1, website_only: 1 },
  );
});
