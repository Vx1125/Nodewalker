local ADDON, NW = ...

local C = NW.COLORS
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ARROW = "Interface\\Minimap\\MinimapArrow"

local overlay = CreateFrame("Frame", "NodewalkerOverlay", UIParent)
overlay:SetAllPoints(UIParent)
overlay:SetFrameStrata("BACKGROUND")
overlay:SetFrameLevel(1)
overlay:EnableMouse(false)
overlay:Hide()
NW.overlay = overlay

-- A window in the middle of the screen, like Diablo II's or Path of Exile's
-- map overlay; the map centres on you and its edges fade out.
local EDGE_MASK = "Interface\\AddOns\\Nodewalker\\Media\\EdgeMask"
local view = CreateFrame("Frame", nil, overlay)
view:SetPoint("CENTER", overlay, "CENTER")
view:SetClipsChildren(true)

-- the borrowed minimap's saved state (see "Live herb and ore dots" below)
local live = { active = false }

local function sizeView()
  local f = (NW.db and NW.db.settings.overlaySize) or 0.5
  view:SetSize(overlay:GetWidth() * f, overlay:GetHeight() * math.min(1, f * 1.25))
end
NW.SizeOverlay = sizeView

-- One soft-edged mask per terrain frame (a mask works on its own frame's textures)
local function edgeMask(frame)
  local m = frame:CreateMaskTexture()
  m:SetTexture(EDGE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(view)
  return m
end

-- How far into the faded edge a point is: 1 inside, falling to 0 at the edge
local function edgeFade(vx, vy)
  local u = math.abs(vx) / (view:GetWidth() / 2)
  local v = math.abs(vy) / (view:GetHeight() / 2)
  local r = (u ^ 4 + v ^ 4) ^ 0.25
  if r <= 0.78 then return 1 end
  if r >= 1 then return 0 end
  local a = (1 - r) / 0.22
  return a * a * (3 - 2 * a)
end

-- The zone's map art, scaled to yards, slid under the player
local canvas = CreateFrame("Frame", nil, view)
local canvasMask = edgeMask(canvas)
local tiles = {}
local tileMapID, tileScale, tileTint

-- Route lines and markers draw above the map art
local lineLayer = CreateFrame("Frame", nil, view)
lineLayer:SetAllPoints(view)
lineLayer:SetFrameLevel(view:GetFrameLevel() + 5)
local lineMask = edgeMask(lineLayer)
local markerLayer = CreateFrame("Frame", nil, view)
markerLayer:SetAllPoints(view)
markerLayer:SetFrameLevel(view:GetFrameLevel() + 10)

-- Icons and route lines hang off this point. Between rebuilds only the point
-- moves, so the map glides without every icon being placed again each frame.
local pan = CreateFrame("Frame", nil, markerLayer)
pan:SetSize(1, 1)
pan:SetPoint("CENTER", view, "CENTER")

local arrow = markerLayer:CreateTexture(nil, "OVERLAY", nil, 7)
arrow:SetTexture(ARROW)
arrow:SetSize(32, 32)
arrow:SetPoint("CENTER", view, "CENTER")

local nextLabel = CreateFrame("Frame", nil, markerLayer, "BackdropTemplate")
nextLabel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
nextLabel:SetBackdropColor(0.05, 0.055, 0.07, 0.8)
nextLabel:SetBackdropBorderColor(1, 0.84, 0.47, 0.55)
nextLabel:SetFrameLevel(markerLayer:GetFrameLevel() + 5)
nextLabel.title = nextLabel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
nextLabel.title:SetPoint("TOPLEFT", 10, -6)
nextLabel.title:SetTextColor(unpack(C.next))
nextLabel.sub = nextLabel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
nextLabel.sub:SetPoint("TOPLEFT", nextLabel.title, "BOTTOMLEFT", 0, -2)
nextLabel:Hide()

------------------------------------------------------------------------
-- Terrain colour
------------------------------------------------------------------------
local TINTS = {
  gold = { 0.95, 0.80, 0.45 },
  blue = { 0.55, 0.80, 0.95 },
}

local function applyTint(t, tint)
  if tint == "natural" then
    t:SetDesaturated(false)
    t:SetVertexColor(1, 1, 1)
  else
    local c = TINTS[tint] or TINTS.gold
    t:SetDesaturated(true)
    t:SetVertexColor(c[1], c[2], c[3])
  end
end

------------------------------------------------------------------------
-- Terrain source 1: the game's minimap tiles (detailed, top-down terrain)
--
-- Outdoor maps are a 64 x 64 grid of 533.33-yard terrain tiles with one
-- minimap picture each. OpenMap's table (OpenMapData\Minimap.lua) gives the
-- game's file ID for every tile on WoW Forever; for a continent it doesn't
-- cover we try the old path World\Minimaps\<folder>\mapXX_YY.
-- (XX = column, west to east; YY = row, north to south.)
------------------------------------------------------------------------
local TILE = 1600 / 3 -- 533.33 yards
local CONTINENT_DIRS = { [0] = "Azeroth", [1] = "Kalimdor" }

local terrain = CreateFrame("Frame", nil, view)
terrain:SetAllPoints(view)
local terrainMask = edgeMask(terrain)
local mmTiles = {}   -- [key] = texture
local mmMissing = {} -- [path] = true when the client has no such file

local function hideMinimapTiles()
  for _, t in pairs(mmTiles) do t:Hide() end
end

-- continent ID and world position (x = north, y = west, in yards), or nil
local function worldPos(mapID, px, py)
  local ok, continentID, wpos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(px, py))
  if not ok or not wpos then return nil end
  return continentID, wpos.x, wpos.y
end

local function tileSource(continentID, col, row)
  local list = NW.MapMinimap and NW.MapMinimap[continentID]
  if list then return list[col * 64 + row] end -- nil: no land there
  local dir = NW.db.settings.continentDirs[continentID] or CONTINENT_DIRS[continentID]
  if dir then return ("World\\Minimaps\\%s\\map%02d_%02d"):format(dir, col, row) end
end

-- Draw the tiles around the player. Returns false when this place has no
-- minimap terrain we can use, so the caller falls back to the zone map.
local function drawMinimapTiles(continentID, wx, wy, scale, tint)
  local halfWYd = view:GetWidth() / 2 / scale + TILE
  local halfHYd = view:GetHeight() / 2 / scale + TILE
  local colMin = math.floor(32 - (wy + halfWYd) / TILE)
  local colMax = math.floor(32 - (wy - halfWYd) / TILE)
  local rowMin = math.floor(32 - (wx + halfHYd) / TILE)
  local rowMax = math.floor(32 - (wx - halfHYd) / TILE)

  local used, shown = {}, 0
  local size = TILE * scale
  for col = math.max(0, colMin), math.min(63, colMax) do
    for row = math.max(0, rowMin), math.min(63, rowMax) do
      local src = tileSource(continentID, col, row)
      if src and not mmMissing[src] then
        local key = col .. "_" .. row
        local t = mmTiles[key]
        if not t or t.src ~= src then
          if not t then
            t = terrain:CreateTexture(nil, "BACKGROUND")
            t:AddMaskTexture(terrainMask)
          end
          mmTiles[key] = t
          t.src = src
          if t:SetTexture(src, nil, nil, "TRILINEAR") == false then
            mmMissing[src] = true
            t.src = nil
          end
          t.tint = nil
        end
        if t.src then
          if t.tint ~= tint then applyTint(t, tint); t.tint = tint end
          -- the tile's north-west corner, relative to you, in UI units
          local sx = (wy - (32 - col) * TILE) * scale
          local sy = ((32 - row) * TILE - wx) * scale
          t:ClearAllPoints()
          t:SetSize(size, size)
          t:SetPoint("TOPLEFT", view, "CENTER", sx, sy)
          t:Show()
          used[key] = true
          shown = shown + 1
        end
      end
    end
  end
  for key, t in pairs(mmTiles) do
    if not used[key] then t:Hide() end
  end
  return shown > 0
end

------------------------------------------------------------------------
-- Indoors: caves, mines and the underground cities, as the game's minimap
-- draws them inside. OpenMap's table (OpenMapData\CaveMinimap.lua) lists each
-- place's box and its pictures: file ID, centre x, y, side (yards), rotation,
-- and texture coordinates, lowest floor first.
------------------------------------------------------------------------
local indoor = CreateFrame("Frame", nil, view)
indoor:SetAllPoints(view)
local indoorMask = edgeMask(indoor)
local placeTex = {}   -- [place key] = { textures }
local shownPlace

local function hideIndoor()
  if shownPlace and placeTex[shownPlace] then
    for _, t in ipairs(placeTex[shownPlace]) do t:Hide() end
  end
  shownPlace = nil
end

local function placeTextures(key, c, tint)
  local list = placeTex[key]
  if list then return list end
  list = {}
  local p = c[6]
  local n = math.floor(#p / 7)
  for i = 1, n do
    local j = (i - 1) * 7
    local fid = p[j + 1]
    if type(fid) == "number" then -- (OpenMap's own edited pictures are strings: skipped)
      local t = indoor:CreateTexture(nil, "ARTWORK", nil, math.min(7, math.floor((i - 1) * 16 / n) - 8))
      t:AddMaskTexture(indoorMask)
      t:SetTexture(fid, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR")
      t:SetTexCoord(0, p[j + 6], p[j + 7], 1)
      t:SetRotation(p[j + 5])
      t.cx, t.cy, t.side = p[j + 2], p[j + 3], p[j + 4]
      list[#list + 1] = t
    end
  end
  placeTex[key] = list
  return list
end

-- The place you're in: the underground city for this map, else the cave
-- whose box holds you.
local lastCave
local function findPlace(mapID, continentID, wx, wy)
  local city = NW.MapCityMinimap and NW.MapCityMinimap[mapID]
  if city then return "city" .. mapID, city end
  local caves = NW.MapCaveMinimap
  if not caves then return nil end
  local function inside(c)
    return c[1] == continentID and wx >= c[2] and wx <= c[4] and wy >= c[3] and wy <= c[5]
  end
  if lastCave and caves[lastCave] and inside(caves[lastCave]) then return "cave" .. lastCave, caves[lastCave] end
  for i, c in ipairs(caves) do
    if inside(c) then lastCave = i; return "cave" .. i, c end
  end
  return nil
end

local function drawIndoor(mapID, continentID, pwx, pwy, wx, wy, scale, tint)
  local key, c = findPlace(mapID, continentID, pwx, pwy)
  if not key then hideIndoor(); return false end
  if shownPlace ~= key then hideIndoor() end
  local list = placeTextures(key, c, tint)
  if #list == 0 then return false end
  for _, t in ipairs(list) do
    if t.tint ~= tint then applyTint(t, tint); t.tint = tint end
    local size = t.side * scale
    t:ClearAllPoints()
    t:SetSize(size, size)
    t:SetPoint("CENTER", view, "CENTER", (wy - t.cy) * scale, (t.cx - wx) * scale)
    t:Show()
  end
  shownPlace = key
  NW.indoorPlace = key
  return true
end

-- /nw terrain: what the overlay is using here, to help with new zones
function NW.TerrainReport()
  local mapID, px, py = NW.PlayerPos()
  if not mapID then NW.Print("Can't read your position here.") return end
  local continentID, wx, wy = worldPos(mapID, px, py)
  if not continentID then NW.Print("No world position for this map; using the zone map.") return end
  local col = math.floor(32 - wy / TILE)
  local row = math.floor(32 - wx / TILE)
  local hasTable = NW.MapMinimap and NW.MapMinimap[continentID] and "yes" or "no"
  local placeKey = findPlace(mapID, continentID, wx, wy)
  NW.Print(("Map %d, continent %s, tile %02d_%02d (file ID table: %s). Indoors: %s. Cave or city here: %s. Drawing: %s."):format(
    mapID, tostring(continentID), col, row, hasTable, IsIndoors() and "yes" or "no",
    placeKey or "none", NW.terrainInUse or "nothing yet"))
  if hasTable == "no" and not (NW.db.settings.continentDirs[continentID] or CONTINENT_DIRS[continentID]) then
    NW.Print(("No tiles known for continent %s. If you know its minimap folder: /nw continent %s <folder>."):format(tostring(continentID), tostring(continentID)))
  end
end

------------------------------------------------------------------------
-- Terrain source 2: the zone's world-map art (fallback)
------------------------------------------------------------------------
local function clearTiles()
  for _, t in ipairs(tiles) do t:Hide() end
end

local function buildTiles(mapID, W, H)
  local s = NW.db.settings
  if tileMapID == mapID and tileScale == W and tileTint == s.tint then return end
  tileMapID, tileScale, tileTint = mapID, W, s.tint
  clearTiles()
  canvas:SetSize(W, H)
  if s.tint == "none" then return end
  local layers = C_Map.GetMapArtLayers(mapID)
  local layer = layers and layers[1]
  if not layer then return end
  local textures = C_Map.GetMapArtLayerTextures(mapID, 1)
  if not textures then return end
  local cols = math.ceil(layer.layerWidth / layer.tileWidth)
  local tw = W * layer.tileWidth / layer.layerWidth
  local th = H * layer.tileHeight / layer.layerHeight
  for i, fileID in ipairs(textures) do
    local t = tiles[i]
    if not t then
      t = canvas:CreateTexture(nil, "BACKGROUND")
      t:AddMaskTexture(canvasMask)
      tiles[i] = t
    end
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    t:ClearAllPoints()
    t:SetSize(tw, th)
    t:SetPoint("TOPLEFT", canvas, "TOPLEFT", col * tw, -row * th)
    t:SetTexture(fileID)
    applyTint(t, s.tint)
    t:SetAlpha(0.7)
    t:Show()
  end
end

------------------------------------------------------------------------
-- Pools: node markers and route lines
------------------------------------------------------------------------
local markers, markerCount = {}, 0
local lines, lineCount = {}, 0

local nodeShowKind = {}
-- Tooltip lines for a known spot, built when you hover it
local SOURCES = { me = "you gathered it here", gm2 = "your GatherMate2", gm2data = "GatherMate2 data (Wowhead)", seen = "spotted on your minimap" }
local SKILL_RGB = { red = { 1, 0.2, 0.2 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 } }
local function nodeLines(info)
  local n, lines = info.n, {}
  local seenAgo = info.seenAgo
  if seenAgo then
    lines[#lines + 1] = { ("Seen up %s ago"):format(seenAgo < 60 and "under a minute" or (math.floor(seenAgo / 60) .. " min")), 0.55, 1, 0.4 }
  else
    lines[#lines + 1] = { "Known spot, not confirmed", 0.7, 0.7, 0.7 }
  end
  local req, skill = NW.RequiredSkill(n.name), NW.GetSkill(n.kind)
  if req and skill then
    local rgb = SKILL_RGB[NW.SkillColor(req, skill)]
    lines[#lines + 1] = { ("Needs %d (you: %d)"):format(req, skill), rgb and rgb[1], rgb and rgb[2], rgb and rgb[3] }
  end
  local mapID, px, py = NW.PlayerPos()
  local dist = px and mapID == info.mapID and NW.Yards(info.mapID, px, py, n.x, n.y)
  if dist then lines[#lines + 1] = { ("%d yd"):format(math.floor(dist)), 0.85, 0.81, 0.73 } end
  lines[#lines + 1] = { "From: " .. (SOURCES[n.src] or n.src or "?"), 0.5, 0.5, 0.5 }
  return lines
end

local function getMarker()
  markerCount = markerCount + 1
  local m = markers[markerCount]
  if not m then
    m = CreateFrame("Button", nil, markerLayer)
    m.edge = m:CreateTexture(nil, "ARTWORK", nil, 1)
    m.edge:SetAllPoints()
    m.fill = m:CreateTexture(nil, "ARTWORK", nil, 2)
    m.fill:SetPoint("TOPLEFT", 2, -2)
    m.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    m.icon = m:CreateTexture(nil, "ARTWORK", nil, 3)
    m.icon:SetPoint("TOPLEFT", 2, -2)
    m.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    m.glow = m:CreateTexture(nil, "BACKGROUND")
    m.glow:SetPoint("TOPLEFT", -6, 6)
    m.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    for _, tex in ipairs({ m.edge, m.fill, m.icon, m.glow }) do
      local mask = m:CreateMaskTexture()
      mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(tex)
      tex:AddMaskTexture(mask)
    end
    m:SetScript("OnEnter", function(self)
      if not self.info then return end
      if self.info.n and not self.info.lines then self.info.lines = nodeLines(self.info) end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.info.title, 1, 0.9, 0.66)
      if self.info.sub then GameTooltip:AddLine(self.info.sub, 0.85, 0.81, 0.73) end
      for _, l in ipairs(self.info.lines or {}) do
        GameTooltip:AddLine(l[1], l[2] or 0.85, l[3] or 0.81, l[4] or 0.73, true)
      end
      if self.info.stop then GameTooltip:AddLine("Ctrl-click: make this the next stop", 0.6, 0.6, 0.6) end
      if self.info.node then GameTooltip:AddLine("Ctrl-right-click: hide all " .. self.info.node, 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    m:SetScript("OnClick", function(self, button)
      local info = self.info
      if not info then return end
      if button == "RightButton" then
        if info.node then
          NW.SetHidden(info.node, true)
        end
      elseif info.stop and NW.progress[info.mapID] then
        NW.progress[info.mapID].index = info.stop
      end
    end)
    markers[markerCount] = m
  end
  m:Show()
  return m
end

local function styleMarker(m, kind, size, state, icon)
  m:SetSize(size, size)
  if icon then
    m.icon:SetTexture(icon)
    m.icon:SetDesaturated(state == "picked")
    m.icon:Show()
    m.fill:Hide()
  else
    m.icon:Hide()
    m.fill:Show()
  end
  local fill, edge = C.herbFill, C.herbEdge
  if kind == "ore" then fill, edge = C.oreFill, C.oreEdge end
  if kind == "mixed" then fill, edge = C.oreFill, C.herbEdge end
  if state == "picked" then fill, edge = C.picked, C.picked end
  m.fill:SetColorTexture(fill[1], fill[2], fill[3], 1)
  m.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
  if state == "next" then
    m.edge:SetColorTexture(C.next[1], C.next[2], C.next[3], 1)
    m.glow:SetColorTexture(1, 0.84, 0.47, 0.35)
    m.glow:Show()
  elseif state == "seen" then
    m.edge:SetColorTexture(0.75, 1, 0.55, 1)
    m.glow:SetColorTexture(0.55, 1, 0.4, 0.4)
    m.glow:Show()
  else
    m.glow:Hide()
  end
  m:SetAlpha(state == "picked" and 0.55 or (state == "far" and 0.6 or 1))
end

local function getLine()
  lineCount = lineCount + 1
  local l = lines[lineCount]
  if not l then
    l = lineLayer:CreateLine(nil, "ARTWORK")
    l:SetThickness(3)
    if l.AddMaskTexture then pcall(l.AddMaskTexture, l, lineMask) end
    lines[lineCount] = l
  end
  l:SetColorTexture(C.route[1], C.route[2], C.route[3], 0.95)
  l:Show()
  return l
end

-- Markers are reused frame to frame rather than hidden and shown again,
-- so a tooltip you're hovering doesn't flicker.
local function resetPools()
  markerCount, lineCount = 0, 0
end

local function finishPools()
  for i = markerCount + 1, #markers do
    local m = markers[i]
    if m:IsShown() then m:Hide(); m.info = nil end
  end
  for i = lineCount + 1, #lines do lines[i]:Hide() end
end

local tipRefresh = 0
local function refreshTooltip()
  local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
  if not owner or not owner.info or not owner:IsShown() then return end
  local now = GetTime()
  if now - tipRefresh < 0.5 then return end
  tipRefresh = now
  local fn = owner:GetScript("OnEnter")
  if fn then fn(owner) end
end

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------
local stopNameCache = {}

local function stopName(mapID, st)
  local key = mapID .. ":" .. st.x .. ":" .. st.y
  local c = stopNameCache[key]
  if c then return c[1], c[2] end
  local best, bestD
  for _, n in ipairs(NW.db.nodes[mapID] or {}) do
    local d = NW.Yards(mapID, n.x, n.y, st.x, st.y)
    if d and (not bestD or d < bestD) then best, bestD = n, d end
  end
  local base = best and best.name or (st.kind == "ore" and "Ore" or "Herb")
  local label = base
  if (st.count or 1) > 1 then label = label .. " +" .. (st.count - 1) end
  stopNameCache[key] = { label, base }
  return label, base
end

-- Hover works without Alt and lets clicks through to the game; Alt also
-- lets you click a stop.
-- With live dots, hovering is the minimap's job: the game shows a tooltip
-- only when a real herb or vein is under the cursor. Our icons then take
-- the mouse only while Alt is held (Alt-click a route stop). Without live
-- dots, our icons show their own details on hover.
local function interact(rebuilt)
  local alt = IsAltKeyDown()
  if live.active then
    if live.motionOnly then
      -- the minimap only takes the mouse while Alt is held, so the middle
      -- of the screen stays free for clicking herbs in the world
      -- (unless "tooltips without Alt" is on, at the cost of world clicks)
      local want = (alt or NW.db.settings.liveHoverNoAlt) and not IsControlKeyDown()
      if live.altState ~= want then
        pcall(Minimap.SetMouseMotionEnabled, Minimap, want)
        live.altState = want
      end
    elseif Minimap:IsMouseEnabled() ~= alt then
      -- fallback for clients without hover-only mouse: minimap hover with Alt
      Minimap:EnableMouse(alt)
    end
  end
  local hover = NW.db.settings.hoverTooltips and not live.active
  -- our icons: Ctrl (or Alt when live dots are off) to see details or pick a stop
  local pick = IsControlKeyDown() or (alt and not live.active)
  if not rebuilt and hover == live.lastHover and pick == live.lastPick then return end
  live.lastHover, live.lastPick = hover, pick
  for i = 1, markerCount do
    local m = markers[i]
    if m.SetMouseClickEnabled and m.SetMouseMotionEnabled then
      m:SetMouseMotionEnabled(hover or pick)
      m:SetMouseClickEnabled(pick)
    else
      m:EnableMouse(pick)
    end
  end
end

------------------------------------------------------------------------
-- The map scrolls smoothly under you, like the minimap: you stay in the
-- middle of the window (north up) and your arrow turns as you do.
------------------------------------------------------------------------
function NW.RecentreOverlay() end -- (kept for older callers; nothing to do)

------------------------------------------------------------------------
-- Live herb and ore dots: the real minimap, borrowed.
--
-- Addons can't read the minimap's tracking dots, but the game keeps
-- drawing them when the minimap itself is invisible (alpha 0). So, like
-- FarmHud, we move the real minimap into the middle of our window, size it
-- to match our map scale, hide its terrain and its buttons, and the game
-- shows the herbs that are actually up. Everything goes back as it was
-- when the overlay hides (and on logout or /reload).
------------------------------------------------------------------------
local MM_OUTDOOR = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local MM_INDOOR = { 300, 240, 180, 120, 80, 50 }
local BLIP_SCALE = 1.4 -- bigger minimap dots

local function liveDiameter()
  local z = (Minimap:GetZoom() or 0) + 1
  return (IsIndoors() and MM_INDOOR or MM_OUTDOOR)[z]
end

-- The LFG eye, battleground and other queue buttons live on the minimap. While
-- the minimap is borrowed they'd end up in the middle of the screen, so they
-- move to where they were on screen and stay usable there.
local function isQueueButton(c)
  local name = c.GetName and c:GetName()
  if not name then return false end
  return name:find("LFG") or name:find("Queue") or name:find("Battlefield")
    or name:find("PvP") or name:find("Battleground") or false
end

local function moveOut(c)
  local m = { frame = c, parent = c:GetParent(), points = {},
              strata = c:GetFrameStrata(), level = c:GetFrameLevel() }
  for i = 1, c:GetNumPoints() do m.points[i] = { c:GetPoint(i) } end
  local cx, cy = c:GetCenter()
  local eff = c:GetEffectiveScale()
  local ok = pcall(function()
    c:SetParent(UIParent)
    c:ClearAllPoints()
    if cx then
      local k = eff / c:GetEffectiveScale()
      c:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * k, cy * k)
    else
      c:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -150, -150)
    end
    c:SetFrameStrata("MEDIUM")
    c:SetFrameLevel(20)
  end)
  if ok then live.moved[#live.moved + 1] = m end
end

-- Anything else the game or an addon shows on the minimap later stays hidden.
local function sweepChildren()
  for _, c in ipairs({ Minimap:GetChildren() }) do
    if isQueueButton(c) then
      moveOut(c)
    elseif c:IsShown() and not (c:IsProtected() and InCombatLockdown()) then
      c:Hide()
      if not live.hidden[c] then
        live.hidden[c] = true
        live.children[#live.children + 1] = c
      end
    end
  end
end

local function startLive()
  if live.active or not Minimap then return end
  live.parent = Minimap:GetParent()
  live.points = {}
  for i = 1, Minimap:GetNumPoints() do live.points[i] = { Minimap:GetPoint(i) } end
  live.w, live.h = Minimap:GetSize()
  live.scale, live.alpha, live.zoom = Minimap:GetScale(), Minimap:GetAlpha(), Minimap:GetZoom()
  live.strata, live.level = Minimap:GetFrameStrata(), Minimap:GetFrameLevel()
  live.mouse, live.wheel = Minimap:IsMouseEnabled(), Minimap:IsMouseWheelEnabled()
  live.rotate = GetCVar and GetCVar("rotateMinimap")
  live.children, live.hidden, live.moved = {}, {}, {}
  for _, c in ipairs({ Minimap:GetChildren() }) do
    if isQueueButton(c) then
      moveOut(c)
    elseif c:IsShown() and not (c:IsProtected() and InCombatLockdown()) then
      c:Hide(); live.children[#live.children + 1] = c; live.hidden[c] = true
    end
  end
  live.sweepAt = 0
  live.cluster = MinimapCluster and MinimapCluster:IsShown()
  -- where the minimap normally sits, for our own button
  local hx, hy = Minimap:GetCenter()
  if hx then
    local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    NW.minimapHome = { hx * k, hy * k, Minimap:GetWidth() / 2 * k }
  end

  Minimap:SetParent(view)
  Minimap:SetFrameStrata(view:GetFrameStrata())
  Minimap:SetFrameLevel(markerLayer:GetFrameLevel() + 20) -- live dots above our icons (it's invisible otherwise)
  Minimap:ClearAllPoints()
  Minimap:SetPoint("CENTER", view, "CENTER")
  Minimap:SetScale(BLIP_SCALE)
  pcall(Minimap.SetZoom, Minimap, 0)
  Minimap:SetAlpha(0)
  Minimap:EnableMouse(false)
  Minimap:EnableMouseWheel(false)
  -- hover-only: the game's dot tooltips work, clicks pass through to the world
  live.motionOnly = false
  if Minimap.SetMouseMotionEnabled and Minimap.SetMouseClickEnabled then
    live.motionOnly = pcall(function()
      Minimap:SetMouseMotionEnabled(false)
      Minimap:SetMouseClickEnabled(false)
    end)
  end
  pcall(Minimap.SetPlayerTexture, Minimap, "")
  if live.rotate == "1" then SetCVar("rotateMinimap", "0") end -- our map is north-up
  if MinimapCluster then MinimapCluster:Hide() end
  live.size = nil
  live.altState = nil
  live.active = true
end

local function stopLive()
  if not live.active then return end
  live.active = false
  Minimap:SetParent(live.parent)
  Minimap:ClearAllPoints()
  for _, p in ipairs(live.points) do Minimap:SetPoint(unpack(p)) end
  Minimap:SetScale(live.scale)
  Minimap:SetSize(live.w, live.h)
  Minimap:SetFrameStrata(live.strata)
  Minimap:SetFrameLevel(live.level)
  pcall(Minimap.SetZoom, Minimap, live.zoom or 0)
  Minimap:SetAlpha(live.alpha or 1)
  Minimap:EnableMouse(live.mouse)
  Minimap:EnableMouseWheel(live.wheel)
  pcall(Minimap.SetPlayerTexture, Minimap, "Interface\\Minimap\\MinimapArrow")
  if live.rotate == "1" then SetCVar("rotateMinimap", "1") end
  for _, c in ipairs(live.children) do c:Show() end
  for _, m in ipairs(live.moved) do
    local c = m.frame
    pcall(function()
      c:SetParent(m.parent)
      c:ClearAllPoints()
      for _, p in ipairs(m.points) do c:SetPoint(unpack(p)) end
      c:SetFrameStrata(m.strata)
      c:SetFrameLevel(m.level)
    end)
  end
  live.moved = {}
  if MinimapCluster and live.cluster then MinimapCluster:Show() end
end

function NW.IsLive() return live.active end

function NW.SetLive(on)
  if on then startLive() else stopLive() end
end

-- Keep the borrowed minimap sized to our scale. Returns its radius in yards.
local function updateLive(scale)
  if not live.active then return nil end
  local now = GetTime()
  if now >= (live.sweepAt or 0) then
    live.sweepAt = now + 0.5
    sweepChildren()
  end
  local diam = liveDiameter()
  if not diam then return nil end
  local size = diam * scale / BLIP_SCALE
  if live.size ~= size then
    Minimap:SetSize(size, size)
    live.size = size
  end
  return diam / 2
end

NW.On("PLAYER_LOGOUT", stopLive)

-- Other addons (GatherMate2, HandyNotes, quest helpers...) put invisible pins
-- on the minimap. While it's borrowed, their tooltips would claim a herb is
-- there when it may not be, so only the minimap's own live-dot tooltip shows.
local function ownedByMinimapPin(owner)
  local f = owner
  for _ = 1, 6 do
    if not f or not f.GetParent then return false end
    local p = f:GetParent()
    if p == Minimap then return true end
    f = p
  end
  return false
end

GameTooltip:HookScript("OnShow", function(tip)
  if not live.active then return end
  local owner = tip:GetOwner()
  if owner and owner ~= Minimap and ownedByMinimapPin(owner) then tip:Hide() end
end)

------------------------------------------------------------------------
-- Range ring: the edge of the minimap's tracking range around you, i.e.
-- where live herb dots can appear.
------------------------------------------------------------------------
local RING_SEGMENTS = 96
local ringLayer = CreateFrame("Frame", nil, view)
ringLayer:SetAllPoints(view)
ringLayer:SetFrameLevel(lineLayer:GetFrameLevel() + 1)
local ringLines, ringRadius = {}, nil

local function drawRing(radiusPx)
  if not radiusPx then
    for _, l in ipairs(ringLines) do l:Hide() end
    ringRadius = nil
    return
  end
  if ringRadius and math.abs(ringRadius - radiusPx) < 0.5 then return end
  ringRadius = radiusPx
  for i = 1, RING_SEGMENTS do
    local l = ringLines[i]
    if not l then
      l = ringLayer:CreateLine(nil, "ARTWORK")
      l:SetThickness(2)
      l:SetColorTexture(0.75, 1, 0.6, 0.55)
      ringLines[i] = l
    end
    local a1 = (i - 1) / RING_SEGMENTS * 2 * math.pi
    local a2 = i / RING_SEGMENTS * 2 * math.pi
    l:SetStartPoint("CENTER", view, math.cos(a1) * radiusPx, math.sin(a1) * radiusPx)
    l:SetEndPoint("CENTER", view, math.cos(a2) * radiusPx, math.sin(a2) * radiusPx)
    l:Show()
  end
end

-- Zoom eases out while you're mounted (if asked) and back in on foot
local zoomNow, frameDt = 1, 0
local function zoom(s)
  local target = (s.mountZoom and IsMounted and IsMounted()) and 0.7 or 1
  if zoomNow ~= target and not InCombatLockdown() then
    zoomNow = zoomNow + (target - zoomNow) * math.min(1, frameDt * 4)
    if math.abs(target - zoomNow) < 0.004 then zoomNow = target end
  end
  return zoomNow
end

local built = {}   -- where you were when the icons were last placed
local lastBuild = 0
local NEAR_YARDS = 100

-- Returns nil with no map to draw, false for a glide frame, true after a rebuild
local function drawInner(force)
  local mapID, px, py = NW.PlayerPos()
  if not mapID then return end
  local w, h = NW.MapSize(mapID)
  if not w then return end
  local s = NW.db.settings
  local scale = s.scale * zoom(s)
  local W, H = w * scale, h * scale
  local cx, cy = px, py -- the window is centred on you
  local liveRadius = updateLive(scale) -- live dots cover this many yards around you
  if s.showRangeRing then
    local r = liveRadius or ((liveDiameter() or 0) / 2)
    drawRing(r > 0 and r * scale or nil)
  else
    drawRing(nil)
  end
  -- Terrain: a cave or underground city when you're inside one, the
  -- minimap tiles outdoors, and the zone's map art where neither works.
  local used = "none"
  if s.tint ~= "none" and s.terrainSource == "minimap" then
    local continentID, pwx, pwy = worldPos(mapID, px, py)
    local _, wx, wy = worldPos(mapID, cx, cy)
    if continentID and wx then
      if IsIndoors() and drawIndoor(mapID, continentID, pwx, pwy, wx, wy, scale, s.tint) then
        used = "cave or city"
      else
        hideIndoor()
      end
      if used == "none" and not IsIndoors() and drawMinimapTiles(continentID, wx, wy, scale, s.tint) then
        used = "minimap tiles"
      end
    end
  end
  if used ~= "minimap tiles" then hideMinimapTiles() end
  if used == "none" then hideIndoor() end
  if used == "none" and s.tint ~= "none" then used = "zone map" end
  NW.terrainInUse = used
  if used ~= "zone map" then
    canvas:Hide()
  else
    canvas:Show()
    buildTiles(mapID, W, H)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", view, "CENTER", -cx * W, cy * H)
  end

  arrow:SetRotation(GetPlayerFacing() or 0)
  local now = GetTime()
  if not force and built.mapID == mapID and built.W == W and now - lastBuild < 0.15 then
    -- glide: slide everything by how far you've moved since the last rebuild
    pan:SetPoint("CENTER", view, "CENTER", (built.px - px) * W, (py - built.py) * H)
    return false
  end
  lastBuild = now
  built.mapID, built.px, built.py, built.W = mapID, px, py, W
  pan:SetPoint("CENTER", view, "CENTER", 0, 0)
  resetPools()
  local near = false
  local nearPx = NEAR_YARDS * scale

  local halfW, halfH = view:GetWidth() / 2 + 20, view:GetHeight() / 2 + 20
  local function toView(x, y) return (x - cx) * W, -(y - cy) * H end
  local function onScreen(vx, vy) return math.abs(vx) < halfW and math.abs(vy) < halfH end

  -- Saved nodes nearby (small), so you see what's around even off-route
  local route = NW.db.routes[mapID]
  local showKind = nodeShowKind
  showKind.herb, showKind.ore = NW.ShowKind("herb", s), NW.ShowKind("ore", s)
  local hasRoute = NW.db.routes[mapID] and #NW.db.routes[mapID].stops > 1
  for i, n in ipairs(NW.db.nodes[mapID] or {}) do
    local vx, vy = toView(n.x, n.y)
    -- cheap tests first: most saved spots are off screen
    if onScreen(vx, vy) and showKind[n.kind] and not NW.IsHidden(n.name) then
      local seenAgo = NW.SeenAgo(mapID, i)
      local pickedAgo = not seenAgo and NW.PickedAgo(mapID, i)
      -- With live dots on, the game shows what's really up near you, so known
      -- spots are only drawn beyond the live circle (and only if asked).
      local hideKnown
      if liveRadius then
        local d = NW.Yards(mapID, px, py, n.x, n.y)
        if d and d < liveRadius then hideKnown = hasRoute -- route stops stand in for them
        else hideKnown = not s.showKnownSpots end
      end
      if not pickedAgo and (seenAgo or not s.onlyConfirmed) and vx * vx + vy * vy < nearPx * nearPx then near = true end
      if not pickedAgo and not hideKnown and (seenAgo or not s.onlyConfirmed) then
        local m = getMarker()
        styleMarker(m, n.kind, seenAgo and 24 or 20, seenAgo and "seen" or "far", NW.NodeIcon(n.name, n.kind))
        if not seenAgo then m:SetAlpha(s.fadedAlpha or 0.35) end
        m:SetAlpha(m:GetAlpha() * edgeFade(vx, vy))
        m:SetPoint("CENTER", pan, "CENTER", vx, vy)
        local info = m.nodeInfo or {}
        m.nodeInfo = info
        info.title, info.node, info.n, info.mapID, info.seenAgo, info.lines = n.name, n.name, n, mapID, seenAgo, nil
        info.sub, info.stop = nil, nil
        m.info = info
      end
    end
  end

  -- Route: lines first, then stops
  local nextIndex
  if route and #route.stops > 1 then
    NW.UpdateProgress(mapID, px, py)
    local _, idx = NW.NextStop(mapID, px, py)
    nextIndex = idx
    local stops = route.stops
    for i = 1, #stops do
      local a, b = stops[i], stops[(i % #stops) + 1]
      local ax, ay = toView(a.x, a.y)
      local bx, by = toView(b.x, b.y)
      if onScreen(ax, ay) or onScreen(bx, by) then
        local l = getLine()
        l:SetStartPoint("CENTER", pan, ax, ay)
        l:SetEndPoint("CENTER", pan, bx, by)
      end
    end
    local prog = NW.progress[mapID]
    local respawn = s.respawnMinutes * 60
    local now = GetTime()
    for i, st in ipairs(stops) do
      local vx, vy = toView(st.x, st.y)
      local label, base = stopName(mapID, st)
      if onScreen(vx, vy) and not NW.IsHidden(base) then
        local state = "stop"
        local seen = prog and prog.visited[i]
        if seen and now - seen < respawn then state = "picked" end
        if i == nextIndex then state = "next" end
        if state ~= "picked" and vx * vx + vy * vy < nearPx * nearPx then near = true end
        local m = getMarker()
        styleMarker(m, st.kind, state == "next" and 34 or 28, state, NW.NodeIcon(base, st.kind ~= "mixed" and st.kind or "ore"))
        -- faded until a herb there is confirmed up, then full opacity
        local up = state ~= "picked" and NW.StopSeenAgo(mapID, i)
        if up then
          if state ~= "next" then styleMarker(m, st.kind, 30, "seen", NW.NodeIcon(base, st.kind ~= "mixed" and st.kind or "ore")) end
          m:SetAlpha(1)
        elseif state == "picked" then
          m:SetAlpha(0.2)
        else
          m:SetAlpha(state == "next" and math.max(0.6, s.fadedAlpha or 0.35) or (s.fadedAlpha or 0.35))
        end
        if state ~= "next" then m:SetAlpha(m:GetAlpha() * edgeFade(vx, vy)) end
        m:SetPoint("CENTER", pan, "CENTER", vx, vy)
        local sub = ("Stop %d of %d"):format(i, #stops)
        if state == "picked" then
          sub = sub .. (" · respawn ~%d min"):format(math.ceil((respawn - (now - seen)) / 60))
        end
        m.info = { title = label, sub = sub, stop = i, mapID = mapID, node = base }
      end
    end
  end

  -- Next-stop label
  if nextIndex and s.showNextLabel then
    local st = route.stops[nextIndex]
    local vx, vy = toView(st.x, st.y)
    -- keep the label inside the window, even when the stop is past its edge
    vx = math.max(-halfW + 30, math.min(halfW - 220, vx))
    vy = math.max(-halfH + 70, math.min(halfH - 30, vy))
    local d = math.floor(NW.Yards(mapID, px, py, st.x, st.y) or 0)
    nextLabel.title:SetText("Next: " .. stopName(mapID, st))
    nextLabel.sub:SetText(("%d yd · stop %d of %d"):format(d, nextIndex, #route.stops))
    nextLabel:SetSize(math.max(nextLabel.title:GetStringWidth(), nextLabel.sub:GetStringWidth()) + 20, 40)
    nextLabel:ClearAllPoints()
    nextLabel:SetPoint("TOPLEFT", view, "CENTER", vx + 18, vy - 10)
    nextLabel:Show()
  else
    nextLabel:Hide()
  end

  NW.nearNode = near
  finishPools()
  return true
end

-- The minimap anchors its tooltip to its own edge, which is far away now
-- that it's big; keep it beside the cursor instead.
local function placeMinimapTooltip()
  if not live.active or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= Minimap then return end
  local x, y = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale()
  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / sc + 18, y / sc + 12)
end

local function draw(force)
  local rebuilt = drawInner(force)
  if rebuilt == nil and built.mapID then
    -- nowhere to draw: clear what's there
    built.mapID = nil
    resetPools()
    finishPools()
    rebuilt = true
  end
  interact(rebuilt)
  refreshTooltip()
  placeMinimapTooltip()
end
NW.DrawOverlay = function() draw(true) end

------------------------------------------------------------------------
-- When to show it
------------------------------------------------------------------------
local inCombat = false

local function trackingOn()
  if not C_Minimap or not C_Minimap.GetNumTrackingTypes then return true end
  local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
  if not ok or not n then return true end
  for i = 1, n do
    local info = C_Minimap.GetTrackingInfo(i)
    local name, active
    if type(info) == "table" then name, active = info.name, info.active
    else local _; name, _, active = C_Minimap.GetTrackingInfo(i) end
    if active and name and NW.TRACKING_NAMES[name] then return true end
  end
  return false
end

function NW.OverlayShouldShow()
  local s = NW.db.settings
  if not s.overlayShown then return false end
  if s.hideCombat and inCombat then return false end
  if s.hideResting and IsResting() then return false end
  if s.hideInstances and IsInInstance() then return false end
  if s.onlyTracking and not trackingOn() then return false end
  return true
end

local function updateVisibility()
  local show = NW.OverlayShouldShow()
  overlay:SetShown(show)
  NW.SetLive(show and NW.db.settings.liveDots)
  if NW.compass then NW.compass:SetShown(show and NW.db.settings.showCompass) end
  if NW.sessionPanel then NW.sessionPanel:SetShown(show and NW.db.settings.showSession) end
end
NW.UpdateVisibility = updateVisibility

local slow, alphaNow = 0, nil
overlay:SetScript("OnUpdate", function(_, dt)
  frameDt = dt
  local s = NW.db.settings
  local a = s.opacity
  -- fade while you travel; come back when a spot or your next stop is close
  if s.fadeMoving and GetUnitSpeed("player") > 0 and not (s.brightNear and NW.nearNode) then a = a * s.fadeMovingAlpha end
  alphaNow = alphaNow and (alphaNow + (a - alphaNow) * math.min(1, dt * 6)) or a
  a = alphaNow
  -- The terrain takes the opacity setting; route and markers stay easy to read
  canvas:SetAlpha(a)
  terrain:SetAlpha(a)
  indoor:SetAlpha(a)
  local marks = math.min(1, a + 0.4)
  lineLayer:SetAlpha(marks)
  markerLayer:SetAlpha(marks)
  draw()
  slow = slow + dt
  if slow >= 0.2 then
    slow = 0
    if NW.UpdateCompass then NW.UpdateCompass() end
    if NW.UpdateSession then NW.UpdateSession() end
  end
end)

NW.On("PLAYER_REGEN_DISABLED", function() inCombat = true; updateVisibility() end)
NW.On("PLAYER_REGEN_ENABLED", function() inCombat = false; updateVisibility() end)
NW.On("PLAYER_UPDATE_RESTING", updateVisibility)
NW.On("ZONE_CHANGED_NEW_AREA", function() tileMapID = nil; updateVisibility() end)
NW.On("ZONE_CHANGED", function() tileMapID = nil end)
NW.On("ZONE_CHANGED_INDOORS", function() tileMapID = nil end)
NW.On("PLAYER_ENTERING_WORLD", updateVisibility)
NW.On("MINIMAP_UPDATE_TRACKING", updateVisibility)

function NW.ToggleOverlay()
  NW.db.settings.overlayShown = not NW.db.settings.overlayShown
  NW.RecentreOverlay()
  updateVisibility()
  if NW.db.settings.overlayShown and not overlay:IsShown() then
    NW.Print("Overlay is on, but hidden right now (combat, a city or inn, an instance, or tracking is off). See /nw options.")
  end
end

function NW.RefreshOverlayArt() tileMapID = nil end

table.insert(NW.OnLoad, function()
  -- the "Next" label is off unless turned on in the options
  if not NW.db.nextLabelOff then NW.db.settings.showNextLabel = false; NW.db.nextLabelOff = true end
  sizeView()
  updateVisibility()
end)
NW.On("DISPLAY_SIZE_CHANGED", sizeView)
NW.On("UI_SCALE_CHANGED", sizeView)
