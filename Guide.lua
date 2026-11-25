local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Farm Guide tab: the best zones for one herb or ore, ranked with your own node
-- data, and a one-click route through just that herb.
------------------------------------------------------------------------
local refreshGuide
local page
page = UI.AddTab("guide", "Farm Guide", function() refreshGuide() if NW.MaybeImportPrompt then NW.MaybeImportPrompt(page) end end)
local selectedHerb, previewID, lastHerb
-- Herbs or ore: the tab shows one list at a time
local kind = "herb"
local KIND = {
  herb = { guide = NW.HERB_GUIDE, skill = "Herbalism", word = "herb", edge = "herbEdge" },
  ore = { guide = NW.ORE_GUIDE, skill = "Mining", word = "ore", edge = "oreEdge" },
  -- everything your skills and filters let you gather, for running both
  both = { guide = { { "Herbs and ore", "Every herb and ore node your skills and filters allow, ranked by what a loop is worth.", {} } }, edge = "herbEdge" },
}
local picked = {} -- last selection per kind
-- Does a saved node count as this guide entry? (ooze-covered veins do)
local function matches(entry, nd)
  local name = nd.name
  if kind == "both" then
    local skill, req = NW.GetSkill(nd.kind), NW.RequiredSkill(name)
    return skill ~= nil and (not req or req <= skill) and NW.NodeWanted(nd, NW.db.settings)
  end
  if name == entry[1] then return true end
  for _, alt in ipairs(entry[4] or {}) do if alt == name then return true end end
  return false
end
local function focusOf(entry)
  local f = { [entry[1]] = true }
  for _, alt in ipairs(entry[4] or {}) do f[alt] = true end
  return f
end
local function entryFor(name)
  for _, e in ipairs(KIND[kind].guide) do if e[1] == name then return e end end
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

-- Quick loop through a set of points (nearest neighbour), in yards
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

