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
  secTodo = "À faire", tileHps = "soins/s", tileAuto = "de soins sans pause", tileNever = "jamais à sec", tileUp = "améliorations",
  tileBuy = "à acheter", tileProf = "métiers", tilePlaces = "lieux à faire",
  todoTrainer = "Aller voir le maître de classe", todoTrainerSpells = "%d sort(s) à apprendre", todoTrainerLikely = "nouveaux sorts probables à ton niveau",
  todoTrainerCost = "coût %s", todoTrainerNoPos = "Passe une fois chez ton maître de classe : je retiens où il est et ses sorts.",
  todoDungeon = "Faire : %s", todoZone = "Quêtes et butin : %s", tagDungeon = "donjon", tagZone = "zone", tagLevel = "niv. %d+",
  placeItems = "%d objet(s) pour toi", placeQuests = "%d quête(s)", placeEntrance = "entrée : %s",
  clickGo = "Clic : itinéraire le plus rapide (flèche, vols connus)", rightOpen = "Clic droit : ouvrir l'onglet",
  noTodo = "Rien d'urgent : tu es prêt.", footer = "Tout voir :",
  tagRange = "niv. %d-%d", todoEquip = "Équiper : %s", todoEquipSrc = "déjà dans tes sacs · clic : équiper",
  todoBuyItem = "Acheter : %s", todoProfRank = "Apprendre %s (%s)", todoProfRankSrc = "%d/%d : le maître te fait passer à %d",
  todoQuests = "Quêtes : %s", todoQuestsN = "%d quêtes", todoQuestsGiver = "donneur : %s", todoQuestsMore = "… et %d autres",
  tagQuests = "quêtes",
  todoFirstAid = "Apprendre le Secourisme", todoFirstAidSrc = "aucun bandage : le Secourisme les fabrique avec le tissu que tu ramasses",
  role = "Rôle :", role_tank = "Tank", role_heal = "Soins", role_melee = "Dégâts (mêlée)", role_caster = "Dégâts (sorts)",
  roleTip = "Ton rôle règle les conseils d'équipement et de préparation (le jeu ne donne pas tes talents aux addons).",
  nowIntro = "Le plus utile à ton niveau (%d), en un coup d'œil. Clique sur une ligne pour le détail.",
  secPriest = "Tes soins", secGear = "Équipement à ta portée", secBuy = "À acheter avant le donjon", secProf = "Métiers",
  hps = "%s soins/s", oom = "à sec après %s de soins sans pause", noOom = "jamais à sec", regen = "régén. %s mana/s hors combat",
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
  help = "Commandes : /fp (maintenant), /fp soins, /fp equipement, /fp prepa, /fp metiers, /fp addons, /fp healbot [voir|annuler], /fp vols, /fp way x y [nom], /fp test, /fp sonde, /fp diag",
  ownBank = "dans ta banque", ownOther = "chez %s",
  scanButton = "Relever les prix", scanTip = "ForeverCompagnon relève tous les prix de l'hôtel des ventes (une fois toutes les 15 minutes, limite du jeu) pour la préparation et les métiers.",
  scanStart = "Relevé des prix de l'hôtel des ventes en cours…", scanDone = "Prix relevés : %d objets (%d enchères).",
  scanWait = "Le jeu permet un relevé toutes les 15 minutes : réessaie dans %d min.", scanNoApi = "Relevé des prix impossible sur ce client.",
  scanLast = "Dernier relevé : %s",
  flashTitle = "Équipement changé", flashNoItem = "Caractéristiques modifiées",
  flash_str = "Force", flash_agi = "Agilité", flash_sta = "Endurance", flash_int = "Intelligence", flash_spi = "Esprit",
  flash_ap = "puissance d'attaque", flash_sp = "puissance des sorts", flash_heal = "aux soins", flash_crit = "critique",
  flash_armor = "Armure", flash_hp = "PV max", flash_mana = "mana max",
  flash_staHp = "%s PV", flash_intMana = "%s mana", flash_armorRed = "%s %% de réduction des dégâts physiques", flashTip = "Glisser : déplacer (position retenue). Clic droit : fermer. /fp flash place : place automatique.",
  flashReset = "Cadre des changements : place automatique (à côté du personnage).", flash_on = "Cadre des changements : activé.", flash_off = "Cadre des changements : désactivé.",
  navArrived = "Arrivé !", navDist = "%d m · ~%s à pied", navOtherContinent = "Sur un autre continent : %s",
  navNoPos = "Position cachée ici (donjon) : %s", navTip = "Glisser : déplacer. Clic droit : effacer. /fp way x y [nom] pour un autre point.",
  navCleared = "Flèche effacée.", navNoMap = "Carte inconnue ici.",
  navFlightMaster = "Maître de vol : %s", navTakeFlight = "Prends le vol vers %s",
  navRouteSteps = "Itinéraire vers %s : %s, puis la flèche (~%s en tout).",
  navStepFly = "vol de %s à %s", navStepBoat = "bateau de %s à %s", navStepZeppelin = "zeppelin de %s à %s",
  navBoatDock = "Quai du bateau pour %s", navZeppelinDock = "Tour du zeppelin pour %s",
  navTakeBoat = "Prends le bateau pour %s", navTakeZeppelin = "Prends le zeppelin pour %s",
  navNoBoat = "Autre continent : aucun bateau ni zeppelin connu pour ta faction vers ce lieu.",
  navRouteWalk = "Itinéraire vers %s : ~%s (aucun vol plus rapide parmi ceux que tu connais).",
  navNoTaxi = "Aucun point de vol connu : ouvre la carte d'un maître de vol, ForeverCompagnon retient tes vols.",
  navTaxiTitle = "Tes points de vol connus (%d), le plus proche d'abord :",
  go = "Y aller", goTip = "Pose la flèche vers ce lieu",
  addons = "Addons",
  addonsIntro = "Les addons qui complètent celui-ci sur WoW Forever. Clique sur une ligne : son adresse s'affiche en bas, à copier (Ctrl+C) dans ton navigateur ou WowUp.",
  addonsUsed = "Utilisés par ForeverCompagnon", addonsMore = "Utiles aussi sur Forever",
  addonsBuiltin = "Intégrés à ForeverCompagnon (plus nécessaires)",
  builtin_att = "Intégré : base WoW Forever d'All The Things incluse dans l'addon.",
  builtin_dj = "Intégré : butin des donjons tiré de la base incluse.",
  builtin_auctionator = "Intégré : bouton « Relever les prix » à l'hôtel des ventes. Utilisé en plus s'il est installé.",
  builtin_syndicator = "Intégré : banque et rerolls retenus par l'addon. Utilisé en plus s'il est installé.",
  builtin_tomtom = "Intégré : flèche de navigation (/fp way, /way, Guide-moi, clic droit : y aller).",
  addonOn = "actif", addonOff = "désactivé", addonAbsent = "absent",
  addonClick = "clic : adresse", addonEnable = "clic : activer",
  addonPick = "Clique sur un addon pour afficher son adresse.", addonUrlFor = "Adresse de %s (Ctrl+C pour copier) :",
  addonNoUrl = "pas d'adresse connue : cherche-le dans WowUp ou sur CurseForge",
  addonEnableBtn = "Activer", addonEnabled = "%s sera actif au prochain /reload.",
  tileOn = "actifs", tileOff = "désactivés", tileAbsent = "absents (facultatifs)",
} or {
  title = "ForeverCompanion",
  now = "Now", heal = "Healing", loot = "Gear", prep = "Preparation", metiers = "Professions",
  nowTitle = "What to do now?",
  secTodo = "To do", tileHps = "healing/s", tileAuto = "of non-stop healing", tileNever = "never dry", tileUp = "upgrades",
  tileBuy = "to buy", tileProf = "professions", tilePlaces = "places to do",
  todoTrainer = "Visit your class trainer", todoTrainerSpells = "%d spell(s) to learn", todoTrainerLikely = "new spells likely at your level",
  todoTrainerCost = "cost %s", todoTrainerNoPos = "Visit your class trainer once: I'll remember where it is and its spells.",
  todoDungeon = "Run: %s", todoZone = "Quests and loot: %s", tagDungeon = "dungeon", tagZone = "zone", tagLevel = "lvl %d+",
  placeItems = "%d item(s) for you", placeQuests = "%d quest(s)", placeEntrance = "entrance: %s",
  clickGo = "Click: fastest route (arrow, known flights)", rightOpen = "Right-click: open the tab",
  noTodo = "Nothing urgent: you're ready.", footer = "See all:",
  tagRange = "lvl %d-%d", todoEquip = "Equip: %s", todoEquipSrc = "already in your bags · click: equip",
  todoBuyItem = "Buy: %s", todoProfRank = "Learn %s (%s)", todoProfRankSrc = "%d/%d: the trainer raises it to %d",
  todoQuests = "Quests: %s", todoQuestsN = "%d quests", todoQuestsGiver = "giver: %s", todoQuestsMore = "… and %d more",
  tagQuests = "quests",
  todoFirstAid = "Learn First Aid", todoFirstAidSrc = "no bandages: First Aid makes them from the cloth you loot",
  role = "Role:", role_tank = "Tank", role_heal = "Healer", role_melee = "Damage (melee)", role_caster = "Damage (spells)",
  roleTip = "Your role drives gear and preparation advice (the game does not give your talents to addons).",
  nowIntro = "The most useful things at your level (%d), at a glance. Click a line for details.",
  secPriest = "Your healing", secGear = "Gear within reach", secBuy = "To buy before the dungeon", secProf = "Professions",
  hps = "%s healing/s", oom = "dry after %s of non-stop healing", noOom = "never out of mana", regen = "regen %s mana/s out of combat",
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
  help = "Commands: /fp (now), /fp heal, /fp gear, /fp prep, /fp prof, /fp addons, /fp healbot [voir|annuler], /fp vols, /fp way x y [name], /fp test, /fp probe, /fp diag",
  ownBank = "in your bank", ownOther = "on %s",
  scanButton = "Scan prices", scanTip = "ForeverCompanion reads every auction house price (once every 15 minutes, game limit) for preparation and professions.",
  scanStart = "Scanning auction house prices…", scanDone = "Prices saved: %d items (%d auctions).",
  scanWait = "The game allows one scan every 15 minutes: try again in %d min.", scanNoApi = "Price scan not possible on this client.",
  scanLast = "Last scan: %s",
  flashTitle = "Gear changed", flashNoItem = "Stats changed",
  flash_str = "Strength", flash_agi = "Agility", flash_sta = "Stamina", flash_int = "Intellect", flash_spi = "Spirit",
  flash_ap = "attack power", flash_sp = "spell power", flash_heal = "healing", flash_crit = "crit",
  flash_armor = "Armor", flash_hp = "max HP", flash_mana = "max mana",
  flash_staHp = "%s HP", flash_intMana = "%s mana", flash_armorRed = "%s%% physical damage reduction", flashTip = "Drag: move (position remembered). Right-click: close. /fp flash place: automatic position.",
  flashReset = "Change frame: automatic position (next to your character).", flash_on = "Change frame: on.", flash_off = "Change frame: off.",
  navArrived = "Arrived!", navDist = "%d yd · ~%s on foot", navOtherContinent = "On another continent: %s",
  navNoPos = "Position hidden here (dungeon): %s", navTip = "Drag: move. Right-click: clear. /fp way x y [name] for another point.",
  navCleared = "Arrow cleared.", navNoMap = "Unknown map here.",
  navFlightMaster = "Flight master: %s", navTakeFlight = "Take the flight to %s",
  navRouteSteps = "Route to %s: %s, then follow the arrow (~%s in total).",
  navStepFly = "flight from %s to %s", navStepBoat = "boat from %s to %s", navStepZeppelin = "zeppelin from %s to %s",
  navBoatDock = "Boat dock for %s", navZeppelinDock = "Zeppelin tower for %s",
  navTakeBoat = "Take the boat to %s", navTakeZeppelin = "Take the zeppelin to %s",
  navNoBoat = "Other continent: no boat or zeppelin known for your faction to this place.",
  navRouteWalk = "Route to %s: ~%s (no faster flight among those you know).",
  navNoTaxi = "No known flight point: open a flight master's map, ForeverCompagnon remembers your flights.",
  navTaxiTitle = "Your known flight points (%d), nearest first:",
  go = "Go there", goTip = "Points the arrow to this place",
  addons = "Addons",
  addonsIntro = "Addons that complement this one on WoW Forever. Click a line: its address shows at the bottom, to copy (Ctrl+C) into your browser or WowUp.",
  addonsUsed = "Used by ForeverCompanion", addonsMore = "Also useful on Forever",
  addonsBuiltin = "Built into ForeverCompanion (no longer needed)",
  builtin_att = "Built in: All The Things' WoW Forever database ships with the addon.",
  builtin_dj = "Built in: dungeon loot from the included database.",
  builtin_auctionator = "Built in: \"Scan prices\" button at the auction house. Used too if installed.",
  builtin_syndicator = "Built in: bank and alts remembered by the addon. Used too if installed.",
  builtin_tomtom = "Built in: navigation arrow (/fp way, /way, Guide me, right-click: go there).",
  addonOn = "enabled", addonOff = "disabled", addonAbsent = "missing",
  addonClick = "click: address", addonEnable = "click: enable",
  addonPick = "Click an addon to show its address.", addonUrlFor = "Address of %s (Ctrl+C to copy):",
  addonNoUrl = "no known address: look for it in WowUp or on CurseForge",
  addonEnableBtn = "Enable", addonEnabled = "%s will be enabled after the next /reload.",
  tileOn = "enabled", tileOff = "disabled", tileAbsent = "missing (optional)",
}

