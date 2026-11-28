#!/usr/bin/env python3
"""Static checks of the recipe data, and an audit of recipe reagents against the Material Finder.

These are offline file checks. They are NOT live-client tests: they do not run the addon, and they
cannot tell whether Forever's real recipes match the files.

  R(name, orange, yellow, green, grey, src, id, "reagents", yield)    Professions/<prof>.lua
  C(name, learn, yellow, green, grey, id, recipeItem, fee, where, "reagents", yield)
                                                                      Professions/Catalog.lua

Errors (exit 1) are rows the addon would misread: wrong arity or types, unreadable reagent strings,
non-positive quantities, or a broken material-finder regression. Pre-existing data issues, such as
colour thresholds out of order, duplicate names, or reagents the Material Finder can't source, are
reported in tools/reports/recipe_audit.md. They are not fixed here.

Usage: python tools/test_recipes.py [--report tools/reports/recipe_audit.md]
"""
import argparse, collections, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from build_sources import lua_value

PROF = os.path.join(ROOT, 'Professions')
REAGENTS = re.compile(r'^(\d+:\d+)(,\d+:\d+)*$')
ERR, WARN = [], collections.defaultdict(list)


def args_of(s):
    """Split a Lua argument list of string, number and nil literals."""
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c in ' \t,':
            i += 1
        elif c == '"':
            j = i + 1
            while s[j] != '"':
                j += 2 if s[j] == '\\' else 1
            out.append(s[i + 1:j].replace('\\"', '"').replace('\\\\', '\\'))
            i = j + 1
        else:
            m = re.match(r'nil|true|false|-?\d+(\.\d+)?', s[i:])
            if not m:
                raise ValueError('unreadable argument at %r' % s[i:i + 20])
            t = m.group(0)
            out.append(None if t == 'nil' else t == 'true' if t in ('true', 'false') else
                       (float(t) if '.' in t else int(t)))
            i += len(t)
    return out


def rows(path, fn):
    """(line, profession key, args) for each top-level fn(...) call in a file."""
    key = None
    adder = re.compile(r'^(?:local\s+)?%s\s*=\s*NW\.(?:Recipe|Catalog)Adder\("(\w+)"\)' % fn)
    call = re.compile(r'^\s*%s\((.*)\)\s*(--.*)?$' % fn)
    for ln, line in enumerate(open(path, encoding='utf-8'), 1):
        m = adder.match(line)
        if m:
            key = m.group(1)
            continue
        m = call.match(line)
        if m:
            try:
                yield ln, key, args_of(m.group(1))
            except (ValueError, IndexError) as e:
                ERR.append('%s:%d: %s' % (os.path.basename(path), ln, e))


def smelt_rows():
    """Mining.lua's S(name, learn, src, item, "reagents", yield) rows, as R rows: colours from
    SmeltingColours.lua (CC BY-SA, kept apart), else the learn level, as Mining.lua does at load."""
    cols = {}
    for line in open(os.path.join(PROF, 'SmeltingColours.lua'), encoding='utf-8'):
        m = re.match(r'\s*\["(.+?)"\] = \{ (\d+), (\d+), (\d+) \}', line)
        if m:
            cols[m.group(1)] = [int(x) for x in m.groups()[1:]]
    for ln, _, v in rows(os.path.join(PROF, 'Mining.lua'), 'S'):
        if len(v) != 6:
            ERR.append('Mining.lua:%d: %d arguments, want 6' % (ln, len(v)))
            continue
        name, learn, src, item, rg, yld = v
        if name not in cols:
            WARN['smelting bar without wiki colours (learn level only)'].append(name)
        c = cols.get(name, [learn] * 3)
        yield ln, 'mining', [name, learn] + c + [src, item, rg, yld]


def is_id(v):
    return isinstance(v, int) and v > 0 or isinstance(v, str) and re.fullmatch(r's\d+', v)


