// UNIDCOM RIMS — executive deck. Touying + the metropolis theme (the Typst port
// of Beamer's mtheme), recoloured to the tokens in docs/reports/*/lib.typ so the
// deck, the A4 reports, the Figma file and lib/theme/tokens.dart are one family.
//
// Live figures re-derived on 18 Sep 2026: `flutter test` (269 green),
// `flutter analyze` (0), and counting SQL against the pilot database. Dated
// historical figures (Phase D, 10–11 Sep) are labelled as such.
//
// Build: ./build.sh

#import "@preview/touying:0.6.1": *
#import themes.metropolis: *

// ---------------------------------------------------------------- TOKENS
#let brand = rgb("#16213A") // navy
#let accent = rgb("#00B49B") // teal — rules and bars only, never text
// metropolis colours `strong` with the primary accent. Bright teal on sand is
// 2.2:1, so emphasis uses a darkened teal (~4.5:1) and the bars keep the brand one.
#let accent-ink = accent.darken(45%)
#let surface = rgb("#F5F4F0") // sand page background
#let hairline = rgb("#D8D6D0")
// lib.typ's muted (#888680) is a 3.0:1 note colour sized for A4 body text;
// darkened here because slide labels are set small against a projected page.
#let muted = rgb("#5F5D58")

#let ok = rgb("#15803D")
#let warn = rgb("#B45309")
#let bad = rgb("#B91C1C")
#let info = rgb("#1D4ED8")

// ---------------------------------------------------------------- HELPERS
#let pill(label, tone: muted) = box(
  inset: (x: 0.45em, y: 0.22em),
  radius: 3pt,
  fill: tone.lighten(88%),
  stroke: 0.5pt + tone.lighten(50%),
  text(size: 0.62em, weight: "medium", fill: tone, upper(label)),
)

#let kpi(value, label, note) = block(
  width: 100%,
  inset: (x: 0.7em, y: 0.6em),
  radius: 5pt,
  fill: white,
  stroke: 0.6pt + hairline,
  {
    text(size: 0.5em, weight: "medium", fill: muted, tracking: 0.06em, upper(label))
    v(0.3em, weak: true)
    text(size: 1.35em, weight: "semibold", fill: brand, value)
    v(0.25em, weak: true)
    text(size: 0.5em, fill: muted, note)
  },
)

#let kpi-row(tiles) = grid(
  columns: (1fr,) * tiles.len(),
  gutter: 0.7em,
  ..tiles.map(t => kpi(..t)),
)

// A node in the flow diagram, plus the labelled connector under it.
#let node(title, sub) = block(
  width: 100%,
  inset: (x: 0.7em, y: 0.4em),
  radius: 4pt,
  fill: white,
  stroke: (left: 2.5pt + accent, rest: 0.6pt + hairline),
  {
    text(size: 0.64em, weight: "semibold", fill: brand, title)
    linebreak()
    text(size: 0.5em, fill: muted, sub)
  },
)

#let link-down(label) = grid(
  columns: (1.4em, auto),
  align: (center, left + horizon),
  rows: 1.35em,
  line(angle: 90deg, length: 1.15em, stroke: 1.5pt + accent),
  text(size: 0.5em, fill: muted, label),
)

#let hrule = line(length: 100%, stroke: 0.6pt + hairline)

// A two-column table with hairline horizontals only — no vertical rules.
#let plain-table(headers, rows, cols) = table(
  columns: cols,
  stroke: (x, y) => (top: if y == 0 { 0.8pt + brand } else { 0.4pt + hairline }),
  inset: (x: 0.5em, y: 0.5em),
  align: left + top,
  table.header(..headers.map(h => text(size: 0.55em, weight: "semibold", fill: brand, tracking: 0.04em, upper(h)))),
  ..rows.flatten().map(c => text(size: 0.62em, fill: brand, c)),
)

