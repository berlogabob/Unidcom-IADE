// UNIDCOM RIMS — briefing kit: how to make quick layout edits with colleagues
// and carry them into Flutter. Decision record, 9 September 2026. Build: ./build.sh
#import "lib.typ": *

#show: report.with((
  title: "UNIDCOM RIMS — Briefing Kit",
  author: ("UNIDCOM/IADE",),
  footer: "UNIDCOM RIMS · briefing kit · 9 September 2026",
  lang: "en",
))

#title-block(
  "Briefing kit — quick layout edits, then Flutter",
  subtitle: "Menus, block placement and alignment during a briefing, transferred to the portal afterwards",
  meta-line: [Setting: in person or screen-share, you drive, colleagues watch · Decided 9 September 2026],
  standfirst: [Two speeds. *Menus* are edited live in the running Flutter app — a 3–5 s hot reload, nothing to transfer. *Block placement* is done by dragging on a design canvas rebuilt from the portal's own tokens, saved as a shared link, and carried into Flutter by a scripted task with the audit crawl as the check. Figma stays the token source only.],
)

#kpi-row((
  ("3–5 s", "Menu change round trip", "edit nav_model.dart, hot reload"),
  ("5", "Canvas artboards", "Overview · Profile · My Outputs · Dashboard · Review queue"),
  ("< 20 min", "Canvas → Flutter loop", "extract, Codex task, crawl check"),
  ("0", "New tools for colleagues", "they watch a screen or open a link"),
))

= Why not Figma or plain HTML

#data-table(
  ("Option", "Verdict", "Reason"),
  (
    ([Figma (Carmela's `UNIDCOM.fig`)], [#pill("tokens only", tone: "neutral")], [Colleagues do not use it; Figma → Flutter is manual; the file already gave us the tokens in `lib/theme/tokens.dart`.]),
    ([Plain HTML in a browser + devtools], [#pill("no", tone: "bad")], [Edits vanish on reload, nothing to hand to the next step, no shared link.]),
    ([Flutter hot reload], [#pill("menus", tone: "ok")], [The IA is already data (`nav_model.dart`); no transfer step at all.]),
    ([Claude Design canvas (Artifact)], [#pill("layout", tone: "ok")], [Drag, resize, retype, Save; link opens without an account; PNG/PDF export; working files live in the repo.]),
  ),
  widths: (4.6cm, 2.4cm, 1fr), right-from: 99,
)

= Path 1 — menus and IA, live in the app

#data-table(
  ("Step", "What", "Where"),
  (
    ([1], [Run the portal locally], [`flutter run -d chrome --web-port 8080` · `r` reload, `R` restart]),
    ([2], [Add, move, rename, regroup rows], [`lib/widgets/nav_model.dart` — groups → rows → routes]),
    ([3], [Section landing pages and placeholder leaves], [`lib/app/portal_pages.dart` (`WipPage`)]),
    ([4], [Show or hide a feature for the pilot], [`lib/data/features.dart` (v1 / v2 flag)]),
    ([5], [Before committing], [`flutter test test/nav_model_test.dart` — fails if a row points at a route that does not exist]),
  ),
  widths: (1.1cm, 5.6cm, 1fr), right-from: 99,
)

Rule: a row needs a route; a new route needs a builder in `lib/main.dart`.

= Path 2 — block placement and alignment, on the canvas

#data-table(
  ("Step", "What", "Notes"),
  (
    ([Build once], [Five artboards at 1280 × 900, pixel-exact from the Flutter tokens and Carmela's HTML exports; sidebar as one shared component], [`design/canvas/*.dc.html` in the repo, sample data only]),
    ([In the briefing], [Drag cards, change widths, reorder rows, retype labels; *Save* when agreed], [Saved versions are kept and attributed; PNG export for the minutes]),
    ([Afterwards], [Extract the saved artboards, diff against the repo copy], [The diff is the change list]),
    ([Transfer], [One Codex task per screen: "make `lib/app/<file>.dart` match `<Screen>.dc.html`: …", with a widget test], [Same pattern as the round-5 fixes]),
    ([Check], [Rebuild, crawl the touched screens, compare screenshot with the artboard export], [`audit/tools/crawl.py`]),
    ([Close], [Commit the extracted artboards back to `design/canvas/`], [Canvas and app stay in step]),
  ),
  widths: (2.2cm, 1fr, 5cm), right-from: 99,
)

= Limits to know

- One editor at a time saves cleanly; two saving at once means the second reloads and re-applies. Fine for a driven briefing.
- The canvas is a mockup: it does not run the app's data. Anything that depends on real rows is checked in the transfer step, not on the canvas.
- Menu changes made on the canvas still go into `nav_model.dart` by hand — that path is faster than any transfer.

= Dry run before the first real briefing

Move the Overview *Alerts* card under *Quick links*, rename *Recent papers* to *Recent outputs*, Save → extract → Codex task for `lib/app/researcher_home.dart` → crawl `r_home` → screenshot matches the artboard → commit. Target: under 20 minutes end to end.

#v(4pt)
#text(size: 8.5pt, fill: muted)[Prerequisites verified 9 September: Node 24 on the audit machine; the artifact roster allows Save and PNG/PDF export. Deliverables of the build step: `docs/briefing-kit.md` (runbook), `design/canvas/` (artboards + README), the published canvas link.]
