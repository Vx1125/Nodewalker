#!/usr/bin/env python3
"""Nodewalker source data generator: writes Materials/SourceData.lua.

Inputs, both pinned by git commit, are recorded in the build manifest:
  cMaNGOS classic-db (GPL-3.0)  Full_DB/ClassicDB_*.sql.gz: creature levels, types, ranks,
                                 skinning loot, creature loot references.
  pfQuest (MIT, Shagu)           db/*.lua: creature spawns, ordinary loot chances, vendors, names,
                                 and, for the items in object_items only, world objects (O) and their spawns.
Both are WoW Classic 1.12 data, not WoW Forever data.

Rules (see tools/README.md):
  * Every source relationship found upstream is either written to SourceData.lua or written to
    reports/rejected_sources.csv with a reason. Nothing is dropped silently, and nothing is
    truncated by rank or count. The build fails if kept + rejected != candidates.
  * Skinning comes only from skinning_loot_template, via creature_template.SkinningLootId.
    Ordinary loot comes only from creature loot (pfQuest U, plus cMaNGOS reference tables).
    A creature being skinnable never makes its ordinary loot "skinning".
  * Spawn points: pfQuest coordinates in the configured open-world zones. Records at the same
    point (to 0.1% of the map) are merged; distinct points are kept.

  --legacy reproduces the old generator's rules (1% cells, loot chance >= 1%, top 80 sources by
  chance x spawn cells) so the old file can be compared and the defect demonstrated.

Usage:
  python tools/build_sources.py --cmangos <classic-db checkout> --pfquest <pfQuest checkout>
         [--out Materials/SourceData.lua] [--reports tools/reports] [--cache <dir>] [--legacy]
Python 3.8+, standard library only. Not part of the packaged addon.
"""
import argparse, collections, csv, datetime, glob, gzip, hashlib, io, json, math, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# creature_template columns in ClassicDB_1_12_1_z2815 (checked against its CREATE TABLE)
CT_ENTRY, CT_NAME, CT_MINLVL, CT_MAXLVL, CT_FACTION, CT_TYPE, CT_RANK, CT_LOOT, CT_SKIN = 0, 1, 3, 4, 9, 12, 33, 56, 58
CT_TFLAGS = 20  # CreatureTypeFlags
# The skinning loot table also holds what Herbalism, Mining and Engineering take
# from creatures flagged for them (CreatureTypeFlags 0x100, 0x200, 0x8000): those
# aren't skinning. Critters (type 8) are left out too (a Sheep "skinned" for Wool
# Cloth in the source data).
GATHER_FLAGS = 0x100 | 0x200 | 0x8000
CRITTER = 8


def really_skinned(r):
    return (r[CT_SKIN] or 0) > 0 and not ((r[CT_TFLAGS] or 0) & GATHER_FLAGS) and r[CT_TYPE] != CRITTER
# *_loot_template columns: entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition, comments
LT_ENTRY, LT_ITEM, LT_CHANCE, LT_GROUP, LT_MINREF, LT_MAX = 0, 1, 2, 3, 4, 5

LEGACY_CAP = 80
LEGACY_MIN_LOOT_CHANCE = 1.0
DUMMY = re.compile(r'\b(target|training|practice|combat)\s+dummy\b|\bdummy\b', re.I)


# ----------------------------------------------------------------------------------------------
# Reading the inputs
# ----------------------------------------------------------------------------------------------
def sql_rows(stream, tables):
    """Parse MySQL dump INSERT statements for the named tables. Returns {table: [row, ...]}."""
    want = {t: [] for t in tables}
    pat = re.compile(r"INSERT INTO `(\w+)` VALUES ")
    for line in stream:
        m = pat.match(line)
        if not m or m.group(1) not in want:
            continue
        out = want[m.group(1)]
        s, i, n = line, m.end(), len(line)
        while i < n:
            if s[i] != '(':
                i += 1
                continue
            i += 1
            row, cur, quoted, isstr = [], [], False, False
            while True:
                c = s[i]
                if quoted:
                    if c == '\\':
                        cur.append(s[i + 1]); i += 2; continue
                    if c == "'":
                        if i + 1 < n and s[i + 1] == "'":
                            cur.append("'"); i += 2; continue
                        quoted = False; i += 1; continue
                    cur.append(c); i += 1; continue
                if c == "'":
                    quoted, isstr = True, True; i += 1; continue
                if c in ',)':
                    v = ''.join(cur).strip()
                    if isstr:
                        row.append(v)
                    elif v == 'NULL':
                        row.append(None)
                    else:
                        try:
                            row.append(int(v))
                        except ValueError:
                            row.append(float(v))
                    cur, isstr = [], False
                    i += 1
                    if c == ')':
                        break
                    continue
                cur.append(c); i += 1
            out.append(row)
    return want


