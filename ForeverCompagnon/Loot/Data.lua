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
  craft = { "Artisanat", "Crafted" },
}
D.zones = Z

-- Prêtre soigneur (Sacré et Discipline : même liste), niveau 60 avant les raids, WoW Forever.
-- Source : liste BiS de kami-labs.fr (calculée le 02/11/2026 avec le simulateur wowsims/forever), numéros relevés
-- dans son lien « Ouvrir dans l'outil ». new = objet nouveau de Forever ; ench = enchantement conseillé.
-- boss : comme sur la source (le jeu affiche le nom réel de l'objet dans ta langue).
D.reference = {
  PRIEST = {
    { slot = 1, id = 16693, zone = "scholo", boss = "Sombre Maître Gandling" },
    { slot = 2, id = 22149, zone = "dm", boss = "quête « La vendetta de Falrin »", ench = "Pouvoir de guérison" },
    { slot = 3, id = 16695, zone = "brs", boss = "monstres du donjon" },
    { slot = 15, id = 18510, zone = "craft", boss = "Travail du cuir 300" },
    { slot = 5, id = 16690, zone = "brs", boss = "Général Drakkisath", ench = "Intelligence majeure" },
    { slot = 9, id = 16697, zone = "strat", boss = "monstres du donjon", ench = "Intelligence excellente" },
    { slot = 10, id = 18409, zone = "craft", boss = "Couture 300", ench = "Pouvoir de guérison" },
    { slot = 6, id = 16696, zone = "brs", boss = "Intendant Zigris" },
    { slot = 7, id = 16694, zone = "strat", boss = "Baron Rivendare" },
    { slot = 8, id = 15802, zone = "craft", boss = "Couture 290", ench = "Esprit" },
    { slot = 11, id = 13345, zone = "strat", boss = "Baron Rivendare" },
    { slot = 11, id = 272406, zone = "strangle", boss = "75 Réals de Terremine ternis", new = true },
    { slot = 13, id = 272439, zone = "strangle", boss = "125 Réals de Terremine ternis", new = true },
    { slot = 13, id = 12930, zone = "brs", boss = "monstres du donjon" },
    { slot = 16, id = 17710, zone = "maraudon", boss = "Princesse Theradras", ench = "Intelligence renforcée" },
    { slot = 17, id = 13353, zone = "strat", boss = "Balnazzar" },
    { slot = 18, id = 249385, zone = "craft", boss = "Enchantement 275", new = true },
  },
}
D.referenceLabel = { "Prêtre soigneur, niveau 60 avant les raids — liste WoW Forever de kami-labs.fr (02/11/2026)",
                     "Healing priest, level 60 pre-raid — WoW Forever list from kami-labs.fr (2026-11-02)" }

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
