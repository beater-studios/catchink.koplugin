"""Reads encounter tables and form lists from PKHeX (https://github.com/kwsch/PKHeX, GPL-3.0) for the games
PokeAPI has no encounters for: Brilliant Diamond and Shining Pearl, Legends: Arceus, Scarlet and Violet (with
Kitakami and Blueberry) and Legends: Z-A (with Mega Dimension). Also which forms each game from Sword and
Shield on has. Formats follow PKHeX.Core (EncounterArea8b, 8a, 9, 9a, EncounterFixed9, PersonalInfo*).

Used by build_data.py with --pkhex <PKHeX.Core folder>.
"""
import os
import re
import struct

RES = "Resources"

# Methods, as ids of data/i18n.lua "methods" (PokeAPI's, plus 67 to 69).
WALK, OLD_ROD, GOOD_ROD, SUPER_ROD, SURF, ROCK_SMASH = 1, 2, 3, 4, 5, 6
GIFT, GIFT_EGG, STATIC, HONEY_TREE, OVERWORLD = 18, 19, 20, 55, 38
UNDERGROUND, ALPHA, OUTBREAK = 67, 68, 69

# Area ids of these games live apart from PokeAPI's: BASE + game code * 100000 + location.
BASE = 1000000
CODES = {"bdsp": 1, "la": 2, "sv": 3, "za": 4}

# PokeAPI version ids.
BD, SP, LA, SCARLET, VIOLET = 37, 38, 39, 40, 41
TEAL = (42, 52)
INDIGO = (43, 53)
ZA, MEGA_DIMENSION = 47, 48

SLOT_8B = {1: WALK, 2: SURF, 3: OLD_ROD, 4: GOOD_ROD, 5: SUPER_ROD, 6: ROCK_SMASH, 7: WALK, 8: HONEY_TREE}


def accessor(data, wide):
    """Entries of a BinLinkerAccessor file (32-bit offsets) or BinLinkerAccessor16 (16-bit)."""
    count = struct.unpack_from("<H", data, 2)[0]
    out = []
    for i in range(count):
        if wide:
            start, end = struct.unpack_from("<II", data, 4 + i * 4)
        else:
            start, end = struct.unpack_from("<HH", data, 4 + i * 2)
        out.append(data[start:end])
    return out


def read(core, *parts):
    with open(os.path.join(core, RES, *parts), "rb") as f:
        return f.read()


def location_names(core, folder, prefix):
    """Location names by id, in English and Spanish, from text/locations/<folder>/text_<prefix>_<bank>_<lang>.txt."""
    names = {}
    for bank in (0, 30000, 40000, 60000):
        for lang, key in (("en", 0), ("es", 1)):
            path = os.path.join(core, RES, "text", "locations", folder, f"text_{prefix}_{bank:05d}_{lang}.txt")
            if not os.path.exists(path):
                continue
            with open(path, encoding="utf-8") as f:
                for i, line in enumerate(f.read().split("\n")):
                    line = line.strip()
                    if line and not line.startswith("—"):
                        names.setdefault(bank + i, ["", ""])[key] = line
    return names


def place_dictionary(core):
    """English place name -> Spanish, from every location list of PKHeX (the lines match across languages)."""
    folder = os.path.join(core, RES, "text", "locations")
    out = {}
    for gen in sorted(os.listdir(folder)):
        path = os.path.join(folder, gen)
        if not os.path.isdir(path):
            continue
        for name in sorted(os.listdir(path)):
            if not name.endswith("_en.txt"):
                continue
            es_path = os.path.join(path, name[:-7] + "_es.txt")
            if not os.path.exists(es_path):
                continue
            with open(os.path.join(path, name), encoding="utf-8") as f:
                en = f.read().split("\n")
            with open(es_path, encoding="utf-8") as f:
                es = f.read().split("\n")
            for a, b in zip(en, es):
                a, b = a.strip(), b.strip()
                if a and b and not a.startswith("\u2014"):
                    # The third generation writes places in capitals.
                    if b.isupper():
                        b = b.title()
                    out.setdefault(a.lower().replace("\u2019", "'").replace("\u00e9", "e"), b)
    return out


