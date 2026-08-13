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
library;

const v2 = bool.fromEnvironment('V2');
