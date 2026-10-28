import { assertEquals } from "jsr:@std/assert@1";
import { clusterMutations, flexibleDate, mutations, Output, outputMutations, outputType, portable, projectMutations, published, Row, singleEntityMutations } from "./mutations.ts";

const row: Row = {
  id: "u1", preferred_name: "Zé Árvore", bio: "b", orcid: null, ciencia_id: null,
  membership_type: "integrated", phd: false, public_visibility: true, merged_into: null, sanity_id: null,
};

const output: Output = {
  id: "o1", sanity_id: null, title: "Output", reporting_year: 2026, type: "journal-article",
  full_reference: null, url: null, doi: "10.1/example", keywords: [], members: ["rims-u1", "member-2"],
};

Deno.test("output mapping includes keyed member references", () => {
  const [create, patch] = outputMutations(output) as any[];
  assertEquals(create.createIfNotExists, { _id: "rims-o1", _type: "researchOutput", title: "Output", migrated: true });
  assertEquals(patch.patch.set.members, [
    { _type: "reference", _ref: "rims-u1", _key: "m0" },
    { _type: "reference", _ref: "member-2", _key: "m1" },
  ]);
  assertEquals(patch.patch.set.link, "https://doi.org/10.1/example");
});

Deno.test("selected outputs precede members and all relation patches", () => {
  const outputs = [output, { ...output, id: "o2", sanity_id: "existing-output", members: [] }];
  const members = [mutations(row), mutations({ ...row, id: "u2", sanity_id: "member-2" })];
  const all = singleEntityMutations(outputs, members) as any[];
  assertEquals(all.slice(0, 4), outputs.flatMap((o) => outputMutations(o, false)));
  for (const m of [all[1], all[3]]) {
    assertEquals("members" in m.patch.set, false);
    assertEquals(m.patch.unset.includes("members"), false);
  }
  assertEquals(all.slice(4, 8), members.flat());
  assertEquals(all.slice(8), [
    { patch: { id: "rims-o1", set: { members: (outputMutations(output)[1] as any).patch.set.members } } },
    { patch: { id: "existing-output", set: { members: [] } } },
  ]);
  assertEquals(singleEntityMutations([], [mutations(row)]), mutations(row));
});

