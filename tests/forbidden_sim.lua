-- Client de WoW Forever (05/11/2026) : s'abonner au journal de combat est interdit aux addons (« … a été bloqué à cause
-- d'une action qui n'est utilisable que par l'IU de Blizzard » à chaque connexion). Aucun addon ne doit s'y abonner
-- quand CombatLogGetCurrentEventInfo n'existe pas. Lancer depuis la racine : lua5.1 tests/forbidden_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check
_G.CombatLogGetCurrentEventInfo = nil
_G.C_CombatLog = { GetCurrentEventInfo = function() error("réservé à Blizzard") end }
local registered = {}
local realCreate = _G.CreateFrame
_G.CreateFrame = function(...)
  local f = realCreate(...)
  f.RegisterEvent = function(_, e) registered[e] = (registered[e] or 0) + 1 end
  return f
end
_G.GetItemInfo = function() return nil end
_G.GetItemInfoInstant = function() return nil end
_G.GetInventoryItemLink = function() return nil end
_G.UnitGUID = function() return "Player-1" end
local addons = { "ForeverCompagnon", "ForeverGazette", "ForeverMacros", "ForeverGFX" }
local loaded = {}
for _, a in ipairs(addons) do
  local ok, ns = pcall(W.load, a)
  if ok then loaded[a] = ns; pcall(W.fire, "ADDON_LOADED", a) end
end
pcall(W.fire, "PLAYER_LOGIN")
check(registered.ADDON_LOADED and registered.ADDON_LOADED >= 5, "addons chargés (" .. tostring(registered.ADDON_LOADED) .. " abonnements à ADDON_LOADED)")
check(not registered.COMBAT_LOG_EVENT_UNFILTERED, "aucun addon ne s'abonne au journal de combat (interdit sur ce client)")
check(registered.ADDON_ACTION_FORBIDDEN == 1, "actions bloquées suivies une seule fois (fenêtre commune)")
-- le jeu signale une action bloquée : elle apparaît dans le diagnostic de chaque addon
W.fire("ADDON_ACTION_FORBIDDEN", "ForeverHeal", "UneFonction()")
local diag = loaded.ForeverCompagnon.mods.ForeverHeal.DiagText()
check(diag:find("ADDON_ACTION_FORBIDDEN ForeverHeal UneFonction()", 1, true), "diagnostic : action bloquée notée avec la fonction")
check(loaded.ForeverGazette.DiagText():find("UneFonction()", 1, true), "diagnostic d'un autre addon : même liste")
W.rprint("\nTOUT OK (" .. LANG .. ")")
