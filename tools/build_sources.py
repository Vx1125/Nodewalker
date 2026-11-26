#!/usr/bin/env python3
"""Build Materials/SourceData.lua: creature, skinning and vendor sources for Material Finder.

Inputs (read as text, never executed):
  pfQuest      https://github.com/shagu/pfQuest        MIT     db/units.lua, db/items.lua, db/enUS/*.lua
  cMaNGOS      https://github.com/cmangos/classic-db   GPL-3   Full_DB/ClassicDB_*.sql.gz (decompressed)

Both describe WoW Classic 1.12, not WoW Forever. Everything they give is labelled "Classic data" in game.

usage: python3 -I tools/build_sources.py <pfQuest dir> <classicdb.sql> <Nodewalker dir>
"""
import re, sys, os, statistics

PF, SQL, NWDIR = sys.argv[1], sys.argv[2], sys.argv[3]

# Outdoor zones only: dungeons and cities aren't farmed with a route
ZONES = [
    "Alterac Mountains", "Arathi Highlands", "Badlands", "Blasted Lands", "Burning Steppes", "Deadwind Pass",
    "Dun Morogh", "Duskwood", "Eastern Plaguelands", "Elwynn Forest", "Hillsbrad Foothills", "Loch Modan",
    "Redridge Mountains", "Searing Gorge", "Silverpine Forest", "Stranglethorn Vale", "Swamp of Sorrows",
    "The Hinterlands", "Tirisfal Glades", "Western Plaguelands", "Westfall", "Wetlands",
    "Ashenvale", "Azshara", "Darkshore", "Desolace", "Durotar", "Dustwallow Marsh", "Felwood", "Feralas",
    "Moonglade", "Mulgore", "Silithus", "Stonetalon Mountains", "Tanaris", "Teldrassil", "The Barrens",
    "Thousand Needles", "Un'Goro Crater", "Winterspring",
]

CLOTH = {2589: "cloth", 2592: "cloth", 4306: "cloth", 4338: "cloth", 14047: "cloth", 14256: "cloth"}
ELEMENTAL = {7067, 7068, 7069, 7070, 7075, 7076, 7077, 7078, 7079, 7080, 7081, 7082, 7972, 12808, 12803}
# mined, not hunted: stone and gems (ore and herbs come from Data.lua's NODE_ITEMS)
MINED = {2835, 2836, 2838, 7912, 12365, 774, 818, 1210, 1206, 1705, 1529, 3864, 7909, 7910, 12361, 12364, 12799, 12800, 11754, 12363, 7911}
LEATHER_WORDS = re.compile(r"\b(Leather|Hide|Scale|Scales|Pelt|Fur)\b")

LOOT_MIN = 1.0      # % chance a creature's ordinary loot must give
SKIN_MIN = 3.0      # % chance a skinning table must give
CLOTH_MIN = 3.0
MAX_UNITS = 80      # creatures kept per material, by chance x spawns


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def lua_blocks(text):
    """Top-level `[id] = { ... },` blocks of a pfQuest table, as (id, body)."""
    for m in re.finditer(r"\n  \[(\d+)\] = \{\n(.*?)\n  \},", text, re.S):
        yield int(m.group(1)), m.group(2)


def lua_names(text):
    out = {}
    for m in re.finditer(r'\n  \[(\d+)\] = "((?:[^"\\]|\\.)*)"', text):
        out[int(m.group(1))] = m.group(2).replace('\\"', '"').replace("\\'", "'")
    return out


def sub_table(body, key):
    m = re.search(r'\["' + key + r'"\] = \{(.*?)\n    \}', body, re.S)
    if not m:
        return {}
    return {int(a): float(b) for a, b in re.findall(r"\[(\d+)\] = ([\d.]+)", m.group(1))}


# ---------------------------------------------------------------- pfQuest
zone_names = lua_names(read(os.path.join(PF, "db/enUS/zones.lua")))
zone_ok = {zid: n for zid, n in zone_names.items() if n in ZONES}
unit_names = lua_names(read(os.path.join(PF, "db/enUS/units.lua")))
item_names = lua_names(read(os.path.join(PF, "db/enUS/items.lua")))

