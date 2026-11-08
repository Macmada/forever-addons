local ADDON, root = ...
local L = root.L

-- Une seule fenêtre : une barre d'onglets verticale (Maintenant, Soins, Équipement, Préparation, Métiers) collée
-- à gauche de la fenêtre affichée. Chaque partie garde sa propre fenêtre ; une seule est visible à la fois,
-- à la même place. La barre suit la fenêtre (déplacement compris).

root.Shared.Diag(ADDON, root)
root.Shared.Widgets(ADDON, root)
local K = root.Kit

root.TABS = {
  { key = "now", label = L.now, icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", frame = "ForeverCompagnonNowFrame",
    open = function() root.ShowNow() end },
  { key = "heal", label = L.heal, icon = "Interface\\Icons\\Spell_Holy_GreaterHeal", frame = "ForeverHealPanel",
    mod = "ForeverHeal", toggle = "TogglePanel", classes = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true } },
  { key = "loot", label = L.loot, icon = "Interface\\Icons\\INV_Chest_Cloth_17", frame = "ForeverLootFrame",
    mod = "ForeverLoot", toggle = "Toggle" },
  { key = "prep", label = L.prep, icon = "Interface\\Icons\\INV_Potion_51", frame = "ForeverPrepFrame",
    mod = "ForeverPrep", toggle = "Toggle" },
  { key = "metiers", label = L.metiers, icon = "Interface\\Icons\\Trade_Tailoring", frame = "ForeverMetiersFrame",
    mod = "ForeverMetiers", toggle = "Toggle" },
  { key = "addons", label = L.addons, icon = "Interface\\Icons\\Trade_Engineering", frame = "ForeverCompagnonAddonsFrame",
    open = function() root.ShowAddons() end },
}
local byKey = {}
for _, t in ipairs(root.TABS) do byKey[t.key] = t end

local rail, current
local hooked = {}

local function Highlight()
  if not rail then return end
  for _, b in ipairs(rail.buttons) do b.sel:SetShown(current and b.tab.key == current.key) end
end

