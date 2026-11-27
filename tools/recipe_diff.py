#!/usr/bin/env python3
"""Regression report: the leveling recipe lists at a git ref against the files on disk.

    python3 tools/recipe_diff.py <git ref> [out.tsv]

For comparison only: nothing here feeds the build (tools/build_recipes.lua reads One For All alone).
Matches by name, else by crafted item. Prints a summary; writes a field-level TSV.
"""
import collections, re, subprocess, sys

PROFS = ["Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "FirstAid", "Leatherworking", "Tailoring"]
FIELDS = ["learn", "yellow", "green", "grey", "src", "item", "reagents", "yield"]


def args(s):
    out, cur, q = [], "", False
    for ch in s:
        if ch == '"':
            q = not q
            cur += ch
        elif ch == "," and not q:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    out.append(cur.strip())
    return out


def parse(text):
    d = {}
    for m in re.finditer(r"^R\((.*)\)\s*$", text, re.M):
        a = args(m.group(1))
        d[a[0].strip('"')] = dict(zip(FIELDS, [a[1], a[2], a[3], a[4], a[5].strip('"'), a[6], a[7].strip('"'), a[8] if len(a) > 8 else "1"]))
    return d


def main():
    ref = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "tools/reports/recipe_remediation_diff.tsv"
    summ, per, rows, gone, added = collections.Counter(), collections.Counter(), [], [], collections.Counter()
    for p in PROFS:
        old = parse(subprocess.run(["git", "show", f"{ref}:Professions/{p}.lua"], capture_output=True, text=True, check=True).stdout)
        new = parse(open(f"Professions/{p}.lua").read())
        by_item = {v["item"]: k for k, v in new.items()}
        matched = set()
        for name, ov in old.items():
            nn = name if name in new else by_item.get(ov["item"])
            if not nn:
                gone.append((p, name))
                continue
            matched.add(nn)
            nv = new[nn]
            diff = [f for f in FIELDS if ov[f] != nv[f]]
            if nn != name:
                diff = ["name"] + diff
            if not diff:
                summ["same"] += 1
                continue
            summ["changed"] += 1
            per.update(diff)
            rows.append((p, name, nn, diff, ov, nv))
        added[p] = len(set(new) - matched)
    with open(out, "w") as fh:
        fh.write("profession\told name\tnew name\tfields\t" + "\t".join("old_" + f for f in FIELDS) + "\t" + "\t".join("new_" + f for f in FIELDS) + "\n")
        for p, a, b, d, ov, nv in rows:
            fh.write("\t".join([p, a, b, ",".join(d)] + [ov[f] for f in FIELDS] + [nv[f] for f in FIELDS]) + "\n")
    print("old recipes:", summ["same"] + summ["changed"] + len(gone), "| same", summ["same"], "| changed", summ["changed"], "| not in the new lists", len(gone))
    print("changed fields:", dict(per))
    print("not in the new lists:", gone)
    print("new recipes per profession:", dict(added))
    learn = collections.Counter()
    for r in rows:
        if "learn" in r[3]:
            o, n = r[4]["learn"], r[5]["learn"]
            learn["unknown -> level" if o == "nil" else "level -> unknown" if n == "nil" else "level -> other level"] += 1
    print("learn changes:", dict(learn))
    print("source changes:", dict(collections.Counter((r[4]["src"], r[5]["src"]) for r in rows if "src" in r[3])))
    print("wrote", out)


if __name__ == "__main__":
    main()
