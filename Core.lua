local ADDON, NW = ...
_G.Nodewalker = NW

local DEFAULTS = {
  version = 1,
  nodes = {},          -- [mapID] = { { x, y, name, kind, src, t }, ... }
  routes = {},         -- [mapID] = { name, stops = { {x,y,kind,count} }, avoid = { {x1,y1,x2,y2} } }
  learnedSkill = {},   -- [node name] = required skill learned in game
  settings = {
    overlayShown = false,
    opacity = 0.55,
    overlaySize = 0.5,    -- share of the screen the map window covers (0.25 to 1)
    scale = 1.0,          -- UI units per yard
    tint = "natural",     -- natural | muted | silhouette | gold | blue | none (nodes and route only)
    terrainSource = "minimap", -- minimap (detailed tiles) | zonemap (world map art)
    continentDirs = {},   -- [continent ID] = minimap folder, for continents we don't know yet
    fadeMoving = true,
    fadeMovingAlpha = 0.6,
    brightNear = true,    -- stop fading when a known spot or your next stop is close
    mountZoom = false,    -- zoom out while mounted
    hideCombat = true,
    hideResting = true,   -- cities and inns
    hideInstances = true,
    onlyTracking = false,
    showNextLabel = false,
    liveDots = true,
    showRangeRing = true,
    liveHoverNoAlt = false,   -- live-dot tooltips without Alt (makes herbs in the world harder to click)     -- ring around you: the range live dots can appear in          -- show the minimap's own herb/ore dots in the window
    showKnownSpots = false,   -- with live dots: also show known spots beyond their range
    onlyMyProfessions = true, -- only show herbs if you have Herbalism, ore if you have Mining
    onlyConfirmed = false,    -- only show nodes seen on your minimap or in the world
    hoverTooltips = true,     -- hover icons for details (clicks still pass through)
    confirmMinutes = 20,
    fadedAlpha = 0.35,
    groupSpots = true,    -- spots that overlap on the map share one icon with a count
    hiddenNodes = {},         -- [node name] = true for herbs and ore you don't want to see        -- herb icons not confirmed up are drawn this faint      -- how long a sighting counts as "there"
    zoneBanner = true,        -- banner when you enter a zone
    autoRoute = true,         -- build a route by itself in a zone that has none
    showCompass = true,
    minimapButton = true,
    minimapAngle = 215,
    showSession = true,
    questRingAlpha = 0.15,
    respawnMinutes = 5,
    arriveYards = 15,
    mergeYards = 100,
    includeOre = true,
    includeHerb = true,
    onlyGatherable = true,
    onlySkillUps = false,
    fishHud = true,           -- the fishing HUD, while a pole is on
    fishHudScale = 1,
    fishHudAlpha = 0.9,
    fishInteract = true,      -- the Smart Fishing key reels in through the game's Interact
    fishHudTarget = true, fishHudValue = true,
    fishTrack = true, fishTrackSpots = true, fishSessions = true, fishAutoSession = true,
    fishNotifyNew = true, fishNotifyRare = true, fishNotifyLure = true, fishNotifyTarget = true,
  },
}

local function copyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

-- WoW Forever's client hides some event and tooltip values from addons
-- ("secret values"), for example in combat or instances. They can't be
-- compared or used as table keys, so check before touching them.
local issecret = _G.issecretvalue
function NW.Readable(v)
  if issecret and issecret(v) then return false end -- first: a secret can't even be compared to nil
  if v == nil then return false end
  return true
end

-- In combat the game hides your speed and facing from addons. These return
-- the last value that could be read, so the overlay keeps working.
local lastFacing, lastMoving = 0, false
function NW.Facing()
  local f = GetPlayerFacing()
  if issecret and issecret(f) then return lastFacing end
  if f then lastFacing = f end
  return lastFacing
end
function NW.Moving()
  local v = GetUnitSpeed("player")
  if issecret and issecret(v) then return lastMoving end
  lastMoving = (v or 0) > 0
  return lastMoving
