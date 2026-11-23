local ADDON, NW = ...

local C = NW.COLORS
local BAR_W = 760
local HALF = BAR_W / 2
local PI = math.pi

------------------------------------------------------------------------
-- Compass bar along the top of the screen
------------------------------------------------------------------------
local bar = CreateFrame("Frame", "NodewalkerCompass", UIParent)
bar:SetSize(BAR_W, 64)
bar:SetPoint("TOP", UIParent, "TOP", 0, -14)
bar:SetFrameStrata("LOW")
bar:Hide()
NW.compass = bar

bar.zone = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
bar.zone:SetPoint("TOP", bar, "TOP", -40, 0)
bar.zone:SetTextColor(C.herbEdge[1], C.herbEdge[2], C.herbEdge[3])
bar.coords = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
bar.coords:SetPoint("LEFT", bar.zone, "RIGHT", 10, 0)

local line = bar:CreateTexture(nil, "ARTWORK")
line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.9)
line:SetSize(BAR_W, 2)
line:SetPoint("BOTTOM", bar, "BOTTOM", 0, 8)
local fadeL = bar:CreateTexture(nil, "ARTWORK")
fadeL:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
fadeL:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.9))
fadeL:SetSize(90, 2)
fadeL:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -90, 8)

local center = bar:CreateTexture(nil, "OVERLAY")
center:SetColorTexture(C.next[1], C.next[2], C.next[3], 1)
center:SetSize(2, 16)
center:SetPoint("BOTTOM", bar, "BOTTOM", 0, 2)

local LABELS = {
  { "N", 0 }, { "NW", PI / 4 }, { "W", PI / 2 }, { "SW", 3 * PI / 4 },
  { "S", PI }, { "SE", 5 * PI / 4 }, { "E", 3 * PI / 2 }, { "NE", 7 * PI / 4 },
}
local labelFS = {}
for i, l in ipairs(LABELS) do
  local fs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetText(l[1])
  fs:SetTextColor(0.93, 0.9, 0.83)
  labelFS[i] = fs
end
local ticks = {}
for i = 1, 24 do
  local t = bar:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.7)
  t:SetSize(1, 6)
  ticks[i] = t
end

local dots, dotCount = {}, 0
local function getDot()
  dotCount = dotCount + 1
  local d = dots[dotCount]
  if not d then
    d = bar:CreateTexture(nil, "OVERLAY")
    local mask = bar:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(d)
    d:AddMaskTexture(mask)
    dots[dotCount] = d
  end
  d:Show()
  return d
end

local function norm(a)
  while a > PI do a = a - 2 * PI end
  while a <= -PI do a = a + 2 * PI end
  return a
end

-- x offset on the bar for a direction, or nil when it's behind you
local function barX(angle, facing)
  local rel = norm(angle - facing)
  if math.abs(rel) >= PI / 2 then return nil end
  return -rel / (PI / 2) * HALF
end

