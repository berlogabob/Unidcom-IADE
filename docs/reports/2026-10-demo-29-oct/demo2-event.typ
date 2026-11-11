#import "lib.typ": *
#let meta = (title: "Demo 2: event", footer: "UNIDCOM RIMS · demo 29 Oct 2026")
#show: report.with(meta)
#title-block("Demo 2: event", subtitle: "Create in RIMS, publish, see it on the website", standfirst: "Proof of the mechanism. Events are phase 3 and outside the v1.0 pilot, so this is not a commitment.", meta-line: "Meeting Thu 29 Oct 2026, 14:00 · Hande, Sabino")


= Status
#scorecard((
  ("Event appears on the website mirror", "Verified", "ok", "Created a published test event; it showed on the events page with type, date and description; removed on un-publish."),
  ("Event in Sanity", "Partly", "warn", "Reaches Sanity only through the full push, not from a single event button."),
  ("Commitment", "Not v1.0", "info", "Events are phase 3; show as proof of mechanism only."),
))

= Steps
#data-table(("#", "Do", "You should see"), (
  ("1", "Website in the sidebar, Events tab, Add event.", "Event form."),
  ("2", "Title, start date, type, location, about. Save.", "Event in the list."),
  ("3", "Switch Published on.", "Switch on."),
  ("4", "Start the site sync (GitHub Actions, Run workflow).", "Run completes in about 3 min."),
  ("5", "Open the website events page.", "Event under Upcoming, with date, type and text."),
), widths: (1cm, 9cm, 1fr), right-from: none)

= After the demo
#callout([Switch Published off and delete the event; the next sync removes it from the website. Only files named rims-\* on the website are managed by the sync, so hand-written events are never touched.], title: "Clean up", tone: "neutral")
