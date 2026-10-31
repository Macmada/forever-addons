local _, ns = ...
local L = ns.L

-- Petit compteur de FPS à l'écran (Maj + glisser pour le déplacer)
local f

local function Create()
  f = CreateFrame("Frame", "ForeverGFXFPSFrame", UIParent, "BackdropTemplate")
  f:SetSize(120, 24)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  f:SetBackdropColor(0, 0, 0, 0.6)
  f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
  local pos = ns.db.overlayPos
  if pos then f:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else f:SetPoint("TOP", 0, -40) end

  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("CENTER")

  f:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    ns.db.overlayPos = { point, x, y }
  end)
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("ForeverGFX", 1, 0.82, 0)
    GameTooltip:AddLine(L.overlayTip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local acc = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    local fps = GetFramerate() or 0
    local color = (fps >= 60 and "|cff66ff66") or (fps >= 30 and "|cffffd100") or "|cffff5555"
    self.text:SetText(string.format("%s%d FPS|r  %.1f ms", color, fps, 1000 / math.max(fps, 1)))
  end)
end

function ns.UpdateOverlay()
  if ns.db.overlay and not f then Create() end
  if f then f:SetShown(ns.db.overlay and true or false) end
  if ns.UpdateSimple then ns.UpdateSimple() end
end
