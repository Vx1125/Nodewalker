local ADDON, NW = ...

local S, UI = NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Buff tracker: the consumables in your Consumes loadout, live.
--
-- What it tracks comes from Consumes (NW.ConsumeSelection): your spec, level, activity,
-- strategy, loadout and your own picks. Nothing is configured here item by item.
--
-- How a buff is recognised (no names, no invented IDs):
--   * the item's own use spell, from the client (GetItemSpell). An aura with that spell ID on
--     you is that buff.
--   * what Nodewalker has seen on your characters: when you use a tracked item, the aura it
--     gives you is remembered (db.buffSeen[item] = aura spell ID). Food works this way: eating
--     is one spell, Well Fed another.
--   * weapon oils, stones and poisons are temporary weapon enchants (GetWeaponEnchantInfo); the
--     enchant you get from an item is remembered the same way (db.enchSeen[enchant] = item).
-- A buff Nodewalker hasn't confirmed yet shows as unknown, never as missing.
--
-- The client hides your auras from addons in combat. The last reading before the pull is
-- kept and counted down; nothing becomes "missing" from what can't be seen.
--
-- Potions, runes, bandages and the like aren't buffs to keep up: they're a separate,
-- optional row with your count and the item's cooldown (the client's own, shared ones too).
--
-- Icons are secure item buttons (click to use, a click you make). Nothing secure is shown,
-- hidden, moved or changed in combat; the layout waits for the fight to end.
------------------------------------------------------------------------
local T = {}
NW.BuffTracker = T
local function st() return NW.db.settings end
local function combat() return InCombatLockdown and InCombatLockdown() end
local R = NW.Readable
local function now() return GetTime() end
-- what's in your bags (not the bank)
local function bagCount(id)
  if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
  if GetItemCount then return GetItemCount(id) or 0 end
  return 0
end

-- What each Consumes heading is: a buff you keep up, a weapon enchant, or something you use
local BUFF = { Flask = "buff", Elixirs = "buff", Food = "buff", ["Weapon oil"] = "weapon", Weapon = "weapon", Poisons = "weapon" }
local function kindOf(e)
  if e.group == "Camp" then return nil end
  -- the leveling list's Utility: scrolls are buffs, drinks are used
  if e.group == "Utility" then return tostring(e.key):match("^lad:s%u") and "buff" or "use" end
  return BUFF[e.group] or "use"
end
T.kindOf = kindOf

------------------------------------------------------------------------
-- Client data: an item's use spell, its cooldown, your auras and weapon enchants
------------------------------------------------------------------------
local useSpell = {} -- [item] = spell ID (only tracked items; cleared with the selection)
local function spellOf(id)
  local v = useSpell[id]
  if v ~= nil then return v or nil end
  local ok, _, sid = pcall(function() return (C_Item and C_Item.GetItemSpell or GetItemSpell)(id) end)
  if ok and R(sid) and type(sid) == "number" then useSpell[id] = sid return sid end
  -- (nil until the item is cached: asked again next time)
end
T.spellOf = spellOf

local function seen() NW.db.buffSeen = NW.db.buffSeen or {} return NW.db.buffSeen end
local function enchSeen() NW.db.enchSeen = NW.db.enchSeen or {} return NW.db.enchSeen end

-- Your helpful auras: [spell ID] = expiration (0 = none). Kept from the last reading where
-- every slot could be read; a reading with hidden slots only adds to it.
local auras, hiddenNow = {}, false
local fresh = {}
local durs = {} -- [spell ID] = full duration, when the client gives it
local function readAuras()
  wipe(fresh)
  local hidden = false
  local modern = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  for i = 1, 40 do
    local sid, exp, dur, done, hid
    if modern then
      local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok then hid = true
      elseif not d then done = true
      else
        local ok2, a, b, c = pcall(function() return d.spellId, d.expirationTime, d.duration end)
        if ok2 then sid, exp, dur = a, b, c else hid = true end
      end
    elseif UnitBuff then
      local ok, n, _, _, _, du, e, _, _, _, id = pcall(UnitBuff, "player", i)
      if not ok then hid = true elseif not n then done = true else sid, exp, dur = id, e, du end
    else
      done = true
    end
    if done then break end
    if hid or not R(sid) then hidden = true
    else
      fresh[sid] = (R(exp) and type(exp) == "number") and exp or 0
      if R(dur) and type(dur) == "number" and dur > 0 then durs[sid] = dur end
    end
  end
  -- in combat the client may hide auras by returning none at all: there, a reading only adds
  if combat() then hidden = true end
  hiddenNow = hidden
  if hidden then
    for k, v in pairs(fresh) do auras[k] = v end
  else
    wipe(auras)
    for k, v in pairs(fresh) do auras[k] = v end
    for k in pairs(durs) do if not fresh[k] then durs[k] = nil end end
  end
  return not hidden