class Collector:
    """Gathers encounters: species -> version -> {(area, method): [min, max]}, and the area names."""

    def __init__(self):
        self.enc = {}
        self.areas = {}
        self.by_name = {}
        self.forms_seen = {}

    def add(self, species, form, versions, game, location, method, lo, hi, names):
        if species <= 0 or species > 1025:
            return
        name = names.get(location)
        if not name or not name[0]:
            return
        # Places with the same name (parts of one cave, say) become one.
        key = (game, name[0])
        area = self.by_name.get(key)
        if area is None:
            area = BASE + CODES[game] * 100000 + location
            self.by_name[key] = area
            self.areas[area] = [name[0], name[1] or name[0]]
        for v in versions:
            slot = self.enc.setdefault(species, {}).setdefault(v, {}).setdefault((area, method), [lo, hi])
            slot[0] = min(slot[0], lo)
            slot[1] = max(slot[1], hi)
        if form:
            self.forms_seen.setdefault(game, set()).add((species, form))


def sv_versions(location):
    if 132 <= location <= 171:
        return TEAL
    if 172 <= location <= 200:
        return INDIGO
    return (SCARLET, VIOLET)


STATIC_LINE = re.compile(r"new\(([^)]*)\)\s*\{([^}]*)\}")


def statics(core, path, blocks):
    """Static encounters and gifts written in PKHeX's C# lists: yields (block, version token, species, form, level, location, gift)."""
    with open(os.path.join(core, path), encoding="utf-8") as f:
        text = f.read()
    for block in blocks:
        m = re.search(r"static readonly \w+\[\] " + block + r"\s*=\s*\[(.*?)\n\s*\];", text, re.S)
        if not m:
            continue
        for line in m.group(1).split("\n"):
            s = STATIC_LINE.search(line)
            if not s:
                continue
            args, body = s.group(1).strip(), s.group(2)
            fields = dict(re.findall(r"(\w+)\s*=\s*([\w.]+)", body))
            positional = [a.strip() for a in args.split(",")]
            if positional and positional[0].isdigit():
                species, form, level = int(positional[0]), int(positional[1]), int(positional[2])
                version = ""
            else:
                version = positional[0] if positional else ""
                species = int(fields.get("Species", "0"))
                form = int(fields.get("Form", "0")) if fields.get("Form", "0").isdigit() else 0
                level = int(fields.get("Level", "0")) if fields.get("Level", "0").isdigit() else 0
            loc = fields.get("Location", "")
            if not loc.isdigit():
                continue
            egg = "EggLocation" in fields
            gift = egg or "FixedBall" in fields or int(loc) >= 30000 or block == "Gifts"
            yield block, version, species, form, level, int(loc), (GIFT_EGG if egg else (GIFT if gift else STATIC))


def bdsp(core, col):
    names = location_names(core, "gen8b", "bdsp")
    w = os.path.join("legality", "wild", "Gen8")
    for file, version, method_override in (("encounter_bd.pkl", BD, None), ("encounter_sp.pkl", SP, None),
                                           ("encounter_bd_underground.pkl", BD, UNDERGROUND), ("encounter_sp_underground.pkl", SP, UNDERGROUND)):
        for area in accessor(read(core, w, file), True):
            location = struct.unpack_from("<H", area, 0)[0]
            kind = area[2]
            method = method_override or SLOT_8B.get(kind, WALK)
            for o in range(4, len(area) - 3, 4):
                sp = struct.unpack_from("<H", area, o)[0]
                col.add(sp & 0x3FF, sp >> 11, (version,), "bdsp", location, method, area[o + 2], area[o + 3], names)
    token = {"BD": (BD,), "SP": (SP,), "BDSP": (BD, SP), "": (BD, SP)}
    for block, version, species, form, level, loc, method in statics(core, "Legality/Encounters/Data/Gen8/Encounters8b.cs", ("Encounter_BDSP", "StaticBD", "StaticSP")):
        versions = token.get(version.strip(), (BD, SP))
        if block == "StaticBD":
            versions = (BD,)
        elif block == "StaticSP":
            versions = (SP,)
        col.add(species, form, versions, "bdsp", loc, method, level, level, names)


