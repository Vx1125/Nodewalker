local _, NW = ...

------------------------------------------------------------------------
-- Fishing Journal: what you've caught, where, and in which session.
--
-- Attribution: a loot window counts only when the game says it's fishing
-- loot (IsFishingLoot). Without that function, only a window opened from a
-- game object within a few seconds of your Fishing channel ending counts.
-- Items are counted as their slots are emptied (LOOT_SLOT_CLEARED), so
-- autoloot, manual loot, full bags (nothing taken, nothing counted) and
-- repeated loot events are all handled the same way.
--
-- Storage, per character (db.chars[name-realm].fishLog), aggregated:
--   items[id] = { n, first, last, k }   k: f fish, t trade goods, e gear, c container, j junk, o other
--   zones[mapID] = { n, fish, t, last, items = { [id] = n } }
--   spots[mapID][cell] = { [id] = n }   cell: 2% of the map, at most 400 per map
--   sessions = { ... }                  last 100, newest last
--   recent = { ... }                    last 100 catches, for detail
-- Prices are never stored per catch; a session keeps the value it had when it ended.
------------------------------------------------------------------------
local J = {}
NW.FishJournal = J
local VERSION = 1
local SESSIONS_KEPT, RECENT_KEPT, CELLS_PER_MAP = 100, 100, 400
local IDLE_GAP = 120    -- seconds between casts that still count as fishing
local SESSION_END = 1200 -- 20 minutes without fishing ends a session

local function st() return NW.db.settings end
local function now() return time() end

function J.charKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?") end

local function upgrade(log)
  log.v = log.v or VERSION
  log.items = log.items or {}
  log.zones = log.zones or {}
  log.spots = log.spots or {}
  log.sessions = log.sessions or {}
  log.recent = log.recent or {}
  log.fish = log.fish or 0
  log.other = log.other or 0
  log.catches = log.catches or 0
  log.time = log.time or 0
  return log
end
-- this character's journal
function J.log()
  local c = NW.charDB
  if not c then return nil end
  c.fishLog = upgrade(c.fishLog or {})
  return c.fishLog
