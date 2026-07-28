-- Outputs a person pins to the top of their own profile.
alter table public.people
  add column featured_outputs uuid[] not null default '{}';

alter table public.people
  add constraint people_featured_outputs_max check (
    coalesce(array_length(featured_outputs, 1), 0) <= 5);

-- ponytail: array, not a join-table flag. people_update RLS + updatePerson()
-- already cover owner/admin writes, and array order IS the display order.
-- Not FK-enforced: rendering intersects against the person's linked outputs,
-- so an unknown or deleted id just doesn't show.
comment on column public.people.featured_outputs is
  'Ordered ids of outputs the person pinned to the top of their profile. Max 5.';
