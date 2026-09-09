#!/usr/bin/env bash
# Rebuild the Sanity bridge how-to and the agency questions. Inter is fetched
# into ./fonts (gitignored) on first run; --ignore-system-fonts keeps the PDF
# identical on every machine.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f fonts/Inter.ttf ]; then
  mkdir -p fonts
  curl -sfL "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" -o fonts/Inter.ttf
fi
typst compile --root ../../.. --font-path fonts --ignore-system-fonts howto.typ sanity-bridge-howto.pdf
typst compile --root ../../.. --font-path fonts --ignore-system-fonts questions.typ sanity-agency-questions.pdf
echo "wrote $(pwd)/sanity-bridge-howto.pdf and sanity-agency-questions.pdf"
