local _, NW = ...

------------------------------------------------------------------------
-- Fishing: its own page (Leveling, Fish Finder, Fishing + Cooking), the
-- fish data, and the combined plan. The combined plan doesn't level
-- Cooking itself: it runs the same planner as every craft (NW.BuildPlan),
-- held to what you can catch, then lays fishing, catching, training and
-- cooking out in order.
--
-- Sources: ranks, books, quests, trainers, lures and the six fish with
-- zones (`forever`) are from Method's WoW Forever fishing guide
-- (method.gg/wow-forever/fishing-in-wow-forever-leveling-guide-fishing-items-trainers).
-- Zones by skill range are wow-professions.com's WoW Forever fishing guide.
-- Fish listed only by skill range (`guide`) come from Nodewalker's earlier
-- guide (Wowhead / wow-professions). WoW Forever doesn't publish each zone's
-- fishing skill, so none is shown; catch rates are unknown and never shown.
------------------------------------------------------------------------
local UI, S = NW.UI, NW.STYLE
local H = S.HEX
local F = {}
NW.FISHING = F
F.BLUE = { 0.478, 0.627, 0.757, 1 } -- Fishing's accent
local BLUE_HEX = "|cff7aa0c1"

-- Ranks in WoW Forever
F.RANKS = {
  { name = "Apprentice", cap = 75, how = "Any fishing trainer" },
  { name = "Journeyman", cap = 150, skill = 50, level = 10, how = "Any fishing trainer" },
  { name = "Expert", cap = 225, skill = 125, level = 20, item = 16083, how = "Book: Expert Fishing - The Bass and You",
    who = "Old Man Heming", where = "Booty Bay, Stranglethorn Vale", map = 1434, price = 10000, note = "Also on the auction house" },
  { name = "Artisan", cap = 300, skill = 225, level = 35, how = "Quest: Nat Pagle, Angler Extreme",
    who = "Nat Pagle", where = "Dustwallow Marsh", map = 1445,
    quest = { { "Feralas Ahi", "Verdantis River, Feralas" }, { "Misty Reed Mahi Mahi", "Misty Reed Strand, Swamp of Sorrows" },
      { "Sar'theris Striker", "Sar'theris Strand, Desolace" }, { "Savage Coast Blue Sailfin", "Savage Coast, Stranglethorn Vale" } } },
}
F.TRAINERS = {
  Alliance = { "Arnold Leland, Stormwind", "Grimnur Stonebrand, Ironforge", "Astaia, Darnassus", "Lee Brown, Elwynn Forest",
    "Paxton Ganter, Dun Morogh", "Androl Oakhand, Teldrassil", "Warg Deepwater, Loch Modan", "Matthew Hooper, Redridge",
    "Harold Riggs, Wetlands", "Donald Rabonne, Hillsbrad", "Brannock, Feralas" },
  Horde = { "Lumak, Orgrimmar", "Armand Cromwell, Undercity", "Kah Mistrunner, Thunder Bluff", "Lau'Tiki, Durotar",
    "Uthan Stillwater, Mulgore", "Clyde Kellen, Tirisfal Glades", "Kil'Hiwana, Ashenvale", "Lui'Mala, Desolace",
    "Katoom the Angler, The Hinterlands" },
  both = { "Myizz Luckycatch, Booty Bay", "Krix, Riverglades", "Baelann Swiftcurrent, Zephras Isle", "Fenn Fairweather, Zephras Isle" },
}
-- { item, bonus }
F.LURES = { { 6529, 25 }, { 6530, 50 }, { 6811, 50 }, { 6532, 75 }, { 6533, 100 } }
local LURE_NAME = { [6529] = "Shiny Bauble", [6530] = "Nightcrawlers", [6811] = "Aquadynamic Fish Lens", [6532] = "Bright Baubles",
  [6533] = "Aquadynamic Fish Attractor" }