// ---------------------------------------------------------------- THEME
#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [UNIDCOM RIMS — Researcher Portal],
    subtitle: [What was built, how it works, what it changes],
    author: [André Berloga · backend and business logic],
    date: [18 September 2026],
    institution: [UNIDCOM / IADE],
  ),
  config-colors(
    primary: accent,
    primary-light: accent.lighten(60%),
    secondary: brand,
    neutral-lightest: surface,
    neutral-dark: brand,
    neutral-darkest: brand,
  ),
  // The theme reads the footer from its own parameter, not config-common.
  footer: text(size: 0.62em, fill: muted)[UNIDCOM RIMS · 18 September 2026],
  // The title slide freezes the counter but still costs a page, so "n / total"
  // would be off by one. Show the number alone.
  footer-right: text(size: 0.62em, fill: muted, context utils.slide-counter.display()),
  // touying re-applies `show strong: alert` inside every slide, which paints
  // emphasis in the bright brand teal — 2.2:1 on sand. Off; see accent-ink.
  config-common(show-strong-with-alert: false),
)

#set text(font: "Inter", weight: "light", size: 20pt, fill: brand)
#set strong(delta: 250)
#set par(spacing: 0.9em)
#show raw: set text(size: 0.85em)
#show strong: set text(fill: accent-ink)

#title-slide(extra: text(size: 0.8em, fill: muted)[
  Portal #link("https://berlogabob.github.io/Unidcom-IADE/") · Public site
  #link("https://berlogabob.github.io/unidcom-site/")
])

// ---------------------------------------------------------------- 1
#slide(title: [What was built], align: top)[
  #v(0.3em)
  The database stopped being a staging area and became the institutional record.
  Every write now goes through one reviewed path, and every one of them is audited.

  #v(0.5em)
  #plain-table(
    ("When", "What shipped"),
    (
      ([*W1–W4* \ August], [ORCID sign-in, profile validation and output approval as two audited state machines; admin review queue; institutional PDF generated from live data; CI gating every deploy.]),
      ([*P0–P14* \ early Sep], [Carmela's design system, five navigation surfaces reduced to one — and a security pass: `anon` revoked from the whole schema, where 153 researcher emails had been readable without signing in.]),
      ([*Phase C* \ 8 Sep], [Rui's 14 August notes applied. Nothing deleted: everything retired hides behind one `v2` flag and still compiles in CI.]),
      ([*Phase D* \ 10–11 Sep], [Rui's v1.0 specification — 48 requirements, 19 gaps — specified, built and deployed inside two days. 17 PRs, all CI-green; 4 additive database changes, nothing renamed.]),
    ),
    (auto, 1fr),
  )
]

// ---------------------------------------------------------------- 2
#slide(title: [How it works], align: top, composer: (1.1fr, 1fr))[
  #v(0.2em)
  #node([Researcher], [signs in with their ORCID iD])
  #link-down[registry gate: the iD must already be on file]
  #node([Researcher portal], [Flutter web, reads live under RLS])
  #link-down[proposals, never direct writes]
  #node([Supabase], [the source of truth — 34 tables, 59 RLS policies])
  #link-down[`sync.py`, nightly 04:00 UTC, field allowlist]
  #node([Public website], [Hugo static site, regenerated from the database])
][
  #v(0.2em)
  #text(size: 0.84em)[*Approval is the gate, not a job.*] \
  #text(size: 0.62em)[Anonymous visitors see approved rows and nothing else. Publishing is a database policy that cannot silently fall behind, and Approve and Publish are now two separate admin actions.]

  #v(0.5em)
  #text(size: 0.84em)[*Three privacy dimensions, deliberately different.*] \
  #text(size: 0.62em)[RLS decides which *rows*. Grants decide which *tables*. The sync allowlist decides which *fields* ever leave the database — RLS has no column dimension, which is exactly how the emails leaked.]

  #v(0.5em)
  #text(size: 0.84em)[*Researchers hold no write grant.*] \
  #text(size: 0.62em)[Own work is recorded through a `security definer` RPC that forces `pending`; profile edits are staged as suggestions for an administrator to accept.]
]

// ---------------------------------------------------------------- 3
#slide(title: [Where it stands, in numbers], align: top)[
  #v(0.3em)
  #kpi-row((
    ("269", "Automated tests", "all green today; 0 analyzer issues"),
    ("365", "Outputs on the site", "every one approved and published"),
    ("185", "Researcher profiles", "26 hold an ORCID iD"),
    ("609", "Audited changes", "who changed what, and when"),
  ))

  #v(0.7em)
  #text(size: 0.62em, fill: muted)[Phase D, 10 → 11 September — the specification's own measures:]
  #v(0.2em)
  #plain-table(
    ("Measure", "Before", "After"),
    (
      ([Researcher sidebar], [25 leaves, 8 of them placeholders], [5 items, 0 placeholders]),
      ([Pages for profile / outputs], [6 and 5], [1 and 1]),
      ([Filters on own outputs], [2], [8, with 5 views and 3 groupings]),
      ([Researcher writes to `people`], [direct, from an Edit dialog], [0 — every edit is a proposal]),
      ([Website state], [approval meant publication], [a separate, auditable column]),
      ([`flutter test`], [199], [267 on the day, 269 today]),
    ),
    (auto, 1fr, 1fr),
  )
]

