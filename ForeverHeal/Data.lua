local _, ns = ...

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
