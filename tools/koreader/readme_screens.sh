#!/bin/sh
# Makes the README screenshots with tools/koreader/render_screens.lua: English in docs/screenshots and
# Portuguese in docs/screenshots/pt. CATCHINK_HOME must have the Red / Blue set downloaded (check_download.lua).
# Usage: KOREADER_DIR=<desktop KOReader> CATCHINK_HOME=<folder> tools/koreader/readme_screens.sh
set -eu
: "${CATCHINK_HOME:?Set CATCHINK_HOME to a folder with the Red / Blue sprites (see check_download.lua).}"
plugin="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# README name, then the render_screens.lua picture it comes from.
pictures="box:05_box_red_blue card:11_card_1 evolution:12_card_eevee_evolution profiles:03_home_profiles"
for lang in en pt; do
    mkdir -p "$work/$lang"
    LANG_CODE="$lang" OUTPUT_DIR="$work/$lang" sh "$plugin/tools/koreader/run_headless.sh" "$plugin/tools/koreader/render_screens.lua"
    out="$plugin/docs/screenshots"
    [ "$lang" = en ] || out="$out/$lang"
    mkdir -p "$out"
    for item in $pictures; do
        cp "$work/$lang/${item#*:}.png" "$out/${item%%:*}.png"
    done
done
echo "Screenshots saved in docs/screenshots and docs/screenshots/pt"
