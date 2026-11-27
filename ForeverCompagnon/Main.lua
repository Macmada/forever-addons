local _, root = ...
local K = root.Kit

-- ForeverCompagnon 4.0 : une fenêtre sombre et dorée. En haut, le personnage (nom, classe, niveau, rôle, zone) et le
-- menu des outils ; dessous, quatre onglets (Accueil, Équipement, Donjon, Soins) ; l'Accueil montre trois compteurs et au
-- plus cinq actions « à faire maintenant », une ligne chacune, avec leur bouton (Équiper, Itinéraire, Guide-moi).
-- Les actions viennent de root.NowLines() (Now.lua) ; en combat, l'écran garde le dernier état connu.

local FR = root.FR
local T = FR and {
  home = "Accueil", gear = "Équipement", dungeon = "Donjon", heal = "Soins",
  level = "%s niveau %d", todo = "À faire maintenant", hint = "clic : l'action · clic droit : le détail",
  cUp = "améliorations à ta portée", cBuy = "achats avant le donjon", cTrainer = "sorts chez le maître",
  cHps = "soins par seconde",
  equip = "Équiper", route = "Itinéraire", guide = "Guide-moi", open = "Ouvrir",
  none = "Rien d'urgent : tu es prêt.", combat = "En combat : dernier état connu.",
  errors = "%d partie(s) en erreur : menu Outils, Erreurs", foot = "/fp · Échap ferme",
  tools = "Outils", roleTip = "Clic : changer de rôle (règle les conseils d'équipement et de préparation).",
  mRoute = "Itinéraire : mes vols", mRouteD = "points de vol connus, le plus proche d'abord",
  mClear = "Effacer la flèche", mClearD = "retire la flèche de l'itinéraire",
  mFlash = "Cadre Flash", mFlashOn = "activé : caractéristiques à chaque changement d'objet", mFlashOff = "désactivé",
  mHealBot = "Configurer HealBot", mHealBotD = "skins en français, rôles, sorts sur les clics",
  mErrors = "Erreurs", mErrorsD = "relevé de tous les addons, à copier",
  mLog = "Journal", mLogD = "ce que l'addon a fait (diagnostic)",
  mAddons = "Addons", mAddonsD = "addons utiles sur Forever",
  mDiag = "Diagnostic", mDiagD = "état de l'addon, à copier pour un rapport",
  mTest = "Auto-test", mTestD = "vérifie l'addon sur ce client",
  mProbe = "Sonde du client", mProbeD = "ce que le jeu donne aux addons",
  mOptions = "Options…", mOptionsD = "Échap > Options > AddOns > ForeverCompagnon",
} or {
  home = "Home", gear = "Gear", dungeon = "Dungeon", heal = "Healing",
  level = "%s level %d", todo = "To do now", hint = "click: action · right-click: details",
  cUp = "upgrades within reach", cBuy = "purchases before the dungeon", cTrainer = "spells at the trainer",
  cHps = "healing per second",
  equip = "Equip", route = "Route", guide = "Guide me", open = "Open",
  none = "Nothing urgent: you are ready.", combat = "In combat: last known state.",
  errors = "%d part(s) failed: Tools menu, Errors", foot = "/fp · Esc closes",
  tools = "Tools", roleTip = "Click: change role (sets gear and preparation advice).",
  mRoute = "Route: my flights", mRouteD = "known flight points, nearest first",
  mClear = "Clear the arrow", mClearD = "removes the route arrow",
  mFlash = "Flash frame", mFlashOn = "on: stats on every gear change", mFlashOff = "off",
  mHealBot = "Set up HealBot", mHealBotD = "skins, roles, click spells",
  mErrors = "Errors", mErrorsD = "errors from every addon, to copy",
  mLog = "Log", mLogD = "what the addon did (diagnostics)",
  mAddons = "Addons", mAddonsD = "useful addons on Forever",
  mDiag = "Diagnostics", mDiagD = "addon state, to copy for a report",
  mTest = "Self-test", mTestD = "checks the addon on this client",
  mProbe = "Client probe", mProbeD = "what the game gives addons",
  mOptions = "Options…", mOptionsD = "Esc > Options > AddOns > ForeverCompagnon",
}
root.MainText = T

