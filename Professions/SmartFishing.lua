local _, NW = ...

------------------------------------------------------------------------
-- Smart Fishing: one key, the next thing to do each press.
--   1. no pole on: equip your fishing gear     (secure macro, /equipslot)
--   2. lures on, none on the pole: apply one  (secure macro, /use item, /use 16)
--   3. otherwise: cast Fishing                 (secure spell button)
--   4. bobber out: the same key is the game's Interact (INTERACTTARGET), so
--      pressing it when the bobber splashes reels in through soft targeting.
-- Every action is a key press. Nothing casts, reels or equips by itself, and
-- nothing secure changes in combat. The game doesn't tell addons when a fish
-- bites, so "reel in" is never guessed.
-- Same approach as EzFishing Forever and Fishing-OneKey (both MIT); this
-- code is Nodewalker's own.
--
-- Combat: a frame with a secure child, or one a secure frame is anchored to,
-- is protected in combat. So the only visible secure button (the HUD's Lure
-- button) is parented to UIParent and placed by coordinates, never anchored
-- to the HUD; the HUD and the settings page stay ordinary frames. Equip and
-- Restore buttons use EquipItemByName, which works out of combat.
------------------------------------------------------------------------
local UI, S = NW.UI, NW.STYLE
local H = S.HEX
local F, J = NW.FISHING, NW.FishJournal
local SF = {}
NW.SmartFish = SF
local BLUE = F and F.BLUE or { 0.478, 0.627, 0.757, 1 }

local function st() return NW.db.settings end
local function cdb() return NW.charDB end
local function combat() return InCombatLockdown and InCombatLockdown() end

-- Poles and their bonus (Method's WoW Forever guide); any other pole counts as +0
SF.POLES = { [19970] = 35, [19022] = 25, [6367] = 20, [6366] = 15, [6365] = 5, [12225] = 3, [6256] = 0 }
SF.LURES = { { 6529, 25 }, { 6530, 50 }, { 6811, 50 }, { 6532, 75 }, { 7307, 75 }, { 6533, 100 } }
SF.LURE_BONUS = {}
for _, l in ipairs(SF.LURES) do SF.LURE_BONUS[l[1]] = l[2] end
SF.LURE_NAME = { [6529] = "Shiny Bauble", [6530] = "Nightcrawlers", [6811] = "Aquadynamic Fish Lens", [6532] = "Bright Baubles",
  [7307] = "Flesh Eating Worm", [6533] = "Aquadynamic Fish Attractor" }
SF.LURE_SECS = { [6533] = 300 } -- the rest last 10 minutes
SF.DEFAULT_LURE = 6532
local GEAR_SLOTS = { 16, 17, 1, 10, 8 }
local HUD_IDLE = 300 -- with no pole on, the HUD goes after 5 minutes without fishing

local function itemName(id) return NW.ItemName(id) or SF.LURE_NAME[id] or ("item " .. id) end

local poleMemo = {}
function SF.isPole(id)
  if not id then return false end
  if SF.POLES[id] then return true end
  if poleMemo[id] ~= nil then return poleMemo[id] end
  if not (C_Item and C_Item.GetItemInfoInstant) then return false end
  local ok, _, _, _, _, _, c, s = pcall(C_Item.GetItemInfoInstant, id)
  if not ok or c == nil then return false end -- not cached yet: ask again later
  poleMemo[id] = (c == 2 and s == 20)
  return poleMemo[id]
end
function SF.worn(slot) return GetInventoryItemID and GetInventoryItemID("player", slot) end
function SF.poleOn() return SF.isPole(SF.worn(16)) end

-- what's in your bags (not the bank: that can't be equipped); rescanned only after a bag change
local bags, bagsDirty = {}, true
function SF.bags()
  if not bagsDirty then return bags end
  bags = {}
  local C = C_Container
  for b = 0, 4 do
    local n = (C and C.GetContainerNumSlots and C.GetContainerNumSlots(b)) or (GetContainerNumSlots and GetContainerNumSlots(b)) or 0
    for slot = 1, n do
      local id = (C and C.GetContainerItemID and C.GetContainerItemID(b, slot)) or (GetContainerItemID and GetContainerItemID(b, slot))
      if id then bags[id] = (bags[id] or 0) + 1 end
    end
  end
  bagsDirty = false
  return bags
end
function SF.lureCount(id)
  return id and (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, false)) or 0
end

function SF.bestPole()
  local best, bb
  for id in pairs(SF.bags()) do
    if SF.isPole(id) then
      local b = SF.POLES[id] or 0
      if not bb or b > bb then best, bb = id, b end
    end
  end
  return best
end
-- your fishing gear: the set you saved, or the best pole you carry
function SF.gearSet()
  local g = cdb() and cdb().fishGear
  if type(g) == "table" and next(g) then return g, true end
  local p = SF.bestPole()
  if p then return { [16] = p }, false end
  return nil, false
end
function SF.wearing(g)
  for slot, id in pairs(g or {}) do if SF.worn(slot) ~= id then return false end end
  return g ~= nil