end
T.auras = auras

-- Temporary weapon enchants: { has, seconds left, enchant ID } for main and off hand
local weapon = { mh = {}, oh = {} }
local function readWeapon()
  if not GetWeaponEnchantInfo then weapon.ok = false return end
  local ok, mh, mhMs, _, mhID, oh, ohMs, _, ohID = pcall(GetWeaponEnchantInfo)
  if not ok or not R(mh) then weapon.ok = false return end -- hidden: keep the last
  weapon.ok = true
  local t = now()
  weapon.mh.on, weapon.mh.exp, weapon.mh.id = mh and true or false, (mh and R(mhMs) and mhMs) and (t + mhMs / 1000) or nil, R(mhID) and mhID or nil
  weapon.oh.on, weapon.oh.exp, weapon.oh.id = oh and true or false, (oh and R(ohMs) and ohMs) and (t + ohMs / 1000) or nil, R(ohID) and ohID or nil
end
T.weapon = weapon

-- An item's cooldown: start, duration (the client's, shared cooldowns included)
local function cooldownOf(id)
  local fn = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
  if not fn then return nil end
  local ok, start, dur = pcall(fn, id)
  if ok and R(start) and R(dur) and dur and dur > 1.5 and start > 0 then return start, dur end
end

------------------------------------------------------------------------
-- Learning what an item gives you (seen on your characters, kept account-wide)
------------------------------------------------------------------------
local pending -- { item, food, at, before = { aura set }, mh, oh }
local function snapshotSet()
  local b = {}
  for k in pairs(auras) do b[k] = true end
  return b
end
local function learn()
  if not pending then return end
  local p = pending
  local age = now() - p.at
  if p.kind == "weapon" then
    local learned
    for _, h in ipairs({ "mh", "oh" }) do
      local w = weapon[h]
      if w.on and w.id and w.id ~= p[h] then enchSeen()[w.id] = p.item learned = true end
    end
    if learned or age > 10 then pending = nil end
    return
  end
  -- the aura with the item's own spell ID (not while eating: that one is the eating itself)
  if not p.food and auras[p.spell] then seen()[p.item] = p.spell pending = nil return end
  -- otherwise one new aura that started after the use (eating: Well Fed comes 10 s or more in)
  -- (eating and drinking auras last 30 s: a buff lasts longer, or has no end)
  local new, n = nil, 0
  local t = now()
  for k, exp in pairs(fresh) do
    if not p.before[k] and k ~= p.spell and (exp == 0 or exp - t > 60) then new, n = k, n + 1 end
  end
  if n == 1 and (not p.food or p.ate) then seen()[p.item] = new pending = nil return end
  if p.food and auras[p.spell] then p.ate = true end
  if age > (p.food and 45 or 5) then pending = nil end
end

