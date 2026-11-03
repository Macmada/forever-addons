local _, ns = ...

-- Base de ForeverLoot : liste BiS de référence (classique), ce que chaque classe peut porter, poids simplifiés.
-- La liste de référence vient des guides du classique (avant les raids) : à vérifier pour WoW Forever, dont les
-- donjons et objets diffèrent. Le BiS calculé (objets réellement vus, évalués pour ton personnage) prime.

local D = {}
ns.Data = D

local Z = {   -- donjons (noms français / anglais)
  strat = { "Stratholme", "Stratholme" }, scholo = { "Scholomance", "Scholomance" },
  brd = { "Profondeurs de Rochenoire", "Blackrock Depths" }, ubrs = { "Pic Rochenoire supérieur", "Upper Blackrock Spire" },
  dme = { "Hache-Tripes (est)", "Dire Maul East" }, dmw = { "Hache-Tripes (ouest)", "Dire Maul West" },
  dmn = { "Hache-Tripes (nord)", "Dire Maul North" }, st = { "Temple englouti", "Sunken Temple" },
  wpl = { "Maleterres de l'Ouest (quête)", "Western Plaguelands (quest)" }, av = { "Vallée d'Alterac", "Alterac Valley" },
  world = { "Butin du monde (lié quand équipé)", "World drop (BoE)" }, craft = { "Artisanat", "Crafted" },
  pvp = { "JcJ (rang 14)", "PvP (rank 14)" },
}
D.zones = Z

-- Prêtre soigneur, avant les raids. slot = emplacement (1 tête … 18 distance) ; ok = false : numéro non vérifié
-- ou introuvable sur Wowhead Forever (https://www.wowhead.com/forever/fr, vérifié le 03/11/2026 : objet peut-être absent de Forever).
-- boss : nom anglais du guide (le jeu affichera le nom réel de l'objet dans ta langue).
D.reference = {
  PRIEST = {
    { slot = 1, id = 13102, zone = "world", note = "Cassandra's Grace" },
    { slot = 1, id = 16693, zone = "scholo", boss = "Darkmaster Gandling", alt = true },
    { slot = 2, id = 18723, zone = "strat", boss = "Ramstein the Gorger", ok = false },           -- page 404 sur Wowhead Forever
    { slot = 3, id = 18681, zone = "scholo", boss = "butin commun / shared loot" },
    { slot = 15, id = 13386, zone = "strat", boss = "Archivist Galford", note = "« de soins » / « of Healing »" },
    { slot = 15, id = 18510, zone = "craft", boss = "Travail du cuir / Leatherworking" },          -- confirmé sur Wowhead Forever
    -- Robe de la Foi vraie (couture 300) retirée : le numéro 18263 est « Couvre-bras Cœur-de-braise » (Wowhead Forever, 03/11/2026)
    { slot = 9, id = 11766, zone = "brd", boss = "Lord Incendius", note = "« de soins » / « of Healing »" },
    { slot = 9, id = 18497, zone = "ubrs", boss = "Warchief Rend Blackhand", alt = true },
    { slot = 10, id = 10787, zone = "st", boss = "mini-boss", note = "« de soins » / « of Healing »" },
    { slot = 6, id = 18327, zone = "dme", boss = "Alzzin the Wildshaper" },
    { slot = 7, id = 11841, zone = "brd", boss = "Fineous Darkvire" },
    { slot = 7, id = 18386, zone = "dmw", boss = "tribut / tribute", alt = true },
    { slot = 8, id = 18507, zone = "dmn", boss = "Captain Kromcrush" },
    { slot = 8, id = 11822, zone = "brd", boss = "Golem Lord Argelmach", alt = true },
    { slot = 11, id = 16058, zone = "wpl", boss = "In Dreams" },
    { slot = 11, id = 18103, zone = "ubrs", boss = "Warchief Rend Blackhand" },
    { slot = 13, id = 12930, zone = "ubrs", boss = "Jed Runewatcher" },
    { slot = 13, id = 18469, zone = "ubrs", boss = "Jed Runewatcher", ok = false },              -- page 404 sur Wowhead Forever
    { slot = 13, id = 11819, zone = "brd", boss = "Golem Lord Argelmach", ok = false },           -- page 404 sur Wowhead Forever
    { slot = 13, id = 18371, zone = "dmw", boss = "Magister Kalendris", alt = true },
    { slot = 13, id = 22268, zone = "ubrs", boss = "General Drakkisath", alt = true },
    { slot = 16, id = 11923, zone = "brd", boss = "Chest of The Seven" },
    { slot = 16, id = 23454, zone = "pvp", boss = "Grand Marshal", alt = true },
    { slot = 17, id = 11928, zone = "brd", boss = "Emperor Dagran Thaurissan" },
    { slot = 17, id = 19312, zone = "av", boss = "Exalté / Exalted", alt = true },
    { slot = 18, id = 16997, zone = "world", boss = "Order Must Be Restored (quête / quest)" },
  },
}
D.referenceLabel = { "Prêtre soigneur, avant les raids (guides du classique, à vérifier pour Forever)",
                     "Healing priest, pre-raid (classic guides, to check for Forever)" }

-- Emplacements affichés (12 = 2e anneau, 14 = 2e bijou : regroupés avec 11 et 13)
D.slotOrder = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 13, 16, 17, 18 }
D.slots = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16, two = true },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Armures : 1 tissu, 2 cuir, 3 mailles, 4 plaques, 6 bouclier (0 = divers : anneaux, bijoux, objets tenus en main gauche)
-- { type le plus lourd, niveau à partir duquel on passe au type supérieur, type avant ce niveau }
D.armor = {
  PRIEST = { 1 }, MAGE = { 1 }, WARLOCK = { 1 }, DRUID = { 2 }, ROGUE = { 2 },
  HUNTER = { 3, 40, 2 }, SHAMAN = { 3, 40, 2 }, WARRIOR = { 4, 40, 3 }, PALADIN = { 4, 40, 3 },
}
D.shield = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- Armes (sous-classes) : 0 hache 1M, 1 hache 2M, 2 arc, 3 fusil, 4 masse 1M, 5 masse 2M, 6 arme d'hast, 7 épée 1M,
-- 8 épée 2M, 10 bâton, 13 arme de pugilat, 15 dague, 16 armes de jet, 18 arbalète, 19 baguette
local function set(t) local s = {}; for _, v in ipairs(t) do s[v] = true end; return s end
D.weapons = {
  PRIEST = set({ 4, 10, 15, 19 }), MAGE = set({ 7, 10, 15, 19 }), WARLOCK = set({ 7, 10, 15, 19 }),
  DRUID = set({ 4, 5, 10, 13, 15 }), ROGUE = set({ 2, 3, 4, 7, 13, 15, 16, 18 }),
  HUNTER = set({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }), SHAMAN = set({ 0, 1, 4, 5, 10, 13, 15 }),
  WARRIOR = set({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }), PALADIN = set({ 0, 1, 4, 5, 6, 7, 8 }),
}

