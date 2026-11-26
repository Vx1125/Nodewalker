local _, NW = ...

------------------------------------------------------------------------
-- Hunting Grounds: where creatures that give a material live, for any
-- creature material (skinning loot or ordinary loot: leather, cloth, meat,
-- elementals, reagents).
--
-- Data: Materials/SourceData.lua (Classic 1.12: pfQuest spawns and loot
-- chances, cMaNGOS skinning loot). Known spawns are where a creature has
-- spawned, not creatures that are alive now.
--
--   density   each known spawn point (1% of the map) counts its creature's
--             chance for the material (0.6 for a 60% drop). Spawns of
--             several creatures add up. Bins are 3% of the map.
--   clusters  the densest bin starts a hunting ground; bins within 6% join
--             it; repeat. Grounds with under 3 spawn points are left out.
--   routes    nearest ground first, then nearest next, improved by 2-opt;
--             straight-line distances, not paths.
-- Progress is yours to move: arriving marks a ground "here", never done.
------------------------------------------------------------------------
local H = {}
NW.Hunt = H

local BIN = 3          -- % of the map per density bin
local JOIN = 2         -- bins from a seed that join its ground
local MIN_SPAWNS = 3   -- spawn points a ground needs
local MAX_GROUNDS = 8  -- per zone
local MAX_STOPS = 6    -- per route