------------------------------------------------------------------------
-- What's tracked and where it stands
------------------------------------------------------------------------
local tracked = {}    -- from the Consumes selection: { id, kind, alts, group, need }
local bySpell = {}    -- [use spell] = tracked entry (for learning)
local carry = {}
local function rebuildTracked(rebuildConsumes)
  wipe(carry)
  for _, x in ipairs(tracked) do carry[x.id] = x end
  wipe(tracked)
  wipe(bySpell)
  wipe(useSpell)
  if not st().buffHud then return end
  for _, e in ipairs(NW.ConsumeSelection and NW.ConsumeSelection(rebuildConsumes) or {}) do
    local k = kindOf(e)
    if k and (k ~= "use" or st().buffCooldowns) then
      local x = { id = e.id, kind = k, alts = e.alts, group = e.group, need = e.need or 0, tier = e.tier }
      local old = carry[e.id]
      if old then x.state, x.prev, x.last, x.hadStock, x.exp, x.by = old.state, old.prev, old.last, old.hadStock, old.exp, old.by end
      tracked[#tracked + 1] = x
      carry[e.id] = nil
      if k ~= "use" then
        for _, a in ipairs(e.alts or { e.id }) do
          local sp = spellOf(a)
          if sp then bySpell[sp] = { item = a, kind = k, food = e.group == "Food" } end
        end
      end
    end
  end
  wipe(carry)
end
T.tracked = tracked

-- states: on, expiring, missing, out (missing, none in your bags), unknown; use: ready, cd, none
local function buffState(x)
  local sn = seen()
  local cands = x.alts or { x.id }
  local best, bestExp, knownAny, bestAura = nil, nil, false, nil
  for _, c in ipairs(cands) do
    local aura = sn[c]
    local direct = spellOf(c)
    if aura then knownAny = true end
    local hit = (aura and auras[aura]) or (direct and x.group ~= "Food" and auras[direct])
    if hit then
      if direct and auras[direct] and not aura and x.group ~= "Food" then sn[c] = direct knownAny = true end
      local exp = hit
      if not best or (exp == 0) or (bestExp ~= 0 and exp > bestExp) then
        best, bestExp, bestAura = c, exp, (aura and auras[aura]) and aura or direct
      end
    end
  end
  if best then
    if bestExp > 0 and bestExp <= now() then best = nil -- ran out (counted down through combat)
    else x.dur = bestAura and durs[bestAura] return "on", best, bestExp end
  end
  -- not seen on you: missing only when Nodewalker knows what it looks like
  if not knownAny then return "unknown" end
  local miss = bagCount(x.id) > 0 and "missing" or "out"
  if combat() or hiddenNow then
    -- can't look: one that was on and has run out is gone; anything else stays as it was
    if x.last == "on" then return miss end
    return x.last or "unknown"
  end
  return miss
end

local function weaponState(x)
  if not weapon.ok then return x.last or "unknown" end
  if NW.SmartFish and NW.SmartFish.poleOn and NW.SmartFish.poleOn() then return "unknown" end -- a lure on the pole
  local es = enchSeen()
  local cands = x.alts or { x.id }
  local isCand = {}
  for _, c in ipairs(cands) do isCand[c] = true end
  local hands = x.group == "Poisons" and { "mh", "oh" } or { "mh" }
  local anyOn, unmapped = false, false
  for _, h in ipairs(hands) do
    local w = weapon[h]
    if w.on then
      anyOn = true
      local item = w.id and es[w.id]
      if item and isCand[item] then return "on", item, w.exp or 0 end
      if not item then unmapped = true end
    end
  end
  -- oils and stones: something already on the weapon will do; poisons: can't tell which
  if anyOn and x.group ~= "Poisons" then return "on", nil, (weapon.mh.exp or 0) end
  if unmapped then return "unknown" end
  if anyOn then return (bagCount(x.id)) > 0 and "missing" or "out" end -- (another poison's)
  return (bagCount(x.id)) > 0 and "missing" or "out"
end

local function evaluate()
  local t = now()
  local warn = (st().buffWarnMin or 5) * 60
  for _, x in ipairs(tracked) do
    x.count = bagCount(x.id)
    if x.kind == "use" then
      local s0, d = cooldownOf(x.id)
      x.cdStart, x.cdDur = s0, d
      x.state = x.count == 0 and "none" or (s0 and "cd" or "ready")
    else
      local state, by, exp
      if x.kind == "weapon" then state, by, exp = weaponState(x) else state, by, exp = buffState(x) end
      x.by, x.exp = by, (exp and exp > 0) and exp or nil
      if state == "on" and x.exp and x.exp - t <= warn then state = "expiring" end
      x.prev, x.last, x.state = x.state, (state == "expiring" and "on" or state), state
    end
  end
end

------------------------------------------------------------------------
-- Notices: once each, never while you're dead
------------------------------------------------------------------------
local said = {} -- [item .. state] = true
local function notify(text)
  if st().buffSound and PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175, "SFX") end
  if UIErrorsFrame then UIErrorsFrame:AddMessage(text, S.gold[1], S.gold[2], S.gold[3]) end
end
local function itemName(id) return NW.ItemName(id) or ("item " .. id) end
local function notices()
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
  for _, x in ipairs(tracked) do
    local key = x.id
    if x.kind ~= "use" then
      if x.state == "expiring" and st().buffNotifyExpiring and not said[key .. "exp"] then
        said[key .. "exp"] = true
        notify(("%s: %d min left"):format(itemName(x.by or x.id), math.max(1, math.floor((x.exp - now()) / 60 + 0.5))))
      elseif (x.state == "missing" or x.state == "out") and (x.prev == "on" or x.prev == "expiring") and st().buffNotifyMissing then
        notify(itemName(x.id) .. ": expired")
      end
      if x.state == "on" then said[key .. "exp"] = nil end
    end
    if x.count == 0 and st().buffNotifyStock and not said[key .. "out"] and x.hadStock then
      said[key .. "out"] = true
      notify(itemName(x.id) .. ": out of stock")
    end
    if x.count > 0 then said[key .. "out"] = nil x.hadStock = true end
  end
end
function T.ReadyCheckSummary()
  local miss = {}
  for _, x in ipairs(tracked) do
    if x.kind ~= "use" and (x.state == "missing" or x.state == "out") then miss[#miss + 1] = itemName(x.id) end
  end
  return miss
end

------------------------------------------------------------------------
-- HUD: a row of buffs, then a row of things you use (optional); icons from a small pool
------------------------------------------------------------------------
local hud = CreateFrame("Frame", "NodewalkerBuffHUD", UIParent)
T.hud = hud
hud:SetSize(40, 40)
hud:SetFrameStrata("MEDIUM")
hud:SetClampedToScreen(true)
hud:SetMovable(true)
hud:EnableMouse(false)
hud:Hide()
-- a grip to drag it by (shown only while it isn't locked)
local grip = CreateFrame("Frame", nil, hud, "BackdropTemplate")
grip:SetPoint("BOTTOMLEFT", hud, "TOPLEFT", 0, 2)
grip:SetSize(40, 8)
UI.Flat(grip, S.header, S.edge)
grip:EnableMouse(true)
grip:RegisterForDrag("LeftButton")
grip:SetScript("OnDragStart", function() if not (st().buffHudLock or combat()) then hud:StartMoving() hud.moving = true end end)
grip:SetScript("OnDragStop", function()
  hud:StopMovingOrSizing()
  hud.moving = false
  local l, top = hud:GetLeft(), hud:GetTop()
  if l and top then
    hud:ClearAllPoints()
    hud:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, top)
    st().buffHudPos = { l, top }
  end
end)
UI.Tip(grip, "Consumables", "Drag to move. Lock it in Settings › Consumes.")

local icons = {}
local DIM = { 0, 0, 0, 0.85 }
local BORDER = {
  on = DIM, ready = DIM,
  expiring = { 0.839, 0.698, 0.400, 0.75 }, -- muted gold
  missing = { 0.820, 0.463, 0.396, 0.9 },   -- red: you have one, it isn't on
  out = DIM, none = DIM, cd = DIM,
  unknown = { 0.576, 0.549, 0.502, 0.6 },   -- neutral
}
local function fmtTime(sec)
  if sec >= 3600 then return ("%dh"):format(math.floor(sec / 3600 + 0.5)) end
  if sec >= 60 then return ("%dm"):format(math.ceil(sec / 60)) end
  return ("%ds"):format(math.max(0, math.floor(sec)))
end

local function iconTip(self)
  local x = self.x
  if not x then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if not pcall(GameTooltip.SetItemByID, GameTooltip, x.by or x.id) then GameTooltip:SetText(itemName(x.id), 1, 1, 1) end
  GameTooltip:AddLine(" ")
  local d = S.dim
  local line
  if x.kind == "use" then
    line = x.state == "cd" and ("Cooldown: " .. fmtTime(x.cdStart + x.cdDur - now())) or (x.state == "none" and "None in your bags" or "Ready")
  elseif x.state == "on" or x.state == "expiring" then
    line = x.exp and ("On you: " .. fmtTime(x.exp - now()) .. " left") or "On you"
    if x.by and x.by ~= x.id then line = line .. "\nCovers " .. itemName(x.id) end
    if not x.by and x.kind == "weapon" then line = line .. "\nA weapon enchant Nodewalker hasn't seen applied" end
  elseif x.state == "missing" then line = "Not on you"
  elseif x.state == "out" then line = "Not on you, and none in your bags"
  else
    line = (combat() or hiddenNow) and "Can't be read in combat" or "Not confirmed yet: use it once and Nodewalker learns its buff"
  end
  GameTooltip:AddLine(line, 1, 1, 1, true)
  GameTooltip:AddDoubleLine("In your bags", tostring(x.count or 0), d[1], d[2], d[3], 1, 1, 1)
  if st().buffClickUse ~= false then GameTooltip:AddDoubleLine("Click", "use it", d[1], d[2], d[3], 1, 1, 1) end
  GameTooltip:AddDoubleLine("Right-click", "in Consumes", d[1], d[2], d[3], 1, 1, 1)
  GameTooltip:Show()
end

local function iconFor(i)
  local b = icons[i]
  if b then return b end
  b = CreateFrame("Button", "NodewalkerBuffIcon" .. i, hud, "SecureActionButtonTemplate, BackdropTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  UI.Flat(b, S.sunk, DIM)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetPoint("TOPLEFT", 1, -1)
  b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.tex)
  if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
  if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
  b.count = UI.Text(b, 11, S.text, "RIGHT")
  b.count:SetPoint("BOTTOMRIGHT", -1, 2)
  if b.count.SetShadowOffset then b.count:SetShadowOffset(1, -1) end
  -- unknown: a small neutral square in the corner (not a red edge: it isn't missing)
  b.unk = UI.Text(b, 12, S.text, "CENTER")
  b.unk:SetPoint("TOPLEFT", 3, -2)
  b.unk:SetText("?")
  if b.unk.SetShadowOffset then b.unk:SetShadowOffset(1, -1) end
  -- time left above the icon; the count stays in the corner, so the two never meet
  b.time = UI.Text(b, 10, S.text, "CENTER")
  b.time:SetPoint("BOTTOM", b, "TOP", 0, 2)
  b:SetScript("OnEnter", iconTip)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("PostClick", function(self, button, down)
    if down then return end
    if button == "RightButton" and self.x and not combat() and NW.ShowConsume then NW.ShowConsume(self.x.id) end
  end)
  icons[i] = b
  return b
end

-- which to show: by display mode
local function wanted(x)
  if st().buffHideEmpty and (x.state == "out" or x.state == "none") then return false end
  if x.kind == "use" then return true end
  local m = st().buffMode or "all"
  if m == "all" then return true end
  if x.state == "missing" or x.state == "out" or x.state == "unknown" then return true end
  return m == "soon" and x.state == "expiring"
end

local function contextHides()
  if st().buffHideResting and IsResting and IsResting() then return true end
  if st().buffHideMounted and IsMounted and IsMounted() then return true end
  return false
end
local shownList, want = {}, {}
local function desired()
  wipe(want)
  local buffsOk = true
  for _, x in ipairs(tracked) do
    -- (one hidden as out of stock doesn't stop "fully buffed")
    if x.kind ~= "use" and x.state ~= "on" and x.state ~= "expiring" and not (st().buffHideEmpty and x.state == "out") then buffsOk = false end
  end
  for _, x in ipairs(tracked) do
    if wanted(x) and not (x.kind ~= "use" and buffsOk and st().buffHideOk) then want[#want + 1] = x end
  end
  return want
end
local function sameList()
  if #want ~= #shownList then return false end
  for i, x in ipairs(want) do if shownList[i] ~= x then return false end end
  return true
end
local function layout()
  if combat() then T.relayout = true return end
  T.relayout = false
  wipe(shownList)
  for i, x in ipairs(want) do shownList[i] = x end
  local size = st().buffIconSize or 32
  local gap, sep = 3, 4
  local tH = st().buffShowTime ~= false and 12 or 0
  local vertical = st().buffLayout == "vertical"
  -- along: where the next icon goes in its group; across: where the group starts
  local along, across, groupDepth, maxAlong, total = 0, 0, 0, 0, 0
  local lastKind
  for i, x in ipairs(shownList) do
    local b = iconFor(i)
    local k = x.kind == "use" and "use" or "buff"
    if lastKind and k ~= lastKind then across, along, groupDepth = across + groupDepth + sep, 0, 0 end -- things you use: their own group
    lastKind = k
    local s = size
    b:ClearAllPoints()
    b:SetSize(s, s)
    if vertical then
      b:SetPoint("TOPLEFT", hud, "TOPLEFT", across, -(along + tH))
      along = along + tH + s + gap
      groupDepth = math.max(groupDepth, s)
    else
      b:SetPoint("TOPLEFT", hud, "TOPLEFT", along, -(across + tH))
      along = along + s + gap
      groupDepth = math.max(groupDepth, tH + s)
    end
    maxAlong = math.max(maxAlong, along - gap)
    total = across + groupDepth
    b.x = x
    b:SetAttribute("type1", st().buffClickUse ~= false and "item" or nil)
    b:SetAttribute("item", "item:" .. x.id)
    b:Show()
  end
  for i = #shownList + 1, #icons do
    icons[i].x = nil
    icons[i]:SetAttribute("type1", nil)
    icons[i]:Hide()
  end
  local n = #shownList
  local w = vertical and total or maxAlong
  local h = vertical and maxAlong or total
  hud:SetSize(math.max(size, w), math.max(size, h))
  grip:SetWidth(math.max(size, w))
  grip:SetShown(not st().buffHudLock)
  hud:SetScale(st().buffHudScale or 1)
  hud:SetAlpha(st().buffHudAlpha or 1)
  hud:SetShown(st().buffHud and n > 0 and not contextHides() and true or false)
end

-- what changes in combat too: textures, borders, counts, times, cooldown swipes
local function paint()
  local t = now()
  local showCount, showTime = st().buffShowCount ~= false, st().buffShowTime ~= false
  local timed = false
  for _, b in ipairs(icons) do
    local x = b.x
    if x and b:IsShown() then
      b.tex:SetTexture(NW.ItemIcon(x.by or x.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local st0 = x.state
      local muted = st0 == "out" or st0 == "none"
      if b.tex.SetDesaturated then b.tex:SetDesaturated(muted) end
      b.tex:SetAlpha(muted and 0.45 or 1)
      b:SetBackdropBorderColor(unpack(BORDER[st0] or DIM))
      b.count:SetText(showCount and tostring(x.count or 0) or "")
      b.count:SetTextColor(unpack((x.count or 0) == 0 and S.bad or S.text))
      b.unk:SetShown(st0 == "unknown")
      local left, cs, cdur
      if x.kind == "use" then
        if x.cdStart then left, cs, cdur = x.cdStart + x.cdDur - t, x.cdStart, x.cdDur end
      elseif x.exp then
        left = x.exp - t
        if x.dur and x.dur > 0 then cs, cdur = x.exp - x.dur, x.dur end
      end
      -- the game's own cooldown animation: started once, cleared once
      if cs ~= b.cdS or cdur ~= b.cdD then
        b.cdS, b.cdD = cs, cdur
        if cs then b.cd:SetCooldown(cs, cdur) else b.cd:Clear() end
      end
      if left and left > 0 then timed = true end
      b.time:SetText((showTime and left and left > 0) and fmtTime(left) or "")
      b.time:SetTextColor(unpack(st0 == "expiring" and S.gold or S.text))
    end
  end
  return timed
end

------------------------------------------------------------------------
-- Updates: events mark what's stale; one short timer does the work; a 1-second
-- ticker runs only while the HUD is up and something counts down
------------------------------------------------------------------------
local dirty = { auras = true, weapon = true, list = true }
T.dirty = dirty
local queued, ticker = false
local function stopTicker() if ticker then ticker:Cancel() ticker = nil end end
local update
local function startTicker()
  if ticker then return end
  ticker = C_Timer.NewTicker(1, function()
    if not hud:IsShown() then stopTicker() return end
    -- a buff running out or a cooldown ending changes the state, not just the number
    dirty.tick = true
    update()
  end)
end
update = function()
  queued = false
  if not st().buffHud then
    stopTicker()
    if not combat() then hud:Hide() end
    return
  end
  if dirty.list then
    if combat() then T.relist = true else rebuildTracked(dirty.rebuild); dirty.rebuild = nil end
    dirty.list = false
  end
  if dirty.auras then readAuras() dirty.auras = false end
  if dirty.weapon then readWeapon() dirty.weapon = false end
  learn()
  evaluate()
  notices()
  -- the set of icons changes only out of combat, and only when it's different
  local ctx = contextHides()
  if ctx ~= T.lastCtx then T.lastCtx, T.relayout = ctx, true end
  desired()
  if T.relayout or not sameList() then layout() end
  dirty.tick = false
  if paint() and hud:IsShown() then startTicker() elseif not hud:IsShown() then stopTicker() end
end
T.Update = update
local function queue(delay)
  if queued then return end
  queued = true
  C_Timer.After(delay or 0.2, update)
end
function T.Refresh(rebuild)
  dirty.list, dirty.auras, dirty.weapon = true, true, true
  if rebuild then dirty.rebuild = true end
  queue(0.05)
end
-- settings changed: position, then everything
function T.Apply()
  if not combat() then
    local p = st().buffHudPos
    hud:ClearAllPoints()
    if p then hud:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2]) else hud:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
    T.relayout = true
  end
  T.Refresh()
end

local function on() return NW.db and st().buffHud end
NW.On("UNIT_AURA", function(unit) if unit == "player" and on() then dirty.auras = true queue() end end)
NW.On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" and on() then dirty.weapon = true queue() end end)
NW.On("BAG_UPDATE_DELAYED", function()
  if not on() then return end
  -- Use what I own picks from your bags: its choices can change
  if st().consumeStrategy == "own" then dirty.list = true dirty.rebuild = true end
  queue(0.3)
end)
NW.On("BAG_UPDATE_COOLDOWN", function() if on() then queue() end end)
NW.On("SPELL_UPDATE_COOLDOWN", function() if on() then queue(0.3) end end)
NW.On("PLAYER_LEVEL_UP", function() if on() then dirty.list, dirty.rebuild = true, true queue(1) end end)
NW.On("PLAYER_REGEN_ENABLED", function()
  if not on() then
    if hud:IsShown() then hud:Hide() end -- (turned off during the fight)
    return
  end
  dirty.auras, dirty.weapon = true, true
  if T.relist then T.relist = nil dirty.list = true end
  T.relayout = true
  queue(0.1)
end)
NW.On("PLAYER_ENTERING_WORLD", function() if on() then C_Timer.After(2, function() T.Apply() T.Refresh(true) end) end end)
NW.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if not on() or not (R(unit) and R(spellID)) or unit ~= "player" then return end
  local hit = bySpell[spellID]
  if not hit then return end
  local p = { item = hit.item, kind = hit.kind, food = hit.food, spell = spellID, at = now(), before = snapshotSet() }
  if hit.kind == "weapon" then p.mh, p.oh = weapon.mh.on and weapon.mh.id, weapon.oh.on and weapon.oh.id end
  pending = p
  dirty.auras, dirty.weapon = true, true
  queue(0.5)
  -- eating takes a while, an oil a few seconds: look again
  for _, d in ipairs({ 3, 12, 25, 40 }) do C_Timer.After(d, function() if pending == p then dirty.auras, dirty.weapon = true, true queue() end end) end
end)
-- a fight is starting: the last moment the HUD can still appear (lockdown comes after this event).
-- Hidden for a city or a mount, it comes back for the fight: potions matter then.
NW.On("PLAYER_REGEN_DISABLED", function()
  if not on() or hud:IsShown() or #shownList == 0 then return end
  if InCombatLockdown and InCombatLockdown() then return end
  hud:Show()
  T.lastCtx = nil -- (looked at again after the fight)
end)
NW.On("PLAYER_UPDATE_RESTING", function() if on() then T.relayout = true queue() end end)
NW.On("PLAYER_MOUNT_DISPLAY_CHANGED", function() if on() then T.relayout = true queue() end end)
NW.On("READY_CHECK", function()
  if not (on() and st().buffNotifyReady) then return end
  local miss = T.ReadyCheckSummary()
  if #miss > 0 then notify("Missing: " .. table.concat(miss, ", ")) end
end)
-- the loadout changed in Consumes (picks, spec, activity, strategy, loadout, level)
if NW.OnConsumeSelection then
  NW.OnConsumeSelection(function() if on() then dirty.list = true queue(0.1) end end)
end

-- Back to the middle of the screen
function T.ResetPosition()
  st().buffHudPos = nil
  T.Apply()
end
-- /nw buffs reset: forget the buffs and enchants learned from your items
function T.ForgetLearned()
  NW.db.buffSeen, NW.db.enchSeen = nil, nil
  T.Refresh()
end
-- /nw buffs: the tracker on or off
function T.Toggle(v)
  if v == nil then v = not st().buffHud end
  st().buffHud = v and true or false
  if v then T.Apply() T.Refresh(true) else
    stopTicker()
    wipe(tracked)
    if not combat() then hud:Hide() end
  end
end
