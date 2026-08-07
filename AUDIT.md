# Audit — 2026-08-07

A three-track review of both repositories: engineering practice, security and
data handling, and product/operational maturity. Findings were verified by hand
against the live system before being recorded; two agent-reported findings did
not survive that check and are listed as such.

**Verdict.** A well-architected, unusually well-documented system that was
carrying a live personal-data exposure, had no way to know when it broke, no
rehearsed recovery, and one person who knows how it runs. The engineering
judgement on display is well above what the gaps suggest — which means the gaps
were unprioritised, not misunderstood.

Everything under "Fixed" below was closed on 2026-08-06/07 and verified.

---

## Fixed

### 1. 153 researcher emails were readable by anyone — CRITICAL

`people_read` gates **rows**. RLS has no column dimension: a policy says which
rows come back, never which columns. The 2026-08-05 bulk approval made every row
readable, so every column was too. Confirmed live with the publishable key that
ships in the public JS bundle:

```
GET /rest/v1/people?select=email&email=not.is.null  ->  153 rows
GET /rest/v1/people?select=*&limit=1                ->  email, legal_name,
                                                        notes, auth_user_id,
                                                        join_date, exit_date
```

`ARCHITECTURE.md` had claimed `sync.py`'s field allowlist covered this. It
covers the static site only; it was guarding one door while another stood open.

