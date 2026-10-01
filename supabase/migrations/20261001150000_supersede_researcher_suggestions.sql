-- One open researcher suggestion per field (1 Oct: Save draft then Submit left
-- two identical pending bio rows). The newest edit supersedes older draft or
-- pending rows for the same subject and field, whichever call inserted them.

alter table enrichment_suggestions
  drop constraint enrichment_suggestions_status_check,
  add constraint enrichment_suggestions_status_check
    check (status in ('draft', 'pending', 'accepted', 'rejected', 'superseded'));

-- security definer: owner RLS may not update a pending row.
create or replace function supersede_researcher_suggestions()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update enrichment_suggestions
     set status = 'superseded'
   where source = 'researcher'
     and subject_type = new.subject_type
     and subject_id = new.subject_id
     and field = new.field
     and status in ('draft', 'pending');
  return new;
end;
$$;

revoke execute on function supersede_researcher_suggestions() from public, anon, authenticated;

create trigger enrichment_suggestions_supersede
  before insert on enrichment_suggestions
  for each row
  when (new.source = 'researcher')
  execute function supersede_researcher_suggestions();

-- Existing duplicates: keep the newest open row per subject and field.
update enrichment_suggestions s
   set status = 'superseded'
 where s.source = 'researcher'
   and s.status in ('draft', 'pending')
   and exists (
     select 1 from enrichment_suggestions n
      where n.source = 'researcher'
        and n.subject_type = s.subject_type
        and n.subject_id = s.subject_id
        and n.field = s.field
        and n.status in ('draft', 'pending')
        and n.created_at > s.created_at
   );
