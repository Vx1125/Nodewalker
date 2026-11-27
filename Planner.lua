local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Routes: the zone's known nodes, its route and the controls to build it.
-- A view of the Material Finder tab (no tab of its own): the Finder's Routes
-- button, a proposed route and the old "route" tab key all open it here.
------------------------------------------------------------------------
-- The map is the page: as big as the window allows, in the zone's own
-- colours. "Expand" opens it near full screen for drawing avoid zones.
local SMALL_W, SMALL_H = 735, 490
local MAP_W, MAP_H = SMALL_W, SMALL_H
local SIDE_X, SIDE_W = 16 + SMALL_W + 2 + 18, 1020 - (16 + SMALL_W + 2 + 18) - 16

local refresh
local finder -- the Material Finder's page and refresh, set by Guide.lua
local editorKeep -- Routes' own view, while the editor is opened from the Finder
NW.Routes = NW.Routes or {}
-- the page sits where a tab's page does and takes the Finder's place while open
local page = CreateFrame("Frame", nil, NW.window)
page:SetPoint("TOPLEFT", 0, -UI.CONTENT_TOP)
page:SetPoint("BOTTOMRIGHT")
page:Hide()

local mapFrame = UI.Box(page, MAP_W + 2, MAP_H + 2)
mapFrame:SetPoint("TOPLEFT", 16, -8)
mapFrame:SetClipsChildren(true)
mapFrame:EnableMouse(true)
local mapArt = CreateFrame("Frame", nil, mapFrame)
mapArt:SetPoint("TOPLEFT", 1, -1)
mapArt:SetSize(MAP_W, MAP_H)

local empty = UI.Text(mapFrame, 13, S.dim, "CENTER")
empty:SetPoint("CENTER")

-- one line under the map: what the colours mean, and what to do while drawing
local legend = CreateFrame("Frame", nil, page)
legend:SetPoint("TOPLEFT", mapFrame, "BOTTOMLEFT", 0, -8)
legend:SetSize(SMALL_W, 16)
do
  local x = 0
  for _, e in ipairs({
    { C.herbEdge, "Herbs" }, { C.oreEdge, "Ore" }, { C.picked, "Left out" }, { { 0.84, 0.35, 0.27 }, "Avoid zone" },
  }) do
    local sw = legend:CreateTexture(nil, "ARTWORK")
    sw:SetSize(8, 8)
    sw:SetPoint("LEFT", x, 0)
    sw:SetColorTexture(e[1][1], e[1][2], e[1][3], 1)
    local t = UI.Text(legend, 11, S.dim)
    t:SetPoint("LEFT", sw, "RIGHT", 5, 0)
    t:SetText(e[2])
    x = x + 8 + 5 + t:GetStringWidth() + 16
  end
end
local drawHint = UI.Text(page, 11, S.gold, "RIGHT")
drawHint:SetPoint("TOPRIGHT", mapFrame, "BOTTOMRIGHT", 0, -10)

local tiles = {}
local drawMode, dragStart

-- A proposed gathering route works on its own zone; otherwise the zone you're in
-- NW.routeView: a saved route's zone picked to look at (session only); nil is where you are
local function mapID()
  local d = NW.routeDraft
  if d and d.kind == "nodes" then return d.map end
  return NW.routeView or (NW.PlayerPos())
end

local getDot, resetDots = UI.Pool(function()
  local t = mapArt:CreateTexture(nil, "OVERLAY")
  local mask = mapArt:CreateMaskTexture()
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(t)
  t:AddMaskTexture(mask)
  return t
end)
local getLine, resetLines = UI.Pool(function()
  local l = mapArt:CreateLine(nil, "ARTWORK")
  l:SetThickness(3)
  return l
end)
local getBox, resetBoxes = UI.Pool(function()
  local b = CreateFrame("Frame", nil, mapArt, "BackdropTemplate")
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  b:SetBackdropColor(0.84, 0.25, 0.2, 0.28)
  b:SetBackdropBorderColor(0.95, 0.3, 0.25, 1)
  return b
end)

-- a faint shade so the route reads over bright map art
local shade = mapArt:CreateTexture(nil, "BORDER")
shade:SetAllPoints()
shade:SetColorTexture(0, 0, 0, 0.18)

-- The loop's colour runs gold, teal, blue around the loop, so its order reads at a glance
local function routeColor(t)
  if t < 0.5 then
    local k = t * 2
    return 0.95 + (0.3 - 0.95) * k, 0.8 + (0.78 - 0.8) * k, 0.4 + (0.8 - 0.4) * k
  end
  local k = (t - 0.5) * 2
  return 0.3 + (0.35 - 0.3) * k, 0.78 + (0.5 - 0.78) * k, 0.8 + (0.95 - 0.8) * k
end

local playerDot = mapArt:CreateTexture(nil, "OVERLAY", nil, 7)
playerDot:SetTexture("Interface\\Minimap\\MinimapArrow")
playerDot:SetSize(24, 24)

local function px(x, y) return x * MAP_W, -y * MAP_H end

------------------------------------------------------------------------
-- Drawing avoid zones: one switch, shown on both views
------------------------------------------------------------------------
local avoidButtons = {}
local function setDrawMode(on)
  drawMode = on and true or false
  dragStart = nil
  for _, b in ipairs(avoidButtons) do b:SetText(drawMode and "Done drawing" or "Draw avoid zone") end
  drawHint:SetText(drawMode and "Drag a box over the area to skip. Right-click a box to remove it." or "")
  if NW.BigMapHint then NW.BigMapHint(drawHint:GetText()) end