Deno.test("selected push bypasses publication gates and dry run performs no writes", async () => {
  const originalFetch = globalThis.fetch;
  const originalEnv = Deno.env.get;
  let handler: (req: Request) => Promise<Response> = undefined!;
  const writes: { url: string; body: any }[] = [];
  const reads: string[] = [];
  let memberResults: any[] = [];
  let outputResults: any[] = [];
  let lookupFails = false;
  let lookupResult: string[] = ["non-doctorate-id"];
  let storedMembership = "collaborator";
  try {
    Deno.env.get = (name) => ({ SANITY_TOKEN: "test", SUPABASE_URL: "https://db.test" })[name];
    globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      if (init?.method === "POST" || init?.method === "PATCH") {
        writes.push({ url, body: JSON.parse(String(init.body)) });
        return Promise.resolve(Response.json({}));
      }
      reads.push(url);
      if (url === "https://photo.test") return Promise.resolve(new Response(null, { status: 404 }));
      let data: unknown;
      if (url.endsWith("/auth/v1/user")) data = { app_metadata: { role: "admin" } };
      else if (url.includes("/people?")) data = [
        { ...row, public_visibility: false, photo_url: "https://photo.test" },
        { ...row, id: "u2", public_visibility: false, sanity_id: "member-2", membership_type: storedMembership },
        { ...row, id: "unrelated" },
      ];
      else if (url.includes("/articles?")) {
        assertEquals(url.includes("published=eq.true"), true);
        data = [{ id: "a1", sanity_id: null, title: "News", slug: "news", date: "2025-01-01",
          news_type: "[Events] conference", scientific_areas: ["Design"], excerpt: null, body: null }];
      }
      else if (url.includes("/outputs?")) {
        assertEquals(url.includes("website_status=eq.published"), !url.includes("id=in."));
        assertEquals(url.includes("merged_into=is.null"), true);
        data = [{ ...output,
          project_outputs: [{ projects: { project_clusters: [
            { clusters: { sanity_id: "cluster-existing" } }, { clusters: { sanity_id: null } },
          ] } }],
          scientific_areas: [{ sanity_id: "science-existing" }, { sanity_id: null }], website_status: "draft", output_authors: [{ person_id: "u1" }, { person_id: "missing" }] }];
      } else if (url.includes("/data/query/")) {
        const query = new URL(url).searchParams;
        if (query.get("query")?.includes('"articleCategory"')) {
          assertEquals(query.get("$value"), JSON.stringify("[events] conference"));
          data = { result: ["conference-id"] };
        } else if (query.get("query")?.includes('"scientificArea"')) {
          assertEquals(query.get("$value"), JSON.stringify("design"));
          data = { result: ["design-id"] };
        } else if (query.get("query")?.includes('"memberType"')) {
          assertEquals(query.get("$title"), JSON.stringify("non-doctorate researcher"));
          if (lookupFails) return Promise.resolve(new Response(null, { status: 503 }));
          data = { result: lookupResult };
        } else data = { result: query.get("query")?.includes('"researchOutput"') ? outputResults : memberResults };
      }
      else if (["clusters", "funders", "projects"].some((table) => url.includes(`/${table}?`))) data = [];
      else throw new Error(`unexpected fetch ${url}`);
      return Promise.resolve(Response.json(data));
    }) as typeof fetch;
    handler = (await import("./index.ts")).handler;
    const request = (body: unknown) => new Request("https://edge.test", {
      method: "POST", headers: { Authorization: "Bearer admin" }, body: JSON.stringify(body),
    });
    const response = await handler(request({ personId: "u2", outputIds: ["o1"], dryRun: true }));
    assertEquals(response.status, 200);
    const result = await response.json();
    assertEquals(result.counts, { outputs: 1, members: 2 });
    assertEquals(result.warnings, []);
    assertEquals(result.mutations[1].patch.set.type, "journalArticle");
    assertEquals(result.mutations[1].patch.set.migrated, true);
    assertEquals(result.mutations[1].patch.set.clusters, [{ _type: "reference", _ref: "cluster-existing", _key: "c0" }]);
    assertEquals(result.mutations[1].patch.set.scientificAreas, [{ _type: "reference", _ref: "science-existing", _key: "s0" }]);
    assertEquals("type" in result.mutations[5].patch.set, false);
    assertEquals(result.dropped, [{ outputId: "o1", personId: "missing" }]);
    assertEquals(writes, []);
    assertEquals(reads.some((url) => url.includes("photo.test")), false);
    assertEquals(result.mutations.at(-1).patch.set.members, [{ _type: "reference", _ref: "rims-u1", _key: "m0" }]);
    // The same plan is sent in order, then ids are persisted.
    const live = await handler(request({ personId: "u2", outputIds: ["o1"] }));
    assertEquals(live.status, 200);
    assertEquals(writes[0].body.mutations, result.mutations);
    assertEquals(writes.slice(1).flatMap((w) => w.body.sanity_id ? [w.body.sanity_id] : []), ["rims-o1", "rims-u1"]);
    const personOnly = await handler(request({ personId: "u2", dryRun: true }));
    assertEquals((await personOnly.json()).counts, { outputs: 0, members: 1 });
    storedMembership = "integrated";
    const storedMember = await handler(request({ personId: "u2", dryRun: true }));
    const storedPlan = await storedMember.json();
    assertEquals(storedPlan.warnings, []);
    assertEquals(storedPlan.mutations[1].patch.id, "member-2");
    assertEquals(storedPlan.mutations[1].patch.setIfMissing.type, { _type: "reference", _ref: "non-doctorate-id" });
    assertEquals("type" in storedPlan.mutations[1].patch.set, false);
    assertEquals(storedPlan.mutations[1].patch.unset.includes("type"), false);
    storedMembership = "collaborator";
    lookupFails = true;
    const unresolved = await handler(request({ personId: "u1", dryRun: true }));
    assertEquals(unresolved.status, 200);
    const unresolvedResult = await unresolved.json();
    assertEquals(unresolvedResult.warnings.length, 2);
    assertEquals(unresolvedResult.warnings[1].includes("cannot resolve memberType for integrated"), true);
    assertEquals("type" in unresolvedResult.mutations[1].patch.set, false);
    assertEquals(unresolvedResult.mutations[1].patch.unset.includes("type"), false);
    lookupFails = false;
    lookupResult = [];
    const missingType = await handler(request({ personId: "u1", dryRun: true }));
    const missingTypeResult = await missingType.json();
    assertEquals(missingTypeResult.warnings, ["Member u1: cannot resolve memberType for integrated (Non-Doctorate Researcher)"]);
    lookupResult = ["non-doctorate-id"];
    const empty = await handler(request({ outputIds: [], dryRun: true }));
    assertEquals((await empty.json()).mutations, []);
    writes.length = 0;
    const bulk = await handler(request({ types: ["members", "outputs"], dryRun: true }));
    const bulkResult = await bulk.json();
    assertEquals(bulkResult.counts, { members: 1, outputs: 1 });
    assertEquals(bulkResult.mutations[0].createIfNotExists._type, "member");
    assertEquals(bulkResult.mutations[2].createIfNotExists._type, "researchOutput");
    assertEquals(bulkResult.mutations[3].patch.unset.includes("members"), true);
    assertEquals(writes, []);
    const outputsOnly = await handler(request({ types: ["outputs"], dryRun: true }));
    assertEquals((await outputsOnly.json()).wouldCreate, [{ portal: "o1", sanity: "rims-o1" }]);
    const articleDryRun = await handler(request({ types: ["articles"], dryRun: true }));
    assertEquals(articleDryRun.status, 200);
    const articlePlan = await articleDryRun.json();
    assertEquals(articlePlan.warnings, []);
    assertEquals(articlePlan.counts, { articles: 1 });
    assertEquals(articlePlan.mutations[1].patch.set.category._ref, "conference-id");
    assertEquals(articlePlan.mutations[1].patch.set.scientificAreas[0]._ref, "design-id");
    assertEquals(articlePlan.mutations[1].patch.set.date, "2025-01-01");
    assertEquals(writes, []);
    // Matched documents must flow through both push paths, relation patches and saved ids.
    memberResults = [{ _id: "matched-member", slug: "ze-arvore" }];
    outputResults = [{ _id: "matched-output", title: "OUTPUT!", year: 2026 }];
    const matchedDryRun = await handler(request({ outputIds: ["o1"], dryRun: true }));
    const matchedPlan = await matchedDryRun.json();
    assertEquals(matchedPlan.matched, [
      { portal: "u1", sanity: "matched-member", by: "slug" },
      { portal: "o1", sanity: "matched-output", by: "title+year" },
    ]);
    assertEquals(matchedPlan.wouldCreate, []);
    assertEquals(matchedPlan.warnings, []);
    assertEquals(matchedPlan.mutations[0].createIfNotExists._id, "matched-output");
    assertEquals(matchedPlan.mutations[2].createIfNotExists._id, "matched-member");
    assertEquals(matchedPlan.mutations[3].patch.setIfMissing.type, { _type: "reference", _ref: "non-doctorate-id" });
    assertEquals(matchedPlan.mutations.at(-1).patch.id, "matched-output");
    assertEquals(matchedPlan.mutations.at(-1).patch.set.members[0]._ref, "matched-member");
    for (const index of [1, 3]) {
      assertEquals("type" in matchedPlan.mutations[index].patch.set, false);
      assertEquals(matchedPlan.mutations[index].patch.unset.includes("type"), false);
    }
    assertEquals(writes, []);
    const matchedLive = await handler(request({ outputIds: ["o1"] }));
    assertEquals(matchedLive.status, 200);
    assertEquals(writes[0].body.mutations, matchedPlan.mutations);
    assertEquals(writes.slice(1).flatMap((w) => w.body.sanity_id ? [w.body.sanity_id] : []), ["matched-output", "matched-member"]);
    writes.length = 0;
    const matchedBulk = await handler(request({ types: ["members", "outputs"] }));
    assertEquals(matchedBulk.status, 200);
    assertEquals((await matchedBulk.json()).wouldCreate, []);
    assertEquals(writes.map((w) => w.body.sanity_id).filter(Boolean), ["matched-member", "matched-output"]);
    assertEquals(writes[2].body.mutations[1].patch.set.members, undefined);
    writes.length = 0;
    memberResults.push({ _id: "duplicate", slug: "ze-arvore" });
    const ambiguous = await handler(request({ outputIds: ["o1"] }));
    assertEquals(ambiguous.status, 502);
    assertEquals(writes.length, 2);
    assertEquals(writes.every((w) => typeof w.body.sanity_error === "string"), true);
    writes.length = 0;
    Deno.env.get = (name) => ({ SANITY_PROJECT: "vj0axykv", SANITY_TOKEN: "test", SUPABASE_URL: "https://db.test" })[name];
    handler = (await import("./index.ts?agency-guard")).handler;
    const guarded = await handler(request({ personId: "u2" }));
    assertEquals(guarded.status, 400);
    assertEquals(await guarded.json(), { error: "refusing the agency project" });
    assertEquals(writes, []);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.get = originalEnv;
  }
});