H.TYPE = { "Beast", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Humanoid", "Critter", "Mechanical" }
H.RANK = { [1] = "Elite", [2] = "Rare elite", [3] = "Boss", [4] = "Rare" }

local function src() return NW.SRC end

-- Skinning skill a creature needs, by WoW Classic's rule (WoW Forever may differ)
function H.SkinReq(level)
  if not level then return nil end
  if level <= 10 then return 1 end
  if level <= 20 then return (level - 10) * 10 end
  return level * 5
end

function H.Unit(npc)
  local u = src() and src().units[npc]
  if not u then return nil end
  return { npc = npc, name = u[1], min = u[2], max = u[3], type = u[4], rank = u[5], fac = u[6], respawn = u[7], skin = u[8] }
end

-- Creatures that give an item: { npc, chance (%), min, max, method }
function H.Sources(id, method)
  local d = src() and src().items[id]
  local out = {}
  if not d then return out end
  if method ~= "loot" then
    local t = d.skin
    for i = 1, #t, 4 do out[#out + 1] = { npc = t[i], chance = t[i + 1], min = t[i + 2], max = t[i + 3], method = "skin" } end
  end
  if method ~= "skin" then
    local t = d.loot
    for i = 1, #t, 2 do out[#out + 1] = { npc = t[i], chance = t[i + 1], method = "loot" } end
  end
  return out
end
function H.Has(id, method)
  local d = src() and src().items[id]
  if not d then return false end
  if method == "skin" then return #d.skin > 0 end
  if method == "loot" then return #d.loot > 0 end
  return #d.skin + #d.loot > 0
end

-- Who a filter leaves in, and why one is out
local myFaction
local function faction()
  if not myFaction then
    local f = UnitFactionGroup and UnitFactionGroup("player")
    myFaction = f == "Alliance" and "A" or f == "Horde" and "H" or ""
  end
  return myFaction
end
function H.Why(u, method, opts)
  opts = opts or {}
  local f = faction()
  if f ~= "" and u.fac and u.fac:find(f, 1, true) then return "friendly" end
  if not opts.elites and u.rank and u.rank > 0 then return "elite" end
  if method == "skin" and opts.skill then
    local req = H.SkinReq(u.max)
    if req and req > opts.skill then return "skill" end
  end
  if opts.level and u.min and u.min > opts.level + (opts.levelOver or 99) then return "level" end
  return nil
end

------------------------------------------------------------------------
-- Grounds for one material: zones, each with density bins and clusters
------------------------------------------------------------------------
local cache = {}
local function optsKey(o)
  o = o or {}
  return ("%s:%s:%s:%s"):format(tostring(o.skill), tostring(o.elites), tostring(o.level), tostring(o.levelOver))
end

local function decode(str, fn)
  for i = 1, #str, 4 do
    fn(tonumber(str:sub(i, i + 1)), tonumber(str:sub(i + 2, i + 3)))
  end
end

local function clusterZone(z, mapID)
  local bins = {}
  for _, b in pairs(z.bins) do bins[#bins + 1] = b end
  table.sort(bins, function(a, b) return a.w > b.w end)
  local w, h = NW.MapSize(mapID or 0)
  local grounds = {}
  for _, seed in ipairs(bins) do
    if not seed.g then
      local g = { w = 0, n = 0, sx = 0, sy = 0, npcs = {}, cells = {} }
      for _, b in ipairs(bins) do
        if not b.g and math.abs(b.bx - seed.bx) <= JOIN and math.abs(b.by - seed.by) <= JOIN then
          b.g = g
          g.w, g.n, g.sx, g.sy = g.w + b.w, g.n + b.n, g.sx + b.sx, g.sy + b.sy
          for npc, n in pairs(b.npcs) do g.npcs[npc] = (g.npcs[npc] or 0) + n end
          for _, c in ipairs(b.cells) do g.cells[#g.cells + 1] = c end
        end
      end
      if g.n >= MIN_SPAWNS then
        g.x, g.y = g.sx / g.w / 100, g.sy / g.w / 100
        -- radius: the furthest spawn point from the centre (map fractions, x and y)
        local r = 0
        for _, c in ipairs(g.cells) do
          local dx, dy = c[1] - g.x, c[2] - g.y
          if w and h then dx, dy = dx * w, dy * h end
          r = math.max(r, math.sqrt(dx * dx + dy * dy))
        end
        if w and h then
          g.yards = math.max(40, r + 0.01 * w)
          g.rx, g.ry = g.yards / w, g.yards / h
        else
          g.rx, g.ry = math.max(0.03, r + 0.01), math.max(0.03, r + 0.01)
        end
        -- levels, skill and respawn of what lives there
        local lo, hi, rs = 999, 0, {}
        for npc in pairs(g.npcs) do
          local u = H.Unit(npc)
          if u then
            lo, hi = math.min(lo, u.min or lo), math.max(hi, u.max or hi)
            if u.respawn and u.respawn > 0 then rs[#rs + 1] = u.respawn end
          end
        end
        g.minL, g.maxL = lo < 999 and lo or nil, hi > 0 and hi or nil
        table.sort(rs)
        g.respawn = rs[math.ceil(#rs / 2)]
        g.cells = nil
        grounds[#grounds + 1] = g
      else
        z.scattered = (z.scattered or 0) + g.n
      end
      if #grounds >= MAX_GROUNDS then break end
    end
  end
  for _, b in ipairs(bins) do b.g = nil end
  z.grounds = grounds
end

-- { zones = { { name, mapID, w, n, npcs = { [npc] = spawns }, bins, grounds, minL, maxL, out = { why = n } } }, total }
function H.Grounds(id, method, opts)
  local S = src()
  if not S then return { zones = {} } end
  local key = id .. ":" .. (method or "any") .. ":" .. optsKey(opts)
  if cache[key] then return cache[key] end
  local zones, out = {}, {}
  for _, s in ipairs(H.Sources(id, method)) do
    local u = H.Unit(s.npc)
    local why = "nodata"
    if u then why = H.Why(u, s.method, opts) end
    local sp = S.spawns[s.npc]
    if why then
      out[why] = (out[why] or 0) + 1
    elseif sp then
      local p = s.chance / 100
      for i = 1, #sp, 2 do
        local zname = S.zones[sp[i]]
        local z = zones[zname]
        if not z then
          z = { name = zname, w = 0, n = 0, npcs = {}, bins = {}, lo = 999, hi = 0 }
          zones[zname] = z
        end
        z.lo, z.hi = math.min(z.lo, u.min or 999), math.max(z.hi, u.max or 0)
        decode(sp[i + 1], function(x, y)
          local bk = math.floor(x / BIN) * 100 + math.floor(y / BIN)
          local b = z.bins[bk]
          if not b then
            b = { bx = math.floor(x / BIN), by = math.floor(y / BIN), w = 0, n = 0, sx = 0, sy = 0, npcs = {}, cells = {} }
            z.bins[bk] = b
          end
          b.w, b.n = b.w + p, b.n + 1
          b.sx, b.sy = b.sx + (x + 0.5) * p, b.sy + (y + 0.5) * p
          b.npcs[s.npc] = (b.npcs[s.npc] or 0) + 1
          b.cells[#b.cells + 1] = { (x + 0.5) / 100, (y + 0.5) / 100 }
          z.w, z.n = z.w + p, z.n + 1
          z.npcs[s.npc] = (z.npcs[s.npc] or 0) + 1
        end)
      end
    end
  end
  local list = {}
  for _, z in pairs(zones) do
    z.mapID = NW.ZoneID and NW.ZoneID(z.name)
    z.minL, z.maxL = z.lo < 999 and z.lo or nil, z.hi > 0 and z.hi or nil
    clusterZone(z, z.mapID)
    list[#list + 1] = z
  end
  table.sort(list, function(a, b) return a.w > b.w end)
  local r = { zones = list, out = out }
  cache[key] = r
  return r
end
function H.ClearCache() cache = {} end

-- Sorting zones; each says what it's based on
H.SORTS = {
  { "density", "Most spawns", "Known spawn points weighted by drop chance (Classic data). Not creatures alive now." },
  { "level", "Nearest my level", "Zones whose creatures are closest to your level." },
  { "mine", "My history", "Where you've collected it most. Shows only zones you've farmed." },
}
function H.Sort(zones, by, id)
  local lvl = UnitLevel and UnitLevel("player") or 1
  local sorted = {}
  for i, z in ipairs(zones) do sorted[i] = z end
  local mine = {}
  if by == "mine" and NW.GatherLog then
    for _, z in ipairs(sorted) do mine[z] = z.mapID and NW.GatherLog.ZoneCount(z.mapID, id) or 0 end
  end
  local function fit(z)
    if not z.minL then return 99 end
    if lvl >= z.minL and lvl <= z.maxL then return 0 end
    return math.min(math.abs(lvl - z.minL), math.abs(lvl - z.maxL))
  end
  table.sort(sorted, function(a, b)
    if by == "level" then
      local fa, fb = fit(a), fit(b)
      if fa ~= fb then return fa < fb end
    elseif by == "mine" then
      if mine[a] ~= mine[b] then return mine[a] > mine[b] end
    end
    return a.w > b.w
  end)
  return sorted
end

------------------------------------------------------------------------
-- Routes: { item, method, zone, map, stops = { { x, y, rx, ry, w, n, npcs } }, cur, state, at, made }
------------------------------------------------------------------------
local function charHunt() return NW.charDB and NW.charDB.hunt end
function H.Route() return charHunt() end

local function yards(mapID, a, b)
  return NW.Yards(mapID, a.x, a.y, b.x, b.y) or math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) * 1000
end
local function tour(mapID, pts, start)
  local n = #pts
  local order, used = { start }, { [start] = true }
  for _ = 2, n do
    local cur, best, bd = order[#order], nil, math.huge
    for j = 1, n do
      if not used[j] then
        local d = yards(mapID, pts[cur], pts[j])
        if d < bd then best, bd = j, d end
      end
    end
    used[best] = true
    order[#order + 1] = best
  end
  -- 2-opt on a closed loop (a handful of stops: exhaustive passes are cheap)
  local improved = n > 3
  while improved do
    improved = false
    for i = 2, n - 1 do
      for k = i + 1, n do
        local a, b = pts[order[i - 1]], pts[order[i]]
        local c, d = pts[order[k]], pts[order[(k % n) + 1]]
        local before = yards(mapID, a, b) + yards(mapID, c, d)
        local after = yards(mapID, a, c) + yards(mapID, b, d)
        if after < before - 1 then
          for q = 0, math.floor((k - i) / 2) do order[i + q], order[k - q] = order[k - q], order[i + q] end
          improved = true
        end
      end
    end
  end
  return order
end

-- Picks the grounds worth a stop (at least a third of the best one's
-- density, at most six) and orders them from where you are.
function H.Plan(z)
  local g = z.grounds or {}
  if #g == 0 then return {} end
  local best = g[1].w
  local pick = {}
  for _, x in ipairs(g) do
    if x.w >= best / 3 and #pick < MAX_STOPS then pick[#pick + 1] = x end
  end
  local start = 1
  local here, px, py = NW.PlayerPos()
  if here and here == z.mapID then
    local bd = math.huge
    for i, x in ipairs(pick) do
      local d = yards(z.mapID, { x = px, y = py }, x)
      if d < bd then start, bd = i, d end
    end
  end
  local order = tour(z.mapID, pick, start)
  local out = {}
  for _, i in ipairs(order) do out[#out + 1] = pick[i] end
  return out
end
-- loop length in yards (straight lines), nil without the map's size
function H.Length(mapID, stops)
  if #stops < 2 or not NW.MapSize(mapID or 0) then return #stops == 1 and 0 or nil end
  local len = 0
  for i = 1, #stops do len = len + yards(mapID, stops[i], stops[(i % #stops) + 1]) end
  return len
end

function H.Start(id, method, z, opts)
  local stops = H.Plan(z)
  if #stops == 0 or not NW.charDB then return end
  local saved = {}
  for _, g in ipairs(stops) do
    local npcs = {}
    for npc in pairs(g.npcs) do npcs[#npcs + 1] = npc end
    saved[#saved + 1] = { x = g.x, y = g.y, rx = g.rx, ry = g.ry, w = g.w, n = g.n, npcs = npcs, respawn = g.respawn, minL = g.minL, maxL = g.maxL }
  end
  NW.charDB.hunt = { item = id, method = method, zone = z.name, map = z.mapID, stops = saved, cur = 1, state = {}, at = {}, made = time() }
  H.Changed()
  if NW.DrawOverlay then NW.DrawOverlay() end
  return NW.charDB.hunt
end
function H.Stop()
  if NW.charDB then NW.charDB.hunt = nil end
  H.Changed()
  if NW.DrawOverlay then NW.DrawOverlay() end
end
-- Next: the current ground counts as hunted, the next becomes current
function H.Advance(skip)
  local r = charHunt()
  if not r then return end
  r.state[r.cur] = skip and "skipped" or "hunted"
  r.at[r.cur] = time()
  r.cur = (r.cur % #r.stops) + 1
  r.state[r.cur] = nil
  H.Changed()
  if NW.DrawOverlay then NW.DrawOverlay() end
end
function H.Select(i)
  local r = charHunt()
  if not r or not r.stops[i] then return end
  r.cur = i
  r.state[i] = nil
  H.Changed()
  if NW.DrawOverlay then NW.DrawOverlay() end
end
-- the ground you're standing in, if any
function H.Here()
  local r = charHunt()
  if not r then return nil end
  local mapID, px, py = NW.PlayerPos()
  if mapID ~= r.map then return nil end
  for i, s in ipairs(r.stops) do
    local dx, dy = (px - s.x) / s.rx, (py - s.y) / s.ry
    if dx * dx + dy * dy <= 1 then return i end
  end
end
-- state of a stop: current, here, hunted, skipped, upcoming
function H.State(i)
  local r = charHunt()
  if not r then return nil end
  if i == r.cur then return "current" end
  return r.state[i] or "upcoming"
end
-- seconds until a hunted ground's creatures are back, by the Classic respawn times
function H.Revisit(i)
  local r = charHunt()
  local s = r and r.stops[i]
  if not (s and r.at[i] and s.respawn and s.respawn > 0) then return nil end
  return math.max(0, s.respawn - (time() - r.at[i]))
end

local listeners = {}
function H.OnChange(fn) listeners[#listeners + 1] = fn end
function H.Changed() for _, fn in ipairs(listeners) do pcall(fn) end end
-- the skinning skill and level change what's in: start the sums again
NW.On("SKILL_LINES_CHANGED", function() H.ClearCache() end)
NW.On("PLAYER_LEVEL_UP", function() H.ClearCache() end)

------------------------------------------------------------------------
-- Overlay: hunting grounds as rings, the route between their centres.
-- Called from Overlay.lua's rebuild (not every frame).
------------------------------------------------------------------------
local RING_SEG = 28
local labels, nLabels = {}, 0
function H.DrawOverlay(mapID, api)
  nLabels = 0
  local r = charHunt()
  if r and r.map == mapID and NW.db.settings.huntOverlay ~= false then
    local toView, onScreen, getLine, pan = api.toView, api.onScreen, api.getLine, api.pan
    local cur = r.cur
    local function ring(s, cr, cg, cb, a, thick)
      for k = 1, RING_SEG do
        local a1, a2 = (k - 1) / RING_SEG * 2 * math.pi, k / RING_SEG * 2 * math.pi
        local x1, y1 = toView(s.x + math.cos(a1) * s.rx, s.y + math.sin(a1) * s.ry)
        local x2, y2 = toView(s.x + math.cos(a2) * s.rx, s.y + math.sin(a2) * s.ry)
        if onScreen(x1, y1) or onScreen(x2, y2) then
          local l = getLine()
          l:SetThickness(thick)
          l:SetColorTexture(cr, cg, cb, a)
          l.under:SetThickness(thick + 2)
          l.under:SetColorTexture(0, 0, 0, a * 0.4)
          l:SetStartPoint("CENTER", pan, x1, y1)
          l:SetEndPoint("CENTER", pan, x2, y2)
          l.under:SetStartPoint("CENTER", pan, x1, y1)
          l.under:SetEndPoint("CENTER", pan, x2, y2)
        end
      end
    end
    -- legs: bright cyan to the current ground, muted for the rest
    local n = #r.stops
    if n > 1 then
      for i = 1, n do
        local a, b = r.stops[i], r.stops[(i % n) + 1]
        local ax, ay = toView(a.x, a.y)
        local bx, by = toView(b.x, b.y)
        if onScreen(ax, ay) or onScreen(bx, by) then
          local toCur = (i % n) + 1 == cur
          local l = getLine()
          local C = NW.COLORS.route
          l:SetThickness(toCur and 3 or 2)
          l:SetColorTexture(C[1], C[2], C[3], toCur and 0.9 or 0.35)
          l.under:SetThickness(toCur and 5 or 3.5)
          l.under:SetColorTexture(0, 0, 0, toCur and 0.45 or 0.2)
          l:SetStartPoint("CENTER", pan, ax, ay)
          l:SetEndPoint("CENTER", pan, bx, by)
          l.under:SetStartPoint("CENTER", pan, ax, ay)
          l.under:SetEndPoint("CENTER", pan, bx, by)
        end
      end
    end
    for i, s in ipairs(r.stops) do
      local st = H.State(i)
      if st == "current" then ring(s, 0.84, 0.70, 0.40, 0.85, 2.5)        -- muted gold
      elseif st == "upcoming" then ring(s, 0.66, 0.55, 0.36, 0.45, 1.5)   -- bronze
      else ring(s, 0.5, 0.5, 0.5, 0.3, 1.2) end                           -- hunted or skipped
      local vx, vy = toView(s.x, s.y)
      if onScreen(vx, vy) then
        nLabels = nLabels + 1
        local fs = labels[nLabels]
        if not fs then
          fs = pan:CreateFontString(nil, "OVERLAY")
          fs:SetFont(NW.UI.FONT, 13, "OUTLINE")
          labels[nLabels] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", pan, "CENTER", vx, vy)
        fs:SetText(i)
        if st == "current" then fs:SetTextColor(0.91, 0.77, 0.42) elseif st == "upcoming" then fs:SetTextColor(0.85, 0.81, 0.73) else fs:SetTextColor(0.55, 0.55, 0.55) end
        fs:Show()
      end
    end
  end
  for k = nLabels + 1, #labels do labels[k]:Hide() end
end