end
-- the slots that still need changing: { { slot, id } }, from your bags
function SF.toEquip(g)
  local out, b = {}, SF.bags()
  for _, slot in ipairs(GEAR_SLOTS) do
    local id = g and g[slot]
    if id and SF.worn(slot) ~= id and b[id] then out[#out + 1] = { slot, id } end
  end
  return out
end
function SF.equipMacro(g)
  local lines = {}
  for _, e in ipairs(SF.toEquip(g)) do lines[#lines + 1] = ("/equipslot %d item:%d"):format(e[1], e[2]) end
  return table.concat(lines, "\n")
end
-- what you wore before fishing gear: { { slot, id } } to put back, and what isn't in your bags
function SF.toRestore()
  local prev = cdb() and cdb().fishPrev
  if type(prev) ~= "table" then return {}, {} end
  local out, missing, b = {}, {}, SF.bags()
  for _, slot in ipairs(GEAR_SLOTS) do
    local id = prev[slot]
    if id and SF.worn(slot) ~= id then
      if b[id] then out[#out + 1] = { slot, id } else missing[#missing + 1] = id end
    end
  end
  return out, missing
end
function SF.restoreMacro()
  local list, missing = SF.toRestore()
  local lines = {}
  for _, e in ipairs(list) do lines[#lines + 1] = ("/equipslot %d item:%d"):format(e[1], e[2]) end
  return table.concat(lines, "\n"), missing
end
-- Before putting on fishing gear, remember what's about to come off. With no
-- pole on, the weapons and every set slot; with a pole already on (put on by
-- hand), only set slots not yet remembered, so a snapshot of your normal gear
-- is never replaced by fishing gear.
function SF.snapshot()
  local c = cdb()
  if not c then return end
  local g = SF.gearSet()
  if not SF.poleOn() then
    local prev = {}
    for _, slot in ipairs(GEAR_SLOTS) do
      if slot == 16 or slot == 17 or (g and g[slot]) then prev[slot] = SF.worn(slot) end
    end
    c.fishPrev = prev
    return
  end
  c.fishPrev = c.fishPrev or {}
  for slot, id in pairs(g or {}) do
    if slot ~= 16 and slot ~= 17 and SF.worn(slot) ~= id and c.fishPrev[slot] == nil then c.fishPrev[slot] = SF.worn(slot) end
  end
end
-- equip or restore without a secure button (out of combat only)
local function equipList(list)
  local fn = (C_Item and C_Item.EquipItemByName) or EquipItemByName
  if not fn or combat() then return false end
  for _, e in ipairs(list) do pcall(fn, e[2], e[1]) end
  return #list > 0
end
function SF.EquipNow()
  if combat() then return false end
  local g = SF.gearSet()
  local list = SF.toEquip(g)
  if #list == 0 then return false end
  SF.snapshot()
  return equipList(list)
end
function SF.RestoreNow()
  if combat() then return false end
  local list, missing = SF.toRestore()
  local ok = equipList(list)
  if #missing > 0 and UIErrorsFrame then
    local names = {}
    for _, id in ipairs(missing) do names[#names + 1] = itemName(id) end
    UIErrorsFrame:AddMessage("Not in your bags: " .. table.concat(names, ", "), S.gold[1], S.gold[2], S.gold[3])
  end
  return ok
end
-- save what you're wearing now as your fishing gear
function SF.SaveWorn()
  local c = cdb()
  if not c then return false end
  if not SF.poleOn() then return false end
  local g = { [16] = SF.worn(16) }
  local want = st().fishGearSlots or {}
  for _, slot in ipairs({ 1, 10, 8 }) do
    if want[slot] and SF.worn(slot) then g[slot] = SF.worn(slot) end
  end
  c.fishGear = g
  SF.Queue()
  return true
end
function SF.ClearGear()
  if cdb() then cdb().fishGear = nil end
  SF.Queue()
end
function SF.GearBonus(g)
  local n = 0
  for slot, id in pairs(g or {}) do if slot == 16 then n = n + (SF.POLES[id] or 0) end end
  return n
end

------------------------------------------------------------------------
-- Lures
------------------------------------------------------------------------
-- seconds left on the lure on your pole, or nil
function SF.lureLeft()
  if not SF.poleOn() or not GetWeaponEnchantInfo then return nil end
  local has, ms = GetWeaponEnchantInfo()
  if has and type(ms) == "number" then return ms / 1000 end
  return nil
end
-- the lure Nodewalker put on, if it's still the one on the pole (recorded
-- only once an enchant actually appeared after the click)
function SF.lureName()
  local u = cdb() and cdb().fishLureUsed
  local left = SF.lureLeft()
  if not (u and left) then return nil end
  local dur = SF.LURE_SECS[u.id] or 600
  if time() - (u.t or 0) <= dur + 5 then return itemName(u.id), u.id end
  return nil
end
NW.FishLureName = function() return (SF.lureName()) end
function SF.prefLure() return st().fishLurePref or SF.DEFAULT_LURE end
-- which lure to put on: the one you prefer, or the strongest you carry
function SF.lureChoice()
  local mode = st().fishLure or "off"
  if mode == "off" then return nil end
  local b = SF.bags()
  if mode == "pref" then
    local pref = SF.prefLure()
    if b[pref] then return pref end
    if not st().fishLureAlt then return nil, "missing" end
  end
  local best, bb
  for _, l in ipairs(SF.LURES) do
    if b[l[1]] and (not bb or l[2] > bb) then best, bb = l[1], l[2] end
  end
  if best then return best end
  return nil, mode == "pref" and "missing" or "none"
end
function SF.strongestLure()
  local best, bb
  for _, x in ipairs(SF.LURES) do if SF.bags()[x[1]] and (not bb or x[2] > bb) then best, bb = x[1], x[2] end end
  return best
end
-- a click that should put a lure on: confirmed when an enchant shows up
local function lureClicked(id)
  if id then SF.pendingLure = { id = id, at = GetTime(), had = SF.lureLeft() } end
end

------------------------------------------------------------------------
-- The Fishing spell, by what you know
------------------------------------------------------------------------
local SPELLS = { 131474, 7620, 7731, 7732, 18248, 33095 }
function SF.spellName()
  for _, id in ipairs(SPELLS) do
    if IsPlayerSpell and IsPlayerSpell(id) then
      local n = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id))
      if n then return n end
    end
  end
  local p = NW.PROF_BY_KEY.fishing
  return p and p.name or "Fishing"
end
NW.FishSpellName = SF.spellName

------------------------------------------------------------------------
-- What the next press does
------------------------------------------------------------------------
SF.channeling = false
function SF.interactOK()
  return st().fishInteract ~= false and C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("SoftTargetInteract") ~= nil
end
-- returns action, label, item
function SF.Next()
  if not NW.ProfSkill("fishing") then return "none", "Fishing not learned" end
  if SF.channeling then
    return "reel", SF.interactOK() and SF.key() and "Bobber out: press when it splashes" or "Bobber out: click it when it splashes"
  end
  if combat() then return "combat", "In combat" end
  if not SF.poleOn() then
    local g = SF.gearSet()
    if g and #SF.toEquip(g) > 0 then
      local more = false
      for slot in pairs(g) do if slot ~= 16 then more = true end end
      return "equip", more and "Equip fishing gear" or "Equip fishing pole"
    end
    return "cast", "No fishing pole"
  end
  if (st().fishLure or "off") ~= "off" and not SF.lureLeft() then
    local l, why = SF.lureChoice()
    if l then return "lure", "Apply " .. itemName(l), l end
    if why == "missing" and not SF.warnedMissing then
      SF.warnedMissing = true
      if st().fishNotifyLure ~= false and NW.FishNotify then NW.FishNotify("Preferred lure: none in your bags", "lure") end
    end
  end
  return "cast", "Cast Fishing"
end

------------------------------------------------------------------------
-- Secure buttons: the hidden Smart Fishing button, and the HUD's Lure button
------------------------------------------------------------------------
local main = CreateFrame("Button", "NodewalkerSmartFish", UIParent, "SecureActionButtonTemplate")
main:SetSize(1, 1)
main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
main:RegisterForClicks("AnyUp", "AnyDown")
SF.main = main
main:SetScript("PreClick", function(self)
  if self.action == "equip" then SF.snapshot()
  elseif self.action == "lure" then lureClicked(self.lureID) end
end)
main:SetScript("PostClick", function() SF.Queue(0.4) end)

local function setMacro(b, text)
  if text and text ~= "" then
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", text)
    b:SetAttribute("spell", nil)
    return true
  end
  b:SetAttribute("type", nil)
  return false
end

-- a flat button; secure ones are parented to UIParent (see the top of the file)
local function flat(parent, w, h, secure, name)
  local b = CreateFrame("Button", name, parent, secure and "SecureActionButtonTemplate, BackdropTemplate" or "BackdropTemplate")
  b:SetSize(w, h or 22)
  if secure then b:RegisterForClicks("AnyUp", "AnyDown") end
  UI.Flat(b, S.cell, S.edge)
  b.label = UI.Text(b, 11, S.text, "CENTER")
  b.label:SetPoint("LEFT", 4, 0)
  b.label:SetPoint("RIGHT", -4, 0)
  b.label:SetWordWrap(false)
  b:HookScript("OnEnter", function(self)
    self:SetBackdropBorderColor(unpack(S.gold))
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.label:GetText() or "", 1, 1, 1)
    if self.tip then GameTooltip:AddLine(self.tip, S.dim[1], S.dim[2], S.dim[3], true) end
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(S.edge)); GameTooltip_Hide() end)
  return b
