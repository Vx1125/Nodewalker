local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Professions tab: a leveling plan for every profession, priced live
------------------------------------------------------------------------
local refresh
local page
page = UI.AddTab("profs", "Professions", function() refresh() end, nil, function()
  if page.dirty then page.dirty = false; refresh() end
end)
local selected

local function st() return NW.db.settings end

-- Item names arrive from the server a moment after we ask
local function itemName(id)
  local name = NW.ItemName(id)
  if not name then
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "item " .. id, false
  end
  return name, true
end
local function itemIcon(id)
  return NW.ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function recipeIcon(r)
  if r.item then return itemIcon(r.item) end
  local tex = r.spell and NW.SpellIcon(r.spell)
  return tex or "Interface\\Icons\\Trade_Engraving"
end
NW.On("GET_ITEM_INFO_RECEIVED", function() page.dirty = true end)

------------------------------------------------------------------------
-- Left: professions
------------------------------------------------------------------------
local LIST_W, PROF_H = 164, 30
local list = UI.Box(page, LIST_W, #NW.PROFS * PROF_H + 8)
list:SetPoint("TOPLEFT", 16, -8)
local profRows = {}
local mode, openMode, craftClick, knowsRecipe
local firstOpen = true -- the first look picks the view that fits your skill
for i, p in ipairs(NW.PROFS) do
  local b = CreateFrame("Button", nil, list)
  b:SetSize(LIST_W - 2, PROF_H)
  b:SetPoint("TOPLEFT", 1, -4 - (i - 1) * PROF_H)
  UI.RowHighlight(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(20, 20)
  b.icon:SetPoint("LEFT", 7, 0)
  b.icon:SetTexture(p.icon)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = UI.Text(b, 12, S.text)
  b.name:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
  b.name:SetPoint("RIGHT", -30, 0)
  b.name:SetWordWrap(false)
  b.name:SetText(p.name)
  b.skill = UI.Text(b, 11, S.dim, "RIGHT")
  b.skill:SetPoint("RIGHT", -6, 0)
  -- a profession whose recipes Nodewalker hasn't read yet says so here
  b:HookScript("OnEnter", function(self)
    if not self.unread then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(p.name, 1, 1, 1)
    GameTooltip:AddLine("Open it once so Nodewalker sees which recipes you know.", S.dim[1], S.dim[2], S.dim[3], true)
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", GameTooltip_Hide)
  b.prof = p
  b:SetScript("OnClick", function()
    if selected ~= p.key then mode = openMode(p.key) end
    selected = p.key; st().profSelected = p.key; refresh()
  end)
  profRows[i] = b
end
mode = "plan" -- plan | missing | profit
-- Opening a profession: there's nothing to level at 300, so show what pays
function openMode(key)
  local skill = NW.ProfSkill(key)
  return (skill and skill >= 300) and "profit" or "plan"
end
local modeBtns = {}
local listNote = UI.Text(page, 11, S.dim)
listNote:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -10)
listNote:SetWidth(LIST_W)
listNote:SetText("Open your profession window once so Nodewalker sees which recipes you know.")

------------------------------------------------------------------------
-- Middle: header, options, steps
------------------------------------------------------------------------
local MID_X, MID_W = 16 + LIST_W + 12, 508
local mid = CreateFrame("Frame", nil, page)
mid:SetPoint("TOPLEFT", MID_X, -8)
mid:SetSize(MID_W, 530)

local hIconBox = UI.Box(mid, 38, 38)
hIconBox:SetPoint("TOPLEFT")
local hIcon = hIconBox:CreateTexture(nil, "ARTWORK")
hIcon:SetPoint("TOPLEFT", 1, -1)
hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local hName = UI.Text(mid, 17, S.gold)
hName:SetPoint("TOPLEFT", hIconBox, "TOPRIGHT", 10, -1)
local hSkill = UI.Text(mid, 12, S.dim)
hSkill:SetPoint("TOPLEFT", hName, "BOTTOMLEFT", 0, -5)
hSkill:SetWidth(MID_W - 240)
hSkill:SetWordWrap(false)
local hCost = UI.Text(mid, 15, S.text, "RIGHT")
hCost:SetPoint("TOPRIGHT", 0, -2)
local hCostSub = UI.Text(mid, 11, S.dim, "RIGHT")
hCostSub:SetPoint("TOPRIGHT", hCost, "BOTTOMRIGHT", 0, -4)
-- Leveling cost as a small ledger: labels down the left, amounts down the right
local LEDGER_W = 176
local ledger = {}
for i = 1, 5 do
  local l, v = UI.Text(mid, 11, S.dim), UI.Text(mid, 11, S.text, "RIGHT")
  ledger[i] = { label = l, val = v }
end
-- rows: { label, amount, big, bright }; a row with no amount is a note across the whole width
local function setLedger(rows)
  local y = -1
  for i, row in ipairs(ledger) do
    local r = rows and rows[i]
    row.label:SetShown(r ~= nil)
    row.val:SetShown(r ~= nil)
    if r then
      local size = r[3] and 14 or 11
      row.label:SetFont(UI.FONT, r[2] and (r[3] and 12 or 11) or 10, "")
      row.val:SetFont(UI.FONT, size, "")
      row.label:ClearAllPoints()
      row.val:ClearAllPoints()
      if r[2] then
        row.label:SetJustifyH("LEFT")
        row.label:SetPoint("TOPLEFT", mid, "TOPRIGHT", -LEDGER_W, y - (r[3] and 2 or 0))
      else
        row.label:SetJustifyH("RIGHT")
        row.label:SetPoint("TOPRIGHT", mid, "TOPRIGHT", 0, y - 2)
      end
      row.val:SetPoint("TOPRIGHT", mid, "TOPRIGHT", 0, y)
      row.label:SetText(r[1])
      row.label:SetTextColor(unpack(r[4] and S.text or S.dim))
      row.val:SetText(r[2] or "")
      row.val:SetTextColor(unpack((r[3] or r[4]) and S.text or S.dim))
      y = y - (r[3] and 19 or 14)
    end
  end
end

-- The three views of a crafting profession, as tabs right under its name
local viewRow = CreateFrame("Frame", nil, mid)
viewRow:SetPoint("TOPLEFT", hIconBox, "BOTTOMLEFT", 0, -10)
viewRow:SetSize(MID_W, 26)
do
  local VIEWS = {
    { "plan", "Leveling", "Cheapest way to level, with a shopping list." },
    { "missing", "Missing recipes", "Recipes you don't know yet and where each comes from." },
    { "profit", "Profit", "What each craft earns at today's prices." },
  }
  local WIDTHS, x = { 84, 124, 76 }, 0
  for i, v in ipairs(VIEWS) do
    local b = CreateFrame("Button", nil, viewRow, "BackdropTemplate")
    b:SetSize(WIDTHS[i], 26)
    b:SetPoint("LEFT", x, 0)
    x = x + WIDTHS[i] + 4
    UI.Flat(b, S.cell, S.edge)
    b.label = UI.Text(b, 12, S.text, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(v[2])
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetPoint("BOTTOMLEFT", 1, 1)
    b.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    b.bar:SetHeight(2)
    b.bar:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 1)
    -- the open view is lit, not greyed out
    function b:SetSelected(on)
      self.on = on
      self.bar:SetShown(on)
      self.label:SetTextColor(unpack(on and S.gold or S.dim))
      self:SetBackdropColor(unpack(on and S.hover or S.cell))
      self:SetBackdropBorderColor(unpack(S.edge))
    end
    b:SetScript("OnEnter", function(self)
      if not self.on then self.label:SetTextColor(unpack(S.text)) end
    end)
    b:SetScript("OnLeave", function(self) self:SetSelected(self.on) end)
    b:SetScript("OnClick", function() mode = v[1]; refresh() end)
    modeBtns[v[1]] = b
  end
end

local optRow = CreateFrame("Frame", nil, mid)
optRow:SetPoint("TOPLEFT", viewRow, "BOTTOMLEFT", 0, -8)
optRow:SetSize(MID_W, 20)
local opts = {
  UI.Check(optRow, "Allow recipes I must buy", function() return st().planRecipeItems end,
    function(v) st().planRecipeItems = v; NW.InvalidatePlans() end,
    "Also plans with vendor and drop recipes, and adds them to the shopping list."),
  UI.Check(optRow, "From skill 1", function() return st().planFromStart end,
    function(v) st().planFromStart = v; refresh() end, "Plans every step from 1, not from your skill."),
  UI.Dropdown(optRow, 156, "", { { false, "Keep what I make" }, { true, "Sell what I make" }, { "de", "Disenchant it" } },
    function() return st().planSellBack or false end,
    function(v) st().planSellBack = v; NW.InvalidatePlans(); refresh() end, 156,
    "Sell and Disenchant plan for the lowest cost after what comes back. Sell counts half the auction price."),
}
opts[1]:SetPoint("LEFT", 2, 0)
opts[2]:SetPoint("LEFT", 206, 0)
opts[3]:SetPoint("RIGHT", 0, 0)

local priceLine = UI.Text(mid, 11, S.dim)
priceLine:SetPoint("TOPLEFT", optRow, "BOTTOMLEFT", 0, -6)
priceLine:SetWidth(MID_W)
priceLine:SetHeight(26)
priceLine:SetJustifyV("TOP")

-- Profit: how to order it, a floor on what's worth it, and less-used filters
local profitCtl = CreateFrame("Frame", nil, mid)
profitCtl:SetPoint("TOPLEFT", optRow, "TOPLEFT", 0, 0)
profitCtl:SetSize(MID_W, 24)
profitCtl:Hide()
local sortDrop = UI.Dropdown(profitCtl, 168, "Sort", {
  { "profit", "Profit each" }, { "roi", "Return" }, { "total", "Total I can make" },
  { "cheap", "Cheapest materials" }, { "count", "Most I can make" },
}, function() return st().profitSort or "profit" end, function(v)
  st().profitSort = v
  refresh()
end, 128)
sortDrop:SetPoint("LEFT", 0, 0)
local minProfit = UI.Dropdown(profitCtl, 132, "At least", {
  { 0, "Any" }, { 1000, NW.Money(1000, true) }, { 5000, NW.Money(5000, true) }, { 10000, NW.Money(10000, true) }, { 50000, NW.Money(50000, true) },
}, function() return st().profitMin or 1000 end, function(v)
  st().profitMin = v
  refresh()
end, 66, "Profit each, after the auction cut.")
minProfit:SetPoint("LEFT", sortDrop, "RIGHT", 18, 0)
local profitFilters = UI.CheckMenu(profitCtl, "Filters", 100, {
  { "Have materials", function() return st().profitHaveMats end, function(v) st().profitHaveMats = v end,
    "Only recipes your bags can make now." },
  { "Complete prices only", function() return st().profitComplete end, function(v) st().profitComplete = v or nil end,
    "Leave out recipes with a material or result that has no auction price." },
  { "10% return or more", function() return st().profitMinRoi end, function(v) st().profitMinRoi = v or nil end },
  { "Recent prices only", function() return st().profitFresh end, function(v) st().profitFresh = v or nil end,
    "Leave out results Auctionator last saw 3 or more days ago." },
}, function() refresh() end)
profitFilters:SetPoint("RIGHT", 0, 0)

-- Search: filters the list below (recipes, materials, zones)
local search = CreateFrame("EditBox", nil, mid, "BackdropTemplate")
search:SetSize(176, 24)
search:SetPoint("RIGHT", viewRow, "RIGHT", 0, 0)
UI.Flat(search, S.sunk, S.edge)
search:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
search:SetTextColor(unpack(S.text))
search:SetTextInsets(24, 22, 0, 0)
search:SetAutoFocus(false)
search:SetMaxLetters(40)
local searchIcon = search:CreateTexture(nil, "ARTWORK")
searchIcon:SetSize(14, 14)
searchIcon:SetPoint("LEFT", 6, 0)
searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
searchIcon:SetVertexColor(unpack(S.dim))
local searchHint = UI.Text(search, 12, S.disabled)
searchHint:SetPoint("LEFT", 24, 0)
searchHint:SetText("Search")
local searchClear = UI.Close(search, function() search:SetText(""); search:ClearFocus() end)
searchClear:SetSize(18, 18)
searchClear:SetPoint("RIGHT", -2, 0)
searchClear:Hide()
local searchText = ""
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(S.gold)) end)
search:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(S.edge)) end)
search:SetScript("OnTextChanged", function(self)
  local t = (self:GetText() or ""):lower()
  searchHint:SetShown(t == "")
  searchClear:SetShown(t ~= "")
  if t ~= searchText then searchText = t; refresh() end
end)

-- A Craft button was clicked: make them, or say what's missing
-- You know it, as far as the last look at the profession window said
function knowsRecipe(key, r)
  local k = r and NW.charDB.known[key]
  return k and k[r.name] and NW.ProfSkill(key) ~= nil or false
end
function craftClick(b)
  if not b.r then return end
  if NW.CanCraft(b.key, b.r) == nil then
    local prof = NW.PROF_BY_KEY[b.key]
    NW.CraftStatus(("Open %s once, then craft from here"):format(prof and prof.name or "the profession"))
    return
  end
  if (b.n or 0) < 1 then
    local id, short = NW.CraftMissing(b.r)
    NW.CraftStatus(id and ("Need %d more %s in your bags"):format(short, (itemName(id))) or "Nothing to make it with")
    return
  end
  local _, msg = NW.Craft(b.key, b.r, b.n)
  NW.CraftStatus(msg)
end

-- New listings came in from a search: reprice the shopping list (not on every page)
local livePending
function NW.OnLiveListings()
  if livePending then return end
  livePending = true
  C_Timer.After(0.6, function()
    livePending = nil
    if page:IsShown() then refresh() end
  end)
end

-- What the last Craft click did, shown on the hint line for a few seconds
local craftMsg, craftMsgAt
function NW.CraftStatus(msg)
  craftMsg, craftMsgAt = msg, GetTime()
  if page:IsShown() then refresh() end
  C_Timer.After(4.1, function() if page:IsShown() then refresh() end end)
end
local STEP_H, STEP_ROWS = 40, 10
local STEPS_BOX_H = STEP_H * STEP_ROWS + 2
local stepsBox = UI.Box(mid, MID_W, STEPS_BOX_H)
stepsBox:SetPoint("TOPLEFT", optRow, "BOTTOMLEFT", 0, -32)
-- What each column is, per view
local caps = {}
for i, c in ipairs({ { "BOTTOMLEFT", "TOPLEFT", 9 }, { "BOTTOMLEFT", "TOPLEFT", 73 }, { "BOTTOMRIGHT", "TOPRIGHT", -107 }, { "BOTTOMRIGHT", "TOPRIGHT", -19 } }) do
  local t = UI.Text(mid, 10, S.dim, i > 2 and "RIGHT" or "LEFT")
  t:SetPoint(c[1], stepsBox, c[2], c[3], 3)
  caps[i] = t
end
local CAPS = {
  plan = { "Skill", "Craft this", "How many", "Cost" },
  missing = { "Skill", "Recipe and where it comes from", "", "" },
  profit = { "Return", "Recipe", "", "Profit each" },
  gather = { "Skill", "Gather", "", "" },
}
stepsBox:EnableMouseWheel(true)
local stepRows = {}
local stepOffset = 0
local steps = {}

local function colorFor(r, sk)
  if sk < r.yellow then return "ff8040" elseif sk < r.green then return "ffff00"
  elseif sk < r.grey then return "40bf40" else return "808080" end
end

