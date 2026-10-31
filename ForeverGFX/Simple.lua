local _, ns = ...
local L = ns.L

-- Vue simple : niveaux de qualité en cartes + trois outils. Le mode expert reste accessible.

local sp, helpBtn, expertBtn, tuneBtn, overlayCheck
local cards, tools = {}, {}

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Card(parent, w, h)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetSize(w, h)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.12, 0.12, 0.16, 0.95)
  f:SetBackdropBorderColor(0.5, 0.5, 0.6, 1)
  return f
end

local function Text(parent, font, x, y, width, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint("TOPLEFT", x, y)
  if width then fs:SetWidth(width) end
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  if text then fs:SetText(text) end
  return fs
end

local function Tool(parent, x, y, title, desc)
  local c = Card(parent, 298, 118)
  c:SetPoint("TOPLEFT", x, y)
  c.title = Text(c, "GameFontNormal", 10, -10, 200, title)
  c.desc = Text(c, "GameFontHighlightSmall", 10, -30, 278, desc)
  c.desc:SetHeight(48)
  return c
end

function ns.BuildSimple(ui)
  sp = CreateFrame("Frame", nil, ui)
  sp:SetPoint("TOPLEFT", 6, -26)
  sp:SetPoint("BOTTOMRIGHT", -6, 6)
  sp:SetFrameLevel(ui:GetFrameLevel() + 50)
  sp:EnableMouse(true)
  sp:EnableMouseWheel(true)
  local bg = sp:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.07, 0.07, 0.09, 1)

  Text(sp, "GameFontNormalLarge", 14, -10, nil, L.simpleTitle)
  Text(sp, "GameFontHighlightSmall", 14, -32, 590, L.simpleIntro)

  -- Réglage automatique
  tuneBtn = MakeButton(sp, L.tuneBtn, 300, function(self)
    if ns.tuner.running then return ns.TunerStart() end
    local items = {}
    for _, fps in ipairs({ 30, 45, 60, 75, 90, 120, 144 }) do
      items[#items + 1] = { text = string.format(L.tuneFps, fps), value = fps, checked = fps == 60 }
    end
    ns.OpenMenu(self, items, function(v) ns.TunerStart(v) end)
  end)
  tuneBtn:SetHeight(26)
  tuneBtn:SetPoint("TOPRIGHT", -12, -8)
  Text(sp, "GameFontDisableSmall", 616, -38, 290, L.tuneHint)

  -- Niveaux de qualité
  for i, p in ipairs(ns.Presets) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local c = Card(sp, 298, 134)
    c:SetPoint("TOPLEFT", 12 + col * 306, -80 - row * 142)
    c.preset = p
    Text(c, "GameFontNormalLarge", 12, -10, 200, ns.PresetLabel(p))
    c.badge = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.badge:SetPoint("TOPRIGHT", -12, -13)
    if p.key == "qualite" then c.badge:SetText(L.recommended) end
    local d = Text(c, "GameFontHighlightSmall", 12, -36, 274, ns.Pick(p.desc, p.desc_en))
    d:SetHeight(52)
    c.active = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.active:SetPoint("BOTTOMLEFT", 12, 15)
    c.btn = MakeButton(c, L.apply, 110, function() ns.ApplyPreset(p, true) end)
    c.btn:SetPoint("BOTTOMRIGHT", -10, 10)
    cards[i] = c
  end

  -- Outils
  Text(sp, "GameFontNormalLarge", 14, -370, nil, L.toolsTitle)

  local tb = Tool(sp, 12, -394, L.toolBenchTitle, L.toolBenchDesc)
  tb.btn = MakeButton(tb, L.bench, 130, function() ns.BenchToggle() end)
  tb.btn:SetPoint("BOTTOMRIGHT", -10, 10)
  local tbr = MakeButton(tb, L.results, 100, function() ns.ShowBenchResults() end)
  tbr:SetPoint("RIGHT", tb.btn, "LEFT", -6, 0)
  overlayCheck = CreateFrame("CheckButton", nil, tb, "UICheckButtonTemplate")
  overlayCheck:SetSize(22, 22)
  overlayCheck:SetPoint("TOPRIGHT", -6, -6)
  local ol = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ol:SetPoint("RIGHT", overlayCheck, "LEFT", -2, 0)
  ol:SetText(L.overlay)
  overlayCheck:SetScript("OnClick", function(self)
    ns.db.overlay = self:GetChecked() and true or false
    ns.UpdateOverlay()
  end)
  overlayCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L.overlayTip, 1, 1, 1, 1, true); GameTooltip:Show()
  end)
  overlayCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tools.bench = tb

  local ta = Tool(sp, 318, -394, L.toolAutoTitle, L.toolAutoDesc)
  ta.status = ta:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ta.status:SetPoint("TOPRIGHT", -12, -12)
  ta.btn = MakeButton(ta, L.configure, 130, function() ns.ShowContext() end)
  ta.btn:SetPoint("BOTTOMRIGHT", -10, 10)
  tools.auto = ta

  local tu = Tool(sp, 624, -394, L.toolUndoTitle, L.toolUndoDesc)
  tu.btn = MakeButton(tu, L.undo, 130, function() ns.Undo() end)
  tu.btn:SetPoint("BOTTOMRIGHT", -10, 10)
  local tur = MakeButton(tu, L.resetAll, 130, function() StaticPopup_Show("FOREVERGFX_RESET") end)
  tur:SetPoint("RIGHT", tu.btn, "LEFT", -6, 0)
  tools.undo = tu

  -- Bas de fenêtre
  expertBtn = MakeButton(sp, L.expertBtn, 150, function()
    ns.db.expert = true
    ns.ApplyView()
  end)
  expertBtn:SetPoint("BOTTOMRIGHT", -12, 12)
  local eh = sp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  eh:SetPoint("RIGHT", expertBtn, "LEFT", -10, 0)
  eh:SetText(L.expertHint)
  local mh = sp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  mh:SetPoint("BOTTOMLEFT", 14, 18)
  mh:SetText(L.minimapHint)

  -- Boutons posés sur la fenêtre elle-même (visibles dans les deux vues)
  helpBtn = MakeButton(ui, "?", 24, function() ns.RunTour() end)
  helpBtn:SetPoint("TOPRIGHT", -28, -2)
  helpBtn:SetFrameLevel(ui:GetFrameLevel() + 60)
  helpBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L.helpTip); GameTooltip:Show()
  end)
  helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ns.simpleBtn = MakeButton(ui, L.simpleBtn, 120, function()
    ns.db.expert = false
    ns.ApplyView()
  end)
  ns.simpleBtn:SetHeight(18)
  ns.simpleBtn:SetPoint("TOPLEFT", 8, -3)
  ns.simpleBtn:SetFrameLevel(ui:GetFrameLevel() + 60)

  ns.ApplyView()
