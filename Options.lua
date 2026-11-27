local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

local function s() return NW.db.settings end
local function changed()
  if NW.RefreshOverlayArt then NW.RefreshOverlayArt() end
  NW.UpdateVisibility()
  if NW.UpdateMinimapButton then NW.UpdateMinimapButton() end
end

------------------------------------------------------------------------
-- Settings: a sidebar of categories (General, Map & Overlay, Gathering with
-- Herbs & Ore, Fishing, Data & Integrations), each a page of two columns.
-- The pages are the window's Settings tabs; the sidebar replaces the tab
-- row's switches. Every setting keeps its saved key.
------------------------------------------------------------------------
local widgets = {}
local function refreshAll() for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end end

local SIDE_X, SIDE_W, NAV_H = 16, 164, 30
local COL_W = 360
local COL_X = { SIDE_X + SIDE_W + 22, SIDE_X + SIDE_W + 22 + COL_W + 34 }
local page, cols
local CATS = {}   -- the sidebar's rows, in order
local LABELS = {} -- setting key -> its label (presets name your changes with it)
local syncNav     -- (set once the sidebar exists)
local function newPage(key, label, icon, child)
  page = UI.AddTab(key, label, function() refreshAll(); if syncNav then syncNav() end end, nil, nil, "Settings")
  page:HookScript("OnHide", function() if syncNav then syncNav() end end)
  page.keys = {} -- what its Defaults button puts back
  cols = { { y = -10 }, { y = -10 } }
  CATS[#CATS + 1] = { key = key, label = label, icon = icon, child = child, page = page }
  return page
end

local function place(col, widget, h, indent)
  local c = cols[col]
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", page, "TOPLEFT", COL_X[col] + (indent or 0), c.y)
  c.y = c.y - h
  widgets[#widgets + 1] = widget
  return widget
end
local function heading(col, text, w)
  if cols[col].y < -10 then cols[col].y = cols[col].y - 10 end
  return place(col, UI.Heading(page, text, w or COL_W), 26)
end
local function track(key, label, noReset)
  LABELS[key] = label
  if not noReset then page.keys[#page.keys + 1] = key end
end
-- Map & Overlay presets remember your changes: a setting a preset sets, changed while
-- that preset is the one you picked last, is kept for it (settings.presetTweaks)
local PRESET_DEFAULTS = {} -- name -> { key = value }, filled where the presets are
local function noteTweak(key, v)
  local name = s().lookPreset
  local def = name and PRESET_DEFAULTS[name]
  if not (def and def[key] ~= nil) then return end
  s().presetTweaks = s().presetTweaks or {}
  local tw = s().presetTweaks[name] or {}
  s().presetTweaks[name] = tw
  local same = (type(v) == "number" and type(def[key]) == "number") and math.abs(v - def[key]) < 0.001 or (v or false) == def[key]
  if same then tw[key] = nil elseif v == nil then tw[key] = false else tw[key] = v end
end
local function check(col, label, key, tip, after, noReset)
  track(key, label, noReset)
  return place(col, UI.Check(page, label, function() return s()[key] end,
    function(v) s()[key] = v; noteTweak(key, v); changed(); refreshAll(); if after then after(v) end end, tip), 24, 2)
end
local function slider(col, label, minV, maxV, step, fmt, key, after, tip)
  track(key, label)
  return place(col, UI.Slider(page, COL_W, label, minV, maxV, step, fmt,
    function() return s()[key] end, function(v) s()[key] = v; noteTweak(key, v); if after then after(v) end end, tip), 44)
end
-- A second check on the row just placed
local function checkBeside(col, label, key, tip, after)
  track(key, label)
  cols[col].y = cols[col].y + 24
  return place(col, UI.Check(page, label, function() return s()[key] end,
    function(v) s()[key] = v; noteTweak(key, v); changed(); refreshAll(); if after then after(v) end end, tip), 24, 190)
end
-- Greyed out (value kept) while another setting is off
local function dependsOn(widget, key, want)
  local old = widget.Refresh
  function widget:Refresh()
    if old then old(self) end
    local on = (s()[key] and true or false) == (want ~= false)
    if self.SetEnabled then self:SetEnabled(on) end
    local sl = rawget(self, "slider")
    if sl then sl:SetEnabled(on) end
    self:SetAlpha(on and 1 or 0.45)
  end
  return widget
end
local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
-- a label and a value on one line (key bindings, commands, add-ons)
local function infoLine(col, left, right, tip)
  local f = CreateFrame("Frame", nil, page)
  f:SetSize(COL_W, 16)
  f.l = UI.Text(f, 12, S.text)
  f.l:SetPoint("LEFT")
  f.l:SetWidth(COL_W * 0.5)
  f.l:SetWordWrap(false)
  f.r = UI.Text(f, 12, S.dim, "RIGHT")
  f.r:SetPoint("RIGHT")
  f.r:SetWidth(COL_W * 0.5)
  f.r:SetWordWrap(false)
  f.l:SetText(left)
  f.r:SetText(type(right) == "function" and "" or right or "")
  if type(right) == "function" then function f:Refresh() self.r:SetText(right() or "") end end
  if tip then f:EnableMouse(true) UI.Tip(f, left, tip) end
  return place(col, f, 18, 2)
end
-- Defaults, at the page's foot: puts back the settings on this page only (a second click confirms)
local function defaultsButton(after)
  local keys = page.keys
  local b
  b = UI.Button(page, "Defaults", 110, function()
    if not rawget(b, "armed") then
      b.armed = true
      b:SetText("Click to confirm")
      C_Timer.After(4, function() b.armed = nil; b:SetText("Defaults") end)
      return
    end
    b.armed = nil
    b:SetText("Defaults")
    local D = NW.DEFAULTS and NW.DEFAULTS.settings or {}
    for _, k in ipairs(keys) do
      local d = D[k]
      if type(d) ~= "table" then s()[k] = d end -- (lists you keep, like hidden herbs or gear, stay)
    end
    if after then after() end
    changed()
    refreshAll()
  end, 22)
  b:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 14)
  UI.Tip(b, "Defaults", "Puts back this page's settings. Other pages, routes, journals and what you've recorded stay as they are.")
  return b
end
local GOLD_HEX = "|cffd6b266"

------------------------------------------------------------------------
-- General: this window, its buttons, key bindings and commands
------------------------------------------------------------------------
newPage("general", "General", "Interface\\Icons\\INV_Misc_Gear_01")
heading(1, "Window")
slider(1, "Window size", 0.6, 1.5, 0.05, pct, "winScale", function() NW.SetWindowScale(s().winScale or 1) end,
  "Or drag the grip in the window's bottom-right corner.")
check(1, "Minimap button", "minimapButton", "Nodewalker is also in the game's AddOns menu.")
-- A button for your action bars: a macro that opens the window, handed to
-- your cursor to drop where you like
local barBtn
-- left-click: this window; right-click: the overlay
local BAR_MACRO = "/nw [btn:2] map; window"
barBtn = UI.Button(page, "Action bar button", 170, function()
  if InCombatLockdown and InCombatLockdown() then return end
  local idx = GetMacroIndexByName and GetMacroIndexByName("Nodewalker") or 0
  if idx > 0 and EditMacro then pcall(EditMacro, idx, nil, nil, BAR_MACRO) end
  if idx == 0 and CreateMacro then
    local ok, made = pcall(CreateMacro, "Nodewalker", "INV_Misc_Map_01", BAR_MACRO, nil)
    idx = ok and made or 0
  end
  if idx and idx > 0 and PickupMacro then
    PickupMacro(idx)
  else
    barBtn:SetText("No free macro slot")
    C_Timer.After(3, function() barBtn:SetText("Action bar button") end)
  end
end, 24)
place(1, barBtn, 30, 2)
UI.Tip(barBtn, "Action bar button", "Drop it on an action bar. Left-click: this window. Right-click: the overlay.")
-- a button made before right-click did anything: give it the overlay too
local function upgradeBarMacro()
  local idx = GetMacroIndexByName and GetMacroIndexByName("Nodewalker") or 0
  if idx > 0 and GetMacroInfo and EditMacro and not (InCombatLockdown and InCombatLockdown()) then
    local _, _, body = GetMacroInfo(idx)
    if body and strtrim(body) == "/nw window" then pcall(EditMacro, idx, nil, nil, BAR_MACRO) end
  end
end
NW.On("PLAYER_LOGIN", upgradeBarMacro)
NW.On("UPDATE_MACROS", upgradeBarMacro)

-- key bindings: set in the game's Key Bindings (under Nodewalker); shown here
heading(1, "Key bindings")
local function bound(action)
  local key = GetBindingKey and GetBindingKey(action)
  if not key then return "|cff6f6f74not bound|r" end
  return GOLD_HEX .. (GetBindingText and GetBindingText(key, "KEY_") or key) .. "|r"
end
local BIND_TIP = "Set in the game's Key Bindings, under Nodewalker."
for _, b in ipairs({ { "NODEWALKER_TOGGLE", "Overlay" }, { "NODEWALKER_PLANNER", "Routes" }, { "NODEWALKER_NEXT", "Skip to next stop" },
  { "NODEWALKER_FISHHUD", "Fishing HUD" }, { "NODEWALKER_JOURNAL", "Fishing Journal" } }) do
  infoLine(1, b[2], function() return bound(b[1]) end, BIND_TIP)
end
if NW.SmartFish then
  infoLine(1, "Smart Fishing", function()
    local k = NW.SmartFish.key and NW.SmartFish.key()
    return k and (GOLD_HEX .. (GetBindingText and GetBindingText(k, "KEY_") or k) .. "|r") or "|cff6f6f74not bound|r"
  end, "Set it under Fishing.")
end

heading(2, "Mouse")
infoLine(2, "Alt + hover a live dot", "what it is")
infoLine(2, "Ctrl + hover a stop", "details")
infoLine(2, "Ctrl + right-click a node", "hide that herb or ore")
heading(2, "Commands")
for _, c in ipairs({ { "/nw", "overlay" }, { "/nw window", "this window" }, { "/nw plan", "Routes" }, { "/nw guide", "Material Finder" },
  { "/nw prof", "Professions" }, { "/nw consumes", "Consumes" }, { "/nw journal", "Fishing Journal" }, { "/nw options", "Settings" },
  { "/nw import", "GatherMate2 nodes" }, { "/nw status", "known spots here" } }) do
  infoLine(2, GOLD_HEX .. c[1] .. "|r", c[2])
end
defaultsButton()

------------------------------------------------------------------------
-- Map & Overlay: when the overlay shows and how it looks
------------------------------------------------------------------------
newPage("map", "Map & Overlay", "Interface\\Icons\\INV_Misc_Map_01")
-- One-click looks
local PRESETS = {
  { "Farming", "Half the screen, live dots, ring, compass and session panel.", {
    overlaySize = 0.5, opacity = 0.4, scale = 1.0, tint = "natural", fadeMoving = true, fadeMovingAlpha = 0.6,
    brightNear = true, liveDots = true, showRangeRing = true, showCompass = true, showSession = true, hidePicked = false } },
  { "Questing", "Smaller and fainter, out of the way.", {
    overlaySize = 0.35, opacity = 0.2, scale = 1.0, tint = "natural", fadeMoving = true, fadeMovingAlpha = 0.4,
    brightNear = true, showRangeRing = false, showCompass = false, showSession = false, hidePicked = false } },
  { "Minimal", "Icons and route only, no terrain or panels.", {
    tint = "none", fadeMoving = false, showRangeRing = false, showCompass = false, showSession = false, hidePicked = true } },
}
-- (zooming out when mounted is yours to choose: no preset changes it)
for _, pr in ipairs(PRESETS) do PRESET_DEFAULTS[pr[1]] = pr[3] end
-- a preset as you've made it: its values with your changes on top
local function presetValues(name)
  local out = {}
  for k, v in pairs(PRESET_DEFAULTS[name]) do out[k] = v end
  for k, v in pairs((s().presetTweaks or {})[name] or {}) do out[k] = v end
  return out
end
local function presetChanges(name)
  local list = {}
  for k in pairs((s().presetTweaks or {})[name] or {}) do list[#list + 1] = LABELS[k] or k end
  table.sort(list)
  return list
end
local presetBtns = {}
local function presetMatches(values)
  for k, v in pairs(values) do
    local cur = s()[k]
    if type(v) == "number" then
      if type(cur) ~= "number" or math.abs(cur - v) > 0.001 then return false end
    elseif (cur or false) ~= v then return false end
  end
  return true
end
local presetMark = { Refresh = function()
  for _, b in ipairs(presetBtns) do
    local on = presetMatches(presetValues(b.name))
    b.label:SetTextColor(unpack(on and S.gold or S.text))
    b:SetBackdropBorderColor(unpack(on and S.gold or S.edge))
    -- a preset you've changed says so
    b:SetText(b.name .. (#presetChanges(b.name) > 0 and "*" or ""))
  end
end }
widgets[#widgets + 1] = presetMark
local function applyPreset(name, own)
  if own and s().presetTweaks then s().presetTweaks[name] = nil end -- Shift-click: its own values again
  s().lookPreset = name
  for k, v in pairs(presetValues(name)) do s()[k] = v end
  if NW.SizeOverlay then NW.SizeOverlay() end
  changed()
  refreshAll()
end
heading(1, "Look", COL_W - 250)
do
  local x = COL_X[1] + COL_W - 240
  for i, pr in ipairs(PRESETS) do
    local b = UI.Button(page, pr[1], 76, function() applyPreset(pr[1], IsShiftKeyDown and IsShiftKeyDown()) end, 20)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x + (i - 1) * 82, -8)
    b.name = pr[1]
    b:HookScript("OnLeave", function() presetMark.Refresh() end)
    UI.Tip(b, pr[1], function()
      local ch = presetChanges(pr[1])
      return pr[2] .. "\nGold: your settings match it."
        .. (#ch > 0 and ("\n*Your changes kept: " .. table.concat(ch, ", ") .. ". Shift-click: its own values.") or "")
    end)
    presetBtns[i] = b
  end
end
slider(1, "Overlay size", 0.25, 1, 0.05, function(v) return pct(v) .. " of the screen" end, "overlaySize",
  function() if NW.SizeOverlay then NW.SizeOverlay() end presetMark.Refresh() end)
-- with Terrain colour off there's no terrain: opacity and map style are greyed out (values kept)
local function terrainOn() return s().tint ~= "none" end
local function whileTerrain(widget)
  local old = widget.Refresh
  function widget:Refresh()
    if old then old(self) end
    local on = terrainOn()
    local sl = rawget(self, "slider")
    if sl then sl:SetEnabled(on) end
    self:SetAlpha(on and 1 or 0.45)
  end
  return widget
end
whileTerrain(slider(1, "Terrain opacity", 0.1, 1, 0.05, pct, "opacity", function() presetMark.Refresh() end,
  "How strongly the map shows under your icons and route."))
slider(1, "Map zoom", 0.5, 3, 0.1, function(v) return ("%.1fx"):format(v) end, "scale", function() changed() presetMark.Refresh() end)
track("terrainSource", "Map style")
whileTerrain(place(1, UI.Dropdown(page, COL_W, "Map style", {
  { "minimap", "Detailed (minimap tiles)" }, { "zonemap", "World map art" },
}, function() return s().terrainSource end, function(v) s().terrainSource = v; changed() end, 190,
  "With Terrain colour off, no map is drawn."), 30))
track("tint", "Terrain colour")
place(1, UI.Dropdown(page, COL_W, "Terrain colour", {
  { "natural", "Natural" }, { "muted", "Muted" }, { "silhouette", "Silhouette (dark)" },
  { "gold", "Gold tint" }, { "blue", "Blue tint" }, { "none", "Off (icons and route only)" },
}, function() return s().tint end, function(v) s().tint = v; noteTweak("tint", v); changed(); refreshAll() end, 190), 30)
-- says why the two above do nothing while it's off
local terrainNote = UI.Text(page, 11, S.dim)
terrainNote:SetText("Terrain off: opacity and map style don't apply.")
terrainNote:SetWidth(COL_W)
place(1, terrainNote, 18, 2)
local tnRefresh = { Refresh = function() terrainNote:SetShown(not terrainOn()) end }
widgets[#widgets + 1] = tnRefresh
heading(1, "Overlay")
check(1, "Show overlay", "overlayShown", "Same as /nw or your key binding. Changes here show on it straight away.", nil, true)
check(1, "Zoom out when mounted", "mountZoom", "With live nodes on, the minimap's herb dots shift while it zooms.")

heading(2, "Visibility")
check(2, "Hide in combat", "hideCombat")
check(2, "Hide in cities and inns", "hideResting")
check(2, "Hide in dungeons and raids", "hideInstances")
check(2, "Only while tracking herbs or ore", "onlyTracking", "Find Herbs or Find Minerals is on.")
heading(2, "Fading")
check(2, "Fade while moving", "fadeMoving")
dependsOn(check(2, "Full opacity near nodes", "brightNear", "Stops fading when a known spot is within 100 yards. Needs Fade while moving."), "fadeMoving")
dependsOn(slider(2, "Fade to", 0.2, 1, 0.05, pct, "fadeMovingAlpha", nil, "Needs Fade while moving."), "fadeMoving")
heading(2, "On screen")
check(2, "Compass bar", "showCompass")
checkBeside(2, "Session panel", "showSession", "Loops, nodes and gold per hour while you farm.")
check(2, "Zone arrival banner", "zoneBanner", "The zone, its known spots and its route as you enter.")
defaultsButton(function() if NW.SizeOverlay then NW.SizeOverlay() end end)

------------------------------------------------------------------------
-- Gathering: live nodes, filters, routes, what's recorded
------------------------------------------------------------------------
newPage("gather", "Gathering", "Interface\\Icons\\Trade_Herbalism")
heading(1, "Detection")
check(1, "Show live nodes", "liveDots", "Moves your minimap into the overlay, like FarmHud, so its herb and ore dots show. Off keeps your minimap where it is.")
dependsOn(check(1, "Show detection radius", "showRangeRing", "Your minimap's range: live nodes can only appear inside this ring. Needs live nodes."), "liveDots")
dependsOn(check(1, "Show distant known spots", "showKnownSpots", "Known spots outside the ring stay on the map. Needs live nodes."), "liveDots")
dependsOn(check(1, "Always show node tooltips", "liveHoverNoAlt",
  "No need to hold Alt. Herbs and veins inside the ring then can't be clicked in the world. Needs live nodes."), "liveDots")
dependsOn(check(1, "Icon tooltips", "hoverTooltips", "Hover an icon on the overlay for its name. With live nodes on, the minimap's own tooltips take over."), "liveDots", false)
dependsOn(slider(1, "Quest area ring", 0, 1, 0.05, pct, "questRingAlpha",
  function() if NW.ApplyQuestRing then NW.ApplyQuestRing() end end,
  "The checkered ring your minimap draws round quest areas, seen through the overlay. Needs live nodes."), "liveDots")
track("hidePicked", "Show gathered spots")
place(1, UI.Check(page, "Show gathered spots", function() return not s().hidePicked end,
  function(v) s().hidePicked = not v or nil; noteTweak("hidePicked", not v); changed(); refreshAll() end,
  "A small grey dot where you gathered, until the gathered node cooldown ends."), 24, 2)
heading(1, "Collection")
track("gatherTrack", "Record what I collect")
place(1, UI.Check(page, "Record what I collect", function() return s().gatherTrack ~= false end,
  function(v) if v then s().gatherTrack = nil else s().gatherTrack = false end; changed(); refreshAll() end,
  "Skinning, creature loot, herbs and ore, for your history and maps in Material Finder. Fishing has its own journal."), 24, 2)
track("huntOverlay", "Hunting route on the overlay")
place(1, UI.Check(page, "Hunting route on the overlay", function() return s().huntOverlay ~= false end,
  function(v) if v then s().huntOverlay = nil else s().huntOverlay = false end; changed(); refreshAll(); if NW.DrawOverlay then NW.DrawOverlay() end end,
  "Rings for the hunting grounds and the route between them."), 24, 2)

heading(2, "Resource filters")
check(2, "Only my professions", "onlyMyProfessions", "Herbs if you have Herbalism, ore if you have Mining.")
check(2, "Group nearby spots", "groupSpots", "Spots that would overlap share one icon with a count.")
local chooseBtn = UI.Button(page, "Herbs and ore...", 170, function() NW.ShowTab("nodes") end, 24)
place(2, chooseBtn, 30, 2)
local hiddenCount = UI.Text(page, 11, S.dim)
hiddenCount:SetPoint("LEFT", chooseBtn, "RIGHT", 10, 0)
widgets[#widgets + 1] = { Refresh = function()
  local n = 0
  for _ in pairs(s().hiddenNodes or {}) do n = n + 1 end
  hiddenCount:SetText(n > 0 and (n .. " hidden") or "all shown")
end }
heading(2, "Routes")
slider(2, "Gathered node cooldown", 1, 20, 1, function(v) return ("%d min"):format(v) end, "respawnMinutes",
  nil, "How long a route skips a stop after you gather it.")
check(2, "Auto-build routes", "autoRoute", "In a zone with known spots and no route, Nodewalker builds one.")
local planBtn = UI.Button(page, "Open Routes", 170, function() NW.ShowRoutes() end, 24)
place(2, planBtn, 30, 2)
UI.Tip(planBtn, "Routes", "Sight range, avoid zones and the map: Material Finder › Routes.")
defaultsButton()

------------------------------------------------------------------------
-- Herbs & Ore: tick the herbs and ore you want to see (under Gathering)
------------------------------------------------------------------------
local nodeChecks = {}
local refreshNodes
local nodesPage = newPage("nodes", "Herbs & ore", nil, true)
nodesPage:HookScript("OnShow", function() refreshNodes() end)

local SKILL_HEX = { red = "ff4040", orange = "ff8040", yellow = "ffe633", green = "59cc59", grey = "8c8c8c", unknown = "d9d9d9" }
local NODE_X = COL_X[1]
local NODE_W = 1020 - NODE_X - 24
-- search, then a section each for Herbalism and Mining (one open at a time, or every match while searching)
local nodeSearch = CreateFrame("EditBox", nil, nodesPage, "BackdropTemplate")
nodeSearch:SetSize(200, 22)
nodeSearch:SetPoint("TOPLEFT", NODE_X, -10)
UI.Flat(nodeSearch, S.sunk, S.edge)
nodeSearch:SetFontObject(ChatFontNormal)
nodeSearch:SetTextInsets(8, 8, 0, 0)
nodeSearch:SetAutoFocus(false)
nodeSearch:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
nodeSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
nodeSearch:SetScript("OnTextChanged", function() refreshNodes() end)
local searchHint = UI.Text(nodeSearch, 12, S.dim)
searchHint:SetPoint("LEFT", 8, 0)
searchHint:SetText("Search")
local nodesHelp = UI.Text(nodesPage, 11, S.dim)
nodesHelp:SetPoint("LEFT", nodeSearch, "RIGHT", 12, 0)
nodesHelp:SetText("Ticked: shown on the map.  Colour: skill-ups at your skill.  Number: skill needed.")
nodesHelp:SetWidth(NODE_W - 212)
nodesHelp:SetWordWrap(false)

local sections = {}
local function section(kind, title, ncols)
  local list = {}
  for name, info in pairs(NW.NODES) do
    if info[1] == kind then list[#list + 1] = { name = name, req = info[2] or 999 } end
  end
  table.sort(list, function(a, b) if a.req ~= b.req then return a.req < b.req end return a.name < b.name end)
  local sec = { kind = kind, list = list, ncols = ncols, colW = math.floor(NODE_W / ncols), checks = {} }
  -- its heading: a fold button, the count shown, All and None
  local hb = CreateFrame("Button", nil, nodesPage)
  hb:SetSize(NODE_W - 160, 22)
  hb.fold = hb:CreateTexture(nil, "ARTWORK")
  hb.fold:SetSize(14, 14)
  hb.fold:SetPoint("LEFT")
  hb.text = UI.Text(hb, 12, S.gold)
  hb.text:SetPoint("LEFT", hb.fold, "RIGHT", 6, 0)
  hb.count = UI.Text(hb, 11, S.dim)
  hb.count:SetPoint("LEFT", hb.text, "RIGHT", 10, 0)
  hb.title = title
  hb:SetScript("OnClick", function()
    s().nodesOpen = (s().nodesOpen == kind) and (kind == "herb" and "ore" or "herb") or kind
    refreshNodes()
  end)
  local line = hb:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(S.sep))
  line:SetHeight(1)
  line:SetPoint("LEFT", hb.count, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", 0, 0)
  sec.head = hb
  local function setAll(show)
    for _, e in ipairs(list) do NW.db.settings.hiddenNodes[e.name] = (not show) or nil end
    if NW.RefreshPlanner then NW.RefreshPlanner() end
    refreshNodes()
  end
  sec.none = UI.Button(nodesPage, "None", 70, function() setAll(false) end, 20)
  sec.all = UI.Button(nodesPage, "All", 70, function() setAll(true) end, 20)
  UI.Tip(sec.all, "All", "Shows every " .. (kind == "herb" and "herb" or "vein") .. " here. Whether you can gather it is its colour.")
  for _, e in ipairs(list) do
    local cb = UI.Check(nodesPage, e.name, function() return not NW.IsHidden(e.name) end,
      function(v) NW.SetHidden(e.name, not v) refreshNodes() end)
    local icon = cb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", cb, "RIGHT", 7, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cb.icon = icon
    cb.label:ClearAllPoints()
    cb.label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    cb.entry, cb.kind = e, kind
    nodeChecks[#nodeChecks + 1] = cb
    sec.checks[#sec.checks + 1] = cb
  end
  sections[#sections + 1] = sec
  return sec
end
-- ore names run long ("Ooze Covered Rich Thorium Vein"): fewer, wider columns
section("herb", "Herbalism", 3)
section("ore", "Mining", 2)

refreshNodes = function()
  if not nodesPage:IsShown() then return end
  local q = (nodeSearch:GetText() or ""):lower()
  searchHint:SetShown(q == "" and not nodeSearch:HasFocus())
  local open = s().nodesOpen
  if open ~= "herb" and open ~= "ore" then
    open = (NW.GetSkill("herb") == nil and NW.GetSkill("ore") ~= nil) and "ore" or "herb"
  end
  local y = -42
  local hidden = 0
  for _, sec in ipairs(sections) do
    local shownN, matches = 0, {}
    for _, cb in ipairs(sec.checks) do
      local e = cb.entry
      if not NW.IsHidden(e.name) then shownN = shownN + 1 else hidden = hidden + 1 end
      if q == "" or e.name:lower():find(q, 1, true) then matches[#matches + 1] = cb end
    end
    local expanded = (q ~= "" and #matches > 0) or (q == "" and open == sec.kind)
    local hb = sec.head
    hb:ClearAllPoints()
    hb:SetPoint("TOPLEFT", nodesPage, "TOPLEFT", NODE_X, y)
    hb.fold:SetTexture(("Interface\\Buttons\\UI-%sButton-Up"):format(expanded and "Minus" or "Plus"))
    hb.text:SetText(hb.title)
    hb.count:SetText(("%d of %d shown"):format(shownN, #sec.list))
    sec.none:ClearAllPoints()
    sec.none:SetPoint("TOPRIGHT", nodesPage, "TOPRIGHT", -24, y + 1)
    sec.all:ClearAllPoints()
    sec.all:SetPoint("RIGHT", sec.none, "LEFT", -6, 0)
    y = y - 28
    for _, cb in ipairs(sec.checks) do cb:Hide() end
    if expanded then
      for i, cb in ipairs(matches) do
        local col, row = (i - 1) % sec.ncols, math.floor((i - 1) / sec.ncols)
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", nodesPage, "TOPLEFT", NODE_X + 2 + col * sec.colW, y - row * 22)
        cb:Show()
        cb:Refresh()
        local e = cb.entry
        local skill = NW.GetSkill(cb.kind)
        local hex = SKILL_HEX[NW.SkillColor(e.req < 999 and e.req or nil, skill)] or SKILL_HEX.unknown
        cb.icon:SetTexture(NW.NodeIcon(e.name, cb.kind))
        cb.icon:SetDesaturated(NW.IsHidden(e.name))
        cb:SetLabel(("|cff%s%s|r  |cff6f6f74%s|r"):format(hex, e.name, e.req < 999 and e.req or ""))
      end
      y = y - math.ceil(#matches / sec.ncols) * 22 - 10
    end
  end
  NW.SetWindowSubtitle(hidden > 0 and (hidden .. " hidden") or "Showing everything")
end
nodeSearch:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
nodeSearch:SetScript("OnEditFocusLost", function() refreshNodes() end)
NW.RefreshNodeOptions = function() if nodesPage:IsShown() then refreshNodes() end end

------------------------------------------------------------------------
-- Fishing: Smart Fishing, lures, gear, the HUD, the Journal, notices
------------------------------------------------------------------------
if NW.SmartFish then
  local SF = NW.SmartFish
  local function hud() SF.Update() end
  newPage("fishing", "Fishing", "Interface\\Icons\\Trade_Fishing")
  heading(1, "Smart Fishing")
  local keyBtn = SF.KeyButton(page, 260)
  place(1, keyBtn, 32, 2)
  check(1, "Reel in with the same key", "fishInteract",
    "While the bobber is out, the key works as the game's Interact Key on it. Turns on interact targeting while you fish.", function() SF.ApplyKey() end)
  heading(1, "Lures")
  local lureItems = {}
  for _, l in ipairs(SF.LURES) do lureItems[#lureItems + 1] = { l[1], ("%s  +%d"):format(SF.LURE_NAME[l[1]], l[2]) } end
  track("fishLure", "Lure")
  place(1, UI.Dropdown(page, COL_W - 20, "Lure", { { "off", "No lure" }, { "pref", "My preferred lure" }, { "best", "Strongest I carry" } },
    function() return s().fishLure or "off" end, function(v) s().fishLure = v; hud(); refreshAll() end, 200,
    "When there's no lure on your pole, Smart Fishing puts one on first."), 30, 2)
  track("fishLurePref", "Preferred lure")
  local pref = place(1, UI.Dropdown(page, COL_W - 20, "Preferred lure", lureItems,
    function() return s().fishLurePref or SF.DEFAULT_LURE end, function(v) s().fishLurePref = v; hud() end, 200,
    "Used when Lure is My preferred lure."), 30, 2)
  local oldPref = pref.Refresh
  function pref:Refresh() if oldPref then oldPref(self) end self:SetAlpha(s().fishLure == "pref" and 1 or 0.45) end
  local alt = check(1, "Use another lure if I'm out", "fishLureAlt", "Used when Lure is My preferred lure.", hud)
  local oldAlt = alt.Refresh
  function alt:Refresh() if oldAlt then oldAlt(self) end local on = s().fishLure == "pref"; self:SetAlpha(on and 1 or 0.45) end

  -- your fishing gear as slots: the pole and the pieces saved with it (native tooltips)
  heading(1, "Equipment")
  local SLOTS = { { 16, "MainHand", "Fishing pole" }, { 1, "Head", "Head" }, { 10, "Hands", "Hands" }, { 8, "Feet", "Feet" } }
  local slotRow = CreateFrame("Frame", nil, page)
  slotRow:SetSize(COL_W, 58)
  slotRow.slots = {}
  for i, sl in ipairs(SLOTS) do
    local b = CreateFrame("Button", nil, slotRow, "BackdropTemplate")
    b:SetSize(32, 32)
    b:SetPoint("TOPLEFT", (i - 1) * 64, 0)
    UI.Flat(b, S.sunk, S.edge)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 1, -1)
    b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    b.count = UI.Text(b, 11, S.text, "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.slot, b.slotTex, b.slotName = sl[1], "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. sl[2], sl[3]
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if not (self.item and pcall(GameTooltip.SetItemByID, GameTooltip, self.item)) then
        GameTooltip:SetText(self.slotName, 1, 1, 1)
        GameTooltip:AddLine(self.slot == 16 and "No fishing pole in your bags." or "Not saved with your pole.", S.dim[1], S.dim[2], S.dim[3], true)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    -- head, hands, feet: whether Use what I'm wearing saves that slot
    if sl[1] ~= 16 then
      local cb = UI.Check(slotRow, "", function() return (s().fishGearSlots or {})[sl[1]] end,
        function(v) s().fishGearSlots = s().fishGearSlots or {}; s().fishGearSlots[sl[1]] = v or nil end,
        "Saved with your pole when you click Use what I'm wearing.")
      cb:SetPoint("TOP", b, "BOTTOM", -4, -6)
      cb:SetLabel("")
      widgets[#widgets + 1] = cb
    end
    slotRow.slots[i] = b
  end
  slotRow.note = UI.Text(slotRow, 11, S.dim)
  slotRow.note:SetPoint("LEFT", slotRow.slots[4], "RIGHT", 14, 0)
  slotRow.note:SetWidth(COL_W - 4 * 64 + 20)
  function slotRow:Refresh()
    local g, saved = SF.gearSet()
    for _, b in ipairs(self.slots) do
      local id = g and g[b.slot]
      b.item = id
      b.tex:SetTexture(id and NW.ItemIcon(id) or b.slotTex)
      b.tex:SetTexCoord(id and 0.08 or 0, id and 0.92 or 1, id and 0.08 or 0, id and 0.92 or 1)
      b.count:SetText((b.slot == 16 and g and SF.GearBonus(g) > 0) and ("+" .. SF.GearBonus(g)) or "")
    end
    self.note:SetText(not g and "No pole in your bags" or (saved and "Saved set" or "Your best pole"))
  end
  place(1, slotRow, 60, 2)
  local saveBtn = UI.Button(page, "Use what I'm wearing", 170, function()
    if not SF.SaveWorn() and UIErrorsFrame then UIErrorsFrame:AddMessage("Put your fishing pole on first", S.gold[1], S.gold[2], S.gold[3]) end
    refreshAll()
  end, 24)
  place(1, saveBtn, 30, 2)
  local clearBtn = UI.Button(page, "Clear", 70, function() SF.ClearGear(); refreshAll() end, 24)
  clearBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
  UI.Tip(clearBtn, "Clear", "Forgets the saved set. Smart Fishing then uses your best pole.")
  local eq = SF.Button(page, "equip", 126, 24, "Equip fishing gear") -- (ordinary buttons: out of combat)
  place(1, eq, 30, 2)
  local rs = SF.Button(page, "restore", 126, 24, "Restore my gear")
  rs:SetPoint("LEFT", eq, "RIGHT", 6, 0)

  heading(2, "Fishing HUD")
  check(2, "Show the HUD", "fishHud", "While a fishing pole is on, or for 5 minutes after you last fished.", hud)
  dependsOn(checkBeside(2, "Minimal", "fishHudMini", "Needs Show the HUD.", hud), "fishHud")
  dependsOn(check(2, "Lock position", "fishHudLock", "Needs Show the HUD."), "fishHud")
  dependsOn(checkBeside(2, "Cooking target", "fishHudTarget", "The fish your Fishing + Cooking plan wants next.", hud), "fishHud")
  dependsOn(check(2, "Catch value", "fishHudValue", "Estimated at Auctionator prices.", hud), "fishHud")
  dependsOn(slider(2, "Scale", 0.6, 1.5, 0.05, pct, "fishHudScale", hud), "fishHud")
  dependsOn(slider(2, "Opacity", 0.3, 1, 0.05, pct, "fishHudAlpha", hud), "fishHud")
  heading(2, "Journal")
  check(2, "Record catches", "fishTrack", "Only loot the game marks as fishing loot.")
  dependsOn(checkBeside(2, "Catch spots", "fishTrackSpots", "Where you stood, to 2% of the map. Needs Record catches."), "fishTrack")
  check(2, "Sessions", "fishSessions", nil, function(v) if not v and NW.FishJournal then NW.FishJournal.SessionsOff() end end)
  dependsOn(checkBeside(2, "Start one when I cast", "fishAutoSession", "A session ends 20 minutes after you last fished. Needs Sessions."), "fishSessions")
  local jb = UI.Button(page, "Open the Journal", 170, function() NW.OpenFishJournal() end, 24)
  place(2, jb, 30, 2)
  heading(2, "Notices")
  check(2, "New fish", "fishNotifyNew")
  checkBeside(2, "Rare catches", "fishNotifyRare", "Rare quality or better, by the game's own item quality.")
  check(2, "Lures", "fishNotifyLure", "Expiring, expired, running low, preferred one missing.")
  checkBeside(2, "Collection complete", "fishNotifyTarget", "The fish your Fishing + Cooking plan wants.")
  check(2, "Sound", "fishSound")
  checkBeside(2, "Quiet while fishing", "fishQuiet",
    "Music and ambience off, sound effects to full so the splash stands out. Your volumes come back when the pole comes off or 90 seconds after your last cast.",
    function(v) if not v then SF.Unquiet() end end)
  defaultsButton(function() SF.ApplyKey(); hud() end)
end

------------------------------------------------------------------------
-- Data & Integrations: other add-ons, where the data comes from, upkeep
------------------------------------------------------------------------
newPage("data", "Data & Integrations", "Interface\\Icons\\INV_Misc_Book_09")
local function loaded(name)
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  return f and f(name) and true or false
end
local function yes(on, off) return on and "|cff94ba78loaded|r" or ("|cff6f6f74" .. (off or "not loaded") .. "|r") end
heading(1, "Add-ons")
infoLine(1, "Auctionator", function() return yes(NW.HasAuctionator and NW.HasAuctionator(), "not loaded: vendor prices only") end,
  "Prices for leveling costs, shopping lists and catch values.")
infoLine(1, "GatherMate2", function() return yes(_G.GatherMate2 ~= nil) end,
  "Only needed for an import. Turn it on for one login, import, then you can turn it off.")
infoLine(1, "LibDBIcon", function()
  local ls = LibStub and LibStub("LibDBIcon-1.0", true)
  return yes(ls ~= nil, "not loaded: own minimap button")
end, "Used only when another add-on loads it.")
local gmBtn = UI.Button(page, "Import GatherMate2", 170, function()
  NW.ImportGatherMate2()
  if NW.RefreshPlanner then NW.RefreshPlanner() end
  refreshAll()
end, 24)
place(1, gmBtn, 30, 2)
UI.Tip(gmBtn, "Import GatherMate2", "Copies its herb and ore spots, and its data pack. Your own spots stay.")
heading(1, "Where the data comes from")
infoLine(1, "Items, recipes, spells", "WoW Forever client")
infoLine(1, "Drops, spawns, skinning", "Classic data (pfQuest, cMaNGOS)",
  "Classic 1.12 data; creatures and chances may differ in WoW Forever.")
infoLine(1, "Fishing skill ranges", "leveling guides", "A guide's skill, not a confirmed minimum.")
infoLine(1, "Prices", "Auctionator, else vendor")
infoLine(1, "Your spots and catches", "recorded by you", "Stay on this PC, in your SavedVariables.")

heading(2, "Saved")
infoLine(2, "Known spots", function()
  local n, z = 0, 0
  for _, list in pairs(NW.db.nodes or {}) do if #list > 0 then z = z + 1 end n = n + #list end
  return ("%d in %d zones"):format(n, z)
end)
infoLine(2, "Saved routes", function()
  local n = 0
  for _, r in pairs(NW.db.routes or {}) do if r.stops and #r.stops > 0 then n = n + 1 end end
  return tostring(n)
end)
heading(2, "Diagnostics")
local memLine = infoLine(2, "Memory", function() return NW.memShown or "|cff6f6f74not measured|r" end,
  "What the game charges to Nodewalker, garbage not yet collected included.")
local memBtn = UI.Button(page, "Measure", 80, function()
  local kb = NW.PerfMem and NW.PerfMem()
  NW.memShown = kb and ("%.0f KB"):format(kb) or "?"
  memLine:Refresh()
end, 20)
memBtn:SetPoint("RIGHT", memLine, "RIGHT", 0, 0)
memLine.r:ClearAllPoints()
memLine.r:SetPoint("RIGHT", memBtn, "LEFT", -8, 0)
local perfRow = CreateFrame("Frame", nil, page)
perfRow:SetSize(COL_W, 26)
local timBtn = UI.Button(perfRow, "Timings", 110, function()
  NW.Perf.on = not NW.Perf.on
  if NW.Perf.on then NW.Perf.stats = {} end
  refreshAll()
end, 22)
timBtn:SetPoint("LEFT")
function perfRow:Refresh() timBtn:SetText(NW.Perf and NW.Perf.on and "Timings: on" or "Timings: off") end
UI.Tip(timBtn, "Timings", "Times the slow parts while on. Report prints them in chat.")
local repBtn = UI.Button(perfRow, "Report", 80, function() NW.PerfReport() end, 22)
repBtn:SetPoint("LEFT", timBtn, "RIGHT", 6, 0)
UI.Tip(repBtn, "Report", "Memory, caches and timings, in chat.")
local cacheBtn = UI.Button(perfRow, "Clear caches", 110, function()
  if NW.Hunt and NW.Hunt.ClearCache then NW.Hunt.ClearCache() end
  if NW.GuideClearCaches then NW.GuideClearCaches() end
  NW.Print("Caches cleared. They rebuild when viewed.")
end, 22)
cacheBtn:SetPoint("LEFT", repBtn, "RIGHT", 6, 0)
UI.Tip(cacheBtn, "Clear caches", "The hunting grounds and zone rankings, rebuilt when viewed. Routes, hunts, goals, journals and settings stay.")
place(2, perfRow, 30, 2)
heading(2, "This session")
local sessBtn
sessBtn = UI.Button(page, "Reset session", 130, function()
  if not rawget(sessBtn, "armed") then
    sessBtn.armed = true
    sessBtn:SetText("Click to confirm")
    C_Timer.After(4, function() sessBtn.armed = nil; sessBtn:SetText("Reset session") end)
    return
  end
  sessBtn.armed = nil
  sessBtn:SetText("Reset session")
  NW.ResetSession()
end, 22)
place(2, sessBtn, 30, 2)
UI.Tip(sessBtn, "Reset session", "The session panel's loops, nodes and gold per hour start again. Nothing saved changes.")

------------------------------------------------------------------------
-- The sidebar: one row a category (Herbs & ore indented under Gathering)
------------------------------------------------------------------------
UI.HideGroupSubs("Settings")
local nav = UI.Box(NW.window, SIDE_W, 8)
nav:SetPoint("TOPLEFT", NW.window, "TOPLEFT", SIDE_X, -UI.CONTENT_TOP - 8)
nav:Hide()
local navRows = {}
for i, c in ipairs(CATS) do
  local b = CreateFrame("Button", nil, nav)
  b:SetSize(SIDE_W - 2, c.child and 24 or NAV_H)
  UI.RowHighlight(b)
  b.name = UI.Text(b, c.child and 11 or 12, c.child and S.dim or S.text)
  if c.icon then
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", 7, 0)
    b.icon:SetTexture(c.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
  else
    b.name:SetPoint("LEFT", 34, 0)
  end
  b.name:SetPoint("RIGHT", -6, 0)
  b.name:SetWordWrap(false)
  b.name:SetText(c.label)
  b:SetScript("OnClick", function() NW.ShowTab(c.key) end)
  b.key = c.key
  navRows[i] = b
end
do
  local y = -4
  for _, b in ipairs(navRows) do
    b:SetPoint("TOPLEFT", 1, y)
    y = y - b:GetHeight()
  end
  nav:SetHeight(-y + 4)
end
syncNav = function()
  local key = NW.CurrentTab and NW.CurrentTab()
  local on = false
  for _, c in ipairs(CATS) do if c.page:IsShown() then on = true end end
  nav:SetShown(on)
  for _, b in ipairs(navRows) do b:SetSelected(b.key == key) end
end
-- old Settings tabs (a saved last tab, a link) open where their settings live now
NW.TAB_ALIAS = NW.TAB_ALIAS or {}
NW.TAB_ALIAS.overlay = function() return "general" end
NW.TAB_ALIAS.look = function() return "map" end
NW.TAB_ALIAS.routes = function() return "gather" end

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
  if NW.window:IsShown() then NW.ShowTab("general") else NW.db.settings.lastTab = "general"; NW.window:Show() end
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
local ldbIcon -- LibDBIcon, when another addon has loaded it: its button replaces ours
function NW.UpdateMinimapButton()
  local want = s().minimapButton and true or false
  -- the overlay hides the minimap and its AddOns menu: our button stays the way back
  local live = NW.IsLive and NW.IsLive()
  if live and mmBtn then
    if ldbIcon then ldbIcon:Hide("Nodewalker") end
    if mmReady then placeButton() end
    mmBtn:SetShown(mmReady)
    return
  end
  if ldbIcon then
    s().ldbIcon = s().ldbIcon or {}
    s().ldbIcon.hide = not want
    if want then ldbIcon:Show("Nodewalker") else ldbIcon:Hide("Nodewalker") end
    if mmBtn then mmBtn:Hide() end
    return
  end
  if mmBtn then mmBtn:SetShown(mmReady and want) end
end

-- The game's addon menu on the minimap, and button-collector addons: they
-- list addons that register through the game or through LibDBIcon.
local function onClick(button)
  if button == "RightButton" then NW.ToggleWindow() else NW.ToggleOverlay() end
end
local function tooltipLines(tt)
  tt:AddLine("Nodewalker", C.gold[1], C.gold[2], C.gold[3])
  tt:AddLine("Left-click: overlay", 0.8, 0.8, 0.85)
  tt:AddLine("Right-click: window", 0.8, 0.8, 0.85)
end
table.insert(NW.OnLoad, function()
  local ICON = "Interface\\AddOns\\Nodewalker\\Media\\Icon"
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    -- listed in the AddOns menu, so the button on the minimap's edge starts off
    if not s().mmInMenu then
      s().mmInMenu = true
      s().minimapButton = false
    end
    pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
      text = "Nodewalker",
      icon = ICON,
      notCheckable = true,
      func = function(_, input, _, _, mouseButton)
        -- (the game passes the mouse button in different places across versions)
        local b = type(input) == "table" and input.buttonName or mouseButton or input
        onClick(b == "RightButton" and "RightButton" or "LeftButton")
      end,
      funcOnEnter = function(button)
        -- the menu row; anything else (a plain table) can't own a tooltip
        local owner = type(button) == "table" and button.GetObjectType and button or AddonCompartmentFrame
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        tooltipLines(GameTooltip)
        GameTooltip:Show()
      end,
      funcOnLeave = function() GameTooltip:Hide() end,
    })
  end
  local LS = LibStub
  local ldb = LS and LS("LibDataBroker-1.1", true)
  local icon = LS and LS("LibDBIcon-1.0", true)
  if ldb and icon then
    local obj = ldb:NewDataObject("Nodewalker", {
      type = "launcher",
      icon = ICON,
      OnClick = function(_, b) onClick(b) end,
      OnTooltipShow = tooltipLines,
    })
    s().ldbIcon = s().ldbIcon or {}
    if pcall(icon.Register, icon, "Nodewalker", obj, s().ldbIcon) then ldbIcon = icon end
  end
end)

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

  mmBtn:SetScript("OnClick", function(_, b) onClick(b) end)
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
    tooltipLines(GameTooltip)
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