units = {}
for uid, body in lua_blocks(read(os.path.join(PF, "db/units.lua"))):
    coords = re.findall(r"\{ ([\d.]+), ([\d.]+), (\d+), (\d+) \}", body)
    lvl = re.search(r'\["lvl"\] = "([^"]*)"', body)
    fac = re.search(r'\["fac"\] = "([^"]*)"', body)
    units[uid] = {
        "coords": [(float(x), float(y), int(z), int(r)) for x, y, z, r in coords],
        "lvl": lvl.group(1) if lvl else "",
        "fac": fac.group(1) if fac else "",
    }

pf_drops, pf_vendors = {}, {}
for iid, body in lua_blocks(read(os.path.join(PF, "db/items.lua"))):
    u = sub_table(body, "U")
    if u:
        pf_drops[iid] = u
    v = sub_table(body, "V")
    if v:
        pf_vendors[iid] = v


# ---------------------------------------------------------------- cMaNGOS
def sql_rows(sql, table):
    out = []
    for m in re.finditer(r"INSERT INTO `" + table + r"` VALUES (.*?);\n", sql, re.S):
        s, i, n = m.group(1), 0, len(m.group(1))
        while i < n:
            if s[i] != "(":
                i += 1
                continue
            i += 1
            row, cur, q = [], "", False
            while i < n:
                c = s[i]
                if q:
                    if c == "\\":
                        cur += s[i + 1]
                        i += 2
                        continue
                    if c == "'":
                        q = False
                    else:
                        cur += c
                elif c == "'":
                    q = True
                elif c == ",":
                    row.append(cur)
                    cur = ""
                elif c == ")":
                    row.append(cur)
                    i += 1
                    break
                else:
                    cur += c
                i += 1
            out.append(row)
    return out


def sql_columns(sql, table):
    m = re.search(r"CREATE TABLE `" + table + r"` \((.*?)\n\)", sql, re.S)
    return re.findall(r"^  `(\w+)`", m.group(1), re.M)


sql = read(SQL)
ct_cols = sql_columns(sql, "creature_template")
ci = {c: k for k, c in enumerate(ct_cols)}
ctemplate = {}
for r in sql_rows(sql, "creature_template"):
    ctemplate[int(r[ci["Entry"]])] = {
        "name": r[ci["Name"]], "min": int(r[ci["MinLevel"]]), "max": int(r[ci["MaxLevel"]]),
        "type": int(r[ci["CreatureType"]]), "rank": int(r[ci["Rank"]]), "skin": int(r[ci["SkinningLootId"]]),
    }


def loot_table(name):
    t = {}
    for r in sql_rows(sql, name):
        entry, item, chance, group, mref, mx = int(r[0]), int(r[1]), float(r[2]), int(r[3]), int(r[4]), int(r[5])
        t.setdefault(entry, []).append((item, chance, group, mref, mx))
    return t


it_cols = sql_columns(sql, "item_template")
ii = {c: k for k, c in enumerate(it_cols)}
item_class = {int(r[ii["entry"]]): int(r[ii["class"]]) for r in sql_rows(sql, "item_template")}

skin_tab = loot_table("skinning_loot_template")
ref_tab = loot_table("reference_loot_template")


def effective(entries, scale=1.0, depth=0):
    """item -> (chance %, min, max). Groups: zero-chance entries share what's left."""
    out = {}
    groups = {}
    for e in entries:
        groups.setdefault(e[2], []).append(e)
    for g, es in groups.items():
        explicit = sum(e[1] for e in es if e[1] > 0)
        zeros = [e for e in es if e[1] == 0]
        share = max(0.0, 100.0 - explicit) / len(zeros) if (g and zeros) else 0
        for item, chance, group, mref, mx in es:
            p = chance if chance > 0 else (share if g else 100.0)
            if mref < 0:
                if depth < 3:
                    for it, (c2, a, b) in effective(ref_tab.get(-mref, []), scale * p / 100, depth + 1).items():
                        old = out.get(it, (0, a, b))
                        out[it] = (old[0] + c2, a, b)
                continue
            old = out.get(item, (0, mref, mx))
            out[item] = (old[0] + p * scale, mref, mx)
    return out


