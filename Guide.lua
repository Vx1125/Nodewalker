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
-- Layout (second pass): categories | materials and the source table |
-- the material, its target, a large map workspace, actions.
------------------------------------------------------------------------
local L_W, C_X, C_W, R_X = 160, 186, 262, 458
local R_W = UI.CONTENT_W - R_X - 16
local MAP_W, MAP_H = 440, 290
local SIDE_X = MAP_W + 12
local SIDE_W = R_W - SIDE_X
local WS_Y = -124 -- top of the workspace (map tabs)
local SKILL_HEX = { red = "|cffff4033", orange = "|cffff8040", yellow = "|cffffe633", green = "|cff59cc59", grey = "|cff8c8c8c" }
local TEAL = "|cff59bfb8"
local function fmtTime(sec) return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60)) end
local function dash() return DIM .. "–|r" end
local function heading(parent, text, w)
  local h = UI.Heading(parent, text, w)
  return h
end
local function tabMark(b)
  b.mark = b:CreateTexture(nil, "OVERLAY")
  b.mark:SetPoint("BOTTOMLEFT", 1, 1)
  b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
  b.mark:SetHeight(2)
  b.mark:SetColorTexture(unpack(S.gold))
end

------------------------------------------------------------------------
-- Left: search, categories, tracked targets
------------------------------------------------------------------------
local search = CreateFrame("EditBox", nil, page, "BackdropTemplate")
search:SetSize(L_W, 22)
search:SetPoint("TOPLEFT", 16, -8)
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

local CAT_H, CAT_N = 24, 13
W.cats = {}
local catBox = UI.Box(page, L_W, CAT_N * CAT_H + 6)
catBox:SetPoint("TOPLEFT", 16, -36)
for i = 1, CAT_N do
  local b = CreateFrame("Button", nil, catBox)
  b:SetSize(L_W - 2, CAT_H)
  b:SetPoint("TOPLEFT", 1, -3 - (i - 1) * CAT_H)
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
W.trackHead = heading(page, "Tracked", L_W)
W.track = {}
for i = 1, 8 do
  local r = CreateFrame("Button", nil, page)
  r:SetSize(L_W, 18)
  r.name = UI.Text(r, 11, S.text)
  r.name:SetPoint("LEFT", 2, 0)
  r.name:SetPoint("RIGHT", -60, 0)
  r.name:SetWordWrap(false)
  r.n = UI.Text(r, 11, S.dim, "RIGHT")
  r.n:SetPoint("RIGHT", -2, 0)
  r:SetScript("OnClick", function(self)
    if self.id then sel.id, sel.src, sel.zone = self.id, nil, nil; st().matSel = self.id; refresh() end
  end)
  W.track[i] = r
end

------------------------------------------------------------------------
-- Centre: materials, then the selected source's table
------------------------------------------------------------------------
local LROW_H, LROW_MAX = 30, 9
W.midHead = UI.Text(page, 12, S.gold)
W.midHead:SetPoint("TOPLEFT", C_X + 2, -10)
W.midCount = UI.Text(page, 11, S.dim, "RIGHT")
W.midCount:SetPoint("TOPRIGHT", page, "TOPLEFT", C_X + C_W - 2, -10)
local mid = UI.Box(page, C_W, 5 * LROW_H + 4)
mid:SetPoint("TOPLEFT", C_X, -30)
mid:EnableMouseWheel(true)
W.rows = {}
W.listOffset = 0
for i = 1, LROW_MAX do
  local r = CreateFrame("Button", nil, mid)
  r:SetSize(C_W - 2, LROW_H)
  r:SetPoint("TOPLEFT", 1, -2 - (i - 1) * LROW_H)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 6, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 7, 2)
  r.name:SetPoint("RIGHT", -64, 0)
  r.name:SetWordWrap(false)
  r.sub = UI.Text(r, 10, S.dim)
  r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 7, -2)
  r.sub:SetPoint("RIGHT", -64, 0)
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
  local max = math.max(0, (W.listN or 0) - (W.listShown or 5))
  local o = math.max(0, math.min(max, W.listOffset - d * 2))
  if o ~= W.listOffset then W.listOffset = o; refresh() end
end)

-- the source table: heading (+ sort), column captions, rows
local tbl = CreateFrame("Frame", nil, page)
tbl:SetSize(C_W, 200)
W.tblHead = heading(tbl, "", C_W)
W.tblHead:SetPoint("TOPLEFT")
W.colName = UI.Text(tbl, 10, S.dim)
W.colName:SetPoint("TOPLEFT", 8, -22)
W.cols = {}
for k = 1, 3 do
  local t = UI.Text(tbl, 10, S.dim, "RIGHT")
  W.cols[k] = t
end
local TROW_H, TROWS = 22, 7
local tbox = UI.Box(tbl, C_W, TROWS * TROW_H + 4)
tbox:SetPoint("TOPLEFT", 0, -36)
tbox:EnableMouseWheel(true)
W.zrows = {}
for i = 1, TROWS do
  local r = CreateFrame("Button", nil, tbox)
  r:SetSize(C_W - 2, TROW_H)
  r:SetPoint("TOPLEFT", 1, -2 - (i - 1) * TROW_H)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("LEFT", 8, 0)
  r.name:SetWidth(128)
  r.name:SetWordWrap(false)
  r.cells = {}
  for k = 1, 3 do r.cells[k] = UI.Text(r, 12, S.text, "RIGHT") end
  r:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
  r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.zrows[i] = r
end
W.zoneOffset = 0
tbox:SetScript("OnMouseWheel", function(_, d)
  local max = math.max(0, (W.zoneN or 0) - TROWS)
  local o = math.max(0, math.min(max, W.zoneOffset - d * 2))
  if o ~= W.zoneOffset then W.zoneOffset = o; refresh() end
end)
local COLX = { C_W - 96, C_W - 50, C_W - 8 }
local function setCols(names)
  for k = 1, 3 do
    local x = COLX[k]
    W.cols[k]:ClearAllPoints()
    W.cols[k]:SetPoint("TOPRIGHT", tbl, "TOPLEFT", x, -22)
    W.cols[k]:SetText(names[k] or "")
    for _, r in ipairs(W.zrows) do
      r.cells[k]:ClearAllPoints()
      r.cells[k]:SetPoint("RIGHT", r, "LEFT", x, 0)
      r.cells[k]:SetText("")
    end
  end
end

-- the fold under the table: creatures in the selected zone
W.fold = CreateFrame("Button", nil, tbl)
W.fold:SetSize(C_W, 20)
W.fold:SetPoint("TOPLEFT", tbox, "BOTTOMLEFT", 0, -6)
local fbg = W.fold:CreateTexture(nil, "BACKGROUND")
fbg:SetAllPoints()
fbg:SetColorTexture(unpack(S.header))
W.fold.sign = UI.Text(W.fold, 12, S.gold)
W.fold.sign:SetPoint("LEFT", 6, 0)
W.fold.text = UI.Text(W.fold, 12, S.gold)
W.fold.text:SetPoint("LEFT", 20, 0)
W.fold.n = UI.Text(W.fold, 11, S.dim, "RIGHT")
W.fold.n:SetPoint("RIGHT", -8, 0)
W.fold:SetScript("OnClick", function()
  local key = "huntFold" .. (sel.src or "")
  local open = st()[key]
  if open == nil then open = sel.src ~= "skin" end
  st()[key] = not open
  refresh()
end)
W.crows = {}
for i = 1, 4 do
  local r = CreateFrame("Button", nil, tbl)
  r:SetSize(C_W, 18)
  r:SetPoint("TOPLEFT", W.fold, "BOTTOMLEFT", 0, -2 - (i - 1) * 18)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  r.name = UI.Text(r, 11, S.text)
  r.name:SetPoint("LEFT", 8, 0)
  r.name:SetWidth(140)
  r.name:SetWordWrap(false)
  r.lvl = UI.Text(r, 11, S.dim, "RIGHT")
  r.lvl:SetPoint("RIGHT", r, "LEFT", C_W - 92, 0)
  r.ch = UI.Text(r, 11, S.text, "RIGHT")
  r.ch:SetPoint("RIGHT", r, "LEFT", C_W - 48, 0)
  r.req = UI.Text(r, 11, S.text, "RIGHT")
  r.req:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.crows[i] = r
end
W.checkA = UI.Check(tbl, "", function() return W.checkAGet and W.checkAGet() end, function(v) if W.checkASet then W.checkASet(v) end refresh() end)
W.checkB = UI.Check(tbl, "", function() return W.checkBGet and W.checkBGet() end, function(v) if W.checkBSet then W.checkBSet(v) end refresh() end)

