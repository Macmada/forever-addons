local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverHeal") end

-- Données du prêtre (WoW Forever, règles classiques). Les valeurs réelles sont relues dans le jeu quand c'est possible :
-- montants des sorts (description), temps d'incantation et coût (talents compris), et les conversions de
-- caractéristiques sont apprises sur ton personnage. Ce qui est ici sert de point de départ.

local D = {}
ns.Data = D

-- Familles de soins : base = temps d'incantation de base (coefficient de bonus aux soins = base / 3,5),
-- hot = durée d'un soin sur la durée (coefficient = durée / 15), targets = cibles d'un soin de groupe (coefficient / 3).
-- ranks = { numéro de sort, niveau d'apprentissage, temps de base si différent }
D.families = {
  greater = { base = 3.0, ranks = { { 2060, 40 }, { 10963, 46 }, { 10964, 52 }, { 10965, 58 }, { 25314, 60 } } },
  heal = { base = 3.0, ranks = { { 2054, 16 }, { 2055, 22 }, { 6063, 28 }, { 6064, 34 } } },
  flash = { base = 1.5, ranks = { { 2061, 20 }, { 9472, 26 }, { 9473, 32 }, { 9474, 38 }, { 10915, 44 }, { 10916, 50 }, { 10917, 56 } } },
  lesser = { base = 1.5, ranks = { { 2050, 1, 1.5 }, { 2052, 4, 2.0 }, { 2053, 10, 2.5 } } },
  renew = { hot = 15, ranks = { { 139, 8 }, { 6074, 14 }, { 6075, 20 }, { 6076, 26 }, { 6077, 32 }, { 6078, 38 },
                                { 10927, 44 }, { 10928, 50 }, { 10929, 56 }, { 25315, 60 } } },
  prayer = { base = 3.0, targets = 5, ranks = { { 596, 30 }, { 996, 40 }, { 10960, 50 }, { 10961, 60 }, { 25316, 60 } } },
}
D.ORDER = { "greater", "heal", "flash", "lesser", "renew", "prayer" }

-- Conversions de départ (classique), remplacées par celles mesurées sur ton personnage
D.defaults = {
  hpPerSta = 10,          -- PV par point d'Endurance
  manaPerInt = 15,        -- mana par point d'Intelligence
  regenPerSpi = 0.125,    -- mana par seconde par point d'Esprit, hors combat (prêtre : 13 + Esprit/4 toutes les 2 s)
  intPerCritAt60 = 59.5,  -- Intelligence pour 1 % de critique des sorts au niveau 60
  critMult = 1.5,         -- un soin critique rend 150 %
  gcd = 1.5,              -- temps global de recharge (sorts instantanés)
}

-- Lignes d'infobulle à lire quand le jeu ne donne pas la caractéristique (motifs en minuscules, nombre capturé)
D.tooltipPatterns = {
  heal = { "healing done by spells and effects by up to (%d+)", "damage and healing done by magical spells and effects by up to (%d+)",
           "%+(%d+) healing spells", "%+(%d+) healing",
           "soins prodigués.-de (%d+)", "soins .-sorts et effets .-(%d+)", "dégâts et les soins .-(%d+)", "%+(%d+) aux sorts de soins",
           "%+(%d+) aux soins" },
  mp5 = { "restores (%d+) mana per 5 sec", "(%d+) mana every 5 sec", "%+(%d+) mana every 5 sec", "(%d+) mana per 5",
          "rend (%d+) points? de mana toutes les 5", "(%d+) points? de mana toutes les 5", "%+(%d+) mana toutes les 5" },
  spellCrit = { "critical strike with spells by (%d+)%%", "coup critique avec vos sorts de (%d+)%%", "coup critique .-sorts.-(%d+)%%" },
}

-- Emplacements d'équipement par type d'objet
D.slots = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16, two = true },
  INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
  INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Familles où lancer un rang inférieur a du sens (soins directs sur une cible) et nom court des macros
D.downrank = { greater = "SoinsSup", heal = "Soins", flash = "Rapides", lesser = "SoinInf" }

-- Ce qu'un prêtre peut porter : armures (classe 4) en tissu ou divers (bijoux, anneaux, colliers),
-- armes (classe 2) : dague, masse à une main, bâton, baguette
D.priestArmor = { [0] = true, [1] = true }
D.priestWeapons = { [4] = true, [10] = true, [15] = true, [19] = true }