// ---------------------------------------------------------------- 4
#slide(title: [What it changes], align: top)[
  #v(0.4em)
  #grid(
    columns: (auto, 1fr),
    row-gutter: 1.1em,
    column-gutter: 1.2em,
    align: (right + top, left + top),

    text(weight: "semibold", size: 0.8em)[For the \ researcher],
    text(size: 0.72em)[One sign-in with the ORCID iD they already have. One profile page and one outputs page instead of eleven. Corrections are proposed in place and go to a queue — no email, no form, no waiting to find out whether it landed. Their own work is added through a guided DOI-first wizard that refuses obvious duplicates.],

    text(weight: "semibold", size: 0.8em)[For the \ administrator],
    text(size: 0.72em)[A single review queue for profiles, outputs and proposed edits, each decision recorded against a person. Approve and Publish are separate, so a correction can be taken off the website without unapproving the record. Duplicate people can be merged. The institutional publication report is a 24-page PDF generated from live data, not assembled by hand.],

    text(weight: "semibold", size: 0.8em)[For the \ institution],
    text(size: 0.72em)[One source of truth that the public site is generated from, so the website cannot drift from the record. Nothing unapproved is reachable by an anonymous visitor. Every change is attributable. New entity types — projects, funding, PhD students — inherit the same approval gate by adopting one column and one policy; there is no second machine to build.],
  )
]

// ---------------------------------------------------------------- 5
#slide(title: [Open, and honestly so], align: top)[
  #v(0.4em)
  #grid(
    columns: (4.2em, 1fr),
    row-gutter: 0.85em,
    column-gutter: 0.8em,
    align: (left + horizon, left + horizon),

    pill("live", tone: ok), text(size: 0.72em)[The portal and the public website are deployed and in use. Phase D's v1.0 scope is on the deployed portal in full.],

    pill("blocked", tone: warn), text(size: 0.72em)[*The pilot cohort has not been named.* Everything downstream of that list is built and verified — this is the only blocker that is not engineering.],

    pill("data", tone: warn), text(size: 0.72em)[*26 of 185 profiles hold an ORCID iD.* A researcher whose iD is not on file cannot sign in at all. The fix is an administrator pass over the list, not code.],

    pill("risk", tone: bad), text(size: 0.72em)[*Backups cover 9 of 27 tables*, and the restore script cascades into 18 it cannot put back. A restore has never been rehearsed. Highest remaining technical risk.],

    pill("risk", tone: bad), text(size: 0.72em)[*Bus factor of one* — a single person holds Supabase, GitHub, the ORCID developer app and DNS.],

    pill("to do", tone: info), text(size: 0.72em)[Live click-throughs of the proposal flows (≈30 min) and three wording decisions from Rui.],
  )
]