end

-- Item and merchant calls moved into C_ namespaces on newer clients.
-- These work on both.
function NW.ItemInfo(id)
  if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
  if GetItemInfo then return GetItemInfo(id) end
end
function NW.ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  return name or (NW.ItemInfo(id))
end
function NW.ItemIcon(id)
  local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
  if not icon and GetItemIcon then icon = GetItemIcon(id) end
  return icon
end
function NW.ItemCount(id)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id, true) or 0 end
  if GetItemCount then return GetItemCount(id, true) or 0 end
  return 0
end
function NW.SpellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  if GetSpellTexture then return GetSpellTexture(id) end
end
-- price, quantity per purchase, numAvailable (-1 = unlimited), hasExtendedCost
function NW.MerchantItem(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(i)
    if info then return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost end
    return nil
  end
  if GetMerchantItemInfo then
    local _, _, price, quantity, numAvailable, _, extendedCost = GetMerchantItemInfo(i)
    return price, quantity, numAvailable, extendedCost
  end
end

function NW.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd6b266Nodewalker|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Positions and distances
------------------------------------------------------------------------
local mapSizeCache = {}

-- Width and height of a map in yards, or nil when the game can't say
-- (some instances and interiors).
function NW.MapSize(mapID)
  if not mapID then return nil end
  local cached = mapSizeCache[mapID]
  if cached ~= nil then return cached and cached[1], cached and cached[2] end
  local ok, _, p0 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
  local ok2, _, p1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
  if ok and ok2 and p0 and p1 then
    local w = math.abs(p0.y - p1.y)
    local h = math.abs(p0.x - p1.x)
    if w > 0 and h > 0 then
      mapSizeCache[mapID] = { w, h }
      return w, h
    end
  end
  mapSizeCache[mapID] = false
  return nil
end

function NW.Yards(mapID, x1, y1, x2, y2)
  local w, h = NW.MapSize(mapID)
  if not w then return nil end
  local dx, dy = (x2 - x1) * w, (y2 - y1) * h
  return math.sqrt(dx * dx + dy * dy)
end

-- mapID, x, y (0-1) of the player, or nil
function NW.PlayerPos()
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if issecret and (issecret(x) or issecret(y) or issecret(mapID)) then
    -- hidden right now: go with where you last were
    if NW.lastPos then return NW.lastPos[1], NW.lastPos[2], NW.lastPos[3] end
    return nil
  end
  if not x or (x == 0 and y == 0) then return nil end
  NW.lastPos = NW.lastPos or {}
  NW.lastPos[1], NW.lastPos[2], NW.lastPos[3] = mapID, x, y
  return mapID, x, y
end

------------------------------------------------------------------------
-- Profession skill
------------------------------------------------------------------------
local SKILL_NAMES = { herb = "Herbalism", ore = "Mining" }

-- Skill lookups are cached for a few seconds: the overlay asks every frame.
local skillCache, skillCacheAt = {}, 0

local function readSkill(want)
  if GetProfessions and GetProfessionInfo then
    local ok, p1, p2 = pcall(GetProfessions)
    if ok then
      local list = { p1, p2 }
      for i = 1, 2 do
        local idx = list[i]
        if idx then
          local name, _, level = GetProfessionInfo(idx)
          if name == want then return level end
        end
      end
    end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(i)
      if not isHeader and name == want then return rank end
    end
  end
  return nil
end

function NW.GetSkill(kind)
  local want = SKILL_NAMES[kind]
  if not want then return nil end
  local now = GetTime()
  if now - skillCacheAt > 5 then skillCache, skillCacheAt = {}, now end
  local v = skillCache[kind]
  if v == nil then
    v = readSkill(want) or false
    skillCache[kind] = v
  end
  return v or nil
end

-- Should this kind of node show on the overlay at all?
function NW.ShowKind(kind, s)
  if kind == "ore" and not s.includeOre then return false end
  if kind == "herb" and not s.includeHerb then return false end
  if s.onlyMyProfessions and not NW.GetSkill(kind) then return false end
  return true
end

function NW.RequiredSkill(name)
  local learned = NW.db.learnedSkill[name]
  if learned then return learned end
  local info = NW.NODES[name]
  return info and info[2]
end

-- Should this node be part of a route, given the filters?
function NW.IsHidden(name)
  return name and NW.db.settings.hiddenNodes[name] and true or false
end

function NW.SetHidden(name, hidden)
  NW.db.settings.hiddenNodes[name] = hidden and true or nil
  if NW.RefreshPlanner then NW.RefreshPlanner() end
  if NW.RefreshNodeOptions then NW.RefreshNodeOptions() end
end

function NW.NodeWanted(node, s)
  if NW.IsHidden(node.name) then return false end
  if node.kind == "ore" and not s.includeOre then return false end
  if node.kind == "herb" and not s.includeHerb then return false end
  if s.onlyGatherable or s.onlySkillUps then
    local skill = NW.GetSkill(node.kind)
    local req = NW.RequiredSkill(node.name)
    if skill and req then
      local c = NW.SkillColor(req, skill)
      if c == "red" then return false end
      if s.onlySkillUps and c == "grey" then return false end
    elseif not skill then
      return false -- you don't have the profession
    end
  end
  return true
end

------------------------------------------------------------------------
-- Events and slash commands
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
NW.eventFrame = frame
local handlers = {}

-- Events differ between game clients: an event this client doesn't have is
-- skipped instead of stopping the addon from loading.
function NW.On(event, fn)
  if not pcall(frame.RegisterEvent, frame, event) then return false end
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
  return true
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, ...)
    if not ok then NW.Print("error in " .. event .. ": " .. tostring(err)) end
  end