skin_by_item = {}
for uid, ct in ctemplate.items():
    if ct["skin"] and ct["skin"] in skin_tab:
        for item, (ch, a, b) in effective(skin_tab[ct["skin"]]).items():
            if ch >= SKIN_MIN:
                skin_by_item.setdefault(item, {})[uid] = (round(ch, 1), a, b)

# ---------------------------------------------------------------- materials
reagents = set()
cooking = set()
crafted = set()
for fn in os.listdir(os.path.join(NWDIR, "Professions")):
    text = read(os.path.join(NWDIR, "Professions", fn))
    for s in re.findall(r'"((?:\d+:\d+)(?:,\d+:\d+)*)"', text):
        ids = {int(a) for a in re.findall(r"(\d+):\d+", s)}
        reagents |= ids
        if fn == "Cooking.lua":
            cooking |= ids
    # what a recipe makes: R(name, ..., src, createdID, "reagents") and the catalog's own lines
    for a in re.findall(r',(\d+),"(?:\d+:\d+)(?:,\d+:\d+)*"', text):
        crafted.add(int(a))
gathered = {int(a) for a in re.findall(r'\] = (\d+)', re.search(r"NW.NODE_ITEMS = \{(.*?)\n\}", read(os.path.join(NWDIR, "Data.lua")), re.S).group(1))}


def spawns(uid):
    """zone name -> set of 1% cells, outdoor zones only."""
    out = {}
    for x, y, z, r in units.get(uid, {}).get("coords", []):
        if z in zone_ok and 0 <= x < 100 and 0 <= y < 100:
            out.setdefault(zone_ok[z], set()).add((int(x), int(y)))
    return out


def respawn(uid):
    rs = [r for _, _, z, r in units.get(uid, {}).get("coords", []) if z in zone_ok and r > 0]
    return int(statistics.median(rs)) if rs else 0


def category(iid, name):
    if iid in CLOTH:
        return "cloth"
    if iid in ELEMENTAL:
        return "elemental"
    if iid in skin_by_item or LEATHER_WORDS.search(name or ""):
        return "leather"
    if iid in cooking:
        return "meat"
    return "reagent"


mats = {}
for iid in set(skin_by_item) | ((reagents | set(CLOTH) | ELEMENTAL) & set(pf_drops)):
    name = item_names.get(iid)
    if not name or item_class.get(iid) not in (5, 7, 15):
        continue
    cat = category(iid, name)
    # other providers own these: crafting, vendors, herb and ore nodes, mining
    if cat in ("reagent", "meat") and (iid in crafted or iid in pf_vendors or iid in gathered or iid in MINED):
        continue
    loot = {}
    floor = CLOTH_MIN if cat == "cloth" else LOOT_MIN
    for uid, ch in pf_drops.get(iid, {}).items():
        if ch >= floor and spawns(uid):
            loot[uid] = ch
    skin = {uid: v for uid, v in skin_by_item.get(iid, {}).items() if spawns(uid)}

    def top(d, key):
        ranked = sorted(d, key=lambda u: -key(u) * sum(len(c) for c in spawns(u).values()))
        return {u: d[u] for u in ranked[:MAX_UNITS]}

    loot = top(loot, lambda u: loot[u])
    skin = top(skin, lambda u: skin[u][0])
    if not loot and not skin:
        continue
    mats[iid] = {"name": name, "cat": cat, "loot": loot, "skin": skin}

keep_units = set()
for m in mats.values():
    keep_units |= set(m["loot"]) | set(m["skin"])

# vendors for recipe reagents that vendors sell (any zone, cities included)
vendors = {}
for iid in reagents:
    for uid, n in pf_vendors.get(iid, {}).items():
        if units.get(uid, {}).get("coords"):
            vendors.setdefault(iid, []).append((uid, int(n)))
            keep_units.add(uid)
