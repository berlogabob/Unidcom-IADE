#!/usr/bin/env bash
# Rebuild the Phase D delivery report. Inter is copied from the sibling report's
# cache (gitignored) or fetched; --ignore-system-fonts keeps the PDF reproducible.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f fonts/Inter.ttf ]; then
  mkdir -p fonts
  if [ -f ../2026-09-ux-audit/fonts/Inter.ttf ]; then
    cp ../2026-09-ux-audit/fonts/Inter.ttf fonts/
  else
    curl -sfL "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" -o fonts/Inter.ttf
  fi
fi

typst compile --root ../../.. --font-path fonts --ignore-system-fonts report.typ phase-d-delivery.pdf
echo "wrote $(pwd)/phase-d-delivery.pdf"