Deno.test("member mapping patches required fields on existing documents", () => {
  const [create, patch] = mutations(row) as any[];
  assertEquals(create.createIfNotExists._id, "rims-u1");
  assertEquals(create.createIfNotExists.slug.current, "ze-arvore");
  assertEquals(patch.patch.set, {
    name: "Zé Árvore", shortBio: "b",
  });
  assertEquals(patch.patch.setIfMissing.slug, { _type: "slug", current: "ze-arvore" });
  const updated = (mutations({ ...row, sanity_id: "existing", board_role: ["scientificDirector"] }, undefined, "resolved-id")[1] as any).patch;
  assertEquals("type" in updated.set, false);
  assertEquals(updated.setIfMissing.type, { _type: "reference", _ref: "resolved-id" });
  assertEquals(updated.set.boardRole, "scientificDirector");
  assertEquals(patch.patch.unset, ["orcid", "cienciaId", "researchInterests", "boardRole"]);
  assertEquals((mutations({ ...row, sanity_id: "abc" })[0] as any).createIfNotExists._id, "abc");
  assertEquals((mutations(row, "member-1")[0] as any).createIfNotExists._id, "member-1");
  assertEquals(published(row), true);
  assertEquals(published({ ...row, public_visibility: false }), false);
  assertEquals(published({ ...row, merged_into: "x" }), false);
});

