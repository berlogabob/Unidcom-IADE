#!/usr/bin/env bash
# Rebuild the briefing-kit report. Fonts fetched on demand into ./fonts (gitignored).
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f fonts/Inter.ttf ]; then
  mkdir -p fonts
  cp ../2026-09-ux-audit/fonts/Inter.ttf fonts/ 2>/dev/null || curl -sfL "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" -o fonts/Inter.ttf
fi
typst compile --font-path fonts --ignore-system-fonts briefing-kit.typ briefing-kit.pdf
echo "wrote $(pwd)/briefing-kit.pdf"