end)

-- Choices that belong to one character (their consumes, their profession page)
-- live in db.chars[name-realm].settings; everything else is shared. Code keeps
-- reading and writing NW.db.settings: these keys are passed through.
local CHAR_KEYS = {
  consumeSpec = true, consumeList = true, consumeHidden = true, consumeBudget = true, consumeHours = true,
  profSelected = true, planTarget = true, lastTab = true, fishCook = true, fishTab = true,
}
local function splitCharSettings(db)
  if not (UnitName and GetRealmName) then return end
  db.chars = db.chars or {}
  local ck = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
  local c = db.chars[ck] or {}
  db.chars[ck] = c
  local first = not c.settings
  c.settings = c.settings or {}
  local cs, base = c.settings, db.settings
  for k in pairs(CHAR_KEYS) do
    -- before this, they were shared: the first character to log in keeps them.
    -- After that, what's left here is only the default (copyDefaults put it back).
    if first and cs[k] == nil then cs[k] = rawget(base, k) end
    rawset(base, k, nil)
  end
  -- a spec carried over from another class: back to this class's own
  if first and cs.consumeSpec and NW.CONSUMES then
    local _, class = UnitClass("player")
    for _, l in ipairs(NW.CONSUMES) do
      if l.key == cs.consumeSpec and l.class and l.class ~= class then cs.consumeSpec = nil end
    end
  end
  setmetatable(base, {
    __index = function(_, k) if CHAR_KEYS[k] then return cs[k] end end,
    __newindex = function(t, k, v) if CHAR_KEYS[k] then cs[k] = v else rawset(t, k, v) end end,
  })
end

frame:RegisterEvent("ADDON_LOADED")
NW.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  NodewalkerDB = NodewalkerDB or {}
  copyDefaults(DEFAULTS, NodewalkerDB)
  NW.db = NodewalkerDB
  splitCharSettings(NodewalkerDB)
  if NW.OnLoad then
    for _, fn in ipairs(NW.OnLoad) do pcall(fn) end
  end
end)

NW.OnLoad = {}

