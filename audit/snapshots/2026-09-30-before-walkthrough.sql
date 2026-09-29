-- Snapshot 29 Sep 2026 22:25 UTC, before the morning walkthrough with Rui.
-- Restores Andrey Dyakov's record to how it was. Run in the Supabase SQL editor.
-- Anything created during the walk (new output, new suggestions) is listed at the
-- end for manual review, not deleted blindly.
alter table public.people disable trigger trg_protect_people;
update public.people set
  bio = 'IADE UNIDCOM updated bio to testTEST form 7 agst. edit from portal 9 sept',
  profile_status = 'to_validate',
  public_visibility = true,
  photo_url = null,
  phone = null
where id = '72e62c1e-536c-4385-bc4a-ad690330da85';
alter table public.people enable trigger trg_protect_people;

update public.outputs set approval_status = 'to_validate', website_status = 'published'
where id in ('92f007e6-c07b-410a-936a-f0bdf6e1b093','5636b5cb-85ae-4fe1-a07c-25f02dbd37d3',
             '167ae2af-4e3c-434c-b528-aca87187c578','f32671cf-707e-40e5-8b7a-da7b887630fb',
             '408809c1-9420-4d68-93d3-48d730aabf60');

-- Review what the walk added (outputs authored by Andrey beyond the 5 above,
-- and suggestions created after the snapshot):
select o.id, o.title, o.approval_status, o.website_status, o.created_at
  from outputs o join output_authors oa on oa.output_id = o.id
 where oa.person_id = '72e62c1e-536c-4385-bc4a-ad690330da85'
   and o.created_at > '2026-09-29 22:25:18+00';
select id, field, status, created_at from enrichment_suggestions
 where subject_id = '72e62c1e-536c-4385-bc4a-ad690330da85'
   and created_at > '2026-09-29 22:25:18+00';

-- 30 Sep 00:xx: Andrey's 5 ORCID outputs were classified (they had no category,
-- so they were missing from the site). To undo that as well:
-- update public.outputs set category_path = null, macro_type = null, subtype = null,
--   type = case when id in ('f32671cf-707e-40e5-8b7a-da7b887630fb','408809c1-9420-4d68-93d3-48d730aabf60')
--               then 'journal-article' else 'conference-paper' end
--  where id in ('92f007e6-c07b-410a-936a-f0bdf6e1b093','5636b5cb-85ae-4fe1-a07c-25f02dbd37d3',
--               '167ae2af-4e3c-434c-b528-aca87187c578','f32671cf-707e-40e5-8b7a-da7b887630fb',
--               '408809c1-9420-4d68-93d3-48d730aabf60');
