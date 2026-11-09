local _, root = ...
local L = root.L
local K = root.Kit

-- Onglet « Addons » : les addons qui complètent les nôtres sur WoW Forever, s'ils sont là, actifs ou absents,
-- ce qu'ils apportent, leur adresse à copier (WoW n'ouvre pas de lien) et « Activer » pour un addon installé
-- mais désactivé (effet au prochain /reload). Un addon est reconnu par son dossier ou son titre (les auteurs
-- nomment parfois le dossier autrement, ex. DungeonJournal), ou par la variable globale qu'il crée.

local FR = root.FR
root.ADDONS = {
  { key = "att", builtin = true, name = "All The Things", match = { "allthethings" }, global = "ATTC", used = true,
    icon = "Interface\\Icons\\INV_Misc_Book_11", url = "https://www.curseforge.com/wow/addons/all-the-things",
    what = FR and "Où obtenir chaque objet et chaque recette (PNJ, quête, zone, réputation) : Équipement et Métiers."
              or "Where to get every item and recipe (NPC, quest, zone, reputation): Gear and Professions." },
  { key = "dj", builtin = true, name = "DungeonJournal", match = { "dungeonjournal", "dungeon journal" }, global = "ForeverDungeonJournal_NS", used = true,
    icon = "Interface\\Icons\\INV_Misc_Book_09", url = nil,
    what = FR and "Butin de chaque boss et récompenses de quête des donjons de Forever : l'onglet Équipement s'en sert pour tes améliorations à ton niveau."
              or "Every boss's loot and dungeon quest rewards on Forever: the Gear tab uses it for upgrades at your level." },
  { key = "auctionator", builtin = true, name = "Auctionator", match = { "auctionator" }, global = "Auctionator", used = true,
    icon = "Interface\\Icons\\INV_Misc_Coin_01", url = "https://www.curseforge.com/wow/addons/auctionator",
    what = FR and "Prix de l'hôtel des ventes : coût des achats (Préparation) et des crafts (Métiers)."
              or "Auction house prices: cost of purchases (Preparation) and crafts (Professions)." },
  { key = "syndicator", builtin = true, name = "Syndicator", match = { "syndicator" }, global = "Syndicator", used = true,
    icon = "Interface\\Icons\\INV_Misc_Bag_10", url = "https://www.curseforge.com/wow/addons/syndicator",
    what = FR and "Ta banque, ton courrier et tes autres personnages : un objet déjà possédé est signalé, les composants comptés."
              or "Your bank, mail and other characters: items you already own are flagged, reagents counted." },
  { key = "tomtom", builtin = true, name = "TomTom", match = { "tomtom" }, global = "TomTom", used = true,
    icon = "Interface\\Icons\\INV_Misc_Map_01", url = "https://www.curseforge.com/wow/addons/tomtom",
    what = FR and "Une flèche vers le vendeur quand tu cliques « Guide-moi » (Préparation)."
              or "An arrow to the vendor when you click \"Guide me\" (Preparation)." },
  { key = "healbot", name = "HealBot Continued", match = { "healbot" }, used = true, healer = true,
    icon = "Interface\\Icons\\Spell_Holy_FlashHeal", url = "https://www.curseforge.com/wow/addons/heal-bot-continued",
    what = FR and "Cadres de soins au clic. Clique sur la ligne puis « Configurer HealBot » : clics du prêtre et cadres de groupe/raid réglés pour toi."
              or "Click-to-heal frames. Click the line, then \"Set up HealBot\": priest clicks and party/raid frames set for you." },
  { key = "questie", name = "Questie", match = { "questie" }, global = "Questie",
    icon = "Interface\\Icons\\INV_Misc_Note_02", url = "https://www.curseforge.com/wow/addons/questie",
    what = FR and "Quêtes sur la carte et la minicarte (version WoW Forever)."
              or "Quests on the map and minimap (WoW Forever version)." },
  { key = "fmf", name = "Full Mana Forever", match = { "fullmanaforever" }, mana = true,
    icon = "Interface\\Icons\\INV_Potion_76", url = "https://www.curseforge.com/wow/addons/full-mana-forever",
    what = FR and "Barre de mana avec la règle des 5 secondes, et la bonne potion au bon moment (fait pour Forever)."
              or "Mana bar with the five-second rule, and the right potion at the right time (made for Forever)." },
  { key = "fcdm", name = "Forever Cooldown Manager", match = { "forevercdm" },
    icon = "Interface\\Icons\\Spell_Nature_TimeStop", url = "https://github.com/Thunderz96/ForeverCDM",
    what = FR and "Temps de recharge, buffs et débuffs en icônes, même en combat (fait pour Forever)."
              or "Cooldowns, buffs and debuffs as icons, even in combat (made for Forever)." },
}

