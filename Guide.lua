local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Material Finder (the tab key stays "guide": saved tabs and links keep working)
--
-- Left: categories and search.  Centre: materials.  Right: the selected
-- material, a switch per way to get it, and that way's zones, creatures,
-- vendors or recipes with a map. Herb and ore zone ranking is the old Farm
-- Guide's (rankZones below), unchanged.
------------------------------------------------------------------------
local M, H = NW.Mat, NW.Hunt
local refresh
local page
page = UI.AddTab("guide", "Material Finder", function() refresh() if NW.MaybeImportPrompt then NW.MaybeImportPrompt(page) end end)

local function st() return NW.db.settings end
local DIM = S.HEX.dim
local W = {}      -- widgets, kept in one table (Lua's upvalue limit)
local sel = {}    -- what's selected: cat, id, src, zone, from

------------------------------------------------------------------------
-- Herb and ore zones (the Farm Guide's ranking)
------------------------------------------------------------------------
local KIND = {
  herb = { guide = NW.HERB_GUIDE, skill = "Herbalism", edge = "herbEdge" },
  ore = { guide = NW.ORE_GUIDE, skill = "Mining", edge = "oreEdge" },
  both = { guide = { { "Herbs and ore", "Every herb and ore node your skills and filters allow, ranked by what a loop is worth.", {} } }, edge = "herbEdge" },
}
local function matches(entry, nd, both)
  local name = nd.name
  if both then
    local skill, req = NW.GetSkill(nd.kind), NW.RequiredSkill(name)
    return skill ~= nil and (not req or req <= skill) and NW.NodeWanted(nd, NW.db.settings)
  end
  for _, alt in ipairs(entry[4]) do if alt == name then return true end end
  return false
end

-- Zone name -> map ID, from the game's own map tree
local zoneIDs
local function norm(name) return (name or ""):lower():gsub("^the ", ""):gsub("[^%w]", "") end
local function zoneID(name)
  if not zoneIDs then
    zoneIDs = {}
    local function add(id)
      local info = C_Map.GetMapInfo(id)
      if info and info.name then zoneIDs[norm(info.name)] = zoneIDs[norm(info.name)] or id end
    end
    for _, cont in ipairs({ 1414, 1415, 947, 1945 }) do
      local ok, kids = pcall(C_Map.GetMapChildrenInfo, cont, nil, true)
      if ok and kids then
        for _, k in ipairs(kids) do
          if k.mapType == 3 or (Enum and Enum.UIMapType and k.mapType == Enum.UIMapType.Zone) then add(k.mapID) end
        end
      end
    end
    for id in pairs(NW.db.nodes) do add(id) end
  end
  return zoneIDs[norm(name)]
end
NW.ZoneID = function(name) return zoneID(name) end

local function quickLoop(pts)
  local n = #pts
  if n < 2 then return 0, { 1 } end
  local used, order = { [1] = true }, { 1 }
  local cur, len = 1, 0
  for _ = 2, n do
    local best, bd = nil, math.huge
    local cx, cy = pts[cur][1], pts[cur][2]
    for j = 2, n do
      if not used[j] then
        local dx, dy = pts[j][1] - cx, pts[j][2] - cy
        local d = dx * dx + dy * dy
        if d < bd then best, bd = j, d end
      end
    end
    used[best] = true
    order[#order + 1] = best
    len = len + math.sqrt(bd)
    cur = best
  end
  local dx, dy = pts[cur][1] - pts[1][1], pts[cur][2] - pts[1][2]
  return len + math.sqrt(dx * dx + dy * dy), order
end

local cache = {}
local function totalNodes()
  local n = 0
  for _, list in pairs(NW.db.nodes) do n = n + #list end
  return n
end
local RARE = { ["Black Lotus"] = 0.02, ["Silver Vein"] = 0.15, ["Ooze Covered Silver Vein"] = 0.15, ["Gold Vein"] = 0.15,
  ["Ooze Covered Gold Vein"] = 0.15, ["Truesilver Deposit"] = 0.15, ["Ooze Covered Truesilver Deposit"] = 0.15 }
-- Ranked zones: { mapID, name, note, recommended, count, loop, rate, gold, pts }
local function rankZones(entry, both)
  local sig = totalNodes()
  if both then sig = ("%d:%s:%s"):format(sig, tostring(NW.GetSkill("herb")), tostring(NW.GetSkill("ore"))) end
  local c = cache[entry[1]]
  if c and c.sig == sig then return c.rows end
  local rows, seen = {}, {}
  local function measure(id, name, note, rec)
    local w, h = NW.MapSize(id)
    local pts = {}
    for _, nd in ipairs(NW.db.nodes[id] or {}) do
      if matches(entry, nd, both) then pts[#pts + 1] = { (w and nd.x * w) or nd.x, (h and nd.y * h) or nd.y, nd.x, nd.y, nd.kind, nd.name } end
    end
    -- what one lap is worth at today's prices (about two per node)
    local worth, priced = 0, false
    for _, pt in ipairs(pts) do
      local item = NW.NODE_ITEMS[pt[6]]
      local price, src
      if item and NW.Price then price, src = NW.Price(item) end
      if price and src ~= "est" then worth, priced = worth + price * 2 * (RARE[pt[6]] or 1), true end
    end
    local row = { mapID = id, name = name, note = note, recommended = rec, count = #pts, pts = pts }
    if w and #pts >= 3 then
      row.loop, row.order = quickLoop(pts)
      local minutes = row.loop / NW.MOUNT_YPS / 60
      row.rate = minutes > 0 and #pts / minutes or 0
      if priced and minutes > 0 then row.gold = worth / minutes * 60 end
      row.score = row.rate * math.min(1, #pts / 25)
      if both and row.gold then row.score = row.gold * math.min(1, #pts / 25) end
    end
    rows[#rows + 1] = row
  end
  for _, z in ipairs(entry[3]) do
    local id = zoneID(z[1])
    if id and not seen[id] then
      seen[id] = true
      measure(id, z[1], z[2], true)
    elseif not id then
      rows[#rows + 1] = { name = z[1], note = z[2], recommended = true, count = 0, missing = true, pts = {} }
    end
  end
  for id, list in pairs(NW.db.nodes) do
    if not seen[id] then
      for _, nd in ipairs(list) do
        if matches(entry, nd, both) then
          seen[id] = true
          local info = C_Map.GetMapInfo(id)
          measure(id, info and info.name or ("Map " .. id), nil, false)
          break
        end
      end
    end
  end
  table.sort(rows, function(a, b)
    local sa, sb = a.score or -1, b.score or -1
    if sa ~= sb then return sa > sb end
    if a.count ~= b.count then return a.count > b.count end
    if a.recommended ~= b.recommended then return a.recommended end
    return a.name < b.name
  end)
  cache[entry[1]] = { sig = sig, rows = rows }
  return rows
end

-- A node material as a guide entry: { first node name, tip, zones, every node name }
local entryCache = {}
local function nodeEntry(e)
  if e.id == "both" then return { "Herbs and ore", KIND.both.guide[1][2], {}, {} } end
  if entryCache[e.id] then return entryCache[e.id] end
  local names = M.NodeNames(e.id) or { e.name }
  local zones, seenZ, tip = {}, {}, nil
  for _, n in ipairs(names) do
    for _, g in ipairs(KIND[e.nodeKind].guide) do
      if g[1] == n then
        tip = tip or g[2]
        for _, z in ipairs(g[3]) do
          if not seenZ[z[1]] then seenZ[z[1]] = true; zones[#zones + 1] = z end
        end
      end
    end
  end
  local entry = { names[1], tip or "", zones, names }
  entryCache[e.id] = entry
  return entry
end
local function focusOf(entry)
  local f = {}
  for _, n in ipairs(entry[4]) do f[n] = true end
  return f
end

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------
local LEFT_W, MID_X, MID_W, RIGHT_X = 176, 202, 236, 450
local RIGHT_W = UI.CONTENT_W - RIGHT_X - 16
local function fmtTime(sec) return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60)) end
local function money(c) return c and NW.Money(c, "mid") or DIM .. "–|r" end

-- Left: search, then categories
local search = CreateFrame("EditBox", nil, page, "BackdropTemplate")
search:SetSize(LEFT_W, 22)
search:SetPoint("TOPLEFT", 16, -6)
UI.Flat(search, S.sunk, S.edge)
search:SetFont(UI.FONT, 12, "")
search:SetTextColor(unpack(S.text))
search:SetTextInsets(22, 8, 0, 0)
search:SetAutoFocus(false)
search:SetMaxLetters(40)
local sIcon = search:CreateTexture(nil, "ARTWORK")
sIcon:SetSize(13, 13)
sIcon:SetPoint("LEFT", 6, 0)
sIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
sIcon:SetVertexColor(unpack(S.dim))
local sHint = UI.Text(search, 12, S.disabled)
sHint:SetPoint("LEFT", 22, 0)
sHint:SetText("Search materials")
local searchText = ""
search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged", function(self)
  local t = self:GetText() or ""
  sHint:SetShown(t == "")
  if t ~= searchText then searchText = t; W.listOffset = 0; refresh() end
end)

local CAT_H = 24
W.cats = {}
local catBox = UI.Box(page, LEFT_W, 13 * CAT_H + 8)
catBox:SetPoint("TOPLEFT", 16, -34)
for i = 1, 13 do
  local b = CreateFrame("Button", nil, catBox)
  b:SetSize(LEFT_W - 2, CAT_H)
  b:SetPoint("TOPLEFT", 1, -4 - (i - 1) * CAT_H)
  UI.RowHighlight(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = UI.Text(b, 12, S.text)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
  b.count = UI.Text(b, 11, S.dim, "RIGHT")
  b.count:SetPoint("RIGHT", -8, 0)
  b:SetScript("OnClick", function(self)
    sel.cat = self.key
    st().matCat = self.key
    W.listOffset = 0
    if searchText ~= "" then search:SetText("") end
    refresh()
  end)
  W.cats[i] = b
end

-- Centre: materials
local LROW_H, LROWS = 30, 15
local mid = UI.Box(page, MID_W, LROWS * LROW_H + 8)
mid:SetPoint("TOPLEFT", MID_X, -34)
mid:EnableMouseWheel(true)
W.midHead = UI.Text(page, 12, S.gold)
W.midHead:SetPoint("BOTTOMLEFT", mid, "TOPLEFT", 2, 8)
W.midCount = UI.Text(page, 11, S.dim, "RIGHT")
W.midCount:SetPoint("BOTTOMRIGHT", mid, "TOPRIGHT", -2, 8)
W.rows = {}
W.listOffset = 0
for i = 1, LROWS do
  local r = CreateFrame("Button", nil, mid)
  r:SetSize(MID_W - 2, LROW_H)
  r:SetPoint("TOPLEFT", 1, -4 - (i - 1) * LROW_H)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 6, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 7, 2)
  r.name:SetPoint("RIGHT", -60, 0)
  r.name:SetWordWrap(false)
  r.sub = UI.Text(r, 10, S.dim)
  r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 7, -2)
  r.sub:SetPoint("RIGHT", -70, 0)
  r.sub:SetWordWrap(false)
  r.have = UI.Text(r, 12, S.text, "RIGHT")
  r.have:SetPoint("TOPRIGHT", -8, -4)
  r.price = UI.Text(r, 10, S.dim, "RIGHT")
  r.price:SetPoint("BOTTOMRIGHT", -8, 4)
  r:SetScript("OnClick", function(self)
    if not self.e then return end
    if IsShiftKeyDown() and type(self.e.id) == "number" and NW.ChatLink and NW.ChatLink(self.e.id, nil, true) then return end
    sel.id, sel.src, sel.zone = self.e.id, nil, nil
    st().matSel = self.e.id
    refresh()
  end)
  r:SetScript("OnEnter", function(self)
    if not (self.e and type(self.e.id) == "number") then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.e.id)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.rows[i] = r
end
mid:SetScript("OnMouseWheel", function(_, d)
  local max = math.max(0, (W.listN or 0) - LROWS)
  local o = math.max(0, math.min(max, W.listOffset - d * 3))
  if o ~= W.listOffset then W.listOffset = o; refresh() end
end)
W.midSort = UI.Dropdown(page, MID_W, "Sort", { { "default", "Default" }, { "name", "Name" }, { "have", "Owned" }, { "price", "Price" } },
  function() return st().matSort or "default" end, function(v) st().matSort = v ~= "default" and v or nil; refresh() end, 150)
W.midSort:SetPoint("TOPLEFT", mid, "BOTTOMLEFT", 0, -6)

------------------------------------------------------------------------
-- Right: the material
------------------------------------------------------------------------
local right = CreateFrame("Frame", nil, page)
right:SetPoint("TOPLEFT", RIGHT_X, -6)
right:SetSize(RIGHT_W, UI.CONTENT_H - 14)
local iconBox = UI.Box(right, 40, 40)
iconBox:SetPoint("TOPLEFT")
W.icon = iconBox:CreateTexture(nil, "ARTWORK")
W.icon:SetPoint("TOPLEFT", 1, -1)
W.icon:SetPoint("BOTTOMRIGHT", -1, 1)
W.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
iconBox:EnableMouse(true)
iconBox:SetScript("OnEnter", function(self)
  if type(sel.id) ~= "number" then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(sel.id)
  GameTooltip:Show()
end)
iconBox:SetScript("OnLeave", GameTooltip_Hide)
W.name = UI.Text(right, 17, S.gold)
W.name:SetPoint("TOPLEFT", iconBox, "TOPRIGHT", 10, -1)
W.sub = UI.Text(right, 11, S.dim)
W.sub:SetPoint("TOPLEFT", W.name, "BOTTOMLEFT", 0, -5)
W.sub:SetWidth(RIGHT_W - 200)
W.sub:SetWordWrap(false)
W.back = UI.Button(right, "", 150, function()
  if sel.from and NW.OpenProfession then NW.OpenProfession(sel.from) end
end, 22)
W.back:SetPoint("TOPRIGHT", 0, 0)
W.ah = UI.Button(right, "Search AH", 100, function()
  if type(sel.id) ~= "number" or not NW.SearchAH then return end
  local n = NW.ItemName(sel.id)
  local g = M.Goal(sel.id)
  local need = g and M.Progress(g).remaining or 1
  if n then NW.SearchAH({ { n, math.max(1, need) } }) end
end, 22)
W.ah:SetPoint("TOPRIGHT", 0, -24)
UI.Tip(W.ah, "Search AH", "Searches Auctionator for it (at the auction house). With a target, for what's still missing.")

-- Objective strip: owned, target, remaining, session, lifetime
local goalBar = CreateFrame("Frame", nil, right)
goalBar:SetSize(RIGHT_W, 26)
goalBar:SetPoint("TOPLEFT", iconBox, "BOTTOMLEFT", 0, -8)
local gbg = goalBar:CreateTexture(nil, "BACKGROUND")
gbg:SetAllPoints()
gbg:SetColorTexture(unpack(S.header))
W.goalText = UI.Text(goalBar, 12, S.text)
W.goalText:SetPoint("LEFT", 8, 0)
W.goalEdit = CreateFrame("EditBox", nil, goalBar, "BackdropTemplate")
W.goalEdit:SetSize(46, 20)
UI.Flat(W.goalEdit, S.sunk, S.edge)
W.goalEdit:SetFont(UI.FONT, 12, "")
W.goalEdit:SetTextColor(unpack(S.text))
W.goalEdit:SetTextInsets(6, 6, 0, 0)
W.goalEdit:SetAutoFocus(false)
W.goalEdit:SetNumeric(true)
W.goalEdit:SetMaxLetters(5)
W.goalEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local MODES = { { "total", "Own" }, { "more", "Collect" } }
W.goalMode = UI.Dropdown(goalBar, 84, "", MODES, function() return W.mode or "total" end, function(v) W.mode = v end, 84,
  "Own: have this many in bags and bank.\nCollect: get this many more than you have now.")
local function trackNow()
  local n = tonumber(W.goalEdit:GetText() or "")
  if type(sel.id) ~= "number" or not n or n <= 0 then return end
  local _, err = M.SetGoal(sel.id, W.mode or "total", n, sel.from)
  if err == "full" then NW.Print("Up to 8 targets. Clear one first.") end
  W.goalEdit:ClearFocus()
  refresh()
end
W.goalEdit:SetScript("OnEnterPressed", trackNow)
W.goalSet = UI.Button(goalBar, "Track", 60, trackNow, 20)
W.goalClear = UI.Button(goalBar, "Clear", 54, function() M.ClearGoal(sel.id); refresh() end, 20)
W.goalClear:SetPoint("RIGHT", -3, 0)
W.goalSet:SetPoint("RIGHT", W.goalClear, "LEFT", -4, 0)
W.goalMode:SetPoint("RIGHT", W.goalSet, "LEFT", -4, 0)
W.goalEdit:SetPoint("RIGHT", W.goalMode, "LEFT", -4, 0)
W.goalLabel = UI.Text(goalBar, 11, S.dim, "RIGHT")
W.goalLabel:SetPoint("RIGHT", W.goalEdit, "LEFT", -6, 0)
W.goalLabel:SetText("Target")

-- Source switches: one per way to get it
W.srcBtns = {}
local SRC_ORDER = { "nodes", "fishing", "skin", "loot", "vendor", "craft" }
for i, k in ipairs(SRC_ORDER) do
  local b = UI.Button(right, k, 90, function() sel.src = k; sel.zone = nil; refresh() end, 22)
  b.key = k
  b.mark = b:CreateTexture(nil, "OVERLAY")
  b.mark:SetPoint("BOTTOMLEFT", 1, 1)
  b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
  b.mark:SetHeight(2)
  b.mark:SetColorTexture(unpack(S.gold))
  W.srcBtns[k] = b
end

-- Body: list on the left, map on the right
local BODY_Y = -112
local LIST_W = 300
local PV_W, PV_H = RIGHT_W - LIST_W - 12, 168
local body = CreateFrame("Frame", nil, right)
body:SetPoint("TOPLEFT", 0, BODY_Y)
body:SetPoint("BOTTOMRIGHT")
W.listHead = UI.Heading(body, "", LIST_W)
W.listHead:SetPoint("TOPLEFT")
W.cols = {}
for k = 1, 4 do
  local t = UI.Text(body, 10, S.dim, "RIGHT")
  t:SetPoint("TOPRIGHT", body, "TOPLEFT", 0, -28)
  W.cols[k] = t
end
W.colName = UI.Text(body, 10, S.dim)
W.colName:SetPoint("TOPLEFT", 10, -28)

local ZROW_H, ZROWS = 22, 9
W.zrows = {}
local zbox = CreateFrame("Frame", nil, body)
zbox:SetSize(LIST_W, ZROWS * ZROW_H)
zbox:SetPoint("TOPLEFT", 0, -42)
zbox:EnableMouseWheel(true)
for i = 1, ZROWS do
  local r = CreateFrame("Button", nil, zbox)
  r:SetSize(LIST_W, ZROW_H - 1)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ZROW_H)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("LEFT", 8, 0)
  r.name:SetWidth(150)
  r.name:SetWordWrap(false)
  r.cells = {}
  for k = 1, 4 do
    local t = UI.Text(r, 12, S.text, "RIGHT")
    r.cells[k] = t
  end
  r:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
  r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.zrows[i] = r
end
W.zoneOffset = 0
zbox:SetScript("OnMouseWheel", function(_, d)
  local max = math.max(0, (W.zoneN or 0) - ZROWS)
  local o = math.max(0, math.min(max, W.zoneOffset - d * 2))
  if o ~= W.zoneOffset then W.zoneOffset = o; refresh() end
end)
local function placeCols(xs)
  for k = 1, 4 do
    W.cols[k]:ClearAllPoints()
    W.cols[k]:SetPoint("TOPRIGHT", body, "TOPLEFT", xs[k] or -100, -28)
    W.cols[k]:SetShown(xs[k] ~= nil)
    for _, r in ipairs(W.zrows) do
      r.cells[k]:ClearAllPoints()
      r.cells[k]:SetPoint("RIGHT", r, "LEFT", xs[k] or -100, 0)
      r.cells[k]:SetShown(xs[k] ~= nil)
    end
  end
end

-- the second list: creatures in the selected zone
local CROWS = 6
W.crowHead = UI.Heading(body, "Creatures", LIST_W)
W.crowHead:SetPoint("TOPLEFT", zbox, "BOTTOMLEFT", 0, -8)
W.crows = {}
for i = 1, CROWS do
  local r = CreateFrame("Button", nil, body)
  r:SetSize(LIST_W, 20)
  r:SetPoint("TOPLEFT", W.crowHead, "BOTTOMLEFT", 0, -4 - (i - 1) * 20)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  r.name = UI.Text(r, 11, S.text)
  r.name:SetPoint("LEFT", 8, 0)
  r.name:SetWidth(150)
  r.name:SetWordWrap(false)
  r.lvl = UI.Text(r, 11, S.dim, "RIGHT")
  r.lvl:SetPoint("RIGHT", r, "LEFT", 196, 0)
  r.ch = UI.Text(r, 11, S.text, "RIGHT")
  r.ch:SetPoint("RIGHT", r, "LEFT", 246, 0)
  r.req = UI.Text(r, 11, S.text, "RIGHT")
  r.req:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.crows[i] = r
end

-- Map
local preview = UI.Box(body, PV_W + 2, PV_H + 2)
preview:SetPoint("TOPRIGHT", 0, -30)
preview:SetClipsChildren(true)
local pvArt = CreateFrame("Frame", nil, preview)
pvArt:SetPoint("TOPLEFT", 1, -1)
pvArt:SetSize(PV_W, PV_H)
local pvShade = pvArt:CreateTexture(nil, "BORDER")
pvShade:SetAllPoints()
pvShade:SetColorTexture(0, 0, 0, 0.18)
local pvTiles = {}
local getDot, resetDots = UI.Pool(function()
  local t = pvArt:CreateTexture(nil, "OVERLAY")
  local mask = pvArt:CreateMaskTexture()
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(t)
  t:AddMaskTexture(mask)
  t:SetSize(5, 5)
  return t
end)
local getCell, resetCells = UI.Pool(function() return pvArt:CreateTexture(nil, "ARTWORK") end)
local getLine, resetLines = UI.Pool(function()
  local l = pvArt:CreateLine(nil, "OVERLAY")
  l:SetThickness(2)
  return l
end)
local getNum, resetNums = UI.Pool(function()
  local f = pvArt:CreateFontString(nil, "OVERLAY")
  f:SetFont(UI.FONT, 11, "OUTLINE")
  return f
end)
local function px(x, y) return x * PV_W, -y * PV_H end
local function clearMap()
  resetDots(); resetCells(); resetLines(); resetNums()
  for _, t in ipairs(pvTiles) do t:Hide() end
  if pvTiles.reveal then for _, t in ipairs(pvTiles.reveal) do t:Hide() end end
end
W.mapModes = {}
local MAP_MODES = { { "density", "Known spawns" }, { "mine", "My history" }, { "route", "Route" } }
for i, m in ipairs(MAP_MODES) do
  local b = UI.Button(body, m[2], (PV_W + 2 - 8) / 3, function() st().huntMap = m[1]; refresh() end, 20)
  b:SetPoint("TOPLEFT", preview, "TOPLEFT", (i - 1) * ((PV_W + 2 - 8) / 3 + 4), 24)
  b.mark = b:CreateTexture(nil, "OVERLAY")
  b.mark:SetPoint("BOTTOMLEFT", 1, 1)
  b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
  b.mark:SetHeight(2)
  b.mark:SetColorTexture(unpack(S.gold))
  b.key = m[1]
  W.mapModes[i] = b
end
UI.Tip(W.mapModes[1], "Known spawns", "Where creatures that give it have spawned (Classic data), weighted by drop chance. Not creatures alive now, not guaranteed drops.")
UI.Tip(W.mapModes[2], "My history", "Where you've collected it yourself.")
UI.Tip(W.mapModes[3], "Route", "The hunting grounds a route would visit, in order.")
W.mapTitle = UI.Text(body, 12, S.text)
W.mapTitle:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
W.mapTitle:SetWidth(PV_W)
W.mapSub = UI.Text(body, 11, S.dim)
W.mapSub:SetPoint("TOPLEFT", W.mapTitle, "BOTTOMLEFT", 0, -3)
W.mapSub:SetWidth(PV_W)
W.stats = {}
for i = 1, 5 do
  local a = UI.Text(body, 12, S.dim)
  a:SetPoint("TOPLEFT", W.mapSub, "BOTTOMLEFT", 0, -8 - (i - 1) * 17)
  local v = UI.Text(body, 12, S.text, "RIGHT")
  v:SetPoint("TOPRIGHT", W.mapSub, "BOTTOMLEFT", PV_W, -8 - (i - 1) * 17)
  W.stats[i] = { a, v }
end
local function stat(i, label, value)
  W.stats[i][1]:SetText(label or "")
  W.stats[i][2]:SetText(value or "")
end
W.checkA = UI.Check(body, "", function() return W.checkAGet and W.checkAGet() end, function(v) if W.checkASet then W.checkASet(v) end refresh() end)
W.checkA:SetPoint("TOPLEFT", W.mapSub, "BOTTOMLEFT", 2, -8 - 5 * 17)
W.checkB = UI.Check(body, "", function() return W.checkBGet and W.checkBGet() end, function(v) if W.checkBSet then W.checkBSet(v) end refresh() end)
W.checkB:SetPoint("TOPLEFT", W.checkA, "BOTTOMLEFT", 0, -2)
W.main = UI.Button(body, "", PV_W + 2, function() if W.mainClick then W.mainClick() end end, 26, "primary")
W.main:SetPoint("BOTTOMRIGHT", 0, 8)
W.second = UI.Button(body, "", PV_W + 2, function() if W.secondClick then W.secondClick() end end, 22)
W.second:SetPoint("BOTTOMRIGHT", W.main, "TOPRIGHT", 0, 4)
W.note = UI.Text(body, 11, S.dim)
W.note:SetPoint("BOTTOMLEFT", 0, 10)
W.note:SetWidth(LIST_W)

------------------------------------------------------------------------
-- Map drawing
------------------------------------------------------------------------
local function heat(t)
  -- restrained green, amber, red
  if t < 0.5 then local k = t * 2 return 0.35 + 0.55 * k, 0.65 + 0.1 * k, 0.3 - 0.1 * k end
  local k = (t - 0.5) * 2
  return 0.9, 0.75 - 0.4 * k, 0.2
end
local function drawArt(mapID)
  clearMap()
  if mapID then UI.DrawZoneArt(mapID, pvArt, pvTiles, PV_W, PV_H, true) end
end
local function drawDensity(z)
  local maxW = 0
  for _, b in pairs(z.bins) do maxW = math.max(maxW, b.w) end
  if maxW <= 0 then return end
  local s = 3 / 100
  for _, b in pairs(z.bins) do
    local t = b.w / maxW
    local c = getCell()
    local r, g, bl = heat(t)
    c:SetColorTexture(r, g, bl, 0.25 + 0.4 * t)
    c:ClearAllPoints()
    c:SetSize(s * PV_W, s * PV_H)
    c:SetPoint("TOPLEFT", pvArt, "TOPLEFT", px(b.bx * s, b.by * s))
  end
end
local function drawRings(stops, ordered, cur)
  local n = #stops
  if ordered and n > 1 then
    for i = 1, n do
      local a, b = stops[i], stops[(i % n) + 1]
      local l = getLine()
      l:SetThickness(2)
      local Cr = C.route
      l:SetColorTexture(Cr[1], Cr[2], Cr[3], ((i % n) + 1 == cur) and 0.95 or 0.5)
      l:SetStartPoint("TOPLEFT", pvArt, px(a.x, a.y))
      l:SetEndPoint("TOPLEFT", pvArt, px(b.x, b.y))
    end
  end
  for i, s in ipairs(stops) do
    local SEG = 20
    local r, g, bl, a = 0.66, 0.55, 0.36, 0.7
    if cur and i == cur then r, g, bl, a = 0.84, 0.70, 0.40, 1 end
    if s.state == "hunted" or s.state == "skipped" then r, g, bl, a = 0.55, 0.55, 0.55, 0.5 end
    for k = 1, SEG do
      local a1, a2 = (k - 1) / SEG * 2 * math.pi, k / SEG * 2 * math.pi
      local l = getLine()
      l:SetThickness(1.5)
      l:SetColorTexture(r, g, bl, a)
      l:SetStartPoint("TOPLEFT", pvArt, px(s.x + math.cos(a1) * s.rx, s.y + math.sin(a1) * s.ry))
      l:SetEndPoint("TOPLEFT", pvArt, px(s.x + math.cos(a2) * s.rx, s.y + math.sin(a2) * s.ry))
    end
    if ordered then
      local f = getNum()
      f:ClearAllPoints()
      f:SetPoint("CENTER", pvArt, "TOPLEFT", px(s.x, s.y))
      f:SetText(i)
      f:SetTextColor(r, g, bl)
    end
  end
end
local function drawMine(mapID, id)
  local spots = NW.GatherLog and mapID and NW.GatherLog.Spots(mapID, id) or {}
  local maxN = 1
  for _, p in ipairs(spots) do maxN = math.max(maxN, p.n) end
  for _, p in ipairs(spots) do
    local d = getDot()
    local sz = 4 + 6 * math.sqrt(p.n / maxN)
    d:SetSize(sz, sz)
    d:SetColorTexture(0.35, 0.75, 0.72, 0.85) -- muted teal: yours
    d:ClearAllPoints()
    d:SetPoint("CENTER", pvArt, "TOPLEFT", px(p.x, p.y))
  end
  return #spots
end

------------------------------------------------------------------------
-- Views, one per source. Each fills the list, the map, stats and buttons.
------------------------------------------------------------------------
local function resetBody()
  for _, r in ipairs(W.zrows) do r:Hide(); r.onClick, r.onEnter = nil, nil; r:SetSelected(false) end
  for _, r in ipairs(W.crows) do r:Hide(); r.onEnter = nil end
  W.crowHead:Hide()
  for i = 1, 5 do stat(i) end
  W.checkA:Hide(); W.checkB:Hide()
  W.checkAGet, W.checkASet, W.checkBGet, W.checkBSet = nil, nil, nil, nil
  W.main:Hide(); W.second:Hide()
  W.mainClick, W.secondClick = nil, nil
  W.main.tipTitle, W.main.tipBody = nil, nil
  W.main:SetEnabled(true); W.second:SetEnabled(true)
  W.note:SetText("")
  W.colName:SetText("")
  for _, b in ipairs(W.mapModes) do b:Hide() end
  W.mapTitle:SetText(""); W.mapSub:SetText("")
  zbox:Show()
  preview:Show()
end
local function setCheck(cb, label, get, set, tip)
  cb:Show()
  cb:SetLabel(label)
  cb.tipTitle, cb.tipBody = label, tip
  if cb == W.checkA then W.checkAGet, W.checkASet = get, set else W.checkBGet, W.checkBSet = get, set end
  cb:Refresh()
end
-- tooltips that change with the view: set .tipTitle / .tipBody, nil for none
local function liveTip(f)
  f:HookScript("OnEnter", function(self)
    if not self.tipBody then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tipTitle or "", 1, 1, 1)
    GameTooltip:AddLine(self.tipBody, S.dim[1], S.dim[2], S.dim[3], true)
    GameTooltip:Show()
  end)
  f:HookScript("OnLeave", GameTooltip_Hide)
end
liveTip(W.checkA); liveTip(W.checkB); liveTip(W.main)
local function listRows(rows, offsetKey)
  W.zoneN = #rows
  for i, r in ipairs(W.zrows) do
    local row = rows[i + W.zoneOffset]
    r.row = row or false
    r:SetShown(row ~= nil)
  end
end

-- Herbs and ore
local function viewNodes(e)
  local both = e.id == "both"
  local entry = nodeEntry(e)
  local rows = rankZones(entry, both)
  local by = st().guideSort
  if by then
    local sorted = {}
    for i, row in ipairs(rows) do sorted[i] = row end
    local key = ({ rate = "rate", gold = "gold", count = "count", loop = "loop" })[by]
    table.sort(sorted, function(a, b)
      local x, y = a[key], b[key]
      if (x ~= nil) ~= (y ~= nil) then return x ~= nil end
      if x and x ~= y then if by == "loop" then return x < y end return x > y end
      return a.name < b.name
    end)
    rows = sorted
  end
  W.listHead.text:SetText("Zones")
  W.colName:SetText("Zone")
  placeCols({ 196, 244, LIST_W - 8 })
  W.cols[1]:SetText("Spots"); W.cols[2]:SetText("Loop"); W.cols[3]:SetText("g/h")
  local pick = rows[1]
  for _, row in ipairs(rows) do if sel.zone and row.name == sel.zone then pick = row end end
  listRows(rows)
  for _, r in ipairs(W.zrows) do
    local row = r.row
    if row then
      r.name:SetText((row.recommended and "|cffd6b266*|r " or "   ") .. row.name)
      r.name:SetTextColor(unpack(row.count > 0 and S.text or S.dim))
      if row.rate then
        r.cells[1]:SetText(row.count)
        r.cells[2]:SetText(fmtTime(row.loop / NW.MOUNT_YPS))
        r.cells[3]:SetText(row.gold and ("~" .. NW.Money(row.gold, true)) or DIM .. "–|r")
      else
        r.cells[1]:SetText(row.count > 0 and row.count or DIM .. "–|r")
        r.cells[2]:SetText(DIM .. "–|r"); r.cells[3]:SetText(DIM .. "–|r")
      end
      r:SetSelected(row == pick)
      r.onClick = function(self, button)
        sel.zone = self.row.name
        if button == "RightButton" and W.mainClick then refresh(); W.mainClick() return end
        refresh()
      end
      r.onEnter = function(self)
        local rw = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(rw.name, 1, 1, 1)
        if rw.recommended then GameTooltip:AddLine("Recommended by farming guides" .. (rw.note and (": " .. rw.note) or ""), S.gold[1], S.gold[2], S.gold[3], true)
        elseif not rw.missing then GameTooltip:AddLine("Found in your own node data", S.dim[1], S.dim[2], S.dim[3]) end
        if rw.missing then GameTooltip:AddLine("Not on your client's map list", S.dim[1], S.dim[2], S.dim[3]) end
        if rw.rate then GameTooltip:AddDoubleLine("Spots per minute", ("%.1f"):format(rw.rate), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        GameTooltip:AddLine("g/h: if every spot were up, about two items each at Auctionator prices. An estimate.", S.dim[1], S.dim[2], S.dim[3], true)
        if rw.mapID and rw.count > 0 then GameTooltip:AddLine("Right-click: build its route", S.dim[1], S.dim[2], S.dim[3]) end
        GameTooltip:Show()
      end
    end
  end
  -- map: your route if it's for this, else the known spots and a quick loop
  local row = pick
  local kind = both and "both" or e.nodeKind
  drawArt(row and row.mapID)
  if row then
    W.mapTitle:SetText(row.name)
    local route = row.mapID and NW.db.routes[row.mapID]
    local isFocus = route and ((route.focus and route.focus[entry[1]]) or (both and not route.focus))
    local function p(x, y) return x * PV_W, -y * PV_H end
    if isFocus and #route.stops > 1 then
      local stp = route.stops
      for i = 1, #stp do
        local pts = i == route.open and {} or NW.LegPoints(route, i)
        for q = 1, #pts - 1 do
          local l = getLine()
          l:SetThickness(2)
          l:SetColorTexture(C.route[1], C.route[2], C.route[3], 0.9)
          l:SetStartPoint("TOPLEFT", pvArt, p(pts[q][1], pts[q][2]))
          l:SetEndPoint("TOPLEFT", pvArt, p(pts[q + 1][1], pts[q + 1][2]))
        end
      end
      for _, a in ipairs(stp) do
        local d = getDot()
        local ed = a.kind == "ore" and C.oreEdge or C.herbEdge
        d:SetSize(7, 7)
        d:SetColorTexture(ed[1], ed[2], ed[3], 1)
        d:ClearAllPoints()
        d:SetPoint("CENTER", pvArt, "TOPLEFT", p(a.x, a.y))
      end
      W.mapSub:SetText(("Your route  ·  %d stops, %s %s"):format(#stp, fmtTime(route.seconds or 0), route.open and "each way" or "per loop"))
    else
      if row.order and #row.pts <= 400 then
        for i = 1, #row.order do
          local a, b = row.pts[row.order[i]], row.pts[row.order[(i % #row.order) + 1]]
          local l = getLine()
          l:SetThickness(1)
          l:SetColorTexture(1, 1, 1, 0.45)
          l:SetStartPoint("TOPLEFT", pvArt, p(a[3], a[4]))
          l:SetEndPoint("TOPLEFT", pvArt, p(b[3], b[4]))
        end
      end
      for _, pt in ipairs(row.pts) do
        local d = getDot()
        d:SetSize(5, 5)
        local ed = pt[5] == "ore" and C.oreEdge or C.herbEdge
        d:SetColorTexture(ed[1], ed[2], ed[3], 1)
        d:ClearAllPoints()
        d:SetPoint("CENTER", pvArt, "TOPLEFT", p(pt[3], pt[4]))
      end
      W.mapSub:SetText(row.missing and "Not on your client's map list" or row.count > 0 and "Known spots  ·  no route built" or "No spots saved yet")
    end
    stat(1, "Known spots", tostring(row.count))
    if row.rate then
      stat(2, "Loop", fmtTime(row.loop / NW.MOUNT_YPS))
      stat(3, "Spots per minute", ("%.1f"):format(row.rate))
      stat(4, "Gold per hour", row.gold and ("~" .. NW.Money(row.gold, true)) or DIM .. "no prices|r")
    end
  end
  if not both then
    setCheck(W.checkA, "Also pick other herbs and ore", function() return st().guideAlsoOthers end,
      function(v) st().guideAlsoOthers = v end, "The route also stops at every other herb and ore your filters allow.")
  end
  W.main:Show()
  W.main:SetText("Build route")
  W.main:SetEnabled(row ~= nil and row.mapID ~= nil and row.count > 0)
  W.mainClick = function()
    if not (row and row.mapID and row.count > 0) then return end
    NW.BuildRoute(row.mapID, function() if page:IsShown() then refresh() end end,
      both and {} or { focus = focusOf(entry), alsoOthers = st().guideAlsoOthers })
  end
  W.main.tipTitle, W.main.tipBody = "Build route", "Replaces this zone's saved route."
  local req = not both and NW.RequiredSkill(entry[1])
  local skill = NW.GetSkill(kind)
  if both then
    W.note:SetText(("Herbalism %s  ·  Mining %s"):format(NW.GetSkill("herb") or "-", NW.GetSkill("ore") or "-"))
  elseif req then
    local c = NW.SkillColor(req, skill)
    W.note:SetText(("Needs %s %d"):format(KIND[kind].skill, req) .. (not skill and "" or c == "red" and "  ·  |cffd17665skill too low|r"
      or c == "grey" and "  ·  no more skill-ups" or "  ·  |cff94ba78gives skill-ups|r"))
  end
end

-- Fishing
local function viewFishing(e)
  local F = NW.FISHING
  local f = F and F.FISH[e.id]
  W.listHead.text:SetText("Where to fish it")
  W.colName:SetText("Zone")
  placeCols({ LIST_W - 8 })
  W.cols[1]:SetText("Caught")
  local zones = {}
  local seen = {}
  local mine = {}
  for _, z in ipairs(NW.GatherLog and NW.GatherLog.ZonesFor(e.id) or {}) do mine[z.map] = z.n end
  for _, z in ipairs(F and F.zonesFor(e.id) or {}) do
    local name = type(z) == "table" and (z.name or z[1]) or z
    if name and not seen[name] then seen[name] = true; zones[#zones + 1] = { name = name, mapID = zoneID(name) } end
  end
  for m, n in pairs(mine) do
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    local name = info and info.name
    if name and not seen[name] then seen[name] = true; zones[#zones + 1] = { name = name, mapID = m } end
  end
  for _, z in ipairs(zones) do z.n = z.mapID and mine[z.mapID] or 0 end
  table.sort(zones, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
  local pick = zones[1]
  for _, z in ipairs(zones) do if sel.zone == z.name then pick = z end end
  listRows(zones)
  for _, r in ipairs(W.zrows) do
    if r.row then
      r.name:SetText(r.row.name)
      r.name:SetTextColor(unpack(S.text))
      r.cells[1]:SetText(r.row.n > 0 and r.row.n or DIM .. "–|r")
      r:SetSelected(r.row == pick)
      r.onClick = function(self) sel.zone = self.row.name; refresh() end
    end
  end
  drawArt(pick and pick.mapID)
  local n = pick and pick.mapID and drawMine(pick.mapID, e.id) or 0
  W.mapTitle:SetText(pick and pick.name or "")
  W.mapSub:SetText(n > 0 and "|cff59bfb8Your catches|r" or "Fishing data is by zone, not by spot")
  if f then
    stat(1, "Fishing skill", f.skill and tostring(f.skill) or DIM .. "unknown|r")
    if f.note then stat(2, "When", f.note) end
  else
    W.note:SetText("Not in Nodewalker's fishing data.")
  end
  W.main:Show(); W.main:SetText("Fish Finder")
  W.main:SetEnabled(NW.OpenFishFinder ~= nil)
  W.mainClick = function() if NW.OpenFishFinder then NW.OpenFishFinder(e.id) end end
  W.second:Show(); W.second:SetText("Fishing + Cooking plan")
  W.second:SetEnabled(NW.OpenFishCook ~= nil)
  W.secondClick = function() if NW.OpenFishCook then NW.OpenFishCook() end end
  W.main.tipTitle, W.main.tipBody = "Fish Finder", "Where it's caught, lures and your catches."
end

-- Skinning and creature loot: Hunting Grounds
local function huntOpts(method)
  local o = { elites = st().huntElites or false }
  if method == "skin" and st().huntSkill ~= false then o.skill = NW.ProfSkill and NW.ProfSkill("skinning") or nil end
  return o
end
local function viewHunt(e, method)
  local opts = huntOpts(method)
  local g = H.Grounds(e.id, method, opts)
  local zones = H.Sort(g.zones, st().huntSort or "density", e.id)
  if st().huntSort == "mine" then
    local f = {}
    for _, z in ipairs(zones) do if z.mapID and NW.GatherLog.ZoneCount(z.mapID, e.id) > 0 then f[#f + 1] = z end end
    zones = f
  end
  W.listHead.text:SetText("Hunting grounds")
  W.colName:SetText("Zone")
  placeCols({ 196, 244, LIST_W - 8 })
  W.cols[1]:SetText("Level"); W.cols[2]:SetText("Spawns"); W.cols[3]:SetText("Mine")
  local pick = zones[1]
  for _, z in ipairs(zones) do if sel.zone == z.name then pick = z end end
  listRows(zones)
  local hunt = H.Route()
  for _, r in ipairs(W.zrows) do
    local z = r.row
    if z then
      local active = hunt and hunt.item == e.id and hunt.zone == z.name
      r.name:SetText((active and "|cff5fd4e0>|r " or "") .. z.name)
      r.name:SetTextColor(unpack(z.mapID and S.text or S.dim))
      r.cells[1]:SetText(z.minL and (z.minL == z.maxL and z.minL or (z.minL .. "-" .. z.maxL)) or DIM .. "?|r")
      r.cells[2]:SetText(z.n)
      local mine = z.mapID and NW.GatherLog and NW.GatherLog.ZoneCount(z.mapID, e.id) or 0
      r.cells[3]:SetText(mine > 0 and mine or DIM .. "–|r")
      r:SetSelected(z == pick)
      r.onClick = function(self) sel.zone = self.row.name; refresh() end
      r.onEnter = function(self)
        local zz = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(zz.name, 1, 1, 1)
        GameTooltip:AddDoubleLine("Known spawn points", zz.n, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Hunting grounds", #zz.grounds, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        if (zz.scattered or 0) > 0 then GameTooltip:AddDoubleLine("Scattered spawns", zz.scattered, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        if not zz.mapID then GameTooltip:AddLine("Not on your client's map list", S.bad[1], S.bad[2], S.bad[3]) end
        GameTooltip:AddLine("Classic data: creatures and chances may differ in WoW Forever.", S.dim[1], S.dim[2], S.dim[3], true)
        GameTooltip:Show()
      end
    end
  end
  -- creatures in the selected zone
  W.crowHead:Show()
  W.crowHead.text:SetText(method == "skin" and "Creatures to skin" or "Creatures that drop it")
  local skill = NW.ProfSkill and NW.ProfSkill("skinning")
  if pick then
    local list = {}
    local chance = {}
    for _, s in ipairs(H.Sources(e.id, method)) do chance[s.npc] = s end
    for npc, n in pairs(pick.npcs) do list[#list + 1] = { u = H.Unit(npc), n = n, s = chance[npc] } end
    table.sort(list, function(a, b) return a.n * a.s.chance > b.n * b.s.chance end)
    for i, r in ipairs(W.crows) do
      local c = list[i]
      r:SetShown(c ~= nil)
      if c then
        local u = c.u
        r.name:SetText(u.name)
        r.lvl:SetText(u.min == u.max and u.min or (u.min .. "-" .. u.max))
        r.ch:SetText(("%d%%"):format(math.floor(c.s.chance + 0.5)))
        if method == "skin" then
          local req = H.SkinReq(u.max)
          local col = NW.SkillColor(req, skill)
          local hex = ({ red = "|cffff4033", orange = "|cffff8040", yellow = "|cffffe633", green = "|cff59cc59", grey = "|cff8c8c8c" })[col] or "|cffe0dbd0"
          r.req:SetText(hex .. req .. "|r")
        else
          r.req:SetText(H.TYPE[u.type] or "")
          r.req:SetTextColor(unpack(S.dim))
        end
        r.onEnter = function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText(u.name, 1, 1, 1)
          GameTooltip:AddDoubleLine("Level", u.min == u.max and u.min or (u.min .. "-" .. u.max), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
          if H.TYPE[u.type] then GameTooltip:AddDoubleLine("Type", H.TYPE[u.type], S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
          GameTooltip:AddDoubleLine(method == "skin" and "Skinning gives it" or "Drops it", ("%.1f%%"):format(c.s.chance), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
          if c.s.max and c.s.max > 1 then GameTooltip:AddDoubleLine("Each time", c.s.min .. "-" .. c.s.max, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
          if method == "skin" then GameTooltip:AddDoubleLine("Skinning needed", H.SkinReq(u.max) .. " (Classic rule)", S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
          GameTooltip:AddDoubleLine("Known spawns here", c.n, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
          if u.respawn and u.respawn > 0 then GameTooltip:AddDoubleLine("Respawn", ("~%d min"):format(math.ceil(u.respawn / 60)), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
          local mine = NW.GatherLog and NW.GatherLog.Npc(u.npc)
          if mine and (mine.skin + mine.loot) > 0 then
            local got = mine.items[e.id] or 0
            local times = method == "skin" and mine.skin or mine.loot
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(method == "skin" and "You skinned" or "You looted", times .. "x", 0.35, 0.75, 0.72, 1, 1, 1)
            GameTooltip:AddDoubleLine("It gave you", got, 0.35, 0.75, 0.72, 1, 1, 1)
            if times >= 10 then GameTooltip:AddDoubleLine("Per " .. (method == "skin" and "skin" or "loot"), ("%.2f"):format(got / times), 0.35, 0.75, 0.72, 1, 1, 1) end
          end
          GameTooltip:AddLine("Classic data", S.dim[1], S.dim[2], S.dim[3])
          GameTooltip:Show()
        end
      end
    end
  end
  -- the map: known spawn density, your history, or the route
  local mode = st().huntMap or "density"
  for _, b in ipairs(W.mapModes) do
    b:Show()
    b.mark:SetShown(b.key == mode)
    b.label:SetTextColor(unpack(b.key == mode and S.gold or S.dim))
  end
  drawArt(pick and pick.mapID)
  local plan = pick and H.Plan(pick) or {}
  local active = hunt and hunt.item == e.id and pick and hunt.zone == pick.name
  if pick then
    W.mapTitle:SetText(pick.name)
    if mode == "density" then
      drawDensity(pick)
      drawRings(pick.grounds, false)
      W.mapSub:SetText("Known spawns × drop chance  ·  Classic data")
    elseif mode == "mine" then
      local n = drawMine(pick.mapID, e.id)
      W.mapSub:SetText(n > 0 and "|cff59bfb8Where you collected it|r" or "Nothing collected here yet")
    else
      if active then
        local stops = {}
        for i, s in ipairs(hunt.stops) do stops[i] = { x = s.x, y = s.y, rx = s.rx, ry = s.ry, state = H.State(i) } end
        drawRings(stops, true, hunt.cur)
      else
        drawRings(plan, true, 1)
      end
      local len = H.Length(pick.mapID, active and hunt.stops or plan)
      W.mapSub:SetText(#plan == 1 and "One area: stay and hunt" or len and ("~%d yd loop, straight lines"):format(math.floor(len / 10 + 0.5) * 10) or "")
    end
    local lo, hi = pick.minL, pick.maxL
    stat(1, "Hunting grounds", tostring(#pick.grounds))
    stat(2, "Known spawn points", tostring(pick.n))
    stat(3, "Creature levels", lo and (lo == hi and tostring(lo) or (lo .. "-" .. hi)) or "?")
    local rs = plan[1] and plan[1].respawn
    if rs then stat(4, "Respawn (Classic)", ("~%d min"):format(math.ceil(rs / 60))) end
  else
    W.mapSub:SetText("")
  end
  local outN = 0
  for _, n in pairs(g.out or {}) do outN = outN + n end
  if #zones == 0 then
    W.note:SetText(st().huntSort == "mine" and "You haven't collected it anywhere yet."
      or (outN > 0 and "No creatures left with these filters." or "No known spawns outdoors."))
  elseif g.out and g.out.skill then
    W.note:SetText(("%d creature%s need more Skinning"):format(g.out.skill, g.out.skill == 1 and "" or "s"))
  end
  if method == "skin" then
    setCheck(W.checkA, "Only what I can skin", function() return st().huntSkill ~= false end,
      function(v) st().huntSkill = v end, "Leaves out creatures above your Skinning skill (Classic rule: level × 5 from level 20).")
  end
  setCheck(W.checkB, "Include elites and rares", function() return st().huntElites end, function(v) st().huntElites = v end)
  W.main:Show()
  if active then
    W.main:SetText("Stop route")
    W.mainClick = function() H.Stop(); refresh() end
  else
    W.main:SetText(#plan > 1 and "Build hunting route" or "Hunt here")
    W.mainClick = function()
      if pick then
        H.Start(e.id, method, pick)
        st().huntMap = "route"
        refresh()
      end
    end
  end
  W.main:SetEnabled(pick ~= nil and pick.mapID ~= nil and #plan > 0)
  W.main.tipTitle, W.main.tipBody = "Hunting route", "Circles the densest hunting grounds, nearest first. On the overlay; Next in the session panel moves on. Straight-line distances, not paths."
  W.second:Show()
  W.second:SetText("Show on map")
  W.second:SetEnabled(pick ~= nil and pick.mapID ~= nil and plan[1] ~= nil)
  W.secondClick = function()
    local s = plan[1]
    if s and NW.PinMap then NW.PinMap(pick.mapID, s.x * 100, s.y * 100, "Hunting ground") end
  end
end

-- Vendors
local function viewVendor(e)
  local SR = NW.SRC
  local list = {}
  local fac = UnitFactionGroup and UnitFactionGroup("player")
  local myF = fac == "Alliance" and "A" or fac == "Horde" and "H" or ""
  for _, npc in ipairs(SR and SR.vendors[e.id] or {}) do
    local u = H.Unit(npc)
    local at = SR.vendorAt[npc]
    if u and at then
      local zname = SR.zones[at[1]]
      local ok = u.fac == "" or u.fac:find(myF, 1, true) ~= nil
      list[#list + 1] = { u = u, zone = zname, x = at[2], y = at[3], ok = ok, mapID = zoneID(zname) }
    end
  end
  table.sort(list, function(a, b)
    if a.ok ~= b.ok then return a.ok end
    return a.zone < b.zone
  end)
  W.listHead.text:SetText("Vendors")
  W.colName:SetText("Vendor")
  placeCols({ LIST_W - 8 })
  W.cols[1]:SetText("Zone")
  listRows(list)
  for _, r in ipairs(W.zrows) do
    local v = r.row
    if v then
      r.name:SetText(v.u.name)
      r.name:SetTextColor(unpack(v.ok and S.text or S.dim))
      r.cells[1]:SetText(v.zone)
      r.onClick = function(self)
        local vv = self.row
        if vv.mapID and NW.PinMap then NW.PinMap(vv.mapID, vv.x, vv.y, vv.u.name) end
      end
      r.onEnter = function(self)
        local vv = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(vv.u.name, 1, 1, 1)
        GameTooltip:AddLine(("%s  %.1f, %.1f"):format(vv.zone, vv.x, vv.y), S.dim[1], S.dim[2], S.dim[3])
        if not vv.ok then GameTooltip:AddLine("Other faction", S.bad[1], S.bad[2], S.bad[3]) end
        GameTooltip:AddLine("Click: put it on your map", S.dim[1], S.dim[2], S.dim[3])
        GameTooltip:AddLine("Classic data", S.dim[1], S.dim[2], S.dim[3])
        GameTooltip:Show()
      end
    end
  end
  preview:Hide()
  local vp = NW.BuyPrice and NW.BuyPrice(e.id)
  stat(1, "Vendor price", vp and NW.Money(vp) or DIM .. "visit a vendor|r")
  if #list == 0 then W.note:SetText("Sold by vendors; no vendor locations in Nodewalker's data.") end
end

-- Crafting
local function viewCraft(e)
  local r, key = NW.RecipeFor(e.id)
  W.listHead.text:SetText("Made by")
  W.colName:SetText("Material")
  placeCols({ LIST_W - 8 })
  W.cols[1]:SetText("Need")
  local rows = {}
  if r then for _, re in ipairs(r.reagents) do rows[#rows + 1] = { id = re[1], n = re[2] } end end
  listRows(rows)
  for _, row in ipairs(W.zrows) do
    local m = row.row
    if m then
      row.name:SetText(NW.ItemName(m.id) or ("item " .. m.id))
      row.name:SetTextColor(unpack(S.text))
      row.cells[1]:SetText(("%d  " .. DIM .. "(have %d)|r"):format(m.n, NW.ItemCount(m.id)))
      row.onClick = function(self) if M.Get(self.row.id) then sel.id, sel.src, sel.zone = self.row.id, nil, nil; refresh() end end
      row.onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.row.id)
        if M.Get(self.row.id) then GameTooltip:AddLine("Click: where to get it", S.gold[1], S.gold[2], S.gold[3]) end
        GameTooltip:Show()
      end
    end
  end
  preview:Hide()
  if r then
    local p = NW.PROF_BY_KEY[key]
    stat(1, "Recipe", r.name)
    stat(2, "Profession", p and p.name or key)
    if r.orange then stat(3, "Skill", tostring(r.orange)) end
    if (r.yield or 1) > 1 then stat(4, "Makes", tostring(r.yield)) end
    local _, _, craft = NW.PriceParts(e.id)
    stat(5, "Materials cost", craft and ("~" .. NW.Money(craft)) or DIM .. "no price|r")
    W.main:Show(); W.main:SetText("Open " .. (p and p.name or "profession"))
    W.mainClick = function() if NW.OpenProfession then NW.OpenProfession(key) end end
  end
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local BOTH = { id = "both", name = "Herbs and ore", cat = "herb", src = { nodes = true }, nodeKind = "both", uses = 0 }
local function ownedText(e)
  if type(e.id) ~= "number" then return "" end
  local g = M.Goal(e.id)
  if g then
    local p = M.Progress(g)
    return (p.done and S.HEX.good or S.HEX.text) .. p.shown .. DIM .. "/" .. p.target .. "|r"
  end
  local n = NW.ItemCount(e.id)
  return n > 0 and tostring(n) or DIM .. "0|r"
end
local function iconOf(e)
  if e.id == "both" then return NW.NodeIcon("Peacebloom", "herb") end
  return NW.ItemIcon(e.id) or (e.src.nodes and NW.NodeIcon(e.name, e.nodeKind)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function subText(e)
  if e.id == "both" then return "Every node you can gather" end
  local parts = {}
  for _, k in ipairs(M.Sources(e)) do parts[#parts + 1] = M.SourceText(e, k) end
  local req = e.src.nodes and NW.RequiredSkill(e.name)
  return (req and (req .. "  ") or "") .. table.concat(parts, " · ")
end

refresh = function()
  if not page:IsShown() then return end
  local s = st()
  sel.cat = sel.cat or s.matCat or "herb"
  -- categories with materials
  local counts = M.Counts()
  local catList = {}
  if #M.Goals() > 0 then catList[#catList + 1] = { key = "tracked", label = "Tracked", n = #M.Goals(), icon = "Interface\\Icons\\INV_Misc_Note_01" } end
  catList[#catList + 1] = { key = "all", label = "All materials", n = counts.all, icon = "Interface\\Icons\\INV_Misc_Bag_10" }
  for _, c in ipairs(M.CATS) do
    if (counts[c.key] or 0) > 0 then catList[#catList + 1] = { key = c.key, label = c.label, n = counts[c.key], icon = NW.ItemIcon(c.icon) } end
  end
  local catOk = false
  for _, c in ipairs(catList) do if c.key == sel.cat then catOk = true end end
  if not catOk then sel.cat = "herb" end
  for i, b in ipairs(W.cats) do
    local c = catList[i]
    b:SetShown(c ~= nil)
    if c then
      b.key = c.key
      b.icon:SetTexture(c.icon)
      b.text:SetText(c.label)
      b.count:SetText(c.n)
      local on = searchText == "" and c.key == sel.cat
      b:SetSelected(on)
      b.text:SetTextColor(unpack(on and S.gold or S.text))
    end
  end
  -- materials
  local list = M.Search(searchText, sel.cat)
  if searchText == "" and (sel.cat == "herb" or sel.cat == "ore") then table.insert(list, 1, BOTH) end
  local by = s.matSort
  if by then
    local key = {}
    for _, e in ipairs(list) do
      if by == "name" then key[e] = M.Name(e)
      elseif by == "have" then key[e] = type(e.id) == "number" and -NW.ItemCount(e.id) or 1
      elseif by == "price" then key[e] = type(e.id) == "number" and NW.Price and -(NW.Price(e.id) or 0) or 1 end
    end
    table.sort(list, function(a, b)
      if key[a] ~= key[b] then return key[a] < key[b] end
      return M.Name(a) < M.Name(b)
    end)
  end
  W.listN = #list
  W.listOffset = math.min(W.listOffset, math.max(0, #list - LROWS))
  W.midHead:SetText(searchText ~= "" and "Search" or (M.CAT[sel.cat] and M.CAT[sel.cat].label or (sel.cat == "tracked" and "Tracked" or "All materials")))
  W.midCount:SetText(#list > LROWS and ("%d-%d of %d"):format(W.listOffset + 1, math.min(#list, W.listOffset + LROWS), #list) or #list)
  sel.id = sel.id or s.matSel
  local e = sel.id == "both" and BOTH or (type(sel.id) == "number" and M.Get(sel.id))
  if not e then e = list[1]; sel.id = e and e.id end
  for i, r in ipairs(W.rows) do
    local x = list[i + W.listOffset]
    r.e = x or false
    r:SetShown(x ~= nil)
    if x then
      r.icon:SetTexture(iconOf(x))
      r.name:SetText((M.ACCENT[x.cat] or "") .. M.Name(x) .. "|r")
      r.sub:SetText(subText(x))
      r.have:SetText(ownedText(x))
      local p = type(x.id) == "number" and NW.Price and NW.Price(x.id)
      r.price:SetText(p and ("~" .. NW.Money(p, true)) or "")
      r:SetSelected(x == e)
    end
  end
  -- details
  right:SetShown(e ~= nil)
  if not e then return end
  W.icon:SetTexture(iconOf(e))
  W.name:SetText(M.Name(e))
  local cat = M.CAT[e.cat]
  local subParts = { cat and cat.label or "" }
  if e.uses and e.uses > 0 then subParts[#subParts + 1] = ("Used in %d recipe%s"):format(e.uses, e.uses == 1 and "" or "s") end
  local p, psrc
  if type(e.id) == "number" and NW.Price then p, psrc = NW.Price(e.id) end
  if p then subParts[#subParts + 1] = (psrc == "vendor" and "Vendor " or "~") .. NW.Money(p) end
  W.sub:SetText(table.concat(subParts, "  ·  "))
  local fromP = sel.from and NW.PROF_BY_KEY[sel.from]
  W.back:SetShown(fromP ~= nil)
  if fromP then W.back:SetText("‹ " .. fromP.name) end
  W.ah:SetShown(type(e.id) == "number" and NW.HasAuctionator and NW.HasAuctionator())
  if W.back:IsShown() then W.ah:SetPoint("TOPRIGHT", 0, -24) else W.ah:SetPoint("TOPRIGHT", 0, 0) end
  -- objective
  local isItem = type(e.id) == "number"
  goalBar:SetShown(isItem)
  if isItem then
    local g = M.Goal(e.id)
    local have = NW.ItemCount(e.id)
    local life = NW.GatherLog and NW.GatherLog.Item(e.id).n or 0
    local sess = NW.GatherLog and NW.GatherLog.Session(e.id) or 0
    local txt
    if g then
      local pr = M.Progress(g)
      txt = (g.mode == "more" and "Collected %s / %d" or "Owned %s / %d"):format((pr.done and S.HEX.good or "") .. pr.shown .. "|r", pr.target)
        .. (pr.done and ("  " .. S.HEX.good .. "done|r") or ("  " .. DIM .. "·|r  Remaining " .. pr.remaining))
    else
      txt = "Owned " .. have
    end
    if sess > 0 then txt = txt .. "  " .. DIM .. "·|r  Session " .. sess end
    if life > 0 then txt = txt .. "  " .. DIM .. "·|r  Lifetime " .. life end
    W.goalText:SetText(txt)
    W.goalClear:SetShown(g ~= nil)
    if g then W.goalSet:SetPoint("RIGHT", W.goalClear, "LEFT", -4, 0) else W.goalSet:SetPoint("RIGHT", -3, 0) end
    W.goalSet:SetText(g and "Update" or "Track")
    if not W.goalEdit:HasFocus() then
      if sel.need and not g then W.goalEdit:SetText(sel.need); W.mode = "more"
      elseif g then W.goalEdit:SetText(g.n); W.mode = g.mode
      else W.goalEdit:SetText(""); W.mode = W.mode or "total" end
    end
    W.goalMode:Refresh()
  end
  -- source switches
  local srcs = e.id == "both" and { "nodes" } or M.Sources(e)
  local okSrc = false
  for _, k in ipairs(srcs) do if k == sel.src then okSrc = true end end
  if not okSrc then sel.src = srcs[1]; sel.zone = nil; W.zoneOffset = 0 end
  local x = 0
  for _, k in ipairs(SRC_ORDER) do W.srcBtns[k]:Hide() end
  for _, k in ipairs(srcs) do
    local b = W.srcBtns[k]
    b:SetText(e.id == "both" and "Gathering" or M.SourceText(e, k))
    b:SetWidth(math.max(80, b.label:GetStringWidth() + 24))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", right, "TOPLEFT", x, isItem and -82 or -50)
    x = x + b:GetWidth() + 4
    b.mark:SetShown(k == sel.src)
    b.label:SetTextColor(unpack(k == sel.src and S.gold or S.dim))
    b:Show()
  end
  body:ClearAllPoints()
  body:SetPoint("TOPLEFT", 0, isItem and BODY_Y or BODY_Y + 32)
  body:SetPoint("BOTTOMRIGHT")
  resetBody()
  if sel.src == "nodes" then viewNodes(e)
  elseif sel.src == "fishing" then viewFishing(e)
  elseif sel.src == "skin" or sel.src == "loot" then viewHunt(e, sel.src)
  elseif sel.src == "vendor" then viewVendor(e)
  elseif sel.src == "craft" then viewCraft(e)
  else
    zbox:Hide(); preview:Hide()
    W.note:SetText("No known source in Nodewalker's data. Check the auction house.")
  end
  local sk = sel.src == "skin" and "skinning" or (sel.src == "fishing" and "fishing") or (e.nodeKind == "herb" and "herbalism") or (e.nodeKind == "ore" and "mining")
  local pr = sk and NW.PROF_BY_KEY[sk]
  local lv = sk and NW.ProfSkill and NW.ProfSkill(sk)
  NW.SetWindowSubtitle(pr and (pr.name .. "  " .. (lv or "·  Not learned")) or "")
end

-- sort for hunting grounds (shown with the creature views)
W.huntSort = UI.Dropdown(page, 186, "Sort", (function()
  local items = {}
  for _, s in ipairs(H.SORTS) do items[#items + 1] = { s[1], s[2] } end
  return items
end)(), function() return st().huntSort or "density" end, function(v) st().huntSort = v ~= "density" and v or nil; refresh() end, 140,
  "Most spawns: known spawn points × drop chance (Classic data).\nNearest my level: creatures closest to your level.\nMy history: where you've collected it.")
W.huntSort:SetPoint("TOPRIGHT", body, "TOPLEFT", LIST_W, 2)
W.nodeSort = UI.Dropdown(page, 186, "Sort", { { "best", "Best" }, { "rate", "Spots per minute" }, { "gold", "Gold per hour" }, { "count", "Known spots" }, { "loop", "Shortest loop" } },
  function() return st().guideSort or "best" end, function(v) st().guideSort = v ~= "best" and v or nil; refresh() end, 140,
  "Best: spots per minute (gold per hour for Herbs and ore), favouring zones with enough spots for a loop.")
W.nodeSort:SetPoint("TOPRIGHT", body, "TOPLEFT", LIST_W, 2)
local baseRefresh = refresh
refresh = function()
  baseRefresh()
  if not page:IsShown() then return end
  W.huntSort:SetShown(right:IsShown() and (sel.src == "skin" or sel.src == "loot"))
  W.nodeSort:SetShown(right:IsShown() and sel.src == "nodes")
end

-- live: bags, objectives, routes, your log
local queued
local function later()
  if queued or not page:IsShown() then return end
  queued = true
  C_Timer.After(0.3, function() queued = false; refresh() end)
end
M.OnChange(later)
H.OnChange(later)
if NW.GatherLog then NW.GatherLog.OnChange(later) end
NW.On("BAG_UPDATE_DELAYED", later)

function NW.ToggleGuide() NW.ToggleWindow("guide") end
local function open()
  if NW.window:IsShown() then NW.ShowTab("guide") else st().lastTab = "guide"; NW.window:Show() end
  refresh()
end
-- Open on one material: from a profession's shopping list (from = its key,
-- need = what's missing, offered as a target), or anywhere else
function NW.FindMaterial(id, from, need)
  local e = M.Get(id)
  if not e then return false end
  sel.id, sel.src, sel.zone, sel.from, sel.need = id, nil, nil, from, need
  sel.cat = e.cat
  if searchText ~= "" then search:SetText("") end
  open()
  return true
end
-- Open on a herb or ore node (old Farm Guide entry point)
function NW.GuideSelectHerb(name)
  local id = NW.NODE_ITEMS[name]
  if not (id and NW.FindMaterial(id)) then open() end
end
-- Open on a category, optionally a source (Skinning's brackets)
function NW.FindMaterials(cat, id, src)
  sel.cat, sel.from, sel.need = cat, nil, nil
  if id then sel.id = id end
  sel.src = src
  if searchText ~= "" then search:SetText("") end
  open()
end
