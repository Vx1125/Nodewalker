local ADDON, NW = ...

------------------------------------------------------------------------
-- Flat widget kit and the main Nodewalker window.
-- 1px black edges, flat fills, a gold accent: the look of PallyPulse's
-- Flat style. Everything the menus use comes from here.
------------------------------------------------------------------------
local C = NW.COLORS
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local S = {
  bg       = { 0.055, 0.06, 0.07, 0.97 },
  edge     = { 0, 0, 0, 1 },
  cell     = { 0.12, 0.125, 0.14, 1 },
  hover    = { 0.18, 0.19, 0.21, 1 },
  sunk     = { 0.08, 0.085, 0.095, 1 },
  sep      = { C.gold[1], C.gold[2], C.gold[3], 0.22 },
  gold     = { C.gold[1], C.gold[2], C.gold[3], 1 },
  text     = { 0.92, 0.9, 0.85, 1 },
  dim      = { 0.58, 0.58, 0.6, 1 },
  disabled = { 0.38, 0.38, 0.4, 1 },
  bad      = { 0.92, 0.36, 0.3, 1 },
  good     = { 0.55, 0.86, 0.48, 1 },
}
NW.STYLE = S

local UI = {}
NW.UI = UI
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

function UI.Flat(f, bg, edge)
  f:SetBackdrop(FLAT)
  f:SetBackdropColor(unpack(bg or S.cell))
  f:SetBackdropBorderColor(unpack(edge or S.edge))
end

function UI.Panel(name, parent, w, h)
  local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
  if w then f:SetSize(w, h) end
  UI.Flat(f, S.bg, S.edge)
  return f
end

-- A sunken box for maps and lists
function UI.Box(parent, w, h)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  if w then f:SetSize(w, h) end
  UI.Flat(f, S.sunk, S.edge)
  return f
end

UI.FONT = FONT
function UI.Text(parent, size, color, justify, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, flags or "")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 1)
  local c = color or S.text
  fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

-- Gold section heading with a hairline running to the right
function UI.Heading(parent, text, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width or 300, 18)
  f.text = UI.Text(f, 12, S.gold)
  f.text:SetPoint("LEFT")
  f.text:SetText(text)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(S.sep))
  line:SetHeight(1)
  line:SetPoint("LEFT", f.text, "RIGHT", 8, 0)
  line:SetPoint("RIGHT")
  return f
end

function UI.Tip(frame, title, body)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(type(title) == "function" and title() or title, 1, 1, 1)
    local b = type(body) == "function" and body() or body
    if b then GameTooltip:AddLine(b, S.dim[1], S.dim[2], S.dim[3], true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", GameTooltip_Hide)
end

------------------------------------------------------------------------
-- Button. style: nil (plain) | "primary" (gold) | "danger"
------------------------------------------------------------------------
function UI.Button(parent, text, w, onClick, h, style)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h or 26)
  local base = style == "primary" and { C.gold[1] * 0.32, C.gold[2] * 0.32, C.gold[3] * 0.32, 1 } or S.cell
  local over = style == "primary" and { C.gold[1] * 0.45, C.gold[2] * 0.45, C.gold[3] * 0.45, 1 } or S.hover
  UI.Flat(b, base, S.edge)
  local fs = UI.Text(b, 12, style == "primary" and S.gold or S.text, "CENTER")
  fs:SetPoint("LEFT", 6, 0)
  fs:SetPoint("RIGHT", -6, 0)
  fs:SetWordWrap(false)
  b:SetFontString(fs)
  b:SetText(text or "")
  b.label = fs
  local textColor = style == "primary" and S.gold or S.text
  b:SetScript("OnEnter", function(self)
    if not self:IsEnabled() then return end
    self:SetBackdropColor(unpack(over))
    self:SetBackdropBorderColor(unpack(S.gold))
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropColor(unpack(base))
    self:SetBackdropBorderColor(unpack(S.edge))
  end)
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then fs:SetPoint("LEFT", 7, -1); fs:SetPoint("RIGHT", -5, -1) end end)
  b:SetScript("OnMouseUp", function() fs:SetPoint("LEFT", 6, 0); fs:SetPoint("RIGHT", -6, 0) end)
  b:SetScript("OnDisable", function(self)
    fs:SetTextColor(unpack(S.disabled))
    self:SetBackdropColor(unpack(S.sunk))
    self:SetBackdropBorderColor(unpack(S.edge))
  end)
  b:SetScript("OnEnable", function(self)
    fs:SetTextColor(unpack(textColor))
    self:SetBackdropColor(unpack(base))
  end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

------------------------------------------------------------------------
-- Check box: 14px box, gold square when on. get() -> bool, set(bool)
------------------------------------------------------------------------
function UI.Check(parent, label, get, set, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  cb:SetSize(14, 14)
  UI.Flat(cb, S.sunk, S.edge)
  local mark = cb:CreateTexture(nil, "ARTWORK")
  mark:SetPoint("TOPLEFT", 3, -3)
  mark:SetPoint("BOTTOMRIGHT", -3, 3)
  mark:SetColorTexture(unpack(S.gold))
  cb:SetCheckedTexture(mark)
  cb.label = UI.Text(cb, 12, S.text)
  cb.label:SetPoint("LEFT", cb, "RIGHT", 8, 0)
  function cb:SetLabel(t)
    self.label:SetText(t)
    self:SetHitRectInsets(-3, -(self.label:GetStringWidth() + 12), -4, -4)
  end
  cb:SetLabel(label)
  function cb:Refresh() self:SetChecked(get() and true or false) end
  cb:SetScript("OnShow", cb.Refresh)
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  cb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(S.gold)) end)
  cb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(S.edge)) end)
  cb:SetScript("OnDisable", function(self) self.label:SetTextColor(unpack(S.disabled)) end)
  cb:SetScript("OnEnable", function(self) self.label:SetTextColor(unpack(S.text)) end)
  if tip then UI.Tip(cb, label, tip) end
  return cb
