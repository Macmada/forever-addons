-- Généré par tools/sync-shared.sh depuis tools/Hub.lua : ne pas modifier ici.
local _, root = ...
root.Shared.Hub = function(...)
local ADDON, ns = ...

-- Icône commune « Forever » autour de la minicarte (copiée dans chaque addon par tools/sync-shared.sh).
-- Le premier addon chargé crée l'icône ; chacun s'y inscrit, avec une entrée dans son menu. À la première connexion,
-- l'icône propre de l'addon est masquée (réglage minimap.hide) : sa commande « minimap » la réaffiche si on la préfère.

local FR = GetLocale() == "frFR"
local ENTRIES = {
  ForeverGazette = { order = 1, label = FR and "Gazette" or "Gazette", icon = "Interface\\Icons\\INV_Misc_Book_09", open = "Toggle" },
  ForeverCompagnon = { order = 2, label = FR and "Compagnon (équipement, prépa, métiers, soins, addons)" or "Companion (gear, prep, professions, healing, addons)",
                   icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", open = "Toggle" },
  ForeverMacros = { order = 4, label = FR and "Macros" or "Macros", icon = "Interface\\Icons\\INV_Misc_Note_01", open = "Toggle" },
  ForeverGFX = { order = 5, label = FR and "Graphismes" or "Graphics", icon = "Interface\\Icons\\INV_Misc_Spyglass_03", open = "ToggleUI" },
}
local T = {
  title = "Forever",
  tip1 = FR and "Clic : menu des addons Forever" or "Click: Forever addons menu",
  tip2 = FR and "Glisser : déplacer l'icône" or "Drag: move the icon",
  hidden = FR and "Icône Forever masquée (/forever minimap pour la remettre)." or "Forever icon hidden (/forever minimap to bring it back).",
  shown = FR and "Icône Forever affichée." or "Forever icon shown.",
  separate = FR and "Icônes séparées remises pour : %s (/forever commune pour revenir à l'icône commune)."
                 or "Separate icons restored for: %s (/forever common to go back to the shared icon).",
  common = FR and "Icône commune : les icônes séparées sont masquées." or "Shared icon: separate icons are hidden.",
  help = FR and "Commandes : /forever (menu), /forever minimap, /forever separees, /forever commune"
             or "Commands: /forever (menu), /forever minimap, /forever separate, /forever common",
}

local hub = _G.ForeverHub
if not hub then
  hub = { entries = {}, addons = {} }
  _G.ForeverHub = hub
end

local function Place()
  local s = hub.settings
  local a = math.rad(s.angle or 200)
  local r = (Minimap:GetWidth() / 2) + 10
  hub.button:ClearAllPoints()
  hub.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function CloseMenu() if hub.menu then hub.menu:Hide() end end

local function ShowMenu(anchor)
  if not hub.menu then
    local m = CreateFrame("Frame", "ForeverHubMenu", UIParent, "BackdropTemplate")
    m:SetFrameStrata("DIALOG")
    m:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    m:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.title:SetPoint("TOPLEFT", 12, -10)
    m.title:SetText(T.title)
    m.rows = {}
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverHubMenu") end
    hub.menu = m
  end
  local m = hub.menu
  local list = {}
  for name, e in pairs(hub.entries) do list[#list + 1] = { name = name, e = e } end
  table.sort(list, function(a, b) return a.e.order < b.e.order end)
  for _, r in ipairs(m.rows) do r:Hide() end
  for i, item in ipairs(list) do
    local r = m.rows[i]
    if not r then
      r = CreateFrame("Button", nil, m)
      r:SetSize(170, 22)
      r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(18, 18)
      r.icon:SetPoint("LEFT", 2, 0)
      r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      r.text:SetPoint("LEFT", 26, 0)
      m.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 10, -28 - (i - 1) * 24)
    r.icon:SetTexture(item.e.icon)
    r.text:SetText(item.e.label)
    r:SetScript("OnClick", function() CloseMenu(); item.e.run() end)
    r:Show()
  end
  m:SetSize(190, 38 + #list * 24)
  m:ClearAllPoints()
  m:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 8, 8)
  m:SetShown(not m:IsShown())
end
hub.ShowMenu = ShowMenu

local function CreateHubButton()
  if hub.button or not Minimap then return end
  local b = CreateFrame("Button", "ForeverHubMinimapButton", Minimap)
  hub.button = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetScript("OnClick", function(self) GameTooltip:Hide(); ShowMenu(self) end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      hub.settings.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(T.title, 1, 0.82, 0)
    GameTooltip:AddLine(T.tip1, 1, 1, 1)
    GameTooltip:AddLine(T.tip2, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Place()
  b:SetShown(not hub.settings.hide)
end

-- Réglages de l'addon : ns.db, sinon sa variable de sauvegarde (ForeverMacrosDB…)
local function AddonDB(name, addonNs) return addonNs.db or _G[name .. "DB"] end

-- Masque (ou réaffiche) l'icône propre d'un addon, y compris sous LibDBIcon
local function SetOwnIcon(name, a, show)
  local db = AddonDB(name, a.ns)
  if not db or not db.minimap then return end
  db.minimap.hide = not show
  local own = _G[name .. "MinimapButton"]
  if own then own:SetShown(show) end
  local DBI = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
  if DBI and db.ldbIcon then
    db.ldbIcon.hide = not show
    pcall(show and DBI.Show or DBI.Hide, DBI, name)
  end
end

local function Register()
  local e = ENTRIES[ADDON]
  local db = AddonDB(ADDON, ns)
  if not e or not db then return end
  hub.entries[ADDON] = { order = e.order, label = e.label, icon = e.icon, run = function() if ns[e.open] then ns[e.open]() end end }
  hub.addons[ADDON] = { ns = ns }
  db.hub = db.hub or {}
  if not hub.settings then hub.settings = db.hub end                -- réglages de l'icône : ceux du premier addon chargé
  if db.minimap and not db.minimap.hubDone then
    db.minimap.hubDone = true
    SetOwnIcon(ADDON, hub.addons[ADDON], false)                     -- première fois : l'icône commune remplace la sienne
  end
  CreateHubButton()
  if db.minimap and db.minimap.hide and hub.button then ns.minimapButton = hub.button end   -- tutoriels
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() C_Timer.After(1.5, Register) end)

if not SlashCmdList.FOREVERHUB then
  SLASH_FOREVERHUB1 = "/forever"
  SlashCmdList.FOREVERHUB = function(msg)
    msg = ((msg or ""):match("^%s*(.-)%s*$")):lower()
    local print = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Forever|r " .. s) end
    if msg == "" then
      if hub.button then ShowMenu(hub.button) end
    elseif msg == "minimap" then
      hub.settings.hide = not hub.settings.hide
      if hub.button then hub.button:SetShown(not hub.settings.hide) end
      print(hub.settings.hide and T.hidden or T.shown)
    elseif msg == "separees" or msg == "séparées" or msg == "separate" then
      local names = {}
      for name, a in pairs(hub.addons) do SetOwnIcon(name, a, true); names[#names + 1] = name end
      table.sort(names)
      hub.settings.hide = true
      if hub.button then hub.button:Hide() end
      print(string.format(T.separate, table.concat(names, ", ")))
    elseif msg == "commune" or msg == "common" then
      for name, a in pairs(hub.addons) do SetOwnIcon(name, a, false) end
      hub.settings.hide = false
      if hub.button then hub.button:Show() end
      print(T.common)
    else
      print(T.help)
    end
  end
end

end
