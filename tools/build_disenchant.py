#!/usr/bin/env python3
"""Disenchanting data, from cMaNGOS classic-db (GPL-3.0) and the Warcraft Wiki (CC BY-SA 4.0).

    python3 tools/build_disenchant.py <classic-db checkout>

Reads Full_DB/ClassicDB_*.sql.gz at the commit pinned in tools/sources_config.json:
disenchant_loot_template (what each table gives: chance, min and max count) and item_template
(class, quality, item level and DisenchantID of every item). Writes Professions/DisenchantData.lua:
  T  the tables; in a loot group, an item listed at 0% gets what the group's others leave
  B  which table an item gets by quality, class and item level, read off the items themselves
  S  the same per quality, class and subclass, where a subclass doesn't follow its class
     (uncommon shields use the weapon tables)
  X  items whose table isn't the one S or B gives
  I  tables whose chances add up to well under 100% (the dump is incomplete there)
  R  the ranges of item IDs that exist in Classic (an ID outside them is new in WoW Forever)
  N  weapons and armour Classic lists with no disenchant (left out, never guessed)
  maxID  the highest item ID in Classic: an item past it is new in WoW Forever, and gets B by item level
Also writes Professions/DisenchantSkill.lua (CC BY-SA) from tools/data/disenchant_skill.json.
WoW Classic 1.12 reference data, not verified for WoW Forever.
"""
import collections, glob, gzip, json, os, re, subprocess, sys

VAL = re.compile(r"'(?:[^'\\]|\\.)*'|[^,]+")


def tuples(body):
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


