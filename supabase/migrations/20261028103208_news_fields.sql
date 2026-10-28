-- Additive only. Year-only news uses January 1 and date_precision = 'year'.
-- Lab codes remain portable through the pure file parser (no DB id lookup).
alter table public.articles
  add column if not exists year int,
  add column if not exists date_precision text not null default 'day'
    check (date_precision in ('year', 'month', 'day')),
  add column if not exists news_type text,
  add column if not exists scientific_areas text[],
  add column if not exists lab text[],
  add column if not exists member_types text[],
  add column if not exists source text,
  add column if not exists import_note text;
