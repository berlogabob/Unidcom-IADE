#import "lib.typ": *
// B — Labs and research clusters
#show: rollup.with(bg: sand, fg: navy)
#logo(dark: true)
#v(4cm)
#display(size: 229pt)[Five labs.\ Five clusters.\ One #text(fill: dteal)[programme.]]
#v(2cm)
#text(size: 70pt, fill: rgb("#444240"))[Instead of separate research groups, UNIDCOM runs a broad programme around five thematic clusters.]
#v(1.5cm)
#let row(code, title, line, c) = block(width: 100%, fill: white, stroke: 0.1cm + rgb("#E2E1DC"),
  radius: 0.5cm, inset: 1cm, below: 0.7cm, grid(columns: (17cm, 1fr), gutter: 1cm, align: horizon,
    text(size: 129pt, weight: 800, fill: c)[#code],
    {
      text(size: 72pt, weight: 700)[#title]
      linebreak()
      text(size: 54pt, fill: rgb("#444240"))[#line]
    }))
#text(size: 54pt, weight: 700, fill: dteal, tracking: 0.12em)[CLUSTERS]
#v(0.8cm)
#row("E3", "Exploring Economic Ethos", "Design in a capitalist world", dteal)
#row("T3", "Thoughtfulness Technology for Thrive", "Design in a sociotechnical world", blue)
#row("C3", "Crafting Cooperation and Coexistence", "Design in a world of tension", purple)
#row("R3", "Rethinking for Regeneration and Resilience", "Design in an unsustainable world", rgb("#2E7D32"))
#row("F3", "Finding Flourishing Futures", "Design for a flourishing world", rgb("#8A5A08"))
#v(2cm)
#text(size: 54pt, weight: 700, fill: dteal, tracking: 0.12em)[LABS]
#v(0.8cm)
#row("MADx", "Media Arts and Design", "Photography, digital arts, games, heritage", dteal)
#row("DFH", "Design for Humanity", "Social sciences and design on societal challenges", blue)
#row("DTN", "Design-Tech Nexus", "Ethical technology: engineering, art, social values", purple)
#row("SDI", "Strategic Design + Innovation", "Products, services and business models", rgb("#2E7D32"))
#row("BID", "Bio-Inspired Design", "Learning from nature for sustainable solutions", rgb("#8A5A08"))
#v(1fr)
#contact(fg: navy, accent: dteal)
