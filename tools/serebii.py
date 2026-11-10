"""Reads the encounter chances of Brilliant Diamond and Shining Pearl from Serebii's Pokéarth (https://www.serebii.net/pokearth/sinnoh/),
credited in the plugin. PKHeX has the places and levels of these games but not the chances.

Usage: serebii.py <cache dir> <output json>

Pages are cached in <cache dir> and fetched one per second and a half. The output maps a place name to
{ version id: { method id: { species id: percent } } }, keeping the highest percent when a place has several areas.
"""
import html
import json
import os
import re
import sys
import time
import urllib.request

BASE = "https://www.serebii.net"
INDEX = "/pokearth/sinnoh/"
BD, SP = 37, 38
METHODS = [
    ("Random Encounter", 1), ("Surfing", 5), ("Fishing - Old Rod", 2), ("Fishing - Good Rod", 3),
    ("Fishing - Super Rod", 4), ("Honey Tree", 55),
]


def fetch(cache, path):
    name = path.strip("/").replace("/", "_") or "index"
    file = os.path.join(cache, name + ".html")
    if not os.path.exists(file):
        req = urllib.request.Request(BASE + path, headers={"User-Agent": "Mozilla/5.0 (CatchInk data build)"})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
        with open(file, "wb") as f:
            f.write(data)
        time.sleep(1.5)
    with open(file, encoding="latin-1") as f:
        return f.read()


def method_of(heading):
    for label, method in METHODS:
        if heading.startswith(label):
            return method
    return None


def parse(page):
    title = re.search(r"<title>(.*?)</title>", page, re.S | re.I)
    name = html.unescape(title.group(1)).split(" - ")[0].strip() if title else ""
    if name.startswith("Serebii") or name.startswith("Pok"):
        parts = [p.strip() for p in html.unescape(title.group(1)).split(" - ")]
        name = parts[-1] if parts else name
    out = {}
    method = None
    for chunk in re.split(r"(?=<table)", page):
        heading = re.search(r"<h[34]>([^<]+)</h[34]>", chunk)
        if heading:
            method = method_of(html.unescape(heading.group(1)).strip())
        text = html.unescape(chunk)
        if "Brilliant Diamond" in text and "Pokémon Brilliant Diamond" in text:
            version = BD
        elif "Pokémon Shining Pearl" in text:
            version = SP
        else:
            continue
        if not method:
            continue
        species = [int(s) for s in re.findall(r"/pokemon/small/(\d+)", chunk)]
        rates = [int(r) for r in re.findall(r">\s*(\d+)%\s*<", chunk)]
        if not species or len(species) != len(rates):
            continue
        slot = out.setdefault(version, {}).setdefault(method, {})
        for sid, rate in zip(species, rates):
            slot[sid] = max(slot.get(sid, 0), rate)
    return name, out


def main():
    cache, output = sys.argv[1], sys.argv[2]
    os.makedirs(cache, exist_ok=True)
    index = fetch(cache, INDEX)
    pages = sorted(set(re.findall(r"/pokearth/sinnoh/[a-z0-9]+\.shtml", index)) - {INDEX + "index.shtml"})
    result = {}
    for path in pages:
        name, data = parse(fetch(cache, path))
        if name and data:
            place = result.setdefault(name, {})
            for version, methods in data.items():
                for method, species in methods.items():
                    slot = place.setdefault(str(version), {}).setdefault(str(method), {})
                    for sid, rate in species.items():
                        slot[str(sid)] = max(slot.get(str(sid), 0), rate)
        print(f"{path}: {name} {sum(len(m) for v in data.values() for m in v.values())}", file=sys.stderr)
    with open(output, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, sort_keys=True, indent=1)
    print(f"{len(result)} places", file=sys.stderr)


if __name__ == "__main__":
    main()
