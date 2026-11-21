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
    local e = { name = name, orange = learn < y and learn or nil, yellow = y, green = g, grey = gr, yield = yield or 1,
      reagents = {}, fee = fee, where = where, recipeItem = recipeItem, catalog = true, src = trainer and "trainer" or "recipe" }
    if type(id) == "string" then e.spell = tonumber(id:sub(2)) else e.item = id end
    for rid, n in reagents:gmatch("(%d+):(%d+)") do e.reagents[#e.reagents + 1] = { tonumber(rid), tonumber(n) } end
    list[#list + 1] = e
  end
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
NW.RANK_WHERE = {
  alchemy = {
    Expert = { Horde = { "Doctor Herbert Halsey", "Undercity" }, Alliance = { "Ainethil", "Darnassus" } },
    Artisan = { Horde = { "Rogvar", "Stonard, Swamp of Sorrows" }, Alliance = { "Kylanna Windwhisper", "Feathermoon, Feralas" } },
  },
  blacksmithing = {
    Expert = { Horde = { "Saru Steelfury", "Orgrimmar" }, Alliance = { "Bengus Deepforge", "Ironforge" } },
    Artisan = { Horde = { "Brikk Keencraft", "Booty Bay, Stranglethorn Vale" }, Alliance = { "Brikk Keencraft", "Booty Bay, Stranglethorn Vale" } },
  },
  enchanting = {
    Expert = { Horde = { "Hgarth", "Sun Rock Retreat, Stonetalon Mountains" }, Alliance = { "Kitta Firewind", "Tower of Azora, Elwynn Forest" } },
    Artisan = { Horde = { "Annora", "inside Uldaman, Badlands" }, Alliance = { "Annora", "inside Uldaman, Badlands" } },
  },
  engineering = {
    Expert = { Horde = { "Roxxik", "Orgrimmar" }, Alliance = { "Springspindle Fizzlegear", "Ironforge" } },
    Artisan = { Horde = { "Buzzek Bracketswing", "Gadgetzan, Tanaris" }, Alliance = { "Buzzek Bracketswing", "Gadgetzan, Tanaris" } },
  },
  leatherworking = {
    Expert = { Horde = { "Una", "Thunder Bluff" }, Alliance = { "Telonis", "Darnassus" } },
    Artisan = { Horde = { "Hahrana Ironhide", "Camp Mojache, Feralas" }, Alliance = { "Drakk Stonehand", "Aerie Peak, The Hinterlands" } },
  },
  tailoring = {
    Expert = { Horde = { "Josef Gregorian", "Undercity" }, Alliance = { "Georgio Bolero", "Stormwind" } },
    Artisan = { Horde = { "Daryl Stack", "Tarren Mill, Hillsbrad Foothills" }, Alliance = { "Timothy Worthington", "Theramore, Dustwallow Marsh" } },
  },
  cooking = {
    Expert = { Horde = { "Expert Cookbook, sold by Wulan", "Shadowprey Village, Desolace" }, Alliance = { "Expert Cookbook, sold by Shandrina", "Mystral Lake, Ashenvale" } },
    Artisan = { Horde = { "Quest from Dirge Quikcleave", "Gadgetzan, Tanaris" }, Alliance = { "Quest from Dirge Quikcleave", "Gadgetzan, Tanaris" } },
  },
  firstaid = {
    Expert = { Horde = { "Expert First Aid book, sold by Balai Lok'Wein", "Brackenwall Village, Dustwallow Marsh" }, Alliance = { "Expert First Aid book, sold by Deneb Walker", "Stromgarde, Arathi Highlands" } },
    Artisan = { Horde = { "Quest from Doctor Gregory Victor", "Hammerfall, Arathi Highlands" }, Alliance = { "Quest from Doctor Gustaf VanHowzen", "Theramore, Dustwallow Marsh" } },
  },
}
-- Returns who and where for your faction
function NW.RankWhere(key, rankName)
  local w = NW.RANK_WHERE[key] and NW.RANK_WHERE[key][rankName]
  if not w then return end
  local e = w[UnitFactionGroup and UnitFactionGroup("player") or "Horde"] or w.Horde
  return e[1], e[2]
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
  local key
  if T.GetBaseProfessionInfo then
    local ok, info = pcall(T.GetBaseProfessionInfo)
    key = ok and info and profKeyFromName(info.professionName)
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
  local catNames = {}
  for _, id in ipairs(ids) do
    local ok, info = pcall(T.GetRecipeInfo, id)
    if ok and info and info.name and not info.isDummyRecipe and not info.isRecraft then
      local e = { id = id, icon = info.icon, learned = info.learned and true or false, diff = info.relativeDifficulty }
      if info.categoryID and T.GetCategoryInfo then
        local cname = catNames[info.categoryID]
        if cname == nil then
          local okc, cat = pcall(T.GetCategoryInfo, info.categoryID)
          cname = okc and cat and cat.name or false
          catNames[info.categoryID] = cname
        end
        e.cat = cname or nil
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
    -- saved before they were per character: the first character to log in keeps them
    if db.known then c.known, c.recipeScan, c.recipeScanAt = db.known, db.recipeScan, db.recipeScanAt end
    db.known, db.recipeScan, db.recipeScanAt = nil, nil, nil
  end
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
  [4289] = 50, [15409] = 1000,                                         -- salt
  [2678] = 10, [2692] = 40, [3713] = 160, [159] = 25, [1179] = 125,   -- spices, drinks
  [4470] = 38, [11291] = 4500, [6217] = 124, [10940] = nil,           -- wood, copper rod
  [2324] = 25, [2604] = 50, [6260] = 50, [2605] = 100, [4340] = 350,  -- bleach, dyes
  [6261] = 1000, [2325] = 1000, [4342] = 2500, [10290] = 2500,
  [3182] = nil, [4399] = 200, [4400] = 2000, [10647] = 2000, [10648] = 500, -- wood stock, engineering
  [6530] = 100, [2894] = 50, [4536] = 25, [17194] = 10, [17196] = 50, -- misc cooking
}
NW.VENDOR_PRICES = VENDOR

local function auctionator(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local ok, price = pcall(api.GetAuctionPriceByItemID, ADDON, id)
  if ok and type(price) == "number" and price > 0 then return price end
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
      local p = NW.Price(re[1], (depth or 0) + 1)
      if not p then unknown = true break end
      cost = cost + p * re[2]
    end
    if not unknown then
      cost = cost / (r.yield or 1)
      if not best or cost < best then best, src = cost, "craft" end
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
  if s.planSellBack and r.item then
    local value = auctionator(r.item)
    if value then cost = cost - value * 0.95 * (r.yield or 1) * 0.5 end -- half: not everything sells
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
  local cacheKey = ("%s:%d:%d:%s%s"):format(key, from, to, s.planRecipeItems and "r" or "", s.planSellBack and "s" or "")
  if planCache[cacheKey] then return planCache[cacheKey] end

  local recipes = NW.RECIPES[key] or {}
  local _, maxSkill = NW.ProfSkill(key)
  if NW.craftKey ~= key then priceMemo = {}; NW.craftKey = key end
  craftOf = {}
  for _, r in ipairs(recipes) do if r.item and not craftOf[r.item] then craftOf[r.item] = r end end

  local costOf, unknownOf = {}, {}
  for i, r in ipairs(recipes) do costOf[i], unknownOf[i] = craftCost(r, s) end

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
            if not best or c < bestCost then best, bestCost, bestNeeds = i, c, needsRecipe end
          end
        end
      end
      if best then break end
    end
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
  local fees, paid = 0, {}
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
      fees = fees + st.train
      total = total + st.cost
      if st.unknown > 0 then unknownTotal = unknownTotal + 1 end
      st.mats = {}
      for _, re in ipairs(st.recipe.reagents) do st.mats[#st.mats + 1] = { re[1], re[2] * st.crafts } end
    end
  end
  local plan = { steps = steps, total = total, fees = fees, unknown = unknownTotal, gaps = gaps, from = from, to = to }
  planCache[cacheKey] = plan
  return plan
end

-- Everything to buy for a plan. Things you can make cheaper than buy are
-- broken down into what they're made from. Counts what's in your bags.
function NW.ShoppingList(key, plan)
  local need = {}
  local function add(id, n, depth)
    local r = craftOf and craftOf[id]
    local price, src = NW.Price(id)
    if r and src == "craft" and depth < 3 then
      local crafts = math.ceil(n / (r.yield or 1))
      for _, re in ipairs(r.reagents) do add(re[1], re[2] * crafts, depth + 1) end
    else
      need[id] = (need[id] or 0) + n
    end
  end
  NW.BuildPlan(key, plan.from, plan.to) -- makes sure craftOf is this profession's
  for _, st in ipairs(plan.steps) do
    for _, m in ipairs(st.mats or {}) do add(m[1], m[2], 0) end
  end
  local list, total = {}, 0
  local useBags = NW.db.settings.planUseBags
  for id, n in pairs(need) do
    local have = useBags and NW.ItemCount(id) or 0
    local buy = math.max(0, n - have)
    local price, src = NW.Price(id)
    local cost = price and price * buy or nil
    if cost then total = total + cost end
    list[#list + 1] = { id = id, need = n, have = have, buy = buy, price = price, src = src, cost = cost }
  end
  table.sort(list, function(a, b) return (a.cost or -1) > (b.cost or -1) end)
  return list, total
end

-- Money text: 12g 34s 56c, shortened for big numbers
function NW.Money(c, short)
  if not c then return "?" end
  c = math.floor(c + 0.5)
  local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local G, S, Cc = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fc|r"
  if g > 0 then
    if short or g >= 100 then return ("%d%s"):format(g, G) end
    return ("%d%s %d%s"):format(g, G, s, S)
  end
  if s > 0 then return short and ("%d%s"):format(s, S) or ("%d%s %d%s"):format(s, S, cp, Cc) end
  return ("%d%s"):format(cp, Cc)
end

-- Things the plan can't know: tools, rank books, left-out recipes
NW.PROF_TIPS = {
  alchemy = "Vials come from alchemy and trade supply vendors. In Forever the six Healing Potions moved to First Aid; Alchemy keeps the Discolored ones.",
  blacksmithing = "Weapons and armor need a Blacksmith Hammer from a trade supply vendor. Weaponsmith and Armorsmith recipes are left out. From about 260 only plans give skill-ups, so tick \"Use recipes to buy or find\" or plan to buy plans.",
  enchanting = "Make your rods as you go: Runed Copper Rod first, then Runed Silver (around 130), Runed Golden (around 175) and Runed Truesilver (around 220); later enchants need them. Each enchant needs an item to go on. Artisan is taught by Annora in Uldaman.",
  engineering = "Make an Arclight Spanner and buy a Blacksmith Hammer first. Gnomish, Goblin and seasonal firework recipes are left out. The Artisan trainer is Buzzek Bracketswing in Tanaris (from the original game).",
  leatherworking = "Salt for curing hides comes from leatherworking suppliers. Dragonscale, Elemental and Tribal recipes are left out. From about 250 most skill-ups come from patterns you buy or find.",
  tailoring = "Thread and dyes come from trade supply vendors. Mooncloth has a cooldown, so it isn't used for leveling. From about 250, patterns you buy or find are much cheaper.",
  cooking = "Expert Cooking comes from the Expert Cookbook (from 125). Most good recipes are sold by cooking vendors: tick \"Use recipes to buy or find\". Catch your own fish on the Fishing page.",
  firstaid = "Expert First Aid comes from a book (from 125). Heavy Silk and Mageweave Bandages need manuals. Artisan was a quest (Triage) in the original game.",
}