-- Couleurs (maquette du 27/11/2026)
local C = {
  bg = { 0.071, 0.078, 0.098 }, head = { 0.098, 0.110, 0.140 }, card = { 0.102, 0.114, 0.141 },
  line = { 0.18, 0.20, 0.24 }, frame = { 0.23, 0.20, 0.15 }, gold = { 0.84, 0.66, 0.29 }, goldL = { 0.94, 0.77, 0.42 },
  text = { 0.91, 0.89, 0.85 }, muted = { 0.64, 0.61, 0.55 }, green = { 0.37, 0.83, 0.54 }, orange = { 0.94, 0.65, 0.29 },
  blue = { 0.29, 0.64, 1 }, red = { 1, 0.42, 0.35 },
}
root.Theme = C
local function Hex(c) return string.format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

local W, H, PAD = 560, 532, 16
local ROWS = 5
local ui, menu
local page = "now"

local function Fill(region, c, a) region:SetColorTexture(c[1], c[2], c[3], a or 1) end
local function Text(parent, size, c, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if size then local f = fs:GetFont(); if f then fs:SetFont(f, size, "") end end
  if c then fs:SetTextColor(c[1], c[2], c[3]) end
  fs:SetJustifyH("LEFT")
  return fs
end
local function Box(parent, c, a, border)
  local f = CreateFrame("Frame", nil, parent)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  Fill(f.bg, c or C.card, a)
  f.edge = K.Border(f, (border or C.line)[1], (border or C.line)[2], (border or C.line)[3], 1)
  return f
end

root.UI = {}
local function HealerClass()
  local _, class = UnitClass("player")
  return class == "PRIEST" or class == "DRUID" or class == "PALADIN" or class == "SHAMAN"
end

root.UI.Fill, root.UI.Text, root.UI.Box, root.UI.Hex, root.UI.HealerClass = Fill, Text, Box, Hex, HealerClass

----------------------------------------------------------------------
-- Onglets
----------------------------------------------------------------------
local TABS = {
  { key = "now", label = T.home }, { key = "loot", label = T.gear }, { key = "prep", label = T.dungeon },
  { key = "heal", label = T.heal, healer = true },
}

local function MakeTab(parent, t)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(28)
  b.fs = Text(b, 13, C.muted, "GameFontNormal")
  b.fs:SetPoint("CENTER", 0, 1)
  b.fs:SetText(t.label)
  b:SetWidth(math.max(70, (b.fs:GetStringWidth() or 60) + 26))
  b.line = b:CreateTexture(nil, "ARTWORK")
  b.line:SetPoint("BOTTOMLEFT", 6, 0)
  b.line:SetPoint("BOTTOMRIGHT", -6, 0)
  b.line:SetHeight(2)
  Fill(b.line, C.gold)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0.3, 0.08)
  function b.SetActive(self, on)
    local c = on and C.goldL or C.muted
    self.fs:SetTextColor(c[1], c[2], c[3])
    self.line:SetShown(on)
  end
  b.tab = t
  b:SetScript("OnClick", function() root.Open(t.key) end)
  b:SetActive(t.key == "now")
  return b
end

----------------------------------------------------------------------
-- Compteurs et lignes d'action
----------------------------------------------------------------------
local function MakeCounter(parent)
  local f = Box(parent)
  f.top = f:CreateTexture(nil, "ARTWORK")
  f.top:SetPoint("TOPLEFT"); f.top:SetPoint("TOPRIGHT"); f.top:SetHeight(3)
  f.value = Text(f, 20, C.text, "GameFontHighlightLarge")
  f.value:SetPoint("TOPLEFT", 10, -10)
  f.label = Text(f, 11, C.muted, "GameFontHighlightSmall")
  f.label:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -3)
  f.label:SetPoint("RIGHT", -8, 0)
  f.label:SetWordWrap(false)
  return f