-- Poids simplifiés par classe (quand le modèle de ForeverHeal ne s'applique pas) : valeur d'un point de chaque caractéristique
D.weights = {
  WARRIOR = { ITEM_MOD_STRENGTH_SHORT = 1, ITEM_MOD_AGILITY_SHORT = 0.8, ITEM_MOD_STAMINA_SHORT = 0.6, ITEM_MOD_ATTACK_POWER_SHORT = 0.5, RESISTANCE0_NAME = 0.02 },
  ROGUE = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_STRENGTH_SHORT = 0.5, ITEM_MOD_ATTACK_POWER_SHORT = 0.5, ITEM_MOD_STAMINA_SHORT = 0.3 },
  HUNTER = { ITEM_MOD_AGILITY_SHORT = 1, ITEM_MOD_ATTACK_POWER_SHORT = 0.45, ITEM_MOD_INTELLECT_SHORT = 0.3, ITEM_MOD_STAMINA_SHORT = 0.3 },
  MAGE = { ITEM_MOD_INTELLECT_SHORT = 0.8, ITEM_MOD_SPELL_POWER_SHORT = 1.2, ITEM_MOD_STAMINA_SHORT = 0.4, ITEM_MOD_SPIRIT_SHORT = 0.2 },
  WARLOCK = { ITEM_MOD_INTELLECT_SHORT = 0.6, ITEM_MOD_SPELL_POWER_SHORT = 1.2, ITEM_MOD_STAMINA_SHORT = 0.6, ITEM_MOD_SPIRIT_SHORT = 0.1 },
  PRIEST = { ITEM_MOD_INTELLECT_SHORT = 1, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1.8, ITEM_MOD_SPIRIT_SHORT = 0.6, ITEM_MOD_STAMINA_SHORT = 0.3, ITEM_MOD_MANA_REGENERATION_SHORT = 2 },
  DRUID = { ITEM_MOD_INTELLECT_SHORT = 0.8, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1.2, ITEM_MOD_AGILITY_SHORT = 0.5, ITEM_MOD_STRENGTH_SHORT = 0.4, ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_SPIRIT_SHORT = 0.4 },
  SHAMAN = { ITEM_MOD_INTELLECT_SHORT = 0.8, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1.2, ITEM_MOD_STRENGTH_SHORT = 0.5, ITEM_MOD_AGILITY_SHORT = 0.4, ITEM_MOD_STAMINA_SHORT = 0.5, ITEM_MOD_MANA_REGENERATION_SHORT = 1.5 },
  PALADIN = { ITEM_MOD_STRENGTH_SHORT = 0.8, ITEM_MOD_INTELLECT_SHORT = 0.7, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1.2, ITEM_MOD_STAMINA_SHORT = 0.6, ITEM_MOD_AGILITY_SHORT = 0.4 },
}
