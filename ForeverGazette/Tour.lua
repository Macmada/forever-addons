local _, ns = ...
local L = ns.L

-- Mini-tutoriel : encadre un élément de l'interface et affiche une bulle d'explication.
-- steps = { { target = frame ou function, title = "...", text = "...", before = function }, ... }

local tour, glow

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local Show

local function Build()
  glow = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  glow:SetFrameStrata("FULLSCREEN_DIALOG")
  glow:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
  glow:SetBackdropBorderColor(1, 0.82, 0, 1)
  local ag = glow:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0.3)
  a:SetDuration(0.6)
  glow.ag = ag
  glow:Hide()

  tour = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  tour:SetFrameStrata("FULLSCREEN_DIALOG")
  tour:SetFrameLevel(glow:GetFrameLevel() + 5)
  tour:SetSize(330, 130)
  tour:SetClampedToScreen(true)
  tour:EnableMouse(true)
  tour:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  tour:SetBackdropColor(0.05, 0.05, 0.12, 0.97)
  tour:SetBackdropBorderColor(1, 0.82, 0, 1)

  tour.title = tour:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tour.title:SetPoint("TOPLEFT", 12, -10)
  tour.step = tour:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  tour.step:SetPoint("TOPRIGHT", -12, -11)
  tour.text = tour:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tour.text:SetPoint("TOPLEFT", 12, -30)
  tour.text:SetWidth(306)
  tour.text:SetJustifyH("LEFT")
  tour.text:SetSpacing(2)

  tour.next = MakeButton(tour, L.tourNext, 96, function()
    tour.i = tour.i + 1
    if tour.i > #tour.steps then ns.EndTour() else Show() end
  end)
  tour.next:SetPoint("BOTTOMRIGHT", -10, 10)
  tour.skip = MakeButton(tour, L.tourSkip, 80, function() ns.EndTour() end)
  tour.skip:SetPoint("BOTTOMLEFT", 10, 10)
  tour:Hide()
end

function Show()
  while tour.i <= #tour.steps do
    local s = tour.steps[tour.i]
    if s.before then s.before() end
    local target = s.target
    if type(target) == "function" then target = target() end
    if target and target:IsVisible() then
      glow:ClearAllPoints()
      glow:SetPoint("TOPLEFT", target, "TOPLEFT", -7, 7)
      glow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 7, -7)
      glow:Show()
      glow.ag:Play()

      tour.title:SetText(s.title)
      tour.text:SetText(s.text)
      tour.step:SetText(tour.i .. " / " .. #tour.steps)
      tour:SetHeight(30 + tour.text:GetStringHeight() + 44)
      tour.next:SetText(tour.i == #tour.steps and L.tourDone or L.tourNext)

      tour:ClearAllPoints()
      local bottom = target:GetBottom() or 0
      local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
      if bottom * scale > tour:GetHeight() + 40 then
        tour:SetPoint("TOP", target, "BOTTOM", 0, -14)
      else
        tour:SetPoint("BOTTOM", target, "TOP", 0, 14)
      end
      tour:Show()
      return
    end
    tour.i = tour.i + 1
  end
  ns.EndTour()
end

function ns.StartTour(steps, onDone)
  if not tour then Build() end
  tour.steps, tour.i, tour.onDone = steps, 1, onDone
  Show()
end

function ns.EndTour()
  if not tour then return end
  local wasShown = tour:IsShown()
  glow.ag:Stop()
  glow:Hide()
  tour:Hide()
  if wasShown and tour.onDone then tour.onDone() end
end

function ns.TourShown() return tour and tour:IsShown() end
