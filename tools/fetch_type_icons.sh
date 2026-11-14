#!/bin/sh
# Downloads the type icons (SVG) of partywhale/pokemon-type-icons (MIT) at a fixed commit, into a new, empty folder,
# and checks them against tools/type_icons.sha256. Nothing downloaded is run.
# Usage: tools/fetch_type_icons.sh <empty folder>
# Then: ICONS_SVG=<folder>/icons KOREADER_DIR=<desktop KOReader> tools/koreader/run_headless.sh tools/koreader/make_type_icons.lua
set -eu
COMMIT=fcbe6978c61c359680bc07636c3f9bdc0f346b43

fail() {
    echo "$*" >&2
    exit 1
}

[ $# -eq 1 ] || fail "Usage: tools/fetch_type_icons.sh <empty folder>"
dest="$1"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$dest"
[ -z "$(ls -A "$dest")" ] || fail "$dest is not empty: the icons go to a new, empty folder."
dest="$(cd "$dest" && pwd)"
git init -q "$dest"
git -C "$dest" remote add origin https://github.com/partywhale/pokemon-type-icons.git
git -C "$dest" sparse-checkout set icons
git -C "$dest" fetch -q --depth 1 origin "$COMMIT"
git -C "$dest" checkout -q --detach FETCH_HEAD
[ "$(git -C "$dest" rev-parse HEAD)" = "$COMMIT" ] || fail "Got another commit than $COMMIT."
(cd "$dest" && shasum -a 256 -c --quiet "$here/type_icons.sha256") || fail "A downloaded icon differs from tools/type_icons.sha256."
echo "Type icons in $dest/icons: partywhale/pokemon-type-icons $COMMIT, $(wc -l < "$here/type_icons.sha256" | tr -d ' ') files checked."
