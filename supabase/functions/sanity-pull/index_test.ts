import { assert, assertEquals } from "jsr:@std/assert@1";
import { handleRequest } from "./index.ts";

Deno.test("preflight, method and missing auth never read data", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("Unexpected fetch");
  };
  try {
    const preflight = await handleRequest(
      new Request("https://local", { method: "OPTIONS" }),
    );
    assertEquals(preflight.headers.get("Access-Control-Allow-Origin"), "*");
    assertEquals(
      (await handleRequest(new Request("https://local"))).status,
      405,
    );
    assertEquals(
      (await handleRequest(new Request("https://local", { method: "POST" })))
        .status,
      403,
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("non-admin denied before reading either dataset", async () => {
  const original = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input) => {
    calls.push(String(input));
    return Promise.resolve(
      Response.json({ app_metadata: { role: "researcher" } }),
    );
  };
  try {
    const res = await handleRequest(
      new Request("https://local", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
      }),
    );
    assertEquals(res.status, 403);
    assertEquals(calls.length, 1);
    assert(calls[0].endsWith("/auth/v1/user"));
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("admin comparison only uses GET, anonymous GROQ and paginated portal reads", async () => {
  const original = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input, init) => {
    const url = String(input);
    calls.push(url);
    assertEquals(init?.method ?? "GET", "GET");
    if (url.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ app_metadata: { role: "admin" } }),
      );
    }
    if (url.includes(".api.sanity.io/")) {
      assertEquals(init?.headers, undefined);
      assert(url.includes("/data/query/production?"));
      return Promise.resolve(
        Response.json({ result: { members: [], outputs: [] } }),
      );
    }
    if (url.includes("/people?") && url.endsWith("offset=0")) {
      return Promise.resolve(
        Response.json(
          Array.from(
            { length: 500 },
            (_, i) => ({ id: `p${i}`, preferred_name: `Person ${i}` }),
          ),
        ),
      );
    }
    return Promise.resolve(Response.json([]));
  };
  try {
    const res = await handleRequest(
      new Request("https://local", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
      }),
    );
    assertEquals(res.status, 200);
    assertEquals((await res.json()).counts.portal_only, 500);
    assert(
      calls.some((url) =>
        url.includes("/people?") && url.endsWith("offset=500")
      ),
    );
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("upstream failure returns CORS JSON error rather than incomplete comparison", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (input) =>
    Promise.resolve(
      String(input).endsWith("/auth/v1/user")
        ? Response.json({ app_metadata: { role: "admin" } })
        : new Response("Unavailable", { status: 503 }),
    );
  try {
    const res = await handleRequest(
      new Request("https://local", {
        method: "POST",
        headers: { Authorization: "Bearer test" },
      }),
    );
    assertEquals(res.status, 502);
    assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
    assertEquals((await res.json()).issues, undefined);
  } finally {
    globalThis.fetch = original;
  }
});
