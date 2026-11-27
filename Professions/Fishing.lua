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
-- the game font has no arrow glyph: the chat frame's arrow texture instead
local ARROW = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:12:12:0:0|t"

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
  -- (night and day are the guides' notes; the Classic loot tables have no time condition for them)
  [13759] = { skill = 225, bracket = 4, note = "At night (guides)", src = "guide" },
  [13760] = { skill = 225, bracket = 4, note = "By day (guides)", src = "guide" },
  -- Raw Summer Bass, Winter Squid: zones and season from cMaNGOS classic-db (13e9337) fishing loot.
  -- Summer Bass: Tanaris and Azshara coastal areas (reference tables 11009, 11105) all year, more in the
  -- Summer Season Fishing event (table 13755, condition 323). Winter Squid: only table 13755 under
  -- condition 322, the Winter Season Fishing event. Classic data; not verified in Forever.
  [13756] = { skill = 225, bracket = 4, zones = { "Tanaris", "Azshara" }, note = "Coast", src = "guide", zoneSrc = "classic" },
  [13755] = { skill = 225, bracket = 4, zones = { "Tanaris", "Azshara", "Stranglethorn Vale", "The Hinterlands", "Feralas" }, note = "Coast, winter only", season = "winter", src = "guide", zoneSrc = "classic" },
  [13758] = { skill = 300, zones = { "Western Plaguelands", "The Hinterlands", "Moonglade", "Felwood", "Un'Goro Crater" }, note = "Lakes and rivers", src = "forever" },
  [4603] = { skill = 300, zones = { "Tanaris", "The Hinterlands" }, note = "Coast", src = "forever" },
  -- Stonescale Eel: cMaNGOS classic-db fishing loot (Tanaris and Azshara coastal areas, reference
  -- tables 11009 and 11105) and the Stonescale Eel Swarm pool (gameobject 180712). Classic data.
  -- No skill: no guide value is cited for it, and a zone's base level isn't the same thing.
  [13422] = { zones = { "Tanaris", "Azshara" }, note = "Coast; Stonescale Eel Swarm pools", src = "classic" },
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
      -- a fish only caught in one season isn't planned for catching (buying it is fine)
      if not ctx.buyFish and f.season then return false end
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
  -- Which phase each cooking step lands in: as soon as its fish can be had
  -- (bought, or caught at the fishing skill that phase reaches) and its
  -- Cooking rank is trained, never before the step before it. The two
  -- professions needn't level together: Cooking 299 with Fishing 7 cooks its
  -- last point once that fish is in reach (or bought), not after Fishing 300.
  -- early: the fish can be had when the phase starts (cooked before fishing on)
  -- (steps start in the phase you're in: Fishing's, while it still levels here, else Cooking's)
  local stepPhase, stepEarly, prevPhase = {}, {}, (base < fishTo) and tierOf(base) or tierOf(cookFrom)
  for _, st in ipairs(cp and cp.steps or {}) do
    local ct = tierOf(st.from)
    local ready = (cookMax or 75) >= TIERS[ct][2] and 1 or ct -- that Cooking rank: trained already, or trained in its phase
    local need, needSkill = 1, nil
    for _, m in ipairs(st.mats or {}) do
      local f = F.FISH[m[1]]
      if f and not c.buyFish and f.skill and f.skill > base then
        local ft = tierOf(f.skill - 1) -- the phase whose fishing reaches it
        if ft > need then need = ft end
        if not needSkill or f.skill > needSkill then needSkill = f.skill end
      end
    end
    local ph = math.max(ready, need, prevPhase)
    stepPhase[st], prevPhase = ph, ph
    stepEarly[st] = not needSkill or needSkill <= math.max(base, TIERS[ph][1])
  end
  local cookTrained = {} -- Cooking ranks given a training step
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
      if stepPhase[st] == ti then cookSteps[#cookSteps + 1] = st end
    end
    local cookHere = #cookSteps > 0
    if fishHere or cookHere then
      -- learning comes first, in whichever phase the plan starts
      if not plan.learnAdded then
        plan.learnAdded = true
        if not fishNow and fishTo > 0 then add({ kind = "learn", prof = "fishing", label = "Learn Fishing", done = false }) end
        if not cookNow and cookTo > 1 then add({ kind = "learn", prof = "cooking", label = "Learn Cooking", done = false }) end
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
      -- a Cooking rank not trained yet: its training goes just before the
      -- first cooking that needs it (a rank already trained gets no step)
      local function trainCooking(upTo)
        for rt = 2, upTo do
          local ru = NW.RANKS[rt]
          local done = cookMax and cookMax >= TIERS[rt][2] or false
          if not cookTrained[rt] and not done then
            cookTrained[rt] = true
            local a = add({ kind = "train", prof = "cooking", crank = ru, label = "Train " .. ru.name .. " Cooking", done = false })
            if ru.level and level < ru.level then a.blocked = ("Needs level %d"):format(ru.level) end
            if cookBlock then a.blocked = a.blocked or cookBlock end
            if a.blocked and not cookBlock then cookBlock = "Needs " .. ru.name .. " Cooking" end
            local fee = (NW.RANK_FEE.cooking or {})[ru.name]
            if fee then a.cost = fee; plan.fees = plan.fees + fee end
          end
        end
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
      local vend, other = {}, {}
      for _, st in ipairs(cookSteps) do
        for _, m in ipairs(st.mats or {}) do
          local id, n = m[1], m[2]
          if F.FISH[id] then
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
      -- the fish for a group of steps, then the cooking: what can be had now
      -- comes before fishing on, what needs more skill after it
      local function catchAndCook(group, reachSkill)
        local fishNeed, fishOrder, noFish = {}, {}, {}
        for _, st in ipairs(group) do
          for _, m in ipairs(st.mats or {}) do
            local id, n = m[1], m[2]
            if F.FISH[id] then
              if not fishNeed[id] then fishOrder[#fishOrder + 1] = id end
              fishNeed[id] = (fishNeed[id] or 0) + n
            end
          end
        end
        -- each fish just before the first cooking that uses it (all of the
        -- group's need at once), so a catch sits right above its dish
        local emitted = {}
        local function catchFish(id)
          if emitted[id] then return end
          emitted[id] = true
          local n = fishNeed[id]
          local h = math.min(have(id), n)
          left[id] = have(id) - h
          local f = F.FISH[id]
          local reach = f.skill and f.skill <= reachSkill
          local buy = c.buyFish and not (f.skill and f.skill <= base)
          local a = add({ kind = "catch", fish = id, need = n, have = h, buy = buy,
            label = (buy and "Buy " or "Catch ") .. (F.itemName(id)), done = h >= n })
          if not reach and not c.buyFish then
            a.blocked = f.skill and ("Guides: Fishing %d"):format(f.skill) or "No fishing data for it"
          elseif not a.done and not buy and fishBlock and f.skill and f.skill > fishCap then
            a.blocked = fishBlock
          end
          local pr = NW.Price(id)
          a.value = pr and pr * n or nil
          plan.fish[#plan.fish + 1] = a
          if a.blocked and not a.done then noFish[id] = true end
        end
        for _, st in ipairs(group) do
          trainCooking(tierOf(st.from))
          for _, m in ipairs(st.mats or {}) do if fishNeed[m[1]] then catchFish(m[1]) end end
          if st.recipe then
            local ca = add({ kind = "cook", step = st, recipe = st.recipe, label = ("Cook %s"):format(st.recipe.name),
              done = (cookNow or 0) >= st.to })
            if not ca.done then
              if gapBlock then ca.blocked = gapBlock
              elseif cookBlock and st.to > cookCap then ca.blocked = cookBlock end
              -- its fish can't be had yet: the cooking waits too
              if not ca.blocked then
                for _, re in ipairs(st.recipe.reagents) do
                  if noFish[re[1]] then ca.blocked = "Needs " .. (F.itemName(re[1])):gsub("^Raw ", "") break end
                end
              end
            end
          else
            local a = add({ kind = "gap", step = st, label = ("No recipe for %d-%d"):format(st.from, st.to), done = false })
            a.blocked = c.nonFish and "Nothing in the data" or "Allow non-fish recipes"
            gapBlock = gapBlock or ("Needs a recipe for %d-%d"):format(st.from, st.to)
          end
        end
      end
      local early, late = {}, {}
      for _, st in ipairs(cookSteps) do
        if stepEarly[st] and #late == 0 then early[#early + 1] = st else late[#late + 1] = st end
      end
      catchAndCook(early, math.max(base, lo))
      if fishHere then
        local bi, b = F.bracketFor(math.max(base, lo))
        local fa = add({ kind = "fishto", from = math.max(base, lo), to = fishAtEnd, bracket = bi, b = b,
          label = ("Fish to %d"):format(fishAtEnd), done = (fishNow or 0) >= fishAtEnd })
        if not fa.done and fishBlock and fishAtEnd > fishCap then fa.blocked = fishBlock end
      end
      catchAndCook(late, math.max(fishAtEnd, base))
      -- a Cooking rank blocked in this phase blocks what it's needed for, even
      -- the recipes and supplies listed before it
      if cookBlock then
        local anyCook, allBlocked = false, true
        for _, a in ipairs(ph.actions) do
          if a.kind == "cook" and not a.done then anyCook = true; if not a.blocked then allBlocked = false end end
        end
        for _, a in ipairs(ph.actions) do
          if not a.done and not a.blocked then
            if a.kind == "recipe" and (a.recipe.orange or a.recipe.yellow) >= cookCap then a.blocked = cookBlock
            elseif (a.kind == "vendor" or a.kind == "other") and anyCook and allBlocked then a.blocked = cookBlock end
          end
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
F.W = W -- (the frames, for tests)

local function st() return NW.db.settings end
-- F.ctx: "fishing" (Fishing's page) or "cooking" (Cooking's Fishing + Cooking view)
F.ctx = "fishing"
local function tab()
  if F.ctx == "cooking" then return "combined" end
  local t = st().fishTab
  return (t and t ~= "finder") and t or "leveling"
end
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
  -- (the Fish Finder is the Material Finder's Fish category now)
  local TABS = { { "leveling", "Leveling", 84 }, { "combined", "Fishing + Cooking", 136 }, { "journal", "Journal", 76 } }
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
  -- seen from Cooking: Cooking's views instead (the same plan, the same settings)
  W.cookTabs = {}
  local x2 = 0
  for i, v in ipairs(NW.COOK_VIEWS or {}) do
    local w = NW.COOK_VIEW_W[i]
    local b = CreateFrame("Button", nil, fp, "BackdropTemplate")
    b:SetSize(w, 26)
    b:SetPoint("TOPLEFT", W.iconBox, "BOTTOMLEFT", x2, -10)
    x2 = x2 + w + 4
    UI.Flat(b, S.cell, S.edge)
    b.label = UI.Text(b, 12, S.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(v[2])
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetPoint("BOTTOMLEFT", 1, 1)
    b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    b.bar:SetHeight(2)
    b.bar:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 1)
    b.bar:Hide()
    local on = v[1] == "fishcook"
    b.on = on
    b.bar:SetShown(on)
    b.label:SetTextColor(unpack(on and S.gold or S.dim))
    b:SetBackdropColor(unpack(on and S.hover or S.cell))
    b:SetScript("OnEnter", function(self) if not self.on then self.label:SetTextColor(unpack(S.text)) end end)
    b:SetScript("OnLeave", function(self) if not self.on then self.label:SetTextColor(unpack(S.dim)) end end)
    b:SetScript("OnClick", function() if not on and NW.SetCookView then NW.SetCookView(v[1]) end end)
    W.cookTabs[i] = b
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
-- fish and dish icons on the rows: the professions' reagent strip, with the
-- fishing facts in the tooltip and Material Finder on click
local SRC_NAME = { forever = "Method's WoW Forever guide", guide = "Classic leveling guides", classic = "Classic data (cMaNGOS)" }
W.fh = {}
function W.fh.tip(icon)
  local id, c = icon.id, icon.ctx
  GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
  if not pcall(GameTooltip.SetItemByID, GameTooltip, id) then GameTooltip:SetText(F.itemName(id), 1, 1, 1) end
  GameTooltip:AddLine(" ")
  local d = S.dim
  local f = F.FISH[id]
  if c.perCraft then GameTooltip:AddDoubleLine("Per craft", c.perCraft, d[1], d[2], d[3], 1, 1, 1) end
  if c.need then GameTooltip:AddDoubleLine("Have", ("%d / %s%d"):format(math.min(c.have or NW.ItemCount(id) or 0, c.need), c.est and "~" or "", c.need), d[1], d[2], d[3], 1, 1, 1) end
  if c.cookedInto then GameTooltip:AddLine("What this fish is cooked into", d[1], d[2], d[3], true) end
  if c.recipe then
    local r = c.recipe
    GameTooltip:AddDoubleLine("Cooking", ("%d-%d"):format(r.orange or r.yellow, r.grey), d[1], d[2], d[3], 1, 1, 1)
    if c.stepFrom then GameTooltip:AddDoubleLine("In this plan", ("%d-%d"):format(c.stepFrom, c.stepTo), d[1], d[2], d[3], 1, 1, 1) end
    if c.recipes then
      GameTooltip:AddLine(" ")
      for k = 2, #c.recipes do local x = c.recipes[k] GameTooltip:AddDoubleLine("Also: " .. x.name, ("%d-%d"):format(x.orange or x.yellow, x.grey), d[1], d[2], d[3], 1, 1, 1) end
    end
    local cook = NW.ProfSkill("cooking")
    local st = F.cookState(r, cook)
    if cook and st then GameTooltip:AddDoubleLine(("At your %d"):format(cook), F.COOK_WORDS[st], d[1], d[2], d[3], 1, 1, 1) end
  end
  if c.lure then
    GameTooltip:AddDoubleLine("Fishing", "+" .. c.lure, d[1], d[2], d[3], 1, 1, 1)
    if c.covered then GameTooltip:AddLine("Your bonus already covers it.", d[1], d[2], d[3], true) end
  end
  if f then
    if f.skill then
      GameTooltip:AddDoubleLine("Guides fish it from", f.skill, d[1], d[2], d[3], 1, 1, 1)
      GameTooltip:AddLine("A guide's skill, not a confirmed minimum.", d[1], d[2], d[3], true)
    else
      GameTooltip:AddDoubleLine("Fishing skill", "not known", d[1], d[2], d[3], d[1], d[2], d[3])
    end
    if f.note then GameTooltip:AddDoubleLine("Where", f.note, d[1], d[2], d[3], 1, 1, 1) end
    if f.zones then GameTooltip:AddLine(table.concat(f.zones, ", "), 1, 1, 1, true) end
    if f.season then GameTooltip:AddLine(("Caught only in %s, by Classic data."):format(f.season), 1, 0.82, 0.2, true) end
    if f.src and SRC_NAME[f.src] then GameTooltip:AddDoubleLine("Skill from", SRC_NAME[f.src], d[1], d[2], d[3], d[1], d[2], d[3]) end
    if f.zoneSrc and SRC_NAME[f.zoneSrc] then GameTooltip:AddDoubleLine("Zones from", SRC_NAME[f.zoneSrc], d[1], d[2], d[3], d[1], d[2], d[3]) end
    local rank, _, bonus = F.skill()
    if rank then GameTooltip:AddDoubleLine("Your fishing", ("%d (+%d gear and lures)"):format(rank, bonus), d[1], d[2], d[3], 1, 1, 1) end
  end
  local have = NW.ItemCount(id) or 0
  if have > 0 then GameTooltip:AddDoubleLine("In your bags and bank", have, d[1], d[2], d[3], 1, 1, 1) end
  GameTooltip:AddDoubleLine("Click", c.recipe and "Cooking plan" or f and "where to fish it, in Material Finder" or "where to get it, in Material Finder", d[1], d[2], d[3], 1, 1, 1)
  GameTooltip:AddDoubleLine("Shift-click", "link in chat", d[1], d[2], d[3], 1, 1, 1)
  GameTooltip:Show()
end
function W.fh.click(icon)
  local id = icon.id
  if not id then return end
  if IsShiftKeyDown() then
    local link = select(2, NW.ItemInfo(id))
    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    return
  end
  if icon.ctx.recipe then NW.OpenProfession("cooking") return end
  if F.FISH[id] then NW.OpenFishFinder(id) elseif NW.FindMaterial then NW.FindMaterial(id) end
end
-- a recipe's colour at your Cooking skill, as the reagent strip shows node colours
F.COOK_WORDS = { orange = "a skill-up every time", yellow = "usually a skill-up", green = "sometimes a skill-up",
  grey = "no skill-ups", red = "your skill is too low" }
function F.cookState(r, cook)
  if not cook then return nil end
  local lo = r.orange or r.yellow
  if cook < lo then return "red" end
  if r.yellow and cook < r.yellow then return "orange" end
  if r.green and cook < r.green then return "yellow" end
  if cook < r.grey then return "green" end
  return "grey"
end
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
  r.strip = UI.ReagentStrip(r, W.fh, 26) -- (the gathering icon size)
  -- column headings (Leveling: Location, Fish, Skill)
  r.cap = UI.Text(r, 10, S.dim)
  r.link = r:CreateTexture(nil, "ARTWORK")
  r.link:SetColorTexture(S.edge[1], S.edge[2], S.edge[3], 0.9)
  r.link:SetWidth(1)
  r.tick = r:CreateTexture(nil, "ARTWORK")
  r.tick:SetColorTexture(S.edge[1], S.edge[2], S.edge[3], 0.9)
  r.tick:SetHeight(1)
  r:SetScript("OnClick", function(self)
    local it = self.item
    if not it or it.colhead then return end
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
-- a row's height: headings and column captions short, rows with icons taller
local ICON_ROW_H = 30
local function rowH(it)
  if it.head then return HEAD_H end
  if it.colhead then return 16 end
  if (it.strip and #it.strip > 0) or (it.fishIcons and #it.fishIcons > 0) then return ICON_ROW_H end
  return ROW_H
end
F.LOC_W, F.FISH_X = 190, 214 -- Leveling's columns: Location, Fish, Skill (right)
function F.drawRows()
  -- column headings (an item first in the list) stay put; the rest scrolls under them
  local pin = (F.items[1] and F.items[1].colhead) and 1 or 0
  local h = F.boxH - 4 - (pin == 1 and rowH(F.items[1]) or 0)
  -- the furthest it scrolls and still fills the list
  local maxOff, sum = 0, 0
  for i = #F.items, pin + 1, -1 do
    sum = sum + rowH(F.items[i])
    if sum > h then maxOff = i - pin break end
  end
  F.offset = math.max(0, math.min(F.offset or 0, maxOff))
  local fit = pin
  do
    local yy = 0
    for i = pin + F.offset + 1, #F.items do
      yy = yy + rowH(F.items[i])
      if yy > h then break end
      fit = fit + 1
    end
  end
  local y = 2
  for i, r in ipairs(W.rows) do
    local it = (i <= pin) and F.items[i] or F.items[i + F.offset]
    r.item = it
    if it and i <= fit then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 4, -y)
      local rh = rowH(it)
      r:SetHeight(rh - 1)
      y = y + rh
      r:Show()
      r:EnableMouse(not it.colhead)
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
      -- a catch under its dish: indented, a line from its icon down to the dish's
      r.icon:ClearAllPoints()
      r.icon:SetPoint("LEFT", it.child and 38 or 20, 0)
      r.link:Hide()
      r.tick:Hide()
      -- Leveling's zone rows: the place in its column, no map icon; captions on top
      r.text:ClearAllPoints()
      if it.colhead or it.zone then
        r.text:SetPoint("LEFT", 22, 0)
      else
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      end
      r.cap:SetText("")
      if it.colhead then
        r.mark:SetText("")
        r.text:SetText(H.dim .. "Location|r")
        r.cap:ClearAllPoints()
        r.cap:SetPoint("LEFT", F.FISH_X, 0)
        r.cap:SetText(H.dim .. "Fish|r")
        r.headBg:Hide()
        r:SetStripe(false)
      end
      if it.child then
        r.link:ClearAllPoints()
        r.link:SetPoint("TOP", r, "TOPLEFT", 29, it.linkTop and 1 or -(r:GetHeight() / 2))
        r.link:SetPoint("BOTTOM", r, "BOTTOMLEFT", 29, -1)
        r.link:Show()
        r.tick:ClearAllPoints()
        r.tick:SetPoint("LEFT", r, "LEFT", 29, 0)
        r.tick:SetWidth(8)
        r.tick:Show()
      elseif it.parent then
        r.link:ClearAllPoints()
        r.link:SetPoint("TOP", r, "TOPLEFT", 29, 1)
        r.link:SetPoint("BOTTOM", r, "TOPLEFT", 29, -(r:GetHeight() - 18) / 2)
        r.link:Show()
      end
      r.icon:SetShown((it.icon ~= nil or it.head) and not it.zone and not it.colhead)
      r.icon:SetDesaturated(it.desat and true or false)
      r.right:SetText(it.right or "")
      -- fish (a zone's), or what a step uses or makes: icons on the right
      local list = it.strip or (it.fishIcons and #it.fishIcons > 0 and it.fishIcons)
      local strip = r.strip
      strip:Begin()
      if list then
        for _, e in ipairs(list) do
          local id = type(e) == "table" and e[1] or e
          local ic = strip:Add(id, type(e) == "table" and e[2] or false, type(e) == "table" and e[3] or nil)
          ic.ctx.perCraft = type(e) == "table" and e[2] or nil
          ic.ctx.cookedInto = type(e) == "table" and e.dish or nil
        end
      end
      local n = strip.n
      local w = math.max(1, n * 31 - 5)
      strip:Finish(w)
      strip:ClearAllPoints()
      local rw = (r.right:GetText() or "") ~= "" and math.min(150, (r.right:GetStringWidth() or 0) + 12) or 0
      if it.zone then
        -- a zone: its fish in their own column, its skill on the right
        strip:SetPoint("LEFT", r, "LEFT", F.FISH_X, 0)
        r.text:SetWidth(F.LOC_W)
      else
        strip:SetPoint("RIGHT", r, "RIGHT", -6 - rw, 0)
        -- the label stops short of the icons and the right-hand text
        r.text:SetWidth(MID_W - 8 - 44 - 12 - rw - (n > 0 and (w + 8) or 0) - (it.child and 18 or 0))
      end
      strip:SetShown(n > 0)
    else
      r:Hide()
    end
  end
  if maxOff > 0 and fit > 0 then
    local total = #F.items
    local th = math.max(20, h * fit / total)
    W.thumb:SetHeight(th)
    W.thumb:ClearAllPoints()
    W.thumb:SetPoint("TOPRIGHT", W.box, "TOPRIGHT", -1, -2 - (h - th) * (F.offset / math.max(1, maxOff)))
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
  v:SetWordWrap(false)
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
-- (w, h: a smaller map, the same 3:2 shape the game's zone maps have)
function F.drawMap(mapID, spots, w, h)
  w, h = w or MAP_W, h or MAP_H
  W.map:SetSize(w, h)
  W.mapArt:SetSize(w - 2, h - 2)
  UI.DrawZoneArt(mapID, W.mapArt, W.mapTiles, w - 2, h - 2, true)
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
      d:SetPoint("CENTER", W.mapArt, "TOPLEFT", sp.x * (w - 2), -sp.y * (h - 2))
      d:Show()
    elseif d then
      d:Hide()
    end
  end
end
-- what the map shows, on its bottom edge; hover for more
W.mapCap = UI.Text(W.map, 10, S.dim)
W.mapCap:SetPoint("BOTTOMLEFT", 5, 4)
W.mapCap:SetShadowOffset(1, -1)
W.mapHit = CreateFrame("Frame", nil, W.map)
W.mapHit:SetAllPoints()
W.mapHit:EnableMouse(true)
W.mapHit:SetScript("OnEnter", function(self) if self.fn then GameTooltip:SetOwner(self, "ANCHOR_LEFT") self.fn(GameTooltip) GameTooltip:Show() end end)
W.mapHit:SetScript("OnLeave", GameTooltip_Hide)
-- one small button on a row (the lure's Smart Fishing choice)
W.rowBtn = UI.Button(W.right, "", 70, nil, 20)
W.rowBtn:Hide()
if W.rowBtn.SetMotionScriptsWhileDisabled then W.rowBtn:SetMotionScriptsWhileDisabled(true) end -- (its tooltip says why it's off)
W.rowBtn:HookScript("OnEnter", function(self)
  if not self.tip then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:SetText(self:GetText() or "", 1, 1, 1)
  GameTooltip:AddLine(self.tip, S.dim[1], S.dim[2], S.dim[3], true) GameTooltip:Show()
end)
W.rowBtn:HookScript("OnLeave", GameTooltip_Hide)
W.btn1 = UI.Button(W.right, "Show on map", math.floor((RIGHT_W - 6) / 2), nil, 24)
W.btn2 = UI.Button(W.right, "", math.floor((RIGHT_W - 6) / 2), nil, 24)
W.btn1:Hide() W.btn2:Hide()

-- icon groups in the panel: the professions' reagent strip (pooled), a short label at the left
W.rstrips = {}
local ICON_LABEL_W = 46
local ITEM2_INFO = 62 -- an item row's info right of its second icon
local function panelStrip(k)
  local s = W.rstrips[k]
  if not s then
    s = UI.ReagentStrip(W.right, W.fh, 26)
    W.rstrips[k] = s
  end
  return s
end
-- a line's tooltip: a hover area made the first time a line needs one
local function lineTip(ln, fn, h)
  if not fn then if ln.hit then ln.hit:Hide() end return end
  if not ln.hit then
    ln.hit = CreateFrame("Frame", nil, W.right)
    ln.hit:EnableMouse(true)
    ln.hit:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT") self.fn(GameTooltip) GameTooltip:Show() end)
    ln.hit:SetScript("OnLeave", GameTooltip_Hide)
  end
  ln.hit.fn = fn
  ln.hit:ClearAllPoints()
  ln.hit:SetPoint("TOPLEFT", ln.l, "TOPLEFT", 0, 2)
  ln.hit:SetSize(RIGHT_W, h or 15)
  ln.hit:Show()
end
F.lineTip = lineTip
-- rows: { label, value } (value nil: a full-width line), "gap", { head = text }, { bar = 0..1 },
-- { icons = { {id, qty|false, state, ctx}, ... }, label = text } ; any line may have tip = function(tooltip)
function F.detail(head, icon, title, sub, rows, b1, b2)
  W.rHead.text:SetText(head or "")
  W.rIconBox:SetShown(icon ~= nil)
  W.rIcon:SetTexture(icon)
  W.rTitle:SetText(title or "")
  W.rSub:SetText(sub or "")
  local anchor, y = icon and W.rIconBox or W.rHead, icon and -10 or -6
  for _, b in ipairs(W.bars) do b:Hide() end
  W.map:Hide()
  local n, nb, ns = 0, 0, 0
  local usedBtn = false
  for _, ln in ipairs(W.lines) do if ln.arrow then ln.arrow:Hide() end end
  for _, row in ipairs(rows or {}) do
    if row == "gap" then
      y = y - 6
    elseif row.icons then
      if #row.icons > 0 and ns < 12 and n < #W.lines then
        ns, n = ns + 1, n + 1
        local s = panelStrip(ns)
        s:Begin()
        for _, e in ipairs(row.icons) do
          local ic = s:Add(e[1], e[2], e[3])
          if e[4] then for k, v in pairs(e[4]) do ic.ctx[k] = v end end
        end
        local lines = s:Finish(RIGHT_W - ICON_LABEL_W)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", ICON_LABEL_W, y)
        s:Show()
        local ln = W.lines[n]
        ln.l:ClearAllPoints()
        ln.l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y - 9)
        ln.l:SetFont(UI.FONT, 11, "")
        ln.l:SetTextColor(unpack(S.dim))
        ln.l:SetWidth(ICON_LABEL_W - 4)
        ln.l:SetText(row.label or "")
        ln.v:SetText("")
        ln.l:Show() ln.v:Show()
        lineTip(ln, row.tip, 26)
        y = y - lines * 31 - 3
      end
    elseif row.item then
      -- an item row: [icon] name, then [→ icon] info, or info on the right (and a button)
      if ns < 12 and n < #W.lines then
        ns, n = ns + 1, n + 1
        local s = panelStrip(ns)
        s:Begin()
        for _, e in ipairs({ row.item, row.item2 }) do
          local ic = s:Add(e[1], e[2], e[3])
          if e[4] then for k, v in pairs(e[4]) do ic.ctx[k] = v end end
        end
        s:Finish(80)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        s:Show()
        local ln = W.lines[n]
        ln.l:ClearAllPoints() ln.v:ClearAllPoints()
        ln.l:SetFont(UI.FONT, 11, "")
        ln.l:SetTextColor(unpack(row.color or S.text))
        ln.l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 32, y - 9)
        ln.l:SetText(row.text or "")
        ln.v:SetFont(UI.FONT, 11, "")
        if row.item2 then
          -- the second icon at the right, after an arrow; its info right of it
          local x2 = RIGHT_W - ITEM2_INFO - 30
          local i2 = s.icons[2]
          i2:ClearAllPoints()
          i2:SetPoint("TOPLEFT", s, "TOPLEFT", x2 + 1, -1)
          ln.l:SetWidth(x2 - 32 - 18)
          if not ln.arrow then
            ln.arrow = W.right:CreateTexture(nil, "ARTWORK")
            ln.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
            ln.arrow:SetSize(12, 12)
            ln.arrow:SetVertexColor(S.dim[1], S.dim[2], S.dim[3])
          end
          ln.arrow:ClearAllPoints()
          ln.arrow:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x2 - 15, y - 8)
          ln.arrow:Show()
          ln.v:SetJustifyH("LEFT")
          ln.v:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x2 + 32, y - 9)
          ln.v:SetWidth(ITEM2_INFO - 4)
        else
          local bw = row.btn and 76 or 0
          ln.v:SetJustifyH("RIGHT")
          ln.v:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", RIGHT_W - bw - 4, y - 9)
          ln.v:SetWidth(40)
          ln.l:SetWidth(RIGHT_W - 32 - 44 - bw)
          if row.btn then
            local b = W.rowBtn
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", RIGHT_W, y - 3)
            b:SetText(row.btn[1])
            b:SetScript("OnClick", row.btn[2])
            b:SetEnabled(row.btn[2] ~= nil)
            b.tip = row.btn.tip
            b:Show()
            usedBtn = true
          end
        end
        ln.v:SetText(row.info or "")
        ln.l:Show() ln.v:Show()
        lineTip(ln, row.tip, 26)
        -- (an item row's tooltip sits on its info, where the "+N" is)
        if ln.hit and row.tip then ln.hit:ClearAllPoints() ln.hit:SetPoint("TOPLEFT", ln.v, "TOPLEFT", 0, 9) ln.hit:SetWidth(row.item2 and ITEM2_INFO or 70) end
        y = y - 28
      end
    elseif row.stats then
      -- values side by side, each under its small label
      local cw = math.floor(RIGHT_W / #row.stats)
      for k, c in ipairs(row.stats) do
        if n < #W.lines then
          n = n + 1
          local ln = W.lines[n]
          ln.l:ClearAllPoints() ln.v:ClearAllPoints()
          ln.l:SetFont(UI.FONT, 10, "")
          ln.l:SetTextColor(unpack(S.dim))
          ln.l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (k - 1) * cw, y)
          ln.l:SetWidth(cw - 6)
          ln.l:SetText(c[1])
          ln.v:SetFont(UI.FONT, 14, "")
          ln.v:SetJustifyH("LEFT")
          ln.v:SetPoint("TOPLEFT", ln.l, "BOTTOMLEFT", 0, -2)
          ln.v:SetWidth(cw - 6)
          ln.v:SetText(c[2])
          ln.l:Show() ln.v:Show()
          lineTip(ln, k == 1 and row.tip or nil, 30)
        end
      end
      y = y - 34
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
      F.drawMap(row.map, row.spots or {}, row.w, row.h)
      W.mapCap:SetText(row.cap or "")
      W.mapHit.fn = row.tip
      W.mapHit:SetShown(row.tip ~= nil)
      y = y - (row.h or MAP_H) - 8
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
        ln.v:SetFont(UI.FONT, 11, "")
        ln.v:SetJustifyH("RIGHT")
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
      lineTip(ln, row.tip)
    end
  end
  for i = n + 1, #W.lines do W.lines[i].l:Hide() W.lines[i].v:Hide() lineTip(W.lines[i], nil) end
  for k = ns + 1, #W.rstrips do W.rstrips[k]:Clear() W.rstrips[k]:Hide() end
  if not usedBtn then W.rowBtn:Hide() end
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
    if r.cap then tt:AddDoubleLine("Raises the cap to", r.cap, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    tt:AddLine(r.how, 1, 0.82, 0, true)
  end
end
function F.leveling()
  local rank, max, bonus = F.skill()
  local base = rank or 0
  local folds = F.cfg().folds
  local items = { { colhead = true, right = H.dim .. "Skill range|r" } }
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
          mark = trained and mark("done") or mark(), text = H.gold .. "Train|r  " .. H.dim .. r.name .. "|r",
          right = ("%d+"):format(r.skill), selKey = "rank" .. bi, tip = rankTip(r), dim = trained }
      end
      for _, z in ipairs(F.sortZones(b.zones)) do
        local here, range = F.fishIn(z, bi)
        local icons = {}
        for _, id in ipairs(here) do icons[#icons + 1] = id end
        if #icons == 0 then for _, id in ipairs(range) do if #icons < 5 then icons[#icons + 1] = id end end end
        local name = F.hostile(z) and (H.dim .. z .. "|r") or z
        if b.best == z then name = name .. "  " .. H.gold .. "best|r" end
        local range = ("%d-%d"):format(b[1], b[2])
        items[#items + 1] = { text = name, fishIcons = icons, right = cur and (H.gold .. range .. "|r") or (H.dim .. range .. "|r"),
          selKey = "zone" .. bi .. ":" .. z, zone = z, bi = bi, dim = done, mark = cur and mark("next") or nil }
      end
      for _, z in ipairs(b.later or {}) do
        items[#items + 1] = { text = z, right = ("from %d with a lure"):format(b.laterAt),
          selKey = "zone" .. bi .. ":" .. z, zone = z, bi = bi, later = b.laterAt, dim = done }
      end
    end
  end
  return items
end

-- your fishing on one line: Base | Bonus | Effective; equipment and lure in the tooltip
function F.equipLines(rows)
  local rank, _, bonus = F.skill()
  if not rank then return end
  local lure = F.lureOn()
  local lb = lure and F.lureBonus()
  local d = S.dim
  rows[#rows + 1] = { ("%sBase|r %d    %sBonus|r %s    %sEffective|r %s%d|r"):format(H.dim, rank, H.dim, bonus > 0 and ("+" .. bonus) or "0",
    H.dim, BLUE_HEX, rank + bonus), tip = function(tt)
    tt:SetText("Fishing skill", 1, 1, 1)
    tt:AddDoubleLine("Base", rank, d[1], d[2], d[3], 1, 1, 1)
    if lure == false then
      -- a pole with no lure on: it's all equipment
      tt:AddDoubleLine("Equipment", "+" .. bonus, d[1], d[2], d[3], 1, 1, 1)
      tt:AddDoubleLine("Lure", "none", d[1], d[2], d[3], d[1], d[2], d[3])
    elseif lb and lb <= bonus then
      tt:AddDoubleLine("Equipment", "+" .. (bonus - lb), d[1], d[2], d[3], 1, 1, 1)
      tt:AddDoubleLine("Lure", ("+%d, %d min left"):format(lb, lure), d[1], d[2], d[3], 1, 1, 1)
    else
      -- the client gives one total; the split is only read off the pole's tooltip
      tt:AddDoubleLine("Equipment and lure", "+" .. bonus, d[1], d[2], d[3], 1, 1, 1)
      if lure then tt:AddDoubleLine("Lure", lure .. " min left", d[1], d[2], d[3], 1, 1, 1) end
    end
    tt:AddDoubleLine("Effective", rank + bonus, d[1], d[2], d[3], 1, 1, 1)
  end }
end
-- the active lure's bonus, read off the equipped pole's tooltip (nil if unreadable)
function F.lureBonus()
  if not CreateFrame then return nil end
  local tip = F.scanTip
  if not tip then
    tip = CreateFrame("GameTooltip", "NodewalkerScanTip", nil, "GameTooltipTemplate")
    F.scanTip = tip
  end
  tip:SetOwner(WorldFrame, "ANCHOR_NONE")
  tip:ClearLines()
  local ok = pcall(tip.SetInventoryItem, tip, "player", 16)
  local found
  if ok then
    for i = 1, tip:NumLines() or 0 do
      local fs = _G["NodewalkerScanTipTextLeft" .. i]
      local s = fs and fs:GetText()
      local n = s and s:match("Lure.-%+(%d+)")
      if n then found = tonumber(n) break end
    end
  end
  tip:Hide()
  return found
end

local function lureFor(b, rows)
  if not b.lure then return end
  local _, _, bonus = F.skill()
  local want
  for _, l in ipairs(F.LURES) do if l[1] == b.lure then want = l end end
  if not want then return end
  local ok = bonus >= want[2]
  rows[#rows + 1] = { icons = { { want[1], "+" .. want[2], ok and "made" or "ok", { lure = want[2], covered = ok } } }, label = "Lure" }
end

-- fish as icons (what you have in the corner), each with its facts in the tooltip
local function fishIcons(ids)
  local out = {}
  for _, id in ipairs(ids) do
    local n = NW.ItemCount(id) or 0
    out[#out + 1] = { id, n > 0 and n or false }
  end
  return out
end
F.fishIcons = fishIcons
-- recipes as their dishes, edged by their colour at your Cooking skill
local function recipeIcons(list, max)
  local cook = NW.ProfSkill("cooking")
  local out = {}
  for _, r in ipairs(list) do
    if r.item and #out < (max or 8) then out[#out + 1] = { r.item, false, F.cookState(r, cook) or "ok", { recipe = r } } end
  end
  return out
end
F.recipeIcons = recipeIcons
local function cookFrom(fish)
  local seen, uses = {}, {}
  for _, id in ipairs(fish) do for _, r in ipairs(NW.CookFish(id)) do if not seen[r] then seen[r] = true; uses[#uses + 1] = r end end end
  table.sort(uses, function(x, y) return (x.orange or x.yellow) < (y.orange or y.yellow) end)
  return uses
end

-- one fish and what it cooks into: [fish] name → [dish] Cooking range (recipe, if it isn't the fish's name)
local function catchRow(id, cook)
  local n = NW.ItemCount(id) or 0
  local name = (F.itemName(id)):gsub("^Raw ", "")
  local row = { item = { id, n > 0 and n or false }, text = name }
  local list = NW.CookFish(id)
  local r = list[1]
  if r and r.item then
    local rname = r.name or ""
    row.item2 = { r.item, false, F.cookState(r, cook) or "ok", { recipe = r, recipes = #list > 1 and list or nil } }
    row.info = ("%d-%d"):format(r.orange or r.yellow, r.grey) .. (#list > 1 and (H.dim .. " +" .. (#list - 1) .. "|r") or "")
    if #list > 1 or rname ~= name then
      row.tip = function(tt)
        tt:SetText(name, 1, 1, 1)
        for _, x in ipairs(list) do tt:AddDoubleLine(x.name, ("%d-%d"):format(x.orange or x.yellow, x.grey), 1, 1, 1, S.dim[1], S.dim[2], S.dim[3]) end
      end
    end
  end
  return row
end
-- the lure for this range: icon, name and bonus; Smart Fishing can put it on with its key
local function lureRow(b)
  if not b.lure then return nil end
  local _, _, bonus = F.skill()
  local want
  for _, l in ipairs(F.LURES) do if l[1] == b.lure then want = l end end
  if not want then return nil end
  local SF = NW.SmartFish
  local covered = bonus >= want[2]
  local have = NW.ItemCount(want[1]) or 0
  local row = { item = { want[1], have > 0 and have or false, covered and "made" or "ok", { lure = want[2], covered = covered } },
    text = F.itemName(want[1], SF and SF.LURE_NAME and SF.LURE_NAME[want[1]]), info = ("+%d"):format(want[2]) }
  if SF then
    local s = NW.db.settings
    local pref = SF.prefLure and SF.prefLure() or s.fishLurePref
    if s.fishLure == "pref" and pref == want[1] then
      row.btn = { "Preferred", nil, tip = "Smart Fishing puts this lure on with its key." }
    elseif have == 0 then
      -- preferring one you don't carry would stop Smart Fishing putting any lure on
      row.btn = { "Prefer", nil, tip = "None in your bags." }
    else
      row.btn = { "Prefer", function()
        s.fishLure, s.fishLurePref = "pref", want[1]
        if SF.Update then SF.Update() end
        F.Redraw()
      end, tip = "Smart Fishing puts this lure on with its key." }
    end
  end
  return row
end

function F.zoneDetail(zone, bi, later)
  local b = F.BRACKETS[bi]
  local here, range = F.fishIn(zone, bi)
  local d = S.dim
  local cook = NW.ProfSkill("cooking")
  local rows = {}
  if F.hostile(zone) then rows[#rows + 1] = { H.bad .. "The other faction's city|r" } end
  -- the zone, and where you've caught fish in it (the journal's spots; none are shipped)
  local mapID = NW.ZoneID and NW.ZoneID(zone)
  local MAXR = 4 -- (fish rows; the map takes what they leave)
  if mapID then
    local J = NW.FishJournal
    local spots = J and J.Spots and J.Spots(mapID, "all") or {}
    -- the panel's height less everything under the map: as big as fits, in the game's 3:2 map shape
    local nFish = math.min(MAXR, #here + #range)
    local labels = (#here > 0 and 1 or 0) + ((#range > 0 and #here < MAXR) and 1 or 0)
    local below = 62 + 8 + labels * 15 + nFish * 28 + 6 + (b.lure and 28 or 0) + 34 + 34 + (F.hostile(zone) and 15 or 0)
    local mh = math.max(96, math.min(math.floor(RIGHT_W * 2 / 3), (530 - TOP) - below - 6))
    rows[#rows + 1] = { map = mapID, spots = spots, w = math.floor(mh * 3 / 2), h = mh,
      cap = #spots > 0 and "Your catches" or "", tip = function(tt)
        tt:SetText(zone, 1, 1, 1)
        if #spots > 0 then tt:AddLine("Dots: where you've caught fish (your journal).", d[1], d[2], d[3], true)
        else tt:AddLine("No catches logged here yet. Fishing spots aren't in the data, so none are shown.", d[1], d[2], d[3], true) end
      end }
  end
  -- what you may catch: this zone's fish, then other fish for this skill (not every water has every fish)
  local shown = 0
  local function list(ids, label, tip)
    if #ids == 0 then return end
    local room = math.max(1, MAXR - shown)
    rows[#rows + 1] = { label .. (#ids > room and (H.dim .. "  +" .. (#ids - room) .. "|r") or ""), color = S.dim, tip = tip }
    for k = 1, math.min(room, #ids) do rows[#rows + 1] = catchRow(ids[k], cook) shown = shown + 1 end
  end
  list(here, "In this zone", function(tt)
    tt:SetText("May be caught in this zone", 1, 1, 1)
    tt:AddLine("Not at every body of water.", d[1], d[2], d[3], true)
    tt:AddLine("Skill range from leveling guides; the zone's minimum isn't published.", d[1], d[2], d[3], true)
    for k = 1, #here do tt:AddLine((F.itemName(here[k])):gsub("^Raw ", ""), 1, 1, 1) end
  end)
  list(range, #here > 0 and "Also at this skill" or "At this skill", function(tt)
    tt:SetText("Other fish at this skill", 1, 1, 1)
    tt:AddLine("Caught in other waters at this skill range.", d[1], d[2], d[3], true)
    for k = 1, #range do tt:AddLine((F.itemName(range[k])):gsub("^Raw ", ""), 1, 1, 1) end
  end)
  rows[#rows + 1] = "gap"
  local lr = lureRow(b)
  if lr then rows[#rows + 1] = lr end
  -- your skill: three values; equipment and lure in the tooltip
  local rank, _, bonus = F.skill()
  if rank then
    local eq = {}
    F.equipLines(eq)
    rows[#rows + 1] = { stats = { { "Base", tostring(rank) }, { "Bonus", bonus > 0 and ("+" .. bonus) or "0" },
      { "Effective", BLUE_HEX .. (rank + bonus) .. "|r" } }, tip = eq[1] and eq[1].tip }
  end
  local first = here[1] or range[1]
  F.detail("Location", "Interface\\Icons\\Trade_Fishing", zone, "", rows,
    { "Show on map", F.showZone(zone) },
    { "Material Finder", function()
      if not (first and NW.FindMaterialAt and NW.FindMaterialAt(first, "fishing", zone)) then NW.OpenFishFinder(first) end
    end })
end

function F.rankDetail(r, prof)
  local level = UnitLevel and UnitLevel("player") or 60
  local rows = {}
  if r.skill then rows[#rows + 1] = { "Skill", tostring(r.skill) } end
  if r.level then rows[#rows + 1] = { "Level", (level >= r.level and H.good or H.bad) .. r.level .. "|r" } end
  rows[#rows + 1] = "gap"
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
  rows[#rows + 1] = { "Guides fish it from", f.skill and tostring(f.skill) or (H.dim .. "not known|r") }
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
-- what a row says next to its icon: the icon and the section say the action
function F.shortLabel(a)
  local k = a.kind
  if k == "catch" then return (a.buy and "Buy " or "") .. (F.itemName(a.fish)):gsub("^Raw ", "") end
  if k == "cook" then return a.recipe.name end
  if k == "recipe" then return "Recipe: " .. a.recipe.name end
  if k == "train" then
    local r = a.rank or a.crank
    return ("%s  %s%s|r"):format(r.name, H.dim, a.prof == "fishing" and "Fishing" or "Cooking")
  end
  if k == "fishto" then
    local b = a.b
    local z = b and (b.best or F.sortZones(b.zones)[1])
    return z and ("Fish: " .. z) or a.label
  end
  if k == "vendor" then return "Vendor" end
  if k == "other" then return "Ingredients" end
  return a.label
end
local function actionRight(a)
  if a.kind == "catch" then
    return ("%s%d|r%s/~%d|r"):format(a.have >= a.need and H.good or H.text, a.have, H.dim, a.need)
  elseif a.kind == "cook" then
    return ("×%d %s %d"):format(a.step.crafts, ARROW, a.step.to)
  elseif a.kind == "fishto" then
    return ("%s %d"):format(ARROW, a.to)
  elseif a.kind == "train" then
    local r = a.rank or a.crank
    return a.blocked and (H.bad .. a.blocked .. "|r") or (r.skill and ("%d+"):format(r.skill) or "")
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
    -- the heading says what the phase holds: Fishing and Cooking can be at different skills
    local fLo, fHi, cLo, cHi
    for _, a in ipairs(ph.actions) do
      if a.kind == "fishto" then fLo, fHi = math.min(fLo or a.from, a.from), math.max(fHi or a.to, a.to) end
      if a.kind == "cook" then cLo, cHi = math.min(cLo or a.step.from, a.step.from), math.max(cHi or a.step.to, a.step.to) end
    end
    local parts = {}
    if fLo then parts[#parts + 1] = ("Fishing %d-%d"):format(fLo, fHi) end
    if cLo then parts[#parts + 1] = ("Cooking %d-%d"):format(cLo, cHi) end
    local what = #parts > 0 and table.concat(parts, "  ·  ") or ("%s  %d-%d"):format(ph.name, ph.lo, ph.hi)
    items[#items + 1] = { head = true, text = what .. tag, foldKey = key, folded = folded }
    if not folded then
      for ai, a in ipairs(ph.actions) do
        local state = a.done and "done" or a.blocked and "blocked" or (plan.next == a and "next") or nil
        local label = F.shortLabel(a)
        if plan.next == a then label = H.gold .. label .. "|r" elseif a.blocked then label = H.dim .. label .. "|r" end
        -- what connects them: a catch shows the dish it's cooked into, a cook
        -- step its fish and other ingredients (one craft's worth)
        local strip
        if a.kind == "vendor" or a.kind == "other" then
          -- what to buy, with how many, in place of a sentence
          strip = {}
          for _, e in ipairs(a.items) do strip[#strip + 1] = { e.id, e.need, (a.done or e.have >= e.need) and "ok" or "short" } end
        elseif a.kind == "catch" then
          strip = {}
          for _, b in ipairs(ph.actions) do
            if b.kind == "cook" and b.recipe.item then
              for _, re in ipairs(b.recipe.reagents) do
                if re[1] == a.fish then strip[#strip + 1] = { b.recipe.item, false, nil, dish = true } break end
              end
            end
          end
        elseif a.kind == "cook" then
          strip = {}
          for _, re in ipairs(a.recipe.reagents) do
            local st = nil
            if not a.done then
              for _, b in ipairs(ph.actions) do
                if b.kind == "catch" and b.fish == re[1] then st = (b.done and "ok") or (b.blocked and "short") or nil end
              end
            end
            strip[#strip + 1] = { re[1], re[2], st }
          end
        end
        items[#items + 1] = { icon = actionIcon(a), mark = mark(state), text = label, right = actionRight(a),
          selKey = ("a%d:%d"):format(ph.ti, ai), action = a, dim = a.done or ph.done, strip = strip }
      end
    end
  end
  -- a catch right above the cooking that uses its fish hangs off it: indented,
  -- with a line down to the dish (catch fish, then cook, as the plan does it)
  for i, it in ipairs(items) do
    local a = it.action
    if a and a.kind == "catch" then
      local j = i + 1
      while items[j] and items[j].action and items[j].action.kind == "catch" do j = j + 1 end
      local cook = items[j] and items[j].action
      if cook and cook.kind == "cook" then
        for _, re in ipairs(cook.recipe.reagents) do
          if re[1] == a.fish then
            it.child = true
            it.strip = nil -- (the line to the dish says what it's for)
            it.linkTop = items[i - 1] and items[i - 1].child or false
            items[j].parent = true
            break
          end
        end
      end
    end
  end
  return items
end

function F.actionDetail(a, plan)
  local k = a.kind
  local d = S.dim
  if k == "catch" then
    local f = F.FISH[a.fish]
    local zones, named = F.zonesFor(a.fish)
    local rows = { { bar = a.need > 0 and math.min(1, a.have / a.need) or 1 },
      { "To go", ("~%d"):format(math.max(0, a.need - a.have)), tip = function(tt)
        tt:SetText("Fish to collect", 1, 1, 1)
        tt:AddLine("An estimate in fish, not casts: skill-ups are random.", d[1], d[2], d[3], true)
      end } }
    -- what stops it, up front
    if a.blocked then rows[#rows + 1] = { H.bad .. a.blocked .. "|r" } end
    if f.season then rows[#rows + 1] = { H.gold .. f.season .. " only|r", tip = function(tt)
      tt:SetText("Seasonal", 1, 1, 1) tt:AddLine("By Classic data.", d[1], d[2], d[3], true) end } end
    rows[#rows + 1] = { "Guides", f.skill and ("from %d"):format(f.skill) or (H.dim .. "not known|r"), tip = function(tt)
      tt:SetText("Fishing skill", 1, 1, 1)
      tt:AddLine(f.skill and "From leveling guides, not a confirmed minimum." or "Not known.", d[1], d[2], d[3], true)
    end }
    if f.note then rows[#rows + 1] = { "Where", f.note } end
    -- catching it waits for Fishing; buying it would let Cooking go on now
    if not a.buy and not a.done and f.skill and f.skill > (plan.fishNow or 0) then
      local p, src = NW.Price(a.fish)
      rows[#rows + 1] = { "Or buy", (p and src ~= "est") and (NW.Money(p, "mid") .. " each") or "set \"Catch or buy\"", color = S.gold, tip = function(tt)
        tt:SetText("Buy instead", 1, 1, 1) tt:AddLine("\"Catch or buy\" lets Cooking go on now.", d[1], d[2], d[3], true) end }
    end
    if a.value then rows[#rows + 1] = { "Worth", "~" .. NW.Money(a.value, "mid") } end
    -- where (zones), what it's cooked into, and other fish that do the same job
    if #zones > 0 then
      local z3 = {}
      for z = 1, math.min(3, #zones) do z3[z] = F.hostile(zones[z]) and (H.dim .. zones[z] .. "|r") or zones[z] end
      rows[#rows + 1] = { (named and "" or (H.dim .. "At this skill: |r")) .. table.concat(z3, ", ") .. (#zones > 3 and (H.dim .. " +" .. (#zones - 3) .. "|r") or ""),
        tip = function(tt)
          tt:SetText(named and "Found in" or "Waters at this skill", 1, 1, 1)
          for z = 1, math.min(10, #zones) do tt:AddLine(zones[z], 1, 1, 1) end
        end }
    end
    local dishes = {}
    for _, b in ipairs(a.phase and a.phase.actions or {}) do
      if b.kind == "cook" and b.recipe.item then
        for _, re in ipairs(b.recipe.reagents) do
          if re[1] == a.fish then dishes[#dishes + 1] = { b.recipe.item, false, F.cookState(b.recipe, NW.ProfSkill("cooking")) or "ok",
            { recipe = b.recipe, perCraft = re[2], stepFrom = b.step.from, stepTo = b.step.to } } break end
        end
      end
    end
    rows[#rows + 1] = { icons = dishes, label = "Cook" }
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
    local altI = {}
    for z = 1, math.min(6, #alt) do altI[z] = fishIcons({ alt[z] })[1] end
    rows[#rows + 1] = { icons = altI, label = "Or", tip = function(tt)
      tt:SetText("Also gives skill-ups", 1, 1, 1) tt:AddLine("Other fish whose recipes level Cooking here.", d[1], d[2], d[3], true) end }
    F.detail(a.buy and "Buy" or "Catch", NW.ItemIcon(a.fish), F.itemName(a.fish),
      ("%s%d|r / ~%d"):format(a.have >= a.need and H.good or H.text, a.have, a.need), rows,
      zones[1] and { "Show on map", F.showZone(zones[1]) } or nil,
      { "Material Finder", function() NW.OpenFishFinder(a.fish) end })
  elseif k == "cook" then
    local r, stp = a.recipe, a.step
    local known = (NW.charDB.known.cooking or {})[r.name]
    local mats, missing, per = {}, {}, {}
    for _, re in ipairs(r.reagents or {}) do per[re[1]] = re[2] end
    for _, m in ipairs(stp.mats or {}) do
      local n = NW.ItemCount(m[1]) or 0
      -- one craft's count in the corner, as everywhere; the total in the tooltip
      mats[#mats + 1] = { m[1], per[m[1]] or m[2], n >= m[2] and "ok" or "short", { need = m[2], perCraft = per[m[1]], est = F.FISH[m[1]] and true or nil } }
      local nm, ok = F.itemName(m[1])
      if n < m[2] and ok and not F.FISH[m[1]] then missing[#missing + 1] = { nm, m[2] - n } end
    end
    local rows = { { icons = mats, label = "Uses", tip = function(tt)
      tt:SetText("Per craft", 1, 1, 1) tt:AddLine("Hover an icon for the total. Red edge: not enough yet.", d[1], d[2], d[3], true) end } }
    if not known then
      rows[#rows + 1] = { "Recipe", (r.src == "trainer" or r.src == "rank") and "trainer" or (H.bad .. "to get|r") }
    end
    F.detail("Cook", r.item and NW.ItemIcon(r.item) or nil, r.name, ("×~%d  ·  Cooking %d-%d"):format(stp.crafts, stp.from, stp.to), rows,
      #missing > 0 and NW.SearchAH and { "Search missing", function() NW.SearchAH(missing) end } or nil,
      { "Cooking plan", function() NW.OpenProfession("cooking") end })
  elseif k == "train" then
    if a.prof == "fishing" then F.rankDetail(a.rank) return end
    local ru = a.crank
    local who, where, mapID, x, y = NW.RankWhere("cooking", ru.name)
    local level = UnitLevel and UnitLevel("player") or 60
    local rows = { { "Skill", tostring(ru.skill or 0) },
      { "Level", ((level >= (ru.level or 0)) and H.good or H.bad) .. (ru.level or 1) .. "|r" }, "gap",
      { who or "Any cooking trainer" } }
    if where then rows[#rows + 1] = { where, color = S.dim } end
    if a.cost then rows[#rows + 1] = { "Cost", NW.Money(a.cost, "mid") } end
    F.detail("Train", "Interface\\Icons\\INV_Misc_Book_09", ru.name .. " Cooking", ("Cooking to %d"):format(ru.cap), rows,
      mapID and { "Show on map", function() NW.PinMap(mapID, x, y, who) end } or nil)
  elseif k == "recipe" then
    local r = a.recipe
    local rows = {}
    -- one source a line, so none is cut off
    local src = NW.RecipeSourceText and NW.RecipeSourceText("cooking", r) or ""
    src = src:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local parts = {}
    for part in (src .. "  ·  "):gmatch("(.-)  ·  ") do if part ~= "" then parts[#parts + 1] = part end end
    for p = 1, math.min(6, #parts) do rows[#rows + 1] = { parts[p] } end
    if #parts > 6 then rows[#rows + 1] = { ("+%d more"):format(#parts - 6), color = S.dim, tip = function(tt)
      tt:SetText("Also", 1, 1, 1)
      for p = 7, #parts do tt:AddLine(parts[p], 1, 1, 1, true) end
    end } end
    rows[#rows + 1] = "gap"
    rows[#rows + 1] = { "Cost", money(a.cost) }
    rows[#rows + 1] = { icons = r.item and recipeIcons({ r }) or {}, label = "Makes" }
    local nm, ok
    if r.recipeItem then nm, ok = F.itemName(r.recipeItem) end
    F.detail("Recipe", r.recipeItem and NW.ItemIcon(r.recipeItem) or "Interface\\Icons\\INV_Scroll_03", r.name,
      a.done and (H.good .. "Known|r") or ("Learn at Cooking %d"):format(r.orange or r.yellow),
      rows, ok and NW.SearchAH and { "Search", function() NW.SearchAH({ { nm, 1 } }) end } or nil)
  elseif k == "fishto" then
    local b = a.b
    local rows = {}
    for _, z in ipairs(F.sortZones(b.zones)) do
      if #rows < 4 then rows[#rows + 1] = { z .. ((b.best == z) and (H.gold .. "  best|r") or ""), color = F.hostile(z) and S.dim or S.text } end
    end
    if #b.zones > 4 then rows[#rows + 1] = { ("+%d more"):format(#b.zones - 4), color = S.dim, tip = function(tt)
      tt:SetText("Also", 1, 1, 1)
      local list = F.sortZones(b.zones)
      for z = 5, #list do tt:AddLine(list[z], 1, 1, 1) end
    end } end
    rows[#rows + 1] = "gap"
    lureFor(b, rows)
    F.equipLines(rows)
    local now = plan.fishNow or a.from
    F.detail("Fishing", "Interface\\Icons\\Trade_Fishing", ("Fishing %d %s %d"):format(math.max(now, a.from), ARROW, a.to), "", rows,
      { "Show on map", F.showZone(b.best or F.sortZones(b.zones)[1]) })
  elseif k == "vendor" or k == "other" then
    local icons, search = {}, {}
    for _, e in ipairs(a.items) do
      local nm, ok = F.itemName(e.id)
      icons[#icons + 1] = { e.id, e.need, e.have >= e.need and "ok" or "short", { need = e.need, have = e.have } }
      if e.have < e.need and ok then search[#search + 1] = { nm, e.need - e.have } end
    end
    F.detail(k == "vendor" and "Vendor" or "Ingredients", actionIcon(a), k == "vendor" and "Vendor supplies" or "Other ingredients",
      k == "vendor" and "Trade goods and cooking vendors" or "", { { icons = icons, label = "Need" } },
      k == "other" and #search > 0 and NW.SearchAH and { "Search missing", function() NW.SearchAH(search) end } or nil)
  elseif k == "learn" then
    local rows = {}
    if a.prof == "fishing" then
      local list = F.TRAINERS[F.faction()] or {}
      for z = 1, math.min(6, #list) do rows[#rows + 1] = { list[z], color = S.dim } end
    else
      rows[#rows + 1] = { "Any cooking trainer in a capital city", color = S.dim }
    end
    F.detail("Learn", NW.PROF_BY_KEY[a.prof].icon, a.label, "Trainers", rows)
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
  local cooking = F.ctx == "cooking"
  local cp = NW.PROF_BY_KEY and NW.PROF_BY_KEY.cooking
  W.icon:SetTexture(cooking and cp and cp.icon or "Interface\\Icons\\Trade_Fishing")
  W.name:SetText(cooking and "Cooking" or "Fishing")
  for _, b in pairs(W.tabs) do b:SetShown(not cooking) end
  for _, b in ipairs(W.cookTabs) do b:SetShown(cooking) end
  if cooking then
    local r, m = NW.ProfSkill("cooking")
    W.skill:SetText(r and ("%d / %d"):format(r, m or 75) or ("Not learned  ·  " .. H.dim .. "planning mode|r"))
    W.next:SetText("")
    W.next2:SetText("")
    return
  end
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
    { "Find fish", function() NW.OpenFishFinder(id) end },
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
function NW.FishPanel(on, ctx)
  if on and ctx and ctx ~= F.ctx then F.ctx = ctx; F.sel = nil; F.offset = 0 end
  fp:SetShown(on)
  if on then F.Redraw() end
end

-- From Cooking, or a fish on a shopping list
function NW.OpenFishCook()
  st().fishTab = "combined"
  F.sel = nil
  NW.OpenProfession("fishing")
end
-- Fish open in the Material Finder (its Fish category, the fishing view)
function NW.OpenFishFinder(id)
  if id and NW.FindMaterials and NW.Mat and NW.Mat.Get(id) then
    NW.FindMaterials("fish", id, "fishing")
  elseif NW.FindMaterials then
    NW.FindMaterials("fish")
  end
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
