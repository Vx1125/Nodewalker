local ADDON, NW = ...

local GATHER_SPELLS = { ["Herb Gathering"] = "herb", ["Mining"] = "ore" }
NW.TRACKING_NAMES = { ["Find Herbs"] = true, ["Find Minerals"] = true }
local SAME_NODE_YARDS = 15

NW.picked = {}      -- [mapID..":"..index] = GetTime() when gathered
NW.seen = {}        -- [mapID..":"..index] = GetTime() when seen up (minimap or world)
NW.seenStop = {}    -- [mapID..":"..stop index] = GetTime() when a herb at that route stop was seen up
NW.gatherListeners = {}

local function spellName(spellID)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  if GetSpellInfo then return (GetSpellInfo(spellID)) end
  return nil
end

-- Add a node, or refresh one already saved within SAME_NODE_YARDS.
-- Returns the node's index in its zone list.
function NW.AddNode(mapID, x, y, name, kind, src)
  NW.db.nodes[mapID] = NW.db.nodes[mapID] or {}
  local list = NW.db.nodes[mapID]
  for i, n in ipairs(list) do
    if n.kind == kind then
      local d = NW.Yards(mapID, n.x, n.y, x, y)
      if d and d < SAME_NODE_YARDS then
        if src == "me" then
          n.x, n.y, n.name, n.src, n.t = x, y, name, "me", time()
        end
        return i, false
      end
    end
  end
  table.insert(list, { x = x, y = y, name = name, kind = kind, src = src, t = time() })
  return #list, true
end

function NW.PickedKey(mapID, i) return mapID .. ":" .. i end

-- The same spells under their names in your game's language
table.insert(NW.OnLoad, function()
  local herb, mine = spellName(2366), spellName(2575)
  if herb then GATHER_SPELLS[herb] = "herb" end
  if mine then GATHER_SPELLS[mine] = "ore" end
  for _, id in ipairs({ 2383, 2580 }) do
    local n = spellName(id)
    if n then NW.TRACKING_NAMES[n] = true end
  end
end)

------------------------------------------------------------------------
-- Recording what you gather
------------------------------------------------------------------------
-- The cast being made: { guid, name, kind, t }. Some values in these events
-- can be hidden from addons (see NW.Readable); then we fall back on the
-- spell and the nearest saved node.
local pending
local R = NW.Readable

NW.On("UNIT_SPELLCAST_SENT", function(unit, target, castGUID, spellID)
  if not R(unit) or unit ~= "player" then return end
  local kind = R(spellID) and GATHER_SPELLS[spellName(spellID) or ""]
  local name = R(target) and target ~= "" and target or nil
  local info = name and NW.NODES[name]
  if info then kind = info[1] end
  if not kind then return end
  pending = { guid = R(castGUID) and castGUID or nil, name = name, kind = kind, t = GetTime() }
end)

local function sameCast(castGUID)
  if not pending then return false end
  if pending.guid and R(castGUID) then return pending.guid == castGUID end
  return GetTime() - pending.t < 10
end

-- Name of the nearest saved node of this kind, when the game hid the name
local function nearestName(mapID, x, y, kind)
  local best, bestD
  for _, n in ipairs(NW.db.nodes[mapID] or {}) do
    if n.kind == kind and n.name then
      local d = NW.Yards(mapID, n.x, n.y, x, y)
      if d and d < 25 and (not bestD or d < bestD) then best, bestD = n.name, d end
    end
  end
  return best
end

NW.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID)
  if not R(unit) or unit ~= "player" or not sameCast(castGUID) then return end
  local p = pending
  pending = nil
  local mapID, x, y = NW.PlayerPos()
  if not mapID then return end
  p.name = p.name or nearestName(mapID, x, y, p.kind)
  local i
  if p.name then
    local isNew
    i, isNew = NW.AddNode(mapID, x, y, p.name, p.kind, "me")
    if isNew and NW.InsertIntoRoute then NW.InsertIntoRoute(mapID, NW.db.nodes[mapID][i]) end
    NW.picked[NW.PickedKey(mapID, i)] = GetTime()
    NW.seen[NW.PickedKey(mapID, i)] = nil
  end
  local route = NW.db.routes[mapID]
  if route then
    local reach = (NW.db.settings.mergeYards or 60) + 10
    for si, st in ipairs(route.stops) do
      local d = NW.Yards(mapID, st.x, st.y, x, y)
      if d and d <= reach then NW.seenStop[mapID .. ":" .. si] = nil end
    end
  end
  NW.session.nodes = NW.session.nodes + 1
  NW.session.lootUntil = GetTime() + 5 -- what you loot next came from this node
  for _, fn in ipairs(NW.gatherListeners) do pcall(fn, mapID, i, x, y, p) end
