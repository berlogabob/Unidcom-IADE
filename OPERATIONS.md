# Operations

What a successor needs that isn't in the code. Written 2026-08-07 because
grepping both repositories for `backup|rotate|incident|recovery|escalate`
returned essentially nothing: the build and architecture documentation was
good, and none of this existed.

**Read the honest bits first.** Several sections below describe a gap rather
than a procedure. That is deliberate — a runbook that pretends is worse than
one that admits.

---

## 1. Bus factor

One person built and runs this. That is the largest single risk to the pilot,
larger than any bug in this repository, and it is not a technical problem.

**Every critical account needs a second human on it.** Today, if the maintainer
is unavailable, nobody can deploy, restore, rotate a key, or fix the researcher
sign-in that 184 people depend on.

| Account | What it controls | Who has it | Second holder |
|---|---|---|---|
| Supabase org | the database, all personal data, edge functions | | **needed** |
| GitHub org / repos | both codebases, Pages hosting, all CI secrets | | **needed** |
| ORCID developer app | **all researcher sign-in** — lose it and nobody logs in | | **needed** |
| DNS for unidcom-iade.pt | the public site at cutover | | **needed** |
| FTP for pixelframe2027 | the conference site | | **needed** |

Fill in the holders and add the seconds. This table is the point of the file.

---

## 2. Secrets register

| Secret | Where it lives | Used by | Rotate |
|---|---|---|---|
| `SUPABASE_SERVICE_KEY` | GitHub Actions secrets, **both repos**; local `scripts/.env` | nightly sync, `orcid-sync.yml`, `doi-check.yml`, all `scripts/*.py` | |
| `SUPABASE_URL` | GitHub Actions secrets, both repos | same | n/a |
| ORCID client id + secret | Supabase Vault, read by `orcid_credentials()` (service-role only); overridable via `supabase secrets set` | the `orcid-auth` edge function | |
| `FTP_USER` / `FTP_PASS` | nowhere — typed by hand at deploy time | `scripts/deploy_pixelframes.sh` | |
| `MAESTRO_EMAIL` / `MAESTRO_PASSWORD` | local `.maestro/.env`, gitignored | E2E flows | |
| Figma PAT | a session transcript — **rotate this** | one-off design reads | **overdue** |

The publishable/anon key and the ORCID **client id** in `lib/main.dart` are
public by design. They are not secrets and do not need rotating.

Nothing sensitive is committed in either repository — verified across history.
Keep it that way: `scripts/.env`, `.maestro/.env` and `RAW_DATA/` are
gitignored, and `.env.example` files carry the shape without the values.

**No rotation has a date against it.** Set one — annually, and immediately on
anyone leaving.

---

## 3. Backup and restore — **this is the weakest area, read it carefully**

### What exists

`scripts/export.py` writes JSON to `scripts/out/`; `scripts/restore.py` reads
it back. `PLAN.md` describes running the export weekly, by hand, on a laptop.

Not uploading exports as CI artifacts is a **correct** decision — the repo is
public and `people` carries emails. Do not "fix" it that way.

### What is wrong with it

1. **The backup covers 9 of 27 tables.** `TABLES` in `export.py` has not been
   updated across eleven table-adding migrations. Not backed up: `person_roles`
   (the whole two-layer role model), `clusters`, `labs`, `objectives` and all
   their join tables, `collaborations`, `change_log` (the audit trail),
   `support_requests`, `output_candidates`, `quality_waivers`,
   `output_taxonomy`.
2. **`restore.py --wipe` destroys more than it can restore.** It deletes in
   reverse order ending at `people` and `outputs`, which cascade to
   `lab_members`, `person_roles`, `support_requests`, `output_candidates` and
   `quality_waivers` — none of which are in the backup. Run on a live database
   it is a second disaster, not a recovery.
3. **Nothing schedules it**, so the real RPO is "whenever someone last
   remembered".
4. **A restore has never been performed.** RTO is therefore unknown.

### What to do about it

Replace both scripts with a nightly `pg_dump` to encrypted object storage
outside the public repo, keep 30 dailies, and add a weekly job that restores the
newest dump into a Supabase preview branch and asserts row counts. Until that
exists, treat the current backup as partial and say so out loud.

