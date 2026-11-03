-- Simulation hors jeu de ForeverMacros (Lua 5.1). Lancer depuis la racine : lua5.1 tests/macros_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check

-- Sorts du « client » : tous ceux de la bibliothèque existent (nom « Sort<id> »), sauf un, absent de Forever
local MISSING = 3411          -- Intervention (TBC)
_G.GetSpellInfo = function(x)
  if type(x) == "number" then if x == MISSING then return nil end return "Sort" .. x end
  if type(x) == "string" and x:match("^Sort%d+$") then return x end
end
_G.GetItemInfo = function() return nil end
_G.GetItemInfoInstant = function() return nil end
local ACC, CHR = {}, {}            -- macros générales (index 1…120) et du personnage (121…)
local function At(i) if i > 120 then return CHR, i - 120 end return ACC, i end
_G.GetNumMacros = function() return #ACC, #CHR end
_G.GetMacroInfo = function(i) local t, k = At(i); local m = t[k]; if m then return m.name, m.icon, m.body end end
_G.GetMacroIndexByName = function(n)
  for i, m in ipairs(ACC) do if m.name == n then return i end end
  for i, m in ipairs(CHR) do if m.name == n then return 120 + i end end
  return 0
end
_G.CreateMacro = function(n, icon, body, perChar)
  local t = perChar and CHR or ACC
  t[#t + 1] = { name = n, icon = icon, body = body }
  return (perChar and 120 or 0) + #t
end
_G.EditMacro = function(i, n, icon, body) local t, k = At(i); local m = t[k]; m.name = n or m.name; m.body = body or m.body; return i end
_G.DeleteMacro = function(i) local t, k = At(i); table.remove(t, k) end
_G.PickupMacro = function() end
_G.ClearCursor, _G.GetCursorInfo = function() end, function() end
_G.MAX_ACCOUNT_MACROS, _G.MAX_CHARACTER_MACROS = 120, 18
_G.LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Prêtre", WARRIOR = "Guerrier" }
W.class = "PRIEST"

local ns = W.load("ForeverMacros")
W.fire("ADDON_LOADED", "ForeverMacros")
W.fire("PLAYER_LOGIN")
W.run(3)
check(ForeverMacrosDB and ForeverMacrosDB.builder, "base créée")

-- constructeur
local body = ns.Build("Soins rapides", "Soins supérieurs")
check(body:find("#showtooltip", 1, true) and body:find("/cast", 1, true) and body:find("mod:shift", 1, true), "constructeur : macro avec modificateur")
local errs, warns = ns.Validate(body)
check(#errs == 0, "vérification : la macro construite est valide")
local bad = ns.Validate("/cast [@mouseover,help Soins")
check(#bad > 0, "vérification : crochet non fermé détecté")
local long = ns.Validate("/cast " .. string.rep("x", 260))
check(#long > 0, "vérification : plus de 255 octets refusé")

-- bibliothèque : macro dont un sort manque masquée, sorts remplacés par leur nom
local total, hidden, sample = 0, 0, nil
for cls, list in pairs(ns.Library) do
  for _, e in ipairs(list) do
    total = total + 1
    if ns.LibAvailable(e) then sample = sample or e else hidden = hidden + 1 end
  end
end
check(total >= 50, "bibliothèque : " .. total .. " macros")
check(hidden >= 1, "macro avec un sort absent de ce client masquée (" .. hidden .. ")")
local resolved = ns.ResolveLib(sample)
check(not resolved:find("{%d+}") and resolved:find("Sort%d+"), "numéros de sorts remplacés par leur nom")
local hasMissing = false
for _, list in pairs(ns.Library) do for _, e in ipairs(list) do if e.body:find("{" .. MISSING .. "}", 1, true) then hasMissing = true end end end
check(hasMissing, "le sort absent (Intervention) est bien utilisé par une macro de la bibliothèque")

-- sauvegarde et restauration de toutes les macros
CreateMacro("Test1", "icon", "/cast Sort100", false)
CreateMacro("Test2", "icon", "#showtooltip\n/cast Sort200", true)
ns._BackupAll()
local backup = _G.ForeverMacrosTextFrame and _G.ForeverMacrosTextFrame.edit and _G.ForeverMacrosTextFrame.edit:GetText()
check(backup and backup:find("^FMAC1") and backup:find("Test2", 1, true), "sauvegarde de toutes les macros en texte")
for i = #CHR, 1, -1 do DeleteMacro(120 + i) end
for i = #ACC, 1, -1 do DeleteMacro(i) end
ns._RestoreFrom(backup)
check(#ACC == 1 and #CHR == 1 and CHR[1].body:find("\n", 1, true), "restauration : macros générale et du personnage recréées, retours à la ligne gardés")

-- interface, diagnostic, icône commune
ns.Toggle()
check(true, "fenêtre ouverte sans erreur")
W.class = "PRIEST"
local diag = ns.DiagText()
check(diag:find("Sorts utilisés par les macros prêtes", 1, true) and diag:find(tostring(MISSING), 1, true), "diagnostic : sort absent signalé")
check(not diag:find("Erreur", 1, true), "diagnostic sans erreur")
check(_G.ForeverHub and ForeverHub.entries.ForeverMacros, "inscrit dans l'icône commune")
W.rprint("\nTOUT OK (" .. LANG .. ")")
