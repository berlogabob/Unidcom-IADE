# News import data hooks (Task A)

`buildNewsTemplate()` returns XLSX bytes, usable with the existing
`downloadBytes` helper and MIME
`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.
It creates News and Taxonomia sheets. `excel` 4.0.6 cannot write dropdown
validation; allowed lists are provided on Taxonomia and enforced by parsing.
`csv` handles CSV quoting/BOM/newlines; `unorm_dart` provides NFKD so slugs
match the Python normalizer instead of relying on a partial accent table.

For Task B, call `fetchArticleSlugs()`, then
`parseNewsFile(bytes, filename, existingSlugs: slugs)`. Display `errors` and
each row's `warnings`. The errors map uses spreadsheet row numbers (CSV record
numbers, including blank records); file-level errors use 1. Duplicate title+year
rows are omitted and reported. Pass corrected/selected `NewsImportRow` objects
to `importNewsDrafts(rows)`; it rejects rows with blocking errors and forces
published=false. No UI is implemented in Task A.

Assumptions:

- Only a literal dash means empty, as in the Python script. Taxonomy cells
  contain a single value; delimiter-separated selections need correction.
- Types retain Taxonomia's bracketed prefixes. Unknown/empty types become
  Unclassified and retain their original value in import_note.
- Lab labels such as BID.Lab are accepted and stored as codes in lab text[].
  These are portable labels, not foreign keys. Both source Taxonomia sheets
  supply the union of member types, including collaborator.
- Date remains required. Numeric years become January 1 with date_precision=year.
  Earlier, missing, and invalid years block import until corrected; no year is
  invented. Excerpts default to the first 150 Unicode characters of the title;
  the complete title is retained and truncation is noted.
- Deduplication uses exact trimmed title + normalized year, matching Python.
  Existing DB slugs influence suffixes; existing titles are not fetched.
- The normalized CSV's source_file and row columns preserve provenance.
- Inserts use batches of 100. A failed batch reports the number already inserted;
  earlier batches remain and are not retried automatically. Refresh existing
  slugs and review partial imports before retrying.
- Sanity article dates are plain dates; it has no precision/year/lab/member/source
  fields. news_type (falling back to legacy category) resolves articleCategory by
  name. scientific_areas resolves scientificArea by title, case-insensitively in
  the target dataset. Missing/ambiguous references warn and preserve existing
  fields. Empty scientific_areas explicitly clears that association.

The migration is written only, and must be applied before using draft insertion.
No migration, deployment, or real import was performed for Task A.

Run the relocated normalizer with:

```sh
cd scripts
uv run python normalize_news.py --input-dir /path/to/original/workbooks
uv run python -m unittest discover -s . -p 'test_*.py'
```

The default output directory is ~/Backups/unidcom; `--output-dir` overrides it.
The 181-row normalized CSV is saved in test/fixtures for portable regression tests.
