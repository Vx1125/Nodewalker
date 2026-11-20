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
local LIST_W = 196
local list = UI.Box(page, LIST_W, #NW.PROFS * 34 + 10)
list:SetPoint("TOPLEFT", 16, -8)
local profRows = {}
for i, p in ipairs(NW.PROFS) do
  local b = CreateFrame("Button", nil, list)
  b:SetSize(LIST_W - 2, 34)
  b:SetPoint("TOPLEFT", 1, -5 - (i - 1) * 34)
  UI.RowHighlight(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(22, 22)
  b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexture(p.icon)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = UI.Text(b, 12, S.text)
  b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
  b.name:SetText(p.name)
  b.skill = UI.Text(b, 11, S.dim, "RIGHT")
  b.skill:SetPoint("RIGHT", -8, 0)
  b.prof = p
  b:SetScript("OnClick", function() selected = p.key; st().profSelected = p.key; refresh() end)
  profRows[i] = b
end
local mode = "plan" -- plan | missing
local modeBtns = {}
modeBtns.plan = UI.Button(page, "Leveling plan", LIST_W, function() mode = "plan"; refresh() end, 24)
modeBtns.plan:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)
modeBtns.missing = UI.Button(page, "Recipes I'm missing", LIST_W, function() mode = "missing"; refresh() end, 24)
modeBtns.missing:SetPoint("TOPLEFT", modeBtns.plan, "BOTTOMLEFT", 0, -4)
local listNote = UI.Text(page, 11, S.dim)
listNote:SetPoint("TOPLEFT", modeBtns.missing, "BOTTOMLEFT", 2, -8)
listNote:SetWidth(LIST_W)
listNote:SetText("Open your profession window once so Nodewalker sees which recipes you know.")

------------------------------------------------------------------------
-- Middle: header, options, steps
------------------------------------------------------------------------
local MID_X, MID_W = 16 + LIST_W + 16, 488
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
hSkill:SetWidth(MID_W - 50)
local hCost = UI.Text(mid, 15, S.text, "RIGHT")
hCost:SetPoint("TOPRIGHT", 0, -2)
local hCostSub = UI.Text(mid, 11, S.dim, "RIGHT")
hCostSub:SetPoint("TOPRIGHT", hCost, "BOTTOMRIGHT", 0, -4)

local optRow = CreateFrame("Frame", nil, mid)
optRow:SetPoint("TOPLEFT", hIconBox, "BOTTOMLEFT", 0, -10)
optRow:SetSize(MID_W, 20)
local opts = {
  UI.Check(optRow, "Use recipes to buy or find", function() return st().planRecipeItems end,
    function(v) st().planRecipeItems = v; NW.InvalidatePlans() end,
    "Lets the plan use recipes from vendors and drops, not just the trainer. Recipes you already know are always used."),
  UI.Check(optRow, "Whole guide from 1", function() return st().planFromStart end,
    function(v) st().planFromStart = v; refresh() end, "Show every step, not just from your current skill."),
  UI.Check(optRow, "Count sale value", function() return st().planSellBack end,
    function(v) st().planSellBack = v; NW.InvalidatePlans() end,
    "Takes half the auction value of what you make off its cost, since not everything sells."),
}
opts[1]:SetPoint("LEFT", 2, 0)
opts[2]:SetPoint("LEFT", 190, 0)
opts[3]:SetPoint("LEFT", 335, 0)

local priceLine = UI.Text(mid, 11, S.dim)
priceLine:SetPoint("TOPLEFT", optRow, "BOTTOMLEFT", 0, -8)
priceLine:SetWidth(MID_W - 186)
priceLine:SetHeight(28)
priceLine:SetJustifyV("TOP")

-- Search: filters the list below (recipes, materials, zones)
local search = CreateFrame("EditBox", nil, mid, "BackdropTemplate")
search:SetSize(176, 24)
search:SetPoint("TOPRIGHT", optRow, "BOTTOMRIGHT", 0, -6)
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

local stepsBox = UI.Box(mid, MID_W, 382)
stepsBox:SetPoint("TOPLEFT", priceLine, "BOTTOMLEFT", 0, -6)
stepsBox:EnableMouseWheel(true)
local STEP_H, STEP_ROWS = 47, 8
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
  bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.02 or 0.045)
  row.range = UI.Text(row, 12, S.gold)
  row.range:SetPoint("TOPLEFT", 8, -7)
  row.range:SetWidth(62)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("TOPLEFT", 72, -4)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, 12, S.text)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(250)
  row.name:SetWordWrap(false)
  row.crafts = UI.Text(row, 12, S.text, "RIGHT")
  row.crafts:SetPoint("TOPRIGHT", -96, -7)
  row.cost = UI.Text(row, 12, S.text, "RIGHT")
  row.cost:SetPoint("TOPRIGHT", -8, -7)
  row.mats = UI.Text(row, 11, S.dim)
  row.mats:SetPoint("TOPLEFT", 72, -27)
  row.mats:SetWidth(MID_W - 92)
  row.mats:SetWordWrap(false)
  row:SetScript("OnEnter", function(self)
    local stp = self.step
    if not (stp and stp.recipe) then return end
    local r = stp.recipe
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if r.item then GameTooltip:SetItemByID(r.item) elseif r.spell then GameTooltip:SetSpellByID(r.spell) else GameTooltip:SetText(r.name) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Skill-up colours", ("|cffff8040%s|r |cffffff00%d|r |cff40bf40%d|r |cff808080%d|r"):format(
      r.orange or "-", r.yellow, r.green, r.grey), S.dim[1], S.dim[2], S.dim[3])
    GameTooltip:AddDoubleLine("Cost per craft", NW.Money(stp.costEach), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("Expected crafts", stp.crafts, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    local src = r.src == "trainer" and "Trainer" or r.src == "rank" and "Learned with the profession"
      or "Recipe from a vendor or drop"
    GameTooltip:AddDoubleLine("Source", src, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    if stp.needsRecipe then GameTooltip:AddLine("You need this recipe first.", 1, 0.5, 0.25, true) end
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
  bg:SetColorTexture(1, 1, 1, 0.04)
  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetWidth(8)
  thumb:EnableMouse(true)
  local tex = thumb:CreateTexture(nil, "OVERLAY")
  tex:SetPoint("TOPLEFT", 2, 0)
  tex:SetPoint("BOTTOMRIGHT", -2, 0)
  tex:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.55)
  thumb:SetScript("OnEnter", function() tex:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.9) end)
  thumb:SetScript("OnLeave", function() if not thumb.dragging then tex:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.55) end end)
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
    tex:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], self:IsMouseOver() and 0.9 or 0.55)
  end)
  track:SetScript("OnMouseDown", function() setFromCursor() end)
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
local stepScroll = makeScroller(stepsBox, 382, STEP_ROWS, function() return #steps end,
  function() return stepOffset end, function(v) stepOffset = v; redrawSteps() end)
