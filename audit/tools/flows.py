#!/usr/bin/env python3
"""Flow suite for the UX audit — the same journeys as .maestro/*.yaml, driven by
Playwright because Maestro's Chromium driver hung on this machine (chromedriver
never returned from the first visibility wait, 3 attempts, 5+ min each).

Writes <run>/flows-results.json and evidence screenshots screens/flow_<name>_<n>.png.
Run: uv run --with playwright python flows.py <run_dir>
"""
import json, re, sys, time
from pathlib import Path
src = open(Path(__file__).parent / "crawl.py").read().split("# --- crawl")[0]
src = re.sub(r"RUN = Path\(sys.argv\[1\]\);.*?\(RUN / \"hierarchy\"\).mkdir\(exist_ok=True\)", "RUN = Path(sys.argv[1])", src, flags=re.S)
exec(src)
from playwright.sync_api import sync_playwright

results = []
ORCID_ERR = "No%20UNIDCOM%20profile%20is%20registered%20for%20ORCID%20iD%200000-0002-1825-0097.%20Contact%20an%20admin."

class Flow:
    def __init__(self, name, page, yaml):
        self.name, self.page, self.yaml = name, page, yaml
        self.steps = 0; self.errors = []; self.warnings = []; self.t0 = time.time(); self.shots = 0
    def step(self, desc):
        self.steps += 1; print(f"  [{self.name}] step {self.steps}: {desc}", flush=True)
    def shot(self, tag):
        self.shots += 1; p = RUN / "screens" / f"flow_{self.name}_{self.shots}_{tag}.png"; self.page.screenshot(path=str(p)); return p.name
    def expect(self, pattern, timeout=20, negate=False):
        ok = visible(self.page, pattern, timeout)
        if negate: ok = not ok
        if not ok: self.errors.append(("expected " + ("absent: " if negate else "visible: ")) + pattern); self.shot("FAIL")
        return ok
    def done(self, note=""):
        results.append(dict(name=self.name, passed=not self.errors, duration_s=round(time.time() - self.t0, 1), steps=self.steps,
                            errors=self.errors, warnings=self.warnings, yaml=self.yaml, note=note)); print(f"  [{self.name}] {'PASS' if not self.errors else 'FAIL'} {self.errors}", flush=True)

def run(name, yaml, fn, note=""):
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page(viewport=DESKTOP); pg.set_default_timeout(30000)
        f = Flow(name, pg, yaml)
        try: fn(f, pg)
        except Exception as e: f.errors.append(f"exception: {e}"); f.shot("EXC")
        f.done(note); b.close()

def pick(f, pg, label):
    for _ in range(4):
        click(pg, label); pg.wait_for_timeout(1200)
        if not find(pg, "How do you want to continue", clickable_only=False): return
    f.errors.append("chooser did not dismiss after tapping " + label)

def do_login(f, pg):
    f.step("open #/login"); pg.goto(f"{BASE}/#/login"); f.expect("^Email$", 60)
    f.step("type email"); typein(pg, "Email", EMAIL); f.step("type password"); typein(pg, "Password", PASSWORD)
    f.step("tap Sign in"); click(pg, "^Sign in$"); f.expect("How do you want to continue", 40)

def auth_gate(f, pg):
    f.step("anon deep link #/people"); pg.goto(f"{BASE}/#/people"); f.expect("^Password$", 60); f.shot("bounced_to_login")
    f.expect("^Structure$", 3, negate=True)
    do_login(f, pg); f.shot("chooser")
    f.step("tap As a researcher"); pick(f, pg, "As a researcher"); f.expect("Your first steps", 30); f.shot("welcome")

