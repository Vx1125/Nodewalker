local ADDON, NW = ...

------------------------------------------------------------------------
-- Flat widget kit and the main Nodewalker window.
-- 1px black edges, flat fills, a gold accent: the look of PallyPulse's
-- Flat style. Everything the menus use comes from here.
------------------------------------------------------------------------
local C = NW.COLORS
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- One palette for every page: warm charcoal, bronze edges, muted gold
local S = {
  bg       = { 0.078, 0.075, 0.067, 1 }, -- main frame
  cell     = { 0.125, 0.118, 0.102, 1 }, -- content panels, buttons
  header   = { 0.141, 0.125, 0.098, 1 }, -- title bar, column headers, status bar
  edge     = { 0.318, 0.263, 0.169, 1 }, -- 1px bronze border
  hover    = { 0.173, 0.157, 0.125, 1 }, -- hovered row / button
  select   = { 0.220, 0.188, 0.118, 1 }, -- selected row
  sunk     = { 0.094, 0.090, 0.078, 1 }, -- lists and maps sit a step darker
  alt      = { 1, 1, 1, 0.025 }, -- every other row
  sep      = { 0.318, 0.263, 0.169, 0.7 },
  gold     = { 0.839, 0.698, 0.400, 1 },
  text     = { 0.878, 0.859, 0.816, 1 },
  dim      = { 0.576, 0.549, 0.502, 1 },
  disabled = { 0.369, 0.345, 0.314, 1 },
  bad      = { 0.820, 0.463, 0.396, 1 },
  good     = { 0.580, 0.729, 0.471, 1 },
}
-- the same, for colour codes in text
S.HEX = { gold = "|cffd6b266", text = "|cffe0dbd0", dim = "|cff938c80", good = "|cff94ba78", bad = "|cffd17665" }
-- sizes every page shares
S.PAD, S.GAP, S.ROW_H, S.ICON = 16, 10, 34, 24
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
-- Set a line's text at its size; if it doesn't fit its width, a point or two
-- smaller (never under min). Lines that still don't fit stay cut, with the
-- whole text on hover where the row has a tooltip.
function UI.FitText(fs, text, size, min)
  local font, _, flags = fs:GetFont()
  fs:SetFont(font or FONT, size, flags or "")
  fs:SetText(text or "")
  local w = fs:GetWidth() or 0
  if w <= 0 then return end
  for s = size - 1, min or (size - 2), -1 do
    if (fs:GetStringWidth() or 0) <= w then return end
    fs:SetFont(font or FONT, s, flags or "")
  end