end

------------------------------------------------------------------------
-- Slider: label left, value right, flat track with a gold fill.
-- fmtValue(v) -> text shown on the right.
------------------------------------------------------------------------
function UI.Slider(parent, width, label, minV, maxV, step, fmtValue, get, set, tip)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width, 34)
  holder.label = UI.Text(holder, 12, S.text)
  holder.label:SetPoint("TOPLEFT", 0, 0)
  holder.label:SetText(label)
  holder.value = UI.Text(holder, 12, S.gold, "RIGHT")
  holder.value:SetPoint("TOPRIGHT", 0, 0)

  local s = CreateFrame("Slider", nil, holder)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(14)
  s:SetPoint("BOTTOMLEFT", 0, 0)
  s:SetPoint("BOTTOMRIGHT", 0, 0)
  s:SetHitRectInsets(0, 0, -4, -4)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(unpack(S.sunk))
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(6)
  local edge = s:CreateTexture(nil, "BACKGROUND", nil, -1)
  edge:SetColorTexture(0, 0, 0, 1)
  edge:SetPoint("TOPLEFT", track, -1, 1)
  edge:SetPoint("BOTTOMRIGHT", track, 1, -1)
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(unpack(S.gold))
  thumb:SetSize(8, 14)
  s:SetThumbTexture(thumb)
  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.45)
  fill:SetHeight(6)
  fill:SetPoint("LEFT", track, "LEFT")
  fill:SetPoint("RIGHT", thumb, "CENTER")

  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  local function show(v) holder.value:SetText(fmtValue(v)) end
  s:SetScript("OnValueChanged", function(_, v, userInput)
    v = math.floor(v / step + 0.5) * step
    show(v)
    if userInput then set(v) end
  end)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d)
    local v = math.max(minV, math.min(maxV, self:GetValue() + d * step))
    self:SetValue(v)
    set(v)
  end)
  s:SetScript("OnEnter", function() thumb:SetColorTexture(1, 0.92, 0.65, 1) end)
  s:SetScript("OnLeave", function() thumb:SetColorTexture(unpack(S.gold)) end)
  function holder:Refresh() local v = get(); s:SetValue(v); show(v) end
  holder:SetScript("OnShow", holder.Refresh)
  holder.slider = s
  if tip then holder:EnableMouse(true); UI.Tip(holder, label, tip) end
  return holder
end

------------------------------------------------------------------------
-- Dropdown: label left, a flat button on the right with the choice.
-- items = { { value, text }, ... }
------------------------------------------------------------------------
local openMenu
local function autoClose(menu)
  menu:SetScript("OnUpdate", function(self)
    if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
      and not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then
      self:Hide()
    end
  end)
end