local function Rail()
  if rail then return rail end
  rail = CreateFrame("Frame", "ForeverCompagnonRail", UIParent)
  local _, myClass = UnitClass("player")
  local tabs = {}
  for _, t in ipairs(root.TABS) do if not t.classes or t.classes[myClass] then tabs[#tabs + 1] = t end end
  rail:SetSize(50, 16 + #tabs * 46)
  rail:SetFrameStrata("HIGH")
  K.Panel(rail, 0.92)
  rail.buttons = {}
  for i, t in ipairs(tabs) do
    local b = CreateFrame("Button", nil, rail)
    b:SetSize(38, 38)
    b:SetPoint("TOP", 0, -8 - (i - 1) * 46)
    b.tab = t
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(t.icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.sel = b:CreateTexture(nil, "OVERLAY")
    b.sel:SetPoint("TOPLEFT", -4, 4)
    b.sel:SetPoint("BOTTOMRIGHT", 4, -4)
    b.sel:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    b.sel:SetBlendMode("ADD")
    b.sel:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.3, 0.25)
    b:SetScript("OnClick", function() root.Open(t.key) end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(t.label)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rail.buttons[i] = b
  end
  rail:Hide()
  return rail
end

-- Place la fenêtre f à la position commune (celle de la dernière fenêtre affichée)
local function Place(f)
  local p = root.db and root.db.pos
  f:ClearAllPoints()
  if p and p.x and p.y then f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
  else f:SetPoint("CENTER", UIParent, "CENTER", 25, 20) end
end
local function SavePos(f)
  local x, y = f:GetLeft(), f:GetTop()
  if root.db and type(x) == "number" and type(y) == "number" then root.db.pos = { x = x, y = y } end
end

-- Une fenêtre de partie vient de s'afficher : elle devient l'onglet courant, les autres se ferment
local function Docked(t, f)
  -- panneau des soins collé à la fiche personnage (ouverte par C) : il reste là, sans barre ni déplacement
  local cf = _G.CharacterFrame
  if t.key == "heal" and cf and cf:IsShown() and f.attached ~= false and f:GetPoint() and select(2, f:GetPoint()) == cf then return end
  if current and current.key ~= t.key then
    local old = _G[current.frame]
    if old and old ~= f and old:IsShown() then
      SavePos(old)
      current = t                         -- avant Hide : son OnHide ne doit pas fermer la barre
      old:Hide()
      Place(f)
    end
  end
  current = t
  local r = Rail()
  r:ClearAllPoints()
  r:SetPoint("TOPRIGHT", f, "TOPLEFT", 2, -24)
  r:Show()
  Highlight()
end

-- Accroche une fenêtre de partie (créée à la première ouverture)
function root.Adopt(t)
  local f = _G[t.frame]
  if not f or hooked[f] then return f end
  hooked[f] = true
  f:HookScript("OnShow", function(self) Docked(t, self) end)
  f:HookScript("OnHide", function(self)
    SavePos(self)
    if current and current.key == t.key and rail then rail:Hide(); current = nil end
  end)
  f:HookScript("OnDragStop", function(self) SavePos(self) end)
  if f:IsShown() then Docked(t, f) end
  return f
end

function root.Open(key)
  local t = byKey[key] or byKey.now
  if root.db then root.db.lastTab = t.key end      -- onglet retenu : celui qu'on a ouvert en dernier
  local f = _G[t.frame]
  if f and f:IsShown() then root.Adopt(t); Docked(t, f); return end
  local prev = current and _G[current.frame]
  if prev and prev:IsShown() then SavePos(prev) end
  if t.open then t.open()
  else
    local ns = root.mods[t.mod]
    if ns and ns[t.toggle] then ns[t.toggle]() end
  end
  f = root.Adopt(t)
  if f and f:IsShown() and prev and prev ~= f then Place(f); Docked(t, f) end
end

-- Ouvre / ferme la fenêtre (icône Forever, liste des addons, /fp)
function root.Toggle()
  if current and _G[current.frame] and _G[current.frame]:IsShown() then _G[current.frame]:Hide(); return end
  root.Open((root.db and root.db.lastTab) or "now")
end
function ForeverCompagnon_OnCompartmentClick() root.Toggle() end

-- Les commandes des parties (/fheal, /floot, /prep, /metiers) passent aussi par la barre : on enveloppe leurs Toggle
local function Wrap()
  for _, t in ipairs(root.TABS) do
    local ns = t.mod and root.mods[t.mod]
    if ns and ns[t.toggle] and not ns["_pretre" .. t.toggle] then
      local orig = ns[t.toggle]
      ns["_pretre" .. t.toggle] = orig
      ns[t.toggle] = function(...)
        local r = orig(...)
        root.Adopt(t)
        return r
      end
    end
  end
end

-- Une seule icône : celle de la minicarte « Forever » ; l'icône séparée de Prépa est masquée la première fois
local function Icons()
  local prep = root.mods.ForeverPrep
  if prep and prep.db and prep.db.minimap and not prep.db.minimap.pretreDone then
    prep.db.minimap.pretreDone = true
    prep.db.minimap.hide = true
    if prep.UpdateMinimapButton then pcall(prep.UpdateMinimapButton) end
  end
  if prep and _G.ForeverHub and _G.ForeverHub.button then prep.minimapButton = _G.ForeverHub.button end
end

root.OnLoaded(function()
  Wrap()
end)
root.OnLogin(function()
  Wrap()
  C_Timer.After(2.5, Icons)
  -- les fenêtres ouvertes toutes seules (fiche de prépa à l'entrée en donjon…) s'accrochent aussi
  C_Timer.After(3, function() for _, t in ipairs(root.TABS) do root.Adopt(t) end end)
end)

-- Diagnostic commun : en-tête, puis celui de chaque partie
function root.DiagCollect(add)
  add("")
  add("Lien avec le jeu (méthodes utilisées) :")
  local keys = {}
  for k in pairs(root.Game.used) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do add("  " .. k .. " = " .. tostring(root.Game.used[k])) end
  for _, name in ipairs(root.order) do
    local ns = root.mods[name]
    if ns and ns.DiagText then
      add("")
      local ok, text = pcall(ns.DiagText)
      add(ok and text or ("Erreur " .. name .. " : " .. tostring(text)))
    end
  end
end

SLASH_FOREVERCOMPAGNON1 = "/fp"
SLASH_FOREVERCOMPAGNON2 = "/compagnon"
SLASH_FOREVERCOMPAGNON3 = "/foreverpretre"
SlashCmdList.FOREVERCOMPAGNON = function(msg)
  local raw = (msg or ""):match("^%s*(.-)%s*$")
  msg = raw:lower()
  local map = { [""] = "now", maintenant = "now", now = "now", soins = "heal", heal = "heal", equipement = "loot", ["équipement"] = "loot",
                gear = "loot", loot = "loot", prepa = "prep", ["prépa"] = "prep", prep = "prep", metiers = "metiers", ["métiers"] = "metiers",
                prof = "metiers", addons = "addons", addon = "addons" }
  local way = raw:match("^[Ww][Aa][Yy]%s*(.*)$")
  local hb = msg:match("^healbot%s*(.*)$")
  if way then root.Nav.Command(way)
  elseif hb then root.HealBot.Command(hb)
  elseif msg == "vols" or msg == "taxi" or msg == "flights" then root.Nav.ListTaxi()
  elseif msg == "flash" or msg == "annonce" then
    root.db.flash = (root.db.flash == false)
    root.Print(root.db.flash and L.flash_on or L.flash_off)
  elseif msg == "flash place" or msg == "flash reset" then
    root.db.flashPos = nil
    root.Print(L.flashReset)
  elseif msg == "flash test" or msg == "annonce test" then
    root.Flash.Show({ item = GetInventoryItemLink("player", 5), rows = { { "sta", "+12 " .. L.flash_sta .. " » " .. string.format(L.flash_staHp, "+120") },
      { "int", "+8 " .. L.flash_int .. " » " .. string.format(L.flash_intMana, "+120") }, { "armor", "-15 " .. L.flash_armor } } })
  elseif map[msg] then root.Open(map[msg])
  elseif msg == "test" then root.RunTests()
  elseif msg == "sonde" or msg == "probe" then root.ShowProbe()
  elseif msg == "diag" then root.ShowDiag()
  else root.Print(L.help) end
end

root.Shared.Hub(ADDON, root)
