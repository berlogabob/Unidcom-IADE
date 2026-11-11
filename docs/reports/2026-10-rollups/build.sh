#!/usr/bin/env bash
# Build the three roll-up PDFs (85x200 cm + 3 mm bleed) and low-res previews.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f fonts/Inter.ttf ]; then
  mkdir -p fonts
  cp ../2026-10-rui-brief/fonts/Inter.ttf fonts/ 2>/dev/null || \
    curl -sfL "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" -o fonts/Inter.ttf
fi
for v in a b c; do
  typst compile --root ../../.. --font-path fonts --ignore-system-fonts rollup-$v.typ rollup-$v.pdf
  pdftoppm -png -r 8 -singlefile rollup-$v.pdf preview-$v
done
echo "built in $(pwd)"
