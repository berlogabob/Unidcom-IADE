-- Two-layer roles: membership (Layer 1: integrated | collaborator | external)
-- and optional roles/tags/mentorships (Layer 2), all in the person_roles logbook.
-- Splits the non-base memberships that Phase-2b lumped in, folds mentorships into
-- person_roles, and drops the now-empty mentorships table.

-- Linked person for kind='mentorship' (the student), nullable.
alter table public.person_roles
  add column link_id uuid references public.people on delete set null;

-- The trigger forces status='pending' for non-admin writes; a migration has no
-- admin JWT, so disable it while we reclassify (keep rows approved).
alter table public.person_roles disable trigger trg_protect_person_roles;

-- Split label ∉ {integrated,collaborator,external} into base membership + a role.
-- phd_student -> collaborator (+ role); advisory_board -> external (+ role);
-- staff -> integrated (+ role).
insert into public.person_roles (person_id, kind, label, year, status)
select person_id, 'role', label, year, status
from public.person_roles
where kind = 'membership' and label in ('phd_student', 'advisory_board', 'staff');

update public.person_roles set label = 'collaborator'
  where kind = 'membership' and label = 'phd_student';
update public.person_roles set label = 'external'
  where kind = 'membership' and label = 'advisory_board';
update public.person_roles set label = 'integrated'
  where kind = 'membership' and label = 'staff';

alter table public.person_roles enable trigger trg_protect_person_roles;

-- Mirror the base membership onto the people cache. The people table has its own
-- protect_people_cols trigger that resets membership_type for non-admin writes
-- (a migration has no admin JWT), so disable it around these updates too.
alter table public.people disable trigger trg_protect_people;
update public.people set membership_type = 'collaborator' where membership_type = 'phd_student';
update public.people set membership_type = 'external'     where membership_type = 'advisory_board';
update public.people set membership_type = 'integrated'   where membership_type = 'staff';
alter table public.people enable trigger trg_protect_people;

-- mentorships folds into person_roles (kind='mentorship'); the table is empty.
drop table if exists public.mentorships;
