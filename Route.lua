local ADDON, NW = ...

local MOUNT_YPS = 11.2 -- yards per second on a 60% mount
NW.MOUNT_YPS = MOUNT_YPS

local function inAvoid(avoid, x, y)
  for _, r in ipairs(avoid or {}) do
    local x1, x2 = math.min(r[1], r[3]), math.max(r[1], r[3])
    local y1, y2 = math.min(r[2], r[4]), math.max(r[2], r[4])
    if x >= x1 and x <= x2 and y >= y1 and y <= y2 then return true end
  end
  return false
end

-- Group nodes closer than mergeYards into one stop.
local function cluster(points, mergeYards)
  local used, stops = {}, {}
  for i, p in ipairs(points) do
    if not used[i] then
      used[i] = true
      local sx, sy, n = p.yx, p.yy, 1
      local herbs, ores = (p.kind == "herb") and 1 or 0, (p.kind == "ore") and 1 or 0
      for j = i + 1, #points do
        if not used[j] then
          local q = points[j]
          local dx, dy = q.yx - p.yx, q.yy - p.yy
          if dx * dx + dy * dy <= mergeYards * mergeYards then
            used[j] = true
            sx, sy, n = sx + q.yx, sy + q.yy, n + 1
            if q.kind == "herb" then herbs = herbs + 1 else ores = ores + 1 end
          end
        end
      end
      local kind = (herbs > 0 and ores > 0) and "mixed" or (herbs > 0 and "herb" or "ore")
      table.insert(stops, { yx = sx / n, yy = sy / n, count = n, kind = kind, herbs = herbs, ores = ores })
    end
  end
  return stops
end

------------------------------------------------------------------------
-- Finding a short loop
--
-- An ant colony search in the style of the Routes addon (our own code):
--  * Several "ants" each build a loop, stepping to nearby stops with odds
--    that favour short steps and steps that good loops used before
--    ("pheromone"). Most steps take the best-looking option outright.
--  * The best loop of each round is cleaned up with 2-opt (uncross two
--    links) and Or-opt (move a run of 1 to 3 stops to a better place),
--    and it lays pheromone for the next round.
--  * It stops when the best loop hasn't improved for a while.
-- Links that cross an avoid zone cost twice their length plus the zone's
-- width, so the loop goes around instead.
-- Everything runs a few milliseconds per frame, so the game never stalls.
------------------------------------------------------------------------
local K_NEAR = 12       -- nearby stops considered at each step
local BETA = 3          -- weight on short steps
local Q0 = 0.9          -- chance of simply taking the best-looking step
local RHO, XI = 0.1, 0.1 -- pheromone evaporation (global, local)
local MAX_ROUNDS, STALE_ROUNDS, MAX_SECONDS = 100, 20, 25

local function segHitsBox(x1, y1, x2, y2, b)
  -- Liang-Barsky clip of the segment against the box
  local t0, t1 = 0, 1
  local dx, dy = x2 - x1, y2 - y1
  local p = { -dx, dx, -dy, dy }
  local q = { x1 - b[1], b[3] - x1, y1 - b[2], b[4] - y1 }
  for i = 1, 4 do
    if p[i] == 0 then
      if q[i] < 0 then return false end
    else
      local r = q[i] / p[i]
      if p[i] < 0 then
        if r > t1 then return false end
        if r > t0 then t0 = r end
      else
        if r < t0 then return false end
        if r < t1 then t1 = r end
      end
    end
  end
  return true
end

local function makeCost(X, Y, boxes, zoneW)
  local N = #X
  local memo = {}
  return function(i, j)
    if i == j then return 0 end
    local key = i < j and (i * N + j) or (j * N + i)
    local c = memo[key]
    if c then return c end
    local dx, dy = X[i] - X[j], Y[i] - Y[j]
    c = math.sqrt(dx * dx + dy * dy)
    for _, b in ipairs(boxes) do
      if segHitsBox(X[i], Y[i], X[j], Y[j], b) then c = c * 2 + zoneW break end
    end
    memo[key] = c
    return c
  end
end

local ops = 0
local function tick(n)
  ops = ops + (n or 1)
  if ops >= 3000 then ops = 0; coroutine.yield() end