end

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
  local base = style == "primary" and { S.gold[1] * 0.3, S.gold[2] * 0.3, S.gold[3] * 0.3, 1 } or S.cell
  local over = style == "primary" and { S.gold[1] * 0.42, S.gold[2] * 0.42, S.gold[3] * 0.42, 1 } or S.hover
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
  cb:SetSize(15, 15)
  UI.Flat(cb, S.sunk, S.edge)
  -- a gold tick on a dark bronze box when on; empty when off
  local mark = cb:CreateTexture(nil, "OVERLAY")
  mark:SetSize(20, 20)
  mark:SetPoint("CENTER", 1, 1)
  mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  mark:SetVertexColor(S.gold[1], S.gold[2], S.gold[3])
  cb:SetCheckedTexture(mark)
  local function tone(self) self:SetBackdropColor(unpack(self:GetChecked() and S.select or S.sunk)) end
  cb.label = UI.Text(cb, 12, S.text)
  cb.label:SetPoint("LEFT", cb, "RIGHT", 8, 0)
  function cb:SetLabel(t)
    self.label:SetText(t)
    self:SetHitRectInsets(-3, -(self.label:GetStringWidth() + 12), -4, -4)
  end
  cb:SetLabel(label)
  function cb:Refresh() self:SetChecked(get() and true or false) tone(self) end
  cb:SetScript("OnShow", cb.Refresh)
  cb:SetScript("OnClick", function(self) tone(self) set(self:GetChecked() and true or false) end)
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
  edge:SetColorTexture(unpack(S.edge))
  edge:SetPoint("TOPLEFT", track, -1, 1)
  edge:SetPoint("BOTTOMRIGHT", track, 1, -1)
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(unpack(S.gold))
  thumb:SetSize(8, 14)
  s:SetThumbTexture(thumb)
  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.45)
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
    -- a light gold wash: the highlight layer draws over the text, so it can't be solid
    hl:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.12)
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
-- A button that opens a short list of check boxes (for filters you don't
-- change often). items = { { label, get, set, tip }, ... }. onChange() after a click.
------------------------------------------------------------------------
function UI.CheckMenu(parent, text, w, items, onChange)
  local b = UI.Button(parent, text, w, nil, 22)
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
  local RH = 22
  local menu = UI.Panel(nil, UIParent, 200, 10)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  menu:Hide()
  menu.anchor = b
  autoClose(menu)
  local checks = {}
  local widest = 0
  local acts = {}
  for i, it in ipairs(items) do
    local y = -8 - (i - 1) * RH
    if it.action then
      -- an action, not a setting: a line of gold text that closes the menu
      local a = CreateFrame("Button", nil, menu)
      a:SetHeight(RH - 2)
      a:SetPoint("TOPLEFT", 6, y + 3)
      a:SetPoint("RIGHT", -6, 0)
      local hl = a:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.1)
      a.label = UI.Text(a, 12, S.gold)
      a.label:SetPoint("LEFT", 4, 0)
      a.label:SetText(it[1])
      a:SetScript("OnClick", function() menu:Hide(); it.action(); if onChange then onChange() end end)
      if it.tip then UI.Tip(a, it[1], it.tip) end
      acts[#acts + 1] = { a, it }
      widest = math.max(widest, a.label:GetStringWidth() - 24)
    else
      local cb = UI.Check(menu, it[1], it[2], function(v) it[3](v) if onChange then onChange() end b:Refresh() end, it[4])
      cb:SetPoint("TOPLEFT", 10, y)
      checks[#checks + 1] = cb
      widest = math.max(widest, cb.label:GetStringWidth())
    end
  end
  menu:SetSize(math.max(w, widest + 44), 12 + #items * RH)
  -- the button shows how many are on
  function b:Refresh()
    local n = 0
    for _, it in ipairs(items) do if not it.action and it[2]() then n = n + 1 end end
    self:SetText(n > 0 and ("%s (%d)"):format(text, n) or text)
  end
  b:SetScript("OnClick", function()
    if menu:IsShown() then menu:Hide() return end
    if openMenu and openMenu ~= menu then openMenu:Hide() end
    openMenu = menu
    for _, cb in ipairs(checks) do cb:Refresh() end
    for _, x in ipairs(acts) do
      local on = not x[2].enabled or x[2].enabled()
      x[1]:SetEnabled(on)
      x[1].label:SetTextColor(unpack(on and S.gold or S.dim))
    end
    menu:SetScale(b:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
    menu:Show()
  end)
  b:HookScript("OnHide", function() menu:Hide() end)
  b:HookScript("OnShow", function(self) self:Refresh() end) -- saved settings aren't loaded yet at build time
  return b
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
  -- the highlight layer draws over text, so it's a light wash of the hover colour
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.07)
  local sel = row:CreateTexture(nil, "BACKGROUND", nil, 3)
  sel:SetAllPoints()
  sel:SetColorTexture(unpack(S.select))
  sel:Hide()
  local bar = row:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("BOTTOMLEFT")
  bar:SetWidth(2)
  bar:SetColorTexture(unpack(S.gold))
  bar:Hide()
  function row:SetSelected(on) sel:SetShown(on); bar:SetShown(on) end
end

-- Every other row a shade lighter. row:SetStripe(on)
function UI.RowStripe(row)
  local t = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  t:SetAllPoints()
  t:SetColorTexture(unpack(S.alt))
  t:Hide()
  function row:SetStripe(on) t:SetShown(on and true or false) end
end

-- A panel with a header strip across its top: returns the panel and the header.
function UI.Section(parent, w, h, title)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  if w then f:SetSize(w, h) end
  UI.Flat(f, S.cell, S.edge)
  local hd = CreateFrame("Frame", nil, f)
  hd:SetPoint("TOPLEFT", 1, -1)
  hd:SetPoint("TOPRIGHT", -1, -1)
  hd:SetHeight(24)
  local bg = hd:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(S.header))
  local line = hd:CreateTexture(nil, "ARTWORK")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  line:SetColorTexture(unpack(S.sep))
  hd.text = UI.Text(hd, 12, S.gold)
  hd.text:SetPoint("LEFT", 10, 0)
  hd.text:SetText(title or "")
  f.header = hd
  return f, hd
end


------------------------------------------------------------------------
-- Main window: title bar, text tabs with a gold underline, pages
------------------------------------------------------------------------
local WIN_W, WIN_H = 1020, 622
local TITLE_H, TABS_H = 38, 32
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
titleBg:SetColorTexture(unpack(S.header))
local titleLine = titleBar:CreateTexture(nil, "ARTWORK")
titleLine:SetPoint("BOTTOMLEFT")
titleLine:SetPoint("BOTTOMRIGHT")
titleLine:SetHeight(1)
titleLine:SetColorTexture(unpack(S.sep))

local logo = titleBar:CreateTexture(nil, "ARTWORK")
logo:SetSize(24, 24)
logo:SetPoint("LEFT", 12, 0)
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
tabLine:SetPoint("TOPLEFT", 1, -(TITLE_H + TABS_H))
tabLine:SetPoint("TOPRIGHT", -1, -(TITLE_H + TABS_H))
tabLine:SetHeight(1)
tabLine:SetColorTexture(unpack(S.sep))

local tabs, tabOrder, current = {}, {}, nil
local ticker
-- Left to right; tabs not listed go at the end
local ORDER = { "profs", "guide", "find", "consumes", "settings" }
local rank = {}
for i, k in ipairs(ORDER) do rank[k] = i end
-- Pages grouped under one tab (Settings): small switches at the right of the tab row
local groups = {} -- name -> { button, label, keys = {}, last, subs = {} }

local function setSub(text) win.sub:SetText(text or "") end
NW.SetWindowSubtitle = setSub

local function tabButton(label, onClick)
  local b = CreateFrame("Button", nil, win)
  b.text = UI.Text(b, 13, S.dim, "CENTER")
  b.text:SetPoint("CENTER", 0, 1)
  b.text:SetText(label)
  b:SetSize(b.text:GetStringWidth() + 26, TABS_H)
  b.line = b:CreateTexture(nil, "OVERLAY")
  b.line:SetPoint("BOTTOMLEFT", 8, 0)
  b.line:SetPoint("BOTTOMRIGHT", -8, 0)
  b.line:SetHeight(2)
  b.line:SetColorTexture(unpack(S.gold))
  b.line:Hide()
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) if not self.on then self.text:SetTextColor(unpack(S.text)) end end)
  b:SetScript("OnLeave", function(self) if not self.on then self.text:SetTextColor(unpack(S.dim)) end end)
  return b