Checking the class rather than the instance found more: `projects` exposed
`total_budget`, `risk` and `notes` — exactly the fields the allowlist withholds
— and `anon` held INSERT/UPDATE/DELETE/**TRUNCATE** on all 27 tables, with RLS
the only thing in the way. TRUNCATE is not subject to RLS at all.

Fixed in `20260806150000` / `20260806150100`: `anon` now has nothing, and
default privileges are revoked so the next table created cannot reintroduce it.
Consequence: `sync.py` genuinely requires the service key. It only appeared to
work with the publishable key because of this hole.

### 2. ORCID login-CSRF — HIGH

Sign-in `state` was a bare return URL: unsigned, no nonce, nothing binding a
callback to the browser that began it. An attacker could complete their **own**
ORCID authorization, capture the code, and hand a victim a link that silently
signed the victim's browser in **as the attacker** — after which the victim's
profile edits and support requests went into the attacker's account.

Fixed with a browser-bound nonce (`signin|<nonce>|<returnTo>`, echoed back,
checked in the app). Also in that pass: `localhost` was an allowlisted return
target **on the production broker** while the success redirect carries a
magic-link token — verified 302 before, 400 after; signature comparison was not
constant-time; the ORCID iD went into a PostgREST filter unescaped; a
non-numeric expiry was coerced rather than rejected.

The broker had **no tests at all** despite being unauthenticated and holding the
service-role key. It now has 14.

### 3. Unapproved roles reached the public site — MEDIUM

`protect_person_roles` forces a self-entered role to `pending` so an admin sees
it first, but `sync.py` used the service key (bypassing RLS) and never read the
column. Someone could have put "Director of UNIDCOM" on the institutional
website overnight. The only place the approval workflow was bypassed.

Latent, not active: all 215 rows were approved, so nothing wrong was published.

### 4. Every failure showed a raw exception — HIGH

`AsyncView`, behind all 19 data screens, rendered `error.toString()` with no way
back. Users saw `Exception: JWT expired` or `Failed host lookup:
nmghxkhstlnxypmfmfhk.supabase.co`. Now classified into actionable messages with
a working retry, a Sign in button where retrying cannot help, and no internals
in any user-facing string (asserted by test).

### 5. No observability at all — CRITICAL

Nothing logged, reported or alerted, in either system. `FlutterError.onError`,
`runZonedGuarded` and a `reportError` seam are in place; a hosted reporter is
one function body away. `Supabase.initialize` ran unguarded, so a bad key at
boot gave a permanently blank page. There were no timeouts anywhere; one
`TimeoutClient` now covers every call.

A count-collapse guard was added to the nightly sync, which commits and deploys
with no human in the loop.

### 6. Builds were not reproducible — CRITICAL

`.gitignore` carried a bare `*.lock`, so `pubspec.lock`, `scripts/uv.lock` and
`deno.lock` had **never** been committed. CI resolved fresh against caret ranges
every run; a malicious patch release in any transitive dependency reached
production with no diff and no review. Lockfiles committed, Python deps pinned.

### 7. Nothing ran before `main` — HIGH

Every workflow was `push: main` or `schedule`. `ci.yml` now runs on pull
requests: Flutter analyze/test, Deno check plus both function suites (which
existed and ran only when a human remembered), and a frozen `uv sync` plus
compile check of the Python that runs on cron with the service key.

### 8. Palette failed WCAG AA — HIGH

`textMuted` 3.64:1 (bound to 12px body text in 53 places), `textFaint` 2.10:1,
brand `teal` 2.62:1 while carrying the active tab underline and the spinner.
Greys darkened; **brand teal left exactly as designed** — load-bearing uses moved
to the existing `tealDark` (5.25:1). `lang="en"` added; the page had none.
Pinned by a test that computes real WCAG ratios.

### 9. Old researcher URLs 404'd — MEDIUM

Only four old WordPress URLs redirected. 60 people now have aliases, built by a
committed script so the one collision (the two Saras) is resolved by a written
rule rather than by hand.

### 10. FTP credentials sent in clear — MEDIUM

`ssl:verify-certificate no` with no `ssl-force`, for an account with `--delete`
rights over a live UNIDCOM domain.

---

## Did not survive verification

Recorded so nobody re-raises them.

- **`report_data()` is not an anon data leak.** It is granted to `anon` and never
  filters `approval_status`, but it is `SECURITY INVOKER`, so `outputs_read`
  applies. The misleading comment dated from the test period and was corrected.
  (It *was* an unauthenticated DoS — the unfiltered call exceeds
  `statement_timeout` — and is now revoked from `anon` anyway.)
- **The `people-photos` bucket has no present exposure.** It is public and the
  approval gate genuinely does not apply to it, but every profile is currently
  approved, so nothing hidden is reachable. Still worth fixing — see below.

---

## Open, in priority order

### Backups — the highest remaining risk

`export.py` covers **9 of 27 tables**; `restore.py --wipe` cascades away 18 it
cannot restore; nothing schedules either; a restore has never been performed.
The documented recovery procedure would make a disaster worse. See
`OPERATIONS.md` §3.

### Bus factor

One person holds every critical account, including the ORCID developer app —
lose it and all 184 researchers are locked out. `OPERATIONS.md` §1 has the table
to fill in.

### Data-protection paperwork

No privacy notice, lawful basis, retention policy, subject-access procedure or
processor register, and **no erasure path in code** — `deletePerson` does not
exist. An EU institution holding 184 researchers' personal data. Needs a
UNIDCOM decision before onboarding, not after.

### Photos bypass the approval gate

The bucket is public, so a photograph is readable regardless of
`profile_status`. The static site hot-links those URLs, so it cannot simply be
made private — the fix is to vendor photos into the Hugo repo during the sync,
which also fixes unprocessed multi-megabyte originals being hot-linked and makes
the "survives the database being down" promise true for images too.

### Test coverage

569 lines of test against 16,000 of `lib/` — and every test is a pure function
or a single widget render. `lib/data/supabase.dart` is 1,975 lines with 110
async functions and **two** symbols under test, both pure helpers. Untested:
`mergePeople`, `mergeOutputs`, `approveAllPendingOutputs`, every delete, and
`logChanges` — the audit trail, which is best-effort and silently drops
non-admin edits because `cl_write` is admin-only.

### Migrations

30 migrations, no migration CI, nothing verifies they apply cleanly to an empty
database, no down migrations, and at least one drift: `20260806090000` revokes a
function no migration creates, so the files are not a faithful description of
the live database.

### E2E runs against production

The flows write to the live database and document manual SQL cleanup. They need
seeded ephemeral data or a preview branch, and then they can go in CI.

### Environment separation

One Supabase project serves development, E2E and production.

### Internationalisation

98 of 112 biographies are Portuguese under `lang="en"` — a WCAG 3.1.2 failure,
live and indexable. The cheap half is a per-field language attribute. The real
blocker is a content policy nobody has written: do researchers write both
languages, does the unit translate, is English canonical?

### Performance

~4 MB over the wire before first paint (`main.dart.js` + CanvasKit), with no
loading shell — a blank screen for 8–15s on a poor connection. `google_fonts`
fetches Inter from Google on every load, which at an EU institution is also a
processor question. The Hugo site got this right; the portal did not.

---

## What is genuinely good

Worth recording so it is not "improved" away.

- RLS is enabled on **all 27 tables**, every `SECURITY DEFINER` function
  validates its caller and pins `search_path`, and the ORCID credentials live in
  Vault behind a service-role-only RPC.
- No secret has ever been committed to either repository.
- The Hugo site's fail-closed content-type allowlist, its field allowlist, and
  the decision to commit generated JSON so deploys need no credentials.
- Deferred work is tagged `ponytail:` with the reason and the ceiling, rather
  than left as anonymous TODOs. 36 markers, zero rotting TODOs.
- The public site's SEO: canonical URLs, Open Graph, JSON-LD `Person` with
  `sameAs` → ORCID, a sitemap that correctly excludes alias stubs.
- Commit messages and `ARCHITECTURE.md` are above professional standard.
