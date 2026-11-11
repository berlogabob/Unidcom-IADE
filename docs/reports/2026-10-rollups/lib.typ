// Roll-up banner kit: 85x200 cm trim + 3 mm bleed. Tokens from lib/theme/tokens.dart.
#let navy = rgb("#16213A")
#let deep = rgb("#101A30")
#let teal = rgb("#00B49B")
#let dteal = rgb("#0A7A68")
#let sand = rgb("#F5F4F0")
#let ondark = rgb("#EEF1F6")
#let muted = rgb("#8A94A8")
#let amber = rgb("#F5A622")
#let orange = rgb("#E8622A")
#let blue = rgb("#2B68B8")
#let purple = rgb("#7B3F9E")

#let bleed = 0.3cm
#let safe = 5cm          // text stays this far inside trim
#let base-zone = 25cm    // hidden by the roll-up base: background only
#let hw-zone = 10cm      // top hardware zone: logo only

#let rollup(bg: navy, fg: ondark, body) = {
  set page(width: 85cm + 2 * bleed, height: 200cm + 2 * bleed, fill: bg,
    margin: (x: bleed + safe, top: bleed + 6cm, bottom: bleed + base-zone + 4cm))
  set text(font: "Inter", fill: fg, size: 59pt, lang: "en")
  set par(leading: 0.55em, spacing: 1.1em)
  body
}

#let logo(dark: false, w: 40cm) = image(
  if dark { "assets/unidcom-navy.svg" } else { "assets/unidcom-white.svg" }, width: w)

#let display(size: 256pt, body) = text(size: size, weight: 800, tracking: -0.02em, body)
#let bar(c: teal, w: 18cm) = rect(width: w, height: 1.2cm, fill: c, radius: 0.2cm)

#let stat(n, label, fg: ondark, c: teal) = block(width: 100%, stroke: (top: 0.5cm + c),
  inset: (top: 1.2cm), {
  text(size: 270pt, weight: 800, fill: fg)[#n]
  linebreak()
  text(size: 75pt, weight: 600, fill: fg)[#label]
})

#let qr(url, c: black, bg: white, size: 9cm) = {
  import "@preview/tiaoma:0.3.0": qrcode
  box(fill: bg, inset: 1cm, radius: 0.4cm, qrcode(url, width: size))
}

#let contact(fg: ondark, accent: teal) = block(width: 100%, stroke: (top: 0.25cm + accent),
  inset: (top: 1.4cm), grid(columns: (1fr, 1fr), gutter: 2cm, {
    text(size: 70pt, weight: 700, fill: fg)[unidcom-iade.pt]
    linebreak()
    text(size: 48pt, fill: fg)[unidcom\@iade.pt · \@unidcom.iade]
  }, text(size: 40pt, fill: fg)[
    Oriente Green Campus, Jardim António Augusto Simenta Mordido, 2,\
    1885-001 Moscavide, Portugal
  ]))

// Replace-me box for logos not in the repo (vector files needed from the unit).
#let todo-logo(label, w: 18cm, c: muted) = rect(width: w, height: 5cm, stroke: 0.1cm + c,
  radius: 0.3cm, align(center + horizon, text(size: 35pt, fill: c)[REPLACE: #label (vector)]))

#let funders(fg: ondark, c: muted) = block(width: 100%, {
  text(size: 40pt, fill: fg)[Supported by FCT — Fundação para a Ciência e Tecnologia, I.P., project UID/00711/2025 (doi.org/10.54499/UID/00711/2025), and by the European Union — NextGenerationEU, project UID/PRR/00711/2025.]
  v(1cm)
  grid(columns: 4, gutter: 1.2cm, todo-logo("FCT", c: c), todo-logo("PRR", c: c),
    todo-logo("União Europeia", c: c), todo-logo("IADE · U. Europeia", c: c))
})