----------------------------------------------------------------------
-- Autres soigneurs (druide, paladin, chaman) : mêmes règles, leurs sorts. Numéros des sorts classiques, niveaux
-- d'apprentissage classiques ; un sort absent de Forever est simplement ignoré (le Diag le dit).
-- coef : coefficient imposé (Rétablissement : part directe) ; chain : soin en chaîne (1 + 0,5 + 0,25 cibles).
----------------------------------------------------------------------
D.classes = {
  PRIEST = { families = D.families, order = D.ORDER, downrank = D.downrank, armor = D.priestArmor, weapons = D.priestWeapons,
             main = { "greater", "heal", "lesser" }, fast = "flash" },
  DRUID = {
    families = {
      touch = { base = 3.5, ranks = { { 5185, 1, 1.5 }, { 5186, 8, 2.0 }, { 5187, 14, 2.5 }, { 5188, 20, 3.0 }, { 5189, 26 }, { 6778, 32 },
                                      { 8903, 38 }, { 9758, 44 }, { 9888, 50 }, { 9889, 56 }, { 25297, 60 } } },
      regrowth = { base = 2.0, coef = 0.286, ranks = { { 8936, 12 }, { 8938, 18 }, { 8939, 24 }, { 8940, 30 }, { 8941, 36 }, { 9750, 42 },
                                                       { 9856, 48 }, { 9857, 54 }, { 9858, 60 } } },
      rejuv = { hot = 12, ranks = { { 774, 4 }, { 1058, 10 }, { 1430, 16 }, { 2090, 22 }, { 2091, 28 }, { 3627, 34 }, { 8910, 40 },
                                    { 9839, 46 }, { 9840, 52 }, { 9841, 58 }, { 25299, 60 } } },
    },
    order = { "touch", "regrowth", "rejuv" }, downrank = { touch = "Toucher", regrowth = "Retab" }, main = { "touch" }, fast = "regrowth",
    armor = { [0] = true, [1] = true, [2] = true }, weapons = { [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
    defaults = { regenPerSpi = 0.1, intPerCritAt60 = 60 },
  },
  PALADIN = {
    families = {
      holy = { base = 2.5, ranks = { { 635, 1 }, { 639, 6 }, { 647, 14 }, { 1026, 22 }, { 1042, 30 }, { 3472, 38 }, { 10328, 46 },
                                     { 10329, 54 }, { 25292, 60 } } },
      flashl = { base = 1.5, ranks = { { 19750, 20 }, { 19939, 26 }, { 19940, 34 }, { 19941, 42 }, { 19942, 50 }, { 19943, 58 } } },
    },
    order = { "holy", "flashl" }, downrank = { holy = "LumSacree", flashl = "EclairLum" }, main = { "holy" }, fast = "flashl",
    armor = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [6] = true },
    weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    defaults = { regenPerSpi = 0.1, intPerCritAt60 = 54 },
  },
  SHAMAN = {
    families = {
      wave = { base = 3.0, ranks = { { 331, 1, 1.5 }, { 332, 6, 2.0 }, { 547, 12, 2.5 }, { 913, 18 }, { 939, 24 }, { 959, 32 },
                                     { 8005, 40 }, { 10395, 48 }, { 10396, 56 }, { 25357, 60 } } },
      lwave = { base = 1.5, ranks = { { 8004, 20 }, { 8008, 28 }, { 8010, 36 }, { 10466, 44 }, { 10467, 52 }, { 10468, 60 } } },
      chain = { base = 2.5, chain = true, targets = 1.75, ranks = { { 1064, 40 }, { 10622, 46 }, { 10623, 54 } } },
    },
    order = { "wave", "lwave", "chain" }, downrank = { wave = "VagueSoins", lwave = "VagueInf" }, main = { "wave" }, fast = "lwave",
    armor = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true },
    weapons = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
    defaults = { regenPerSpi = 0.1, intPerCritAt60 = 59.5 },
  },
}

-- Applique les données de la classe du personnage (appelé au chargement) ; false si la classe ne soigne pas
function ns.ApplyClass(class)
  local c = D.classes[class]
  if not c then return false end
  D.families, D.ORDER, D.downrank, D.priestArmor, D.priestWeapons = c.families, c.order, c.downrank, c.armor, c.weapons
  D.mixMain, D.mixFast = c.main, c.fast
  for k, v in pairs(c.defaults or {}) do D.defaults[k] = v end
  return true
end
ns.healer = ns.ApplyClass(select(2, UnitClass("player")))
