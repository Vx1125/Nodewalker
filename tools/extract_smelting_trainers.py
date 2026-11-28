#!/usr/bin/env python3
"""Which smelting spells Classic mining trainers teach, from cMaNGOS classic-db (GPL-3.0).

    python3 tools/extract_smelting_trainers.py <classic-db checkout>

Reads Full_DB/ClassicDB_*.sql.gz at the commit pinned in tools/sources_config.json:
npc_trainer rows with required skill 186 (Mining), and spell_template to map each teaching
spell to the spell it learns (effect 36, learn spell). Writes tools/data/cmangos_smelting_trainers.json,
which tools/build_recipes.lua reads. Classic reference data, not verified for Forever.
"""
import glob, gzip, json, os, re, subprocess, sys

ROW = re.compile(r"\(([^()]*)\)")


def fields(t):
    return [x.strip() for x in re.findall(r"'(?:[^'\\]|\\.)*'|[^,]+", t)]


def main():
    root = sys.argv[1]
    pin = json.load(open("tools/sources_config.json"))["pins"]["cmangos"]
    head = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if head != pin:
        sys.exit("classic-db checkout is at %s; tools/sources_config.json pins %s" % (head, pin))
    dump = sorted(glob.glob(os.path.join(root, "Full_DB", "ClassicDB_*.sql.gz")))[-1]
    teach, cols, in_create, spells = {}, [], False, {}
    with gzip.open(dump, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("CREATE TABLE `spell_template`"):
                in_create = True
                continue
            if in_create:
                m = re.match(r"\s+`(\w+)`", line)
                if m:
                    cols.append(m.group(1))
                elif line.startswith(")"):
                    in_create = False
            m = re.match(r"INSERT INTO `npc_trainer(?:_template)?` VALUES (.*);", line)
            if m:
                for t in ROW.findall(m.group(1)):
                    a = t.split(",")
                    if a[3] == "186":
                        e = teach.setdefault(int(a[1]), {"cost": int(a[2]), "reqskill": int(a[4]), "trainers": set()})
                        e["trainers"].add(int(a[0]))
            if line.startswith("INSERT INTO `spell_template`"):
                for t in re.findall(r"\((\d+,[^()]*?)\)(?=,\(|;)", line):
                    a = fields(t)
                    spells[int(a[0])] = dict(zip(cols, a))
    out = []
    for tid, e in sorted(teach.items()):
        s = spells.get(tid, {})
        learned = [int(s["EffectTriggerSpell%d" % i]) for i in (1, 2, 3) if s.get("Effect%d" % i) == "36"]
        out.append({"teaching_spell": tid, "name": s.get("SpellName", "").strip("'"), "learns": learned,
                    "cost": e["cost"], "reqskill": e["reqskill"], "trainers": sorted(e["trainers"])})
    json.dump({"source": "cMaNGOS classic-db (GPL-3.0), npc_trainer + spell_template",
               "commit": pin, "dump": os.path.basename(dump),
               "note": "Classic 1.12 reference data. Not verified for WoW Forever.",
               "rows": out}, open("tools/data/cmangos_smelting_trainers.json", "w"), indent=1)
    print("rows:", len(out))


if __name__ == "__main__":
    main()
