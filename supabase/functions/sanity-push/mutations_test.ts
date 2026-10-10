import { assertEquals } from "jsr:@std/assert@1";
import { mutations, published, Row } from "./mutations.ts";

const row: Row = {
  id: "u1", preferred_name: "Zé Árvore", bio: "b", orcid: null, ciencia_id: null,
  membership_type: "integrated", public_visibility: true, merged_into: null, sanity_id: null,
};

Deno.test("same output as sanity_push.py self-check", () => {
  const [create, patch] = mutations(row) as any[];
  assertEquals(create.createIfNotExists._id, "rims-u1");
  assertEquals(create.createIfNotExists.slug.current, "ze-arvore");
  assertEquals(patch.patch.set, { name: "Zé Árvore", shortBio: "b" });
  assertEquals(patch.patch.unset, ["orcid", "cienciaId"]);
  assertEquals((mutations({ ...row, sanity_id: "abc" })[0] as any).createIfNotExists._id, "abc");
  assertEquals((mutations(row, "member-1")[0] as any).createIfNotExists._id, "member-1");
  assertEquals(published(row), true);
  assertEquals(published({ ...row, public_visibility: false }), false);
  assertEquals(published({ ...row, merged_into: "x" }), false);
});
