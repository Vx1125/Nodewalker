-- Nodewalker: raid consumables by spec, with what you have and what each costs
local ADDON, NW = ...
local UI, S = NW.UI, NW.STYLE

-- { item, effect, tier }: tier "full" or "budget" shows on that list only.
-- Lists follow the WoW Forever guides (Method, Wowhead); see README.
NW.CONSUMES = {
  {
    key = "paladin-holy", class = "PALADIN", label = "Holy Paladin",
    groups = {
      { "Flask", {
        { 13511, "+2000 mana", "full" },
      } },
      { "Elixirs", {
        { 250333, "+40 healing" },
        { 250341, "20 mana / 5s" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 9179, "+25 Int", "budget" },
      } },
      { "Food", {
        { 249870, "+44 healing", "full" },
        { 249869, "+33 healing", "budget" },
      } },
      { "Weapon oil", {
        { 20749, "+36 healing, 1% spell crit", "full" },
        { 20748, "15 mana / 5s, +30 healing", "full" },
        { 20747, "10 mana / 5s, +20 healing", "budget" },
      } },
      { "Potions", {
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
        { 250949, "+88 healing for 30s", "full" },
        { 18253, "1440-1760 health and mana", "full" },
      } },
    },
  },
}

local function st() return NW.db.settings end
local refresh
local page = UI.AddTab("consumes", "Consumes", function() refresh() end)
NW.On("GET_ITEM_INFO_RECEIVED", function() if page:IsShown() then page.dirty = true end end)
NW.On("BAG_UPDATE_DELAYED", function() if page:IsShown() then page.dirty = true end end)
page:SetScript("OnUpdate", function(self) if self.dirty then self.dirty = false refresh() end end)

local LEFT_W, RIGHT_W, ROW_H, MAX_ROWS = 610, 330, 24, 20
local selectedItem

local head = UI.Heading(page, "", LEFT_W)
head:SetPoint("TOPLEFT", 24, -8)
local budget = UI.Check(page, "Budget", function() return st().consumeBudget end, function(v)
  st().consumeBudget = v
  refresh()
end)
budget:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
local total = UI.Text(page, 12, S.dim, "RIGHT")
total:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -12)

local listBox = UI.Box(page, LEFT_W, MAX_ROWS * ROW_H + 2)
listBox:SetPoint("TOPLEFT", budget, "BOTTOMLEFT", 0, -8)

-- Right side: the selected consumable
local right = CreateFrame("Frame", nil, page)
right:SetSize(RIGHT_W, 480)
right:SetPoint("TOPLEFT", head, "TOPRIGHT", 28, 0)
local rHead = UI.Heading(right, "", RIGHT_W)
rHead:SetPoint("TOPLEFT")
local detail = UI.Text(right, 12, S.text)
detail:SetPoint("TOPLEFT", rHead, "BOTTOMLEFT", 0, -8)
detail:SetWidth(RIGHT_W)
detail:SetJustifyV("TOP")
detail:SetSpacing(4)
local searchBtn

local function itemName(id)
  local n = NW.ItemName(id)
  if n then return n, true end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return "item " .. id, false
end

local function currentList()
  local _, class = UnitClass("player")
  local pick = st().consumeSpec
  local first, mine
  for _, l in ipairs(NW.CONSUMES) do
    first = first or l
    if l.key == pick then return l end
    if l.class == class then mine = mine or l end
  end
  return mine or first
end

local rows, shown = {}, {}
for i = 1, MAX_ROWS do
  local row = CreateFrame("Button", nil, listBox)
  row:SetSize(LEFT_W - 2, ROW_H)
  row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
  UI.RowHighlight(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 8, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, 12, S.text)
  row.name:SetPoint("LEFT", 34, 0)
  row.name:SetWidth(210)
  row.name:SetWordWrap(false)
  row.effect = UI.Text(row, 11, S.dim)
  row.effect:SetPoint("LEFT", 250, 0)
  row.effect:SetWidth(190)
  row.effect:SetWordWrap(false)
  row.have = UI.Text(row, 12, S.text, "RIGHT")
  row.have:SetPoint("RIGHT", row, "LEFT", 500, 0)
  row.price = UI.Text(row, 12, S.text, "RIGHT")
  row.price:SetPoint("RIGHT", -10, 0)
  row:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    if not self.item then return end
    if IsShiftKeyDown() then
      -- at the auction house it searches; otherwise it links in chat
      local n, ok = itemName(self.item)
      if NW.AHOpen() then
        if ok then NW.SearchAH({ { n, 1 } }) end
      else
        NW.ChatLink(self.item, nil, true)
      end
      return
    end
    selectedItem = self.item
    refresh()
  end)
  rows[i] = row
