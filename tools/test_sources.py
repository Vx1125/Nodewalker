#!/usr/bin/env python3
"""Static checks of a generated SourceData.lua and its build reports.

These are offline file checks. They are NOT live-client tests: they do not load the addon in
WoW, and passing them says nothing about Forever's real spawns or drop rates.

Usage: python tools/test_sources.py [--data Materials/SourceData.lua] [--reports tools/reports]
Exit code 0 when every check passes; failures are listed.
"""
import argparse, collections, csv, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from build_sources import lua_value, DUMMY  # the generic Lua-literal reader and dummy-name rule

FAIL = []


def check(ok, msg):
    if not ok:
        FAIL.append(msg)
    return ok


def table(text, name):
    m = re.search(r'^S\.%s = ' % re.escape(name), text, re.M)
    if not m:
        return None
    return lua_value(text, m.end())[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', default=os.path.join(ROOT, 'Materials', 'SourceData.lua'))
    ap.add_argument('--reports', default=os.path.join(HERE, 'reports'))
    ap.add_argument('--config', default=os.path.join(HERE, 'sources_config.json'))
    a = ap.parse_args()
    text = open(a.data, encoding='utf-8').read()
    cfg = json.load(open(a.config, encoding='utf-8'))

    # 1. the file parses as Lua table literals, and nothing follows the last table
    check(text.startswith('local _, NW = ...'), 'header: missing addon namespace line')
    zones = table(text, 'zones'); units = table(text, 'units'); spawns = table(text, 'spawns')
    items = table(text, 'items'); calc = table(text, 'calc') or {}
    vendors = table(text, 'vendors'); vendor_at = table(text, 'vendorAt')
    m = re.search(r'^S\.coordScale = (\d+)$', text, re.M)
    scale = int(m.group(1)) if m else 100
    digits = len(str(scale - 1))
    check(scale in (100, 1000), 'coordScale %d unsupported by Materials/Hunt.lua' % scale)
    zl = [zones[i] for i in sorted(zones)]
    check(zl == cfg['zones'], 'S.zones differs from tools/sources_config.json (index order must be stable)')
    excluded = set(cfg.get('excluded_zones', {})) | set(cfg.get('city_zones', []))

    # 2. units: shape and values
    for npc, u in units.items():
        u = [u[i] for i in sorted(u)]
        if not check(len(u) == 8, 'unit %d: %d fields, want 8' % (npc, len(u))):
            continue
        name, lo, hi, typ, rank, fac, resp, skin = u
        check(isinstance(name, str) and name, 'unit %d: no name' % npc)
        check(isinstance(lo, int) and isinstance(hi, int) and 0 < lo <= hi <= 63, 'unit %d: levels %r-%r' % (npc, lo, hi))
        check(rank in (0, 1, 2, 3, 4), 'unit %d: rank %r' % (npc, rank))
        check(fac in ('', 'A', 'H', 'AH'), 'unit %d: faction %r' % (npc, fac))
        check(isinstance(resp, int) and resp >= 0, 'unit %d: respawn %r' % (npc, resp))
        check(isinstance(skin, bool), 'unit %d: skinnable flag %r' % (npc, skin))

    # 3. spawns: valid zone indices, open world only, well-formed points, no duplicate points
    for npc, sp in spawns.items():
        check(npc in units, 'spawns %d: creature not in S.units' % npc)
        vals = [sp[i] for i in sorted(sp)]
        check(len(vals) % 2 == 0, 'spawns %d: odd field count' % npc)
        for zi, s in zip(vals[0::2], vals[1::2]):
            if not check(isinstance(zi, int) and 1 <= zi <= len(zl), 'spawns %d: zone index %r' % (npc, zi)):
                continue
            check(zl[zi - 1] not in excluded, 'spawns %d: points in excluded zone %s' % (npc, zl[zi - 1]))
            if not check(isinstance(s, str) and s.isdigit() and len(s) % (2 * digits) == 0 and s,
                         'spawns %d: malformed point string in zone %d' % (npc, zi)):
                continue
            pts = [s[i:i + 2 * digits] for i in range(0, len(s), 2 * digits)]
            check(len(pts) == len(set(pts)), 'spawns %d: duplicate points in zone %d' % (npc, zi))

    # 4. item sources: known creatures with spawn points, sane chances, no duplicates, sorted
    for item, d in items.items():
        check(isinstance(d.get(1), str) and isinstance(d.get(2), str), 'item %d: name/category' % item)
        for method, width in (('skin', 4), ('loot', 2)):
            lst = [d[method][i] for i in sorted(d.get(method) or {})]
            if not check(len(lst) % width == 0, 'item %d %s: list length %d' % (item, method, len(lst))):
                continue
            rows = [lst[i:i + width] for i in range(0, len(lst), width)]
            npcs = [r[0] for r in rows]
            check(len(npcs) == len(set(npcs)), 'item %d %s: duplicate creatures' % (item, method))
            chances = [r[1] for r in rows]
            check(chances == sorted(chances, reverse=True), 'item %d %s: not sorted by chance' % (item, method))
            for r in rows:
                npc, ch = r[0], r[1]
                check(npc in units, 'item %d %s: creature %d not in S.units' % (item, method, npc))
                check(npc in spawns, 'item %d %s: creature %d has no spawn points' % (item, method, npc))
                check(isinstance(ch, (int, float)) and 0 < ch <= 100, 'item %d %s: creature %d chance %r' % (item, method, npc, ch))
                u = units.get(npc) or {}
                check(not DUMMY.search(u.get(1, '')), 'item %d %s: training dummy %d' % (item, method, npc))
                if method == 'skin':
                    check(u.get(8) is True, 'item %d skin: creature %d is not skinnable' % (item, npc))
                    check(1 <= r[2] <= r[3], 'item %d skin: creature %d quantity %r-%r' % (item, npc, r[2], r[3]))
        for npc in (calc.get(item) or {}).values():
            srcs = set()
            for method, width in (('skin', 4), ('loot', 2)):
                lst = [d[method][i] for i in sorted(d.get(method) or {})]
                srcs.update(lst[0::width])
            check(npc in srcs, 'S.calc %d: creature %d is not a source of the item' % (item, npc))
    check(set(int(k) for k in cfg['items']) == set(items), 'S.items differs from the configured item list')

    # 5. vendors placed
    for item, lst in vendors.items():
        for npc in lst.values():
            check(npc in vendor_at, 'vendor %d for item %d has no S.vendorAt' % (npc, item))
            check(npc in units, 'vendor %d for item %d not in S.units' % (npc, item))
    for npc, at in vendor_at.items():
        zi, x, y = at[1], at[2], at[3]
        check(1 <= zi <= len(zl) and 0 <= x <= 100 and 0 <= y <= 100, 'vendorAt %d: %r' % (npc, at))

    # 6. reports: complete accounting, a reason for every rejection, no truncation rules
    manifest = json.load(open(os.path.join(a.reports, 'build_manifest.json')))
    cov = json.load(open(os.path.join(a.reports, 'coverage.json')))
    check(not manifest.get('legacy'), 'reports are from a --legacy build')
    check(manifest['output']['bytes'] == len(text.encode('utf-8')), 'build_manifest.json does not describe this SourceData.lua')
    for want in ('cmangos', 'pfquest'):
        check(manifest[want].get('commit') == cfg['pins'][want], 'manifest: %s commit is not the pinned one' % want)
    rej = collections.Counter()
    with open(os.path.join(a.reports, 'rejected_sources.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            check(r['reason'] and r['detail'], 'rejected row without reason/detail: %r' % r)
            check(not r['reason'].startswith('legacy'), 'legacy rule in a repaired build: %r' % r['reason'])
            rej[(int(r['item']), r['method'])] += 1
    for item, c in cov.items():
        item = int(item)
        d = items[item]
        for method, width in (('skin', 4), ('loot', 2)):
            n = len(d.get(method) or {}) // width
            check(n == c[method + '_kept'], 'coverage %d %s: file has %d, report %d' % (item, method, n, c[method + '_kept']))
            check(c[method + '_kept'] + rej[(item, method)] == c[method + '_candidates'],
                  'coverage %d %s: kept %d + rejected %d != candidates %d' % (item, method, c[method + '_kept'], rej[(item, method)], c[method + '_candidates']))

    # 7. regressions: the G1/G2 defect (Heavy Leather etc. capped at 80 skinners) stays fixed
    for item, at_least in ((4234, 150), (2318, 150), (8170, 150), (4304, 150)):
        n = len(items[item].get('skin') or {}) // 4
        check(n >= at_least, 'regression: item %d has %d skinning sources (old cap was 80)' % (item, n))
    capped = [i for i, d in items.items() for m, w in (('skin', 4), ('loot', 2)) if len(d.get(m) or {}) // w == 80]
    check(len(capped) <= 1, 'items with exactly 80 sources of one kind (old cap?): %r' % capped)

    total = sum(len(v) // 4 for d in items.values() for k, v in d.items() if k == 'skin') + \
        sum(len(v) // 2 for d in items.values() for k, v in d.items() if k == 'loot')
    print('checked %d items, %d sources, %d units, %d creatures with spawns, scale %d' %
          (len(items), total, len(units), len(spawns), scale))
    if FAIL:
        print('%d FAILED:' % len(FAIL))
        for f in FAIL[:200]:
            print('  ' + f)
        sys.exit(1)
    print('all checks passed (static file checks; not a live-client test)')


if __name__ == '__main__':
    main()