end
SF.buttons = {}
-- Equip and Restore (ordinary buttons; out of combat) for the HUD and the settings page
function SF.Button(parent, kind, w, h, text)
  local b = flat(parent, w, h, false)
  b.kind = kind
  b.label:SetText(text or ({ equip = "Equip gear", restore = "Restore gear" })[kind])
  b:SetScript("OnClick", function(self)
    if combat() then return end
    if self.kind == "equip" then SF.EquipNow() else SF.RestoreNow() end
    SF.Queue(0.4)
  end)
  SF.buttons[#SF.buttons + 1] = b
  return b
end
-- the HUD's Lure button: secure, on UIParent
local lureBtn = flat(UIParent, 64, 20, true, "NodewalkerFishLure")
lureBtn.label:SetText("Lure")
lureBtn:Hide()
lureBtn:SetScript("PreClick", function(self) lureClicked(self.lureID) end)
lureBtn:SetScript("PostClick", function() SF.Queue(0.4) end)
SF.lureBtn = lureBtn

local function refreshButtons()
  for _, b in ipairs(SF.buttons) do
    local ok
    if b.kind == "equip" then
      local g = SF.gearSet()
      ok = g ~= nil and #SF.toEquip(g) > 0
      b.tip = not g and "No fishing pole in your bags." or (SF.wearing(g) and "You're wearing it." or nil)
    else
      local list, missing = SF.toRestore()
      ok = #list > 0
      local names = {}
      for _, id in ipairs(missing) do names[#names + 1] = itemName(id) end
      b.tip = #names > 0 and ("Not in your bags: " .. table.concat(names, ", ")) or (not ok and "Nothing to put back." or nil)
    end
    b:SetAlpha(ok and 1 or 0.45)
  end
end

SF.pending = false
function SF.Update()
  if combat() then SF.pending = true return end
  -- nothing to do for a character without Fishing and nothing on screen
  local learned = NW.ProfSkill("fishing") ~= nil
  local fishPage = NW.FISHING and NW.FISHING.frame and NW.FISHING.frame:IsVisible()
  local settingsPage = NW.CurrentTab and NW.CurrentTab() == "fishing"
  if not learned and not fishPage and not settingsPage then
    SF.action, SF.label = "none", "Fishing not learned"
    if SF.RefreshHUD then SF.RefreshHUD() end
    return
  end
  -- a restore that's done: forget it
  local prev = cdb() and cdb().fishPrev
  if prev and not SF.poleOn() then
    local all = true
    for slot, id in pairs(prev) do if SF.worn(slot) ~= id then all = false end end
    if all then cdb().fishPrev = nil end
  end
  local action, label, item = SF.Next()
  SF.action, SF.label = action, label
  main.action, main.lureID = action, nil
  if action == "equip" then
    setMacro(main, SF.equipMacro((SF.gearSet())))
  elseif action == "lure" then
    main.lureID = item
    setMacro(main, ("/use item:%d\n/use 16"):format(item))
  elseif action == "cast" or action == "none" then
    main:SetAttribute("type", "spell")
    main:SetAttribute("spell", SF.spellName())
  end
  -- the Lure button: your choice, or the strongest you carry when lures are off for Smart Fishing
  local l = SF.lureChoice()
  if not l and (st().fishLure or "off") == "off" then l = SF.strongestLure() end
  lureBtn.lureID = l
  setMacro(lureBtn, l and ("/use item:%d\n/use 16"):format(l))
  lureBtn.tip = l and ("%s, +%d"):format(itemName(l), SF.LURE_BONUS[l] or 0) or "No lures in your bags."
  lureBtn:SetAlpha(l and 1 or 0.45)
  refreshButtons()
  if SF.RefreshHUD then SF.RefreshHUD() end
end
-- one update shortly after a burst of events
local queued
function SF.Queue(delay)
  if queued then return end
  queued = true
  C_Timer.After(delay or 0.3, function() queued = nil; SF.Update() end)
end

------------------------------------------------------------------------
-- The key: a normal game binding (Key Bindings › AddOns › Smart Fishing, or
-- Settings › Fishing), like PallyPulse's Smart Buff. While the bobber is out,
-- that key is overridden to Interact; the override is cleared when the
-- channel ends. The interact CVar's previous value is saved, so a reload or
-- combat mid-cast can't leave it changed.
------------------------------------------------------------------------
SF.COMMAND = "CLICK NodewalkerSmartFish:LeftButton"
_G["BINDING_NAME_CLICK NodewalkerSmartFish:LeftButton"] = "Smart Fishing"
function SF.keys()
  if not GetBindingKey then return {} end
  return { GetBindingKey(SF.COMMAND) }
end
function SF.key() return SF.keys()[1] end
function SF.ApplyKey()
  if combat() then SF.pendingKey = true return end
  ClearOverrideBindings(main)
  if SF.channeling and SF.interactOK() then
    for _, k in ipairs(SF.keys()) do SetOverrideBinding(main, true, k, "INTERACTTARGET") end
  end
end
local function saveBindings() pcall(function() SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end) end
-- a key set in Settings before Smart Fishing was a game binding: move it over
local function migrateKey()
  local old = st().fishKey
  if not old or combat() then return end
  if not SF.key() and SetBinding then
    local bound = GetBindingAction and GetBindingAction(old) or ""
    if bound == "" or bound == SF.COMMAND then SetBinding(old, SF.COMMAND); saveBindings() end
  end
  st().fishKey = nil
end
local function restoreSoft()
  local saved = st().fishSoftSaved
  if saved == nil or SF.channeling or combat() then return end
  if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, "SoftTargetInteract", saved) end
  st().fishSoftSaved = nil
end
SF.restoreSoft = restoreSoft
local function isFishing(unit, spellID) return J and J.isFishing(spellID, unit) end
NW.On("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if not isFishing(unit, spellID) then return end
  SF.channeling = true
  if SF.interactOK() and SF.key() and not combat() then
    local cur = C_CVar.GetCVar("SoftTargetInteract")
    if cur ~= "3" then
      if st().fishSoftSaved == nil then st().fishSoftSaved = cur end
      pcall(C_CVar.SetCVar, "SoftTargetInteract", "3")
    end
  end
  SF.ApplyKey()
  SF.Update()
end)
local function channelEnded()
  SF.channeling = false
  SF.ApplyKey()
  restoreSoft()
  SF.Queue()
end
NW.On("UNIT_SPELLCAST_CHANNEL_STOP", function(unit, _, spellID)
  if isFishing(unit, spellID) then channelEnded() end
end)
NW.On("PLAYER_ENTERING_WORLD", function()
  if SF.channeling then channelEnded() end
  C_Timer.After(1, function() restoreSoft(); SF.ApplyKey(); SF.Queue() end)
end)
NW.On("PLAYER_REGEN_ENABLED", function()
  if SF.pendingKey then SF.pendingKey = nil; SF.ApplyKey() end
  restoreSoft()
  SF.pending = false
  SF.Update()
end)
NW.On("PLAYER_REGEN_DISABLED", function() if SF.RefreshHUD then SF.RefreshHUD() end end)
NW.On("PLAYER_EQUIPMENT_CHANGED", function() SF.Queue() end)
NW.On("BAG_UPDATE_DELAYED", function() bagsDirty = true; SF.Queue() end)
NW.On("SKILL_LINES_CHANGED", function() SF.Queue() end)
table.insert(NW.OnLoad, function()
  local s = st()
  if s.fishLure == nil then s.fishLure = "off" end
  C_Timer.After(1, function() migrateKey(); restoreSoft(); SF.ApplyKey(); SF.Update() end)
end)
NW.On("UPDATE_BINDINGS", function() if SF.RefreshHUD then SF.RefreshHUD() end end)

-- A button that sets the Smart Fishing key binding (the same one as in the
-- game's Key Bindings). A key already bound to something else asks for a
-- second press, then moves to Smart Fishing.
function SF.KeyButton(parent, w)
  local b = UI.Button(parent, "", w, nil, 24)
  local function label()
    local key = SF.key()
    b:SetText(b.waiting and (b.confirm and ("Press %s again to use it"):format(b.confirm) or "Press a key...")
      or (key and ("Smart Fishing: %s"):format(GetBindingText and GetBindingText(key, "KEY_") or key) or "Set Smart Fishing key"))
  end
  b.Refresh = label
  local function stop(self) self.waiting, self.confirm = nil, nil; self:EnableKeyboard(false); label() end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if combat() then return end -- the game blocks binding changes in combat
    if button == "RightButton" then
      for _, k in ipairs(SF.keys()) do SetBinding(k) end
      saveBindings()
      stop(self)
      return
    end
    if self.waiting then stop(self) return end
    self.waiting, self.confirm = true, nil
    self:EnableKeyboard(true)
    pcall(self.SetPropagateKeyboardInput, self, false)
    label()
  end)
  b:SetScript("OnKeyDown", function(self, key)
    if not self.waiting then return end
    if key == "ESCAPE" then stop(self) return end
    if key:find("SHIFT$") or key:find("CTRL$") or key:find("ALT$") then return end
    local full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    local bound = GetBindingAction and GetBindingAction(full) or ""
    if bound ~= "" and bound ~= SF.COMMAND and self.confirm ~= full then
      self.confirm = full
      self.boundTo = bound
      label()
      return
    end
    if combat() then stop(self) return end
    for _, k in ipairs(SF.keys()) do SetBinding(k) end
    SetBinding(full, SF.COMMAND)
    saveBindings()
    stop(self)
    SF.ApplyKey()
  end)
  b:SetScript("OnHide", function(self) self.waiting, self.confirm = nil, nil; self:EnableKeyboard(false) end)
  b:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Smart Fishing key", 1, 1, 1)
    if self.confirm and self.boundTo then
      GameTooltip:AddLine(("%s is bound to %s. Pressing it again moves it to Smart Fishing."):format(self.confirm, _G["BINDING_NAME_" .. self.boundTo] or self.boundTo), 1, 0.82, 0.2, true)
    end
    GameTooltip:AddLine("Also in Key Bindings › AddOns. Right-click to clear.", S.dim[1], S.dim[2], S.dim[3], true)
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnShow", label) -- (settings aren't loaded yet when this is built)
  return b
end

------------------------------------------------------------------------
-- Notices: the HUD's own line, or the game's error line if the HUD is hidden
------------------------------------------------------------------------
function NW.FishNotify(text, kind)
  if st().fishSound and PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175, "SFX") end
  if SF.hud and SF.hud:IsShown() then
    SF.notice, SF.noticeAt = text, GetTime()
    SF.RefreshHUD()
  elseif UIErrorsFrame then
    UIErrorsFrame:AddMessage(text, S.gold[1], S.gold[2], S.gold[3])
  end
