# Questions for the Sanity website agency

Context for them: UNIDCOM keeps its research directory (people, projects, outputs) in its own
database. We have read the public Sanity dataset of project `vj0axykv` and want to feed it
from our database without breaking the site. Before we write anything we need:

1. **Hosting.** Where is the Sanity-backed frontend deployed, and is it live anywhere yet?
   (`unidcom-iade.pt` still serves the WordPress site.)
2. **Studio schema.** Access to the Sanity Studio repository (`sanity/schemaTypes`), or an
   export of the schema, so our documents match your types and validation rules exactly.
3. **Publishing.** Does the site read Sanity live, or does it need a revalidate/rebuild hook
   after content changes? If so, which endpoint and secret?
4. **Editorial ownership.** Who edits Sanity today, and which fields do you consider editorial
   (photos, short bios, cover images, page copy) versus data we may update (names, ORCID,
   emails, project dates, publications)?
5. **Access.** When we are ready, an Editor API token for `vj0axykv`, and whether a staging
   dataset exists or can be created.

Nothing will be written to `vj0axykv` before questions 2 and 5 are answered.
