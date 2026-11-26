local _, NW = ...

------------------------------------------------------------------------
-- Gathering log: materials you collected, and how.
--
-- Attribution (fishing stays with the Fishing Journal):
--   skin   a loot window from a creature within 3 s of your Skinning cast
--   herb   from a game object within 3 s of your Herb Gathering cast
--   ore    from a game object within 3 s of your Mining cast
--   loot   from a creature with no Skinning cast before it (ordinary loot)
-- Anything else (chests, containers, mail, trades, vendors, the bank,
-- crafting, pick pocketing) never comes through here. Without
-- GetLootSourceInfo, only windows right after a gathering cast count, with no
-- creature. Items count as their slot empties (LOOT_SLOT_CLEARED): autoloot
-- and manual loot alike, once each, nothing for loot left behind.
-- Only materials: Material Finder's catalog or the game's Trade Goods.
--
-- Storage, per character (charDB.gatherLog, v = 1), aggregated:
--   items[id] = { n, first, last, m = { skin, loot, herb, ore } }
--   npcs[npc] = { skin, loot (windows), items = { [id] = n } }   at most 1500 creatures
--   zones[mapID] = { n, items = { [id] = n } }
--   spots[mapID][cell] = { [id] = n }   2% cells, at most 400 per map
--   events = { skin, loot, herb, ore }  loot windows
--   recent = last 100
------------------------------------------------------------------------
local GL = {}
NW.GatherLog = GL
local RECENT_KEPT, CELLS_PER_MAP, NPCS_KEPT, WINDOW = 100, 400, 1500, 3

local function upgrade(l)
  l.v = l.v or 1
  l.items, l.npcs, l.zones, l.spots, l.recent = l.items or {}, l.npcs or {}, l.zones or {}, l.spots or {}, l.recent or {}
  l.events = l.events or {}
  l.nNpcs = l.nNpcs or 0
  return l
end
function GL.log()
  local c = NW.charDB
  if not c then return nil end
  c.gatherLog = upgrade(c.gatherLog or {})
  return c.gatherLog
end
function GL.logs(scope)
  local out = {}
  if scope == "all" then
    for _, c in pairs(NW.db.chars or {}) do
      if type(c) == "table" and type(c.gatherLog) == "table" then out[#out + 1] = upgrade(c.gatherLog) end
    end
  else
    local l = GL.log()
    if l then out[1] = l end
  end
  return out
end

------------------------------------------------------------------------
-- Casts
------------------------------------------------------------------------
local SPELLS = {
  skin = { 8613, 8617, 8618, 10768 },
  herb = { 2366, 2368, 3570, 11993 },
  ore = { 2575, 2576, 3564, 10248 },
  pick = { 921 },
}
local kindOf, nameKind = {}, nil
for k, ids in pairs(SPELLS) do for _, id in ipairs(ids) do kindOf[id] = k end end
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id))
end
local function castKind(spellID)
  if kindOf[spellID] then return kindOf[spellID] end
  if not nameKind or not nameKind._full then
    nameKind = nameKind or {}
    local all = true
    for k, ids in pairs(SPELLS) do
      local n = spellName(ids[1])
      if n then nameKind[n] = k else all = false end
    end
    nameKind._full = all -- names not cached yet: ask again next time
  end
  local n = spellName(spellID)
  return n and nameKind[n]
end
GL.castKind = castKind
local last = { kind = nil, t = -100 }
NW.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if not (NW.Readable(unit) and NW.Readable(spellID)) or unit ~= "player" then return end
  local k = castKind(spellID)
  if k then last.kind, last.t = k, GetTime() end
end)

local function npcOf(guid)
  if type(guid) ~= "string" then return nil, nil end
  -- Creature-0-server-instance-zone-npcID-spawn
  local kind = guid:match("^(%a+)%-")
  local id = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  return kind, tonumber(id)
