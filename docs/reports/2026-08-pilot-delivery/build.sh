#!/usr/bin/env bash
# Rebuild the pilot delivery report.
#
# Inter is fetched on demand into ./fonts (gitignored) rather than committed —
# same pattern as the institutional report's Lato cache. Typst 0.15 synthesises
# the 400/600/700 weights from the variable font correctly.
#
# --ignore-system-fonts keeps the build reproducible: without it a locally
# installed font could substitute silently and the PDF would differ per machine.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f fonts/Inter.ttf ]; then
  echo "fetching Inter…"
  mkdir -p fonts
  curl -sfL "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" \
    -o fonts/Inter.ttf
fi

typst compile --font-path fonts --ignore-system-fonts report.typ pilot-delivery-report.pdf
echo "wrote $(pwd)/pilot-delivery-report.pdf"
