local ADDON, NW = ...

local C, S, UI = NW.COLORS, NW.STYLE, NW.UI

------------------------------------------------------------------------
-- Herb Guide tab: the best zones for one herb, ranked with your own node
-- data, and a one-click route through just that herb.
------------------------------------------------------------------------
local refreshGuide
local page = UI.AddTab("guide", "Herb Guide", function() refreshGuide() end)
local selectedHerb, previewID, lastHerb


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
  local c = cache[herb]
  if c and c.sig == sig then return c.rows end
  local rows, seen = {}, {}
  local function measure(id, name, note, rec)
    local w, h = NW.MapSize(id)
    local pts = {}
    for _, nd in ipairs(NW.db.nodes[id] or {}) do
      if nd.name == herb then pts[#pts + 1] = { (w and nd.x * w) or nd.x, (h and nd.y * h) or nd.y, nd.x, nd.y } end
    end
    local row = { mapID = id, name = name, note = note, recommended = rec, count = #pts, pts = pts }
    if w and #pts >= 3 then
      row.loop, row.order = quickLoop(pts)
      local minutes = row.loop / NW.MOUNT_YPS / 60
      row.rate = minutes > 0 and #pts / minutes or 0
      -- favour zones with enough spots to keep a loop going
      row.score = row.rate * math.min(1, #pts / 25)
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
        if nd.name == herb then
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
local LIST_W, ROW_H = 224, 17
local herbRows = {}
local list = UI.Box(page, LIST_W, #NW.HERB_GUIDE * ROW_H + 10)
list:SetPoint("TOPLEFT", 16, -8)

local SKILL_RGB = {
  red = { 1, 0.25, 0.2 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 0.9, 0.2 },
  green = { 0.35, 0.8, 0.35 }, grey = { 0.55, 0.55, 0.55 }, unknown = { 0.85, 0.85, 0.85 },
}

for i, entry in ipairs(NW.HERB_GUIDE) do
  local b = CreateFrame("Button", nil, list)
  b:SetSize(LIST_W - 2, ROW_H)
  b:SetPoint("TOPLEFT", 1, -5 - (i - 1) * ROW_H)
  UI.RowHighlight(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(14, 14)
  b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = UI.Text(b, 12, S.text)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.skill = UI.Text(b, 11, S.dim, "RIGHT")
  b.skill:SetPoint("RIGHT", -8, 0)
  b.entry = entry
  b:SetScript("OnClick", function() selectedHerb = entry[1]; refreshGuide() end)
  herbRows[i] = b
end
local listKey = UI.Text(page, 11, S.dim)
listKey:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -6)
listKey:SetText("Colour: skill-ups at your Herbalism")

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

local alsoOthers = UI.Check(right, "Also pick other herbs on the way",
  function() return NW.db.settings.guideAlsoOthers end,
  function(v) NW.db.settings.guideAlsoOthers = v end,
  "Built routes also stop at every other herb your filters allow.")
alsoOthers:SetPoint("TOPLEFT", hTip, "BOTTOMLEFT", 2, -6)

local colHead = UI.Heading(right, "Best zones", TEXT_W)
colHead:SetPoint("TOPLEFT", alsoOthers, "BOTTOMLEFT", -2, -14)
local colSub = UI.Text(right, 11, S.dim)
colSub:SetPoint("TOPLEFT", colHead, "BOTTOMLEFT", 0, -3)
colSub:SetText("Ranked by spots per minute on a loop, from your saved nodes")

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
local pvTiles = {}
local getPvDot, resetPvDots = UI.Pool(function()
  local t = pvArt:CreateTexture(nil, "OVERLAY")
  t:SetSize(5, 5)
  return t
end)
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
  if not row then pvTitle:SetText(""); pvSub:SetText("") return end
  pvTitle:SetText(row.name)
  if not row.mapID then
    pvSub:SetText("This zone isn't on your client's map list.")
    return
  end
  UI.DrawZoneArt(row.mapID, pvArt, pvTiles, PV_W, PV_H)
  local function p(x, y) return x * PV_W, -y * PV_H end
  local route = NW.db.routes[row.mapID]
  local isFocus = route and route.focus and route.focus[herb]
  if isFocus and #route.stops > 1 then
    local st = route.stops
    for i = 1, #st do
      local a, b = st[i], st[(i % #st) + 1]
      local l = getPvLine()
      l:SetColorTexture(C.route[1], C.route[2], C.route[3], 0.95)
      l:SetStartPoint("TOPLEFT", pvArt, p(a.x, a.y))
      l:SetEndPoint("TOPLEFT", pvArt, p(b.x, b.y))
    end
    pvSub:SetText(("Your optimized route: %d stops, %s per loop."):format(#st, fmtTime(route.seconds or 0)))
  elseif row.order and #row.pts <= 400 then
    for i = 1, #row.order do
      local a, b = row.pts[row.order[i]], row.pts[row.order[(i % #row.order) + 1]]
      local l = getPvLine()
      l:SetColorTexture(C.route[1], C.route[2], C.route[3], 0.4)
      l:SetStartPoint("TOPLEFT", pvArt, p(a[3], a[4]))
      l:SetEndPoint("TOPLEFT", pvArt, p(b[3], b[4]))
    end
    pvSub:SetText("Quick preview. Build route makes an optimized loop.")
  else
    pvSub:SetText(row.count > 0 and (row.count .. " known spots.")
      or "No spots saved yet. Import GatherMate2 data to rank it.")
  end
  for _, pt in ipairs(row.pts) do
    local d = getPvDot()
    d:SetColorTexture(C.herbEdge[1], C.herbEdge[2], C.herbEdge[3], 1)
    d:ClearAllPoints()
    d:SetPoint("CENTER", pvArt, "TOPLEFT", p(pt[3], pt[4]))
  end
end

-- Zone rows
local ROWS = 8
for i = 1, ROWS do
  local r = CreateFrame("Button", nil, right)
  r:SetSize(TEXT_W, 38)
  r:SetPoint("TOPLEFT", colSub, "BOTTOMLEFT", 0, -8 - (i - 1) * 40)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.02 or 0.045)
  UI.RowHighlight(r)
  r.line1 = UI.Text(r, 12, S.text)
  r.line1:SetPoint("TOPLEFT", 10, -5)
  r.line1:SetWidth(TEXT_W - 120)
  r.line1:SetWordWrap(false)
  r.line2 = UI.Text(r, 11, S.dim)
  r.line2:SetPoint("TOPLEFT", r.line1, "BOTTOMLEFT", 0, -4)
  r.line2:SetWidth(TEXT_W - 120)
  r.line2:SetWordWrap(false)
  r.build = UI.Button(r, "Build route", 96, nil, 22)
  r.build:SetPoint("RIGHT", -8, 0)
  r:SetScript("OnClick", function(self) drawPreview(self.row, selectedHerb) end)
  r.build:SetScript("OnClick", function(self)
    local row, herb = self:GetParent().row, selectedHerb
    if not row or not row.mapID then return end
    NW.BuildRoute(row.mapID, function()
      if page:IsShown() then drawPreview(row, herb) end
    end, { focus = { [herb] = true }, alsoOthers = NW.db.settings.guideAlsoOthers })
  end)
  UI.Tip(r.build, "Build route", "Replaces your saved route for this zone with an optimized loop through this herb.")
  zoneRows[i] = r
end
local moreText = UI.Text(right, 11, S.dim)
moreText:SetPoint("TOPLEFT", zoneRows[ROWS], "BOTTOMLEFT", 0, -6)
moreText:SetWidth(TEXT_W)

refreshGuide = function()
  if not page:IsShown() then return end
  local herbSkill = NW.GetSkill("herb")
  NW.SetWindowSubtitle(herbSkill and ("Herbalism " .. herbSkill) or "You don't have Herbalism")
  if not selectedHerb then
    -- start on the highest herb you can pick
    if herbSkill then
      for _, e in ipairs(NW.HERB_GUIDE) do
        local req = NW.RequiredSkill(e[1])
        if req and req <= herbSkill then selectedHerb = e[1] end
      end
    end
    selectedHerb = selectedHerb or NW.HERB_GUIDE[1][1]
  end
  if lastHerb ~= selectedHerb then previewID = nil; lastHerb = selectedHerb end
  local entry
  for _, b in ipairs(herbRows) do
    local e = b.entry
    local req = NW.RequiredSkill(e[1])
    local col = SKILL_RGB[NW.SkillColor(req, herbSkill)] or SKILL_RGB.unknown
    b.icon:SetTexture(NW.NodeIcon(e[1], "herb"))
    b.icon:SetDesaturated(NW.IsHidden(e[1]))
    b.text:SetText(e[1])
    b.text:SetTextColor(col[1], col[2], col[3])
    b.skill:SetText(req or "?")
    b:SetSelected(e[1] == selectedHerb)
    if e[1] == selectedHerb then entry = e end
  end
  local req = NW.RequiredSkill(entry[1])
  hIcon:SetTexture(NW.NodeIcon(entry[1], "herb"))
  hName:SetText(entry[1])
  local skillLine = ("Needs Herbalism %s"):format(req or "?")
  if herbSkill and req then
    local c = NW.SkillColor(req, herbSkill)
    skillLine = skillLine .. (c == "red" and "  ·  |cffeb5c4cskill too low|r"
      or c == "grey" and "  ·  no more skill-ups"
      or "  ·  |cff8cdb7agives skill-ups|r")
  end
  if NW.IsHidden(entry[1]) then skillLine = skillLine .. "  ·  hidden on your map" end
  hSkill:SetText(skillLine)
  hTip:SetText(entry[2])

  local rows = rankZones(entry)
  for i, r in ipairs(zoneRows) do
    local row = rows[i]
    r.row = row
    if row then
      local star = row.recommended and "|cffe8c46a*|r " or "   "
      local stats
      if row.rate then
        stats = ("|cff9be08a%d spots|r  ·  %s loop  ·  |cffffffff%.1f/min|r"):format(row.count, fmtTime(row.loop / NW.MOUNT_YPS), row.rate)
      elseif row.missing then
        stats = "|cff6f6f74not on your client's maps|r"
      elseif row.count > 0 then
        stats = ("|cff9be08a%d spot%s|r  ·  too few to rank"):format(row.count, row.count == 1 and "" or "s")
      else
        stats = "|cff6f6f74no spots saved|r"
      end
      r.line1:SetText(star .. row.name .. "    " .. stats)
      r.line2:SetText("   " .. (row.note or (row.recommended and "" or "Found in your data; not in the guides")))
      r.build:SetEnabled(row.mapID ~= nil and row.count > 0)
      r:Show()
    else
      r:Hide()
    end
  end
  local extra = #rows - ROWS
  moreText:SetText((extra > 0 and ("+%d more zones with fewer spots.   "):format(extra) or "")
    .. "|cffe8c46a*|r recommended by farming guides")
  local pv = rows[1]
  for _, row in ipairs(rows) do if previewID and row.mapID == previewID then pv = row end end
  drawPreview(pv, entry[1])
end

function NW.ToggleGuide() NW.ToggleWindow("guide") end

-- Open the guide on one herb (from the Professions tab)
function NW.GuideSelectHerb(name)
  selectedHerb = name
  if NW.window:IsShown() then NW.ShowTab("guide") else NW.db.settings.lastTab = "guide"; NW.window:Show() end
end