def read(dump, want):
    cols, rows, cur, done = collections.defaultdict(list), collections.defaultdict(list), None, set()
    with gzip.open(dump, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = re.match(r"CREATE TABLE `(\w+)`", line)
            if m:
                cur = m.group(1) if m.group(1) in want else None
                continue
            if cur and cur not in done:
                m2 = re.match(r"\s+`(\w+)`", line)
                if m2: cols[cur].append(m2.group(1)); continue
                if line.startswith(")"): done.add(cur); cur = None; continue
            m = re.match(r"INSERT INTO `(\w+)` VALUES (.*);\s*$", line)
            if m and m.group(1) in want:
                for tu in tuples(m.group(2)):
                    rows[m.group(1)].append(dict(zip(cols[m.group(1)], [v.strip() for v in VAL.findall(tu)])))
    return rows


def num(v):
    return ("%d" % v) if float(v).is_integer() else ("%.4g" % v)


def main():
    root = sys.argv[1]
    pin = json.load(open("tools/sources_config.json"))["pins"]["cmangos"]
    head = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if head != pin:
        sys.exit("classic-db checkout is at %s; tools/sources_config.json pins %s" % (head, pin))
    dump = sorted(glob.glob(os.path.join(root, "Full_DB", "ClassicDB_*.sql.gz")))[-1]
    rows = read(dump, {"disenchant_loot_template", "item_template"})

    # the tables, with each group's 0% items given what the group leaves
    raw = collections.defaultdict(list)
    for r in rows["disenchant_loot_template"]:
        raw[int(r["entry"])].append((int(r["item"]), float(r["ChanceOrQuestChance"]), int(r["groupid"]),
                                     int(r["mincountOrRef"]), int(r["maxcount"])))
    T = {}
    for e, lst in sorted(raw.items()):
        out = []
        for g in sorted(set(x[2] for x in lst)):
            grp = [x for x in lst if x[2] == g]
            if g == 0:
                out += [(x[0], x[1], x[3], x[4]) for x in grp]
                continue
            fixed = sum(x[1] for x in grp if x[1] > 0)
            zero = [x for x in grp if x[1] == 0]
            share = max(0.0, 100 - fixed) / len(zero) if zero else 0
            out += [(x[0], x[1] if x[1] > 0 else share, x[3], x[4]) for x in grp]
        T[e] = sorted(out, key=lambda x: -x[1])

    items = [dict(id=int(r["entry"]), cls=int(r["class"]), sub=int(r["subclass"]), q=int(r["Quality"]), il=int(r["ItemLevel"]),
                  did=int(r["DisenchantID"])) for r in rows["item_template"]]
    maxid = max(i["id"] for i in items)
    eligible = lambda i: i["cls"] in (2, 4) and i["q"] in (2, 3, 4)

    # B: per quality and class (weapon / armour), the item-level band of each table, read off the items
    def bands(keyf):
        band = collections.defaultdict(lambda: collections.defaultdict(list))
        for i in items:
            if eligible(i) and i["did"]:
                band[keyf(i)][i["did"]].append(i["il"])
        return band
    B = {}
    band = bands(lambda i: (i["q"], i["cls"]))
    for (q, cls), tabs in band.items():
        # the table most items of this quality and class get, per item level
        per = collections.defaultdict(collections.Counter)
        for did, ils in tabs.items():
            for il in ils: per[il][did] += 1
        steps = []
        for il in sorted(per):
            did = per[il].most_common(1)[0][0]
            if steps and steps[-1][1] == did: steps[-1][0] = il
            else: steps.append([il, did])
        B[(q, cls)] = steps

    def steps_of(tabs):
        per = collections.defaultdict(collections.Counter)
        for did, ils in tabs.items():
            for il in ils: per[il][did] += 1
        steps = []
        for il in sorted(per):
            did = per[il].most_common(1)[0][0]
            if steps and steps[-1][1] == did: steps[-1][0] = il
            else: steps.append([il, did])
        return steps

    def look(steps, il):
        for top, did in steps:
            if il <= top: return did
        return steps[-1][1] if steps else None

    # S: a subclass whose items mostly don't get their class's table
    S = {}
    for (q, cls, sub), tabs in bands(lambda i: (i["q"], i["cls"], i["sub"])).items():
        n = sum(len(v) for v in tabs.values())
        off = sum(1 for did, ils in tabs.items() for il in ils if look(B[(q, cls)], il) != did)
        if off * 2 > n:
            S[(q, cls, sub)] = steps_of(tabs)

    def rule(i):
        steps = S.get((i["q"], i["cls"], i["sub"])) or B.get((i["q"], i["cls"]))
        return look(steps, i["il"]) if steps else None

    incomplete = sorted(e for e, out in T.items() if sum(x[1] for x in out) < 99)
    ids = sorted(i["id"] for i in items)
    R, start, prev = [], ids[0], ids[0]
    for x in ids[1:]:
        if x != prev + 1:
            R.append((start, prev)); start = x
        prev = x
    R.append((start, prev))

    X, N = {}, []
    for i in items:
        if not eligible(i) or i["il"] < 1: continue
        if not i["did"]:
            N.append(i["id"])
        elif rule(i) != i["did"]:
            X[i["id"]] = i["did"]

    L = ["local _, NW = ...",
         "-- Generated by tools/build_disenchant.py. Do not edit by hand.",
         "-- cMaNGOS classic-db (GPL-3.0) @ %s, %s: disenchant_loot_template and item_template." % (pin[:12], os.path.basename(dump)),
         "-- WoW Classic 1.12 data, not WoW Forever data: what an item breaks into may differ in game.",
         "NW.DE = {}",
         "local D = NW.DE",
         "D.source = \"cMaNGOS classic-db @ %s\"" % pin[:12],
         "D.maxID = %d -- the highest item ID in Classic; past it, an item is new in WoW Forever" % maxid,
         "-- [table] = { item, chance %, min, max, ... }; in a loot group, a 0% item gets what the others leave",
         "D.T = {"]
    for e, out in T.items():
        L.append("[%d]={%s}," % (e, ",".join("%d,%s,%d,%d" % (a, num(round(b, 3)), c, d) for a, b, c, d in out)))
    L.append("}")
    L.append("-- [quality * 10 + class] = { top item level, table, ... }: the table most items get (class 2 weapons, 4 armour)")
    L.append("D.B = {")
    for (q, cls), steps in sorted(B.items()):
        L.append("[%d]={%s}," % (q * 10 + cls, ",".join("%d,%d" % (a, b) for a, b in steps)))
    L.append("}")
    L.append("-- [quality * 1000 + class * 100 + subclass] = the same, where a subclass doesn't follow its class")
    L.append("D.S = {")
    for (q, cls, sub), steps in sorted(S.items()):
        L.append("[%d]={%s}," % (q * 1000 + cls * 100 + sub, ",".join("%d,%d" % (a, b) for a, b in steps)))
    L.append("}")
    L.append("-- tables whose chances add up to well under 100%%: the Classic data is incomplete there")
    L.append("D.I = {%s}" % ",".join("[%d]=true" % e for e in incomplete))
    L.append("-- item IDs that exist in Classic, as first, last, first, last, ...")
    L.append("D.R = {%s}" % ",".join("%d,%d" % r for r in R))
    L.append("-- [item] = table, where it isn't the one D.S or D.B gives")
    L.append("D.X = {%s}" % ",".join("[%d]=%d" % (k, v) for k, v in sorted(X.items())))
    L.append("-- weapons and armour Classic lists with no disenchant: nothing is shown for them")
    L.append("D.N = {%s}" % ",".join("[%d]=true" % k for k in sorted(N)))
    open("Professions/DisenchantData.lua", "w").write("\n".join(L) + "\n")

    sk = json.load(open("tools/data/disenchant_skill.json"))
    K = ["local _, NW = ...",
         "-- Generated by tools/build_disenchant.py from tools/data/disenchant_skill.json. Do not edit by hand.",
         "-- Enchanting skill needed to disenchant, by quality and item level.",
         "-- Source: %s, retrieved %s." % (sk["source"], sk["retrieved"]),
         "-- Licence: %s (this file only; see LICENSES/Warcraft-Wiki-CC-BY-SA-4.0.txt)." % sk["licence"],
         "-- %s" % sk["note"],
         "NW.DE_SKILL = {"]
    for key, q in (("uncommon", 2), ("rare", 3), ("epic", 4)):
        K.append("[%d]={%s}," % (q, ",".join("%d,%d,%d" % tuple(r) for r in sk[key])))
    K.append("}")
    open("Professions/DisenchantSkill.lua", "w").write("\n".join(K) + "\n")
    print("subclass rules", {k: len(v) for k, v in S.items()}, "incomplete", incomplete, "id ranges", len(R))
    print("tables", len(T), "bands", {k: len(v) for k, v in B.items()}, "exceptions", len(X), "no disenchant", len(N), "maxID", maxid)


if __name__ == "__main__":
    main()
