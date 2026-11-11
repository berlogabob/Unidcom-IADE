#import "lib.typ": *
// C — Researchers and funders
#show: rollup.with(bg: deep)
#logo()
#v(8cm)
#display[Research\ that #text(fill: teal)[designs]\ what's next.]
#v(2cm)
#bar()
#v(2cm)
#text(size: 89pt, weight: 600)[130+ researchers across 5 labs and 10+ scientific areas, evaluated and funded by FCT.]
#v(4cm)
#grid(columns: (1fr, 1fr), gutter: 2cm, row-gutter: 3cm,
  stat("130+", "Researchers"), stat("5", "Labs"),
  stat("10+", "Scientific areas"), stat("5", "Clusters"))
#v(4cm)
#block(fill: navy, radius: 0.8cm, inset: 2.5cm, width: 100%, grid(columns: (1fr, auto), gutter: 2cm, align: horizon, {
  text(size: 105pt, weight: 800)[Join us. Explore our research.]
  linebreak()
  text(size: 59pt, fill: ondark)[Researchers, post-docs, visiting scholars and postgraduate students: scan to see people, projects and outputs.]
}, qr("https://unidcom-iade.pt", c: navy)))
#v(1fr)
#funders()
#v(2cm)
#contact()