local A = C_AddOns or {}
local function Lower(s) return tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower() end

-- État d'un addon : "on" (chargé), "off" (installé mais désactivé ou pas chargé), "absent" ; avec son nom de dossier
function root.AddonStatus(e)
  local folder
  local n = A.GetNumAddOns and A.GetNumAddOns() or 0
  for i = 1, n do
    local name, title = A.GetAddOnInfo(i)
    local ln, lt = Lower(name), Lower(title)
    for _, m in ipairs(e.match) do
      if ln:find(m, 1, true) or lt:find(m, 1, true) then folder = folder or name end
    end
  end
  local loaded = (e.global and _G[e.global] ~= nil) or (folder and A.IsAddOnLoaded and A.IsAddOnLoaded(folder))
  if loaded then return "on", folder end
  if folder then return "off", folder end
  return "absent"
end

local function Recommended(e)
  local _, class = UnitClass("player")
  if e.healer and not ({ PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true })[class] then return false end
  if e.mana and class == "WARRIOR" or e.mana and class == "ROGUE" then return false end
  return true
end

function root.AddonLines()
  local lines = {}                       -- (introduction remplacée par les tuiles actifs / désactivés / absents)
  -- remplacés par ForeverCompagnon (facultatifs : utilisés en plus s'ils sont là), puis utiles en complément
  local groups = { { title = L.addonsBuiltin, builtin = true }, { title = L.addonsMore, builtin = false } }
  for _, g in ipairs(groups) do
    lines[#lines + 1] = { kind = "head", icon = g.builtin and "Interface\\Icons\\INV_Misc_Book_09" or "Interface\\Icons\\INV_Misc_Gift_01",
                          title = g.title, text = g.title }
    for _, e in ipairs(root.ADDONS) do
      if (e.builtin and true or false) == g.builtin and Recommended(e) then
        local st, folder = root.AddonStatus(e)
        local tag = (st == "on" and ("|cff40d860" .. L.addonOn .. "|r")) or (st == "off" and ("|cffffc860" .. L.addonOff .. "|r"))
                    or ("|cffa0a0a0" .. L.addonAbsent .. "|r")
        lines[#lines + 1] = { kind = "card", icon = e.icon, quality = st == "on" and 2 or (st == "off" and 1 or 0), name = e.name,
                              bar = (st == "on" and { 0.25, 0.85, 0.38 }) or (st == "off" and { 1, 0.66, 0.24 }) or { 0.5, 0.5, 0.5 },
                              status = st,
                              source = e.builtin and (e.what .. "\n|cff40d860" .. L["builtin_" .. e.key] .. "|r") or e.what, gain = tag, gainSub = st == "absent" and L.addonClick or (st == "off" and L.addonEnable or nil),
                              onClick = function() root.SelectAddon(e, st, folder) end }
      end
    end
  end
  return lines
end

local ui
function root.SelectAddon(e, st, folder)
  if not ui then return end
  ui.sel = { e = e, st = st, folder = folder }
  ui.url:SetText(e.url or L.addonNoUrl)
  ui.url:SetFocus()
  ui.url:HighlightText()
  ui.urlLabel:SetText(string.format(L.addonUrlFor, e.name))
  ui.enable:SetShown(st == "off" and folder ~= nil and A.EnableAddOn ~= nil)
  local _, class = UnitClass("player")
  ui.healbot:SetShown(e.key == "healbot" and st == "on" and class == "PRIEST")
end

function root.RefreshAddons()
  if not (ui and ui:IsShown()) then return end
  local lines = root.AddonLines()
  local n = { on = 0, off = 0, absent = 0 }
  for _, l in ipairs(lines) do if l.status then n[l.status] = n[l.status] + 1 end end
  local defs = { { n.on, L.tileOn, { 0.25, 0.85, 0.38 } }, { n.off, L.tileOff, { 1, 0.66, 0.24 } }, { n.absent, L.tileAbsent, { 0.5, 0.5, 0.5 } } }
  local fw = ui:GetWidth()
  fw = (type(fw) == "number" and fw > 0) and fw or 600
  local tw = (fw - 32 - 12) / 3
  for i, t in ipairs(ui.tiles) do
    local d = defs[i]
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", 16 + (i - 1) * (tw + 6), -32)
    t:SetWidth(tw)
    t.value:SetText(tostring(d[1]))
    t.label:SetText(d[2])
    t.top:SetColorTexture(d[3][1], d[3][2], d[3][3], 1)
  end
  ui.list.Render(lines)
end

local function Create()
  if ui then return ui end
  local W, H = 600, 560
  ui = CreateFrame("Frame", "ForeverCompagnonAddonsFrame", UIParent, "BasicFrameTemplateWithInset")
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
  tinsert(UISpecialFrames, "ForeverCompagnonAddonsFrame")
  ui:Hide()
  K.Dress(ui, "Interface\\Icons\\Trade_Engineering", L.title .. " — " .. L.addons)
  ui.tiles = {}
  for i = 1, 3 do
    local t = CreateFrame("Frame", nil, ui)
    t:SetHeight(46)
    local bg = t:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.1, 0.08, 0.9)
    t.top = t:CreateTexture(nil, "ARTWORK")
    t.top:SetPoint("TOPLEFT", 1, -1); t.top:SetPoint("TOPRIGHT", -1, -1); t.top:SetHeight(3)
    K.Border(t, 0.45, 0.37, 0.24, 1, "BORDER")
    t.value = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    t.value:SetPoint("TOP", 0, -8)
    t.value:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.label:SetPoint("BOTTOM", 0, 6)
    t.label:SetTextColor(0.85, 0.78, 0.6)
    ui.tiles[i] = t
  end
  ui.list = K.CardList(ui, W - 60)
  ui.list.scroll:SetPoint("TOPLEFT", 16, -88)
  ui.list.scroll:SetPoint("BOTTOMRIGHT", -34, 74)
  K.Backdrop(ui, ui.list.scroll, 0.6, 6)
  ui.urlLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ui.urlLabel:SetPoint("BOTTOMLEFT", 20, 50)
  ui.urlLabel:SetText(L.addonPick)
  ui.url = CreateFrame("EditBox", nil, ui, "InputBoxTemplate")
  ui.url:SetSize(W - 170, 22)
  ui.url:SetPoint("BOTTOMLEFT", 24, 20)
  ui.url:SetAutoFocus(false)
  ui.url:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ui.url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  ui.url:SetScript("OnTextChanged", function(self, user)          -- adresse en lecture seule
    if user and ui.sel then self:SetText(ui.sel.e.url or L.addonNoUrl); self:HighlightText() end
  end)
  ui.enable = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.enable:SetSize(110, 22)
  ui.enable:SetPoint("BOTTOMRIGHT", -20, 20)
  ui.enable:SetText(L.addonEnableBtn)
  ui.enable:Hide()
  ui.enable:SetScript("OnClick", function()
    local s = ui.sel
    if not (s and s.folder) then return end
    pcall(A.EnableAddOn, s.folder, UnitName("player"))
    root.Print(L.addonEnabled, s.e.name)
    ui.enable:Hide()
  end)
  ui.healbot = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.healbot:SetSize(140, 22)
  ui.healbot:SetPoint("BOTTOMRIGHT", -20, 20)
  ui.healbot:SetText(root.HealBot and root.HealBot.T.button or "HealBot")
  ui.healbot:Hide()
  ui.healbot:SetScript("OnClick", function() root.HealBot.Setup() end)
  ui.healbot:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(root.HealBot.T.buttonTip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  ui.healbot:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui:SetScript("OnShow", function() root.RefreshAddons() end)
  return ui
end

function root.ShowAddons()
  Create()
  if ui:IsShown() then ui:Hide() else ui:Show() end
end
