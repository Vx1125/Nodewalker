local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

local function s() return NW.db.settings end
local function changed()
  if NW.RefreshOverlayArt then NW.RefreshOverlayArt() end
  NW.UpdateVisibility()
  if NW.UpdateMinimapButton then NW.UpdateMinimapButton() end
end

------------------------------------------------------------------------
-- Settings: General, Appearance, Gathering, Routes (and Herbs & Ore below).
-- Each page has two columns; the helpers place onto the page being built.
------------------------------------------------------------------------
local widgets = {}
local function refreshAll() for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end end

local COL_W = 440
local COL_X = { 24, 24 + COL_W + 60 }
local page, cols
local function newPage(key, label)
  page = UI.AddTab(key, label, refreshAll, nil, nil, "Settings")
  cols = { { y = -10 }, { y = -10 } }
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
-- Appearance presets remember your changes: a setting a preset sets, changed while
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
local function check(col, label, key, tip, after)
  return place(col, UI.Check(page, label, function() return s()[key] end,
    function(v) s()[key] = v; noteTweak(key, v); changed(); refreshAll(); if after then after(v) end end, tip), 24, 2)
end
local function slider(col, label, minV, maxV, step, fmt, key, after, tip)
  return place(col, UI.Slider(page, COL_W, label, minV, maxV, step, fmt,
    function() return s()[key] end, function(v) s()[key] = v; noteTweak(key, v); if after then after(v) end end, tip), 44)
end
-- A second check on the row just placed
local function checkBeside(col, label, key, tip)
  cols[col].y = cols[col].y + 24
  return place(col, UI.Check(page, label, function() return s()[key] end,
    function(v) s()[key] = v; noteTweak(key, v); changed(); refreshAll() end, tip), 24, 222)
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
end
local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

------------------------------------------------------------------------
-- General: when the overlay shows
------------------------------------------------------------------------
newPage("overlay", "General")
heading(1, "Overlay")
check(1, "Show overlay", "overlayShown", "Same as /nw or your key binding.")
check(1, "Zoom out when mounted", "mountZoom")
heading(1, "Overlay visibility")
check(1, "Hide in combat", "hideCombat")
check(1, "Hide in cities and inns", "hideResting")
check(1, "Hide in dungeons and raids", "hideInstances")
check(1, "Only while tracking herbs or ore", "onlyTracking", "Find Herbs or Find Minerals is on.")

heading(2, "Fading")
check(2, "Fade while moving", "fadeMoving")
dependsOn(check(2, "Full opacity near nodes", "brightNear", "Stops fading when a known spot is within 100 yards."), "fadeMoving")
dependsOn(slider(2, "Fade to", 0.2, 1, 0.05, pct, "fadeMovingAlpha"), "fadeMoving")
heading(2, "Interface elements")
check(2, "Zone arrival banner", "zoneBanner", "The zone, its known spots and its route as you enter.")
check(2, "Minimap button", "minimapButton", "Nodewalker is also in the game's AddOns menu.")
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
place(2, barBtn, 30, 2)
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

-- Controls and commands: on hover, not on the page
local helpBtn = UI.Button(page, "Controls & commands", 170, nil, 22)
helpBtn:SetPoint("BOTTOMLEFT", 24, 12)
helpBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
  GameTooltip:SetText("Controls", 1, 1, 1)
  local d = S.dim
  GameTooltip:AddDoubleLine("Alt + hover a live dot", "what it is", 0.84, 0.7, 0.4, d[1], d[2], d[3])
  GameTooltip:AddDoubleLine("Ctrl + hover a stop", "details", 0.84, 0.7, 0.4, d[1], d[2], d[3])
  GameTooltip:AddDoubleLine("Ctrl + right-click a node", "hide that herb or ore", 0.84, 0.7, 0.4, d[1], d[2], d[3])
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Commands", 1, 1, 1)
  for _, c in ipairs({ { "/nw", "overlay" }, { "/nw window", "this window" }, { "/nw plan", "routes" }, { "/nw guide", "Material Finder" },
    { "/nw prof", "professions" }, { "/nw consumes", "consumes" }, { "/nw options", "settings" }, { "/nw import", "GatherMate2 nodes" } }) do
    GameTooltip:AddDoubleLine(c[1], c[2], 0.84, 0.7, 0.4, d[1], d[2], d[3])
  end
  GameTooltip:Show()