end

searchBtn = UI.Button(page, "Search missing in Auctionator", RIGHT_W, function()
  local items = {}
  for _, e in ipairs(shown) do
    if e.id and e.have == 0 then
      local n, ok = itemName(e.id)
      if ok then items[#items + 1] = { n, 1 } end
    end
  end
  NW.SearchAH(items)
end)
searchBtn:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", 28, 0)

local function drawDetail()
  local id = selectedItem
  if not id then
    rHead.text:SetText("Consumable")
    detail:SetText("|cff94949aClick one for its prices and materials.|r")
    return
  end
  rHead.text:SetText((itemName(id)))
  local lines = {}
  local vendor, ah, craft = NW.PriceParts(id)
  if ah then lines[#lines + 1] = ("|cff94949aAuction|r  %s"):format(NW.Money(ah)) end
  if vendor then lines[#lines + 1] = ("|cff94949aVendor|r  %s"):format(NW.Money(vendor)) end
  if craft then lines[#lines + 1] = ("|cff94949aMake it|r  %s"):format(NW.Money(craft)) end
  local r, key = NW.RecipeFor(id)
  if r then
    local prof = NW.PROF_BY_KEY[key]
    local req = r.orange or r.yellow
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("|cffe8c46a%s|r%s"):format(prof and prof.name or "", req and req > 0 and (" " .. req) or "")
    for _, re in ipairs(r.reagents) do
      local p = NW.Price(re[1])
      lines[#lines + 1] = ("%d  %s  |cff94949a%s|r"):format(re[2], (itemName(re[1])), p and NW.Money(p * re[2], true) or "?")
    end
    if (r.yield or 1) > 1 then lines[#lines + 1] = ("|cff94949aMakes %d|r"):format(r.yield) end
  end
  detail:SetText(table.concat(lines, "\n"))
end

refresh = function()
  if not page:IsShown() then return end
  local list = currentList()
  head.text:SetText(list.label)
  budget:Refresh()
  local wantBudget = st().consumeBudget
  wipe(shown)
  local sum, missing = 0, 0
  for _, g in ipairs(list.groups) do
    shown[#shown + 1] = { header = g[1] }
    for _, c in ipairs(g[2]) do
      local tier = c[3]
      if not tier or (tier == "budget") == (wantBudget and true or false) then
        local price, src = NW.Price(c[1])
        if src == "est" then price = nil end
        local have = NW.ItemCount(c[1]) or 0
        shown[#shown + 1] = { id = c[1], effect = c[2], price = price, have = have }
        if price then sum = sum + price end
        if have == 0 then missing = missing + 1 end
      end
    end
  end
  for i, row in ipairs(rows) do
    local e = shown[i]
    if not e then
      row:Hide()
    elseif e.header then
      row:Show()
      row.item = nil
      row:SetSelected(false)
      row.icon:Hide()
      row.name:SetText("|cffe8c46a" .. e.header .. "|r")
      row.effect:SetText("")
      row.have:SetText("")
      row.price:SetText("")
    else
      row:Show()
      row.item = e.id
      row:SetSelected(e.id == selectedItem)
      row.icon:Show()
      row.icon:SetTexture(NW.ItemIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetText((itemName(e.id)))
      row.effect:SetText(e.effect)
      row.have:SetText(e.have > 0 and ("|cff8cdb7a%d|r"):format(e.have) or "|cffeb5c4d0|r")
      row.price:SetText(e.price and NW.Money(e.price, true) or "|cff94949a?|r")
    end
  end
  total:SetText(("One of each %s  ·  Missing %d"):format(NW.Money(sum, true), missing))
  searchBtn:SetEnabled(missing > 0)
  drawDetail()
end
