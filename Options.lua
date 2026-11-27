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
-- Reset this page, at the page's foot: puts back the settings on this page only (a second click confirms)
local function defaultsButton(after)
  local keys = page.keys
  local b
  b = UI.Button(page, "Reset this page", 130, function()
    if not rawget(b, "armed") then
      b.armed = true
      b:SetText("Click again to reset")
      -- (only the latest arming times out: an older timer can't cut a new confirm short)
      local id = (rawget(b, "armID") or 0) + 1
      b.armID = id
      C_Timer.After(4, function() if b.armID == id then b.armed = nil; b:SetText("Reset this page") end end)
      return
    end
    b.armed = nil
    b:SetText("Reset this page")
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
  UI.Tip(b, "Reset this page", function()
    local names = {}
    for _, k in ipairs(keys) do names[#names + 1] = LABELS[k] or k end
    return "Back to their defaults, on this page only: " .. table.concat(names, ", ") .. ".\nOther pages, routes, journals and what you've recorded stay as they are."
  end)
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

-- key bindings: set here (the game's own binding system, the same as Key Bindings ›
-- AddOns): click, then press a key; a key already in use asks for a second press;
-- right-click clears
heading(1, "Key bindings")
local function keyName(k) return GetBindingText and GetBindingText(k, "KEY_") or k end
local bindStops = {} -- every row's stop(): one waits at a time, and combat stops them all
NW.On("PLAYER_REGEN_DISABLED", function() for _, f in ipairs(bindStops) do f() end end)
local function bindButton(action, label, after)
  local row = CreateFrame("Frame", nil, page)
  row:SetSize(COL_W, 24)
  row.l = UI.Text(row, 12, S.text)
  row.l:SetPoint("LEFT")
  row.l:SetText(label)
  local b = UI.Button(row, "", 150, nil, 22)
  b:SetPoint("RIGHT")
  local function keys() if not GetBindingKey then return {} end return { GetBindingKey(action) } end
  local function show()
    local k = keys()[1]
    if rawget(b, "waiting") then
      b:SetText(rawget(b, "confirm") and ("Press %s again"):format(keyName(b.confirm)) or "Press a key...")
      b.label:SetTextColor(unpack(S.gold))
    elseif k then
      b:SetText(keyName(k))
      b.label:SetTextColor(unpack(S.gold))
    else
      b:SetText("Not bound")
      b.label:SetTextColor(unpack(S.dim))
    end
  end
  row.Refresh = show
  local function listen(on)
    b:EnableKeyboard(on)
    if b.EnableGamePadButton then pcall(b.EnableGamePadButton, b, on) end
  end
  local function stop() if rawget(b, "waiting") then b.waiting, b.confirm = nil, nil; listen(false); show() end end
  bindStops[#bindStops + 1] = stop
  local function save() pcall(function() SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end) end
  local function inCombat() return InCombatLockdown and InCombatLockdown() end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(_, button)
    if inCombat() then return end -- the game blocks binding changes in combat
    if button == "RightButton" then
      -- clears the key shown; a second key set in Key Bindings stays
      local k1 = keys()[1]
      if k1 then SetBinding(k1) end
      save(); stop(); if after then after() end
      refreshAll()
      return
    end
    if rawget(b, "waiting") then stop() return end
    for _, f in ipairs(bindStops) do f() end
    b.waiting, b.confirm = true, nil
    listen(true)
    pcall(b.SetPropagateKeyboardInput, b, false)
    show()
  end)
  local function take(_, key)
    if not rawget(b, "waiting") then return end
    if inCombat() then stop() return end -- (never hold a key back in a fight)
    if key == "ESCAPE" or key == "PADBACK" then stop() return end
    if key:find("SHIFT$") or key:find("CTRL$") or key:find("ALT$") then return end
    local full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    local was = GetBindingAction and GetBindingAction(full) or ""
    if was ~= "" and was ~= action and rawget(b, "confirm") ~= full then
      b.confirm, b.boundTo = full, was
      show()
      return
    end
    -- the new key takes the shown one's place; a second key set in Key Bindings stays
    local k1 = keys()[1]
    if k1 and k1 ~= full then SetBinding(k1) end
    SetBinding(full, action)
    save(); stop(); if after then after() end
    refreshAll()
  end
  b:SetScript("OnKeyDown", take)
  pcall(b.SetScript, b, "OnGamePadButtonDown", take)
  b:SetScript("OnHide", function() b.waiting, b.confirm = nil, nil; listen(false) end)
  b:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(label, 1, 1, 1)
    local c, was = rawget(self, "confirm"), rawget(self, "boundTo")
    if c and was then
      GameTooltip:AddLine(("%s is bound to %s. Press it again to move it here."):format(keyName(c), _G["BINDING_NAME_" .. was] or was), 1, 0.82, 0.2, true)
    end
    local all = keys()
    if #all > 1 then
      local names = {}
      for _, k in ipairs(all) do names[#names + 1] = keyName(k) end
      GameTooltip:AddDoubleLine("Keys", table.concat(names, ", "), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    end
    GameTooltip:AddLine("Click, then press a key. Right-click to clear. Also in Key Bindings › AddOns.", S.dim[1], S.dim[2], S.dim[3], true)
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", GameTooltip_Hide)
  return place(1, row, 26, 2)
end
for _, b in ipairs({ { "NODEWALKER_TOGGLE", "Overlay" }, { "NODEWALKER_PLANNER", "Routes" }, { "NODEWALKER_NEXT", "Skip to next stop" },
  { "NODEWALKER_FISHHUD", "Fishing HUD" }, { "NODEWALKER_JOURNAL", "Fishing Journal" } }) do
  bindButton(b[1], b[2])
end
if NW.SmartFish then
  local SF = NW.SmartFish
  bindButton(SF.COMMAND, "Smart Fishing", function() if SF.ApplyKey then SF.ApplyKey() end if SF.KeyRefresh then SF.KeyRefresh() end end)
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
defaultsButton(function() NW.SetWindowScale(s().winScale or 1) end)

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
-- Preview: the real overlay, shown for a while whatever the visibility rules say;
-- your Show overlay setting isn't touched, so it goes back as it was
local mapPage = page
local preview
local function endPreview()
  if not NW.overlayPreview then return end
  NW.overlayPreview = nil
  if NW.overlay then NW.overlay:SetFrameStrata("BACKGROUND") end
  NW.UpdateVisibility()
  if preview then preview:SetText("Preview overlay") end
end
preview = UI.Button(page, "Preview overlay", 150, function()
  if NW.overlayPreview then endPreview() return end
  if InCombatLockdown and InCombatLockdown() then return end
  NW.overlayPreview = true
  -- above this window while it lasts (it's drawn under everything otherwise)
  if NW.overlay then NW.overlay:SetFrameStrata("DIALOG") end
  if NW.RecentreOverlay then NW.RecentreOverlay() end
  NW.UpdateVisibility()
  preview:SetText("End preview")
  local id = (rawget(preview, "pid") or 0) + 1
  preview.pid = id
  C_Timer.After(20, function() if preview.pid == id then endPreview() end end)
end, 24)
place(1, preview, 30, 2)
UI.Tip(preview, "Preview overlay", "Shows the overlay for 20 seconds, even where it would be hidden, so you can see your changes. Ends when you leave this page; Show overlay stays as you set it.")
mapPage:HookScript("OnHide", endPreview)

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
  hiddenCount:SetText(n > 0 and (n .. " herbs and ore hidden") or "all shown")
end }
heading(2, "Routes")
slider(2, "Gathered node cooldown", 1, 20, 1, function(v) return ("%d min"):format(v) end, "respawnMinutes",
  nil, "How long a route skips a stop after you gather it.")
check(2, "Auto-build routes", "autoRoute", "In a zone with known spots and no route, Nodewalker builds one.")
local planBtn = UI.Button(page, "Open Routes", 170, function() NW.ShowRoutes() end, 24)
place(2, planBtn, 30, 2)
UI.Tip(planBtn, "Routes", "Sight range, avoid zones and the map: Material Finder › Routes.")
defaultsButton(function()
  if NW.ApplyQuestRing then NW.ApplyQuestRing() end
  if NW.DrawOverlay then NW.DrawOverlay() end
end)

------------------------------------------------------------------------
-- Herbs & Ore: tick the herbs and ore you want to see (under Gathering)
------------------------------------------------------------------------
local nodeChecks = {}
local refreshNodes
local nodesPage = newPage("nodes", "Herbs & ore", "Interface\\Icons\\Trade_Mining", true)
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
  hb:SetSize(NODE_W - 340, 22)
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
  sec.none = UI.Button(nodesPage, "None", 56, function() setAll(false) end, 20)
  sec.all = UI.Button(nodesPage, "All", 56, function() setAll(true) end, 20)
  local what = kind == "herb" and "herbs" or "veins"
  local prof = kind == "herb" and "Herbalism" or "Mining"
  UI.Tip(sec.all, "All", "Shows every one of these " .. what .. ", the whole section (not just a search). Whether you can gather one is its colour.")
  UI.Tip(sec.none, "None", "Hides all of these " .. what .. ", the whole section.")
  -- one-time picks by your skill now: shown if they match, hidden if not; ones with no
  -- known skill stay as they are. Nothing changes later by itself.
  local function pick(want)
    local skill = NW.GetSkill(kind)
    if not skill then return end
    for _, e in ipairs(list) do
      if e.req < 999 then
        local c = NW.SkillColor(e.req, skill)
        NW.db.settings.hiddenNodes[e.name] = (not want(c)) or nil
      end
    end
    if NW.RefreshPlanner then NW.RefreshPlanner() end
    refreshNodes()
  end
  -- (it replaces your picks in this section, so a second click confirms)
  local function armed(bb, text, fn)
    return function()
      if not rawget(bb[1], "armed") then
        bb[1].armed = true
        bb[1]:SetText("Click again")
        local id = (rawget(bb[1], "armID") or 0) + 1
        bb[1].armID = id
        C_Timer.After(4, function() if bb[1].armID == id then bb[1].armed = nil; bb[1]:SetText(text) end end)
        return
      end
      bb[1].armed = nil
      bb[1]:SetText(text)
      fn()
    end
  end
  local skuRef, gatRef = {}, {}
  sec.sku = UI.Button(nodesPage, "Skill-ups", 80, armed(skuRef, "Skill-ups", function()
    pick(function(c) return c == "orange" or c == "yellow" or c == "green" end)
  end), 20)
  sec.gat = UI.Button(nodesPage, "Gatherable", 90, armed(gatRef, "Gatherable", function()
    pick(function(c) return c ~= "red" end)
  end), 20)
  skuRef[1], gatRef[1] = sec.sku, sec.gat
  for _, bb in ipairs({ sec.sku, sec.gat }) do
    if bb.SetMotionScriptsWhileDisabled then bb:SetMotionScriptsWhileDisabled(true) end
  end
  UI.Tip(sec.gat, "Gatherable", function()
    if not NW.GetSkill(kind) then return "You don't have " .. prof .. "." end
    return ("Shows the %s you can gather at %s %d and hides the rest. Once, now: it doesn't change as your skill goes up. Whole section; replaces your picks here (click twice)."):format(what, prof, NW.GetSkill(kind))
  end)
  UI.Tip(sec.sku, "Skill-ups", function()
    if not NW.GetSkill(kind) then return "You don't have " .. prof .. "." end
    return ("Shows the %s that still give skill-ups at %s %d (orange, yellow, green) and hides the rest. Once, now. Whole section; replaces your picks here (click twice)."):format(what, prof, NW.GetSkill(kind))
  end)
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
    sec.sku:ClearAllPoints()
    sec.sku:SetPoint("RIGHT", sec.all, "LEFT", -6, 0)
    sec.gat:ClearAllPoints()
    sec.gat:SetPoint("RIGHT", sec.sku, "LEFT", -6, 0)
    local known = NW.GetSkill(sec.kind) ~= nil
    sec.sku:SetEnabled(known)
    sec.gat:SetEnabled(known)
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
  local SLOTS = { { 16, "MainHand", "Pole" }, { 1, "Head", "Head" }, { 10, "Hands", "Hands" }, { 8, "Feet", "Feet" } }
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
    -- worn now: a tick in the corner (the set is what Equip puts on; this is what you have on)
    b.worn = b:CreateTexture(nil, "OVERLAY")
    b.worn:SetSize(12, 12)
    b.worn:SetPoint("TOPRIGHT", 3, 3)
    b.worn:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    b.cap = UI.Text(slotRow, 10, S.dim, "CENTER")
    b.cap:SetPoint("TOP", b, "BOTTOM", 0, -3)
    b.cap:SetText(sl[3])
    b.slot, b.slotTex, b.slotName = sl[1], "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. sl[2], sl[3]
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local d = S.dim
      if not (self.item and pcall(GameTooltip.SetItemByID, GameTooltip, self.item)) then
        GameTooltip:SetText(self.slotName, 1, 1, 1)
        if self.slot == 16 then
          GameTooltip:AddLine("No fishing pole in your bags.", d[1], d[2], d[3], true)
        elseif (s().fishGearSlots or {})[self.slot] then
          GameTooltip:AddLine("Ticked: saved with your pole the next time you click Use what I'm wearing.", d[1], d[2], d[3], true)
        else
          GameTooltip:AddLine("Not in your fishing set. Tick it to save this slot with your pole.", d[1], d[2], d[3], true)
        end
      else
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fishing set", self.saved and "saved" or "your best pole", d[1], d[2], d[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Now", self.isWorn and "worn" or "in your bags", d[1], d[2], d[3], 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    -- head, hands, feet: whether Use what I'm wearing saves that slot
    if sl[1] ~= 16 then
      -- (beside its slot; named in its tooltip)
      local cb = UI.Check(slotRow, sl[3], function() return (s().fishGearSlots or {})[sl[1]] end,
        function(v) s().fishGearSlots = s().fishGearSlots or {}; s().fishGearSlots[sl[1]] = v or nil; refreshAll() end,
        "Ticked: saved with your pole when you click Use what I'm wearing.")
      cb:SetPoint("LEFT", b, "RIGHT", 4, 0)
      cb:SetLabel("")
      widgets[#widgets + 1] = cb
    end
    slotRow.slots[i] = b
  end
  slotRow.note = UI.Text(slotRow, 11, S.dim)
  slotRow.note:SetPoint("LEFT", slotRow.slots[4], "RIGHT", 26, 0)
  slotRow.note:SetWidth(COL_W - 4 * 64 + 6)
  function slotRow:Refresh()
    local g, saved = SF.gearSet()
    for _, b in ipairs(self.slots) do
      local id = g and g[b.slot]
      b.item, b.saved = id, saved
      b.isWorn = id ~= nil and GetInventoryItemID and GetInventoryItemID("player", b.slot) == id
      b.worn:SetShown(b.isWorn and true or false)
      b.tex:SetTexture(id and NW.ItemIcon(id) or b.slotTex)
      b.tex:SetTexCoord(id and 0.08 or 0, id and 0.92 or 1, id and 0.08 or 0, id and 0.92 or 1)
      -- an empty slot: not in the set (faint); its name stays under it
      b.tex:SetAlpha(id and 1 or 0.45)
      b.cap:SetTextColor(unpack(id and S.text or S.dim))
      b.count:SetText((b.slot == 16 and g and SF.GearBonus(g) > 0) and ("+" .. SF.GearBonus(g)) or "")
    end
    self.note:SetText((not g and "No pole in your bags" or (saved and "Saved set" or "Your best pole"))
      .. "\n|TInterface\\RaidFrame\\ReadyCheck-Ready:10:10:0:0|t worn now")
  end
  -- what you have on changes the ticks
  NW.On("PLAYER_EQUIPMENT_CHANGED", function() if slotRow:IsVisible() then slotRow:Refresh() end end)
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
-- Consumes: the buff tracker (what it tracks is your Consumes loadout)
------------------------------------------------------------------------
if NW.BuffTracker then
  local BT = NW.BuffTracker
  local function apply() BT.Apply() end
  newPage("buffs", "Consumes", "Interface\\Icons\\INV_Potion_62")
  heading(1, "Tracker")
  check(1, "Show the tracker", "buffHud", "The consumables you picked in Consumes: what's on you, what's missing, how many you carry. Follows your loadout, level and spec.",
    function(v) BT.Toggle(v) end)
  dependsOn(checkBeside(1, "Lock position", "buffHudLock", "Needs Show the tracker.", apply), "buffHud")
  dependsOn(check(1, "Click to use", "buffClickUse", "Click an icon to use the item. Right-click opens it in Consumes.", apply), "buffHud")
  dependsOn(checkBeside(1, "Hide when fully buffed", "buffHideOk", "Buffs only; potions and the like stay.", apply), "buffHud")
  dependsOn(check(1, "Hide in cities and inns", "buffHideResting", "It comes back when a fight starts.", apply), "buffHud")
  dependsOn(checkBeside(1, "Hide while mounted", "buffHideMounted", "It comes back when a fight starts.", apply), "buffHud")
  local resetPos = UI.Button(page, "Reset position", 130, function() BT.ResetPosition() end, 22)
  place(1, resetPos, 30, 2)
  heading(1, "Display")
  track("buffMode", "Show")
  dependsOn(place(1, UI.Dropdown(page, COL_W - 20, "Show", { { "missing", "Missing only" }, { "soon", "Missing + expiring" }, { "all", "Show all, dim active" } },
    function() return s().buffMode or "soon" end, function(v) s().buffMode = v; apply() end, 200), 30, 2), "buffHud")
  track("buffLayout", "Layout")
  dependsOn(place(1, UI.Dropdown(page, COL_W - 20, "Layout", { { "horizontal", "Horizontal" }, { "vertical", "Vertical" } },
    function() return s().buffLayout or "horizontal" end, function(v) s().buffLayout = v; apply() end, 200), 30, 2), "buffHud")
  dependsOn(slider(1, "Icon size", 20, 48, 2, function(v) return ("%d"):format(v) end, "buffIconSize", apply,
    "The icons only; counts and times keep their size."), "buffHud")
  dependsOn(slider(1, "Scale", 0.6, 1.5, 0.05, pct, "buffHudScale", apply, "Everything, text included."), "buffHud")
  dependsOn(slider(1, "Opacity", 0.3, 1, 0.05, pct, "buffHudAlpha", apply), "buffHud")
  dependsOn(check(1, "Inventory counts", "buffShowCount", "How many are in your bags, bottom right.", apply), "buffHud")
  dependsOn(checkBeside(1, "Buff duration", "buffShowTime", "Time left, above each icon.", apply), "buffHud")
  dependsOn(check(1, "Hide out of stock", "buffHideEmpty", "None in your bags and not on you. A buff that's on stays.", apply), "buffHud")
  heading(2, "Duration warnings")
  dependsOn(slider(2, "Expiring at", 1, 15, 1, function(v) return ("%d min"):format(v) end, "buffWarnMin", apply,
    "A buff with less time left than this gets a gold edge."), "buffHud")
  heading(2, "Cooldowns")
  dependsOn(check(2, "Potions, runes and bandages", "buffCooldowns",
    "Their own row: how many you carry and their cooldown. Never counted as missing.", function() BT.Refresh(true) end), "buffHud")
  heading(2, "Notices")
  dependsOn(check(2, "Expired", "buffNotifyMissing", "A tracked buff ran out."), "buffHud")
  dependsOn(checkBeside(2, "Expiring", "buffNotifyExpiring", "Once, at your Expiring at time."), "buffHud")
  dependsOn(check(2, "Out of stock", "buffNotifyStock", "You used your last one."), "buffHud")
  dependsOn(checkBeside(2, "Ready check", "buffNotifyReady", "Names the tracked buffs you're missing."), "buffHud")
  dependsOn(check(2, "Sound", "buffSound"), "buffHud")
  defaultsButton(function() BT.Toggle(s().buffHud) end)
end

------------------------------------------------------------------------
-- Data & Integrations: other add-ons, where the data comes from, upkeep
------------------------------------------------------------------------
newPage("data", "Data & Integrations", "Interface\\Icons\\INV_Misc_Book_09")
-- an add-on's state, as far as the game tells: loaded, installed but not loaded, or not installed
-- (none of them is required: a missing one is just "not installed", not an error)
local function addonState(name, isLoaded)
  local isOn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if isLoaded or (isOn and isOn(name)) then return "loaded" end
  local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  if info then
    local ok, nm, _, _, _, reason = pcall(info, name)
    if ok and nm and reason ~= "MISSING" then return "installed" end
  end
  return "missing"
end
local STATE_TEXT = { loaded = "|cff94ba78loaded|r", installed = "|cffd6b266installed, not loaded|r", missing = "|cff6f6f74not installed|r" }
heading(1, "Add-ons")
infoLine(1, "Auctionator", function() return STATE_TEXT[addonState("Auctionator", NW.HasAuctionator and NW.HasAuctionator())] end,
  "Optional. Prices for leveling costs, shopping lists and catch values. Without it: vendor prices and estimates.")
infoLine(1, "GatherMate2", function() return STATE_TEXT[addonState("GatherMate2", _G.GatherMate2 ~= nil)] end,
  "Optional, only for an import. Turn it on in the AddOns list for one login, import, then you can turn it off.")
infoLine(1, "LibDBIcon", function()
  local ls = LibStub and LibStub("LibDBIcon-1.0", true)
  return ls and "|cff94ba78in use|r" or "|cff6f6f74not in use|r"
end, "A library other add-ons may load. When one does, Nodewalker's minimap button goes through it; otherwise it draws its own.")
local gmBtn = UI.Button(page, "Import GatherMate2", 170, function()
  if not _G.GatherMate2 then return end
  NW.ImportGatherMate2()
  if NW.RefreshPlanner then NW.RefreshPlanner() end
  refreshAll()
end, 24)
if gmBtn.SetMotionScriptsWhileDisabled then gmBtn:SetMotionScriptsWhileDisabled(true) end
place(1, gmBtn, 30, 2)
function gmBtn:Refresh() self:SetEnabled(_G.GatherMate2 ~= nil) end
UI.Tip(gmBtn, "Import GatherMate2", function()
  if _G.GatherMate2 then return "Copies its herb and ore spots, and its data pack. Your own spots stay." end
  return addonState("GatherMate2") == "installed"
    and "GatherMate2 is installed but not loaded. Turn it on in the AddOns list, log in, then import."
    or "Needs GatherMate2 loaded. It isn't installed."
end)
-- where each kind of data comes from; the full source and licence on hover (LICENSES/ in the add-on folder)
heading(1, "Where the data comes from")
infoLine(1, "Items, recipes, spells", "WoW Forever client",
  "Recipe data from One For All (Forever) by Smoergi (GPL-3.0-or-later), built from the WoW Forever client database, QuestieDB, cMaNGOS classic-db and ProfessionDB. Nodewalker's corrections are its own. LICENSES/OneForAll.txt.")
infoLine(1, "Drops, spawns, skinning", "Classic data (pfQuest, cMaNGOS)",
  "Spawns and loot chances from pfQuest (MIT, Shagu); skinning loot, and some fishing zones and seasons, from cMaNGOS classic-db (GPL-3.0). Classic 1.12 data: creatures and chances may differ in WoW Forever. LICENSES/.")
infoLine(1, "Minimap tiles", "OpenMap", "Minimap tile tables from OpenMap (MIT, OpenMap contributors). LICENSES/OpenMap-LICENSE.txt.")
infoLine(1, "Fishing skill ranges", "leveling guides",
  "Classic leveling guides and Method's WoW Forever guide: a guide's skill, not a confirmed minimum. Seasonal fish and some zones from cMaNGOS classic-db.")
infoLine(1, "Prices", "Auctionator, else vendor")
infoLine(1, "Your spots and catches", "recorded by you", "Stay on this PC, in your SavedVariables. Never shipped or uploaded.")

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
    local id = (rawget(sessBtn, "armID") or 0) + 1
    sessBtn.armID = id
    C_Timer.After(4, function() if sessBtn.armID == id then sessBtn.armed = nil; sessBtn:SetText("Reset session") end end)
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
    -- (a child row: a smaller icon, indented under its parent)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(c.child and 16 or 20, c.child and 16 or 20)
    b.icon:SetPoint("LEFT", c.child and 25 or 7, 0)
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
  for _, b in ipairs(navRows) do
    b:SetSelected(b.key == key)
    -- Gathering stays lit (gold name) while you're on its Herbs & ore
    if b.key == "gather" then b.name:SetTextColor(unpack(key == "nodes" and S.gold or S.text)) end
  end
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
