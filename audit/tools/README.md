# Audit tools

Playwright drivers used by the 2026-09-09 UX audit (Maestro's Chromium driver hung on the
audit machine). All read `MAESTRO_EMAIL` / `MAESTRO_PASSWORD` from the environment
(`.maestro/.env`) and expect the E2E build served on :8123:

```sh
flutter build web --dart-define=E2E=true
python3 -m http.server 8123 --directory build/web
set -a; source .maestro/.env; set +a
uv run --with playwright playwright install chromium          # once
uv run --with playwright python audit/tools/crawl.py audit/$(date +%Y-%m-%d-%H%M)
uv run --with playwright python audit/tools/flows.py  audit/<run>          # all flows
uv run --with playwright python audit/tools/flows.py  audit/<run> review_queue   # one flow
uv run --with pillow      python audit/tools/measure_px.py audit/<run>
python3 audit/tools/aggregate.py audit/<run>                              # after sub_*.json exist
```

- `crawl.py` — visits every route in anonymous, researcher and admin mode; writes `screens/*.png`,
  `hierarchy/*.json` (Android-style bounds from the Flutter semantics DOM) and `screens.md`.
  Person/output/project ids are hard-coded near the top; refresh them from the DB if rows change.
- `flows.py` — the 7 journeys (5 mirror `.maestro/*.yaml`, 2 new: `profile_confirm`, `add_output`)
  plus `review_queue`; writes `flows-results.json`. Two flows write to the live DB — cleanup SQL
  is in the run's `screens.md`.
- `measure_px.py` — `app-audit/scripts/measure.py` with scale fixed to 1 (CSS px) and the
  24 px WCAG 2.5.8 target minimum instead of the 44 pt mobile figure.
- `aggregate.py` — merges `sub_*.json` (one per review dimension), enforces the traceability
  rule, dedupes by (criterion, screen), computes the ISO 9241-11 metrics and writes `findings.json`.
