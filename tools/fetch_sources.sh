#!/bin/sh
# Downloads the sources of data/ at the commits that built the published data, into a new, empty folder, and checks
# every file tools/build_data.py reads against tools/sources.sha256. Nothing downloaded is run.
# Usage: tools/fetch_sources.sh <empty folder>
# Then: python3 -I tools/build_data.py <folder>/pokeapi/data/v2/csv --out data --pkhex <folder>/pkhex/PKHeX.Core
# Changing a commit is a change on purpose: build again, review what changed in data/ and update sources.sha256.
set -eu
POKEAPI_COMMIT=5cbeb3f3eb55a9b86da52c4869336f9d61fdd6d7
PKHEX_COMMIT=96e33e7432d900e5345afdfd117eabfac43f5bbd

fail() {
    echo "$*" >&2
    exit 1
}

[ $# -eq 1 ] || fail "Usage: tools/fetch_sources.sh <empty folder>"
dest="$1"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$dest"
[ -z "$(ls -A "$dest")" ] || fail "$dest is not empty: the sources go to a new, empty folder."
dest="$(cd "$dest" && pwd)"

# name, repository, commit, then the folders the generator reads.
fetch() {
    name="$1"
    url="$2"
    commit="$3"
    shift 3
    git init -q "$dest/$name"
    git -C "$dest/$name" remote add origin "$url"
    git -C "$dest/$name" sparse-checkout set "$@"
    git -C "$dest/$name" fetch -q --depth 1 --filter=blob:none origin "$commit"
    git -C "$dest/$name" checkout -q --detach FETCH_HEAD
    [ "$(git -C "$dest/$name" rev-parse HEAD)" = "$commit" ] || fail "$name: got another commit than $commit."
}

fetch pokeapi https://github.com/PokeAPI/pokeapi.git "$POKEAPI_COMMIT" data/v2/csv
fetch pkhex https://github.com/kwsch/PKHeX.git "$PKHEX_COMMIT" \
    PKHeX.Core/Legality/Encounters/Data PKHeX.Core/Resources/byte/personal PKHeX.Core/Resources/legality/wild \
    PKHeX.Core/Resources/text/locations
(cd "$dest" && shasum -a 256 -c --quiet "$here/sources.sha256") || fail "A downloaded file differs from tools/sources.sha256."
echo "Sources in $dest: PokeAPI $POKEAPI_COMMIT, PKHeX $PKHEX_COMMIT, $(wc -l < "$here/sources.sha256" | tr -d ' ') files checked."
