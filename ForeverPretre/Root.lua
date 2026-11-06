local ADDON, root = ...

-- ForeverPrêtre : Soins, Équipement, Préparation et Métiers en un seul addon (avant : ForeverHeal, ForeverLoot,
-- ForeverPrep, ForeverMetiers). Chaque partie garde son propre espace de noms (root.mods.<ancien nom>), ses réglages
-- et ses commandes ; les modules communs (diagnostic, composants, sources ATT, tutoriel) n'existent qu'une fois
-- (Shared/*.lua) et sont appliqués à chaque partie à la place qu'ils avaient dans son ancien chargement.

root.ROOT = ADDON
root.Shared = {}
root.mods = {}
root.order = { "ForeverHeal", "ForeverLoot", "ForeverPrep", "ForeverMetiers" }

local FR = GetLocale() == "frFR"
root.FR = FR
root.L = FR and {
  title = "ForeverPrêtre",
  now = "Maintenant", heal = "Soins", loot = "Équipement", prep = "Préparation", metiers = "Métiers",
  nowTitle = "Que faire maintenant ?",
  nowIntro = "Le plus utile à ton niveau (%d), en un coup d'œil. Clique sur une ligne pour le détail.",
  secPriest = "Ton prêtre", secGear = "Équipement à ta portée", secBuy = "À acheter avant le donjon", secProf = "Métiers",
  hps = "%s soins/s", oom = "panne de mana en %s", noOom = "sans panne de mana", regen = "régén. %s mana/s hors combat",
  manaSecret = "Valeurs du prêtre lues hors combat.",
  noGear = "Rien de mieux à portée pour l'instant (jusqu'au niveau %d).",
  allGood = "Rien à acheter : tu es prêt.",
  guide = "Guide-moi vers le vendeur", guideSub = "%d article(s) à acheter",
  noProf = "Rien à faire en métier pour l'instant.",
  more = "Voir tout",
  combat = "En combat : dernier état connu (mise à jour après le combat).",
  refresh = "Actualiser", test = "Auto-test", probe = "Sonde", diag = "Diag",
  err = "Erreur : %s",
  testTitle = "ForeverPrêtre — auto-test", probeTitle = "ForeverPrêtre — sonde du client",
  testHelp = "Copie ce rapport (Ctrl+A, Ctrl+C) et colle-le à Claude.",
  ok = "OK", ko = "ÉCHEC", skip = "non testé",
  help = "Commandes : /fp (maintenant), /fp soins, /fp equipement, /fp prepa, /fp metiers, /fp test, /fp sonde, /fp diag",
  obsolete = "%s fait maintenant partie de ForeverPrêtre : l'ancien dossier est désactivé (tu peux le supprimer).",
} or {
  title = "ForeverPriest",
  now = "Now", heal = "Healing", loot = "Gear", prep = "Preparation", metiers = "Professions",
  nowTitle = "What to do now?",
  nowIntro = "The most useful things at your level (%d), at a glance. Click a line for details.",
  secPriest = "Your priest", secGear = "Gear within reach", secBuy = "To buy before the dungeon", secProf = "Professions",
  hps = "%s healing/s", oom = "out of mana in %s", noOom = "never out of mana", regen = "regen %s mana/s out of combat",
  manaSecret = "Priest values read out of combat.",
  noGear = "Nothing better within reach for now (up to level %d).",
  allGood = "Nothing to buy: you're ready.",
  guide = "Guide me to the vendor", guideSub = "%d item(s) to buy",
  noProf = "Nothing to do in professions for now.",
  more = "See all",
  combat = "In combat: last known state (updated after the fight).",
  refresh = "Refresh", test = "Self-test", probe = "Probe", diag = "Diag",
  err = "Error: %s",
  testTitle = "ForeverPriest — self-test", probeTitle = "ForeverPriest — client probe",
  testHelp = "Copy this report (Ctrl+A, Ctrl+C) and paste it to Claude.",
  ok = "OK", ko = "FAIL", skip = "not tested",
  help = "Commands: /fp (now), /fp heal, /fp gear, /fp prep, /fp prof, /fp test, /fp probe, /fp diag",
  obsolete = "%s is now part of ForeverPriest: the old folder is disabled (you can delete it).",
}

function root.Print(fmt, ...)
  local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. root.L.title .. "|r " .. tostring(msg))
end

-- Espace de noms d'une partie (appelé par la première ligne de chacun de ses fichiers)
function root.Module(name)
  local ns = root.mods[name]
  if not ns then
    ns = { ROOT = ADDON, root = root, MODULE = name, Game = root.Game }
    root.mods[name] = ns
  end
  return name, ns
end

-- Module commun appliqué à une partie (fichiers relais Heal/Diag.lua, Loot/ATT.lua…)
function root.UseShared(name, shared)
  local _, ns = root.Module(name)
  ns.Game = ns.Game or root.Game
  root.Shared[shared](name, ns)
end

-- Réglages communs (fenêtre, sonde)
local ev = CreateFrame("Frame")
root.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == ADDON then
    ForeverPretreDB = ForeverPretreDB or {}
    root.db = ForeverPretreDB
    -- compteur de chargements : s'il reste à 1, le client ne relit pas les sauvegardes (bug de la bêta de Forever,
    -- relevé par forever-addon-kit : « SavedVariables are never loaded ») et tous les réglages repartent de zéro
    root.db.loads = (root.db.loads or 0) + 1
    root.loadsAtStart = root.db.loads
    root.db.hub = root.db.hub or {}
    for _, f in ipairs(root.onLoaded or {}) do pcall(f) end
  elseif event == "PLAYER_LOGIN" then
    for _, f in ipairs(root.onLogin or {}) do pcall(f) end
  end
end)
function root.OnLoaded(f) root.onLoaded = root.onLoaded or {}; table.insert(root.onLoaded, f) end
function root.OnLogin(f) root.onLogin = root.onLogin or {}; table.insert(root.onLogin, f) end