function NW.UpdateCompass()
  if not bar:IsShown() then return end
  local facing = NW.Facing()
  local mapID, px, py = NW.PlayerPos()
  local info = mapID and C_Map.GetMapInfo(mapID)
  bar.zone:SetText(info and info.name or "")
  bar.coords:SetText(px and ("%.1f, %.1f"):format(px * 100, py * 100) or "")
  for i = 1, dotCount do dots[i]:Hide() end
  dotCount = 0
  if not facing then
    for _, fs in ipairs(labelFS) do fs:Hide() end
    for _, t in ipairs(ticks) do t:Hide() end
    return
  end
  for i, l in ipairs(LABELS) do
    local x = barX(l[2], facing)
    local fs = labelFS[i]
    if x then
      fs:ClearAllPoints()
      fs:SetPoint("BOTTOM", bar, "BOTTOM", x, 14)
      fs:Show()
    else
      fs:Hide()
    end
  end
  for i, t in ipairs(ticks) do
    local x = barX((i - 1) * PI / 12, facing)
    if x then
      t:ClearAllPoints()
      t:SetPoint("BOTTOM", bar, "BOTTOM", x, 9)
      t:Show()
    else
      t:Hide()
    end
  end

  -- Route stops within range, by bearing
  local route = mapID and NW.db.routes[mapID]
  local w, h = NW.MapSize(mapID)
  if not route or not w then return end
  local prog = NW.progress[mapID]
  for i, st in ipairs(route.stops) do
    local dx, dy = (st.x - px) * w, (st.y - py) * h
    local d = math.sqrt(dx * dx + dy * dy)
    local isNext = false -- every stop is drawn alike
    if isNext or d < 300 then
      local x = barX(math.atan2(-dx, -dy), facing)
      if x then
        local dot = getDot()
        local edge = st.kind == "herb" and C.herbEdge or C.oreEdge
        if isNext then edge = C.next end
        local size = isNext and 14 or 10
        dot:SetSize(size, size)
        dot:SetColorTexture(edge[1], edge[2], edge[3], isNext and 1 or 0.85)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", bar, "BOTTOM", x, 9)
      end
    end
  end
end

------------------------------------------------------------------------
-- Session panel, bottom right
------------------------------------------------------------------------
local panel = CreateFrame("Frame", "NodewalkerSession", UIParent, "BackdropTemplate")
panel:SetSize(236, 112)
panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 180)
panel:SetFrameStrata("LOW")
panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
panel:SetBackdropColor(0.055, 0.06, 0.07, 0.8)
panel:SetBackdropBorderColor(0, 0, 0, 1)
panel:Hide()
NW.sessionPanel = panel

panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
panel.title:SetPoint("TOPLEFT", 14, -12)
panel.title:SetText("Session")
panel.body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.body:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
panel.body:SetJustifyH("LEFT")
panel.body:SetSpacing(4)

local function fmtTime(sec)
  if not sec then return "–" end
  return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60))
end

function NW.UpdateSession()
  if not panel:IsShown() then return end
  panel:SetHeight((NW.session.value or 0) > 0 and 130 or 112)
  local mapID = NW.PlayerPos()
  local route = mapID and NW.db.routes[mapID]
  local s = NW.session
  local hours = math.max((GetTime() - s.started) / 3600, 1 / 60)
  panel.body:SetText(table.concat({
    "Route:  " .. (route and #route.stops > 0 and (#route.stops .. " stops") or "none here (/nw plan)"),
    "Loops:  " .. s.loops .. "    Last loop: " .. fmtTime(s.lastLoopTime),
    "Gathered:  " .. s.nodes .. " nodes",
    ("Per hour:  %d nodes"):format(math.floor(s.nodes / hours))
      .. ((s.value or 0) > 0 and NW.Money and ("  ·  " .. NW.Money(math.floor(s.value / hours), true)) or ""),
    (s.value or 0) > 0 and NW.Money and ("Value:  " .. NW.Money(s.value, true)) or nil,
  }, "\n"))
end

------------------------------------------------------------------------
-- Entering a zone: a banner with what Nodewalker knows there, a fresh
-- start on the route, and a route built by itself if the zone has none.
------------------------------------------------------------------------
local S = NW.STYLE
local banner = CreateFrame("Frame", "NodewalkerZoneBanner", UIParent, "BackdropTemplate")
banner:SetSize(360, 52)
banner:SetPoint("TOP", UIParent, "TOP", 0, -92)
banner:SetFrameStrata("MEDIUM")
NW.UI.Flat(banner, { 0.055, 0.06, 0.07, 0.88 }, { 0, 0, 0, 1 })
banner:Hide()
local accent = banner:CreateTexture(nil, "ARTWORK")
accent:SetPoint("TOPLEFT", 1, -1)
accent:SetPoint("TOPRIGHT", -1, -1)
accent:SetHeight(2)
accent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
banner.zone = NW.UI.Text(banner, 16, S.gold, "CENTER")
banner.zone:SetPoint("TOP", 0, -10)
banner.info = NW.UI.Text(banner, 12, S.text, "CENTER")
banner.info:SetPoint("TOP", banner.zone, "BOTTOM", 0, -5)

local HOLD, FADE = 6, 1
local function showBanner(zone, info)
  banner.zone:SetText(zone)
  banner.info:SetText(info or "")
  banner:SetWidth(math.max(300, banner.zone:GetStringWidth(), banner.info:GetStringWidth()) + 48)
  banner.t = 0
  banner:SetAlpha(1)
  banner:Show()
end
-- update the second line without restarting the timer
local function updateBanner(info)
  if not banner:IsShown() then return end
  banner.info:SetText(info)
  banner:SetWidth(math.max(300, banner.zone:GetStringWidth(), banner.info:GetStringWidth()) + 48)
  banner.t = math.min(banner.t, 1)
end
banner:SetScript("OnUpdate", function(self, dt)
  self.t = self.t + dt
  if self.t > HOLD + FADE then self:Hide()
  elseif self.t > HOLD then self:SetAlpha(1 - (self.t - HOLD) / FADE) end
end)

local function fmt(sec) return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60)) end

