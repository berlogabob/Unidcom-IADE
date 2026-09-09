#!/usr/bin/env python3
"""UX-audit crawler for the UNIDCOM portal (Flutter web, semantics on).

Playwright + Chromium. For every screen: screens/<name>.png and
hierarchy/<name>.json in the Android-style {attributes:{bounds,text,clickable},children}
shape that app-audit/scripts/measure.py parses. Writes screens.md.

Run: uv run --with playwright python crawl.py <run_dir>
"""
import json, os, re, sys, time
from pathlib import Path
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

BASE = "http://localhost:8123"
EMAIL = os.environ["MAESTRO_EMAIL"]; PASSWORD = os.environ["MAESTRO_PASSWORD"]
IDS = dict(person="4f09781a-c469-5368-91aa-50c6b0ec0648", output="08e00845-05f7-5d99-b73d-e5b5812c50c4",
           project="ce19906d-11e7-5213-92ec-54deb067fab5", lab="e9e4427a-d634-5dc7-bfa7-225da992076e",
           cluster="ed43a144-9f44-5fde-8730-a208f5779d6e", objective="ac0befd5-67ce-57c2-9eaf-29635b749a75",
           e2e_person="64e46dd8-0e57-4e6c-8560-b1f4f4d83415")
RUN = Path(sys.argv[1]); import shutil; shutil.rmtree(RUN / 'screens', ignore_errors=True); shutil.rmtree(RUN / 'hierarchy', ignore_errors=True); (RUN / "screens").mkdir(parents=True, exist_ok=True); (RUN / "hierarchy").mkdir(exist_ok=True)
DESKTOP = dict(width=1280, height=900); PHONE = dict(width=390, height=844)
inventory = []  # (name, mode, how, note)

# --- semantics helpers -------------------------------------------------------
HIER_JS = """
() => {
  const walk = (el) => {
    const r = el.getBoundingClientRect();
    const a = {bounds: `[${Math.round(r.left)},${Math.round(r.top)}][${Math.round(r.right)},${Math.round(r.bottom)}]`};
    let own = '';
    for (const n of el.childNodes) { if (n.nodeType === 3) own += n.textContent; else if (n.nodeType === 1 && !n.tagName.toLowerCase().startsWith('flt-') && n.tagName !== 'INPUT') own += n.textContent; }
    const lbl = el.getAttribute('aria-label') || (el.tagName === 'INPUT' ? (el.value || el.placeholder || '') : '') || own.trim();
    if (lbl) a.text = lbl;
    const role = el.getAttribute('role'); if (role) a.role = role;
    const flags = el.getAttribute('flt-tappable') !== null || role === 'button' || role === 'link' || role === 'checkbox' || role === 'radio' || role === 'textbox' || el.tagName === 'INPUT' || el.tagName === 'BUTTON' || (el.getAttribute('tabindex') !== null && role !== 'text');
    a.clickable = flags ? 'true' : 'false';
    if (el.getAttribute('aria-disabled') === 'true') a.enabled = 'false';
    const id = el.id; if (id) a['resource-id'] = id;
    const kids = [];
    for (const c of el.children) {
      if (c.tagName && c.tagName.toLowerCase().startsWith('flt-semantics')) kids.push(walk(c));
      else if (c.tagName === 'INPUT' || c.tagName === 'BUTTON' || c.tagName === 'TEXTAREA') kids.push(walk(c));
      else for (const g of c.querySelectorAll(':scope > flt-semantics, :scope > flt-semantics-container')) kids.push(walk(g));
    }
    return {attributes: a, children: kids};
  };
  const root = document.querySelector('flt-semantics-host') || document.querySelector('flt-glass-pane')?.shadowRoot?.querySelector('flt-semantics-host');
  if (!root) return {attributes:{bounds:'[0,0][0,0]', text:'NO SEMANTICS HOST'}, children:[]};
  const top = [...root.querySelectorAll(':scope > flt-semantics, :scope > flt-semantics-container')];
  return {attributes:{bounds:`[0,0][${window.innerWidth},${window.innerHeight}]`}, children: top.map(walk)};
}
"""

def flatten(node, out):
    a = node["attributes"]; out.append(a)
    for c in node["children"]: flatten(c, out)
    return out

def semantics(page):
    return page.evaluate(HIER_JS)

def count_nodes(page):
    return len(flatten(semantics(page), []))

