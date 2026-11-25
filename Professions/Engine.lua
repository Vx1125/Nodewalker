local ADDON, NW = ...
NW.charDB = { known = {}, recipeScan = {}, recipeScanAt = {} } -- replaced at login

------------------------------------------------------------------------
-- Profession leveling engine
--
-- Recipe data (orange/yellow/green/grey skill, reagents) + live prices
-- -> the cheapest way to each skill point -> a step-by-step plan with a
-- shopping list. Prices come from Auctionator when it has scanned, from
-- vendor prices seen at merchants, or from rough estimates.
------------------------------------------------------------------------
NW.RECIPES = {}

NW.PROFS = {
  { key = "alchemy",        name = "Alchemy",        kind = "craft",  icon = "Interface\\Icons\\Trade_Alchemy" },
  { key = "blacksmithing",  name = "Blacksmithing",  kind = "craft",  icon = "Interface\\Icons\\Trade_BlackSmithing" },
  { key = "enchanting",     name = "Enchanting",     kind = "craft",  icon = "Interface\\Icons\\Trade_Engraving" },
  { key = "engineering",    name = "Engineering",    kind = "craft",  icon = "Interface\\Icons\\Trade_Engineering" },
  { key = "leatherworking", name = "Leatherworking", kind = "craft",  icon = "Interface\\Icons\\INV_Misc_ArmorKit_17" },
  { key = "tailoring",      name = "Tailoring",      kind = "craft",  icon = "Interface\\Icons\\Trade_Tailoring" },
  { key = "cooking",        name = "Cooking",        kind = "craft",  icon = "Interface\\Icons\\INV_Misc_Food_15", secondary = true },
  { key = "firstaid",       name = "First Aid",      kind = "craft",  icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", secondary = true },
  { key = "herbalism",      name = "Herbalism",      kind = "gather", icon = "Interface\\Icons\\Trade_Herbalism" },
  { key = "mining",         name = "Mining",         kind = "gather", icon = "Interface\\Icons\\Trade_Mining" },
  { key = "skinning",       name = "Skinning",       kind = "gather", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
  { key = "fishing",        name = "Fishing",        kind = "gather", icon = "Interface\\Icons\\Trade_Fishing", secondary = true },
}
NW.PROF_BY_KEY, NW.PROF_BY_NAME = {}, {}
for _, p in ipairs(NW.PROFS) do NW.PROF_BY_KEY[p.key] = p; NW.PROF_BY_NAME[p.name] = p end

-- R(name, orange, yellow, green, grey, source, createdID, "id:n,id:n", yield)
function NW.RecipeAdder(key)
  NW.RECIPES[key] = NW.RECIPES[key] or {}
  local list = NW.RECIPES[key]
  return function(name, o, y, g, gr, src, id, reagents, yield)
    local r = { name = name, orange = o, yellow = y, green = g, grey = gr, src = src, yield = yield or 1, reagents = {} }
    if type(id) == "string" and id:sub(1, 1) == "s" then r.spell = tonumber(id:sub(2)) else r.item = id end
    for rid, n in reagents:gmatch("(%d+):(%d+)") do r.reagents[#r.reagents + 1] = { tonumber(rid), tonumber(n) } end
    list[#list + 1] = r
  end
end

-- The item that teaches a recipe (Pattern: ..., Plans: ...), by recipe name
function NW.RecipeItems(key, map)
  for _, r in ipairs(NW.RECIPES[key] or {}) do
    if map[r.name] then r.recipeItem = map[r.name] end
  end
end

-- The full recipe list (Professions/Catalog.lua). Recipes already in the
-- leveling data get what they lack; the rest are kept for the Recipes view.
NW.CATALOG, NW.RANK_FEE = {}, {}
function NW.CatalogAdder(key)
  NW.CATALOG[key] = {}
  local list, byName, byItem = NW.CATALOG[key], {}, {}
  for _, r in ipairs(NW.RECIPES[key] or {}) do
    byName[r.name] = r
    if r.item then byItem[r.item] = r end
  end
  return function(name, learn, y, g, gr, id, recipeItem, fee, where, reagents, yield)
    if where == "" then where = nil end
    local r = byName[name] or (type(id) == "number" and byItem[id]) or nil
    if r then
      r.fee, r.where = fee, where
      r.recipeItem = r.recipeItem or recipeItem
      return
    end
    local trainer = where and (where:find("^[TB]") ~= nil) or false
    -- learn can sit above yellow (taught late): the list shows when you can learn it
    local e = { name = name, orange = (learn > 0 and learn ~= y) and learn or nil, yellow = y, green = g, grey = gr, yield = yield or 1,
      reagents = {}, fee = fee, where = where, recipeItem = recipeItem, catalog = true, src = trainer and "trainer" or "recipe" }
    if type(id) == "string" then e.spell = tonumber(id:sub(2)) else e.item = id end
    for rid, n in reagents:gmatch("(%d+):(%d+)") do e.reagents[#e.reagents + 1] = { tonumber(rid), tonumber(n) } end
    list[#list + 1] = e
  end
end

-- Does this recipe name belong to a profession, going by the recipe lists?
-- true: yes; false: only to other professions; nil: not in the lists at all
local ownerOf
function NW.RecipeBelongs(name, key)
  if not ownerOf then
    ownerOf = {}
    for _, src in ipairs({ NW.RECIPES, NW.CATALOG }) do
      for k, list in pairs(src) do
        for _, r in ipairs(list) do
          ownerOf[r.name] = ownerOf[r.name] or {}
          ownerOf[r.name][k] = true
        end
      end
    end
  end
  local o = ownerOf[name]
  if not o then return nil end
  return o[key] or false
end

-- The same question asked of the game, by recipe ID: is this recipe filed
-- under this profession's skill line? nil when the game can't say.
local SKILL_LINE = { alchemy = 171, blacksmithing = 164, enchanting = 333, engineering = 202, leatherworking = 165,
  tailoring = 197, cooking = 185, firstaid = 129, mining = 186, herbalism = 182, skinning = 393, fishing = 356 }
local lineMemo = {}
function NW.RecipeLineIs(id, key, baseID, baseName)
  local T = C_TradeSkillUI
  if not (id and T and T.GetTradeSkillLineForRecipe) then return nil end
  local m = lineMemo[id]
  if not m then
    local ok, line, lineName, parent = pcall(T.GetTradeSkillLineForRecipe, id)
    if not ok or not line then return nil end
    m = { line, parent, lineName }
    lineMemo[id] = m
  end
  local want = SKILL_LINE[key]
  if want and (m[1] == want or m[2] == want) then return true end
  if baseID and (m[1] == baseID or m[2] == baseID) then return true end
  if baseName and m[3] == baseName then return true end
  -- only a clear "another profession's" counts as no
  for _, other in pairs(SKILL_LINE) do
    if m[1] == other or m[2] == other then return false end
  end
  return nil
end

-- Recipes never used for leveling: cooldowns (transmutes), camp objects, raid-only
NW.NO_LEVEL = {}
for _, n in ipairs({ "Gold Bar", "Truesilver Bar", "Essence of Fire", "Arcanite Bar", "Living Essence", "Essence of Water",
  "Essence of Earth", "Legionite Bar", "Essence of Air", "Essence of Undeath", "Alchemy Laboratory", "Elemental Fire",
  "Gurubashi Mojo Madness", "Refined Scale of Onyxia" }) do NW.NO_LEVEL[n] = true end

-- Training ranks: skill cap, and what you need to learn the next one
NW.RANKS = {
  { cap = 75,  name = "Apprentice" },
  { cap = 150, name = "Journeyman", skill = 50,  level = 10 },
  { cap = 225, name = "Expert",     skill = 125, level = 20 },
  { cap = 300, name = "Artisan",    skill = 200, level = 35 },
}

-- Where the higher ranks are taught, from the original game: { who or what, where }.
-- Journeyman is taught by any trainer.
-- What a rank's quest asks for: { item, count }
local CLAMLETTE = { { 12207, 12 }, { 7974, 10 }, { 8932, 20 } } -- Giant Egg, Zesty Clam Meat, Alterac Swiss
NW.RANK_WHERE = {
  alchemy = {
    Expert = { Horde = { "Doctor Herbert Halsey", "Undercity", 1458, 47.8, 73.3 }, Alliance = { "Ainethil", "Darnassus", 1457, 54.9, 24.0 } },
    Artisan = { Horde = { "Rogvar", "Stonard, Swamp of Sorrows", 1435, 48.5, 55.9 }, Alliance = { "Kylanna Windwhisper", "Feathermoon, Feralas", 1444, 32.6, 43.8 } },
  },
  blacksmithing = {
    Expert = { Horde = { "Saru Steelfury", "Orgrimmar", 1454, 82.4, 23.0 }, Alliance = { "Bengus Deepforge", "Ironforge", 1455, 52.6, 41.5 } },
    Artisan = { Horde = { "Brikk Keencraft", "Booty Bay, Stranglethorn Vale", 1434, 29.0, 75.6 }, Alliance = { "Brikk Keencraft", "Booty Bay, Stranglethorn Vale", 1434, 29.0, 75.6 } },
  },
  enchanting = {
    Expert = { Horde = { "Hgarth", "Sun Rock Retreat, Stonetalon Mountains", 1442, 49.2, 57.2 }, Alliance = { "Kitta Firewind", "Tower of Azora, Elwynn Forest", 1429, 64.9, 70.7 } },
    Artisan = { Horde = { "Annora", "inside Uldaman, Badlands", 1418, 44.6, 12.1 }, Alliance = { "Annora", "inside Uldaman, Badlands", 1418, 44.6, 12.1 } },
  },
  engineering = {
    Expert = { Horde = { "Roxxik", "Orgrimmar", 1454, 76.2, 25.2 }, Alliance = { "Springspindle Fizzlegear", "Ironforge", 1455, 68.5, 43.5 } },
    Artisan = { Horde = { "Buzzek Bracketswing", "Gadgetzan, Tanaris", 1446, 52.3, 27.7 }, Alliance = { "Buzzek Bracketswing", "Gadgetzan, Tanaris", 1446, 52.3, 27.7 } },
  },
  leatherworking = {
    Expert = { Horde = { "Una", "Thunder Bluff", 1456, 41.5, 42.6 }, Alliance = { "Telonis", "Darnassus", 1457, 64.4, 21.5 } },
    Artisan = { Horde = { "Hahrana Ironhide", "Camp Mojache, Feralas", 1444, 74.4, 43.0 }, Alliance = { "Drakk Stonehand", "Aerie Peak, The Hinterlands", 1425, 13.4, 43.5 } },
  },
  tailoring = {
    Expert = { Horde = { "Josef Gregorian", "Undercity", 1458, 70.8, 30.7 }, Alliance = { "Georgio Bolero", "Stormwind", 1453, 53.1, 81.4 } },
    Artisan = { Horde = { "Daryl Stack", "Tarren Mill, Hillsbrad Foothills", 1424, 63.8, 20.8 }, Alliance = { "Timothy Worthington", "Theramore, Dustwallow Marsh", 1445, 66.2, 51.8 } },
  },
  cooking = {
    Expert = { Horde = { "Expert Cookbook, sold by Wulan", "Shadowprey Village, Desolace", 1443, 26.2, 69.7 }, Alliance = { "Expert Cookbook, sold by Shandrina", "Mystral Lake, Ashenvale", 1440, 49.6, 67.0 } },
    Artisan = { Horde = { "Quest from Dirge Quikcleave", "Gadgetzan, Tanaris", 1446, 52.6, 28.1, CLAMLETTE }, Alliance = { "Quest from Dirge Quikcleave", "Gadgetzan, Tanaris", 1446, 52.6, 28.1, CLAMLETTE } },
  },
  firstaid = {
    Expert = { Horde = { "Expert First Aid book, sold by Balai Lok'Wein", "Brackenwall Village, Dustwallow Marsh", 1445, 36.5, 30.4 }, Alliance = { "Expert First Aid book, sold by Deneb Walker", "Stromgarde, Arathi Highlands", 1417, 27.0, 58.8 } },
    Artisan = { Horde = { "Quest from Doctor Gregory Victor", "Hammerfall, Arathi Highlands", 1417, 73.4, 36.9, nil, "Triage: save 15 patients. Nothing to bring." }, Alliance = { "Quest from Doctor Gustaf VanHowzen", "Theramore, Dustwallow Marsh", 1445, 67.8, 49.0, nil, "Triage: save 15 patients. Nothing to bring." } },
  },
}
-- Returns who and where for your faction
function NW.RankWhere(key, rankName)
  local w = NW.RANK_WHERE[key] and NW.RANK_WHERE[key][rankName]
  if not w then return end
  local e = w[UnitFactionGroup and UnitFactionGroup("player") or "Horde"] or w.Horde
  return e[1], e[2], e[3], e[4], e[5], e[6], e[7]
end

-- Pin a spot on the world map and track it. x, y are 0-100.
function NW.PinMap(mapID, x, y, label)
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  if ok and OpenWorldMap then pcall(OpenWorldMap, mapID) end
  if not ok then
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    NW.Print(("%s: %s %.1f, %.1f"):format(label or "Go to", info and info.name or "", x, y))
  end
  return ok
end

------------------------------------------------------------------------
-- Your skill in each profession
------------------------------------------------------------------------
local skillCache, skillAt = {}, -10
local function scanSkills()
  local out = {}
  if GetProfessions and GetProfessionInfo then
    local ok, a, b, c, d, e, f = pcall(GetProfessions)
    if ok then
      local list = { a, b, c, d, e, f }
      for i = 1, 6 do
        local idx = list[i]
        if idx then
          local name, _, rank, max = GetProfessionInfo(idx)
          if name then out[name] = { rank = rank, max = max } end
        end
      end
    end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(i)
      if name and not isHeader and NW.PROF_BY_NAME[name] then out[name] = { rank = rank, max = max } end
    end
  end
  return out
end

-- rank, max for a profession key, or nil if you don't have it
function NW.ProfSkill(key)
  local now = GetTime()
  if now - skillAt > 3 then skillCache, skillAt = scanSkills(), now end
  local p = NW.PROF_BY_KEY[key]
  local s = p and skillCache[p.name]
  if s then return s.rank, s.max end
end

------------------------------------------------------------------------
-- What you know, learned from the profession and trainer windows
------------------------------------------------------------------------
local function profKeyFromName(name)
  local p = name and NW.PROF_BY_NAME[name]
  return p and p.key
end

local function remember(profKey, recipeName)
  if not profKey or not recipeName then return end
  local known = NW.charDB.known
  known[profKey] = known[profKey] or {}
  known[profKey][recipeName] = true
end

local function learnItemLink(link)
  if type(link) ~= "string" then return end
  local id = tonumber(link:match("item:(%d+)"))
  local name = link:match("%[(.-)%]")
  if id and name then NW.db.itemIDs[name] = id end
end

-- Read the whole recipe list from the profession window (newer clients list
-- unlearned recipes too, with where they come from).
local function modernScan()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return false end
  -- someone else's profession (a link, the guild, an NPC): not yours
  for _, fn in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
    if T[fn] then
      local ok, v = pcall(T[fn])
      if ok and v then return true end
    end
  end
  local key, baseID, baseName
  if T.GetBaseProfessionInfo then
    local ok, info = pcall(T.GetBaseProfessionInfo)
    key = ok and info and profKeyFromName(info.professionName)
    if ok and info then baseID, baseName = info.professionID, info.professionName end
  end
  if not key and T.GetChildProfessionInfo then
    local ok, info = pcall(T.GetChildProfessionInfo)
    key = ok and info and (profKeyFromName(info.parentProfessionName) or profKeyFromName(info.professionName))
  end
  if not key and T.GetTradeSkillLine then
    local ok, _, name = pcall(T.GetTradeSkillLine)
    key = ok and profKeyFromName(name)
  end
  if not key then return false end
  NW.currentTradeKey = key
  local okIDs, ids = pcall(T.GetAllRecipeIDs)
  if not okIDs or not ids or #ids == 0 then return true end
  local scan = {}
  NW.charDB.known[key] = {} -- the full list is the truth: rebuild what you know
  local catNames, catOrder = {}, {}
  -- The game can hand back every profession's recipes: keep this one's
  local function mine(id, name)
    local belongs = NW.RecipeBelongs(name, key)
    if belongs ~= nil then return belongs end
    local byLine = NW.RecipeLineIs(id, key, baseID, baseName)
    if byLine ~= nil then return byLine end
    return true
  end
  for _, id in ipairs(ids) do
    local ok, info = pcall(T.GetRecipeInfo, id)
    if ok and info and info.name and not info.isDummyRecipe and not info.isRecraft and mine(id, info.name) then
      local e = { id = id, icon = info.icon, learned = info.learned and true or false, diff = info.relativeDifficulty }
      if info.categoryID and T.GetCategoryInfo then
        local cname = catNames[info.categoryID]
        if cname == nil then
          local okc, cat = pcall(T.GetCategoryInfo, info.categoryID)
          cname = okc and cat and cat.name or false
          catNames[info.categoryID] = cname
          if cname and okc and cat.uiOrder then catOrder[cname] = cat.uiOrder end
        end
        e.cat = cname or nil
        e.catOrder = cname and catOrder[cname] or nil
      end
      if T.GetRecipeSchematic then
        local oks, sch = pcall(T.GetRecipeSchematic, id, false)
        if oks and sch then
          e.item = sch.outputItemID
          e.yield = sch.quantityMin
          e.reagents = {}
          for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
            local r = slot.reagents and slot.reagents[1]
            if r and r.itemID and (slot.reagentType == nil or slot.reagentType == 1) then
              e.reagents[#e.reagents + 1] = { r.itemID, slot.quantityRequired or 1 }
            end
          end
        end
      end
      if not e.learned and T.GetRecipeSourceText then
        local okt, text = pcall(T.GetRecipeSourceText, id)
        if okt and type(text) == "string" and text ~= "" then e.source = text end
      end
      if e.learned then remember(key, info.name) end
      scan[info.name] = e
    end
  end
  NW.charDB.recipeScan[key] = scan
  NW.charDB.recipeScanAt[key] = time()
  return true
end

local lastScan = 0
local function scanTradeSkill()
  if not NW.db then return end
  if GetTime() - lastScan < 2 then return end
  lastScan = GetTime()
  if modernScan() then return end
  -- Classic-style API: only the recipes you know
  if GetTradeSkillLine and GetNumTradeSkills then
    if IsTradeSkillLinked and IsTradeSkillLinked() then return end
    local ok, line = pcall(GetTradeSkillLine)
    local key = ok and profKeyFromName(line)
    if key then
      NW.currentTradeKey = key
      for i = 1, GetNumTradeSkills() do
        local name, kind = GetTradeSkillInfo(i)
        if name and kind ~= "header" and kind ~= "subheader" then
          remember(key, name)
          if GetTradeSkillReagentItemLink and GetTradeSkillNumReagents then
            for j = 1, (GetTradeSkillNumReagents(i) or 0) do learnItemLink(GetTradeSkillReagentItemLink(i, j)) end
          end
        end
      end
    end
  end
end

-- Enchanting used its own "craft" window in the original game
local function scanCraft()
  if not (NW.db and GetCraftDisplaySkillLine and GetNumCrafts) then return end
  local ok, line = pcall(GetCraftDisplaySkillLine)
  local key = ok and profKeyFromName(line)
  if not key then return end
  NW.currentTradeKey = key
  for i = 1, GetNumCrafts() do
    local name, _, kind = GetCraftInfo(i)
    if name and kind ~= "header" then remember(key, name) end
  end
end

-- Trainer: the real skill each recipe needs, for recipes the data leaves open
local function scanTrainer()
  if not (NW.db and GetNumTrainerServices and GetTrainerServiceSkillReq) then return end
  for i = 1, GetNumTrainerServices() do
    local name = GetTrainerServiceInfo(i)
    local skillName, rank = GetTrainerServiceSkillReq(i)
    local key = profKeyFromName(skillName)
    if key and name and rank then
      NW.db.trainerReq[key] = NW.db.trainerReq[key] or {}
      NW.db.trainerReq[key][name] = rank
    end
  end
  NW.InvalidatePlans()
end

-- Merchant: vendor prices for reagents
local function scanMerchant()
  if not (NW.db and GetMerchantNumItems and GetMerchantItemLink) then return end
  for i = 1, GetMerchantNumItems() do
    local link = GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    local price, quantity, numAvailable, extendedCost = NW.MerchantItem(i)
    if id and price and price > 0 and not extendedCost and (numAvailable == -1) then
      NW.db.vendorPrices[id] = math.floor(price / math.max(1, quantity or 1))
      learnItemLink(link)
    end
  end
  NW.InvalidatePlans()
end

NW.On("TRADE_SKILL_SHOW", function() C_Timer.After(0.5, scanTradeSkill) end)
NW.On("TRADE_SKILL_UPDATE", function() scanTradeSkill(); NW.InvalidatePlans() end)
NW.On("TRADE_SKILL_LIST_UPDATE", function() scanTradeSkill(); NW.InvalidatePlans() end)
NW.On("TRADE_SKILL_DATA_SOURCE_CHANGED", function() C_Timer.After(0.5, scanTradeSkill) end)
NW.On("NEW_RECIPE_LEARNED", function() C_Timer.After(0.5, scanTradeSkill); NW.InvalidatePlans() end)
NW.On("CRAFT_SHOW", function() C_Timer.After(0.5, scanCraft) end)
NW.On("CRAFT_UPDATE", function() scanCraft(); NW.InvalidatePlans() end)
NW.On("TRAINER_SHOW", function() C_Timer.After(0.5, scanTrainer) end)
NW.On("MERCHANT_SHOW", function() C_Timer.After(0.5, scanMerchant) end)
NW.On("SKILL_LINES_CHANGED", function() skillAt = -10; NW.InvalidatePlans() end)

table.insert(NW.OnLoad, function()
  local db = NW.db
  -- recipes you know are kept per character
  db.chars = db.chars or {}
  local ck = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
  local c = db.chars[ck]
  if not c then
    c = {}
    db.chars[ck] = c
  end
  -- saved before they were per character: the first character to log in keeps them
  if db.known and not c.known then c.known, c.recipeScan, c.recipeScanAt = db.known, db.recipeScan, db.recipeScanAt end
  db.known, db.recipeScan, db.recipeScanAt = nil, nil, nil
  c.known = c.known or {}
  c.recipeScan = c.recipeScan or {}
  c.recipeScanAt = c.recipeScanAt or {}
  NW.charDB = c
  db.trainerReq = db.trainerReq or {}
  db.vendorPrices = db.vendorPrices or {}
  db.itemIDs = db.itemIDs or {}
  local s = db.settings
  if s.planRecipeItems == nil then s.planRecipeItems = false end
  if s.planUseBags == nil then s.planUseBags = true end
  if s.planSellBack == nil then s.planSellBack = false end
  if s.planOwnMats == nil then s.planOwnMats = false end
  -- Auctionator tells us when it has new prices
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.RegisterForDBUpdate then
    pcall(api.RegisterForDBUpdate, ADDON, function() NW.InvalidatePlans() end)
  end
end)

------------------------------------------------------------------------
-- Prices
------------------------------------------------------------------------
-- Rough vendor prices (copper) until you visit a merchant that sells them
local VENDOR = {
  [3371] = 20, [3372] = 200, [8925] = 2500, [18256] = 20000,          -- vials
  [2320] = 10, [2321] = 100, [4291] = 500, [8343] = 2000, [14341] = 5000, -- thread
  [2880] = 100, [3466] = 2000, [3857] = 500, [18567] = 30000,         -- flux, coal
  [4289] = 50,                                                         -- salt (Refined Deeprock Salt is a 3-day cooldown, not sold)
  [2678] = 10, [2692] = 40, [3713] = 160, [159] = 25, [1179] = 125,   -- spices, drinks
  [4470] = 38, [11291] = 4500, [6217] = 124, [10940] = nil,           -- wood, copper rod
  [2324] = 25, [2604] = 50, [6260] = 50, [2605] = 100, [4340] = 350,  -- bleach, dyes
  [6261] = 1000, [2325] = 1000, [4342] = 2500, [10290] = 2500,
  [3182] = nil, [4399] = 200, [4400] = 2000, [10647] = 2000, [10648] = 500, -- wood stock, engineering
  [6530] = 100, [2894] = 50, [4536] = 25, [17194] = 10, [17196] = 50, -- misc cooking
}
NW.VENDOR_PRICES = VENDOR

-- Today's lowest listing, as Auctionator last saw it
local function latest(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local ok, price = pcall(api.GetAuctionPriceByItemID, ADDON, id)
  if ok and type(price) == "number" and price > 0 then return price end
end

local function median(t)
  table.sort(t)
  local n = #t
  if n == 0 then return nil end
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end

-- What Auctionator has seen of an item over the last two weeks of scans:
-- { today, typical, low, high, days, listed, flag }
--   typical: the middle of each day's lowest price
--   listed:  how many are usually up
--   flag:    "low" or "high" when today's price is far from typical
-- nil without Auctionator or any price.
local statsMemo = {}
local HISTORY_DAYS, OUTLIER = 14, 0.6
function NW.PriceStats(id)
  local memo = statsMemo[id]
  if memo ~= nil then return memo or nil end
  local today = latest(id)
  local st = false
  if today then
    st = { today = today, typical = today, low = today, high = today, days = 0 }
    local db = Auctionator and Auctionator.Database
    local ok, hist
    if db and db.GetPriceHistory then ok, hist = pcall(db.GetPriceHistory, db, tostring(id)) end
    if ok and type(hist) == "table" and #hist > 0 then
      local newest = tonumber(hist[1].rawDay) or 0
      local lows, counts = {}, {}
      for _, d in ipairs(hist) do
        local day = tonumber(d.rawDay) or 0
        if newest - day < HISTORY_DAYS and d.minSeen then
          lows[#lows + 1] = d.minSeen
          if d.minSeen < st.low then st.low = d.minSeen end
          if (d.maxSeen or d.minSeen) > st.high then st.high = d.maxSeen or d.minSeen end
          if d.available then counts[#counts + 1] = d.available end
        end
      end
      st.days = #lows
      st.typical = median(lows) or today
      st.listed = median(counts)
      -- how many are up today, at any price
      if tonumber(hist[1].rawDay) == newest then st.listedToday = hist[1].available end
      -- Three days of scans is enough to call today's price odd. A low price
      -- can be one stray listing under a normal market. A high one is the
      -- cheapest of everything listed, so with plenty up it's the real price:
      -- the market has moved.
      if st.days >= 3 then
        local plenty = st.listedToday and st.listedToday >= math.max(5, (st.listed or 0) * 0.25)
        if today < st.typical * OUTLIER then st.flag = "low"
        elseif today * OUTLIER > st.typical and not plenty then st.flag = "high" end
      end
    end
  end
  statsMemo[id] = st
  return st or nil
end

-- The auction price to plan with: today's, unless today is a stray listing
-- far from what the item usually goes for
local function auctionator(id)
  local st = NW.PriceStats(id)
  if not st then return nil end
  return st.flag and st.typical or st.today
end

-- Not obtainable yet: these recipes come from Zandalar Tribe reputation, and
-- Zul'Gurub isn't open. Empty this table when it is.
NW.NOT_YET = {
  [20007] = true, -- Mageblood Elixir
  [20004] = true, -- Major Troll's Blood Elixir
  [20002] = true, -- Greater Dreamless Sleep Potion
  [20008] = true, -- Living Action Potion
  [20748] = true, -- Brilliant Mana Oil
  [20749] = true, -- Brilliant Wizard Oil
  [18253] = true, -- Major Rejuvenation Potion (recipe drops in Molten Core)
  [18262] = true, -- Elemental Sharpening Stone (recipe drops in Molten Core)
}
local NOT_YET_NAME = {
  ["Mageblood Elixir"] = true, ["Major Troll's Blood Elixir"] = true, ["Greater Dreamless Sleep Potion"] = true,
  ["Living Action Potion"] = true, ["Brilliant Mana Oil"] = true, ["Brilliant Wizard Oil"] = true,
}
-- Raids that aren't open on Forever yet: recipes that only drop there, and
-- recipes that need what only drops there. Take a line out when one opens.
local CLOSED_PLACES = { "Rin'wosho", "Zul'Gurub", "Ahn'Qiraj", "Molten Core", "Naxxramas" }
local CLOSED_MATS = {
  [17010] = true, -- Fiery Core (Molten Core)
  [17011] = true, -- Lava Core (Molten Core)
  [17012] = true, -- Core Leather (Molten Core)
  [17203] = true, -- Sulfuron Ingot (Molten Core)
  [22682] = true, -- Frozen Rune (Naxxramas)
}
-- A recipe nobody can learn, or make, yet
function NW.NotYet(r)
  if (r.item and NW.NOT_YET[r.item]) or NOT_YET_NAME[r.name] then return true end
  local w = r.where
  if w then
    for _, place in ipairs(CLOSED_PLACES) do
      if w:find(place, 1, true) then return true end
    end
  end
  for _, re in ipairs(r.reagents or {}) do
    if CLOSED_MATS[re[1]] then return true end
  end
  return false
end

-- Recipes on a long cooldown can't be made in bulk, so they never count as
-- "cheaper to make" (transmutes, Mooncloth)
local function onCooldown(r)
  return r.name:find("^Transmute") ~= nil or r.name == "Mooncloth"
end
NW.RecipeOnCooldown = onCooldown

-- The recipe that makes an item, in any profession: recipe, profession key
local makerOf
function NW.RecipeFor(itemID)
  if not makerOf then
    makerOf = {}
    for _, src in ipairs({ NW.RECIPES, NW.CATALOG }) do
      for key, list in pairs(src) do
        for _, r in ipairs(list) do
          if r.item and not makerOf[r.item] then makerOf[r.item] = { r, key } end
        end
      end
    end
  end
  local m = makerOf[itemID]
  if m then return m[1], m[2] end
end

-- Every price Nodewalker has for an item: vendor, auction, and what it costs
-- to make (each, from its recipe's materials). Any of them can be nil.
function NW.PriceParts(itemID)
  local vendor = NW.db.vendorPrices[itemID] or VENDOR[itemID]
  local ah = auctionator(itemID)
  local craft
  local r = NW.RecipeFor(itemID)
  if r and not onCooldown(r) then
    local cost, ok = 0, true
    for _, re in ipairs(r.reagents) do
      local p, src = NW.Price(re[1])
      if p and src ~= "est" then cost = cost + p * re[2] else ok = false break end
    end
    if ok and #r.reagents > 0 then craft = cost / (r.yield or 1) end
  end
  return vendor, ah, craft
end

-- What one craft earns: the auction price of what it makes, less the 5% cut,
-- minus its materials at today's prices. Returns profit, cost, sale and
-- whether a material had no real price. profit is nil with no sale price.
function NW.RecipeProfit(r)
  if not r.item then return nil end
  local cost, unknown = 0, false
  for _, re in ipairs(r.reagents) do
    local p, src = NW.Price(re[1])
    if p and src ~= "est" then cost = cost + p * re[2] else unknown = true end
  end
  local value = auctionator(r.item)
  local sale = value and value * (r.yield or 1) * 0.95
  -- gear nobody buys is still worth its dust: take whichever pays more
  local de = NW.DisenchantValue(r.item)
  de = de and de * (r.yield or 1) * 0.95
  if de and (not sale or de > sale) then return de - cost, cost, de, unknown, true end
  if not sale then return nil, cost, nil, unknown end
  return sale - cost, cost, sale, unknown
end

function NW.HasAuctionator()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  return api and api.GetAuctionPriceByItemID and true or false
end

-- Days since Auctionator last saw an item, or nil
function NW.PriceAge(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionAgeByItemID) then return nil end
  local ok, age = pcall(api.GetAuctionAgeByItemID, ADDON, id)
  if ok then return age end
end

-- What an item costs to buy outright (vendor or auction), or nil
function NW.BuyPrice(id)
  local v = NW.db.vendorPrices[id] or VENDOR[id]
  local ah = auctionator(id)
  if v and ah then return math.min(v, ah) end
  return v or ah
end

-- Price of one item: copper, source ("ah" | "vendor" | "craft" | "est" | nil)
local priceMemo = {}
local craftOf -- [itemID] = recipe that makes it (built per profession)
function NW.Price(id, depth)
  local memo = priceMemo[id]
  if memo then return memo[1], memo[2] end
  local best, src
  local v = NW.db.vendorPrices[id] or VENDOR[id]
  if v then best, src = v, "vendor" end
  local ah = auctionator(id)
  if ah and (not best or ah < best) then best, src = ah, "ah" end
  -- something you can make yourself (bolts, bars, tubes...)
  local r = craftOf and craftOf[id]
  if r and (depth or 0) < 3 then
    local cost, unknown = 0, false
    for _, re in ipairs(r.reagents) do
      -- Made from materials you can buy, one step down and no further,
      -- whether or not the item itself has a price. Otherwise a chain like
      -- Light > Medium > Heavy > Thick Leather turns one piece into 120.
      local p = NW.BuyPrice(re[1])
      if not p then unknown = true break end
      cost = cost + p * re[2]
    end
    if not unknown then
      cost = cost / (r.yield or 1)
      if not best or cost < best * 0.75 then best, src = cost, "craft" end
    end
  end
  if not best then
    local sell = select(11, NW.ItemInfo(id))
    if sell and sell > 0 then best, src = sell * 4, "est" end
  end
  if best then priceMemo[id] = { best, src } else NW.missingPrice = true end
  return best, src
end

------------------------------------------------------------------------
-- Planning
------------------------------------------------------------------------
local planCache = {}
-- item info arrives a moment after it's asked for: re-price once it has
local repricing
NW.On("GET_ITEM_INFO_RECEIVED", function()
  if not NW.missingPrice or repricing then return end
  repricing = true
  C_Timer.After(1, function()
    repricing, NW.missingPrice = false, false
    NW.InvalidatePlans()
  end)
end)

function NW.InvalidatePlans()
  planCache = {}
  priceMemo = {}
  statsMemo = {}
  if NW.RefreshProfessions then NW.RefreshProfessions() end
end

-- Chance one craft gives a skill point at skill s
function NW.SkillUpChance(r, s)
  if s < r.yellow then return 1 end
  if s >= r.grey then return 0 end
  return (r.grey - s) / (r.grey - r.yellow)
end

-- Skill needed to learn/use a recipe
local function required(key, r)
  local t = NW.db.trainerReq[key]
  if t and t[r.name] then return t[r.name] end
  if r.orange then return r.orange end
  -- trainer recipes with no orange range are learned when they turn yellow
  return r.yellow
end

local function isKnown(key, r)
  local k = NW.charDB.known[key]
  return k and k[r.name] or false
end

-- Disenchanting: what an item breaks into, by quality and item level.
-- Each row: top item level, then { item, chance, average count } outcomes.
local DUST = { 10940, 11083, 11137, 11176, 16204 }
local DE_GREEN = { -- armour; weapons swap the dust and essence chances
  { 15, { 10940, 0.80, 1.5 }, { 10938, 0.20, 1.5 } },
  { 20, { 10940, 0.75, 2.5 }, { 10939, 0.20, 1.5 }, { 10978, 0.05, 1 } },
  { 25, { 10940, 0.75, 5 }, { 10998, 0.15, 1.5 }, { 10978, 0.10, 1 } },
  { 30, { 11083, 0.75, 1.5 }, { 11082, 0.20, 1.5 }, { 11084, 0.05, 1 } },
  { 35, { 11083, 0.75, 3.5 }, { 11134, 0.20, 1.5 }, { 11138, 0.05, 1 } },
  { 40, { 11137, 0.75, 1.5 }, { 11135, 0.20, 1.5 }, { 11139, 0.05, 1 } },
  { 45, { 11137, 0.75, 3.5 }, { 11174, 0.20, 1.5 }, { 11177, 0.05, 1 } },
  { 50, { 11176, 0.75, 1.5 }, { 11175, 0.20, 1.5 }, { 11178, 0.05, 1 } },
  { 55, { 11176, 0.75, 3.5 }, { 16202, 0.20, 1.5 }, { 14343, 0.05, 1 } },
  { 60, { 16204, 0.75, 1.5 }, { 16203, 0.20, 1.5 }, { 14344, 0.05, 1 } },
  { 999, { 16204, 0.75, 3.5 }, { 16203, 0.20, 2.5 }, { 14344, 0.05, 1 } },
}
local DE_BLUE = { { 25, 10978 }, { 30, 11084 }, { 35, 11138 }, { 40, 11139 }, { 45, 11177 }, { 50, 11178 }, { 55, 14343 }, { 999, 14344 } }
local DE_EPIC = { { 45, 11177, 3 }, { 50, 11178, 3 }, { 55, 14343, 3 }, { 60, 20725, 1 }, { 999, 20725, 1.5 } }
local isDust = {}
for _, id in ipairs(DUST) do isDust[id] = true end

-- What an item is worth disenchanted, at today's prices; nil if it can't be
-- (or the game hasn't sent the item yet). Also returns the outcomes used.
function NW.DisenchantValue(itemID)
  if type(itemID) ~= "number" then return nil end
  -- Auctionator's own disenchant figure, when it has one for this client
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetDisenchantPriceByItemID then
    local ok, v = pcall(api.GetDisenchantPriceByItemID, ADDON, itemID)
    if ok and type(v) == "number" and v > 0 then return v end
  end
  local _, _, quality, ilvl, _, _, _, _, _, _, _, classID = NW.ItemInfo(itemID)
  if not quality then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return nil
  end
  if (classID ~= 2 and classID ~= 4) or quality < 2 or quality > 4 or not ilvl or ilvl < 5 then return nil end
  local outcomes
  if quality == 2 then
    for _, row in ipairs(DE_GREEN) do
      if ilvl <= row[1] then
        outcomes = {}
        for i = 2, #row do
          local o = row[i]
          local chance = o[2]
          -- weapons: mostly essence, sometimes dust
          if classID == 2 and chance ~= 0.05 and chance ~= 0.10 then chance = isDust[o[1]] and 0.20 or (1 - 0.20 - (row[4] and row[4][2] or 0)) end
          outcomes[#outcomes + 1] = { o[1], chance * o[3] }
        end
        break
      end
    end
  else
    for _, row in ipairs(quality == 3 and DE_BLUE or DE_EPIC) do
      if ilvl <= row[1] then outcomes = { { row[2], row[3] or 1 } } break end
    end
  end
  if not outcomes then return nil end
  local value = 0
  for _, o in ipairs(outcomes) do
    local p = auctionator(o[1])
    if not p then return nil, outcomes end
    value = value + p * o[2]
  end
  return value, outcomes
end

-- How much one craft costs, after anything you choose to count as free
local function craftCost(r, s)
  local cost, unknown = 0, 0
  local guess = 0
  for _, re in ipairs(r.reagents) do
    local p, src = NW.Price(re[1])
    if p then
      cost = cost + p * re[2]
      if src == "est" then guess = guess + p * re[2] * 0.5 end
    else
      unknown = unknown + 1
    end
  end
  r.guessExtra = guess -- planning leans away from guessed prices a little
  r.matCost = cost -- what the materials really cost, before any sale value
  if s.planSellBack == "de" and r.item then
    -- what it breaks into is worth nearly what it lists for; dust always sells
    local value = NW.DisenchantValue(r.item)
    if value then cost = math.max(cost * 0.1, cost - value * 0.95 * (r.yield or 1)) end
  elseif s.planSellBack and r.item then
    local value = auctionator(r.item)
    -- half: not everything sells. A craft never counts as cheaper than a fifth
    -- of its materials, or the plan would mass-produce whatever lists highest.
    if value then cost = math.max(cost * 0.2, cost - value * 0.95 * (r.yield or 1) * 0.5) end
  end
  return math.max(cost, 0), unknown
end

-- The skill caps where you must train the next rank before going on
local RANK_AT = {}
for _, r in ipairs(NW.RANKS) do if r.skill then RANK_AT[r.cap - 75] = r end end

-- Build the plan from skill `from` to `to`.
-- Returns { steps = {...}, total, unknown, gaps }
function NW.BuildPlan(key, from, to)
  local s = NW.db.settings
  local cacheKey = ("%s:%d:%d:%s%s"):format(key, from, to, s.planRecipeItems and "r" or "", s.planSellBack == "de" and "d" or s.planSellBack and "s" or "")
  if planCache[cacheKey] then return planCache[cacheKey] end

  local recipes = NW.RECIPES[key] or {}
  local _, maxSkill = NW.ProfSkill(key)
  if NW.craftKey ~= key then priceMemo = {}; NW.craftKey = key end
  craftOf = {}
  for _, r in ipairs(recipes) do if r.item and not craftOf[r.item] and not onCooldown(r) then craftOf[r.item] = r end end

  local costOf, unknownOf = {}, {}
  for i, r in ipairs(recipes) do costOf[i], unknownOf[i] = craftCost(r, s) end

  -- What it costs once to get a recipe you don't know: the recipe item, or
  -- the trainer's fee. Spread over the points it would be used for, so the
  -- plan doesn't buy a recipe for a handful of skill-ups.
  local onceOf, buyOf = {}, {} -- buyOf: a recipe item with a real price
  for i, r in ipairs(recipes) do
    if isKnown(key, r) then
      onceOf[i] = 0
    elseif NW.NotYet(r) then
      onceOf[i] = 1e9 -- can't be learned yet
    elseif r.src == "trainer" or r.src == "rank" then
      onceOf[i] = r.fee or 0
    else
      local price, src = nil, nil
      if r.recipeItem then price, src = NW.Price(r.recipeItem) end
      onceOf[i] = (price and (src == "ah" or src == "vendor")) and price or 10000 -- unpriced: assume about 1g
      if price and (src == "ah" or src == "vendor") then buyOf[i] = price end
    end
  end
  local owned = {}

  -- pick the cheapest recipe for each skill point
  local pick = {}
  local gaps = 0
  for sk = from, to - 1 do
    local best, bestCost, bestNeeds
    for pass = 1, 2 do
      for i, r in ipairs(recipes) do
        local avail = r.src == "rank" or r.src == "trainer" or isKnown(key, r)
        if NW.NO_LEVEL[r.name] then avail = nil end
        local needsRecipe = not avail
        if avail ~= nil and (avail or pass == 2 or s.planRecipeItems) and required(key, r) <= sk then
          local p = NW.SkillUpChance(r, sk)
          if p > 0 then
            -- unknown prices count as expensive so priced options win
            local c = (costOf[i] + (r.guessExtra or 0) + unknownOf[i] * 10000) / p
            if needsRecipe then c = c * 1.15 end -- slight nudge toward what you can learn now
            if not owned[i] and onceOf[i] > 0 then
              c = c + onceOf[i] / math.max(1, math.min(r.green, to) - sk)
            end
            if not best or c < bestCost then best, bestCost, bestNeeds = i, c, needsRecipe end
          end
        end
      end
      if best then break end
    end
    if best then owned[best] = true end
    pick[sk] = best and { i = best, needs = bestNeeds } or false
    if not best then gaps = gaps + 1 end
  end

  -- group runs of the same recipe into steps
  local steps, total, unknownTotal = {}, 0, 0
  local cur
  for sk = from, to - 1 do
    local pk = pick[sk]
    local idx = pk and pk.i or nil
    local rankUp = RANK_AT[sk]
    if rankUp and maxSkill and maxSkill >= rankUp.cap then rankUp = nil end -- already trained
    if not cur or cur.idx ~= idx or rankUp then
      cur = { idx = idx, from = sk, to = sk + 1, crafts = 0, var = 0, recipe = idx and recipes[idx], needsRecipe = pk and pk.needs, rankUp = rankUp }
      steps[#steps + 1] = cur
    else
      cur.to = sk + 1
    end
    if idx then
      local p = NW.SkillUpChance(recipes[idx], sk)
      cur.crafts = cur.crafts + 1 / p
      cur.var = cur.var + (1 - p) / (p * p) -- luck: how much the crafts needed can vary
    end
  end
  local fees, paid, spend = 0, {}, 0
  local rankFee = NW.RANK_FEE[key] or {}
  for _, st in ipairs(steps) do
    if st.recipe then
      st.crafts = math.ceil(st.crafts - 0.05)
      -- a few spare crafts, enough for about 4 runs in 5; none while it's orange
      st.spare = st.var > 0 and math.ceil(0.85 * math.sqrt(st.var)) or 0
      st.crafts = st.crafts + st.spare
      st.costEach, st.unknown = costOf[st.idx], unknownOf[st.idx]
      st.cost = st.costEach * st.crafts
      -- what the trainer charges: the recipe (once) and the next rank
      local r = st.recipe
      if r.fee and r.src == "trainer" and not paid[r.name] and not isKnown(key, r) then
        paid[r.name] = true
        st.fee = r.fee
      end
      if st.rankUp then st.rankFee = rankFee[st.rankUp.name] end
      st.train = (st.fee or 0) + (st.rankFee or 0)
      st.cost = st.cost + st.train
      -- what you pay; st.cost is that minus the sale value you chose to count
      -- a recipe you have to buy is paid for once, the first time it's used
      local recipeCost = 0
      if buyOf[st.idx] and not paid[r.name] then
        paid[r.name] = true
        recipeCost = buyOf[st.idx]
        st.cost = st.cost + recipeCost
      end
      st.spend = (r.matCost or st.costEach) * st.crafts + st.train + recipeCost
      spend = spend + st.spend
      fees = fees + st.train
      total = total + st.cost
      if st.unknown > 0 then unknownTotal = unknownTotal + 1 end
      st.mats = {}
      for _, re in ipairs(st.recipe.reagents) do st.mats[#st.mats + 1] = { re[1], re[2] * st.crafts } end
    end
  end
  local plan = { steps = steps, total = total, spend = spend, fees = fees, unknown = unknownTotal, gaps = gaps, from = from, to = to }
  planCache[cacheKey] = plan
  return plan
end

-- Everything to buy for a plan. Things you can make cheaper than buy are
-- broken down into what they're made from. Counts what's in your bags.
function NW.ShoppingList(key, plan)
  local need = {}
  local function add(id, n, depth, leaf)
    local r = craftOf and craftOf[id]
    local price, src = NW.Price(id)
    if r and src == "craft" and depth < 3 and not leaf then
      local crafts = math.ceil(n / (r.yield or 1))
      -- one step down, never a whole chain
      for _, re in ipairs(r.reagents) do add(re[1], re[2] * crafts, depth + 1, true) end
    else
      need[id] = (need[id] or 0) + n
    end
  end
  NW.BuildPlan(key, plan.from, plan.to) -- makes sure craftOf is this profession's
  local forQuest = {}
  for _, st in ipairs(plan.steps) do
    for _, m in ipairs(st.mats or {}) do add(m[1], m[2], 0) end
    -- what the next rank's quest asks for
    if st.rankUp then
      local _, _, _, _, _, needs = NW.RankWhere(key, st.rankUp.name)
      for _, it in ipairs(needs or {}) do
        need[it[1]] = (need[it[1]] or 0) + it[2]
        forQuest[it[1]] = st.rankUp.name
      end
    end
  end
  local list, total = {}, 0
  local useBags = NW.db.settings.planUseBags
  for id, n in pairs(need) do
    local have = useBags and NW.ItemCount(id) or 0
    local buy = math.max(0, n - have)
    local price, src = NW.Price(id)
    local cost = price and price * buy or nil
    if cost then total = total + cost end
    local e = { id = id, need = n, have = have, buy = buy, price = price, src = src, cost = cost, quest = forQuest[id] }
    -- priced from the listings you just searched, when there are any
    if src == "ah" and buy > 0 then
      local fill, got, complete, seen = NW.FillCost(id, buy)
      if fill and got > 0 then
        e.live = { cost = fill, got = got, complete = complete, seen = seen }
        local rest = (buy - got) * (price or 0)
        if cost then total = total - cost end
        e.cost = fill + rest
        total = total + e.cost
      end
    end
    if src == "ah" then
      local ps = NW.PriceStats(id)
      if ps then
        e.stats = ps
        -- more than the auction house usually holds: the price won't last
        if ps.listed and buy > ps.listed then e.scarce = true end
        -- the listings themselves say whether there's enough
        if e.live then e.scarce = e.live.complete and e.live.got < buy or false end
      end
    end
    list[#list + 1] = e
  end
  table.sort(list, function(a, b) return (a.cost or -1) > (b.cost or -1) end)
  return list, total
end

-- Money text: 12g 34s 56c, shortened for big numbers
function NW.Money(c, short)
  if not c then return "?" end
  c = math.floor(c + 0.5)
  local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  -- the game's own coins, sized to the text
  local G, S, Cc = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t",
    "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"
  if g > 0 then
    -- "mid": short, but keeps the silver while it still matters
    if short == "mid" and g < 10 and s > 0 then return ("%d%s %d%s"):format(g, G, s, S) end
    if short or g >= 100 then return ("%d%s"):format(g, G) end
    return ("%d%s %d%s"):format(g, G, s, S)
  end
  if s > 0 then return short and ("%d%s"):format(s, S) or ("%d%s %d%s"):format(s, S, cp, Cc) end
  return ("%d%s"):format(cp, Cc)
end

-- Things the plan can't know: tools, rank books, left-out recipes
NW.PROF_TIPS = {
  alchemy = "Vials: trade supply vendors. Healing Potions are First Aid in Forever; Alchemy keeps the Discolored ones.",
  blacksmithing = "Blacksmith Hammer: trade supply vendors. Weaponsmith and Armorsmith recipes are left out. From about 260 only bought plans give skill-ups: tick \"Allow recipes I must buy\".",
  enchanting = "Make rods as you go: Runed Copper, Silver (130), Golden (175), Truesilver (220). Artisan: Annora, Uldaman.",
  engineering = "Make an Arclight Spanner and buy a Blacksmith Hammer first. Gnomish, Goblin and firework recipes are left out.",
  leatherworking = "Salt: trade supply vendors. Refined Deeprock Salt is a Salt Shaker cooldown. Dragonscale, Elemental and Tribal recipes are left out. From about 250 most skill-ups come from bought patterns.",
  tailoring = "Thread and dyes: trade supply vendors. Mooncloth is on a cooldown, so the plan skips it. From about 250, bought patterns are much cheaper.",
  cooking = "Expert: the Expert Cookbook, at 125. Most good recipes are sold by vendors: tick \"Allow recipes I must buy\".",
  firstaid = "Expert: a book, at 125. Heavy Silk and Mageweave Bandages need manuals. Artisan: the Triage quest.",
}

------------------------------------------------------------------------
-- Crafting from Nodewalker. The profession has to be open (the game shows
-- its own window for that), and every batch takes a click of yours.
------------------------------------------------------------------------
local function bagCount(id)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
  if GetItemCount then return GetItemCount(id) or 0 end
  return 0
end

-- The game's ID for a recipe you know, from the last look at the profession
local function knownRecipe(key, r)
  local scan = NW.charDB and NW.charDB.recipeScan[key]
  local e = scan and scan[r.name]
  if e and e.learned and e.id then return e end
end

-- How many you could make right now from your bags; nil if you can't craft
-- it from here (not known, or the profession was never opened)
function NW.CanCraft(key, r)
  if not (r and r.reagents and NW.ProfSkill(key)) then return nil end
  if not knownRecipe(key, r) then return nil end
  local n
  for _, re in ipairs(r.reagents) do
    local can = math.floor(bagCount(re[1]) / re[2])
    n = n and math.min(n, can) or can
  end
  return n or 0
end

-- What your bags are short of for one craft: itemID, how many more
function NW.CraftMissing(r)
  for _, re in ipairs(r.reagents or {}) do
    local have = bagCount(re[1])
    if have < re[2] then return re[1], re[2] - have end
  end
end

-- Is this profession the one the game has open?
local function isOpen(key)
  local T = C_TradeSkillUI
  if not T then return false end
  if T.IsTradeSkillReady then
    local ok, ready = pcall(T.IsTradeSkillReady)
    if not (ok and ready) then return false end
  end
  if T.GetBaseProfessionInfo then
    local ok, info = pcall(T.GetBaseProfessionInfo)
    if ok and info and info.professionID then return info.professionID == SKILL_LINE[key] end
  end
  return NW.currentTradeKey == key
end

local pending
local function castNow(key, e, count)
  local T = C_TradeSkillUI
  if not (T and T.CraftRecipe) then return false, "This client has no craft call for addons" end
  local ok, err = pcall(T.CraftRecipe, e.id, count)
  if not ok then return false, tostring(err) end
  return true
end

-- Craft `count` of a recipe. Returns ok, message. If the profession isn't
-- open yet this click opens it, and the next click crafts.
function NW.Craft(key, r, count)
  if InCombatLockdown and InCombatLockdown() then return false, "Not in combat" end
  local e = knownRecipe(key, r)
  if not e then return false, "Open the profession once first" end
  count = math.max(1, math.floor(count or 1))
  if isOpen(key) then
    local ok, err = castNow(key, e, count)
    return ok, ok and ("Crafting %d %s"):format(count, r.name) or err
  end
  local T = C_TradeSkillUI
  if not (T and T.OpenTradeSkill and SKILL_LINE[key]) then return false, "Open the profession window, then click Craft" end
  pending = { key = key, e = e, count = count, name = r.name, at = GetTime() }
  local ok, err = pcall(T.OpenTradeSkill, SKILL_LINE[key])
  if not ok then pending = nil return false, tostring(err) end
  return true, "Opening the profession…"
end

-- The profession is open now. The game only lets a craft start from your
-- own click, so the one that was waiting is asked for again.
local function finishPending()
  local p = pending
  if not p or GetTime() - p.at > 5 then pending = nil return end
  if not isOpen(p.key) then return end
  pending = nil
  local prof = NW.PROF_BY_KEY and NW.PROF_BY_KEY[p.key]
  if NW.CraftStatus then NW.CraftStatus(("%s is ready. Click Craft again."):format(prof and prof.name or "The profession")) end
end
NW.On("TRADE_SKILL_SHOW", function() C_Timer.After(0.2, finishPending) end)
NW.On("TRADE_SKILL_LIST_UPDATE", function() C_Timer.After(0.1, finishPending) end)

------------------------------------------------------------------------
-- Live listings. When Auctionator searches the auction house, the listings
-- it gets back (cheapest first) are kept here for a few minutes, so a big
-- purchase can be priced by what it really takes to fill, not by the single
-- lowest listing.
------------------------------------------------------------------------
local depth = {} -- [itemID] = { query, at, complete, pages = { [page] = { {unit, count}, ... } } }
local DEPTH_AGE = 600

local function onScanPage(results, gotAll)
  if type(results) ~= "table" then return end
  local me = UnitName and UnitName("player")
  local now = GetTime()
  local touched = {}
  for _, entry in ipairs(results) do
    local info = entry.info
    local id, count, buyout, owner = info and info[17], info and info[3], info and info[10], info and info[14]
    if type(id) == "number" and count and count > 0 and buyout and buyout > 0 and owner ~= me then
      local d = depth[id]
      if not d or d.query ~= entry.query then
        d = { query = entry.query, pages = {} }
        depth[id] = d
      end
      d.at = now
      local page = entry.page or 0
      if not touched[id] or touched[id] ~= page then
        d.pages[page] = {} -- this page again: replace, never add twice
        touched[id] = page
      end
      local rows = d.pages[page]
      rows[#rows + 1] = { buyout / count, count }
    end
  end
  if gotAll then
    local q = results[1] and results[1].query
    for _, d in pairs(depth) do if d.query == q then d.complete = true end end
  end
  if NW.OnLiveListings then NW.OnLiveListings() end
end

NW.LiveListings = onScanPage

table.insert(NW.OnLoad, function()
  local bus = Auctionator and Auctionator.EventBus
  local ev = Auctionator and Auctionator.AH and Auctionator.AH.Events and Auctionator.AH.Events.ScanResultsUpdate
  if not (bus and bus.Register and ev) then return end
  pcall(bus.Register, bus, {
    ReceiveEvent = function(_, _, results, gotAll) pcall(onScanPage, results, gotAll) end,
  }, { ev })
end)

-- What it costs to buy `qty` of an item from the listings last seen:
-- cost (copper, for the part that can be filled), how many that covers, and
-- whether every listing was seen. nil with no recent listings.
function NW.FillCost(id, qty)
  local d = depth[id]
  if not d or GetTime() - d.at > DEPTH_AGE then return nil end
  local rows = {}
  for _, page in pairs(d.pages) do
    for _, r in ipairs(page) do rows[#rows + 1] = r end
  end
  if #rows == 0 then return nil end
  table.sort(rows, function(a, b) return a[1] < b[1] end)
  local cost, got, seen = 0, 0, 0
  for _, r in ipairs(rows) do
    seen = seen + r[2]
    if got < qty then
      -- stacks sell whole, but what you pay per piece is what matters here
      local take = math.min(r[2], qty - got)
      cost = cost + r[1] * take
      got = got + take
    end
  end
  return cost, got, d.complete or false, seen
end
