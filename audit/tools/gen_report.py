#!/usr/bin/env python3
"""Compose report.md from findings.json, flows-results.json, bp-scorecard.json, measurements.json
plus the narrative sections in NARRATIVE below. Run: python3 gen_report.py <run_dir>"""
import json, sys
from pathlib import Path
from collections import Counter
RUN = Path(sys.argv[1])
F = json.loads((RUN / "findings.json").read_text()); M = F["metrics"]; findings = F["findings"]
flows = json.loads((RUN / "flows-results.json").read_text())
bp = json.loads((RUN / "bp-scorecard.json").read_text())
meas = json.loads((RUN / "measurements.json").read_text())
sev = M["findings_by_severity"]
N = json.loads((RUN / "narrative.json").read_text()) if (RUN / "narrative.json").exists() else {"top": "", "criticism": "", "recommendations": ""}
bpc = Counter(b["status"] for b in bp)
bp_score = round(100 * (bpc["yes"] + 0.5 * bpc["partial"]) / len(bp))
verdict = "NOT READY" if sev["4"] else ("READY WITH FIXES" if sev["3"] else "READY")
top = [x for x in findings if x["severity"] >= 3]

def fl(x):
    m = f" Measurement: {x['measurement']}" if x.get("measurement") else ""
    return f"**{x['id']} · sev {x['severity']} · {x['criterion']} · screen: {x['screen']}** — {x['evidence']} Evidence: `{x['screenshot']}`.{m}\n\n> Recommendation: {x['recommendation']}\n"