def settle(page, min_nodes=3, timeout=25):
    """Wait until the semantics node count is stable for ~700 ms."""
    t0 = time.time(); last = -1; stable_since = None
    while time.time() - t0 < timeout:
        n = count_nodes(page)
        if n == last and n >= min_nodes:
            if stable_since is None: stable_since = time.time()
            elif time.time() - stable_since > 0.7: return n
        else:
            last = n; stable_since = None
        page.wait_for_timeout(150)
    return last

def find(page, pattern, clickable_only=True):
    """Smallest semantics node whose text matches pattern. Returns (x,y,w,h,text) or None."""
    rx = re.compile(pattern)
    nodes = [a for a in flatten(semantics(page), []) if a.get("text") and rx.search(a["text"])]
    if clickable_only:
        c = [a for a in nodes if a.get("clickable") == "true"]
        nodes = c or nodes
    best = None
    for a in nodes:
        m = re.match(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]", a["bounds"]); x1, y1, x2, y2 = map(int, m.groups())
        area = max(1, (x2 - x1) * (y2 - y1))
        if (x2 - x1) <= 0 or (y2 - y1) <= 0: continue
        if best is None or area < best[0]: best = (area, x1, y1, x2 - x1, y2 - y1, a["text"])
    return best[1:] if best else None

def click(page, pattern, timeout=15):
    t0 = time.time()
    while time.time() - t0 < timeout:
        f = find(page, pattern)
        if f:
            x, y, w, h, _ = f; page.mouse.click(x + w / 2, y + h / 2); return True
        page.wait_for_timeout(250)
    raise RuntimeError(f"not found: {pattern}")

def dom_click(page, pattern):
    """Dispatch a DOM click on the semantics node itself (Flutter maps it to SemanticsAction.tap)."""
    return page.evaluate("""(pat) => { const rx = new RegExp(pat); for (const el of document.querySelectorAll('flt-semantics[role=button], flt-semantics[flt-tappable]')) { let own=''; for (const n of el.childNodes){ if(n.nodeType===3) own+=n.textContent; else if(n.nodeType===1 && !n.tagName.toLowerCase().startsWith('flt-')) own+=n.textContent; } const t=(el.getAttribute('aria-label')||own).trim(); if (rx.test(t)) { el.click(); return t; } } return null; }""", pattern)

def visible(page, pattern, timeout=15):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if find(page, pattern, clickable_only=False): return True
        page.wait_for_timeout(250)
    return False

def typein(page, label, text):
    loc = page.locator(f'input[aria-label="{label}"]').first
    if loc.count():
        loc.click(); loc.fill(""); loc.fill(text); page.wait_for_timeout(150); return
    click(page, f"^{label}$"); page.wait_for_timeout(200)  # Flutter text field whose label is a sibling semantics node
    page.keyboard.type(text, delay=10); page.wait_for_timeout(150)

def capture(page, name, mode, how, note=""):
    settle(page)
    page.screenshot(path=str(RUN / "screens" / f"{name}.png"))
    (RUN / "hierarchy" / f"{name}.json").write_text(json.dumps(semantics(page)))
    inventory.append((name, mode, how, note)); print("  captured", name, flush=True)

def goto(page, route, name, mode, note="", wait=None):
    page.goto(f"{BASE}/#{route}"); page.wait_for_timeout(400)
    if wait: visible(page, wait)
    capture(page, name, mode, f"openLink #{route}", note)

# --- session helpers ---------------------------------------------------------
def login(page):
    page.goto(f"{BASE}/#/login"); visible(page, "^Email$", 60)
    typein(page, "Email", EMAIL); typein(page, "Password", PASSWORD)
    click(page, "^Sign in$")
    assert visible(page, "How do you want to continue", 40), "login failed"

def choose(page, mode):
    page.evaluate("() => sessionStorage.removeItem('view_mode')")
    page.goto(f"{BASE}/#/app/mode"); page.wait_for_timeout(300)
    if not visible(page, "How do you want to continue", 20): page.reload(); visible(page, "How do you want to continue", 30)
    click(page, "As a researcher|Continue as researcher" if mode == "researcher" else "As an administrator|Continue as admin")
    page.wait_for_timeout(800); settle(page)