def researcher_mode(f, pg):
    do_login(f, pg); f.step("tap As a researcher"); pick(f, pg, "As a researcher"); f.expect("Your first steps", 30)
    f.expect("^Structure$", 2, negate=True); f.expect("^Projects$", 2, negate=True); f.expect("^Support requests$", 2, negate=True)
    f.expect("OUTPUTS|PROFILE STATUS|Getting started", 5); f.shot("sidebar")  # sidebar rows are not in the desktop semantics tree (finding); assert content instead
    f.step("deep link #/people in researcher mode"); pg.goto(f"{BASE}/#/people"); f.expect("OUTPUTS|Research Activity Summary|Overview", 20); f.shot("deeplink_home")
    f.expect("LAST VERIFIED", 2, negate=True)
    f.step("open #/app/profile"); pg.goto(f"{BASE}/#/app/profile"); f.expect("^Edit$", 20)
    for t in ["Approve", "Auto-fill", "ORCID sync", "^Last verified$"]: f.expect(t, 1, negate=True)
    f.step("open #/app/outputs"); pg.goto(f"{BASE}/#/app/outputs"); f.expect("Add output", 20)
    f.step("open #/app/outputs/import"); pg.goto(f"{BASE}/#/app/outputs/import"); f.expect("My ORCID publications", 20); f.shot("import")

def admin_mode(f, pg):
    do_login(f, pg); f.step("tap As an administrator"); pick(f, pg, "As an administrator"); f.expect("ORCID LINKED|OUTPUTS APPROVED", 30); f.shot("dashboard")
    f.expect("RESEARCHERS|People", 5)
    f.step("open #/people"); pg.goto(f"{BASE}/#/people"); f.expect("Search", 20)
    f.step("switch: #/app/mode after clearing choice"); pg.evaluate("() => sessionStorage.removeItem('view_mode')"); pg.goto(f"{BASE}/#/app/mode"); pg.reload()
    f.expect("How do you want to continue", 30); f.step("tap As a researcher"); pick(f, pg, "As a researcher"); f.expect("Your first steps", 30)
    f.expect("^Structure$", 2, negate=True); f.shot("back_to_researcher")

def orcid_error(f, pg):
    f.step("open /?orcid_error=…"); pg.goto(f"{BASE}/?orcid_error={ORCID_ERR}"); f.expect("^Password$", 60); f.expect("No UNIDCOM profile", 10); f.shot("error_shown")
    f.step("open /?v=stale#/app/welcome/start"); pg.goto(f"{BASE}/?v=stale#/app/welcome/start"); f.expect("Your first steps", 30)
    f.step("open /?v=stale#/login"); pg.goto(f"{BASE}/?v=stale#/login"); f.expect("^Password$", 20); f.expect("No UNIDCOM profile", 2, negate=True)

def profile_confirm(f, pg):
    do_login(f, pg); f.step("tap As a researcher"); pick(f, pg, "As a researcher"); f.expect("Your first steps", 30)
    f.step("open #/app/profile"); pg.goto(f"{BASE}/#/app/profile"); f.expect("Confirm my profile", 20); f.shot("draft")
    f.step("tap Confirm my profile"); click(pg, "^Confirm my profile$"); ok = f.expect("Awaiting UNIDCOM approval", 20); f.shot("after_confirm")
    f.step("open #/app/home/status"); pg.goto(f"{BASE}/#/app/home/status"); f.expect("Awaiting UNIDCOM approval|pending", 20); f.shot("status_page")

def add_output(f, pg):
    do_login(f, pg); f.step("tap As a researcher"); pick(f, pg, "As a researcher"); f.expect("Your first steps", 30)
    f.step("open #/app/outputs/add"); pg.goto(f"{BASE}/#/app/outputs/add"); f.expect("^Add output$", 20)
    f.step("tap Add output"); click(pg, "^Add output$"); f.expect("^Title$", 10); f.shot("dialog")
    f.step("tap Save with empty form"); click(pg, "^Save$"); pg.wait_for_timeout(800); f.expect("A title is required|required", 5); f.shot("validation")
    f.step("type title"); typein(pg, "Title", "E2E UX audit output (delete me)")
    f.step("tap Save"); click(pg, "^Save$"); pg.wait_for_timeout(2500); f.shot("after_add")
    f.step("open #/app/outputs"); pg.goto(f"{BASE}/#/app/outputs"); f.expect("E2E UX audit output", 20); f.shot("in_my_outputs")
    if not visible(pg, "Pending|pending|Awaiting", 5): f.warnings.append("no status tag on the new pending output in My Outputs (finding, not a task failure)")

