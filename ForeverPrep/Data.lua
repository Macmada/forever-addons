local _, ns = ...

-- Base de données de ForeverPrep (WoW Forever : contenu classique, niveaux 1 à 60).
-- Objets : { id, niveau requis indicatif }. Au chargement, l'addon demande au jeu le vrai nom et le vrai niveau requis
-- (GetItemInfo) : un objet absent du client Forever est ignoré, et le niveau du jeu l'emporte sur celui écrit ici.
-- Sorts : par numéro (nom traduit par le jeu). Un sort n'est vérifié que si tu le connais (rang quelconque).

local D = {}
ns.Data = D

----------------------------------------------------------------------
-- Consommables : chaque catégorie = une ligne de la fiche. « need » = quantité conseillée {donjon, raid}.
-- roles : rôles concernés (tank, heal, melee, caster) ; mana = seulement les classes à mana.
----------------------------------------------------------------------
D.consumables = {
  {
    key = "healpot", need = { 5, 10 }, roles = "all",
    items = { { 118, 1 }, { 858, 3 }, { 929, 12 }, { 1710, 21 }, { 3928, 35 }, { 13446, 45 } },
    -- pierres de soins des démonistes : comptent comme soins, jamais à acheter
    extra = { { 5512, 1 }, { 5511, 1 }, { 5509, 1 }, { 5510, 1 }, { 9421, 1 } },
  },
  {
    key = "manapot", need = { 5, 10 }, roles = "all", mana = true,
    items = { { 2455, 5 }, { 3385, 14 }, { 3827, 22 }, { 6149, 31 }, { 13443, 41 }, { 13444, 49 } },
  },
  {
    key = "food", need = { 20, 20 }, roles = "all",
    items = {
      { 4540, 1 }, { 4541, 5 }, { 4542, 15 }, { 4544, 25 }, { 4601, 35 }, { 8950, 45 },          -- pains
      { 117, 1 }, { 2287, 5 }, { 3770, 15 }, { 3771, 25 }, { 4599, 35 }, { 8952, 45 },           -- viandes
      { 2070, 1 }, { 414, 5 }, { 422, 15 }, { 1707, 25 }, { 3927, 35 }, { 8932, 45 },             -- fromages
      { 4536, 1 }, { 4537, 5 }, { 4538, 15 }, { 4539, 25 }, { 4602, 35 }, { 8953, 45 },           -- fruits
    },
    extra = { { 5349, 1 }, { 1113, 5 }, { 1114, 15 }, { 1487, 25 }, { 8075, 35 }, { 8076, 45 } },  -- pain du mage
  },
  {
    key = "water", need = { 20, 40 }, roles = "all", mana = true,
    items = { { 159, 1 }, { 1179, 5 }, { 1205, 15 }, { 1708, 25 }, { 1645, 35 }, { 8766, 45 } },
    extra = { { 5350, 1 }, { 2288, 5 }, { 2136, 15 }, { 3772, 25 }, { 8077, 35 }, { 8078, 45 }, { 8079, 55 } },  -- eau du mage
  },
  {
    key = "bandage", need = { 10, 20 }, roles = "all", noBuy = true,      -- fabriqués (Secourisme), pas vendus
    items = { { 1251, 1 }, { 2581, 1 }, { 3530, 1 }, { 3531, 1 }, { 6450, 1 }, { 6451, 1 },
              { 8544, 1 }, { 8545, 1 }, { 14529, 1 }, { 14530, 1 } },
  },
  {
    key = "statfood", need = { 5, 10 }, roles = "all", minLevel = 20, optional = true, noBuy = true,
    items = { { 2680, 1 }, { 2682, 5 }, { 12210, 30 }, { 13928, 35 }, { 13931, 35 }, { 12218, 40 }, { 18045, 40 },
              { 18254, 45 }, { 21023, 45 }, { 20452, 45 } },
  },
}

