// Pinned runtime assets, shared by the Edge Function and the local preview so both
// render with identical fonts.
//
// ponytail: fetched from jsDelivr rather than vendored into the repo or a Storage
// bucket — that keeps the function bundle tiny, needs no Docker deploy, and gives one
// source of truth. Lato has been stable in google/fonts for years; if a font update
// ever reflows the document, vendor the four TTFs and drop these URLs.

export const WASM =
  "https://cdn.jsdelivr.net/npm/@myriaddreamin/typst-ts-web-compiler@0.7.0/pkg/typst_ts_web_compiler_bg.wasm";

export const FONT_BASE = "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/lato/";
export const FONT_FILES = [
  "Lato-Regular.ttf",
  "Lato-Bold.ttf",
  "Lato-Italic.ttf",
  "Lato-BoldItalic.ttf",
];