end

local function Tip(self)
  local l = self.line
  if not l then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if l.link and GameTooltip.SetHyperlink then
    GameTooltip:SetHyperlink(l.link)
  else
    GameTooltip:SetText((l.tip and l.tip.title) or l.name or "", C.goldL[1], C.goldL[2], C.goldL[3])
    for _, x in ipairs(l.tip and l.tip.lines or {}) do
      if type(x) == "table" then GameTooltip:AddLine(x[1], x[2] or 1, x[3] or 1, x[4] or 1, true)
      else GameTooltip:AddLine(x, 1, 1, 1, true) end
    end
  end
  GameTooltip:Show()
end

local function MakeRow(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(48)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  Fill(b.bg, C.card)
  K.Border(b, C.line[1], C.line[2], C.line[3], 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0.3, 0.07)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(32, 32)
  b.icon:SetPoint("LEFT", 9, 0)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local ringFrame = CreateFrame("Frame", nil, b)
  ringFrame:SetPoint("TOPLEFT", b.icon, -1, 1)
  ringFrame:SetPoint("BOTTOMRIGHT", b.icon, 1, -1)
  b.ring = K.Border(ringFrame, C.line[1], C.line[2], C.line[3], 1, "OVERLAY")
  b.action = Text(b, 12, C.blue, "GameFontNormalSmall")
  b.action:SetPoint("RIGHT", -12, 0)
  b.action:SetJustifyH("RIGHT")
  b.pill = b:CreateTexture(nil, "ARTWORK")
  b.pill:SetPoint("TOPLEFT", b.action, -8, 5)
  b.pill:SetPoint("BOTTOMRIGHT", b.action, 8, -5)
  Fill(b.pill, C.gold)
  b.gain = Text(b, 12, C.green, "GameFontNormalSmall")
  b.gain:SetJustifyH("RIGHT")
  b.name = Text(b, 13, C.text, "GameFontHighlight")
  b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, -1)
  b.name:SetWordWrap(false)
  b.sub = Text(b, 11, C.muted, "GameFontHighlightSmall")
  b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
  b.sub:SetWordWrap(false)
  b:SetScript("OnClick", function(self, button)
    local l = self.line
    if not l then return end
    if button == "RightButton" then if l.onRight then l.onRight() end
    elseif l.onClick then l.onClick() end
  end)
  b:SetScript("OnEnter", Tip)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- Bouton d'une action : Équiper (pastille dorée), Itinéraire, Guide-moi, sinon Ouvrir
local function ActionOf(l)
  if l.equip then return T.equip, true end
  if l.buy then return T.guide end
  if l.place or l.quests or l.trainer or l.vendor then return T.route end
  return T.open
end
root.HomeAction = ActionOf

local function SetRow(b, l)
  b.line = l
  b.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  local qc = (l.quality and l.quality >= 2 and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[l.quality]) or nil
  for _, t in ipairs(b.ring) do
    if qc then t:SetColorTexture(qc.r, qc.g, qc.b, 1) else t:SetColorTexture(C.line[1], C.line[2], C.line[3], 1) end
  end
  b.name:SetText(l.name or "")
  local sub = l.source or ""
  if l.tags and l.tags ~= "" then sub = l.tags .. (sub ~= "" and ("  " .. sub) or "") end
  b.sub:SetText(sub)
  local label, pill = ActionOf(l)
  b.action:SetText(label)
  if pill then b.action:SetTextColor(C.bg[1], C.bg[2], C.bg[3]) else b.action:SetTextColor(C.blue[1], C.blue[2], C.blue[3]) end
  b.pill:SetShown(pill and true or false)
  b.gain:SetText(l.gain or "")
  b.gain:ClearAllPoints()
  b.gain:SetPoint("RIGHT", b.action, "LEFT", pill and -18 or -12, 0)
  local right = (b.gain:GetStringWidth() or 0) + (b.action:GetStringWidth() or 0) + 52
  b.name:SetPoint("RIGHT", b, "RIGHT", -right, 0)
  b.sub:SetPoint("RIGHT", b, "RIGHT", -right, 0)
  b:Show()