end

local function tourCost(t, cost)
  local len = 0
  for i = 1, #t do len = len + cost(t[i], t[(i % #t) + 1]) end
  return len
end

-- nearest K stops for each stop (straight-line)
local function neighbourLists(X, Y)
  local N, near = #X, {}
  for i = 1, N do
    local cand = {}
    for j = 1, N do
      if j ~= i then
        local dx, dy = X[i] - X[j], Y[i] - Y[j]
        cand[#cand + 1] = { j, dx * dx + dy * dy }
      end
    end
    table.sort(cand, function(a, b) return a[2] < b[2] end)
    local list = {}
    for k = 1, math.min(K_NEAR, #cand) do list[k] = cand[k][1] end
    near[i] = list
    tick(N)
  end
  return near
end

local function twoOpt(t, cost, near)
  local N = #t
  local pos = {}
  for i = 1, N do pos[t[i]] = i end
  local improved, passes = true, 0
  while improved and passes < 50 do
    improved, passes = false, passes + 1
    for i = 1, N do
      local a, b = t[i], t[(i % N) + 1]
      local dab = cost(a, b)
      for _, c in ipairs(near[a]) do
        local dac = cost(a, c)
        if dac >= dab then break end
        local j = pos[c]
        local dn = t[(j % N) + 1]
        if c ~= b and dn ~= a then
          local delta = dac + cost(b, dn) - dab - cost(c, dn)
          if delta < -0.01 then
            local lo, hi
            if i < j then lo, hi = i + 1, j else lo, hi = j + 1, i end
            while lo < hi do
              t[lo], t[hi] = t[hi], t[lo]
              pos[t[lo]], pos[t[hi]] = lo, hi
              lo, hi = lo + 1, hi - 1
            end
            improved = true
            break
          end
        end
      end
      tick(K_NEAR)
    end
  end
end

local function orOpt(t, cost, near)
  local N = #t
  if N < 8 then return end
  local pos = {}
  local function reindex() for k = 1, N do pos[t[k]] = k end end
  reindex()
  local improved, passes = true, 0
  while improved and passes < 20 do
    improved, passes = false, passes + 1
    for L = 1, 3 do
      local i = 2
      while i + L <= N do
        local s1, sL = t[i], t[i + L - 1]
        local p, q = t[i - 1], t[i + L]
        local gain = cost(p, s1) + cost(sL, q) - cost(p, q)
        local inSeg = {}
        for k = i, i + L - 1 do inSeg[t[k]] = true end
        local best, bestAt, bestRev
        for _, end_ in ipairs({ s1, sL }) do
          for _, c in ipairs(near[end_]) do
            if not inSeg[c] then
              -- insert between c and the stop after it (in the loop without the run)
              local ci = pos[c]
              local nxt = t[(ci % N) + 1]
              if inSeg[nxt] then nxt = t[((i + L - 1) % N) + 1] end
              if nxt ~= c and not inSeg[nxt] then
                local fwd = cost(c, s1) + cost(sL, nxt) - cost(c, nxt)
                local rev = cost(c, sL) + cost(s1, nxt) - cost(c, nxt)
                local add, r = fwd, false
                if rev < fwd then add, r = rev, true end
                if add < gain - 0.01 and (not best or add < best) then best, bestAt, bestRev = add, c, r end
              end
            end
          end
        end
        tick(2 * K_NEAR)
        if best then
          local run = {}
          for k = i, i + L - 1 do run[#run + 1] = t[k] end
          if bestRev then
            local r2 = {}
            for k = #run, 1, -1 do r2[#r2 + 1] = run[k] end
            run = r2
          end
          local rest = {}
          for k = 1, N do if not inSeg[t[k]] then rest[#rest + 1] = t[k] end end
          local out = {}
          for _, v in ipairs(rest) do
            out[#out + 1] = v
            if v == bestAt then for _, r3 in ipairs(run) do out[#out + 1] = r3 end end
          end
          for k = 1, N do t[k] = out[k] end
          reindex()
          tick(N)
          improved = true
        else
          i = i + 1
        end
      end
    end
  end
end

local function nearestTour(N, cost)
  local seen, t = { [1] = true }, { 1 }
  for _ = 2, N do
    local last, best, bestD = t[#t], nil, math.huge
    for j = 1, N do
      if not seen[j] then
        local d = cost(last, j)
        if d < bestD then best, bestD = j, d end
      end
    end
    seen[best] = true
    t[#t + 1] = best
    tick(N)
  end
  return t
end

-- Returns the best order (list of stop indexes), its length, and the
-- length of the quick nearest-neighbour loop for comparison.
local function optimize(X, Y, boxes, zoneW, report)
  local N = #X
  local cost = makeCost(X, Y, boxes, zoneW)
  if N <= 3 then
    local t = {}
    for i = 1, N do t[i] = i end
    local l = tourCost(t, cost)
    return t, l, l
  end
  local near = neighbourLists(X, Y)
  local best = nearestTour(N, cost)
  local quick = tourCost(best, cost)
  twoOpt(best, cost, near)
  orOpt(best, cost, near)
  local bestLen = tourCost(best, cost)

  local tau0 = 1 / (N * quick)
  local pher = {}
  local function ph(i, j)
    local key = i < j and (i * N + j) or (j * N + i)
    return pher[key] or tau0, key
  end
  local ants = math.min(30, math.ceil(2 * math.sqrt(N)))
  local started, stale = GetTime(), 0

  for round = 1, MAX_ROUNDS do
    local roundBest, roundLen
    for _ = 1, ants do
      local start = math.random(N)
      local seen, t = { [start] = true }, { start }
      for _ = 2, N do
        local cur = t[#t]
        local pick, bestVal, total, choices = nil, -1, 0, {}
        for _, j in ipairs(near[cur]) do
          if not seen[j] then
            local v = ph(cur, j) * (1 / math.max(cost(cur, j), 0.1)) ^ BETA
            choices[#choices + 1] = { j, v }
            total = total + v
            if v > bestVal then pick, bestVal = j, v end
          end
        end
        if pick and math.random() > Q0 then
          local r = math.random() * total
          for _, c in ipairs(choices) do
            r = r - c[2]
            if r <= 0 then pick = c[1] break end
          end
        end
        if not pick then -- every nearby stop is used: take the closest left
          local bd = math.huge
          for j = 1, N do
            if not seen[j] then
              local d = cost(cur, j)
              if d < bd then pick, bd = j, d end
            end
          end
        end
        local p, key = ph(cur, pick)
        pher[key] = (1 - XI) * p + XI * tau0
        seen[pick] = true
        t[#t + 1] = pick
        tick(K_NEAR)
      end
      local len = tourCost(t, cost)
      if not roundLen or len < roundLen then roundBest, roundLen = t, len end
    end
    twoOpt(roundBest, cost, near)
    orOpt(roundBest, cost, near)
    roundLen = tourCost(roundBest, cost)
    if roundLen < bestLen - 0.5 then
      best, bestLen, stale = roundBest, roundLen, 0
    else
      stale = stale + 1
    end
    for i = 1, N do
      local a, b = best[i], best[(i % N) + 1]
      local p, key = ph(a, b)
      pher[key] = (1 - RHO) * p + RHO / bestLen
    end
    if report then report(round, bestLen) end
    if stale >= STALE_ROUNDS or GetTime() - started > MAX_SECONDS then break end
  end
  return best, bestLen, quick
end

local runner = CreateFrame("Frame")
local job

runner:SetScript("OnUpdate", function()
  if not job then runner:Hide() return end
  local started = debugprofilestop()
  while job and debugprofilestop() - started < 8 do
    local res = { coroutine.resume(job.co) }
    if not res[1] then
      NW.Print("route error: " .. tostring(res[2]))
      NW.routeStatus = nil
      job = nil
    elseif coroutine.status(job.co) == "dead" then
      local done = job
      job = nil
      done.finish(unpack(res, 2))
    end
  end
end)
runner:Hide()

-- Build and save the route for a zone. callback(route) when finished.
-- opts.focus = { [herb name] = true }: build only through those herbs (the
-- Farm Guide's routes). opts.alsoOthers: also take any other node your
-- filters allow.
function NW.BuildRoute(mapID, callback, opts)
  local s = NW.db.settings
  opts = opts or {}
  local focus = opts.focus
  local w, h = NW.MapSize(mapID)
  if not w then
    NW.Print("This map has no size the game can measure, so a route can't be built here.")
    return
  end
  local existing = NW.db.routes[mapID]
  local avoid = existing and existing.avoid or {}
  local points = {}
  for _, node in ipairs(NW.db.nodes[mapID] or {}) do
    local want
    if focus and focus[node.name] then
      want = true -- picked on purpose, even if hidden
    elseif focus and not opts.alsoOthers then
      want = false
    else
      want = NW.NodeWanted(node, s)
    end
    if want and not inAvoid(avoid, node.x, node.y) then
      points[#points + 1] = { yx = node.x * w, yy = node.y * h, kind = node.kind }
    end
  end
  if #points == 0 then
    if focus then
      NW.Print("No known spots for that herb in this zone. Import from GatherMate2 with /nw import, or gather a few first.")
    else
      NW.Print("No nodes match your filters in this zone yet. Gather a few, or import from GatherMate2 with /nw import.")
    end
    return
  end
  local stops = cluster(points, s.mergeYards)
  local X, Y = {}, {}
  for i, st in ipairs(stops) do X[i], Y[i] = st.yx, st.yy end
  local boxes = {}
  for _, r in ipairs(avoid) do
    boxes[#boxes + 1] = { math.min(r[1], r[3]) * w, math.min(r[2], r[4]) * h, math.max(r[1], r[3]) * w, math.max(r[2], r[4]) * h }
  end
  NW.routeStatus = ("Optimizing %d stops..."):format(#stops)
  job = {
    co = coroutine.create(function()
      return optimize(X, Y, boxes, w, function(round, len)
        NW.routeStatus = ("Optimizing %d stops: round %d, best %d yd"):format(#stops, round, math.floor(len))
      end)
    end),
    finish = function(order, len, quick)
      local route = { stops = {}, avoid = avoid, built = time(), focus = focus, alsoOthers = opts.alsoOthers }
      for _, idx in ipairs(order) do
        local st = stops[idx]
        table.insert(route.stops, { x = st.yx / w, y = st.yy / h, kind = st.kind, count = st.count, herbs = st.herbs, ores = st.ores })
      end
      route.length = len
      route.quick = quick
      route.seconds = len / MOUNT_YPS
      route.nodes = #points
      NW.db.routes[mapID] = route
      NW.ResetProgress(mapID)
      NW.routeStatus = nil
      if callback then callback(route) end
    end,
  }
  runner:Show()
end

-- A newly learned node joins the zone's route: merged into a stop that's
-- close enough, or slotted in where it adds the least distance (cheapest
-- insertion, as Routes does).
function NW.InsertIntoRoute(mapID, node)
  local route = NW.db.routes[mapID]
  if not route or #route.stops < 2 then return end
  local s = NW.db.settings
  if route.focus and not route.focus[node.name] and not route.alsoOthers then
    return -- a single-herb route only grows with that herb
  end
  if not (route.focus and route.focus[node.name]) and not NW.NodeWanted(node, s) then
    return
  end
  if inAvoid(route.avoid, node.x, node.y) then return end
  local w, h = NW.MapSize(mapID)
  if not w then return end
  local function d(a, b)
    local dx, dy = (a.x - b.x) * w, (a.y - b.y) * h
    return math.sqrt(dx * dx + dy * dy)
  end
  local stops = route.stops
  for _, st in ipairs(stops) do
    if d(st, node) <= s.mergeYards then
      st.count = (st.count or 1) + 1
      if node.kind == "herb" then st.herbs = (st.herbs or 0) + 1 else st.ores = (st.ores or 0) + 1 end
      return
    end
  end
  local bestI, bestAdd
  for i = 1, #stops do
    local a, b = stops[i], stops[(i % #stops) + 1]
    local add = d(a, node) + d(node, b) - d(a, b)
    if not bestAdd or add < bestAdd then bestI, bestAdd = i, add end
  end
  local pos = bestI + 1
  table.insert(stops, pos, { x = node.x, y = node.y, kind = node.kind, count = 1,
    herbs = node.kind == "herb" and 1 or 0, ores = node.kind == "ore" and 1 or 0 })
  route.length = (route.length or 0) + bestAdd
  route.seconds = route.length / MOUNT_YPS
  -- shift anything keyed by stop number at or after the new one
  local prog = NW.progress[mapID]
  if prog then
    if prog.index >= pos then prog.index = prog.index + 1 end
    if prog.startIndex and prog.startIndex >= pos then prog.startIndex = prog.startIndex + 1 end
    local moved = {}
    for k, v in pairs(prog.visited) do moved[k >= pos and k + 1 or k] = v end
    prog.visited = moved
  end
  local shifted = {}
  local prefix = mapID .. ":"
  for k, v in pairs(NW.seenStop) do
    local m, si = k:match("^(%d+):(%d+)$")
    if m and tonumber(m) == mapID and tonumber(si) >= pos then
      shifted[prefix .. (tonumber(si) + 1)] = v
      NW.seenStop[k] = nil
    end
  end
  for k, v in pairs(shifted) do NW.seenStop[k] = v end
end

function NW.AddAvoid(mapID, x1, y1, x2, y2)
  NW.db.routes[mapID] = NW.db.routes[mapID] or { stops = {}, avoid = {} }
  table.insert(NW.db.routes[mapID].avoid, { x1, y1, x2, y2 })
end

function NW.ClearAvoid(mapID)
  if NW.db.routes[mapID] then NW.db.routes[mapID].avoid = {} end
end

------------------------------------------------------------------------
-- Following a route
------------------------------------------------------------------------
NW.progress = {} -- [mapID] = { index = current stop, visited = { [i] = GetTime() }, startIndex }

function NW.ResetProgress(mapID)
  NW.progress[mapID] = nil
end

-- The stop to head for next, picking up at the nearest stop the first time.
function NW.NextStop(mapID, px, py)
  local route = NW.db.routes[mapID]
  if not route or #route.stops == 0 then return nil end
  local prog = NW.progress[mapID]
  if not prog then
    local best, bestD = 1, math.huge
    for i, st in ipairs(route.stops) do
      local d = NW.Yards(mapID, px, py, st.x, st.y) or math.huge
      if d < bestD then best, bestD = i, d end
    end
    prog = { index = best, visited = {}, startIndex = best }
    NW.progress[mapID] = prog
    NW.session.loopStarted = NW.session.loopStarted or GetTime()
  end
  return route.stops[prog.index], prog.index, #route.stops
end

local function advance(mapID)
  local route, prog = NW.db.routes[mapID], NW.progress[mapID]
  if not route or not prog then return end
  local now = GetTime()
  local respawn = NW.db.settings.respawnMinutes * 60
  prog.visited[prog.index] = now
  -- Move on, skipping stops picked too recently to have respawned.
  for _ = 1, #route.stops do
    prog.index = (prog.index % #route.stops) + 1
    if prog.index == prog.startIndex then
      NW.session.loops = NW.session.loops + 1
      if NW.session.loopStarted then NW.session.lastLoopTime = now - NW.session.loopStarted end
      NW.session.loopStarted = now
    end
    local seen = prog.visited[prog.index]
    if not seen or now - seen >= respawn then break end
  end
end

function NW.SkipNext()
  local mapID = NW.PlayerPos()
  if mapID and NW.progress[mapID] then advance(mapID) end
end

-- Called often by the overlay: move on once you're at the stop.
function NW.UpdateProgress(mapID, px, py)
  local st = NW.NextStop(mapID, px, py)
  if not st then return end
  local d = NW.Yards(mapID, px, py, st.x, st.y)
  if d and d <= NW.db.settings.arriveYards then advance(mapID) end
end

-- Gathering at a stop also counts as reaching it.
table.insert(NW.gatherListeners, function(mapID, _, x, y)
  local route, prog = NW.db.routes[mapID], NW.progress[mapID]
  if not route or not prog then return end
  local st = route.stops[prog.index]
  local d = st and NW.Yards(mapID, x, y, st.x, st.y)
  if d and d <= NW.db.settings.mergeYards then advance(mapID) end
end)