out = []
out.append(f"""# UX/UI Audit — UNIDCOM RIMS researcher portal (web, Playwright Chromium 1280×900 / 390×844) — 2026-09-09

## Executive Summary

**Release verdict: {verdict}.**

{M['findings_total']} findings ({sev['4']} severity-4, {sev['3']} severity-3, {sev['2']} severity-2, {sev['1']} severity-1) across {M['screens_audited']} screens, task success rate {M['task_success_rate_pct']:.0f} % on {M['flows_run']} of {M['flows_defined']} defined flows, best-practice score {bp_score} / 100 ({bpc['yes']} yes · {bpc['partial']} partial · {bpc['no']} no of {len(bp)} BP items).

{N['top']}

## Background & Objectives

- App: UNIDCOM RIMS researcher portal, `Unidcom-IADE` repo, commit `{F['commit']}` ({N.get('build_note', '')}). Build: `flutter build web --dart-define=E2E=true`, v1 (pilot) feature set — v2-only controls (Support requests, Approve/Auto-fill/ORCID-sync on the profile band, Find DOI) are compiled out and were not audited.
- Trigger: pilot cohort onboarding in September 2026; no UX/UI audit had been done (the 2026-08-07 `AUDIT.md` covered engineering, security and operations).
- Companion documents: `docs/research/2026-09-rims-best-practices.md` (cited RIMS/CRIS best practice + BP checklist) and `docs/reports/2026-09-ux-audit/` (stakeholder PDF).

## Methodology

- **Crawl:** every route in `lib/main.dart` in three modes — anonymous, researcher, admin — plus dialogs, the mode chooser, the phone breakpoint for the shell and 7 representative pages, and five provoked system states (cold-start loading, wrong password, empty search, backend unreachable at 3 s and at 26 s). {M['screens_audited']} screens, each with a screenshot and a semantics-tree dump (`screens.md`).
- **Flow suite:** the five v1 Maestro journeys re-expressed in Playwright (Maestro's Chromium driver never returned from its first wait on this machine, three attempts) plus two new journeys covering the RIMS value loop: `profile_confirm` and `add_output` → `review_queue`. `featured_star` (E2E account owns no output) and `support_request` (v2) were not run.
- **Deterministic measurements:** `audit/tools/measure_px.py` over the hierarchies — tap targets vs the 24 px WCAG 2.5.8 minimum, groups vs Miller 7±2, alignment near-misses, contrast estimates (leaf text only; container estimates discarded).
- **Frameworks:** Nielsen's 10 heuristics, UX laws (Fitts, Hick, Miller, Jakob), visual design incl. WCAG 2.2 AA, design-system consistency against `lib/theme/tokens.dart` and Carmela's Figma exports (`RAW_DATA/TemplatesFromCarmela/`), five system states, navigation, ISO 9241-11 metrics, Google HEART mapping, and the BP-01…38 checklist from the research report. Five review passes ran in parallel (one per dimension) plus the orchestrator's own verified findings; every subagent claim at severity ≥ 3 was re-tested before inclusion, and 6 were corrected or dropped (see Appendix C).
- **Not covered:** ORCID OAuth on device; human-participant methods (SUS, interviews); the public Hugo site (reviewed from code and generated data only, scored in the BP table where relevant); v2 controls.

## Metrics

| Metric | Value | Source |
|---|---|---|
| Screens audited | {M['screens_audited']} | `screens.md` |
| Flows defined / run / passed | {M['flows_defined']} / {M['flows_run']} / {M['flows_passed']} | `flows-results.json` |
| Task success rate (ISO 9241-11 effectiveness) | {M['task_success_rate_pct']:.0f} % | flows |
| Mean steps per flow (efficiency) | {M['avg_steps_per_flow']} | flows |
| Mean automation time per flow | {M['avg_duration_s']} s | flows (automation speed, compare run-over-run only) |
| Flow errors | {M['flow_errors']} (+2 warnings) | flows |
| Findings sev 4 / 3 / 2 / 1 | {sev['4']} / {sev['3']} / {sev['2']} / {sev['1']} | `findings.json` |
| Defect density | {M['defect_density_per_screen']} findings per screen | derived |
| Severity-weighted score (Σ severity) | {M['severity_weighted_score']} | derived — the number to drive down next run |
| Best-practice score | {bp_score} / 100 | `bp-scorecard.json` (yes = 1, partial = ½) |
| Untraceable findings dropped | {M['dropped_untraceable']} | aggregate |

### Google HEART mapping

| Dimension | Measured here | Needs instrumentation |
|---|---|---|
| Happiness | Proxy: severity-weighted score {M['severity_weighted_score']}; sev-3+ count {sev['4'] + sev['3']} | in-app rating after first profile confirmation |
| Engagement | Proxy: core loop is 7.9 steps mean; researcher must scroll the sidebar to find Scientific Outputs at 1280×900 (F-007) | sessions per researcher per month |
| Adoption | Proxy: first-launch to value (login → chooser → welcome) in 6 steps; 158/184 researchers cannot sign in until an admin registers their ORCID iD | sign-ins per cohort member (auth.users.last_sign_in_at: 3 of 5 accounts in the last 30 days) |
| Retention | Proxy: state persists across reload (collapse state, mode) — good; 20 s silent spinner on a bad connection (F-031) | returning users after 7 days |
| Task success | **Measured:** {M['task_success_rate_pct']:.0f} % task success, 0 errors, 2 warnings (status invisibility) | field completion rate of profile confirmation and first claim per cohort member |

Minimal instrumentation (one finding's worth): log `mode_chosen`, `profile_confirmed`, `output_added`, `candidate_claimed`, `review_decision` with actor and timestamp — `change_log` already holds the last three; the first two are one insert each.

## Key Findings

### Severity 4 — must fix before the cohort is onboarded

""")
for x in [f for f in findings if f["severity"] == 4]: out.append(fl(x))
out.append("\n### Severity 3 — high priority\n\n")
for x in [f for f in findings if f["severity"] == 3]: out.append(fl(x))
out.append("\n### Severity 2 — minor\n\n")
for x in [f for f in findings if f["severity"] == 2]: out.append(fl(x))
out.append("\n### Severity 1 — cosmetic\n\n")
for x in [f for f in findings if f["severity"] == 1]: out.append(fl(x))