-- Élixirs et flacons : conseillés surtout en raid (et à partir du niveau 25 en donjon), selon le rôle.
D.elixirs = {
  tank = { { 3825, 25 }, { 8951, 29 }, { 13445, 43 }, { 9206, 38 }, { 13455, 46 }, { 20004, 51 }, { 13510, 50 } },
  melee = { { 3390, 4 }, { 2454, 1 }, { 8949, 27 }, { 3391, 20 }, { 9187, 38 }, { 9206, 38 }, { 13452, 46 },
            { 12451, 55 }, { 12460, 55 }, { 13510, 50 } },
  caster = { { 9179, 37 }, { 13447, 44 }, { 13454, 47 }, { 21546, 40 }, { 9264, 40 }, { 17708, 40 }, { 13512, 50 } },
  heal = { { 9179, 37 }, { 13447, 44 }, { 20007, 40 }, { 13511, 50 } },
}
D.elixirNeed = { 2, 5 }

-- Pierres à aiguiser, à lester, huiles : amélioration temporaire d'arme (conseillée, pas obligatoire)
D.weaponBoost = {
  melee = { { 2862, 1 }, { 2863, 15 }, { 2871, 25 }, { 7964, 35 }, { 12404, 45 }, { 18262, 50 },
            { 3239, 1 }, { 3240, 15 }, { 3241, 25 }, { 7965, 35 }, { 12643, 45 } },
  caster = { { 20744, 5 }, { 20746, 15 }, { 20750, 30 }, { 20749, 45 } },
  heal = { { 20745, 20 }, { 20747, 40 }, { 20748, 45 } },
}

