local ADDON, NW = ...

------------------------------------------------------------------------
-- Smart Tooltips: short Nodewalker sections added to the game's own item
-- and creature tooltips (Settings › Tooltips, /nw tips).
--
-- One hook per tooltip type, through the game's TooltipDataProcessor where
-- the client has it (WoW Forever does, as Auctionator and One For All use it),
-- else OnTooltipSetItem / OnTooltipSetUnit. Each tooltip gets each section
-- once per fill: a fill is marked done and the mark goes when the game clears
-- the tooltip. Only the hovered item or creature is looked up; no scans, no
-- per-frame work, and the one index (creature -> skinning loot) is built once.
------------------------------------------------------------------------
local TT = {}
NW.Tooltips = TT

local GOLD = { 0.84, 0.70, 0.40 }
local DIM = { 0.58, 0.55, 0.50 }
local RED = { 0.82, 0.46, 0.40 }
local DIMHEX = "|cff938c80"

local function st() return NW.db.settings end
local function on(key) local s = st() return s.tipOn ~= false and s[key] ~= false end
local function readable(v) return NW.Readable == nil or NW.Readable(v) end

-- the display mode: always, or only while a modifier is held
local function modifierOK()
  local m = st().tipMode or "always"
  if m == "shift" then return IsShiftKeyDown() end
  if m == "ctrl" then return IsControlKeyDown() end
  if m == "alt" then return IsAltKeyDown() end
  return true
end

local function icon(id) local t = NW.ItemIcon(id) return t and ("|T" .. t .. ":0|t ") or "" end
local function itemName(id)
  local n = NW.ItemInfo(id)
  if n then return n end
  local S = NW.SRC
  local d = S and S.items and S.items[id]
  return d and d[1] or ("item " .. id)
end
local function range(a, b) return a == b and tostring(a) or (a .. "-" .. b) end
local function pct(c)
  if c >= 0.995 then return "" end
  local p = c * 100
  return p < 1 and ("%.1f%%"):format(p) or ("%d%%"):format(math.floor(p + 0.5))
end
-- auction price, or nil (never zero)
local function auction(id)
  local s = NW.PriceStats and NW.PriceStats(id)
  if not s then return nil end
  local p = s.flag and s.typical or s.today
  return (p and p > 0) and p or nil
end
local function money(v) return NW.Money(v, "mid") end