end

root.UI.MakeCounter, root.UI.MakeRow, root.UI.Tip = MakeCounter, MakeRow, Tip

----------------------------------------------------------------------
-- Données de l'Accueil : 3 compteurs et 5 actions au plus
----------------------------------------------------------------------
function root.HomeData()
  local lines, stale, tiles = root.NowLines()
  local actions = {}
  for _, l in ipairs(lines or {}) do
    if l.kind == "card" and #actions < ROWS then actions[#actions + 1] = l end
  end
  local counters = {}
  local byKind = {}
  for _, t in ipairs(tiles or {}) do if t.kind then byKind[t.kind] = t end end
  local up, buy = byKind.up, byKind.buy
  counters[1] = { value = up and up.value or "0", label = T.cUp, color = C.green, open = "loot" }
  counters[2] = { value = buy and buy.value or "0", label = T.cBuy, color = C.orange, open = "prep" }
  local due = 0
  local prep = root.mods.ForeverPrep
  if prep and prep.TrainerDue then
    local ok, d = pcall(prep.TrainerDue)
    if ok and type(d) == "table" then due = #d end
  end
  if byKind.hps and (root.Role() == "heal") then
    counters[3] = { value = byKind.hps.value, label = T.cHps, color = C.blue, open = "heal" }
  else
    counters[3] = { value = tostring(due), label = T.cTrainer, color = C.blue, open = "prep" }
  end
  return actions, counters, stale
end

----------------------------------------------------------------------
-- Menu des outils (bouton engrenage)
----------------------------------------------------------------------
local function MenuItems()
  local items = {
    { T.mRoute, T.mRouteD, function() root.Nav.ListTaxi() end },
    { T.mClear, T.mClearD, function() root.Nav.Command("") end },
    { T.mFlash, (root.db and root.db.flash == false) and T.mFlashOff or T.mFlashOn, function()
      root.db.flash = (root.db.flash == false)
      root.Print(root.db.flash and root.L.flash_on or root.L.flash_off)
    end },
    { T.mErrors, T.mErrorsD, function() root.Debug.Command("") end },
    { T.mLog, T.mLogD, function() root.Debug.Command("log") end },
    { T.mAddons, T.mAddonsD, function() root.ShowAddons() end },
    { T.mDiag, T.mDiagD, function() root.ShowDiag() end },
    { T.mTest, T.mTestD, function() root.RunTests() end },
    { T.mProbe, T.mProbeD, function() root.ShowProbe() end },
    { T.mOptions, T.mOptionsD, function() root.ShowOptions() end },
  }
  if root.HealBot and root.HealBot.Command then
    table.insert(items, 3, { T.mHealBot, T.mHealBotD, function() root.HealBot.Command("") end })
  end
  return items
end