end

------------------------------------------------------------------------
-- The Fishing + Cooking target: the fish the plan wants next. The plan is
-- rebuilt only after a bag, skill or recipe change, at most every 5 seconds.
------------------------------------------------------------------------
local targetDirty, targetAt = true, -100
function SF.Target()
  if SF.targetCache ~= nil and (not targetDirty or GetTime() - targetAt < 5) then return SF.targetCache or nil end
  targetDirty, targetAt = false, GetTime()
  SF.targetCache = false
  if not (F and F.Build) or st().fishHudTarget == false then return nil end
  local ok, plan = pcall(F.Build)
  if not ok or not plan then return nil end
  local catch, nextCook
  if plan.next and plan.next.kind == "catch" then catch = plan.next end
  if not catch and plan.current then
    for _, a in ipairs(plan.current.actions) do
      if a.kind == "catch" and not a.blocked and not a.done and not catch then catch = a end
    end
  end
  if plan.next and plan.next.kind == "cook" then nextCook = plan.next end
  SF.targetCache = { catch = catch, cook = nextCook }
  -- a collection that just filled up, by your bags
  local was = SF.lastCatch
  if was and (not catch or catch.fish ~= was) and nextCook and st().fishNotifyTarget ~= false and NW.FishNotify then
    NW.FishNotify("Collection complete. Next: " .. nextCook.label, "target")
  end
  SF.lastCatch = catch and catch.fish or nil
  return SF.targetCache