SLASH_NODEWALKER1 = "/nw"
SLASH_NODEWALKER2 = "/nodewalker"
SlashCmdList.NODEWALKER = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "" or msg == "map" or msg == "toggle" then
    NW.ToggleOverlay()
  elseif msg == "plan" or msg == "route" then
    NW.TogglePlanner()
  elseif msg == "guide" or msg == "herbs" or msg == "ore" or msg == "farm" then
    NW.ToggleGuide()
  elseif msg == "consumes" or msg == "consume" then
    NW.ToggleWindow("consumes")
  elseif msg == "prof" or msg == "profs" or msg == "professions" or msg == "level" then
    NW.ToggleProfessions()
  elseif msg == "journal" or msg == "fish" then
    if NW.OpenFishJournal then NW.OpenFishJournal() end
  elseif msg == "fishhud" then
    if NW.ToggleFishHUD then NW.ToggleFishHUD() end
  elseif msg == "window" or msg == "open" then
    NW.ToggleWindow()
  elseif msg == "options" or msg == "config" then
    NW.OpenOptions()
  elseif msg == "import" then
    NW.ImportGatherMate2()
  elseif msg == "import help" then
    -- the GatherMate2 warning, whatever you already have
    NW.ToggleWindow("route")
    if NW.window:IsShown() and NW.TabPage then NW.MaybeImportPrompt(NW.TabPage("route"), true) end
  elseif msg == "next" then
    NW.SkipNext()
  elseif msg == "harvest" or msg == "harvest all" then
    if NW.HarvestConsumes then NW.HarvestConsumes(msg == "harvest all") end
  elseif msg == "reset session" then
    NW.ResetSession()
  elseif msg:match("^hide ") or msg:match("^show ") then
    local verb, want = msg:match("^(%a+) (.+)$")
    local found
    for name in pairs(NW.NODES) do if name:lower() == want then found = name end end
    if found then
      NW.SetHidden(found, verb == "hide")
    else
      NW.Print("Unknown herb or vein: " .. want)
    end
  elseif msg == "hidden" then
    local list = {}
    for name in pairs(NW.db.settings.hiddenNodes) do list[#list + 1] = name end
    table.sort(list)
    NW.Print(#list > 0 and ("Hidden: " .. table.concat(list, ", ")) or "Nothing is hidden.")
  elseif msg == "terrain" then
    NW.TerrainReport()
  elseif msg:match("^continent ") then
    local id, dir = msg:match("^continent (%d+) (%S+)$")
    if id then
      NW.db.settings.continentDirs[tonumber(id)] = dir:gsub("^%l", string.upper)
      NW.Print(("Continent %s will use World\\Minimaps\\%s."):format(id, NW.db.settings.continentDirs[tonumber(id)]))
    else
      NW.Print("Usage: /nw continent <id> <folder>   (see /nw terrain for the id)")
    end
  elseif msg == "frame" then
    if NW.FrameUnderMouse then NW.FrameUnderMouse() end
  elseif msg == "status" then
    local mapID = NW.PlayerPos()
    local n = 0
    for _, list in pairs(NW.db.nodes) do n = n + #list end
    NW.Print(("%d nodes saved in all zones; %d in this zone; route here: %s"):format(
      n, mapID and #(NW.db.nodes[mapID] or {}) or 0,
      (mapID and NW.db.routes[mapID]) and (#NW.db.routes[mapID].stops .. " stops") or "none"))
  else
    NW.Print("/nw  toggle overlay · /nw plan  route · /nw guide  farm guide · /nw prof  professions · /nw consumes · /nw journal · /nw options · /nw import  GatherMate2 nodes · /nw status")
  end
end

-- Key binding labels (Bindings.xml)
BINDING_HEADER_NODEWALKER = "Nodewalker"
BINDING_NAME_NODEWALKER_TOGGLE = "Toggle overlay"
BINDING_NAME_NODEWALKER_PLANNER = "Toggle route planner"
BINDING_NAME_NODEWALKER_NEXT = "Skip to next stop"
BINDING_NAME_NODEWALKER_FISHHUD = "Toggle fishing HUD"
BINDING_NAME_NODEWALKER_JOURNAL = "Fishing Journal"
