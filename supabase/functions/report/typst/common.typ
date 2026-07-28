// Shared layout for the UNIDCOM reports.
//
// Targets Typst 0.14.2 — the version embedded in @myriaddreamin/typst-ts-web-compiler.
// Keep the local CLI pinned to 0.14.2 too; 0.15 changes inline-box baselines and would
// silently shift the badge pills.

#let brand = rgb("#FF2A13") // matches _brandRed in lib/main.dart
#let ink = rgb("#1A1A1A")
#let muted = rgb("#5A5A5A")
#let rule-color = rgb("#E3E3E3")
#let callout-bg = rgb("#F6F7F8")
#let zebra = rgb("#FAFAFA")

// ponytail: no icon glyph on callouts. No emoji font is loaded (a 🧼 would be tofu),
// and the brand-red left bar plus the bold title already mark the block. The `icon`
// field stays in the data contract for a future themed variant.

/// Document-wide setup. Applied as `#show: report.with(data.meta)`.
#let report(meta, doc) = {
  set document(title: meta.title + " " + meta.subtitle, author: ("UNIDCOM/IADE",))
  set text(
    font: "Lato",
    size: 10pt,
    fill: ink,
    // region is load-bearing: plain "pt" yields Brazilian strings (Seção/Sumário),
    // "pt"+"PT" yields Secção/Índice.
    lang: meta.lang,
    region: meta.region,
  )
  set page(
    paper: "a4",
    margin: (top: 2.2cm, bottom: 2.2cm, x: 2.2cm),
    // Once `footer` is set, page(numbering:) is IGNORED — the footer must draw the
    // page number itself. Never set both.
    footer: context {
      set text(size: 8pt, fill: muted)
      grid(
        columns: (1fr, auto),
        align: (left + horizon, right + horizon),
        meta.footer,
        counter(page).display("1"),
      )
    },
  )
  set par(justify: false, leading: 0.62em)
  set list(marker: text(brand)[•], indent: 0.4em)

  show heading: set block(above: 1.4em, below: 0.7em, sticky: true)
  show heading.where(level: 1): set text(size: 17pt, weight: 700, fill: brand)
  show heading.where(level: 2): set text(size: 12pt, weight: 700, fill: ink)
  show heading.where(level: 3): set text(size: 10.5pt, weight: 600, fill: ink)
  // Do NOT enable hyphenation on links: Typst's URL line-breaker handles DOIs better.
  show link: set text(fill: brand.darken(15%))

  doc
}

#let title-block(meta) = {
  text(size: 24pt, weight: 700, fill: brand, meta.title)
  linebreak()
  text(size: 14pt, weight: 400, fill: muted, meta.subtitle)
  v(0.6em)
  block(above: 0.4em, below: 1em, line(length: 100%, stroke: 2pt + brand))
  par(meta.scope)
}

#let notes-block(title, notes, source) = {
  heading(level: 2, outlined: false, title)
  for n in notes { par(text(size: 9.5pt, n)) }
  par(text(size: 8.5pt, style: "italic", fill: muted, source))
}

/// Table with a repeating brand header, zebra body and an optional rule-topped Total row.
#let data-table(spec, widths: auto) = {
  let n = spec.columns.len()
  let body = spec.rows.map(r => r.cells.map(c => text(size: 9pt, c))).flatten()
  table(
    columns: if widths == auto { (1fr,) * n } else { widths },
    align: (col, _) => if col == 0 { left } else { right },
    inset: (x: 7pt, y: 6pt),
    stroke: none,
    fill: (_, y) => if y == 0 { brand } else if calc.odd(y) { zebra },
    // repeat: true is the default, but the reference document depends on it across
    // page breaks, so it is stated explicitly.
    table.header(
      repeat: true,
      ..spec.columns.map(c => text(fill: white, weight: 700, size: 9pt, c)),
    ),
    table.hline(y: 1, stroke: 0.6pt + rule-color),
    ..body,
    ..if spec.total == none { () } else {
      (
        table.hline(stroke: 1pt + brand),
        ..spec.total.cells.map(c => text(size: 9pt, weight: 700, c)),
      )
    },
  )
}

