"""Downloads the base sprite set that ships inside the plugin (sprites/base, female, shiny and shiny_female), from
PokeAPI/sprites at the commit of tools/sources/sprites_manifest.json. Files already there are kept.

Usage: fetch_base_sprites.py [plugin dir]
"""
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDERS = {"": "base", "female": "female", "shiny": "shiny", "shiny/female": "shiny_female"}


def main():
    plugin = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(HERE)
    with open(os.path.join(HERE, "sources", "sprites_manifest.json")) as f:
        manifest = json.load(f)
    jobs = []
    for folder, local in FOLDERS.items():
        info = manifest["folders"][folder]
        out = os.path.join(plugin, "sprites", local)
        os.makedirs(out, exist_ok=True)
        remote = manifest["root"] + ("/" + folder if folder else "")
        for stem in info["files"]:
            path = os.path.join(out, f"{stem}.{info['ext']}")
            if not os.path.exists(path):
                jobs.append((f"https://raw.githubusercontent.com/PokeAPI/sprites/{manifest['commit']}/{remote}/{stem}.{info['ext']}", path))

    def fetch(job):
        url, path = job
        req = urllib.request.Request(url, headers={"User-Agent": "CatchInk data build"})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)

    with ThreadPoolExecutor(8) as pool:
        for _ in pool.map(fetch, jobs):
            pass
    print(f"{len(jobs)} files downloaded")


if __name__ == "__main__":
    main()
