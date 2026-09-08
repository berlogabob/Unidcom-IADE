/// Which build of the portal this is.
///
/// Rui, on the call of 2026-08-10, after seeing every control at once:
///
/// > all the stuff im stating to take off you can pack it on v2 — so you have
/// > a v1 with less stuff that works well together, and buttons and links that
/// > are only visible if were seeing v2, and we can work on those later
///
/// So v1 is what the pilot cohort gets: fewer controls, all of them working.
/// Nothing behind this flag is deleted — it is only unrendered, and the code
/// and its tests stay live. Build with `--dart-define=V2=true` to see it all.
///
/// Rui's 14 Aug notes call the same set "M2" (milestone 2 — next stage, not
/// now). Behind this flag as of 2026-09-08: support requests; the welcome
/// pack's Support sections (Documents & forms, Conferences & events, Open
/// Access, Missions) and its advice callouts; "Last verified" on the Overview
/// and the profile; the Open Access quick link; the dashboard Top 10 panel.
/// The v1 surface is asserted by test/v1_surface_test.dart. See PLAN.md §8
/// "Phase C".
library;

const v2 = bool.fromEnvironment('V2');