Deno.test("existing members fill missing types without setting or unsetting an existing type", () => {
  for (const [member, existing] of [[{ ...row, sanity_id: "stored" }, undefined], [row, "resolved"]] as const) {
    const [create, patch] = mutations(member, existing, "member-type-id") as any[];
    assertEquals("type" in create.createIfNotExists, false);
    assertEquals(patch.patch.setIfMissing.type, { _type: "reference", _ref: "member-type-id" });
    assertEquals("type" in patch.patch.set, false);
    assertEquals(patch.patch.unset.includes("type"), false);
    const unresolved = (mutations(member, existing)[1] as any).patch;
    assertEquals("type" in unresolved.setIfMissing, false);
    assertEquals("type" in unresolved.set, false);
    assertEquals(unresolved.unset.includes("type"), false);
  }
  const [create, patch] = mutations(row, undefined, "member-type-id") as any[];
  assertEquals(create.createIfNotExists.type, { _type: "reference", _ref: "member-type-id" });
  assertEquals(patch.patch.set.type, create.createIfNotExists.type);
  assertEquals("type" in patch.patch.setIfMissing, false);
});

Deno.test("project mapping", () => {
  const [create, patch] = projectMutations({
    id: "p1", sanity_id: null, title: "Proj A", slug: null, description: "d", status: "active",
    start_date: "2024-03-05", end_date: null, start_precision: "month", end_precision: null, total_budget: 10,
    keywords: [], location: null, reference_number: null, website: null, partners: null, results: "a\n\nb",
    funder: "f1", clusters: ["c1"], team: { pi: ["m1"], coPi: [] },
  }) as any[];
  assertEquals(create.createIfNotExists._id, "rims-p1");
  assertEquals(patch.patch.set.status, "ongoing");
  assertEquals(patch.patch.set.startingDate, { precision: "month", month: "2024-03" });
  assertEquals(patch.patch.set.team.pi[0]._ref, "m1");
  assertEquals(patch.patch.set.results.length, 2);
  assertEquals(patch.patch.unset.includes("keywords"), true);
  assertEquals(patch.patch.unset.includes("endingDate"), true);
});

Deno.test("cluster has no slug; helpers", () => {
  const [create] = clusterMutations({ id: "c", sanity_id: null, code: "C1", name: "N", concern: null, description: null }) as any[];
  assertEquals("slug" in create.createIfNotExists, false);
  assertEquals(flexibleDate("2024-03-05", "year"), { precision: "year", month: "2024" });
  assertEquals(portable(" x "). length, 1);
});

Deno.test("output kinds map ORCID and reporting taxonomy without inventing types", () => {
  for (const [kind, expected] of Object.entries({
    book: "book", "book-chapter": "book", "journal-article": "journalArticle",
    "conference-paper": "conferencePaper", "conference-abstract": "abstract", patent: "patentModels", exhibition: "exhibition",
    journalArticle: "journalArticle", conferencePaper: "conferencePaper", patentModels: "patentModels",
    Livros: "book", "Artigos em revistas": "journalArticle", "Exposições": "exhibition", Patentes: "patentModels",
  })) assertEquals(outputType({ ...output, type: kind }), expected, kind);
  assertEquals(outputType({ ...output, type: null, category_path: "Livros › Capítulos de livros › Atas de congressos não indexados" }), "conferencePaper");
  assertEquals(outputType({ ...output, type: "unmapped", macro_type: "Artigos em revistas" }), "journalArticle");
  assertEquals(outputType({ ...output, type: "workshop" }), undefined);
});

