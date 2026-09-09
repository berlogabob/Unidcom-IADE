// UNIDCOM RIMS — Sanity bridge: how to review and link the Sanity archive.
// Numbers from the live view sanity_member_matches on 9 September 2026. Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — Sanity bridge how-to",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · Sanity bridge how-to · 9 September 2026",
  lang: "en",
))

#title-block(
  "Sanity bridge — how to test the bulk link",
  subtitle: "Admin tool at People → Sanity merge. Branch feat/sanity-bridge, commits f088341 and cb119fb.",
  meta-line: [Sanity project `vj0axykv` is read only · Supabase is the master · every change is logged and reversible],
  standfirst: [The tool links our people to the agency's Sanity members and files what Sanity knows and we lack as *suggestions*. No person field is ever written automatically. Nothing is written to Sanity.],
)

#kpi-row((
  ("159", "Matches in queue", "130 email · 13 ORCID · 16 name"),
  ("143", "Safe to link in one click", "ORCID or email, no conflict"),
  ("126", "Suggestions it will file", "legal name 86 · ORCID 23 · bio 8 · photo 8 · Ciência 1"),
  ("0", "Person fields changed", "only the link and the log"),
))

= 1. Run the app as admin

The branch is not deployed. Run it locally against the live database and sign in with an admin account.

#data-table(
  ("Step", "Command or action"),
  (
    ([Check out the branch], [`cd ~/Documents/GitHub/Unidcom-IADE && git checkout feat/sanity-bridge`]),
    ([Start the app], [`flutter run -d chrome --dart-define=SUPABASE_URL=https://nmghxkhstlnxypmfmfhk.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>`]),
    ([Sign in], [Admin account (role `admin` in app metadata). Researcher accounts see "Admin access required".]),
    ([Open the tool], [Sidebar → People → *Sanity merge*, or `/app/admin/sanity`.]),
  ),
  widths: (3.4cm, 1fr), right-from: 99,
)

= 2. The three tabs

#data-table(
  ("Tab", "What it shows", "Actions"),
  (
    ([Matches], [Sanity members paired with a Supabase person by ORCID, email or name tokens; conflict count and "AMBIGUOUS" when two people tie.], [*Link N safe matches* (bulk) · *Review & link* (per person, field matrix) · filter *Status mismatch*]),
    ([Sanity only], [Members with no Supabase counterpart; filter listed / unlisted on the site.], [*Import* as draft person · *Ignore* · *Link…* to a person the matcher missed]),
    ([Supabase only], [Our people with no Sanity document.], [none — read only]),
  ),
  widths: (2.4cm, 1fr, 5.6cm), right-from: 99,
)

= 3. Test the bulk link

#data-table(
  ("#", "Do", "Expect"),
  (
    ([1], [Matches tab. Read the button label.], [*Link 143 safe matches*. The 16 name-token matches are not counted and stay listed.]),
    ([2], [Press it. Read the dialog.], [Text: "Sets the Sanity link on 143 people. No person field is changed; ORCID, bio, photo and name-form values from Sanity go to Suggestions for review."]),
    ([3], [Confirm.], [Snackbar *Linked 143 · 126 suggestions filed · 16 skipped*. The list shrinks to 16 rows.]),
    ([4], [Open a linked person's page (admin view).], [Values unchanged. Chip *from sanity* next to the Sanity link. Suggestions section lists the Sanity proposals with accept / reject. New panel *Sanity archive*: legacy projects and output count.]),
    ([5], [Accept one suggestion, e.g. ORCID.], [Field fills, chip on that field reads *from sanity*, one `change_log` row with source `sanity`.]),
    ([6], [Toggle *Status mismatch* on the Matches tab.], [Only the 16 remaining rows that are listed on the site but not active here, or the reverse. No action changes status.]),
  ),
  widths: (0.8cm, 5.2cm, 1fr), right-from: 99,
)

= 4. Verify in SQL

Supabase dashboard → SQL editor, or the MCP `execute_sql` tool.

#data-table(
  ("Query", "Expected"),
  (
    ([`select count(*) from people where sanity_id is not null;`], [143]),
    ([`select field, count(*) from enrichment_suggestions where source = 'sanity' group by 1;`], [legal_name 86 · orcid 23 · bio 8 · photo_url 8 · ciencia_id 1]),
    ([`select count(*) from sanity_member_matches;`], [16]),
    ([`select count(*) from change_log where source = 'sanity';`], [143 + one per accepted suggestion]),
    ([`select md5(string_agg(coalesce(orcid,'')||coalesce(bio,'')||coalesce(photo_url,''), '|' order by id)) from people;`], [same value before and after the bulk run (until you accept a suggestion)]),
  ),
  widths: (1fr, 5.4cm), right-from: 99,
)

= 5. Undo

The bulk run wrote only the link, the decision flag, log rows and pending suggestions. Three statements reverse it:

#data-table(
  ("Statement",),
  (
    ([`update people set sanity_id = null where id in (select subject_id from change_log where source = 'sanity' and field = 'sanity_id');`],),
    ([`update sanity_docs set decision = null, decided_at = null, decided_by = null where decision = 'linked';`],),
    ([`delete from enrichment_suggestions where source = 'sanity' and status = 'pending';`],),
  ),
  widths: (1fr,), right-from: 99,
)

= 6. What is deliberately not done

#scorecard((
  ("Write to the official Sanity project", "Not started", "neutral", "needs the agency's schema and token"),
  ("Push to testUNIDCOM (ld5jhf23)", "Pending (blocked on agency answers 2 and 5)", "warn", "script and workflow are specified, not built"),
  ("Import 43 legacy projects / 1 596 outputs", "Not planned", "neutral", "shown read-only on the person page instead"),
  ("Overwrite any person field from Sanity", "Never", "ok", "suggestions only; accept per field"),
))