end

------------------------------------------------------------------------
-- Side panel
------------------------------------------------------------------------
local side = CreateFrame("Frame", nil, page)
side:SetPoint("TOPLEFT", SIDE_X, -8)
side:SetSize(SIDE_W, SMALL_H + 30)

local function s() return NW.db.settings end

local hFilters = UI.Heading(side, "Nodes", SIDE_W)
hFilters:SetPoint("TOPLEFT")
local checks = {
  UI.Check(side, "Herbs", function() return s().includeHerb end, function(v) s().includeHerb = v; refresh() end),
  UI.Check(side, "Ore veins", function() return s().includeOre end, function(v) s().includeOre = v; refresh() end),
  UI.Check(side, "Only ones I can gather", function() return s().onlyGatherable end,
    function(v) s().onlyGatherable = v; refresh() end, "Leaves out herbs and ore above your skill."),
  UI.Check(side, "Only skill-ups", function() return s().onlySkillUps end,
    function(v) s().onlySkillUps = v; refresh() end, "Leaves out grey nodes too."),
}
for i, cb in ipairs(checks) do cb:SetPoint("TOPLEFT", hFilters, "BOTTOMLEFT", 2, -8 - (i - 1) * 23) end

local merge = UI.Slider(side, SIDE_W, "Sight range", 40, 200, 10,
  function(v) return ("%d yd"):format(v) end,
  function() return s().mergeYards end,
  function(v) s().mergeYards = v end,
  "The route only has to pass this close to each node. Optimize loop to apply.")