def la(core, col):
    names = location_names(core, "gen8a", "la")
    for area in accessor(read(core, "legality", "wild", "Gen8", "encounter_la.pkl"), True):
        count = area[0]
        locations = list(area[1:1 + count])
        align = count + 1
        align += align & 1
        rest = area[align:]
        kind, slots = rest[0], rest[1]
        body = rest[2:]
        for i in range(slots):
            e = body[i * 8:(i + 1) * 8]
            species = struct.unpack_from("<H", e, 0)[0]
            form, alpha, lo, hi = e[2], e[3], e[4], e[5]
            method = ALPHA if alpha else (OUTBREAK if kind in (3, 4) else OVERWORLD)
            for loc in locations[:1]:
                col.add(species, form, (LA,), "la", loc, method, lo, hi, names)
    for _, _, species, form, level, loc, method in statics(core, "Legality/Encounters/Data/Gen8/Encounters8a.cs", ("StaticLA",)):
        col.add(species, form, (LA,), "la", loc, method, level, level, names)


def sv(core, col):
    names = location_names(core, "gen9", "sv")
    for area in accessor(read(core, "legality", "wild", "Gen9", "encounter_wild_paldea.pkl"), True):
        location = area[0]
        body = area[4:]
        for o in range(0, len(body) - 7, 8):
            species = struct.unpack_from("<H", body, o)[0]
            col.add(species, body[o + 2], sv_versions(location), "sv", location, OVERWORLD, body[o + 4], body[o + 5], names)
    fixed = read(core, "legality", "wild", "Gen9", "encounter_fixed_paldea.pkl")
    for o in range(0, len(fixed) - 0x13, 0x14):
        species = struct.unpack_from("<H", fixed, o)[0]
        form, level, location = fixed[o + 2], fixed[o + 3], fixed[o + 0x10]
        col.add(species, form, sv_versions(location), "sv", location, STATIC, level, level, names)
    for block, version, species, form, level, loc, method in statics(core, "Legality/Encounters/Data/Gen9/Encounters9.cs", ("Encounter_SV", "StaticSL", "StaticVL")):
        versions = sv_versions(loc) if loc < 30000 else (SCARLET, VIOLET)
        if block == "StaticSL" or version == "SL":
            versions = (versions[0],)
        elif block == "StaticVL" or version == "VL":
            versions = (versions[-1],) if len(versions) > 1 else versions
        col.add(species, form, versions, "sv", loc, method, level, level, names)


def za(core, col):
    names = location_names(core, "gen9a", "za")
    for file, version in (("encounter_za.pkl", ZA), ("encounter_hyperspace_za.pkl", MEGA_DIMENSION)):
        for area in accessor(read(core, "legality", "wild", "Gen9", file), False):
            location = struct.unpack_from("<H", area, 0)[0]
            body = area[4:]
            for o in range(0, len(body) - 7, 8):
                species = struct.unpack_from("<H", body, o)[0]
                form, lo, hi, alpha = body[o + 2], body[o + 4], body[o + 5], body[o + 6] == 1
                col.add(species, form, (version,), "za", location, ALPHA if alpha else OVERWORLD, lo, hi, names)
    for _, _, species, form, level, loc, method in statics(core, "Legality/Encounters/Data/Gen9/Encounters9a.cs", ("Gifts", "Static")):
        col.add(species, form, (ZA,), "za", loc, method, level, level, names)


def encounters(core):
    col = Collector()
    for reader in (bdsp, la, sv, za):
        reader(core, col)
    return col


# Personal tables: entry size, offset of FormStatsIndex, FormCount, and how "present in game" is stored.
PERSONAL = {
    "swsh": (0xB0, 0x1E, 0x20, lambda e: (e[0x21] >> 6) & 1 == 1, 898),
    "bdsp": (0x44, 0x1E, 0x20, lambda e: (e[0x21] >> 6) & 1 == 1, 493),
    "la": (0xB0, 0x1E, 0x20, lambda e: (e[0x21] >> 6) & 1 == 1, 905),
    "sv": (0x50, 0x18, 0x1A, lambda e: e[0x1C] != 0, 1025),
    "za": (0x50, 0x18, 0x1A, lambda e: e[0x1C] != 0, 1025),
}


def present_forms(core, table):
    """(species, form number) pairs a game has, form numbers above 0 only."""
    size, fsi, fc, present, top = PERSONAL[table]
    raw = read(core, "byte", "personal", "personal_" + table)
    entries = [raw[i * size:(i + 1) * size] for i in range(len(raw) // size)]
    out = set()
    for sid in range(1, min(top, len(entries) - 1) + 1):
        base = entries[sid]
        count = base[fc]
        index = struct.unpack_from("<H", base, fsi)[0]
        for form in range(1, count):
            entry = entries[index + form - 1] if index and index + form - 1 < len(entries) else base
            if present(entry):
                out.add((sid, form))
    return out