def git_head(path):
    try:
        return subprocess.check_output(['git', '-C', path, 'rev-parse', 'HEAD'], text=True,
                                       stderr=subprocess.DEVNULL).strip()
    except Exception:
        return None


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def load_cmangos(root, cache):
    dumps = sorted(glob.glob(os.path.join(root, 'Full_DB', 'ClassicDB_*.sql.gz')))
    if not dumps:
        sys.exit('no Full_DB/ClassicDB_*.sql.gz under ' + root)
    dump = dumps[-1]
    tables = ['creature_template', 'creature_loot_template', 'skinning_loot_template', 'reference_loot_template']
    key = sha256(dump)
    cpath = cache and os.path.join(cache, 'cmangos-%s.json' % key[:16])
    if cpath and os.path.exists(cpath):
        data = json.load(open(cpath))
    else:
        with gzip.open(dump, 'rt', encoding='utf-8', errors='replace') as f:
            data = sql_rows(f, tables)
        if cpath:
            os.makedirs(cache, exist_ok=True)
            json.dump(data, open(cpath, 'w'))
    return data, {'path': os.path.relpath(dump, root).replace('\\', '/'), 'sha256': key, 'commit': git_head(root)}


# pfQuest db files are Lua table literals; a small reader turns them into Python values.
_WS = re.compile(r'(?:\s+|--[^\n]*)*')
_STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
_NUM = re.compile(r'-?\d+(?:\.\d+)?(?:[eE]-?\d+)?')
_KW = re.compile(r'true|false|nil')
_NAMEKEY = re.compile(r'([A-Za-z_]\w*)\s*=')
_ESC = re.compile(r'\\(.)')


def lua_value(t, i):
    i = _WS.match(t, i).end()
    c = t[i]
    if c == '{':
        i += 1
        d, n = {}, 1
        while True:
            i = _WS.match(t, i).end()
            if t[i] == '}':
                return d, i + 1
            if t[i] == '[':
                k, i = lua_value(t, i + 1)
                i = _WS.match(t, i).end()
                if t[i] != ']':
                    raise ValueError('bad key at %d' % i)
                i = _WS.match(t, i + 1).end()
                if t[i] != '=':
                    raise ValueError('bad table at %d' % i)
                v, i = lua_value(t, i + 1)
                d[k] = v
            else:
                m = _NAMEKEY.match(t, i)
                if m:
                    v, i = lua_value(t, m.end())
                    d[m.group(1)] = v
                else:
                    v, i = lua_value(t, i)
                    d[n] = v
                    n += 1
            i = _WS.match(t, i).end()
            if t[i] in ',;':
                i += 1
    if c == '"':
        m = _STR.match(t, i)
        return _ESC.sub(lambda x: x.group(1), m.group(1)), m.end()
    m = _NUM.match(t, i)
    if m:
        s = m.group(0)
        return (float(s) if ('.' in s or 'e' in s.lower()) else int(s)), m.end()
    m = _KW.match(t, i)
    if not m:
        raise ValueError('unexpected %r at %d' % (t[i:i + 20], i))
    return {'true': True, 'false': False, 'nil': None}[m.group(0)], m.end()


def lua_assign(path, marker):
    t = open(path, encoding='utf-8', errors='replace').read()
    i = t.index(marker) + len(marker)
    return lua_value(t, t.index('{', i))[0]


def load_pfquest(root, cache):
    db = os.path.join(root, 'db')
    files = {
        'items': ('items.lua', 'pfDB["items"]["data"]'),
        'units': ('units.lua', 'pfDB["units"]["data"]'),
        'refloot': ('refloot.lua', 'pfDB["refloot"]["data"]'),
        'zone_names': ('enUS/zones.lua', 'pfDB["zones"]["enUS"]'),
        'unit_names': ('enUS/units.lua', 'pfDB["units"]["enUS"]'),
        'item_names': ('enUS/items.lua', 'pfDB["items"]["enUS"]'),
        'objects': ('objects.lua', 'pfDB["objects"]["data"]'),
        'object_names': ('enUS/objects.lua', 'pfDB["objects"]["enUS"]'),
    }
    out, sums = {}, {}
    for k, (f, marker) in files.items():
        p = os.path.join(db, f)
        sums[f] = sha256(p)
        cpath = cache and os.path.join(cache, 'pfq-%s-%s.json' % (k, sums[f][:16]))
        if cpath and os.path.exists(cpath):
            v = json.load(open(cpath))
        else:
            v = lua_assign(p, marker)
            if cpath:
                os.makedirs(cache, exist_ok=True)
                json.dump(v, open(cpath, 'w'))
        out[k] = intkeys(v)
    return out, {'commit': git_head(root), 'files': sums}


