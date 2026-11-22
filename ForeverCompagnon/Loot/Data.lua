local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end

-- Base de ForeverLoot : liste BiS de référence (classique), ce que chaque classe peut porter, poids simplifiés.
-- La liste de référence vient des guides du classique (avant les raids) : à vérifier pour WoW Forever, dont les
-- donjons et objets diffèrent. Le BiS calculé (objets réellement vus, évalués pour ton personnage) prime.

local D = {}
ns.Data = D

local Z = {   -- donjons et sources (noms français / anglais)
  strat = { "Stratholme", "Stratholme" }, scholo = { "Scholomance", "Scholomance" },
  brs = { "Pic Blackrock", "Blackrock Spire" }, dm = { "Hache-tripes", "Dire Maul" }, maraudon = { "Maraudon", "Maraudon" },
  strangle = { "Vallée de Strangleronce (marchand Pix Xizzix)", "Stranglethorn Vale (vendor Pix Xizzix)" },
  craft = { "Artisanat", "Crafted" }, brd = { "Profondeurs de Blackrock", "Blackrock Depths" },
  world = { "Butin du monde", "World drop" }, theramore = { "Réputation", "Reputation" },
}
D.zones = Z

-- Prêtre soigneur Sacré, niveau 60 avant les raids, WoW Forever.
-- Source : liste BiS de kami-labs.fr calculée le 20/11/2026 avec le simulateur wowsims/forever (sources du 15/11/2026),
-- numéros relevés dans son lien « Ouvrir dans l'outil » :
-- #1.pretre-sacre.60-preraid.16693-1443~1249058-16695-18510-16690~20028-16697~1248661-271945~25079-16696-16694-15802~20024-
-- 18395-22334-18469-272439-812~1248636-0-22254 (tête, cou, épaules, dos, torse, poignets, mains, taille, jambes, pieds,
-- doigts, bijoux, main droite, main gauche, distance ; « ~ » = enchantement). Pas de main gauche : bâton à deux mains.
-- new = objet nouveau de Forever ; ench = enchantement conseillé (libellé de kami-labs) ; faction = réservé à un camp.
D.reference = {
  PRIEST = {
    { slot = 1, id = 16693, zone = "scholo", boss = "Sombre Maître Gandling" },
    { slot = 2, id = 1443, zone = "world", boss = "butin du monde", ench = "Pouvoir de guérison" },
    { slot = 3, id = 16695, zone = "brs", boss = "Solakar Voluteflamme" },
    { slot = 15, id = 18510, zone = "craft", boss = "Travail du cuir 300" },
    { slot = 5, id = 16690, zone = "brs", boss = "Général Drakkisath", ench = "Intelligence majeure" },
    { slot = 9, id = 16697, zone = "strat", boss = "monstres du donjon", ench = "Intelligence excellente" },
    { slot = 10, id = 271945, zone = "theramore", boss = "Troupe d'intervention de Theramore, exalté", ench = "Pouvoir de guérison", new = true, faction = "Alliance" },
    { slot = 6, id = 16696, zone = "brs", boss = "Intendant Zigris" },
    { slot = 7, id = 16694, zone = "strat", boss = "Baron Rivendare" },
    { slot = 8, id = 15802, zone = "craft", boss = "Couture 270", ench = "Esprit" },
    { slot = 11, id = 18395, zone = "dm", boss = "Prince Tortheldrin" },
    { slot = 11, id = 22334, zone = "strat", boss = "Balnazzar" },
    { slot = 13, id = 18469, zone = "dm", boss = "quête « Sainte Bolognaise : Ce que la lumière ne vous dit pas »" },
    { slot = 13, id = 272439, zone = "strangle", boss = "Pix Xizzix", new = true },
    { slot = 16, id = 812, zone = "world", boss = "butin du monde", ench = "Pouvoir de guérison renforcé" },
    { slot = 18, id = 22254, zone = "brd", boss = "monstres du donjon" },
  },
}
D.referenceLabel = { "Prêtre Sacré, niveau 60 avant les raids — kami-labs.fr, calculée avec wowsims le 20/11/2026",
                     "Holy priest, level 60 pre-raid — kami-labs.fr, computed with wowsims on 2026-11-20" }