def review_queue(f, pg):
    do_login(f, pg); f.step("tap As an administrator"); pick(f, pg, "As an administrator"); f.expect("ORCID LINKED|OUTPUTS APPROVED", 30)
    f.step("open #/app/admin/review"); pg.goto(f"{BASE}/#/app/admin/review"); f.expect("Profiles to approve", 30); f.shot("queue_default_tab")
    f.step("tap Outputs to approve tab"); click(pg, "^Outputs to approve$"); f.expect("E2E UX audit output", 30); f.shot("queue_outputs")
    f.step("tap Approve all pending"); click(pg, "^Approve all")
    if not visible(pg, "Approve all .* pending outputs\\?", 4): dom_click(pg, "^Approve all")
    f.expect("Approve all .* pending outputs\\?", 10); f.shot("confirm_dialog")
    f.step("tap Cancel"); click(pg, "^Cancel$"); pg.wait_for_timeout(500)
    f.step("tap Reject on the E2E row"); click(pg, "^Reject$"); pg.wait_for_timeout(1500)
    if visible(pg, "E2E UX audit output", 2): dom_click(pg, "^Reject$"); pg.wait_for_timeout(2000)
    f.shot("after_reject")
    gone = not visible(pg, "E2E UX audit output", 3)
    if not gone: f.errors.append("row still present after Reject")
    if not visible(pg, "rejected|Rejected|removed|Undo", 2): f.warnings.append("no feedback after Reject (finding)")

if __name__ == "__main__":
    only = set(sys.argv[2:])
    prev = json.loads((RUN / "flows-results.json").read_text()) if (RUN / "flows-results.json").exists() and only else []
    _run = run
    def run(name, yaml, fn, note=""):
        if only and name not in only: return
        _run(name, yaml, fn, note)
    run("auth_gate", ".maestro/auth_gate.yaml", auth_gate)
    run("researcher_mode", ".maestro/researcher_mode.yaml", researcher_mode)
    run("admin_mode", ".maestro/admin_mode.yaml", admin_mode)
    run("orcid_error", ".maestro/orcid_error.yaml", orcid_error)
    run("profile_confirm", "(new) profile_confirm — researcher confirms draft profile", profile_confirm, "writes people.profile_status for the E2E account; cleanup: update people set profile_status='draft' where email='andre.berloga+e2e@gmail.com'")
    run("add_output", "(new) add_output — researcher records an output manually", add_output, "creates a pending output; cleanup: delete from outputs where title like 'E2E UX audit output%'")
    run("review_queue", "(new) review_queue — admin sees, confirms-all, rejects", review_queue, "Reject has no confirmation dialog in code (review_queue.dart _rejectOutput)")
    results.append(dict(name="featured_star", passed=None, duration_s=0, steps=0, errors=["NOT RUN: the E2E account has 0 outputs to star"], yaml=".maestro/featured_star.yaml", note="not run"))
    results.append(dict(name="support_request", passed=None, duration_s=0, steps=0, errors=["NOT RUN: v2-only route, compiled out of the pilot build"], yaml=".maestro/support_request.yaml", note="not run"))
    if only:
        names = {r["name"] for r in results}; results = [r for r in prev if r["name"] not in names] + results
        order = ["auth_gate","researcher_mode","admin_mode","orcid_error","profile_confirm","add_output","review_queue","featured_star","support_request"]; results.sort(key=lambda r: order.index(r["name"]))
    (RUN / "flows-results.json").write_text(json.dumps(results, indent=2)); print(json.dumps([(r["name"], r["passed"], r["steps"]) for r in results]))
