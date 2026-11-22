local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

local function s() return NW.db.settings end
local function changed()
  if NW.RefreshOverlayArt then NW.RefreshOverlayArt() end
  NW.UpdateVisibility()
  if NW.UpdateMinimapButton then NW.UpdateMinimapButton() end
end

------------------------------------------------------------------------
-- Overlay tab: two columns of settings
------------------------------------------------------------------------
local widgets = {}
local page = UI.AddTab("overlay", "Overlay", function()
  for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end)

local COL_W = 440
local COL_X = { 24, 24 + COL_W + 60 }
local cols = { { y = -10 }, { y = -10 } }

local function place(col, widget, h, indent)
  local c = cols[col]
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[col] + (indent or 0), c.y)
  c.y = c.y - h
  widgets[#widgets + 1] = widget
  return widget
end
local function heading(col, text)
  if cols[col].y < -10 then cols[col].y = cols[col].y - 10 end
  place(col, UI.Heading(page, text, COL_W), 26)
end
local function check(col, label, key, tip, after)
  place(col, UI.Check(page, label, function() return s()[key] end,
    function(v) s()[key] = v; changed(); if after then after(v) end end, tip), 24, 2)
end
local function slider(col, label, minV, maxV, step, fmt, key, after, tip)
  place(col, UI.Slider(page, COL_W, label, minV, maxV, step, fmt,
    function() return s()[key] end, function(v) s()[key] = v; if after then after(v) end end, tip), 44)
end
-- A second check on the row just placed
local function checkBeside(col, label, key, tip)
  cols[col].y = cols[col].y + 24
  place(col, UI.Check(page, label, function() return s()[key] end,
    function(v) s()[key] = v; changed() end, tip), 24, 222)
end
local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

-- One-click looks
local PRESETS = {
  { "Farming", "Half the screen, live dots, ring, compass and session panel.", {
    overlaySize = 0.5, opacity = 0.55, scale = 1.0, tint = "natural", fadeMoving = true, fadeMovingAlpha = 0.6,
    brightNear = true, mountZoom = true, liveDots = true, showRangeRing = true, showCompass = true, showSession = true } },
  { "Questing", "Smaller and fainter, out of the way.", {
    overlaySize = 0.35, opacity = 0.35, scale = 1.0, tint = "natural", fadeMoving = true, fadeMovingAlpha = 0.4,
    brightNear = true, mountZoom = true, showRangeRing = false, showCompass = false, showSession = false } },
  { "Minimal", "Icons and route only, no terrain or panels.", {
    tint = "none", fadeMoving = false, mountZoom = false, showRangeRing = false, showCompass = false, showSession = false } },
}
local function applyPreset(values)
  for k, v in pairs(values) do s()[k] = v end
  if NW.SizeOverlay then NW.SizeOverlay() end
  changed()
  for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

-- Column 1: the map
place(1, UI.Heading(page, "Map window", COL_W - 250), 26)
do
  local x = COL_X[1] + COL_W - 240
  for i, pr in ipairs(PRESETS) do
    local b = UI.Button(page, pr[1], 76, function() applyPreset(pr[3]) end, 20)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x + (i - 1) * 82, -8)
    UI.Tip(b, pr[1], pr[2])
  end
end
check(1, "Show the overlay", "overlayShown", "Same as /nw or your key binding.")
checkBeside(1, "Zoom out when mounted", "mountZoom")
slider(1, "Window size", 0.25, 1, 0.05, function(v) return pct(v) .. " of the screen" end, "overlaySize",
  function() if NW.SizeOverlay then NW.SizeOverlay() end end)
slider(1, "Terrain opacity", 0.1, 1, 0.05, pct, "opacity", nil, "Icons and the route stay easy to read at any setting.")
slider(1, "Zoom", 0.5, 3, 0.1, function(v) return ("%.1fx"):format(v) end, "scale", changed)
place(1, UI.Dropdown(page, COL_W, "Map style", {
  { "minimap", "Detailed (minimap tiles)" }, { "zonemap", "World map art" },
}, function() return s().terrainSource end, function(v) s().terrainSource = v; changed() end, 190), 30)
place(1, UI.Dropdown(page, COL_W, "Terrain colour", {
  { "natural", "Natural" }, { "muted", "Muted" }, { "silhouette", "Silhouette (dark)" },
  { "gold", "Gold tint" }, { "blue", "Blue tint" }, { "none", "Off (icons and route only)" },
}, function() return s().tint end, function(v) s().tint = v; changed() end, 190), 30)

