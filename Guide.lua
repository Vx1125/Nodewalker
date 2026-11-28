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
-- Routes (Planner.lua) is a view of this tab: it takes the page's place while open
page = UI.AddTab("guide", "Material Finder", function()
  local R = NW.Routes
  if R then
    local keep = R.keep
    R.keep = nil
    -- the tab clicked while Routes shows: back to the Finder
    if R.IsOpen() and not keep then R.Close() return end
    if R.Wanted() then R.Open() return end
  end
  refresh()
  if NW.MaybeImportPrompt then NW.MaybeImportPrompt(page) end
end, function() if NW.Routes then NW.Routes.Leave() end end,
function() if NW.Routes then NW.Routes.Tick() end end)

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
  if both then
    local st0, hid = NW.db.settings, 0
    for _ in pairs(st0.hiddenNodes or {}) do hid = hid + 1 end
    sig = ("%d:%s:%s:%s:%s:%s:%s:%d"):format(sig, tostring((NW.GetSkill("herb"))), tostring((NW.GetSkill("ore"))),
      tostring(st0.includeHerb), tostring(st0.includeOre), tostring(st0.onlyGatherable), tostring(st0.onlySkillUps), hid)
  end
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
    -- Theoretical: every known spot up every lap, two items each. Known
    -- spots are where nodes have spawned, not nodes up at once, so this is an
    -- upper bound, never income. A spot with no price makes it partial (+?).
    local worth, priced, unpriced = 0, false, 0
    for _, pt in ipairs(pts) do
      local item = NW.NODE_ITEMS[pt[6]]
      local price, src
      if item and NW.Price then price, src = NW.Price(item) end
      if price and src ~= "est" then worth, priced = worth + price * 2 * (RARE[pt[6]] or 1), true
      else unpriced = unpriced + 1 end
    end
    local row = { mapID = id, name = name, note = note, recommended = rec, count = #pts, pts = pts }
    if w and #pts >= 3 then
      row.loop, row.order = quickLoop(pts)
      local minutes = row.loop / NW.MOUNT_YPS / 60
      row.rate = minutes > 0 and #pts / minutes or 0
      if priced and minutes > 0 then row.gold = worth / minutes * 60; row.goldPartial = unpriced > 0 end
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
-- For /nw perf: zone rankings kept (materials, node points) and node entries
function NW.GuideCacheStats()
  local n, pts, e = 0, 0, 0
  for _, c in pairs(cache) do
    n = n + 1
    for _, row in ipairs(c.rows) do pts = pts + #row.pts end
  end
  for _ in pairs(entryCache) do e = e + 1 end
  return n, pts, e
end
function NW.GuideClearCaches()
  for k in pairs(cache) do cache[k] = nil end
  for k in pairs(entryCache) do entryCache[k] = nil end
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
local LIST_W = 290
local L_W = LIST_W
local R_X = 16 + LIST_W + 16
local R_W = UI.CONTENT_W - R_X - 16
local MAP_W, MAP_H = 468, 312
local ZL_X = MAP_W + 2 + 10      -- the zone list, beside the map
local ZL_W = R_W - ZL_X
local C_W = ZL_W                 -- (the zone list's width: its rows and columns)
local SIDE_W = R_W               -- the strip under the map runs the full width
local WS_Y = -92 -- top of the map
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
-- a font string that shows its whole text on hover when it's cut short
local function fullOnHover(owner, fs)
  owner:HookScript("OnEnter", function(self)
    if fs:IsShown() and fs.IsTruncated and fs:IsTruncated() then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(fs:GetText() or "", 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  owner:HookScript("OnLeave", GameTooltip_Hide)
end

------------------------------------------------------------------------
-- Left: search, category, filters, the materials
------------------------------------------------------------------------
local ROUTES_W = 72
local search = CreateFrame("EditBox", nil, page, "BackdropTemplate")
search:SetSize(L_W - ROUTES_W - 6, 24)
search:SetPoint("TOPLEFT", 16, -8)
UI.Flat(search, S.sunk, S.edge)
search:SetFont(UI.FONT, 12, "")
search:SetTextColor(unpack(S.text))
search:SetTextInsets(22, 8, 0, 0)
search:SetAutoFocus(false)
search:SetMaxLetters(40)
-- Routes: your saved routes and the one you're on, no material needed
W.routes = UI.Button(page, "Routes", ROUTES_W, function() if NW.ShowRoutes then NW.ShowRoutes(false) end end, 24)
W.routes:SetPoint("LEFT", search, "RIGHT", 6, 0)
UI.Tip(W.routes, "Routes", "Saved routes, the route where you are, and the editor.")
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
search:SetScript("OnTextChanged", function(self, userInput)
  local t = self:GetText() or ""
  sHint:SetShown(t == "")
  if t ~= searchText then
    searchText = t
    -- typed by you: a new browse (code clears the search through clearSearch)
    if userInput ~= false then W.listOffset = 0; sel.hist = nil end
    refresh()
  end
end)
-- Clear the search from code: the text is emptied first, so whenever the
-- game fires OnTextChanged (now or next frame) there's nothing to redo
local function clearSearch()
  if searchText == "" and (search:GetText() or "") == "" then return end
  searchText = ""
  search:SetText("")
  sHint:Show()
end

-- Category: a button that opens the list of categories
local CAT_H, CAT_N = 24, 14
local CAT_BTN_W = L_W - 106
W.catBtn = UI.Button(page, "", CAT_BTN_W, nil, 22)
W.catBtn:SetPoint("TOPLEFT", 16, -38)
W.catBtn.label:ClearAllPoints()
W.catBtn.label:SetPoint("LEFT", 8, 0)
W.catBtn.label:SetPoint("RIGHT", -44, 0)
W.catBtn.label:SetJustifyH("LEFT")
W.catBtn.count = UI.Text(W.catBtn, 11, S.dim, "RIGHT")
W.catBtn.count:SetPoint("RIGHT", -20, 0)
local catArrow = W.catBtn:CreateTexture(nil, "OVERLAY")
catArrow:SetSize(10, 10)
catArrow:SetPoint("RIGHT", -6, 0)
catArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
catArrow:SetRotation(-math.pi / 2)
catArrow:SetVertexColor(unpack(S.gold))
local catBox = UI.Panel(nil, UIParent, 210, CAT_N * CAT_H + 6)
catBox:SetFrameStrata("FULLSCREEN_DIALOG")
catBox:SetClampedToScreen(true)
catBox:Hide()
catBox.anchor = W.catBtn
if UI.AutoClose then UI.AutoClose(catBox) end
W.catBtn:SetScript("OnClick", function()
  if catBox:IsShown() then catBox:Hide() return end
  catBox:SetScale(W.catBtn:GetEffectiveScale() / UIParent:GetEffectiveScale())
  catBox:ClearAllPoints()
  catBox:SetPoint("TOPLEFT", W.catBtn, "BOTTOMLEFT", 0, -2)
  catBox:Show()
end)
W.catBtn:HookScript("OnHide", function() catBox:Hide() end)
W.cats = {}
for i = 1, CAT_N do
  local b = CreateFrame("Button", nil, catBox)
  b:SetSize(208, CAT_H)
  b:SetPoint("TOPLEFT", 1, -3 - (i - 1) * CAT_H)
  UI.RowHighlight(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = UI.Text(b, 11, S.dim, "RIGHT")
  b.count:SetPoint("RIGHT", -8, 0)
  b.count:SetWidth(30)
  b.text = UI.Text(b, 12, S.text)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
  b.text:SetPoint("RIGHT", b.count, "LEFT", -4, 0)
  b.text:SetWordWrap(false)
  b:SetScript("OnClick", function(self)
    sel.cat = self.key
    st().matCat = self.key
    sel.hist, sel.from = nil, nil
    W.listOffset = 0
    catBox:Hide()
    clearSearch()
    refresh()
  end)
  W.cats[i] = b
end

-- Filters: what to leave out, and the order
local function sortSet(key) return function(v) st().matSort = v and key or nil end end
W.filters = UI.CheckMenu(page, "Filters", 100, {
  { "In my bags", function() return st().matHave end, function(v) st().matHave = v or nil end },
  { "Has a price", function() return st().matPriced end, function(v) st().matPriced = v or nil end },
  { "I can gather it", function() return st().matCan end, function(v) st().matCan = v or nil end,
    "Herbs, ore, fish and skins your professions can collect now." },
  { "Sort by name", function() return st().matSort == "name" end, sortSet("name") },
  { "Sort by price", function() return st().matSort == "price" end, sortSet("price") },
  { "Sort by owned", function() return st().matSort == "have" end, sortSet("have") },
}, function() W.listOffset = 0; refresh() end)
W.filters:SetPoint("TOPRIGHT", page, "TOPLEFT", 16 + L_W, -38)

local LROW_H, LROW_MAX = 22, 20
W.midHead = UI.Text(page, 10, S.dim)
W.midHead:SetPoint("TOPLEFT", 24, -68)
W.midHead:SetText("Material")
W.midCap = UI.Text(page, 10, S.dim, "RIGHT")
W.midCap:SetPoint("TOPRIGHT", page, "TOPLEFT", 16 + L_W - 8, -68)
W.midCap:SetText("Skill  ·  Price")
local mid = UI.Box(page, L_W, 5 * LROW_H + 4)
mid:SetPoint("TOPLEFT", 16, -82)
mid:EnableMouseWheel(true)
W.midCount = UI.Text(page, 10, S.dim, "RIGHT")
W.midCount:SetPoint("TOPRIGHT", mid, "BOTTOMRIGHT", -2, -4)
W.midEmpty = UI.Text(mid, 12, S.dim, "CENTER")
W.midEmpty:SetPoint("TOP", 0, -20)
W.midEmpty:SetWidth(L_W - 20)
W.rows = {}
W.listOffset = 0
for i = 1, LROW_MAX do
  local r = CreateFrame("Button", nil, mid)
  r:SetSize(L_W - 2, LROW_H)
  r:SetPoint("TOPLEFT", 1, -2 - (i - 1) * LROW_H)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 6, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.right = UI.Text(r, 11, S.dim, "RIGHT")
  r.right:SetPoint("RIGHT", -8, 0)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetWordWrap(false)
  r:SetScript("OnClick", function(self)
    if not self.e then return end
    if IsShiftKeyDown() and type(self.e.id) == "number" and NW.ChatLink and NW.ChatLink(self.e.id, nil, true) then return end
    sel.id, sel.src, sel.zone, sel.hist, sel.from = self.e.id, nil, nil, nil, nil
    st().matSel = self.e.id
    refresh()
  end)
  r:SetScript("OnEnter", function(self)
    if not self.e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if type(self.e.id) == "number" then GameTooltip:SetItemByID(self.e.id)
    else GameTooltip:SetText(self.name:GetText() or "", 1, 1, 1) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.rows[i] = r
end
mid:SetScript("OnMouseWheel", function(_, d)
  local max = math.max(0, (W.listN or 0) - (W.listShown or 5))
  local o = math.max(0, math.min(max, W.listOffset - d * 3))
  if o ~= W.listOffset then
    W.listOffset = o
    if W.listCache and W.drawRows then W.drawRows() else refresh() end
  end
end)
-- (the old Tracked list: tracked materials are a category now)
W.trackHead = CreateFrame("Frame", nil, page)
W.track = {}

------------------------------------------------------------------------
-- Right: header (name, target, Search AH), source switches
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
W.iconBox = iconBox
W.name = UI.Text(right, 17, S.gold)
W.name:SetPoint("TOPLEFT", iconBox, "TOPRIGHT", 10, -1)
W.name:SetWordWrap(false)
W.sub = UI.Text(right, 11, S.dim)
W.sub:SetPoint("BOTTOMLEFT", iconBox, "BOTTOMRIGHT", 10, 2)
W.sub:SetWordWrap(false)
-- hover areas for the two lines, for when they're cut short
W.nameHit = CreateFrame("Frame", nil, right)
W.nameHit:SetAllPoints(W.name)
W.nameHit:EnableMouse(true)
fullOnHover(W.nameHit, W.name)
W.subHit = CreateFrame("Frame", nil, right)
W.subHit:SetAllPoints(W.sub)
W.subHit:EnableMouse(true)
fullOnHover(W.subHit, W.sub)
W.ah = UI.Button(right, "Search AH", 86, function()
  if type(sel.id) ~= "number" or not NW.SearchAH then return end
  local n = NW.ItemName(sel.id)
  local g = M.Goal(sel.id)
  local need = g and M.Progress(g).remaining or 1
  if n then NW.SearchAH({ { n, math.max(1, need) } }) end
end, 22)
W.ah:SetPoint("TOPRIGHT", 0, -8)
UI.Tip(W.ah, "Search AH", "Searches Auctionator for it (at the auction house). With a target, for what's still missing.")
W.back = UI.Button(right, "", 120, function()
  local hist = sel.hist
  if hist and #hist > 0 then
    local prev = table.remove(hist)
    local pe = M.Get(prev.id)
    if pe then
      sel.id, sel.src, sel.zone, sel.cat = prev.id, prev.src, nil, prev.cat or pe.cat
      clearSearch()
      refresh()
      return
    end
  end
  if sel.from == "consumes" then NW.ShowTab("consumes") return end
  if sel.from and NW.OpenProfession then NW.OpenProfession(sel.from) end
end, 22)
W.back:SetPoint("RIGHT", W.ah, "LEFT", -4, 0)

-- target: owned, the number, the mode, Track (header, second line)
local goalBar = CreateFrame("Frame", nil, right)
goalBar:SetSize(350, 22)
goalBar:SetPoint("TOPRIGHT", 0, -30)
W.goalBar = goalBar
W.goalClear = UI.Button(goalBar, "Clear", 46, function() M.ClearGoal(sel.id); refresh() end, 20)
W.goalClear:SetPoint("RIGHT", 0, 0)
local function trackNow()
  local n = tonumber(W.goalEdit:GetText() or "")
  if type(sel.id) ~= "number" then return end
  if not n or n < 1 or n ~= math.floor(n) or n > 99999 then
    W.goalEdit:SetText("")
    W.goalEdit:ClearFocus()
    return
  end
  local _, err = M.SetGoal(sel.id, W.mode or "total", n, sel.from)
  if err == "full" then W.note:SetText("|cffd17665Up to 8 targets: clear one first|r") return end
  W.goalEdit:ClearFocus()
  refresh()
end
W.goalSet = UI.Button(goalBar, "Track", 56, trackNow, 20)
local MODES = { { "total", "Own total" }, { "more", "Collect more" } }
W.goalMode = UI.Dropdown(goalBar, 114, "", MODES, function() return W.mode or "total" end, function(v) W.mode = v end, 114,
  "Own total: have this many in your bags and bank.\nCollect more: get this many more than you have now.")
W.goalMode:SetPoint("RIGHT", W.goalSet, "LEFT", -4, 0)
W.goalEdit = CreateFrame("EditBox", nil, goalBar, "BackdropTemplate")
W.goalEdit:SetSize(56, 20)
UI.Flat(W.goalEdit, S.sunk, S.edge)
W.goalEdit:SetFont(UI.FONT, 12, "")
W.goalEdit:SetTextColor(unpack(S.text))
W.goalEdit:SetTextInsets(6, 6, 0, 0)
W.goalEdit:SetAutoFocus(false)
W.goalEdit:SetNumeric(true)
W.goalEdit:SetMaxLetters(5)
W.goalEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
W.goalEdit:SetScript("OnEnterPressed", trackNow)
W.goalEdit:SetPoint("RIGHT", W.goalMode, "LEFT", -4, 0)
W.goalHint = UI.Text(W.goalEdit, 12, S.disabled)
W.goalHint:SetPoint("LEFT", 6, 0)
W.goalHint:SetText("Target")
W.goalEdit:HookScript("OnTextChanged", function(self) W.goalHint:SetShown((self:GetText() or "") == "" and not self:HasFocus()) end)
W.goalEdit:HookScript("OnEditFocusGained", function() W.goalHint:Hide() end)
W.goalEdit:HookScript("OnEditFocusLost", function(self) W.goalHint:SetShown((self:GetText() or "") == "") end)
W.goalText = UI.Text(goalBar, 12, S.text, "RIGHT")
W.goalText:SetPoint("RIGHT", W.goalEdit, "LEFT", -8, 0)
W.goalText:SetWordWrap(false)
W.goalLabel = W.goalHint
-- the whole count (session, lifetime) on hover
W.goalHit = CreateFrame("Frame", nil, goalBar)
W.goalHit:SetAllPoints(W.goalText)
W.goalHit:EnableMouse(true)
W.goalHit:SetScript("OnEnter", function(self)
  if not W.goalTip then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(W.goalTipTitle or "", 1, 1, 1)
  for _, l in ipairs(W.goalTip) do GameTooltip:AddDoubleLine(l[1], l[2], S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
  GameTooltip:Show()
end)
W.goalHit:SetScript("OnLeave", GameTooltip_Hide)

-- what you need for the selected way to get it, beside its switch
W.req = CreateFrame("Frame", nil, right)
W.req:SetSize(260, 24)
W.req:EnableMouse(true)
W.req.text = UI.Text(W.req, 11, S.dim, "RIGHT")
W.req.text:SetPoint("RIGHT")
W.req.text:SetWidth(260)
W.req.text:SetWordWrap(false)
W.srcBtns = {}
local SRC_ORDER = { "nodes", "obj", "fishing", "skin", "loot", "vendor", "craft" }
for _, k in ipairs(SRC_ORDER) do
  local b = UI.Button(right, k, 90, function() sel.src = k; sel.zone = nil; W.zoneOffset = 0; refresh() end, 24)
  tabMark(b)
  W.srcBtns[k] = b
end

-- the zone list beside the map: heading (+ sort), captions, rows, checks
local tbl = CreateFrame("Frame", nil, page)
tbl:SetSize(C_W, MAP_H + 2)
W.tblHead = heading(tbl, "", C_W)
W.tblHead:SetPoint("TOPLEFT", 0, -2)
W.colName = UI.Text(tbl, 10, S.dim)
W.colName:SetPoint("TOPLEFT", 8, -26)
W.cols = {}
for k = 1, 3 do
  local t = UI.Text(tbl, 10, S.dim, "RIGHT")
  W.cols[k] = t
end
local TROW_H, TROWS = 22, 12
local tbox = UI.Box(tbl, C_W, 5 * TROW_H + 4)
tbox:SetPoint("TOPLEFT", 0, -40)
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
  r.name:SetWidth(C_W - 66) -- ends before the number
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
  local max = math.max(0, (W.zoneN or 0) - (W.tRows or 5))
  local o = math.max(0, math.min(max, W.zoneOffset - d * 2))
  if o ~= W.zoneOffset then W.zoneOffset = o; refresh() end
end)
-- long zone names, the way players shorten them, for when the full one won't fit
local SHORT_ZONE = {
  ["Eastern Plaguelands"] = "E. Plaguelands", ["Western Plaguelands"] = "W. Plaguelands",
  ["Stranglethorn Vale"] = "Stranglethorn", ["Hillsbrad Foothills"] = "Hillsbrad",
  ["Alterac Mountains"] = "Alterac", ["Redridge Mountains"] = "Redridge",
  ["Silverpine Forest"] = "Silverpine", ["Tirisfal Glades"] = "Tirisfal",
  ["Stonetalon Mountains"] = "Stonetalon", ["Dustwallow Marsh"] = "Dustwallow",
  ["Arathi Highlands"] = "Arathi", ["Deadwind Pass"] = "Deadwind", ["Elwynn Forest"] = "Elwynn",
}
-- a zone name in a table row: shortened only when the whole one doesn't fit
local function zoneText(fs, prefix, name)
  fs:SetText(prefix .. name)
  local short = SHORT_ZONE[name]
  if short and fs:GetStringWidth() > fs:GetWidth() then fs:SetText(prefix .. short) end
end
-- One number per row beside the map (the others are in the strip under it).
-- names: the three column captions a view has; W.showCol: which one shows.
local function setCols(names, show)
  local k0 = show
  if not k0 then for k = 3, 1, -1 do if names[k] then k0 = k break end end end
  W.showCol = k0
  for k = 1, 3 do
    local on = k == k0
    W.cols[k]:ClearAllPoints()
    W.cols[k]:SetPoint("TOPRIGHT", tbl, "TOPLEFT", C_W - 8, -26)
    W.cols[k]:SetText(on and names[k] or "")
    W.cols[k]:SetShown(on)
    for _, r in ipairs(W.zrows) do
      r.cells[k]:ClearAllPoints()
      r.cells[k]:SetPoint("RIGHT", r, "RIGHT", -8, 0)
      r.cells[k]:SetText("")
      r.cells[k]:SetShown(on)
    end
  end
  local oneCol = k0 and k0 > 0
  for _, r in ipairs(W.zrows) do r.name:SetWidth(oneCol and (C_W - 66) or (C_W - 16)) end
end

-- the table under the map: creatures in the selected zone (or what a fish is used in)
W.fold = CreateFrame("Button", nil, page)
W.fold:SetSize(R_W, 18)
W.fold.sign = UI.Text(W.fold, 12, S.gold)
W.fold.sign:SetPoint("LEFT", 6, 0)
W.fold.sign:Hide()
W.fold.text = UI.Text(W.fold, 10, S.dim)
W.fold.text:SetPoint("LEFT", 8, 0)
W.fold.n = UI.Text(W.fold, 10, S.dim, "RIGHT")
W.fold.n:SetPoint("RIGHT", -8, 0)
W.fold.c1 = UI.Text(W.fold, 10, S.dim, "RIGHT")
W.fold.c1:SetPoint("RIGHT", W.fold, "LEFT", R_W - 250, 0)
W.fold.c2 = UI.Text(W.fold, 10, S.dim, "RIGHT")
W.fold.c2:SetPoint("RIGHT", W.fold, "LEFT", R_W - 170, 0)
W.fold.c3 = UI.Text(W.fold, 10, S.dim, "RIGHT")
W.fold.c3:SetPoint("RIGHT", W.fold, "LEFT", R_W - 90, 0)
local CROWS = 3
W.crows = {}
for i = 1, CROWS do
  local r = CreateFrame("Button", nil, page)
  r:SetSize(R_W, 18)
  r:SetPoint("TOPLEFT", W.fold, "BOTTOMLEFT", 0, -(i - 1) * 18)
  UI.RowStripe(r)
  r:SetStripe(i % 2 == 0)
  UI.RowHighlight(r)
  r:SetScript("OnClick", function(self) if self.npc and W.onCreature then W.onCreature(self.npc) end end)
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function(_, d)
    local max = math.max(0, (W.cN or 0) - CROWS)
    local o = math.max(0, math.min(max, (W.cOffset or 0) - d))
    if o ~= W.cOffset then W.cOffset = o; refresh() end
  end)
  r.name = UI.Text(r, 12, S.text)
  r.name:SetPoint("LEFT", 8, 0)
  r.name:SetPoint("RIGHT", r, "LEFT", R_W - 270, 0)
  r.name:SetWordWrap(false)
  r.lvl = UI.Text(r, 12, S.dim, "RIGHT")
  r.lvl:SetPoint("RIGHT", r, "LEFT", R_W - 250, 0)
  r.ch = UI.Text(r, 12, S.text, "RIGHT")
  r.ch:SetPoint("RIGHT", r, "LEFT", R_W - 170, 0)
  r.req = UI.Text(r, 12, S.text, "RIGHT")
  r.req:SetPoint("RIGHT", r, "LEFT", R_W - 90, 0)
  r.extra = UI.Text(r, 12, S.text, "RIGHT")
  r.extra:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  W.crows[i] = r
end
W.checkA = UI.Check(tbl, "", function() return W.checkAGet and W.checkAGet() end, function(v) if W.checkASet then W.checkASet(v) end refresh() end)
W.checkB = UI.Check(tbl, "", function() return W.checkBGet and W.checkBGet() end, function(v) if W.checkBSet then W.checkBSet(v) end refresh() end)

-- sorts for the zone list, shown with their views
local function sortItems()
  local items = {}
  for _, s in ipairs(H.SORTS) do items[#items + 1] = { s[1], s[2] } end
  return items
end
W.huntSort = UI.Dropdown(tbl, 136, "", sortItems(), function() return st().huntSort or "density" end,
  function(v) st().huntSort = v ~= "density" and v or nil; refresh() end, 136,
  "Most spawns: known spawn points, each counted at its creature's drop chance (Classic data). Not creatures alive now.\nNearest my level: zones whose creature levels are closest to yours, then most spawns.\nMy history: where you've collected it most, from your own log.")
W.huntSort:SetPoint("TOPRIGHT", 0, 1)
W.nodeSort = UI.Dropdown(tbl, 136, "", { { "best", "Best" }, { "rate", "Spots per minute" }, { "gold", "Theoretical g/h" }, { "count", "Known spots" }, { "loop", "Shortest loop" } },
  function() return st().guideSort or "best" end, function(v) st().guideSort = v ~= "best" and v or nil; refresh() end, 136,
  "Best: known spots passed per minute on a mounted loop through all of them, scaled down for zones with under 25 known spots. For all herbs and ore: theoretical gold per hour the same way.\nZones with fewer than 3 known spots come last.")
W.nodeSort:SetPoint("TOPRIGHT", 0, 1)

------------------------------------------------------------------------
-- Map workspace: the map (its tabs on it), the zone list beside it
------------------------------------------------------------------------
local ws = CreateFrame("Frame", nil, right)
ws:SetPoint("TOPLEFT", 0, WS_Y)
ws:SetSize(R_W, MAP_H + 2)
local preview = UI.Box(ws, MAP_W + 2, MAP_H + 2)
preview:SetPoint("TOPLEFT", 0, 0)
preview:SetClipsChildren(true)
local pvArt = CreateFrame("Frame", nil, preview)
pvArt:SetPoint("TOPLEFT", 1, -1)
pvArt:SetSize(MAP_W, MAP_H)
local pvShade = pvArt:CreateTexture(nil, "BORDER")
pvShade:SetAllPoints()
pvShade:SetColorTexture(0, 0, 0, 0.15)
local pvTiles = {}
-- a click on the map away from any hunting ground clears the selection
pvArt:EnableMouse(true)
pvArt:SetScript("OnMouseUp", function() if W.onMapClick then W.onMapClick() end end)
local function plate(parent)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetFrameLevel(pvArt:GetFrameLevel() + 5)
  UI.Flat(f, { S.bg[1], S.bg[2], S.bg[3], 0.85 }, S.edge)
  return f
end
W.plate = plate(preview)
W.plate:SetPoint("TOPLEFT", 8, -8)
W.plate.text = UI.Text(W.plate, 12, S.gold)
W.plate.text:SetPoint("LEFT", 8, 0)
W.plate:SetHeight(20)
-- map modes and Expand, small, on the map's top right
local MODES_MAP = { { "known", "Known" }, { "mine", "History" }, { "route", "Route" }, { "heat", "Heatmap" } }
W.mapTabs = {}
W.expand = UI.Button(preview, "Expand", 58, function()
  -- on a zone's route, Expand opens the full-size route editor
  if W.routeEdit and not W.expanded then W.routeEdit() return end
  W.expanded = not W.expanded
  refresh()
end, 20)
W.expand:SetFrameLevel(pvArt:GetFrameLevel() + 6)
W.expand.label:SetFont(UI.FONT, 11, "")
W.expand:SetPoint("TOPRIGHT", -8, -8)
UI.Tip(W.expand, function() return W.routeEdit and not W.expanded and "Route editor" or "Expand map" end,
  function() return W.routeEdit and not W.expanded and "This zone's route, full size: avoid zones, Optimize loop, Start."
    or "The same map, larger. Click again to restore." end)
local prevTab = W.expand
for i = #MODES_MAP, 1, -1 do
  local m = MODES_MAP[i]
  local b = UI.Button(preview, m[2], 54, function(self)
    if not self.ok then return end
    st().huntMap = m[1]
    refresh()
  end, 20)
  b:SetFrameLevel(pvArt:GetFrameLevel() + 6)
  b.label:SetFont(UI.FONT, 11, "")
  b:SetWidth(math.max(44, b.label:GetStringWidth() + 16))
  b:SetPoint("RIGHT", prevTab, "LEFT", i == #MODES_MAP and -6 or -2, 0)
  tabMark(b)
  b.key = m[1]
  W.mapTabs[i] = b
  prevTab = b
end
W.legend = plate(preview)
W.legend:SetPoint("BOTTOMRIGHT", -8, 8)
W.legend:SetSize(132, 18)
W.legend.text = UI.Text(W.legend, 10, S.dim)
W.legend.text:SetPoint("CENTER")
W.mapNone = UI.Text(preview, 12, S.dim, "CENTER")
W.mapNone:SetPoint("CENTER")
W.mapNone:SetWidth(MAP_W - 60)
-- the caption: on the map's bottom left, its caveat on hover
W.capPlate = plate(preview)
W.capPlate:SetPoint("BOTTOMLEFT", 8, 8)
W.capPlate:SetHeight(18)
W.capPlate:EnableMouse(true)
W.caption = UI.Text(W.capPlate, 10, S.text)
W.caption:SetPoint("LEFT", 6, 0)
W.caption:SetWordWrap(false)
local capSet = W.caption.SetText
W.caption.SetText = function(self, t)
  capSet(self, t or "")
  local w = self:GetStringWidth() or 0
  local room = MAP_W - 16 - (W.legend:IsShown() and 150 or 0)
  self:SetWidth(math.min(w + 2, room - 12))
  W.capPlate:SetWidth(math.min(w + 14, room))
  W.capPlate:SetShown((t or "") ~= "")
end
W.capHit = W.capPlate
W.capHit:SetScript("OnEnter", function(self)
  local cut = W.caption.IsTruncated and W.caption:IsTruncated()
  if not (W.capTip or cut) then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText(W.caption:GetText() or "", 1, 1, 1, 1, true)
  if W.capTip then GameTooltip:AddLine(W.capTip, S.dim[1], S.dim[2], S.dim[3], true) end
  GameTooltip:Show()
end)
W.capHit:SetScript("OnLeave", GameTooltip_Hide)

local getDot, resetDots = UI.Pool(function()
  local t = pvArt:CreateTexture(nil, "OVERLAY")
  local mask = pvArt:CreateMaskTexture()
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(t)
  t:AddMaskTexture(mask)
  t:SetSize(5, 5)
  return t
end, "Finder map dots")
local getCell, resetCells = UI.Pool(function() return pvArt:CreateTexture(nil, "ARTWORK") end, "Finder heatmap cells")
local getLine, resetLines = UI.Pool(function()
  local l = pvArt:CreateLine(nil, "OVERLAY")
  l:SetThickness(2)
  return l
end, "Finder map lines")
local getNum, resetNums = UI.Pool(function()
  local f = pvArt:CreateFontString(nil, "OVERLAY")
  f:SetFont(UI.FONT, 13, "OUTLINE")
  return f
end, "Finder map numbers")
-- invisible hover areas over hunting grounds: who lives there
local getHot, resetHots = UI.Pool(function()
  local b = CreateFrame("Frame", nil, pvArt)
  b:EnableMouse(true)
  b:SetScript("OnMouseUp", function(self) if W.onHot then W.onHot(self.ground) end end)
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
        local lv = u.object and "" or u.min == u.max and tostring(u.min) or (u.min .. "-" .. u.max)
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
end, "Finder ground hover areas")
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
  selected = { 0.95, 0.82, 0.50, 1, 3 },
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
local function hot(s, g, method, title, ground)
  local h = getHot()
  h:ClearAllPoints()
  h:SetSize(math.max(16, s.rx * 2 * MAP_W), math.max(16, s.ry * 2 * MAP_H))
  h:SetPoint("CENTER", pvArt, "TOPLEFT", px(s.x, s.y))
  h.g, h.method, h.title, h.ground = g, method, title, ground
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

-- the strip under the map: what's selected (zone, ground, creature) and its facts
local strip = CreateFrame("Frame", nil, right)
strip:SetSize(R_W, 20)
strip:SetPoint("TOPLEFT", ws, "BOTTOMLEFT", 0, -6)
strip:EnableMouse(true)
W.strip = strip
W.sideTitle = UI.Text(strip, 13, S.gold)
W.sideTitle:SetPoint("LEFT", 0, 0)
W.sideTitle:SetWordWrap(false)
W.sideLine = UI.Text(strip, 11, S.text)
W.sideLine:SetPoint("LEFT", W.sideTitle, "RIGHT", 12, 0)
W.sideLine:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
W.sideLine:SetWordWrap(false)
W.sideLine:SetJustifyH("LEFT")
W.sideStats = {}
-- every fact on its own line, on hover (the strip is one line)
strip:SetScript("OnEnter", function(self)
  if #W.sideStats == 0 then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText(W.sideTitle:GetText() or "", 1, 1, 1)
  for _, s in ipairs(W.sideStats) do GameTooltip:AddDoubleLine(s[1], s[2], S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
  GameTooltip:Show()
end)
strip:SetScript("OnLeave", GameTooltip_Hide)
W.next = UI.Button(right, "Next", 52, function() H.Advance() end, 22)
W.skip = UI.Button(right, "Skip", 48, function() H.Advance(true) end, 22)
UI.Tip(W.next, "Next hunting ground", "Marks this one hunted and moves on.")
UI.Tip(W.skip, "Skip", "Moves on without marking it hunted.")
W.sideBtns = {}
for _, k in ipairs({ "reverse", "restore", "startHere", "showAll" }) do
  local label = ({ reverse = "Reverse", restore = "Restore", startHere = "Start here", showAll = "Show all" })[k]
  local b = UI.Button(right, label, 80, function() if W.sideClick[k] then W.sideClick[k]() end end, 22)
  b:SetWidth(b.label:GetStringWidth() + 26)
  W.sideBtns[k] = b
end
W.sideClick = {}
W.sideOrder = {}
UI.Tip(W.sideBtns.reverse, "Reverse", "Run the loop the other way, from this ground.")
UI.Tip(W.sideBtns.restore, "Restore", "Back to the route Nodewalker suggests for this zone.")
UI.Tip(W.sideBtns.startHere, "Start here", "Start the loop at the selected ground.")
UI.Tip(W.sideBtns.showAll, "Show all", "Back to every hunting ground and creature in this zone.")
local function sideDraw()
  local parts = {}
  for _, s in ipairs(W.sideStats) do parts[#parts + 1] = DIM .. s[1] .. "|r " .. s[2] end
  W.sideTitle:SetWidth(math.min(260, (W.sideTitle:GetStringWidth() or 0) + 2))
  W.sideLine:SetText(table.concat(parts, "    "))
end
local function sideReset(title)
  W.sideTitle:SetWidth(0)
  W.sideTitle:SetText(title or "")
  for k in pairs(W.sideStats) do W.sideStats[k] = nil end
  for k in pairs(W.sideOrder) do W.sideOrder[k] = nil end
  W.next:Hide(); W.skip:Hide()
  for _, b in pairs(W.sideBtns) do b:Hide() end
  sideDraw()
end
local function sideButton(k, fn)
  W.sideBtns[k]:Show()
  W.sideClick[k] = fn
  W.sideOrder[#W.sideOrder + 1] = W.sideBtns[k]
end
local function sideStat(label, value)
  W.sideStats[#W.sideStats + 1] = { label, value }
  sideDraw()
end
local function sideButtons()
  W.next:Show(); W.skip:Show()
  table.insert(W.sideOrder, 1, W.skip)
  table.insert(W.sideOrder, 1, W.next)
end

------------------------------------------------------------------------
-- Craft workspace (in place of the map for crafted materials)
------------------------------------------------------------------------
local craft = CreateFrame("Frame", nil, right)
craft:SetPoint("TOPLEFT", 0, WS_Y)
craft:SetSize(R_W, 384)
local CL_W = 400
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
  r.name:SetWidth(CL_W - 220) -- ends before the Need column
  r.name:SetWordWrap(false)
  r.cells = {}
  for k, c in ipairs(MATCOL) do
    local t = UI.Text(r, 12, S.text, "RIGHT")
    t:SetPoint("RIGHT", r, "LEFT", c[2], 0)
    r.cells[k] = t
  end
  r.find = UI.Button(r, "Find", 46, function(self)
    local id = self:GetParent().id
    if id and W.goTo then W.goTo(id, self:GetParent().missing) end
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
W.main = UI.Button(right, "", 120, function() if W.mainClick then W.mainClick() end end, 22, "primary")
W.second = UI.Button(right, "", 100, function() if W.secondClick then W.secondClick() end end, 22)
W.third = UI.Button(right, "", 100, function() if W.thirdClick then W.thirdClick() end end, 22)
W.note = UI.Text(right, 11, S.dim, "RIGHT")
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
liveTip(W.checkA); liveTip(W.checkB); liveTip(W.main); liveTip(W.second); liveTip(W.req)
local function action(btn, text, fn, tipTitle, tipBody, enabled)
  btn:Show()
  btn:SetText(text)
  btn:SetWidth(math.max(btn == W.main and 110 or 80, btn.label:GetStringWidth() + 26))
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
  local n = W.tRows or 5
  W.zoneOffset = math.min(W.zoneOffset, math.max(0, #rows - n))
  for i, r in ipairs(W.zrows) do
    local row = i <= n and rows[i + W.zoneOffset] or nil
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
-- a recipe's colour at a skill
local function diffColor(r, skill)
  if not skill then return nil end
  local o, y, g, gr = r.orange or r.yellow, r.yellow, r.green, r.grey
  if o and skill < o then return "red" end
  if y and skill < y then return "orange" end
  if g and skill < g then return "yellow" end
  if gr and skill < gr then return "green" end
  return "grey"
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
  W.tblHead.text:SetText("Zones")
  W.nodeSort:Show()
  W.colName:SetText("Zone   |cffd6b266*|r guide pick")
  setCols({ "Spots", "Loop", "g/h" }, (by == "gold" and 3) or (by == "loop" and 2) or 1)
  local pick = rows[1]
  for _, row in ipairs(rows) do if sel.zone and row.name == sel.zone then pick = row end end
  tableRows(rows)
  for _, r in ipairs(W.zrows) do
    local row = r.row
    if row then
      zoneText(r.name, row.recommended and "|cffd6b266*|r " or "", row.name)
      r.name:SetTextColor(unpack(row.count > 0 and S.text or S.dim))
      r.cells[1]:SetText(row.count > 0 and row.count or dash())
      r.cells[2]:SetText(row.loop and fmtTime(row.loop / NW.MOUNT_YPS) or dash())
      r.cells[3]:SetText(row.gold and ("~" .. NW.Money(row.gold, true) .. (row.goldPartial and "|cffd17665+|r" or "")) or dash())
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
        GameTooltip:AddLine("Theoretical g/h: as if every known spot had a node on every lap, two items each, at Auctionator prices, mounted, no time to gather. Known spots are where nodes have spawned, not nodes up at once: real income is lower.", S.dim[1], S.dim[2], S.dim[3], true)
        if rw.goldPartial then GameTooltip:AddLine("Some nodes here have no price yet (+): left out, not counted as zero.", S.bad[1], S.bad[2], S.bad[3], true) end
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
      W.caption:SetText(("Your route  ·  %d stops, %s %s%s"):format(#stp, fmtTime(route.seconds or 0), route.open and "each way" or "per loop",
        route.alsoOthers and "  ·  mixed: other herbs and ore you can gather" or ""))
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
      W.caption:SetText("Quick loop past every known spot  ·  no route built")
      W.capTip = "Known spots are where nodes have spawned before, not nodes up now."
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
    W.caption:SetText("Known spots per area")
    W.capTip = "Known spots are where nodes have spawned before, not nodes up now."
  elseif row then
    W.caption:SetText(row.count > 0 and (("%d known spots%s"):format(row.count,
      row.loop and ("  ·  loop " .. fmtTime(row.loop / NW.MOUNT_YPS)) or "")) or "No spots saved yet")
    W.capTip = row.count > 0 and ("Known spots are where nodes have spawned before, not nodes up now. The loop is one mounted lap past all of them, no time to gather.") or nil
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
    local all = both and row.mapID and #(NW.db.nodes[row.mapID] or {}) or 0
    sideStat("Known spots", tostring(row.count) .. (all > row.count and (DIM .. " of " .. all .. "|r") or ""))
    if row.rate then
      sideStat("Loop", fmtTime(row.loop / NW.MOUNT_YPS))
      sideStat("Spots per minute", ("%.1f"):format(row.rate))
      sideStat("Theoretical g/h", row.gold and ("~" .. NW.Money(row.gold, true) .. (row.goldPartial and " |cffd17665+?|r" or "")) or DIM .. "no prices|r")
    end
    if isFocus then sideStat("Your route", ("%d stops"):format(#route.stops)) end
    local mine = NW.GatherLog and row.mapID and NW.GatherLog.ZoneCount(row.mapID, not both and e.id or nil) or 0
    if mine > 0 then sideStat("You gathered here", TEAL .. mine .. "|r") end
  end
  if row and row.mapID and mode == "route" then
    local zid = row.mapID
    W.routeEdit = function() NW.OpenRouteEditor(zid) end
  end
  if route and #route.stops > 1 then
    action(W.second, "Edit route", function() NW.ShowRoutes(row.mapID) end, "Edit route",
      "This zone's saved route in Routes: avoid zones, Optimize loop, Restart.")
  end
  action(W.main, "Build route", function()
    if not (row and row.mapID and row.count > 0) then return end
    -- Routes builds, reviews and starts it; the saved route stays until then
    NW.ProposeRoute({ kind = "nodes", item = e.id, src = sel.src, zone = row.name, map = row.mapID,
      opts = both and {} or { focus = focusOf(entry), alsoOthers = st().guideAlsoOthers } })
  end, "Build route", "Opens it in Routes to review. This zone's saved route changes only when you start the new one.",
    row ~= nil and row.mapID ~= nil and row.count > 0)
end

-- Fishing
local function viewFishing(e)
  local F = NW.FISHING
  local f = F and F.FISH[e.id]
  W.tblHead.text:SetText("Waters")
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
      zoneText(r.name, "", r.row.name)
      r.name:SetTextColor(unpack(S.text))
      r.cells[3]:SetText(r.row.n > 0 and (TEAL .. r.row.n .. "|r") or dash())
      r:SetSelected(r.row == pick)
      r.onClick = function(self) sel.zone = self.row.name; refresh() end
      r.onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.row.name, 1, 1, 1)
        if self.row.n > 0 then GameTooltip:AddDoubleLine("You caught here", self.row.n, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        GameTooltip:Show()
      end
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
  local cskill = NW.ProfSkill and NW.ProfSkill("cooking")
  local used = {}
  for _, rr in ipairs(NW.RECIPES and NW.RECIPES.cooking or {}) do
    for _, re in ipairs(rr.reagents) do if re[1] == e.id then used[#used + 1] = { r = rr, n = re[2] } break end end
  end
  if #used > 0 then
    W.fold:Show()
    W.cN = #used
    W.cOffset = math.max(0, math.min(W.cOffset or 0, #used - #W.crows))
    W.fold.text:SetText("Used in Cooking" .. (#used > #W.crows and ("  ·  %d-%d of %d"):format(W.cOffset + 1, math.min(#used, W.cOffset + #W.crows), #used) or ""))
    W.fold.c1:SetText("Uses"); W.fold.c2:SetText("Learn"); W.fold.c3:SetText("Grey"); W.fold.n:SetText("")
    for i, r in ipairs(W.crows) do
      local u = used[i + W.cOffset]
      r:SetShown(u ~= nil)
      r.npc = nil
      if u then
        local col = cskill and diffColor(u.r, cskill)
        r.name:SetText((SKILL_HEX[col] or "") .. u.r.name .. "|r")
        r.lvl:SetText(u.n)
        r.ch:SetText(u.r.orange or u.r.yellow or "?")
        r.req:SetText(u.r.grey or "?")
        r.extra:SetText("")
        r:SetSelected(false)
      end
    end
  end
  action(W.main, "Fishing + Cooking plan", function() if NW.OpenFishCook then NW.OpenFishCook() end end, nil, nil, NW.OpenFishCook ~= nil)

end

-- Skinning and creature loot: Hunting Grounds
local function huntOpts(method)
  local o = { elites = st().huntElites or false }
  if method == "skin" and st().huntSkill ~= false then o.skill = NW.ProfSkill and NW.ProfSkill("skinning") or nil end
  return o
end
local function lv(lo, hi)
  if not lo then return "?" end
  if not hi or lo == hi then return tostring(lo) end
  return lo .. "-" .. hi
end
local function sameXY(a, b) return a and b and math.abs(a.x - b.x) < 1e-4 and math.abs(a.y - b.y) < 1e-4 end
local function viewHunt(e, method)
  local g = H.Grounds(e.id, method, huntOpts(method))
  local zones = H.Sort(g.zones, st().huntSort or "density", e.id)
  if st().huntSort == "mine" then
    local f = {}
    for _, z in ipairs(zones) do if z.mapID and NW.GatherLog.ZoneCount(z.mapID, e.id) > 0 then f[#f + 1] = z end end
    zones = f
  end
  local skill = NW.ProfSkill and NW.ProfSkill("skinning")
  local OBJ = method == "obj"
  local GOT = method == "skin" and "Skinned" or (OBJ and "Picked" or "Looted")
  W.tblHead.text:SetText(OBJ and "Zones" or "Grounds")
  W.huntSort:Show()
  W.colName:SetText("Zone")
  if method == "skin" then setCols({ "Spawns", "Skill", GOT }, 1) elseif OBJ then setCols({ "", "Spots", GOT }, 2) else setCols({ "Level", "Spawns", GOT }, 2) end
  local pick = zones[1]
  for _, z in ipairs(zones) do if sel.zone == z.name then pick = z end end
  local hunt = H.Route()
  tableRows(zones)
  for _, r in ipairs(W.zrows) do
    local z = r.row
    if z then
      local active = hunt and hunt.item == e.id and hunt.method == method and hunt.zone == z.name
      zoneText(r.name, active and "|cff5fd4e0›|r " or "", z.name)
      r.name:SetTextColor(unpack(z.mapID and S.text or S.dim))
      local mine = z.mapID and NW.GatherLog and NW.GatherLog.ZoneCount(z.mapID, e.id) or 0
      if method == "skin" then
        local req = H.SkinReq(z.maxL)
        r.cells[1]:SetText(z.n)
        r.cells[2]:SetText(req and ((SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r") or dash())
      else
        r.cells[1]:SetText(OBJ and "" or lv(z.minL, z.maxL))
        r.cells[2]:SetText(z.n)
      end
      r.cells[3]:SetText(mine > 0 and (TEAL .. mine .. "|r") or dash())
      r:SetSelected(z == pick)
      r.onClick = function(self) sel.zone = self.row.name; sel.ground, sel.npc, W.cOffset = nil, nil, 0; refresh() end
      r.onEnter = function(self)
        local zz = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(zz.name, 1, 1, 1)
        if not OBJ then GameTooltip:AddDoubleLine("Creature levels", lv(zz.minL, zz.maxL), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        GameTooltip:AddDoubleLine(OBJ and "Known spots" or "Known spawn points", zz.n, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        if not OBJ then GameTooltip:AddDoubleLine("Expected per clear", ("~%d"):format(math.floor(zz.w + 0.5)), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        GameTooltip:AddDoubleLine(OBJ and "Areas" or "Hunting grounds", #zz.grounds, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        local m2 = zz.mapID and NW.GatherLog and NW.GatherLog.ZoneCount(zz.mapID, e.id) or 0
        if m2 > 0 then GameTooltip:AddDoubleLine("You collected here", m2, 0.35, 0.75, 0.72, 1, 1, 1) end
        if method == "skin" then GameTooltip:AddLine("Skill: the most any creature here needs (Classic rule).", S.dim[1], S.dim[2], S.dim[3], true) end
        GameTooltip:AddLine(GOT .. ": what you've collected here yourself.", S.dim[1], S.dim[2], S.dim[3], true)
        if not zz.mapID then GameTooltip:AddLine("Not on your client's map list", S.bad[1], S.bad[2], S.bad[3]) end
        GameTooltip:AddLine(OBJ and "Classic data (pfQuest): spots may differ in WoW Forever." or "Classic data (pfQuest, cMaNGOS): creatures and chances may differ in WoW Forever.", S.dim[1], S.dim[2], S.dim[3], true)
        GameTooltip:Show()
      end
    end
  end
  -- what's selected inside the zone: a hunting ground, a creature
  local ground
  if pick and sel.ground then
    for _, gr in ipairs(pick.grounds) do if sameXY(gr, sel.ground) then ground = gr end end
    if not ground then sel.ground = nil end
  end
  local chance = {}
  for _, sr in ipairs(H.Sources(e.id, method)) do chance[sr.npc] = sr end
  local list = {}
  if pick then
    for npc, n in pairs((ground or pick).npcs) do if chance[npc] then list[#list + 1] = { u = H.Unit(npc), n = n, s = chance[npc] } end end
    table.sort(list, function(a, b) return a.n * a.s.chance > b.n * b.s.chance end)
  end
  local npcSel
  if sel.npc then
    for _, c in ipairs(list) do if c.u and c.u.npc == sel.npc then npcSel = c end end
    if not npcSel then sel.npc = nil end
  end
  -- the fold: creatures in the zone, or in the selected ground
  local open = true
  W.fold:Show()
  W.cN = #list
  W.cOffset = math.max(0, math.min(W.cOffset or 0, #list - #W.crows))
  W.fold.text:SetText((ground and (OBJ and "Objects here" or "Creatures in this ground") or (method == "skin" and "Creatures to skin" or (OBJ and "Objects" or "Creatures")))
    .. (#list > #W.crows and ("  ·  %d-%d of %d"):format(W.cOffset + 1, math.min(#list, W.cOffset + #W.crows), #list) or ("  ·  " .. #list)))
  W.fold.c1:SetText(OBJ and "" or "Level"); W.fold.c2:SetText("Chance"); W.fold.c3:SetText(method == "skin" and "Skill" or ""); W.fold.n:SetText("Spawns")
  local shown = 0
  for i, r in ipairs(W.crows) do
    local c = open and list[i + W.cOffset]
    r:SetShown(c and true or false)
    r.npc = c and c.u and c.u.npc or nil
    if c and c.u then
      shown = i
      local u = c.u
      r:SetSelected(npcSel == c)
      r.name:SetText(u.name)
      r.lvl:SetText(OBJ and "" or lv(u.min, u.max))
      r.ch:SetText(H.ChanceText(c.s.chance))
      r.extra:SetText(c.n)
      if method == "skin" then
        local req = H.SkinReq(u.max)
        r.req:SetText((SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r")
      else
        r.req:SetText("")
      end
      r.onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(u.name, 1, 1, 1)
        local kind = (H.TYPE[u.type] or "") .. ((u.rank and u.rank > 0) and ("  ·  " .. (H.RANK[u.rank] or "")) or "")
        if kind ~= "" and not OBJ then GameTooltip:AddLine(kind, S.dim[1], S.dim[2], S.dim[3]) end
        if not OBJ then GameTooltip:AddDoubleLine("Level", lv(u.min, u.max), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        GameTooltip:AddDoubleLine(method == "skin" and "Skinning gives it" or (OBJ and "Gives it" or "Drops it (ordinary loot)"), H.ChanceText(c.s.chance, true) .. (c.s.calc and " (calculated)" or ""), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        if c.s.max and c.s.max > 1 then GameTooltip:AddDoubleLine("Each time", c.s.min .. "-" .. c.s.max, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        if method == "skin" then GameTooltip:AddDoubleLine("Skinning needed", H.SkinReq(u.max) .. " (Classic rule)", S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        GameTooltip:AddDoubleLine(ground and "Known spawns in this ground" or "Known spawns here", c.n, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
        if u.respawn and u.respawn > 0 then GameTooltip:AddDoubleLine("Respawn (Classic)", ("~%d min"):format(math.ceil(u.respawn / 60)), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        local mine = NW.GatherLog and NW.GatherLog.Npc(u.npc)
        if mine and (mine.skin + mine.loot + (mine.obj or 0)) > 0 then
          local got = mine.items[e.id] or 0
          local times = method == "skin" and mine.skin or (OBJ and (mine.obj or 0) or mine.loot)
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Your own log (not the server's drop rate)", 0.35, 0.75, 0.72)
          GameTooltip:AddDoubleLine(method == "skin" and "You skinned" or (OBJ and "You picked" or "You looted"), times .. "x", S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
          GameTooltip:AddDoubleLine("It gave you", got, S.dim[1], S.dim[2], S.dim[3], 1, 1, 1)
          if times >= 10 then GameTooltip:AddDoubleLine("Each time", ("%.2f"):format(got / times), S.dim[1], S.dim[2], S.dim[3], 1, 1, 1) end
        end
        GameTooltip:AddLine(OBJ and "Classic data (pfQuest)" or "Classic data (pfQuest, cMaNGOS)", S.dim[1], S.dim[2], S.dim[3])
        GameTooltip:AddLine(npcSel == c and (OBJ and "Click: show all objects" or "Click: show all creatures") or "Click: show only its spawns on the map", S.gold[1], S.gold[2], S.gold[3])
        GameTooltip:Show()
      end
    end
  end
  if method == "skin" then
    setCheck(W.checkA, "Only what I can skin", function() return st().huntSkill ~= false end,
      function(v) st().huntSkill = v end, skill and "Leaves out creatures above your Skinning skill (Classic rule: level × 5 from level 20)."
        or "Has no effect until you learn Skinning: every creature is shown.")
  end
  if not OBJ then setCheck(method == "skin" and W.checkB or W.checkA, "Include elites and rares", function() return st().huntElites end, function(v) st().huntElites = v end) end
  -- clicks: a ground on the map, a creature in the list, the map's empty space
  W.onHot = function(gr)
    if not gr then return end
    if sameXY(gr, sel.ground) then sel.ground = nil else sel.ground = { x = gr.x, y = gr.y } end
    sel.npc, W.cOffset = nil, 0
    refresh()
  end
  W.onCreature = function(npc)
    sel.npc = sel.npc ~= npc and npc or nil
    refresh()
  end
  W.onMapClick = function()
    if sel.ground or sel.npc then sel.ground, sel.npc = nil, nil; refresh() end
  end
  -- map
  local plan = pick and H.Plan(pick) or {}
  local active = hunt and hunt.item == e.id and hunt.method == method and pick and hunt.zone == pick.name
  local mode = mapTabs({ known = true, mine = true, route = true, heat = true }, active and "route" or "heat")
  drawArt(pick and pick.mapID, pick and pick.name)
  if pick and not pick.mapID then W.mapNone:SetText("Not on your client's map list") end
  local function groundOf(st2)
    for _, gr in ipairs(pick.grounds) do if sameXY(gr, st2) then return gr end end
  end
  if pick and pick.mapID then
    if npcSel and mode ~= "mine" and mode ~= "route" then
      -- one creature: only its spawns, the grounds faint behind them
      for _, gr in ipairs(pick.grounds) do ring(gr, "hunted") end
      local pts = H.SpawnsIn(npcSel.u.npc, pick.name)
      for _, c in ipairs(pts) do dotAt(c[1], c[2], 6, 0.95, 0.82, 0.50, 0.95) end
      W.caption:SetText(("%s  ·  %d known %s  ·  Classic data"):format(npcSel.u.name, #pts, OBJ and "spots" or "spawn points"))
      W.capTip = OBJ and "Where it spawned in WoW Classic. Not where one is now." or "Where this creature spawned in WoW Classic. Not where one is now. Click it again in the list, or Show all, for every creature."
    elseif mode == "known" or mode == "heat" then
      if mode == "known" then
        for _, b in pairs(pick.bins) do
          for _, c in ipairs(b.cells) do dotAt(c[1], c[2], 4, 0.85, 0.72, 0.45, 0.8) end
        end
        W.caption:SetText(OBJ and "Known spots  ·  Classic data" or "Known spawn points  ·  Classic data")
      else
        drawBins(pick.bins, 3)
        W.caption:SetText(OBJ and "Known spots per area  ·  Classic data" or "Expected per clear  ·  Classic data")
      end
      W.capTip = OBJ and "Where it spawned in WoW Classic, not objects up now. Click a ring to select that area." or "Where creatures that give it spawned in WoW Classic; the heatmap weights each spawn by its drop chance and count. Not creatures alive now. Click a ring to select that hunting ground."
      for i, gr in ipairs(pick.grounds) do
        ring(gr, gr == ground and "selected" or "plain")
        hot(gr, gr, method, (OBJ and "Area " or "Hunting ground ") .. i, gr)
      end
    elseif mode == "mine" then
      local n = drawMine(pick.mapID, e.id)
      if ground then ring(ground, "selected") end
      W.caption:SetText(n > 0 and (TEAL .. "Where you collected it|r") or "Nothing collected here yet")
      W.capTip = n > 0 and "Your own gathering log: where you skinned, looted or picked it. Purchases, mail and trades aren't counted." or nil
    else
      local stops, states, cur = plan, nil, 1
      if active then
        stops, states, cur = hunt.stops, {}, hunt.cur
        for i in ipairs(hunt.stops) do states[i] = H.State(i) end
      end
      drawRoute(stops, states, cur)
      for i, s2 in ipairs(stops) do
        local gr = groundOf(s2)
        if gr and gr == ground then ring(s2, "selected") end
        hot(s2, gr or { npcs = {}, n = s2.n, respawn = s2.respawn }, method, "Ground " .. i .. (states and states[i] and ("  ·  " .. states[i]) or ""), gr)
      end
      local len = H.Length(pick.mapID, stops)
      W.caption:SetText(#stops == 1 and (OBJ and "One area" or "One area: stay and hunt") or
        (("%d %s  ·  ~%d yd loop, straight lines"):format(#stops, OBJ and "areas" or "grounds", len and math.floor(len / 10 + 0.5) * 10 or 0)))
      W.capTip = (OBJ and "Areas" or "Hunting grounds") .. " from Classic spawn data. Distances are straight lines, not paths. Click a ring to select it."
    end
  end
  -- side column: the creature, else the ground, else the route, else the zone
  local inRoute = ground and active and H.StopFor(ground)
  if npcSel then
    local u = npcSel.u
    sideReset(u.name)
    if not OBJ then sideStat("Level", lv(u.min, u.max) .. ((u.rank and u.rank > 0) and ("  " .. (H.RANK[u.rank] or "")) or "")) end
    sideStat(method == "skin" and "Skinning gives it" or (OBJ and "Gives it" or "Drops it"), H.ChanceText(npcSel.s.chance, true) .. (npcSel.s.calc and " (calculated)" or ""))
    if method == "skin" then
      local req = H.SkinReq(u.max)
      sideStat("Skinning needed", (SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r")
    end
    sideStat(OBJ and "Known spots here" or "Known spawns here", tostring(#H.SpawnsIn(u.npc, pick.name)))
    local mine = NW.GatherLog and NW.GatherLog.Npc(u.npc)
    if mine and (mine.skin + mine.loot + (mine.obj or 0)) > 0 then
      sideStat(method == "skin" and "You skinned" or (OBJ and "You picked" or "You looted"), TEAL .. ((method == "skin" and mine.skin or (OBJ and mine.obj or mine.loot)) .. "x") .. "|r")
    end
    sideButton("showAll", function() sel.npc, sel.ground = nil, nil; refresh() end)
  elseif ground then
    local idx
    for i, gr in ipairs(pick.grounds) do if gr == ground then idx = i end end
    sideReset((OBJ and "Area " or "Ground ") .. (idx or ""))
    if not OBJ then sideStat("Creature levels", lv(ground.minL, ground.maxL)) end
    sideStat(OBJ and "Spots" or "Spawn points", tostring(ground.n))
    if method == "skin" and ground.maxL then
      local req = H.SkinReq(ground.maxL)
      sideStat("Skinning needed", (SKILL_HEX[NW.SkillColor(req, skill)] or "") .. req .. "|r")
    end
    if ground.respawn then sideStat("Respawn (Classic)", ("~%d min"):format(math.ceil(ground.respawn / 60))) end
    -- your own collecting inside this ground
    local mineHere = 0
    for _, sp in ipairs(NW.GatherLog and NW.GatherLog.Spots(pick.mapID, e.id) or {}) do
      local dx, dy = (sp.x - ground.x) / ground.rx, (sp.y - ground.y) / ground.ry
      if dx * dx + dy * dy <= 1 then mineHere = mineHere + sp.n end
    end
    if mineHere > 0 then sideStat("You collected here", TEAL .. mineHere .. "|r") end
    if inRoute and inRoute ~= hunt.cur then sideButton("startHere", function() H.SetStart(inRoute); refresh() end) end
    sideButton("showAll", function() sel.npc, sel.ground = nil, nil; refresh() end)
  elseif active then
    sideReset("Route")
    local here = H.Here()
    sideStat("Ground", ("%d of %d"):format(hunt.cur, #hunt.stops) .. (here == hunt.cur and "  |cff94ba78here|r" or ""))
    if #hunt.stops > 1 then sideButtons() end
    for i = 1, #hunt.stops do
      local back = H.Revisit(i)
      if back and i ~= hunt.cur then sideStat("Ground " .. i, back > 0 and ("back ~%d min"):format(math.ceil(back / 60)) or "back now") break end
    end
    local sess = NW.GatherLog and NW.GatherLog.Session(e.id) or 0
    if sess > 0 then sideStat("This session", TEAL .. sess .. "|r") end
    if #hunt.stops > 2 then sideButton("reverse", function() H.Reverse(); refresh() end) end
    if hunt.custom then sideButton("restore", function() H.Start(e.id, method, pick); refresh() end) end
  else
    sideReset(pick and pick.name or "")
    if pick then
      if not OBJ then sideStat("Creature levels", lv(pick.minL, pick.maxL)) end
      sideStat(OBJ and "Areas" or "Hunting grounds", tostring(#pick.grounds))
      sideStat(OBJ and "Spots" or "Spawn points", tostring(pick.n))
      if plan[1] and plan[1].respawn then sideStat("Respawn (Classic)", ("~%d min"):format(math.ceil(plan[1].respawn / 60))) end
      local mine = pick.mapID and NW.GatherLog and NW.GatherLog.ZoneCount(pick.mapID, e.id) or 0
      if mine > 0 then sideStat("You collected here", TEAL .. mine .. "|r") end
    end
  end
  -- note: empty lists, filtered creatures
  local outN = 0
  for _, n in pairs(g.out or {}) do outN = outN + n end
  if #zones == 0 then
    W.mapNone:SetText(st().huntSort == "mine" and "You haven't collected it anywhere yet."
      or (outN > 0 and "No creatures left with these filters." or (OBJ and "No known spots outdoors." or "No known spawns outdoors.")))
  elseif g.out and g.out.skill then
    W.note:SetText(("%d creature%s need more Skinning"):format(g.out.skill, g.out.skill == 1 and "" or "s"))
  end
  -- actions: a selected ground first, then the route
  local ok = pick ~= nil and pick.mapID ~= nil
  if ground then
    action(W.main, "Farm this area", function() NW.ProposeRoute(H.Propose(e.id, method, pick, huntOpts(method), ground)) end,
      "Farm this area", OBJ and "A route of just this area. Opens in Routes to review and start." or "A route of just this hunting ground: stay and hunt. Opens in Routes to review and start.", ok)
    if active then
      if inRoute then
        action(W.second, "Remove from route", function() H.RemoveStop(inRoute); refresh() end)
      else
        action(W.second, "Add to route", function() H.AddGround(ground); refresh() end, "Add to route", "Joins the loop where it adds the least distance.")
      end
    end
    action(W.third, "Show on map", function() if NW.PinMap then NW.PinMap(pick.mapID, ground.x * 100, ground.y * 100, OBJ and M.Name(e) or "Hunting ground") end end)
  else
    if active then
      action(W.main, "Stop route", function() H.Stop(); refresh() end)
      if W.note:GetText() == "" then W.note:SetText("Next and Skip are in the session panel too") end
    else
      action(W.main, #plan > 1 and (OBJ and "Build route" or "Build hunting route") or (OBJ and "Farm here" or "Hunt here"), function()
        if pick then NW.ProposeRoute(H.Propose(e.id, method, pick, huntOpts(method))) end
      end, OBJ and "Route" or "Hunting route", OBJ and "Circles the densest areas of known spots, nearest first. Opens in Routes to review. Straight-line distances, not paths." or "Circles the densest hunting grounds, nearest first. Opens in Routes to review; your current hunt stays until you start the new one. Straight-line distances, not paths. Click a ring on the map to farm one ground.",
        ok and #plan > 0)
    end
    action(W.second, "Show on map", function()
      local s2 = (active and hunt.stops[hunt.cur]) or plan[1]
      if s2 and NW.PinMap then NW.PinMap(pick.mapID, s2.x * 100, s2.y * 100, OBJ and M.Name(e) or "Hunting ground") end
    end, nil, nil, ok and plan[1] ~= nil)
  end
end
do -- time it for /nw perf (a no-op unless timings are on)
  local inner = viewHunt
  viewHunt = function(e, method)
    local t0 = NW.PerfStart()
    inner(e, method)
    NW.PerfStop("Finder hunt view (grounds, list and map)", t0)
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
  setCols({ nil, nil, "Zone" }, 0)
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
  -- (the materials are in the table under it)
  W.cDesc:SetText((p and p.name or key) .. ((r.yield or 1) > 1 and ("  ·  makes " .. r.yield) or ""))
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
    if not (me and (me.src.nodes or me.src.obj or me.src.skin or me.src.loot or me.src.fishing)) then farmable = false
    else farmWhere[#farmWhere + 1] = NW.ItemName(m.id) or ("item " .. m.id) end
  end
  local ways = {}
  if #missingList == 0 then
    ways[#ways + 1] = { "Craft it", "You have the reagents", S.HEX.good .. "0|r" }
  else
    if farmable then ways[#ways + 1] = { "Craft it, gather reagents", "Gather: " .. table.concat(farmWhere, ", "), S.HEX.good .. "0|r" } end
    ways[#ways + 1] = { "Craft it, buy reagents", "Missing reagents from the AH or a vendor", "~" .. NW.Money(buyCost, true) .. (buyUnknown and " |cffd17665+?|r" or "") }
  end
  if ahP and ahSrc == "ah" then ways[#ways + 1] = { ("Buy %d"):format(n), "Ready-made from the AH; no skill-ups", "~" .. NW.Money(ahP * n, true) } end
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
      UI.FitText(ur.name, u.r.name, 11, 9)
      ur.n:SetText(u.n)
      ur.req:SetText((SKILL_HEX[u.col] or S.HEX.dim) .. (u.r.orange or u.r.yellow or "?") .. "|r")
    end
  end
  W.cUsedMore:SetText(#used > #W.cUsed and (("%d more  ·  colours: skill-ups at your skill"):format(#used - #W.cUsed)) or "Colours: skill-ups at your skill")
  -- actions
  local first = missingList[1]
  if first and M.Get(first.id) then
    action(W.main, "Find " .. (NW.ItemName(first.id) or "material"), function() W.goTo(first.id, first.n) end)
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
  -- (what one round of crafts takes is the materials table)
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local BOTH = { id = "both", name = "All herbs and ore", cat = "herb", src = { nodes = true }, nodeKind = "both", uses = 0 }
-- named for what you can gather: "All herbs", "All ore", or both
local function bothName()
  local h, o = NW.GetSkill("herb"), NW.GetSkill("ore")
  if h and not o then return "All herbs", "herb" end
  if o and not h then return "All ore", "ore" end
  return "All herbs and ore", "node"
end
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
  if e.id == "both" then
    if NW.GetSkill("ore") and not NW.GetSkill("herb") then return NW.NodeIcon("Copper Vein", "ore") end
    return NW.NodeIcon("Peacebloom", "herb")
  end
  return NW.ItemIcon(e.id) or (e.src.nodes and NW.NodeIcon(e.name, e.nodeKind)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function subText(e)
  if e.id == "both" then return "One route past every node you can gather" end
  local parts = {}
  for _, k in ipairs(M.Sources(e)) do parts[#parts + 1] = M.SourceText(e, k) end
  local nn = e.src.nodes and M.NodeNames(e.id)
  local req = nn and nn[1] and NW.RequiredSkill(nn[1])
  local rr, rk
  if e.src.craft and not e.src.nodes then rr, rk = NW.RecipeFor(e.id) end
  local txt = table.concat(parts, " · ")
  if req then txt = txt .. " " .. req
  elseif rr and #parts == 1 and rr.orange then txt = txt .. " · " .. ((NW.PROF_BY_KEY[rk] or {}).name or "") .. " " .. rr.orange end
  return txt
end

-- What the selected way to get it needs from you: shown beside its switch.
-- Never blocks a preview; says what gathering would take.
W.eligibility = function(e, src)
  local BAD, DIMC = "|cffd17665", DIM
  local function prof(key) local p = NW.PROF_BY_KEY[key] return p and p.name or key end
  if src == "nodes" then
    if e.id == "both" then
      return ("Herbalism %s  ·  Mining %s"):format(NW.GetSkill("herb") or "-", NW.GetSkill("ore") or "-")
    end
    local kind = e.nodeKind
    local name = kind == "ore" and "Mining" or "Herbalism"
    local entry = nodeEntry(e)
    local req = NW.RequiredSkill(entry[1])
    local skill = NW.GetSkill(kind)
    if not skill then
      return BAD .. name .. " not learned|r" .. DIMC .. "  ·  preview only|r",
        ("This route can be previewed, but gathering needs %s%s."):format(name, req and (" " .. req) or "")
    end
    if req and skill < req then
      return BAD .. ("Needs %s %d"):format(name, req) .. "|r" .. DIMC .. ("  ·  you have %d|r"):format(skill),
        ("Your %s is too low to gather it yet. Routes still preview."):format(name)
    end
    if req then
      local c = NW.SkillColor(req, skill)
      return DIMC .. ("%s %d  ·  you have %d|r"):format(name, req, skill) .. (c == "grey" and DIMC .. "  ·  no skill-ups|r" or "")
    end
  elseif src == "skin" then
    local skill = NW.ProfSkill and NW.ProfSkill("skinning")
    if not skill then return BAD .. "Skinning not learned|r" .. DIMC .. "  ·  preview only|r", "Hunting grounds and routes preview, but skinning needs Skinning." end
    return DIMC .. ("Skinning %d  ·  creatures you can skin are coloured|r"):format(skill)
  elseif src == "fishing" then
    local f = NW.FISHING and NW.FISHING.FISH[e.id]
    local skill = NW.ProfSkill and NW.ProfSkill("fishing")
    if not skill then return BAD .. "Fishing not learned|r", "Fishing is taught by any fishing trainer." end
    if f and f.skill and skill < f.skill then
      return BAD .. ("Guides fish it at %d"):format(f.skill) .. "|r" .. DIMC .. ("  ·  you have %d|r"):format(skill)
    end
    return DIMC .. ("Fishing %d|r"):format(skill)
  elseif src == "craft" then
    local r, key = NW.RecipeFor(e.id)
    if not r then return nil end
    local skill = NW.ProfSkill and NW.ProfSkill(key)
    local need = r.orange or r.yellow
    if not skill then return BAD .. prof(key) .. " not learned|r", ("Made by %s%s."):format(prof(key), need and (" at " .. need) or "") end
    if need and skill < need then return BAD .. ("Needs %s %d"):format(prof(key), need) .. "|r" .. DIMC .. ("  ·  you have %d|r"):format(skill) end
    return DIMC .. ("%s %d|r"):format(prof(key), skill)
  end
  return nil
end

local function resetViews()
  for _, r in ipairs(W.crows) do r:Hide(); r.onEnter = nil; r.extra:SetText("") end
  W.fold:Hide()
  W.fold.c1:SetText(""); W.fold.c2:SetText(""); W.fold.c3:SetText(""); W.fold.n:SetText("")
  W.checkA:Hide(); W.checkB:Hide()
  W.checkAGet, W.checkASet, W.checkBGet, W.checkBSet = nil, nil, nil, nil
  W.checkAnchor = nil
  W.huntSort:Hide(); W.nodeSort:Hide()
  for _, b in ipairs({ W.main, W.second, W.third }) do b:Hide(); b.tipTitle, b.tipBody = nil, nil end
  W.mainClick, W.secondClick, W.thirdClick = nil, nil, nil
  W.note:SetText("")
  W.caption:SetText("")
  W.capTip = nil
  ws:Show()
  craft:Hide()
  tbl:Show()
  W.strip:Show()
end

-- the skill a material's main source asks for, if it has one
local function skillOf(e)
  if type(e.id) ~= "number" then return nil end
  if e.src.nodes then
    local nn = M.NodeNames(e.id)
    return nn and nn[1] and NW.RequiredSkill(nn[1])
  end
  if e.src.fishing then
    local f = NW.FISHING and NW.FISHING.FISH[e.id]
    return f and f.skill
  end
  if e.src.craft then
    local r = NW.RecipeFor(e.id)
    return r and (r.orange or r.yellow)
  end
end
-- can you collect it now (herb, ore, fish, skins) with what you know
local function canGather(e)
  if e.src.nodes and e.nodeKind then
    local have = NW.GetSkill(e.nodeKind)
    local req = skillOf(e)
    if have and (not req or req <= have) then return true end
  end
  if e.src.fishing and NW.ProfSkill and NW.ProfSkill("fishing") then return true end
  if e.src.skin and NW.ProfSkill and NW.ProfSkill("skinning") then return true end
  return false
end

-- the material rows alone: scrolling redraws these, not the whole page
function W.drawRows()
  local list, e, shownN = W.listCache or {}, W.listSel, W.listShown or 5
  W.midCount:SetText(#list > shownN and ("%d-%d of %d"):format(W.listOffset + 1, math.min(#list, W.listOffset + shownN), #list) or (#list > 0 and (#list .. (#list == 1 and " material" or " materials")) or ""))
  W.midEmpty:SetText(#list == 0 and (searchText ~= "" and "No materials match." or "Nothing here with these filters.") or "")
  for i, r in ipairs(W.rows) do
    local x = i <= shownN and list[i + W.listOffset] or nil
    r.e = x or false
    r:SetShown(x ~= nil)
    if x then
      r.icon:SetTexture(iconOf(x))

      local g = type(x.id) == "number" and M.Goal(x.id)
      local txt
      if g then
        txt = ownedText(x)
      else
        local sk = skillOf(x)
        local p = type(x.id) == "number" and NW.Price and NW.Price(x.id)
        txt = (sk and tostring(sk) or "") .. ((sk and p) and "  ·  " or "") .. (p and NW.Money(p, true) or "")
        if x.id == "both" then txt = DIM .. "whole zone|r" end
      end
      r.right:SetText(txt)
      -- the name gets what the number leaves, a point smaller if that's not enough
      r.name:SetWidth(math.max(60, L_W - 2 - 28 - 16 - (r.right:GetStringWidth() or 0)))
      UI.FitText(r.name, (x.id == "both" and "|cffd6b266" or M.ACCENT[x.cat] or "") .. M.Name(x) .. "|r", 12, 10)
      r:SetSelected(x == e)
    end
  end
end

refresh = function()
  if not page:IsVisible() then return end
  W.routeEdit = nil
  local s = st()
  sel.cat = sel.cat or s.matCat or "herb"
  -- category menu
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
  local curCat
  for i, b in ipairs(W.cats) do
    local c = catList[i]
    b:SetShown(c ~= nil)
    if c then
      b.key = c.key
      b.icon:SetTexture(c.icon)
      b.text:SetText(c.label)
      b.count:SetText(c.n)
      local on = c.key == sel.cat
      if on then curCat = c end
      b:SetSelected(on)
      b.text:SetTextColor(unpack(on and S.gold or S.text))
    end
  end
  catBox:SetHeight(math.min(#catList, #W.cats) * CAT_H + 6)
  if searchText ~= "" then
    W.catBtn:SetText("Search: all materials")
    W.catBtn.count:SetText("")
  else
    W.catBtn:SetText(curCat and curCat.label or "All materials")
    W.catBtn.count:SetText(curCat and curCat.n or "")
  end
  -- materials
  local list = M.Search(searchText, sel.cat)
  if s.matHave or s.matPriced or s.matCan then
    local f = {}
    for _, x in ipairs(list) do
      local ok = type(x.id) == "number"
      if ok and s.matHave and NW.ItemCount(x.id) <= 0 then ok = false end
      if ok and s.matPriced and not (NW.Price and NW.Price(x.id)) then ok = false end
      if ok and s.matCan and not canGather(x) then ok = false end
      if ok then f[#f + 1] = x end
    end
    list = f
  end
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
  -- the whole-zone route for everything you can gather: always the first row
  if searchText == "" and (sel.cat == "herb" or sel.cat == "ore" or sel.cat == "all" or not sel.cat) and not (s.matHave or s.matPriced) then
    BOTH.name = bothName()
    table.insert(list, 1, BOTH)
  end
  -- One selection: the material must be in the list on screen. A category or
  -- search that leaves it out picks the first result (or nothing), and
  -- everything below (source, zone, map, actions) follows from that.
  sel.id = sel.id or s.matSel
  local e
  for _, x in ipairs(list) do if x.id == sel.id then e = x break end end
  if not e then
    e = list[1]
    sel.id, sel.src, sel.zone, sel.hist = e and e.id, nil, nil, nil
    W.zoneOffset = 0
  end
  if sel.id ~= nil then s.matSel = sel.id end
  if sel.needFor ~= sel.id then sel.need = nil end -- a shopping list's amount belongs to its material
  if W.shownID ~= sel.id then W.shownID = sel.id; W.expanded = false end
  local srcs = e and (e.id == "both" and { "nodes" } or M.Sources(e)) or {}
  local okSrc = false
  for _, k in ipairs(srcs) do if k == sel.src then okSrc = true end end
  if not okSrc then sel.src = srcs[1]; sel.zone = nil; W.zoneOffset = 0 end
  local selKey = tostring(sel.id) .. ":" .. tostring(sel.src) .. ":" .. tostring(sel.zone)
  if W.selKey ~= selKey then W.selKey = selKey; sel.ground, sel.npc, W.cOffset = nil, nil, 0 end
  W.onHot, W.onCreature, W.onMapClick = nil, nil, nil
  -- the list fills the column
  local pageH = page:GetHeight() or 0
  if pageH < 300 then pageH = UI.CONTENT_H end
  local shownN = math.max(5, math.min(LROW_MAX, math.floor((pageH - 82 - 22 - 4) / LROW_H)))
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
  W.midCap:SetText(sel.cat == "tracked" and searchText == "" and "Target" or "Skill  ·  Price")
  W.listCache, W.listSel = list, e
  W.drawRows()
  -- right
  right:SetShown(e ~= nil)
  tbl:SetShown(e ~= nil)
  W.fold:Hide()
  for _, r in ipairs(W.crows) do r:Hide() end
  if not e then
    W.expanded = false
    NW.SetWindowSubtitle("")
    return
  end
  W.icon:SetTexture(iconOf(e))
  W.name:SetText(M.Name(e))
  local cat = M.CAT[e.cat]
  local subParts = { cat and (cat.short or cat.label) or "" }
  if e.id == "both" then
    -- what the route takes in, and what your filters leave out
    local _, what = bothName()
    local hid = 0
    for _ in pairs(NW.db.settings.hiddenNodes or {}) do hid = hid + 1 end
    subParts = { ("One route past every %s you can gather"):format(what) }
    if hid > 0 then subParts[#subParts + 1] = ("|cffd17665%d hidden in Settings|r"):format(hid) end
  end
  if e.uses and e.uses > 0 then subParts[#subParts + 1] = ("Used in %d recipe%s"):format(e.uses, e.uses == 1 and "" or "s") end
  local p, psrc
  if type(e.id) == "number" and NW.Price then p, psrc = NW.Price(e.id) end
  if p then subParts[#subParts + 1] = (psrc == "vendor" and "Vendor " or "~") .. NW.Money(p, "mid") end
  W.sub:SetText(table.concat(subParts, "  ·  "))
  local isItem = type(e.id) == "number"
  W.ah:SetShown(isItem and NW.HasAuctionator ~= nil and NW.HasAuctionator())
  W.back:ClearAllPoints()
  if W.ah:IsShown() then W.back:SetPoint("RIGHT", W.ah, "LEFT", -4, 0) else W.back:SetPoint("TOPRIGHT", 0, -8) end
  -- back: to the material you came from (an ingredient's Find), else the profession
  local hist = sel.hist
  local prev = hist and hist[#hist]
  local fromP = sel.from and (sel.from == "consumes" and { name = "Consumes" } or NW.PROF_BY_KEY[sel.from])
  W.back:SetShown(prev ~= nil or fromP ~= nil)
  if prev then
    local pe = M.Get(prev.id)
    W.back:SetText("‹ " .. (pe and M.Name(pe) or "Back"))
  elseif fromP then
    W.back:SetText("‹ " .. fromP.name)
  end
  W.back:SetWidth(math.min(170, (W.back.label:GetStringWidth() or 60) + 24))
  -- the name runs up to the buttons, the line under it up to the target
  local topRight = (W.ah:IsShown() and 90 or 0) + (W.back:IsShown() and (W.back:GetWidth() + 4) or 0)
  W.name:SetWidth(math.max(80, R_W - 50 - topRight - 8))
  -- target (second line of the header)
  goalBar:SetShown(isItem)
  local goalW = 0
  if isItem then
    local g = M.Goal(e.id)
    local have = NW.ItemCount(e.id)
    local life = NW.GatherLog and NW.GatherLog.Item(e.id).n or 0
    local sess = NW.GatherLog and NW.GatherLog.Session(e.id) or 0
    local tip = { { "Owned", have } }
    local txt
    if g then
      local pr = M.Progress(g)
      if g.mode == "more" then
        txt = ("Collected %s / %d"):format((pr.done and S.HEX.good or "") .. pr.shown .. "|r", pr.target)
      else
        txt = ("Owned %s / %d"):format((pr.done and S.HEX.good or "") .. have .. "|r", pr.target)
      end
      tip[#tip + 1] = { "Target", pr.target .. (g.mode == "more" and " more" or "") }
      tip[#tip + 1] = { "Remaining", pr.done and "done" or pr.remaining }
    else
      txt = "Owned " .. have
    end
    if sess > 0 then tip[#tip + 1] = { "This session", sess } end
    if life > 0 then tip[#tip + 1] = { "Lifetime", life } end
    W.goalText:SetText(txt)
    W.goalTip, W.goalTipTitle = tip, M.Name(e)
    W.goalClear:SetShown(g ~= nil)
    W.goalSet:ClearAllPoints()
    if g then W.goalSet:SetPoint("RIGHT", W.goalClear, "LEFT", -4, 0) else W.goalSet:SetPoint("RIGHT", 0, 0) end
    W.goalSet:SetText(g and "Update" or "Track")
    local gkey = tostring(e.id) .. ":" .. tostring(g and g.at) .. ":" .. tostring(sel.need)
    if W.goalKey ~= gkey and not W.goalEdit:HasFocus() then
      W.goalKey = gkey
      if sel.need and not g then W.goalEdit:SetText(sel.need); W.mode = "more"
      elseif g then W.goalEdit:SetText(g.n); W.mode = g.mode
      else W.goalEdit:SetText(""); W.mode = "total" end
    end
    W.goalHint:SetShown((W.goalEdit:GetText() or "") == "" and not W.goalEdit:HasFocus())
    W.goalMode:Refresh()
    goalW = (W.goalText:GetStringWidth() or 60) + 8 + 56 + 4 + 114 + 4 + 56 + (g and 50 or 0)
  end
  W.sub:SetWidth(math.max(80, R_W - 50 - goalW - 12))
  -- source switches, then what that way needs from you
  local x = 0
  local srcY = -58
  for _, k in ipairs(SRC_ORDER) do W.srcBtns[k]:Hide() end
  for _, k in ipairs(srcs) do
    local b = W.srcBtns[k]
    b:SetText(e.id == "both" and "Gathering" or M.SourceText(e, k))
    b:SetWidth(math.max(80, b.label:GetStringWidth() + 26))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", right, "TOPLEFT", x, srcY)
    x = x + b:GetWidth() + 4
    b.mark:SetShown(k == sel.src)
    b.label:SetTextColor(unpack(k == sel.src and S.gold or S.dim))
    b:Show()
  end
  local reqText, reqTip = W.eligibility(e, sel.src)
  W.req:ClearAllPoints()
  W.req:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, srcY)
  W.req:SetWidth(math.max(60, R_W - x - 8))
  W.req.text:SetWidth(math.max(60, R_W - x - 8))
  W.req.text:SetText(reqText or "")
  W.req.tipTitle, W.req.tipBody = reqTip and "Requirement" or ((W.req.text.IsTruncated and W.req.text:IsTruncated()) and "Requirement" or nil), reqTip or (W.req.text.IsTruncated and W.req.text:IsTruncated() and reqText or nil)
  W.req:SetShown(reqText ~= nil)
  ws:ClearAllPoints(); ws:SetPoint("TOPLEFT", 0, WS_Y)
  craft:ClearAllPoints(); craft:SetPoint("TOPLEFT", 0, WS_Y)
  -- the zone list beside the map: as many rows as fit above its checks
  tbl:ClearAllPoints()
  tbl:SetPoint("TOPLEFT", preview, "TOPRIGHT", 10, 0)
  local checks = (sel.src == "skin") and 2 or ((sel.src == "loot" or (sel.src == "nodes" and e.id ~= "both")) and 1 or 0)
  local tRows = math.max(4, math.min(TROWS, math.floor((MAP_H + 2 - 40 - 4 - (checks > 0 and (checks * 20 + 6) or 0)) / TROW_H)))
  W.tRows = tRows
  tbox:SetHeight(tRows * TROW_H + 4)
  resetViews()
  if sel.src == "nodes" then viewNodes(e)
  elseif sel.src == "fishing" then viewFishing(e)
  elseif sel.src == "skin" or sel.src == "loot" or sel.src == "obj" then viewHunt(e, sel.src)
  elseif sel.src == "vendor" then viewVendor(e)
  elseif sel.src == "craft" then viewCraft(e); tbl:Hide()
  else
    tbl:Hide()
    mapTabs({}, nil)
    drawArt(nil)
    sideReset("")
    W.mapNone:SetText("No known source in Nodewalker's data. Check the auction house.")
  end
  -- the map, larger: the same map frame scaled up over the whole page
  local mapView = ws:IsShown() and preview:IsShown()
  if not mapView then W.expanded = false end
  local big = W.expanded and mapView
  local leftSide = { search, W.routes, W.catBtn, W.filters, W.midHead, W.midCap, mid, W.midCount }
  local head = { W.iconBox, W.name, W.sub, W.nameHit, W.subHit }
  if big then
    for _, f in ipairs(leftSide) do f:Hide() end
    for _, f in ipairs(head) do f:Hide() end
    for _, f in ipairs({ tbl, W.ah, W.back, W.goalBar, W.req, W.strip, W.fold }) do f:Hide() end
    for _, r in ipairs(W.crows) do r:Hide() end
    for _, k in ipairs(SRC_ORDER) do W.srcBtns[k]:Hide() end
  else
    for _, f in ipairs(leftSide) do f:Show() end
    for _, f in ipairs(head) do f:Show() end
  end
  ws:ClearAllPoints()
  preview:ClearAllPoints()
  if big then
    ws:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -8)
    local sc = math.min((UI.CONTENT_W - 32) / (MAP_W + 2), (pageH - 8 - 6 - 22 - 12) / (MAP_H + 2))
    preview:SetScale(sc)
    preview:SetPoint("TOPLEFT", ws, "TOPLEFT", 0, 0)
  else
    ws:SetPoint("TOPLEFT", 0, WS_Y)
    preview:SetScale(1)
    preview:SetPoint("TOPLEFT", 0, 0)
  end
  W.expand:SetShown(mapView)
  W.expand:SetText(big and "Restore" or "Expand")
  -- under the map: the strip, then the buttons, then the table
  local btnTop
  if craft:IsShown() then
    W.strip:Hide()
    btnTop = { craft, -390 }
  elseif big then
    btnTop = { preview, "BOTTOMLEFT", 6 }
  else
    btnTop = { W.strip, "BOTTOMLEFT", 4 }
  end
  local row = {}
  for _, b in ipairs({ W.main, W.second, W.third }) do if b:IsShown() then row[#row + 1] = b end end
  if not big then for _, b in ipairs(W.sideOrder) do if b:IsShown() then row[#row + 1] = b end end
  else W.next:Hide(); W.skip:Hide(); for _, b in pairs(W.sideBtns) do b:Hide() end end
  local used = 0
  for i, b in ipairs(row) do
    b:ClearAllPoints()
    if i == 1 then
      if btnTop[2] == -390 then b:SetPoint("TOPLEFT", craft, "TOPLEFT", 0, -390)
      elseif big then b:SetPoint("TOPLEFT", ws, "TOPLEFT", 0, -((MAP_H + 2) * preview:GetScale()) - 6)
      else b:SetPoint("TOPLEFT", btnTop[1], btnTop[2], 0, -btnTop[3]) end
    else
      b:SetPoint("LEFT", row[i - 1], "RIGHT", 6, 0)
    end
    used = used + b:GetWidth() + 6
  end
  local rowW = big and (UI.CONTENT_W - 32) or R_W
  W.note:ClearAllPoints()
  if row[1] then
    W.note:SetPoint("LEFT", row[1], "LEFT", used + 4, 0)
  else
    if btnTop[2] == -390 then W.note:SetPoint("TOPLEFT", craft, "TOPLEFT", 0, -394)
    else W.note:SetPoint("TOPLEFT", btnTop[1], btnTop[2], 0, -btnTop[3] - 4) end
  end
  W.note:SetWidth(math.max(40, rowW - used - 4))
  -- the table under the buttons
  if W.fold:IsShown() and not big then
    W.fold:ClearAllPoints()
    W.fold:SetPoint("TOPLEFT", W.strip, "BOTTOMLEFT", 0, -(4 + 22 + 6))
  else
    W.fold:Hide()
    for _, r in ipairs(W.crows) do r:Hide() end
  end
  -- checks under the zone list
  W.checkA:ClearAllPoints()
  W.checkA:SetPoint("TOPLEFT", tbox, "BOTTOMLEFT", 2, -6)
  W.checkB:ClearAllPoints()
  W.checkB:SetPoint("TOPLEFT", W.checkA, "BOTTOMLEFT", 0, -5)
  local sk = sel.src == "skin" and "skinning" or (sel.src == "fishing" and "fishing") or (e.nodeKind == "herb" and "herbalism") or (e.nodeKind == "ore" and "mining")
    or (sel.src == "craft" and select(2, NW.RecipeFor(e.id)))
  local pr = sk and NW.PROF_BY_KEY[sk]
  local lv = sk and NW.ProfSkill and NW.ProfSkill(sk)
  NW.SetWindowSubtitle(pr and (pr.name .. "  " .. (lv or "·  Not learned")) or "")
end
do -- time a whole Finder refresh for /nw perf (a no-op unless timings are on)
  local inner = refresh
  refresh = function()
    local t0 = NW.PerfStart()
    inner()
    NW.PerfStop("Finder refresh (material selection)", t0)
  end
end

-- live: bags, objectives, routes, your log
local queued
local function later()
  if queued or not page:IsVisible() then return end
  queued = true
  C_Timer.After(0.3, function() queued = false; refresh() end)
end
M.OnChange(later)
H.OnChange(later)
if NW.GatherLog then NW.GatherLog.OnChange(later) end
NW.On("BAG_UPDATE_DELAYED", later)

function NW.ToggleGuide()
  if NW.Routes and NW.Routes.IsOpen() then NW.Routes.Close() return end
  if NW.Routes and not NW.window:IsShown() then NW.Routes.Close() end -- opens on the Finder, not Routes
  NW.ToggleWindow("guide")
end
if NW.Routes then NW.Routes.Attach(page, function() refresh() end) end
-- what's selected (read-only use: tests, debugging)
function NW.MaterialSelection() return sel, W end
local function open()
  if NW.Routes then NW.Routes.Close() end
  if NW.window:IsShown() then NW.ShowTab("guide") else st().lastTab = "guide"; NW.window:Show() end
  refresh()
end
-- Open on one material: from a profession's shopping list (from = its key,
-- need = what's missing, offered as a target), or anywhere else
function NW.FindMaterial(id, from, need)
  local e = M.Get(id)
  if not e then return false end
  sel.id, sel.src, sel.zone, sel.from, sel.need, sel.needFor, sel.hist = id, nil, nil, from, need, id, nil
  sel.cat = e.cat
  clearSearch()
  open()
  return true
end
-- From an ingredient (a crafted material's Find): remember where you were,
-- at most five back, never the same material twice in the trail
W.goTo = function(id, need)
  local e = M.Get(id)
  if not e then return end
  local hist = sel.hist or {}
  for i = #hist, 1, -1 do
    if hist[i].id == id then for _ = i, #hist do table.remove(hist) end break end
  end
  local curE = sel.id and M.Get(sel.id)
  if sel.id and sel.id ~= id then hist[#hist + 1] = { id = sel.id, src = sel.src, cat = curE and curE.cat or sel.cat } end
  while #hist > 5 do table.remove(hist, 1) end
  sel.hist = hist
  sel.id, sel.src, sel.zone, sel.need, sel.needFor = id, nil, nil, need, id
  sel.cat = e.cat
  clearSearch()
  refresh()
end
-- Open on a material, source and zone (Routes' way back to where a route came from)
function NW.FindMaterialAt(id, src, zone)
  local e = M.Get(id)
  if not e then return false end
  if sel.id ~= id then sel.from, sel.need, sel.needFor, sel.hist = nil, nil, id, nil end -- same material: keep its shopping target and trail
  sel.id, sel.src, sel.zone = id, src, zone
  sel.cat = e.cat
  W.zoneOffset = 0
  clearSearch()
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
  sel.cat, sel.from, sel.need, sel.hist = cat, nil, nil, nil
  if id then sel.id = id end
  sel.src, sel.zone = src, nil
  clearSearch()
  open()
end