function UI.Dropdown(parent, width, label, items, get, set, btnW, tip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 24)
  f.label = UI.Text(f, 12, S.text)
  f.label:SetPoint("LEFT")
  f.label:SetText(label)
  btnW = btnW or 170
  local b = UI.Button(f, "", btnW, nil, 22)
  b:SetPoint("RIGHT")
  b.label:ClearAllPoints()
  b.label:SetPoint("LEFT", 8, 0)
  b.label:SetPoint("RIGHT", -20, 0)
  b.label:SetJustifyH("LEFT")
  local arrow = b:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(10, 10)
  arrow:SetPoint("RIGHT", -6, 0)
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetRotation(-math.pi / 2)
  arrow:SetVertexColor(unpack(S.gold))

  local RH = 20
  local menu = UI.Panel(nil, UIParent, btnW, 10)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  menu:Hide()
  menu.anchor = b
  autoClose(menu)
  menu.rows = {}
  for i, it in ipairs(items) do
    local r = CreateFrame("Button", nil, menu)
    r:SetHeight(RH)
    r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * RH)
    r:SetPoint("RIGHT", -1, 0)
    r.text = UI.Text(r, 12, S.text)
    r.text:SetPoint("LEFT", 8, 0)
    r.text:SetText(it[2])
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    r:SetScript("OnClick", function() set(it[1]); menu:Hide(); f:Refresh() end)
    r.value = it[1]
    menu.rows[i] = r
  end
  menu:SetHeight(2 + #items * RH)
  b:SetScript("OnClick", function()
    if menu:IsShown() then menu:Hide() return end
    if openMenu and openMenu ~= menu then openMenu:Hide() end
    openMenu = menu
    for _, r in ipairs(menu.rows) do r.text:SetTextColor(unpack(r.value == get() and S.gold or S.text)) end
    menu:SetScale(b:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
    menu:Show()
  end)
  f:SetScript("OnHide", function() menu:Hide() end)
  function f:Refresh()
    local cur = get()
    for _, it in ipairs(items) do if it[1] == cur then b:SetText(it[2]) return end end
    b:SetText(tostring(cur or ""))
  end
  f:SetScript("OnShow", f.Refresh)
  if tip then f:EnableMouse(true); UI.Tip(f, label, tip) end
  return f
end

------------------------------------------------------------------------
-- Close button: a flat X drawn with two lines
------------------------------------------------------------------------
function UI.Close(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  local lines = {}
  for i = 1, 2 do
    local l = b:CreateLine(nil, "OVERLAY")
    l:SetThickness(2)
    l:SetColorTexture(unpack(S.dim))
    lines[i] = l
  end
  lines[1]:SetStartPoint("TOPLEFT", b, 6, -6); lines[1]:SetEndPoint("BOTTOMRIGHT", b, -6, 6)
  lines[2]:SetStartPoint("TOPRIGHT", b, -6, -6); lines[2]:SetEndPoint("BOTTOMLEFT", b, 6, 6)
  b:SetScript("OnEnter", function() for _, l in ipairs(lines) do l:SetColorTexture(unpack(S.bad)) end end)
  b:SetScript("OnLeave", function() for _, l in ipairs(lines) do l:SetColorTexture(unpack(S.dim)) end end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Flat hover/selection textures for list rows
function UI.RowHighlight(row)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)
  local sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  sel:SetAllPoints()
  sel:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.16)
  sel:Hide()
  local bar = row:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("BOTTOMLEFT")
  bar:SetWidth(2)
  bar:SetColorTexture(unpack(S.gold))
  bar:Hide()
  function row:SetSelected(on) sel:SetShown(on); bar:SetShown(on) end
end

------------------------------------------------------------------------
-- Main window: title bar, text tabs with a gold underline, pages
------------------------------------------------------------------------
local WIN_W, WIN_H = 1020, 610
local TITLE_H, TABS_H = 32, 26
UI.CONTENT_TOP = TITLE_H + TABS_H + 6
UI.CONTENT_W, UI.CONTENT_H = WIN_W, WIN_H - UI.CONTENT_TOP

local win = UI.Panel("NodewalkerWindow", UIParent, WIN_W, WIN_H)
win:SetPoint("CENTER")
win:SetFrameStrata("HIGH")
win:SetToplevel(true)
win:SetMovable(true)
win:SetClampedToScreen(true)
win:EnableMouse(true)
win:Hide()
tinsert(UISpecialFrames, "NodewalkerWindow") -- Escape closes it
NW.window = win

local titleBar = CreateFrame("Frame", nil, win)
titleBar:SetPoint("TOPLEFT", 1, -1)
titleBar:SetPoint("TOPRIGHT", -1, -1)
titleBar:SetHeight(TITLE_H - 1)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() win:StartMoving() end)
titleBar:SetScript("OnDragStop", function()
  win:StopMovingOrSizing()
  local p, _, rp, x, y = win:GetPoint()
  if NW.db then NW.db.settings.winPos = { p, rp, x, y } end
end)
local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
titleBg:SetAllPoints()
titleBg:SetColorTexture(0, 0, 0, 0.35)

local logo = titleBar:CreateTexture(nil, "ARTWORK")
logo:SetSize(22, 22)
logo:SetPoint("LEFT", 10, 0)
logo:SetTexture("Interface\\AddOns\\Nodewalker\\Media\\Icon")
win.title = UI.Text(titleBar, 15, S.gold)
win.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
win.title:SetText("Nodewalker")
win.sub = UI.Text(titleBar, 12, S.dim)
win.sub:SetPoint("LEFT", win.title, "RIGHT", 10, -1)

local close = UI.Close(titleBar, function() win:Hide() end)
close:SetPoint("RIGHT", -6, 0)
win.version = UI.Text(titleBar, 11, S.dim, "RIGHT")
win.version:SetPoint("RIGHT", close, "LEFT", -10, 0)

local tabLine = win:CreateTexture(nil, "ARTWORK")
tabLine:SetPoint("TOPLEFT", 8, -(TITLE_H + TABS_H))
tabLine:SetPoint("TOPRIGHT", -8, -(TITLE_H + TABS_H))
tabLine:SetHeight(1)
tabLine:SetColorTexture(unpack(S.sep))

local tabs, tabOrder, current = {}, {}, nil
local ticker

local function setSub(text) win.sub:SetText(text or "") end
NW.SetWindowSubtitle = setSub

function NW.ShowTab(key)
  local t = tabs[key] or tabs[tabOrder[1]]
  if not t then return end
  if current and current ~= t and current.onHide then current.onHide() end
  current = t
  if NW.db then NW.db.settings.lastTab = t.key end
  for _, o in pairs(tabs) do
    local on = o == t
    o.page:SetShown(on)
    o.button.text:SetTextColor(unpack(on and S.gold or S.dim))
    o.button.line:SetShown(on)
  end
  setSub("")
  if t.onShow then t.onShow() end
end

function NW.CurrentTab() return current and current.key end

-- key, label, onShow, onHide, onTick (once a second while shown). Returns the page.
function UI.AddTab(key, label, onShow, onHide, onTick)
  local page = CreateFrame("Frame", nil, win)
  page:SetPoint("TOPLEFT", 0, -UI.CONTENT_TOP)
  page:SetPoint("BOTTOMRIGHT")
  page:Hide()
  local b = CreateFrame("Button", nil, win)
  b.text = UI.Text(b, 13, S.dim, "CENTER")
  b.text:SetPoint("CENTER", 0, 1)
  b.text:SetText(label)
  b:SetSize(b.text:GetStringWidth() + 26, TABS_H)
  local prev = tabOrder[#tabOrder] and tabs[tabOrder[#tabOrder]].button
  if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", 10, -TITLE_H) end
  b.line = b:CreateTexture(nil, "OVERLAY")
  b.line:SetPoint("BOTTOMLEFT", 8, 0)
  b.line:SetPoint("BOTTOMRIGHT", -8, 0)
  b.line:SetHeight(2)
  b.line:SetColorTexture(unpack(S.gold))
  b.line:Hide()
  b:SetScript("OnClick", function() NW.ShowTab(key) end)
  b:SetScript("OnEnter", function(self) if current ~= tabs[key] then self.text:SetTextColor(unpack(S.text)) end end)
  b:SetScript("OnLeave", function(self) if current ~= tabs[key] then self.text:SetTextColor(unpack(S.dim)) end end)
  tabs[key] = { key = key, page = page, button = b, onShow = onShow, onHide = onHide, onTick = onTick }
  tabOrder[#tabOrder + 1] = key
  return page
end

win:SetScript("OnShow", function()
  local v = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version"))
  win.version:SetText((v and not v:find("@")) and ("v" .. v:gsub("^[vV]", "")) or "")
  NW.ShowTab((NW.db and NW.db.settings.lastTab) or tabOrder[1])
  ticker = C_Timer.NewTicker(1, function()
    if current and current.onTick then current.onTick() end
  end)
end)
win:SetScript("OnHide", function()
  if ticker then ticker:Cancel(); ticker = nil end
  if current and current.onHide then current.onHide() end
  if openMenu then openMenu:Hide() end
end)

-- Open the window on a tab; if it's already open on that tab, close it.
function NW.ToggleWindow(key)
  if win:IsShown() and (not key or NW.CurrentTab() == key) then
    win:Hide()
    return
  end
  if win:IsShown() then NW.ShowTab(key) return end
  if key and NW.db then NW.db.settings.lastTab = key end
  win:Show()
end

table.insert(NW.OnLoad, function()
  local p = NW.db.settings.winPos
  if p then
    win:ClearAllPoints()
    win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
end)

------------------------------------------------------------------------
-- Shared helpers for the map pages
------------------------------------------------------------------------
-- Object pool: get() returns a shown object, reset() hides them all.
function UI.Pool(make)
  local list, n = {}, 0
  return function()
    n = n + 1
    local o = list[n] or make()
    list[n] = o
    o:Show()
    return o
  end, function()
    for i = 1, #list do list[i]:Hide() end
    n = 0
  end
end

-- The zone's world map art, drawn into frame at W x H, muted gold.
function UI.DrawZoneArt(id, frame, tiles, W, H, full)
  for _, t in ipairs(tiles) do t:Hide() end
  tiles.reveal = tiles.reveal or {}
  for _, t in ipairs(tiles.reveal) do t:Hide() end
  local layers = id and C_Map.GetMapArtLayers(id)
  local layer = layers and layers[1]
  local textures = layer and C_Map.GetMapArtLayerTextures(id, 1)
  if not textures then return end
  local cols = math.ceil(layer.layerWidth / layer.tileWidth)
  local tw = W * layer.tileWidth / layer.layerWidth
  local th = H * layer.tileHeight / layer.layerHeight
  for i, fileID in ipairs(textures) do
    local t = tiles[i] or frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tiles[i] = t
    t:ClearAllPoints()
    t:SetSize(tw, th)
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", ((i - 1) % cols) * tw, -math.floor((i - 1) / cols) * th)
    t:SetTexture(fileID)
    -- full: the map as the game draws it; otherwise a quiet gold wash
    t:SetDesaturated(not full)
    if full then t:SetVertexColor(1, 1, 1) t:SetAlpha(1) else t:SetVertexColor(0.95, 0.8, 0.45) t:SetAlpha(0.45) end
    t:Show()
  end
  -- The full map is drawn fully explored: every explored-area piece laid over
  -- the base art, cut into 256 px tiles as the game's own map does it.
  local art = full and NW.MapReveal and C_Map.GetMapArtID and C_Map.GetMapArtID(id)
  local pieces = art and NW.MapReveal[art]
  if not pieces then return end
  local sx, sy = W / layer.layerWidth, H / layer.layerHeight
  local n = 0
  local function fileSize(px) -- the texture file is the next power of two up
    local f = 256
    while f / 2 >= px and f > 16 do f = f / 2 end
    return f
  end
  for key, files in pairs(pieces) do
    local pw, ph, ox, oy = key:match("^(%d+):(%d+):(%d+):(%d+)$")
    pw, ph, ox, oy = tonumber(pw), tonumber(ph), tonumber(ox), tonumber(oy)
    if pw then
      local across = math.ceil(pw / 256)
      local k = 0
      for fid in files:gmatch("%d+") do
        local col, row = k % across, math.floor(k / across)
        k = k + 1
        local cw = math.min(256, pw - col * 256)
        local ch = math.min(256, ph - row * 256)
        if cw > 0 and ch > 0 then
          n = n + 1
          local t = tiles.reveal[n] or frame:CreateTexture(nil, "BACKGROUND", nil, 2)
          tiles.reveal[n] = t
          t:SetTexture(tonumber(fid))
          t:SetTexCoord(0, cw / fileSize(cw), 0, ch / fileSize(ch))
          t:ClearAllPoints()
          t:SetSize(cw * sx, ch * sy)
          t:SetPoint("TOPLEFT", frame, "TOPLEFT", (ox + col * 256) * sx, -(oy + row * 256) * sy)
          t:SetVertexColor(1, 1, 1)
          t:SetAlpha(1)
          t:Show()
        end
      end
    end
  end
end