def reagents_of(where, s):
    if s == '':
        return []
    if not isinstance(s, str) or not REAGENTS.match(s):
        ERR.append('%s: reagent string %r' % (where, s))
        return []
    out = [(int(a), int(b)) for a, b in (p.split(':') for p in s.split(','))]
    for rid, q in out:
        if q <= 0:
            ERR.append('%s: reagent %d quantity %d' % (where, rid, q))
    ids = [r for r, _ in out]
    if len(ids) != len(set(ids)):
        WARN['duplicate reagent in one recipe'].append(where)
    return out


def order(where, vals, label):
    v = [x for x in vals if x is not None]
    if any(not isinstance(x, int) for x in v):
        ERR.append('%s: non-integer skill %r' % (where, vals))
    elif v != sorted(v):
        WARN['skill colours out of order (%s)' % label].append('%s %r' % (where, vals))


def table_ids(path, name):
    t = open(path, encoding='utf-8').read()
    m = re.search(r'^%s = ' % re.escape(name), t, re.M)
    return lua_value(t, m.end())[0] if m else {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--report', default=os.path.join(HERE, 'reports', 'recipe_audit.md'))
    a = ap.parse_args()

    recipes = []     # (where, prof, name, product item or None, reagents, kind)
    # 1. per-profession lists
    for fn in sorted(os.listdir(PROF)):
        if not fn.endswith('.lua') or fn == 'Catalog.lua':
            continue
        names = collections.Counter()
        for ln, key, v in (smelt_rows() if fn == 'Mining.lua' else rows(os.path.join(PROF, fn), 'R')):
            where = '%s:%d' % (fn, ln)
            if len(v) not in (8, 9):
                ERR.append('%s: %d arguments, want 8-9' % (where, len(v)))
                continue
            name, o, y, g, gr, src, rid, rg = v[:8]
            yld = v[8] if len(v) > 8 else None
            if not (isinstance(name, str) and name):
                ERR.append('%s: no name' % where)
            if not is_id(rid):
                ERR.append('%s: product id %r' % (where, rid))
            if yld is not None and not (isinstance(yld, int) and yld >= 1):
                ERR.append('%s: yield %r' % (where, yld))
            if not isinstance(src, str):
                ERR.append('%s: source %r' % (where, src))
            order(where, (o, y, g, gr), 'orange <= yellow <= green <= grey')
            names[name] += 1
            recipes.append((where, key, name, rid if isinstance(rid, int) else None, reagents_of(where, rg), 'R'))
        for n, c in names.items():
            if c > 1:
                WARN['recipe name listed twice in one profession file'].append('%s: %s x%d' % (fn, n, c))
    # 2. the full catalog
    path = os.path.join(PROF, 'Catalog.lua')
    for ln, key, v in rows(path, 'C'):
        where = 'Catalog.lua:%d' % ln
        if len(v) not in (10, 11):
            ERR.append('%s: %d arguments, want 10-11' % (where, len(v)))
            continue
        name, learn, y, g, gr, rid, ritem, fee, wh, rg = v[:10]
        yld = v[10] if len(v) > 10 else None
        if not (isinstance(name, str) and name):
            ERR.append('%s: no name' % where)
        if not is_id(rid):
            ERR.append('%s: product id %r' % (where, rid))
        if not isinstance(learn, int):
            ERR.append('%s: learn level %r' % (where, learn))
        if yld is not None and not (isinstance(yld, int) and yld >= 1):
            ERR.append('%s: yield %r' % (where, yld))
        if ritem is not None and not (isinstance(ritem, int) and ritem > 0):
            ERR.append('%s: recipe item %r' % (where, ritem))
        # learn may sit above yellow (taught late; Engine.lua), so only yellow..grey is ordered
        order(where, (y, g, gr), 'yellow <= green <= grey')
        recipes.append((where, key, name, rid if isinstance(rid, int) else None, reagents_of(where, rg), 'C'))

    # 3. Material Finder: what can source a reagent (mirrors Materials/Catalog.lua's providers)
    nodes = set(table_ids(os.path.join(ROOT, 'Data.lua'), 'NW.NODE_ITEMS').values())
    fish_t = table_ids(os.path.join(PROF, 'Fishing.lua'), 'F.FISH')
    fish = {i for i, f in fish_t.items() if isinstance(f, dict) and (f.get('skill') or f.get('zones'))}
    src_items = table_ids(os.path.join(ROOT, 'Materials', 'SourceData.lua'), 'S.items')
    src_vend = table_ids(os.path.join(ROOT, 'Materials', 'SourceData.lua'), 'S.vendors')
    eng = open(os.path.join(PROF, 'Engine.lua'), encoding='utf-8').read()
    m = re.search(r'^local VENDOR = ', eng, re.M)
    vendor = set(lua_value(eng, m.end())[0]) | set(src_vend)
    made = {}
    uses = collections.Counter()
    for where, prof, name, item, rg, kind in recipes:
        if item and item not in made:
            made[item] = name
        for rid, _ in rg:
            uses[rid] += 1
    def providers(i):
        p = []
        if i in nodes: p.append('nodes')
        if i in fish: p.append('fishing')
        d = src_items.get(i) or {}
        if d.get('skin'): p.append('skin')
        if d.get('loot'): p.append('loot')
        if i in vendor: p.append('vendor')
        if i in made: p.append('craft')
        return p
    unsourced = sorted(i for i in uses if not providers(i))
    in_finder_no_src = sorted(i for i in src_items if not providers(i))

    # 4. regressions for this repair (errors: these must stay fixed)
    for item, want, why in ((2318, 'craft', 'G4 Light Leather craftable'), (8170, 'craft', 'G4 Rugged Leather craftable'),
                            (4234, 'craft', 'Heavy Leather craftable'), (4304, 'craft', 'Thick Leather craftable'),
                            (13422, 'fishing', 'G3 Stonescale Eel fishing entry')):
        if want not in providers(item):
            ERR.append('regression: %s (item %d has %r)' % (why, item, providers(item)))

    # report
    names = {i: d.get(1) for i, d in src_items.items()}
    L = ['# Recipe audit', '',
         'Generated by `tools/test_recipes.py`. These are static file checks, not live-client tests.',
         'The issues below were already in the data. They are reported here, not fixed.', '',
         '- Recipe rows read: %d (%d profession-list rows, %d catalog rows)' %
         (len(recipes), sum(r[5] == 'R' for r in recipes), sum(r[5] == 'C' for r in recipes)),
         '- Distinct reagents: %d; distinct products: %d' % (len(uses), len(made)),
         '- Errors: %d' % len(ERR), '']
    for k in sorted(WARN):
        L.append('## %s (%d)' % (k, len(WARN[k])))
        L.append('')
        L += ['- ' + w for w in WARN[k][:200]]
        if len(WARN[k]) > 200:
            L.append('- ... %d more' % (len(WARN[k]) - 200))
        L.append('')
    L.append('## Reagents with no Material Finder provider (%d)' % len(unsourced))
    L.append('')
    L.append('Recipes use these items, but no node, fish, creature, vendor or recipe provides them, so the')
    L.append('Material Finder cannot show where to get them. Many are quest or drop items outside the')
    L.append('configured material list (`tools/sources_config.json`). The list is informational.')
    L.append('')
    L.append('| item | used by recipes |')
    L.append('|---|---|')
    for i in sorted(unsourced, key=lambda i: (-uses[i], i)):
        L.append('| %d | %d |' % (i, uses[i]))
    L.append('')
    if in_finder_no_src:
        L.append('## Configured materials with no provider (%d)' % len(in_finder_no_src))
        L.append('')
        L += ['- %d %s' % (i, names.get(i) or '') for i in in_finder_no_src]
        L.append('')
    if ERR:
        L.append('## Errors')
        L.append('')
        L += ['- ' + e for e in ERR]
    os.makedirs(os.path.dirname(a.report), exist_ok=True)
    open(a.report, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')

    print('read %d recipe rows, %d reagents; %d warnings in %d groups; %d reagents unsourced; report %s' %
          (len(recipes), len(uses), sum(len(v) for v in WARN.values()), len(WARN), len(unsourced),
           os.path.relpath(a.report, ROOT)))
    if ERR:
        print('%d ERRORS:' % len(ERR))
        for e in ERR[:100]:
            print('  ' + e)
        sys.exit(1)
    print('no errors (static file checks; not a live-client test)')


if __name__ == '__main__':
    main()