Also confirm the Supabase plan's PITR: on the free tier there is none, so a
`drop table` or a bad `--wipe` is **permanent loss of 184 researchers'
records**.

---

## 4. Incidents

### How you find out

Honestly: a researcher emails someone. There is no uptime check and no alerting.
`lib/data/failure.dart` now routes unexpected errors through a single
`reportError` seam that writes structured console output — point it at a hosted
reporter and add an uptime check on both surfaces, and this section becomes
real.

The one automatic signal today is GitHub emailing the repo owner when a
scheduled workflow fails. That covers the batch jobs, not the live app, and it
reaches one inbox.

### Rolling back

| Broken thing | Rollback |
|---|---|
| Portal (Flutter) | revert the commit, push to `main`. The deploy gates on `flutter analyze` + `flutter test`, so the revert must be green. `concurrency: cancel-in-progress` means a second push cancels the first — do not push twice in a panic. |
| Public site (Hugo) | same, but content lives in `data/generated/`, so `git revert` of a sync commit restores the previous content exactly. |
| Edge function | redeploy the previous version. `orcid-auth` is at v5; v4 is the pre-nonce build. |
| Migration | there are **no down migrations**. Write the inverse by hand against a preview branch first. |

### Sync went wrong

The nightly sync refuses to write if any entity count drops more than 20%
(`check_no_collapse` in `scripts/sync.py`). If it fails that way, do not pass
`--allow-collapse` until you know why the count moved.

---

## 5. Supporting researchers

### The call you will get first: "I can't sign in"

Sign-in is gated on the ORCID iD being **already recorded** against the person's
UNIDCOM profile. If it is not, the broker refuses with:

> No UNIDCOM profile is registered for ORCID iD … Contact an admin.

**26 of 183 published profiles have an iD; 157 do not.** So this is the expected
case, not the exception.

Fix: an admin adds the iD to the person's profile in the portal — the People
list has a "Missing ORCID" filter — then the researcher signs in again.

### Other likely calls

| Symptom | Cause | Fix |
|---|---|---|
| "This profile is already linked to an account" | someone claimed the profile with a password account and never linked ORCID | sign in with the password, then **Connect ORCID** on the profile |
| "That sign-in link did not come from this browser" | the anti-CSRF nonce did not match — usually a stale tab or a link that came from somewhere else | start again from the Sign in page. If it repeats, treat it as suspicious and say so |
| "My profile isn't on the website" | not approved, or approved after the last sync | check `profile_status` + `public_visibility`; the site rebuilds nightly at 04:00 UTC |
| "My role is wrong on the website" | roles publish only once approved | approve it in the portal; appears next sync |
| Report generation fails first time | the Typst function cold-starts (~28 MB wasm) and can hit a resource limit | retry; warm it before any demonstration |

### Support requests have no notification

A researcher files one and it sits in the table until an admin opens
`/app/admin/requests`. There is no email, no acknowledgement, no timer. Either
add a trigger or make someone responsible for checking daily — and tell
researchers which it is.

---

## 6. Routine

| When | What |
|---|---|
| Nightly 04:00 UTC | site sync (`unidcom-site`), auto-commits and deploys |
| Mondays 05:00 UTC | ORCID works staged into `output_candidates` |
| Mondays 06:00 UTC | DOI liveness check |
| Weekly, manual | database export — **see §3, it is partial** |
| Before any demo | warm the report function; re-check the numbers in `DEMO.md` |
| Annually / on departure | rotate every secret in §2 |

---

## 7. Data protection

The engineering is careful — approval-gated visibility, a field allowlist on the
sync, an audit trail. The paperwork does not exist, and for an EU public
institution holding 184 researchers' names, emails, ORCID identities and
photographs, that is the gap that matters.

Missing, all of it: a privacy notice, a record of lawful basis, a retention
policy, a subject-access procedure, a processor register (Supabase, GitHub,
ORCID, Google Fonts), and a breach-notification plan.

There is also **no erasure path in code**: `deletePerson` does not exist, and
`merge_people` keeps the row as a tombstone. A researcher who leaves and asks to
be removed cannot currently be. `exit_date` exists and nothing acts on it.

This needs a decision from UNIDCOM, not a commit from an engineer — but it
should be made before the cohort is onboarded, not after.