end
-- what a loot window is: method, creature (nil when unknown)
function GL.Classify(slot)
  local recent = (GetTime() - last.t) <= WINDOW and last.kind or nil
  local guid
  if GetLootSourceInfo then
    local ok, g = pcall(GetLootSourceInfo, slot or 1)
    if ok and NW.Readable(g) then guid = g end
  end
  local kind, npc = npcOf(guid)
  if recent == "pick" then return nil end
  if not GetLootSourceInfo then
    if recent and recent ~= "pick" then return recent, nil end
    return nil
  end
  if kind == "Creature" or kind == "Vehicle" then
    if recent == "skin" then return "skin", npc end
    return "loot", npc
  end
  if kind == "GameObject" and (recent == "herb" or recent == "ore") then return recent, nil end
  return nil
end

local function isMaterial(id)
  if NW.Mat and NW.Mat.Get(id) then return true end
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if fn then
    local ok, _, _, _, _, _, classID = pcall(fn, id)
    return ok and classID == 7
  end
  return false
end
GL.isMaterial = isMaterial

------------------------------------------------------------------------
-- Recording
------------------------------------------------------------------------
local listeners = {}
function GL.OnChange(fn) listeners[#listeners + 1] = fn end
local function changed(id) for _, fn in ipairs(listeners) do pcall(fn, id) end end

function GL.Record(id, qty, method, npc, newWindow)
  if NW.db.settings.gatherTrack == false then return end
  local l = GL.log()
  if not (l and id and method) then return end
  qty = qty or 1
  local t = time()
  local it = l.items[id]
  if not it then it = { n = 0, first = t, m = {} }; l.items[id] = it end
  it.n, it.last = it.n + qty, t
  it.m[method] = (it.m[method] or 0) + qty
  if newWindow then l.events[method] = (l.events[method] or 0) + 1 end
  if npc then
    local c = l.npcs[npc]
    if not c and l.nNpcs < NPCS_KEPT then c = { items = {} }; l.npcs[npc] = c; l.nNpcs = l.nNpcs + 1 end
    if c then
      if newWindow then c[method] = (c[method] or 0) + 1 end
      c.items[id] = (c.items[id] or 0) + qty
    end
  end
  local mapID, x, y
  if NW.FishJournal then mapID, x, y = NW.FishJournal.where() end
  local zk = mapID or 0
  local z = l.zones[zk]
  if not z then z = { n = 0, items = {} }; l.zones[zk] = z end
  z.n = z.n + qty
  z.items[id] = (z.items[id] or 0) + qty
  if mapID and x then
    local cells = l.spots[mapID]
    if not cells then cells = { _n = 0 }; l.spots[mapID] = cells end
    local key = ("%d:%d"):format(math.floor(x * 50), math.floor(y * 50))
    local cell = cells[key]
    if not cell and cells._n < CELLS_PER_MAP then cell = {}; cells[key] = cell; cells._n = cells._n + 1 end
    if cell then cell[id] = (cell[id] or 0) + qty end
  end
  l.recent[#l.recent + 1] = { id = id, n = qty, m = method, npc = npc, map = mapID, t = t }
  while #l.recent > RECENT_KEPT do table.remove(l.recent, 1) end
  -- this session (the overlay's session panel)
  local s = NW.session
  if s then
    s.mats = s.mats or {}
    s.mats[id] = (s.mats[id] or 0) + qty
    if newWindow then s.events = s.events or {}; s.events[method] = (s.events[method] or 0) + 1 end
    -- herbs and ore are valued from the loot message (Nodes.lua); creature materials here
    -- (within a few seconds of a node, Nodes.lua values every loot message itself)
    if (method == "skin" or method == "loot") and NW.Price and not (s.lootUntil and GetTime() <= s.lootUntil) then
      local price, from = NW.Price(id)
      if price and (from == "ah" or from == "vendor") then s.value = (s.value or 0) + price * qty end
    end
  end
  changed(id)
end

local win
local function openWindow()
  if win and win.skip then return end
  if not win then
    if NW.FishJournal and NW.FishJournal.IsFishingWindow() then win = { skip = true } return end
    local method = GL.Classify(1)
    if not method then win = { skip = true } return end
    win = { method = method, slots = {}, seen = {} }
    -- the cast belongs to this window only: the next corpse within the
    -- window is ordinary loot, not another skin (and a failed skin can't leak)
    if method ~= "loot" then last.kind = nil end
  end
  for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
    if not win.seen[i] then
      local link = GetLootSlotLink and GetLootSlotLink(i)
      local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
      if id then
        win.seen[i] = true
        if isMaterial(id) then
          local _, _, qty = GetLootSlotInfo(i)
          local _, npc = GL.Classify(i)
          win.slots[i] = { id, tonumber(qty) or 1, win.method, npc }
        end
      end
    end
  end
end
NW.On("LOOT_READY", openWindow)
NW.On("LOOT_OPENED", openWindow)
NW.On("LOOT_SLOT_CLEARED", function(slot)
  local e = win and win.slots and win.slots[slot]
  if not e then return end
  win.slots[slot] = false
  local first = not win.counted
  win.counted = true
  GL.Record(e[1], e[2], e[3], e[4], first)
end)
NW.On("LOOT_CLOSED", function() win = nil end)

------------------------------------------------------------------------
-- Views
------------------------------------------------------------------------
-- totals for an item: n, by method (fishing from the Fishing Journal)
function GL.Item(id, scope)
  local o = { n = 0, m = {} }
  for _, l in ipairs(GL.logs(scope)) do
    local it = l.items[id]
    if it then
      o.n = o.n + it.n
      for k, v in pairs(it.m) do o.m[k] = (o.m[k] or 0) + v end
      if it.last and (not o.last or it.last > o.last) then o.last = it.last end
    end
  end
  local FJ = NW.FishJournal
  if FJ then
    local f = FJ.Items(scope)[id]
    if f and f.n > 0 then o.n = o.n + f.n; o.m.fish = (o.m.fish or 0) + f.n end
  end
  return o
end
function GL.Events(scope)
  local e = {}
  for _, l in ipairs(GL.logs(scope)) do for k, v in pairs(l.events) do e[k] = (e[k] or 0) + v end end
  return e
end
function GL.ZoneCount(mapID, id, scope)
  local n = 0
  for _, l in ipairs(GL.logs(scope)) do
    local z = l.zones[mapID]
    if z then n = n + (id and (z.items[id] or 0) or z.n) end
  end
  return n
end
function GL.ZonesFor(id, scope)
  local by = {}
  for _, l in ipairs(GL.logs(scope)) do
    for m, z in pairs(l.zones) do
      local n = z.items[id]
      if n and n > 0 then by[m] = (by[m] or 0) + n end
    end
  end
  local FJ = NW.FishJournal
  if FJ then for _, z in ipairs(FJ.ZonesFor(id, scope)) do by[z.map] = (by[z.map] or 0) + z.n end end
  local out = {}
  for m, n in pairs(by) do out[#out + 1] = { map = m, n = n } end
  table.sort(out, function(a, b) return a.n > b.n end)
  return out
end
-- your spots in a zone for an item: { x, y, n } (cell centres)
function GL.Spots(mapID, id, scope)
  local merged = {}
  for _, l in ipairs(GL.logs(scope)) do
    for key, cell in pairs(l.spots[mapID] or {}) do
      if key ~= "_n" then
        local n = id and (cell[id] or 0) or 0
        if not id then for _, c in pairs(cell) do n = n + c end end
        if n > 0 then merged[key] = (merged[key] or 0) + n end
      end
    end
  end
  local out = {}
  for key, n in pairs(merged) do
    local cx, cy = key:match("^(%d+):(%d+)$")
    out[#out + 1] = { x = (tonumber(cx) + 0.5) / 50, y = (tonumber(cy) + 0.5) / 50, n = n }
  end
  local FJ = NW.FishJournal
  if FJ and id and NW.IsFish and NW.IsFish(id) then
    for _, s in ipairs(FJ.Spots(mapID, scope, id)) do out[#out + 1] = s end
  end
  return out
end
-- what one creature has given you: windows by method, items
function GL.Npc(npc, scope)
  local o = { skin = 0, loot = 0, items = {} }
  for _, l in ipairs(GL.logs(scope)) do
    local c = l.npcs[npc]
    if c then
      o.skin, o.loot = o.skin + (c.skin or 0), o.loot + (c.loot or 0)
      for id, n in pairs(c.items) do o.items[id] = (o.items[id] or 0) + n end
    end
  end
  return o
end
function GL.Session(id)
  local s = NW.session
  return s and s.mats and s.mats[id] or 0
end