end)

local function cancel(unit, castGUID)
  if R(unit) and unit == "player" and sameCast(castGUID) then pending = nil end
end
NW.On("UNIT_SPELLCAST_FAILED", cancel)
NW.On("UNIT_SPELLCAST_INTERRUPTED", cancel)

------------------------------------------------------------------------
-- Sightings: is a herb or vein actually up right now?
--
-- Addons can't read the minimap's tracking dots, but the game does show
-- their names in a tooltip when you hover them, and names a node when you
-- point at it in the world. We use both:
--  * Minimap: work out where the cursor is in the world from the minimap's
--    zoom, then mark the saved node of that name there (or save a new one).
--  * World: mark the nearest saved node of that name within 45 yards.
------------------------------------------------------------------------
-- Minimap diameter in yards per zoom level (the game's fixed values)
local MM_OUTDOOR = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local MM_INDOOR = { 300, 240, 180, 120, 80, 50 }

local function nodeNamesIn(text)
  local found = {}
  if not text then return found end
  text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  for line in text:gmatch("[^\n]+") do
    local name = strtrim(line)
    local info = NW.NODES[name]
    if info then found[#found + 1] = { name = name, kind = info[1] } end
  end
  return found
end

-- Mark the node of this name nearest to (x, y) within maxYards as seen.
-- addIfMissing: save a new node there when none is close (minimap only).
local function markSeen(mapID, x, y, name, kind, maxYards, addIfMissing)
  local best, bestD
  for i, n in ipairs(NW.db.nodes[mapID] or {}) do
    if n.kind == kind then
      local d = NW.Yards(mapID, n.x, n.y, x, y)
      if d and d <= maxYards and (not bestD or d < bestD) then best, bestD = i, d end
    end
  end
  if not best and addIfMissing then
    local isNew
    best, isNew = NW.AddNode(mapID, x, y, name, kind, "seen")
    if isNew and NW.InsertIntoRoute then NW.InsertIntoRoute(mapID, NW.db.nodes[mapID][best]) end
  end
  if best then
    local key = NW.PickedKey(mapID, best)
    NW.seen[key] = GetTime()
    NW.picked[key] = nil
    local n = NW.db.nodes[mapID][best]
    if n and (n.name == "Herb" or n.name == "Ore") then n.name = name end
    -- the route stop this herb belongs to counts as confirmed too
    local route = NW.db.routes[mapID]
    if n and route then
      local reach = (NW.db.settings.mergeYards or 60) + 10
      for si, st in ipairs(route.stops) do
        local d = NW.Yards(mapID, st.x, st.y, n.x, n.y)
        if d and d <= reach then NW.seenStop[mapID .. ":" .. si] = GetTime() end
      end
    end
  end
end

function NW.StopSeenAgo(mapID, si)
  local t = NW.seenStop[mapID .. ":" .. si]
  if not t then return nil end
  local ago = GetTime() - t
  if ago > (NW.db.settings.confirmMinutes or 20) * 60 then return nil end
  return ago
end

local function minimapCursorPos()
  local mapID, px, py = NW.PlayerPos()
  if not mapID then return nil end
  local w, h = NW.MapSize(mapID)
  if not w then return nil end
  local zoom = Minimap:GetZoom() or 0
  local diam = (IsIndoors() and MM_INDOOR or MM_OUTDOOR)[zoom + 1]
  if not diam then return nil end
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local mx, my = Minimap:GetCenter()
  if not mx then return nil end
  local perPx = diam / Minimap:GetWidth()
  local east, north = (cx / scale - mx) * perPx, (cy / scale - my) * perPx
  if GetCVar and GetCVar("rotateMinimap") == "1" then
    local f = NW.Facing()
    east, north = east * math.cos(f) - north * math.sin(f), east * math.sin(f) + north * math.cos(f)
  end
  return mapID, px + east / w, py - north / h
end

local lastTip
local function checkMinimapTooltip()
  if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= Minimap then lastTip = nil return end
  local text = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
  if not R(text) or text == lastTip then return end
  lastTip = text
  local found = nodeNamesIn(text)
  if #found == 0 then return end
  local mapID, x, y = minimapCursorPos()
  if not mapID then return end
  for _, f in ipairs(found) do markSeen(mapID, x, y, f.name, f.kind, 40, true) end
end

local function checkWorldTooltip()
  if GameTooltip:GetOwner() == Minimap then return end
  if GameTooltip:GetUnit() then return end
  local text = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
  if not R(text) then return end
  local found = nodeNamesIn(text)
  if #found == 0 then return end
  local mapID, px, py = NW.PlayerPos()
  if not mapID then return end
  for _, f in ipairs(found) do markSeen(mapID, px, py, f.name, f.kind, 45, false) end
end

GameTooltip:HookScript("OnShow", function()
  pcall(checkMinimapTooltip)
  pcall(checkWorldTooltip)
end)

-- The minimap tooltip changes as you move along it without hiding, so watch it
local tipWatch = CreateFrame("Frame")
local tipElapsed = 0
tipWatch:SetScript("OnUpdate", function(_, dt)
  tipElapsed = tipElapsed + dt
  if tipElapsed < 0.15 then return end
  tipElapsed = 0
  if Minimap:IsMouseOver() then pcall(checkMinimapTooltip) end
end)

-- Seconds since a node was seen up, or nil
function NW.SeenAgo(mapID, i)
  local t = NW.seen[NW.PickedKey(mapID, i)]
  if not t then return nil end
  local ago = GetTime() - t
  if ago > (NW.db.settings.confirmMinutes or 20) * 60 then return nil end
  return ago
end

-- Seconds since a node was gathered, while it still counts as picked, or nil
function NW.PickedAgo(mapID, i)
  local t = NW.picked[NW.PickedKey(mapID, i)]
  if not t then return nil end
  local ago = GetTime() - t
  if ago > (NW.db.settings.respawnMinutes or 5) * 60 then return nil end
  return ago
end

------------------------------------------------------------------------
-- Session numbers
------------------------------------------------------------------------
NW.session = { started = GetTime(), nodes = 0, loops = 0, value = 0, loopStarted = nil, lastLoopTime = nil }

function NW.ResetSession()
  NW.session = { started = GetTime(), nodes = 0, loops = 0, value = 0, loopStarted = nil, lastLoopTime = nil }
end

-- What you gather is worth: loot within a few seconds of gathering a node,
-- at Auctionator's price (vendor price when it has none).
local function lootPattern(fmt)
  if not fmt then return nil end
  fmt = fmt:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
  fmt = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
  return "^" .. fmt:gsub("\1", "(.+)"):gsub("\2", "(%%d+)") .. "$"
end
local LOOT_MANY = lootPattern(LOOT_ITEM_SELF_MULTIPLE)
local LOOT_ONE = lootPattern(LOOT_ITEM_SELF)
local PUSH_MANY = lootPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE)
local PUSH_ONE = lootPattern(LOOT_ITEM_PUSHED_SELF)

NW.On("CHAT_MSG_LOOT", function(msg)
  local s = NW.session
  if not s.lootUntil or GetTime() > s.lootUntil or not NW.Readable(msg) or type(msg) ~= "string" then return end
  local link, count
  for _, pat in ipairs({ LOOT_MANY, PUSH_MANY }) do
    if pat and not link then link, count = msg:match(pat) end
  end
  for _, pat in ipairs({ LOOT_ONE, PUSH_ONE }) do
    if pat and not link then link = msg:match(pat) end
  end
  local id = link and tonumber(link:match("|Hitem:(%d+)"))
  if not id or not NW.Price then return end
  local price, src = NW.Price(id)
  if price and (src == "ah" or src == "vendor") then
    s.value = (s.value or 0) + price * (tonumber(count) or 1)
  end
end)

------------------------------------------------------------------------
-- GatherMate2 import (one-time, optional)
--
-- Two sources:
--  1. Your own GatherMate2 nodes: the saved tables GatherMate2HerbDB and
--     GatherMate2MineDB, plus any per-expansion storage tables. (GatherMate2's
--     own gmdbs entries are proxy tables, so we read the real tables.)
--  2. The GatherMate2_Data pack (node locations from Wowhead, loaded on
--     demand): GatherMateData2HerbDB and GatherMateData2MineDB.
-- Both store nodes per map as [coord] = nodeID, where
-- coord = floor(x*10000+0.5)*1000000 + floor(y*10000+0.5)*100 + level.
------------------------------------------------------------------------
local GM_TYPES = { ["Herb Gathering"] = "herb", ["Mining"] = "ore" }
local GM_PREFIX = { ["Herb Gathering"] = "Herb", ["Mining"] = "Mine" }
local DATA_GLOBALS = { ["Herb Gathering"] = "GatherMateData2HerbDB", ["Mining"] = "GatherMateData2MineDB" }

-- Fast bulk add: a 15-yard grid per map so thousands of nodes import
-- without comparing every pair.
local function makeGrid(mapID)
  local w, h = NW.MapSize(mapID)
  local cellX = w and (SAME_NODE_YARDS / w) or 0.002
  local cellY = h and (SAME_NODE_YARDS / h) or 0.002
  local grid = {}
  local function key(kind, cx, cy) return kind .. ":" .. cx .. ":" .. cy end
  local function cellOf(x, y) return math.floor(x / cellX), math.floor(y / cellY) end
  for _, n in ipairs(NW.db.nodes[mapID] or {}) do
    local cx, cy = cellOf(n.x, n.y)
    grid[key(n.kind, cx, cy)] = true
  end
  return function(x, y, kind)
    local cx, cy = cellOf(x, y)
    for dx = -1, 1 do
      for dy = -1, 1 do
        if grid[key(kind, cx + dx, cy + dy)] then return false end
      end
    end
    grid[key(kind, cx, cy)] = true
    return true
  end
end

local function importTable(GM, gmType, kind, db, stats)
  if type(db) ~= "table" then return end
  for mapID, coords in pairs(db) do
    if type(mapID) == "number" and type(coords) == "table" then
      NW.db.nodes[mapID] = NW.db.nodes[mapID] or {}
      local list = NW.db.nodes[mapID]
      local isFree = makeGrid(mapID)
      for coord, nodeID in pairs(coords) do
        if type(coord) == "number" then
          local x = math.floor(coord / 1000000) / 10000
          local y = math.floor((coord % 1000000) / 100) / 10000
          stats.seen = stats.seen + 1
          if x > 0 and y > 0 and isFree(x, y, kind) then
            local name
            if GM and GM.GetNameForNode then
              local ok, n = pcall(GM.GetNameForNode, GM, gmType, nodeID)
              if ok then name = n end
            end
            list[#list + 1] = { x = x, y = y, name = name or (kind == "ore" and "Ore" or "Herb"), kind = kind, src = stats.src, t = time() }
            stats.added = stats.added + 1
          end
        end
      end
    end
  end
end

function NW.ImportGatherMate2()
  local GM = _G.GatherMate2
  if not GM then
    NW.Print("GatherMate2 isn't loaded, so there is nothing to import. Turn it on for one login, run /nw import, then you can turn it off.")
    return
  end

  -- 1. Your own GatherMate2 nodes
  local mine = { seen = 0, added = 0, src = "gm2" }
  for gmType, kind in pairs(GM_TYPES) do
    local base = "GatherMate2" .. GM_PREFIX[gmType] .. "DB"
    importTable(GM, gmType, kind, _G[base], mine)
    local proxy = GM.gmdbs and GM.gmdbs[gmType]
    local map = proxy and rawget(proxy, "__gm2_storage_map")
    if type(map) == "table" then
      for _, storage in pairs(map) do importTable(GM, gmType, kind, storage, mine) end
    end
  end

  -- 2. The GatherMate2_Data pack (Wowhead locations)
  local pack = { seen = 0, added = 0, src = "gm2data" }
  local loaded = _G.GatherMateData2HerbDB ~= nil
  if not loaded then
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then
      local ok, res = pcall(load, "GatherMate2_Data")
      loaded = ok and res and _G.GatherMateData2HerbDB ~= nil
    end
  end
  if loaded then
    for gmType, kind in pairs(GM_TYPES) do
      importTable(GM, gmType, kind, _G[DATA_GLOBALS[gmType]], pack)
    end
  end

  NW.Print(("From your GatherMate2: %d new nodes (%d read)."):format(mine.added, mine.seen))
  if loaded then
    NW.Print(("From the GatherMate2_Data pack: %d new nodes (%d read)."):format(pack.added, pack.seen))
  else
    NW.Print("The GatherMate2_Data pack isn't installed or enabled, so only your own nodes were read.")
  end
  if NW.RefreshPlanner then NW.RefreshPlanner() end
end

------------------------------------------------------------------------
-- Routes and the Farm Guide need known spots. With hardly any, a warning
-- over the page says how to get them from GatherMate2, with the import button.
------------------------------------------------------------------------
local FEW_NODES = 200
local promptFrame, promptSkip
local function addonState(name)
  local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  if not info then return "unknown" end
  local ok, _, _, _, loadable, reason = pcall(info, name)
  if not ok then return "unknown" end
  if reason == "MISSING" then return "missing" end
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)(name)
  if loaded then return "on" end
  return loadable and "off" or "disabled"
end
local function knownNodes()
  local n = 0
  for _, list in pairs(NW.db.nodes) do n = n + #list end
  return n
end

local function buildPrompt()
  local UI, S = NW.UI, NW.STYLE
  local f = CreateFrame("Frame", nil, NW.window)
  f:EnableMouse(true) -- the page underneath can't be clicked while it's up
  local shade = f:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints()
  shade:SetColorTexture(0, 0, 0, 0.6)
  local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
  box:SetSize(520, 300)
  box:SetPoint("CENTER", 0, 10)
  UI.Flat(box, S.bg, { 0.85, 0.2, 0.15, 1 })
  local bar = box:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(3)
  bar:SetColorTexture(0.85, 0.2, 0.15, 1)
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetSize(32, 32)
  icon:SetPoint("TOPLEFT", 20, -20)
  icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  local title = UI.Text(box, 17, { 1, 0.35, 0.3, 1 })
  title:SetPoint("LEFT", icon, "RIGHT", 12, 0)
  title:SetText("No herb and ore spots yet")
  local body = UI.Text(box, 12, S.text)
  body:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -14)
  body:SetWidth(480)
  body:SetJustifyV("TOP")
  body:SetSpacing(5)
  body:SetText("Routes and the Farm Guide are built from known spots. Get thousands of them from GatherMate2:\n\n"
    .. "|cffd6b2661.|r  Install |cffd6b266GatherMate2|r and |cffd6b266GatherMate2_Data|r from CurseForge.\n"
    .. "|cffd6b2662.|r  Enable both at character select, then log in.\n"
    .. "|cffd6b2663.|r  Click |cffd6b266Import now|r below. Afterwards you can turn GatherMate2 off.")
  f.status = UI.Text(box, 12, S.dim)
  f.status:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -14)
  f.status:SetWidth(480)
  f.status:SetSpacing(3)
  f.import = UI.Button(box, "Import now", 150, function()
    NW.ImportGatherMate2()
    if knownNodes() >= FEW_NODES then f:Hide() else f:Refresh() end
  end, 26, "primary")
  f.import:SetPoint("BOTTOMLEFT", 20, 18)
  local later = UI.Button(box, "Not now", 110, function() promptSkip = true f:Hide() end, 26)
  later:SetPoint("LEFT", f.import, "RIGHT", 8, 0)
  local never = UI.Button(box, "Don't show again", 150, function() NW.db.importPromptOff = true f:Hide() end, 26)
  never:SetPoint("BOTTOMRIGHT", -20, 18)
  function f:Refresh()
    local gm, data = addonState("GatherMate2"), addonState("GatherMate2_Data")
    local function line(name, st)
      if st == "on" then return ("|cff94ba78%s is on|r"):format(name) end
      if st == "missing" then return ("|cffd17665%s isn't installed|r"):format(name) end
      if st == "off" and name == "GatherMate2_Data" then return ("|cff94ba78%s is installed|r (loads when you import)"):format(name) end
      return ("|cffd17665%s is installed but turned off|r"):format(name)
    end
    self.status:SetText(line("GatherMate2", gm) .. "\n" .. line("GatherMate2_Data", data)
      .. ("\n|cff938c80Nodewalker knows %d spots.|r"):format(knownNodes()))
    self.import:SetEnabled(_G.GatherMate2 ~= nil)
  end
  return f
end

-- Called when Route or the Farm Guide opens
function NW.MaybeImportPrompt(page, force)
  if not (NW.db and page) then return end
  if not force and (NW.db.importPromptOff or promptSkip or knownNodes() >= FEW_NODES) then
    if promptFrame then promptFrame:Hide() end
    return
  end
  promptFrame = promptFrame or buildPrompt()
  promptFrame:SetParent(page)
  promptFrame:SetAllPoints(page)
  promptFrame:SetFrameLevel(page:GetFrameLevel() + 40)
  promptFrame:Refresh()
  promptFrame:Show()
end