-- Paladin, niveau 60 avant les raids, WoW Forever : listes de kami-labs.fr calculées le 20/11/2026 avec wowsims/forever
-- (sources du 15/11/2026), une par spé ; numéros relevés dans le lien « Ouvrir dans l'outil » (même ordre que le prêtre ;
-- « ~ » = enchantement, libellé de kami-labs). Sacré-Protection et Vindicte-Protection : même liste que Protection.
-- paladin-sacre : #1.paladin-sacre.60-preraid.252561-18723~1249058-12625-18510-10020~20028-13969~23802-18527~25079-14553-250600-275609~20024-275983-16058-18472-272439-22315~22750-19312-23201
D.reference.PALADIN_holy = {
  { slot = 1, id = 252561, boss = "Travail du cuir 300" },
  { slot = 2, id = 18723, boss = "Ramstein Grandgosier, Stratholme", ench = "Pouvoir de guérison" },
  { slot = 3, id = 12625, boss = "Forge 265" },
  { slot = 15, id = 18510, boss = "Travail du cuir 300" },
  { slot = 5, id = 10020, boss = "Couture", ench = "Intelligence majeure" },
  { slot = 9, id = 13969, boss = "Kirtonos le Héraut, Scholomance", ench = "Pouvoir de guérison" },
  { slot = 10, id = 18527, boss = "Roi Gordok, Hache-tripes", ench = "Pouvoir de guérison" },
  { slot = 6, id = 14553, boss = "butin du monde" },
  { slot = 7, id = 250600, boss = "Forge 300" },
  { slot = 8, id = 275609, boss = "Couture 295", ench = "Esprit" },
  { slot = 11, id = 275983, boss = "The Watchers, exalté" },
  { slot = 11, id = 16058, boss = "quête « En rêves »" },
  { slot = 13, id = 18472, boss = "quête « La lumière et comment l'altérer », Hache-tripes" },
  { slot = 13, id = 272439, boss = "Pix Xizzix" },
  { slot = 16, id = 22315, boss = "Isalien, Hache-tripes", ench = "Pouvoir de guérison" },
  { slot = 17, id = 19312, boss = "Garde Foudrepique / Clan Loup-de-givre, exalté" },
  { slot = 18, id = 23201, boss = "Seigneur Alexei Barov, Scholomance" },
}
-- paladin-protection : #1.paladin-protection.60-preraid.272783-19491~1249060-20057-13397~20015-12895~20025-19578~1248599-271940~25080-272779-237825-272781~20023-2246-275984-272440-20071-1728~23800-19321~20017-272434
D.reference.PALADIN_prot = {
  { slot = 1, id = 272783, boss = "marchand JcJ Alliance" },
  { slot = 2, id = 19491, boss = "quête « 1200 bons - Amulette de la Sombrelune »", ench = "Déviation" },
  { slot = 3, id = 20057, boss = "La Ligue d'Arathor, exalté" },
  { slot = 15, id = 13397, boss = "Echine-de-pierre, Stratholme", ench = "Défense excellente" },
  { slot = 5, id = 12895, boss = "quête « La cuirasse du vol chromatique »", ench = "Caractéristiques supérieures" },
  { slot = 9, id = 19578, boss = "Sentinelles d'Aile-argent / Voltigeurs Chanteguerre, exalté", ench = "Agilité excellente" },
  { slot = 10, id = 271940, boss = "Troupe d'intervention de Theramore, exalté", ench = "Agilité excellente" },
  { slot = 6, id = 272779, boss = "marchand JcJ Alliance" },
  { slot = 7, id = 237825, boss = "Sentinelles d'Aile-argent, exalté" },
  { slot = 8, id = 272781, boss = "marchand JcJ Alliance", ench = "Agilité supérieure" },
  { slot = 11, id = 2246, boss = "butin du monde" },
  { slot = 11, id = 275984, boss = "The Watchers, exalté" },
  { slot = 13, id = 272440, boss = "Pix Xizzix" },
  { slot = 13, id = 20071, boss = "La Ligue d'Arathor, amical" },
  { slot = 16, id = 1728, boss = "butin du monde", ench = "Agilité" },
  { slot = 17, id = 19321, boss = "Garde Foudrepique / Clan Loup-de-givre, exalté", ench = "Endurance supérieure" },
  { slot = 18, id = 272434, boss = "Pix Xizzix" },
}
-- paladin-vindicte : #1.paladin-vindicte.60-preraid.12640-15411~1249019-20212-20068~13419-252484~20025-19578~20010-272095~1248640-19044-22385-275618~20023-275981-19325-22268-272437-19323~1248668-0-272435
D.reference.PALADIN_ret = {
  { slot = 1, id = 12640, boss = "Forge 300" },
  { slot = 2, id = 15411, boss = "quête « En rêves »", ench = "Force" },
  { slot = 3, id = 20212, boss = "Les Profanateurs, exalté" },
  { slot = 15, id = 20068, boss = "Les Profanateurs, exalté", ench = "Agilité mineure" },
  { slot = 5, id = 252484, boss = "Travail du cuir 300", ench = "Caractéristiques supérieures" },
  { slot = 9, id = 19578, boss = "Sentinelles d'Aile-argent / Voltigeurs Chanteguerre, exalté", ench = "Force excellente" },
  { slot = 10, id = 272095, boss = "Chevaucheurs sombrelances, exalté", ench = "Force excellente" },
  { slot = 6, id = 19044, boss = "Travail du cuir 265" },
  { slot = 7, id = 22385, boss = "Forge 300" },
  { slot = 8, id = 275618, boss = "Travail du cuir 295", ench = "Agilité supérieure" },
  { slot = 11, id = 275981, boss = "The Watchers, exalté" },
  { slot = 11, id = 19325, boss = "Garde Foudrepique / Clan Loup-de-givre, exalté" },
  { slot = 13, id = 22268, boss = "Général Drakkisath, Pic Blackrock" },
  { slot = 13, id = 272437, boss = "Pix Xizzix" },
  { slot = 16, id = 19323, boss = "Garde Foudrepique / Clan Loup-de-givre, exalté", ench = "Force" },
  { slot = 18, id = 272435, boss = "Pix Xizzix" },
}
-- shockadin-paladin : #1.shockadin-paladin.60-preraid.250599-15411~1249057-272745-272411~13419-252484~20025-19595~20010-271940~1248640-272404-22753-272718~20023-19325-275981-272438-280065-19323~1248607-0-272435
D.reference.PALADIN_shock = {
  { slot = 1, id = 250599, boss = "Forge 300" },
  { slot = 2, id = 15411, boss = "quête « En rêves »", ench = "Puissance des sorts" },
  { slot = 3, id = 272745, boss = "marchand JcJ Alliance" },
  { slot = 15, id = 272411, boss = "Pix Xizzix", ench = "Agilité mineure" },
  { slot = 5, id = 252484, boss = "Travail du cuir 300", ench = "Caractéristiques supérieures" },
  { slot = 9, id = 19595, boss = "Sentinelles d'Aile-argent / Voltigeurs Chanteguerre, exalté", ench = "Force excellente" },
  { slot = 10, id = 271940, boss = "Troupe d'intervention de Theramore, exalté", ench = "Force excellente" },
  { slot = 6, id = 272404, boss = "Pix Xizzix" },
  { slot = 7, id = 22753, boss = "Sentinelles d'Aile-argent, exalté" },
  { slot = 8, id = 272718, boss = "marchand JcJ Alliance", ench = "Agilité supérieure" },
  { slot = 11, id = 19325, boss = "Garde Foudrepique / Clan Loup-de-givre, exalté" },
  { slot = 11, id = 275981, boss = "The Watchers, exalté" },
  { slot = 13, id = 272438, boss = "Pix Xizzix" },
  { slot = 13, id = 280065, boss = "Blackmaw Behemoth, Repaire des Noiregueules" },
  { slot = 16, id = 19323, boss = "Garde Foudrepique / Clan Loup-de-givre, exalté", ench = "Puissance de sort renforcée" },
  { slot = 18, id = 272435, boss = "Pix Xizzix" },
}
D.referenceLabels = {
  PRIEST = D.referenceLabel,
  PALADIN_holy = { "Paladin Sacré, niveau 60 avant les raids — kami-labs.fr, calculée avec wowsims le 20/11/2026",
                   "Holy paladin, level 60 pre-raid — kami-labs.fr, computed with wowsims on 2026-11-20" },
  PALADIN_prot = { "Paladin Protection, niveau 60 avant les raids — kami-labs.fr, calculée avec wowsims le 20/11/2026",
                   "Protection paladin, level 60 pre-raid — kami-labs.fr, computed with wowsims on 2026-11-20" },
  PALADIN_ret = { "Paladin Vindicte, niveau 60 avant les raids — kami-labs.fr, calculée avec wowsims le 20/11/2026",
                  "Retribution paladin, level 60 pre-raid — kami-labs.fr, computed with wowsims on 2026-11-20" },
  PALADIN_shock = { "Paladin « Shockadin » (Horion sacré), niveau 60 avant les raids — kami-labs.fr, calculée avec wowsims le 20/11/2026",
                    "\"Shockadin\" paladin (Holy Shock), level 60 pre-raid — kami-labs.fr, computed with wowsims on 2026-11-20" },
}

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