end
local function dirtyTarget() targetDirty = true end
NW.On("BAG_UPDATE_DELAYED", dirtyTarget)
NW.On("SKILL_LINES_CHANGED", dirtyTarget)
NW.On("NEW_RECIPE_LEARNED", dirtyTarget)

------------------------------------------------------------------------
-- HUD (an ordinary frame: no secure children, nothing anchored to it)
------------------------------------------------------------------------
local hud = CreateFrame("Frame", "NodewalkerFishHUD", UIParent, "BackdropTemplate")
SF.hud = hud
hud:SetSize(220, 100)
hud:SetFrameStrata("MEDIUM")
hud:SetClampedToScreen(true)
hud:SetMovable(true)
hud:EnableMouse(true)
hud:RegisterForDrag("LeftButton")
UI.Flat(hud, S.bg, S.edge)
hud:Hide()
-- The HUD is kept by its top-left corner, so its height changing doesn't
-- move it; the Lure button follows it every frame while it's dragged.
local function saveTopLeft(self)
  local left, top = self:GetLeft(), self:GetTop()
  if not (left and top) then return end
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  st().fishHudPos = { "TOPLEFT", "BOTTOMLEFT", left, top }
end
hud:SetScript("OnDragStart", function(self)
  if st().fishHudLock or combat() then return end
  self:StartMoving()
  self.moving = true
end)
hud:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  self.moving = false
  saveTopLeft(self)
  SF.RefreshHUD()
