-- Builds Nodewalker's recipe data from One For All (OneForAll – Forever by Smoergi, GPL-3.0-or-later,
-- CurseForge 1714201). Deterministic: the same input files give the same output, byte for byte.
--
--   texlua tools/build_recipes.lua <OneForAll folder> [Professions output folder]
--
-- Reads   <OneForAll>/Data/Professions/<Profession>.lua and Data/ProfessionFees.lua (checked against
--         tools/recipes_manifest.json: version and SHA-256 of each file; a mismatch stops the build).
-- Writes  Professions/Catalog.lua (every recipe), and the leveling lists Professions/<Profession>.lua
--         for the eight crafting professions: every recipe with skill colours, except a specialization's
--         (trainer flag or RECIPE_SPEC pattern), cooldown recipes (CRAFT_COOLDOWN), and Classic recipes
--         One For All has no way of learning for (no trainer, recipe item or source). Mining (smelting) isn't in One For All: not written here.
--
-- What each value is taken from (and what isn't used):
--   name, crafted item or spell, reagents, count     One For All (from the Forever client's DB2 tables)
--   yellow / green / grey                            One For All (client skill-line data)
--   learn level   1. the trainer's required skill: ProfessionFees (CMaNGOS classic-db npc_trainer, GPL-3.0)
--                 2. 1 for a recipe known from the start
--                 3. One For All's req, unless marked rw=true (taken from wowtbc.gg, no licence): left unknown
--   source        rank (known from the start), trainer (a fee, not a specialization), recipe (anything else)
--   recipe item   One For All (the client item that teaches it)
-- Nothing from Nodewalker's earlier recipe files is read.

local OFA = assert(arg[1], "usage: texlua tools/build_recipes.lua <OneForAll folder> [out folder]")
local OUT = arg[2] or "Professions"
OFA = OFA:gsub("/$", "")

local PROFS = { -- One For All file, its profession name, Nodewalker key, leveling file
  { "Alchemy", "Alchemy", "alchemy" }, { "Blacksmithing", "Blacksmithing", "blacksmithing" },
  { "Cooking", "Cooking", "cooking" }, { "Enchanting", "Enchanting", "enchanting" },
  { "Engineering", "Engineering", "engineering" }, { "FirstAid", "First Aid", "firstaid" },
  { "Leatherworking", "Leatherworking", "leatherworking" }, { "Tailoring", "Tailoring", "tailoring" },
}

-- ---------- input check ----------
local function sha256(path)
  local p = assert(io.popen(("sha256sum %q"):format(path)))
  local out = p:read("*a") p:close()
  return out:match("^(%x+)")
end
local manifest = assert(io.open("tools/recipes_manifest.json")):read("*a")
local want = {}
for file, sum in manifest:gmatch('"(Data/[^"]+)"%s*:%s*"(%x+)"') do want[file] = sum end
local bad, n = 0, 0
for _ in pairs(want) do n = n + 1 end
if n < 10 then error("tools/recipes_manifest.json lists " .. n .. " files; expected 10") end
for file, sum in pairs(want) do
  local got = sha256(OFA .. "/" .. file)
  if got ~= sum then bad = bad + 1 io.stderr:write(("checksum mismatch: %s (%s, want %s)\n"):format(file, tostring(got), sum)) end
end
if bad > 0 then error("One For All files don't match tools/recipes_manifest.json: update the manifest only after reviewing the new version") end

-- ---------- load ----------
local FLT = {}
local function load(path) local f = assert(loadfile(path)); f("OneForAll", FLT) end
for _, p in ipairs(PROFS) do load(OFA .. "/Data/Professions/" .. p[1] .. ".lua") end
load(OFA .. "/Data/ProfessionFees.lua")
load(OFA .. "/Data/Smelting.lua")

local function clean(s) return (tostring(s):gsub("[;|]", ",")) end
-- Reviewed corrections: tools/recipe_overrides.json, one per recipe, each with its evidence; only
-- entries marked "approved": true are applied (a user's in-game report waits for that review)
OVERRIDES = {}
do
  local fh = io.open("tools/recipe_overrides.json")
  local txt = fh and fh:read("*a") or ""
  if fh then fh:close() end
  for body in txt:gmatch("%b{}") do
    local k = body:match('"recipe"%s*:%s*"([^"]+)"')
    if k and body:match('"approved"%s*:%s*true') then
      OVERRIDES[k] = { source = body:match('"source"%s*:%s*"([^"]+)"'), exclude = body:match('"exclude"%s*:%s*true') ~= nil }
    end
  end
end
-- recipes a trainer teaches (One For All's teach lists: CMaNGOS trainers, plus Forever's own)
local function taughtSet(feesT)
  local set = {}
  for _, t in ipairs(feesT.teach or {}) do for _, sp in ipairs(t[2] or {}) do set[sp] = true end end
  return set
end
local function q(s) return ("%q"):format(s) end

-- two entries can share a name (the recipe, and an item's own use effect): keep the real recipe
local function bestByName(list, fees)
  local function score(r) return ((r.y or 0) > 0 and 2 or 0) + ((r.ri or (fees and fees[r.s])) and 1 or 0) end
  local best, order = {}, {}
  for _, r in ipairs(list) do
    if not best[r.n] then order[#order + 1] = r.n end
    if not best[r.n] or score(r) > score(best[r.n]) then best[r.n] = r end
  end
  return best, order
end

-- the learn level, by the rules above; nil when unknown
local function learnOf(r, fee)
  if r.start then return 1, "start" end
  if r.req and r.req > 0 and not r.rw then return r.req, "client" end
  -- a Classic trainer level only where Forever's colours agree with it (Forever moved some recipes down)
  if fee and fee[2] and fee[2] > 0 and (not r.y or r.y == 0 or fee[2] <= r.y) then return fee[2], "cmangos" end
  return nil, r.rw and "rw-excluded" or "unknown"
end

local report = { "profession\tname\tlearn\tlearn_from\tyellow\tgreen\tgrey\tsource\titem\treagents\tyield" }

-- ---------- Catalog.lua ----------
local cat = {}
local function w(s) cat[#cat + 1] = s end
w("local _, NW = ...")
w("")
w("-- Every recipe in WoW Forever, with where it comes from, the item that teaches it and the trainer's fee.")
w("-- Generated by tools/build_recipes.lua from OneForAll – Forever 6.3.0 by Smoergi (GPL-3.0-or-later,")
w("-- CurseForge 1714201; built from the Forever client's data, QuestieDB and CMaNGOS classic-db).")
w("-- Learn levels: the trainer's (CMaNGOS) or the client's; levels One For All took from elsewhere are left out.")
w("-- Source codes: T trainer, S specialization trainer, B known from the start, F Merchant's Favor,")
w("-- V<A|H|*>vendor, zone   D mob, zone   +n more mobs   Q quest. Generated; do not edit by hand.")
w("local C")

local leveling = {}
for _, p in ipairs(PROFS) do
  local file, prof, key = p[1], p[2], p[3]
  local feesT = FLT.PROFESSION_FEES[prof] or {}
  local fees = feesT.fees or {}
  local taught = taughtSet(feesT)
  local best, order = bestByName(FLT.PROFESSION_RECIPES[prof] or {}, fees)
  w("")
  w(("C = NW.CatalogAdder(%q)"):format(key))
  local ranks = {}
  for _, rk in ipairs(feesT.ranks or {}) do ranks[#ranks + 1] = ("%s=%d"):format(rk[1], rk[4]) end
  w(("NW.RANK_FEE.%s = { %s }"):format(key, table.concat(ranks, ", ")))
  local lev = {}
  for _, name in ipairs(order) do
    local r = best[name]
    local fee = fees[r.s]
    local learn, from = learnOf(r, fee)
    -- where it comes from (Catalog's codes)
    local src = {}
    if r.start then src[#src + 1] = "B" end
    if fee then src[#src + 1] = fee[3] and "S" or "T" end
    if r.fav then src[#src + 1] = "F" end
    local s = r.src or {}
    local perFac = { A = 0, H = 0, ["*"] = 0 }
    for _, v in ipairs(s.v or {}) do
      local f = v.fac; if f ~= "A" and f ~= "H" then f = "*" end
      if perFac[f] < 3 then perFac[f] = perFac[f] + 1 src[#src + 1] = ("V%s%s, %s"):format(f, clean(v[2]), clean(v[3] or "?")) end
    end
    local nd = 0
    for _, d in ipairs(s.d or {}) do
      if nd < 3 then nd = nd + 1 src[#src + 1] = ("D%s%s"):format(clean(d[2]), d[3] and (", " .. clean(d[3])) or "") end
    end
    local total = s.dn or #(s.d or {})
    if total > nd then src[#src + 1] = "+" .. (total - nd) end
    for _, qq in ipairs(s.qs or {}) do src[#src + 1] = "Q" .. clean(qq[2]) end
    -- no source at all: a trainer's only for Forever's own spells or a teach list (see the leveling rule)
    if #src == 0 and not r.ri and ((r.s and r.s >= 1000000) or taught[r.s]) then src[#src + 1] = "T" end
    local re = {}
    for _, x in ipairs(r.r or {}) do re[#re + 1] = x[1] .. ":" .. x[2] end
    local reagents = table.concat(re, ",")
    local y = r.y or 0
    local g, gr = r.g, r.gr
    local colours = y > 0
    if not colours then y = learn or 1 g, gr = nil, nil end
    local id = r.i and tostring(r.i) or ('"s' .. r.s .. '"')
    w(("C(%s,%d,%d,%d,%d,%s,%s,%s,%s,%s,%d)"):format(q(r.n), learn or y, y, g or y, gr or y, id,
      r.ri and tostring(r.ri) or "nil", fee and tostring(fee[1]) or "nil", q(table.concat(src, ";")), q(reagents), r.c or 1))
    -- the leveling list: every recipe with skill colours that isn't a specialization's (the planner
    -- weighs trainer, vendor and drop recipes itself; "Include purchasable recipes" decides the rest)
    local s0 = r.src or {}
    local noOtherSource = not r.ri and not (s0.v or s0.d or s0.qs)
    -- trainer: a fee (not a specialization's), a teach list, or (One For All's own rule, as in its
    -- Catalog codes) no recipe item and no other source: Forever's new trainer recipes have no fee data
    -- (only for Forever's own spells, IDs from 1,000,000: a Classic recipe with no source is a quest,
    -- reputation or drop recipe One For All has no source for, and stays out of the leveling list)
    local foreverNew = r.s and r.s >= 1000000
    local trainerTaught = (fee and not fee[3]) or (not fee and (taught[r.s] or (noOtherSource and foreverNew)))
    local kind = r.start and "rank" or trainerTaught and "trainer" or "recipe"
    local unknownWay = noOtherSource and not trainerTaught and not r.start
    -- a pattern only a specialization can learn (client ItemSparse RequiredAbility, One For All's
    -- RECIPE_SPEC), and recipes on a long cooldown (CRAFT_COOLDOWN: "never planned for skill")
    local specOnly = r.ri and FLT.RECIPE_SPEC and FLT.RECIPE_SPEC[r.ri]
    local cooldown = FLT.CRAFT_COOLDOWN and FLT.CRAFT_COOLDOWN[r.s]
    -- reviewed corrections (tools/recipe_overrides.json, approved ones only)
    local ov = OVERRIDES[key .. "/" .. r.n]
    if ov and ov.source then kind = ov.source end
    if ov and ov.exclude then colours = false end
    if colours and not (fee and fee[3]) and not specOnly and not cooldown and not unknownWay then
      lev[#lev + 1] = { r = r, learn = learn, from = from, kind = kind, reagents = reagents, id = id }
    end
  end
  -- by when you can make it, then by name: stable
  table.sort(lev, function(a, b)
    local la, lb = a.learn or a.r.y, b.learn or b.r.y
    if la ~= lb then return la < lb end
    if a.r.y ~= b.r.y then return a.r.y < b.r.y end
    return a.r.n < b.r.n
  end)
  leveling[#leveling + 1] = { file = file, key = key, prof = prof, list = lev }
end
local f = assert(io.open(OUT .. "/Catalog.lua", "w"))
f:write(table.concat(cat, "\n") .. "\n") f:close()

-- ---------- leveling lists ----------
local counts = {}
for _, L in ipairs(leveling) do
  local out = {}
  local function o(s) out[#out + 1] = s end
  o("local _, NW = ...")
  o(("-- WoW Forever %s recipes for leveling: name, learn (orange), yellow, green, grey, source,"):format(L.prof:lower()))
  o("-- created item, reagents (\"itemID:count,...\"), items made per craft.")
  o("-- Generated by tools/build_recipes.lua from OneForAll – Forever 6.3.0 by Smoergi (GPL-3.0-or-later);")
  o("-- learn levels from CMaNGOS classic-db trainers (GPL-3.0) or the Forever client. Do not edit by hand.")
  o(("local R = NW.RecipeAdder(%q)"):format(L.key))
  local items = {}
  for _, e in ipairs(L.list) do
    local r = e.r
    local orange = (e.learn and e.learn ~= r.y) and tostring(e.learn) or "nil"
    o(("R(%s,%s,%d,%d,%d,%s,%s,%s,%d)"):format(q(r.n), orange, r.y, r.g or r.y, r.gr or r.y, q(e.kind), e.id, q(e.reagents), r.c or 1))
    if e.kind == "recipe" and r.ri then items[#items + 1] = ("[%s]=%d"):format(q(r.n), r.ri) end
    report[#report + 1] = table.concat({ L.key, r.n, tostring(e.learn or ""), e.from, r.y, r.g or r.y, r.gr or r.y, e.kind, e.id, e.reagents, r.c or 1 }, "\t")
  end
  if #items > 0 then o(("NW.RecipeItems(%q, { %s })"):format(L.key, table.concat(items, ", "))) end
  local fh = assert(io.open(OUT .. "/" .. L.file .. ".lua", "w"))
  fh:write(table.concat(out, "\n") .. "\n") fh:close()
  counts[#counts + 1] = ("%s %d"):format(L.key, #L.list)
end
-- ---------- smelting (Mining) ----------
-- Bars, items, reagents, counts and learn levels: One For All's Data/Smelting.lua (Forever client).
-- Skill colours: Warcraft Wiki's "Forever mining techniques" (CC BY-SA 4.0), in their own file,
-- Professions/SmeltingColours.lua, which Mining.lua reads at load. A bar the wiki lacks: no colours.
do
  local wj = assert(io.open("tools/data/forever_mining_wiki.json")):read("*a")
  local rev = "oldid " .. assert(wj:match('oldid (%d+)')) .. ", last edited " .. assert(wj:match('last edited ([^,"]+)'))
  -- which bars Classic mining trainers teach (cMaNGOS, via tools/extract_smelting_trainers.py)
  local cj = assert(io.open("tools/data/cmangos_smelting_trainers.json")):read("*a")
  local cmCommit = assert(cj:match('"commit"%s*:%s*"(%x+)"'))
  local taughtAt = {}
  for row in cj:gmatch('{%s*"teaching_spell".-%]%s*}') do
    local req = tonumber(row:match('"reqskill"%s*:%s*(%d+)'))
    local learns = row:match('"learns"%s*:%s*%[([^%]]*)%]')
    for id in learns:gmatch("%d+") do taughtAt[tonumber(id)] = req end
  end
  local cols, single = {}, {}
  for row in wj:gmatch('{"bar"[^}]*}') do
    local bar = row:match('"bar"%s*:%s*"([^"]+)"')
    local a, b, c, d = row:match('"skills"%s*:%s*%[%s*(%d+),%s*(%d+),%s*(%d+),%s*(%d+)%s*%]')
    cols[bar] = { tonumber(a), tonumber(b), tonumber(c), tonumber(d) }
    single[bar] = row:find('"single_value"%s*:%s*true') ~= nil
  end
  local co = {}
  local function c(s) co[#co + 1] = s end
  c("local _, NW = ...")
  c("-- Smelting skill colours (yellow, green, grey) for WoW Forever, from Warcraft Wiki:")
  c("-- \"Forever mining techniques\", https://warcraft.wiki.gg/wiki/Forever_mining_techniques")
  c("-- (" .. rev .. "). Licensed CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/);")
  c("-- this file is under the same licence, separate from Nodewalker's GPL code. Community values, not")
  c("-- verified in game. Numbers as the page prints them; \"one value\" rows print a single number four")
  c("-- times (the page may only know the learn level). Generated by tools/build_recipes.lua; see")
  c("-- LICENSES/Warcraft-Wiki-CC-BY-SA-4.0.txt. Do not edit by hand.")
  c("NW.SMELT_COLOURS = {")
  local mo = {}
  local function m(s) mo[#mo + 1] = s end
  m("local _, NW = ...")
  m("-- WoW Forever smelting. Mining itself levels by mining nodes (see the guide).")
  m("-- Generated by tools/build_recipes.lua: bars, reagents, counts and learn levels from OneForAll – Forever")
  m("-- 6.3.0 by Smoergi (GPL-3.0-or-later; Data/Smelting.lua, from the Forever client). Skill colours from")
  m("-- Professions/SmeltingColours.lua (Warcraft Wiki, CC BY-SA 4.0); without one, only the learn level is known.")
  m("-- Source: rank (known from the start); trainer where Classic mining trainers teach it (cMaNGOS classic-db,")
  m("-- GPL-3.0, @ " .. cmCommit:sub(1, 12) .. ", same required skill; Classic reference); else recipe (not in the data).")
  m("-- Do not edit by hand.")
  m('local add = NW.RecipeAdder("mining")')
  m("local C = NW.SMELT_COLOURS or {}")
  m("local function S(name, learn, src, item, reagents, yield)")
  m("  local col = C[name]")
  m("  add(name, learn, col and col[1] or learn, col and col[2] or learn, col and col[3] or learn, src, item, reagents, yield)")
  m("end")
  local list = {}
  for _, r in ipairs(FLT.SMELTING or {}) do list[#list + 1] = r end
  table.sort(list, function(a, b) if a.req ~= b.req then return a.req < b.req end return a.n < b.n end)
  for _, r in ipairs(list) do
    local re = {}
    for _, x in ipairs(r.r or {}) do re[#re + 1] = x[1] .. ":" .. x[2] end
    local src = r.start and "rank" or (taughtAt[r.s] == r.req and "trainer") or "recipe"
    if taughtAt[r.s] and taughtAt[r.s] ~= r.req then io.stderr:write(("note: %s client %d vs cMaNGOS %d\n"):format(r.n, r.req, taughtAt[r.s])) end
    m(("S(%s,%d,%s,%d,%s,%d)"):format(q(r.n), r.req, q(src), r.i, q(table.concat(re, ",")), r.c or 1))
    local w = cols[r.n]
    if w then
      if w[1] ~= r.req then io.stderr:write(("note: %s learn %d (client) vs %d (wiki)\n"):format(r.n, r.req, w[1])) end
      c(("  [%s] = { %d, %d, %d }, -- learn %d on the page%s"):format(q(r.n), w[2], w[3], w[4], w[1], single[r.n] and "; one value" or ""))
    end
    report[#report + 1] = table.concat({ "mining", r.n, tostring(r.req), "client", w and w[2] or "", w and w[3] or "", w and w[4] or "",
      src, r.i, table.concat(re, ","), r.c or 1 }, "\t")
  end
  c("}")
  local fh = assert(io.open(OUT .. "/SmeltingColours.lua", "w")) fh:write(table.concat(co, "\n") .. "\n") fh:close()
  fh = assert(io.open(OUT .. "/Mining.lua", "w")) fh:write(table.concat(mo, "\n") .. "\n") fh:close()
  counts[#counts + 1] = ("mining %d"):format(#list)
end

local rf = io.open("tools/reports/recipes_built.tsv", "w")
if rf then rf:write(table.concat(report, "\n") .. "\n") rf:close() end
print("leveling recipes: " .. table.concat(counts, ", "))
