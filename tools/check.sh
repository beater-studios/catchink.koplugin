#!/bin/sh
# Every check that runs without KOReader. The CI runs tools/check.sh; the release runs tools/check.sh release, which
# also downloads the sources of data/ at their fixed commits, builds it again and fails if it differs from the
# repository.
set -eu
cd "$(dirname "$0")/.."
for spec in tests/*_spec.lua; do
    luajit "$spec"
done
luajit tools/check_texts.lua t
luajit tools/validate.lua
if [ "${1:-}" = release ]; then
    sources="$(mktemp -d)"
    sh tools/fetch_sources.sh "$sources"
    python3 -I tools/build_data.py "$sources/pokeapi/data/v2/csv" --out data --pkhex "$sources/pkhex/PKHeX.Core"
    rm -rf "$sources"
    # Changed files, and new ones the generator made, against what the repository has. data/i18n.lua holds the
    # interface texts, written by hand, not by the generator.
    generated="data :(exclude)data/i18n.lua"
    if ! git diff --quiet -- $generated || [ -n "$(git ls-files --others --exclude-standard -- $generated)" ]; then
        git status --short -- $generated
        echo "data/ differs from what the sources build." >&2
        exit 1
    fi
fi
sh tools/package.sh