-- sorts for the table, shown with their views
local function sortItems()
  local items = {}
  for _, s in ipairs(H.SORTS) do items[#items + 1] = { s[1], s[2] } end
  return items
end
W.huntSort = UI.Dropdown(tbl, 130, "", sortItems(), function() return st().huntSort or "density" end,
  function(v) st().huntSort = v ~= "density" and v or nil; refresh() end, 112,
  "Most spawns: known spawn points × drop chance (Classic data).\nNearest my level: creatures closest to your level.\nMy history: where you've collected it.")
W.huntSort:SetPoint("TOPRIGHT", 0, 3)
W.nodeSort = UI.Dropdown(tbl, 130, "", { { "best", "Best" }, { "rate", "Spots per minute" }, { "gold", "Gold per hour" }, { "count", "Known spots" }, { "loop", "Shortest loop" } },
  function() return st().guideSort or "best" end, function(v) st().guideSort = v ~= "best" and v or nil; refresh() end, 112,
  "Best: spots per minute (gold per hour for Herbs and ore), favouring zones with enough spots for a loop.")
W.nodeSort:SetPoint("TOPRIGHT", 0, 3)

------------------------------------------------------------------------
-- Right: header, target strip, source switches
------------------------------------------------------------------------
local right = CreateFrame("Frame", nil, page)
right:SetPoint("TOPLEFT", R_X, 0)
right:SetSize(R_W, UI.CONTENT_H)
local iconBox = UI.Box(right, 40, 40)
iconBox:SetPoint("TOPLEFT", 0, -8)
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
W.name:SetPoint("RIGHT", right, "RIGHT", -230, 0)
W.name:SetWordWrap(false)
W.sub = UI.Text(right, 11, S.dim)
W.sub:SetPoint("TOPLEFT", W.name, "BOTTOMLEFT", 0, -5)
W.sub:SetPoint("RIGHT", right, "RIGHT", -110, 0)
W.sub:SetWordWrap(false)
W.ah = UI.Button(right, "Search AH", 92, function()
  if type(sel.id) ~= "number" or not NW.SearchAH then return end
  local n = NW.ItemName(sel.id)
  local g = M.Goal(sel.id)
  local need = g and M.Progress(g).remaining or 1
  if n then NW.SearchAH({ { n, math.max(1, need) } }) end
end, 22)
W.ah:SetPoint("TOPRIGHT", 0, -8)
UI.Tip(W.ah, "Search AH", "Searches Auctionator for it (at the auction house). With a target, for what's still missing.")
W.back = UI.Button(right, "", 120, function()
  if sel.from and NW.OpenProfession then NW.OpenProfession(sel.from) end
end, 22)
W.back:SetPoint("RIGHT", W.ah, "LEFT", -4, 0)

local goalBar = CreateFrame("Frame", nil, right)
goalBar:SetSize(R_W, 26)
goalBar:SetPoint("TOPLEFT", 0, -58)
local gbg = goalBar:CreateTexture(nil, "BACKGROUND")
gbg:SetAllPoints()
gbg:SetColorTexture(unpack(S.header))
W.goalText = UI.Text(goalBar, 12, S.text)
W.goalText:SetPoint("LEFT", 8, 0)
W.goalText:SetPoint("RIGHT", goalBar, "RIGHT", -262, 0)
W.goalText:SetWordWrap(false)
W.goalEdit = CreateFrame("EditBox", nil, goalBar, "BackdropTemplate")
W.goalEdit:SetSize(44, 20)
UI.Flat(W.goalEdit, S.sunk, S.edge)
W.goalEdit:SetFont(UI.FONT, 12, "")
W.goalEdit:SetTextColor(unpack(S.text))
W.goalEdit:SetTextInsets(6, 6, 0, 0)
W.goalEdit:SetAutoFocus(false)
W.goalEdit:SetNumeric(true)
W.goalEdit:SetMaxLetters(5)
W.goalEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local MODES = { { "total", "Own" }, { "more", "Collect" } }
W.goalMode = UI.Dropdown(goalBar, 70, "", MODES, function() return W.mode or "total" end, function(v) W.mode = v end, 70,
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
W.goalSet = UI.Button(goalBar, "Track", 54, trackNow, 20)
W.goalClear = UI.Button(goalBar, "Clear", 46, function() M.ClearGoal(sel.id); refresh() end, 20)
W.goalClear:SetPoint("RIGHT", -3, 0)
W.goalMode:SetPoint("RIGHT", W.goalSet, "LEFT", -4, 0)
W.goalEdit:SetPoint("RIGHT", W.goalMode, "LEFT", -4, 0)
W.goalLabel = UI.Text(goalBar, 11, S.dim, "RIGHT")
W.goalLabel:SetPoint("RIGHT", W.goalEdit, "LEFT", -6, 0)
W.goalLabel:SetText("Target")

W.srcBtns = {}
local SRC_ORDER = { "nodes", "fishing", "skin", "loot", "vendor", "craft" }
for _, k in ipairs(SRC_ORDER) do
  local b = UI.Button(right, k, 90, function() sel.src = k; sel.zone = nil; W.zoneOffset = 0; refresh() end, 24)
  tabMark(b)
  W.srcBtns[k] = b
end

------------------------------------------------------------------------
-- Map workspace: tabs, the map, the side column, caption
------------------------------------------------------------------------
local ws = CreateFrame("Frame", nil, right)
ws:SetPoint("TOPLEFT", 0, WS_Y)
ws:SetSize(R_W, 340)
local MODES_MAP = { { "known", "Known Sources" }, { "mine", "My History" }, { "route", "Route" }, { "heat", "Heatmap" } }
W.mapTabs = {}
local TAB_W = (MAP_W + 2 - 9) / 4
for i, m in ipairs(MODES_MAP) do
  local b = UI.Button(ws, m[2], TAB_W, function(self)
    if not self.ok then return end
    st().huntMap = m[1]
    refresh()
  end, 22)
  b:SetPoint("TOPLEFT", (i - 1) * (TAB_W + 3), 0)
  tabMark(b)
  b.key = m[1]
  W.mapTabs[i] = b
end
local preview = UI.Box(ws, MAP_W + 2, MAP_H + 2)
preview:SetPoint("TOPLEFT", 0, -22)
preview:SetClipsChildren(true)
local pvArt = CreateFrame("Frame", nil, preview)
pvArt:SetPoint("TOPLEFT", 1, -1)
pvArt:SetSize(MAP_W, MAP_H)
local pvShade = pvArt:CreateTexture(nil, "BORDER")
pvShade:SetAllPoints()
pvShade:SetColorTexture(0, 0, 0, 0.15)
local pvTiles = {}
W.plate = CreateFrame("Frame", nil, preview, "BackdropTemplate")
W.plate:SetPoint("TOPLEFT", 8, -8)
W.plate:SetFrameLevel(pvArt:GetFrameLevel() + 5)
UI.Flat(W.plate, { S.bg[1], S.bg[2], S.bg[3], 0.85 }, S.edge)
W.plate.text = UI.Text(W.plate, 12, S.gold)
W.plate.text:SetPoint("LEFT", 8, 0)
W.plate:SetHeight(20)
W.legend = CreateFrame("Frame", nil, preview, "BackdropTemplate")
W.legend:SetPoint("BOTTOMRIGHT", -8, 8)
W.legend:SetSize(132, 18)
W.legend:SetFrameLevel(pvArt:GetFrameLevel() + 5)
UI.Flat(W.legend, { S.bg[1], S.bg[2], S.bg[3], 0.85 }, S.edge)
W.legend.text = UI.Text(W.legend, 10, S.dim)
W.legend.text:SetPoint("CENTER")
W.mapNone = UI.Text(preview, 12, S.dim, "CENTER")
W.mapNone:SetPoint("CENTER")
W.mapNone:SetWidth(MAP_W - 60)
W.caption = UI.Text(ws, 11, S.dim)
W.caption:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
W.caption:SetWidth(MAP_W)
W.caption:SetWordWrap(false)

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
  f:SetFont(UI.FONT, 13, "OUTLINE")
  return f
end)
-- invisible hover areas over hunting grounds: who lives there
local getHot, resetHots = UI.Pool(function()
  local b = CreateFrame("Frame", nil, pvArt)
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    local g = self.g
    if not g then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title or "Hunting ground", 1, 1, 1)
    local list = {}
    for npc, n in pairs(g.npcs or {}) do list[#list + 1] = { u = H.Unit(npc), n = n } end
    table.sort(list, function(a, b2) return a.n > b2.n end)
    local skill = NW.ProfSkill and NW.ProfSkill("skinning")
    for i = 1, math.min(5, #list) do
      local u = list[i].u
      if u then
        local lv = u.min == u.max and tostring(u.min) or (u.min .. "-" .. u.max)
        local right2 = lv
        if self.method == "skin" then
          local req = H.SkinReq(u.max)
          right2 = lv .. "   " .. (SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r"
        end
        GameTooltip:AddDoubleLine(u.name, right2, 0.88, 0.86, 0.82, S.dim[1], S.dim[2], S.dim[3])
      end
    end
    GameTooltip:AddLine(("%d spawn points"):format(g.n or 0) .. (g.respawn and ("  ·  respawn ~%d min"):format(math.ceil(g.respawn / 60)) or ""), S.dim[1], S.dim[2], S.dim[3])
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end)
local function px(x, y) return x * MAP_W, -y * MAP_H end
local function clearMap()
  resetDots(); resetCells(); resetLines(); resetNums(); resetHots()
  for _, t in ipairs(pvTiles) do t:Hide() end
  if pvTiles.reveal then for _, t in ipairs(pvTiles.reveal) do t:Hide() end end
  W.plate:Hide(); W.legend:Hide(); W.mapNone:SetText("")
end
local function drawArt(mapID, title)
  clearMap()
  if mapID then UI.DrawZoneArt(mapID, pvArt, pvTiles, MAP_W, MAP_H, true) end
  if title then
    W.plate:Show()
    W.plate.text:SetText(title)
    W.plate:SetWidth(W.plate.text:GetStringWidth() + 16)
  end
end
local function heat(t)
  if t < 0.5 then local k = t * 2 return 0.56 + 0.29 * k, 0.68 - 0.03 * k, 0.35 - 0.1 * k end
  local k = (t - 0.5) * 2
  return 0.85 - 0.03 * k, 0.65 - 0.27 * k, 0.25 - 0.02 * k
end
local function drawBins(bins, size)
  local maxW = 0
  for _, b in pairs(bins) do maxW = math.max(maxW, b.w) end
  if maxW <= 0 then return end
  local s = size / 100
  for _, b in pairs(bins) do
    local t = b.w / maxW
    local c = getCell()
    local r, g, bl = heat(t)
    c:SetColorTexture(r, g, bl, 0.25 + 0.4 * t)
    c:ClearAllPoints()
    c:SetSize(s * MAP_W, s * MAP_H)
    c:SetPoint("TOPLEFT", pvArt, "TOPLEFT", px(b.bx * s, b.by * s))
  end
  W.legend:Show()
  W.legend.text:SetText("Low  |cff8fae5a■|r |cffd9a640■|r |cffd0603a■|r  High")
end
local RING = {
  current = { 0.84, 0.70, 0.40, 1, 2.4 }, upcoming = { 0.66, 0.55, 0.36, 0.8, 1.5 },
  hunted = { 0.5, 0.5, 0.5, 0.55, 1.4 }, skipped = { 0.5, 0.5, 0.5, 0.55, 1.4 }, plain = { 0.66, 0.55, 0.36, 0.75, 1.4 },
}
local function ring(s, look)
  local c = RING[look] or RING.plain
  local SEG = 28
  for k = 1, SEG do
    local a1, a2 = (k - 1) / SEG * 2 * math.pi, k / SEG * 2 * math.pi
    local l = getLine()
    l:SetThickness(c[5])
    l:SetColorTexture(c[1], c[2], c[3], c[4])
    l:SetStartPoint("TOPLEFT", pvArt, px(s.x + math.cos(a1) * s.rx, s.y + math.sin(a1) * s.ry))
    l:SetEndPoint("TOPLEFT", pvArt, px(s.x + math.cos(a2) * s.rx, s.y + math.sin(a2) * s.ry))
  end
end
local function hot(s, g, method, title)
  local h = getHot()
  h:ClearAllPoints()
  h:SetSize(math.max(16, s.rx * 2 * MAP_W), math.max(16, s.ry * 2 * MAP_H))
  h:SetPoint("CENTER", pvArt, "TOPLEFT", px(s.x, s.y))
  h.g, h.method, h.title = g, method, title
end
local function drawRoute(stops, states, cur)
  local n = #stops
  local Cr = C.route
  if n > 1 then
    for i = 1, n do
      local a, b = stops[i], stops[(i % n) + 1]
      local into = (i % n) + 1 == cur
      local l = getLine()
      l:SetThickness(into and 3 or 2)
      l:SetColorTexture(Cr[1], Cr[2], Cr[3], into and 0.95 or 0.4)
      l:SetStartPoint("TOPLEFT", pvArt, px(a.x, a.y))
      l:SetEndPoint("TOPLEFT", pvArt, px(b.x, b.y))
    end
  end
  for i, s in ipairs(stops) do
    local look = states and states[i] or (i == cur and "current" or "upcoming")
    ring(s, look)
    local f = getNum()
    f:ClearAllPoints()
    f:SetPoint("CENTER", pvArt, "TOPLEFT", px(s.x, s.y))
    f:SetText(i)
    local c = RING[look] or RING.plain
    if look == "current" then f:SetTextColor(0.91, 0.77, 0.42) elseif look == "upcoming" then f:SetTextColor(0.85, 0.81, 0.73) else f:SetTextColor(c[1], c[2], c[3]) end
  end
  W.legend:Show()
  W.legend.text:SetText("|cffd6b266o|r Current   |cffa88c5co|r Next   |cff808080o|r Done")
end
local function drawMine(mapID, id)
  local spots = NW.GatherLog and mapID and NW.GatherLog.Spots(mapID, id) or {}
  local maxN = 1
  for _, p in ipairs(spots) do maxN = math.max(maxN, p.n) end
  for _, p in ipairs(spots) do
    local d = getDot()
    local sz = 4 + 7 * math.sqrt(p.n / maxN)
    d:SetSize(sz, sz)
    d:SetColorTexture(0.35, 0.75, 0.72, 0.85)
    d:ClearAllPoints()
    d:SetPoint("CENTER", pvArt, "TOPLEFT", px(p.x, p.y))
  end
  return #spots
end
local function dotAt(x, y, size, r, g, b, a)
  local d = getDot()
  d:SetSize(size, size)
  d:SetColorTexture(r, g, b, a or 1)
  d:ClearAllPoints()
  d:SetPoint("CENTER", pvArt, "TOPLEFT", px(x, y))
end

-- side column: a title, label/value pairs, Next / Skip
local side = CreateFrame("Frame", nil, ws)
side:SetPoint("TOPLEFT", SIDE_X, -22)
side:SetSize(SIDE_W, MAP_H)
W.sideTitle = UI.Text(side, 13, S.gold)
W.sideTitle:SetPoint("TOPLEFT", 0, -2)
W.sideTitle:SetWidth(SIDE_W)
W.sideTitle:SetWordWrap(false)
W.sideStats = {}
for i = 1, 7 do
  local l = UI.Text(side, 10, S.dim)
  local v = UI.Text(side, 13, S.text)
  v:SetWidth(SIDE_W)
  v:SetWordWrap(false)
  W.sideStats[i] = { l, v }
end
W.next = UI.Button(side, "Next", 44, function() H.Advance() end, 18)
W.skip = UI.Button(side, "Skip", 40, function() H.Advance(true) end, 18)
W.next.label:SetFont(UI.FONT, 11, "")
W.skip.label:SetFont(UI.FONT, 11, "")
W.skip:SetPoint("LEFT", W.next, "RIGHT", 4, 0)
UI.Tip(W.next, "Next hunting ground", "Marks this one hunted and moves on.")
UI.Tip(W.skip, "Skip", "Moves on without marking it hunted.")
local sideN, sideY
local function sideReset(title)
  W.sideTitle:SetText(title or "")
  sideN, sideY = 0, -24
  for _, s in ipairs(W.sideStats) do s[1]:SetText(""); s[2]:SetText("") end
  W.next:Hide(); W.skip:Hide()
end
local function sideStat(label, value)
  if sideN >= #W.sideStats then return end
  sideN = sideN + 1
  local s = W.sideStats[sideN]
  s[1]:ClearAllPoints(); s[1]:SetPoint("TOPLEFT", 0, sideY); s[1]:SetText(label)
  s[2]:ClearAllPoints(); s[2]:SetPoint("TOPLEFT", 0, sideY - 12); s[2]:SetText(value)
  sideY = sideY - 34
end
local function sideButtons()
  W.next:ClearAllPoints()
  W.next:SetPoint("TOPLEFT", side, "TOPLEFT", 0, sideY + 4)
  W.next:Show(); W.skip:Show()
  sideY = sideY - 24
end

------------------------------------------------------------------------
-- Craft workspace (in place of the map for crafted materials)
------------------------------------------------------------------------
local craft = CreateFrame("Frame", nil, right)
craft:SetPoint("TOPLEFT", 0, WS_Y)
craft:SetSize(R_W, 384)
local CL_W = 318
W.cRecipeHead = heading(craft, "Recipe", CL_W)
W.cRecipeHead:SetPoint("TOPLEFT")
local cIconBox = UI.Box(craft, 24, 24)
cIconBox:SetPoint("TOPLEFT", 0, -22)
W.cIcon = cIconBox:CreateTexture(nil, "ARTWORK")
W.cIcon:SetPoint("TOPLEFT", 1, -1)
W.cIcon:SetPoint("BOTTOMRIGHT", -1, 1)
W.cIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
W.cName = UI.Text(craft, 12, S.text)
W.cName:SetPoint("TOPLEFT", cIconBox, "TOPRIGHT", 8, 0)
W.cName:SetWidth(CL_W - 34)
W.cName:SetWordWrap(false)
W.cDesc = UI.Text(craft, 11, S.dim)
W.cDesc:SetPoint("BOTTOMLEFT", cIconBox, "BOTTOMRIGHT", 8, 0)
W.cDesc:SetWidth(CL_W - 34)
W.cDesc:SetWordWrap(false)
W.cBar = {}
local BAR_COL = { { 1, 0.5, 0.25 }, { 1, 0.9, 0.2 }, { 0.35, 0.8, 0.35 }, { 0.44, 0.44, 0.44 } }
for k = 1, 4 do
  local t = craft:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(BAR_COL[k][1], BAR_COL[k][2], BAR_COL[k][3], 1)
  t:SetHeight(6)
  W.cBar[k] = t
end
W.cBarMark = craft:CreateTexture(nil, "OVERLAY")
W.cBarMark:SetColorTexture(1, 1, 1, 1)
W.cBarMark:SetSize(2, 10)
W.cBarLbl = {}
for k = 1, 4 do W.cBarLbl[k] = UI.Text(craft, 10, S.dim) end
W.cSkill = UI.Text(craft, 11, S.text)
W.cSkill:SetPoint("TOPLEFT", 0, -78)
W.cSkill:SetWidth(CL_W)
W.cMatHead = heading(craft, "", CL_W)
W.cMatHead:SetPoint("TOPLEFT", 0, -98)
local MATCOL = { { "Need", CL_W - 158 }, { "Have", CL_W - 114 }, { "Missing", CL_W - 62 } }
for _, c in ipairs(MATCOL) do
  local t = UI.Text(craft, 10, S.dim, "RIGHT")
  t:SetPoint("TOPRIGHT", craft, "TOPLEFT", c[2], -120)
  t:SetText(c[1])
end
local cbox = UI.Box(craft, CL_W, 4 * 22 + 4)
cbox:SetPoint("TOPLEFT", 0, -134)
W.cMats = {}
for i = 1, 4 do
  local r = CreateFrame("Button", nil, cbox)
  r:SetSize(CL_W - 2, 22)
  r:SetPoint("TOPLEFT", 1, -2 - (i - 1) * 22)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 6, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetWidth(120)
  r.name:SetWordWrap(false)
  r.cells = {}
  for k, c in ipairs(MATCOL) do
    local t = UI.Text(r, 12, S.text, "RIGHT")
    t:SetPoint("RIGHT", r, "LEFT", c[2], 0)
    r.cells[k] = t
  end
  r.find = UI.Button(r, "Find", 46, function(self)
    local id = self:GetParent().id
    if id and NW.FindMaterial then NW.FindMaterial(id, sel.from, self:GetParent().missing) end
  end, 18)
  r.find.label:SetFont(UI.FONT, 11, "")
  r.find:SetPoint("RIGHT", -4, 0)
  r:SetScript("OnEnter", function(self)
    if not self.id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.id)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.cMats[i] = r
end
W.cBuyLine = UI.Text(craft, 11, S.dim)
W.cBuyLine:SetPoint("TOPLEFT", cbox, "BOTTOMLEFT", 0, -4)
W.cBuyCost = UI.Text(craft, 11, S.text, "RIGHT")
W.cBuyCost:SetPoint("TOPRIGHT", cbox, "BOTTOMRIGHT", 0, -4)
W.cWaysHead = heading(craft, "", CL_W)
W.cWaysHead:SetPoint("TOPLEFT", 0, -250)
local wcap = UI.Text(craft, 10, S.dim)
wcap:SetPoint("TOPLEFT", 8, -272)
wcap:SetText("Option  ·  estimates")
local wcap2 = UI.Text(craft, 10, S.dim, "RIGHT")
wcap2:SetPoint("TOPRIGHT", craft, "TOPLEFT", CL_W - 8, -272)
wcap2:SetText("You pay")
local wbox = UI.Box(craft, CL_W, 3 * 30 + 4)
wbox:SetPoint("TOPLEFT", 0, -286)
W.cWays = {}
for i = 1, 3 do
  local r = CreateFrame("Frame", nil, wbox)
  r:SetSize(CL_W - 2, 30)
  r:SetPoint("TOPLEFT", 1, -2 - (i - 1) * 30)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.a = UI.Text(r, 12, S.text)
  r.a:SetPoint("TOPLEFT", 8, -3)
  r.a:SetWidth(CL_W - 90)
  r.a:SetWordWrap(false)
  r.b = UI.Text(r, 10, S.dim)
  r.b:SetPoint("BOTTOMLEFT", 8, 3)
  r.b:SetWidth(CL_W - 90)
  r.b:SetWordWrap(false)
  r.c = UI.Text(r, 12, S.text, "RIGHT")
  r.c:SetPoint("RIGHT", -8, 0)
  W.cWays[i] = r
end
-- used in
local CR_X = CL_W + 14
local CR_W = R_W - CR_X
W.cUsedHead = heading(craft, "", CR_W)
W.cUsedHead:SetPoint("TOPLEFT", CR_X, 0)
local ucap = UI.Text(craft, 10, S.dim)
ucap:SetPoint("TOPLEFT", CR_X + 6, -22)
ucap:SetText("Recipe")
local ucap2 = UI.Text(craft, 10, S.dim, "RIGHT")
ucap2:SetPoint("TOPRIGHT", craft, "TOPLEFT", CR_X + CR_W - 40, -22)
ucap2:SetText("Uses")
local ucap3 = UI.Text(craft, 10, S.dim, "RIGHT")
ucap3:SetPoint("TOPRIGHT", craft, "TOPLEFT", CR_X + CR_W - 6, -22)
ucap3:SetText("Skill")
local ubox = UI.Box(craft, CR_W, 10 * 20 + 4)
ubox:SetPoint("TOPLEFT", CR_X, -36)
W.cUsed = {}
for i = 1, 10 do
  local r = CreateFrame("Frame", nil, ubox)
  r:SetSize(CR_W - 2, 20)
  r:SetPoint("TOPLEFT", 1, -2 - (i - 1) * 20)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  r.name = UI.Text(r, 11, S.text)
  r.name:SetPoint("LEFT", 6, 0)
  r.name:SetWidth(CR_W - 72)
  r.name:SetWordWrap(false)
  r.n = UI.Text(r, 11, S.text, "RIGHT")
  r.n:SetPoint("RIGHT", r, "LEFT", CR_W - 40, 0)
  r.req = UI.Text(r, 11, S.text, "RIGHT")
  r.req:SetPoint("RIGHT", -6, 0)
  W.cUsed[i] = r
end
W.cUsedMore = UI.Text(craft, 10, S.dim)
W.cUsedMore:SetPoint("TOPLEFT", ubox, "BOTTOMLEFT", 0, -4)
W.cUsedMore:SetWidth(CR_W)

------------------------------------------------------------------------
-- Action row
------------------------------------------------------------------------
W.main = UI.Button(right, "", 190, function() if W.mainClick then W.mainClick() end end, 26, "primary")
W.main:SetPoint("BOTTOMLEFT", 0, 10)
W.second = UI.Button(right, "", 120, function() if W.secondClick then W.secondClick() end end, 26)
W.second:SetPoint("LEFT", W.main, "RIGHT", 6, 0)
W.third = UI.Button(right, "", 120, function() if W.thirdClick then W.thirdClick() end end, 26)
W.third:SetPoint("LEFT", W.second, "RIGHT", 6, 0)
W.note = UI.Text(right, 11, S.dim, "RIGHT")
W.note:SetPoint("BOTTOMRIGHT", 0, 17)
W.note:SetWidth(R_W - 330)
W.note:SetWordWrap(false)
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
liveTip(W.checkA); liveTip(W.checkB); liveTip(W.main); liveTip(W.second)
local function action(btn, text, fn, tipTitle, tipBody, enabled)
  btn:Show()
  btn:SetText(text)
  btn:SetWidth(math.max(btn == W.main and 190 or 100, btn.label:GetStringWidth() + 26))
  btn:SetEnabled(enabled ~= false)
  btn.tipTitle, btn.tipBody = tipTitle, tipBody
  if btn == W.main then W.mainClick = fn elseif btn == W.second then W.secondClick = fn else W.thirdClick = fn end
end

------------------------------------------------------------------------
-- Per-view helpers
------------------------------------------------------------------------
local function setCheck(cb, label, get, set, tip)
  cb:Show()
  cb:SetLabel(label)
  cb.tipTitle, cb.tipBody = label, tip
  if cb == W.checkA then W.checkAGet, W.checkASet = get, set else W.checkBGet, W.checkBSet = get, set end
  cb:Refresh()
end
-- which map tabs a view offers; returns the mode to draw
local function mapTabs(avail, default)
  local mode = st().huntMap or default
  if not avail[mode] then mode = default end
  if not avail[mode] then for _, m in ipairs(MODES_MAP) do if avail[m[1]] then mode = m[1] break end end end
  for _, b in ipairs(W.mapTabs) do
    b.ok = avail[b.key] and true or false
    b:SetEnabled(b.ok)
    b.mark:SetShown(b.key == mode)
    if b.ok then b.label:SetTextColor(unpack(b.key == mode and S.gold or S.dim)) end
  end
  return mode
end
local function tableRows(rows)
  W.zoneN = #rows
  W.zoneOffset = math.min(W.zoneOffset, math.max(0, #rows - TROWS))
  for i, r in ipairs(W.zrows) do
    local row = rows[i + W.zoneOffset]
    r.row = row or false
    r:SetShown(row ~= nil)
    r:SetSelected(false)
    r.onClick, r.onEnter = nil, nil
  end
end
local function foldState()
  local open = st()["huntFold" .. (sel.src or "")]
  if open == nil then open = sel.src ~= "skin" end
  return open
end

------------------------------------------------------------------------
-- Views
------------------------------------------------------------------------
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
  W.tblHead.text:SetText("Zones")
  W.nodeSort:Show()
  W.colName:SetText("Zone")
  setCols({ "Spots", "Loop", "g/h" })
  local pick = rows[1]
  for _, row in ipairs(rows) do if sel.zone and row.name == sel.zone then pick = row end end
  tableRows(rows)
  for _, r in ipairs(W.zrows) do
    local row = r.row
    if row then
      r.name:SetText((row.recommended and "|cffd6b266*|r " or "") .. row.name)
      r.name:SetTextColor(unpack(row.count > 0 and S.text or S.dim))
      r.cells[1]:SetText(row.count > 0 and row.count or dash())
      r.cells[2]:SetText(row.loop and fmtTime(row.loop / NW.MOUNT_YPS) or dash())
      r.cells[3]:SetText(row.gold and ("~" .. NW.Money(row.gold, true)) or dash())
      r:SetSelected(row == pick)
      r.onClick = function(self, button)
        sel.zone = self.row.name
        refresh()
        if button == "RightButton" and W.mainClick then W.mainClick() end
      end
      r.onEnter = function(self)
        local rw = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(rw.name, 1, 1, 1)
        if rw.recommended then GameTooltip:AddLine("Recommended by farming guides" .. (rw.note and (": " .. rw.note) or ""), S.gold[1], S.gold[2], S.gold[3], true)
        elseif not rw.missing then GameTooltip:AddLine("Found in your own node data", S.dim[1], S.dim[2], S.dim[3]) end
        if rw.missing then GameTooltip:AddLine("Not on your client's map list", S.dim[1], S.dim[2], S.dim[3]) end
        GameTooltip:AddLine("g/h: if every spot were up, about two items each at Auctionator prices. An estimate.", S.dim[1], S.dim[2], S.dim[3], true)
        if rw.mapID and rw.count > 0 then GameTooltip:AddLine("Right-click: build its route", S.dim[1], S.dim[2], S.dim[3]) end
        GameTooltip:Show()
      end
    end
  end
  if not both then
    setCheck(W.checkA, "Also pick other herbs and ore", function() return st().guideAlsoOthers end,
      function(v) st().guideAlsoOthers = v end, "The route also stops at every other herb and ore your filters allow.")
  end
  -- map
  local row = pick
  local route = row and row.mapID and NW.db.routes[row.mapID]
  local isFocus = route and ((route.focus and route.focus[entry[1]]) or (both and not route.focus)) and #route.stops > 1
  local mode = mapTabs({ known = true, mine = not both, route = true, heat = true }, isFocus and "route" or "known")
  drawArt(row and row.mapID, row and row.name)
  local function p(x, y) return x * MAP_W, -y * MAP_H end
  if row and not row.mapID then
    W.mapNone:SetText("Not on your client's map list")
  elseif row and mode == "route" then
    if isFocus then
      local stp = route.stops
      for i = 1, #stp do
        local pts = i == route.open and {} or NW.LegPoints(route, i)
        for q = 1, #pts - 1 do
          local l = getLine()
          l:SetThickness(2.5)
          l:SetColorTexture(C.route[1], C.route[2], C.route[3], 0.9)
          l:SetStartPoint("TOPLEFT", pvArt, p(pts[q][1], pts[q][2]))
          l:SetEndPoint("TOPLEFT", pvArt, p(pts[q + 1][1], pts[q + 1][2]))
        end
      end
      for _, a in ipairs(stp) do
        local ed = a.kind == "ore" and C.oreEdge or C.herbEdge
        dotAt(a.x, a.y, 7, ed[1], ed[2], ed[3], 1)
      end
      W.caption:SetText(("Your route  ·  %d stops, %s %s"):format(#stp, fmtTime(route.seconds or 0), route.open and "each way" or "per loop"))
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
      W.caption:SetText("A quick loop past every known spot  ·  no route built")
    end
  elseif row and mode == "mine" then
    local n = drawMine(row.mapID, e.id)
    W.caption:SetText(n > 0 and (TEAL .. "Where you gathered it|r") or "Nothing gathered here yet")
  elseif row and mode == "heat" then
    local bins = {}
    for _, pt in ipairs(row.pts) do
      local bx, by2 = math.floor(pt[3] * 100 / 3), math.floor(pt[4] * 100 / 3)
      local k = bx * 100 + by2
      bins[k] = bins[k] or { bx = bx, by = by2, w = 0 }
      bins[k].w = bins[k].w + 1
    end
    drawBins(bins, 3)
    W.caption:SetText("Known spots per area  ·  not nodes up now")
  elseif row then
    W.caption:SetText(row.count > 0 and "Known spots  ·  where nodes have spawned, not nodes up now" or "No spots saved yet")
  end
  if row and row.mapID and mode ~= "mine" and mode ~= "heat" and not (mode == "route" and isFocus) then
    for _, pt in ipairs(row.pts) do
      local ed = pt[5] == "ore" and C.oreEdge or C.herbEdge
      dotAt(pt[3], pt[4], 5, ed[1], ed[2], ed[3], 1)
    end
  end
  -- side
  sideReset(row and row.name or "")
  if row then
    sideStat("Known spots", tostring(row.count))
    if row.rate then
      sideStat("Loop", fmtTime(row.loop / NW.MOUNT_YPS))
      sideStat("Spots per minute", ("%.1f"):format(row.rate))
      sideStat("Gold per hour", row.gold and ("~" .. NW.Money(row.gold, true)) or DIM .. "no prices|r")
    end
    if isFocus then sideStat("Your route", ("%d stops"):format(#route.stops)) end
    local mine = NW.GatherLog and row.mapID and NW.GatherLog.ZoneCount(row.mapID, not both and e.id or nil) or 0
    if mine > 0 then sideStat("You gathered here", TEAL .. mine .. "|r") end
  end
  action(W.main, "Build route", function()
    if not (row and row.mapID and row.count > 0) then return end
    NW.BuildRoute(row.mapID, function() if page:IsShown() then refresh() end end,
      both and {} or { focus = focusOf(entry), alsoOthers = st().guideAlsoOthers })
  end, "Build route", "Replaces this zone's saved route.", row ~= nil and row.mapID ~= nil and row.count > 0)
  local kind = both and "both" or e.nodeKind
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
  W.tblHead.text:SetText("Where to fish it")
  W.colName:SetText("Zone")
  setCols({ nil, nil, "Caught" })
  local zones, seen, mine = {}, {}, {}
  for _, z in ipairs(NW.GatherLog and NW.GatherLog.ZonesFor(e.id) or {}) do mine[z.map] = z.n end
  for _, z in ipairs(F and F.zonesFor(e.id) or {}) do
    local name = type(z) == "table" and (z.name or z[1]) or z
    if name and not seen[name] then seen[name] = true; zones[#zones + 1] = { name = name, mapID = zoneID(name) } end
  end
  for m in pairs(mine) do
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    local name = info and info.name
    if name and not seen[name] then seen[name] = true; zones[#zones + 1] = { name = name, mapID = m } end
  end
  for _, z in ipairs(zones) do z.n = z.mapID and mine[z.mapID] or 0 end
  table.sort(zones, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
  local pick = zones[1]
  for _, z in ipairs(zones) do if sel.zone == z.name then pick = z end end
  tableRows(zones)
  for _, r in ipairs(W.zrows) do
    if r.row then
      r.name:SetText(r.row.name)
      r.name:SetTextColor(unpack(S.text))
      r.cells[3]:SetText(r.row.n > 0 and (TEAL .. r.row.n .. "|r") or dash())
      r:SetSelected(r.row == pick)
      r.onClick = function(self) sel.zone = self.row.name; refresh() end
    end
  end
  mapTabs({ mine = true }, "mine")
  drawArt(pick and pick.mapID, pick and pick.name)
  local n = pick and pick.mapID and drawMine(pick.mapID, e.id) or 0
  W.caption:SetText(n > 0 and (TEAL .. "Your catches|r") or "Fishing data is by zone, not by spot")
  sideReset(pick and pick.name or "")
  if f then
    sideStat("Fishing skill", f.skill and tostring(f.skill) or DIM .. "unknown|r")
    if f.note then sideStat("When", f.note) end
  end
  if pick and pick.n > 0 then sideStat("You caught here", TEAL .. pick.n .. "|r") end
  if not f then W.note:SetText("Not in Nodewalker's fishing data.") end
  action(W.main, "Fish Finder", function() if NW.OpenFishFinder then NW.OpenFishFinder(e.id) end end,
    "Fish Finder", "Where it's caught, lures and your catches.", NW.OpenFishFinder ~= nil)
  action(W.second, "Fishing + Cooking plan", function() if NW.OpenFishCook then NW.OpenFishCook() end end, nil, nil, NW.OpenFishCook ~= nil)
end

-- Skinning and creature loot: Hunting Grounds
local function huntOpts(method)
  local o = { elites = st().huntElites or false }
  if method == "skin" and st().huntSkill ~= false then o.skill = NW.ProfSkill and NW.ProfSkill("skinning") or nil end
  return o
end
local function viewHunt(e, method)
  local g = H.Grounds(e.id, method, huntOpts(method))
  local zones = H.Sort(g.zones, st().huntSort or "density", e.id)
  if st().huntSort == "mine" then
    local f = {}
    for _, z in ipairs(zones) do if z.mapID and NW.GatherLog.ZoneCount(z.mapID, e.id) > 0 then f[#f + 1] = z end end
    zones = f
  end
  local skill = NW.ProfSkill and NW.ProfSkill("skinning")
  W.tblHead.text:SetText("Hunting grounds")
  W.huntSort:Show()
  W.colName:SetText("Zone")
  setCols({ "Level", method == "skin" and "Skill" or "Spawns", "Mine" })
  local pick = zones[1]
  for _, z in ipairs(zones) do if sel.zone == z.name then pick = z end end
  local hunt = H.Route()
  tableRows(zones)
  for _, r in ipairs(W.zrows) do
    local z = r.row
    if z then
      local active = hunt and hunt.item == e.id and hunt.zone == z.name
      r.name:SetText((active and "|cff5fd4e0›|r " or "") .. z.name)
      r.name:SetTextColor(unpack(z.mapID and S.text or S.dim))
      r.cells[1]:SetText(z.minL and (z.minL == z.maxL and z.minL or (z.minL .. "-" .. z.maxL)) or DIM .. "?|r")
      if method == "skin" then
        local req = H.SkinReq(z.maxL)
        r.cells[2]:SetText(req and ((SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r") or dash())
      else
        r.cells[2]:SetText(z.n)
      end
      local mine = z.mapID and NW.GatherLog and NW.GatherLog.ZoneCount(z.mapID, e.id) or 0
      r.cells[3]:SetText(mine > 0 and (TEAL .. mine .. "|r") or dash())
      r:SetSelected(z == pick)
      r.onClick = function(self) sel.zone = self.row.name; refresh() end
      r.onEnter = function(self)
        local zz = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(zz.name, 1, 1, 1)
        GameTooltip:AddDoubleLine("Known spawn points", zz.n, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Hunting grounds", #zz.grounds, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        if method == "skin" then GameTooltip:AddLine("Skill: the most any creature here needs (Classic rule).", S.dim[1], S.dim[2], S.dim[3], true) end
        if not zz.mapID then GameTooltip:AddLine("Not on your client's map list", S.bad[1], S.bad[2], S.bad[3]) end
        GameTooltip:AddLine("Classic data: creatures and chances may differ in WoW Forever.", S.dim[1], S.dim[2], S.dim[3], true)
        GameTooltip:Show()
      end
    end
  end
  -- the fold: creatures in the zone
  local open = foldState()
  W.fold:Show()
  W.fold.sign:SetText(open and "–" or "+")
  W.fold.text:SetText(method == "skin" and "Creatures to skin here" or "Creatures here")
  local list = {}
  if pick then
    local chance = {}
    for _, s in ipairs(H.Sources(e.id, method)) do chance[s.npc] = s end
    for npc, n in pairs(pick.npcs) do if chance[npc] then list[#list + 1] = { u = H.Unit(npc), n = n, s = chance[npc] } end end
    table.sort(list, function(a, b) return a.n * a.s.chance > b.n * b.s.chance end)
  end
  W.fold.n:SetText(#list)
  local shown = 0
  for i, r in ipairs(W.crows) do
    local c = open and list[i]
    r:SetShown(c and true or false)
    if c then
      shown = i
      local u = c.u
      r.name:SetText(u.name)
      r.lvl:SetText(u.min == u.max and u.min or (u.min .. "-" .. u.max))
      r.ch:SetText(("%d%%"):format(math.floor(c.s.chance + 0.5)))
      if method == "skin" then
        local req = H.SkinReq(u.max)
        r.req:SetText((SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r")
      else
        r.req:SetText(DIM .. (H.TYPE[u.type] or "") .. "|r")
      end
      r.onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(u.name, 1, 1, 1)
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
          if times >= 10 then GameTooltip:AddDoubleLine("Each time", ("%.2f"):format(got / times), 0.35, 0.75, 0.72, 1, 1, 1) end
        end
        GameTooltip:AddLine("Classic data", S.dim[1], S.dim[2], S.dim[3])
        GameTooltip:Show()
      end
    end
  end
  W.checkAnchor = shown > 0 and W.crows[shown] or W.fold
  if method == "skin" then
    setCheck(W.checkA, "Only what I can skin", function() return st().huntSkill ~= false end,
      function(v) st().huntSkill = v end, "Leaves out creatures above your Skinning skill (Classic rule: level × 5 from level 20).")
  end
  setCheck(method == "skin" and W.checkB or W.checkA, "Include elites and rares", function() return st().huntElites end, function(v) st().huntElites = v end)
  -- map
  local plan = pick and H.Plan(pick) or {}
  local active = hunt and hunt.item == e.id and pick and hunt.zone == pick.name
  local mode = mapTabs({ known = true, mine = true, route = true, heat = true }, active and "route" or "heat")
  drawArt(pick and pick.mapID, pick and pick.name)
  if pick and not pick.mapID then W.mapNone:SetText("Not on your client's map list") end
  if pick and pick.mapID then
    if mode == "known" then
      for _, b in pairs(pick.bins) do
        for _, c in ipairs(b.cells) do dotAt(c[1], c[2], 4, 0.85, 0.72, 0.45, 0.8) end
      end
      for i, gr in ipairs(pick.grounds) do ring(gr, "plain"); hot(gr, gr, method, "Hunting ground " .. i) end
      W.caption:SetText("Known spawn points  ·  Classic data  ·  not creatures alive now")
    elseif mode == "heat" then
      drawBins(pick.bins, 3)
      for i, gr in ipairs(pick.grounds) do ring(gr, "plain"); hot(gr, gr, method, "Hunting ground " .. i) end
      W.caption:SetText("Known spawns × drop chance  ·  Classic data  ·  not creatures alive now")
    elseif mode == "mine" then
      local n = drawMine(pick.mapID, e.id)
      W.caption:SetText(n > 0 and (TEAL .. "Where you collected it|r") or "Nothing collected here yet")
    else
      local stops, states, cur = plan, nil, 1
      if active then
        stops, states, cur = hunt.stops, {}, hunt.cur
        for i in ipairs(hunt.stops) do states[i] = H.State(i) end
      end
      drawRoute(stops, states, cur)
      for i, s in ipairs(stops) do
        local src = plan[i] or s
        hot(s, { npcs = (function() local t = {} for _, npc in ipairs(s.npcs or {}) do t[npc] = 1 end return next(t) and t or src.npcs end)(), n = s.n, respawn = s.respawn },
          method, "Ground " .. i .. (states and states[i] and ("  ·  " .. states[i]) or ""))
      end
      local len = H.Length(pick.mapID, stops)
      W.caption:SetText(#stops == 1 and "One area: stay and hunt" or
        (("%d grounds  ·  ~%d yd loop, straight lines  ·  Classic data"):format(#stops, len and math.floor(len / 10 + 0.5) * 10 or 0)))
    end
  end
  -- side: the route when it's here, else the zone
  if active then
    sideReset("Route")
    local here = H.Here()
    sideStat("Ground", ("%d of %d"):format(hunt.cur, #hunt.stops) .. (here == hunt.cur and "  |cff94ba78here|r" or ""))
    if #hunt.stops > 1 then sideButtons() end
    for i = 1, #hunt.stops do
      local back = H.Revisit(i)
      if back and i ~= hunt.cur then sideStat("Ground " .. i, back > 0 and ("back ~%d min"):format(math.ceil(back / 60)) or "back now") break end
    end
    sideStat("Creature levels", pick.minL and (pick.minL .. "-" .. pick.maxL) or "?")
    if method == "skin" and skill then sideStat("Your Skinning", tostring(skill)) end
    local sess = NW.GatherLog and NW.GatherLog.Session(e.id) or 0
    if sess > 0 then sideStat("This session", TEAL .. sess .. "|r") end
  else
    sideReset(pick and pick.name or "")
    if pick then
      sideStat("Creature levels", pick.minL and (pick.minL == pick.maxL and tostring(pick.minL) or (pick.minL .. "-" .. pick.maxL)) or "?")
      sideStat("Hunting grounds", tostring(#pick.grounds))
      sideStat("Spawn points", tostring(pick.n))
      if plan[1] and plan[1].respawn then sideStat("Respawn (Classic)", ("~%d min"):format(math.ceil(plan[1].respawn / 60))) end
      local mine = pick.mapID and NW.GatherLog and NW.GatherLog.ZoneCount(pick.mapID, e.id) or 0
      if mine > 0 then sideStat("You collected here", TEAL .. mine .. "|r") end
      if method == "skin" and skill then sideStat("Your Skinning", tostring(skill)) end
    end
  end
  -- note: empty lists, filtered creatures
  local outN = 0
  for _, n in pairs(g.out or {}) do outN = outN + n end
  if #zones == 0 then
    W.mapNone:SetText(st().huntSort == "mine" and "You haven't collected it anywhere yet."
      or (outN > 0 and "No creatures left with these filters." or "No known spawns outdoors."))
  elseif g.out and g.out.skill then
    W.note:SetText(("%d creature%s need more Skinning"):format(g.out.skill, g.out.skill == 1 and "" or "s"))
  end
  if active then
    action(W.main, "Stop route", function() H.Stop(); refresh() end)
    if W.note:GetText() == "" then W.note:SetText("Next and Skip are in the session panel too") end
  else
    action(W.main, #plan > 1 and "Build hunting route" or "Hunt here", function()
      if pick then H.Start(e.id, method, pick); st().huntMap = "route"; refresh() end
    end, "Hunting route", "Circles the densest hunting grounds, nearest first. On the overlay; Next in the session panel moves on. Straight-line distances, not paths.",
      pick ~= nil and pick.mapID ~= nil and #plan > 0)
  end
  action(W.second, "Show on map", function()
    local s = (active and hunt.stops[hunt.cur]) or plan[1]
    if s and NW.PinMap then NW.PinMap(pick.mapID, s.x * 100, s.y * 100, "Hunting ground") end
  end, nil, nil, pick ~= nil and pick.mapID ~= nil and plan[1] ~= nil)
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
      local ok = u.fac == "" or myF == "" or u.fac:find(myF, 1, true) ~= nil
      list[#list + 1] = { u = u, zone = zname, x = at[2], y = at[3], ok = ok, mapID = zoneID(zname) }
    end
  end
  table.sort(list, function(a, b)
    if a.ok ~= b.ok then return a.ok end
    if a.zone ~= b.zone then return a.zone < b.zone end
    return a.u.name < b.u.name
  end)
  W.tblHead.text:SetText("Vendors")
  W.colName:SetText("Vendor")
  setCols({ nil, nil, "Zone" })
  local pick = list[1]
  for _, v in ipairs(list) do if sel.zone == v.u.name then pick = v end end
  tableRows(list)
  for _, r in ipairs(W.zrows) do
    local v = r.row
    if v then
      r.name:SetText(v.u.name)
      r.name:SetTextColor(unpack(v.ok and S.text or S.dim))
      r.cells[3]:SetText(v.zone)
      r:SetSelected(v == pick)
      r.onClick = function(self) sel.zone = self.row.u.name; refresh() end
      r.onEnter = function(self)
        local vv = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(vv.u.name, 1, 1, 1)
        GameTooltip:AddLine(("%s  %.1f, %.1f"):format(vv.zone, vv.x, vv.y), S.dim[1], S.dim[2], S.dim[3])
        if not vv.ok then GameTooltip:AddLine("Other faction", S.bad[1], S.bad[2], S.bad[3]) end
        GameTooltip:AddLine("Classic data", S.dim[1], S.dim[2], S.dim[3])
        GameTooltip:Show()
      end
    end
  end
  mapTabs({ known = true }, "known")
  drawArt(pick and pick.mapID, pick and pick.zone)
  if pick and pick.mapID then
    dotAt(pick.x / 100, pick.y / 100, 11, 0.84, 0.70, 0.40, 1)
    for _, v in ipairs(list) do
      if v ~= pick and v.mapID == pick.mapID then dotAt(v.x / 100, v.y / 100, 7, 0.66, 0.55, 0.36, 0.9) end
    end
  elseif pick then
    W.mapNone:SetText(pick.zone .. " isn't on your client's map list")
  end
  W.caption:SetText(#list > 0 and "Vendor locations  ·  Classic data" or "")
  sideReset(pick and pick.u.name or "")
  if pick then
    sideStat("Where", ("%s  %.0f, %.0f"):format(pick.zone, pick.x, pick.y))
    if not pick.ok then sideStat("Faction", "|cffd17665Other faction|r") end
  end
  local vp = NW.BuyPrice and NW.BuyPrice(e.id)
  sideStat("Vendor price", vp and NW.Money(vp) or DIM .. "visit a vendor|r")
  if #list == 0 then W.mapNone:SetText("Sold by vendors; no vendor locations in Nodewalker's data.") end
  action(W.main, "Show on map", function()
    if pick and pick.mapID and NW.PinMap then NW.PinMap(pick.mapID, pick.x, pick.y, pick.u.name) end
  end, nil, nil, pick ~= nil and pick.mapID ~= nil)
end

-- Crafting: recipe, materials for the target, ways to get it, what it's used in
local function diffColor(r, skill)
  if not skill then return nil end
  local o, y, g, gr = r.orange or r.yellow, r.yellow, r.green, r.grey
  if o and skill < o then return "red" end
  if y and skill < y then return "orange" end
  if g and skill < g then return "yellow" end
  if gr and skill < gr then return "green" end
  return "grey"
end
local function viewCraft(e)
  local r, key = NW.RecipeFor(e.id)
  ws:Hide()
  craft:Show()
  -- centre: made by, also from
  W.tblHead.text:SetText("Made by")
  W.colName:SetText("")
  setCols({ nil, nil, nil })
  local rows = {}
  local p = r and NW.PROF_BY_KEY[key]
  if r then rows[#rows + 1] = { kind = "recipe" } end
  local ahP, ahSrc
  if NW.Price then ahP, ahSrc = NW.Price(e.id) end
  if ahP and ahSrc == "ah" then rows[#rows + 1] = { kind = "ah", price = ahP } end
  for _, k in ipairs(M.Sources(e)) do
    if k ~= "craft" then rows[#rows + 1] = { kind = "src", src = k } end
  end
  tableRows(rows)
  local skill = key and NW.ProfSkill and NW.ProfSkill(key)
  for _, row in ipairs(W.zrows) do
    local x = row.row
    if x then
      if x.kind == "recipe" then
        row.name:SetText(p and p.name or key)
        row.cells[3]:SetText(r.orange and ("Skill " .. r.orange) or "")
        row.onClick = function() if NW.OpenProfession then NW.OpenProfession(key) end end
      elseif x.kind == "ah" then
        row.name:SetText("Auction house")
        row.cells[3]:SetText("~" .. NW.Money(x.price, true) .. " each")
      else
        row.name:SetText(M.SourceText(e, x.src))
        row.cells[3]:SetText(DIM .. "see the switch above|r")
        row.onClick = function() sel.src = x.src; sel.zone = nil; refresh() end
      end
      row.name:SetTextColor(unpack(S.text))
    end
  end
  if not r then
    W.cName:SetText("No recipe in Nodewalker's data")
    return
  end
  -- recipe line
  W.cIcon:SetTexture(NW.ItemIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
  W.cName:SetText(r.name)
  local parts = {}
  for _, re in ipairs(r.reagents) do parts[#parts + 1] = re[2] .. " " .. (NW.ItemName(re[1]) or ("item " .. re[1])) end
  W.cDesc:SetText((p and p.name or key) .. "  ·  makes " .. (r.yield or 1) .. "  ·  " .. table.concat(parts, ", "))
  -- skill bar: orange, yellow, green, grey
  local o, y, g, gr = r.orange or r.yellow or 1, r.yellow or r.orange or 1, r.green or r.yellow or 1, r.grey or r.green or 1
  local lo, hi = o, gr + math.max(10, math.floor((gr - o) * 0.25))
  local span = math.max(1, hi - lo)
  local edges = { o, y, g, gr, hi }
  local x0 = 0
  for k = 1, 4 do
    local w = math.max(1, (edges[k + 1] - edges[k]) / span * CL_W)
    W.cBar[k]:ClearAllPoints()
    W.cBar[k]:SetPoint("TOPLEFT", craft, "TOPLEFT", x0, -54)
    W.cBar[k]:SetWidth(w)
    W.cBarLbl[k]:ClearAllPoints()
    W.cBarLbl[k]:SetPoint("TOPLEFT", craft, "TOPLEFT", x0, -63)
    W.cBarLbl[k]:SetText(edges[k])
    x0 = x0 + w
  end
  if skill and skill >= lo then
    W.cBarMark:Show()
    W.cBarMark:ClearAllPoints()
    W.cBarMark:SetPoint("TOPLEFT", craft, "TOPLEFT", math.min(CL_W - 2, (skill - lo) / span * CL_W), -52)
  else
    W.cBarMark:Hide()
  end
  local col = diffColor(r, skill)
  local WORDS = { red = "too high for you", orange = "always a skill-up", yellow = "usually a skill-up", green = "small chance of a skill-up", grey = "no skill-ups" }
  W.cSkill:SetText(skill and ((SKILL_HEX[col] or "") .. (col and (col:sub(1, 1):upper() .. col:sub(2)) or "") .. " at your " .. skill .. "|r" .. DIM .. ": " .. WORDS[col] .. "|r")
    or DIM .. ((p and p.name or key) .. " not learned") .. "|r")
  -- materials for the target (or one craft)
  local goal = M.Goal(e.id)
  local want = goal and M.Progress(goal).remaining or 0
  local crafts = want > 0 and math.ceil(want / (r.yield or 1)) or 1
  W.cMatHead.text:SetText(want > 0 and ("Materials for %d more"):format(want) or "Materials for one")
  local buyCost, buyUnknown, missingList = 0, false, {}
  for i, mr in ipairs(W.cMats) do
    local re = r.reagents[i]
    mr:SetShown(re ~= nil)
    if re then
      local need = re[2] * crafts
      local have = NW.ItemCount(re[1])
      local miss = math.max(0, need - have)
      mr.id, mr.missing = re[1], miss > 0 and miss or nil
      mr.icon:SetTexture(NW.ItemIcon(re[1]))
      mr.name:SetText(NW.ItemName(re[1]) or ("item " .. re[1]))
      mr.cells[1]:SetText(need)
      mr.cells[2]:SetText(have)
      mr.cells[3]:SetText(miss > 0 and ("|cffd17665" .. miss .. "|r") or "|cff94ba780|r")
      mr.find:SetShown(M.Get(re[1]) ~= nil)
      if miss > 0 then
        missingList[#missingList + 1] = { id = re[1], n = miss }
        local pr = NW.Price and NW.Price(re[1])
        if pr then buyCost = buyCost + pr * miss else buyUnknown = true end
      end
    end
  end
  if #missingList == 0 then
    W.cBuyLine:SetText("You have everything for it")
    W.cBuyCost:SetText("")
  else
    W.cBuyLine:SetText("Buy what's missing")
    W.cBuyCost:SetText("~" .. NW.Money(buyCost, true) .. (buyUnknown and " |cffd17665+?|r" or ""))
  end
  -- ways to get it
  local n = want > 0 and want or 1
  W.cWaysHead.text:SetText(("Ways to get %d"):format(n))
  local farmable = true
  local farmWhere = {}
  for _, m in ipairs(missingList) do
    local me = M.Get(m.id)
    if not (me and (me.src.nodes or me.src.skin or me.src.loot or me.src.fishing)) then farmable = false
    else farmWhere[#farmWhere + 1] = NW.ItemName(m.id) or ("item " .. m.id) end
  end
  local ways = {}
  if #missingList == 0 then
    ways[#ways + 1] = { "Craft from what you have", "Your bags and bank", S.HEX.good .. "0|r" }
  else
    if farmable then ways[#ways + 1] = { "Craft, gather what's missing", "Collect: " .. table.concat(farmWhere, ", "), S.HEX.good .. "0|r" } end
    ways[#ways + 1] = { "Craft, buy what's missing", "Auction house or vendor, today's price", "~" .. NW.Money(buyCost, true) .. (buyUnknown and " |cffd17665+?|r" or "") }
  end
  if ahP and ahSrc == "ah" then ways[#ways + 1] = { ("Buy %d"):format(n), "Auction house; no skill-ups from buying", "~" .. NW.Money(ahP * n, true) } end
  for i, wr in ipairs(W.cWays) do
    local w = ways[i]
    wr:SetShown(w ~= nil)
    if w then wr.a:SetText(w[1]); wr.b:SetText(w[2]); wr.c:SetText(w[3]); wr:SetSelected(i == 1) end
  end
  -- used in
  local used = {}
  for k, lst in pairs(NW.RECIPES or {}) do
    for _, rr in ipairs(lst) do
      for _, re in ipairs(rr.reagents) do
        if re[1] == e.id then used[#used + 1] = { r = rr, key = k, n = re[2] } break end
      end
    end
  end
  local RANK = { orange = 1, yellow = 2, green = 3, red = 4, grey = 5 }
  for _, u in ipairs(used) do
    u.col = diffColor(u.r, NW.ProfSkill and NW.ProfSkill(u.key))
    u.rank = RANK[u.col or ""] or 6
  end
  table.sort(used, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return (a.r.orange or a.r.yellow or 0) < (b.r.orange or b.r.yellow or 0)
  end)
  W.cUsedHead.text:SetText(("Used in %d"):format(#used))
  for i, ur in ipairs(W.cUsed) do
    local u = used[i]
    ur:SetShown(u ~= nil)
    if u then
      ur.name:SetText(u.r.name)
      ur.n:SetText(u.n)
      ur.req:SetText((SKILL_HEX[u.col] or S.HEX.dim) .. (u.r.orange or u.r.yellow or "?") .. "|r")
    end
  end
  W.cUsedMore:SetText(#used > #W.cUsed and (("%d more  ·  colours: skill-ups at your skill"):format(#used - #W.cUsed)) or "Colours: skill-ups at your skill")
  -- actions
  local first = missingList[1]
  if first and M.Get(first.id) then
    action(W.main, "Find " .. (NW.ItemName(first.id) or "material"), function() NW.FindMaterial(first.id, sel.from, first.n) end)
  else
    action(W.main, "Open " .. (p and p.name or "profession"), function() if NW.OpenProfession then NW.OpenProfession(key) end end)
  end
  if #missingList > 0 and NW.SearchAH then
    action(W.second, "Search missing", function()
      local q = {}
      for _, m in ipairs(missingList) do local nm = NW.ItemName(m.id) if nm then q[#q + 1] = { nm, m.n } end end
      NW.SearchAH(q)
    end, "Search missing", "Searches Auctionator for every missing material (at the auction house).")
  end
  if first and M.Get(first.id) then
    action(W.third, "Open " .. (p and p.name or "profession"), function() if NW.OpenProfession then NW.OpenProfession(key) end end)
  end
  W.note:SetText(("Craft %d: %s"):format(crafts, table.concat((function()
    local t = {}
    for _, re in ipairs(r.reagents) do t[#t + 1] = (re[2] * crafts) .. " " .. (NW.ItemName(re[1]) or "?") end
    return t
  end)(), ", ")))
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
  local rr, rk = e.src.craft and not e.src.nodes and NW.RecipeFor(e.id)
  local txt = table.concat(parts, " · ")
  if req then txt = txt .. " " .. req
  elseif rr and #parts == 1 and rr.orange then txt = txt .. " · " .. ((NW.PROF_BY_KEY[rk] or {}).name or "") .. " " .. rr.orange end
  return txt
end

local function resetViews()
  for _, r in ipairs(W.crows) do r:Hide(); r.onEnter = nil end
  W.fold:Hide()
  W.checkA:Hide(); W.checkB:Hide()
  W.checkAGet, W.checkASet, W.checkBGet, W.checkBSet = nil, nil, nil, nil
  W.checkAnchor = nil
  W.huntSort:Hide(); W.nodeSort:Hide()
  for _, b in ipairs({ W.main, W.second, W.third }) do b:Hide(); b.tipTitle, b.tipBody = nil, nil end
  W.mainClick, W.secondClick, W.thirdClick = nil, nil, nil
  W.note:SetText("")
  W.caption:SetText("")
  ws:Show()
  craft:Hide()
  tbl:Show()
end

refresh = function()
  if not page:IsShown() then return end
  local s = st()
  sel.cat = sel.cat or s.matCat or "herb"
  -- left: categories with materials
  local counts = M.Counts()
  local catList = {}
  local goals = M.Goals()
  if #goals > 0 then catList[#catList + 1] = { key = "tracked", label = "Tracked", n = #goals, icon = "Interface\\Icons\\INV_Misc_Note_01" } end
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
  catBox:SetHeight(#catList * CAT_H + 6)
  W.trackHead:ClearAllPoints()
  W.trackHead:SetPoint("TOPLEFT", catBox, "BOTTOMLEFT", 0, -10)
  W.trackHead:SetShown(#goals > 0)
  for i, r in ipairs(W.track) do
    local g = goals[i]
    r:SetShown(g ~= nil)
    if g then
      local p = M.Progress(g)
      r.id = g.id
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", W.trackHead, "BOTTOMLEFT", 0, -4 - (i - 1) * 18)
      r.name:SetText(NW.ItemName(g.id) or ("item " .. g.id))
      r.n:SetText((p.done and S.HEX.good or "") .. p.shown .. " / " .. p.target .. "|r")
      local on = g.id == sel.id
      r.name:SetTextColor(unpack(on and S.gold or S.text))
    end
  end
  -- centre: materials
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
  sel.id = sel.id or s.matSel
  local e = sel.id == "both" and BOTH or (type(sel.id) == "number" and M.Get(sel.id))
  if not e then e = list[1]; sel.id = e and e.id end
  -- the source decides how tall the list is: crafted items have a short table
  local srcs = e and (e.id == "both" and { "nodes" } or M.Sources(e)) or {}
  local okSrc = false
  for _, k in ipairs(srcs) do if k == sel.src then okSrc = true end end
  if not okSrc then sel.src = srcs[1]; sel.zone = nil; W.zoneOffset = 0 end
  local shortTable = sel.src == "craft" or sel.src == nil
  local shownN = shortTable and LROW_MAX or 5
  W.listShown = shownN
  W.listN = #list
  W.listOffset = math.min(W.listOffset, math.max(0, #list - shownN))
  -- a newly selected material (from a shopping list, say) scrolls into view
  if e and W.lastSel ~= e.id then
    W.lastSel = e.id
    for i, x in ipairs(list) do
      if x == e and (i <= W.listOffset or i > W.listOffset + shownN) then
        W.listOffset = math.max(0, math.min(i - 1, #list - shownN))
      end
    end
  end
  mid:SetHeight(shownN * LROW_H + 4)
  W.midHead:SetText(searchText ~= "" and "Search" or (M.CAT[sel.cat] and M.CAT[sel.cat].label or (sel.cat == "tracked" and "Tracked" or "All materials")))
  W.midCount:SetText(#list > shownN and ("%d-%d of %d"):format(W.listOffset + 1, math.min(#list, W.listOffset + shownN), #list) or #list)
  for i, r in ipairs(W.rows) do
    local x = i <= shownN and list[i + W.listOffset] or nil
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
  tbl:ClearAllPoints()
  tbl:SetPoint("TOPLEFT", mid, "BOTTOMLEFT", 0, -10)
  -- right
  right:SetShown(e ~= nil)
  tbl:SetShown(e ~= nil)
  if not e then return end
  W.icon:SetTexture(iconOf(e))
  W.name:SetText(M.Name(e))
  local cat = M.CAT[e.cat]
  local subParts = { cat and cat.label or "" }
  if e.uses and e.uses > 0 then subParts[#subParts + 1] = ("Used in %d recipe%s"):format(e.uses, e.uses == 1 and "" or "s") end
  local p, psrc
  if type(e.id) == "number" and NW.Price then p, psrc = NW.Price(e.id) end
  if p then subParts[#subParts + 1] = (psrc == "vendor" and "Vendor " or "~") .. NW.Money(p, "mid") .. " each" end
  W.sub:SetText(table.concat(subParts, "  ·  "))
  local fromP = sel.from and NW.PROF_BY_KEY[sel.from]
  local isItem = type(e.id) == "number"
  W.ah:SetShown(isItem and NW.HasAuctionator ~= nil and NW.HasAuctionator())
  W.back:ClearAllPoints()
  if W.ah:IsShown() then W.back:SetPoint("RIGHT", W.ah, "LEFT", -4, 0) else W.back:SetPoint("TOPRIGHT", 0, -8) end
  W.back:SetShown(fromP ~= nil)
  if fromP then W.back:SetText("‹ " .. fromP.name); W.back:SetWidth(W.back.label:GetStringWidth() + 24) end
  -- target strip
  goalBar:SetShown(isItem)
  if isItem then
    local g = M.Goal(e.id)
    local have = NW.ItemCount(e.id)
    local life = NW.GatherLog and NW.GatherLog.Item(e.id).n or 0
    local sess = NW.GatherLog and NW.GatherLog.Session(e.id) or 0
    local sep = "  " .. DIM .. "·|r  "
    local txt
    if g then
      local pr = M.Progress(g)
      txt = (g.mode == "more" and "Collected %s / %d" or "Owned %s / %d"):format((pr.done and S.HEX.good or "") .. pr.shown .. "|r", pr.target)
        .. (pr.done and (sep .. S.HEX.good .. "done|r") or (sep .. "Remaining " .. pr.remaining))
    else
      txt = "Owned " .. have
    end
    if sess > 0 then txt = txt .. sep .. "Session " .. sess end
    if life > 0 then txt = txt .. sep .. "Lifetime " .. life end
    W.goalText:SetText(txt)
    W.goalClear:SetShown(g ~= nil)
    W.goalSet:ClearAllPoints()
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
  local x = 0
  for _, k in ipairs(SRC_ORDER) do W.srcBtns[k]:Hide() end
  for _, k in ipairs(srcs) do
    local b = W.srcBtns[k]
    b:SetText(e.id == "both" and "Gathering" or M.SourceText(e, k))
    b:SetWidth(math.max(80, b.label:GetStringWidth() + 26))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", right, "TOPLEFT", x, isItem and -92 or -58)
    x = x + b:GetWidth() + 4
    b.mark:SetShown(k == sel.src)
    b.label:SetTextColor(unpack(k == sel.src and S.gold or S.dim))
    b:Show()
  end
  local wsY = isItem and WS_Y or WS_Y + 34
  ws:ClearAllPoints(); ws:SetPoint("TOPLEFT", 0, wsY)
  craft:ClearAllPoints(); craft:SetPoint("TOPLEFT", 0, wsY)
  resetViews()
  if sel.src == "nodes" then viewNodes(e)
  elseif sel.src == "fishing" then viewFishing(e)
  elseif sel.src == "skin" or sel.src == "loot" then viewHunt(e, sel.src)
  elseif sel.src == "vendor" then viewVendor(e)
  elseif sel.src == "craft" then viewCraft(e)
  else
    tbl:Hide()
    mapTabs({}, nil)
    drawArt(nil)
    sideReset("")
    W.mapNone:SetText("No known source in Nodewalker's data. Check the auction house.")
  end
  -- checks sit under the table, or under the fold when it's showing
  local anchor = W.checkAnchor or tbox
  W.checkA:ClearAllPoints()
  W.checkA:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -8)
  W.checkB:ClearAllPoints()
  W.checkB:SetPoint("TOPLEFT", W.checkA, "BOTTOMLEFT", 0, -5)
  local sk = sel.src == "skin" and "skinning" or (sel.src == "fishing" and "fishing") or (e.nodeKind == "herb" and "herbalism") or (e.nodeKind == "ore" and "mining")
    or (sel.src == "craft" and select(2, NW.RecipeFor(e.id)))
  local pr = sk and NW.PROF_BY_KEY[sk]
  local lv = sk and NW.ProfSkill and NW.ProfSkill(sk)
  NW.SetWindowSubtitle(pr and (pr.name .. "  " .. (lv or "·  Not learned")) or "")
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
-- Open on a category, optionally a material and a source (Skinning's ranges)
function NW.FindMaterials(cat, id, src)
  sel.cat, sel.from, sel.need = cat, nil, nil
  if id then sel.id = id end
  sel.src = src
  if searchText ~= "" then search:SetText("") end
  open()
end
