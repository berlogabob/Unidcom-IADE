// POST { kind, year, filters } -> application/pdf
//
// Queries the report_data RPC, shapes the rows (shape.ts), and compiles the Typst
// templates to PDF with @myriaddreamin/typst.ts.
//
// Why this engine and not typst-wasm: the Supabase Edge Runtime exposes neither JSPI
// nor SharedArrayBuffer+Atomics.wait, so typst-wasm has no usable backend here and
// throws at boot. typst.ts is synchronous wasm-bindgen and needs neither. Local Deno
// reports both capabilities as available, so this is only reproducible when deployed.
//
// Authorization: the caller's Authorization header is forwarded to PostgREST, so RLS
// governs exactly which rows come back — the same rule every screen in the app uses,
// and the same data the existing CSV export already exposes. No separate admin gate.

import { createTypstCompiler } from "@myriaddreamin/typst.ts";
import { disableDefaultFontAssets, loadFonts } from "@myriaddreamin/typst.ts/options.init";
import { shape } from "./shape.ts";
import type { Kind, Row } from "./shape.ts";
import { FONT_BASE, FONT_FILES, WASM } from "./assets.ts";
// Generated from typst/*.typ by build-templates.ts — Supabase's bundler ships only
// files in the module graph, and rejects `with { type: "text" }`.
import { TEMPLATES } from "./typst/templates.gen.ts";

const PDF_FORMAT = 1; // CompileFormatEnum.pdf — the string "pdf" silently yields vector IR
const KINDS: Kind[] = ["outputs", "activities", "list", "review"];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const grab = async (u: string) => new Uint8Array(await (await fetch(u)).arrayBuffer());

// Booted once and reused across warm invocations: ~28 MB of wasm and 4 fonts.
let compilerP: Promise<TypstCompilerish> | undefined;

type TypstCompilerish = {
  mapShadow(path: string, data: Uint8Array): void;
  addSource(path: string, text: string): void;
  compile(
    o: { mainFilePath: string; format: number },
  ): Promise<{ result?: Uint8Array; diagnostics?: unknown }>;
};

async function boot(): Promise<TypstCompilerish> {
  const [wasm, fonts] = await Promise.all([
    grab(WASM),
    Promise.all(FONT_FILES.map((f) => grab(FONT_BASE + f))),
  ]);
  const c = createTypstCompiler();
  await c.init({
    getWrapper: () => import("@myriaddreamin/typst-ts-web-compiler"),
    getModule: () => wasm,
    beforeBuild: [disableDefaultFontAssets(), loadFonts(fonts)],
  });
  // Templates never change between requests.
  for (const [name, src] of Object.entries(TEMPLATES)) c.addSource(`/${name}`, src);
  return c as unknown as TypstCompilerish;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") {
    return Response.json({ error: "POST only" }, { status: 405, headers: CORS });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const kind: Kind = KINDS.includes(body.kind) ? body.kind : "outputs";
    const year = body.year == null ? null : Number(body.year);
    if (year !== null && !Number.isInteger(year)) {
      return Response.json({ error: "year must be an integer" }, { status: 400, headers: CORS });
    }
    const filters = body.filters && typeof body.filters === "object" ? body.filters : {};

    const auth = req.headers.get("Authorization") ?? "";
    const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const rpc = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/report_data`, {
      method: "POST",
      headers: { Authorization: auth, apikey, "Content-Type": "application/json" },
      body: JSON.stringify({ p_kind: kind, p_year: year, p_filters: filters }),
    });
    if (!rpc.ok) {
      return Response.json({ error: `report_data: ${await rpc.text()}` }, {
        status: rpc.status,
        headers: CORS,
      });
    }
    const rows = await rpc.json() as Row[];

    const data = shape(rows, {
      kind,
      year,
      toc: body.toc === true,
      generatedOn: new Date().toISOString().slice(0, 10),
    });

    compilerP ??= boot();
    const compiler = await compilerP;
    compiler.mapShadow("/data.json", new TextEncoder().encode(JSON.stringify(data)));
    const res = await compiler.compile({ mainFilePath: "/report.typ", format: PDF_FORMAT });

    if (!res.result?.length) {
      return Response.json({ error: "compile produced no output", diagnostics: res.diagnostics }, {
        status: 500,
        headers: CORS,
      });
    }

    const name = `unidcom-${kind}-${year ?? "todos"}.pdf`;
    // Deliberately octet-stream, not application/pdf: supabase functions_client only
    // hands back raw bytes for "application/octet-stream" — any other non-JSON type
    // falls through to utf8.decode() and corrupts the PDF. The Flutter side re-attaches
    // the application/pdf MIME when it builds the download blob.
    // Uint8Array is a valid body at runtime; the cast placates the DOM lib types.
    return new Response(res.result as unknown as BodyInit, {
      headers: {
        ...CORS,
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${name}"`,
        "X-Report-Rows": String(rows.length),
      },
    });
  } catch (e) {
    // Deliberately keep `compilerP`: each request re-maps /data.json, so a failed
    // compile leaves nothing stale behind. Clearing it forced a fresh 28 MB wasm boot
    // on the next call, which made one resource-limit failure self-perpetuating.
    return Response.json({ error: String(e) }, { status: 500, headers: CORS });
  }
});
