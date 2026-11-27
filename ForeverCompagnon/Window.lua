local ADDON, root = ...
local L = root.L

-- 4.0 : une seule fenêtre (Main.lua) à quatre onglets : Accueil, Équipement, Donjon, Soins (Pages.lua). Ici : ouverture,
-- commandes, icône, diagnostic commun.

root.Shared.Diag(ADDON, root)
root.Shared.Widgets(ADDON, root)

root.TABS = {
  { key = "now" }, { key = "loot", mod = "ForeverLoot", toggle = "Toggle" }, { key = "prep", mod = "ForeverPrep", toggle = "Toggle" },
  { key = "heal", mod = "ForeverHeal", toggle = "TogglePanel" },
}
local PAGES = { now = true, loot = true, prep = true, heal = true }

-- Ouvre la fenêtre sur une partie (anciens noms : Maintenant, Métiers… : l'Accueil)
function root.Open(key)
  if not PAGES[key] then key = "now" end
  if root.db then root.db.lastTab = key end
  root.ShowPage(key)
end

-- Ouvre / ferme la fenêtre (icône Forever, liste des addons, /fp)
function root.Toggle()
  local f = _G.ForeverCompagnonFrame
  if f and f:IsShown() then f:Hide(); return end
  root.Open((root.db and root.db.lastTab) or "now")
end
function ForeverCompagnon_OnCompartmentClick() root.Toggle() end

-- Les commandes et icônes des parties (/floot, /bis, /prep, /fheal, fiche de prépa automatique) ouvrent la même fenêtre.
-- Les anciennes fenêtres des parties ne s'ouvrent plus.
local function Wrap()
  for _, t in ipairs(root.TABS) do
    local ns = t.mod and root.mods[t.mod]
    if ns and ns[t.toggle] and not ns._wrapped then
      ns._wrapped = true
      ns[t.toggle] = function()
        local f = _G.ForeverCompagnonFrame
        if f and f:IsShown() and root.CurrentPage() == t.key then f:Hide() else root.Open(t.key) end
      end
    end
  end
  local prep = root.mods.ForeverPrep
  if prep and prep.Show and not prep._wrappedShow then
    prep._wrappedShow = true
    prep.Show = function(_, reason) root.prepReason = reason; root.Open("prep") end
  end
  local loot = root.mods.ForeverLoot
  if loot and loot.ShowTab and not loot._wrappedTab then
    loot._wrappedTab = true
    loot.ShowTab = function(t) root.lootView = (t == "bis") and "goal" or "now"; root.Open("loot") end
  end
end

root.OnLoaded(function()
  Wrap()
end)
root.OnLogin(function()
  Wrap()
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
                gear = "loot", loot = "loot", prepa = "prep", ["prépa"] = "prep", prep = "prep" }
  local way = raw:match("^[Ww][Aa][Yy]%s*(.*)$")
  local hb = msg:match("^healbot%s*(.*)$")
  if way then root.Nav.Command(way)
  elseif msg == "addons" or msg == "addon" then root.ShowAddons()
  elseif msg == "options" or msg == "config" then root.ShowOptions()
  elseif msg == "fiche place" or msg == "sheet reset" then
    root.db.sheetPos = nil
    root.Print(root.FR and "Fiche Soins : remise à côté de la fiche du personnage." or "Healing sheet: back next to the character frame.")
  elseif msg == "outils" or msg == "tools" then root.Open("now"); root.ShowToolsMenu()
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
  elseif msg == "rapport" or msg == "report" or msg == "diag complet" then root.Debug.ShowReport()
  elseif msg == "log" or msg == "journal" or msg:match("^log ") or msg:match("^journal ") then root.Debug.Command(msg)
  elseif msg:match("^erreurs?%s*") or msg:match("^errors?%s*") then root.Debug.Command(msg:gsub("^%a+%s*", ""))
  else root.Print(L.help) end
end

root.Shared.Hub(ADDON, root)
