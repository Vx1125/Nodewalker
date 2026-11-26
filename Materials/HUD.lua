local _, NW = ...

------------------------------------------------------------------------
-- The session panel (Compass.lua) grows a few lines while you farm a
-- material: the active objective and the hunting route, with Next.
-- No second floating window.
------------------------------------------------------------------------
local S, UI = NW.STYLE, NW.UI
local M, H, GL = NW.Mat, NW.Hunt, NW.GatherLog
local panel = NW.sessionPanel
if not panel then return end

local BASE_H = panel:GetHeight()
local TOP = -30 - 5 * 15 - 8
local lines = {}
for i = 1, 5 do
  local l = UI.Text(panel, 11, S.dim)
  l:SetPoint("TOPLEFT", 12, TOP - (i - 1) * 15)
  local v = UI.Text(panel, 11, S.text, "RIGHT")
  v:SetPoint("TOPRIGHT", -12, TOP - (i - 1) * 15)
  lines[i] = { l, v }
end
local sep = panel:CreateTexture(nil, "ARTWORK")
sep:SetColorTexture(unpack(S.sep))
sep:SetHeight(1)
sep:SetPoint("TOPLEFT", 10, TOP + 5)
sep:SetPoint("TOPRIGHT", -10, TOP + 5)
local nextBtn = UI.Button(panel, "Next", 46, function() H.Advance() end, 16)
local skipBtn = UI.Button(panel, "Skip", 40, function() H.Advance(true) end, 16)
nextBtn.label:SetFont(UI.FONT, 10, "")
skipBtn.label:SetFont(UI.FONT, 10, "")
UI.Tip(nextBtn, "Next hunting ground", "Marks this one hunted and moves on.")
UI.Tip(skipBtn, "Skip", "Moves on without marking it hunted.")

local function fmtRevisit(sec)
  if sec <= 0 then return "back now" end
  return ("back ~%d min"):format(math.ceil(sec / 60))
end

local function update()
  local n = 0
  local function line(l, v)
    n = n + 1
    lines[n][1]:SetText(l)
    lines[n][2]:SetText(v)
  end
  local g = M.Active()
  if g then
    local p = M.Progress(g)
    local name = NW.ItemName(g.id) or ("item " .. g.id)
    line(S.HEX.gold .. name .. "|r", (p.done and S.HEX.good or "") .. p.shown .. " / " .. p.target .. "|r")
    local sess = GL.Session(g.id)
    if sess > 0 then line("This session", tostring(sess)) end
  end
  local r = H.Route()
  nextBtn:Hide(); skipBtn:Hide()
  if r then
    local here = H.Here()
    local label = ("Ground %d of %d"):format(r.cur, #r.stops)
    line(label, here == r.cur and S.HEX.good .. "here|r" or (r.zone or ""))
    local nx = (r.cur % #r.stops) + 1
    local back = H.Revisit(nx)
    if #r.stops > 1 and back then line("Then " .. nx, fmtRevisit(back)) end
    if #r.stops > 1 then
      n = n + 1
      lines[n][1]:SetText("")
      lines[n][2]:SetText("")
      nextBtn:ClearAllPoints()
      nextBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, TOP - (n - 1) * 15 + 1)
      skipBtn:SetPoint("RIGHT", nextBtn, "LEFT", -4, 0)
      nextBtn:Show(); skipBtn:Show()
    end
  end
  local s = NW.session
  local skins = s and s.events and s.events.skin or 0
  if skins > 0 and n < #lines then line("Skinned", tostring(skins)) end
  for i = n + 1, #lines do lines[i][1]:SetText(""); lines[i][2]:SetText("") end
  sep:SetShown(n > 0)
  panel:SetHeight(BASE_H + (n > 0 and (n * 15 + 8) or 0))
end
NW.UpdateMaterialHUD = update

local base = NW.UpdateSession
NW.UpdateSession = function(...)
  if base then base(...) end
  if panel:IsShown() then update() end
end
M.OnChange(function() if panel:IsShown() then update() end end)
H.OnChange(function() if panel:IsShown() then update() end end)