local function routeLine(route)
  local focus = ""
  if route.focus then
    local names = {}
    for n in pairs(route.focus) do names[#names + 1] = n end
    focus = table.concat(names, ", ") .. " route: "
  end
  return ("%s%d stops, %s per loop"):format(focus, #route.stops, fmt(route.seconds or 0))
end

local lastMap, leftAt = nil, {}
local STALE = 600 -- away this long and the route picks up at the nearest stop again

local function entered(mapID)
  local s = NW.db.settings
  local info = C_Map.GetMapInfo(mapID)
  local isZone = info and info.mapType == 3
  -- back after a while: start from the nearest stop, not where you left off
  if leftAt[mapID] and GetTime() - leftAt[mapID] > STALE then NW.ResetProgress(mapID) end
  if not (isZone and s.overlayShown) or IsInInstance() then return end

  local wanted, herbs, ores = 0, 0, 0
  for _, n in ipairs(NW.db.nodes[mapID] or {}) do
    if NW.NodeWanted(n, s) then
      wanted = wanted + 1
      if n.kind == "herb" then herbs = herbs + 1 else ores = ores + 1 end
    end
  end
  local spots = {}
  if herbs > 0 then spots[#spots + 1] = herbs .. " herb" end
  if ores > 0 then spots[#spots + 1] = ores .. " ore" end
  local spotText = #spots > 0 and (table.concat(spots, ", ") .. " spots") or "No known spots for you here"

  local route = NW.db.routes[mapID]
  local line
  if route and #route.stops > 1 then
    line = spotText .. "   ·   " .. routeLine(route)
  elseif s.autoRoute and wanted >= 3 and not NW.routeStatus then
    line = spotText .. "   ·   building a route..."
    NW.BuildRoute(mapID, function(r)
      updateBanner(spotText .. "   ·   " .. routeLine(r))
      if NW.RefreshPlanner then NW.RefreshPlanner() end
    end)
  elseif wanted > 0 then
    line = spotText .. "   ·   no route yet (/nw plan)"
  else
    line = spotText .. "   ·   import GatherMate2 or gather a few"
  end
  if s.zoneBanner then showBanner(info.name, line) end
end

local function check()
  if not NW.db then return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID or mapID == lastMap then return end
  if lastMap then leftAt[lastMap] = GetTime() end
  lastMap = mapID
  entered(mapID)
end
NW.CheckZone = check

NW.On("ZONE_CHANGED_NEW_AREA", check)
NW.On("ZONE_CHANGED", check)
NW.On("ZONE_CHANGED_INDOORS", check)
NW.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, check) end)
-- some borders don't fire an event, so look now and then too
table.insert(NW.OnLoad, function() C_Timer.NewTicker(2, check) end)