merge:SetPoint("TOPLEFT", checks[#checks], "BOTTOMLEFT", -2, -12)

local hRoute = UI.Heading(side, "Route", SIDE_W)
hRoute:SetPoint("TOPLEFT", merge, "BOTTOMLEFT", 0, -12)
local stats = UI.Text(side, 12, S.text)
stats:SetPoint("TOPLEFT", hRoute, "BOTTOMLEFT", 0, -8)
stats:SetWidth(SIDE_W)
stats:SetJustifyV("TOP")
stats:SetSpacing(4)
stats:SetHeight(76)

local function optimize()
  local d = NW.routeDraft
  if d and d.kind == "hunt" then NW.Hunt.DraftReverse(d); refresh() return end -- "Reverse loop"
  if d then
    -- a proposal: built with the Material Finder's choice of nodes, not saved until started
    NW.BuildRoute(d.map, function(route)
      if NW.routeDraft == d then d.route = route end
      refresh()
    end, { focus = d.opts.focus, alsoOthers = d.opts.alsoOthers, preview = true })
    refresh()
    return
  end
  local id = mapID()
  if not id then return end
  NW.BuildRoute(id, function() refresh() end)
end
local btnOptimize = UI.Button(side, "Optimize loop", SIDE_W, optimize, 28, "primary")
btnOptimize:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", 0, -8)

local btnAvoid = UI.Button(side, "Draw avoid zone", SIDE_W, function() setDrawMode(not drawMode) end)
btnAvoid:SetPoint("TOPLEFT", btnOptimize, "BOTTOMLEFT", 0, -6)
avoidButtons[#avoidButtons + 1] = btnAvoid
local function clearAvoid()
  local id = mapID()
  if id then NW.ClearAvoid(id); refresh() end
end
local btnClear = UI.Button(side, "Clear avoid zones", SIDE_W, clearAvoid)
btnClear:SetPoint("TOPLEFT", btnAvoid, "BOTTOMLEFT", 0, -6)

local half = (SIDE_W - 6) / 2
-- (GatherMate2 import is in Settings › Routes)
local btnImport = UI.Button(side, "Discard", half, function()
  NW.routeDraft = nil
  refresh()
end)
btnImport:SetPoint("TOPLEFT", btnClear, "BOTTOMLEFT", 0, -6)
UI.Tip(btnImport, "Discard proposal", "Drops the proposed route. Your saved and active routes stay as they are.")
local btnGuide = UI.Button(side, "Materials", half, function()
  -- back to the material the proposed route came from; the proposal stays
  local d = NW.routeDraft
  if d and d.item and NW.FindMaterialAt and NW.FindMaterialAt(d.item, d.src or d.method, d.zone) then return end
  NW.Routes.Close()
end)
UI.Tip(btnGuide, "Materials", "Back to the Material Finder. Routes stay as they are.")

-- Starting a proposal: the only place a proposal replaces the active hunt or the zone's saved route
local function startDraft(d)
  if d.kind == "hunt" then
    if not NW.Hunt.Commit(d) then return false end
    NW.db.settings.huntMap = "route" -- the Material Finder opens on the route, as before
  else
    local route = d.route
    if not route then return false end
    local saved = NW.db.routes[d.map]
    if saved and saved.avoid then route.avoid = saved.avoid end -- keep the zone's avoid zones with it
    NW.db.routes[d.map] = route
    NW.RouteAroundAvoid(d.map)
    NW.ResetProgress(d.map)
    -- Routes then shows the route just started (where you are, if you're there)
    NW.routeView = (NW.PlayerPos()) ~= d.map and d.map or nil
  end
  NW.routeDraft = nil
  return true
end
-- Start makes the route the zone's (or the hunt); the overlay stays as you have it
local btnStart = UI.Button(side, "Start route", SIDE_W, function()
  local d = NW.routeDraft
  if d then
    if not startDraft(d) then return end
  else
    local id = mapID()
    if id then NW.ResetProgress(id) end
  end
  if NW.DrawOverlay then NW.DrawOverlay() end
  refresh()
end, 28, "primary")
btnStart:SetPoint("TOPLEFT", btnGuide, "BOTTOMLEFT", 0, -8)

------------------------------------------------------------------------
-- Expanded map: near full screen, for seeing the ground and drawing zones
------------------------------------------------------------------------
local big = UI.Panel("NodewalkerBigMap", UIParent)
big:SetFrameStrata("DIALOG")
big:SetToplevel(true)
big:EnableMouse(true)
big:Hide()
tinsert(UISpecialFrames, "NodewalkerBigMap") -- Escape closes it
local bigTitle = UI.Text(big, 14, S.gold)
bigTitle:SetPoint("TOPLEFT", 14, -12)
local bigClose = UI.Close(big, function() big:Hide() end)
bigClose:SetPoint("TOPRIGHT", -6, -6)
local bigAvoid = UI.Button(big, "Draw avoid zone", 150, function() setDrawMode(not drawMode) end)
bigAvoid:SetPoint("RIGHT", bigClose, "LEFT", -12, 0)
avoidButtons[#avoidButtons + 1] = bigAvoid
local bigClear = UI.Button(big, "Clear avoid zones", 150, clearAvoid)
bigClear:SetPoint("RIGHT", bigAvoid, "LEFT", -6, 0)
local bigOptimize = UI.Button(big, "Optimize loop", 130, optimize, nil, "primary")
bigOptimize:SetPoint("RIGHT", bigClear, "LEFT", -6, 0)
local bigHint = UI.Text(big, 11, S.gold, "LEFT")
bigHint:SetPoint("LEFT", bigTitle, "RIGHT", 16, 0)
NW.BigMapHint = function(t) bigHint:SetText(t or "") end

local function placeMap(expanded)
  mapFrame:ClearAllPoints()
  if expanded then
    -- as big as the screen allows at the map's own shape, with room for the bar on top
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local w = math.floor(math.min(sw * 0.92, (sh * 0.9 - 44) * SMALL_W / SMALL_H))
    MAP_W, MAP_H = w, math.floor(w * SMALL_H / SMALL_W)
    big:SetSize(MAP_W + 2 + 20, MAP_H + 2 + 54)
    big:ClearAllPoints()
    big:SetPoint("CENTER")
    mapFrame:SetParent(big)
    mapFrame:SetPoint("TOPLEFT", 10, -44)
  else
    MAP_W, MAP_H = SMALL_W, SMALL_H
    mapFrame:SetParent(page)
    mapFrame:SetPoint("TOPLEFT", 16, -8)
  end
  mapFrame:SetSize(MAP_W + 2, MAP_H + 2)
  mapArt:SetSize(MAP_W, MAP_H)
  for _, t in ipairs(tiles) do t:Hide() end
end

local btnExpand = UI.Button(page, "Expand", 70, function()
  placeMap(true)
  big:Show()
  refresh()
end, 22)
btnExpand:SetPoint("TOPRIGHT", mapFrame, "TOPRIGHT", -6, -6)
btnExpand:SetFrameLevel(mapFrame:GetFrameLevel() + 20)

big:SetScript("OnHide", function()
  placeMap(false)
  if editorKeep then NW.routeView = editorKeep.view; editorKeep = nil end
  if page:IsVisible() then refresh()
  elseif finder and finder.page:IsVisible() then finder.refresh() end -- the Finder's map shows what changed
end)

------------------------------------------------------------------------
-- Proposed routes (drafts). The Material Finder's Build buttons send one here
-- (NW.ProposeRoute). It lives for the session only and is never saved, and it
-- holds copies, never the Finder's cached tables. Nothing on the overlay changes
-- until Start.
--   hunt:  { kind = "hunt", item, method, zone, map, stops, spare, opts, custom } (Hunt.lua H.Propose)
--   nodes: { kind = "nodes", item, src, zone, map, opts = { focus, alsoOthers }, route = preview }
------------------------------------------------------------------------
function NW.ProposeRoute(d)
  if not d then return end
  NW.routeDraft = d
  setDrawMode(false)
  NW.ShowRoutes()
  if d.kind == "nodes" then optimize() end -- arrives with its preview building
end

local getNum, resetNums = UI.Pool(function()
  local fs = mapArt:CreateFontString(nil, "OVERLAY")
  fs:SetFont(UI.FONT, 13, "OUTLINE")
  return fs
end, "Routes ground numbers")
local DR = {} -- draft helpers, in one table to keep refresh's upvalues down

-- which controls show: the node controls, or the few a hunting route needs
function DR.mode(d)
  local hunt = d and d.kind == "hunt"
  hFilters:SetShown(not hunt)
  for _, cb in ipairs(checks) do cb:SetShown(not hunt) end
  merge:SetShown(not hunt)
  hRoute:ClearAllPoints()
  if hunt then hRoute:SetPoint("TOPLEFT") else hRoute:SetPoint("TOPLEFT", merge, "BOTTOMLEFT", 0, -12) end
  btnOptimize:SetText(hunt and "Reverse loop" or "Optimize loop")
  -- avoid zones belong to the zone's saved route, so they're edited without a proposal open
  -- (a proposal is built around the ones already there)
  if d and drawMode then setDrawMode(false) end
  btnAvoid:SetShown(not d)
  btnClear:SetShown(not d)
  bigAvoid:SetShown(not d)
  bigClear:SetShown(not d)
  bigOptimize:SetShown(not hunt)
  btnImport:ClearAllPoints()
  btnImport:SetPoint("TOPLEFT", d and btnOptimize or btnClear, "BOTTOMLEFT", 0, -6)
  btnImport:SetShown(d ~= nil)
  btnGuide:ClearAllPoints()
  if d then
    btnGuide:SetWidth(half)
    btnGuide:SetPoint("LEFT", btnImport, "RIGHT", 6, 0)
  else
    btnGuide:SetWidth(SIDE_W)
    btnGuide:SetPoint("TOPLEFT", btnClear, "BOTTOMLEFT", 0, -6)
  end
  btnStart:ClearAllPoints()
  btnStart:SetPoint("TOPLEFT", d and btnImport or btnGuide, "BOTTOMLEFT", 0, -8)
  if NW.Routes.picker then NW.Routes.picker:SetShown(not d) end
  if hunt then
    btnStart:SetText(NW.charDB and NW.charDB.hunt and "Replace active hunt" or "Start hunting route")
  elseif d then
    btnStart:SetText("Save and start route")
  else
    btnStart:SetText("Restart route")
  end
  btnStart:SetEnabled(not d or hunt or d.route ~= nil)
end

local RING_SEG = 28
function DR.ring(g, r, gr, b, a, thick)
  local px0, py0 = px(g.x + g.rx, g.y)
  for k = 1, RING_SEG do
    local ang = k / RING_SEG * 2 * math.pi
    local x2, y2 = px(g.x + math.cos(ang) * g.rx, g.y + math.sin(ang) * g.ry)
    local l = getLine()
    l:SetThickness(thick)
    l:SetColorTexture(r, gr, b, a)
    l:SetStartPoint("TOPLEFT", mapArt, px0, py0)
    l:SetEndPoint("TOPLEFT", mapArt, x2, y2)
    px0, py0 = x2, y2
  end
end

-- the ground under the cursor: list "stops" or "spare", and its index
local LISTS = { "stops", "spare" }
function DR.hit(d, x, y)
  local best, bestList, bestD
  for _, list in ipairs(LISTS) do
    for i, g in ipairs(d[list]) do
      local rx, ry = math.max(g.rx or 0, 10 / MAP_W), math.max(g.ry or 0, 10 / MAP_H)
      local dx, dy = (x - g.x) / rx, (y - g.y) / ry
      local q = dx * dx + dy * dy
      if q <= 1 and (not bestD or q < bestD) then best, bestList, bestD = i, list, q end
    end
  end
  return bestList, best
end

function DR.hunt(d, here, ppx, ppy)
  local id = d.map
  resetNums()
  local info = C_Map.GetMapInfo(id)
  local zoneName = info and info.name or d.zone or "?"
  NW.SetWindowSubtitle(zoneName .. "  ·  proposed hunting route")
  UI.DrawZoneArt(id, mapArt, tiles, MAP_W, MAP_H, true)
  bigTitle:SetText(zoneName)
  empty:SetText("")
  -- grounds left out: faint, click to add
  for _, g in ipairs(d.spare) do DR.ring(g, 0.6, 0.6, 0.6, 0.55, 1.5) end
  local n = #d.stops
  if n > 1 then
    local Cr = C.route
    for i = 1, n do
      local a, b = d.stops[i], d.stops[(i % n) + 1]
      local l = getLine()
      l:SetThickness(2)
      l:SetColorTexture(Cr[1], Cr[2], Cr[3], 0.8)
      l:SetStartPoint("TOPLEFT", mapArt, px(a.x, a.y))
      l:SetEndPoint("TOPLEFT", mapArt, px(b.x, b.y))
    end
  end
  for i, g in ipairs(d.stops) do
    DR.ring(g, 0.84, 0.70, 0.40, 0.9, i == 1 and 2.5 or 1.8)
    local fs = getNum()
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", mapArt, "TOPLEFT", px(g.x, g.y))
    fs:SetText(i)
    fs:SetTextColor(0.91, 0.77, 0.42)
  end
  playerDot:SetShown(here == id)
  if here == id then
    playerDot:ClearAllPoints()
    playerDot:SetPoint("CENTER", mapArt, "TOPLEFT", px(ppx, ppy))
    playerDot:SetRotation(NW.Facing())
  end
  local gold, dim, bad = "|cffd6b266", "|cff938c80", "|cffd17665"
  local e = NW.Mat and NW.Mat.Get(d.item)
  local lines = {}
  lines[#lines + 1] = gold .. "Proposed: " .. (e and e.name or d.label or ("item " .. tostring(d.item))) .. "|r"
    .. dim .. (d.method == "skin" and ", skinning" or ", creature loot") .. "|r"
  local len = NW.Hunt.DraftLength(d)
  lines[#lines + 1] = ("%d ground%s"):format(n, n == 1 and "" or "s") .. (len and len > 0 and ("  ·  %d yd loop"):format(math.floor(len)) or "")
  local active = NW.charDB and NW.charDB.hunt
  if active then
    local ae = NW.Mat and NW.Mat.Get(active.item)
    lines[#lines + 1] = bad .. "Replaces your hunt: " .. (ae and ae.name or "?") .. ", " .. (active.zone or "?") .. "|r"
  else
    lines[#lines + 1] = dim .. "Not active until you start it.|r"
  end
  lines[#lines + 1] = dim .. (d.opts.elites and "Elites and rares in" or "Elites and rares left out")
    .. (d.method == "skin" and d.opts.skill and (", Skinning " .. d.opts.skill) or "") .. "|r"
  stats:SetText(table.concat(lines, "\n"))
  btnOptimize:SetEnabled(n > 2)
  if not drawMode then drawHint:SetText("Click a grey ring to add it; right-click a gold one to leave it out.") end
end

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------
refresh = function()
  if not page:IsVisible() and not big:IsShown() then return end
  resetDots(); resetLines(); resetBoxes()
  local draft = NW.routeDraft
  DR.mode(draft)
  if NW.Routes.pickerText then NW.Routes.pickerText() end
  local id, ppx, ppy = NW.PlayerPos()
  if draft and draft.kind == "hunt" then return DR.hunt(draft, id, ppx, ppy) end
  resetNums()
  if not drawMode then drawHint:SetText("") end
  local viewMap = draft and draft.map or NW.routeView
  if viewMap then
    -- a proposed gathering route, or a saved route picked to look at: its zone, wherever you are
    if id ~= viewMap then ppx, ppy = nil, nil end
    id = viewMap
  end
  if not id then
    NW.SetWindowSubtitle("")
    empty:SetText("Can't read your position here.")
    stats:SetText("")
    btnOptimize:Disable()
    bigOptimize:Disable()
    return
  end
  local info = C_Map.GetMapInfo(id)
  local nodes = NW.db.nodes[id] or {}
  NW.SetWindowSubtitle((info and info.name or "?") .. "  ·  " .. #nodes .. " known nodes")
  UI.DrawZoneArt(id, mapArt, tiles, MAP_W, MAP_H, true)
  bigTitle:SetText(info and info.name or "")
  local st = s()
  local wantedCount = 0
  local saved = NW.db.routes[id]
  local route = saved
  if draft then route = draft.route end -- a proposal shows its preview (none yet while it builds), never the saved route
  local routed = route and #route.stops > 1
  for _, n in ipairs(nodes) do
    if not NW.IsHidden(n.name) then
      local wanted = NW.NodeWanted(n, st)
      if wanted then wantedCount = wantedCount + 1 end
      -- with a route drawn, its stops stand for the nodes on it
      if not (routed and wanted) then
        local d = getDot()
        local col = wanted and (n.kind == "ore" and C.oreEdge or C.herbEdge) or C.picked
        local size = wanted and 6 or 4
        d:SetSize(size, size)
        d:SetColorTexture(col[1], col[2], col[3], wanted and 1 or 0.45)
        d:ClearAllPoints()
        d:SetPoint("CENTER", mapArt, "TOPLEFT", px(n.x, n.y))
      end
    end
  end
  empty:SetText(#nodes == 0 and "No nodes known here yet.\nGather a few, or import GatherMate2 in Settings › Routes." or "")
  btnOptimize:SetEnabled(wantedCount > 0)
  bigOptimize:SetEnabled(wantedCount > 0)

  if route then
    local stops = route.stops
    if #stops > 1 then
      local n = #stops
      local first
      if route == saved and ppx then _, first = NW.NextStop(id, ppx, ppy) end
      first = first or 1
      -- busy routes get finer lines and smaller dots
      local roomy = MAP_W / SMALL_W -- the expanded map draws everything a little larger
      local thick = (n > 200 and 1.5 or (n > 80 and 2 or 3)) * math.min(1.6, roomy)
      local base = (n > 200 and 5 or (n > 80 and 7 or 9)) * math.min(1.5, roomy)
      for k = 0, n - 1 do
        local i = ((first - 1 + k) % n) + 1
        local pts = i == route.open and {} or NW.LegPoints(route, i)
        local r, g, bl = routeColor(k / n)
        for q = 1, #pts - 1 do
          local l = getLine()
          l:SetThickness(thick)
          l:SetColorTexture(r, g, bl, 0.95)
          l:SetStartPoint("TOPLEFT", mapArt, px(pts[q][1], pts[q][2]))
          l:SetEndPoint("TOPLEFT", mapArt, px(pts[q + 1][1], pts[q + 1][2]))
        end
      end
      for i, a in ipairs(stops) do
        local d = getDot()
        local fill = a.kind == "herb" and C.herbEdge or C.oreEdge
        -- a stop with several nodes is a little bigger
        local size = base + math.min(4, (a.count or 1) - 1)
        d:SetSize(size, size)
        d:SetColorTexture(fill[1], fill[2], fill[3], 1)
        d:ClearAllPoints()
        d:SetPoint("CENTER", mapArt, "TOPLEFT", px(a.x, a.y))
      end
    end
  end
  if saved then
    for _, r in ipairs(saved.avoid or {}) do
      local b = getBox()
      local x1, x2 = math.min(r[1], r[3]), math.max(r[1], r[3])
      local y1, y2 = math.min(r[2], r[4]), math.max(r[2], r[4])
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", mapArt, "TOPLEFT", px(x1, y1))
      b:SetSize((x2 - x1) * MAP_W, (y2 - y1) * MAP_H)
    end
  end
  local anyAvoid = saved and saved.avoid and #saved.avoid > 0 or false
  btnClear:SetEnabled(anyAvoid)
  bigClear:SetEnabled(anyAvoid)
  playerDot:SetShown(ppx ~= nil)
  if ppx then
    playerDot:ClearAllPoints()
    playerDot:SetPoint("CENTER", mapArt, "TOPLEFT", px(ppx, ppy))
    playerDot:SetRotation(NW.Facing())
  end

  local gold, dim = "|cffd6b266", "|cff938c80"
  if NW.routeStatus then
    stats:SetText(gold .. NW.routeStatus .. "|r")
  elseif draft and not draft.route then
    local names = {}
    for nm in pairs(draft.opts.focus or {}) do names[#names + 1] = nm end
    stats:SetText(gold .. "Proposed: " .. (#names > 0 and table.concat(names, ", ") or "herbs and ore") .. "|r\n"
      .. dim .. "Press Optimize loop to build the preview." .. (saved and #saved.stops > 1 and " Your saved route here stays until you start the new one." or "") .. "|r")
  elseif route and route.length then
    local herbs, ores = 0, 0
    for _, a in ipairs(route.stops) do herbs = herbs + (a.herbs or 0); ores = ores + (a.ores or 0) end
    local lines = {}
    if route.focus then
      local names = {}
      for n in pairs(route.focus) do names[#names + 1] = n end
      lines[#lines + 1] = gold .. (draft and "Proposed: " or "Route: ") .. table.concat(names, ", ") .. "|r" .. (route.alsoOthers and (dim .. " + others|r") or "")
    end
    lines[#lines + 1] = route.open and ("%d stops  ·  %d yd, there and back"):format(#route.stops, math.floor(route.length))
      or ("%d stops  ·  %d yd loop"):format(#route.stops, math.floor(route.length))
    lines[#lines + 1] = ("%d:%02d %s, 60%% mount"):format(math.floor(route.seconds / 60), math.floor(route.seconds % 60),
      route.open and "each way" or "per loop")
    if route.quick and route.quick > 0 then
      lines[#lines + 1] = dim .. ("%d%% shorter than a quick route"):format(math.floor(100 * (1 - route.length / route.quick) + 0.5)) .. "|r"
    end
    lines[#lines + 1] = dim .. ("%d herb, %d ore spots"):format(herbs, ores) .. "|r"
    if draft and saved and #saved.stops > 1 then
      lines[#lines] = "|cffd17665Starting replaces this zone's saved route.|r"
    end
    stats:SetText(table.concat(lines, "\n"))
  else
    stats:SetText(dim .. "No route here yet.\nPress Optimize loop.|r")
  end
end
NW.RefreshPlanner = function() if page:IsVisible() or big:IsShown() then refresh() end end

-- Hover a stop: which one it is and what's there
local hoverStop
local dragBox = CreateFrame("Frame", nil, mapArt, "BackdropTemplate")
dragBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
dragBox:SetBackdropColor(0.84, 0.25, 0.2, 0.2)
dragBox:SetBackdropBorderColor(1, 0.85, 0.4, 1)
dragBox:Hide()
local cursorOnMap
mapFrame:SetScript("OnUpdate", function(self)
  -- the box follows the cursor while you drag one out
  if drawMode and dragStart and cursorOnMap then
    local x, y = cursorOnMap()
    dragBox:ClearAllPoints()
    dragBox:SetPoint("TOPLEFT", mapArt, "TOPLEFT", px(math.min(x, dragStart[1]), math.min(y, dragStart[2])))
    dragBox:SetSize(math.max(1, math.abs(x - dragStart[1]) * MAP_W), math.max(1, math.abs(y - dragStart[2]) * MAP_H))
    dragBox:Show()
  else
    dragBox:Hide()
  end
  if drawMode or not self:IsMouseOver() then
    if hoverStop then hoverStop = nil; GameTooltip:Hide() end
    return
  end
  local draft = NW.routeDraft
  if draft and draft.kind == "hunt" then
    local list, i = DR.hit(draft, cursorOnMap())
    local key = list and (list == "stops" and i or -i) or nil
    if key == hoverStop then return end
    hoverStop = key
    if not list then GameTooltip:Hide() return end
    local g = draft[list][i]
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    if list == "stops" then
      GameTooltip:SetText(("Ground %d of %d"):format(i, #draft.stops), 1, 0.9, 0.66)
    else
      GameTooltip:SetText("Not on the route", 0.8, 0.8, 0.8)
    end
    local lv = g.minL and (", level " .. g.minL .. ((g.maxL and g.maxL ~= g.minL) and ("-" .. g.maxL) or "")) or ""
    GameTooltip:AddLine(("%d spawn points%s"):format(g.n or 0, lv), 0.85, 0.81, 0.73)
    GameTooltip:AddLine(list == "spare" and "Click: add it"
      or (#draft.stops > 1 and "Right-click: leave it out" or "The only ground on the route"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
    return
  end
  local id, ppx, ppy = NW.PlayerPos()
  local viewMap = draft and draft.map or NW.routeView
  if viewMap then
    if id ~= viewMap then ppx = nil end
    id = viewMap
  end
  local route
  if draft then route = draft.route elseif id then route = NW.db.routes[id] end
  if not (route and #route.stops > 1) then return end
  local cx, cy = GetCursorPosition()
  local scale = mapArt:GetEffectiveScale()
  local mx, my = cx / scale - mapArt:GetLeft(), mapArt:GetTop() - cy / scale
  local best, bestD = nil, 9 * 9
  for i, a in ipairs(route.stops) do
    local dx, dy = a.x * MAP_W - mx, a.y * MAP_H - my
    local d = dx * dx + dy * dy
    if d < bestD then best, bestD = i, d end
  end
  if best == hoverStop then return end
  hoverStop = best
  if not best then GameTooltip:Hide() return end
  local a = route.stops[best]
  local n = #route.stops
  local first
  if not draft and ppx then _, first = NW.NextStop(id, ppx, ppy) end
  local away = first and ((best - first) % n) or nil
  GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
  GameTooltip:SetText(("Stop %d of %d"):format(best, n), 1, 0.9, 0.66)
  local what = {}
  if (a.herbs or 0) > 0 then what[#what + 1] = ("%d herb"):format(a.herbs) end
  if (a.ores or 0) > 0 then what[#what + 1] = ("%d ore"):format(a.ores) end
  if #what > 0 then GameTooltip:AddLine(table.concat(what, ", "), 0.85, 0.81, 0.73) end
  if away then GameTooltip:AddLine(away == 0 and "First on the route" or ("%d stops from now"):format(away), 0.6, 0.6, 0.6) end
  GameTooltip:Show()
end)

-- Drawing avoid zones by dragging on the map
cursorOnMap = function()
  local cx, cy = GetCursorPosition()
  local scale = mapArt:GetEffectiveScale()
  local x = (cx / scale - mapArt:GetLeft()) / MAP_W
  local y = (mapArt:GetTop() - cy / scale) / MAP_H
  return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

mapFrame:SetScript("OnMouseDown", function(_, button)
  local draft = NW.routeDraft
  if draft and draft.kind == "hunt" then
    -- grey ring: add it; right-click a gold one: leave it out
    local list, i = DR.hit(draft, cursorOnMap())
    if list == "spare" and button == "LeftButton" then NW.Hunt.DraftAdd(draft, i)
    elseif list == "stops" and button == "RightButton" then NW.Hunt.DraftRemove(draft, i) end
    hoverStop = nil
    refresh()
    return
  end
  if drawMode and button == "LeftButton" then dragStart = { cursorOnMap() } end
  -- right-click inside an avoid zone removes it (not while a proposal is open: they're the saved route's)
  if button == "RightButton" and not draft then
    local id = mapID()
    local route = id and NW.db.routes[id]
    if not (route and route.avoid) then return end
    local x, y = cursorOnMap()
    for i = #route.avoid, 1, -1 do
      local r = route.avoid[i]
      if x >= math.min(r[1], r[3]) and x <= math.max(r[1], r[3]) and y >= math.min(r[2], r[4]) and y <= math.max(r[2], r[4]) then
        table.remove(route.avoid, i)
        NW.RouteAroundAvoid(id)
        refresh()
        return
      end
    end
  end
end)
mapFrame:SetScript("OnMouseUp", function(_, button)
  if not (drawMode and dragStart and button == "LeftButton") then return end
  local x, y = cursorOnMap()
  local id = mapID()
  if id and math.abs(x - dragStart[1]) > 0.01 and math.abs(y - dragStart[2]) > 0.01 then
    NW.AddAvoid(id, dragStart[1], dragStart[2], x, y)
  end
  dragStart = nil
  refresh()
end)

page:SetScript("OnHide", function()
  if not big:IsShown() then setDrawMode(false) end
end)

------------------------------------------------------------------------
-- Which route to look at: where you are, or any zone with a saved route
-- (on the map's top left). The active hunt opens in the Material Finder.
------------------------------------------------------------------------
local picker = UI.Button(mapFrame, "", 170, nil, 22)
picker:SetPoint("TOPLEFT", 6, -6)
picker:SetFrameLevel(mapFrame:GetFrameLevel() + 20)
picker.label:ClearAllPoints()
picker.label:SetPoint("LEFT", 8, 0)
picker.label:SetPoint("RIGHT", -20, 0)
picker.label:SetJustifyH("LEFT")
picker.label:SetWordWrap(false)
do
  local arrow = picker:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(10, 10)
  arrow:SetPoint("RIGHT", -6, 0)
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetRotation(-math.pi / 2)
  arrow:SetVertexColor(unpack(S.gold))
end
local pickMenu = UI.Panel(nil, UIParent, 240, 10)
pickMenu:SetFrameStrata("FULLSCREEN_DIALOG")
pickMenu:SetClampedToScreen(true)
pickMenu:Hide()
local pickRows = {}
local function zoneName(id)
  local info = C_Map.GetMapInfo(id)
  return info and info.name or ("map " .. id)
end
local function pickItems()
  local items = { { label = "Where I am", fn = function() NW.routeView = nil end } }
  local zones = {}
  for id, r in pairs(NW.db.routes or {}) do
    if type(r) == "table" and r.stops and #r.stops > 1 then zones[#zones + 1] = { id = id, name = zoneName(id), n = #r.stops } end
  end
  table.sort(zones, function(a, b) return a.name < b.name end)
  for _, z in ipairs(zones) do
    items[#items + 1] = { label = z.name, right = z.n .. " stops", fn = function() NW.routeView = z.id end }
  end
  local hunt = NW.charDB and NW.charDB.hunt
  if hunt and hunt.item then
    local e = NW.Mat and NW.Mat.Get(hunt.item)
    items[#items + 1] = { label = "Hunt: " .. (e and e.name or "?"), right = hunt.zone, gold = true, fn = function()
      if not (NW.FindMaterialAt and NW.FindMaterialAt(hunt.item, hunt.method, hunt.zone)) then NW.Routes.Close() end
    end }
  end
  return items
end
picker:SetScript("OnClick", function()
  if pickMenu:IsShown() then pickMenu:Hide() return end
  local items = pickItems()
  for i, it in ipairs(items) do
    local r = pickRows[i]
    if not r then
      r = CreateFrame("Button", nil, pickMenu)
      r:SetHeight(20)
      r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 20)
      r:SetPoint("RIGHT", -1, 0)
      r.text = UI.Text(r, 12, S.text)
      r.text:SetPoint("LEFT", 8, 0)
      r.right = UI.Text(r, 11, S.dim, "RIGHT")
      r.right:SetPoint("RIGHT", -8, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.12)
      pickRows[i] = r
    end
    r.text:SetText(it.label)
    r.text:SetTextColor(unpack(it.gold and S.gold or S.text))
    r.right:SetText(it.right or "")
    r:SetScript("OnClick", function() pickMenu:Hide(); it.fn(); setDrawMode(false); refresh() end)
    r:Show()
  end
  for i = #items + 1, #pickRows do pickRows[i]:Hide() end
  pickMenu:SetSize(240, #items * 20 + 2)
  pickMenu:SetScale(picker:GetEffectiveScale() / UIParent:GetEffectiveScale())
  pickMenu:ClearAllPoints()
  pickMenu:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -2)
  pickMenu:Show()
end)
picker:HookScript("OnHide", function() pickMenu:Hide() end)
UI.Tip(picker, "Routes", "Where you are, or any zone with a saved route.")
NW.Routes.picker = picker
function NW.Routes.pickerText()
  local v = NW.routeView
  picker:SetText(v and zoneName(v) or "Where I am")
end

------------------------------------------------------------------------
-- Opening and closing the view (NW.Routes): the Material Finder's tab calls
-- these. Closing never touches a proposal, a saved route or the active one.
------------------------------------------------------------------------
NW.Routes.page = page
function NW.Routes.Attach(fpage, frefresh) finder = { page = fpage, refresh = frefresh } end
function NW.Routes.Wanted() return NW.db and NW.db.settings.routesOpen end
function NW.Routes.IsOpen() return page:IsVisible() end
-- show the view in place of the Finder (the Finder's tab is the current one)
function NW.Routes.Open()
  NW.db.settings.routesOpen = true
  if finder then finder.page:Hide() end
  page:Show()
  refresh()
  if NW.MaybeImportPrompt then NW.MaybeImportPrompt(page) end
end
-- back to the Finder
function NW.Routes.Close()
  if NW.db then NW.db.settings.routesOpen = nil end
  local was = page:IsShown()
  page:Hide()
  if finder and was and NW.CurrentTab() == "guide" then
    finder.page:Show()
    finder.refresh()
  end
end
-- leaving the Finder's tab: hide the view, remember it was open
function NW.Routes.Leave() page:Hide() end
function NW.Routes.Tick() if page:IsVisible() or big:IsShown() then refresh() end end
-- map: a zone to look at (false: where you are; nil: as it was)
function NW.ShowRoutes(map)
  if map ~= nil then NW.routeView = map or nil end
  NW.db.settings.routesOpen = true
  if NW.window:IsShown() and NW.CurrentTab() == "guide" then NW.Routes.Open()
  elseif NW.window:IsShown() then NW.ShowTab("guide")
  else NW.db.settings.lastTab = "guide"; NW.window:Show() end
end
-- the full-size editor straight away, on a zone's route
function NW.OpenRouteEditor(map)
  -- a proposal elsewhere is open: show it in Routes, where it can be started or discarded
  local d = NW.routeDraft
  if d and (d.kind == "hunt" or d.map ~= map) then NW.ShowRoutes() return end
  -- the zone is looked at only while the editor is open; Routes keeps its own
  if not page:IsVisible() then editorKeep = { view = NW.routeView } end
  if map and not d then NW.routeView = map end
  setDrawMode(false)
  placeMap(true)
  big:Show()
  refresh()
end
-- saved tabs and links to the old Route tab open this view
NW.TAB_ALIAS = NW.TAB_ALIAS or {}
NW.TAB_ALIAS.route = function()
  if NW.db then NW.db.settings.routesOpen = true end
  NW.Routes.keep = true
  return "guide"
end
function NW.TogglePlanner()
  if NW.window:IsShown() and page:IsVisible() then NW.window:Hide() else NW.ShowRoutes() end
end