-- Where to fish at each skill range
F.BRACKETS = {
  { 1, 75, zones = { "Durotar", "Elwynn Forest", "Dun Morogh", "Mulgore", "Tirisfal Glades", "Teldrassil", "Zephras Isle" }, lure = 6529 },
  { 75, 150, zones = { "Orgrimmar", "Stormwind City", "Undercity", "Thunder Bluff", "Darnassus", "Ironforge", "The Barrens",
    "Westfall", "Loch Modan", "Darkshore", "Silverpine Forest" }, lure = 6530,
    later = { "Wetlands", "Ashenvale", "Hillsbrad Foothills", "Stonetalon Mountains" }, laterAt = 125 },
  { 150, 225, zones = { "Dustwallow Marsh", "Alterac Mountains", "Arathi Highlands", "Desolace", "Stranglethorn Vale",
    "Swamp of Sorrows", "Thousand Needles" }, best = "Dustwallow Marsh", lure = 6532 },
  { 225, 300, zones = { "Tanaris", "Feralas", "The Hinterlands", "Felwood", "Un'Goro Crater", "Western Plaguelands" }, lure = 6532 },
}
-- Fish: skill = where the guides fish it; zones only where a source names them.
-- No skill: a fish the cooking data uses that no source places.
F.FISH = {
  [6291] = { skill = 25, zones = { "Dun Morogh", "Elwynn Forest", "Mulgore" }, src = "forever" },
  [6303] = { skill = 1, bracket = 1, src = "guide" },
  [6289] = { skill = 75, zones = { "Stormwind City", "Darnassus", "Orgrimmar", "Thunder Bluff" }, src = "forever" },
  [6361] = { skill = 75, bracket = 2, src = "guide" },
  [6317] = { skill = 75, bracket = 2, src = "guide" },
  [6358] = { skill = 75, bracket = 2, src = "guide" },
  [6308] = { skill = 150, zones = { "Redridge Mountains", "Duskwood", "Stonetalon Mountains", "Ashenvale" }, src = "forever" },
  [6362] = { skill = 150, bracket = 3, note = "Coast", src = "guide" },
  [6359] = { skill = 150, bracket = 3, note = "Coast", src = "guide" },
  [8365] = { skill = 225, zones = { "Alterac Mountains", "Arathi Highlands", "Dustwallow Marsh", "Desolace" }, src = "forever" },
  [13754] = { skill = 225, bracket = 4, note = "Coast", src = "guide" },
  [13759] = { skill = 225, bracket = 4, note = "At night", src = "guide" },
  [13760] = { skill = 225, bracket = 4, note = "By day", src = "guide" },
  [13756] = { skill = 225, bracket = 4, src = "guide" },
  [13755] = { skill = 225, bracket = 4, src = "guide" },
  [13758] = { skill = 300, zones = { "Western Plaguelands", "The Hinterlands", "Moonglade", "Felwood", "Un'Goro Crater" }, note = "Lakes and rivers", src = "forever" },
  [4603] = { skill = 300, zones = { "Tanaris", "The Hinterlands" }, note = "Coast", src = "forever" },
  [21071] = {}, [21153] = {}, [6522] = {}, [13890] = {}, [8959] = {},
}
F.ORDER = {}
for id in pairs(F.FISH) do F.ORDER[#F.ORDER + 1] = id end
table.sort(F.ORDER, function(a, b)
  local x, y = F.FISH[a].skill or 999, F.FISH[b].skill or 999
  if x ~= y then return x < y end
  return a < b
end)
function NW.IsFish(id) return id and F.FISH[id] ~= nil end

-- Your own faction's cities first; the other faction's last
local CITY = { Orgrimmar = "Horde", Undercity = "Horde", ["Thunder Bluff"] = "Horde", Durotar = "Horde", Mulgore = "Horde",
  ["Tirisfal Glades"] = "Horde", ["Stormwind City"] = "Alliance", Ironforge = "Alliance", Darnassus = "Alliance",
  ["Elwynn Forest"] = "Alliance", ["Dun Morogh"] = "Alliance", Teldrassil = "Alliance" }
local HOSTILE_CITY = { Orgrimmar = true, Undercity = true, ["Thunder Bluff"] = true, ["Stormwind City"] = true, Ironforge = true, Darnassus = true }
function F.faction() return (UnitFactionGroup and UnitFactionGroup("player")) or "Horde" end
function F.hostile(zone)
  local c = CITY[zone]
  return HOSTILE_CITY[zone] and c and c ~= F.faction()
end
function F.sortZones(list)
  local out, me = {}, F.faction()
  for i, z in ipairs(list or {}) do out[i] = z end
  local function w(z) local c = CITY[z]; return (c == me and 0) or (c and 2) or 1 end
  local pos = {}
  for i, z in ipairs(out) do pos[z] = i end
  table.sort(out, function(a, b) if w(a) ~= w(b) then return w(a) < w(b) end return pos[a] < pos[b] end)
  return out
end

-- Fish caught in a zone: by name where a source says so, and by skill range
function F.fishIn(zone, bi)
  local here, range = {}, {}
  for _, id in ipairs(F.ORDER) do
    local f = F.FISH[id]
    local named
    for _, z in ipairs(f.zones or {}) do if z == zone then named = true end end
    if named then here[#here + 1] = id
    elseif bi and f.bracket == bi then range[#range + 1] = id end
  end
  return here, range
end
-- Zones for a fish: its own, or its skill range's
function F.zonesFor(id)
  local f = F.FISH[id]
  if not f then return {} end
  if f.zones then return F.sortZones(f.zones), true end
  local b = f.bracket and F.BRACKETS[f.bracket]
  return b and F.sortZones(b.zones) or {}, false
end
function F.bracketFor(skill)
  for i, b in ipairs(F.BRACKETS) do if skill < b[2] then return i, b end end
  return #F.BRACKETS, F.BRACKETS[#F.BRACKETS]
end

------------------------------------------------------------------------
-- Your fishing: base skill, what gear and lures add, lure on the pole
------------------------------------------------------------------------
function F.skill()
  local rank, max = NW.ProfSkill("fishing")
  local bonus = rank and NW.ProfBonus("fishing") or 0
  return rank, max, bonus
end
function F.rankOf(max)
  local name = "Apprentice"
  for _, r in ipairs(F.RANKS) do if max and max >= r.cap then name = r.name end end
  return name
end
function F.nextRank(max)
  for _, r in ipairs(F.RANKS) do if not max or max < r.cap then return r end end
end
-- A temporary enchant on an equipped fishing pole is a lure: minutes left, or nil
function F.lureOn()
  local id = GetInventoryItemID and GetInventoryItemID("player", 16)
  if not id or not (C_Item and C_Item.GetItemInfoInstant) then return nil end
  local ok, _, _, _, _, _, classID, subID = pcall(C_Item.GetItemInfoInstant, id)
  if not ok or classID ~= 2 or subID ~= 20 then return nil end
  local has, ms = GetWeaponEnchantInfo()
  if has and type(ms) == "number" then return math.max(1, math.floor(ms / 60000 + 0.5)) end
  return false
end
function F.itemName(id, fallback)
  local n = NW.ItemName(id)
  return n or fallback or ("item " .. id), n ~= nil
end

------------------------------------------------------------------------
-- Cooking ingredient rules. Standalone Cooking: all ingredients, fish
-- only, or no fish (settings.cookSource). The combined plan: what you can
-- catch by then, plus vendor supplies, plus anything you allow.
------------------------------------------------------------------------
local ctx -- set while the combined plan runs the planner
local fishOf = setmetatable({}, { __mode = "k" })
local function fishInRecipe(r)
  local l = fishOf[r]
  if l then return l end
  l = {}
  for _, re in ipairs(r.reagents) do if F.FISH[re[1]] then l[#l + 1] = re[1] end end
  fishOf[r] = l
  return l
end
F.fishInRecipe = fishInRecipe
function NW.CookAllowKey()
  if ctx then return ctx.key end
  return NW.db.settings.cookSource or ""
end
function NW.CookAllow(r, sk)
  local fl = fishInRecipe(r)
  if not ctx then
    local src = NW.db.settings.cookSource
    if src == "fish" then return #fl > 0 end
    if src == "nofish" then return #fl == 0 end
    return true
  end
  if #fl == 0 and not ctx.nonFish then return false end
  local canFish = ctx.fishAt(sk)
  for _, re in ipairs(r.reagents) do
    local id = re[1]
    local f = F.FISH[id]
    if f then
      if not ctx.buyFish and not (f.skill and f.skill <= canFish) then return false end
    elseif NW.IsVendor(id) then
      if not ctx.vendor then return false end
    elseif not ctx.nonFish then
      return false
    end
  end
  return true
end

------------------------------------------------------------------------
-- The combined plan
------------------------------------------------------------------------
local TIERS = { { 0, 75, "Apprentice" }, { 75, 150, "Journeyman" }, { 150, 225, "Expert" }, { 225, 300, "Artisan" } }
local function tierOf(sk) for i, t in ipairs(TIERS) do if sk < t[2] then return i end end return #TIERS end

function F.cfg()
  local s = NW.db.settings
  local c = s.fishCook
  if type(c) ~= "table" then c = {}; s.fishCook = c end
  c.folds = c.folds or {}
  return c
end
function F.targets()
  local c = F.cfg()
  return c.fishTo or 300, c.cookTo or 300
end

function F.Build()
  local c = F.cfg()
  local fishNow, fishMax = NW.ProfSkill("fishing")
  local cookNow, cookMax = NW.ProfSkill("cooking")
  local fishTo, cookTo = F.targets()
  local base = fishNow or 0
  local level = UnitLevel and UnitLevel("player") or 60
  local plan = { phases = {}, fish = {}, buy = {}, recipes = {}, vendor = {}, fees = 0, unknown = 0,
    fishNow = fishNow, cookNow = cookNow, fishTo = fishTo, cookTo = cookTo }
  -- the cooking plan, held to what you'll be able to catch by each point
  local cookFrom = math.max(1, cookNow or 1)
  local cp
  if cookTo > cookFrom then
    ctx = {
      key = ("fc%d:%d:%s%s%s"):format(base, fishTo, c.buyFish and "b" or "", c.nonFish and "n" or "", c.noVendor and "" or "v"),
      buyFish = c.buyFish, nonFish = c.nonFish, vendor = not c.noVendor,
      fishAt = function(sk) return math.max(base, math.min(fishTo, TIERS[tierOf(sk)][2])) end,
    }
    local s = NW.db.settings
    local a, b, d = s.planStrategy, s.planRecipeItems, s.planSellBack
    s.planStrategy, s.planRecipeItems, s.planSellBack = nil, not c.noRecipes, false
    NW.kitHold = true -- its own plan: neither follows nor replaces Cooking's kit
    local ok, res = pcall(NW.BuildPlan, "cooking", cookFrom, cookTo)
    NW.kitHold = nil
    s.planStrategy, s.planRecipeItems, s.planSellBack = a, b, d
    ctx = nil
    if ok then cp = res end
  end
  plan.cook = cp
  local left = {} -- what's in your bags, handed out to the steps in order
  local function have(id)
    if left[id] == nil then left[id] = NW.ItemCount(id) or 0 end
    return left[id]
  end
  local known = NW.charDB.known.cooking or {}
  local seenR = {} -- a recipe is got once, in the first phase that uses it
  local nextFound
  -- set once a training step can't be done (or a stretch has no recipe): later
  -- steps that need it are blocked with the same reason
  local fishBlock, cookBlock, gapBlock
  local fishCap, cookCap = fishMax or 75, cookMax or 75
  for ti, t in ipairs(TIERS) do
    local lo, hi = t[1], t[2]
    local ph = { name = t[3], lo = lo, hi = hi, ti = ti, actions = {} }
    local function add(a)
      a.phase = ph
      ph.actions[#ph.actions + 1] = a
      return a
    end
    local fishHere = fishTo > lo and base < math.min(fishTo, hi)
    local fishAtEnd = math.min(fishTo, hi)
    if fishAtEnd < base then fishAtEnd = base end
    local cookSteps = {}
    for _, st in ipairs(cp and cp.steps or {}) do
      if tierOf(st.from) == ti then cookSteps[#cookSteps + 1] = st end
    end
    local cookHere = #cookSteps > 0
    if fishHere or cookHere then
      if ti == 1 and not fishNow and fishTo > 0 then
        add({ kind = "learn", prof = "fishing", label = "Learn Fishing", done = false })
      end
      if ti == 1 and not cookNow and cookTo > 1 then
        add({ kind = "learn", prof = "cooking", label = "Learn Cooking", done = false })
      end
      if ti >= 2 and fishTo > lo then
        local r = F.RANKS[ti]
        local done = fishMax and fishMax >= hi or false
        local a = add({ kind = "train", prof = "fishing", rank = r, label = "Train " .. r.name .. " Fishing", done = done })
        if not done and level < r.level then a.blocked = ("Needs level %d"):format(r.level) end
        if not done and fishBlock then a.blocked = a.blocked or fishBlock end
        if a.blocked and not fishBlock then fishBlock = "Needs " .. r.name .. " Fishing" end
        if not done and r.item then
          local p = NW.Price(r.item)
          a.cost = p or r.price
          plan.fees = plan.fees + (a.cost or 0)
        end
      end
      if ti >= 2 and cookHere then
        local ru = NW.RANKS[ti]
        local done = cookMax and cookMax >= hi or false
        local a = add({ kind = "train", prof = "cooking", crank = ru, label = "Train " .. ru.name .. " Cooking", done = done })
        if not done and ru.level and level < ru.level then a.blocked = ("Needs level %d"):format(ru.level) end
        if not done and cookBlock then a.blocked = a.blocked or cookBlock end
        if a.blocked and not cookBlock then cookBlock = "Needs " .. ru.name .. " Cooking" end
        local fee = (NW.RANK_FEE.cooking or {})[ru.name]
        if not done and fee then a.cost = fee; plan.fees = plan.fees + fee end
      end
      -- recipes this phase needs
      for _, st in ipairs(cookSteps) do
        local r = st.recipe
        if r and st.needsRecipe and not seenR[r.name] then
          seenR[r.name] = true
          local a = add({ kind = "recipe", recipe = r, label = "Get recipe: " .. r.name, done = known[r.name] or false })
          if not a.done and (cookBlock or gapBlock) and (lo >= cookCap or (r.orange or r.yellow) >= cookCap) then a.blocked = cookBlock or gapBlock end
          if r.recipeItem then
            local p, src = NW.Price(r.recipeItem)
            if p and (src == "ah" or src == "vendor") then a.cost = p end
          end
          if not a.done then plan.recipes[#plan.recipes + 1] = a end
        end
      end
      -- what the phase's cooking takes
      local fishNeed, fishOrder, vend, other = {}, {}, {}, {}
      for _, st in ipairs(cookSteps) do
        for _, m in ipairs(st.mats or {}) do
          local id, n = m[1], m[2]
          if F.FISH[id] then
            if not fishNeed[id] then fishOrder[#fishOrder + 1] = id end
            fishNeed[id] = (fishNeed[id] or 0) + n
          elseif NW.IsVendor(id) then vend[id] = (vend[id] or 0) + n
          else other[id] = (other[id] or 0) + n end
        end
      end
      local vlist, vdone = {}, true
      for id, n in pairs(vend) do
        local h = math.min(have(id), n)
        left[id] = have(id) - h
        vlist[#vlist + 1] = { id = id, need = n, have = h }
        if h < n then vdone = false end
      end
      table.sort(vlist, function(x, y) return x.id < y.id end)
      if #vlist > 0 then
        local va = add({ kind = "vendor", items = vlist, label = "Buy vendor supplies", done = vdone })
        if not vdone and (cookBlock or gapBlock) then va.blocked = cookBlock or gapBlock end
        for _, e in ipairs(vlist) do plan.vendor[#plan.vendor + 1] = e end
      end
      local olist = {}
      for id, n in pairs(other) do
        local h = math.min(have(id), n)
        left[id] = have(id) - h
        olist[#olist + 1] = { id = id, need = n, have = h }
      end
      table.sort(olist, function(x, y) return x.id < y.id end)
      if #olist > 0 then
        local odone = true
        for _, e in ipairs(olist) do if e.have < e.need then odone = false end end
        local oa = add({ kind = "other", items = olist, label = "Get other ingredients", done = odone })
        if not odone and (cookBlock or gapBlock) then oa.blocked = cookBlock or gapBlock end
        for _, e in ipairs(olist) do plan.buy[#plan.buy + 1] = e end
      end
      if fishHere then
        local bi, b = F.bracketFor(math.max(base, lo))
        local fa = add({ kind = "fishto", from = math.max(base, lo), to = fishAtEnd, bracket = bi, b = b,
          label = ("Fish to %d"):format(fishAtEnd), done = (fishNow or 0) >= fishAtEnd })
        if not fa.done and fishBlock and fishAtEnd > fishCap then fa.blocked = fishBlock end
      end
      for _, id in ipairs(fishOrder) do
        local n = fishNeed[id]
        local h = math.min(have(id), n)
        left[id] = have(id) - h
        local f = F.FISH[id]
        local reach = f.skill and f.skill <= math.max(fishAtEnd, base)
        local buy = c.buyFish and not reach
        local a = add({ kind = "catch", fish = id, need = n, have = h, buy = buy,
          label = (buy and "Buy " or "Catch ") .. (F.itemName(id)), done = h >= n })
        if not reach and not c.buyFish then
          a.blocked = f.skill and ("Needs Fishing %d"):format(f.skill) or "No fishing data for it"
        elseif not a.done and not buy and fishBlock and f.skill and f.skill > fishCap then
          a.blocked = fishBlock
        end
        local pr = NW.Price(id)
        a.value = pr and pr * n or nil
        plan.fish[#plan.fish + 1] = a
      end
      for _, st in ipairs(cookSteps) do
        if st.recipe then
          local ca = add({ kind = "cook", step = st, recipe = st.recipe, label = ("Cook %s"):format(st.recipe.name),
            done = (cookNow or 0) >= st.to })
          if not ca.done then
            if gapBlock then ca.blocked = gapBlock
            elseif cookBlock and st.to > cookCap then ca.blocked = cookBlock end
          end
        else
          local a = add({ kind = "gap", step = st, label = ("No recipe for %d-%d"):format(st.from, st.to), done = false })
          a.blocked = c.nonFish and "Nothing in the data" or "Allow non-fish recipes"
          gapBlock = gapBlock or ("Needs a recipe for %d-%d"):format(st.from, st.to)
        end
      end
      -- the phase is finished when everything in it is
      local all = true
      for _, a in ipairs(ph.actions) do if not a.done then all = false end end
      ph.done = all and #ph.actions > 0
      if #ph.actions > 0 then plan.phases[#plan.phases + 1] = ph end
    end
  end
  -- the next thing to do: the first step not done and not blocked
  for _, ph in ipairs(plan.phases) do
    for _, a in ipairs(ph.actions) do
      if not a.done and not a.blocked and not nextFound then nextFound = a end
    end
    if nextFound and not plan.current then plan.current = nextFound.phase end
  end
  plan.next = nextFound
  -- money: what you'll pay, and what your catch is worth
  local pay, value, unknown = plan.fees, 0, false
  for _, a in ipairs(plan.recipes) do if a.cost then pay = pay + a.cost else unknown = true end end
  for _, e in ipairs(plan.vendor) do
    local p = NW.Price(e.id)
    if p then pay = pay + p * (e.need - e.have) end
  end
  for _, e in ipairs(plan.buy) do
    local p, src = NW.Price(e.id)
    if p and src ~= "est" then pay = pay + p * (e.need - e.have) elseif e.need > e.have then unknown = true end
  end
  for _, a in ipairs(plan.fish) do
    local p, src = NW.Price(a.fish)
    if a.buy then
      if p and src ~= "est" then pay = pay + p * (a.need - a.have) elseif a.need > a.have then unknown = true end
    elseif p and src ~= "est" then
      value = value + p * a.need
    end
  end
  plan.pay, plan.value, plan.unknownPrice = pay, value, unknown
  return plan
end

------------------------------------------------------------------------
-- Page
------------------------------------------------------------------------
local L = NW.ProfUI
if not L then return end
local MID_W, RIGHT_W = L.MID_W, L.RIGHT_W
local GAP = L.RIGHT_X - L.MID_X - L.MID_W
local fp = CreateFrame("Frame", nil, L.page)
fp:SetPoint("TOPLEFT", L.MID_X, -8)
fp:SetSize(MID_W + GAP + RIGHT_W, 530)
fp:Hide()
F.frame = fp
local W = {} -- widgets

local function st() return NW.db.settings end
local function tab() return st().fishTab or "leveling" end
local function money(c, mode) return c and NW.Money(c, mode or "mid") or (H.dim .. "–|r") end

-- header
W.iconBox = UI.Box(fp, 38, 38)
W.iconBox:SetPoint("TOPLEFT")
W.icon = W.iconBox:CreateTexture(nil, "ARTWORK")
W.icon:SetPoint("TOPLEFT", 1, -1)
W.icon:SetPoint("BOTTOMRIGHT", -1, 1)
W.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
W.icon:SetTexture("Interface\\Icons\\Trade_Fishing")
W.name = UI.Text(fp, 17, S.gold)
W.name:SetPoint("TOPLEFT", W.iconBox, "TOPRIGHT", 10, -1)
W.name:SetText("Fishing")
W.skill = UI.Text(fp, 12, S.dim)
W.skill:SetPoint("TOPLEFT", W.name, "BOTTOMLEFT", 0, -5)
W.skill:SetWidth(MID_W - 60)
W.skill:SetWordWrap(false)
W.next = UI.Text(fp, 11, S.dim, "RIGHT")
W.next:SetPoint("TOPRIGHT", fp, "TOPLEFT", MID_W, -4)
W.next2 = UI.Text(fp, 11, S.dim, "RIGHT")
W.next2:SetPoint("TOPRIGHT", W.next, "BOTTOMRIGHT", 0, -4)

-- sub-tabs, styled like a craft's views
W.tabs = {}
do
  local TABS = { { "leveling", "Leveling", 84 }, { "finder", "Fish Finder", 100 }, { "combined", "Fishing + Cooking", 136 }, { "journal", "Journal", 76 } }
  local x = 0
  for _, t in ipairs(TABS) do
    local b = CreateFrame("Button", nil, fp, "BackdropTemplate")
    b:SetSize(t[3], 26)
    b:SetPoint("TOPLEFT", W.iconBox, "BOTTOMLEFT", x, -10)
    x = x + t[3] + 4
    UI.Flat(b, S.cell, S.edge)
    b.label = UI.Text(b, 12, S.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(t[2])
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetPoint("BOTTOMLEFT", 1, 1)
    b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    b.bar:SetHeight(2)
    b.bar:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 1)
    function b:SetSelected(on)
      self.on = on
      self.bar:SetShown(on)
      self.label:SetTextColor(unpack(on and S.gold or S.dim))
      self:SetBackdropColor(unpack(on and S.hover or S.cell))
    end
    b:SetScript("OnEnter", function(self) if not self.on then self.label:SetTextColor(unpack(S.text)) end end)
    b:SetScript("OnLeave", function(self) self:SetSelected(self.on) end)
    b:SetScript("OnClick", function() st().fishTab = t[1]; F.sel = nil; F.offset = 0; F.Redraw() end)
    W.tabs[t[1]] = b
  end
end

-- the list in the middle
local TOP = 84
local ROW_H, HEAD_H = 24, 22
W.box = UI.Box(fp, MID_W, 530 - TOP)
W.box:SetPoint("TOPLEFT", 0, -TOP)
W.box:EnableMouseWheel(true)
W.empty = UI.Text(W.box, 12, S.dim, "CENTER")
W.empty:SetPoint("CENTER")
W.thumb = W.box:CreateTexture(nil, "OVERLAY")
W.thumb:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.6)
W.thumb:SetWidth(3)
F.items, F.offset = {}, 0
W.rows = {}
local function mark(state)
  if state == "done" then return "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t" end
  if state == "blocked" then return "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12:0:0|t" end
  if state == "next" then return "|TInterface\\ChatFrame\\ChatFrameExpandArrow:12:12:0:0|t" end
  return ""
end
for i = 1, 24 do
  local r = CreateFrame("Button", nil, W.box)
  r:SetSize(MID_W - 8, ROW_H)
  UI.RowStripe(r)
  UI.RowHighlight(r)
  r.headBg = r:CreateTexture(nil, "BACKGROUND", nil, 2)
  r.headBg:SetAllPoints()
  r.headBg:SetColorTexture(unpack(S.header))
  r.mark = UI.Text(r, 12, S.text, "CENTER")
  r.mark:SetPoint("LEFT", 2, 0)
  r.mark:SetWidth(16)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT", 20, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.text = UI.Text(r, 12, S.text)
  r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.text:SetWidth(MID_W - 200)
  r.text:SetWordWrap(false)
  r.right = UI.Text(r, 11, S.dim, "RIGHT")
  r.right:SetPoint("RIGHT", -6, 0)
  r.right:SetWidth(150)
  r.right:SetWordWrap(false)
  r.icons = {}
  for k = 1, 5 do
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetSize(16, 16)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:SetPoint("RIGHT", r, "RIGHT", -6 - (k - 1) * 19, 0)
    t:Hide()
    r.icons[k] = t
  end
  r:SetScript("OnClick", function(self)
    local it = self.item
    if not it then return end
    if it.head then
      local folds = F.cfg().folds
      folds[it.foldKey] = not it.folded
      F.Redraw()
      return
    end
    F.sel = it.selKey
    F.confirmDelete = nil
    F.Redraw()
  end)
  r:SetScript("OnEnter", function(self)
    local it = self.item
    if it and it.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      it.tip(GameTooltip)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.rows[i] = r
end
F.boxH = 530 - TOP
function F.drawRows()
  local h = F.boxH - 4
  local fit = math.floor(h / ROW_H)
  F.offset = math.max(0, math.min(F.offset or 0, math.max(0, #F.items - fit)))
  local y = 2
  for i, r in ipairs(W.rows) do
    local it = F.items[i + F.offset]
    r.item = it
    if it and i <= fit then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 4, -y)
      local rh = it.head and HEAD_H or ROW_H
      r:SetHeight(rh - 1)
      y = y + rh
      r:Show()
      r.headBg:SetShown(it.head and true or false)
      r:SetStripe(not it.head and (i % 2 == 0))
      r:SetSelected(not it.head and it.selKey ~= nil and it.selKey == F.sel)
      r:SetAlpha(it.dim and 0.55 or 1)
      if it.head then
        r.mark:SetText("")
        r.icon:SetTexture(("Interface\\Buttons\\UI-%sButton-Up"):format(it.folded and "Plus" or "Minus"))
        r.icon:SetSize(14, 14)
        r.icon:SetTexCoord(0, 1, 0, 1)
        r.text:SetText(H.gold .. it.text .. "|r")
      else
        r.mark:SetText(it.mark or "")
        r.icon:SetSize(18, 18)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon:SetTexture(it.icon)
        r.text:SetText(it.text)
      end
      r.icon:SetShown(it.icon ~= nil or it.head)
      r.icon:SetDesaturated(it.desat and true or false)
      r.right:SetText(it.right or "")
      for k, t in ipairs(r.icons) do
        local id = it.fishIcons and it.fishIcons[k]
        t:SetShown(id ~= nil)
        if id then t:SetTexture(NW.ItemIcon(id)) end
      end
      if it.fishIcons and #it.fishIcons > 0 then r.right:SetText("") end
    else
      r:Hide()
    end
  end
  if #F.items > fit and fit > 0 then
    local total = #F.items
    local th = math.max(20, h * fit / total)
    W.thumb:SetHeight(th)
    W.thumb:ClearAllPoints()
    W.thumb:SetPoint("TOPRIGHT", W.box, "TOPRIGHT", -1, -2 - (h - th) * (F.offset / math.max(1, total - fit)))
    W.thumb:Show()
  else
    W.thumb:Hide()
  end
end
W.box:SetScript("OnMouseWheel", function(_, d)
  F.offset = (F.offset or 0) - d * 2
  F.drawRows()
end)

-- the right panel: what's selected
local RX = MID_W + GAP
W.right = CreateFrame("Frame", nil, fp)
W.right:SetPoint("TOPLEFT", RX, -TOP + 0)
W.right:SetSize(RIGHT_W, 530 - TOP)
W.rHead = UI.Heading(W.right, "", RIGHT_W)
W.rHead:SetPoint("TOPLEFT")
W.rIconBox = UI.Box(W.right, 32, 32)
W.rIconBox:SetPoint("TOPLEFT", W.rHead, "BOTTOMLEFT", 0, -8)
W.rIcon = W.rIconBox:CreateTexture(nil, "ARTWORK")
W.rIcon:SetPoint("TOPLEFT", 1, -1)
W.rIcon:SetPoint("BOTTOMRIGHT", -1, 1)
W.rIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
W.rTitle = UI.Text(W.right, 13, S.text)
W.rTitle:SetPoint("TOPLEFT", W.rIconBox, "TOPRIGHT", 8, -1)
W.rTitle:SetWidth(RIGHT_W - 44)
W.rTitle:SetWordWrap(false)
W.rSub = UI.Text(W.right, 11, S.dim)
W.rSub:SetPoint("TOPLEFT", W.rTitle, "BOTTOMLEFT", 0, -4)
W.rSub:SetWidth(RIGHT_W - 44)
W.rSub:SetWordWrap(false)
-- label / value lines and plain lines, laid out top to bottom
W.lines = {}
for i = 1, 28 do
  local l = UI.Text(W.right, 11, S.dim)
  local v = UI.Text(W.right, 11, S.text, "RIGHT")
  l:SetWordWrap(false)
  W.lines[i] = { l = l, v = v }
end
W.bars = {}
for i = 1, 8 do
  local b = CreateFrame("StatusBar", nil, W.right)
  b:SetSize(RIGHT_W, 5)
  b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  b:SetStatusBarColor(unpack(F.BLUE))
  b:SetMinMaxValues(0, 1)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(S.sunk))
  b:Hide()
  W.bars[i] = b
end
-- a zone's map with your catch spots (2% squares, sized by how many)
local MAP_W, MAP_H = 240, 160
W.map = UI.Box(W.right, MAP_W, MAP_H)
W.map:Hide()
W.mapArt = CreateFrame("Frame", nil, W.map)
W.mapArt:SetPoint("TOPLEFT", 1, -1)
W.mapArt:SetSize(MAP_W - 2, MAP_H - 2)
W.mapTiles, W.dots = {}, {}
function F.drawMap(mapID, spots)
  UI.DrawZoneArt(mapID, W.mapArt, W.mapTiles, MAP_W - 2, MAP_H - 2, true)
  local most = 1
  for _, sp in ipairs(spots) do if sp.n > most then most = sp.n end end
  table.sort(spots, function(a, b) return a.n > b.n end)
  for i = 1, math.max(#W.dots, math.min(#spots, 200)) do
    local sp = i <= 200 and spots[i]
    local d = W.dots[i]
    if sp then
      if not d then
        d = W.mapArt:CreateTexture(nil, "OVERLAY")
        d:SetColorTexture(F.BLUE[1], F.BLUE[2], F.BLUE[3], 0.9)
        W.dots[i] = d
      end
      local size = 3 + math.floor(5 * math.sqrt(sp.n / most))
      d:SetSize(size, size)
      d:ClearAllPoints()
      d:SetPoint("CENTER", W.mapArt, "TOPLEFT", sp.x * (MAP_W - 2), -sp.y * (MAP_H - 2))
      d:Show()
    elseif d then
      d:Hide()
    end
  end
end
W.btn1 = UI.Button(W.right, "Show on map", math.floor((RIGHT_W - 6) / 2), nil, 24)
W.btn2 = UI.Button(W.right, "", math.floor((RIGHT_W - 6) / 2), nil, 24)
W.btn1:Hide() W.btn2:Hide()

-- rows: { label, value } (value nil: a full-width line), "gap", { head = text }, { bar = 0..1 }
function F.detail(head, icon, title, sub, rows, b1, b2)
  W.rHead.text:SetText(head or "")
  W.rIconBox:SetShown(icon ~= nil)
  W.rIcon:SetTexture(icon)
  W.rTitle:SetText(title or "")
  W.rSub:SetText(sub or "")
  local anchor, y = icon and W.rIconBox or W.rHead, icon and -10 or -6
  for _, b in ipairs(W.bars) do b:Hide() end
  W.map:Hide()
  local n, nb = 0, 0
  for _, row in ipairs(rows or {}) do
    if row == "gap" then
      y = y - 6
    elseif row.bar then
      if nb < #W.bars then
        nb = nb + 1
        local b = W.bars[nb]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y - 1)
        b:SetValue(row.bar)
        b:Show()
        y = y - 9
      end
    elseif row.map then
      W.map:ClearAllPoints()
      W.map:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y - 4)
      W.map:Show()
      F.drawMap(row.map, row.spots or {})
      y = y - MAP_H - 8
    elseif n < #W.lines then
      n = n + 1
      local ln = W.lines[n]
      ln.l:ClearAllPoints()
      ln.v:ClearAllPoints()
      ln.l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
      if row.head then
        ln.l:SetFont(UI.FONT, 10, "")
        ln.l:SetTextColor(unpack(S.gold))
        ln.l:SetText(row.head:upper())
        ln.l:SetWidth(RIGHT_W)
        ln.v:SetText("")
        y = y - 16
      elseif row[2] ~= nil then
        ln.l:SetFont(UI.FONT, 11, "")
        ln.l:SetTextColor(unpack(S.dim))
        ln.l:SetText(row[1])
        -- the value on the same line as its label, and the label gets whatever the value leaves
        ln.v:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", RIGHT_W, y)
        ln.v:SetWidth(0)
        ln.v:SetText(row[2])
        local vw = math.min(150, math.ceil(ln.v:GetStringWidth() or 0))
        ln.v:SetWidth(vw + 2)
        ln.l:SetWidth(math.max(60, RIGHT_W - vw - 10))
        y = y - 15
      else
        ln.l:SetFont(UI.FONT, 11, "")
        ln.l:SetTextColor(unpack(row.color or S.text))
        ln.l:SetText(row[1])
        ln.l:SetWidth(RIGHT_W)
        ln.v:SetText("")
        y = y - 15
      end
      ln.l:Show() ln.v:Show()
    end
  end
  for i = n + 1, #W.lines do W.lines[i].l:Hide() W.lines[i].v:Hide() end
  local function place(b, spec, x)
    if not spec then b:Hide() return end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y - 8)
    b:SetWidth(b2 and b1 and math.floor((RIGHT_W - 6) / 2) or RIGHT_W)
    b:SetText(spec[1])
    b:SetScript("OnClick", spec[2])
    b:SetEnabled(spec[2] ~= nil)
    b:Show()
  end
  place(W.btn1, b1, 0)
  place(W.btn2, b2, b1 and (math.floor((RIGHT_W - 6) / 2) + 6) or 0)
end

-- open a zone's map (fishing data is by zone, so no pin)
function F.showZone(zone)
  local id = NW.ZoneID and NW.ZoneID(zone)
  if not id then return nil end
  return function()
    if OpenWorldMap then pcall(OpenWorldMap, id) end
  end
end

------------------------------------------------------------------------
-- Leveling: skill ranges, where to fish, when to train
------------------------------------------------------------------------
local function rankTip(r)
  return function(tt)
    tt:SetText(r.name .. " Fishing", 1, 1, 1)
    if r.skill then tt:AddDoubleLine("Skill", r.skill, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    if r.level then tt:AddDoubleLine("Level", r.level, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    tt:AddLine(r.how, 1, 0.82, 0, true)
  end
end
function F.leveling()
  local rank, max, bonus = F.skill()
  local base = rank or 0
  local folds = F.cfg().folds
  local items = {}
  for bi, b in ipairs(F.BRACKETS) do
    local r = F.RANKS[bi]
    local done = base >= b[2]
    local cur = base >= b[1] and base < b[2] or (bi == 1 and not rank)
    local key = "lvl" .. bi
    local folded = folds[key]
    if folded == nil then folded = done end
    items[#items + 1] = { head = true, text = ("%s  %d-%d%s"):format(r.name, b[1], b[2], done and ("   " .. H.good .. "done|r") or cur and ("   " .. H.gold .. "now|r") or ""),
      foldKey = key, folded = folded }
    if not folded then
      if bi > 1 then
        local trained = max and max >= r.cap
        items[#items + 1] = { icon = r.item and NW.ItemIcon(r.item) or "Interface\\Icons\\INV_Misc_Book_09",
          mark = trained and mark("done") or mark(), text = H.gold .. "Train " .. r.name .. "|r",
          right = ("skill %d, level %d"):format(r.skill, r.level), selKey = "rank" .. bi, tip = rankTip(r), dim = trained }
      end
      for _, z in ipairs(F.sortZones(b.zones)) do
        local here, range = F.fishIn(z, bi)
        local icons = {}
        for _, id in ipairs(here) do icons[#icons + 1] = id end
        if #icons == 0 then for _, id in ipairs(range) do if #icons < 5 then icons[#icons + 1] = id end end end
        local name = z
        if b.best == z then name = name .. "  " .. H.gold .. "best|r" end
        if F.hostile(z) then name = H.dim .. z .. "|r" end
        items[#items + 1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", text = name, fishIcons = icons,
          selKey = "zone" .. bi .. ":" .. z, zone = z, bi = bi, dim = done }
      end
      for _, z in ipairs(b.later or {}) do
        items[#items + 1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", text = z, right = ("from %d with a lure"):format(b.laterAt),
          selKey = "zone" .. bi .. ":" .. z, zone = z, bi = bi, later = b.laterAt, dim = done }
      end
    end
  end
  return items
end

function F.equipLines(rows)
  local rank, _, bonus = F.skill()
  if not rank then return end
  local lure = F.lureOn()
  rows[#rows + 1] = "gap"
  rows[#rows + 1] = { head = "Your fishing" }
  rows[#rows + 1] = { "Skill", tostring(rank) }
  rows[#rows + 1] = { "Gear and lures", bonus > 0 and ("+" .. bonus) or "0" }
  rows[#rows + 1] = { "Effective", BLUE_HEX .. (rank + bonus) .. "|r" }
  if lure ~= nil then rows[#rows + 1] = { "Lure", lure and (lure .. " min left") or (H.dim .. "none|r") } end
end

local function lureFor(b, rows)
  if not b.lure then return end
  local _, _, bonus = F.skill()
  local want
  for _, l in ipairs(F.LURES) do if l[1] == b.lure then want = l end end
  if not want then return end
  local name = F.itemName(want[1], LURE_NAME[want[1]])
  local ok = bonus >= want[2]
  rows[#rows + 1] = { "Lure", ok and (H.good .. "+" .. bonus .. " on|r") or ("%s +%d"):format(name, want[2]) }
end

local function fishLines(rows, ids, title)
  if #ids == 0 then return end
  rows[#rows + 1] = { head = title }
  for _, id in ipairs(ids) do
    local f = F.FISH[id]
    local n = NW.ItemCount(id) or 0
    local name = F.itemName(id):gsub("^Raw ", "")
    rows[#rows + 1] = { ("|T%s:14:14:0:0|t %s%s"):format(NW.ItemIcon(id) or "", name, f.note and (H.dim .. "  " .. f.note:lower() .. "|r") or ""),
      n > 0 and tostring(n) or "" }
  end
end

function F.zoneDetail(zone, bi, later)
  local b = F.BRACKETS[bi]
  local here, range = F.fishIn(zone, bi)
  local rows = {
    { head = "Fishing" },
    { "Recommended", later and ("%d+ with a lure"):format(later) or ("%d-%d"):format(b[1], b[2]) },
    { "Zone minimum", H.dim .. "not published|r" },
  }
  lureFor(b, rows)
  rows[#rows + 1] = "gap"
  fishLines(rows, here, "Caught here")
  fishLines(rows, range, #here > 0 and "Also at this skill" or "Fish at this skill")
  -- what you can cook from them
  local cook = NW.ProfSkill("cooking")
  local seen, uses = {}, {}
  for _, id in ipairs(here) do for _, r in ipairs(NW.CookFish(id)) do if not seen[r] then seen[r] = true; uses[#uses + 1] = r end end end
  for _, id in ipairs(range) do for _, r in ipairs(NW.CookFish(id)) do if not seen[r] then seen[r] = true; uses[#uses + 1] = r end end end
  if #uses > 0 then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Cooking" }
    for k = 1, math.min(5, #uses) do
      local r = uses[k]
      local col = (not cook or cook < (r.orange or r.yellow)) and H.dim or cook < r.grey and H.text or H.dim
      rows[#rows + 1] = { col .. r.name .. "|r", ("%d-%d"):format(r.orange or r.yellow, r.grey) }
    end
  end
  F.equipLines(rows)
  local sub = F.hostile(zone) and "The other faction's city" or (b.best == zone and "Best for this skill range" or ("Fishing %d-%d"):format(b[1], b[2]))
  F.detail("Location", "Interface\\Icons\\INV_Misc_Map_01", zone, sub, rows, { "Show on map", F.showZone(zone) })
end

function F.rankDetail(r, prof)
  local level = UnitLevel and UnitLevel("player") or 60
  local rows = { { head = "Requirements" } }
  if r.skill then rows[#rows + 1] = { "Skill", tostring(r.skill) } end
  if r.level then rows[#rows + 1] = { "Level", (level >= r.level and H.good or H.bad) .. r.level .. "|r" } end
  rows[#rows + 1] = "gap"
  rows[#rows + 1] = { head = "Source" }
  rows[#rows + 1] = { r.how }
  if r.who then rows[#rows + 1] = { r.who .. ", " .. r.where, color = S.dim } end
  if r.item then
    local p = NW.Price(r.item)
    rows[#rows + 1] = { "Cost", money(p or r.price) }
    if r.note then rows[#rows + 1] = { r.note, color = S.dim } end
  end
  if r.quest then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Quest fish" }
    for _, q in ipairs(r.quest) do rows[#rows + 1] = { q[1] .. H.dim .. "  " .. q[2] .. "|r" } end
  end
  if not r.who then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Trainers" }
    local list = F.TRAINERS[F.faction()] or {}
    for k = 1, math.min(6, #list) do rows[#rows + 1] = { list[k], color = S.dim } end
    rows[#rows + 1] = { F.TRAINERS.both[1], color = S.dim }
  end
  local mapFn = r.map and function() if OpenWorldMap then pcall(OpenWorldMap, r.map) end end or nil
  F.detail("Training", r.item and NW.ItemIcon(r.item) or "Interface\\Icons\\INV_Misc_Book_09", r.name .. " Fishing",
    ("Fishing to %d"):format(r.cap), rows, mapFn and { "Show on map", mapFn } or nil)
end

------------------------------------------------------------------------
-- Fish Finder
------------------------------------------------------------------------
function F.finderItems()
  local c = F.cfg()
  local rank, _, bonus = F.skill()
  local eff = (rank or 0) + (bonus or 0)
  local inPlan = {}
  if c.fPlan then
    local ok, plan = pcall(F.Build)
    if ok then for _, a in ipairs(plan.fish) do inPlan[a.fish] = true end end
  end
  local q = (F.search or ""):lower()
  local items = {}
  for _, id in ipairs(F.ORDER) do
    local f = F.FISH[id]
    local name = F.itemName(id)
    local ok = true
    if q ~= "" and not name:lower():find(q, 1, true) then ok = false end
    if c.fNow and not (f.skill and f.skill <= eff) then ok = false end
    if c.fCook and #NW.CookFish(id) == 0 then ok = false end
    if c.fPlan and not inPlan[id] then ok = false end
    if ok then
      local n = NW.ItemCount(id) or 0
      local p = NW.Price(id)
      local can = f.skill and f.skill <= eff
      items[#items + 1] = { icon = NW.ItemIcon(id), selKey = "fish" .. id, fish = id,
        text = (can and H.text or H.dim) .. name:gsub("^Raw ", "") .. "|r" .. (n > 0 and (H.good .. "  " .. n .. "|r") or ""),
        right = (f.skill and ("%d  ·  "):format(f.skill) or "–  ·  ") .. money(p),
        mark = can and mark("done") or "" }
    end
  end
  return items
end

function F.fishDetail(id)
  local f = F.FISH[id]
  local zones, named = F.zonesFor(id)
  local rows = { { head = "Fishing" } }
  rows[#rows + 1] = { "Fished from", f.skill and tostring(f.skill) or (H.dim .. "not known|r") }
  if f.note then rows[#rows + 1] = { "Where", f.note } end
  rows[#rows + 1] = { "In your bags", tostring(NW.ItemCount(id) or 0) }
  local p, src = NW.Price(id)
  rows[#rows + 1] = { "Auction house", (p and src == "ah") and NW.Money(p, "mid") or (H.dim .. "no price|r") }
  rows[#rows + 1] = "gap"
  if #zones > 0 then
    rows[#rows + 1] = { head = named and "Known locations" or "Waters at this skill" }
    for k = 1, math.min(5, #zones) do rows[#rows + 1] = { zones[k], color = F.hostile(zones[k]) and S.dim or S.text } end
  else
    rows[#rows + 1] = { "Not in Nodewalker's fishing data.", color = S.dim }
  end
  -- where you've caught it yourself (all your characters)
  local mine = NW.FishJournal and NW.FishJournal.ZonesFor(id, "all") or {}
  if #mine > 0 then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Your catches" }
    for k = 1, math.min(3, #mine) do rows[#rows + 1] = { NW.FishJournal.zoneName(mine[k].map), ("%d caught"):format(mine[k].n) } end
  end
  local uses = NW.CookFish(id)
  if #uses > 0 then
    local cook = NW.ProfSkill("cooking")
    local known = NW.charDB.known.cooking or {}
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Used in" }
    for k = 1, math.min(3, #uses) do
      local r = uses[k]
      local tag = known[r.name] and (H.good .. "  known|r") or ""
      rows[#rows + 1] = { r.name .. tag, ("%d-%d"):format(r.orange or r.yellow, r.grey) }
    end
  end
  F.detail("Fish", NW.ItemIcon(id), F.itemName(id), named and "Zones from WoW Forever guides" or (f.bracket and "Zones by skill range" or ""),
    rows, zones[1] and { "Show on map", F.showZone(zones[1]) } or nil,
    #uses > 0 and { "Cooking plan", function() NW.OpenProfession("cooking") end } or nil)
end

------------------------------------------------------------------------
-- Fishing + Cooking
------------------------------------------------------------------------
W.combo = CreateFrame("Frame", nil, fp)
W.combo:SetPoint("TOPLEFT", 0, -TOP)
W.combo:SetSize(MID_W, 58)
W.combo:Hide()
local function profLine(y, key, label, color)
  local f = CreateFrame("Frame", nil, W.combo)
  f:SetSize(MID_W, 22)
  f:SetPoint("TOPLEFT", 0, y)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(16, 16)
  f.icon:SetPoint("LEFT")
  f.icon:SetTexture(NW.PROF_BY_KEY[key].icon)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.name = UI.Text(f, 12, S.text)
  f.name:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
  f.name:SetText(label)
  f.val = UI.Text(f, 12, S.text, "RIGHT")
  f.val:SetPoint("LEFT", 90, 0)
  f.val:SetWidth(70)
  f.barBg = f:CreateTexture(nil, "BACKGROUND")
  f.barBg:SetColorTexture(unpack(S.sunk))
  f.barBg:SetSize(150, 5)
  f.barBg:SetPoint("LEFT", 170, 0)
  f.bar = f:CreateTexture(nil, "ARTWORK")
  f.bar:SetColorTexture(unpack(color))
  f.bar:SetHeight(5)
  f.bar:SetPoint("LEFT", f.barBg, "LEFT")
  local field = key == "fishing" and "fishTo" or "cookTo"
  f.target = UI.Dropdown(f, 150, "Target", { { 75, "75" }, { 150, "150" }, { 225, "225" }, { 300, "300" } },
    function() return F.cfg()[field] or 300 end, function(v) F.cfg()[field] = v; F.Redraw() end, 70)
  f.target:SetPoint("RIGHT", 0, 0)
  return f
end
W.fishLine = profLine(0, "fishing", "Fishing", F.BLUE)
W.cookLine = profLine(-24, "cooking", "Cooking", S.gold)
W.box2y = TOP + 56
W.mode = UI.Dropdown(W.combo, 220, "Fish", { { false, "Catch them" }, { true, "Catch or buy" } },
  function() return F.cfg().buyFish or false end, function(v) F.cfg().buyFish = v or nil; F.Redraw() end, 170,
  "Catch them: never plans to buy fish. Catch or buy: buys a fish you can't catch yet.")
W.opts = UI.CheckMenu(W.combo, "Options", 100, {
  { "Non-fish recipes", function() return F.cfg().nonFish end, function(v) F.cfg().nonFish = v or nil end,
    "Meat and other ingredients you'd buy or farm, where they're cheaper or fill a gap." },
  { "Recipes to buy", function() return not F.cfg().noRecipes end, function(v) F.cfg().noRecipes = (not v) or nil end,
    "Plans with vendor and drop recipes. Off: trainer and known recipes first, bought ones only where nothing else gives skill-ups." },
  { "Vendor supplies", function() return not F.cfg().noVendor end, function(v) F.cfg().noVendor = (not v) or nil end,
    "Spices, flour and the like." },
}, function() F.Redraw() end)

local KIND_ICON = { fishto = "Interface\\Icons\\Trade_Fishing", vendor = "Interface\\Icons\\INV_Misc_Coin_01",
  other = "Interface\\Icons\\INV_Misc_Bag_10", gap = "Interface\\Icons\\INV_Misc_QuestionMark" }
local function actionIcon(a)
  if a.kind == "learn" then return NW.PROF_BY_KEY[a.prof].icon end
  if a.kind == "train" then return (a.rank and a.rank.item and NW.ItemIcon(a.rank.item)) or "Interface\\Icons\\INV_Misc_Book_09" end
  if a.kind == "recipe" then return a.recipe.recipeItem and NW.ItemIcon(a.recipe.recipeItem) or "Interface\\Icons\\INV_Scroll_03" end
  if a.kind == "catch" then return NW.ItemIcon(a.fish) end
  if a.kind == "cook" then return a.recipe.item and NW.ItemIcon(a.recipe.item) or NW.PROF_BY_KEY.cooking.icon end
  return KIND_ICON[a.kind]
end
local function actionRight(a)
  if a.kind == "catch" then
    return ("%s%d|r%s/~%d"):format(a.have >= a.need and H.good or H.text, a.have, H.dim, a.need)
  elseif a.kind == "cook" then
    return ("%d-%d  ·  ×%d"):format(a.step.from, a.step.to, a.step.crafts)
  elseif a.kind == "fishto" then
    return ("%d-%d"):format(a.from, a.to)
  elseif a.kind == "train" then
    local r = a.rank or a.crank
    return a.blocked and (H.bad .. a.blocked .. "|r") or (r.skill and ("skill %d"):format(r.skill) or "")
  elseif a.kind == "recipe" then
    return money(a.cost)
  end
  return a.blocked and (H.bad .. a.blocked .. "|r") or ""
end
function F.combinedItems(plan)
  local folds = F.cfg().folds
  local items = {}
  for _, ph in ipairs(plan.phases) do
    local key = "ph" .. ph.ti
    local folded = folds[key]
    if folded == nil then folded = ph.done end
    local tag = ph.done and ("   " .. H.good .. "done|r") or (plan.current == ph and ("   " .. H.gold .. "now|r") or "")
    items[#items + 1] = { head = true, text = ("Phase %d  %s  %d-%d%s"):format(ph.ti, ph.name, ph.lo, ph.hi, tag), foldKey = key, folded = folded }
    if not folded then
      for ai, a in ipairs(ph.actions) do
        local state = a.done and "done" or a.blocked and "blocked" or (plan.next == a and "next") or nil
        local label = a.label
        if plan.next == a then label = H.gold .. label .. "|r" elseif a.blocked then label = H.dim .. label .. "|r" end
        if a.kind == "catch" and a.done and not a.blocked then label = label .. H.good .. "  collected|r" end
        items[#items + 1] = { icon = actionIcon(a), mark = mark(state), text = label, right = actionRight(a),
          selKey = ("a%d:%d"):format(ph.ti, ai), action = a, dim = a.done or ph.done }
      end
    end
  end
  return items
end

function F.actionDetail(a, plan)
  local k = a.kind
  if k == "catch" then
    local f = F.FISH[a.fish]
    local zones, named = F.zonesFor(a.fish)
    local rows = {
      { head = a.buy and "Buy" or "Collection target" },
      { "Have", tostring(a.have) },
      { "Need", ("~%d"):format(a.need) },
      { "Left", tostring(math.max(0, a.need - a.have)) },
      { bar = a.need > 0 and math.min(1, a.have / a.need) or 1 },
      { "Fished from", f.skill and tostring(f.skill) or (H.dim .. "not known|r") },
    }
    if a.blocked then rows[#rows + 1] = { H.bad .. a.blocked .. "|r" } end
    if a.value then rows[#rows + 1] = { "Worth", "~" .. NW.Money(a.value, "mid") } end
    rows[#rows + 1] = "gap"
    if #zones > 0 then
      rows[#rows + 1] = { head = named and "Found in" or "Waters at this skill" }
      for z = 1, math.min(4, #zones) do rows[#rows + 1] = { zones[z], color = F.hostile(zones[z]) and S.dim or S.text } end
    end
    -- other fish that give skill-ups over the same stretch
    local alt, seen = {}, { [a.fish] = true }
    for _, ph in ipairs(plan.phases) do
      for _, b in ipairs(ph.actions) do
        if b.kind == "cook" and b.phase == a.phase then
          for _, r in ipairs(NW.RECIPES.cooking or {}) do
            local fl = F.fishInRecipe(r)
            if #fl == 1 and not seen[fl[1]] and #r.reagents <= 2 and NW.SkillUpChance(r, b.step.from) > 0
              and (r.orange or r.yellow) <= b.step.from and F.FISH[fl[1]].skill then
              seen[fl[1]] = true
              alt[#alt + 1] = fl[1]
            end
          end
        end
      end
    end
    if #alt > 0 then
      rows[#rows + 1] = "gap"
      rows[#rows + 1] = { head = "Also gives skill-ups" }
      for z = 1, math.min(3, #alt) do rows[#rows + 1] = { (F.itemName(alt[z])):gsub("^Raw ", ""), color = S.dim } end
    end
    F.detail("Fish", NW.ItemIcon(a.fish), F.itemName(a.fish), "Estimate: skill-ups are random", rows,
      zones[1] and { "Show on map", F.showZone(zones[1]) } or nil,
      { "Fish Finder", function() st().fishTab = "finder"; F.sel = "fish" .. a.fish; F.Redraw() end })
  elseif k == "cook" then
    local r, stp = a.recipe, a.step
    local known = (NW.charDB.known.cooking or {})[r.name]
    local rows = { { head = "Cooking" }, { "Skill", ("%d-%d"):format(stp.from, stp.to) }, { "Crafts", ("~%d"):format(stp.crafts) },
      { "Recipe", known and (H.good .. "known|r") or (r.src == "trainer" or r.src == "rank") and "trainer" or (H.bad .. "to get|r") }, "gap", { head = "Ingredients" } }
    for _, m in ipairs(stp.mats or {}) do
      local n = NW.ItemCount(m[1]) or 0
      rows[#rows + 1] = { ("|T%s:14:14:0:0|t %s"):format(NW.ItemIcon(m[1]) or "", F.itemName(m[1])),
        ("%s%d|r%s/%d|r"):format(n >= m[2] and H.good or H.text, math.min(n, m[2]), H.dim, m[2]) }
    end
    local missing = {}
    for _, m in ipairs(stp.mats or {}) do
      local n = NW.ItemCount(m[1]) or 0
      local nm, ok = F.itemName(m[1])
      if n < m[2] and ok and not F.FISH[m[1]] then missing[#missing + 1] = { nm, m[2] - n } end
    end
    F.detail("Cook", r.item and NW.ItemIcon(r.item) or nil, r.name, ("~%d crafts"):format(stp.crafts), rows,
      #missing > 0 and NW.SearchAH and { "Search missing", function() NW.SearchAH(missing) end } or nil,
      { "Cooking plan", function() NW.OpenProfession("cooking") end })
  elseif k == "train" then
    if a.prof == "fishing" then F.rankDetail(a.rank) return end
    local ru = a.crank
    local who, where, mapID, x, y = NW.RankWhere("cooking", ru.name)
    local level = UnitLevel and UnitLevel("player") or 60
    local rows = { { head = "Requirements" }, { "Skill", tostring(ru.skill or 0) },
      { "Level", ((level >= (ru.level or 0)) and H.good or H.bad) .. (ru.level or 1) .. "|r" }, "gap", { head = "Source" },
      { who or "Any cooking trainer" } }
    if where then rows[#rows + 1] = { where, color = S.dim } end
    if a.cost then rows[#rows + 1] = { "Cost", NW.Money(a.cost, "mid") } end
    F.detail("Training", "Interface\\Icons\\INV_Misc_Book_09", ru.name .. " Cooking", ("Cooking to %d"):format(ru.cap), rows,
      mapID and { "Show on map", function() NW.PinMap(mapID, x, y, who) end } or nil)
  elseif k == "recipe" then
    local r = a.recipe
    local rows = { { head = "Where" } }
    -- one source a line, so none is cut off
    local src = NW.RecipeSourceText and NW.RecipeSourceText("cooking", r) or ""
    src = src:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for part in (src .. "  ·  "):gmatch("(.-)  ·  ") do
      if part ~= "" and #rows < 8 then rows[#rows + 1] = { part } end
    end
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { "Cost", money(a.cost) }
    rows[#rows + 1] = { "Learn at", ("Cooking %d"):format(r.orange or r.yellow) }
    local nm, ok
    if r.recipeItem then nm, ok = F.itemName(r.recipeItem) end
    F.detail("Recipe", r.recipeItem and NW.ItemIcon(r.recipeItem) or "Interface\\Icons\\INV_Scroll_03", r.name, a.done and "Known" or "Not known",
      rows, ok and NW.SearchAH and { "Search", function() NW.SearchAH({ { nm, 1 } }) end } or nil)
  elseif k == "fishto" then
    local b = a.b
    local rows = { { head = "Fishing" }, { "From", tostring(a.from) }, { "To", tostring(a.to) }, { "Catches needed", H.dim .. "not estimated|r" }, "gap",
      { head = "Where" } }
    for _, z in ipairs(F.sortZones(b.zones)) do
      if #rows < 13 then rows[#rows + 1] = { z .. ((b.best == z) and (H.gold .. "  best|r") or ""), color = F.hostile(z) and S.dim or S.text } end
    end
    lureFor(b, rows)
    F.equipLines(rows)
    F.detail("Fishing", "Interface\\Icons\\Trade_Fishing", a.label, "Skill-ups come from catches", rows,
      { "Show on map", F.showZone(b.best or F.sortZones(b.zones)[1]) })
  elseif k == "vendor" or k == "other" then
    local rows = { { head = k == "vendor" and "Vendor supplies" or "Buy or gather" } }
    local search = {}
    for _, e in ipairs(a.items) do
      local nm, ok = F.itemName(e.id)
      rows[#rows + 1] = { ("|T%s:14:14:0:0|t %s"):format(NW.ItemIcon(e.id) or "", nm),
        ("%s%d|r%s/%d|r"):format(e.have >= e.need and H.good or H.text, e.have, H.dim, e.need) }
      if e.have < e.need and ok then search[#search + 1] = { nm, e.need - e.have } end
    end
    F.detail(k == "vendor" and "Vendor" or "Ingredients", actionIcon(a), a.label, k == "vendor" and "Trade goods and cooking vendors" or "", rows,
      k == "other" and #search > 0 and NW.SearchAH and { "Search missing", function() NW.SearchAH(search) end } or nil)
  elseif k == "learn" then
    local rows = { { head = "Trainers" } }
    if a.prof == "fishing" then
      local list = F.TRAINERS[F.faction()] or {}
      for z = 1, math.min(6, #list) do rows[#rows + 1] = { list[z], color = S.dim } end
    else
      rows[#rows + 1] = { "Any cooking trainer in a capital city", color = S.dim }
    end
    F.detail("Learn", NW.PROF_BY_KEY[a.prof].icon, a.label, "", rows)
  elseif k == "gap" then
    F.detail("Blocked", KIND_ICON.gap, a.label, "", {
      { "With these options, no recipe gives skill-ups here." }, "gap",
      { "Allow non-fish recipes or buying fish under Options.", color = S.dim } })
  end
end

-- what you'll pay and what the catch is worth, under the steps
function F.planSummary(plan, rows)
  rows[#rows + 1] = "gap"
  rows[#rows + 1] = { head = "Plan" }
  local catch = 0
  for _, a in ipairs(plan.fish) do if not a.buy then catch = catch + math.max(0, a.need - a.have) end end
  rows[#rows + 1] = { "Fish to catch", ("~%d"):format(catch) }
  if plan.value > 0 then rows[#rows + 1] = { "Worth at auction", "~" .. NW.Money(plan.value, "gs") } end
  rows[#rows + 1] = { "To pay", NW.Money(plan.pay, "gs") .. (plan.unknownPrice and (H.bad .. " +?|r") or "") }
end

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------
function F.header()
  local rank, max, bonus = F.skill()
  if rank then
    W.skill:SetText(("%d / %d  ·  %s%s"):format(rank, max or 75, F.rankOf(max),
      bonus > 0 and ("  ·  " .. BLUE_HEX .. "effective %d|r"):format(rank + bonus) or ""))
  else
    W.skill:SetText("Not learned  ·  " .. H.dim .. "planning mode|r")
  end
  local nr = F.nextRank(max)
  if nr and nr.skill then
    W.next:SetText(("Next: %s%s|r"):format(H.text, nr.name))
    W.next2:SetText(("skill %d, level %d"):format(nr.skill, nr.level))
  else
    W.next:SetText("")
    W.next2:SetText("")
  end
end

function F.Redraw()
  if not fp:IsShown() then return end
  F.header()
  local t = tab()
  for k, b in pairs(W.tabs) do b:SetSelected(k == t) end
  W.combo:SetShown(t == "combined")
  W.search:SetShown(t == "finder")
  W.filters:SetShown(t == "finder")
  W.jctl:SetShown(t == "journal")
  local top = t == "combined" and W.box2y or (t == "finder" and TOP + 30 or t == "journal" and TOP + 48 or TOP)
  W.box:ClearAllPoints()
  W.box:SetPoint("TOPLEFT", 0, -top)
  W.box:SetHeight(530 - top)
  F.boxH = 530 - top
  W.empty:SetText("")
  if t == "leveling" then
    F.items = F.leveling()
    if not F.sel then
      local base = F.skill() or 0
      local bi = F.bracketFor(base)
      F.sel = "zone" .. bi .. ":" .. (F.BRACKETS[bi].best or F.sortZones(F.BRACKETS[bi].zones)[1])
      for i, it in ipairs(F.items) do if it.selKey == F.sel then F.offset = math.max(0, i - 3) break end end
    end
    F.drawRows()
    local sel
    for _, it in ipairs(F.items) do if F.sel and it.selKey == F.sel then sel = it end end
    if sel and sel.zone then F.zoneDetail(sel.zone, sel.bi, sel.later)
    elseif F.sel and F.sel:match("^rank(%d)") then F.rankDetail(F.RANKS[tonumber(F.sel:match("^rank(%d)"))])
    else F.detail("Location", nil, "", "", {}) end
  elseif t == "journal" then
    F.journal()
  elseif t == "finder" then
    F.items = F.finderItems()
    if not F.sel and F.items[1] then F.sel = F.items[1].selKey end
    W.empty:SetText(#F.items == 0 and "No fish match." or "")
    F.drawRows()
    local id = F.sel and tonumber(F.sel:match("^fish(%d+)"))
    if id and F.FISH[id] then F.fishDetail(id) else F.detail("Fish", nil, "", "", {}) end
  else
    local rank = NW.ProfSkill("fishing")
    local cook = NW.ProfSkill("cooking")
    local fishTo, cookTo = F.targets()
    W.fishLine.val:SetText(rank and ("%d"):format(rank) or (H.dim .. "–|r"))
    W.fishLine.bar:SetWidth(math.max(1, 150 * math.min(1, (rank or 0) / math.max(1, fishTo))))
    W.cookLine.val:SetText(cook and ("%d"):format(cook) or (H.dim .. "–|r"))
    W.cookLine.bar:SetWidth(math.max(1, 150 * math.min(1, (cook or 0) / math.max(1, cookTo))))
    W.fishLine.target:Refresh() W.cookLine.target:Refresh() W.mode:Refresh() W.opts:Refresh()
    local ok, plan = pcall(F.Build)
    if not ok then
      F.items = {}
      W.empty:SetText("Couldn't build the plan.")
      F.drawRows()
      F.detail("", nil, "", "", {})
      return
    end
    F.plan = plan
    F.items = F.combinedItems(plan)
    if #plan.phases == 0 then
      W.empty:SetText(((rank or 0) >= fishTo and (cook or 0) >= cookTo) and "Both targets reached." or "Nothing to plan.")
    end
    -- open on the next step
    local found
    for _, it in ipairs(F.items) do if F.sel and it.selKey == F.sel then found = it end end
    if not found then
      for i, it in ipairs(F.items) do
        if it.action and it.action == plan.next then F.sel = it.selKey; F.offset = math.max(0, i - 4); found = it break end
      end
    end
    F.drawRows()
    if found and found.action then
      F.actionDetail(found.action, plan)
    else
      local rows = {}
      F.planSummary(plan, rows)
      F.detail("Plan", nil, "", "", rows)
    end
    -- the plan's money stays in view under any step
    W.sum:SetText(("%sTo pay|r  %s%s    %sCatch worth|r  %s"):format(H.dim, NW.Money(plan.pay, "gs"), plan.unknownPrice and (H.bad .. " +?|r") or "",
      H.dim, plan.value > 0 and ("~" .. NW.Money(plan.value, "gs")) or "–"))
  end
  W.sum:SetShown(t == "combined")
end

-- Fish Finder search and filters
W.search = CreateFrame("EditBox", nil, fp, "BackdropTemplate")
W.search:SetSize(200, 24)
W.search:SetPoint("TOPLEFT", 0, -TOP)
UI.Flat(W.search, S.sunk, S.edge)
W.search:SetFont(UI.FONT, 12, "")
W.search:SetTextInsets(8, 8, 0, 0)
W.search:SetAutoFocus(false)
W.search:SetScript("OnEscapePressed", W.search.ClearFocus)
W.search:SetScript("OnTextChanged", function(self) F.search = self:GetText() or ""; F.offset = 0; F.Redraw() end)
W.searchHint = UI.Text(W.search, 12, S.dim)
W.searchHint:SetPoint("LEFT", 8, 0)
W.searchHint:SetText("Search")
W.search:HookScript("OnTextChanged", function(self) W.searchHint:SetShown((self:GetText() or "") == "") end)
W.filters = UI.CheckMenu(fp, "Filters", 100, {
  { "Catchable now", function() return F.cfg().fNow end, function(v) F.cfg().fNow = v or nil end, "At your effective skill." },
  { "Used in Cooking", function() return F.cfg().fCook end, function(v) F.cfg().fCook = v or nil end },
  { "In my Fishing + Cooking plan", function() return F.cfg().fPlan end, function(v) F.cfg().fPlan = v or nil end },
}, function() F.offset = 0; F.Redraw() end)
W.filters:SetPoint("TOPRIGHT", fp, "TOPLEFT", MID_W, -TOP)
W.mode:SetPoint("TOPLEFT", W.combo, "TOPLEFT", 0, -50)
W.opts:SetPoint("TOPRIGHT", W.combo, "TOPRIGHT", 0, -50)
W.box2y = TOP + 80
W.combo:SetHeight(80)
W.sum = UI.Text(fp, 11, S.text)
W.sum:SetPoint("BOTTOMLEFT", W.right, "BOTTOMLEFT", 0, 4)
W.sum:SetWidth(RIGHT_W)
W.sum:Hide()

------------------------------------------------------------------------
-- Journal: your catches by fish, by zone, and by session
------------------------------------------------------------------------
-- (FishJournal.lua loads after this file)
local JN = setmetatable({}, { __index = function(_, k) return NW.FishJournal[k] end })
local function jcfg() return F.cfg() end
local function fmtDur(sec)
  sec = math.floor(sec or 0)
  if sec >= 3600 then return ("%dh %02dm"):format(sec / 3600, (sec % 3600) / 60) end
  return ("%dm"):format(math.max(0, sec / 60))
end
local function day(t)
  if not t then return "–" end
  local d, today = date("%Y%m%d", t), date("%Y%m%d")
  if d == today then return "Today " .. date("%H:%M", t) end
  if d == date("%Y%m%d", time() - 86400) then return "Yesterday " .. date("%H:%M", t) end
  return date("%b %d", t)
end
local function commas(n)
  local s = tostring(math.floor(n or 0))
  while true do
    local k
    s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return s
end
F.fmtDur, F.day = fmtDur, day

W.jctl = CreateFrame("Frame", nil, fp)
W.jctl:SetPoint("TOPLEFT", 0, -TOP)
W.jctl:SetSize(MID_W, 46)
W.jctl:Hide()
W.jsum = UI.Text(W.jctl, 11, S.dim)
W.jsum:SetPoint("TOPLEFT", 0, 0)
W.jsum:SetWidth(MID_W)
W.jsum:SetWordWrap(false)
W.jview = UI.Dropdown(W.jctl, 118, "", { { "fish", "Collection" }, { "zones", "Zones" }, { "sessions", "Sessions" } },
  function() return jcfg().jView or "fish" end, function(v) jcfg().jView = v; F.sel = nil; F.offset = 0; F.Redraw() end, 118)
W.jview:SetPoint("TOPLEFT", 0, -18)
W.jscope = UI.Dropdown(W.jctl, 124, "", { { "char", "This character" }, { "all", "All characters" } },
  function() return jcfg().jScope or "char" end, function(v) jcfg().jScope = v; F.Redraw() end, 124,
  "Sessions are always this character's.")
W.jscope:SetPoint("LEFT", W.jview, "RIGHT", 8, 0)
W.jsort = UI.Dropdown(W.jctl, 130, "", { { "n", "Most caught" }, { "name", "Name" }, { "first", "First caught" },
  { "last", "Latest" }, { "value", "Value" }, { "cook", "Cooking uses" } },
  function() return jcfg().jSort or "n" end, function(v) jcfg().jSort = v; F.Redraw() end, 130)
W.jsort:SetPoint("LEFT", W.jscope, "RIGHT", 8, 0)
W.jsearch = CreateFrame("EditBox", nil, W.jctl, "BackdropTemplate")
W.jsearch:SetSize(MID_W - 118 - 124 - 130 - 24, 22)
W.jsearch:SetPoint("TOPRIGHT", 0, -19)
UI.Flat(W.jsearch, S.sunk, S.edge)
W.jsearch:SetFont(UI.FONT, 12, "")
W.jsearch:SetTextInsets(8, 8, 0, 0)
W.jsearch:SetAutoFocus(false)
W.jsearch:SetScript("OnEscapePressed", W.jsearch.ClearFocus)
W.jsearch:SetScript("OnTextChanged", function(self) F.jq = (self:GetText() or ""):lower(); F.offset = 0; F.Redraw() end)
W.jhint = UI.Text(W.jsearch, 12, S.dim)
W.jhint:SetPoint("LEFT", 8, 0)
W.jhint:SetText("Search")
W.jsearch:HookScript("OnTextChanged", function(self) W.jhint:SetShown((self:GetText() or "") == "") end)

-- the fish: everything in the catalog, plus fish you caught that it doesn't list
function F.jFish(scope)
  local items = JN.Items(scope)
  local list, seen = {}, {}
  for _, id in ipairs(F.ORDER) do list[#list + 1] = id; seen[id] = true end
  for id, e in pairs(items) do if e.k == "f" and not seen[id] then list[#list + 1] = id; seen[id] = true end end
  return list, items
end

function F.journal()
  local c = jcfg()
  local view, scope = c.jView or "fish", c.jScope or "char"
  local T = JN.Totals(scope)
  W.jsum:SetText(("%sFish|r %s   %sSpecies|r %d / %d cataloged%s   %sZones|r %d   %sTime|r %s   %sOther|r %s"):format(
    H.dim, commas(T.fish), H.dim, T.catalogFound, T.catalog, T.extra > 0 and (" +" .. T.extra) or "", H.dim, T.zones,
    H.dim, fmtDur(T.time), H.dim, commas(T.other)))
  W.jsort:SetShown(view == "fish")
  W.jsearch:SetShown(view == "fish")
  W.jscope:SetShown(view ~= "sessions")
  W.jview:Refresh() W.jscope:Refresh() W.jsort:Refresh()
  local items = {}
  if view == "fish" then
    local list, caught = F.jFish(scope)
    local sort, q = c.jSort or "n", F.jq or ""
    local price = {}
    local function pr(id) if price[id] == nil then local p, src = NW.Price(id); price[id] = (p and src ~= "est") and p or false end return price[id] or 0 end
    local rows = {}
    for _, id in ipairs(list) do
      local name = F.itemName(id)
      if q == "" or name:lower():find(q, 1, true) then rows[#rows + 1] = { id = id, name = name, e = caught[id] } end
    end
    table.sort(rows, function(a, b)
      local an, bn = a.e and a.e.n or 0, b.e and b.e.n or 0
      if (an > 0) ~= (bn > 0) then return an > 0 end
      if sort == "name" then return a.name < b.name end
      if sort == "first" and an > 0 then return (a.e.first or 0) < (b.e.first or 0) end
      if sort == "last" and an > 0 then return (a.e.last or 0) > (b.e.last or 0) end
      if sort == "value" then local x, y = pr(a.id) * an, pr(b.id) * bn; if x ~= y then return x > y end end
      if sort == "cook" then local x, y = #NW.CookFish(a.id), #NW.CookFish(b.id); if x ~= y then return x > y end end
      if an ~= bn then return an > bn end
      return a.name < b.name
    end)
    for _, r in ipairs(rows) do
      local n = r.e and r.e.n or 0
      items[#items + 1] = { icon = NW.ItemIcon(r.id), desat = n == 0, selKey = "jf" .. r.id,
        text = (n > 0 and H.text or H.dim) .. r.name .. "|r", right = n > 0 and (BLUE_HEX .. commas(n) .. "|r") or (H.dim .. "Undiscovered|r"),
        dim = n == 0 }
    end
    -- everything else fishing brought up
    local others = {}
    for id, e in pairs(caught) do if e.k ~= "f" then others[#others + 1] = { id = id, e = e } end end
    table.sort(others, function(a, b) return a.e.n > b.e.n end)
    if #others > 0 then
      local folded = c.folds.jOther
      if folded == nil then folded = true end
      items[#items + 1] = { head = true, text = ("Other catches  %d"):format(#others), foldKey = "jOther", folded = folded }
      if not folded then
        for _, o in ipairs(others) do
          items[#items + 1] = { icon = NW.ItemIcon(o.id), selKey = "jo" .. o.id, text = F.itemName(o.id),
            right = H.dim .. (JN.KIND_LABEL[o.e.k] or "") .. "|r  " .. commas(o.e.n) }
        end
      end
    end
    W.empty:SetText(#items == 0 and "Nothing matches." or "")
  elseif view == "zones" then
    local zones = JN.Zones(scope)
    local list = {}
    for m, z in pairs(zones) do list[#list + 1] = { m = m, z = z } end
    table.sort(list, function(a, b) return a.z.n > b.z.n end)
    for _, e in ipairs(list) do
      items[#items + 1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", selKey = "jz" .. e.m, text = JN.zoneName(e.m),
        right = ("%s fish  ·  %s"):format(commas(e.z.fish), day(e.z.last)) }
    end
    W.empty:SetText(#items == 0 and "No catches yet. Fish anywhere and they're recorded here." or "")
  else
    local log = JN.log()
    local live = JN.session()
    if live then
      local top, topN = nil, -1
      for m, n in pairs(live.zones) do if n > topN then top, topN = m, n end end
      items[#items + 1] = { icon = "Interface\\Icons\\Trade_Fishing", selKey = "jsnow", mark = live.pausedAt and "" or mark("next"),
        text = H.gold .. "Now|r  " .. (top and JN.zoneName(top) or (GetZoneText and GetZoneText() or "")),
        right = ("%s  ·  %d fish"):format(fmtDur(JN.Elapsed(live)), live.fish) }
    end
    for i = #(log and log.sessions or {}), 1, -1 do
      local se = log.sessions[i]
      items[#items + 1] = { icon = "Interface\\Icons\\INV_Misc_Book_09", selKey = "js" .. i,
        text = day(se.start) .. H.dim .. "  " .. JN.zoneName(se.zone) .. "|r", right = ("%s  ·  %d fish"):format(fmtDur(se.elapsed), se.fish) }
    end
    W.empty:SetText(#items == 0 and "No sessions yet. One starts when you cast." or "")
  end
  F.items = items
  if not F.sel and items[1] then
    for _, it in ipairs(items) do if it.selKey then F.sel = it.selKey break end end
  end
  F.drawRows()
  local sel = F.sel or ""
  local id = tonumber(sel:match("^jf(%d+)") or "")
  local oid = tonumber(sel:match("^jo(%d+)") or "")
  local zm = tonumber(sel:match("^jz(%d+)") or "")
  local si = tonumber(sel:match("^js(%d+)") or "")
  if id then F.jFishDetail(id, scope)
  elseif oid then F.jOtherDetail(oid, scope)
  elseif zm then F.jZoneDetail(zm, scope)
  elseif sel == "jsnow" then F.jSessionDetail(nil)
  elseif si then F.jSessionDetail(si)
  else F.detail("Journal", nil, "", "", {}) end
end

-- what a fish could be cooked into, and what that's worth (estimates)
function F.cookValue(id)
  local out = {}
  for _, r in ipairs(NW.CookFish(id)) do
    if r.item then
      local _, ah = NW.PriceParts(r.item)
      local mats, partial = 0, false
      for _, re in ipairs(r.reagents) do
        local p, src = NW.Price(re[1])
        if p and src ~= "est" then mats = mats + p * re[2] else partial = true end
      end
      out[#out + 1] = { r = r, sells = ah and ah * (r.yield or 1) or nil, mats = mats, partial = partial }
    end
  end
  return out
end

function F.jFishDetail(id, scope)
  local e = JN.Items(scope)[id]
  local n = e and e.n or 0
  local rows = { { head = "Your catches" }, { "Caught", BLUE_HEX .. commas(n) .. "|r" } }
  if e then
    rows[#rows + 1] = { "First", day(e.first) }
    rows[#rows + 1] = { "Latest", day(e.last) }
  end
  local p, src = NW.Price(id)
  local priced = p and src ~= "est"
  rows[#rows + 1] = { "Each, at auction", priced and ("~" .. NW.Money(p, "mid")) or (H.dim .. "no price|r") }
  if n > 0 and priced then rows[#rows + 1] = { "All of it, today", "~" .. NW.Money(p * n, "gs") } end
  local where = JN.ZonesFor(id, scope)
  if #where > 0 then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Where you caught it" }
    for k = 1, math.min(4, #where) do rows[#rows + 1] = { JN.zoneName(where[k].map), commas(where[k].n) } end
  end
  local cooks = F.cookValue(id)
  if #cooks > 0 then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Cook it or sell it" }
    for k = 1, math.min(2, #cooks) do
      local cv = cooks[k]
      local profit = cv.sells and (cv.sells * 0.95 - cv.mats) or nil
      rows[#rows + 1] = { cv.r.name, cv.sells and ("~" .. NW.Money(cv.sells, "mid")) or (H.dim .. "no price|r") }
      rows[#rows + 1] = { "  after cut and materials", profit and ((profit >= 0 and H.good or H.bad) .. "~" .. NW.Money(math.abs(profit), "mid") .. (profit < 0 and " loss" or "") .. "|r" .. (cv.partial and (H.bad .. " +?|r") or "")) or "–" }
    end
  end
  F.detail("Fish", NW.ItemIcon(id), F.itemName(id), n > 0 and "Prices are estimates" or "Not caught yet", rows,
    { "Fish Finder", function() st().fishTab = "finder"; F.sel = "fish" .. id; F.Redraw() end },
    where[1] and where[1].map ~= 0 and { "Show on map", function() if OpenWorldMap then pcall(OpenWorldMap, where[1].map) end end } or nil)
end

function F.jOtherDetail(id, scope)
  local e = JN.Items(scope)[id]
  local rows = { { head = "Your catches" }, { "Kind", JN.KIND_LABEL[e and e.k or "o"] }, { "Caught", commas(e and e.n or 0) },
    { "First", day(e and e.first) }, { "Latest", day(e and e.last) } }
  local p, src = NW.Price(id)
  rows[#rows + 1] = { "Each, at auction", (p and src ~= "est") and ("~" .. NW.Money(p, "mid")) or (H.dim .. "no price|r") }
  F.detail("Catch", NW.ItemIcon(id), F.itemName(id), "", rows)
end

function F.jZoneDetail(mapID, scope)
  local z = JN.Zones(scope)[mapID]
  if not z then F.detail("Zone", nil, "", "", {}) return end
  local rows = { { "Fish", commas(z.fish) }, { "Other catches", commas(z.n - z.fish) }, { "Time fished", fmtDur(z.t) },
    { "Latest", day(z.last) } }
  -- what you caught here, by share of your own fish
  local list = {}
  for id, n in pairs(z.items) do if JN.kind(id) == "f" then list[#list + 1] = { id = id, n = n } end end
  table.sort(list, function(a, b) return a.n > b.n end)
  if z.fish > 0 then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Your catch" }
    local shown = 0
    for k = 1, math.min(4, #list) do
      local e = list[k]
      shown = shown + e.n
      rows[#rows + 1] = { (F.itemName(e.id)):gsub("^Raw ", ""), ("%d  ·  %d%%"):format(e.n, math.floor(100 * e.n / z.fish + 0.5)) }
      rows[#rows + 1] = { bar = e.n / z.fish }
    end
    if z.fish - shown > 0 then
      rows[#rows + 1] = { "Other fish", ("%d  ·  %d%%"):format(z.fish - shown, math.floor(100 * (z.fish - shown) / z.fish + 0.5)) }
      rows[#rows + 1] = { bar = (z.fish - shown) / z.fish }
    end
    rows[#rows + 1] = { ("From %d fish you caught%s"):format(z.fish, z.fish < 50 and ": a small sample" or ""), color = S.dim }
  end
  local spots = mapID ~= 0 and JN.Spots(mapID, scope) or {}
  if #spots > 0 then rows[#rows + 1] = { map = mapID, spots = spots } end
  F.detail("Zone", "Interface\\Icons\\INV_Misc_Map_01", JN.zoneName(mapID), "Your catches, not drop rates", rows,
    #spots == 0 and mapID ~= 0 and { "Show on map", function() if OpenWorldMap then pcall(OpenWorldMap, mapID) end end } or nil)
end

function F.jSessionDetail(i)
  local log = JN.log()
  local se = i and log and log.sessions[i] or JN.session()
  if not se then F.detail("Session", nil, "", "", {}) return end
  local live = i == nil
  local rows = { { "Started", day(se.start) }, { "Length", fmtDur(live and JN.Elapsed(se) or se.elapsed) },
    { "Fishing", fmtDur(se.active) }, { "Catches", tostring(se.catches or 0) }, { "Fish", tostring(se.fish or 0) },
    { "Other", tostring(se.other or 0) } }
  local s1 = live and NW.ProfSkill("fishing") or se.skill1
  if se.skill0 and s1 and s1 > se.skill0 then rows[#rows + 1] = { "Skill gained", BLUE_HEX .. "+" .. (s1 - se.skill0) .. "|r" } end
  local v, partial
  if live then v, partial = JN.Value(se.items) else v, partial = se.value, se.partial end
  rows[#rows + 1] = { live and "Worth today" or "Worth when it ended", (v and v > 0 and ("~" .. NW.Money(v, "gs")) or "–") .. (partial and (H.bad .. " +?|r") or "") }
  if (se.active or 0) >= 300 and v and v > 0 then rows[#rows + 1] = { "Per fishing hour", "~" .. NW.Money(v * 3600 / se.active, "gs") } end
  local list = {}
  for id, n in pairs(se.items or {}) do list[#list + 1] = { id = id, n = n } end
  table.sort(list, function(a, b) return a.n > b.n end)
  if #list > 0 then
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { head = "Caught" }
    for k = 1, math.min(6, #list) do
      rows[#rows + 1] = { ("|T%s:14:14:0:0|t %s"):format(NW.ItemIcon(list[k].id) or "", (F.itemName(list[k].id)):gsub("^Raw ", "")), tostring(list[k].n) }
    end
  end
  if live then
    F.detail("Session", "Interface\\Icons\\Trade_Fishing", se.pausedAt and "Paused" or "Fishing now", "Fishing time leaves out gaps over 2 minutes", rows,
      { se.pausedAt and "Resume" or "Pause", function() if se.pausedAt then JN.Resume() else JN.Pause() end F.Redraw() end },
      { "End", function() JN.End(); F.sel = nil; F.Redraw() end })
  else
    local confirm = F.confirmDelete == i
    F.detail("Session", "Interface\\Icons\\INV_Misc_Book_09", day(se.start), JN.zoneName(se.zone), rows,
      { confirm and "Click again to delete" or "Delete", function()
        if F.confirmDelete == i then F.confirmDelete = nil; JN.DeleteSession(i); F.sel = nil else F.confirmDelete = i end
        F.Redraw()
      end })
  end
end

function NW.OpenFishJournal()
  st().fishTab = "journal"
  F.sel = nil
  NW.OpenProfession("fishing")
end
table.insert(NW.OnLoad, function()
  JN.OnChange(function()
    if not fp:IsVisible() or F.jPending then return end
    F.jPending = true
    C_Timer.After(0.5, function() F.jPending = nil; if fp:IsVisible() then F.Redraw() end end)
  end)
end)

-- shown in place of the craft layout while Fishing is selected
function NW.FishPanel(on)
  fp:SetShown(on)
  if on then F.Redraw() end
end

-- From Cooking, or a fish on a shopping list
function NW.OpenFishCook()
  st().fishTab = "combined"
  F.sel = nil
  NW.OpenProfession("fishing")
end
function NW.OpenFishFinder(id)
  st().fishTab = "finder"
  F.sel = id and ("fish" .. id) or nil
  F.search = ""
  if W.search then W.search:SetText("") end
  NW.OpenProfession("fishing")
end

-- Live: bags, skills and recipes change what's left
local pending
local function later()
  if pending or not fp:IsVisible() then return end
  pending = true
  C_Timer.After(0.5, function() pending = nil; F.Redraw() end)
end
NW.On("BAG_UPDATE_DELAYED", later)
NW.On("SKILL_LINES_CHANGED", later)
NW.On("CHAT_MSG_SKILL", later)
NW.On("NEW_RECIPE_LEARNED", later)
NW.On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then later() end end)
