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
    { C.herbEdge, "Herbs" }, { C.oreEdge, "Ore" }, { C.picked, "Left out by your filters" },
    { C.route, "Route" }, { { 0.84, 0.35, 0.27 }, "Avoid zone" },
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

local merge = UI.Slider(side, SIDE_W, "Merge nodes closer than", 20, 150, 5,
  function(v) return ("%d yd"):format(v) end,
  function() return s().mergeYards end,
  function(v) s().mergeYards = v end,
  "Nodes this close together become one stop.")
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
local btnGuide = UI.Button(side, "Herb Guide", half, function() NW.ShowTab("guide") end)
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
  for _, n in ipairs(nodes) do
    if not NW.IsHidden(n.name) then
      local d = getDot()
      local wanted = NW.NodeWanted(n, st)
      if wanted then wantedCount = wantedCount + 1 end
      local col = wanted and (n.kind == "ore" and C.oreEdge or C.herbEdge) or C.picked
      d:SetSize(7, 7)
      d:SetColorTexture(col[1], col[2], col[3], wanted and 1 or 0.6)
      d:ClearAllPoints()
      d:SetPoint("CENTER", mapArt, "TOPLEFT", px(n.x, n.y))
    end
  end
  empty:SetText(#nodes == 0 and "No nodes known here yet.\nImport GatherMate2, or gather a few." or "")
  btnOptimize:SetEnabled(wantedCount > 0)

  local route = NW.db.routes[id]
  if route then
    local stops = route.stops
    if #stops > 1 then
      for i = 1, #stops do
        local a, b = stops[i], stops[(i % #stops) + 1]
        local l = getLine()
        l:SetColorTexture(C.route[1], C.route[2], C.route[3], 0.95)
        l:SetStartPoint("TOPLEFT", mapArt, px(a.x, a.y))
        l:SetEndPoint("TOPLEFT", mapArt, px(b.x, b.y))
      end
      for _, a in ipairs(stops) do
        local d = getDot()
        local fill = a.kind == "herb" and C.herbFill or C.oreFill
        d:SetSize(12, 12)
        d:SetColorTexture(fill[1], fill[2], fill[3], 1)
        d:ClearAllPoints()
        d:SetPoint("CENTER", mapArt, "TOPLEFT", px(a.x, a.y))
      end
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
  btnClear:SetEnabled(route and route.avoid and #route.avoid > 0 or false)
  playerDot:ClearAllPoints()
  playerDot:SetPoint("CENTER", mapArt, "TOPLEFT", px(ppx, ppy))
  playerDot:SetRotation(GetPlayerFacing() or 0)

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
      lines[#lines + 1] = gold .. "Herb route: " .. table.concat(names, ", ") .. "|r" .. (route.alsoOthers and (dim .. " + others|r") or "")
    end
    lines[#lines + 1] = ("%d stops  ·  %d yd loop"):format(#route.stops, math.floor(route.length))
    lines[#lines + 1] = ("About %d:%02d per loop on a 60%% mount"):format(math.floor(route.seconds / 60), math.floor(route.seconds % 60))
    if route.quick and route.quick > 0 then
      lines[#lines + 1] = dim .. ("%d%% shorter than a quick route"):format(math.floor(100 * (1 - route.length / route.quick) + 0.5)) .. "|r"
    end
    lines[#lines + 1] = dim .. ("%d herb, %d ore spots"):format(herbs, ores) .. "|r"
    stats:SetText(table.concat(lines, "\n"))
  else
    stats:SetText(dim .. "No route in this zone yet.\nPress Optimize loop, or pick a herb in the Herb Guide.|r")
  end
end
NW.RefreshPlanner = function() if page:IsShown() then refresh() end end

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
