#!/usr/bin/env bash
# Rebuild the executive deck. Needs network on a cold machine: Typst fetches
# @preview/touying once into its package cache, and Inter is copied from a
# sibling report or downloaded. --ignore-system-fonts keeps the PDF reproducible.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f fonts/Inter.ttf ]; then
  mkdir -p fonts
  if [ -f ../2026-09-phase-d-delivery/fonts/Inter.ttf ]; then
    cp ../2026-09-phase-d-delivery/fonts/Inter.ttf fonts/
  else
    curl -sfL "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" -o fonts/Inter.ttf
  fi
fi

typst compile --root ../../.. --font-path fonts --ignore-system-fonts deck.typ unidcom-rims-deck.pdf
echo "wrote $(pwd)/unidcom-rims-deck.pdf"