/// Text with inline links, from `{parts: [{t, url}]}`.
#let rich-text(node) = {
  for p in node.parts {
    if p.url == none { p.t } else { link(p.url)[#p.t] }
  }
}

/// Data-hygiene callout. `block`, not `rect` — rect is unbreakable and the longest of
/// these nearly fills a column.
#let callout(c) = block(
  width: 100%,
  breakable: true,
  sticky: true,
  fill: callout-bg,
  stroke: (left: 3pt + brand),
  radius: (right: 4pt),
  inset: (x: 10pt, y: 9pt),
  above: 1em,
  below: 1em,
  {
    text(weight: 700, size: 9.5pt, c.title)
    v(0.35em, weak: true)
    set text(size: 9pt, fill: muted)
    list(..c.items.map(rich-text))
  },
)

#let pill(label, kind: "neutral") = box(
  inset: (x: 4pt, y: 1.5pt),
  outset: (y: 1.5pt),
  radius: 3pt,
  // 0.14 takes the box baseline from its bottom edge; 0.15 changed this. Explicit.
  baseline: 0.15em,
  fill: if kind == "state" { rgb("#FFF0ED") } else { rgb("#EFEFEF") },
  text(
    size: 7.5pt,
    weight: 600,
    fill: if kind == "state" { brand } else { muted },
    label,
  ),
)

/// One APA reference entry. Order matches the approved document.
#let ref-item(it) = {
  it.ref
  if it.url != none {
    " "
    // A null url-label renders the raw URL so the link line-breaker can split it.
    // Never wrap this in a box — that removes the break opportunities.
    if it.at("url-label") == none { link(it.url) } else { link(it.url)[#it.at("url-label")] }
  }
  if it.isbn != none { " ISBN " + it.isbn }
  for b in it.badges { " " + pill(b) }
  if it.state != none { " " + pill(it.state, kind: "state") }
  if it.people.len() > 0 { text(fill: muted)[ — #it.people.join("; ")] }
  if it.warn != none { " " + pill("! " + it.warn, kind: "state") }
}

#let section-heading(number, title, suffix: none) = {
  heading(level: 1, numbering: none)[#number. #title]
  if suffix != none { par(text(size: 9pt, fill: muted, suffix)) }
}

/// The whole document body, shared by outputs.typ / activities.typ / list.typ.
#let render(data) = {
  title-block(data.meta)
  notes-block(data.meta.at("notes-title"), data.meta.notes, data.meta.at("source-note"))

  if data.meta.at("show-toc") {
    outline(title: [Índice], depth: 1)
  }

  if data.summary != none {
    heading(level: 1, numbering: none, data.summary.title)
    par(data.summary.intro)
    data-table(data.summary, widths: (1fr, 6em, 5em))
  }

  for s in data.sections {
    section-heading(s.number, s.title)
    par(s.intro)

    if s.summary != none {
      heading(level: 2, outlined: false, s.summary.title)
      data-table(s.summary, widths: (1fr, 6em, 5em))
    }
    for c in s.callouts { callout(c) }

    for sub in s.subsections {
      // Count lives in the heading, as in the approved document
      // ("1.3 Capítulos de livro indexados — 20 (19 de 2025 + 1 de 2024)").
      heading(level: 2, numbering: none)[
        #sub.number #sub.title #text(weight: 400, fill: muted)[— #sub.at("count-label")]
      ]
      if sub.note != none { par(text(size: 9pt, fill: muted, sub.note)) }
      for c in sub.callouts { callout(c) }
      for g in sub.groups {
        if g.label != none { par(text(weight: "medium", size: 9.5pt, g.label)) }
        if g.items.len() > 0 { list(..g.items.map(ref-item)) }
      }
    }
  }

  if data.appendix != none {
    // Only break when there is a body above it. The `review` kind is appendix-only,
    // and an unconditional break left its first page almost empty.
    if data.sections.len() > 0 { pagebreak(weak: true) }
    heading(level: 1, numbering: none, data.appendix.title)
    par(data.appendix.intro)
    heading(level: 2, outlined: false, data.appendix.table.title)
    data-table(data.appendix.table, widths: (2.2fr, 1fr, 1.2fr))
    for b in data.appendix.blocks {
      heading(level: 2, b.title)
      par(b.intro)
      if b.items.len() > 0 { list(..b.items.map(rich-text)) }
    }
  }
}