# --- crawl -------------------------------------------------------------------
with sync_playwright() as p:
    browser = p.chromium.launch()
    ctx = browser.new_context(viewport=DESKTOP, device_scale_factor=1); page = ctx.new_page()
    page.set_default_timeout(30000)

    # cold start: loading state
    page.goto(f"{BASE}/#/login"); page.wait_for_timeout(250)
    page.screenshot(path=str(RUN / "screens" / "state_loading_cold.png")); (RUN / "hierarchy" / "state_loading_cold.json").write_text(json.dumps(semantics(page)))
    inventory.append(("state_loading_cold", "anon", "cold load, screenshot at +250 ms", "ST-LOAD evidence"))
    visible(page, "^Email$", 60)
    capture(page, "login", "anon", "openLink #/login")
    for slug in ["start", "affiliation", "fct", "report", "signature", "social", "logos", "contacts"]:
        goto(page, f"/app/welcome/{slug}", f"anon_welcome_{slug}", "anon")
    goto(page, "/people", "anon_deeplink_people", "anon", "expected: bounced to /login")
    goto(page, "/app/welcome/docs", "anon_welcome_docs_m2", "anon", "M2 slug: expected redirect to start")
    # login error state: wrong password
    page.goto(f"{BASE}/#/login"); visible(page, "^Email$", 30)
    typein(page, "Email", EMAIL); typein(page, "Password", "wrong-password-123!"); click(page, "^Sign in$"); page.wait_for_timeout(2500)
    capture(page, "state_login_error", "anon", "login with wrong password", "ST-ERROR evidence")

    # --- researcher mode
    login(page); capture(page, "mode_chooser", "signed-in", "after Sign in")
    click(page, "As a researcher|Continue as researcher"); page.wait_for_timeout(800)
    capture(page, "r_landing_after_choose", "researcher", "chooser → As a researcher")
    R = [("/app/home", "r_home"), ("/app/home/summary", "r_home_summary"), ("/app/home/recent", "r_home_recent"),
         ("/app/home/alerts", "r_home_alerts"), ("/app/home/status", "r_home_status"),
         ("/app/profile", "r_profile"), ("/app/profile/identifiers", "r_profile_identifiers"), ("/app/profile/bio", "r_profile_bio"),
         ("/app/profile/areas", "r_profile_areas_wip"), ("/app/profile/interests", "r_profile_interests_wip"), ("/app/profile/status", "r_profile_status"),
         ("/app/outputs", "r_outputs"), ("/app/outputs/add", "r_outputs_add"), ("/app/outputs/edit", "r_outputs_edit_wip"),
         ("/app/outputs/import", "r_outputs_import"), ("/app/outputs/validation", "r_outputs_validation_wip"),
         ("/app/welcome/start", "r_welcome_start"), ("/app/welcome/affiliation", "r_welcome_affiliation"), ("/app/welcome/fct", "r_welcome_fct"),
         ("/app/welcome/report", "r_welcome_report"), ("/app/welcome/signature", "r_welcome_signature"), ("/app/welcome/social", "r_welcome_social"),
         ("/app/welcome/logos", "r_welcome_logos"), ("/app/welcome/contacts", "r_welcome_contacts"),
         ("/app/help/links", "r_help_links"), ("/app/help/docs", "r_help_docs_wip"), ("/app/help/faq", "r_help_faq_wip"),
         ("/app/settings", "r_settings"), ("/people", "r_deeplink_people", "expected: bounced to /app/home"),
         ("/app/requests", "r_deeplink_requests_v2", "v2 route: expected bounce"), ("/nope/404", "r_unknown_route", "unknown route")]
    for row in R:
        goto(page, row[0], row[1], "researcher", row[2] if len(row) > 2 else "")
    # Edit profile dialog
    page.goto(f"{BASE}/#/app/profile"); visible(page, "^Edit$", 20); click(page, "^Edit$"); page.wait_for_timeout(600)
    capture(page, "r_profile_edit_dialog", "researcher", "/app/profile → Edit")
    page.keyboard.press("Escape"); page.wait_for_timeout(400)
    # Add output dialog
    page.goto(f"{BASE}/#/app/outputs/add"); visible(page, "Add output", 20); click(page, "^Add output$"); page.wait_for_timeout(700)
    capture(page, "r_add_output_dialog", "researcher", "/app/outputs/add → Add output")
    page.keyboard.press("Escape"); page.wait_for_timeout(400)
    # sidebar collapse
    page.goto(f"{BASE}/#/app/home"); settle(page)
    f = find(page, "^Overview$", clickable_only=False)
    page.screenshot(path=str(RUN / "screens" / "r_sidebar_expanded.png")); inventory.append(("r_sidebar_expanded", "researcher", "/app/home default sidebar", ""))
    # account controls live in the sidebar footer (F-018): capture, never click —
    # "Switch to admin" is a real button now that the sidebar has semantics.
    capture(page, "r_account_menu", "researcher", "sidebar footer: Switch to admin / Public site / Sign out (not clicked)")
    # phone width
    page.set_viewport_size(PHONE)
    for route, name in [("/app/home", "phone_r_home"), ("/app/profile", "phone_r_profile"), ("/app/outputs", "phone_r_outputs")]:
        goto(page, route, name, "researcher (390px)")
    try:
        click(page, "^Menu$|Open navigation menu|navigation", timeout=6); page.wait_for_timeout(500)
        capture(page, "phone_r_drawer", "researcher (390px)", "hamburger → drawer"); page.keyboard.press("Escape")
    except Exception as e:
        print("  drawer not found:", e)
    page.set_viewport_size(DESKTOP)

    # --- admin mode
    choose(page, "admin"); capture(page, "a_landing_after_choose", "admin", "chooser → As an administrator")
    A = [("/app/dashboard", "a_dashboard"), ("/people", "a_people"), (f"/people/{IDS['person']}", "a_person"),
         (f"/people/{IDS['e2e_person']}", "a_person_e2e_self"), ("/outputs", "a_outputs"), (f"/outputs/{IDS['output']}", "a_output"),
         ("/projects", "a_projects"), (f"/projects/{IDS['project']}", "a_project"), ("/conferences", "a_conferences"),
         ("/structure", "a_structure"), (f"/labs/{IDS['lab']}", "a_lab"), (f"/clusters/{IDS['cluster']}", "a_cluster"),
         (f"/objectives/{IDS['objective']}", "a_objective"), ("/app/admin/review", "a_admin_review"), ("/app/admin/merge", "a_admin_merge"),
         ("/app/admin/reports", "a_admin_reports"), ("/app/admin/data", "a_admin_data"), ("/app/settings", "a_settings"),
         ("/app/admin/requests", "a_admin_requests_v2", "v2 route: expected redirect"), ("/app/profile", "a_deeplink_profile", "researcher route in admin mode")]
    for row in A:
        goto(page, row[0], row[1], "admin", row[2] if len(row) > 2 else "")
    # empty state: people search with nonsense
    page.goto(f"{BASE}/#/people"); settle(page)
    try:
        click(page, "^Search|Search people|Search", timeout=8); page.keyboard.type("zzqxv-nomatch", delay=20); page.wait_for_timeout(1500)
        capture(page, "state_empty_people_search", "admin", "/people → search 'zzqxv-nomatch'", "ST-EMPTY evidence")
    except Exception as e:
        print("  search not found:", e)
    # destructive confirm: Approve all pending (needs a pending output) – try
    page.goto(f"{BASE}/#/app/admin/review"); settle(page)
    try:
        click(page, "^Approve all", timeout=5); page.wait_for_timeout(600)
        capture(page, "a_confirm_approve_all", "admin", "review → Approve all pending", "destructive confirm"); click(page, "^Cancel$")
    except Exception as e:
        print("  approve-all not available:", e)
    # phone admin
    page.set_viewport_size(PHONE)
    for route, name in [("/app/dashboard", "phone_a_dashboard"), ("/people", "phone_a_people"), (f"/people/{IDS['person']}", "phone_a_person"), ("/app/admin/review", "phone_a_review")]:
        goto(page, route, name, "admin (390px)")
    page.set_viewport_size(DESKTOP)

    # --- error state: backend unreachable
    page.route("**/*.supabase.co/**", lambda r: r.abort())
    page.goto(f"{BASE}/#/people"); page.wait_for_timeout(3000)
    capture(page, "state_error_backend_down", "admin", "/people with supabase blocked", "ST-ERROR evidence")
    page.goto(f"{BASE}/#/app/dashboard"); page.wait_for_timeout(3000)
    capture(page, "state_error_dashboard_down", "admin", "/app/dashboard with supabase blocked", "ST-ERROR evidence")
    page.unroute("**/*.supabase.co/**")
    browser.close()

with open(RUN / "screens.md", "w") as f:
    f.write("# Screen inventory\n\nCrawler: Playwright/Chromium 1280×900 (phone rows 390×844). Build: `flutter build web --dart-define=E2E=true` (v1), commit 7d628bb, served from build/web on :8123.\n\n| Screen | Mode | How reached | Files | Note |\n|---|---|---|---|---|\n")
    for n, m, h, note in inventory:
        f.write(f"| {n} | {m} | {h} | screens/{n}.png · hierarchy/{n}.json | {note} |\n")
    f.write("\n## NOT COVERED\n\n- ORCID OAuth sign-in (third-party login; not automatable safely).\n- v2-only surfaces (Support requests, Approve/Auto-fill/ORCID sync buttons) — compiled out of the pilot build.\n- Research Areas / Interests / Edit outputs / Validation / Documentation / FAQs render the shared WipPage.\n")
print("screens:", len(inventory))