heading(1, "Live dots")
check(1, "Show live dots from your minimap", "liveDots", "Moves your minimap into the window, like FarmHud. Turn off to keep your minimap where it is.")
check(1, "Range ring around you", "showRangeRing", "Live dots can only appear inside this ring.")
check(1, "Also show known spots outside the ring", "showKnownSpots")
check(1, "Live-dot tooltips without holding Alt", "liveHoverNoAlt", "Makes herbs in the world harder to click through the window.")

heading(1, "Route")
slider(1, "Picked stops count as empty for", 1, 20, 1, function(v) return ("%d min"):format(v) end, "respawnMinutes",
  nil, "How long the route skips a stop after you gather it.")
check(1, "Build a route by itself in new zones", "autoRoute",
  "When you enter a zone with known spots and no route, Nodewalker builds one.")

-- Column 2: when it shows, extras, filters
heading(2, "When to show it")
check(2, "Fade while moving", "fadeMoving")
checkBeside(2, "Brighter near a node", "brightNear", "Stops fading when a known spot or your next stop is within 100 yards.")
slider(2, "Fade to", 0.2, 1, 0.05, pct, "fadeMovingAlpha")
check(2, "Hide in combat", "hideCombat")
check(2, "Hide in cities and inns", "hideResting")
check(2, "Hide in dungeons and raids", "hideInstances")
check(2, "Only while Find Herbs or Find Minerals is on", "onlyTracking")

heading(2, "On screen")
check(2, "Zone banner when you arrive", "zoneBanner", "Shows the zone, its known spots and its route as you enter.")
check(2, "Compass bar", "showCompass")
checkBeside(2, "Minimap button", "minimapButton")
check(2, "Session panel (loops, nodes and gold per hour)", "showSession")
check(2, "\"Next stop\" label on the map", "showNextLabel")
check(2, "Icon tooltips when live dots are off", "hoverTooltips")

heading(2, "Which herbs and ore")
check(2, "Only my professions", "onlyMyProfessions", "Herbs if you have Herbalism, ore if you have Mining.")
check(2, "Only spots confirmed up", "onlyConfirmed", "Seen on your minimap or in the world recently.")
checkBeside(2, "Group nearby spots", "groupSpots", "Spots that would overlap share one icon with a count. Hover it to see what's there.")
place(2, UI.Button(page, "Choose herbs and ore...", 200, function() NW.ShowTab("nodes") end, 24), 28, 2)

-- Controls reference along the bottom
local help = UI.Box(page, UI.CONTENT_W - 48, 40)
help:SetPoint("BOTTOMLEFT", 24, 8)
local helpText = UI.Text(help, 11, S.dim)
helpText:SetPoint("LEFT", 12, 0)
helpText:SetPoint("RIGHT", -12, 0)
helpText:SetSpacing(3)
helpText:SetText("|cffe8c46aAlt|r + hover a live dot: identify it   ·   |cffe8c46aCtrl|r + hover a stop: details   ·   "
  .. "|cffe8c46aCtrl-click|r: next stop   ·   |cffe8c46aCtrl-right-click|r: hide that herb\n"
  .. "|cffe8c46a/nw|r overlay   ·   |cffe8c46a/nw plan|r route   ·   |cffe8c46a/nw guide|r farm guide   ·   |cffe8c46a/nw prof|r professions   ·   |cffe8c46a/nw consumes|r   ·   "
  .. "|cffe8c46a/nw options|r settings")

------------------------------------------------------------------------
-- Nodes tab: tick the herbs and ore you want to see
------------------------------------------------------------------------
local nodeChecks = {}
local refreshNodes
local nodesPage = UI.AddTab("nodes", "Herbs & Ore", function() refreshNodes() end)

local SKILL_HEX = { red = "ff4040", orange = "ff8040", yellow = "ffe633", green = "59cc59", grey = "8c8c8c", unknown = "d9d9d9" }

