// Single entry point for all report kinds. The `kind` field drives what `shape.ts`
// puts in the payload (list nulls out the summary and appendix, etc.), so the layout
// needs no branching. Split this file only when a kind needs genuinely different pages.
#import "common.typ": *
#let data = json("/data.json")
#show: report.with(data.meta)
#render(data)
