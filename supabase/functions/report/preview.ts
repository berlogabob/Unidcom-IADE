// Local preview loop — no Supabase deploy needed.
//
//   deno run -A supabase/functions/report/preview.ts [kind] [year]
//
// Pulls fresh rows from the report_data RPC (or reuses fixtures/rows.json with --cached),
// runs them through shape.ts, and compiles with the pinned typst 0.14.2 binary — the same
// version the Edge Function's wasm engine embeds. Writes out/report.pdf.

import { shape } from "./shape.ts";
import type { Kind, Row } from "./shape.ts";
import { FONT_BASE, FONT_FILES } from "./assets.ts";
import { buildTemplates } from "./build-templates.ts";

const URL_BASE = "https://nmghxkhstlnxypmfmfhk.supabase.co";
const ANON = "sb_publishable_uCvM2dlnxkS3gqCsyaANVQ_RswEP6Zm";

const here = new URL(".", import.meta.url).pathname;
const kind = (Deno.args[0] ?? "outputs") as Kind;
const year = Deno.args[1] ? Number(Deno.args[1]) : 2025;
const cached = Deno.args.includes("--cached");

const fixture = `${here}fixtures/rows.json`;
let rows: Row[];
if (cached) {
  rows = JSON.parse(await Deno.readTextFile(fixture));
} else {
  const res = await fetch(`${URL_BASE}/rest/v1/rpc/report_data`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ p_kind: kind, p_year: year }),
  });
  if (!res.ok) throw new Error(`rpc ${res.status}: ${await res.text()}`);
  rows = await res.json();
  await Deno.writeTextFile(fixture, JSON.stringify(rows, null, 1));
}
console.log(`${rows.length} rows (${cached ? "cached" : "fresh"})`);

const data = shape(rows, {
  kind,
  year,
  generatedOn: new Date().toISOString().slice(0, 10),
});

// Keep the generated module the Edge Function ships in sync with the .typ sources.
await Deno.writeTextFile(`${here}typst/templates.gen.ts`, await buildTemplates());

await Deno.mkdir(`${here}out`, { recursive: true });
await Deno.writeTextFile(`${here}typst/data.json`, JSON.stringify(data));

// Same fonts, same URLs the Edge Function uses — cached locally so the preview matches
// the deployed output instead of silently falling back to a system sans.
const fontDir = `${here}.fonts`;
await Deno.mkdir(fontDir, { recursive: true });
for (const f of FONT_FILES) {
  const dest = `${fontDir}/${f}`;
  if (await Deno.stat(dest).then(() => false).catch(() => true)) {
    const r = await fetch(FONT_BASE + f);
    await Deno.writeFile(dest, new Uint8Array(await r.arrayBuffer()));
    console.log(`fetched ${f}`);
  }
}

// --root pins the project root so `json("/data.json")` resolves exactly as it does in
// the virtual filesystem the Edge Function builds with mapShadow.
const typst = Deno.env.get("TYPST_BIN") ?? "typst";
const cmd = new Deno.Command(typst, {
  args: ["compile", "--root", `${here}typst`, "--font-path", fontDir, `${here}typst/report.typ`, `${here}out/report.pdf`],
  stdout: "inherit",
  stderr: "inherit",
});
const { code } = await cmd.output();
await Deno.remove(`${here}typst/data.json`).catch(() => {});
if (code !== 0) Deno.exit(code);
console.log(`wrote ${here}out/report.pdf`);
