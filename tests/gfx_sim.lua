-- Simulation hors jeu de ForeverGFX (Lua 5.1). Lancer depuis la racine : lua5.1 tests/gfx_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check

-- Variables du « client » : toutes celles de la base (valeur 1 par défaut), plus une absente et une inconnue
local ns = W.load("ForeverGFX")
W.cvarDefaults = {}
for name in pairs(ns.Descriptions) do W.cvars[name] = "1"; W.cvarDefaults[name] = "1" end
W.cvars.graphicsQuality, W.cvarDefaults.graphicsQuality = "5", "5"
W.cvars.renderScale, W.cvarDefaults.renderScale = "1", "1"
local absent = next(ns.Descriptions) == "graphicsQuality" and "graphicsShadowQuality" or "graphicsLiquidDetail"
W.cvars[absent], W.cvarDefaults[absent] = nil, nil
W.cvars.rtNouvelleVariable, W.cvarDefaults.rtNouvelleVariable = "2", "2"      -- variable graphique « Forever » inconnue

W.fire("ADDON_LOADED", "ForeverGFX")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD")
W.run(3)
check(ForeverGFXDB and ns.db and ns.db.profiles, "base créée")

-- préréglages
local before = W.cvars.graphicsQuality
SlashCmdList.FOREVERGFX("preset ultra")
check(W.cvars.graphicsQuality ~= before, "préréglage Ultra appliqué (graphicsQuality " .. before .. " -> " .. W.cvars.graphicsQuality .. ")")
check(#ns.history >= 1, "historique d'annulation alimenté")
SlashCmdList.FOREVERGFX("undo")
check(W.cvars.graphicsQuality == before, "annulation : valeurs d'avant remises")
SlashCmdList.FOREVERGFX("preset inconnu")
check(true, "préréglage inconnu : liste affichée sans erreur")

-- profils
SlashCmdList.FOREVERGFX("preset perf")
local perfValue = W.cvars.graphicsQuality
SlashCmdList.FOREVERGFX("save Mon profil")
check(ns.db.profiles["Mon profil"], "profil enregistré")
SlashCmdList.FOREVERGFX("preset ultra")
SlashCmdList.FOREVERGFX("load Mon profil")
check(W.cvars.graphicsQuality == perfValue, "profil rechargé : graphicsQuality = " .. tostring(perfValue))
SlashCmdList.FOREVERGFX("del Mon profil")
check(not ns.db.profiles["Mon profil"], "profil supprimé")
local text = ns.Export(ns.db.overrides)
check(type(text) == "string" and #text > 0, "export du réglage en texte")

-- combat : changement mis en attente
W.combat = true
ns.SetValue("graphicsQuality", 7, nil, true)
check(W.cvars.graphicsQuality ~= "7", "en combat : changement mis en attente")
W.combat = false
W.fire("PLAYER_REGEN_ENABLED")
W.run(2)
check(W.cvars.graphicsQuality == "7", "après le combat : changement appliqué")

-- interface
ns.ToggleUI()
check(ns.mainFrame and ns.mainFrame:IsShown(), "fenêtre ouverte")
SlashCmdList.FOREVERGFX("expert")
check(ns.db.expert == true, "mode expert")
SlashCmdList.FOREVERGFX("expert")
SlashCmdList.FOREVERGFX("fps")
check(ns.db.overlay == true, "compteur de FPS activé")
SlashCmdList.FOREVERGFX("fps")
check(ns.diagBtn and ns.diagBtn.scripts.OnClick, "bouton « Diag » dans la fenêtre")

-- diagnostic
local diag = ns.DiagText()
check(diag:find("Variables gérées", 1, true) and diag:find(absent, 1, true), "diagnostic : variables gérées et absente (" .. absent .. ")")
check(diag:find("rtNouvelleVariable = 2", 1, true), "diagnostic : variable graphique inconnue du client repérée")
check(not diag:find("Erreur", 1, true), "diagnostic sans erreur")

-- icône commune
check(_G.ForeverHub and ForeverHub.entries.ForeverGFX and ForeverHub.button, "icône commune « Forever » créée, ForeverGFX inscrit")
check(ns.db.minimap.hide == true, "icône propre masquée au profit de l'icône commune")
ns.mainFrame:Hide()
ForeverHub.ShowMenu(ForeverHub.button)
check(ForeverHub.menu and ForeverHub.menu:IsShown(), "clic sur l'icône commune : menu ouvert")
ForeverHub.menu.rows[1].scripts.OnClick()
check(ns.mainFrame:IsShown() and not ForeverHub.menu:IsShown(), "entrée du menu : ForeverGFX ouvert, menu refermé")
SlashCmdList.FOREVERHUB("separees")
check(ns.db.minimap.hide == false and not ForeverHub.button:IsShown(), "/forever separees : icônes séparées, icône commune masquée")
SlashCmdList.FOREVERHUB("commune")
check(ns.db.minimap.hide == true and ForeverHub.button:IsShown(), "/forever commune : retour à l'icône commune")
W.rprint("\nTOUT OK (" .. LANG .. ")")