end
-- the journals a view covers: this character, or every character
function J.logs(scope)
  local out = {}
  if scope == "all" then
    for ck, c in pairs(NW.db.chars or {}) do
      if type(c) == "table" and type(c.fishLog) == "table" then out[#out + 1] = upgrade(c.fishLog) end
    end
  else
    local l = J.log()
    if l then out[1] = l end
  end
  return out
end

------------------------------------------------------------------------
-- What kind of catch an item is, from the game's own item classes
------------------------------------------------------------------------
local kindMemo = {}
function J.kind(id)
  if kindMemo[id] then return kindMemo[id] end
  if NW.IsFish and NW.IsFish(id) then kindMemo[id] = "f" return "f" end
  local classID, subID
  if C_Item and C_Item.GetItemInfoInstant then
    local ok, _, _, _, _, _, c, s = pcall(C_Item.GetItemInfoInstant, id)
    if ok then classID, subID = c, s end
  end
  local _, _, quality = NW.ItemInfo(id)
  -- not in the item cache yet: a best guess, asked again next time
  local sure = classID ~= nil and quality ~= nil
  local k
  if classID == 7 and subID == 8 then k = "f" -- trade goods: cooking (raw fish)
  elseif classID == 2 or classID == 4 then k = "e"
  elseif classID == 1 then k = "c"
  elseif classID == 15 and subID == 0 and quality == 0 then k = "j"
  elseif quality == 0 then k = "j"
  elseif classID == 7 then k = "t"
  elseif classID == 15 then k = "c" -- miscellaneous: lockboxes, crates and other things to open
  elseif classID then k = "o" end
  if k and sure then kindMemo[id] = k end
  return k or "o", sure
end
J.KIND_LABEL = { f = "Fish", t = "Trade goods", e = "Gear", c = "Containers and treasure", j = "Junk", o = "Other" }

------------------------------------------------------------------------
-- Where you are, as precisely as the game says
------------------------------------------------------------------------
function J.where()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not NW.Readable(mapID) then return nil end -- hidden here (an instance, say)
  local x, y
  if C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if ok and pos and pos.GetXY then
      local ok2, a, b = pcall(pos.GetXY, pos)
      if ok2 and NW.Readable(a) and NW.Readable(b) then x, y = a, b end
    end
    if x == 0 and y == 0 then x, y = nil, nil end
  end
  return mapID, x, y
end
function J.zoneName(mapID)
  if not mapID or mapID == 0 then return "Unknown zone" end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name or ("Map " .. mapID)
end

------------------------------------------------------------------------
-- Sessions
------------------------------------------------------------------------
local listeners = {}
function J.OnChange(fn) listeners[#listeners + 1] = fn end
local function changed(what) for _, fn in ipairs(listeners) do pcall(fn, what) end end
J.changed = changed

function J.session() return NW.charDB and NW.charDB.fishSession end
function J.Start()
  local c = NW.charDB
  if not c then return end
  if c.fishSession then return c.fishSession end
  local skill = NW.ProfSkill("fishing")
  c.fishSession = { start = now(), last = now(), active = 0, pausedTotal = 0, fish = 0, other = 0, catches = 0,
    items = {}, zones = {}, skill0 = skill }
  changed("session")
  return c.fishSession
end
function J.Pause()
  local s = J.session()
  if s and not s.pausedAt then s.pausedAt = now(); changed("session") end
end
function J.Resume()
  local s = J.session()
  if s and s.pausedAt then
    s.pausedTotal = s.pausedTotal + (now() - s.pausedAt)
    s.pausedAt = nil
    s.last = now()
    changed("session")
  end
end
function J.Elapsed(s)
  s = s or J.session()
  if not s then return 0 end
  local stop = s.stop or s.pausedAt or now()
  return math.max(0, stop - s.start - (s.pausedTotal or 0))
end
-- what a session's catch is worth at today's prices; partial is true when something has no price
function J.Value(items)
  local v, partial = 0, false
  for id, n in pairs(items or {}) do
    local p, src = NW.Price(id)
    if p and src ~= "est" then v = v + p * n else partial = true end
  end
  return v, partial
end
function J.End(atTime)
  local c = NW.charDB
  local s = c and c.fishSession
  if not s then return end
  if s.pausedAt then J.Resume() end
  local log = J.log()
  s.stop = atTime or now()
  local top, topN = nil, -1
  for m, n in pairs(s.zones) do if n > topN then top, topN = m, n end end
  if (s.catches or 0) > 0 then
    local value, partial = J.Value(s.items)
    log.sessions[#log.sessions + 1] = { start = s.start, stop = s.stop, active = s.active, elapsed = J.Elapsed(s),
      fish = s.fish, other = s.other, catches = s.catches, items = s.items, zone = top, skill0 = s.skill0,
      skill1 = NW.ProfSkill("fishing"), value = value, partial = partial or nil }
    while #log.sessions > SESSIONS_KEPT do table.remove(log.sessions, 1) end
  end
  c.fishSession = nil
  changed("session")
end
function J.DeleteSession(i)
  local log = J.log()
  if log and log.sessions[i] then table.remove(log.sessions, i); changed("sessions") end
end

-- 20 minutes without fishing ends the open session at your last activity
function J.CheckIdle()
  local s = J.session()
  if s and not s.pausedAt and now() - (s.last or now()) > SESSION_END then J.End(s.last) end
end
-- Sessions turned off: the open one ends
function J.SessionsOff() if J.session() then J.End() end end

-- You're fishing: counts toward active time, starts or rolls over the session
function J.Activity()
  if st().fishSessions == false then return end
  local s = J.session()
  local t = now()
  if s and not s.pausedAt and t - (s.last or t) > SESSION_END then
    J.End(s.last)
    s = nil
  end
  if not s and st().fishAutoSession ~= false then s = J.Start() end
  if not s or s.pausedAt then return end
  local gap = t - (s.last or t)
  if gap > 0 and gap <= IDLE_GAP then
    s.active = s.active + gap
    local log = J.log()
    log.time = log.time + gap
    local mapID = J.where()
    if mapID then
      local z = log.zones[mapID]
      if z then z.t = (z.t or 0) + gap end
    end
  end
  s.last = t
end

------------------------------------------------------------------------
-- Recording a catch
------------------------------------------------------------------------
local function notify(text, kind)
  if NW.FishNotify then NW.FishNotify(text, kind) end
end
-- one item from a fishing loot window; newCatch on the first item of that window
function J.Record(id, qty, quality, newCatch)
  if st().fishTrack == false then return end
  local log = J.log()
  if not log or not id then return end
  qty = qty or 1
  local t = now()
  local k, sure = J.kind(id)
  local fish = k == "f"
  local it = log.items[id]
  local discovered = not it
  if not it then it = { n = 0, first = t, k = k }; log.items[id] = it end
  if sure and it.k ~= k then it.k = k end -- a guess made before the item was cached
  it.n, it.last = it.n + qty, t
  if newCatch then log.catches = log.catches + 1 end
  if fish then log.fish = log.fish + qty else log.other = log.other + qty end
  local mapID, x, y = J.where()
  local zk = mapID or 0
  local z = log.zones[zk]
  if not z then z = { n = 0, fish = 0, t = 0, items = {} }; log.zones[zk] = z end
  z.n = z.n + qty
  if fish then z.fish = z.fish + qty end
  z.items[id] = (z.items[id] or 0) + qty
  z.last = t
  -- where, to 2% of the map, only when the game gives a position
  if mapID and x and st().fishTrackSpots ~= false then
    local cells = log.spots[mapID]
    if not cells then cells = { _n = 0 }; log.spots[mapID] = cells end
    local key = ("%d:%d"):format(math.floor(x * 50), math.floor(y * 50))
    local cell = cells[key]
    if not cell and (cells._n or 0) < CELLS_PER_MAP then
      cell = {}
      cells[key] = cell
      cells._n = (cells._n or 0) + 1
    end
    if cell then cell[id] = (cell[id] or 0) + qty end
  end
  -- the last few catches in detail
  local rank = NW.ProfSkill("fishing")
  log.recent[#log.recent + 1] = { id = id, n = qty, map = mapID, x = x and math.floor(x * 1000) / 10 or nil,
    y = y and math.floor(y * 1000) / 10 or nil, t = t, sub = GetSubZoneText and GetSubZoneText() or nil,
    skill = rank, eff = rank and (rank + NW.ProfBonus("fishing")) or nil, lure = NW.FishLureName and NW.FishLureName() or nil }
  while #log.recent > RECENT_KEPT do table.remove(log.recent, 1) end
  -- the session: a long break ends the old one first
  J.Activity()
  local s = J.session()
  if not s and st().fishSessions ~= false and st().fishAutoSession ~= false then s = J.Start() end
  if s and not s.pausedAt then
    if newCatch then s.catches = s.catches + 1 end
    if fish then s.fish = s.fish + qty else s.other = s.other + qty end
    s.items[id] = (s.items[id] or 0) + qty
    s.zones[zk] = (s.zones[zk] or 0) + qty
  end
  -- worth a word: a new fish, or a rare item (the game's own quality)
  local name = NW.ItemName(id) or ("item " .. id)
  if discovered and fish and st().fishNotifyNew ~= false then notify("New fish: " .. name, "new")
  elseif quality and quality >= 3 and st().fishNotifyRare ~= false then notify("Rare catch: " .. name, "rare") end
  changed("catch", id)
end

------------------------------------------------------------------------
-- Attribution
------------------------------------------------------------------------
local FISHING = { [131474] = true, [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true }
J.FISHING_SPELLS = FISHING
local lastStop = -100
local win -- the loot window being watched: { slots = { [slot] = { id, qty, quality } }, catch = false } or { skip = true }

local function fromObject()
  if not GetLootSourceInfo then return false end
  local ok, guid = pcall(GetLootSourceInfo, 1)
  return ok and type(guid) == "string" and guid:find("^GameObject") ~= nil
end
function J.IsFishingWindow()
  if IsFishingLoot then return IsFishingLoot() and true or false end
  return (GetTime() - lastStop) < 4 and fromObject()
end
local function openWindow()
  if win and win.skip then return end
  if not win then
    if not J.IsFishingWindow() then win = { skip = true } return end
    win = { slots = {}, seen = {} }
  end
  -- the second event (LOOT_OPENED after LOOT_READY) fills any slot not ready the first time
  for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
    if win.slots[i] == nil and not win.seen[i] then
    local link = GetLootSlotLink and GetLootSlotLink(i)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then
      local _, _, qty = GetLootSlotInfo(i)
      -- quality from the item itself: the loot slot's return order differs between clients
      local _, _, quality = NW.ItemInfo(id)
      win.slots[i] = { id, tonumber(qty) or 1, tonumber(quality) }
      win.seen[i] = true
    end
    end
  end
end
NW.On("LOOT_READY", openWindow)
NW.On("LOOT_OPENED", openWindow)
NW.On("LOOT_SLOT_CLEARED", function(slot)
  local e = win and win.slots and win.slots[slot]
  if not e then return end
  win.slots[slot] = false -- taken: never counted again
  local first = not win.catch
  win.catch = true
  J.Record(e[1], e[2], e[3], first)
end)
NW.On("LOOT_CLOSED", function() win = nil end)
-- casting, and the end of the channel (the window that follows is the catch)
local function isFishing(spellID, unit)
  -- event values can be hidden from addons in combat: those aren't fishing
  if not (NW.Readable(unit) and NW.Readable(spellID)) then return false end
  if unit ~= "player" then return false end
  if FISHING[spellID] then return true end
  local name = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
  return name ~= nil and NW.FishSpellName and name == NW.FishSpellName()
end
J.isFishing = isFishing
NW.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if isFishing(spellID, unit) then J.Activity() end
end)
NW.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit, _, spellID)
  if isFishing(spellID, unit) then lastStop = GetTime() end
end)
-- a session left open carries over a reload; one idle too long ends at login
table.insert(NW.OnLoad, function()
  local s = NW.charDB and NW.charDB.fishSession
  if s and not s.pausedAt and now() - (s.last or 0) > SESSION_END then J.End(s.last) end
end)

------------------------------------------------------------------------
-- Views: added up across the journals in scope
------------------------------------------------------------------------
function J.Totals(scope)
  local t = { fish = 0, other = 0, catches = 0, time = 0, species = 0, zones = 0, catalog = 0, catalogFound = 0, extra = 0 }
  local items, zones = J.Items(scope), J.Zones(scope)
  for id, e in pairs(items) do
    if e.k == "f" then
      t.species = t.species + 1
      if NW.IsFish and NW.IsFish(id) then t.catalogFound = t.catalogFound + 1 else t.extra = t.extra + 1 end
    end
  end
  for m in pairs(zones) do if m ~= 0 then t.zones = t.zones + 1 end end
  for _, log in ipairs(J.logs(scope)) do
    t.fish, t.other, t.catches, t.time = t.fish + log.fish, t.other + log.other, t.catches + log.catches, t.time + log.time
  end
  local F = NW.FISHING
  t.catalog = F and #F.ORDER or 0
  return t
end
function J.Items(scope)
  local out = {}
  for _, log in ipairs(J.logs(scope)) do
    for id, e in pairs(log.items) do
      local o = out[id]
      if not o then out[id] = { n = e.n, first = e.first, last = e.last, k = e.k }
      else
        o.n = o.n + e.n
        if e.first and (not o.first or e.first < o.first) then o.first = e.first end
        if e.last and (not o.last or e.last > o.last) then o.last = e.last end
      end
    end
  end
  return out
end
function J.Zones(scope)
  local out = {}
  for _, log in ipairs(J.logs(scope)) do
    for m, z in pairs(log.zones) do
      local o = out[m]
      if not o then o = { n = 0, fish = 0, t = 0, items = {} }; out[m] = o end
      o.n, o.fish, o.t = o.n + z.n, o.fish + z.fish, o.t + (z.t or 0)
      if z.last and (not o.last or z.last > o.last) then o.last = z.last end
      for id, n in pairs(z.items) do o.items[id] = (o.items[id] or 0) + n end
    end
  end
  return out
end
-- zones where you caught one item, most first
function J.ZonesFor(id, scope)
  local list = {}
  for m, z in pairs(J.Zones(scope)) do
    local n = z.items[id]
    if n and n > 0 then list[#list + 1] = { map = m, n = n } end
  end
  table.sort(list, function(a, b) return a.n > b.n end)
  return list
end
-- your catch spots in a zone: { x, y (0-1, cell centres), n }, optionally one item
function J.Spots(mapID, scope, id)
  local merged = {}
  for _, log in ipairs(J.logs(scope)) do
    for key, cell in pairs(log.spots[mapID] or {}) do
      if key ~= "_n" then
        local n = 0
        if id then n = cell[id] or 0 else for _, c in pairs(cell) do n = n + c end end
        if n > 0 then merged[key] = (merged[key] or 0) + n end
      end
    end
  end
  local out = {}
  for key, n in pairs(merged) do
    local cx, cy = key:match("^(%d+):(%d+)$")
    out[#out + 1] = { x = (tonumber(cx) + 0.5) / 50, y = (tonumber(cy) + 0.5) / 50, n = n }
  end
  return out
end
