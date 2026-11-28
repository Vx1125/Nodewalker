#!/usr/bin/env python3
"""How Classic teaches recipes One For All has no source for, from cMaNGOS classic-db (GPL-3.0).

    python3 tools/extract_recipe_sources.py <classic-db checkout> <One For All folder>

Finds One For All recipes with a Classic spell ID (< 1,000,000), no recipe item, no source and no
trainer fee, and looks up trainers, recipe items (with who sells or drops them, and the item's
reputation), and quests that teach them. Writes tools/data/classic_recipe_sources.json, which
tools/build_recipes.lua reads. Classic 1.12 reference data: not verified for WoW Forever.
"""
import gzip, re, sys, collections

import glob, json, os, subprocess
ROOT, OFA = sys.argv[1], sys.argv[2]
PIN = json.load(open("tools/sources_config.json"))["pins"]["cmangos"]
HEAD = subprocess.run(["git", "-C", ROOT, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
if HEAD != PIN:
    sys.exit("classic-db checkout is at %s; tools/sources_config.json pins %s" % (HEAD, PIN))
DUMP = sorted(glob.glob(os.path.join(ROOT, "Full_DB", "ClassicDB_*.sql.gz")))[-1]
# One For All recipes with no way to learn them in its data
fees = open(os.path.join(OFA, "Data", "ProfessionFees.lua"), encoding="utf-8").read()
feeIds = set(int(x) for x in re.findall(r"\[(\d+)\]=\{\d+,", fees))
SPELLS = []
for fn in sorted(glob.glob(os.path.join(OFA, "Data", "Professions", "*.lua"))):
    for line in open(fn, encoding="utf-8"):
        m = re.match(r"\s*\{s=(\d+),", line)
        if not m: continue
        s = int(m.group(1))
        if s >= 1000000 or s in feeIds or " ri=" in line or "src=" in line or "start=true" in line: continue
        SPELLS.append(s)
VAL = re.compile(r"'(?:[^'\\]|\\.)*'|[^,]+")


def tuples(body):
    # split "(...),(...)" respecting quotes
    out, depth, cur, q, esc = [], 0, [], False, False
    for ch in body:
        if q:
            cur.append(ch)
            if esc: esc = False
            elif ch == "\\": esc = True
            elif ch == "'": q = False
            continue
        if ch == "'":
            q = True; cur.append(ch)
        elif ch == "(":
            depth += 1
            if depth == 1: cur = []; continue
            cur.append(ch)
        elif ch == ")":
            depth -= 1
            if depth == 0: out.append("".join(cur)); continue
            cur.append(ch)
        elif depth >= 1:
            cur.append(ch)
    return out


cols, tables, cur = collections.defaultdict(list), collections.defaultdict(list), None
WANT = {"spell_template", "npc_trainer", "npc_trainer_template", "item_template", "quest_template", "npc_vendor",
        "npc_vendor_template", "creature_loot_template", "reference_loot_template", "gameobject_loot_template",
        "creature_template", "item_loot_template"}
with gzip.open(DUMP, "rt", encoding="utf-8", errors="replace") as fh:
    for line in fh:
        m = re.match(r"CREATE TABLE `(\w+)`", line)
        if m:
            cur = m.group(1) if m.group(1) in WANT else None
            continue
        if cur and not cols.get(cur + "#done"):
            m2 = re.match(r"\s+`(\w+)`", line)
            if m2: cols[cur].append(m2.group(1)); continue
            if line.startswith(")"): cols[cur + "#done"] = True; cur = None; continue
        m = re.match(r"INSERT INTO `(\w+)` VALUES (.*);\s*$", line)
        if m and m.group(1) in WANT:
            t = m.group(1)
            for tu in tuples(m.group(2)):
                tables[t].append(dict(zip(cols[t], [v.strip() for v in VAL.findall(tu)])))

name = lambda s: s.strip("'")
spell = {int(r["Id"]): r for r in tables["spell_template"]}
creature = {int(r["Entry"]): name(r["Name"]) for r in tables["creature_template"]}
items = {int(r["entry"]): r for r in tables["item_template"]}
teach = collections.defaultdict(set)  # learned spell -> teaching spells
for sid, r in spell.items():
    for i in (1, 2, 3):
        if r.get("Effect%d" % i) == "36":
            teach[int(r["EffectTriggerSpell%d" % i])].add(sid)
trainers = collections.defaultdict(list)
for t in ("npc_trainer", "npc_trainer_template"):
    for r in tables[t]:
        trainers[int(r["spell"])].append((t, int(r["entry"]), int(r["reqskillvalue"])))
item_by_spell = collections.defaultdict(list)
for e, r in items.items():
    for i in range(1, 6):
        s = int(r.get("spellid_%d" % i, 0) or 0)
        if s: item_by_spell[s].append(e)
vend = collections.defaultdict(list)
for t in ("npc_vendor", "npc_vendor_template"):
    for r in tables[t]: vend[int(r["item"])].append(int(r["entry"]))
loot = collections.defaultdict(list)
refs = collections.defaultdict(list)
for r in tables["reference_loot_template"]: refs[int(r["item"])].append(int(r["entry"]))
for t in ("creature_loot_template", "gameobject_loot_template", "item_loot_template"):
    for r in tables[t]:
        it, mc = int(r["item"]), int(r.get("mincountOrRef", "1") or 1)
        if mc < 0: continue
        loot[it].append((t.split("_")[0], int(r["entry"]), float(r["ChanceOrQuestChance"])))
refloot = collections.defaultdict(list)
for t in ("creature_loot_template", "gameobject_loot_template", "item_loot_template"):
    for r in tables[t]:
        mc = int(r.get("mincountOrRef", "1") or 1)
        if mc < 0: refloot[-mc].append((t.split("_")[0], int(r["entry"])))
refparent = collections.defaultdict(list)  # reference entry -> reference entries that include it
for r in tables["reference_loot_template"]:
    mc = int(r.get("mincountOrRef", "1") or 1)
    if mc < 0: refparent[-mc].append(int(r["entry"]))
qrew = collections.defaultdict(list)
qitem = collections.defaultdict(list)
for r in tables["quest_template"]:
    q = (int(r["entry"]), name(r["Title"]))
    for k in ("RewSpell", "RewSpellCast"):
        if int(r.get(k, 0) or 0): qrew[int(r[k])].append(q)
    for k in [c for c in r if re.match(r"Rew(Choice)?ItemId\d", c)]:
        if int(r[k] or 0): qitem[int(r[k])].append(q)

def up_to_creatures(entry, seen=None):
    """creatures (and objects) whose loot reaches reference entry, following nested references"""
    seen = seen or set()
    if entry in seen: return []
    seen.add(entry)
    out = list(refloot.get(entry, []))
    for parent in refparent.get(entry, []):
        out += up_to_creatures(parent, seen)
    return out


out = []
for s in sorted(set(SPELLS)):
    rec = {"spell": s, "name": name(spell.get(s, {}).get("SpellName", "''")).replace("\\'", "'"),
           "trainers": [], "quests": [], "items": []}
    for ts in sorted(teach.get(s, set()) | {s}):
        for t, npc, req in trainers.get(ts, []):
            rec["trainers"].append({"npc": npc, "name": creature.get(npc, "?"), "req": req})
        for q in qrew.get(ts, []):
            if {"id": q[0], "title": q[1]} not in rec["quests"]:
                rec["quests"].append({"id": q[0], "title": q[1].replace("\\'", "'")})
        for it in item_by_spell.get(ts, []):
            r = items[it]
            e = {"item": it, "name": name(r["name"]).replace("\\'", "'"), "skill": int(r["RequiredSkillRank"] or 0),
                 "vendors": [{"npc": n, "name": creature.get(n, "?")} for n in sorted(set(vend.get(it, [])))],
                 "quests": [{"id": q[0], "title": q[1].replace("\\'", "'")} for q in qitem.get(it, [])]}
            if int(r["RequiredReputationFaction"] or 0):
                e["rep"] = [int(r["RequiredReputationFaction"]), int(r["RequiredReputationRank"])]
            mobs = set(b for a, b, _ in loot.get(it, []) if a == "creature")
            for ref in refs.get(it, []):
                mobs |= set(b for a, b in up_to_creatures(ref) if a == "creature")
            e["drops"] = len(mobs)
            if mobs: e["drop_example"] = creature.get(min(mobs), "?")
            rec["items"].append(e)
    out.append(rec)
json.dump({"source": "cMaNGOS classic-db (GPL-3.0): npc_trainer, spell_template, item_template, npc_vendor, loot, quest_template",
           "commit": PIN, "note": "Classic 1.12 reference data for recipes One For All has no source for. Not verified for WoW Forever.",
           "recipes": out}, open("tools/data/classic_recipe_sources.json", "w"), indent=1, ensure_ascii=False)
# the same as a Lua table for tools/build_recipes.lua (no JSON parser in plain Lua)
def lua(v):
    if isinstance(v, dict): return "{" + ", ".join("%s=%s" % (k, lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, list): return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, str): return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return str(v)
with open("tools/data/classic_recipe_sources.lua", "w") as fh:
    fh.write("-- Generated by tools/extract_recipe_sources.py from cMaNGOS classic-db @ %s (GPL-3.0). Classic reference.\n" % PIN)
    fh.write("return {\n" + "".join("  " + lua(r) + ",\n" for r in out) + "}\n")
print("recipes:", len(out), "with an item:", sum(1 for r in out if r["items"]), "quest only:", sum(1 for r in out if r["quests"] and not r["items"]), "nothing:", sum(1 for r in out if not (r["items"] or r["quests"] or r["trainers"])))