end)
helpBtn:SetScript("OnLeave", GameTooltip_Hide)

------------------------------------------------------------------------
-- Appearance: how the overlay looks
------------------------------------------------------------------------
newPage("look", "Appearance")
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
  end
end }
widgets[#widgets + 1] = presetMark
local function applyPreset(name)
  s().lookPreset = name
  for k, v in pairs(presetValues(name)) do s()[k] = v end
  if NW.SizeOverlay then NW.SizeOverlay() end
  changed()
  refreshAll()
end
heading(1, "Overlay", COL_W - 250)
do
  local x = COL_X[1] + COL_W - 240
  for i, pr in ipairs(PRESETS) do
    local b = UI.Button(page, pr[1], 76, function() applyPreset(pr[1]) end, 20)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x + (i - 1) * 82, -8)
    b.name = pr[1]
    b:HookScript("OnLeave", function() presetMark.Refresh() end)
    UI.Tip(b, pr[1], pr[2] .. " Keeps your changes to it. Gold: your settings match it.")
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
whileTerrain(place(1, UI.Dropdown(page, COL_W, "Map style", {
  { "minimap", "Detailed (minimap tiles)" }, { "zonemap", "World map art" },
}, function() return s().terrainSource end, function(v) s().terrainSource = v; changed() end, 190), 30))
place(1, UI.Dropdown(page, COL_W, "Terrain colour", {
  { "natural", "Natural" }, { "muted", "Muted" }, { "silhouette", "Silhouette (dark)" },
  { "gold", "Gold tint" }, { "blue", "Blue tint" }, { "none", "Off (icons and route only)" },
}, function() return s().tint end, function(v) s().tint = v; noteTweak("tint", v); changed(); refreshAll() end, 190), 30)
-- says why the two above do nothing while it's off
local terrainNote = UI.Text(page, 11, S.dim)
terrainNote:SetText("Terrain colour is Off (Minimal): no map is drawn, so opacity and map style don't apply.")
terrainNote:SetWidth(COL_W)
place(1, terrainNote, 18, 2)
local tnRefresh = { Refresh = function() terrainNote:SetShown(not terrainOn()) end }
widgets[#widgets + 1] = tnRefresh

heading(2, "On screen")
check(2, "Compass bar", "showCompass")
check(2, "Session panel", "showSession", "Loops, nodes and gold per hour while you farm.")
heading(2, "This window")
slider(2, "Window size", 0.6, 1.5, 0.05, pct, "winScale", function() NW.SetWindowScale(s().winScale or 1) end)
-- (or drag the grip in the window's bottom-right corner)

------------------------------------------------------------------------
-- Gathering: live nodes and which ones show
------------------------------------------------------------------------
newPage("gather", "Gathering")
heading(1, "Live nodes")
check(1, "Show live nodes", "liveDots", "Moves your minimap into the overlay, like FarmHud, so its herb and ore dots show. Off keeps your minimap where it is.")
dependsOn(check(1, "Show detection radius", "showRangeRing", "Your minimap's range: live nodes can only appear inside this ring."), "liveDots")
dependsOn(check(1, "Show distant known spots", "showKnownSpots", "Known spots outside the ring stay on the map."), "liveDots")
dependsOn(check(1, "Always show node tooltips", "liveHoverNoAlt",
  "No need to hold Alt. Herbs and veins inside the ring then can't be clicked in the world."), "liveDots")
dependsOn(check(1, "Icon tooltips", "hoverTooltips", "Hover an icon on the overlay for its name."), "liveDots", false)
dependsOn(slider(1, "Quest area ring", 0, 1, 0.05, pct, "questRingAlpha",
  function() if NW.ApplyQuestRing then NW.ApplyQuestRing() end end,
  "The checkered ring your minimap draws round quest areas, seen through the overlay."), "liveDots")
place(1, UI.Check(page, "Show gathered spots", function() return not s().hidePicked end,
  function(v) s().hidePicked = not v or nil; noteTweak("hidePicked", not v); changed(); refreshAll() end,
  "A small grey dot where you gathered, until the gathered node cooldown ends."), 24, 2)

heading(2, "Resource filters")
check(2, "Only my professions", "onlyMyProfessions", "Herbs if you have Herbalism, ore if you have Mining.")
check(2, "Group nearby spots", "groupSpots", "Spots that would overlap share one icon with a count.")
local chooseBtn = UI.Button(page, "Choose herbs and ore...", 200, function() NW.ShowTab("nodes") end, 24)
place(2, chooseBtn, 28, 2)
heading(2, "Material Finder")
place(2, UI.Check(page, "Record what I collect", function() return s().gatherTrack ~= false end,
  function(v) if v then s().gatherTrack = nil else s().gatherTrack = false end; changed(); refreshAll() end,
  "Skinning, creature loot, herbs and ore, for your history and maps in Material Finder. Fishing has its own journal."), 24, 2)
place(2, UI.Check(page, "Hunting route on the overlay", function() return s().huntOverlay ~= false end,
  function(v) if v then s().huntOverlay = nil else s().huntOverlay = false end; changed(); refreshAll(); if NW.DrawOverlay then NW.DrawOverlay() end end,
  "Rings for the hunting grounds and the route between them."), 24, 2)

------------------------------------------------------------------------
-- Routes
------------------------------------------------------------------------
newPage("routes", "Routes")
heading(1, "Routes")
slider(1, "Gathered node cooldown", 1, 20, 1, function(v) return ("%d min"):format(v) end, "respawnMinutes",
  nil, "How long a route skips a stop after you gather it.")
check(1, "Auto-build routes", "autoRoute", "In a zone with known spots and no route, Nodewalker builds one.")
heading(2, "Planning")
local planBtn = UI.Button(page, "Open Routes", 200, function() NW.ShowRoutes() end, 24)
place(2, planBtn, 30, 2)
UI.Tip(planBtn, "Routes", "Sight range, avoid zones and the map: Material Finder › Routes.")
heading(2, "GatherMate2")
local gmBtn = UI.Button(page, "Import GatherMate2", 200, function()
  NW.ImportGatherMate2()
  if NW.RefreshPlanner then NW.RefreshPlanner() end
end, 24)
place(2, gmBtn, 30, 2)
UI.Tip(gmBtn, "Import GatherMate2", "Copies its herb and ore spots, and its data pack.")

------------------------------------------------------------------------
-- Fishing: Smart Fishing, gear, lures, the HUD, the Journal
------------------------------------------------------------------------
if NW.SmartFish then
  local SF = NW.SmartFish
  local function hud() SF.Update() end
  newPage("fishing", "Fishing")
  heading(1, "Smart Fishing")
  local keyBtn = SF.KeyButton(page, 260)
  place(1, keyBtn, 32, 2)
  check(1, "Reel in with the same key", "fishInteract",
    "While the bobber is out, the key works as the game's Interact Key on it. Turns on interact targeting while you fish.", function() SF.ApplyKey() end)
  local lureItems = {}
  for _, l in ipairs(SF.LURES) do lureItems[#lureItems + 1] = { l[1], ("%s  +%d"):format(SF.LURE_NAME[l[1]], l[2]) } end
  place(1, UI.Dropdown(page, COL_W - 20, "Lure", { { "off", "No lure" }, { "pref", "My preferred lure" }, { "best", "Strongest I carry" } },
    function() return s().fishLure or "off" end, function(v) s().fishLure = v; hud(); refreshAll() end, 200,
    "When there's no lure on your pole, Smart Fishing puts one on first."), 30, 2)
  local pref = place(1, UI.Dropdown(page, COL_W - 20, "Preferred lure", lureItems,
    function() return s().fishLurePref or SF.DEFAULT_LURE end, function(v) s().fishLurePref = v; hud() end, 200), 30, 2)
  local oldPref = pref.Refresh
  function pref:Refresh() if oldPref then oldPref(self) end self:SetAlpha(s().fishLure == "pref" and 1 or 0.45) end
  local alt = check(1, "Use another lure if I'm out", "fishLureAlt", nil, hud)
  local oldAlt = alt.Refresh
  function alt:Refresh() if oldAlt then oldAlt(self) end local on = s().fishLure == "pref"; self:SetAlpha(on and 1 or 0.45) end
  heading(1, "Fishing gear")
  local gearText = UI.Text(page, 11, S.dim)
  gearText:SetWidth(COL_W - 20)
  gearText:SetWordWrap(true)
  place(1, gearText, 30, 2)
  function gearText:Refresh()
    local g, saved = SF.gearSet()
    if not g then self:SetText("No fishing pole in your bags.") return end
    local names = {}
    for _, slot in ipairs({ 16, 1, 10, 8 }) do if g[slot] then names[#names + 1] = NW.ItemName(g[slot]) or ("item " .. g[slot]) end end
    self:SetText((saved and "Saved set: " or "Your best pole: ") .. table.concat(names, ", ") .. ((SF.GearBonus(g) > 0) and ("  ·  pole +" .. SF.GearBonus(g)) or ""))
  end
  local slotNames = { { 1, "Head" }, { 10, "Hands" }, { 8, "Feet" } }
  for i, sn in ipairs(slotNames) do
    local cb = UI.Check(page, sn[2], function() return (s().fishGearSlots or {})[sn[1]] end,
      function(v) s().fishGearSlots = s().fishGearSlots or {}; s().fishGearSlots[sn[1]] = v or nil end,
      "Saved with your pole when you click Use what I'm wearing.")
    if i == 1 then place(1, cb, 24, 2) else cols[1].y = cols[1].y + 24; place(1, cb, 24, 2 + (i - 1) * 110) end
  end
  local saveBtn = UI.Button(page, "Use what I'm wearing", 180, function()
    if not SF.SaveWorn() and UIErrorsFrame then UIErrorsFrame:AddMessage("Put your fishing pole on first", S.gold[1], S.gold[2], S.gold[3]) end
    refreshAll()
  end, 24)
  place(1, saveBtn, 30, 2)
  local clearBtn = UI.Button(page, "Clear", 70, function() SF.ClearGear(); refreshAll() end, 24)
  clearBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
  local eq = SF.Button(page, "equip", 126, 24, "Equip fishing gear") -- (ordinary buttons: out of combat)
  place(1, eq, 30, 2)
  local rs = SF.Button(page, "restore", 126, 24, "Restore my gear")
  rs:SetPoint("LEFT", eq, "RIGHT", 6, 0)
  heading(1, "Notices")
  check(1, "New fish", "fishNotifyNew")
  checkBeside(1, "Rare catches", "fishNotifyRare", "Rare quality or better, by the game's own item quality.")
  check(1, "Lures", "fishNotifyLure", "Expiring, expired, running low, preferred one missing.")
  checkBeside(1, "Collection complete", "fishNotifyTarget", "The fish your Fishing + Cooking plan wants.")
  check(1, "Sound", "fishSound")
  checkBeside(1, "Quiet while fishing", "fishQuiet",
    "Music and ambience off, sound effects to full so the splash stands out. Your volumes come back when the pole comes off or 90 seconds after your last cast.",
    function(v) if not v then SF.Unquiet() end end)

  heading(2, "Fishing HUD")
  check(2, "Show the HUD", "fishHud", "While a fishing pole is on, or for 5 minutes after you last fished.", hud)
  checkBeside(2, "Minimal", "fishHudMini", nil)
  check(2, "Lock position", "fishHudLock")
  checkBeside(2, "Cooking target", "fishHudTarget", "The fish your Fishing + Cooking plan wants next.")
  check(2, "Catch value", "fishHudValue", "Estimated at Auctionator prices.")
  slider(2, "Scale", 0.6, 1.5, 0.05, pct, "fishHudScale", hud)
  slider(2, "Opacity", 0.3, 1, 0.05, pct, "fishHudAlpha", hud)
  heading(2, "Journal")
  check(2, "Record catches", "fishTrack", "Only loot the game marks as fishing loot.")
  checkBeside(2, "Catch spots", "fishTrackSpots", "Where you stood, to 2% of the map.")
  check(2, "Sessions", "fishSessions", nil, function(v) if not v and NW.FishJournal then NW.FishJournal.SessionsOff() end end)
  checkBeside(2, "Start one when I cast", "fishAutoSession", "A session ends 20 minutes after you last fished.")
  local jb = UI.Button(page, "Open the Journal", 180, function() NW.OpenFishJournal() end, 24)
  place(2, jb, 30, 2)
end

------------------------------------------------------------------------
-- Nodes tab: tick the herbs and ore you want to see
------------------------------------------------------------------------
local nodeChecks = {}
local refreshNodes
local nodesPage = UI.AddTab("nodes", "Herbs & Ore", function() refreshNodes() end, nil, nil, "Settings")

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
nodesHelp:SetText("Number: skill needed.  Colour: skill-ups at your level.")
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