----------------------------------------------------------------------
-- Composants de classe : item, quantité {donjon, raid}, spells = sorts qui les consomment (un seul connu suffit),
-- unless = sorts de rang supérieur qui en utilisent un autre (si connus, ce composant n'est plus demandé).
----------------------------------------------------------------------
D.reagents = {
  WARLOCK = { { item = 6265, need = { 5, 10 }, spells = { 693 } } },                          -- Fragment d'âme
  MAGE = {
    { item = 17031, need = { 3, 5 }, spells = { 3561, 3562, 3565, 3567, 3563, 3566 } },        -- Rune de téléportation
    { item = 17032, need = { 2, 5 }, spells = { 10059, 11416, 11419, 11417, 11418, 11420 } },  -- Rune des portails
    { item = 17020, need = { 0, 20 }, spells = { 23028 } },                                    -- Poudre des arcanes
    { item = 17056, need = { 5, 5 }, spells = { 130 } },                                       -- Plume légère
  },
  PRIEST = {
    { item = 17028, need = { 0, 20 }, spells = { 21562 }, unless = { 21564 } },                -- Bougie sacrée
    { item = 17029, need = { 0, 20 }, spells = { 21564 } },                                    -- Bougie consacrée
    { item = 17056, need = { 5, 5 }, spells = { 1706 } },                                      -- Plume légère
  },
  DRUID = {
    { item = 17034, need = { 1, 2 }, spells = { 20484 }, unless = { 20739, 20742, 20747, 20748 } },  -- graines de
    { item = 17035, need = { 1, 2 }, spells = { 20739 }, unless = { 20742, 20747, 20748 } },         -- Renaissance,
    { item = 17036, need = { 1, 2 }, spells = { 20742 }, unless = { 20747, 20748 } },                -- une par rang
    { item = 17037, need = { 1, 2 }, spells = { 20747 }, unless = { 20748 } },
    { item = 17038, need = { 1, 2 }, spells = { 20748 } },
    { item = 17021, need = { 0, 20 }, spells = { 21849 }, unless = { 21850 } },                -- Baies sauvages
    { item = 17026, need = { 0, 20 }, spells = { 21850 } },                                    -- Ronceracine sauvage
  },
  PALADIN = {
    { item = 17033, need = { 1, 2 }, spells = { 19752 } },                                     -- Symbole de divinité
    { item = 21177, need = { 0, 40 }, spells = { 25782, 25894, 25898, 25895, 25890, 25899 } }, -- Symbole des rois
  },
  SHAMAN = { { item = 17030, need = { 1, 2 }, spells = { 20608 } } },                         -- Ankh
  ROGUE = {
    { item = 5140, need = { 5, 10 }, spells = { 1856 } },                                      -- Poudre éclipsante
    { item = 5530, need = { 3, 5 }, spells = { 2094 } },                                       -- Poudre aveuglante
  },
}

-- Poisons du voleur : une ligne « poisons », meilleur rang utilisable (niveau requis lu dans le jeu)
D.poisons = {
  { 6947, 20 }, { 6949, 28 }, { 6950, 36 }, { 8926, 44 }, { 8927, 52 }, { 8928, 60 },     -- Instantané I à VI
  { 2892, 30 }, { 2893, 38 }, { 8984, 46 }, { 8985, 54 }, { 20844, 60 },                  -- Mortel I à V
}
D.poisonNeed = { 10, 20 }

-- Munitions du chasseur (selon l'arme à distance équipée) et quantités
D.ammo = {
  arrow = { { 2512, 1 }, { 2515, 10 }, { 3030, 25 }, { 11285, 40 }, { 18042, 52 } },
  bullet = { { 2516, 1 }, { 2519, 10 }, { 3033, 25 }, { 11284, 40 }, { 15997, 52 } },
}
D.ammoNeed = { 1000, 2000 }

----------------------------------------------------------------------
-- Améliorations (buffs). Liste d'alternatives : n'importe laquelle suffit.
-- self = sur toi ; group = à donner au groupe (vérifié sur chaque membre à portée) ; role = seulement pour ce rôle.
----------------------------------------------------------------------
D.buffs = {
  PRIEST = {
    { self = true, spells = { 588 } },                                           -- Feu intérieur
    { group = true, spells = { 1243, 21562 } },                                  -- Mot de pouvoir : Robustesse / Prière
    { group = true, spells = { 14752, 27681 } },                                 -- Esprit divin / Prière d'esprit
  },
  MAGE = {
    { self = true, spells = { 168, 7302, 6117 } },                               -- Armure de givre / de glace / du mage
    { group = true, spells = { 1459, 23028 }, manaOnly = true },                 -- Intelligence des arcanes / Illumination
  },
  WARLOCK = {
    { self = true, spells = { 687, 706 } },                                      -- Peau / Armure démoniaque
    { pet = true },
  },
  DRUID = {
    { group = true, spells = { 1126, 21849 } },                                  -- Marque / Don du fauve
    { self = true, spells = { 467 }, role = "tank" },                            -- Épines
  },
  PALADIN = {
    { self = true, spells = { 465, 7294, 19746, 19876, 19888, 19891, 20218 } },  -- une aura
    { self = true, spells = { 25780 }, role = "tank" },                          -- Fureur vertueuse
    { group = true, spells = { 19740, 19742, 20217, 1038, 19977, 20911, 25782, 25894, 25898, 25895, 25890, 25899 } },
  },
  HUNTER = {
    { self = true, spells = { 13165, 13163, 20043 } },                           -- Aspect du faucon / du singe / sauvage
    { self = true, spells = { 19506 } },                                         -- Aura de précision (talent)
    { pet = true, happy = true },
  },
  SHAMAN = {
    { self = true, spells = { 324 }, role = "caster" },                          -- Bouclier de foudre
    { weapon = true },                                                           -- arme imprégnée
  },
  ROGUE = { { weapon = true, poisons = true, minLevel = 20 } },
  WARRIOR = {},
}

-- Classes à mana
D.manaClass = { PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true }

-- Rôle par défaut selon l'arbre de talents le plus rempli (1, 2, 3)
D.roleByTree = {
  WARRIOR = { "melee", "melee", "tank" },
  PALADIN = { "heal", "tank", "melee" },
  HUNTER = { "melee", "melee", "melee" },        -- « melee » = dégâts physiques (agilité) pour les consommables
  ROGUE = { "melee", "melee", "melee" },
  PRIEST = { "heal", "heal", "caster" },
  SHAMAN = { "caster", "melee", "heal" },
  MAGE = { "caster", "caster", "caster" },
  WARLOCK = { "caster", "caster", "caster" },
  DRUID = { "caster", "tank", "heal" },
}
D.ROLES = { "tank", "heal", "melee", "caster" }

D.HEARTHSTONE = 6948