stepsBox:SetScript("OnMouseWheel", function(_, d)
  stepOffset = math.max(0, math.min(math.max(0, #steps - STEP_ROWS), stepOffset - d))
  redrawSteps()
end)

------------------------------------------------------------------------
-- Right: shopping list (crafting) or extra info (gathering)
------------------------------------------------------------------------
local RIGHT_X = MID_X + MID_W + 16
local RIGHT_W = 1020 - RIGHT_X - 16
local right = CreateFrame("Frame", nil, page)
right:SetPoint("TOPLEFT", RIGHT_X, -8)
right:SetSize(RIGHT_W, 530)
local rHead = UI.Heading(right, "Shopping list", RIGHT_W)
rHead:SetPoint("TOPLEFT")
local rTotal = UI.Text(right, 12, S.text)
rTotal:SetPoint("TOPLEFT", rHead, "BOTTOMLEFT", 0, -6)
rTotal:SetWidth(RIGHT_W)
local shopBox = UI.Box(right, RIGHT_W, 318)
shopBox:SetPoint("TOPLEFT", rTotal, "BOTTOMLEFT", 0, -8)
shopBox:EnableMouseWheel(true)
local SHOP_H, SHOP_ROWS = 26, 12
local shopRows, shop, shopOffset = {}, {}, 0
for i = 1, SHOP_ROWS do
  local row = CreateFrame("Button", nil, shopBox)
  row:SetSize(RIGHT_W - 8, SHOP_H)
  row:SetPoint("TOPLEFT", 1, -2 - (i - 1) * SHOP_H)
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
    GameTooltip:SetItemByID(e.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Need", e.need, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    if e.have > 0 then GameTooltip:AddDoubleLine("In your bags and bank", e.have, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    local srcText = ({ ah = "Auction house (Auctionator)", vendor = "Vendor", craft = "Cheaper to make", est = "Estimate (no price yet)" })[e.src or ""] or "No price"
    GameTooltip:AddDoubleLine("Price each", NW.Money(e.price), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("From", srcText, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
    local age = e.src == "ah" and NW.PriceAge(e.id)
    if age then GameTooltip:AddDoubleLine("Last scanned", age == 0 and "today" or (age .. " days ago"), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  shopRows[i] = row
end
local drawShop
local shopScroll = makeScroller(shopBox, 318, SHOP_ROWS, function() return #shop end,
  function() return shopOffset end, function(v) shopOffset = v; drawShop() end)
shopBox:SetScript("OnMouseWheel", function(_, d)
  shopOffset = math.max(0, math.min(math.max(0, #shop - SHOP_ROWS), shopOffset - d))
  drawShop()
end)
local searchBtn = UI.Button(right, "Search all in Auctionator", RIGHT_W, function()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local terms = {}
  for _, e in ipairs(shop) do
    if e.buy > 0 and e.src ~= "vendor" then
      local n, ok = itemName(e.id)
      if ok then terms[#terms + 1] = n end
    end
  end
  if api and (api.MultiSearchExact or api.MultiSearch) and #terms > 0 then
    pcall(api.MultiSearchExact or api.MultiSearch, ADDON, terms)
  else
    NW.Print("Open the auction house with Auctionator to search for the list.")
  end
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
-- Drawing: crafting
------------------------------------------------------------------------
local function matsText(r)
  local parts = {}
  for _, re in ipairs(r.reagents) do
    parts[#parts + 1] = re[2] .. " " .. (itemName(re[1]))
  end
  return table.concat(parts, ", ") .. " each"
end

local function rankNote(key, from)
  local rank, max = NW.ProfSkill(key)
  if not rank then return "" end
  for _, r in ipairs(NW.RANKS) do
    if max and max < r.cap and r.skill then
      if rank >= r.skill then
        return ("  ·  |cffe8c46aTrain %s now|r (cap %d)"):format(r.name, max)
      end
      return ("  ·  train %s at skill %d, level %d"):format(r.name, r.skill, r.level)
    end
  end
  return ""
end

drawSteps = function()
  local rank = NW.ProfSkill(selected) or 0
  for i, row in ipairs(stepRows) do
    local stp = steps[i + stepOffset]
    row.step = stp
    row.bracket = nil
    row.missingRecipe = nil
    if stp then
      row:Show()
      row:SetSelected(rank >= stp.from and rank < stp.to)
      row.range:SetText(("%d-%d"):format(stp.from, stp.to))
      if stp.recipe then
        local r = stp.recipe
        row.icon:SetTexture(recipeIcon(r))
        row.icon:Show()
        row.name:SetText(("|cff%s%s|r"):format(colorFor(r, stp.from), r.name))
        row.crafts:SetText("x" .. stp.crafts)
        row.cost:SetText(NW.Money(stp.cost, true) .. (stp.unknown > 0 and " |cffeb5c4c?|r" or ""))
        local tag = stp.needsRecipe and "|cffff8040needs recipe|r  ·  " or ""
        if stp.rankUp then
          tag = ("|cffe8c46aTrain %s first|r (level %d)  ·  "):format(stp.rankUp.name, stp.rankUp.level) .. tag
        end
        row.mats:SetText(tag .. matsText(r))
      else
        row.icon:Hide()
        row.name:SetText("|cffeb5c4cNo recipe in the data covers this range|r")
        row.crafts:SetText("")
        row.cost:SetText("")
        row.mats:SetText("Tick \"Use recipes to buy or find\", or level with anything that is still yellow.")
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
    local e = shop[i + shopOffset]
    row.entry = e
    if e then
      row:Show()
      row.icon:SetTexture(itemIcon(e.id))
      local have = e.have > 0 and ("|cff8cdb7a%d|r/"):format(math.min(e.have, e.need)) or ""
      row.name:SetText(("%s%d  %s"):format(have, e.need, (itemName(e.id))))
      local tag = e.src == "vendor" and " |cff94949av|r" or e.src == "est" and " |cffeb5c4c~|r" or ""
      row.cost:SetText((e.buy == 0 and "|cff8cdb7ahave|r") or (NW.Money(e.cost, true) .. tag))
    else
      row:Hide()
    end
  end
end

-- The list keeps its scroll position unless you switch profession, view or search
local viewChanged, lastView = true, nil
local function clampOffsets()
  stepOffset = math.max(0, math.min(stepOffset, math.max(0, #steps - STEP_ROWS)))
  shopOffset = math.max(0, math.min(shopOffset, math.max(0, #shop - SHOP_ROWS)))
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
  if from >= 300 then
    steps = {}
    stepsEmpty:SetText("You've reached 300. Nothing left to level.")
    drawSteps()
    hCost:SetText("")
    hCostSub:SetText("")
    rTotal:SetText("")
    shop = {}
    drawShop()
    return
  end
  local plan = NW.BuildPlan(p.key, from, 300)
  steps = filter(plan.steps, stepMatches)
  if viewChanged then
    stepOffset = 0
    -- start on the step you're on
    for i, stp in ipairs(steps) do
      if rank and rank >= stp.from and rank < stp.to then stepOffset = math.max(0, math.min(i - 1, #steps - STEP_ROWS)) end
    end
  end
  clampOffsets()
  stepsEmpty:SetText(#steps == 0 and (searchText ~= "" and "Nothing in the plan matches your search." or "No recipes for this profession yet.") or "")
  drawSteps()

  hCost:SetText(NW.Money(plan.total))
  local sub = ("to 300 from %d"):format(from)
  if plan.unknown > 0 then sub = sub .. (" · %d steps without full prices"):format(plan.unknown) end
  -- what bought or found recipes would save
  if not st().planRecipeItems then
    st().planRecipeItems = true
    local alt = NW.BuildPlan(p.key, from, 300)
    st().planRecipeItems = false
    NW.BuildPlan(p.key, from, 300) -- back to this profession's prices
    if alt.total < plan.total * 0.85 then
      sub = sub .. ("\n|cff8cdb7a%s with recipes you buy or find|r"):format(NW.Money(alt.total, true))
    end
  end
  hCostSub:SetText(sub)

  local list, total = NW.ShoppingList(p.key, plan)
  shop = list
  if viewChanged then shopOffset = 0 end
  clampOffsets()
  rTotal:SetText(("%d items  ·  %s to buy"):format(#list, NW.Money(total)))
  drawShop()

  local ah = NW.HasAuctionator()
  priceLine:SetText(ah and "Prices: Auctionator's last scan, vendor prices, and making it yourself when that's cheaper. Rescan the AH to update."
    or "|cffeb5c4cAuctionator isn't loaded:|r using vendor prices and rough estimates. Install or enable it for live prices.")
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
    row.missingRecipe = nil
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

-- Click a bracket: herbs open the Herb Guide; ore builds a route in the best zone
for _, row in ipairs(stepRows) do
  row:SetScript("OnClick", function(self)
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
      local rows = NW.RankZonesForNodes(b.nodes, b.zones)
      local best = rows[1]
      if not (best and best.mapID and best.count > 0) then
        NW.Print("No known ore spots in those zones yet. Import GatherMate2 or mine a few first.")
        return
      end
      local focus = {}
      for _, n in ipairs(b.nodes) do focus[n] = true end
      NW.BuildRoute(best.mapID, function(route)
        NW.Print(("Mining route for %s: %d stops (%d known spots)."):format(best.name, #route.stops, best.count))
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
    lines[#lines + 1] = "|cffe8c46aClick a range|r to open the Herb Guide on the best herb for you there."
  elseif p.key == "mining" then
    lines[#lines + 1] = "|cffe8c46aClick a range|r to build a mining route in the zone where you know the most of those veins."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffe8c46aSmelting skill-ups|r"
    for _, r in ipairs(NW.RECIPES.mining or {}) do
      if r.grey > r.yellow or r.yellow <= 250 then
        lines[#lines + 1] = ("%s  |cffff8040%s|r-|cff808080%d|r"):format(r.name, r.orange or r.yellow, r.grey)
      end
    end
  elseif p.key == "skinning" then
    if rank then
      local maxLevel = rank < 100 and math.floor(rank / 10) + 10 or math.floor(rank / 5)
      lines[#lines + 1] = ("At %d skill you can skin beasts up to |cffe8c46alevel %d|r."):format(rank, maxLevel)
    end
  elseif p.key == "fishing" then
    -- cook what you catch, for the bracket you're in
    local cook = NW.ProfSkill("cooking") or 0
    local fishRank = rank or 1
    local b = steps[1]
    for _, x in ipairs(steps) do if fishRank >= x.from and fishRank < x.to then b = x end end
    lines[#lines + 1] = ("|cffe8c46aCook what you catch|r (Cooking %d)"):format(cook)
    for _, fid in ipairs(b.fish or {}) do
      for _, r in ipairs(NW.CookFish(fid)) do
        local col = cook < r.yellow and "ff8040" or cook < r.green and "ffff00" or cook < r.grey and "40bf40" or "808080"
        if (r.orange or r.yellow) > cook then col = "eb5c4c" end
        lines[#lines + 1] = ("|cff%s%s|r  %s-%d%s"):format(col, r.name, r.orange or r.yellow, r.grey,
          r.src == "recipe" and " |cff94949a(recipe)|r" or "")
      end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cff94949aRed: you need more Cooking. Grey: no more skill-ups.|r"
  end
  infoText:SetText(table.concat(lines, "\n"))
end

------------------------------------------------------------------------
-- Missing recipes: what you don't know yet, and where it comes from
------------------------------------------------------------------------
local RECIPE_PREFIX = {
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
  local sc = NW.db.recipeScan[key]
  return sc and sc[r.name]
end

local function sourceText(key, r, rank)
  local e = r.scanned or scanOf(key, r)
  if r.src == "scan" or (r.src == "recipe" and e and e.source) then
    if e and e.source then
      local merchant = e.source:find("Merchant") or e.source:find("Durotar Supply") or e.source:find("Commerce Authority")
      return (merchant and "|cffe8c46a" or "") .. cleanSource(e.source, true) .. (merchant and "|r" or ""), merchant and "merchant" or "drop"
    end
    if r.src == "scan" then return "Source not listed by the game", "drop" end
  end
  local req = r.orange or r.yellow
  if r.src == "trainer" or r.src == "rank" then
    if not rank then return "Trainer", "dim" end
    if rank >= req then return "|cff8cdb7aTrainer: learn it now|r", "now" end
    return ("Trainer at skill %d"):format(req), "later"
  end
  if isForeverNew(r) then return "|cffe8c46a" .. MERCHANT .. "|r", "merchant" end
  return "Vendor or world drop  ·  click to search the AH", "drop"
end

local missing = {}
local function buildMissing(key)
  local known = NW.db.known[key] or {}
  local rank = NW.ProfSkill(key)
  local out, have = {}, {}
  local scan = NW.db.recipeScan[key]
  for _, r in ipairs(NW.RECIPES[key] or {}) do
    have[r.name] = true
    local e = scan and scan[r.name]
    local learned = known[r.name] or (e and e.learned)
    if not learned then out[#out + 1] = r end
  end
  -- recipes the game lists that Nodewalker's data doesn't have
  for name, e in pairs(scan or {}) do
    if not e.learned and not have[name] then
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

local function drawMissingRows(key)
  local rank = NW.ProfSkill(key)
  for i, row in ipairs(stepRows) do
    local r = steps[i + stepOffset]
    row.step, row.bracket, row.missingRecipe = nil, nil, r
    if r then
      row:Show()
      row:SetSelected(false)
      local req = r.orange or r.yellow
      row.range:SetText(req and tostring(req) or "?")
      row.icon:SetTexture(r.icon or recipeIcon(r))
      row.icon:Show()
      local col = (not rank or not req or rank >= req) and "ffffff" or "eb5c4c"
      row.name:SetText(("|cff%s%s|r"):format(col, r.name))
      row.crafts:SetText("")
      row.cost:SetText("")
      row.mats:SetText((sourceText(key, r, rank)))
    else
      row:Hide()
    end
  end
  stepScroll:Update()
end

local function drawMissing(p)
  steps = filter(buildMissing(p.key), function(r)
    if has(r.name) then return true end
    for _, re in ipairs(r.reagents) do if has((itemName(re[1]))) then return true end end
    return false
  end)
  if viewChanged then stepOffset = 0 end
  clampOffsets()
  local rank = NW.ProfSkill(p.key)
  local scanned = NW.db.known[p.key] and next(NW.db.known[p.key]) ~= nil
  local fullList = NW.db.recipeScan[p.key] and next(NW.db.recipeScan[p.key]) ~= nil
  stepsEmpty:SetText(#steps == 0 and (searchText ~= "" and "No missing recipe matches your search."
    or "You know every recipe Nodewalker has for this profession.") or "")
  drawMissingRows(p.key)
  local counts = { now = 0, later = 0, merchant = 0, drop = 0, dim = 0 }
  for _, r in ipairs(steps) do
    local _, kind = sourceText(p.key, r, rank)
    counts[kind] = counts[kind] + 1
  end
  hCost:SetText(("%d missing"):format(#steps))
  hCostSub:SetText(fullList and "from the game's full recipe list" or scanned and "of the recipes in Nodewalker's data"
    or "|cffeb5c4cOpen your profession window once|r so this knows what you have")
  priceLine:SetText("Trainer recipes you can learn now come first. Hover a recipe for details; click a bought or found one to search the auction house.")
  local lines = {
    ("|cff8cdb7a%d|r to learn at the trainer now"):format(counts.now),
    ("%d at the trainer later"):format(counts.later + counts.dim),
    ("|cffe8c46a%d|r from Merchant's Favor vendors"):format(counts.merchant),
    ("%d from other vendors or drops"):format(counts.drop),
    "",
    "|cffe8c46aTrainers|r",
    TRAINERS[p.key] or "",
    "",
    "|cffe8c46aMerchant's Favor|r",
    "Forever's new recipes are sold at the Durotar Supply and Logistics camp outside the Crossroads (Horde) and the Azeroth Commerce Authority at Three Corners in Redridge (Alliance). Earn Merchant's Favor by filling Waylaid Crates; some recipes need Friendly or Honored reputation from Craftsman's Writs.",
    "",
    fullList and "|cff94949aThe list comes from your profession window, so it has every recipe the game knows about. Open the window again to refresh it.|r"
      or "|cff94949aOpen your profession window to load the game's full recipe list, with where each one comes from.|r",
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
    local r = self.missingRecipe
    if not r or (r.src ~= "recipe" and r.src ~= "scan") then return end
    local term = (RECIPE_PREFIX[selected] or "") .. r.name
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and (api.MultiSearchExact or api.MultiSearch) and AuctionHouseFrame and AuctionHouseFrame:IsShown() then
      pcall(api.MultiSearchExact or api.MultiSearch, ADDON, { term })
    elseif api and (api.MultiSearchExact or api.MultiSearch) and AuctionFrame and AuctionFrame:IsShown() then
      pcall(api.MultiSearchExact or api.MultiSearch, ADDON, { term })
    else
      NW.Print(("Open the auction house to search for \"%s\"."):format(term))
    end
  end)
end

------------------------------------------------------------------------
refresh = function()
  if not page:IsShown() then return end
  selected = selected or st().profSelected
  if not selected then
    -- start on the first profession you have
    for _, p in ipairs(NW.PROFS) do if NW.ProfSkill(p.key) and p.kind == "craft" and not p.secondary then selected = p.key break end end
    selected = selected or "alchemy"
  end
  for _, b in ipairs(profRows) do
    local rank, max = NW.ProfSkill(b.prof.key)
    b.skill:SetText(rank and ("%d/%d"):format(rank, max or 300) or "")
    b.name:SetTextColor(unpack(rank and S.text or S.dim))
    b.icon:SetDesaturated(not rank)
    b:SetSelected(b.prof.key == selected)
  end
  local p = NW.PROF_BY_KEY[selected]
  local vk = selected .. ":" .. mode .. ":" .. searchText
  viewChanged = vk ~= lastView
  lastView = vk
  hIcon:SetTexture(p.icon)
  hName:SetText(p.name)
  local rank, max = NW.ProfSkill(p.key)
  hSkill:SetText((rank and ("Skill %d / %d"):format(rank, max or 300) or "You don't have this profession")
    .. rankNote(p.key))
  NW.SetWindowSubtitle(p.name)

  local isCraft = p.kind == "craft"
  local isMissing = isCraft and mode == "missing"
  modeBtns.plan:SetShown(isCraft)
  modeBtns.missing:SetShown(isCraft)
  modeBtns.plan:SetEnabled(mode ~= "plan")
  modeBtns.missing:SetEnabled(mode ~= "missing")
  optRow:SetShown(isCraft and not isMissing)
  priceLine:SetShown(isCraft)
  shopBox:SetShown(isCraft and not isMissing)
  searchBtn:SetShown(isCraft and not isMissing)
  tips:SetShown(isCraft and not isMissing)
  tips:SetText(NW.PROF_TIPS[p.key] or "")
  rTotal:SetShown(isCraft and not isMissing)
  info:SetShown(not isCraft or isMissing)
  rHead.text:SetText(isMissing and "Where to get them" or isCraft and "Shopping list" or (p.key == "fishing" and "Fishing + Cooking" or "Notes"))
  scrollDraw = isMissing and function() drawMissingRows(p.key) end
    or (not isCraft and function() drawGatherRows(p.key) end) or nil
  if isMissing then drawMissing(p) elseif isCraft then drawCraft(p) else drawGather(p) end
end
NW.RefreshProfessions = function() if page:IsShown() then refresh() end end

function NW.ToggleProfessions() NW.ToggleWindow("profs") end

------------------------------------------------------------------------
-- A Nodewalker tab under the game's profession window, with your next step
------------------------------------------------------------------------
function NW.OpenProfession(key)
  if key then selected = key; st().profSelected = key end
  mode = "plan"
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
tradeTab:SetScript("OnMouseDown", function() ttIcon:SetVertexColor(0.7, 0.7, 0.7) end)
tradeTab:SetScript("OnMouseUp", function() ttIcon:SetVertexColor(1, 1, 1) end)

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
tradeTab:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
  local tag = stp.rankUp and ("  |cffe8c46a(train %s)|r"):format(stp.rankUp.name) or (stp.needsRecipe and "  |cffff8040(needs recipe)|r" or "")
  nextText:SetText(("Next: |cffe8c46a%s|r x%d  to %d%s"):format(stp.recipe.name, math.ceil(left - 0.05), stp.to, tag))
  nextBox:SetWidth(nextText:GetStringWidth() + 40)
  nextBox:Show()
end

-- Find the profession window: known names first, then any big shown frame
-- whose name mentions professions or trade skills.
local KNOWN_FRAMES = { "ProfessionsBookFrame", "ProfessionsFrame", "TradeSkillFrame", "CraftFrame", "SpellBookFrame", "PlayerSpellsFrame" }
local function findTradeFrame()
  for _, name in ipairs(KNOWN_FRAMES) do
    local f = _G[name]
    if f and f.IsShown and f:IsShown() then return f end
  end
  if EnumerateFrames then
    local f = EnumerateFrames()
    while f do
      if f:IsShown() and not f:IsForbidden() and f:GetParent() == UIParent then
        local n = f:GetName()
        if n and (n:find("Profession") or n:find("TradeSkill")) and (f:GetWidth() or 0) > 300 then return f end
      end
      f = EnumerateFrames(f)
    end
  end
end

-- The profession buttons down the right side: shown, roughly square buttons
-- just outside the window's right edge. Returns the lowest one and the gap
-- between one button's bottom and the next one's top.
local function tabScore(b)
  local n = 0
  if b:GetObjectType() == "CheckButton" then n = n + 2 end
  if b.GetNormalTexture and b:GetNormalTexture() then n = n + 1 end
  return n
end
local function findSideButtons(f)
  local right, top, bottom = f:GetRight(), f:GetTop(), f:GetBottom()
  if not (right and top and bottom) then return end
  local found = {}
  local function consider(b)
    if b == tradeTab or not b:IsShown() or b:IsForbidden() then return end
    local ot = b:GetObjectType()
    if ot ~= "Button" and ot ~= "CheckButton" then return end
    local l, t, w, h = b:GetLeft(), b:GetTop(), b:GetWidth(), b:GetHeight()
    if not (l and t) then return end
    if l >= right - 12 and l <= right + 40 and t <= top + 5 and t >= bottom and w >= 24 and w <= 110 and math.abs(w - h) <= 14 then
      found[#found + 1] = b
    end
  end
  local function walk(frame, depth)
    for _, c in ipairs({ frame:GetChildren() }) do
      consider(c)
      if depth < 3 then walk(c, depth + 1) end
    end
  end
  walk(f, 1)
  if #found == 0 and EnumerateFrames then
    local x = EnumerateFrames()
    while x do
      if x:IsVisible() then consider(x) end
      x = EnumerateFrames(x)
    end
  end
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
  local gap = 17
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
  if last then
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
  -- not found by name yet: a slower search every couple of seconds
  if not open and not attachedTo then
    self.slow = (self.slow or 0) + 1
    if self.slow >= 5 then
      self.slow = 0
      open = findTradeFrame()
    end
  end
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
for _, fn in ipairs({ "ToggleProfessionsBook", "ToggleSpellBook", "ToggleProfessionsFrame" }) do
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
