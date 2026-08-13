-- Make outputs.category_path mean what output_taxonomy says it means.
--
-- The importer read a spreadsheet with a fixed four-column layout
-- (Macro-tipo / Tipo / Subtipo / Papel) and padded shallow branches out to four
-- columns by REPEATING a level, positionally:
--
--   depth 1 -> [L1, L1, L1, L1]      depth 3 -> [L1, L1, L2, L3]
--   depth 2 -> [L1, L1, L2, L2]      depth 4 -> [L1, L2, L3, L4]
--
-- That padding is what a researcher actually saw on screen:
--
--   Organização de Seminários e Conferências › Organização de Seminários e
--   Conferências › Membro da comissão científica… › Membro da comissão científica…
--
-- and it is why nothing could ever be built on the taxonomy: as stored, only
-- 39 of the 301 classified rows matched a taxonomy leaf. Collapsing consecutive
-- duplicates inverts the padding exactly and takes that to 294; the remaining 7
-- are one da/de spelling difference, fixed below. 301/301 after this runs.
--
-- Corrects the record: the note at 20260728150000_report_data.sql:14-18 says
-- output_taxonomy "matches only 13 of the 51 distinct category_paths". That
-- was measured against the padded string. It is 51/51 once this has run, so a
-- future report_data() may join the taxonomy for section ordering. The comment
-- in that file is left as written — it is applied history, not documentation.

-- Scoped to this migration and dropped at the end: the app
-- (lib/data/taxonomy.dart) and the importer (scripts/import.py) each carry
-- their own copy for their own layer, so nothing needs it afterwards.
-- A real function rather than pg_temp — migrations may be applied over a
-- pooled connection, where a temp object does not survive between statements.
create function public._collapse_category_path(p text) returns text
language sql immutable as $$
  select string_agg(s, ' › ' order by ord)
  from (
    select s, ord, lag(s) over (order by ord) as prev
    from unnest(string_to_array(p, ' › ')) with ordinality as t(s, ord)
  ) q
  where btrim(s) <> '' and (prev is null or s is distinct from prev);
$$;

-- 1. Un-pad every stored path.
update public.outputs
   set category_path = public._collapse_category_path(category_path)
 where category_path is not null
   and category_path <> public._collapse_category_path(category_path);

-- 2. Backfill the 61 rows that never had a path. macro_type/type/subtype are
--    the first three padded columns, so the same collapse recovers an internal
--    node — not a leaf, but enough to be reachable by a prefix filter, which is
--    the difference between 83% and 100% of outputs being findable.
--
--    Only where the result is a real taxonomy node. Two rows came from the ORCID
--    importer carrying an English `type` of 'conference-paper', which is not in
--    the director's vocabulary at all; inventing a path for those would put a
--    branch in the cascade that maps to nothing. They stay unclassified, which
--    is true, and the UI shows them under "Not classified".
--    The collapse expression is spelled out three times rather than hoisted
--    into a LATERAL: an UPDATE's FROM cannot reference its own target row. It
--    is immutable over 365 rows, so the repetition costs nothing but width.
update public.outputs o
   set category_path = public._collapse_category_path(
         array_to_string(
           array_remove(array[o.macro_type, o.type, o.subtype], null), ' › '))
 where o.category_path is null
   and o.macro_type is not null
   and exists (
     select 1 from public.output_taxonomy t
      where array_to_string(t.segments, ' › ') = public._collapse_category_path(
              array_to_string(
                array_remove(array[o.macro_type, o.type, o.subtype], null), ' › '))
         or array_to_string(t.segments, ' › ') like public._collapse_category_path(
              array_to_string(
                array_remove(array[o.macro_type, o.type, o.subtype], null), ' › ')) || ' › %'
   );

-- 3. The da/de stragglers. The taxonomy is itself inconsistent about da/de
--    across sibling labels; the seed is the FCT-facing vocabulary, so the data
--    moves to it rather than the other way round.
--
--    After the backfill, not before: `subtype` carries the same misspelling, so
--    running this first would leave the rows repaired in step 2 still wrong.
update public.outputs
   set category_path = replace(
         category_path,
         'Membro da comissão científica de conferência não indexada',
         'Membro de comissão científica de conferência não indexada')
 where category_path like '%Membro da comissão científica de conferência não indexada%';

-- 4. Fail the migration rather than the UI. A path that resolves to no taxonomy
--    node means the cascade would offer a branch that selects nothing, which is
--    exactly the "filter that returns an empty list" this work exists to remove.
do $$
declare stray int;
begin
  select count(*) into stray
    from public.outputs o
   where o.category_path is not null
     and not exists (
       select 1 from public.output_taxonomy t
        where array_to_string(t.segments, ' › ') = o.category_path
           or array_to_string(t.segments, ' › ') like o.category_path || ' › %'
     );
  if stray > 0 then
    raise exception
      'category_path repair left % row(s) outside output_taxonomy', stray;
  end if;
end $$;

drop function public._collapse_category_path(text);