-- Ranked zones for a herb: { mapID, name, note, recommended, count, loop, rate, pts }
local function rankZones(entry)
  local herb = entry[1]
  local sig = totalNodes()
  if kind == "both" then sig = ("%d:%s:%s"):format(sig, tostring(NW.GetSkill("herb")), tostring(NW.GetSkill("ore"))) end
  local c = cache[herb]
  if c and c.sig == sig then return c.rows end
  local rows, seen = {}, {}
  local function measure(id, name, note, rec)
    local w, h = NW.MapSize(id)
    local pts = {}
    for _, nd in ipairs(NW.db.nodes[id] or {}) do
      if matches(entry, nd) then pts[#pts + 1] = { (w and nd.x * w) or nd.x, (h and nd.y * h) or nd.y, nd.x, nd.y, nd.kind, nd.name } end
    end
    -- what one lap is worth at today's prices (about two per node). Rare
    -- spawns are only up at a few of their spots at a time.
    local RARE = { ["Black Lotus"] = 0.02, ["Silver Vein"] = 0.15, ["Ooze Covered Silver Vein"] = 0.15, ["Gold Vein"] = 0.15,
      ["Ooze Covered Gold Vein"] = 0.15, ["Truesilver Deposit"] = 0.15, ["Ooze Covered Truesilver Deposit"] = 0.15 }
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
      -- favour zones with enough spots to keep a loop going
      row.score = row.rate * math.min(1, #pts / 25)
      -- running both professions: what the loop pays matters more than node count
      if kind == "both" and row.gold then row.score = row.gold * math.min(1, #pts / 25) end
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
        if matches(entry, nd) then
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
  cache[herb] = { sig = sig, rows = rows }
  return rows
end

-- Left: herb list

------------------------------------------------------------------------
-- Left: herb list
------------------------------------------------------------------------
local LIST_W, ROW_H = 224, 16
local herbRows = {}
local MAX_LIST = math.max(#NW.HERB_GUIDE, #NW.ORE_GUIDE)
local kindBtns = {}
local KW = (LIST_W - 8) / 3
for i, k in ipairs({ "herb", "ore", "both" }) do
  local b = UI.Button(page, k == "herb" and "Herbs" or k == "ore" and "Ore" or "Both", KW, function()
    if kind == k then return end
    picked[kind] = selectedHerb
    kind, selectedHerb, previewID = k, picked[k], nil
    refreshGuide()
  end, 22)
  b:SetPoint("TOPLEFT", 16 + (i - 1) * (KW + 4), -6)
  b.mark = b:CreateTexture(nil, "OVERLAY")
  b.mark:SetPoint("BOTTOMLEFT", 1, 1)
  b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
  b.mark:SetHeight(2)
  b.mark:SetColorTexture(unpack(S.gold))
  kindBtns[k] = b
end
-- a search above the list
local search = CreateFrame("EditBox", nil, page, "BackdropTemplate")
search:SetSize(LIST_W, 22)
search:SetPoint("TOPLEFT", 16, -32)
UI.Flat(search, S.sunk, S.edge)
search:SetFont(UI.FONT, 12, "")
search:SetTextColor(unpack(S.text))
search:SetTextInsets(22, 8, 0, 0)
search:SetAutoFocus(false)
search:SetMaxLetters(30)
local sIcon = search:CreateTexture(nil, "ARTWORK")
sIcon:SetSize(13, 13)
sIcon:SetPoint("LEFT", 6, 0)
sIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
sIcon:SetVertexColor(unpack(S.dim))
local sHint = UI.Text(search, 12, S.disabled)
sHint:SetPoint("LEFT", 22, 0)
sHint:SetText("Search")
local searchText = ""
search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged", function(self)
  local t = (self:GetText() or ""):lower()
  sHint:SetShown(t == "")
  if t ~= searchText then searchText = t refreshGuide() end
end)
local list = UI.Box(page, LIST_W, MAX_LIST * ROW_H + 8)
list:SetPoint("TOPLEFT", 16, -58)

local SKILL_RGB = {
  red = { 1, 0.25, 0.2 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 0.9, 0.2 },
  green = { 0.35, 0.8, 0.35 }, grey = { 0.55, 0.55, 0.55 }, unknown = { 0.85, 0.85, 0.85 },
}

for i = 1, MAX_LIST do
  local b = CreateFrame("Button", nil, list)
  b:SetSize(LIST_W - 2, ROW_H)
  b:SetPoint("TOPLEFT", 1, -4 - (i - 1) * ROW_H)
  UI.RowStripe(b)
  b:SetStripe(i % 2 == 0)
  UI.RowHighlight(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(14, 14)
  b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = UI.Text(b, 12, S.text)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.skill = UI.Text(b, 11, S.dim, "RIGHT")
  b.skill:SetPoint("RIGHT", -8, 0)
  b:SetScript("OnClick", function(self) if self.entry then selectedHerb = self.entry[1]; refreshGuide() end end)
  -- what the colour means, on hover
  b:SetScript("OnEnter", function(self)
    if not self.entry or kind == "both" then return end
    local K = KIND[kind]
    local req = NW.RequiredSkill(self.entry[1])
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.entry[1], 1, 1, 1)
    GameTooltip:AddLine(("Needs %s %s"):format(K.skill, req or "?"), S.dim[1], S.dim[2], S.dim[3])
    GameTooltip:AddLine("|cffff4033Red|r too high  ·  |cffff8040orange|r |cffffe633yellow|r |cff59cc59green|r skill-ups  ·  |cff8c8c8cgrey|r none", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  herbRows[i] = b
end
local listKey = { SetShown = function() end } -- (the colour key is in the row tooltips now)

------------------------------------------------------------------------
-- Right: details
------------------------------------------------------------------------
local RIGHT_X = 16 + LIST_W + 18
local TEXT_W = 430
local right = CreateFrame("Frame", nil, page)
right:SetPoint("TOPLEFT", RIGHT_X, -8)
right:SetPoint("BOTTOMRIGHT", -16, 8)

local hIconBox = UI.Box(right, 40, 40)
hIconBox:SetPoint("TOPLEFT")
local hIcon = hIconBox:CreateTexture(nil, "ARTWORK")
hIcon:SetPoint("TOPLEFT", 1, -1)
hIcon:SetPoint("BOTTOMRIGHT", -1, 1)
hIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local hName = UI.Text(right, 17, S.gold)
hName:SetPoint("TOPLEFT", hIconBox, "TOPRIGHT", 10, -2)
local hSkill = UI.Text(right, 12, S.dim)
hSkill:SetPoint("TOPLEFT", hName, "BOTTOMLEFT", 0, -5)
hSkill:SetWidth(TEXT_W - 50)
local hTip = UI.Text(right, 12, S.text)
hTip:SetPoint("TOPLEFT", hIconBox, "BOTTOMLEFT", 0, -10)
hTip:SetWidth(TEXT_W)
hTip:SetHeight(30)
hTip:SetJustifyV("TOP")

local colHead = UI.Heading(right, "Zones", TEXT_W - 196)
colHead:SetPoint("TOPLEFT", hTip, "BOTTOMLEFT", 0, -8)
local SORTS = { { "best", "Best" }, { "rate", "Spots per minute" }, { "gold", "Gold per hour" }, { "count", "Known spots" }, { "loop", "Shortest loop" } }
local sortDrop = UI.Dropdown(right, 186, "Sort", SORTS, function() return NW.db.settings.guideSort or "best" end,
  function(v) NW.db.settings.guideSort = v ~= "best" and v or nil; refreshGuide() end, 140,
  "Best: spots per minute (gold per hour for Both), favouring zones with enough spots for a loop.")
sortDrop:SetPoint("RIGHT", colHead, "RIGHT", 196, 0)
-- column captions; their tooltips say what each number is
local COLS = {
  { "Spots", 268, "Known spots", "Places a node has been seen. Not all are up at once." },
  { "Loop", 322, "Loop", "One lap mounted, past every known spot. No time for gathering." },
  { "/min", 370, "Spots per minute", "Known spots passed per minute of that loop." },
  { "g/h", TEXT_W - 8, "Gold per hour", "If every spot were up: about two items each at Auctionator prices. An estimate, not income." },
}
local colBar = CreateFrame("Frame", nil, right)
colBar:SetSize(TEXT_W, 18)
colBar:SetPoint("TOPLEFT", colHead, "BOTTOMLEFT", 0, -4)
local zl = UI.Text(colBar, 10, S.dim)
zl:SetPoint("LEFT", 10, 0)
zl:SetText("Zone")
for _, c in ipairs(COLS) do
  local h = CreateFrame("Frame", nil, colBar)
  h:SetSize(46, 18)
  h:SetPoint("RIGHT", colBar, "LEFT", c[2], 0)
  h:EnableMouse(true)
  local t = UI.Text(h, 10, S.dim, "RIGHT")
  t:SetPoint("RIGHT")
  t:SetText(c[1])
  h:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(c[3], 1, 1, 1)
    GameTooltip:AddLine(c[4], S.dim[1], S.dim[2], S.dim[3], true)
    GameTooltip:Show()
  end)
  h:SetScript("OnLeave", GameTooltip_Hide)
end
local colSub = { SetText = function() end } -- (the sort says how it's ranked)

-- Preview map
local PV_W, PV_H = 300, 200
local preview = UI.Box(right, PV_W + 2, PV_H + 2)
preview:SetPoint("TOPRIGHT")
preview:SetClipsChildren(true)
local pvArt = CreateFrame("Frame", nil, preview)
pvArt:SetPoint("TOPLEFT", 1, -1)
pvArt:SetSize(PV_W, PV_H)
local pvTitle = UI.Text(right, 12, S.text)
pvTitle:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
pvTitle:SetWidth(PV_W)
local pvSub = UI.Text(right, 11, S.dim)
pvSub:SetPoint("TOPLEFT", pvTitle, "BOTTOMLEFT", 0, -3)
pvSub:SetWidth(PV_W)
-- the selected zone's numbers, label left and value right
local stats = {}
for i, l in ipairs({ "Known spots", "Loop", "Spots per minute", "Gold per hour" }) do
  local a = UI.Text(right, 12, S.dim)
  a:SetPoint("TOPLEFT", pvSub, "BOTTOMLEFT", 0, -10 - (i - 1) * 18)
  a:SetText(l)
  local v = UI.Text(right, 12, S.text, "RIGHT")
  v:SetPoint("TOPRIGHT", pvSub, "BOTTOMLEFT", PV_W, -10 - (i - 1) * 18)
  stats[i] = v
end
local alsoOthers = UI.Check(right, "Also pick other herbs and ore",
  function() return NW.db.settings.guideAlsoOthers end,
  function(v) NW.db.settings.guideAlsoOthers = v end,
  "The route also stops at every other herb and ore your filters allow.")
alsoOthers:SetPoint("TOPLEFT", pvSub, "BOTTOMLEFT", 2, -10 - 4 * 18 - 4)
local buildBtn = UI.Button(right, "Build route", PV_W, nil, 26, "primary")
buildBtn:SetPoint("TOPLEFT", alsoOthers, "BOTTOMLEFT", -2, -12)
UI.Tip(buildBtn, "Build route", "Replaces this zone's saved route.")
local pvTiles = {}
-- drawn like the Route map: the zone fully explored in its own colours,
-- round dots, and the loop shaded gold to blue so its order reads
local pvShade = pvArt:CreateTexture(nil, "BORDER")
pvShade:SetAllPoints()
pvShade:SetColorTexture(0, 0, 0, 0.18)
local getPvDot, resetPvDots = UI.Pool(function()
  local t = pvArt:CreateTexture(nil, "OVERLAY")
  local mask = pvArt:CreateMaskTexture()
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(t)
  t:AddMaskTexture(mask)
  t:SetSize(5, 5)
  return t
end)
local function routeColor(t)
  if t < 0.5 then
    local k = t * 2
    return 0.95 + (0.3 - 0.95) * k, 0.8 + (0.78 - 0.8) * k, 0.4 + (0.8 - 0.4) * k
  end
  local k = (t - 0.5) * 2
  return 0.3 + (0.35 - 0.3) * k, 0.78 + (0.5 - 0.78) * k, 0.8 + (0.95 - 0.8) * k
end
local getPvLine, resetPvLines = UI.Pool(function()
  local l = pvArt:CreateLine(nil, "ARTWORK")
  l:SetThickness(2)
  return l
end)

local function fmtTime(sec)
  return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60))
end

local zoneRows = {}
local function drawPreview(row, herb)
  resetPvDots(); resetPvLines()
  for _, t in ipairs(pvTiles) do t:Hide() end
  previewID = row and row.mapID
  for _, r in ipairs(zoneRows) do r:SetSelected(r.row ~= nil and r.row == row) end
  for k = 1, 4 do stats[k]:SetText("") end
  buildBtn:SetEnabled(row ~= nil and row.mapID ~= nil and row.count > 0)
  if not row then pvTitle:SetText(""); pvSub:SetText("") return end
  pvTitle:SetText(row.name)
  stats[1]:SetText(row.count)
  if row.rate then
    stats[2]:SetText(fmtTime(row.loop / NW.MOUNT_YPS))
    stats[3]:SetText(("%.1f"):format(row.rate))
    stats[4]:SetText(row.gold and ("~" .. NW.Money(row.gold, true)) or "|cff938c80no prices|r")
  end
  if not row.mapID then
    pvSub:SetText("This zone isn't on your client's map list.")
    return
  end
  UI.DrawZoneArt(row.mapID, pvArt, pvTiles, PV_W, PV_H, true)
  local function p(x, y) return x * PV_W, -y * PV_H end
  local route = NW.db.routes[row.mapID]
  local isFocus = route and ((route.focus and route.focus[herb]) or (kind == "both" and not route.focus))
  local edge = C[KIND[kind].edge]
  if isFocus and #route.stops > 1 then
    local st = route.stops
    for i = 1, #st do
      local pts = i == route.open and {} or NW.LegPoints(route, i)
      local r, g, b = routeColor((i - 1) / #st)
      for q = 1, #pts - 1 do
        local l = getPvLine()
        l:SetColorTexture(r, g, b, 0.95)
        l:SetStartPoint("TOPLEFT", pvArt, p(pts[q][1], pts[q][2]))
        l:SetEndPoint("TOPLEFT", pvArt, p(pts[q + 1][1], pts[q + 1][2]))
      end
    end
    for _, a in ipairs(st) do
      local d = getPvDot()
      local e = a.kind == "ore" and C.oreEdge or C.herbEdge
      d:SetSize(7, 7)
      d:SetColorTexture(e[1], e[2], e[3], 1)
      d:ClearAllPoints()
      d:SetPoint("CENTER", pvArt, "TOPLEFT", p(a.x, a.y))
    end
    pvSub:SetText(("Your route  ·  %d stops, %s %s"):format(#st, fmtTime(route.seconds or 0), route.open and "each way" or "per loop"))
  elseif row.order and #row.pts <= 400 then
    for i = 1, #row.order do
      local a, b = row.pts[row.order[i]], row.pts[row.order[(i % #row.order) + 1]]
      local l = getPvLine()
      l:SetColorTexture(1, 1, 1, 0.45)
      l:SetStartPoint("TOPLEFT", pvArt, p(a[3], a[4]))
      l:SetEndPoint("TOPLEFT", pvArt, p(b[3], b[4]))
    end
    pvSub:SetText("Known spots  ·  no route built")
  else
    pvSub:SetText(row.count > 0 and "Known spots" or "No spots saved yet")
  end
  local routed = isFocus and #route.stops > 1
  for _, pt in ipairs(routed and {} or row.pts) do
    local d = getPvDot()
    d:SetSize(5, 5)
    local e = pt[5] == "ore" and C.oreEdge or pt[5] == "herb" and C.herbEdge or edge
    d:SetColorTexture(e[1], e[2], e[3], 1)
    d:ClearAllPoints()
    d:SetPoint("CENTER", pvArt, "TOPLEFT", p(pt[3], pt[4]))
  end
end

-- Zone rows: click selects (the map and numbers follow); right-click builds its route
local ROWS, ZROW_H = 14, 24
local moreOpen, zoneOffset, allRows = false, 0, {}
local function buildFor(row, herb)
  if not row or not row.mapID or row.count == 0 then return end
  NW.BuildRoute(row.mapID, function()
    if page:IsShown() then drawPreview(row, herb) end
  end, kind == "both" and {} or { focus = focusOf(entryFor(herb)), alsoOthers = NW.db.settings.guideAlsoOthers })
end
buildBtn:SetScript("OnClick", function()
  for _, row in ipairs(allRows) do if row.mapID and row.mapID == previewID then buildFor(row, selectedHerb) return end end
end)
local zoneBox = CreateFrame("Frame", nil, right)
zoneBox:SetSize(TEXT_W, ROWS * ZROW_H)
zoneBox:SetPoint("TOPLEFT", colBar, "BOTTOMLEFT", 0, -2)
zoneBox:EnableMouseWheel(true)
for i = 1, ROWS do
  local r = CreateFrame("Button", nil, zoneBox)
  r:SetSize(TEXT_W, ZROW_H - 1)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ZROW_H)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("LEFT", 10, 0)
  r.name:SetWidth(200)
  r.name:SetWordWrap(false)
  r.cells = {}
  for k, c in ipairs(COLS) do
    local t = UI.Text(r, 12, S.text, "RIGHT")
    t:SetPoint("RIGHT", r, "LEFT", c[2], 0)
    r.cells[k] = t
  end
  r:SetScript("OnClick", function(self, button)
    if button == "RightButton" then buildFor(self.row, selectedHerb) return end
    drawPreview(self.row, selectedHerb)
  end)
  r:SetScript("OnEnter", function(self)
    local row = self.row
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.name, 1, 1, 1)
    if row.recommended then GameTooltip:AddLine("Recommended by farming guides" .. (row.note and (": " .. row.note) or ""), S.gold[1], S.gold[2], S.gold[3], true)
    elseif not row.missing then GameTooltip:AddLine("Found in your own node data", S.dim[1], S.dim[2], S.dim[3]) end
    if row.missing then GameTooltip:AddLine("Not on your client's map list", S.dim[1], S.dim[2], S.dim[3]) end
    if row.mapID and row.count > 0 then GameTooltip:AddLine("Right-click: build its route", S.dim[1], S.dim[2], S.dim[3]) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  zoneRows[i] = r
end
local moreBtn = CreateFrame("Button", nil, right)
moreBtn:SetSize(TEXT_W, 18)
moreBtn:SetPoint("TOPLEFT", zoneBox, "BOTTOMLEFT", 0, -4)
local moreText = UI.Text(moreBtn, 11, S.gold)
moreText:SetPoint("LEFT", 10, 0)
moreBtn:SetScript("OnClick", function() moreOpen = not moreOpen zoneOffset = 0 refreshGuide() end)
moreBtn:SetScript("OnEnter", function() moreText:SetTextColor(unpack(S.text)) end)
moreBtn:SetScript("OnLeave", function() moreText:SetTextColor(unpack(S.gold)) end)
zoneBox:SetScript("OnMouseWheel", function(_, d)
  if not moreOpen then return end
  local max = math.max(0, #allRows - ROWS)
  local o = math.max(0, math.min(max, zoneOffset - d * 2))
  if o ~= zoneOffset then zoneOffset = o refreshGuide() end
end)
local TOP_N = 8

refreshGuide = function()
  if not page:IsShown() then return end
  local K = KIND[kind]
  local guide = K.guide
  local both = kind == "both"
  local herbSkill = not both and NW.GetSkill(kind) or nil
  if both then
    local hs, os = NW.GetSkill("herb"), NW.GetSkill("ore")
    NW.SetWindowSubtitle(("Herbalism %s  ·  Mining %s"):format(hs or "-", os or "-"))
  else
    NW.SetWindowSubtitle(herbSkill and (K.skill .. " " .. herbSkill) or (K.skill .. "  ·  Not learned"))
  end
  alsoOthers:SetShown(not both)
  listKey:SetShown(not both)
  for k, b in pairs(kindBtns) do
    b.mark:SetShown(k == kind)
    b.label:SetTextColor(unpack(k == kind and S.gold or S.dim))
  end
  if not (selectedHerb and entryFor(selectedHerb)) then
    selectedHerb = nil
    -- start on the highest one you can gather
    if herbSkill then
      for _, e in ipairs(guide) do
        local req = NW.RequiredSkill(e[1])
        if req and req <= herbSkill then selectedHerb = e[1] end
      end
    end
    selectedHerb = selectedHerb or guide[1][1]
  end
  if lastHerb ~= selectedHerb then previewID = nil; lastHerb = selectedHerb end
  local entry
  -- the search narrows the list (the one you're on stays selected)
  local shownList = guide
  if searchText ~= "" then
    shownList = {}
    for _, e in ipairs(guide) do if e[1]:lower():find(searchText, 1, true) then shownList[#shownList + 1] = e end end
  end
  for _, e in ipairs(guide) do if e[1] == selectedHerb then entry = e end end
  for i, b in ipairs(herbRows) do
    local e = shownList[i]
    b.entry = e
    b:SetShown(e ~= nil)
    if e then
      local req = NW.RequiredSkill(e[1])
      local col = SKILL_RGB[NW.SkillColor(req, herbSkill)] or SKILL_RGB.unknown
      b.icon:SetTexture(NW.NodeIcon(e[1], both and "herb" or kind))
      b.icon:SetDesaturated(NW.IsHidden(e[1]))
      b.text:SetText(e[1])
      b.text:SetTextColor(col[1], col[2], col[3])
      b.skill:SetText(both and "" or req or "?")
      b:SetSelected(e[1] == selectedHerb)
    end
  end
  local req = NW.RequiredSkill(entry[1])
  hIcon:SetTexture(NW.NodeIcon(entry[1], both and "herb" or kind))
  hName:SetText(entry[1])
  local skillLine = both and "What you can gather now, with your Herbs & Ore filters" or ("Needs %s %s"):format(K.skill, req or "?")
  if herbSkill and req then
    local c = NW.SkillColor(req, herbSkill)
    skillLine = skillLine .. (c == "red" and "  ·  |cffd17665skill too low|r"
      or c == "grey" and "  ·  no more skill-ups"
      or "  ·  |cff94ba78gives skill-ups|r")
  end
  if NW.IsHidden(entry[1]) then skillLine = skillLine .. "  ·  hidden on your map" end
  hSkill:SetText(skillLine)
  hTip:SetText(entry[2])

  local rows = rankZones(entry)
  -- ordered by the sort you picked (Best keeps the guide's own ranking)
  local by = NW.db.settings.guideSort
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
  allRows = rows
  local visibleN = moreOpen and #rows or math.min(TOP_N, #rows)
  for i, r in ipairs(zoneRows) do
    local idx = i + (moreOpen and zoneOffset or 0)
    local row = i <= visibleN and rows[idx] or nil
    r.row = row
    if row then
      r.name:SetText((row.recommended and "|cffd6b266*|r " or "   ") .. row.name)
      r.name:SetTextColor(unpack(row.count > 0 and S.text or S.dim))
      if row.rate then
        r.cells[1]:SetText(row.count)
        r.cells[2]:SetText(fmtTime(row.loop / NW.MOUNT_YPS))
        r.cells[3]:SetText(("%.1f"):format(row.rate))
        r.cells[4]:SetText(row.gold and ("~" .. NW.Money(row.gold, true)) or "|cff938c80–|r")
      else
        r.cells[1]:SetText(row.count > 0 and row.count or "|cff938c80–|r")
        for k = 2, 4 do r.cells[k]:SetText("|cff938c80–|r") end
      end
      r:Show()
    else
      r:Hide()
    end
  end
  local extra = #rows - TOP_N
  moreBtn:SetShown(extra > 0)
  moreText:SetText(moreOpen and "Show fewer zones" or ("Show %d more zone%s"):format(extra, extra == 1 and "" or "s"))
  local pv = rows[1]
  for _, row in ipairs(rows) do if previewID and row.mapID == previewID then pv = row end end
  drawPreview(pv, entry[1])
end

function NW.ToggleGuide() NW.ToggleWindow("guide") end

-- Open the guide on one herb (from the Professions tab)
function NW.GuideSelectHerb(name)
  kind = (NW.NODES[name] and NW.NODES[name][1] == "ore") and "ore" or "herb"
  selectedHerb = name
  if NW.window:IsShown() then NW.ShowTab("guide") else NW.db.settings.lastTab = "guide"; NW.window:Show() end
end