local function buildList(kind, title, y, ncols, colW)
  local list = {}
  for name, info in pairs(NW.NODES) do
    if info[1] == kind then list[#list + 1] = { name = name, req = info[2] or 999 } end
  end
  table.sort(list, function(a, b) if a.req ~= b.req then return a.req < b.req end return a.name < b.name end)

  local h = UI.Heading(nodesPage, title, UI.CONTENT_W - 48 - 230)
  h:SetPoint("TOPLEFT", 24, y)
  local function setAll(show)
    for _, e in ipairs(list) do NW.db.settings.hiddenNodes[e.name] = (not show) or nil end
    if NW.RefreshPlanner then NW.RefreshPlanner() end
    refreshNodes()
  end
  local none = UI.Button(nodesPage, "None", 70, function() setAll(false) end, 20)
  none:SetPoint("TOPRIGHT", nodesPage, "TOPRIGHT", -24, y + 1)
  local all = UI.Button(nodesPage, "All", 70, function() setAll(true) end, 20)
  all:SetPoint("RIGHT", none, "LEFT", -6, 0)

  local rowH = 22
  for i, e in ipairs(list) do
    local cb = UI.Check(nodesPage, e.name, function() return not NW.IsHidden(e.name) end,
      function(v) NW.SetHidden(e.name, not v) end)
    local col, row = (i - 1) % ncols, math.floor((i - 1) / ncols)
    cb:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 2 + col * colW, -10 - row * rowH)
    local icon = cb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", cb, "RIGHT", 7, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cb.icon = icon
    cb.label:ClearAllPoints()
    cb.label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    cb.entry, cb.kind = e, kind
    nodeChecks[#nodeChecks + 1] = cb
  end
  return y - 26 - 10 - math.ceil(#list / ncols) * rowH - 18
end

local nodesHelp = UI.Text(nodesPage, 12, S.dim)
nodesHelp:SetPoint("TOPLEFT", 24, -10)
nodesHelp:SetText("Untick what you don't farm: it leaves the overlay, the planner and new routes. Number: skill needed. Colour: skill-ups at your level.")
nodesHelp:SetWidth(UI.CONTENT_W - 48)
nodesHelp:SetWordWrap(false)
local nextY = buildList("herb", "Herbs", -36, 4, 240)
-- ore names run long ("Ooze Covered Rich Thorium Vein"): three wider columns
buildList("ore", "Ore", nextY, 3, 320)

refreshNodes = function()
  if not nodesPage:IsShown() then return end
  local hidden = 0
  for _, cb in ipairs(nodeChecks) do
    cb:Refresh()
    local e = cb.entry
    local skill = NW.GetSkill(cb.kind)
    local hex = SKILL_HEX[NW.SkillColor(e.req < 999 and e.req or nil, skill)] or SKILL_HEX.unknown
    cb.icon:SetTexture(NW.NodeIcon(e.name, cb.kind))
    cb.icon:SetDesaturated(NW.IsHidden(e.name))
    cb:SetLabel(("|cff%s%s|r  |cff6f6f74%s|r"):format(hex, e.name, e.req < 999 and e.req or ""))
    if NW.IsHidden(e.name) then hidden = hidden + 1 end
  end
  NW.SetWindowSubtitle(hidden > 0 and (hidden .. " hidden") or "Showing everything")
end
NW.RefreshNodeOptions = function() if nodesPage:IsShown() then refreshNodes() end end

------------------------------------------------------------------------
-- The game's options window gets a small page that opens ours
------------------------------------------------------------------------
local stub = CreateFrame("Frame", "NodewalkerOptions")
stub.name = "Nodewalker"
local stubTitle = UI.Text(stub, 16, S.gold)
stubTitle:SetPoint("TOPLEFT", 16, -16)
stubTitle:SetText("Nodewalker")
local stubText = UI.Text(stub, 12, S.text)
stubText:SetPoint("TOPLEFT", stubTitle, "BOTTOMLEFT", 0, -10)
stubText:SetText("All settings live in Nodewalker's own window. You can also open it with /nw options.")
local stubBtn = UI.Button(stub, "Open Nodewalker settings", 220, function()
  if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
  if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
  NW.OpenOptions()
end, 28, "primary")
stubBtn:SetPoint("TOPLEFT", stubText, "BOTTOMLEFT", 0, -14)

table.insert(NW.OnLoad, function()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(stub, "Nodewalker")
    Settings.RegisterAddOnCategory(category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(stub)
  end
end)

function NW.OpenOptions()
  if NW.window:IsShown() then NW.ShowTab("overlay") else NW.db.settings.lastTab = "overlay"; NW.window:Show() end
end

------------------------------------------------------------------------
-- Minimap button: click for the overlay, right-click for the window
------------------------------------------------------------------------
local mmBtn
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- The button sits on the screen where the minimap's edge normally is. It isn't
-- attached to the minimap, which the overlay borrows for live dots.
local function minimapHome()
  local ui = UIParent:GetEffectiveScale()
  local cluster = MinimapCluster
  local cx, cy = nil, nil
  if cluster then cx, cy = cluster:GetCenter() end
  local ck = cluster and cluster:GetEffectiveScale() / ui
  if not (NW.IsLive and NW.IsLive()) then
    local x, y = Minimap:GetCenter()
    if x then
      local k = Minimap:GetEffectiveScale() / ui
      NW.minimapHome = { x * k, y * k, Minimap:GetWidth() / 2 * k }
      -- remember where the minimap sits inside its cluster, for when it's borrowed
      if cx then s().minimapInCluster = { x * k - cx * ck, y * k - cy * ck, NW.minimapHome[3] } end
    end
  elseif cx and s().minimapInCluster then
    -- borrowed: the cluster hasn't moved, so work it out from there
    local o = s().minimapInCluster
    NW.minimapHome = { cx * ck + o[1], cy * ck + o[2], o[3] }
  end
  return NW.minimapHome
end
local function placeButton()
  local home = minimapHome()
  if not home then return end
  local a = math.rad(s().minimapAngle or 215)
  local r = home[3] + 5
  mmBtn:ClearAllPoints()
  mmBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", home[1] + r * math.cos(a), home[2] + r * math.sin(a))
end

local mmReady = false -- not until the game has laid out the minimap
function NW.UpdateMinimapButton()
  if mmBtn then mmBtn:SetShown(mmReady and s().minimapButton and true or false) end
end

table.insert(NW.OnLoad, function()
  if not Minimap then return end
  mmBtn = CreateFrame("Button", "NodewalkerMinimapButton", UIParent)
  NW.minimapButton = mmBtn
  mmBtn:SetSize(31, 31)
  mmBtn:SetFrameStrata("MEDIUM")
  mmBtn:SetFrameLevel(8)
  mmBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmBtn:RegisterForDrag("LeftButton")

  local icon = mmBtn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture("Interface\\AddOns\\Nodewalker\\Media\\Icon")
  local border = mmBtn:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mmBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  mmBtn:SetScript("OnClick", function(_, b)
    if b == "RightButton" then NW.ToggleWindow() else NW.ToggleOverlay() end
  end)
  mmBtn:SetScript("OnDragStart", function(self)
    self.dragging = true
  end)
  mmBtn:SetScript("OnDragStop", function(self) self.dragging = nil end)
  -- follow the cursor while dragged; otherwise keep up if the minimap moves
  mmBtn:SetScript("OnUpdate", function(self, dt)
    if self.dragging then
      local home = minimapHome()
      if not home then return end
      local px, py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      s().minimapAngle = math.deg(atan2(py / scale - home[2], px / scale - home[1]))
      placeButton()
      return
    end
    self.t = (self.t or 0) + dt
    if self.t > 1 then self.t = 0; placeButton() end
  end)
  mmBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Nodewalker", C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine("Left-click: overlay", 0.8, 0.8, 0.85)
    GameTooltip:AddLine("Right-click: window", 0.8, 0.8, 0.85)
    GameTooltip:Show()
  end)
  mmBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  mmBtn:Hide()
  -- the minimap isn't in its final place until a moment after you're in the world
  NW.On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(1.5, function()
      mmReady = true
      placeButton()
      NW.UpdateMinimapButton()
    end)
  end)
end)
