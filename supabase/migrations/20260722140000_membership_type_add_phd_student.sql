-- Allow 'phd_student' as a membership type (PhD students were a distinct roster
-- category with no matching value).
alter table public.people drop constraint people_membership_type_check;
alter table public.people add constraint people_membership_type_check
  check (membership_type = any (array[
    'integrated','collaborator','phd_student','external','staff','advisory_board'
  ]::text[]));
