-- C: context fields skipped on day 0.
alter table public.projects
  add column notes text,   -- Notas
  add column risk text;    -- Risco (Baixo | Médio | Alto)

alter table public.people
  add column notes text,             -- Notas
  add column phd text,               -- PhD (field of doctoral study)
  add column integration_year int;   -- Ano de integração
