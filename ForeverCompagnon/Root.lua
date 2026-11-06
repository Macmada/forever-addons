local ADDON, root = ...

-- ForeverCompagnon : Soins, Équipement, Préparation et Métiers en un seul addon (avant : ForeverHeal, ForeverLoot,
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
  title = "ForeverCompagnon",
  now = "Maintenant", heal = "Soins", loot = "Équipement", prep = "Préparation", metiers = "Métiers",
  nowTitle = "Que faire maintenant ?",
  role = "Rôle :", role_tank = "Tank", role_heal = "Soins", role_melee = "Dégâts (mêlée)", role_caster = "Dégâts (sorts)",
  roleTip = "Ton rôle règle les conseils d'équipement et de préparation (le jeu ne donne pas tes talents aux addons).",
  nowIntro = "Le plus utile à ton niveau (%d), en un coup d'œil. Clique sur une ligne pour le détail.",
  secPriest = "Tes soins", secGear = "Équipement à ta portée", secBuy = "À acheter avant le donjon", secProf = "Métiers",
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
  testTitle = "ForeverCompagnon — auto-test", probeTitle = "ForeverCompagnon — sonde du client",
  testHelp = "Copie ce rapport (Ctrl+A, Ctrl+C) et colle-le à Claude.",
  ok = "OK", ko = "ÉCHEC", skip = "non testé",
  help = "Commandes : /fp (maintenant), /fp soins, /fp equipement, /fp prepa, /fp metiers, /fp addons, /fp test, /fp sonde, /fp diag",
  obsolete = "%s fait maintenant partie de ForeverCompagnon : l'ancien dossier est désactivé (tu peux le supprimer).",
  addons = "Addons",
  addonsIntro = "Les addons qui complètent celui-ci sur WoW Forever. Clique sur une ligne : son adresse s'affiche en bas, à copier (Ctrl+C) dans ton navigateur ou WowUp.",
  addonsUsed = "Utilisés par ForeverCompagnon", addonsMore = "Utiles aussi sur Forever",
  addonOn = "actif", addonOff = "désactivé", addonAbsent = "absent",
  addonClick = "clic : adresse", addonEnable = "clic : activer",
  addonPick = "Clique sur un addon pour afficher son adresse.", addonUrlFor = "Adresse de %s (Ctrl+C pour copier) :",
  addonNoUrl = "pas d'adresse connue : cherche-le dans WowUp ou sur CurseForge",
  addonEnableBtn = "Activer", addonEnabled = "%s sera actif au prochain /reload.",
} or {
  title = "ForeverCompanion",
  now = "Now", heal = "Healing", loot = "Gear", prep = "Preparation", metiers = "Professions",
  nowTitle = "What to do now?",
  role = "Role:", role_tank = "Tank", role_heal = "Healer", role_melee = "Damage (melee)", role_caster = "Damage (spells)",
  roleTip = "Your role drives gear and preparation advice (the game does not give your talents to addons).",
  nowIntro = "The most useful things at your level (%d), at a glance. Click a line for details.",
  secPriest = "Your healing", secGear = "Gear within reach", secBuy = "To buy before the dungeon", secProf = "Professions",
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
  testTitle = "ForeverCompanion — self-test", probeTitle = "ForeverCompanion — client probe",
  testHelp = "Copy this report (Ctrl+A, Ctrl+C) and paste it to Claude.",
  ok = "OK", ko = "FAIL", skip = "not tested",
  help = "Commands: /fp (now), /fp heal, /fp gear, /fp prep, /fp prof, /fp addons, /fp test, /fp probe, /fp diag",
  obsolete = "%s is now part of ForeverCompanion: the old folder is disabled (you can delete it).",
  addons = "Addons",
  addonsIntro = "Addons that complement this one on WoW Forever. Click a line: its address shows at the bottom, to copy (Ctrl+C) into your browser or WowUp.",
  addonsUsed = "Used by ForeverCompanion", addonsMore = "Also useful on Forever",
  addonOn = "enabled", addonOff = "disabled", addonAbsent = "missing",
  addonClick = "click: address", addonEnable = "click: enable",
  addonPick = "Click an addon to show its address.", addonUrlFor = "Address of %s (Ctrl+C to copy):",
  addonNoUrl = "no known address: look for it in WowUp or on CurseForge",
  addonEnableBtn = "Enable", addonEnabled = "%s will be enabled after the next /reload.",
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
    ForeverCompagnonDB = ForeverCompagnonDB or {}
    root.db = ForeverCompagnonDB
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
-- Rôle du personnage : celui de Préparation (choisi sur l'écran Maintenant, /prep role, ou deviné) ; partagé par
-- Équipement (poids des caractéristiques) et l'écran Maintenant
function root.Role()
  local prep = root.mods.ForeverPrep
  if prep and prep.Role then
    local ok, r = pcall(prep.Role)
    if ok then return r end
  end
end
function root.SetRole(role)
  local prep = root.mods.ForeverPrep
  if prep and prep.db then prep.db.role = role end
  local loot = root.mods.ForeverLoot
  if loot then loot.version = (loot.version or 0) + 1 end
  if root.RefreshNow then root.RefreshNow() end
end
-- Rôles possibles pour la classe (d'après les poids d'Équipement)
function root.ClassRoles()
  local _, class = UnitClass("player")
  local loot = root.mods.ForeverLoot
  local byRole = loot and loot.Data and loot.Data.roleWeights and loot.Data.roleWeights[class]
  local out = {}
  for _, r in ipairs({ "tank", "heal", "melee", "caster" }) do if byRole and byRole[r] then out[#out + 1] = r end end
  return out
end

function root.OnLoaded(f) root.onLoaded = root.onLoaded or {}; table.insert(root.onLoaded, f) end
function root.OnLogin(f) root.onLogin = root.onLogin or {}; table.insert(root.onLogin, f) end