local function ShowMenu(anchor)
  if not menu then
    menu = CreateFrame("Frame", "ForeverCompagnonToolsMenu", ui)
    menu:SetFrameStrata("DIALOG")
    menu:SetWidth(250)
    menu.bg = menu:CreateTexture(nil, "BACKGROUND")
    menu.bg:SetAllPoints()
    Fill(menu.bg, { 0.114, 0.125, 0.161 }, 0.98)
    K.Border(menu, 0.23, 0.25, 0.29, 1)
    menu:EnableMouse(true)
    menu.rows = {}
  end
  local items = MenuItems()
  for i, it in ipairs(items) do
    local r = menu.rows[i]
    if not r then
      r = CreateFrame("Button", nil, menu)
      r:SetHeight(34)
      r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 34)
      r:SetPoint("RIGHT", -6, 0)
      -- survol : fond plus clair DERRIÈRE le texte (la couche HIGHLIGHT du jeu se dessine par-dessus le texte : opaque,
      -- elle le masquait, 27/11/2026)
      r.hover = r:CreateTexture(nil, "BACKGROUND")
      r.hover:SetAllPoints()
      r.hover:SetColorTexture(0.165, 0.184, 0.227, 1)
      r.hover:Hide()
      r:SetScript("OnEnter", function(self) self.hover:Show() end)
      r:SetScript("OnLeave", function(self) self.hover:Hide() end)
      r.title = Text(r, 12, C.text, "GameFontHighlight")
      r.title:SetPoint("TOPLEFT", 8, -4)
      r.desc = Text(r, 10, C.muted, "GameFontHighlightSmall")
      r.desc:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -2)
      r.desc:SetPoint("RIGHT", -6, 0)
      r.desc:SetWordWrap(false)
      menu.rows[i] = r
    end
    r.title:SetText(it[1])
    r.desc:SetText(it[2])
    r:SetScript("OnClick", function() menu:Hide(); local ok, e = pcall(it[3]); if not ok then root.Print(tostring(e)) end end)
    r:Show()
  end
  for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
  menu:SetHeight(12 + #items * 34)
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
  menu:Show()
end
root.ShowToolsMenu = function() if ui then ShowMenu(ui.gear) end end

----------------------------------------------------------------------
-- Fenêtre
----------------------------------------------------------------------
local function Subtitle()
  local className = UnitClass("player")
  local role = root.Role and root.Role()
  local parts = { string.format(T.level, className or "?", UnitLevel("player") or 0) }
  if role and root.L["role_" .. role] then parts[#parts + 1] = root.L["role_" .. role] end
  local zone = (GetRealZoneText and GetRealZoneText()) or ""
  if zone ~= "" then parts[#parts + 1] = zone end
  return table.concat(parts, " · ")
end

function root.RefreshNow()
  if not (ui and ui:IsShown()) then return end
  ui.name:SetText(UnitName("player") or "")
  ui.subBtn.fs:SetText(Subtitle())
  ui.subBtn:SetWidth((ui.subBtn.fs:GetStringWidth() or 200) + 4)
  if _G.SetPortraitTexture then pcall(_G.SetPortraitTexture, ui.portrait, "player") end
  local healer = HealerClass()
  local x = PAD
  for _, b in ipairs(ui.tabs) do
    local show = not b.tab.healer or healer
    b:SetShown(show)
    if show then b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", ui.tabBar, "BOTTOMLEFT", x, 0); x = x + b:GetWidth() + 4 end
  end
  if page ~= "now" then
    local p = root.Pages and root.Pages[page]
    if p then
      local ok, e = pcall(p.Refresh, ui.pages[page], ui)
      ui.status:SetText(ok and (root.pageStatus or "") or ("|cff" .. Hex(C.red) .. tostring(e) .. "|r"))
    end
    return
  end
  local actions, counters, stale = root.HomeData()
  for i, c in ipairs(ui.counters) do
    local d = counters[i]
    c.value:SetText(d.value)
    c.label:SetText(d.label)
    Fill(c.top, d.color)
    c.open = d.open
  end
  for i, r in ipairs(ui.rows) do
    if actions[i] then SetRow(r, actions[i]) else r:Hide(); r.line = nil end
  end
  ui.empty:SetShown(#actions == 0)
  local status = ""
  if stale then status = "|cff" .. Hex(C.orange) .. T.combat .. "|r"
  elseif #root.nowErrors > 0 then status = "|cff" .. Hex(C.red) .. string.format(T.errors, #root.nowErrors) .. "|r" end
  ui.status:SetText(status)
end

local function Create()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverCompagnonFrame", UIParent)
  root.SafeClose(ui)
  ui:SetSize(W, H)
  ui:SetPoint("CENTER", 25, 20)
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverCompagnonFrame")
  ui:Hide()
  ui.bg = ui:CreateTexture(nil, "BACKGROUND")
  ui.bg:SetAllPoints()
  Fill(ui.bg, C.bg, 0.97)
  K.Border(ui, C.frame[1], C.frame[2], C.frame[3], 1)

  -- en-tête : portrait, nom, « classe niveau · rôle · zone » (clic : rôle suivant), outils, fermer
  local head = CreateFrame("Frame", nil, ui)
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(62)
  head.bg = head:CreateTexture(nil, "BACKGROUND")
  head.bg:SetAllPoints()
  Fill(head.bg, C.head)
  ui.portrait = head:CreateTexture(nil, "ARTWORK")
  ui.portrait:SetSize(40, 40)
  ui.portrait:SetPoint("LEFT", PAD, 0)
  ui.portrait:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  local ring = CreateFrame("Frame", nil, head)
  ring:SetPoint("TOPLEFT", ui.portrait, -2, 2)
  ring:SetPoint("BOTTOMRIGHT", ui.portrait, 2, -2)
  K.Border(ring, C.gold[1], C.gold[2], C.gold[3], 1, "OVERLAY")
  ui.name = Text(head, 17, C.text, "GameFontNormalLarge")
  K.TitleFont(ui.name, 17, "GameFontNormalLarge")
  ui.name:SetTextColor(C.text[1], C.text[2], C.text[3])
  ui.name:SetPoint("TOPLEFT", ui.portrait, "TOPRIGHT", 12, -2)
  ui.subBtn = CreateFrame("Button", nil, head)
  ui.subBtn:SetHeight(16)
  ui.subBtn:SetPoint("TOPLEFT", ui.name, "BOTTOMLEFT", 0, -3)
  ui.subBtn.fs = Text(ui.subBtn, 11, C.muted, "GameFontHighlightSmall")
  ui.subBtn.fs:SetPoint("LEFT")
  ui.subBtn:SetScript("OnClick", function()
    local roles, cur = root.ClassRoles(), root.Role()
    local nextRole = roles[1]
    for i, r in ipairs(roles) do if r == cur then nextRole = roles[i % #roles + 1] end end
    if nextRole then root.SetRole(nextRole) end
    root.RefreshNow()
  end)
  K.Tooltip(ui.subBtn, root.L.role, T.roleTip)
  local close = CreateFrame("Button", nil, head, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() ui:Hide() end)
  ui.gear = CreateFrame("Button", nil, head)
  ui.gear:SetSize(30, 30)
  ui.gear:SetPoint("RIGHT", -40, 0)
  ui.gear.bg = ui.gear:CreateTexture(nil, "BACKGROUND")
  ui.gear.bg:SetAllPoints()
  Fill(ui.gear.bg, { 0.125, 0.141, 0.176 })
  K.Border(ui.gear, 0.23, 0.25, 0.29, 1)
  ui.gear.icon = ui.gear:CreateTexture(nil, "ARTWORK")
  ui.gear.icon:SetPoint("TOPLEFT", 4, -4)
  ui.gear.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  ui.gear.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  ui.gear.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  ui.gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  ui.gear:SetScript("OnClick", function(self) if menu and menu:IsShown() then menu:Hide() else ShowMenu(self) end end)
  K.Tooltip(ui.gear, T.tools)

  -- onglets
  ui.tabBar = CreateFrame("Frame", nil, ui)
  ui.tabBar:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, 0)
  ui.tabBar:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, 0)
  ui.tabBar:SetHeight(34)
  local sep = ui.tabBar:CreateTexture(nil, "ARTWORK")
  sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetHeight(1)
  Fill(sep, C.line)
  ui.tabs = {}
  for _, t in ipairs(TABS) do ui.tabs[#ui.tabs + 1] = MakeTab(ui.tabBar, t) end

  -- pages : l'Accueil ici, les autres dans Pages.lua
  ui.body = CreateFrame("Frame", nil, ui)
  ui.body:SetPoint("TOPLEFT", ui.tabBar, "BOTTOMLEFT", 0, 0)
  ui.body:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -1, 27)
  ui.home = CreateFrame("Frame", nil, ui.body)
  ui.home:SetAllPoints()
  ui.pages = { now = ui.home }
  for key, def in pairs(root.Pages or {}) do
    local f = CreateFrame("Frame", nil, ui.body)
    f:SetAllPoints()
    f:Hide()
    def.Create(f, ui)
    ui.pages[key] = f
  end

  -- compteurs
  local cw = math.floor((W - 2 * PAD - 2 * 10) / 3)
  ui.counters = {}
  for i = 1, 3 do
    local c = MakeCounter(ui.home)
    c:SetSize(cw, 54)
    c:SetPoint("TOPLEFT", ui.tabBar, "BOTTOMLEFT", PAD + (i - 1) * (cw + 10), -14)
    c:EnableMouse(true)
    c:SetScript("OnMouseUp", function(self) if self.open then root.Open(self.open) end end)
    ui.counters[i] = c
  end

  -- « À faire maintenant »
  ui.todo = Text(ui.home, 14, C.goldL, "GameFontNormal")
  K.TitleFont(ui.todo, 14, "GameFontNormal")
  ui.todo:SetTextColor(C.goldL[1], C.goldL[2], C.goldL[3])
  ui.todo:SetPoint("TOPLEFT", ui.counters[1], "BOTTOMLEFT", 0, -16)
  ui.todo:SetText(T.todo)
  local hint = Text(ui.home, 10, C.muted, "GameFontHighlightSmall")
  hint:SetPoint("RIGHT", ui, "RIGHT", -PAD, 0)
  hint:SetPoint("BOTTOM", ui.todo, "BOTTOM", 0, 0)
  hint:SetJustifyH("RIGHT")
  hint:SetText(T.hint)
  ui.rows = {}
  for i = 1, ROWS do
    local r = MakeRow(ui.home)
    r:SetPoint("TOPLEFT", ui.todo, "BOTTOMLEFT", 0, -10 - (i - 1) * 54)
    r:SetPoint("RIGHT", ui, "RIGHT", -PAD, 0)
    r:Hide()
    ui.rows[i] = r
  end
  ui.empty = Text(ui.home, 12, C.muted, "GameFontHighlight")
  ui.empty:SetPoint("TOPLEFT", ui.todo, "BOTTOMLEFT", 0, -16)
  ui.empty:SetText(T.none)

  -- pied
  local foot = CreateFrame("Frame", nil, ui)
  foot:SetPoint("BOTTOMLEFT", 1, 1)
  foot:SetPoint("BOTTOMRIGHT", -1, 1)
  foot:SetHeight(26)
  local fsep = foot:CreateTexture(nil, "ARTWORK")
  fsep:SetPoint("TOPLEFT"); fsep:SetPoint("TOPRIGHT"); fsep:SetHeight(1)
  Fill(fsep, C.line)
  ui.status = Text(foot, 10, C.muted, "GameFontHighlightSmall")
  ui.status:SetPoint("LEFT", PAD, 0)
  local keys = Text(foot, 10, C.muted, "GameFontHighlightSmall")
  keys:SetPoint("RIGHT", -PAD, 0)
  keys:SetJustifyH("RIGHT")
  keys:SetText(T.foot)

  ui:SetScript("OnShow", function() root.RefreshNow() end)
  ui:SetScript("OnHide", function() if menu then menu:Hide() end end)
  return ui
end

function root.CurrentPage() return page end

-- Affiche la fenêtre sur une page (now, loot, prep, heal) ; Soins seulement pour les classes qui soignent
function root.ShowPage(key)
  Create()
  if key == "heal" and not HealerClass() then key = "now" end
  if not ui.pages[key] then key = "now" end
  page = key
  for k, f in pairs(ui.pages) do f:SetShown(k == key) end
  for _, b in ipairs(ui.tabs) do b:SetActive(b.tab.key == key) end
  if ui:IsShown() then root.RefreshNow() else ui:Show() end
end
function root.ShowNow() root.ShowPage("now") end

-- 4.0 : réglages de l'ancienne interface remis à zéro (position, dernier onglet, cadre Flash). Ce que l'addon a appris
-- (maîtres de classe, vendeurs, lancers de sorts, objets de la banque) est gardé.
root.OnLogin(function()
  local db = root.db
  if db and db.uiVersion ~= 4 then
    db.pos, db.lastTab, db.flashPos = nil, nil, nil
    db.uiVersion = 4
  end
end)