-- Sources intégrées (850 Ko) : addon ForeverCompagnon_Data, chargé au premier besoin (survol d'un objet, Équipement,
-- « À faire »…) au lieu de chaque connexion. Une seule tentative ; sans lui, les fonctions qui s'en servent se taisent.
function root.LoadSources()
  if root.Sources then return root.Sources end
  if root.sourcesTried then return nil end
  root.sourcesTried = true
  local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
  if load then pcall(load, "ForeverCompagnon_Data") end
  if type(_G.ForeverCompagnonSources) == "table" then
    root.Sources = _G.ForeverCompagnonSources
    _G.ForeverCompagnonSources = nil
  end
  return root.Sources
end

-- Infobulles d'objets : une seule accroche pour tout ForeverCompagnon (avant : une par partie). Chaque partie inscrit sa
-- fonction avec un rang (Soins 1, Équipement 2, Métiers 3 : lignes toujours dans cet ordre) ; une erreur dans l'une
-- n'empêche pas les autres.
local tipHandlers, tipHooked = {}, false
function root.HookItemTooltip(rank, fn)
  tipHandlers[#tipHandlers + 1] = { rank = rank, fn = fn }
  table.sort(tipHandlers, function(a, b) return a.rank < b.rank end)
  if tipHooked then return end
  tipHooked = true
  local function Run(tt)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    for _, h in ipairs(tipHandlers) do pcall(h.fn, tt) end
  end
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Run)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", Run) end
    end
  end
end

function root.Print(fmt, ...)
  local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. root.L.title .. "|r " .. tostring(msg)) end
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
  if loot then loot.version = (loot.version or 0) + 1; if loot.ForgetMemo then loot.ForgetMemo() end end
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