end

function ns.ApplyView()
  if not sp then return end
  local expert = ns.db.expert and true or false
  sp:SetShown(not expert)
  ns.simpleBtn:SetShown(expert)
  ns.UpdateSimple()
end

function ns.UpdateSimple()
  if not sp or not sp:IsShown() then return end
  local last = ns.state.lastLabel
  for _, c in ipairs(cards) do
    local isActive = last == string.format(L.presetPrefix, ns.PresetLabel(c.preset))
    c.active:SetText(isActive and L.active or "")
    if isActive then c:SetBackdropBorderColor(0.4, 1, 0.4, 1) else c:SetBackdropBorderColor(0.5, 0.5, 0.6, 1) end
  end
  tools.auto.status:SetText(ns.db.context.enabled and L.autoOn or L.autoOff)
  local b = ns.bench
  local tuning = ns.tuner and ns.tuner.running
  tools.bench.btn:SetText((b.running and not tuning) and string.format(L.benchRunning, b.left or b.duration) or L.bench)
  tuneBtn:SetText(tuning and string.format(L.tuneRunning, ns.tuner.step, ns.TUNE_STEPS, b.left or 0) or L.tuneBtn)
  overlayCheck:SetChecked(ns.db.overlay and true or false)
end

function ns.RunTour()
  if not sp then return end
  ns.db.expert = false
  ns.ApplyView()
  ns.StartTour({
    { target = function() return cards[3] or cards[1] end, title = L.g1t, text = L.g1 },
    { target = function() return tuneBtn end, title = L.g8t, text = L.g8 },
    { target = function() return tools.bench.btn end, title = L.g2t, text = L.g2 },
    { target = function() return tools.auto.btn end, title = L.g3t, text = L.g3 },
    { target = function() return tools.undo.btn end, title = L.g4t, text = L.g4 },
    { target = function() return expertBtn end, title = L.g5t, text = L.g5 },
    { target = function() return ns.minimapButton end, title = L.g6t, text = L.g6 },
    { target = function() return helpBtn end, title = L.g7t, text = L.g7 },
  }, function() ns.db.tourDone = true end)
end

function ns.OnMainShow()
  ns.ApplyView()
  if not ns.db.tourDone then
    C_Timer.After(0.2, function()
      if ns.mainFrame and ns.mainFrame:IsShown() then ns.RunTour() end
    end)
  end
end