end
local function setOn(b, on)
  b.on = on
  b.text:SetTextColor(unpack(on and S.gold or S.dim))
  b.line:SetShown(on)
end

local function layoutTabs()
  table.sort(tabOrder, function(x, y)
    local rx, ry = rank[x] or 99, rank[y] or 99
    if rx ~= ry then return rx < ry end
    return x < y
  end)
  local prev
  for _, k in ipairs(tabOrder) do
    local b = tabs[k] and tabs[k].button or groups[k] and groups[k].button
    b:ClearAllPoints()
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", 10, -TITLE_H) end
    prev = b
  end
end

-- A group's switches sit at the right of the tab row, in whatever room the
-- main tabs leave: a step smaller (font, padding, gap) until they fit
local function layoutSubs(g)
  local used = 10
  for _, k in ipairs(tabOrder) do
    local b = tabs[k] and tabs[k].button or groups[k] and groups[k].button
    if b then used = used + b:GetWidth() + 2 end
  end
  local room = WIN_W - 10 - used - 12
  local STEPS = { { 12, 22, 2 }, { 12, 14, 0 }, { 11, 12, 0 }, { 11, 8, 0 } }
  for si, step in ipairs(STEPS) do
    local total = 0
    for _, k in ipairs(g.keys) do
      local sb = g.subs[k]
      sb.text:SetFont(UI.FONT or STANDARD_TEXT_FONT, step[1])
      total = total + sb.text:GetStringWidth() + step[2] + step[3]
    end
    if total <= room or si == #STEPS then
      local prev
      for i = #g.keys, 1, -1 do
        local sb = g.subs[g.keys[i]]
        sb:SetSize(sb.text:GetStringWidth() + step[2], TABS_H)
        sb:ClearAllPoints()
        if prev then sb:SetPoint("RIGHT", prev, "LEFT", -step[3], 0) else sb:SetPoint("TOPRIGHT", -10, -TITLE_H) end
        prev = sb
      end
      return
    end
  end
