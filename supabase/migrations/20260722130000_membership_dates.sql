-- Membership entry/exit dates from the roster spreadsheets (Entrada / Saída).
alter table public.people
  add column join_date date,
  add column exit_date date;