out.append(f"""
## Comparison with RIMS best practice (BP-01…{len(bp)})

Scored against the checklist in `docs/research/2026-09-rims-best-practices.md`. Evidence is a screen file, a code pointer, a migration or a SQL result from the production database on 2026-09-09. Score: **{bp_score} / 100** ({bpc['yes']} yes · {bpc['partial']} partial · {bpc['no']} no).

| ID | Status | Evidence | Gap |
|---|---|---|---|
""")
for b in bp: out.append(f"| {b['id']} | {b['status']} | {b['evidence']} | {b['gap']} |\n")
out.append(f"""
**Where the portal is ahead of the field for its size:** the data model (link rows for authorship, unique DOI, full audit trail), the approval gate feeding a nightly, fail-closed public build, ORCID harvesting into a staging table, and a real merge tool. These are the parts commercial systems charge for and small units usually skip.

**Where it trails every system surveyed:** the *entry* experience — a blank form instead of an identifier lookup (BP-07), no title-similarity warning (BP-16), no draft/withdraw (BP-11/12), no reviewer comment (BP-13), and no status tag in the researcher's own list (BP-21). Pure, Converis, Elements and Haplo all start from a DOI/ORCID lookup and show the workflow state on the researcher's list; FCT's own guidance makes CIÊNCIA ID coverage and the five representative outputs the unit-level facts that matter (BP-34, BP-36), and neither is surfaced yet.

{N['criticism']}

{N['recommendations']}

""")
T = F.get("trend")
if T:
    out.append(f"""## Trend vs previous run ({T['previous_run']})

| Metric | Previous | Now | Δ |
|---|---|---|---|
""")
    for m, (a, b) in T["metric_deltas"].items():
        out.append(f"| {m} | {a} | {b} | {round(b - a, 2) if isinstance(a, (int, float)) and isinstance(b, (int, float)) else ''} |\n")
    for s_, (a, b) in T["severity_deltas"].items():
        out.append(f"| findings sev {s_} | {a} | {b} | {b - a:+d} |\n")
    out.append(f"""
- **Fixed ({len(T['fixed'])}):** {', '.join(T['fixed']) or '—'}
- **New ({len(T['new'])}):** {', '.join(T['new']) or '—'}
- **Regressed ({len(T['regressed'])}):** {', '.join(T['regressed']) or '—'}
- **Persisting ({len(T['persisting'])}):** {', '.join(T['persisting']) or '—'}
""")
out.append(f"""
## Appendix

### A. Screen inventory
See `screens.md` ({M['screens_audited']} crawled screens + 21 flow-step screenshots + 4 verification screenshots). Files: `screens/<name>.png`, `hierarchy/<name>.json` — **kept out of git** (they contain researcher emails from the admin data browser); they exist only on the audit machine, alongside `measurements.json`.

### B. Flow results

| Flow | Passed | Steps | Duration (s) | Source | Note |
|---|---|---|---|---|---|
""")
for r in flows:
    out.append(f"| {r['name']} | {'yes' if r['passed'] else ('NOT RUN' if r['passed'] is None else 'no')} | {r['steps']} | {r['duration_s']} | {r['yaml']} | {'; '.join(r.get('warnings') or r.get('errors') or [])} |\n")
keys = ['small_tap_targets', 'oversized_groups', 'alignment_near_misses']
tot = {k: 0 for k in keys}
for s_, v in meas.items():
    if isinstance(v, dict) and 'error' not in v:
        for k in keys: tot[k] += len(v.get(k, []))
out.append(f"""
### C. Verification of subagent claims
Six claims at severity ≥ 3 were re-tested by the orchestrator before inclusion: two "no error state" claims (backend down) — the classified error appears after the 20 s client timeout, recorded instead as F-035 (silent spinner); one "wrong person shown" claim — confirmed and promoted (F-002); one "account menu does nothing" claim — there is no menu, the copy points to the wrong place (F-018); two tap-target claims (drawer rows 15 px / 5 px, a 6 px row on conferences) — clipped-viewport artefacts, folded into F-035 or dropped.

### D. measurements.json summary
{tot['small_tap_targets']} tap targets under 24 px (most `assumed`, i.e. labelled leaves without an explicit clickable flag), {tot['oversized_groups']} groups over 9 items, {tot['alignment_near_misses']} alignment near-misses across {len(meas)} hierarchies. Contrast estimates were used only for leaf text.

### E. Reproduce
`audit/tools/README.md`. Cleanup SQL for the two DB-writing flows is in `screens.md`.
""")
(RUN / "report.md").write_text("".join(out))
print("report.md:", len("".join(out)), "chars; verdict", verdict, "bp", bp_score, bpc)