Deno.test("outputs require citation, cap keywords, and only reference stored Sanity ids", () => {
  const patch = (outputMutations({
    ...output, full_reference: "  APA citation  ", url: "https://example.org/paper", keywords: ["1", "2", "3", "4", "5", "6", "7"],
    clusters: [{ sanity_id: "c1" }, { sanity_id: null }, { sanity_id: "c1" }],
    scientific_areas: [{ sanity_id: "s1" }, { sanity_id: null }],
  })[1] as any).patch;
  assertEquals(patch.set.citation, "APA citation");
  assertEquals(patch.set.link, "https://example.org/paper");
  assertEquals(patch.set.keywords.length, 6);
  assertEquals(patch.set.clusters, [{ _type: "reference", _ref: "c1", _key: "c0" }]);
  assertEquals(patch.set.scientificAreas, [{ _type: "reference", _ref: "s1", _key: "s0" }]);
  for (const key of ["authorRole", "bookCategory", "journalArticleCategory"]) {
    assertEquals(key in patch.set, false);
    assertEquals(patch.unset.includes(key), false);
  }
  assertEquals((outputMutations({ ...output, full_reference: "  " })[1] as any).patch.set.citation, "Output");
  const sparse = (outputMutations({ ...output, title: " ", clusters: [], scientific_areas: [] })[1] as any).patch;
  assertEquals(sparse.set.citation, "Untitled output");
  assertEquals(sparse.unset.includes("clusters"), true);
  assertEquals(sparse.unset.includes("scientificAreas"), true);
  const absent = (outputMutations(output)[1] as any).patch;
  assertEquals(absent.unset.includes("clusters"), false);
  assertEquals(absent.unset.includes("scientificAreas"), false);
});

Deno.test("article refs resolve target category name and scientific area titles", async () => {
  const { articleMutations, articleReferences } = await import("./mutations.ts");
  const article = { id: "a1", sanity_id: null, title: "News", slug: "news", date: "2025-01-01",
    excerpt: null, body: null, news_type: "[Events] conference", scientific_areas: ["Design", "Science", "Design"] };
  const queries: string[] = [];
  const warnings: string[] = [];
  const resolved = await articleReferences(article, (groq, params) => {
    queries.push(groq);
    return Promise.resolve([params.value === "[events] conference" ? "category-id" : `${params.value}-id`]);
  }, warnings);
  assertEquals(warnings, []);
  assertEquals(queries[0].includes('lower(name)'), true);
  assertEquals(queries[1].includes('lower(title)'), true);
  assertEquals(queries.every((q) => q.includes('path("drafts.**")')), true);
  const patch = (articleMutations(article, resolved)[1] as any).patch;
  assertEquals(patch.set.category, { _type: "reference", _ref: "category-id" });
  assertEquals(patch.set.scientificAreas, [
    { _type: "reference", _ref: "design-id", _key: "s0" },
    { _type: "reference", _ref: "science-id", _key: "s1" },
  ]);
  assertEquals(patch.set.date, "2025-01-01");
  for (const field of ["year", "date_precision", "news_type", "lab", "member_types", "source", "import_note"]) {
    assertEquals(field in patch.set, false);
    assertEquals(patch.unset.includes(field), false);
  }
});

Deno.test("article missing/ambiguous/failed lookups warn and preserve existing references", async () => {
  const { articleMutations, articleReferences } = await import("./mutations.ts");
  const article = { id: "a", sanity_id: "existing", title: "T", slug: "t", date: "2026-01-01",
    excerpt: null, body: "Text", category: "Legacy", scientific_areas: ["Design"] };
  for (const result of [[], ["one", "two"], null, "bad", new Error("offline")]) {
    const warnings: string[] = [];
    const refs = await articleReferences(article, () => {
      if (result instanceof Error) throw result;
      return Promise.resolve(result);
    }, warnings);
    assertEquals(warnings.length >= 2, true);
    const patch = (articleMutations(article, refs)[1] as any).patch;
    for (const field of ["category", "scientificAreas"]) {
      assertEquals(field in patch.set, false);
      assertEquals(patch.unset.includes(field), false);
    }
  }
  const warnings: string[] = [];
  const cleared = await articleReferences({ ...article, scientific_areas: [] }, () => Promise.resolve(["legacy-id"]), warnings);
  assertEquals(warnings, []);
  assertEquals((articleMutations(article, cleared)[1] as any).patch.unset.includes("scientificAreas"), true);
});