def intkeys(v):
    if isinstance(v, dict):
        return {(int(k) if isinstance(k, str) and k.lstrip('-').isdigit() else k): intkeys(x) for k, x in v.items()}
    return v


# ----------------------------------------------------------------------------------------------
# Loot probability helpers (cMaNGOS semantics)
# ----------------------------------------------------------------------------------------------
def group_chance(rows, row):
    """Chance (%) that `row` drops from its loot table, honouring groups.
    Group 0: each row rolls its own chance. Group N > 0: one row of the group drops; rows with
    chance 0 share what the explicit chances leave, equally. Returns (chance, calculated)."""
    c = abs(row[LT_CHANCE])
    if row[LT_GROUP] == 0 or c > 0:
        return c, False
    same = [r for r in rows if r[LT_GROUP] == row[LT_GROUP]]
    explicit = sum(abs(r[LT_CHANCE]) for r in same if r[LT_CHANCE] != 0)
    zeros = sum(1 for r in same if r[LT_CHANCE] == 0)
    return max(0.0, 100.0 - explicit) / max(1, zeros), True


def ref_item_chance(ref_tables, ref, item, depth=0):
    """Chance (%) that one roll of reference table `ref` yields `item` (nested references followed)."""
    if depth > 4:
        return 0.0
    rows = ref_tables.get(ref, [])
    miss = 1.0
    for r in rows:
        if r[LT_MINREF] < 0:
            p_row = group_chance(rows, r)[0] / 100.0
            p_in = ref_item_chance(ref_tables, -r[LT_MINREF], item, depth + 1) / 100.0
            rolls = max(1, r[LT_MAX] or 1)
            miss *= 1 - p_row * (1 - (1 - p_in) ** rolls)
        elif r[LT_ITEM] == item:
            miss *= 1 - group_chance(rows, r)[0] / 100.0
    return (1 - miss) * 100.0


