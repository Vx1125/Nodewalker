local _, NW = ...

------------------------------------------------------------------------
-- Material Finder: one catalog of materials, each with every way to get it.
--
-- Providers (a material can have several):
--   nodes    herb and ore nodes (Data.lua NODES / NODE_ITEMS, your saved spots, Guide.lua's zone ranking)
--   fishing  Professions/Fishing.lua's fish data
--   skin     skinning loot     (Materials/SourceData.lua, Classic data)
--   loot     ordinary creature loot (Materials/SourceData.lua, Classic data)
--   vendor   vendors (Engine.lua's vendor prices; vendor NPCs from SourceData.lua)
--   craft    a recipe makes it (NW.RecipeFor)
-- The auction house is an action on every material, not a provider.
--
-- Static data only here. What you gathered is in Materials/GatherLog.lua;
-- collection objectives are per character (charDB.matGoals).
------------------------------------------------------------------------
local M = {}
NW.Mat = M

M.CATS = {
  { key = "herb", label = "Herbs", icon = 2447 },
  { key = "ore", label = "Ore", icon = 2770 },
  { key = "leather", label = "Leather & Hides", short = "Leather", icon = 4234 },
  { key = "fish", label = "Fish", icon = 6303 },
  { key = "cloth", label = "Cloth", icon = 2589 },
  { key = "meat", label = "Meat & Cooking", short = "Meat", icon = 769 },
  { key = "elemental", label = "Elemental", icon = 7068 },
  { key = "reagent", label = "Specialty Reagents", short = "Reagents", icon = 5635 },
  { key = "vendor", label = "Vendor Supplies", short = "Vendor", icon = 2320 },
  { key = "crafted", label = "Crafted Components", short = "Crafted", icon = 2840 },
}
M.CAT = {}
for _, c in ipairs(M.CATS) do M.CAT[c.key] = c end
M.SOURCE_LABEL = { nodes = "Gathering", fishing = "Fishing", skin = "Skinning", loot = "Creature loot", vendor = "Vendor", craft = "Crafting" }
-- category accents (restrained: they tell kinds apart, they don't decorate)
M.ACCENT = {
  herb = "|cff8fb878", ore = "|cffa8a49c", leather = "|cffb88f68", fish = "|cff7aa0c1", cloth = "|cffa58fb8",
  meat = "|cffb87a68", elemental = "|cffd6a85a", reagent = "|cffb8806a", vendor = "|cffe0dbd0", crafted = "|cffd6b266",
}

local entries, byID, uses
local function add(id, cat, name)
  if not id then return end
  local e = byID[id]
  if not e then
    e = { id = id, cat = cat, name = name, static = name, src = {} }
    byID[id] = e
    entries[#entries + 1] = e
  end
  return e
end

-- Every node name that gives an item (ooze-covered veins, Small and Rich Thorium)
local nodesOf
local function nodeNames(id)
  if not nodesOf then
    nodesOf = {}
    for name, item in pairs(NW.NODE_ITEMS) do
      nodesOf[item] = nodesOf[item] or {}
      table.insert(nodesOf[item], name)
    end
    for _, l in pairs(nodesOf) do
      table.sort(l, function(a, b) return (NW.RequiredSkill(a) or 999) < (NW.RequiredSkill(b) or 999) end)
    end
  end
  return nodesOf[id]
end
M.NodeNames = nodeNames

function M.Build()
  if entries then return entries end
  entries, byID, uses = {}, {}, {}
  -- herbs and ore: the guides' order (lowest skill first)
  for _, list in ipairs({ { NW.HERB_GUIDE, "herb" }, { NW.ORE_GUIDE, "ore" } }) do
    for _, g in ipairs(list[1]) do
      local id = NW.NODE_ITEMS[g[1]]
      local e = add(id, list[2], g[1])
      if e then e.src.nodes = true; e.nodeKind = list[2] end
    end
  end
  -- fish with fishing data
  local F = NW.FISHING
  if F then
    for _, id in ipairs(F.ORDER or {}) do
      local f = F.FISH[id]
      if f and (f.skill or f.zones) then add(id, "fish").src.fishing = true end
    end
  end
  -- creature sources
  local S = NW.SRC
  if S then
    local order = {}
    for id in pairs(S.items) do order[#order + 1] = id end
    table.sort(order)
    for _, id in ipairs(order) do
      local d = S.items[id]
      local e = add(id, d[2], d[1])
      if #d.skin > 0 then e.src.skin = true end
      if #d.loot > 0 then e.src.loot = true end
    end
  end
  -- reagents: how many recipes use each; what a recipe makes that others use
  local made = {}
  -- both recipe sources: the profession lists and the catalog rows they don't already hold
  -- (NW.CatalogAdder merges a catalog row into a matching list recipe instead of adding it)
  for _, book in ipairs({ NW.RECIPES or {}, NW.CATALOG or {} }) do
    for _, list in pairs(book) do
      for _, r in ipairs(list) do
        for _, re in ipairs(r.reagents or {}) do uses[re[1]] = (uses[re[1]] or 0) + 1 end
        if r.item and not made[r.item] then made[r.item] = r end
      end
    end
  end
  -- vendor supplies: the vendor price table and vendor NPCs from the source data
  local vend = {}
  for id in pairs(NW.VENDOR_PRICES or {}) do vend[id] = true end
  if S then for id in pairs(S.vendors) do vend[id] = true end end
  for id in pairs(vend) do
    if uses[id] then add(id, "vendor").src.vendor = true end
  end
  -- crafted components: made by a recipe and used by another
  for id, r in pairs(made) do
    if uses[id] then add(id, "crafted", r.name).src.craft = true end
  end
  -- every material that a recipe makes can also be crafted (Light Leather from scraps)
  for _, e in ipairs(entries) do
    if made[e.id] then e.src.craft = true end
    e.uses = uses[e.id] or 0
  end
  M.Names()
  return entries
end

function M.Get(id) M.Build() return byID[id] end
function M.Entries() return M.Build() end

-- Names: the game's own once cached, else the static English name
function M.Name(e)
  local n = NW.ItemName(e.id)
  if n then e.name = n end
  return e.name or ("item " .. e.id)
end
local index, indexDirty = nil, true
function M.Names()
  indexDirty = true
end
NW.On("GET_ITEM_INFO_RECEIVED", function() indexDirty = true end)

-- Search: names (part of a word is enough), item IDs and links, category
-- words ("leather", "cloth", "herb"), source words ("skinning", "vendor").
local CAT_WORDS = {
  herb = { "herb", "herbs", "herbalism", "plant" }, ore = { "ore", "mining", "metal" },
  leather = { "leather", "hide", "hides", "skin", "skinning", "scale" }, fish = { "fish", "fishing" },
  cloth = { "cloth" }, meat = { "meat", "cooking", "food" }, elemental = { "elemental", "element" },
  reagent = { "reagent", "reagents" }, vendor = { "vendor" }, crafted = { "crafted", "craft" },
}
local function buildIndex()
  index = {}
  for _, e in ipairs(M.Build()) do
    local words = { (M.Name(e)):lower(), e.static and e.static:lower() or nil }
    for _, w in ipairs(CAT_WORDS[e.cat] or {}) do words[#words + 1] = w end
    if e.src.skin then words[#words + 1] = "skinning" end
    if e.src.vendor then words[#words + 1] = "vendor" end
    if e.src.loot then words[#words + 1] = "drop" end
    for _, n in ipairs(nodeNames(e.id) or {}) do words[#words + 1] = n:lower() end
    index[#index + 1] = { e = e, text = table.concat(words, "|") }
  end
  indexDirty = false
end
function M.Search(text, cat)
  if indexDirty or not index then buildIndex() end
  text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local wantID = tonumber(text) or tonumber(text:match("item:(%d+)") or "")
  local out = {}
  -- Tracked: the objectives, in their own order
  if cat == "tracked" and text == "" then
    for _, g in ipairs(M.Goals()) do local e = M.Get(g.id) if e then out[#out + 1] = e end end
    return out
  end
  -- typing searches every category
  for _, row in ipairs(index) do
    local e = row.e
    local ok
    if wantID then ok = e.id == wantID
    elseif text == "" then ok = (not cat or cat == "all" or e.cat == cat)
    else ok = row.text:find(text, 1, true) ~= nil end
    if ok then out[#out + 1] = e end
  end
  return out
end
-- category counts (only categories with materials are shown)
function M.Counts()
  local c = { all = 0 }
  for _, e in ipairs(M.Build()) do c[e.cat] = (c[e.cat] or 0) + 1; c.all = c.all + 1 end
  return c
end

-- The provider list for a material, in the order the details show them
local ORDER = { "nodes", "fishing", "skin", "loot", "vendor", "craft" }
function M.Sources(e)
  local out = {}
  for _, k in ipairs(ORDER) do if e.src[k] then out[#out + 1] = k end end
  return out
end
-- the one shown in lists
function M.Primary(e) return M.Sources(e)[1] end
function M.SourceText(e, k)
  if k == "nodes" then return e.nodeKind == "ore" and "Mining" or "Herbalism" end
  return M.SOURCE_LABEL[k]
end

------------------------------------------------------------------------
-- Collection objectives (per character)
--   { id, mode = "total" | "more", n, base, from = profession key, at = time }
-- total: own n in bags and bank.  more: collect n more than you had (base).
------------------------------------------------------------------------
local MAX_GOALS = 8
function M.Goals()
  local c = NW.charDB
  if not c then return {} end
  c.matGoals = c.matGoals or {}
  return c.matGoals
end
function M.Goal(id)
  for i, g in ipairs(M.Goals()) do if g.id == id then return g, i end end
end
function M.SetGoal(id, mode, n, from)
  if not id or not n or n <= 0 then return end
  local goals = M.Goals()
  local g = M.Goal(id)
  if not g then
    if #goals >= MAX_GOALS then return nil, "full" end
    g = { id = id }
    goals[#goals + 1] = g
  end
  g.mode, g.n, g.at = mode == "more" and "more" or "total", math.floor(n), time()
  g.base = NW.ItemCount(id)
  g.from = from or g.from
  if NW.charDB then NW.charDB.matActive = id end
  M.Changed()
  return g
end
function M.ClearGoal(id)
  local _, i = M.Goal(id)
  if i then table.remove(M.Goals(), i) end
  if NW.charDB and NW.charDB.matActive == id then NW.charDB.matActive = M.Goals()[1] and M.Goals()[1].id end
  M.Changed()
end
function M.ClearDone()
  local goals = M.Goals()
  for i = #goals, 1, -1 do
    local p = M.Progress(goals[i])
    if p.done then table.remove(goals, i) end
  end
  M.Changed()
end
-- have, target, remaining for a goal, from the bags and bank right now
function M.Progress(g)
  local have = NW.ItemCount(g.id)
  local p = { have = have }
  if g.mode == "more" then
    p.got = math.max(0, have - (g.base or 0))
    p.target, p.remaining = g.n, math.max(0, g.n - p.got)
    p.shown = p.got
  else
    p.target, p.remaining = g.n, math.max(0, g.n - have)
    p.shown = have
  end
  p.done = p.remaining == 0
  return p
end
function M.Active()
  local c = NW.charDB
  local id = c and c.matActive
  local g = id and M.Goal(id)
  return g or M.Goals()[1]
end
function M.SetActive(id) if NW.charDB then NW.charDB.matActive = id end M.Changed() end

local listeners = {}
function M.OnChange(fn) listeners[#listeners + 1] = fn end
function M.Changed(what) for _, fn in ipairs(listeners) do pcall(fn, what) end end
-- bag changes move objectives: tell the views, at most twice a second
local pending
NW.On("BAG_UPDATE_DELAYED", function()
  if pending or #M.Goals() == 0 then return end
  pending = true
  C_Timer.After(0.5, function() pending = false; M.Changed("bags") end)
end)