end)
hud:SetScript("OnUpdate", function(self)
  if self.moving and SF.placeLure then SF.placeLure() end
end)
hud:SetScript("OnHide", function() if not combat() then lureBtn:Hide() end end)
hud.title = UI.Text(hud, 12, S.gold)
hud.title:SetPoint("TOPLEFT", 10, -8)
hud.title:SetText("Fishing")
hud.sub = UI.Text(hud, 10, S.dim)
hud.sub:SetPoint("TOPLEFT", hud.title, "BOTTOMLEFT", 0, -3)
hud.sub:SetWidth(200)
hud.sub:SetWordWrap(false)
hud.lines = {}
for i = 1, 6 do
  local l = UI.Text(hud, 11, S.dim)
  local v = UI.Text(hud, 11, S.text, "RIGHT")
  hud.lines[i] = { l = l, v = v }
end
hud.tname = UI.Text(hud, 11, S.text)
hud.tname:SetWidth(150)
hud.tname:SetWordWrap(false)
hud.tval = UI.Text(hud, 11, S.text, "RIGHT")
hud.barBg = hud:CreateTexture(nil, "ARTWORK")
hud.barBg:SetColorTexture(unpack(S.sunk))
hud.barBg:SetSize(200, 4)
hud.bar = hud:CreateTexture(nil, "OVERLAY")
hud.bar:SetColorTexture(unpack(BLUE))
hud.bar:SetHeight(4)
hud.nextText = UI.Text(hud, 11, S.gold)
hud.nextText:SetWidth(160)
hud.nextText:SetWordWrap(false)
hud.key = UI.Text(hud, 11, S.text, "RIGHT")
hud.notice = UI.Text(hud, 10, S.good)
hud.notice:SetWidth(200)
hud.notice:SetWordWrap(false)
hud.bEquip = SF.Button(hud, "equip", 64, 20, "Gear")
hud.bJournal = UI.Button(hud, "Journal", 64, function() if NW.OpenFishJournal then NW.OpenFishJournal() end end, 20)

local function fmtTime(sec)
  sec = math.floor(sec or 0)
  if sec >= 3600 then return ("%dh %02dm"):format(sec / 3600, (sec % 3600) / 60) end
  return ("%d:%02d"):format(sec / 60, sec % 60)
end
SF.fmtTime = fmtTime

-- the session's value, worked out when a catch comes in (not every second)
local function sessionValue()
  local sess = J and J.session()
  if not sess then SF.sessValue = nil return end
  local v, partial = J.Value(sess.items)
  SF.sessValue = { v, partial }
