import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { memberTypeTitle, normalizeLink, resolver } from "./resolution.ts";
import { mutations, outputMutations, Row } from "./mutations.ts";

const person: Row = {
  id: "p", preferred_name: "Verónica Silva", orcid: null, email: " Veronica.Silva@example.org ",
  bio: null, ciencia_id: null, membership_type: "collaborator", public_visibility: true,
  merged_into: null, sanity_id: null,
};
const output = {
  id: "o", sanity_id: null, url: null, doi: "10.1234/ABC", title: "É Design!",
  reporting_year: 2020, full_reference: null, keywords: [], members: [], type: "book",
};

Deno.test("mock GROQ resolves Verónica by email despite different slug, preserving type", async () => {
  const resolve = resolver(async (query) => {
    assertEquals(query.includes('_type == "member"'), true);
    assertEquals(query.includes('path("drafts.**")'), true);
    return [{ _id: "member-2aa6aab39b8940e791b4c02c5daaf531", email: "veronica.silva@example.org", slug: "veronica-jeanette-silva-velez" }];
  });
  const found = await resolve.member(person);
  assertEquals(found.existing, true);
  assertEquals(resolve.matched, [{ portal: "p", sanity: found.id, by: "email" }]);
  assertEquals(resolve.wouldCreate, []);
  const pair = mutations(person, found.id, "must-not-overwrite") as any[];
  assertEquals(pair[0].createIfNotExists._id, found.id);
  assertEquals("type" in pair[0].createIfNotExists, false);
  assertEquals("type" in pair[1].patch.set, false);
  assertEquals(pair[1].patch.unset.includes("type"), false);
});

Deno.test("ORCID precedes email and slug; stored ids skip GROQ; unmatched rows create", async () => {
  let queries = 0;
  const resolve = resolver(async () => {
    queries++;
    return [{ _id: "orcid-match", orcid: "https://orcid.org/0000-0001-2345-678X" },
      { _id: "email-match", email: "veronica.silva@example.org" },
      { _id: "slug-match", slug: "veronica-silva" }];
  });
  assertEquals((await resolve.member({ ...person, orcid: "0000-0001-2345-678x" })).id, "orcid-match");
  assertEquals((await resolve.member({ ...person, id: "slug", email: null })).id, "slug-match");
  assertEquals((await resolve.member({ ...person, id: "stored", sanity_id: "original" })).id, "original");
  assertEquals((await resolve.member({ ...person, id: "new", email: null, preferred_name: "New" })).id, "rims-new");
  assertEquals(queries, 1);
  assertEquals(resolve.wouldCreate, [{ portal: "new", sanity: "rims-new" }]);
});

Deno.test("ambiguous identities and competing portal rows fail before creation", async () => {
  const resolve = resolver(async () => [
    { _id: "one", email: "veronica.silva@example.org" },
    { _id: "two", email: "veronica.silva@example.org" },
  ]);
  await assertRejects(() => resolve.member(person), Error, "Ambiguous member");
  assertEquals(resolve.wouldCreate, []);
  const unique = resolver(async () => [{ _id: "one", email: "veronica.silva@example.org" }]);
  await unique.member(person);
  await assertRejects(() => unique.member({ ...person, id: "other" }), Error, "Multiple portal rows");
  const failed = resolver(async () => { throw new Error("Sanity 503"); });
  await assertRejects(() => failed.member(person), Error, "Sanity 503");
  assertEquals(failed.wouldCreate, []);
});

Deno.test("outputs resolve by normalized DOI/link then normalized title and year", async () => {
  const resolve = resolver(async (query) => {
    assertEquals(query.includes('_type == "researchOutput"'), true);
    return [{ _id: "doi", link: "https://doi.org/10.1234/abc" },
      { _id: "title", title: "e design", year: 2020 },
      { _id: "url", link: "https://example.org/p/" }];
  });
  const found = await resolve.output(output);
  assertEquals(found.id, "doi");
  assertEquals((await resolve.output({ ...output, id: "title", doi: null })).id, "title");
  assertEquals((await resolve.output({ ...output, id: "url", doi: null, url: "http://EXAMPLE.org/p" })).id, "url");
  assertEquals((await resolve.output({ ...output, id: "new", doi: null, reporting_year: null })).existing, false);
  assertEquals(resolve.matched.map((m) => m.by), ["link/doi", "title+year", "link/doi"]);
  assertEquals(normalizeLink("doi:10.1234/ABC"), "doi:10.1234/abc");
  const patch = (outputMutations({ ...output, sanity_id: found.id })[1] as any).patch;
  assertEquals("type" in patch.set, false);
  assertEquals(patch.unset.includes("type"), false);
  const ambiguous = resolver(async () => [{ _id: "a", title: "e design", year: 2020 }, { _id: "b", title: "É Design!", year: 2020 }]);
  await assertRejects(() => ambiguous.output({ ...output, doi: null }), Error, "Ambiguous researchOutput");
});

Deno.test("only explicit new-member mappings choose a memberType title", () => {
  assertEquals(memberTypeTitle({ ...person, membership_type: "integrated", phd: false }), "Non-Doctorate Researcher");
  assertEquals(memberTypeTitle({ ...person, membership_type: "integrated", phd: true }), "Doctorate Researcher");
  for (const phd of [undefined, null, "Design", "false"]) {
    assertEquals(memberTypeTitle({ ...person, membership_type: "integrated", phd }), "Integrated");
  }
  assertEquals(memberTypeTitle({ ...person, membership_type: "external" }), "Visiting researcher");
  assertEquals(memberTypeTitle(person), undefined);
  assertEquals(memberTypeTitle({ ...person, membership_type: "unknown" }), undefined);
  const pair = mutations(person, undefined, "target-type-id") as any[];
  assertEquals(pair[1].patch.set.type._ref, "target-type-id");
});