------------------------------------------------------------------------
-- Disenchanting
------------------------------------------------------------------------
function TT.Disenchant(tip, itemID)
  if not on("tipDisenchant") then return end
  local out, how, quality, ilvl = NW.DisenchantOutcomes(itemID)
  if not out then return end
  local skill = NW.DisenchantSkill(quality, ilvl)
  local have = NW.ProfSkill and NW.ProfSkill("enchanting")
  local c = GOLD
  if skill and have and have < skill then c = RED end
  tip:AddDoubleLine("Disenchant" .. (skill and ("  " .. DIMHEX .. "Enchanting " .. skill .. "|r") or ""),
    how == "classic" and "Classic data" or "by item level", c[1], c[2], c[3], DIM[1], DIM[2], DIM[3])
  local counts, chances = on("tipCounts"), on("tipChances")
  local value, missing = 0, false
  for _, o in ipairs(out) do
    local left = "  " .. icon(o[1]) .. itemName(o[1]) .. (counts and (" " .. DIMHEX .. "x" .. range(o[3], o[4]) .. "|r") or "")
    tip:AddDoubleLine(left, chances and pct(o[2]) or "", 1, 1, 1, DIM[1], DIM[2], DIM[3])
    local p = auction(o[1])
    if p then value = value + p * o[2] * (o[3] + o[4]) / 2 else missing = true end
  end
  if on("tipValues") then
    local parts = {}
    if value > 0 then parts[#parts + 1] = "~" .. money(value) .. (missing and " |cffd17665+?|r" or "")
    else parts[#parts + 1] = "no price" end
    local sell = select(11, NW.ItemInfo(itemID))
    if sell and sell > 0 then parts[#parts + 1] = DIMHEX .. "vendor|r " .. money(sell) end
    local ah = auction(itemID)
    if ah then parts[#parts + 1] = DIMHEX .. "auction|r " .. money(ah) end
    tip:AddDoubleLine("  Value", table.concat(parts, "  "), DIM[1], DIM[2], DIM[3], 1, 1, 1)
  end
end

------------------------------------------------------------------------
-- Skinning
------------------------------------------------------------------------
local skinOf -- [npc] = { { item, chance %, min, max }, ... }, built on first use
local function skinIndex()
  if skinOf then return skinOf end
  skinOf = {}
  local S = NW.SRC
  for id, d in pairs(S and S.items or {}) do
    local t = d.skin
    for i = 1, #(t or {}), 4 do
      local l = skinOf[t[i]] or {}
      l[#l + 1] = { id, t[i + 1], t[i + 2], t[i + 3] }
      skinOf[t[i]] = l
    end
  end
  for _, l in pairs(skinOf) do table.sort(l, function(a, b) return a[2] > b[2] end) end
  return skinOf
end
TT.SkinIndex = skinIndex

local function npcOf(unit)
  local guid = UnitGUID(unit)
  if not readable(guid) or type(guid) ~= "string" then return nil end
  local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if kind ~= "Creature" then return nil end
  return tonumber(npc)
end

function TT.Skinning(tip, unit)
  if not on("tipSkinning") then return end
  local isPlayer = UnitIsPlayer(unit)
  if not readable(isPlayer) or isPlayer then return end
  local npc = npcOf(unit)
  if not npc then return end
  local S = NW.SRC
  local u = S and S.units[npc]
  local list = skinIndex()[npc]
  -- no entry, or Classic doesn't say it's skinnable: say nothing (missing data isn't "not skinnable")
  if not list and not (u and u[8]) then return end
  local lvl = UnitLevel(unit)
  if not readable(lvl) or not lvl or lvl <= 0 then lvl = u and u[3] end
  local req = NW.Hunt and NW.Hunt.SkinReq(lvl)
  local have = NW.ProfSkill and NW.ProfSkill("skinning")
  local c = GOLD
  if req and have and have < req then c = RED end
  tip:AddDoubleLine("Skinning" .. (req and (" " .. req) or ""), "Classic data", c[1], c[2], c[3], DIM[1], DIM[2], DIM[3])
  if not list then
    tip:AddLine("  " .. DIMHEX .. "Skinnable; what it gives isn't in Nodewalker's materials|r")
    return
  end
  local counts, chances = on("tipCounts"), on("tipChances")
  local value, missing = 0, false
  for i = 1, math.min(3, #list) do
    local o = list[i]
    local left = "  " .. icon(o[1]) .. itemName(o[1]) .. (counts and (" " .. DIMHEX .. "x" .. range(o[3], o[4]) .. "|r") or "")
    tip:AddDoubleLine(left, chances and pct(o[2] / 100) or "", 1, 1, 1, DIM[1], DIM[2], DIM[3])
  end
  for _, o in ipairs(list) do
    local p = auction(o[1])
    if p then value = value + p * o[2] / 100 * (o[3] + o[4]) / 2 else missing = true end
  end
  if on("tipValues") and value > 0 then
    tip:AddDoubleLine("  Each skin", "~" .. money(value) .. (missing and " |cffd17665+?|r" or ""), DIM[1], DIM[2], DIM[3], 1, 1, 1)
  end
end

------------------------------------------------------------------------
-- Character needs: saved shopping lists (Professions › Characters) that
-- still need this item. Your own list counts your bags live; an alt's uses
-- its bags as last saved, less what you've mailed it. Your bags count once:
-- first toward your own list, then what's left toward the alts.
------------------------------------------------------------------------
local needIndex, needAt = nil, 0
local function needs()
  local now = GetTime()
  if needIndex and now - needAt < 10 then return needIndex end
  needIndex, needAt = {}, now
  local shop, sent = NW.db.altShop or {}, NW.db.altSent or {}
  for ck, plans in pairs(shop) do
    for key, p in pairs(plans) do
      for _, it in ipairs(p.items or {}) do
        if it.id and it.g ~= "r" and it.g ~= "t" then
          local l = needIndex[it.id] or {}
          l[#l + 1] = { ck = ck, key = key, need = it.need or 0, have = it.have or 0, t = p.t,
            sent = (sent[ck] and sent[ck][it.id] and sent[ck][it.id].n) or 0 }
          needIndex[it.id] = l
        end
      end
    end
  end
  return needIndex
end
function TT.ForgetNeeds() needIndex = nil end

function TT.Needs(tip, itemID)
  if not on("tipNeeds") then return end
  local l = needs()[itemID]
  if not l then return end
  local me = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
  local bags = GetItemCount(itemID) or 0
  local rows, mine, alts = {}, 0, 0
  for _, r in ipairs(l) do
    local left
    if r.ck == me then
      left = math.max(0, r.need - bags)
      mine = mine + r.need
    else
      left = math.max(0, r.need - r.have - r.sent)
      alts = alts + left
    end
    if left > 0 or r.ck == me then
      local prof = NW.PROF_BY_KEY and NW.PROF_BY_KEY[r.key]
      rows[#rows + 1] = { (r.ck == me and "You" or (r.ck:gsub("%-$", ""))) .. " " .. DIMHEX .. "· " .. (prof and prof.name or r.key) .. "|r",
        left, r.ck == me }
    end
  end
  local spare = math.max(0, bags - mine)
  local still = math.max(0, mine - bags) + math.max(0, alts - spare)
  if #rows == 0 then return end
  tip:AddDoubleLine("Needed by", "saved lists", GOLD[1], GOLD[2], GOLD[3], DIM[1], DIM[2], DIM[3])
  table.sort(rows, function(a, b) if a[3] ~= b[3] then return a[3] end return a[2] > b[2] end)
  for i = 1, math.min(4, #rows) do tip:AddDoubleLine("  " .. rows[i][1], tostring(rows[i][2]), 1, 1, 1, 1, 1, 1) end
  if #rows > 4 then tip:AddLine("  " .. DIMHEX .. "+" .. (#rows - 4) .. " more|r") end
  tip:AddDoubleLine("  In your bags " .. bags, still > 0 and (still .. " still to get") or "covered", DIM[1], DIM[2], DIM[3], 1, 1, 1)
end

------------------------------------------------------------------------
-- The hooks
------------------------------------------------------------------------
local done = setmetatable({}, { __mode = "k" }) -- [tooltip] = what this fill already has
local watched = setmetatable({}, { __mode = "k" })
local function watch(tip)
  if watched[tip] or not tip.HookScript then return end
  watched[tip] = true
  tip:HookScript("OnTooltipCleared", function(t) done[t] = nil end)
end

local function itemFrom(tip, data)
  if data and type(data.id) == "number" then return data.id end
  local _, link = tip:GetItem()
  return readable(link) and type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function onItem(tip, data)
  if not NW.db or st().tipOn == false then return end
  if tip.IsForbidden and tip:IsForbidden() then return end
  if not modifierOK() then return end
  local id = itemFrom(tip, data)
  if not id then return end
  local mark = "i" .. id
  if done[tip] == mark then return end
  done[tip] = mark
  watch(tip)
  local n = tip:NumLines()
  pcall(TT.Disenchant, tip, id)
  pcall(TT.Needs, tip, id)
  if tip:NumLines() > n then tip:Show() end
end

local function onUnit(tip)
  if not NW.db or st().tipOn == false then return end
  if tip.IsForbidden and tip:IsForbidden() then return end
  if not modifierOK() then return end
  local _, unit = tip:GetUnit()
  if not readable(unit) or not unit then return end
  local npc = npcOf(unit)
  if not npc then return end
  local mark = "u" .. npc
  if done[tip] == mark then return end
  done[tip] = mark
  watch(tip)
  local n = tip:NumLines()
  pcall(TT.Skinning, tip, unit)
  if tip:NumLines() > n then tip:Show() end
end
TT.OnItem, TT.OnUnit = onItem, onUnit

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
    if tip == GameTooltip or tip == ItemRefTooltip then onItem(tip, data) end
  end)
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip)
    if tip == GameTooltip then onUnit(tip) end
  end)
else
  for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tip and tip.HookScript then tip:HookScript("OnTooltipSetItem", function(t) onItem(t) end) end
  end
  if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipSetUnit", function(t) onUnit(t) end) end
end

-- Holding or letting go of the modifier refills a shown tooltip, where the game can
NW.On("MODIFIER_STATE_CHANGED", function()
  if not NW.db or (st().tipMode or "always") == "always" or st().tipOn == false then return end
  if GameTooltip:IsShown() and GameTooltip.RefreshData then
    done[GameTooltip] = nil
    pcall(GameTooltip.RefreshData, GameTooltip)
  end
end)
