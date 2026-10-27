"""Generate offline SQL for review only. Run: uv run --project scripts scripts/backfill_sanity_ids.py."""
from __future__ import annotations

import csv
import json
import os
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import unquote, urlsplit, urlunsplit

REPO = Path(__file__).resolve().parent.parent
ROOT = Path.home() / 'Backups/unidcom'


def title_key(value):
    value = unicodedata.normalize('NFKD', value or '').lower()
    return ' '.join(''.join(c if c.isalnum() else ' ' for c in value
                            if not unicodedata.combining(c)).split())


def link_key(value):
    value = unquote((value or '').strip())
    doi = re.search(r'(?:^doi:\s*|^https?://(?:dx\.)?doi\.org/|^)(10\.\d{4,9}/\S+)$', value, re.I)
    if doi:
        return 'doi:' + doi[1].lower()
    try:
        url = urlsplit(value)
        if url.scheme.lower() in ('http', 'https') and url.netloc:
            return urlunsplit(('', url.netloc.lower(), url.path.rstrip('/'), url.query, ''))
    except ValueError:
        pass
    return ''


def output_matches(outputs, documents):
    links, titles = defaultdict(set), defaultdict(set)
    for doc in documents:
        if doc.get('_type') != 'researchOutput' or doc['_id'].startswith('drafts.'):
            continue
        if key := link_key(doc.get('link')):
            links[key].add(doc['_id'])
        if (key := title_key(doc.get('title'))) and doc.get('year') is not None:
            titles[(key, str(doc['year']))].add(doc['_id'])
    proposals, skipped = [], []
    for row in outputs:
        if row.get('merged_into'):
            skipped.append({**row, 'reason': 'merged'})
            continue
        candidates = set()
        kinds = []
        for key in {link_key(row.get('doi')), link_key(row.get('url'))} - {''}:
            if links[key]:
                candidates.update(links[key])
                kinds.append('doi/link')
        key = (title_key(row.get('title')), str(row.get('reporting_year')))
        if key[0] and row.get('reporting_year') is not None and titles[key]:
            candidates.update(titles[key])
            kinds.append('title+year')
        record = {'person_id': '', 'output_id': row['id'], 'sanity_id': '',
                  'match_kind': '+'.join(sorted(set(kinds))), 'title': row.get('title', '')}
        if row.get('sanity_id'):
            skipped.append({**record, 'sanity_id': row['sanity_id'], 'reason': 'already linked'})
        elif len(candidates) == 1:
            proposals.append({**record, 'sanity_id': next(iter(candidates))})
        else:
            skipped.append({**record, 'sanity_id': '|'.join(sorted(candidates)),
                            'reason': 'ambiguous' if candidates else 'no match'})
    # Include existing links when checking that a target has exactly one portal owner.
    owners = Counter(r['sanity_id'] for r in proposals)
    owners.update(r['sanity_id'] for r in outputs if r.get('sanity_id') and not r.get('merged_into'))
    accepted = []
    for record in proposals:
        if owners[record['sanity_id']] == 1:
            accepted.append(record)
        else:
            skipped.append({**record, 'reason': 'multiple portal outputs for target'})
    return accepted, skipped


def people_matches(records):
    eligible, skipped = [], []
    for row in records:
        if row['ambiguous'].strip().lower() == 'false' and row['match_kind'] in ('orcid', 'email') and row['sanity_id'] and row['person_id']:
            eligible.append(row)
        else:
            skipped.append({**row, 'reason': 'ambiguous or unsupported match'})
    people = Counter(r['person_id'] for r in eligible)
    targets = Counter(r['sanity_id'] for r in eligible)
    accepted = []
    for row in eligible:
        if people[row['person_id']] == targets[row['sanity_id']] == 1:
            accepted.append(row)
        else:
            skipped.append({**row, 'reason': 'not one-to-one'})
    return accepted, skipped


def write_review(table, id_column, accepted, skipped, stem):
    quote = lambda v: "'" + v.replace("'", "''") + "'"
    sql = ['-- REVIEW ONLY: generated offline; no SQL has been executed.']
    for row in accepted:
        sql.append(f"update {table} set sanity_id={quote(row['sanity_id'])} where id={quote(row[id_column])} and sanity_id is null;")
    (ROOT / f'{stem}.sql').write_text('\n'.join(sql) + '\n')
    fields = sorted(set().union(*(row.keys() for row in skipped))) if skipped else ['reason']
    with (ROOT / f'{stem}_skipped.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fields)
        writer.writeheader()
        writer.writerows(skipped)
    return {'updates': len(accepted), 'skipped': len(skipped),
            'skip_reasons': dict(Counter(r['reason'] for r in skipped)),
            'match_kinds': dict(Counter(r['match_kind'] for r in accepted))}


def main():
    os.umask(0o077)
    dumps = sorted(ROOT.glob('*/sanity-ld5jhf23.ndjson'))
    if not dumps:
        raise SystemExit('No backup Sanity dump found')
    dump = dumps[-1]
    with (REPO / 'docs/reports/2026-09-sanity-vs-supabase/matched_people.csv').open(newline='') as stream:
        people = people_matches(list(csv.DictReader(stream)))
    outputs = json.loads((dump.parent / 'public/outputs.json').read_text())
    documents = [json.loads(line) for line in dump.read_text().splitlines() if line.strip()]
    summary = {'backup': str(dump.parent),
               'people': write_review('people', 'person_id', *people, 'backfill_sanity_ids'),
               'outputs': write_review('outputs', 'output_id', *output_matches(outputs, documents), 'backfill_output_sanity_ids')}
    (ROOT / 'backfill_sanity_ids_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
