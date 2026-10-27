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
published=false. Task B supplies the UI described below.

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

## News publishing UI (Task B)

Admin → Website → articles provides New news item (wizard), Download template,
and Import filled template. Opening an existing article uses the same wizard.
`canPublishNews` in `lib/app/news_wizard.dart` is the single news permission
policy and currently follows `isAdmin` (including admin view mode).

The wizard follows the existing output dialog/vertical Stepper. Title, a real
date at the selected precision, and a type are required; Unclassified is allowed
with a warning. Taxonomy associations, excerpt, body and image are optional;
missing lab warns. Excerpts allow at most 150 Unicode characters. Partial dates
are entered as YYYY or YYYY-MM and stored with January 1 / day 1 respectively.
Changing precision requires the date text to match the new precision. New slugs
use the import normalizer, refresh existing slugs before saving, and suffix
collisions; edits retain the existing website address. Database uniqueness still
handles concurrent writes. Publish attempts the articles-only Sanity push after
saving; a bridge failure does not undo the saved publication.

The import preview counts all parsed rows, including skipped ones, in mutually
exclusive OK / warnings / errors groups; duplicate rows are shown separately.
Unclassified type and missing lab can be corrected inline. Other blocking errors
require skipping the row or correcting and reopening the file. Original
import_note provenance remains after inline corrections. Confirmation imports
only selected valid rows, always unpublished, in batches of 100 with progress.
A failed batch ends the preview with the inserted count and partial-import
message; reopen the import to refresh slugs before retrying. File selection and
download use the existing web-only helper pattern.

Widget tests inject loaders, saves, image selection, push and import callbacks;
no network or database writes are needed. The Task A migration must already be
applied to the target database before using these fields. Task B does not apply
migrations or deploy anything.
