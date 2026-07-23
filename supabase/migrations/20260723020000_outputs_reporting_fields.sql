-- A: report-critical output fields that the first import dropped.
alter table public.outputs
  add column full_reference text,   -- Referência completa (the citation)
  add column fct_selected boolean,  -- FCT selected
  add column macro_type text,       -- Macro-tipo
  add column verified_online boolean, -- Verificado online?
  add column source text,           -- Fonte
  add column output_status text;    -- Estado do output (Concluído | Planeado)
