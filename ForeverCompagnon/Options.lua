local _, root = ...

-- Panneau Échap > Options > AddOns > ForeverCompagnon : tous les réglages au même endroit (avant : une fenêtre d'options
-- par partie et des commandes). Chaque case lit et écrit directement le réglage de la partie concernée.

local FR = root.FR
local T = FR and {
  intro = "Ton compagnon d'aventure. Ouvre-le avec /fp ou l'icône Forever de la minicarte.",
  open = "Ouvrir ForeverCompagnon",
  window = "Fenêtre", flash = "Cadre Flash : tes caractéristiques à chaque changement d'objet",
  gear = "Équipement", dungeon = "Donjon", heal = "Soins",
  announce = "Annoncer ce que change un objet pour tes soins", where = "Annonces à l'écran (sinon dans la discussion)",
  mana = "Alerte de mana basse en combat",
} or {
  intro = "Your adventure companion. Open it with /fp or the Forever minimap icon.",
  open = "Open ForeverCompagnon",
  window = "Window", flash = "Flash frame: your stats on every gear change",
  gear = "Gear", dungeon = "Dungeon", heal = "Healing",
  announce = "Announce what an item changes for your healing", where = "Announcements on screen (otherwise in chat)",
  mana = "Low mana alert in combat",
}
root.OptionsText = T

-- { section } ou { libellé, lire, écrire } ; une partie absente (classe sans soins…) : ligne retirée
local function Entries()
  local prep, loot, heal = root.mods.ForeverPrep, root.mods.ForeverLoot, root.mods.ForeverHeal
  local list = {
    { T.window },
    { T.flash, function() return root.db and root.db.flash ~= false end, function(v) root.db.flash = v end },
  }
  if loot and loot.db then
    list[#list + 1] = { T.gear }
    for _, o in ipairs({ { "optLootAlert", "lootAlert" }, { "optRoll", "rollHelp" }, { "optQuest", "questHelp" },
                         { "optTip", "tooltipHint" }, { "optHigher", "higher" } }) do
      local key = o[2]
      list[#list + 1] = { loot.L[o[1]], function() return loot.db[key] end,
                          function(v) loot.db[key] = v; loot.version = (loot.version or 0) + 1; if loot.ForgetMemo then loot.ForgetMemo() end end }
    end
  end
  if prep and prep.db then
    local PL = prep.L
    list[#list + 1] = { T.dungeon }
    for _, k in ipairs({ "autoInstance", "autoReady", "autoLFG", "merchant" }) do
      list[#list + 1] = { PL["opt" .. k:sub(1, 1):upper() .. k:sub(2)], function() return prep.db[k] end, function(v) prep.db[k] = v end }
    end
    list[#list + 1] = { PL.optFloat, function() return prep.db.float and prep.db.float.shown end,
                        function(v) prep.db.float = prep.db.float or {}; prep.db.float.shown = v; if prep.UpdateFloat then prep.UpdateFloat() end end }
  end
  if heal and heal.db and root.UI and root.UI.HealerClass() then
    list[#list + 1] = { T.heal }
    list[#list + 1] = { T.announce, function() return heal.db.announce end, function(v) heal.db.announce = v end }
    list[#list + 1] = { T.where, function() return heal.db.announceWhere ~= "chat" end, function(v) heal.db.announceWhere = v and "screen" or "chat" end }
    list[#list + 1] = { T.mana, function() return heal.db.manaAlert end,
                        function(v) heal.db.manaAlert = v; if heal.UpdateManaAlert then pcall(heal.UpdateManaAlert) end end }
  end
  return list
end
root.OptionEntries = Entries

local panel, category
local function Build()
  panel = CreateFrame("Frame", "ForeverCompagnonOptions")
  panel.name = "ForeverCompagnon"
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ForeverCompagnon")
  local intro = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  intro:SetText(T.intro)
  local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  open:SetSize(200, 24)
  open:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)
  open:SetText(T.open)
  open:SetScript("OnClick", function()
    if _G.SettingsPanel and _G.SettingsPanel:IsShown() and _G.HideUIPanel then _G.HideUIPanel(_G.SettingsPanel) end
    root.Open("now")
  end)
  panel.checks = {}
  panel.heads = {}
  panel:SetScript("OnShow", function(self)
    for _, c in ipairs(self.checks) do c:Hide() end
    for _, h in ipairs(self.heads) do h:Hide() end
    local y, nc, nh = -96, 0, 0
    for _, e in ipairs(Entries()) do
      if not e[2] then
        nh = nh + 1
        local h = self.heads[nh]
        if not h then h = self:CreateFontString(nil, "OVERLAY", "GameFontNormal"); self.heads[nh] = h end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 16, y - 8)
        h:SetText(e[1])
        h:Show()
        y = y - 30
      elseif e[1] then
        nc = nc + 1
        local cb = self.checks[nc]
        if not cb then
          cb = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
          cb:SetSize(24, 24)
          cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
          cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
          cb:SetScript("OnClick", function(b) if b.set then b.set(b:GetChecked() and true or false) end end)
          self.checks[nc] = cb
        end
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", 24, y)
        cb.label:SetText(e[1])
        cb.set = e[3]
        local ok, v = pcall(e[2])
        cb:SetChecked(ok and v and true or false)
        cb:Show()
        y = y - 28
      end
    end
  end)
  if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    category = _G.Settings.RegisterCanvasLayoutCategory(panel, "ForeverCompagnon")
    _G.Settings.RegisterAddOnCategory(category)
  elseif _G.InterfaceOptions_AddCategory then
    _G.InterfaceOptions_AddCategory(panel)
  end
end

-- Ouvre le panneau (menu Outils > Options, /fp options)
function root.ShowOptions()
  if not panel then Build() end
  if category and _G.Settings and _G.Settings.OpenToCategory then
    local id = category.GetID and category:GetID() or category.ID
    _G.Settings.OpenToCategory(id)
  elseif _G.InterfaceOptionsFrame_OpenToCategory then
    _G.InterfaceOptionsFrame_OpenToCategory(panel)
  else
    panel:Show()
  end
end

root.OnLogin(function() if not panel then Build() end end)
