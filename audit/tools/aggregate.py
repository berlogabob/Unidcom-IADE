#!/usr/bin/env python3
"""Merge sub_*.json → findings.json; enforce traceability; compute metrics.
Run: python3 aggregate.py <run_dir>   (prints a summary; report.md is written by hand from it)
"""
import json, sys, re
from pathlib import Path
from collections import Counter, defaultdict

RUN = Path(sys.argv[1])
findings = []; dropped = []
for f in sorted(RUN.glob("sub_*.json")):
    for x in json.loads(f.read_text()):
        x["_src"] = f.stem.replace("sub_", "")
        shot = x.get("screenshot") or ""
        if not (RUN / shot).exists() or not x.get("criterion") or int(x.get("severity", 0)) < 1:
            dropped.append((f.stem, x.get("criterion"), x.get("screen"), shot)); continue
        x["severity"] = int(x["severity"]); findings.append(x)

# same root cause under two criteria → fold the secondary into the primary (noted in evidence)
FOLD = {("DS-BRAND-1", "r_unknown_route"): ("H9", "r_unknown_route"),
        ("ST-SUCCESS", "flow_review_queue_4_after_reject"): ("H5", "a_admin_review"),
        ("LAW-MILLER-1", "phone_r_drawer"): ("LAW-MILLER-1", "r_sidebar_expanded"),
        ("LAW-JAKOB-1", "r_account_menu"): ("H2", "r_account_menu"),
        ("H1", "state_loading_cold"): ("ST-LOAD", "state_loading_cold"),
        ("ST-ERROR", "r_unknown_route"): ("H9", "r_unknown_route"),
        ("LAW-FITTS-1", "phone_a_review"): ("VD-RESP-1", "phone_a_review"),
        ("LAW-FITTS-1", "phone_r_drawer"): ("VD-GES-1", "r_home"),
        ("VD-RESP-1", "phone_r_drawer"): ("VD-GES-1", "r_home")}
primary = {k: None for k in FOLD.values()}
for x in findings:
    if (x["criterion"], x["screen"]) in primary: primary[(x["criterion"], x["screen"])] = x
kept = []
for x in findings:
    k = (x["criterion"], x["screen"])
    if k in FOLD and primary[FOLD[k]] is not None:
        primary[FOLD[k]]["evidence"] += f" [also {k[0]} on {k[1]}: {x['evidence'][:200]}]"; continue
    kept.append(x)
findings = kept

# dedupe: same screen + same criterion → keep highest severity, merge evidence
by_key = {}
for x in findings:
    k = (x["criterion"], x["screen"])
    if k in by_key:
        y = by_key[k]
        if x["severity"] > y["severity"]: x, y = y, x; by_key[k] = y
        y["evidence"] += f" [{x['_src']}: {x['evidence'][:160]}]"
    else:
        by_key[k] = x
merged = sorted(by_key.values(), key=lambda x: (-x["severity"], x["criterion"], x["screen"]))
for i, x in enumerate(merged, 1):
    x["id"] = f"F-{i:03d}"; x["source"] = x.pop("_src")
    x = {k: x[k] for k in ["id", "criterion", "screen", "severity", "evidence", "screenshot", "measurement", "recommendation", "source"] if k in x}
    merged[i - 1] = x

flows = json.loads((RUN / "flows-results.json").read_text())
ran = [r for r in flows if r["passed"] is not None]
screens = [l for l in (RUN / "screens.md").read_text().splitlines() if l.startswith("| ") and not l.startswith("| Screen") and not l.startswith("|---") and "| flow `" not in l]
sev = Counter(x["severity"] for x in merged)
metrics = {
    "screens_audited": len(screens),
    "flows_defined": len(flows), "flows_run": len(ran), "flows_passed": sum(1 for r in ran if r["passed"]),
    "task_success_rate_pct": round(100 * sum(1 for r in ran if r["passed"]) / max(1, len(ran)), 1),
    "avg_steps_per_flow": round(sum(r["steps"] for r in ran) / max(1, len(ran)), 1),
    "avg_duration_s": round(sum(r["duration_s"] for r in ran) / max(1, len(ran)), 1),
    "flow_errors": sum(len(r["errors"]) for r in ran),
    "findings_total": len(merged), "findings_by_severity": {str(s): sev.get(s, 0) for s in (4, 3, 2, 1)},
    "defect_density_per_screen": round(len(merged) / max(1, len(screens)), 2),
    "severity_weighted_score": sum(x["severity"] for x in merged),
    "dropped_untraceable": len(dropped),
}
out = {"app": "UNIDCOM RIMS researcher portal (Unidcom-IADE)", "platform": "web", "device": "Playwright Chromium 1280×900 / 390×844", "date": "2026-09-09",
       "commit": "73259d4", "build": "flutter build web --dart-define=E2E=true (v1)", "screens_audited": len(screens),
       "flows": [{k: r[k] for k in ("name", "passed", "duration_s", "steps", "yaml")} for r in flows], "metrics": metrics, "findings": merged}
(RUN / "findings.json").write_text(json.dumps(out, indent=2, ensure_ascii=False))
print(json.dumps(metrics, indent=1))
print("by source:", Counter(x["source"] for x in merged))
print("by criterion (top):", Counter(x["criterion"] for x in merged).most_common(12))
print("dropped:", dropped[:10])
for x in merged:
    if x["severity"] >= 3: print(x["id"], x["severity"], x["criterion"], x["screen"], "—", x["evidence"][:110])
