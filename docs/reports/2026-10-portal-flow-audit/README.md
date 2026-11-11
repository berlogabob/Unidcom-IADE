# Portal flow audit, 28 Oct 2026

Method: headless Chromium (Playwright) driving the live portal as admin (magic-link session, deleted afterwards), test person Antirobot-test only. Screenshots in `shots/`. Click counts below marked "measured" were clicked; "estimate" were counted from the code/screens, not clicked.

## Clicks from "new researcher" to online (admin)

| Step | Clicks | Basis |
|---|---|---|
| Mode chooser ("As an administrator"), on every page load | 1 | measured |
| People | 1 | measured |
| Add person (form + Save) | 2 | estimate |
| Open the person (search, click row) | 2 | measured |
| Scientific Outputs tab | 1 | measured |
| Add output wizard (type, subtype, metadata, review/submit) | 6-8 | estimate |
| Pending approval, To review: open, approve | 3-4 | estimate |
| Pending approval, Ready to publish: Publish selected, confirm | 2 (+1 to get there) | measured |
| Optional check in Sanity: person, Edit (admin), Push to test Sanity, Confirm | 4 | measured from screenshots |
| Total | about 25-30 clicks over 6 screens | |

## Findings

1. (Retracted) The chooser appearing on every load was an artifact of the headless run opening a fresh tab each time. The app remembers the mode across F5 within a tab (sessionStorage, deliberately tab-scoped). A new tab still asks once.
2. Output rows show no review or publish state; the person overview says "No action required" while a pending output exists.
3. People list: UNIDCOM status "To be validated" next to Website "Published" for the same rows, and the dashboard says "156 published, 0 not published". The two states contradict.
4. Publish gives feedback for the website only ("updates by itself within about 15 minutes"). Whether Sanity updated is invisible; the Sanity push is best-effort and silent.
5. Publish is two steps (Publish selected, then confirm) and the confirm text mentions only the website.
6. "Ready to publish" lists people, not outputs. An approved output does not show up on its own.
7. Sanity member created before the fallback fix has no `type` and `sanity-push` never sets the type of an already matched member.
8. Seven separate entry points make something live (see chat summary); only one is on the happy path.
9. Three different add-output paths (researcher wizard, admin outputs list dialog, admin for another person).

## Kept by decision

The Hugo static site stays as the safe design mirror and the test Sanity project `ld5jhf23` stays. Neither is to be removed.

## After Phase I (live, 28 Oct, same day)

Measured on the live build: People list has one State column (no more "To be validated" next to "Published"); output rows show state plus "On site" / "Not on Sanity" chips; the add-output wizard goes Add output, No DOI, Type, Continue, Subtype, Continue, two fields, Continue, Submit = 8 clicks (the last Continue and Submit were counted from the screens, the headless run could not type into the year field). Publish is one click with Undo and reports Website and Sanity per person (not re-clicked live: nothing was left to publish).

Estimated total from "new researcher" to online: about 21-22 clicks (was 25-30). The saving is the confirm click, the separate Sanity push (4 clicks, now automatic, Retry only on failure) and the state clarity; the biggest remaining costs are Add person (2), opening the person (2) and the 8-click wizard.

New findings: after choosing a subtype the wizard shows a redundant Category / Subcategory / Detail picker under the radios (extra dropdown "Detail: All"), which also moves Continue down; the existing "test" output shows "Not on Sanity" because nothing was pushed since the status columns were added.
