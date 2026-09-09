-- F-005 / BP-13: admins record why an output was rejected; the researcher sees it on their own list.
-- Applied to the live project via the Supabase MCP on 2026-09-09.
alter table public.outputs add column if not exists rejection_reason text;
comment on column public.outputs.rejection_reason is 'Optional reviewer note set when approval_status becomes rejected; shown to the output''s authors.';
