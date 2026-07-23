-- Per-year roles & allocations, so "present" = current-year rows and history is
-- preserved instead of overwritten. Answers the boss's "how were coordinators/
-- members allocated by year" and enables "mentored N students in year Y".
-- ponytail: add a `year` where it hurts (lab_members, mentorships) — not a
-- universal temporal-everything engine.

-- ---------------------------------------------------------------- lab_members
-- Add year to the allocation and fold it into the PK (a person can be member of
-- a lab in several years, with different coordinator status each year).
alter table public.lab_members add column year int;
update public.lab_members set year = extract(year from now())::int where year is null;
alter table public.lab_members alter column year set not null;
alter table public.lab_members drop constraint lab_members_pkey;
alter table public.lab_members add primary key (lab_id, person_id, year);

-- ---------------------------------------------------------------- person_tags
-- Optional year on a tag assignment; NULL = a standing/current tag.
-- ponytail: attribute only (PK unchanged) — no concrete multi-year-per-tag need yet.
alter table public.person_tags add column year int;

-- ---------------------------------------------------------------- mentorships
-- Net-new: there is no mentorship edge today. Student may be an internal person
-- (student_person_id) or a free-text external name (student_name).
create table public.mentorships (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.people on delete cascade,
  student_person_id uuid references public.people on delete set null,
  student_name text,                        -- for students not in `people`
  year int not null,
  notes text,
  created_at timestamptz default now()
);
create index mentorships_mentor_idx on public.mentorships (mentor_id, year);

-- ============================================================ RLS
alter table public.mentorships enable row level security;
-- Readable to all (matches join-table convention), admin-only write.
create policy mentorships_read  on public.mentorships for select using (true);
create policy mentorships_write on public.mentorships for all using (public.is_admin()) with check (public.is_admin());