end
SF.sessionValue = sessionValue

-- shown with a pole on, a bobber out, or fishing in the last 5 minutes
function SF.HudWanted()
  local s = st()
  if not s.fishHud then return false end
  if SF.poleOn() or SF.channeling then return true end
  local sess = J and J.session()
  return sess ~= nil and not sess.pausedAt and (time() - (sess.last or 0)) < HUD_IDLE
end

-- put the secure Lure button over its place in the HUD, by coordinates
local lureX, lureY
local function placeLure(x, y, show)
  if combat() then return end
  if x == nil then x, y, show = lureX, lureY, lureX ~= nil end -- (while dragging)
  lureX, lureY = show and x or nil, show and y or nil
  if not show then lureBtn:Hide() return end
  local left, top = hud:GetLeft(), hud:GetTop()
  local p = st().fishHudPos
  if not hud.moving and p and p[1] == "TOPLEFT" and p[2] == "BOTTOMLEFT" then left, top = p[3], p[4] end
  if not (left and top) then lureBtn:Hide() return end
  lureBtn:SetScale(hud:GetScale())
  lureBtn:SetFrameStrata("MEDIUM")
  lureBtn:SetFrameLevel(hud:GetFrameLevel() + 10)
  lureBtn:ClearAllPoints()
  lureBtn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + x, top + y)
  lureBtn:Show()
end