for i = 1, STEP_ROWS do
  local row = CreateFrame("Button", nil, stepsBox)
  row:SetSize(MID_W - 12, STEP_H - 2)
  row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * STEP_H)
  UI.RowHighlight(row)
  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.025 or 0)
  row.range = UI.Text(row, 12, S.gold)
  row.range:SetPoint("TOPLEFT", 8, -5)
  row.range:SetWidth(62)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("TOPLEFT", 70, -2)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, 12, S.text)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(270)
  row.name:SetWordWrap(false)
  row.crafts = UI.Text(row, 12, S.text, "RIGHT")
  row.crafts:SetPoint("TOPRIGHT", -96, -5)
  row.cost = UI.Text(row, 12, S.text, "RIGHT")
  row.cost:SetPoint("TOPRIGHT", -8, -5)
  row.mats = UI.Text(row, 11, S.dim)
  row.mats:SetPoint("TOPLEFT", 96, -24)
  row.mats:SetWidth(MID_W - 116)
  row.mats:SetWordWrap(false)
  -- Craft what this row makes, as many as your bags allow
  row.craft = UI.Button(row, "", 64, function(self) craftClick(self) end, 17)
  row.craft.label:SetFont(UI.FONT, 11, "")
  row.craft:SetPoint("BOTTOMRIGHT", -6, 3)
  row.craft:Hide()
  row.craft:HookScript("OnEnter", function(self)
    if not self.why then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(self.why, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  row.craft:HookScript("OnLeave", GameTooltip_Hide)
  function row:SetCraft(key, r, want)
    local can = r and NW.CanCraft(key, r)
    local n = can and math.min(can, want or can) or 0
    local b = self.craft
    -- any recipe you know gets the button; it's dim until your bags can make one
    b:SetShown(can ~= nil or knowsRecipe(key, r))
    self.mats:SetWidth(MID_W - 116 - (b:IsShown() and 70 or 0))
    b.key, b.r, b.n = key, r, n
    b:SetText(n > 1 and ("Craft " .. n) or "Craft")
    b:SetAlpha(n > 0 and 1 or 0.45)
    -- why it can't, for the tooltip
    b.why = nil
    if b:IsShown() and n < 1 then
      if can == nil then
        local prof = NW.PROF_BY_KEY[key]
        b.why = ("Open %s once to craft from here."):format(prof and prof.name or "the profession")
      else
        local id, short = NW.CraftMissing(r)
        b.why = id and ("Need %d more %s."):format(short, (itemName(id))) or "Missing materials."
      end
    end
  end
  row:SetScript("OnEnter", function(self)
    local stp = self.step
    if stp and stp.banner then
      -- a Train row: who, where, and what to bring
      local ru = stp.rankUp
      local who, where, mapID, _, _, needs, note = NW.RankWhere(selected, ru.name)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Train " .. ru.name, 0.91, 0.77, 0.42)
      GameTooltip:AddLine(who and (who .. ", " .. where) or "Any trainer in a capital city", 1, 1, 1, true)
      GameTooltip:AddDoubleLine("Needs", ("skill %d, level %d"):format(ru.skill, ru.level), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
      if stp.rankFee and stp.rankFee > 0 then GameTooltip:AddDoubleLine("Cost", NW.Money(stp.rankFee), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
      if needs then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Bring", 0.91, 0.77, 0.42)
        for _, it in ipairs(needs) do
          local have = math.min(NW.ItemCount(it[1]) or 0, it[2])
          local c = have >= it[2] and "94ba78" or "ffffff"
          GameTooltip:AddDoubleLine((itemName(it[1])), ("|cff%s%d/%d|r"):format(c, have, it[2]), 1, 1, 1)
        end
      end
      if note then GameTooltip:AddLine(note, 1, 1, 1, true) end
      if mapID then GameTooltip:AddLine("Click: pin on your map", S.dim[1], S.dim[2], S.dim[3]) end
      GameTooltip:Show()
      return
    end
    if not (stp and stp.recipe) then return end
    local r = stp.recipe
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if r.item then GameTooltip:SetItemByID(r.item) elseif r.spell then GameTooltip:SetSpellByID(r.spell) else GameTooltip:SetText(r.name) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Skill-up colours", ("|cffff8040%s|r |cffffff00%d|r |cff40bf40%d|r |cff808080%d|r"):format(
      r.orange or "-", r.yellow, r.green, r.grey), S.dim[1], S.dim[2], S.dim[3])
    GameTooltip:AddDoubleLine("Cost per craft", NW.Money(stp.recipe and stp.recipe.matCost or stp.costEach), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    local de = stp.recipe and stp.recipe.item and NW.DisenchantValue(stp.recipe.item)
    if de then GameTooltip:AddDoubleLine("Disenchants for about", NW.Money(de), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    GameTooltip:AddDoubleLine("Crafts", stp.spare and stp.spare > 0 and ("%d (%d spare)"):format(stp.crafts, stp.spare) or stp.crafts, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    if stp.fee then GameTooltip:AddDoubleLine("Trainer: recipe", NW.Money(stp.fee), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    if stp.rankFee and stp.rankFee > 0 then GameTooltip:AddDoubleLine("Trainer: " .. stp.rankUp.name, NW.Money(stp.rankFee), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    local src = r.src == "trainer" and "Trainer" or r.src == "rank" and "Learned with the profession"
      or "Recipe from a vendor or drop"
    GameTooltip:AddDoubleLine("Source", src, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    if stp.needsRecipe then
      GameTooltip:AddLine("You need this recipe first.", 1, 0.5, 0.25, true)
      if not st().planRecipeItems then GameTooltip:AddLine("No trainer recipe gives skill-ups here.", S.dim[1], S.dim[2], S.dim[3], true) end
    end
    if stp.rankUp then
      local who, where = NW.RankWhere(selected, stp.rankUp.name)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(("Train %s first (level %d)"):format(stp.rankUp.name, stp.rankUp.level), 0.91, 0.77, 0.42)
      GameTooltip:AddLine(who and (who .. ", " .. where) or "Any trainer", 1, 1, 1, true)
    end
    if (r.yield or 1) > 1 then GameTooltip:AddDoubleLine("Makes", r.yield .. " per craft", S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  stepRows[i] = row
end
local stepsEmpty = UI.Text(stepsBox, 12, S.dim, "CENTER")
stepsEmpty:SetPoint("CENTER")
stepsEmpty:SetWidth(MID_W - 40)
-- A scroll bar you can grab and drag, or click above/below to jump
local function makeScroller(box, boxH, visible, getCount, getOffset, setOffset)
  local track = CreateFrame("Frame", nil, box)
  track:SetPoint("TOPRIGHT", -2, -2)
  track:SetPoint("BOTTOMRIGHT", -2, 2)
  track:SetWidth(8)
  track:EnableMouse(true)
  local bg = track:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(S.edge[1], S.edge[2], S.edge[3], 0.35)
  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetWidth(8)
  thumb:EnableMouse(true)
  local tex = thumb:CreateTexture(nil, "OVERLAY")
  tex:SetPoint("TOPLEFT", 1, 0)
  tex:SetPoint("BOTTOMRIGHT", -1, 0)
  tex:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.55)
  thumb:SetScript("OnEnter", function() tex:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.9) end)
  thumb:SetScript("OnLeave", function() if not thumb.dragging then tex:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.55) end end)
  local sc = {}
  local trackH = boxH - 4
  local function thumbH() return math.max(24, trackH * visible / math.max(visible, getCount())) end
  local function cursorY()
    local _, y = GetCursorPosition()
    return y / track:GetEffectiveScale()
  end
  local function setFromCursor(grabOffset)
    local maxOff = getCount() - visible
    if maxOff <= 0 then return end
    local top = track:GetTop()
    local th = thumbH()
    local pos = (top - cursorY()) - (grabOffset or th / 2)
    local frac = math.max(0, math.min(1, pos / (trackH - th)))
    local off = math.floor(frac * maxOff + 0.5)
    if off ~= getOffset() then setOffset(off) end
  end
  thumb:SetScript("OnMouseDown", function(self)
    self.dragging = true
    self.grab = self:GetTop() - cursorY()
    self:SetScript("OnUpdate", function() setFromCursor(self.grab) end)
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self.dragging = false
    self:SetScript("OnUpdate", nil)
    tex:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], self:IsMouseOver() and 0.9 or 0.55)
  end)
  track:SetScript("OnMouseDown", function() setFromCursor() end)
  function sc:SetVisible(h, n) trackH, visible = h - 4, n end
  function sc:Update()
    local n = getCount()
    if n <= visible then track:Hide() return end
    track:Show()
    local th = thumbH()
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, -((trackH - th) * getOffset() / (n - visible)))
  end
  return sc
end

local drawSteps
local scrollDraw
local function redrawSteps() if scrollDraw then scrollDraw() else drawSteps() end end
local stepScroll = makeScroller(stepsBox, STEPS_BOX_H, STEP_ROWS, function() return #steps end,
  function() return stepOffset end, function(v) stepOffset = v; redrawSteps() end)
stepsBox:SetScript("OnMouseWheel", function(_, d)
  stepOffset = math.max(0, math.min(math.max(0, #steps - STEP_ROWS), stepOffset - d))
  redrawSteps()
end)

------------------------------------------------------------------------
-- Right: shopping list (crafting) or extra info (gathering)
------------------------------------------------------------------------
local RIGHT_X = MID_X + MID_W + 12
local RIGHT_W = 1020 - RIGHT_X - 16
local right = CreateFrame("Frame", nil, page)
right:SetPoint("TOPLEFT", RIGHT_X, -8)
right:SetSize(RIGHT_W, 530)
local rHead = UI.Heading(right, "Shopping list", RIGHT_W)
rHead:SetPoint("TOPLEFT")
local rTotal = UI.Text(right, 12, S.text)
rTotal:SetPoint("TOPLEFT", rHead, "BOTTOMLEFT", 0, -6)
rTotal:SetWidth(RIGHT_W)
-- How far to level: the plan and the list stop there
local function targetFor(key)
  local t = st().planTarget
  return t and t[key] or 300
end
local targetSlider = UI.Slider(right, RIGHT_W, "Level to", 25, 300, 5, function(v) return ("%d"):format(v) end,
  function() return targetFor(selected) end,
  function(v)
    local s = st()
    s.planTarget = s.planTarget or {}
    s.planTarget[selected] = v < 300 and v or nil
    refresh()
  end)
targetSlider:SetPoint("TOPLEFT", rTotal, "BOTTOMLEFT", 0, -10)
local KEY = "|cffff8040Orange|r recipes always skill up, |cffffff00yellow|r often, |cff40bf40green|r rarely.\n"
  .. "|cffe0dbd06/78|r have / need  ·  |cffe0dbd0v|r vendor  ·  |cffd17665~|r guessed, no auction price  ·  |cffffd133!|r odd price or few listed (hover)\n"
  .. "Shift-click anything to search the auction house.\n\n"
local shopBox = UI.Box(right, RIGHT_W, 240)
shopBox:SetPoint("TOPLEFT", targetSlider, "BOTTOMLEFT", 0, -10)
shopBox:EnableMouseWheel(true)
local SHOP_H, SHOP_ROWS = 26, 9
local shopVisible = SHOP_ROWS -- the opened recipe shows only as many rows as it has materials
local RECIPE_PREFIX, sourceText -- set further down
-- Shift-click: put an item (or a recipe's spell) into chat. With no chat box
-- open, `open` starts one. Returns true when the link went somewhere.
local function chatLink(itemID, spellID, open)
  local link
  if itemID then
    link = select(2, NW.ItemInfo(itemID))
  elseif spellID then
    link = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)) or (GetSpellLink and GetSpellLink(spellID))
  end
  if not link then return false end
  local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
  if active then
    if ChatFrameUtil and ChatFrameUtil.InsertLink then return ChatFrameUtil.InsertLink(link) and true or false end
    return ChatEdit_InsertLink and ChatEdit_InsertLink(link) and true or false
  end
  if open then
    if ChatFrameUtil and ChatFrameUtil.OpenChat then ChatFrameUtil.OpenChat(link) return true end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link) return true end
  end
  return false
end
local function ahOpen()
  return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown()) or false
end

-- Search Auctionator for { { name, quantity }, ... }; the quantity is what
-- you still need, so its buy box starts on that number.
local function searchAH(items)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local open = (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
  if not (api and open and #items > 0) then return false end
  if api.MultiSearchAdvanced then
    local terms = {}
    for i, it in ipairs(items) do terms[i] = { searchString = it[1], isExact = true, quantity = it[2] } end
    if pcall(api.MultiSearchAdvanced, ADDON, terms) then return true end
  end
  local fn = api.MultiSearchExact or api.MultiSearch
  if not fn then return false end
  local names = {}
  for i, it in ipairs(items) do names[i] = it[1] end
  return (pcall(fn, ADDON, names))
end
local shopRows, shop, shopOffset = {}, {}, 0
-- Profit view: the recipe opened on the right, and the ones you came through
local card -- { r = recipe, key = profession, stack = { earlier cards } }
local lastCardKey
for i = 1, SHOP_ROWS do
  local row = CreateFrame("Button", nil, shopBox)
  row:SetSize(RIGHT_W - 8, SHOP_H)
  row:SetPoint("TOPLEFT", 1, -2 - (i - 1) * SHOP_H)
  UI.RowStripe(row)
  row:SetStripe(i % 2 == 0)
  UI.RowHighlight(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 6, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, 11, S.text)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(RIGHT_W - 120)
  row.name:SetWordWrap(false)
  row.cost = UI.Text(row, 11, S.text, "RIGHT")
  row.cost:SetPoint("RIGHT", -6, 0)
  row:SetScript("OnEnter", function(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if e.recipe then
      GameTooltip:SetText(e.term, 1, 0.5, 0.25)
      GameTooltip:AddLine((sourceText(e.key, e.recipe)), 1, 1, 1, true)
      if not st().planRecipeItems then GameTooltip:AddLine("Needed: no trainer recipe gives skill-ups at that point.", S.dim[1], S.dim[2], S.dim[3], true) end
      if e.price then GameTooltip:AddDoubleLine(e.src == "vendor" and "Vendor" or "Auction house", NW.Money(e.price), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
      GameTooltip:Show()
      return
    end
    GameTooltip:SetItemByID(e.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Need", e.need, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    if e.quest then GameTooltip:AddDoubleLine("For", e.quest .. " quest", S.dim[1], S.dim[2], S.dim[3], 0.91, 0.77, 0.42) end
    if e.buy > 0 and e.src ~= "vendor" then GameTooltip:AddDoubleLine("Click or Shift-click", ("search for %d"):format(e.buy), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    if e.have > 0 then GameTooltip:AddDoubleLine("In your bags and bank", e.have, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    local srcText = ({ ah = "Auction house (Auctionator)", vendor = "Vendor", craft = "Cheaper to make", est = "Estimate (no price yet)" })[e.src or ""] or "No price"
    GameTooltip:AddDoubleLine("Price each", NW.Money(e.price), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("From", srcText, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    -- every price there is for it, so you can see why that one was used
    local vendor, ah, craft = NW.PriceParts(e.id)
    -- only worth listing when there is more than one price to compare
    if (vendor and 1 or 0) + (ah and 1 or 0) + (craft and 1 or 0) > 1 then
      GameTooltip:AddLine(" ")
      if ah then GameTooltip:AddDoubleLine("Auction", NW.Money(ah), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
      if vendor then GameTooltip:AddDoubleLine("Vendor", NW.Money(vendor), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
      if craft then GameTooltip:AddDoubleLine("Make it", NW.Money(craft), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    end
    if e.need and e.need > 1 and e.price then
      GameTooltip:AddDoubleLine(("x%d"):format(e.need), NW.Money(e.price * e.need), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    end
    if card and e.maker then GameTooltip:AddLine("Click: how to make it", 0.91, 0.77, 0.42) end
    -- what the listings you just searched add up to
    if e.live then
      local lv = e.live
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine(("Listed now: %d for"):format(lv.got), NW.Money(lv.cost), 0.55, 0.86, 0.48, 1, 1, 1)
      if lv.got > 0 then GameTooltip:AddDoubleLine("Average each", NW.Money(lv.cost / lv.got), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
      if lv.got < e.buy then
        GameTooltip:AddLine(lv.complete and ("Only %d listed. You need %d."):format(lv.got, e.buy)
          or ("The search showed the cheapest %d. The other %d are counted at the usual price."):format(lv.got, e.buy - lv.got), 1, 0.82, 0.2, true)
      end
    end
    -- what the auction house has looked like lately
    local ps = e.src == "ah" and NW.PriceStats(e.id)
    if ps and ps.days > 1 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine("Usually", NW.Money(ps.typical), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
      GameTooltip:AddDoubleLine(("Last %d scan days"):format(ps.days), NW.Money(ps.low, true) .. " - " .. NW.Money(ps.high, true), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
      if ps.flag then
        GameTooltip:AddDoubleLine("Today", NW.Money(ps.today), S.dim[1], S.dim[2], S.dim[3], 1, 0.82, 0.2)
        GameTooltip:AddLine(ps.flag == "low" and "Today's listing is far below usual. Planned at the usual price."
          or "Today's listing is far above usual. Planned at the usual price.", 1, 0.82, 0.2, true)
      end
      if ps.listed then
        local r, g, b = 1, 1, 1
        if e.scarce then r, g, b = 1, 0.82, 0.2 end
        GameTooltip:AddDoubleLine("Usually listed", math.floor(ps.listed + 0.5), S.dim[1], S.dim[2], S.dim[3], r, g, b)
        if e.scarce then GameTooltip:AddLine(("You need %d. Expect to pay more for the rest."):format(e.buy), 1, 0.82, 0.2, true) end
      end
    end
    local age = e.src == "ah" and NW.PriceAge(e.id)
    if age then GameTooltip:AddDoubleLine("Last scanned", age == 0 and "today" or (age .. " days ago"), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self)
    local e = self.entry
    if not e then return end
    -- a material you can make: open its recipe
    if card and e.maker and not IsShiftKeyDown() then
      card.stack[#card.stack + 1] = { r = card.r, key = card.key }
      card.r, card.key = e.maker, e.makerKey
      refresh()
      return
    end
    -- Shift-click links it in chat; at the auction house it searches
    if IsShiftKeyDown() and e.id then
      if not ahOpen() and chatLink(e.id, nil, true) then return end
    end
    -- Shift-click searches even when you already have enough
    if e.buy <= 0 and not IsShiftKeyDown() then return end
    local qty = math.max(1, e.buy)
    if e.recipe then
      searchAH({ { e.term, 1 } })
    else
      local n, ok = itemName(e.id)
      if ok then searchAH({ { n, qty } }) end
    end
  end)
  shopRows[i] = row
end
local drawShop
local shopScroll = makeScroller(shopBox, 240, SHOP_ROWS, function() return #shop end,
  function() return shopOffset end, function(v) shopOffset = v; drawShop() end)
shopBox:SetScript("OnMouseWheel", function(_, d)
  shopOffset = math.max(0, math.min(math.max(0, #shop - shopVisible), shopOffset - d))
  drawShop()
end)
local searchBtn = UI.Button(right, "Search all in Auctionator", RIGHT_W, function()
  local items = {}
  for _, e in ipairs(shop) do
    if e.recipe then
      if e.buy > 0 then items[#items + 1] = { e.term, 1 } end
    elseif e.buy > 0 and e.src ~= "vendor" then
      local n, ok = itemName(e.id)
      if ok then items[#items + 1] = { n, e.buy } end
    end
  end
  if not searchAH(items) then NW.Print("Open the auction house with Auctionator to search for the list.") end
end, 26, "primary")
searchBtn:SetPoint("TOPLEFT", shopBox, "BOTTOMLEFT", 0, -8)
local tips = UI.Text(right, 11, S.dim)
tips:SetPoint("TOPLEFT", searchBtn, "BOTTOMLEFT", 0, -10)
tips:SetWidth(RIGHT_W)
tips:SetSpacing(2)
tips:SetJustifyV("TOP")

-- extra info panel for gathering professions (shares the right column)
local info = CreateFrame("Frame", nil, right)
info:SetPoint("TOPLEFT", rHead, "BOTTOMLEFT", 0, -6)
info:SetSize(RIGHT_W, 480)
local infoText = UI.Text(info, 12, S.text)
infoText:SetPoint("TOPLEFT")
infoText:SetWidth(RIGHT_W)
infoText:SetJustifyV("TOP")
infoText:SetSpacing(3)

------------------------------------------------------------------------
-- The opened recipe (Profit and Missing recipes): header, money, materials, actions
------------------------------------------------------------------------
local CW = {} -- the opened recipe's widgets (one table: the file is near Lua's local limit)
local cardFrame = CreateFrame("Frame", nil, right)
cardFrame:SetPoint("TOPLEFT")
cardFrame:SetSize(RIGHT_W, 200)
cardFrame:Hide()
CW.cIconBox = UI.Box(cardFrame, 38, 38)
CW.cIconBox:SetPoint("TOPLEFT")
CW.cIcon = CW.cIconBox:CreateTexture(nil, "ARTWORK")
CW.cIcon:SetPoint("TOPLEFT", 1, -1)
CW.cIcon:SetPoint("BOTTOMRIGHT", -1, 1)
CW.cIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
CW.cName = UI.Text(cardFrame, 13, S.text)
CW.cName:SetPoint("TOPLEFT", CW.cIconBox, "TOPRIGHT", 8, -2)
CW.cName:SetPoint("RIGHT", -24, 0)
CW.cName:SetWordWrap(false)
CW.cProf = UI.Text(cardFrame, 11, S.dim)
CW.cProf:SetPoint("TOPLEFT", CW.cName, "BOTTOMLEFT", 0, -4)
CW.cProf:SetPoint("RIGHT", -4, 0)
CW.cProf:SetWordWrap(false)
CW.cClose = UI.Close(cardFrame, function() card = nil refresh() end)
CW.cClose:SetPoint("TOPRIGHT", 2, 2)
CW.cSource = UI.Text(cardFrame, 11, S.dim)
CW.cSource:SetPoint("TOPLEFT", CW.cIconBox, "BOTTOMLEFT", 0, -6)
CW.cSource:SetWidth(RIGHT_W)
CW.cSource:SetJustifyV("TOP")
if CW.cSource.SetMaxLines then CW.cSource:SetMaxLines(2) end

-- Money in a 2x2 grid: what it's worth, what goes in, what's left, what to buy
CW.CELL_W, CW.CELL_H = math.floor((RIGHT_W - 4) / 2), 36
CW.cells = {}
CW.grid = CreateFrame("Frame", nil, cardFrame)
CW.grid:SetSize(RIGHT_W, CW.CELL_H * 2 + 4)
CW.grid:SetPoint("TOPLEFT", CW.cSource, "BOTTOMLEFT", 0, -8)
for i = 1, 4 do
  local c = CreateFrame("Frame", nil, CW.grid)
  c:SetSize(CW.CELL_W, CW.CELL_H)
  c:SetPoint("TOPLEFT", ((i - 1) % 2) * (CW.CELL_W + 4), -math.floor((i - 1) / 2) * (CW.CELL_H + 4))
  local bg = c:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(S.sunk))
  c.label = UI.Text(c, 10, S.dim)
  c.label:SetPoint("TOPLEFT", 7, -5)
  c.value = UI.Text(c, 13, S.text)
  c.value:SetPoint("BOTTOMLEFT", 7, 5)
  c.value:SetPoint("RIGHT", -6, 0)
  c.value:SetWordWrap(false)
  c:EnableMouse(true)
  c:SetScript("OnEnter", function(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(self.label:GetText(), 1, 1, 1)
    GameTooltip:AddLine(self.tip, S.dim[1], S.dim[2], S.dim[3], true)
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", GameTooltip_Hide)
  CW.cells[i] = c
end
CW.cAge = UI.Text(cardFrame, 10, S.dim)
CW.cAge:SetPoint("TOPLEFT", CW.grid, "BOTTOMLEFT", 0, -5)
CW.cAge:SetWidth(RIGHT_W)
CW.cAge:SetWordWrap(false)
CW.cMatsHead = UI.Text(cardFrame, 12, S.gold)
CW.cMatsHead:SetPoint("TOPLEFT", CW.cAge, "BOTTOMLEFT", 0, -10)
CW.cMatsHead:SetText("Materials")
CW.cMatsCount = UI.Text(cardFrame, 11, S.dim, "RIGHT")
CW.cMatsCount:SetPoint("BOTTOMRIGHT", CW.cMatsHead, "BOTTOMLEFT", RIGHT_W, 0)

-- Actions under the materials
CW.HALF = math.floor((RIGHT_W - 6) / 2)
local cardCraft = UI.Button(right, "Craft", CW.HALF, function(self) craftClick(self) end, 24, "primary")
cardCraft:HookScript("OnEnter", function(self)
  if not self.why then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(self.why, 1, 1, 1, true)
  GameTooltip:Show()
end)
cardCraft:HookScript("OnLeave", GameTooltip_Hide)
function CW.cardSearch(what)
  if not card then return end
  local items = {}
  if what == "item" then
    local n, ok = itemName(card.r.item)
    if ok then items[1] = { n, 1 } end
  else
    for _, e in ipairs(shop) do
      local n, ok = itemName(e.id)
      local qty = what == "all" and e.need or e.buy
      if ok and qty > 0 and e.src ~= "vendor" then items[#items + 1] = { n, qty } end
    end
  end
  if not searchAH(items) then NW.Print("Open the auction house with Auctionator to search.") end
end
CW.cardMissing = UI.Button(right, "Search missing", CW.HALF, function() CW.cardSearch("missing") end, 24)
CW.cardAll = UI.Button(right, "Search all materials", CW.HALF, function() CW.cardSearch("all") end, 24)
CW.cardItem = UI.Button(right, "Search the item", CW.HALF, function() CW.cardSearch("item") end, 24)
local cardBack = UI.Button(right, "", RIGHT_W, function()
  if not card then return end
  local prev = table.remove(card.stack)
  if prev then card.r, card.key = prev.r, prev.key else card = nil end
  refresh()
end, 22)
CW.cardButtons = { cardCraft, CW.cardMissing, CW.cardAll, CW.cardItem, cardBack }
for _, b in ipairs(CW.cardButtons) do b:Hide() end

------------------------------------------------------------------------
-- Drawing: crafting
------------------------------------------------------------------------
local function matsText(r)
  local parts = {}
  for _, re in ipairs(r.reagents) do
    parts[#parts + 1] = re[2] .. " " .. (itemName(re[1]))
  end
  return table.concat(parts, ", ") .. " each"
end

-- The next rank you haven't trained: the rank, and whether you can train it now
local function nextRank(key)
  local rank, max = NW.ProfSkill(key)
  if not rank then return end
  for _, r in ipairs(NW.RANKS) do
    if max and max < r.cap and r.skill then return r, rank >= r.skill, max end
  end
end
-- "Expert Cookbook, sold by Wulan: Shadowprey Village, Desolace"
local function rankWhereText(key, rankName)
  local who, where = NW.RankWhere(key, rankName)
  if who then return who .. ": " .. where end
  return "Any trainer in a capital city"
end
local function rankNote(key)
  local r, now = nextRank(key)
  if not r then return "" end
  if now then return ("  ·  |cffd6b266Train %s now|r"):format(r.name) end
  return ("  ·  %s at %d"):format(r.name, r.skill)
end
-- One clear line: what to train next and where to go
local function rankLine(key)
  local r, now, max = nextRank(key)
  if not r then return end
  return ("|cffd6b266%s %s|r to pass %d: |cffffffff%s|r"):format(
    now and "Train" or "Next:", r.name, max, rankWhereText(key, r.name))
end


drawSteps = function()
  local rank = NW.ProfSkill(selected) or 0
  for i, row in ipairs(stepRows) do
    local stp = steps[i + stepOffset]
    row.step = stp
    row.bracket = nil
    row.missingRecipe = nil
    row.sectionRow = nil
    row.profitRow = nil
    row:SetCraft()
    if stp then
      row:Show()
      row:SetSelected(rank >= stp.from and rank < stp.to)
      row.range:SetText(("%d-%d"):format(stp.from, stp.to))
      if stp.banner then
        -- a stop at the trainer before the next steps
        local ru = stp.rankUp
        row:SetSelected(rank >= ru.skill and rank <= stp.from)
        row.range:SetText(tostring(stp.from))
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
        row.icon:Show()
        local who, where, mapID, _, _, needs = NW.RankWhere(selected, ru.name)
        row.name:SetText(("|cffd6b266Train %s|r%s"):format(ru.name, who and ("  |cffffffff" .. who .. "|r") or ""))
        row.crafts:SetText("")
        row.cost:SetText(stp.rankFee and stp.rankFee > 0 and NW.Money(stp.rankFee, true) or "")
        if needs then
          -- a quest: what to bring matters most
          local parts = {}
          for _, it in ipairs(needs) do parts[#parts + 1] = ("%d %s"):format(it[2], (itemName(it[1]))) end
          row.mats:SetText(("|cffffffff%s|r  ·  bring %s"):format(where, table.concat(parts, ", ")))
        else
          row.mats:SetText(("|cffffffff%s|r  ·  skill %d, level %d%s"):format(where or "Any trainer in a capital city", ru.skill, ru.level,
            mapID and "  ·  |cff94ba78click to pin|r" or ""))
        end
      elseif stp.recipe then
        local r = stp.recipe
        row.icon:SetTexture(recipeIcon(r))
        row.icon:Show()
        row.name:SetText(("|cff%s%s|r"):format(colorFor(r, stp.from), r.name))
        row.crafts:SetText("x" .. stp.crafts)
        row:SetCraft(selected, r, stp.crafts)
        row.cost:SetText(NW.Money(stp.spend or stp.cost, true) .. (stp.unknown > 0 and " |cffd17665?|r" or ""))
        local tag = stp.needsRecipe and "|cffff8040needs recipe|r  ·  " or ""
        if stp.rankUp and searchText ~= "" then
          tag = ("|cffd6b266Train %s first|r  ·  "):format(stp.rankUp.name) .. tag
        end
        row.mats:SetText(tag .. matsText(r))
      else
        row.icon:Hide()
        row.name:SetText("|cffd17665No recipe in the data covers this range|r")
        row.crafts:SetText("")
        row.cost:SetText("")
        row.mats:SetText("Tick \"Allow recipes I must buy\", or level with anything that is still yellow.")
      end
    else
      row:Hide()
    end
  end
  stepScroll:Update()
end

drawShop = function()
  shopScroll:Update()
  for i, row in ipairs(shopRows) do
    local e = i <= shopVisible and shop[i + shopOffset] or nil
    row.entry = e
    if e then
      row:Show()
    end
    if e and e.recipe then
      row.icon:SetTexture(e.id and itemIcon(e.id) or "Interface\\Icons\\INV_Scroll_03")
      row.name:SetText("|cffff8040" .. e.term .. "|r")
      row.cost:SetText((e.buy == 0 and "|cff94ba78have|r") or (e.cost and NW.Money(e.cost, "mid")) or "|cff938c80find|r")
    elseif e and card then
      -- have/need, the name (gold: you can make it), and what's still to buy
      row.icon:SetTexture(itemIcon(e.id))
      local ok = e.have >= e.need
      row.name:SetText(("%s%d|r|cff938c80/%d|r  %s%s|r"):format(ok and "|cff94ba78" or "|cffd17665", math.min(e.have, e.need), e.need,
        e.maker and "|cffd6b266" or "|cffe0dbd0", (itemName(e.id))))
      row.cost:SetText(ok and "|cff94ba78Have|r" or e.cost and NW.Money(e.cost, "mid") or "|cff938c80No price|r")
    elseif e then
      row.icon:SetTexture(itemIcon(e.id))
      local have = e.have > 0 and ("|cff94ba78%d|r/"):format(math.min(e.have, e.need)) or ""
      row.name:SetText(("%s%d  %s%s|r"):format(have, e.need, e.maker and card and "|cffd6b266" or "|cffe0dbd0", (itemName(e.id))))
      local tag = e.src == "vendor" and " |cff938c80v|r" or e.src == "est" and " |cffd17665~|r"
        or (e.scarce or (e.stats and e.stats.flag)) and " |cffffd133!|r" or ""
      row.cost:SetText((e.buy == 0 and "|cff94ba78have|r") or (NW.Money(e.cost, "mid") .. tag))
    else
      row:Hide()
    end
  end
end

-- The list keeps its scroll position unless you switch profession, view or search
local viewChanged, lastView = true, nil
local function clampOffsets()
  stepOffset = math.max(0, math.min(stepOffset, math.max(0, #steps - STEP_ROWS)))
  shopOffset = math.max(0, math.min(shopOffset, math.max(0, #shop - shopVisible)))
end

local function has(text)
  return text and text:lower():find(searchText, 1, true) ~= nil
end
local function filter(list, test)
  if searchText == "" then return list end
  local out = {}
  for _, e in ipairs(list) do if test(e) then out[#out + 1] = e end end
  return out
end
local function stepMatches(stp)
  if not stp.recipe then return false end
  if has(stp.recipe.name) then return true end
  for _, re in ipairs(stp.recipe.reagents) do if has((itemName(re[1]))) then return true end end
  return false
end

local function drawCraft(p)
  local rank = NW.ProfSkill(p.key)
  local from = (st().planFromStart or not rank) and 1 or math.max(1, rank)
  local to = targetFor(p.key)
  if from >= to then
    steps = {}
    stepsEmpty:SetText(("You've reached %d."):format(to))
    priceLine:SetText(to < 300 and "Raise \"Level to\" to plan further." or "Nothing left to level. Missing recipes and Profit are up top.")
    drawSteps()
    hCost:SetText("")
    hCostSub:SetText("")
    rTotal:SetText("")
    shop = {}
    drawShop()
    return
  end
  local plan = NW.BuildPlan(p.key, from, to)
  steps = filter(plan.steps, stepMatches)
  if searchText == "" then
    -- each new rank gets its own row: where to go before the next steps
    local list = {}
    for _, stp in ipairs(steps) do
      if stp.rankUp then
        list[#list + 1] = { banner = true, rankUp = stp.rankUp, rankFee = stp.rankFee, from = stp.from, to = stp.from }
      end
      list[#list + 1] = stp
    end
    steps = list
  end
  if viewChanged then
    stepOffset = 0
    -- start on the step you're on
    for i, stp in ipairs(steps) do
      if rank and rank >= stp.from and rank < stp.to then
        if i > 1 and steps[i - 1].banner then i = i - 1 end
        stepOffset = math.max(0, math.min(i - 1, #steps - STEP_ROWS))
      end
    end
  end
  clampOffsets()
  stepsEmpty:SetText(#steps == 0 and (searchText ~= "" and "Nothing in the plan matches your search." or "No recipes for this profession yet.") or "")
  drawSteps()

  -- the headline is what you pay; sale value is shown beside it, never taken off
  local spend = plan.spend or plan.total
  hCost:SetText("")
  hCostSub:SetText("")
  local rows = { { ("Spend to %d"):format(to), NW.Money(spend), true } }
  -- what selling or disenchanting might return, and what that leaves you out of pocket
  local back = spend - plan.total
  if back > 0 then
    rows[#rows + 1] = { st().planSellBack == "de" and "Disenchant back" or "Sell back", "~" .. NW.Money(back, true) }
    rows[#rows + 1] = { "Net", "~" .. NW.Money(spend - back, true), nil, true }
  -- three rows at most: that's the room beside the profession name
  elseif plan.fees and plan.fees > 0 then
    rows[#rows + 1] = { "incl. training", NW.Money(plan.fees, true) }
  end
  -- what bought or found recipes would save
  if not st().planRecipeItems then
    st().planRecipeItems = true
    local alt = NW.BuildPlan(p.key, from, to)
    st().planRecipeItems = false
    NW.BuildPlan(p.key, from, to) -- back to this profession's prices
    if back <= 0 and alt.total < plan.total * 0.85 then
      rows[#rows + 1] = { "|cff94ba78With bought recipes|r", "|cff94ba78" .. NW.Money(alt.spend or alt.total, true):gsub("|r", "|r|cff94ba78") .. "|r" }
    end
  end
  setLedger(rows)

  local list, total = NW.ShoppingList(p.key, plan)
  -- recipes the plan needs you to buy or find go on top
  local recipes, seen = {}, {}
  for _, stp in ipairs(plan.steps) do
    local r = stp.needsRecipe and stp.recipe
    if r and not seen[r.name] then
      seen[r.name] = true
      local term = (RECIPE_PREFIX[p.key] or "") .. r.name
      local e = { recipe = r, key = p.key, term = term, need = 1, have = 0, buy = 1 }
      -- the game only knows the recipe item once you've seen it
      local id = r.recipeItem
      if not id then
        local okID, found = pcall(function() return C_Item.GetItemInfoInstant(term) end)
        id = okID and found or nil
      end
      if id then
        local realName, okName = itemName(id)
        if okName then e.term = realName end
        e.id = id
        e.have = math.min(1, NW.ItemCount(id) or 0)
        e.buy = 1 - e.have
        local price, src = NW.Price(id)
        if price and (src == "ah" or src == "vendor") then e.price, e.cost, e.src = price, price * e.buy, src end
      end
      if e.cost then total = total + e.cost end
      recipes[#recipes + 1] = e
    end
  end
  for i, e in ipairs(recipes) do table.insert(list, i, e) end
  shop = list
  if viewChanged then shopOffset = 0 end
  clampOffsets()
  local odd = 0
  for _, e in ipairs(list) do if e.buy > 0 and (e.scarce or (e.stats and e.stats.flag)) then odd = odd + 1 end end
  local live = 0
  for _, e in ipairs(list) do if e.live then live = live + 1 end end
  rTotal:SetText(("%d items  ·  %s to buy%s%s%s"):format(#list, NW.Money(total),
    plan.unknown > 0 and ("  ·  |cffd17665%d no price|r"):format(plan.unknown) or "",
    live > 0 and ("  ·  |cff94ba78%d live|r"):format(live) or "",
    odd > 0 and ("  ·  |cffffd133%d to check|r"):format(odd) or ""))
  drawShop()

  local ah = NW.HasAuctionator()
  local nextUp = rankLine(p.key)
  priceLine:SetText(not ah and "|cffd17665Auctionator isn't loaded:|r using vendor prices and rough estimates. Install or enable it for live prices."
    or nextUp or "")
end

------------------------------------------------------------------------
-- Drawing: gathering
------------------------------------------------------------------------
local function bracketRows(key)
  local g = NW.GATHER_GUIDE[key]
  local out = {}
  for _, b in ipairs(g.brackets) do
    out[#out + 1] = { from = b[1], to = b[2], nodes = b[3], zones = b[4], note = b[5], fish = b[6], gather = true }
  end
  return out
end

-- reuse step rows for gathering brackets
local function drawGatherRows(key)
  local rank = NW.ProfSkill(key) or 0
  for i, row in ipairs(stepRows) do
    local b = steps[i + stepOffset]
    row.step = nil
    row:SetCraft()
    row.missingRecipe = nil
    row.sectionRow = nil
    row.profitRow = nil
    if b then
      row:Show()
      row:SetSelected(rank >= b.from and rank < b.to)
      row.range:SetText(("%d-%d"):format(b.from, b.to))
      row.icon:Hide()
      local what = b.nodes and table.concat(b.nodes, ", ") or b.note or ""
      if b.fish then
        local names = {}
        for _, id in ipairs(b.fish) do names[#names + 1] = (itemName(id)):gsub("^Raw ", "") end
        what = table.concat(names, ", ")
      end
      row.name:SetText(what)
      row.crafts:SetText("")
      row.cost:SetText("")
      local zones = {}
      for j = 1, math.min(4, #b.zones) do zones[j] = b.zones[j] end
      row.mats:SetText(table.concat(zones, ", ") .. (#b.zones > 4 and ", ..." or "") .. (b.fish and b.note and ("  ·  " .. b.note) or ""))
      row.bracket = b
    else
      row:Hide()
    end
  end
  stepScroll:Update()
end

-- Click a bracket: opens the Farm Guide on the best herb or ore for it
for _, row in ipairs(stepRows) do
  -- Shift-click a recipe: link what it makes in chat, and do nothing else
  row:SetScript("PreClick", function(self)
    self.linked = false
    if not IsShiftKeyDown() then return end
    local r = self.missingRecipe or (self.step and self.step.recipe)
    if not r then return end
    -- at the auction house it searches instead
    if ahOpen() then
      -- what it makes, not the recipe
      local n, ok
      if r.item then n, ok = itemName(r.item) end
      if ok and searchAH({ { n, 1 } }) then self.linked = true return end
    end
    self.linked = chatLink(r.item, r.spell, true)
  end)
  row:SetScript("OnClick", function(self)
    if self.linked then return end
    local b = self.bracket
    if not (b and b.gather and b.nodes) then return end
    if selected == "herbalism" then
      -- the highest herb you can pick in this bracket
      local skill = NW.ProfSkill("herbalism") or 0
      local pickName = b.nodes[1]
      for _, n in ipairs(b.nodes) do
        local req = NW.RequiredSkill(n)
        if req and req <= skill then pickName = n end
      end
      NW.GuideSelectHerb(pickName)
    elseif selected == "mining" then
      -- the highest ore you can mine in this bracket, if the guide covers it
      local skill = NW.ProfSkill("mining") or 0
      local pickName
      for _, n in ipairs(b.nodes) do
        local inGuide
        for _, e in ipairs(NW.ORE_GUIDE) do if e[1] == n then inGuide = true end end
        local req = NW.RequiredSkill(n)
        if inGuide and (not pickName or (req and req <= skill)) then pickName = n end
      end
      if pickName then NW.GuideSelectHerb(pickName) return end
      local rows = NW.RankZonesForNodes(b.nodes, b.zones)
      local best = rows[1]
      if not (best and best.mapID and best.count > 0) then
        NW.Print("No known ore spots in those zones yet. Import GatherMate2 or mine a few first.")
        return
      end
      local focus = {}
      for _, n in ipairs(b.nodes) do focus[n] = true end
      NW.BuildRoute(best.mapID, function(route)
      end, { focus = focus })
    end
  end)
end

local function drawGather(p)
  local g = NW.GATHER_GUIDE[p.key]
  steps = filter(bracketRows(p.key), function(b)
    if b.note and has(b.note) then return true end
    for _, n in ipairs(b.nodes or {}) do if has(n) then return true end end
    for _, z in ipairs(b.zones or {}) do if has(z) then return true end end
    for _, id in ipairs(b.fish or {}) do if has((itemName(id))) then return true end end
    return false
  end)
  if viewChanged then stepOffset = 0 end
  clampOffsets()
  stepsEmpty:SetText("")
  drawGatherRows(p.key)
  hCost:SetText("")
  hCostSub:SetText("")
  local rank = NW.ProfSkill(p.key)
  local lines = { g.intro, "" }
  if p.key == "herbalism" then
    lines[#lines + 1] = "|cffd6b266Click a range|r to open the Farm Guide on the best herb for you there."
  elseif p.key == "mining" then
    lines[#lines + 1] = "|cffd6b266Click a range|r to build a mining route in the zone where you know the most of those veins."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffd6b266Smelting skill-ups|r"
    for _, r in ipairs(NW.RECIPES.mining or {}) do
      if r.grey > r.yellow or r.yellow <= 250 then
        lines[#lines + 1] = ("%s  |cffff8040%s|r-|cff808080%d|r"):format(r.name, r.orange or r.yellow, r.grey)
      end
    end
  elseif p.key == "skinning" then
    if rank then
      local maxLevel = rank < 100 and math.floor(rank / 10) + 10 or math.floor(rank / 5)
      lines[#lines + 1] = ("At %d skill you can skin beasts up to |cffd6b266level %d|r."):format(rank, maxLevel)
    end
  elseif p.key == "fishing" then
    -- cook what you catch, for the bracket you're in
    local cook = NW.ProfSkill("cooking") or 0
    local fishRank = rank or 1
    local b = steps[1]
    for _, x in ipairs(steps) do if fishRank >= x.from and fishRank < x.to then b = x end end
    lines[#lines + 1] = ("|cffd6b266Cook what you catch|r (Cooking %d)"):format(cook)
    for _, fid in ipairs(b and b.fish or {}) do
      for _, r in ipairs(NW.CookFish(fid)) do
        local col = cook < r.yellow and "ff8040" or cook < r.green and "ffff00" or cook < r.grey and "40bf40" or "808080"
        if (r.orange or r.yellow) > cook then col = "d17665" end
        lines[#lines + 1] = ("|cff%s%s|r  %s-%d%s"):format(col, r.name, r.orange or r.yellow, r.grey,
          r.src == "recipe" and " |cff938c80(recipe)|r" or "")
      end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cff938c80Red: you need more Cooking. Grey: no more skill-ups.|r"
  end
  infoText:SetText(table.concat(lines, "\n"))
end

------------------------------------------------------------------------
-- Missing recipes: what you don't know yet, and where it comes from
------------------------------------------------------------------------
RECIPE_PREFIX = {
  alchemy = "Recipe: ", blacksmithing = "Plans: ", enchanting = "Formula: ", engineering = "Schematic: ",
  leatherworking = "Pattern: ", tailoring = "Pattern: ", cooking = "Recipe: ", firstaid = "Manual: ",
}
-- Trainers; names marked Forever were confirmed in WoW Forever, the rest are from the original game
local TRAINERS = {
  alchemy = "Undercity: Doctor Herbert Halsey, Doctor Marsh (Forever). Alliance trainers in Stormwind and Ironforge.",
  blacksmithing = "Orgrimmar: Saru Steelfury, to Expert (Forever). Ironforge: Bengus Deepforge. Artisan: Brikk Keencraft, Booty Bay.",
  enchanting = "Orgrimmar: Godan (Forever). Stormwind: Lucan Cordell. Expert: Hgarth (Stonetalon) or Kitta Firewind (Elwynn). Artisan: Annora, Uldaman.",
  engineering = "Orgrimmar: Roxxik, to Expert (Forever). Ironforge: Springspindle Fizzlegear. Artisan: Buzzek Bracketswing, Tanaris.",
  leatherworking = "Thunder Bluff: Mak, Tarn, Una (Forever). Darnassus: Telonis. Artisan: Hahrana Ironhide (Feralas) or Drakk Stonehand (Hinterlands).",
  tailoring = "Undercity: Josef Gregorian, Rhiannon Davis, Victor Ward (Forever). Stormwind: Georgio Bolero.",
  cooking = "Orgrimmar: Zamja (Forever). Stormwind: Stephen Ryback. Expert comes from the Expert Cookbook.",
  firstaid = "Orgrimmar: Arnok. Stormwind: Shaina Fuller. Expert comes from the book Expert First Aid - Under Wraps.",
}
local MERCHANT = "Merchant's Favor vendor: Crossroads, Barrens (Horde) or Three Corners, Redridge (Alliance)"

-- Forever's new recipes are sold for Merchant's Favor; their items have new IDs
local function isForeverNew(r)
  return (r.item and r.item >= 240000) or false
end

-- The game's own source text ("Vendor: ... Zone: ..."), cleaned for one line
local function cleanSource(text, oneLine)
  text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if oneLine then
    local parts = {}
    for line in text:gmatch("[^\n]+") do parts[#parts + 1] = strtrim(line) end
    text = table.concat(parts, "  ·  ")
  end
  return text
end
local function scanOf(key, r)
  local sc = NW.charDB.recipeScan[key]
  return sc and sc[r.name]
end

-- Where a recipe comes from, from the recipe list's source codes
local function whereText(r)
  if not r.where then return end
  local fac = (UnitFactionGroup and UnitFactionGroup("player")) == "Alliance" and "A" or "H"
  local parts, fav, other = {}, false, false
  for tok in r.where:gmatch("[^;]+") do
    local c, rest = tok:sub(1, 1), tok:sub(2)
    if tok == "F" then fav = true
    elseif tok == "S" then parts[#parts + 1] = "Specialization trainer"
    elseif tok == "T" or tok == "B" then -- handled as a trainer recipe
    elseif c == "V" then
      local f = rest:sub(1, 1)
      if f == "*" or f == fac then parts[#parts + 1] = "Vendor: " .. rest:sub(2) else other = true end
    elseif c == "D" then parts[#parts + 1] = "Drop: " .. rest
    elseif c == "+" then parts[#parts + 1] = "+" .. rest .. " more"
    elseif c == "Q" then parts[#parts + 1] = "Quest: " .. rest
    end
  end
  if #parts == 0 and other then parts[1] = "Sold to the other faction: auction house" end
  return table.concat(parts, "  ·  "), fav
end

function sourceText(key, r, rank)
  local e = r.scanned or scanOf(key, r)
  if r.src == "scan" or (r.src == "recipe" and e and e.source) then
    if e and e.source then
      local merchant = e.source:find("Merchant") or e.source:find("Durotar Supply") or e.source:find("Commerce Authority")
      return (merchant and "|cffd6b266" or "") .. cleanSource(e.source, true) .. (merchant and "|r" or ""), merchant and "merchant" or "drop"
    end
    if r.src == "scan" then return "Source not listed by the game", "drop" end
  end
  local req = r.orange or r.yellow
  if r.src == "trainer" or r.src == "rank" then
    if not rank then return "Trainer", "dim" end
    if rank >= req then return "|cff94ba78Trainer: learn it now|r", "now" end
    return ("Trainer at skill %d"):format(req), "later"
  end
  local w, fav = whereText(r)
  if w and w ~= "" then return (fav and ("|cffd6b266" .. w .. "|r") or w), fav and "merchant" or "drop" end
  if fav or isForeverNew(r) then return "|cffd6b266" .. MERCHANT .. "|r", "merchant" end
  return "Vendor or world drop  ·  click to search the AH", "drop"
end

local missing = {}
local function buildMissing(key)
  local known = NW.charDB.known[key] or {}
  local rank = NW.ProfSkill(key)
  local out, have = {}, {}
  local scan = NW.charDB.recipeScan[key]
  -- searching shows recipes you know too
  local all = searchText ~= ""
  for _, list in ipairs({ NW.RECIPES[key] or {}, NW.CATALOG[key] or {} }) do
    for _, r in ipairs(list) do
      have[r.name] = true
      local e = scan and scan[r.name]
      r.knownNow = (known[r.name] or (e and e.learned) or (r.where and r.where:sub(1, 1) == "B")) and true or false
      if (all or not r.knownNow) and (r.knownNow or not NW.NotYet(r)) then out[#out + 1] = r end
    end
  end
  -- recipes the game lists that Nodewalker's data doesn't have
  for name, e in pairs(scan or {}) do
    local belongs = NW.RecipeBelongs(name, key)
    if belongs == nil then belongs = NW.RecipeLineIs(e.id, key) end -- not in the lists: ask the game
    if not e.learned and not have[name] and belongs ~= false then
      out[#out + 1] = { name = name, src = "scan", item = e.item, icon = e.icon, reagents = e.reagents or {}, scanned = e, cat = e.cat }
    end
  end
  table.sort(out, function(a, b)
    local ra, rb = a.orange or a.yellow or 999, b.orange or b.yellow or 999
    if ra ~= rb then return ra < rb end
    return a.name < b.name
  end)
  -- the ones you could learn now come first
  if rank then
    local now, rest = {}, {}
    for _, r in ipairs(out) do
      if (r.src == "trainer" or r.src == "rank") and rank >= (r.orange or r.yellow) then now[#now + 1] = r else rest[#rest + 1] = r end
    end
    for _, r in ipairs(rest) do now[#now + 1] = r end
    out = now
  end
  return out
end

-- Sections you've folded away, per profession. While searching, folds are
-- kept apart and forgotten when the search changes, so a search starts with
-- every match showing and your saved folds come back after.
local searchFolds, searchFoldsFor = {}, nil
local function collapsedOf(key)
  if searchText ~= "" then
    local k = key .. "\0" .. searchText
    if searchFoldsFor ~= k then searchFolds, searchFoldsFor = {}, k end
    return searchFolds
  end
  local all = st().recipeCollapsed
  if not all then all = {} st().recipeCollapsed = all end
  all[key] = all[key] or {}
  return all[key]
end
local function drawMissingRows(key)
  local rank = NW.ProfSkill(key)
  for i, row in ipairs(stepRows) do
    local r = steps[i + stepOffset]
    row.step, row.bracket, row.missingRecipe = nil, nil, r
    row.sectionRow = r and r.header and r or nil
    row.profitRow = nil
    row:SetCraft()
    if r and r.header then
      -- a section heading, as in the game's own profession window
      row.missingRecipe = nil
      row.profitRow = nil
      row:Show()
      row:SetSelected(false)
      row.range:SetText("")
      row.icon:Hide()
      row.name:SetText(("|TInterface\\Buttons\\UI-%sButton-Up:14:14:-2:0|t |cffd6b266%s|r  |cff938c80%d|r"):format(
        r.collapsed and "Plus" or "Minus", r.header, r.count))
      row.crafts:SetText("")
      row.cost:SetText("")
      row.mats:SetText("")
    elseif r then
      row:Show()
      row:SetSelected(card ~= nil and (card.r == r or (card.stack[1] and card.stack[1].r == r)) or false)
      local req = r.orange or r.yellow
      row.range:SetText(req and req > 0 and tostring(req) or "?")
      row.icon:SetTexture(r.icon or recipeIcon(r))
      row.icon:Show()
      local col = r.knownNow and "94ba78" or (not rank or not req or rank >= req) and "ffffff" or "d17665"
      row.name:SetText(("|cff%s%s|r%s"):format(col, r.name, r.knownNow and "  |cff938c80known|r" or ""))
      row.crafts:SetText("")
      row.cost:SetText("")
      row.mats:SetText((sourceText(key, r, rank)))
    else
      row:Hide()
    end
  end
  stepScroll:Update()
end

------------------------------------------------------------------------
-- Profit: what each craft earns at today's prices, best first
------------------------------------------------------------------------
local function signedMoney(c)
  if c >= 0 then return "|cff94ba78+|r" .. NW.Money(c, "mid") end
  return "|cffd17665-|r" .. NW.Money(-c, "mid")
end
local function drawProfitRows(key)
  for i, row in ipairs(stepRows) do
    local e = steps[i + stepOffset]
    row.step, row.bracket, row.missingRecipe, row.profitRow = nil, nil, e and e.r, e and true or nil
    row.sectionRow = nil
    row:SetCraft(selected, e and e.r)
    if e then
      local r = e.r
      row:Show()
      row:SetSelected(card ~= nil and (card.r == r or (card.stack[1] and card.stack[1].r == r)) or false)
      row.icon:SetTexture(r.icon or recipeIcon(r))
      row.icon:Show()
      row.crafts:SetText("")
      if e.profit then
        local col = e.profit > 0 and "94ba78" or "d17665"
        row.range:SetText(e.roi and ("|cff%s%s%d%%|r"):format(col, e.roi > 0 and "+" or "", math.max(-999, math.min(999, e.roi))) or "")
        row.name:SetText(("|cff%s%s|r%s"):format(e.profit > 0 and "e0dbd0" or "938c80", r.name, e.known and "" or "  |cff938c80not known|r"))
        row.cost:SetText((e.unknown and "|cff938c80~|r" or "") .. signedMoney(e.profit))
        local parts = {
          ("%s %s"):format(e.de and "Disenchants" or "Sells", NW.Money(e.sale, "mid")),
          "materials " .. NW.Money(e.cost, "mid") .. (e.unknown and " |cffd17665+?|r" or ""),
        }
        if e.count > 0 and e.profit > 0 then parts[#parts + 1] = ("|cffe0dbd0%d now, %s|r"):format(e.count, signedMoney(e.total)) end
        if (r.yield or 1) > 1 then parts[#parts + 1] = ("makes %d"):format(r.yield) end
        if e.age and e.age >= 3 then parts[#parts + 1] = ("|cffd6b266price %dd old|r"):format(e.age) end
        row.mats:SetText(table.concat(parts, "  ·  "))
      else
        row.range:SetText("")
        row.name:SetText(("|cff938c80%s|r"):format(r.name))
        row.cost:SetText("|cff938c80?|r")
        row.mats:SetText("No auction price for what it makes")
      end
    else
      row:Hide()
    end
  end
  stepScroll:Update()
end
local function drawProfit(p)
  local known = NW.charDB.known[p.key] or {}
  local scan = NW.charDB.recipeScan[p.key]
  local all = searchText ~= ""
  local out, seen = {}, {}
  for _, list in ipairs({ NW.RECIPES[p.key] or {}, NW.CATALOG[p.key] or {} }) do
    for _, r in ipairs(list) do
      if r.item and not seen[r.name] then
        seen[r.name] = true
        local e = scan and scan[r.name]
        local isKnown = (known[r.name] or (e and e.learned)) and true or false
        -- "Have materials": only what your bags can make right now
        local makeable = not st().profitHaveMats or (NW.CanCraft(p.key, r) or 0) > 0
        if (isKnown or all) and makeable and (isKnown or not NW.NotYet(r)) then
          local profit, cost, sale, unknown, de = NW.RecipeProfit(r)
          cost = cost or 0
          -- return on what goes in; what your bags can make now, and what that earns
          local count = isKnown and (NW.CanCraft(p.key, r) or 0) or 0
          out[#out + 1] = { r = r, profit = profit, cost = cost, sale = sale, unknown = unknown, known = isKnown, de = de,
            roi = profit and cost > 0 and math.floor(profit / cost * 100 + 0.5) or nil,
            count = count, total = profit and profit * count or 0, age = sale and NW.PriceAge(r.item) or nil }
        end
      end
    end
  end
  steps = filter(out, function(e)
    local r = e.r
    if has(r.name) then return true end
    for _, re in ipairs(r.reagents) do if has((itemName(re[1]))) then return true end end
    return false
  end)
  -- less-used filters
  local s0 = st()
  if s0.profitComplete or s0.profitMinRoi or s0.profitFresh then
    local kept = {}
    for _, e in ipairs(steps) do
      if not (s0.profitComplete and (not e.profit or e.unknown))
        and not (s0.profitMinRoi and not (e.roi and e.roi >= 10))
        and not (s0.profitFresh and (not e.age or e.age >= 3)) then
        kept[#kept + 1] = e
      end
    end
    steps = kept
  end
  -- profit each first: a big return on a copper craft isn't worth more than gold on a modest one
  local by = s0.profitSort or "profit"
  local key = ({ roi = "roi", total = "total", count = "count" })[by]
  table.sort(steps, function(a, b)
    if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
    if by == "cheap" and a.cost ~= b.cost then return a.cost < b.cost end
    if key then
      local x, y = a[key] or -math.huge, b[key] or -math.huge
      if x ~= y then return x > y end
    end
    if a.profit and a.profit ~= b.profit then return a.profit > b.profit end
    return a.r.name < b.r.name
  end)
  -- "At least": only what earns enough to be worth the clicks. A search shows everything.
  local everything, floor = steps, st().profitMin or 1000
  local worth = 0
  for _, e in ipairs(everything) do if e.profit and e.profit >= math.max(floor, 1) then worth = worth + 1 end end
  if floor > 0 and not all then
    steps = {}
    for _, e in ipairs(everything) do if e.profit and e.profit >= floor then steps[#steps + 1] = e end end
  end
  if viewChanged then stepOffset = 0 end
  clampOffsets()
  local good, bad, none = 0, 0, 0
  for _, e in ipairs(everything) do
    if not e.profit then none = none + 1 elseif e.profit > 0 then good = good + 1 else bad = bad + 1 end
  end
  local hasKnown = next(known) ~= nil or (scan and next(scan) ~= nil)
  stepsEmpty:SetText(#steps == 0 and (searchText ~= "" and "No recipe matches your search."
    or #everything > 0 and "Nothing earns that much. Lower \"At least\"."
    or st().profitHaveMats and "Nothing you can make from your bags right now."
    or hasKnown and "None of your recipes make something that sells."
    or "Open your profession window once so Nodewalker sees which recipes you know.") or "")
  drawProfitRows(p.key)
  hCost:SetText(("%d worth making"):format(worth))
  hCostSub:SetText(("of %d recipes"):format(#everything))
  priceLine:SetText(NW.HasAuctionator() and ""
    or "|cffd17665Auctionator isn't loaded:|r profit needs its auction prices.")
  local stale, canNow, nowTotal = 0, 0, 0
  for _, e in ipairs(everything) do
    if e.age and e.age >= 3 then stale = stale + 1 end
    if e.count > 0 and e.profit and e.profit > 0 then canNow = canNow + 1 nowTotal = nowTotal + e.total end
  end
  local lines = {
    ("|cff94ba78%d|r make a profit"):format(good),
    ("|cffd17665%d|r cost more than they sell for"):format(bad),
    ("%d with no auction price"):format(none),
  }
  if stale > 0 then lines[#lines + 1] = ("|cffd6b266%d|r with prices 3+ days old"):format(stale) end
  if canNow > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("Your bags can make |cffe0dbd0%d|r of them, for %s"):format(canNow, signedMoney(nowTotal))
  end
  for _, l in ipairs({
    "",
    "|cffd6b266Profit each|r  auction price less the 5% cut, minus every material at today's price, bags included",
    "|cffd6b266Return|r  profit over material value",
    "|cff938c80Deposits aren't counted. Gear counts its disenchant value when that pays more. ~ means a price is missing.|r",
  }) do lines[#lines + 1] = l end
  infoText:SetText(table.concat(lines, "\n"))
end

-- The opened recipe: header, a money CW.grid, its materials, and what you can do
CW.MAX_CARD_ROWS = 7
local function drawCard()
  local r = card.r
  local list = {}
  for _, re in ipairs(r.reagents) do
    local price, src = NW.Price(re[1])
    local have = NW.ItemCount(re[1]) or 0
    local maker, makerKey = NW.RecipeFor(re[1])
    local buy = math.max(0, re[2] - have)
    -- what's left to buy, from the live listings when you've just searched
    local cost = price and src ~= "est" and price * buy or nil
    local live
    if src == "ah" and buy > 0 and NW.FillCost then
      local fill, got, complete = NW.FillCost(re[1], buy)
      if fill and got > 0 then
        cost = fill + (buy - got) * price
        live = { cost = fill, got = got, complete = complete }
      end
    end
    list[#list + 1] = { id = re[1], need = re[2], have = have, buy = buy, live = live,
      price = price, src = src, cost = cost, full = price and src ~= "est" and price * re[2] or nil, maker = maker, makerKey = makerKey }
  end
  shop = list
  shopOffset = 0

  -- header
  CW.cIcon:SetTexture(recipeIcon(r))
  local q = r.item and select(3, NW.ItemInfo(r.item))
  local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  CW.cName:SetText(r.name)
  if qc then CW.cName:SetTextColor(qc.r, qc.g, qc.b) else CW.cName:SetTextColor(unpack(S.text)) end
  local prof = NW.PROF_BY_KEY[card.key]
  local req = r.orange or r.yellow
  CW.cProf:SetText(("%s%s%s"):format(prof and prof.name or "", req and req > 0 and (" " .. req) or "",
    (r.yield or 1) > 1 and ("  ·  makes %d"):format(r.yield) or ""))
  CW.cSource:SetText((sourceText(card.key, r, NW.ProfSkill(card.key))) or "")

  -- money: every material counts at its price, even the ones in your bags
  local profit, _, sale, _, de = NW.RecipeProfit(r)
  local full, toBuy, unpriced, missingUnpriced, ready = 0, 0, false, false, 0
  for _, e in ipairs(list) do
    if e.full then full = full + e.full else unpriced = true end
    if e.buy > 0 then
      if e.cost then toBuy = toBuy + e.cost else missingUnpriced = true end
    else
      ready = ready + 1
    end
  end
  local function m(c, partial) return NW.Money(c, "mid") .. (partial and " |cffd17665+?|r" or "") end
  CW.cells[1].label:SetText(de and "Disenchant value" or "Market value")
  CW.cells[1].value:SetText(sale and m(sale) or "|cff938c80No price|r")
  CW.cells[1].value:SetTextColor(unpack(S.text))
  CW.cells[1].tip = sale and (de and "Its dust at auction, less the 5% cut." or "Auction price less the 5% cut. Not a promise it sells.") or nil
  CW.cells[2].label:SetText("Material value")
  CW.cells[2].value:SetText((full > 0 or not unpriced) and m(full, unpriced) or "|cff938c80No price|r")
  CW.cells[2].tip = "Every material at today's price, including what's in your bags."
  CW.cells[3].label:SetText("Estimated profit")
  if profit and not unpriced then
    CW.cells[3].value:SetText((profit >= 0 and "+" or "-") .. NW.Money(math.abs(profit), "mid"))
    CW.cells[3].value:SetTextColor(unpack(profit >= 0 and S.good or S.bad))
  else
    CW.cells[3].value:SetText(profit and ("~" .. NW.Money(math.abs(profit), "mid")) or "|cff938c80Unknown|r")
    CW.cells[3].value:SetTextColor(unpack(S.dim))
  end
  CW.cells[3].tip = "Market value minus material value. Deposits aren't counted."
  CW.cells[4].label:SetText("To buy")
  if toBuy > 0 or missingUnpriced then
    CW.cells[4].value:SetText(m(toBuy, missingUnpriced))
    CW.cells[4].value:SetTextColor(unpack(S.gold))
  else
    CW.cells[4].value:SetText("Nothing")
    CW.cells[4].value:SetTextColor(unpack(S.good))
  end
  CW.cells[4].tip = "Gold you'd spend on the materials you don't have."

  -- how old the price for what it makes is
  local age = r.item and NW.PriceAge(r.item)
  if not sale then
    CW.cAge:SetText("|cff938c80No auction data for what it makes|r")
  elseif age == nil then
    CW.cAge:SetText("")
  elseif age >= 3 then
    CW.cAge:SetText(("|cffd6b266Auction price %d days old|r"):format(age))
  else
    CW.cAge:SetText(age == 0 and "Auction price from today" or ("Auction price %d day%s old"):format(age, age == 1 and "" or "s"))
  end

  -- materials: as many rows as it has, up to a few
  CW.cMatsCount:SetText(("%d/%d available"):format(ready, #list))
  shopVisible = math.min(#list, CW.MAX_CARD_ROWS)
  local boxH = math.max(1, shopVisible) * SHOP_H + 4
  shopBox:SetHeight(boxH)
  shopScroll:SetVisible(boxH, shopVisible)
  shopBox:ClearAllPoints()
  shopBox:SetPoint("TOPLEFT", CW.cMatsHead, "BOTTOMLEFT", 0, -6)
  drawShop()

  -- actions
  local can = NW.CanCraft(card.key, r)
  local craftable = can ~= nil or knowsRecipe(card.key, r)
  cardCraft.key, cardCraft.r, cardCraft.n = card.key, r, can or 0
  cardCraft:SetText((can or 0) > 1 and ("Craft " .. can) or "Craft")
  cardCraft:SetAlpha((can or 0) > 0 and 1 or 0.45)
  cardCraft.why = nil
  if craftable and (can or 0) < 1 then
    if can == nil then
      cardCraft.why = ("Open %s once to craft from here."):format(prof and prof.name or "the profession")
    else
      local id, short = NW.CraftMissing(r)
      cardCraft.why = id and ("Need %d more %s."):format(short, (itemName(id))) or "Missing materials."
    end
  end
  for _, b in ipairs(CW.cardButtons) do b:Hide() end
  local below = shopBox
  local function under(b) b:ClearAllPoints() b:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8) b:Show() end
  local function beside(b, left) b:ClearAllPoints() b:SetPoint("LEFT", left, "RIGHT", 6, 0) b:Show() end
  -- the main thing to do now: craft it, and buy what's missing
  local missing = toBuy > 0 or missingUnpriced
  if craftable then
    under(cardCraft)
    if missing then beside(CW.cardMissing, cardCraft) end
    below = cardCraft
  elseif missing then
    under(CW.cardMissing)
    below = CW.cardMissing
  end
  -- the other searches
  under(CW.cardAll)
  if r.item then beside(CW.cardItem, CW.cardAll) end
  below = CW.cardAll
  -- back to the recipe you came from
  local prev = card.stack[#card.stack]
  if prev then
    cardBack:SetText("< " .. prev.r.name)
    under(cardBack)
  end
end

local function drawMissing(p)
  steps = filter(buildMissing(p.key), function(r)
    if has(r.name) or has(r.where) then return true end
    for _, re in ipairs(r.reagents) do if has((itemName(re[1]))) then return true end end
    return false
  end)
  -- Sections, as the game's profession window groups them (Stamina Food,
  -- Attack Power Food...). They come from your profession window, so this
  -- needs it to have been opened once.
  local found = #steps
  local everything = steps -- for the counts, whatever is folded away
  do
    local folded = collapsedOf(p.key)
    local groups, order, anyCat = {}, {}, false
    for _, r in ipairs(steps) do
      local e = r.scanned or scanOf(p.key, r)
      local cat = e and e.cat or "Other"
      if e and e.cat then anyCat = true end
      local g = groups[cat]
      if not g then
        g = { name = cat, rows = {}, order = e and e.catOrder, first = r.orange or r.yellow or 0 }
        groups[cat] = g
        order[#order + 1] = g
      end
      g.order = g.order or (e and e.catOrder)
      g.first = math.min(g.first, r.orange or r.yellow or 0)
      g.rows[#g.rows + 1] = r
    end
    if anyCat and #order > 1 then
      table.sort(order, function(a, b)
        if (a.name == "Other") ~= (b.name == "Other") then return b.name == "Other" end
        if a.order and b.order and a.order ~= b.order then return a.order < b.order end
        if a.first ~= b.first then return a.first < b.first end
        return a.name < b.name
      end)
      local out = {}
      for _, g in ipairs(order) do
        local shut = folded[g.name] and true or false
        out[#out + 1] = { header = g.name, count = #g.rows, collapsed = shut }
        if not shut then for _, r in ipairs(g.rows) do out[#out + 1] = r end end
      end
      steps = out
    end
  end
  if viewChanged then stepOffset = 0 end
  clampOffsets()
  local rank = NW.ProfSkill(p.key)
  local scanned = NW.charDB.known[p.key] and next(NW.charDB.known[p.key]) ~= nil
  local fullList = NW.charDB.recipeScan[p.key] and next(NW.charDB.recipeScan[p.key]) ~= nil
  stepsEmpty:SetText(#steps == 0 and (searchText ~= "" and "No recipe matches your search."
    or "You know every recipe Nodewalker has for this profession.") or "")
  drawMissingRows(p.key)
  local counts = { now = 0, later = 0, merchant = 0, drop = 0, dim = 0 }
  local nMissing = 0
  for _, r in ipairs(everything) do
    if not r.header and not r.knownNow then
      nMissing = nMissing + 1
      local _, kind = sourceText(p.key, r, rank)
      counts[kind] = counts[kind] + 1
    end
  end
  hCost:SetText(searchText ~= "" and ("%d found"):format(found) or ("%d missing"):format(nMissing))
  -- short, so it can't run into the skill line; no nagging about a profession you don't have
  hCostSub:SetText(not rank and "of every recipe" or fullList and "from the game's recipe list"
    or scanned and "of Nodewalker's recipes" or "|cffd17665Open the profession once|r")
  priceLine:SetText("")
  local lines = {
    ("|cff94ba78%d|r to learn at the trainer now"):format(counts.now),
    ("%d at the trainer later"):format(counts.later + counts.dim),
    ("|cffd6b266%d|r from Merchant's Favor vendors"):format(counts.merchant),
    ("%d from other vendors or drops"):format(counts.drop),
    "",
    "|cffd6b266Trainers|r",
    TRAINERS[p.key] or "",
    "",
    "|cffd6b266Merchant's Favor|r",
    "Horde: Durotar Supply and Logistics, Crossroads. Alliance: Azeroth Commerce Authority, Three Corners, Redridge. Favor comes from Waylaid Crates; some recipes need Friendly or Honored.",
    "",
    fullList and "|cff938c80Open your profession window again to refresh the list.|r"
      or "|cff938c80Open your profession window to load the full recipe list.|r",
  }
  infoText:SetText(table.concat(lines, "\n"))
end

-- hover and click for missing rows
for _, row in ipairs(stepRows) do
  row:HookScript("OnEnter", function(self)
    local r = self.missingRecipe
    if not r then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if r.item then GameTooltip:SetItemByID(r.item) elseif r.spell then GameTooltip:SetSpellByID(r.spell) else GameTooltip:SetText(r.name) end
    GameTooltip:AddLine(" ")
    if r.yellow then
      GameTooltip:AddDoubleLine("Skill-up colours", ("|cffff8040%s|r |cffffff00%d|r |cff40bf40%d|r |cff808080%d|r"):format(
        r.orange or "-", r.yellow, r.green, r.grey), S.dim[1], S.dim[2], S.dim[3])
    end
    if r.cat then GameTooltip:AddDoubleLine("Category", r.cat, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    local parts = {}
    for _, re in ipairs(r.reagents) do parts[#parts + 1] = re[2] .. " " .. (itemName(re[1])) end
    if #parts > 0 then GameTooltip:AddLine("Needs: " .. table.concat(parts, ", "), 1, 1, 1, true) end
    local e = r.scanned or scanOf(selected, r)
    if e and e.source then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(cleanSource(e.source, false), 1, 0.82, 0, true)
    else
      GameTooltip:AddLine((sourceText(selected, r, NW.ProfSkill(selected))), 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  row:HookScript("OnClick", function(self)
    -- a Train row: pin the trainer on the map
    local stp = self.step
    if self.linked or not (stp and stp.banner) then return end
    local who, _, mapID, x, y = NW.RankWhere(selected, stp.rankUp.name)
    if mapID then NW.PinMap(mapID, x, y, who) end
  end)
  row:HookScript("OnClick", function(self)
    -- a section heading: fold or unfold it
    local sec = self.sectionRow
    if sec and not self.linked then
      local folded = collapsedOf(selected)
      folded[sec.header] = not folded[sec.header] or nil
      refresh()
      return
    end
    local r = self.missingRecipe
    if self.linked or not r then return end
    if r.header or not r.reagents then return end
    if IsAltKeyDown() then
      -- Alt-click: Profit looks up what it makes, Recipes the recipe itself
      local term
      if self.profitRow then
        local n, ok
      if r.item then n, ok = itemName(r.item) end
        term = ok and n or nil
      elseif r.src == "recipe" or r.src == "scan" then
        term = (RECIPE_PREFIX[r.findKey or selected] or "") .. r.name
      end
      if term then searchAH({ { term, 1 } }) end
      return
    end
    -- open it on the right: materials and what each costs
    card = { r = r, key = r.findKey or selected, stack = {} }
    refresh()
  end)
end

NW.SearchAH, NW.AHOpen, NW.ChatLink = searchAH, ahOpen, chatLink
NW.RecipeSourceText = function(key, r) return (sourceText(key, r, NW.ProfSkill(key))) end

------------------------------------------------------------------------
-- Find a craft: any recipe in the game, for having someone make it
------------------------------------------------------------------------
local findAll -- every recipe once: { r, key }
local function allRecipes()
  if findAll then return findAll end
  findAll = {}
  local seen = {}
  for _, prof in ipairs(NW.PROFS) do
    if prof.kind == "craft" then
      for _, src in ipairs({ NW.RECIPES[prof.key] or {}, NW.CATALOG[prof.key] or {} }) do
        for _, r in ipairs(src) do
          local k = prof.key .. ":" .. r.name
          if not seen[k] and r.reagents and #r.reagents > 0 and not NW.NotYet(r) then
            seen[k] = true
            r.findKey = prof.key
            findAll[#findAll + 1] = r
          end
        end
      end
    end
  end
  return findAll
end
-- materials at today's prices, and what's left to buy after your bags
local function matsCost(r)
  local full, toBuy, unpriced = 0, 0, false
  for _, re in ipairs(r.reagents) do
    local price, src = NW.Price(re[1])
    if price and src ~= "est" then
      full = full + price * re[2]
      toBuy = toBuy + price * math.max(0, re[2] - (NW.ItemCount(re[1]) or 0))
    else
      unpriced = true
    end
  end
  return full, toBuy, unpriced
end
refresh = function()
  if not page:IsShown() then return end
  selected = selected or st().profSelected
  if selected == "find" then selected = nil end -- (Find a craft has its own tab now)
  if not selected then
    -- start on the first profession you have
    for _, p in ipairs(NW.PROFS) do if NW.ProfSkill(p.key) and p.kind == "craft" and not p.secondary then selected = p.key break end end
    selected = selected or "alchemy"
  end
  for _, b in ipairs(profRows) do
    local rank, max = NW.ProfSkill(b.prof.key)
    b.skill:SetText(rank and tostring(rank) or "") -- the cap is in the header; long names need the room
    b.name:SetTextColor(unpack(rank and S.text or S.dim))
    b.icon:SetDesaturated(not rank)
    b:SetSelected(b.prof.key == selected)
    local k = NW.charDB.known[b.prof.key]
    b.unread = b.prof.kind == "craft" and rank ~= nil and not (k and next(k) ~= nil)
  end
  -- only nag about the profession window while a craft you have is unread
  local unread = false
  for _, pr in ipairs(NW.PROFS) do
    if pr.kind == "craft" and NW.ProfSkill(pr.key) then
      local k = NW.charDB.known[pr.key]
      if not (k and next(k) ~= nil) then unread = true end
    end
  end
  listNote:Hide()
  local p = NW.PROF_BY_KEY[selected]
  local vk = selected .. ":" .. mode .. ":" .. searchText
  viewChanged = vk ~= lastView
  lastView = vk
  hIcon:SetTexture(p.icon)
  hName:SetText(p.name)
  setLedger(nil)
  local rank, max = NW.ProfSkill(p.key)
  hSkill:SetText((rank and ("Skill %d / %d"):format(rank, max or 300) or "You don't have this profession")
    .. rankNote(p.key))
  NW.SetWindowSubtitle(p.name)
  if firstOpen then firstOpen = nil mode = openMode(selected) end

  local isCraft = p.kind == "craft"
  local isProfit = isCraft and mode == "profit"
  local isMissing = isCraft and (mode == "missing" or isProfit) -- both use the list-and-notes layout
  for k, b in pairs(modeBtns) do
    b:SetShown(isCraft)
    b:SetSelected(k == mode)
  end
  -- Leveling has its options row with one line under it; the list views
  -- use both rows for their description
  priceLine:ClearAllPoints()
  if isMissing and not isProfit then
    priceLine:SetPoint("TOPLEFT", optRow, "TOPLEFT", 0, -2)
    priceLine:SetHeight(36)
  else
    priceLine:SetPoint("TOPLEFT", optRow, "BOTTOMLEFT", 0, -5)
    priceLine:SetHeight(13)
  end
  profitCtl:SetShown(isProfit)
  if isProfit then sortDrop:Refresh() minProfit:Refresh() profitFilters:Refresh() end
  priceLine:SetWidth(MID_W)
  local capSet = CAPS[isProfit and "profit" or isMissing and "missing" or isCraft and "plan" or "gather"]
  for i, t in ipairs(caps) do t:SetText(capSet[i]) end
  -- an opened recipe belongs to the Profit view of one profession
  local cardKey = selected .. ":" .. mode
  if not (isProfit or isMissing) or cardKey ~= lastCardKey then card = nil end
  lastCardKey = cardKey
  local showCard = card ~= nil
  local planPanel = isCraft and not isMissing
  optRow:SetShown(planPanel)
  priceLine:SetShown(isCraft)
  shopBox:SetShown(planPanel or showCard)
  searchBtn:SetShown(planPanel)
  tips:SetShown(planPanel)
  tips:SetText(KEY .. (NW.PROF_TIPS[p.key] or ""))
  rTotal:SetShown(planPanel)
  rHead:SetShown(not showCard)
  cardFrame:SetShown(showCard)
  if not showCard then
    for _, b in ipairs(CW.cardButtons) do b:Hide() end
    -- the shopping list's own size and place
    shopVisible = SHOP_ROWS
    shopBox:SetHeight(240)
    shopScroll:SetVisible(240, SHOP_ROWS)
    shopBox:ClearAllPoints()
    shopBox:SetPoint("TOPLEFT", targetSlider, "BOTTOMLEFT", 0, -10)
  end
  targetSlider:SetShown(planPanel)
  if targetSlider:IsShown() then targetSlider:Refresh() end
  info:SetShown((not isCraft or isMissing) and not showCard)
  rHead.text:SetText(isProfit and "Profit" or isMissing and "Where to get them" or isCraft and "Shopping list" or (p.key == "fishing" and "Fishing + Cooking" or "Notes"))
  scrollDraw = isProfit and function() drawProfitRows(p.key) end
    or isMissing and function() drawMissingRows(p.key) end
    or (not isCraft and function() drawGatherRows(p.key) end) or nil
  if isProfit then drawProfit(p) elseif isMissing then drawMissing(p) elseif isCraft then drawCraft(p) else drawGather(p) end
  if showCard then drawCard() end
  if craftMsg and GetTime() - craftMsgAt < 4 then priceLine:SetText("|cffd6b266" .. craftMsg .. "|r") end
end
NW.RefreshProfessions = function() if page:IsShown() then refresh() end end

function NW.ToggleProfessions() NW.ToggleWindow("profs") end

------------------------------------------------------------------------
-- A Nodewalker tab under the game's profession window, with your next step
------------------------------------------------------------------------
function NW.OpenProfession(key)
  if key then selected = key; st().profSelected = key end
  mode = openMode(selected or key or "alchemy")
  if NW.window:IsShown() then NW.ShowTab("profs") else st().lastTab = "profs"; NW.window:Show() end
end

local ICON = "Interface\\AddOns\\Nodewalker\\Media\\Icon"
NW.ICON = ICON

-- Square icon button that sits in the column of profession buttons on the
-- right of the profession window, under the last one
local tradeTab = CreateFrame("Button", "NodewalkerTradeTab", UIParent)
tradeTab:SetSize(48, 48)
tradeTab:Hide()
local ttIcon = tradeTab:CreateTexture(nil, "ARTWORK")
ttIcon:SetAllPoints()
ttIcon:SetTexture(ICON)
local ttHL = tradeTab:CreateTexture(nil, "HIGHLIGHT")
ttHL:SetAllPoints()
ttHL:SetTexture(ICON)
ttHL:SetBlendMode("ADD")
ttHL:SetAlpha(0.35)
-- The game's own side tab (the template its profession and Group Finder tabs
-- are made from) drawn inside our button, so size and frame art are the game's.
local skin
local function buildSkin()
  if skin ~= nil then return skin end
  skin = false
  local ok, f = pcall(CreateFrame, "Frame", nil, tradeTab, "LargeSideTabButtonTemplate")
  if not ok or not f then return false end
  if not f.Icon then f:Hide() return false end
  f:EnableMouse(false)
  f:SetPoint("CENTER")
  f.Icon:SetTexture(ICON)
  if f.SetFillToInterior then pcall(f.SetFillToInterior, f, true) end
  if f.SetChecked then pcall(f.SetChecked, f, false) end
  f.glow = f:CreateTexture(nil, "OVERLAY")
  f.glow:SetAllPoints(f.Icon)
  f.glow:SetTexture(ICON)
  f.glow:SetBlendMode("ADD")
  f.glow:SetAlpha(0.35)
  f.glow:Hide()
  ttIcon:Hide()
  ttHL:SetAlpha(0)
  skin = f
  -- Let the game's tab take the mouse, so hovering and pressing it look
  -- exactly like the profession tabs; clicks and drags are passed on.
  if f.SetCustomOnMouseUpHandler then
    f:EnableMouse(true)
    f.ownMouse = true
    f:SetCustomOnMouseUpHandler(function(_, button, inside)
      if f.dragged then f.dragged = nil return end
      if button == "LeftButton" and inside then tradeTab:GetScript("OnClick")(tradeTab, button) end
    end)
    f:HookScript("OnMouseUp", function(_, button)
      if button == "RightButton" then tradeTab:GetScript("OnClick")(tradeTab, button) end
    end)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
      tradeTab:GetScript("OnDragStart")(tradeTab)
      if tradeTab.moving then f.dragged = true end
    end)
    f:SetScript("OnDragStop", function()
      tradeTab:GetScript("OnDragStop")(tradeTab)
      C_Timer.After(0.2, function() f.dragged = nil end)
    end)
    f:HookScript("OnEnter", function() tradeTab:GetScript("OnEnter")(tradeTab) end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return f
end
local function tint(v)
  ttIcon:SetVertexColor(v, v, v)
  if skin then skin.Icon:SetVertexColor(v, v, v) end
end
tradeTab:SetScript("OnMouseDown", function() tint(0.7) end)
tradeTab:SetScript("OnMouseUp", function() tint(1) end)

-- next step from the plan, along the bottom of the profession window
local nextBox = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
nextBox:SetHeight(30)
UI.Flat(nextBox, S.bg, S.edge)
nextBox:Hide()
local nextAccent = nextBox:CreateTexture(nil, "OVERLAY")
nextAccent:SetPoint("TOPLEFT", 1, -1)
nextAccent:SetPoint("BOTTOMLEFT", 1, 1)
nextAccent:SetWidth(2)
nextAccent:SetColorTexture(unpack(S.gold))
local nextIcon = nextBox:CreateTexture(nil, "ARTWORK")
nextIcon:SetSize(18, 18)
nextIcon:SetPoint("LEFT", 9, 0)
nextIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local nextText = UI.Text(nextBox, 12, S.text)
nextText:SetPoint("LEFT", nextIcon, "RIGHT", 7, 0)
nextBox:EnableMouse(true)
nextBox:SetScript("OnMouseUp", function() NW.OpenProfession(NW.currentTradeKey) end)
tradeTab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
tradeTab:RegisterForDrag("LeftButton")
tradeTab:SetMovable(true)
tradeTab:SetScript("OnClick", function(_, button)
  if IsShiftKeyDown() and button == "RightButton" then
    st().tradeTabPos, st().tradeTabCenter = nil, nil
    if tradeTab.placeOn then tradeTab.placeOn() end
    return
  end
  NW.OpenProfession(NW.currentTradeKey)
end)
tradeTab:SetScript("OnDragStart", function(self)
  if IsShiftKeyDown() then self.moving = true; self:StartMoving() end
end)
tradeTab:SetScript("OnDragStop", function(self)
  if not self.moving then return end
  self.moving = false
  self:StopMovingOrSizing()
  local f = self:GetParent()
  if f and f.GetRight and f:GetRight() then
    local cx, cy = self:GetCenter()
    st().tradeTabCenter = { cx - f:GetRight(), cy - f:GetTop() }
    st().tradeTabPos = nil
    self:ClearAllPoints()
    self:SetPoint("CENTER", f, "TOPRIGHT", st().tradeTabCenter[1], st().tradeTabCenter[2])
  end
end)
tradeTab:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("Nodewalker")
  GameTooltip:AddLine("Leveling plan, shopping list, missing recipes", 1, 1, 1, true)
  GameTooltip:AddLine("Shift-drag: move. Shift-right-click: reset.", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end)
tradeTab:SetScript("OnLeave", function() GameTooltip:Hide() if skin then skin.glow:Hide() end end)
tradeTab:HookScript("OnEnter", function() if skin and not skin.ownMouse then skin.glow:Show() end end)

local function updateNext()
  local key = NW.currentTradeKey
  local p = key and NW.PROF_BY_KEY[key]
  if not (p and p.kind == "craft" and NW.RECIPES[key]) then nextBox:Hide() return end
  local rank = NW.ProfSkill(key)
  if not rank or rank >= 300 then nextBox:Hide() return end
  local plan = NW.BuildPlan(key, rank, 300)
  local stp = plan.steps[1]
  if not (stp and stp.recipe) then nextBox:Hide() return end
  -- crafts left until the end of this step
  local left = 0
  for sk = rank, stp.to - 1 do
    local c = NW.SkillUpChance(stp.recipe, sk)
    if c > 0 then left = left + 1 / c end
  end
  nextIcon:SetTexture(recipeIcon(stp.recipe))
  local tag = stp.rankUp and ("  |cffd6b266(train %s)|r"):format(stp.rankUp.name) or (stp.needsRecipe and "  |cffff8040(needs recipe)|r" or "")
  nextText:SetText(("Next: |cffd6b266%s|r x%d  to %d%s"):format(stp.recipe.name, math.ceil(left - 0.05), stp.to, tag))
  nextBox:SetWidth(nextText:GetStringWidth() + 40)
  nextBox:Show()
end

-- Find the profession window: known names first, then any big shown frame
-- whose name mentions professions or trade skills.
local KNOWN_FRAMES = { "ProfessionsBookFrame", "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }
local function findTradeFrame()
  for _, name in ipairs(KNOWN_FRAMES) do
    local f = _G[name]
    if f and f.IsShown and f:IsShown() then return f end
  end
end

-- The profession buttons down the right side: shown, roughly square buttons
-- just outside the window's right edge. Returns the lowest one and the gap
-- between one button's bottom and the next one's top.
local function tabScore(b)
  local n = 0
  if b:GetObjectType() == "CheckButton" then n = n + 2 end
  if b.Icon and b.SetChecked then n = n + 3 end -- the game's side tab template
  if b.GetNormalTexture and b:GetNormalTexture() then n = n + 1 end
  return n
end
local function isSideTab(b)
  return b.Icon and b.SetChecked and b.SetCustomOnMouseUpHandler and true or false
end
local function findSideButtons(f)
  local right, top, bottom = f:GetRight(), f:GetTop(), f:GetBottom()
  if not (right and top and bottom) then return end
  local found, tabs = {}, {}
  local function consider(b)
    if b == tradeTab or b:GetParent() == tradeTab or not b:IsVisible() then return end
    local l, t, w, h = b:GetLeft(), b:GetTop(), b:GetWidth(), b:GetHeight()
    if not (l and t and w and h) then return end
    if isSideTab(b) then
      -- made from the game's side tab template: no guessing needed
      if l >= right - 40 then tabs[#tabs + 1] = b end
      return
    end
    local ot = b:GetObjectType()
    if ot == "Frame" then
      if not b:IsMouseEnabled() then return end
    elseif ot ~= "Button" and ot ~= "CheckButton" then
      return
    end
    if l >= right - 12 and l <= right + 40 and t <= top + 5 and t >= bottom and w >= 24 and w <= 110 and math.abs(w - h) <= 14 then
      found[#found + 1] = b
    end
  end
  local function walk(frame, depth)
    for _, c in ipairs({ frame:GetChildren() }) do
      -- some frames can't be measured by addons: skip those
      if not c:IsForbidden() then
        pcall(consider, c)
        if depth < 6 then walk(c, depth + 1) end
      end
    end
  end
  walk(f, 1)
  if #tabs > 0 then found = tabs end
  if #found == 0 then return end
  table.sort(found, function(a, b) return a:GetTop() > b:GetTop() end)
  -- a tab and a button inside it count once: keep the real tab of each row
  local rows = {}
  for _, b in ipairs(found) do
    local prev = rows[#rows]
    if prev and math.abs(prev:GetTop() - b:GetTop()) < 12 then
      local sb, sp = tabScore(b), tabScore(prev)
      if sb > sp or (sb == sp and b:GetWidth() > prev:GetWidth()) then rows[#rows] = b end
    else
      rows[#rows + 1] = b
    end
  end
  local last = rows[#rows]
  local gap = 2
  if #rows >= 2 then gap = math.max(0, rows[#rows - 1]:GetBottom() - last:GetTop()) end
  return last, gap
end

-- Copy the native tab's frame art (the border drawn outside its click area)
-- so ours is the same size and look; the icon slot gets our icon.
local artPool = {}
local function cloneArt(src, k)
  for _, t in ipairs(artPool) do t:Hide() end
  local l, t = src:GetLeft(), src:GetTop()
  local bw, bh = src:GetWidth(), src:GetHeight()
  local normal = src.GetNormalTexture and src:GetNormalTexture()
  local skip = {}
  for _, fn in ipairs({ "GetHighlightTexture", "GetCheckedTexture", "GetPushedTexture", "GetDisabledTexture" }) do
    local x = src[fn] and src[fn](src)
    if x then skip[x] = true end
  end
  local n, iconRect = 0
  for _, r in ipairs({ src:GetRegions() }) do
    if r:GetObjectType() == "Texture" and r:IsShown() and not skip[r] then
      local rl, rt, rw, rh = r:GetLeft(), r:GetTop(), r:GetWidth(), r:GetHeight()
      if rl and rt and rw and rw > 0 then
        local iconLike = math.abs(rw - bw) <= 4 and math.abs(rh - bh) <= 4
        if r == normal or iconLike then
          iconRect = iconRect or { (rl - l) * k, (rt - t) * k, rw * k, rh * k }
        elseif rw > bw and rh > bh then
          n = n + 1
          local c = artPool[n] or tradeTab:CreateTexture()
          artPool[n] = c
          c:SetDrawLayer(r:GetDrawLayer())
          local atlas = r.GetAtlas and r:GetAtlas()
          if atlas then
            c:SetAtlas(atlas)
          else
            c:SetTexture(r:GetTexture())
            c:SetTexCoord(r:GetTexCoord())
          end
          c:SetVertexColor(r:GetVertexColor())
          c:SetBlendMode(r:GetBlendMode())
          c:SetAlpha(r:GetAlpha())
          c:ClearAllPoints()
          c:SetPoint("TOPLEFT", tradeTab, "TOPLEFT", (rl - l) * k, (rt - t) * k)
          c:SetSize(rw * k, rh * k)
          c:Show()
        end
      end
    end
  end
  ttIcon:ClearAllPoints()
  ttHL:ClearAllPoints()
  if iconRect then
    ttIcon:SetPoint("TOPLEFT", tradeTab, "TOPLEFT", iconRect[1], iconRect[2])
    ttIcon:SetSize(iconRect[3], iconRect[4])
  else
    ttIcon:SetAllPoints()
  end
  ttHL:SetAllPoints(ttIcon)
end

local attachedTo
local attachSoon
local placedOn
local function place(f)
  local last, gap = findSideButtons(f)
  placedOn = last
  tradeTab:ClearAllPoints()
  local s = st()
  if not s.tradeTabV2 then
    -- placement changed: drop spots saved by the old button
    s.tradeTabV2, s.tradeTabPos, s.tradeTabCenter = true, nil, nil
  end
  if buildSkin() then
    for _, t in ipairs(artPool) do t:Hide() end
    local w, h = skin:GetSize()
    if last and w and w > 0 then
      local k = last:GetEffectiveScale() / tradeTab:GetEffectiveScale()
      tradeTab:SetSize(last:GetWidth() * k, last:GetHeight() * k)
      skin:SetScale(tradeTab:GetWidth() / w)
    else
      skin:SetScale(1)
      tradeTab:SetSize(w, h)
    end
  elseif last then
    local k = last:GetEffectiveScale() / tradeTab:GetEffectiveScale()
    tradeTab:SetSize(last:GetWidth() * k, last:GetHeight() * k)
    cloneArt(last, k)
  else
    tradeTab:SetSize(40, 40)
    for _, t in ipairs(artPool) do t:Hide() end
    ttIcon:ClearAllPoints()
    ttIcon:SetAllPoints()
    ttHL:ClearAllPoints()
    ttHL:SetAllPoints()
  end
  if s.tradeTabCenter then
    -- where you dragged it, relative to the window's top-right corner
    tradeTab:SetPoint("CENTER", f, "TOPRIGHT", s.tradeTabCenter[1], s.tradeTabCenter[2])
  elseif last then
    -- straight under the last tab, same spacing as the others
    tradeTab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
  else
    tradeTab:SetPoint("CENTER", f, "TOPRIGHT", 30, -(f:GetHeight() * 0.62))
  end
  nextBox:ClearAllPoints()
  nextBox:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
end

local function attach()
  local f = findTradeFrame()
  if not f then return end
  if attachedTo ~= f then
    attachedTo = f
    tradeTab:SetParent(f)
    nextBox:SetParent(f)
    if not f.nodewalkerHooked then
      f.nodewalkerHooked = true
      f:HookScript("OnHide", function() tradeTab:Hide(); nextBox:Hide() end)
      f:HookScript("OnShow", attachSoon)
    end
  end
  tradeTab:SetFrameStrata(f:GetFrameStrata())
  tradeTab:SetFrameLevel(f:GetFrameLevel() + 20)
  nextBox:SetFrameStrata(f:GetFrameStrata())
  tradeTab.placeOn = function() place(f) end
  if not tradeTab.moving then place(f) end
  tradeTab:Show()
  updateNext()
  return true
end

-- The window and its buttons appear a moment after the event (and the first
-- time it has to load), so keep trying for a few seconds.
local poller = CreateFrame("Frame")
poller:Hide()
poller:SetScript("OnUpdate", function(self, dt)
  self.t = self.t + dt
  self.next = self.next - dt
  if self.next > 0 then return end
  self.next = 0.3
  attach()
  if self.t > 4 then self:Hide() end
end)
-- Watch the known windows (cheap): the button follows whichever is open
local watcher = CreateFrame("Frame")
watcher.t = 0
watcher:SetScript("OnUpdate", function(self, dt)
  self.t = self.t + dt
  if self.t < 0.4 then return end
  self.t = 0
  local open
  for _, n in ipairs(KNOWN_FRAMES) do
    local f = _G[n]
    if f and f.IsShown and f:IsShown() then open = f break end
  end
  if not open and attachedTo and attachedTo:IsShown() then open = attachedTo end
  if open then
    if not tradeTab:IsShown() or tradeTab:GetParent() ~= open then
      attach()
    elseif not tradeTab.moving then
      -- tabs come and go as professions change: follow the last one
      self.check = (self.check or 0) + 1
      if self.check >= 3 then
        self.check = 0
        local last = findSideButtons(open)
        if last ~= placedOn then place(open) end
      end
    end
  end
end)

attachSoon = function()
  poller.t, poller.next = 0, 0.1
  poller:Show()
end

NW.On("TRADE_SKILL_SHOW", attachSoon)
NW.On("CRAFT_SHOW", attachSoon)
NW.On("TRADE_SKILL_DATA_SOURCE_CHANGED", attachSoon)
NW.On("TRADE_SKILL_CLOSE", function() poller:Hide() end)
-- K opens the professions book: catch that directly too
for _, fn in ipairs({ "ToggleProfessionsBook", "ToggleProfessionsFrame" }) do
  if type(_G[fn]) == "function" then hooksecurefunc(fn, function() attachSoon() end) end
end

-- /nw frame: name the window under the mouse (to help place the button)
function NW.FrameUnderMouse()
  local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
  local f = foci and foci[1]
  local names = {}
  while f and #names < 8 do
    names[#names + 1] = (f.GetName and f:GetName()) or ("<" .. (f.GetObjectType and f:GetObjectType() or "?") .. ">")
    f = f.GetParent and f:GetParent()
  end
  NW.Print("Under the mouse: " .. table.concat(names, " < "))
end
-- the newer profession window loads on demand; hook it as soon as it exists
NW.On("ADDON_LOADED", function(name)
  if name == "Blizzard_Professions" or name == "Blizzard_TradeSkillUI" then
    C_Timer.After(0, function()
      for _, n in ipairs(KNOWN_FRAMES) do
        local f = _G[n]
        if f and not f.nodewalkerShowHook then
          f.nodewalkerShowHook = true
          f:HookScript("OnShow", attachSoon)
        end
      end
    end)
  end
end)
NW.On("TRADE_SKILL_LIST_UPDATE", function() if tradeTab:IsShown() then updateNext() end end)
NW.On("SKILL_LINES_CHANGED", function() if tradeTab:IsShown() then C_Timer.After(0.2, updateNext) end end)

------------------------------------------------------------------------
-- Find a craft: any recipe in the game, for having someone make it for you
------------------------------------------------------------------------
do
  local fpage = UI.AddTab("find", "Find a craft", function() NW.RefreshFind() end, nil, function()
    if NW.findDirty then NW.findDirty = false NW.RefreshFind() end
  end)
  local LIST_X, LIST_W2 = 16, 640
  local ROW_H2, ROWS2 = 24, 19
  local DET_X = LIST_X + LIST_W2 + 16
  local DET_W = 1020 - DET_X - 16
  local text, results, offset2, chosen = "", {}, 0, nil

  -- search
  local box = CreateFrame("EditBox", nil, fpage, "BackdropTemplate")
  box:SetSize(320, 26)
  box:SetPoint("TOPLEFT", LIST_X, -8)
  UI.Flat(box, S.sunk, S.edge)
  box:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
  box:SetTextColor(unpack(S.text))
  box:SetTextInsets(26, 24, 0, 0)
  box:SetAutoFocus(false)
  box:SetMaxLetters(40)
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetSize(14, 14)
  icon:SetPoint("LEFT", 7, 0)
  icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  icon:SetVertexColor(unpack(S.dim))
  local hint = UI.Text(box, 13, S.disabled)
  hint:SetPoint("LEFT", 26, 0)
  hint:SetText("What do you want made?")
  local clear = UI.Close(box, function() box:SetText(""); box:ClearFocus() end)
  clear:SetSize(18, 18)
  clear:SetPoint("RIGHT", -3, 0)
  clear:Hide()
  local count = UI.Text(fpage, 12, S.dim)
  count:SetPoint("LEFT", box, "RIGHT", 14, 0)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(S.gold)) end)
  box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(S.edge)) end)
  box:SetScript("OnTextChanged", function(self)
    local t = (self:GetText() or ""):lower()
    hint:SetShown(t == "")
    clear:SetShown(t ~= "")
    if t ~= text then text = t; offset2 = 0; NW.RefreshFind() end
  end)

  -- columns
  local COLS = { { "Recipe", 30, "LEFT" }, { "Profession", 262, "LEFT" }, { "Materials", 470, "RIGHT" },
    { "To buy", 545, "RIGHT" }, { "On AH", LIST_W2 - 14, "RIGHT" } }
  local listBox = UI.Box(fpage, LIST_W2, ROWS2 * ROW_H2 + 4)
  listBox:SetPoint("TOPLEFT", LIST_X, -60)
  for _, c in ipairs(COLS) do
    local t = UI.Text(fpage, 11, S.dim, c[3])
    if c[3] == "RIGHT" then t:SetPoint("BOTTOMRIGHT", listBox, "TOPLEFT", c[2], 4)
    else t:SetPoint("BOTTOMLEFT", listBox, "TOPLEFT", c[2], 4) end
    t:SetText(c[1])
  end
  local empty = UI.Text(listBox, 13, S.dim, "CENTER")
  empty:SetPoint("CENTER")
  empty:SetWidth(LIST_W2 - 60)

  local rows = {}
  local function cell(row, x, w, justify, size, color)
    local t = UI.Text(row, size or 12, color or S.text, justify)
    if justify == "RIGHT" then t:SetPoint("RIGHT", row, "LEFT", x, 0) else t:SetPoint("LEFT", x, 0) end
    t:SetWidth(w)
    t:SetWordWrap(false)
    return t
  end
  for i = 1, ROWS2 do
    local row = CreateFrame("Button", nil, listBox)
    row:SetSize(LIST_W2 - 14, ROW_H2)
    row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW_H2)
    UI.RowStripe(row)
    row:SetStripe(i % 2 == 0)
    UI.RowHighlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 6, 0)
    row.name = cell(row, 30, 226)
    row.prof = cell(row, 262, 110, "LEFT", 11, S.dim)
    row.mats = cell(row, 468, 90, "RIGHT")
    row.buy = cell(row, 543, 72, "RIGHT")
    row.ah = cell(row, LIST_W2 - 16, 90, "RIGHT")
    row:SetScript("OnClick", function(self)
      if not self.r then return end
      if IsShiftKeyDown() and self.r.item then
        local n, ok = itemName(self.r.item)
        if ok and searchAH({ { n, 1 } }) then return end
      end
      chosen = self.r
      NW.RefreshFind()
    end)
    row:SetScript("OnEnter", function(self)
      if self.r and self.r.item then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.r.item)
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = row
  end
  local scroller = makeScroller(listBox, ROWS2 * ROW_H2 + 4, ROWS2, function() return #results end,
    function() return offset2 end, function(v) offset2 = v; NW.RefreshFind() end)
  listBox:EnableMouseWheel(true)
  listBox:SetScript("OnMouseWheel", function(_, d)
    offset2 = math.max(0, math.min(math.max(0, #results - ROWS2), offset2 - d))
    NW.RefreshFind()
  end)

  -- the chosen recipe
  local det = CreateFrame("Frame", nil, fpage)
  det:SetPoint("TOPLEFT", DET_X, -8)
  det:SetSize(DET_W, 530)
  local dHead = UI.Heading(det, "", DET_W)
  dHead:SetPoint("TOPLEFT")
  local dWhere = UI.Text(det, 11, S.dim)
  dWhere:SetPoint("TOPLEFT", dHead, "BOTTOMLEFT", 0, -6)
  dWhere:SetWidth(DET_W)
  dWhere:SetJustifyV("TOP")
  local dTotals = UI.Text(det, 12, S.text)
  dTotals:SetPoint("TOPLEFT", dWhere, "BOTTOMLEFT", 0, -10)
  dTotals:SetWidth(DET_W)
  dTotals:SetJustifyV("TOP")
  dTotals:SetSpacing(4)
  local matBox = UI.Box(det, DET_W, 8 * 30 + 6)
  matBox:SetPoint("TOPLEFT", dTotals, "BOTTOMLEFT", 0, -10)
  local matRows = {}
  for i = 1, 8 do
    local m = CreateFrame("Button", nil, matBox)
    m:SetSize(DET_W - 4, 30)
    m:SetPoint("TOPLEFT", 2, -3 - (i - 1) * 30)
    UI.RowHighlight(m)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(20, 20)
    m.icon:SetPoint("LEFT", 6, 0)
    m.name = UI.Text(m, 12, S.text)
    m.name:SetPoint("LEFT", m.icon, "RIGHT", 8, 0)
    m.name:SetWidth(DET_W - 120)
    m.name:SetWordWrap(false)
    m.cost = UI.Text(m, 12, S.text, "RIGHT")
    m.cost:SetPoint("RIGHT", -8, 0)
    m:SetScript("OnEnter", function(self)
      if not self.id then return end
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      pcall(GameTooltip.SetItemByID, GameTooltip, self.id)
      GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:SetScript("OnClick", function(self)
      if self.id and IsShiftKeyDown() then
        local n, ok = itemName(self.id)
        if ok then searchAH({ { n, math.max(1, self.buy or 1) } }) end
      end
    end)
    matRows[i] = m
  end
  local need = {}
  local btnMats = UI.Button(det, "Search what I need in Auctionator", DET_W, function()
    local items = {}
    for _, e in ipairs(need) do
      if e.buy > 0 and e.src ~= "vendor" then
        local n, ok = itemName(e.id)
        if ok then items[#items + 1] = { n, e.buy } end
      end
    end
    if #items > 0 and not searchAH(items) then NW.Print("Open the auction house with Auctionator to search for the list.") end
  end, 28, "primary")
  btnMats:SetPoint("TOPLEFT", matBox, "BOTTOMLEFT", 0, -10)
  local btnMade = UI.Button(det, "Search it ready-made", DET_W, function()
    if not (chosen and chosen.item) then return end
    local n, ok = itemName(chosen.item)
    if ok and not searchAH({ { n, 1 } }) then NW.Print("Open the auction house with Auctionator to search for it.") end
  end, 26)
  btnMade:SetPoint("TOPLEFT", btnMats, "BOTTOMLEFT", 0, -6)
  local dNote = UI.Text(det, 11, S.dim)
  dNote:SetPoint("TOPLEFT", btnMade, "BOTTOMLEFT", 0, -12)
  dNote:SetWidth(DET_W)
  dNote:SetJustifyV("TOP")
  dNote:SetText("|cffd6b266Materials|r  all of them at today's prices\n|cffd6b266To buy|r  what's left after your bags\n|cffd6b266On AH|r  buying the finished item instead\n\n|cffd6b266Shift-click|r anything to search the auction house.")

  local function drawDetail()
    local r = chosen
    det:SetShown(true)
    if not r then
      dHead.text:SetText("Find a craft")
      dWhere:SetText("")
      dTotals:SetText("")
      for _, m in ipairs(matRows) do m:Hide() end
      matBox:Hide() btnMats:Hide() btnMade:Hide()
      dNote:ClearAllPoints()
      dNote:SetPoint("TOPLEFT", dWhere, "BOTTOMLEFT", 0, -16)
      return
    end
    matBox:Show() btnMats:Show()
    dNote:ClearAllPoints()
    dNote:SetPoint("TOPLEFT", btnMade, "BOTTOMLEFT", 0, -12)
    dHead.text:SetText(r.name)
    local prof = NW.PROF_BY_KEY[r.findKey]
    local req = r.orange or r.yellow
    dWhere:SetText(("|cffd6b266%s|r%s\n%s"):format(prof and prof.name or "", req and req > 0 and (" " .. req) or "",
      sourceText(r.findKey, r, NW.ProfSkill(r.findKey)) or ""))
    wipe(need)
    local full, toBuy, unpriced, haveAny = 0, 0, false, false
    for i, m in ipairs(matRows) do
      local re = r.reagents[i]
      if re then
        local price, src = NW.Price(re[1])
        if src == "est" then price = nil end
        local have = NW.ItemCount(re[1]) or 0
        local buy = math.max(0, re[2] - have)
        local cost = price and price * buy
        if price and src == "ah" and buy > 0 and NW.FillCost then
          local fill, got = NW.FillCost(re[1], buy)
          if fill and got > 0 then cost = fill + (buy - got) * price end
        end
        need[#need + 1] = { id = re[1], buy = buy, src = src }
        if price then full = full + price * re[2] else unpriced = true end
        if buy > 0 then if cost then toBuy = toBuy + cost else unpriced = true end end
        if have > 0 then haveAny = true end
        m.id, m.buy = re[1], buy
        m.icon:SetTexture(itemIcon(re[1]))
        local hv = have > 0 and ("|cff94ba78%d|r/"):format(math.min(have, re[2])) or ""
        m.name:SetText(("%s%d  %s"):format(hv, re[2], (itemName(re[1]))))
        m.cost:SetText(buy == 0 and "|cff94ba78have|r" or cost and (NW.Money(cost, "mid") .. (src == "vendor" and " |cff938c80v|r" or ""))
          or "|cff938c80?|r")
        m:Show()
      else
        m.id = nil
        m:Hide()
      end
    end
    local q = unpriced and " |cffd17665+?|r" or ""
    local ah
    if r.item then ah = select(2, NW.PriceParts(r.item)) end
    local lines = {
      ("|cff938c80Materials|r  %s%s"):format(NW.Money(full, "mid"), q),
      ("|cff938c80To buy|r  |cffffffff%s|r%s"):format(NW.Money(toBuy, "mid"), q),
    }
    if ah then lines[#lines + 1] = ("|cff938c80On AH|r  %s"):format(NW.Money(ah * (r.yield or 1), "mid")) end
    if (r.yield or 1) > 1 then lines[#lines + 1] = ("|cff938c80Makes %d|r"):format(r.yield) end
    dTotals:SetText(table.concat(lines, "\n"))
    btnMats:SetEnabled(toBuy > 0)
    btnMade:SetShown(r.item ~= nil)
  end

  function NW.RefreshFind()
    if not fpage:IsShown() then return end
    -- matches: name first, then anything made from a material with that name
    wipe(results)
    if text ~= "" then
      local byMat = {}
      local function hit(t) return t and t:lower():find(text, 1, true) ~= nil end
      for _, r in ipairs(allRecipes()) do
        if hit(r.name) then results[#results + 1] = r
        else
          for _, re in ipairs(r.reagents) do if hit((itemName(re[1]))) then byMat[#byMat + 1] = r break end end
        end
      end
      local function bySkill(a, b)
        local ra, rb = a.orange or a.yellow or 999, b.orange or b.yellow or 999
        if ra ~= rb then return ra < rb end
        return a.name < b.name
      end
      table.sort(results, bySkill)
      table.sort(byMat, bySkill)
      for _, r in ipairs(byMat) do results[#results + 1] = r end
    end
    offset2 = math.max(0, math.min(offset2, #results - ROWS2))
    count:SetText(text ~= "" and ("%d found in every profession"):format(#results) or "")
    empty:SetText(text == "" and "Type an item, such as Crusader or Runecloth Bag."
      or #results == 0 and "No recipe matches your search." or "")
    for i, row in ipairs(rows) do
      local r = results[i + offset2]
      row.r = r
      if r then
        row:Show()
        row:SetSelected(r == chosen)
        row.icon:SetTexture(r.icon or recipeIcon(r))
        row.name:SetText(r.name)
        local prof = NW.PROF_BY_KEY[r.findKey]
        local req = r.orange or r.yellow
        row.prof:SetText((prof and prof.name or "") .. (req and req > 0 and (" " .. req) or ""))
        local full, toBuy, unpriced = matsCost(r)
        local q = unpriced and "|cffd17665+?|r" or ""
        row.mats:SetText(NW.Money(full, "mid") .. q)
        row.buy:SetText(toBuy < full and (NW.Money(toBuy, "mid") .. q) or "|cff938c80-|r")
        local ah
        if r.item then ah = select(2, NW.PriceParts(r.item)) end
        row.ah:SetText(ah and NW.Money(ah * (r.yield or 1), "mid") or "|cff938c80-|r")
      else
        row:Hide()
      end
    end
    scroller:Update()
    drawDetail()
  end
  NW.On("BAG_UPDATE_DELAYED", function() NW.findDirty = true end)
  NW.On("GET_ITEM_INFO_RECEIVED", function() NW.findDirty = true end)
end
