import { assert, assertEquals } from "jsr:@std/assert@1";
import { handler } from "./index.ts";

for (const mode of ["success", "reject", "throw", "dry", "patch-throw", "patch-reject", "reject-patch-throw", "read-throw", "bulk"] as const) {
  Deno.test(`sync status: ${mode}`, async () => {
    const original = globalThis.fetch;
    const env = { SUPABASE_URL: "https://db.test", SUPABASE_SERVICE_ROLE_KEY: "service-test", SANITY_TOKEN: "sanity-test" };
    const saved = Object.fromEntries(Object.keys(env).map((key) => [key, Deno.env.get(key)]));
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    const patches: { url: string; body: Record<string, unknown> }[] = [];
    globalThis.fetch = async (input, init) => {
      const url = String(input);
      if (url.endsWith("/auth/v1/user")) return Response.json({ app_metadata: { role: "admin" } });
      if (init?.method === "PATCH") {
        assertEquals(new Headers(init.headers).get("Authorization"), "Bearer service-test");
        patches.push({ url, body: JSON.parse(String(init.body)) });
        if (mode === "patch-throw" || mode === "reject-patch-throw") throw new Error("status unavailable");
        return new Response(null, { status: mode === "patch-reject" ? 400 : 204 });
      }
      if (url.includes("/rest/v1/people?")) {
        if (mode === "read-throw") throw new Error("read unavailable");
        return Response.json([
          { id: "p1", preferred_name: "Person", sanity_id: "member-existing", public_visibility: true, merged_into: null },
          { id: "coauthor", preferred_name: "Coauthor", sanity_id: "coauthor-existing", public_visibility: true, merged_into: null },
        ]);
      }
      if (url.includes("/rest/v1/outputs?")) return Response.json([
        { id: "o1", title: "Output", sanity_id: "output-existing", type: "book",
          output_authors: [{ person_id: "p1" }, { person_id: "coauthor" }] },
      ]);
      if (url.includes("/rest/v1/")) return Response.json([]);
      if (url.includes("/data/mutate/")) {
        if (mode === "throw") throw new Error("network unavailable");
        return mode === "reject" || mode === "reject-patch-throw" ? new Response("rejected".repeat(80), { status: 400 }) : Response.json({});
      }
      throw new Error(`Unexpected fetch ${url}`);
    };
    try {
      const response = await handler(new Request("https://function.test", {
        method: "POST", headers: { Authorization: "Bearer admin" },
        body: JSON.stringify(mode === "bulk" ? { types: ["members", "outputs"] }
          : { personId: "p1", outputIds: ["o1"], dryRun: mode === "dry" }),
      }));
      const failed = ["reject", "reject-patch-throw", "throw", "read-throw"].includes(mode);
      assertEquals(response.status, failed ? 502 : 200);
      const result = await response.json();
      if (mode === "dry") {
        assertEquals(patches, []);
        return;
      }
      const ids = patches.map((p) => p.url.split("/rest/v1/")[1]).sort();
      assertEquals(ids, mode === "read-throw" ? ["outputs?id=eq.o1", "people?id=eq.p1"]
        : ["outputs?id=eq.o1", "people?id=eq.coauthor", "people?id=eq.p1"]);
      for (const { body } of patches) {
        if (failed) {
          assertEquals(body.sanity_error, result.error.slice(0, 300));
          assertEquals("sanity_synced_at" in body, false);
        } else {
          assertEquals(body.sanity_error, null);
          assert(Number.isFinite(Date.parse(body.sanity_synced_at as string)));
          assertEquals("sanity_id" in body, false); // Existing IDs still get status updates.
        }
      }
    } finally {
      globalThis.fetch = original;
      for (const [key, value] of Object.entries(saved)) {
        if (value === undefined) Deno.env.delete(key); else Deno.env.set(key, value);
      }
    }
  });
}
