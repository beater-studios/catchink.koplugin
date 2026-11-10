"""Lists the sprite folders CatchInk downloads from, at a fixed commit of PokeAPI/sprites.

Usage: fetch_sprite_manifest.py <output json>

Needs the GitHub CLI (gh) logged in, since the unauthenticated API allows too few calls.
The result maps each folder to its files (name without extension) and their sizes in bytes.
"""
import json
import subprocess
import sys

COMMIT = "1b3b7c0a538dd2226ae08d0d2f8955125075bbd4"
ROOT = "sprites/pokemon"
FOLDERS = [
    "", "shiny", "female", "shiny/female",
    "versions/generation-i/red-blue/transparent/gray",
    "versions/generation-i/yellow/transparent/gray",
    "versions/generation-ii/gold/transparent", "versions/generation-ii/gold/transparent/shiny",
    "versions/generation-ii/crystal/transparent", "versions/generation-ii/crystal/transparent/shiny",
    "versions/generation-iii/ruby-sapphire", "versions/generation-iii/ruby-sapphire/shiny",
    "versions/generation-iii/emerald", "versions/generation-iii/emerald/shiny",
    "versions/generation-iii/firered-leafgreen", "versions/generation-iii/firered-leafgreen/shiny",
    "versions/generation-iv/diamond-pearl", "versions/generation-iv/diamond-pearl/shiny",
    "versions/generation-iv/diamond-pearl/female", "versions/generation-iv/diamond-pearl/shiny/female",
    "versions/generation-iv/platinum", "versions/generation-iv/platinum/shiny",
    "versions/generation-iv/platinum/female", "versions/generation-iv/platinum/shiny/female",
    "versions/generation-iv/heartgold-soulsilver", "versions/generation-iv/heartgold-soulsilver/shiny",
    "versions/generation-iv/heartgold-soulsilver/female", "versions/generation-iv/heartgold-soulsilver/shiny/female",
    "versions/generation-v/black-white", "versions/generation-v/black-white/shiny",
    "versions/generation-v/black-white/female", "versions/generation-v/black-white/shiny/female",
    "versions/generation-vi/x-y", "versions/generation-vi/x-y/shiny",
    "versions/generation-vi/x-y/female", "versions/generation-vi/x-y/shiny/female",
    "versions/generation-vi/omega-ruby-alpha-sapphire", "versions/generation-vi/omega-ruby-alpha-sapphire/shiny",
    "versions/generation-vi/omega-ruby-alpha-sapphire/female", "versions/generation-vi/omega-ruby-alpha-sapphire/shiny/female",
    "versions/generation-vii/icons", "versions/generation-vii/icons/female",
    "versions/generation-vii/lets-go-pikachu-lets-go-eevee/icons",
    "versions/generation-viii/sword-shield/icons", "versions/generation-viii/sword-shield/icons/female",
    "versions/generation-viii/brilliant-diamond-shining-pearl/icons",
    "versions/generation-viii/legends-arceus/icons", "versions/generation-viii/legends-arceus/icons/shiny",
    "versions/generation-viii/legends-arceus/icons/female",
    "versions/generation-ix/scarlet-violet/icons", "versions/generation-ix/scarlet-violet/icons/female",
    "versions/generation-ix/legends-za/icons", "versions/generation-ix/legends-za/icons/shiny",
    "versions/generation-ix/legends-za/icons/female",
]


def gh(path):
    out = subprocess.run(["gh", "api", path], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def tree(sha):
    return gh(f"repos/PokeAPI/sprites/git/trees/{sha}")["tree"]


def main():
    root_sha = gh(f"repos/PokeAPI/sprites/git/commits/{COMMIT}")["tree"]["sha"]
    cache = {}

    def folder_sha(path):
        if path in cache:
            return cache[path]
        sha = root_sha
        for part in path.split("/"):
            sha = next(e["sha"] for e in tree(sha) if e["path"] == part and e["type"] == "tree")
        cache[path] = sha
        return sha

    manifest = {"commit": COMMIT, "root": ROOT, "folders": {}}
    for folder in FOLDERS:
        full = ROOT + ("/" + folder if folder else "")
        files = {}
        exts = set()
        for e in tree(folder_sha(full)):
            if e["type"] == "blob" and "." in e["path"]:
                stem, ext = e["path"].rsplit(".", 1)
                files[stem] = e["size"]
                exts.add(ext)
        manifest["folders"][folder] = {"ext": sorted(exts)[0] if exts else "png", "files": files}
        print(f"{folder or '(root)'}: {len(files)}", file=sys.stderr)
    with open(sys.argv[1], "w") as f:
        json.dump(manifest, f, sort_keys=True)


if __name__ == "__main__":
    main()