end

function NW.ShowTab(key)
  -- an old tab's key (saved, or from a link) opens where it lives now
  local alias = NW.TAB_ALIAS and NW.TAB_ALIAS[key]
  if alias then key = alias() end
  if groups[key] then key = groups[key].last or groups[key].keys[1] end
  local t = tabs[key] or tabs[tabOrder[1]] or (groups[tabOrder[1]] and tabs[groups[tabOrder[1]].keys[1]])
  if not t then return end
  if current and current ~= t and current.onHide then current.onHide() end
  current = t
  if NW.db then NW.db.settings.lastTab = t.key end
  for _, o in pairs(tabs) do
    o.page:SetShown(o == t)
    if o.button then setOn(o.button, o == t) end
  end
  for name, g in pairs(groups) do
    local inside = t.group == name
    if inside then layoutSubs(g) end
    setOn(g.button, inside)
    if inside then g.last = t.key end
    for k, sb in pairs(g.subs) do
      sb:SetShown(inside)
      setOn(sb, k == t.key)
    end
  end
  setSub("")
  if t.onShow then t.onShow() end
end

function NW.CurrentTab() return current and current.key end
function NW.TabPage(key) return tabs[key] and tabs[key].page end

-- key, label, onShow, onHide, onTick (once a second while shown), group
-- (a tab name its page goes under, e.g. "Settings"). Returns the page.
function UI.AddTab(key, label, onShow, onHide, onTick, group)
  local page = CreateFrame("Frame", nil, win)
  page:SetPoint("TOPLEFT", 0, -UI.CONTENT_TOP)
  page:SetPoint("BOTTOMRIGHT")
  page:Hide()
  local t = { key = key, page = page, onShow = onShow, onHide = onHide, onTick = onTick }
  tabs[key] = t
  if group then
    local gk = group:lower()
    local g = groups[gk]
    if not g then
      g = { keys = {}, subs = {} }
      g.button = tabButton(group, function() NW.ShowTab(gk) end)
      groups[gk] = g
      tabOrder[#tabOrder + 1] = gk
    end
    t.group = gk
    g.keys[#g.keys + 1] = key
    -- its switch, right-aligned in the tab row
    local sb = tabButton(label, function() NW.ShowTab(key) end)
    sb.text:SetFont(UI.FONT or STANDARD_TEXT_FONT, 12)
    sb:SetSize(sb.text:GetStringWidth() + 22, TABS_H)
    local lastSub = g.subs[g.keys[#g.keys - 1] or ""]
    if lastSub then
      -- re-anchor all, right to left
      local prev
      for i = #g.keys, 1, -1 do
        local b = g.subs[g.keys[i]] or sb
        b:ClearAllPoints()
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", -10, -TITLE_H) end
        prev = b
      end
    else
      sb:SetPoint("TOPRIGHT", -10, -TITLE_H)
    end
    sb:Hide()
    g.subs[key] = sb
  else
    t.button = tabButton(label, function() NW.ShowTab(key) end)
    tabOrder[#tabOrder + 1] = key
  end
  layoutTabs()
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
  if key == "route" and NW.TogglePlanner then return NW.TogglePlanner() end
  local alias = NW.TAB_ALIAS and NW.TAB_ALIAS[key]
  if alias then key = alias() end
  if win:IsShown() and (not key or NW.CurrentTab() == key) then
    win:Hide()
    return
  end
  if win:IsShown() then NW.ShowTab(key) return end
  if key and NW.db then NW.db.settings.lastTab = key end
  win:Show()
end

function NW.SetWindowScale(v)
  NW.db.settings.winScale = v
  -- keep the top-left corner where it is
  local l, t = win:GetLeft(), win:GetTop()
  local old = win:GetScale()
  win:SetScale(v)
  if l and t then
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * old / v, t * old / v)
    local p, _, rp, x, y = win:GetPoint()
    NW.db.settings.winPos = { p, rp, x, y }
  end
end

-- A size grip in the bottom-right corner: drag to make the whole window
-- bigger or smaller (it scales; the top-left corner stays put). Saved as
-- the same Window scale as in Settings › Appearance.
local SCALE_MIN, SCALE_MAX = 0.6, 1.5
local grip = CreateFrame("Button", nil, win)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -3, 3)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:SetFrameLevel(win:GetFrameLevel() + 20)
local function cursorX() return GetCursorPosition() / UIParent:GetEffectiveScale() end
grip:SetScript("OnMouseDown", function(self, button)
  if button ~= "LeftButton" then return end
  self.startX, self.startScale = cursorX(), win:GetScale()
  self:SetScript("OnUpdate", function(g)
    -- the window's right edge follows the cursor
    local w = WIN_W * g.startScale + (cursorX() - g.startX)
    local v = math.max(SCALE_MIN, math.min(SCALE_MAX, w / WIN_W))
    v = math.floor(v * 100 + 0.5) / 100
    if math.abs(v - win:GetScale()) >= 0.01 then NW.SetWindowScale(v) end
  end)
end)
grip:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
grip:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
grip:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
  GameTooltip:SetText("Window size", 1, 1, 1)
  GameTooltip:AddLine(("Drag to resize. %d%% now."):format(math.floor(win:GetScale() * 100 + 0.5)), S.dim[1], S.dim[2], S.dim[3], true)
  GameTooltip:Show()
end)
grip:SetScript("OnLeave", GameTooltip_Hide)
table.insert(NW.OnLoad, function()
  win:SetScale(NW.db.settings.winScale or 1)
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
-- One pool per marker kind, shared by every material and zone: it grows to the most
-- shown at once and its frames are reused, never destroyed. A name lists it in /nw perf.
function UI.Pool(make, name)
  local list, n = {}, 0
  local function stats() return #list, n end
  if name and NW.Perf then NW.Perf.pools[#NW.Perf.pools + 1] = { name = name, stats = stats } end
  return function()
    n = n + 1
    local o = list[n] or make()
    list[n] = o
    o:Show()
    return o
  end, function()
    for i = 1, #list do list[i]:Hide() end
    n = 0
  end, stats
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

------------------------------------------------------------------------
-- Reagent strip: a recipe's reagents as their item icons in full colour, in
-- a grid (a second row of icons when they don't fit across), with the count
-- one craft takes on each, always shown, outlined. The state shows on the
-- icon's edge and count: "ok" plain, "made" a gold edge (steps before make
-- what's missing), "short" a red edge and a red count. The art itself never
-- changes. Icons are made once per strip and reused; a view passes one handler
-- table for tooltips and clicks, so nothing is created per refresh.
--   strip = UI.ReagentStrip(parent, handler, size)  handler.tip(icon), handler.click(icon, button)
--   strip:Begin()  strip:Add(id, qty, state)  strip:AddStatus(tex, kind)  rows = strip:Finish(width)
--   UI.ReagentRows(n, width, size): how many rows n icons take
-- Each icon carries id, qty, state, kind and whatever the view sets in icon.ctx.
------------------------------------------------------------------------
do
  local GAP = 6
  local QMARK = "Interface\\Icons\\INV_Misc_QuestionMark"
  local EDGE = { ok = { 0, 0, 0, 0.85 }, made = { 0.839, 0.698, 0.400, 1 }, short = { 0.820, 0.463, 0.396, 1 } }
  local COUNT = { ok = { 1, 1, 1, 1 }, made = { 1, 1, 1, 1 }, short = { 1, 0.55, 0.45, 1 } }
  local function iconOnEnter(self)
    local h = self.strip.handler
    if h and h.tip then h.tip(self) end
  end
  local function iconOnClick(self, button)
    local h = self.strip.handler
    if h and h.click then h.click(self, button) end
  end
  local function newIcon(strip)
    local size = strip.size
    local b = CreateFrame("Button", nil, strip)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp")
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetPoint("TOPLEFT", -1, 1)
    b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- one craft's count, where the game puts a stack's
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(FONT, size >= 26 and 13 or 10, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -1, 2)
    b.count:SetJustifyH("RIGHT")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    b.strip = strip
    b.ctx = {} -- what the view needs for its tooltip and click (wiped on reuse)
    b:SetScript("OnEnter", iconOnEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", iconOnClick)
    return b
  end
  local function nextIcon(strip)
    strip.n = strip.n + 1
    local b = strip.icons[strip.n]
    if not b then b = newIcon(strip); strip.icons[strip.n] = b end
    b.id, b.qty, b.state, b.kind = nil, nil, nil, nil
    for k in pairs(b.ctx) do b.ctx[k] = nil end
    return b
  end
  local Strip = {}
  function Strip:Begin()
    self.n = 0
  end
  function Strip:Add(id, qty, state)
    local b = nextIcon(self)
    state = state or "ok"
    b.id, b.qty, b.state, b.kind = id, qty or 1, state, "item"
    b.tex:SetTexture(NW.ItemIcon(id) or QMARK)
    b.edge:SetColorTexture(unpack(EDGE[state] or EDGE.ok))
    b.count:SetText(tostring(b.qty))
    b.count:SetTextColor(unpack(COUNT[state] or COUNT.ok))
    return b
  end
  -- a state that isn't a reagent (needs a recipe): its own icon, first in line
  function Strip:AddStatus(tex, kind)
    local b = nextIcon(self)
    b.kind, b.state = kind, "short"
    b.tex:SetTexture(tex or QMARK)
    b.edge:SetColorTexture(1, 0.5, 0.25, 1) -- a blocker: orange-edged, like the "needs recipe" it stands for
    b.count:SetText("")
    return b
  end
  function UI.ReagentRows(n, width, size)
    local cols = math.max(1, math.floor((width + GAP) / (size + GAP)))
    return math.max(1, math.ceil(n / cols)), cols
  end
  -- lay the icons out across width, wrapping to more rows; returns the rows
  function Strip:Finish(width)
    local size = self.size
    local rows, cols = UI.ReagentRows(self.n, width or 150, size)
    for k, b in ipairs(self.icons) do
      if k <= self.n then
        local c, r = (k - 1) % cols, math.floor((k - 1) / cols)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", c * (size + GAP) + 1, -r * (size + GAP) - 1)
        b:Show()
      else
        b:Hide()
      end
    end
    self.shown = self.n
    self:SetSize(width or 150, rows * (size + GAP))
    return rows
  end
  function Strip:Clear()
    self.n, self.shown = 0, 0
    for _, b in ipairs(self.icons) do b:Hide() end
  end
  function UI.ReagentStrip(parent, handler, size)
    local strip = CreateFrame("Frame", nil, parent)
    strip.size = size or 16
    strip:SetSize(150, strip.size + 2)
    for k, fn in pairs(Strip) do strip[k] = fn end
    strip.handler = handler
    strip.icons = {}
    strip.n, strip.shown = 0, 0
    return strip
  end
end