function SF.RefreshHUD()
  local s = st()
  local inCombat = combat()
  local want = SF.HudWanted()
  if not want then
    if hud:IsShown() then hud:Hide() end
    if not inCombat and lureBtn:IsShown() then lureBtn:Hide() end
    return
  end
  if not inCombat then
    if not hud.placed then
      hud.placed = true
      local p = s.fishHudPos
      hud:ClearAllPoints()
      if p then hud:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else hud:SetPoint("RIGHT", UIParent, "RIGHT", -260, 60) end
      -- an older saved place, or the default: turn it into a top-left one once laid out
      if not (p and p[1] == "TOPLEFT" and p[2] == "BOTTOMLEFT") then
        C_Timer.After(0, function() if not combat() then saveTopLeft(hud); SF.RefreshHUD() end end)
      end
    end
    hud:SetScale(s.fishHudScale or 1)
  end
  hud:SetBackdropColor(S.bg[1], S.bg[2], S.bg[3], s.fishHudAlpha or 0.9)
  hud:SetBackdropBorderColor(S.edge[1], S.edge[2], S.edge[3], s.fishHudAlpha or 0.9)
  if not hud:IsShown() then hud:Show() end
  local mini = s.fishHudMini
  local rank, max = NW.ProfSkill("fishing")
  local bonus = rank and NW.ProfBonus("fishing") or 0
  local sess = J and J.session()
  local left = SF.lureLeft()
  local lname = SF.lureName()
  local rows = {}
  rows[#rows + 1] = { "Fishing", rank and (("%d / %d"):format(rank, max or 75) .. (bonus > 0 and ("  |cff7aa0c1%d|r"):format(rank + bonus) or "")) or "–" }
  rows[#rows + 1] = { mini and "Lure" or (lname or "Lure"), left and (H.good .. fmtTime(left) .. "|r") or (H.dim .. "none|r") }
  rows[#rows + 1] = { "Caught", sess and tostring(sess.fish) or "0" }
  if not mini and s.fishHudValue ~= false and sess then
    if not SF.sessValue then sessionValue() end
    local sv = SF.sessValue or { 0, false }
    rows[#rows + 1] = { "Est. value", (sv[1] > 0 and ("~" .. NW.Money(sv[1], "gs")) or "–") .. (sv[2] and (H.bad .. " +?|r") or "") }
  end
  local y = -8
  hud.title:SetShown(not mini)
  hud.sub:SetShown(not mini)
  if not mini then
    local zone = GetZoneText and GetZoneText() or ""
    hud.sub:SetText(sess and (("%s  ·  %s%s"):format(zone, fmtTime(J.Elapsed(sess)), sess.pausedAt and "  ·  paused" or "")) or zone)
    y = -36
  end
  for i, ln in ipairs(hud.lines) do
    local r = rows[i]
    ln.l:SetShown(r ~= nil)
    ln.v:SetShown(r ~= nil)
    if r then
      ln.l:ClearAllPoints() ln.v:ClearAllPoints()
      ln.l:SetPoint("TOPLEFT", 10, y)
      ln.v:SetPoint("TOPRIGHT", -10, y)
      ln.l:SetText(r[1])
      ln.v:SetText(r[2])
      y = y - 15
    end
  end
  -- the fish the Fishing + Cooking plan wants
  local t = (not mini) and SF.Target() or nil
  local catch = t and t.catch
  hud.tname:SetShown(catch ~= nil)
  hud.tval:SetShown(catch ~= nil)
  hud.barBg:SetShown(catch ~= nil)
  hud.bar:SetShown(catch ~= nil)
  if catch then
    y = y - 4
    local have = NW.ItemCount(catch.fish) or 0
    local need = catch.need
    hud.tname:ClearAllPoints() hud.tval:ClearAllPoints()
    hud.tname:SetPoint("TOPLEFT", 10, y)
    hud.tval:SetPoint("TOPRIGHT", -10, y)
    hud.tname:SetText(((NW.ItemName(catch.fish) or "Fish"):gsub("^Raw ", "")))
    hud.tval:SetText(("%s%d|r%s/~%d|r"):format(have >= need and H.good or H.text, math.min(have, need), H.dim, need))
    y = y - 15
    hud.barBg:ClearAllPoints()
    hud.barBg:SetPoint("TOPLEFT", 10, y)
    hud.bar:ClearAllPoints()
    hud.bar:SetPoint("LEFT", hud.barBg, "LEFT")
    hud.bar:SetWidth(math.max(1, 200 * math.min(1, have / math.max(1, need))))
    y = y - 10
  end
  -- what the key does next
  hud.nextText:ClearAllPoints() hud.key:ClearAllPoints()
  hud.nextText:SetPoint("TOPLEFT", 10, y - 2)
  hud.key:SetPoint("TOPRIGHT", -10, y - 2)
  local label = inCombat and not SF.channeling and "In combat" or (SF.label or "Cast Fishing")
  hud.nextText:SetText(mini and ("Next: " .. (label:gsub(" Fishing$", ""))) or label)
  local key = SF.key()
  hud.key:SetText(key and (H.dim .. (GetBindingText and GetBindingText(key, "KEY_") or key) .. "|r") or (H.dim .. "no key|r"))
  y = y - 18
  -- notices for a few seconds
  local showNotice = SF.notice and GetTime() - (SF.noticeAt or 0) < 6
  hud.notice:SetShown(showNotice and true or false)
  if showNotice then
    hud.notice:ClearAllPoints()
    hud.notice:SetPoint("TOPLEFT", 10, y)
    hud.notice:SetText(SF.notice)
    y = y - 14
  end
  hud.bEquip:SetShown(not mini)
  hud.bJournal:SetShown(not mini)
  local lureY
  if not mini then
    y = y - 2
    hud.bEquip:ClearAllPoints()
    hud.bEquip:SetPoint("TOPLEFT", 10, y)
    hud.bJournal:ClearAllPoints()
    hud.bJournal:SetPoint("TOPLEFT", 10 + 2 * 68, y)
    lureY = y
    y = y - 22
  end
  hud:SetHeight(-y + 8)
  placeLure(10 + 68, lureY or 0, lureY ~= nil)
end

SF.placeLure = function() placeLure() end

-- once a second, whether the HUD is up or not: lure alerts, the lure you put
-- on, a channel that ended unseen, the session's idle end, and the HUD
local alerts = CreateFrame("Frame")
SF.alerts = alerts
local tick = 0
alerts:SetScript("OnUpdate", function(_, el)
  tick = tick + el
  if tick < 1 then return end
  tick = 0
  if not NW.db then return end
  local left = SF.lureLeft()
  -- a lure click counts once an enchant shows up (or grows) within 10 seconds
  local pl = SF.pendingLure
  if pl then
    if left and (not pl.had or left > pl.had + 1) then
      cdb().fishLureUsed = { id = pl.id, t = time() }
      SF.pendingLure = nil
    elseif GetTime() - pl.at > 10 then
      SF.pendingLure = nil
    end
  end
  if st().fishNotifyLure ~= false and SF.poleOn() then
    if left then
      if SF.lastLeft and left > SF.lastLeft + 1 then SF.warnedSoon = false end -- put on again
      SF.hadLure = true
      if left < 30 and not SF.warnedSoon then SF.warnedSoon = true; NW.FishNotify("Lure: 30 seconds left", "lure") end
    elseif SF.hadLure then
      SF.hadLure, SF.warnedSoon = false, false
      NW.FishNotify("Lure expired", "lure")
      local u = cdb() and cdb().fishLureUsed
      local n = u and SF.lureCount(u.id) or 0
      if n > 0 and n < 3 then NW.FishNotify(("%s: %d left"):format(itemName(u.id), n), "lure") end
    end
  elseif not SF.poleOn() then
    SF.hadLure = false -- a pole taken off with a lure on isn't an expired lure
  end
  SF.lastLeft = left
  if SF.warnedMissing and SF.bags()[SF.prefLure()] then SF.warnedMissing = false end
  -- a channel whose end the game didn't report
  if SF.channeling and UnitChannelInfo and not UnitChannelInfo("player") then channelEnded() end
  if J and J.CheckIdle then J.CheckIdle() end
  if hud:IsShown() or SF.HudWanted() then SF.RefreshHUD() end
end)
if J then J.OnChange(function(what)
  if what == "catch" or what == "session" then sessionValue() end
  if hud:IsShown() then SF.RefreshHUD() end
end) end

function NW.ToggleFishHUD()
  st().fishHud = not st().fishHud
  SF.RefreshHUD()
  if st().fishHud and not hud:IsShown() and UIErrorsFrame then
    UIErrorsFrame:AddMessage("Fishing HUD: shows with a pole on", S.dim[1], S.dim[2], S.dim[3])
  end
end
