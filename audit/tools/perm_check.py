# E1.5: reproduce "permission denied for table people" — log every failed REST call
# with its role (anon key vs user JWT) and every console error, across login,
# mode choice, the 5 researcher pages and a hard reload (session-restore race).
import sys, json, base64
sys.argv = [sys.argv[0], "/tmp/claude-501/perm-run"]
src = open("audit/tools/crawl.py").read().split("# --- crawl")[0]
exec(src)
hits = []
def role(req):
    a = req.headers.get("authorization", "")
    try: return json.loads(base64.urlsafe_b64decode(a.split(".")[1] + "==")).get("role")
    except Exception: return "none"
def on_resp(r):
    if "/rest/v1/" in r.url and r.status >= 400:
        try: body = r.text()[:160]
        except Exception: body = ""
        hits.append(f"HTTP {r.status} {role(r.request)} {r.request.method} {r.url.split('/rest/v1/')[1][:90]} {body}")
with sync_playwright() as p:
    b = p.chromium.launch(); page = b.new_page(viewport=DESKTOP)
    page.on("console", lambda m: m.type == "error" and hits.append("CONSOLE " + m.text[:200]))
    page.on("response", on_resp)
    page.goto(f"{BASE}/#/login"); visible(page, "^Email$", 60)
    typein(page, "Email", EMAIL); page.keyboard.press("Tab"); page.keyboard.type(PASSWORD, delay=15); click(page, "^Sign in$")
    page.wait_for_timeout(12000); hits.append("-- after sign-in: " + page.url.split("#")[-1]); page.screenshot(path="/tmp/claude-501/after_signin.png")
    if visible(page, "How do you want to continue", 3): choose(page, "researcher")
    for r in ["/app/home", "/app/profile", "/app/outputs", "/app/welcome/resources", "/app/welcome/contacts"]:
        page.goto(f"{BASE}/#{r}"); page.wait_for_timeout(2500); hits.append(f"-- visited {r}")
    page.reload(); page.wait_for_timeout(4000); hits.append("-- hard reload")
    b.close()
print("\n".join(hits))
