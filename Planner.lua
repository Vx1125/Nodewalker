local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Route tab: the zone's known nodes, its route and the controls to build it
------------------------------------------------------------------------
local MAP_W, MAP_H = 660, 440
local SIDE_X, SIDE_W = 16 + MAP_W + 22, 300

local refresh
local page = UI.AddTab("route", "Route", function() refresh() end, nil, function() refresh() end)

local mapFrame = UI.Box(page, MAP_W + 2, MAP_H + 2)
mapFrame:SetPoint("TOPLEFT", 16, -8)
mapFrame:SetClipsChildren(true)
mapFrame:EnableMouse(true)
local mapArt = CreateFrame("Frame", nil, mapFrame)
mapArt:SetPoint("TOPLEFT", 1, -1)
mapArt:SetSize(MAP_W, MAP_H)

local empty = UI.Text(mapFrame, 13, S.dim, "CENTER")
empty:SetPoint("CENTER")

-- legend under the map
local legend = CreateFrame("Frame", nil, page)
legend:SetPoint("TOPLEFT", mapFrame, "BOTTOMLEFT", 0, -8)
legend:SetSize(MAP_W, 16)
do
  local x = 0
  for _, e in ipairs({
    { C.herbEdge, "Herbs" }, { C.oreEdge, "Ore" }, { C.picked, "Left out" },
    { { 0.95, 0.8, 0.4 }, "Route: gold first" }, { { 0.35, 0.5, 0.95 }, "blue last" },
    { { 0.84, 0.35, 0.27 }, "Avoid zone" },
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

local function mapID() return (NW.PlayerPos()) end

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
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropColor(0.84, 0.35, 0.27, 0.15)
  b:SetBackdropBorderColor(0.84, 0.35, 0.27, 0.9)
  return b
end)

-- a light shade over the map art so the route stands out
local shade = mapArt:CreateTexture(nil, "BORDER")
shade:SetAllPoints()
shade:SetColorTexture(0, 0, 0, 0.35)

-- The loop's colour runs gold, teal, blue from your next stop, so its order reads at a glance
local function routeColor(t)
  if t < 0.5 then
    local k = t * 2
    return 0.95 + (0.3 - 0.95) * k, 0.8 + (0.78 - 0.8) * k, 0.4 + (0.8 - 0.4) * k
  end
  local k = (t - 0.5) * 2
  return 0.3 + (0.35 - 0.3) * k, 0.78 + (0.5 - 0.78) * k, 0.8 + (0.95 - 0.8) * k
end

local nextRing = mapArt:CreateTexture(nil, "ARTWORK", nil, 7)
nextRing:SetColorTexture(1, 0.84, 0.47, 0.4)
nextRing:SetSize(26, 26)
do
  local mask = mapArt:CreateMaskTexture()
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(nextRing)
  nextRing:AddMaskTexture(mask)
end

local playerDot = mapArt:CreateTexture(nil, "OVERLAY", nil, 7)
playerDot:SetTexture("Interface\\Minimap\\MinimapArrow")
playerDot:SetSize(24, 24)

local function px(x, y) return x * MAP_W, -y * MAP_H end

------------------------------------------------------------------------
-- Side panel
------------------------------------------------------------------------
local side = CreateFrame("Frame", nil, page)
side:SetPoint("TOPLEFT", SIDE_X, -8)
side:SetSize(SIDE_W, MAP_H + 30)

local function s() return NW.db.settings end

local hFilters = UI.Heading(side, "Nodes in the route", SIDE_W)
hFilters:SetPoint("TOPLEFT")
local checks = {
  UI.Check(side, "Herbs", function() return s().includeHerb end, function(v) s().includeHerb = v; refresh() end),
  UI.Check(side, "Ore veins", function() return s().includeOre end, function(v) s().includeOre = v; refresh() end),
  UI.Check(side, "Only nodes I can gather", function() return s().onlyGatherable end,
    function(v) s().onlyGatherable = v; refresh() end, "Leaves out herbs and ore above your skill."),
  UI.Check(side, "Only nodes that give skill-ups", function() return s().onlySkillUps end,
    function(v) s().onlySkillUps = v; refresh() end, "Leaves out grey nodes too."),
}
for i, cb in ipairs(checks) do cb:SetPoint("TOPLEFT", hFilters, "BOTTOMLEFT", 2, -10 - (i - 1) * 24) end

local merge = UI.Slider(side, SIDE_W, "Sight range", 40, 200, 10,
  function(v) return ("%d yd"):format(v) end,
  function() return s().mergeYards end,
  function(v) s().mergeYards = v end,
  "The route only has to pass this close to each node. Optimize loop to apply.")
merge:SetPoint("TOPLEFT", checks[#checks], "BOTTOMLEFT", -2, -14)

local hRoute = UI.Heading(side, "This route", SIDE_W)
hRoute:SetPoint("TOPLEFT", merge, "BOTTOMLEFT", 0, -16)
local stats = UI.Text(side, 12, S.text)
stats:SetPoint("TOPLEFT", hRoute, "BOTTOMLEFT", 0, -8)
stats:SetWidth(SIDE_W)
stats:SetJustifyV("TOP")
stats:SetSpacing(4)
stats:SetHeight(92)

local btnOptimize = UI.Button(side, "Optimize loop", SIDE_W, function()
  local id = mapID()
  if not id then return end
  NW.BuildRoute(id, function() refresh() end)
end, 28, "primary")
btnOptimize:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", 0, -10)
UI.Tip(btnOptimize, "Optimize loop", "Builds the shortest loop through every node your filters allow in this zone.")

local half = (SIDE_W - 6) / 2
local btnAvoid
btnAvoid = UI.Button(side, "Draw avoid zone", half, function()
  drawMode = not drawMode
  btnAvoid:SetText(drawMode and "Done drawing" or "Draw avoid zone")
  drawHint:SetText(drawMode and "Drag a box on the map to mark an area to skip" or "")
end)
btnAvoid:SetPoint("TOPLEFT", btnOptimize, "BOTTOMLEFT", 0, -6)
local btnClear = UI.Button(side, "Clear avoid zones", half, function()
  local id = mapID()
  if id then NW.ClearAvoid(id); refresh() end
end)
btnClear:SetPoint("LEFT", btnAvoid, "RIGHT", 6, 0)

local btnImport = UI.Button(side, "Import GatherMate2", half, function() NW.ImportGatherMate2(); refresh() end)
btnImport:SetPoint("TOPLEFT", btnAvoid, "BOTTOMLEFT", 0, -6)
UI.Tip(btnImport, "Import GatherMate2", "Copies GatherMate2's herb and ore spots (and its data pack) into Nodewalker.")
local btnGuide = UI.Button(side, "Farm Guide", half, function() NW.ShowTab("guide") end)
btnGuide:SetPoint("LEFT", btnImport, "RIGHT", 6, 0)

local btnStart = UI.Button(side, "Start route on overlay", SIDE_W, function()
  NW.db.settings.overlayShown = true
  local id = mapID()
  if id then NW.ResetProgress(id) end
  NW.UpdateVisibility()
  NW.window:Hide()
end, 28, "primary")
btnStart:SetPoint("TOPLEFT", btnImport, "BOTTOMLEFT", 0, -10)

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------
refresh = function()
  if not page:IsShown() then return end
  resetDots(); resetLines(); resetBoxes()
  local id, ppx, ppy = NW.PlayerPos()
  if not id then
    NW.SetWindowSubtitle("")
    empty:SetText("Can't read your position here.")
    stats:SetText("")
    btnOptimize:Disable()
    return
  end
  local info = C_Map.GetMapInfo(id)
  local nodes = NW.db.nodes[id] or {}
  NW.SetWindowSubtitle((info and info.name or "?") .. "  ·  " .. #nodes .. " known nodes")
  UI.DrawZoneArt(id, mapArt, tiles, MAP_W, MAP_H)
  local st = s()
  local wantedCount = 0
  local routed = NW.db.routes[id] and #NW.db.routes[id].stops > 1
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
  empty:SetText(#nodes == 0 and "No nodes known here yet.\nImport GatherMate2, or gather a few." or "")
  btnOptimize:SetEnabled(wantedCount > 0)

  local route = NW.db.routes[id]
  if route then
    local stops = route.stops
    nextRing:Hide()
    if #stops > 1 then
      local n = #stops
      local _, first = NW.NextStop(id, ppx, ppy)
      first = first or 1
      -- busy routes get finer lines and smaller dots
      local thick = n > 200 and 1.5 or (n > 80 and 2 or 3)
      local base = n > 200 and 5 or (n > 80 and 7 or 9)
      for k = 0, n - 1 do
        local i = ((first - 1 + k) % n) + 1
        local a, b = stops[i], stops[(i % n) + 1]
        local l = getLine()
        l:SetThickness(thick)
        local r, g, bl = routeColor(k / n)
        l:SetColorTexture(r, g, bl, 0.95)
        l:SetStartPoint("TOPLEFT", mapArt, px(a.x, a.y))
        l:SetEndPoint("TOPLEFT", mapArt, px(b.x, b.y))
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
      nextRing:ClearAllPoints()
      nextRing:SetPoint("CENTER", mapArt, "TOPLEFT", px(stops[first].x, stops[first].y))
      nextRing:Show()
    end
    for _, r in ipairs(route.avoid or {}) do
      local b = getBox()
      local x1, x2 = math.min(r[1], r[3]), math.max(r[1], r[3])
      local y1, y2 = math.min(r[2], r[4]), math.max(r[2], r[4])
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", mapArt, "TOPLEFT", px(x1, y1))
      b:SetSize((x2 - x1) * MAP_W, (y2 - y1) * MAP_H)
    end
  end
  if not route then nextRing:Hide() end
  btnClear:SetEnabled(route and route.avoid and #route.avoid > 0 or false)
  playerDot:ClearAllPoints()
  playerDot:SetPoint("CENTER", mapArt, "TOPLEFT", px(ppx, ppy))
  playerDot:SetRotation(NW.Facing())

  local gold, dim = "|cffe8c46a", "|cff94949a"
  if NW.routeStatus then
    stats:SetText(gold .. NW.routeStatus .. "|r")
  elseif route and route.length then
    local herbs, ores = 0, 0
    for _, a in ipairs(route.stops) do herbs = herbs + (a.herbs or 0); ores = ores + (a.ores or 0) end
    local lines = {}
    if route.focus then
      local names = {}
      for n in pairs(route.focus) do names[#names + 1] = n end
      lines[#lines + 1] = gold .. "Route: " .. table.concat(names, ", ") .. "|r" .. (route.alsoOthers and (dim .. " + others|r") or "")
    end
    lines[#lines + 1] = ("%d stops  ·  %d yd loop"):format(#route.stops, math.floor(route.length))
    lines[#lines + 1] = ("About %d:%02d per loop on a 60%% mount"):format(math.floor(route.seconds / 60), math.floor(route.seconds % 60))
    if route.quick and route.quick > 0 then
      lines[#lines + 1] = dim .. ("%d%% shorter than a quick route"):format(math.floor(100 * (1 - route.length / route.quick) + 0.5)) .. "|r"
    end
    lines[#lines + 1] = dim .. ("%d herb, %d ore spots"):format(herbs, ores) .. "|r"
    stats:SetText(table.concat(lines, "\n"))
  else
    stats:SetText(dim .. "No route in this zone yet.\nPress Optimize loop, or pick a herb or ore in the Farm Guide.|r")
  end
end
NW.RefreshPlanner = function() if page:IsShown() then refresh() end end

-- Hover a stop: which one it is and what's there
local hoverStop
mapFrame:SetScript("OnUpdate", function(self)
  if drawMode or not self:IsMouseOver() then
    if hoverStop then hoverStop = nil; GameTooltip:Hide() end
    return
  end
  local id, ppx, ppy = NW.PlayerPos()
  local route = id and NW.db.routes[id]
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
  local _, first = NW.NextStop(id, ppx, ppy)
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
local function cursorOnMap()
  local cx, cy = GetCursorPosition()
  local scale = mapArt:GetEffectiveScale()
  local x = (cx / scale - mapArt:GetLeft()) / MAP_W
  local y = (mapArt:GetTop() - cy / scale) / MAP_H
  return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

mapFrame:SetScript("OnMouseDown", function(_, button)
  if drawMode and button == "LeftButton" then dragStart = { cursorOnMap() } end
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
  drawMode = false
  dragStart = nil
  btnAvoid:SetText("Draw avoid zone")
  drawHint:SetText("")
end)

function NW.TogglePlanner() NW.ToggleWindow("route") end

------------------------------------------------------------------------
-- The route on the world map
------------------------------------------------------------------------
do
  local layer, lines, drawn
  local function draw()
    local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
      or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
    if not canvas then return end
    if not layer then
      layer = CreateFrame("Frame", nil, canvas)
      layer:SetAllPoints(canvas)
      layer:SetFrameLevel(canvas:GetFrameLevel() + 60) -- over the map art, under the game's pins
      lines = {}
    end
    local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local route = mapID and NW.db.routes[mapID]
    local on = NW.db.settings.routeOnWorldMap ~= false and route and #route.stops > 1
    local W, H = canvas:GetSize()
    -- only redraw when something changed
    local sig = on and ("%d:%s:%d:%d"):format(mapID, tostring(route.built), #route.stops, W) or "off"
    if sig == drawn then return end
    drawn = sig
    for _, l in ipairs(lines) do l:Hide() end
    if not on then return end
    for i, a in ipairs(route.stops) do
      local b = route.stops[i % #route.stops + 1]
      local l = lines[i]
      if not l then
        l = layer:CreateLine(nil, "OVERLAY")
        lines[i] = l
      end
      l:SetColorTexture(0.35, 0.86, 0.92, 0.9)
      l:SetThickness(math.max(1.5, W / 420))
      l:SetStartPoint("TOPLEFT", layer, a.x * W, -a.y * H)
      l:SetEndPoint("TOPLEFT", layer, b.x * W, -b.y * H)
      l:Show()
    end
  end
  -- The world map loads when first opened; a small driver on it redraws
  -- while it's showing.
  local driver
  local function hook()
    if driver or not WorldMapFrame then return driver ~= nil end
    driver = CreateFrame("Frame", nil, WorldMapFrame)
    local wait = 0
    driver:SetScript("OnUpdate", function(_, dt)
      wait = wait - dt
      if wait > 0 then return end
      wait = 0.3
      pcall(draw)
    end)
    return true
  end
  local tries = CreateFrame("Frame")
  local t = 0
  tries:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if t < 1 then return end
    t = 0
    if hook() then self:SetScript("OnUpdate", nil) end
  end)
  function NW.RefreshWorldMapRoute() drawn = nil end
end