-- Poids par classe et par rôle (tank, heal, melee, caster), choisi sur l'écran Maintenant ou dans Préparation
-- (le client de Forever ne donne pas les arbres de talents aux addons). Puissance des sorts : compte aussi pour les soins.
local SP, HEAL, DMG = "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"
local STR, AGI, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local AP, RAP, MP5, ARM, DPS = "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT", "RESISTANCE0_NAME", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
local DEF, DODGE, PARRY, BLOCK = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT"
local CRIT, HIT = "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT"
local function W(t) return t end
local HEALER = W({ [INT] = 1, [HEAL] = 1.8, [SP] = 1.8, [MP5] = 2, [SPI] = 0.5, [STA] = 0.3 })
local CASTER = W({ [INT] = 0.7, [SP] = 1.2, [DMG] = 1.2, [SPI] = 0.25, [STA] = 0.4, [CRIT] = 0.8, [HIT] = 0.9 })
D.roleWeights = {
  WARRIOR = { melee = W({ [STR] = 1, [AGI] = 0.8, [AP] = 0.5, [STA] = 0.5, [CRIT] = 1, [HIT] = 1, [DPS] = 4 }),
              tank = W({ [STA] = 1, [ARM] = 0.06, [DEF] = 1.2, [DODGE] = 1, [PARRY] = 1, [BLOCK] = 0.6, [AGI] = 0.6, [STR] = 0.5, [DPS] = 1.5 }) },
  PALADIN = { heal = HEALER,
              tank = W({ [STA] = 1, [ARM] = 0.06, [DEF] = 1.2, [DODGE] = 0.9, [PARRY] = 0.8, [BLOCK] = 0.7, [STR] = 0.5, [INT] = 0.3, [SP] = 0.6 }),
              melee = W({ [STR] = 1, [AGI] = 0.6, [AP] = 0.5, [INT] = 0.3, [STA] = 0.4, [CRIT] = 0.9, [HIT] = 0.9, [DPS] = 4 }) },
  SHAMAN = { heal = HEALER, caster = CASTER,
             melee = W({ [AGI] = 0.8, [STR] = 0.8, [AP] = 0.5, [INT] = 0.3, [STA] = 0.4, [CRIT] = 0.9, [HIT] = 0.9, [DPS] = 4 }) },
  DRUID = { heal = HEALER, caster = CASTER,
            tank = W({ [STA] = 1, [AGI] = 0.9, [ARM] = 0.05, [STR] = 0.5, [DEF] = 1, [DODGE] = 1 }),
            melee = W({ [AGI] = 1, [STR] = 0.9, [AP] = 0.5, [STA] = 0.3, [CRIT] = 1, [HIT] = 0.9 }) },
  PRIEST = { heal = HEALER, caster = W({ [INT] = 0.6, [SP] = 1.2, [DMG] = 1.2, [SPI] = 0.35, [STA] = 0.4, [HIT] = 0.9 }) },
  MAGE = { caster = CASTER }, WARLOCK = { caster = W({ [INT] = 0.5, [SP] = 1.2, [DMG] = 1.2, [STA] = 0.6, [SPI] = 0.1, [HIT] = 0.9 }) },
  ROGUE = { melee = W({ [AGI] = 1, [STR] = 0.5, [AP] = 0.5, [STA] = 0.3, [CRIT] = 1, [HIT] = 1, [DPS] = 4 }) },
  HUNTER = { melee = W({ [AGI] = 1, [RAP] = 0.5, [AP] = 0.45, [INT] = 0.3, [STA] = 0.3, [CRIT] = 1, [HIT] = 1, [DPS] = 1.5 }) },
}
-- Poids simplifiés par classe (sans rôle connu) : valeur d'un point de chaque caractéristique
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