vzone = {}
for iid, vs in vendors.items():
    for uid, _ in vs:
        for x, y, z, r in units[uid]["coords"][:1]:
            if z in zone_names:
                vzone[uid] = (zone_names[z], round(x, 1), round(y, 1))

# ---------------------------------------------------------------- write
zones_used = sorted({zn for u in keep_units for zn in spawns(u)} | {v[0] for v in vzone.values()})
zidx = {z: k + 1 for k, z in enumerate(zones_used)}


def lstr(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


out = []
w = out.append
w("local _, NW = ...")
w("-- Generated by tools/build_sources.py. Do not edit by hand.")
w("-- WoW Classic 1.12 data, not WoW Forever data: creatures, spawns and chances may differ in game.")
w("--   pfQuest (MIT, Shagu): creature spawns, ordinary loot chances, vendors.")
w("--   cMaNGOS classic-db (GPL-3): creature levels and types, skinning loot.")
w("NW.SRC = {}")
w("local S = NW.SRC")
w("S.zones = {" + ",".join(lstr(z) for z in zones_used) + "}")
w("-- [npc] = { name, minLevel, maxLevel, type, rank, faction, respawn seconds, skinnable }")
w("S.units = {")
for uid in sorted(keep_units):
    ct = ctemplate.get(uid, {})
    name = unit_names.get(uid) or ct.get("name", "?")
    lo, hi = ct.get("min"), ct.get("max")
    if lo is None:
        lv = re.findall(r"\d+", units[uid]["lvl"])
        lo = int(lv[0]) if lv else 0
        hi = int(lv[-1]) if lv else 0
    w("[%d]={%s,%d,%d,%d,%d,%s,%d,%s}," % (uid, lstr(name), lo, hi, ct.get("type", 0), ct.get("rank", 0),
                                         lstr(units[uid]["fac"]), respawn(uid), "true" if ct.get("skin") else "false"))
w("}")
w("-- [npc] = { zone, \"xxyyxxyy...\" (1% cells), zone, ... }")
w("S.spawns = {")
for uid in sorted(keep_units):
    sp = spawns(uid)
    if not sp:
        continue
    parts = []
    for zn in sorted(sp):
        parts.append("%d,\"%s\"" % (zidx[zn], "".join("%02d%02d" % c for c in sorted(sp[zn]))))
    w("[%d]={%s}," % (uid, ",".join(parts)))
w("}")
w("-- [item] = { name, category, loot = { npc, chance, ... }, skin = { npc, chance, min, max, ... } }")
w("S.items = {")
for iid in sorted(mats):
    m = mats[iid]
    loot = ",".join("%d,%s" % (u, ("%g" % c)) for u, c in sorted(m["loot"].items(), key=lambda kv: -kv[1]))
    skin = ",".join("%d,%s,%d,%d" % (u, ("%g" % v[0]), v[1], v[2]) for u, v in sorted(m["skin"].items(), key=lambda kv: -kv[1][0]))
    w("[%d]={%s,%s,loot={%s},skin={%s}}," % (iid, lstr(m["name"]), lstr(m["cat"]), loot, skin))
w("}")
w("-- [item] = { npc, ... }; S.vendorAt[npc] = { zone, x, y }")
w("S.vendors = {")
for iid in sorted(vendors):
    w("[%d]={%s}," % (iid, ",".join(str(u) for u, _ in vendors[iid] if u in vzone)))
w("}")
w("S.vendorAt = {")
for uid in sorted(vzone):
    z, x, y = vzone[uid]
    w("[%d]={%d,%g,%g}," % (uid, zidx[z], x, y))
w("}")
dst = os.path.join(NWDIR, "Materials", "SourceData.lua")
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
print("materials", len(mats), "units", len(keep_units), "zones", len(zones_used), "vendored", len(vendors),
      "bytes", os.path.getsize(dst))
from collections import Counter
print(Counter(m["cat"] for m in mats.values()))