# ----------------------------------------------------------------------------------------------
# Build
# ----------------------------------------------------------------------------------------------
class Build:
    def __init__(self, cm, pf, cfg, legacy):
        self.cfg, self.legacy = cfg, legacy
        self.ct = {r[CT_ENTRY]: r for r in cm['creature_template']}
        self.pf = pf
        self.zones = cfg['zones']
        self.zone_idx = {z: i + 1 for i, z in enumerate(self.zones)}
        self.excluded_zones = cfg.get('excluded_zones', {})
        self.city_zones = set(cfg.get('city_zones', []))   # vendors only: creature points there are not hunting grounds
        self.items = {int(k): v for k, v in cfg['items'].items()}
        self.rejected = []          # (item, method, npc, chance, reason, detail)
        self.kept = collections.defaultdict(lambda: {'skin': [], 'loot': [], 'obj': []})
        self.object_items = set(int(i) for i in cfg.get('object_items', []))
        self.candidates = collections.Counter()
        self.calc = collections.defaultdict(set)   # item -> npcs whose chance was calculated
        self.cm = cm
        self._place = {}
        self.coord_stats = collections.Counter()

    # spawn points per zone for one creature, after the zone and coordinate checks
    def placement(self, npc, obj=False):
        key = ('o', npc) if obj else npc
        if key in self._place:
            return self._place[key]
        u = self.pf['objects' if obj else 'units'].get(npc) or {}
        by_zone = collections.OrderedDict()
        bad, other, bg, city, recs = 0, collections.Counter(), 0, 0, 0
        for _, p in sorted((u.get('coords') or {}).items()):
            x, y, zid = p.get(1), p.get(2), p.get(3)
            zname = self.pf['zone_names'].get(zid)
            if not isinstance(x, (int, float)) or not isinstance(y, (int, float)) or not (0 <= x <= 100 and 0 <= y <= 100):
                bad += 1
                continue
            if zname in self.excluded_zones:
                bg += 1
                continue
            if zname not in self.zone_idx:
                other[zname or ('zone %s' % zid)] += 1
                continue
            if zname in self.city_zones:
                city += 1
                continue
            recs += 1
            if self.legacy:
                pt = (min(99, int(math.floor(x))), min(99, int(math.floor(y))))
            else:
                pt = (min(999, int(round(x * 10))), min(999, int(round(y * 10))))
            by_zone.setdefault(self.zone_idx[zname], []).append(pt)
        cells = collections.OrderedDict()
        for zi, pts in sorted(by_zone.items()):
            seen, keep = set(), []
            for pt in pts:
                if pt not in seen:
                    seen.add(pt)
                    keep.append(pt)
            cells[zi] = keep
        res = {'cells': cells, 'n': sum(len(v) for v in cells.values()), 'records': recs, 'bad': bad,
               'other': other, 'battleground': bg, 'city': city, 'respawn': self.respawn(u)}
        self._place[key] = res
        return res

    @staticmethod
    def respawn(u):
        for _, p in sorted((u.get('coords') or {}).items()):
            if isinstance(p.get(4), (int, float)):
                return int(p[4])
        return 0

    def reject(self, item, method, npc, chance, reason, detail=''):
        self.rejected.append((item, method, npc, chance, reason, detail))

    # a candidate (item, method, npc, chance) passes the shared checks or is rejected with a reason
    def check(self, item, method, npc, chance, qmin=1, qmax=1):
        self.candidates[(item, method)] += 1
        r = self.ct.get(npc)
        if not r:
            return self.reject(item, method, npc, chance, 'unknown-creature', 'not in cMaNGOS creature_template')
        name = r[CT_NAME] or ''
        if DUMMY.search(name):
            return self.reject(item, method, npc, chance, 'training-dummy', name)
        if chance is None or chance < 0:
            return self.reject(item, method, npc, chance, 'quest-only', 'negative chance: drops only on a quest')
        if chance == 0 or chance > 100:
            return self.reject(item, method, npc, chance, 'impossible-probability', 'chance %r' % chance)
        if not (1 <= qmin <= qmax):
            return self.reject(item, method, npc, chance, 'bad-quantity', '%r-%r' % (qmin, qmax))
        if method == 'skin' and not (r[CT_SKIN] or 0) > 0:
            return self.reject(item, method, npc, chance, 'not-skinnable', 'SkinningLootId 0')
        if method == 'skin' and not really_skinned(r):
            return self.reject(item, method, npc, chance, 'gathered-or-critter',
                               'herb/mine/salvage creature or critter (flags %d, type %d)' % (r[CT_TFLAGS] or 0, r[CT_TYPE]))
        pl = self.placement(npc)
        if pl['n'] == 0:
            why = []
            if pl['battleground']:
                why.append('battleground x%d' % pl['battleground'])
            if pl['other']:
                why.append('outside open-world zones: ' + ', '.join('%s x%d' % kv for kv in pl['other'].most_common(4)))
            if pl['city']:
                why.append('capital city x%d' % pl['city'])
            if pl['bad']:
                why.append('invalid coordinates x%d' % pl['bad'])
            if not why:
                reason = 'no-spawns'
            elif pl['other'] and not (pl['battleground'] or pl['city'] or pl['bad']):
                reason = 'instance-or-other-zone'
            elif pl['battleground'] and not (pl['other'] or pl['city'] or pl['bad']):
                reason = 'battleground'
            elif pl['city'] and not (pl['other'] or pl['battleground'] or pl['bad']):
                reason = 'city-only'
            else:
                reason = 'unplaceable'
            return self.reject(item, method, npc, chance, reason, '; '.join(why) or
                               'pfQuest has no coordinates (pfQuest omits dungeon and raid creatures; also unused templates)')
        if self.legacy and method == 'loot' and chance < LEGACY_MIN_LOOT_CHANCE:
            return self.reject(item, method, npc, chance, 'legacy-min-chance', '< 1%')
        return True

    def skin_sources(self):
        rows_by_tpl = collections.defaultdict(list)
        for r in self.cm['skinning_loot_template']:
            rows_by_tpl[r[LT_ENTRY]].append(r)
        users = collections.defaultdict(list)
        for e, r in self.ct.items():
            if (r[CT_SKIN] or 0) > 0:
                users[r[CT_SKIN]].append(e)
        orphan_tpl = set(rows_by_tpl) - set(users)
        for item in self.items:
            seen = set()
            for tpl, rows in sorted(rows_by_tpl.items()):
                for row in rows:
                    if row[LT_MINREF] < 0:
                        if ref_item_chance(self.ref_tables, -row[LT_MINREF], item) > 0:
                            self.reject(item, 'skin', None, None, 'unsupported-reference', 'skinning template %d uses reference %d' % (tpl, -row[LT_MINREF]))
                        continue
                    if row[LT_ITEM] != item:
                        continue
                    chance, calculated = group_chance(rows, row)
                    if row[LT_CHANCE] < 0:
                        chance = row[LT_CHANCE]
                    if tpl in orphan_tpl:
                        self.candidates[(item, 'skin')] += 1
                        self.reject(item, 'skin', None, chance, 'orphan-template', 'skinning template %d has no creature' % tpl)
                        continue
                    for npc in users[tpl]:
                        if (npc, item) in seen:
                            self.candidates[(item, 'skin')] += 1
                            self.reject(item, 'skin', npc, chance, 'duplicate', 'template %d' % tpl)
                            continue
                        seen.add((npc, item))
                        if self.check(item, 'skin', npc, chance, row[LT_MINREF], row[LT_MAX]) is True:
                            self.kept[item]['skin'].append((npc, chance, row[LT_MINREF], row[LT_MAX], 'cmangos'))
                            if calculated:
                                self.calc[item].add(npc)

    def loot_sources(self):
        # creature loot rows that point at a reference table, by creature
        loot_rows = collections.defaultdict(list)
        for r in self.cm['creature_loot_template']:
            loot_rows[r[LT_ENTRY]].append(r)
        lootid_users = collections.defaultdict(list)
        for e, r in self.ct.items():
            if (r[CT_LOOT] or 0) > 0:
                lootid_users[r[CT_LOOT]].append(e)
        for item in self.items:
            U = ((self.pf['items'].get(item) or {}).get('U')) or {}
            seen = set()
            for npc, chance in sorted(U.items()):
                seen.add(npc)
                if self.check(item, 'loot', npc, chance) is True:
                    self.kept[item]['loot'].append((npc, chance, 1, 1, 'pfquest'))
            # pfQuest R: creatures that reach the item through one of pfQuest's reference tables. pfQuest
            # gives no chance for these; they are reported, never written with an invented chance,
            # unless cMaNGOS (below) supplies one.
            R = ((self.pf['items'].get(item) or {}).get('R')) or {}
            pf_ref = {}
            for ref in sorted(R):
                for npc in sorted(((self.pf['refloot'].get(ref) or {}).get('U')) or {}):
                    pf_ref.setdefault(npc, ref)
            if self.legacy:
                for npc, ref in sorted(pf_ref.items()):
                    if npc not in seen:
                        self.candidates[(item, 'loot')] += 1
                        self.reject(item, 'loot', npc, None, 'legacy-reference-ignored', 'pfQuest reference %d' % ref)
                continue
            # creatures that reach the item only through a reference table (pfQuest lists these
            # under R/refloot without a chance): chance calculated from cMaNGOS
            for lootid, rows in loot_rows.items():
                for row in rows:
                    if row[LT_MINREF] >= 0:
                        continue
                    p_in = ref_item_chance(self.ref_tables, -row[LT_MINREF], item)
                    if p_in <= 0:
                        continue
                    p_row = group_chance(rows, row)[0] / 100.0
                    rolls = max(1, row[LT_MAX] or 1)
                    chance = round(p_row * (1 - (1 - p_in / 100.0) ** rolls) * 100.0, 4)
                    for npc in lootid_users.get(lootid, []):
                        if npc in seen:
                            continue
                        seen.add(npc)
                        if self.check(item, 'loot', npc, chance) is True:
                            self.kept[item]['loot'].append((npc, chance, 1, 1, 'cmangos-ref'))
                            self.calc[item].add(npc)
            for npc, ref in sorted(pf_ref.items()):
                if npc in seen:
                    continue
                seen.add(npc)
                self.candidates[(item, 'loot')] += 1
                self.reject(item, 'loot', npc, None, 'reference-no-chance',
                            'pfQuest reference %d; no cMaNGOS reference table at the pinned commit gives this item a chance' % ref)

    # world objects (pfQuest O) for the items listed in object_items: crystals and the like that
    # you pick up in the open world. Chests and containers are never listed there.
    def obj_sources(self):
        for item in sorted(self.object_items):
            O = ((self.pf['items'].get(item) or {}).get('O')) or {}
            seen = {}
            for obj, chance in sorted(O.items()):
                self.candidates[(item, 'obj')] += 1
                name = self.pf['object_names'].get(obj)
                if not name:
                    self.reject(item, 'obj', obj, chance, 'unknown-object', 'not in pfQuest object names')
                    continue
                if chance is None or chance <= 0 or chance > 100:
                    self.reject(item, 'obj', obj, chance, 'impossible-probability', 'chance %r' % chance)
                    continue
                pl = self.placement(obj, True)
                if pl['n'] == 0:
                    self.reject(item, 'obj', obj, chance, 'no-spawns', 'no open-world coordinates')
                    continue
                sig = tuple((zi, tuple(p)) for zi, p in pl['cells'].items())
                if sig in seen:
                    self.reject(item, 'obj', obj, chance, 'duplicate-spawns', 'same points as object %d' % seen[sig])
                    continue
                seen[sig] = obj
                self.kept[item]['obj'].append((obj, chance, 1, 1, 'pfquest'))

    def legacy_cap(self):
        for item, d in self.kept.items():
            for method in ('skin', 'loot'):
                lst = d[method]
                if len(lst) <= LEGACY_CAP:
                    continue
                lst.sort(key=lambda s: -(s[1] * self.placement(s[0])['n']))
                for s in lst[LEGACY_CAP:]:
                    self.reject(item, method, s[0], s[1], 'legacy-cap-80', 'score %.2f' % (s[1] * self.placement(s[0])['n']))
                d[method] = lst[:LEGACY_CAP]

    def vendors(self):
        out, at = {}, {}
        for item in self.cfg.get('vendor_items', []):
            V = ((self.pf['items'].get(item) or {}).get('V')) or {}
            npcs = []
            for npc in sorted(V):
                u = self.pf['units'].get(npc) or {}
                spot = None
                for _, p in sorted((u.get('coords') or {}).items()):
                    zname = self.pf['zone_names'].get(p.get(3))
                    if zname in self.zone_idx:
                        spot = (self.zone_idx[zname], p[1], p[2])
                        break
                if not spot:
                    self.candidates[(item, 'vendor')] += 1
                    self.reject(item, 'vendor', npc, None, 'unplaceable', 'vendor outside open-world zones')
                    continue
                if npc not in self.ct:
                    self.candidates[(item, 'vendor')] += 1
                    self.reject(item, 'vendor', npc, None, 'unknown-creature', '')
                    continue
                self.candidates[(item, 'vendor')] += 1
                npcs.append(npc)
                at[npc] = spot
            if npcs:
                out[item] = npcs
        return out, at

    def run(self):
        # config items unknown upstream: reported, still written (with no sources) so the UI keeps them
        self.unknown_items = sorted(i for i in self.items if i not in self.pf['item_names'])
        self.ref_tables = collections.defaultdict(list)
        for r in self.cm['reference_loot_template']:
            self.ref_tables[r[LT_ENTRY]].append(r)
        self.skin_sources()
        self.loot_sources()
        if not self.legacy:
            self.obj_sources()
        if self.legacy:
            self.legacy_cap()
        self.vend, self.vend_at = self.vendors()
        # every unit that any kept record names
        npcs = set()
        for d in self.kept.values():
            for m in ('skin', 'loot'):
                npcs.update(s[0] for s in d[m])
        npcs.update(self.vend_at)
        self.units = {}
        for npc in sorted(npcs):
            r = self.ct[npc]
            pfu = self.pf['units'].get(npc) or {}
            name = self.pf['unit_names'].get(npc) or r[CT_NAME]
            self.units[npc] = (name, r[CT_MINLVL], r[CT_MAXLVL], r[CT_TYPE], r[CT_RANK], pfu.get('fac') or '',
                               self.placement(npc)['respawn'], really_skinned(r))
        objs = set()
        for d in self.kept.values():
            objs.update(s[0] for s in d['obj'])
        self.objects = {o: (self.pf['object_names'][o], self.placement(o, True)['respawn']) for o in sorted(objs)}
        self.integrity()

    def integrity(self):
        """kept + rejected must equal candidates for every item and method: no silent loss."""
        kept = collections.Counter()
        for item, d in self.kept.items():
            for m in ('skin', 'loot', 'obj'):
                kept[(item, m)] += len(d[m])
        for item, npcs in self.vend.items():
            kept[(item, 'vendor')] += len(npcs)
        rej = collections.Counter((r[0], r[1]) for r in self.rejected if r[4] != 'unsupported-reference')
        bad = [(k, n, kept[k], rej[k]) for k, n in self.candidates.items() if kept[k] + rej[k] != n]
        if bad:
            sys.exit('integrity: kept + rejected != candidates for %r' % bad[:10])


