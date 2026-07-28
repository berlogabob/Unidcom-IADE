// deno test -A supabase/functions/report/shape_test.ts
//
// Guards the counting rules, which are the part of this feature that can be wrong while
// still producing a beautiful PDF.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { pct, SECTIONS, shape } from "./shape.ts";
import type { Row } from "./shape.ts";

const row = (over: Partial<Row> = {}): Row => ({
  id: crypto.randomUUID(),
  title: "T",
  reporting_year: 2025,
  section: "Livros",
  subsection: "Capítulos de livros indexados ISI e Scopus ou equivalentes",
  type: "Capítulos de livros",
  category_path: null,
  full_reference: "Autor, A. (2025). Um título.",
  doi: null,
  url: null,
  output_status: null,
  approval_status: "pending",
  fct_selected: false,
  verified_online: false,
  doi_status: null,
  people: ["Alguém"],
  issues: [],
  ...over,
});

const opts = { kind: "outputs" as const, year: 2025, generatedOn: "2026-07-28" };

Deno.test("pct uses a PT-PT decimal comma and survives divide-by-zero", () => {
  assertEquals(pct(15, 100), "15,0%");
  assertEquals(pct(1, 3), "33,3%");
  assertEquals(pct(0, 0), "—");
});

Deno.test("Planeado/Submetido are listed but excluded from every count", () => {
  const rows = [
    row(),
    row(),
    row({ output_status: "Planeado" }),
    row({ output_status: "Submetido" }),
  ];
  const d = shape(rows, opts);
  const livros = d.sections.find((s) => s.title === "Livros")!;

  assertEquals(livros.count, 2, "only the two countable rows");
  assertEquals(livros.summary!.total!.cells[1], "2");

  // ...but all four still appear, split into a second labelled group.
  const items = livros.subsections.flatMap((s) => s.groups.flatMap((g) => g.items));
  assertEquals(items.length, 4);
  assertEquals(items.filter((i) => i.state !== null).length, 2);
});

Deno.test("all 11 editorial sections render even when empty", () => {
  const d = shape([row()], opts);
  assertEquals(d.sections.length, SECTIONS.length);
  const patentes = d.sections.find((s) => s.title === "Patentes e contratos industriais")!;
  assertEquals(patentes.count, 0);
  assertEquals(patentes.number, "10", "editorial order, not data order");
});

Deno.test("an unknown macro_type is appended rather than dropped", () => {
  const d = shape([row({ section: "Categoria Nova" })], opts);
  const extra = d.sections.find((s) => s.title === "Categoria Nova");
  assert(extra, "unknown section must survive");
  assertEquals(extra!.count, 1);
});

Deno.test("a DOI already inside the reference is not printed twice", () => {
  const withDoi = shape([
    row({ doi: "10.1234/abc", full_reference: "Autor, A. (2025). T. https://doi.org/10.1234/abc" }),
  ], opts);
  const a = withDoi.sections[0].subsections[0].groups[0].items[0];
  assertEquals(a.url, null, "reference already carries the DOI");

  const without = shape([row({ doi: "10.1234/abc", full_reference: "Autor, A. (2025). T." })], opts);
  const b = without.sections[0].subsections[0].groups[0].items[0];
  assertEquals(b.url, "https://doi.org/10.1234/abc");
});

Deno.test("quality issues mark the item and feed the section hygiene callout", () => {
  const d = shape([row({ issues: ["missing_doi"] }), row()], opts);
  const items = d.sections[0].subsections[0].groups[0].items;
  assertEquals(items.filter((i) => i.warn !== null).length, 1);
  assertEquals(items.find((i) => i.warn)!.warn, "sem DOI");
  assertEquals(d.sections[0].callouts.length, 1, "section keeps its hygiene callout");
});

Deno.test("the reconciliation appendix is its own report kind, not part of outputs", () => {
  const rows = [row({ issues: ["missing_doi", "duplicate"] }), row()];

  // Bundling it into `outputs` made a 28-page doc that tripped the Edge worker's
  // resource limit ~40% of the time. Split, both render reliably.
  assertEquals(shape(rows, opts).appendix, null);

  const review = shape(rows, { ...opts, kind: "review" });
  assertEquals(review.sections.length, 0, "review lists no outputs");
  assertEquals(review.summary, null);
  assertEquals(review.appendix!.table.rows.length, 1);
  assertEquals(review.appendix!.table.columns.length, 3, "no constant 4th column");
  assertEquals(review.appendix!.table.rows[0].cells[2], "sem DOI; possível duplicado");
});

Deno.test("list kind flattens to one section and drops summary + appendix", () => {
  const d = shape([row(), row({ section: "Artigos em revistas" })], { ...opts, kind: "list" });
  assertEquals(d.summary, null);
  assertEquals(d.appendix, null);
  assertEquals(d.sections.length, 1);
  assertEquals(d.sections[0].subsections[0].groups[0].items.length, 2);
  assertEquals(d.meta["show-toc"], false);
});

Deno.test("executive summary totals equal the sum of section counts", () => {
  const rows = [
    row(),
    row(),
    row({ section: "Artigos em revistas", subsection: "Artigo em revista científica de quartil Q1" }),
    row({ output_status: "Planeado" }),
  ];
  const d = shape(rows, opts);
  const sum = d.sections.reduce((n, s) => n + s.count, 0);
  assertEquals(d.summary!.total!.cells[1], String(sum));
  assertEquals(sum, 3, "the Planeado row is excluded");
});