# ----------------------------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------------------------
def num(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int) or float(v).is_integer():
        return str(int(v))
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return s


def luastr(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def chance_out(c, legacy, method):
    if legacy and method == 'skin':
        return round(c, 1)
    if c >= 1:
        return round(c, 2)
    return float('%.2g' % c)          # small chances keep two significant figures


def write_lua(b, path, manifest):
    scale = 100 if b.legacy else 1000
    w = 2 if b.legacy else 3
    L = []
    L.append('local _, NW = ...')
    L.append('-- Generated by tools/build_sources.py. Do not edit by hand.')
    L.append('-- WoW Classic 1.12 data, not WoW Forever data: creatures, spawns and chances may differ in game.')
    L.append('--   pfQuest (MIT, Shagu) @ %s: creature spawns, ordinary loot chances, vendors.' % (manifest['pfquest']['commit'] or '?')[:12])
    L.append('--   cMaNGOS classic-db (GPL-3.0) @ %s: creature levels and types, skinning loot,' % (manifest['cmangos']['commit'] or '?')[:12])
    L.append('--     loot reached through reference tables (chances in S.calc are calculated, not listed upstream).')
    L.append('-- Complete: every source upstream is here or in tools/reports/rejected_sources.csv with a reason.')
    L.append('NW.SRC = {}')
    L.append('local S = NW.SRC')
    L.append('S.zones = {%s}' % ','.join(luastr(z) for z in b.zones))
    L.append('-- spawn strings: %d digits for x then %d for y per point; position = (value + 0.5) / %d of the map' % (w, w, scale))
    L.append('S.coordScale = %d' % scale)
    L.append('-- [npc] = { name, minLevel, maxLevel, type, rank, faction, respawn seconds, skinnable }')
    L.append('S.units = {')
    for npc, u in b.units.items():
        L.append('[%d]={%s,%s,%s,%s,%s,%s,%s,%s},' % (npc, luastr(u[0]), num(u[1]), num(u[2]), num(u[3]), num(u[4]),
                                                    luastr(u[5]), num(u[6]), num(u[7])))
    L.append('}')
    L.append('-- [npc] = { zone index, "points", ... }')
    L.append('S.spawns = {')
    for npc in b.units:
        cells = b.placement(npc)['cells']
        if not cells:
            continue
        parts = []
        for zi, pts in cells.items():
            parts.append('%d,"%s"' % (zi, ''.join('%0*d%0*d' % (w, x, w, y) for x, y in pts)))
        L.append('[%d]={%s},' % (npc, ','.join(parts)))
    L.append('}')
    if b.objects:
        L.append('-- world objects you pick up (pfQuest O, only for config object_items): [object] = { name, respawn seconds }')
        L.append('S.objects = {')
        for o, (name, rs) in b.objects.items():
            L.append('[%d]={%s,%s},' % (o, luastr(name), num(rs)))
        L.append('}')
        L.append('-- [object] = { zone index, "points", ... }')
        L.append('S.ospawns = {')
        for o in b.objects:
            parts = ['%d,"%s"' % (zi, ''.join('%0*d%0*d' % (w, x, w, y) for x, y in pts)) for zi, pts in b.placement(o, True)['cells'].items()]
            L.append('[%d]={%s},' % (o, ','.join(parts)))
        L.append('}')
    L.append('-- [item] = { name, category, loot = { npc, chance, ... }, skin = { npc, chance, min, max, ... }, obj = { object, chance, ... } }')
    L.append('-- sorted by chance; chances are percent')
    L.append('S.items = {')
    for item in sorted(b.items):
        cat, name = b.items[item]
        d = b.kept.get(item) or {'skin': [], 'loot': []}
        skin = sorted(d['skin'], key=lambda s: (-s[1], s[0]))
        loot = sorted(d['loot'], key=lambda s: (-s[1], s[0]))
        sk = ','.join('%d,%s,%d,%d' % (s[0], num(chance_out(s[1], b.legacy, 'skin')), s[2], s[3]) for s in skin)
        lo = ','.join('%d,%s' % (s[0], num(chance_out(s[1], b.legacy, 'loot'))) for s in loot)
        ob = ','.join('%d,%s' % (s[0], num(chance_out(s[1], b.legacy, 'loot'))) for s in sorted(d.get('obj', []), key=lambda s: (-s[1], s[0])))
        L.append('[%d]={%s,%s,loot={%s},skin={%s}%s},' % (item, luastr(name), luastr(cat), lo, sk, (',obj={%s}' % ob) if ob else ''))
    L.append('}')
    L.append('-- [item] = { npc, ... } whose chance was calculated (cMaNGOS groups or reference tables)')
    L.append('S.calc = {')
    for item in sorted(b.calc):
        L.append('[%d]={%s},' % (item, ','.join(str(n) for n in sorted(b.calc[item]))))
    L.append('}')
    L.append('-- [item] = { vendor npc, ... }')
    L.append('S.vendors = {')
    for item in sorted(b.vend):
        L.append('[%d]={%s},' % (item, ','.join(str(n) for n in b.vend[item])))
    L.append('}')
    L.append('-- [npc] = { zone index, x, y }')
    L.append('S.vendorAt = {')
    for npc in sorted(b.vend_at):
        zi, x, y = b.vend_at[npc]
        L.append('[%d]={%d,%s,%s},' % (npc, zi, num(x), num(y)))
    L.append('}')
    text = '\n'.join(L) + '\n'
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    return len(text.encode('utf-8'))


def write_reports(b, rdir, manifest):
    os.makedirs(rdir, exist_ok=True)
    names = b.pf['unit_names']
    sfx = '_legacy' if b.legacy else ''
    with open(os.path.join(rdir, 'rejected_sources%s.csv' % sfx), 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        w.writerow(['item', 'item_name', 'method', 'npc', 'npc_name', 'chance', 'reason', 'detail'])
        for item, method, npc, chance, reason, detail in sorted(b.rejected, key=lambda r: (r[0], r[1], r[4], r[2] or 0)):
            w.writerow([item, b.items.get(item, ['', ''])[1], method, npc if npc is not None else '',
                        names.get(npc, '') if npc else '', '' if chance is None else chance, reason, detail])
    reasons = collections.Counter((r[1], r[4]) for r in b.rejected)
    cov = {}
    for item in sorted(b.items):
        d = b.kept.get(item) or {'skin': [], 'loot': [], 'obj': []}
        cov[item] = {
            'name': b.items[item][1],
            'skin_candidates': b.candidates[(item, 'skin')], 'skin_kept': len(d['skin']),
            'loot_candidates': b.candidates[(item, 'loot')], 'loot_kept': len(d['loot']),
            'vendor_kept': len(b.vend.get(item, [])),
        }
        if item in b.object_items:
            cov[item].update({'obj_candidates': b.candidates[(item, 'obj')], 'obj_kept': len(d['obj'])})
    manifest['counts'] = {
        'items': len(b.items), 'units': len(b.units), 'vendors': sum(len(v) for v in b.vend.values()),
        'skin_kept': sum(len(d['skin']) for d in b.kept.values()), 'loot_kept': sum(len(d['loot']) for d in b.kept.values()),
        'obj_kept': sum(len(d['obj']) for d in b.kept.values()), 'objects': len(b.objects),
        'rejected': len(b.rejected), 'config_items_unknown_upstream': b.unknown_items, 'rejected_by_reason': {'%s/%s' % k: v for k, v in sorted(reasons.items())},
        'spawn_records_open_world': sum(b.placement(n)['records'] for n in b.units),
        'spawn_points_written': sum(b.placement(n)['n'] for n in b.units),
    }
    json.dump(cov, open(os.path.join(rdir, 'coverage%s.json' % sfx), 'w'), indent=1)
    json.dump(manifest, open(os.path.join(rdir, 'build_manifest%s.json' % sfx), 'w'), indent=1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--cmangos', required=True, help='classic-db checkout (Full_DB/ClassicDB_*.sql.gz)')
    ap.add_argument('--pfquest', required=True, help='pfQuest checkout (db/*.lua)')
    ap.add_argument('--config', default=os.path.join(HERE, 'sources_config.json'))
    ap.add_argument('--out', default=os.path.join(ROOT, 'Materials', 'SourceData.lua'))
    ap.add_argument('--reports', default=os.path.join(HERE, 'reports'))
    ap.add_argument('--cache', default=None, help='directory for parsed-input caches')
    ap.add_argument('--legacy', action='store_true', help="reproduce the old generator's rules (for comparison only)")
    a = ap.parse_args()
    cfg = json.load(open(a.config, encoding='utf-8'))
    cm, cm_meta = load_cmangos(a.cmangos, a.cache)
    pf, pf_meta = load_pfquest(a.pfquest, a.cache)
    manifest = {'generated': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                'legacy': a.legacy, 'cmangos': cm_meta, 'pfquest': pf_meta,
                'config_sha256': sha256(a.config)}
    for want, meta in (('cmangos', cm_meta), ('pfquest', pf_meta)):
        pin = cfg.get('pins', {}).get(want)
        if pin and meta.get('commit') and meta['commit'] != pin:
            sys.exit('%s checkout is %s, config pins %s' % (want, meta['commit'], pin))
    b = Build(cm, pf, cfg, a.legacy)
    b.run()
    size = write_lua(b, a.out, manifest)
    manifest['output'] = {'path': os.path.basename(a.out), 'bytes': size}
    write_reports(b, a.reports, manifest)
    c = manifest['counts']
    print('wrote %s: %d bytes, %d units, %d skin + %d loot sources, %d rejected' %
          (a.out, size, c['units'], c['skin_kept'], c['loot_kept'], c['rejected']))


if __name__ == '__main__':
    main()
