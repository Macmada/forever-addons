local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverMetiers") end

-- Données de ForeverMetiers. Sources : guides mamytwink.com de WoW Forever (couture 28/10/2026, enchantement 30/10/2026,
-- métiers 03/11/2026), d'après la bêta et le classique : à confirmer en jeu (bouton Diag). L'addon s'appuie d'abord sur
-- ce que la fenêtre du métier donne vraiment (couleurs, composants, recettes connues) ; ces tables servent de guide.
local D = {}
ns.Data = D

-- Rangs : plafond, compétence et niveau requis pour l'apprendre
D.ranks = {
  { key = "apprentice", cap = 75, skill = 0, level = 0 },
  { key = "journeyman", cap = 150, skill = 50, level = 10 },
  { key = "expert", cap = 225, skill = 125, level = 20 },
  { key = "artisan", cap = 300, skill = 200, level = 35 },
}

D.profs = {
  tailoring = {
    names = { "Couture", "Tailoring" }, icon = "Interface\\Icons\\Trade_Tailoring",
    trainers = {
      journeyman = { all = "capitales, camp Taurajo, Baie-du-Butin, Île de Zéphras (Taleen Fil-Luisant, Othesia Trombecalme)" },
      expert = { Alliance = "Lawrence Schneider ou Georgio Bolero (Vieille ville, Hurlevent), Charles Worth (Dalaran, Alterac)",
                 Horde = "Josef Gregorian (Fossoyeuse)" },
      artisan = { Alliance = "Timothy Worthington (Theramore, Marécage d'Âprefange) ?", Horde = "Daryl Stack (Moulin-de-Tarren, Hautebrande) ?" },
    },
  },
  enchanting = {
    names = { "Enchantement", "Enchanting" }, icon = "Interface\\Icons\\Trade_Engraving",
    trainers = {
      journeyman = { all = "capitales, Vanessa Sellers (Dalaran), Xylinnia Starshine (Féralas)" },
      expert = { Alliance = "Kitta Firewind (tour d'Azora, Elwynn), Vanessa Sellers (Dalaran), Melanie Sable (Rives Claires)",
                 Horde = "Hgarth (Serres-Rocheuses)" },
      artisan = { all = "Annora (Uldaman, Terres ingrates : apparaît une fois la salle nettoyée) ?" },
    },
  },
}
-- Tous les métiers : ceux sans guide pas à pas (pas de « trainers » ni de « routes ») ont la partie générique :
-- compétence et rang, rappel du maître, meilleurs crafts d'après les couleurs de la fenêtre, recettes à apprendre (ATT)
local function Prof(fr, en, icon, skill, gather) return { names = { fr, en }, icon = "Interface\\Icons\\" .. icon, skill = skill, gather = gather } end
D.profs.tailoring.skill, D.profs.enchanting.skill = 197, 333
D.profs.alchemy = Prof("Alchimie", "Alchemy", "Trade_Alchemy", 171)
D.profs.blacksmithing = Prof("Forge", "Blacksmithing", "Trade_BlackSmithing", 164)
D.profs.leatherworking = Prof("Travail du cuir", "Leatherworking", "Trade_LeatherWorking", 165)
D.profs.engineering = Prof("Ingénierie", "Engineering", "Trade_Engineering", 202)
D.profs.cooking = Prof("Cuisine", "Cooking", "INV_Misc_Food_15", 185)
D.profs.firstaid = Prof("Secourisme", "First Aid", "Spell_Holy_SealOfSacrifice", 129)
D.profs.herbalism = Prof("Herboristerie", "Herbalism", "Trade_Herbalism", 182, true)
D.profs.mining = Prof("Minage", "Mining", "Trade_Mining", 186, true)
D.profs.skinning = Prof("Dépeçage", "Skinning", "INV_Misc_Pelt_Wolf_01", 393, true)
D.profs.fishing = Prof("Pêche", "Fishing", "Trade_Fishing", 356, true)
-- métiers avec guide pas à pas (couture, enchantement) ; D.allProfOrder : tous, dans l'ordre d'affichage
D.profOrder = { "tailoring", "enchanting" }
D.allProfOrder = { "tailoring", "enchanting", "alchemy", "blacksmithing", "leatherworking", "engineering",
                   "herbalism", "mining", "skinning", "cooking", "firstaid", "fishing" }
D.primary = { tailoring = true, enchanting = true, alchemy = true, blacksmithing = true, leatherworking = true, engineering = true,
              herbalism = true, mining = true, skinning = true }
-- Paire de métiers conseillée par classe (proposée tant que tu n'as pas tes deux métiers principaux)
D.classProfs = {
  PRIEST = { "tailoring", "enchanting" }, MAGE = { "tailoring", "enchanting" }, WARLOCK = { "tailoring", "enchanting" },
  WARRIOR = { "mining", "blacksmithing" }, PALADIN = { "mining", "blacksmithing" },
  ROGUE = { "skinning", "leatherworking" }, HUNTER = { "skinning", "leatherworking" },
  DRUID = { "skinning", "leatherworking" }, SHAMAN = { "skinning", "leatherworking" },
}
-- Patron ou recette (classe d'objet 9) : sous-classe -> métier
D.recipeSub = { [1] = "leatherworking", [2] = "tailoring", [3] = "engineering", [4] = "blacksmithing", [5] = "cooking",
                [6] = "alchemy", [7] = "firstaid", [8] = "enchanting", [9] = "fishing" }

-- Noms français des composants (affichés tant que le jeu n'a pas chargé l'objet)
D.matNames = {
  [2589] = "Étoffe de lin", [2996] = "Rouleau d'étoffe en lin", [2320] = "Bobine de fil grossier", [2592] = "Étoffe de laine",
  [2997] = "Rouleau d'étoffe de laine", [2321] = "Bobine de fil raffiné", [4340] = "Teinture grise", [4306] = "Étoffe de soie",
  [4305] = "Rouleau d'étoffe de soie", [6260] = "Teinture bleue", [2324] = "Décolorant", [4338] = "Étoffe de tisse-mage",
  [4339] = "Rouleau de tisse-mage", [4291] = "Bobine de soie", [2604] = "Teinture rouge", [8343] = "Bobine de soie lourde",
  [14047] = "Étoffe runique", [14048] = "Rouleau d'étoffe runique", [14341] = "Fil runique", [8170] = "Cuir robuste",
  [14227] = "Soie d'araignée toilacier", [14343] = "Petit éclat brillant", [7082] = "Essence d'air",
  [6217] = "Bâtonnet en cuivre", [247786] = "Granule de magie", [10940] = "Poussière étrange", [10938] = "Essence de magie inférieure",
  [10939] = "Essence de magie supérieure", [6338] = "Bâtonnet en argent", [1210] = "Œil ténébreux", [10978] = "Petit éclat scintillant",
  [11083] = "Poussière d'âme", [11128] = "Bâtonnet doré", [5500] = "Perle iridescente", [11082] = "Essence astrale supérieure",
  [10998] = "Essence astrale inférieure", [11084] = "Gros éclat scintillant", [11134] = "Essence mystique inférieure",
  [11135] = "Essence mystique supérieure", [11137] = "Poussière de vision", [11138] = "Petit éclat luminescent",
  [11139] = "Gros éclat luminescent", [11144] = "Bâtonnet en vrai-argent", [7971] = "Perle noire", [11174] = "Essence du néant inférieure",
  [11175] = "Essence du néant supérieure", [11176] = "Poussière de rêve", [11177] = "Petit éclat irradiant", [11178] = "Gros éclat irradiant",
  [8153] = "Sauvageonne", [16202] = "Essence éternelle inférieure", [16203] = "Essence éternelle supérieure", [16204] = "Poudre d'illusion",
  [14344] = "Grand éclat brillant", [20725] = "Cristal de nexus", [14342] = "Étoffe lunaire", [274030] = "Essence malléable de la nature",
}
-- Composants vendus par les fournisseurs (fil, teintures, bâtonnets) : jamais à chercher à l'hôtel des ventes
D.vendorMats = { [2320] = true, [2321] = true, [4291] = true, [8343] = true, [14341] = true, [4340] = true, [6260] = true,
                 [2604] = true, [2324] = true, [6217] = true }

-- Parcours de montée (guides mamytwink) : de, à, « i » objet fabriqué / « s » sort (enchantement), numéro, nombre de
-- fabrications, nom français, composants pour toute l'étape { id, quantité, ... }
local function R(from, to, kind, id, n, name, mats)
  local m = {}
  for i = 1, #mats, 2 do m[#m + 1] = { id = mats[i], n = mats[i + 1] } end
  return { from = from, to = to, item = kind == "i" and id or nil, spell = kind == "s" and id or nil, n = n, name = name, mats = m }
end
D.routes = {
  tailoring = {
    R(1, 25, "i", 2996, 25, "Rouleau d'étoffe en lin", { 2589, 50 }),
    R(25, 50, "i", 7026, 25, "Ceinture en lin", { 2996, 25, 2320, 25 }),
    R(50, 60, "i", 2580, 10, "Cape en lin renforcé", { 2996, 20, 2320, 30 }),
    R(60, 70, "i", 2997, 10, "Rouleau d'étoffe de laine", { 2592, 30 }),
    R(70, 80, "i", 2584, 10, "Cape en laine", { 2997, 10, 2321, 10 }),
    R(80, 90, "i", 2587, 10, "Chemise grise en laine", { 2997, 20, 2321, 10, 4340, 10 }),
    R(90, 100, "i", 4314, 10, "Épaulières à double couture en laine", { 2997, 30, 2321, 20 }),
    R(100, 115, "i", 4305, 17, "Rouleau d'étoffe de soie", { 4306, 68 }),
    R(115, 120, "i", 7046, 5, "Pantalon azur en soie", { 4305, 20, 6260, 10, 2321, 15 }),
    R(120, 130, "i", 7048, 10, "Chaperon azur en soie", { 4305, 20, 6260, 20, 2321, 10 }),
    R(130, 135, "i", 7050, 5, "Bandeau en soie", { 4305, 15, 2321, 10 }),
    R(135, 140, "i", 4334, 5, "Chemise blanche habillée", { 4305, 15, 2324, 10, 2321, 5 }),
    R(140, 145, "i", 4339, 5, "Rouleau de tisse-mage", { 4338, 25 }),
    R(145, 150, "i", 7057, 5, "Épaulières vertes en soie", { 4305, 25, 4291, 10 }),
    R(150, 170, "i", 7058, 20, "Gilet cramoisi en soie", { 4305, 80, 2604, 40, 2321, 40 }),
    R(170, 185, "i", 9998, 15, "Gilet noir en tisse-mage", { 4339, 30, 4291, 45 }),
    R(185, 195, "i", 10003, 10, "Gants noirs en tisse-mage", { 4339, 20, 8343, 20 }),
    R(195, 205, "i", 10024, 10, "Bandeau noir en tisse-mage", { 4339, 30, 8343, 20 }),
    R(205, 210, "i", 14048, 5, "Rouleau d'étoffe runique", { 14047, 25 }),
    R(210, 230, "i", 13856, 22, "Ceinture en étoffe runique", { 14048, 66, 14341, 22 }),
    R(230, 250, "i", 13863, 22, "Gants en étoffe runique", { 14048, 88, 8170, 88, 14341, 22 }),
    R(250, 280, "i", 254123, 35, "Crispins en étoffe runique", { 14048, 175, 14227, 35, 14341, 35 }),
    R(280, 285, "i", 13867, 7, "Épaulières en étoffe runique", { 14048, 49, 14227, 14, 8170, 28, 14341, 7 }),
    R(285, 290, "i", 275604, 5, "Gants de crache-venin", { 14048, 20, 14343, 5, 7082, 15, 14341, 30 }),
    R(290, 295, "i", 275605, 5, "Corde de crache-venin", { 14048, 30, 14343, 5, 7082, 15, 14341, 30 }),
    R(295, 300, "i", 275606, 7, "Souliers de crache-venin", { 14048, 35, 14343, 7, 7082, 21, 14341, 42 }),
  },
  enchanting = {
    R(1, 2, "i", 6218, 1, "Bâtonnet runique en cuivre", { 6217, 1, 247786, 1 }),
    R(2, 20, "s", 7418, 18, "Enchantement de brassards (Endurance médiocre)", { 247786, 18 }),
    R(20, 70, "s", 7420, 50, "Enchantement de plastron (Endurance médiocre)", { 10940, 50 }),
    R(70, 90, "s", 7426, 20, "Enchantement de plastron (Absorption mineure)", { 10938, 20 }),
    R(90, 100, "s", 7457, 10, "Enchantement de brassards (Endurance mineure)", { 10940, 20 }),
    R(100, 101, "i", 6339, 1, "Bâtonnet runique en argent", { 6338, 1, 10940, 3, 10938, 4, 1210, 1 }),
    R(101, 110, "s", 7771, 9, "Enchantement de cape (Protection mineure)", { 10940, 18 }),
    R(110, 130, "s", 7745, 20, "Enchantement d'arme 2M (Impact mineur)", { 10940, 20, 10978, 20 }),
    R(130, 155, "s", 13501, 25, "Enchantement de brassards (Endurance inférieure)", { 11083, 25 }),
    R(155, 156, "i", 11130, 1, "Bâtonnet runique en or", { 11128, 1, 5500, 1, 11082, 1, 11083, 1 }),
    R(156, 160, "s", 13607, 4, "Enchantement de plastron (Intelligence)", { 11082, 4 }),
    R(160, 180, "s", 13637, 20, "Enchantement de bottes (Agilité inférieure)", { 11083, 20 }),
    R(180, 200, "s", 13661, 20, "Enchantement de brassards (Force)", { 11137, 20 }),
    R(200, 201, "i", 11145, 1, "Bâtonnet runique en vrai-argent", { 11144, 1, 7971, 1, 11135, 1, 11137, 1 }),
    R(201, 205, "s", 13663, 4, "Enchantement de plastron (Intelligence supérieure)", { 11134, 4 }),
    R(205, 225, "s", 13746, 20, "Enchantement de cape (Défense supérieure)", { 11137, 20 }),
    R(225, 230, "s", 13815, 5, "Enchantement de gants (Agilité)", { 11137, 5 }),
    R(230, 235, "s", 13836, 5, "Enchantement de bottes (Endurance)", { 11137, 10 }),
    R(235, 240, "s", 13858, 5, "Enchantement de plastron (Endurance excellente)", { 11137, 15 }),
    R(240, 245, "s", 13887, 5, "Enchantement de gants (Force)", { 11174, 5, 11137, 10 }),
    R(245, 250, "s", 13905, 5, "Enchantement de bouclier (Esprit supérieur)", { 11174, 10, 11176, 5 }),
    R(250, 255, "s", 13935, 5, "Enchantement de bottes (Agilité)", { 11175, 5 }),
    R(255, 260, "s", 13939, 5, "Enchantement de brassards (Force supérieure)", { 11176, 5, 11174, 10 }),
    R(260, 270, "s", 13948, 10, "Enchantement de gants (Hâte mineure)", { 11178, 10, 8153, 10 }),
    R(270, 285, "s", 20017, 15, "Enchantement de bouclier (Endurance supérieure)", { 11176, 90 }),
    R(285, 300, "s", 20015, 15, "Enchantement de cape (Défense excellente)", { 16204, 120 }),
  },
}

-- Désenchantement : niveau d'objet maximal -> poussière, essence, éclat (+ compétence requise, valeurs du classique)
D.disenchant = {
  { max = 15, dust = 10940, ess = 10938, skill = 1 },
  { max = 20, dust = 10940, ess = 10939, shard = 10978, skill = 1 },
  { max = 25, dust = 10940, ess = 10998, shard = 10978, skill = 25 },
  { max = 30, dust = 11083, ess = 11082, shard = 11084, skill = 50 },
  { max = 35, dust = 11083, ess = 11134, shard = 11138, skill = 75 },
  { max = 40, dust = 11137, ess = 11135, shard = 11139, skill = 100 },
  { max = 45, dust = 11137, ess = 11174, shard = 11177, skill = 125 },
  { max = 50, dust = 11176, ess = 11175, shard = 11178, skill = 150 },
  { max = 55, dust = 11176, ess = 16202, shard = 14343, skill = 175 },
  { max = 65, dust = 16204, ess = 16203, shard = 14344, skill = 200 },
  { max = 999, dust = 16204, ess = 16203, shard = 14344, nexus = 20725, skill = 225 },
}
-- Emplacements qu'on ne désenchante pas
D.noDE = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true, INVTYPE_AMMO = true }
D.disenchantSpell = 13262

-- Enchantements utiles à un soigneur. slot : emplacement porté ; two : arme à deux mains seulement ; off : main gauche tenue ;
-- d : gain de caractéristiques (repris de la description du jeu quand la formule est connue) ; src : où l'obtenir
local function E(spell, skill, slot, name, d, src, extra)
  local e = { spell = spell, skill = skill, slot = slot, name = name, d = d, src = src }
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end
D.healEnchants = {
  -- poignets
  E(1248458, 70, 9, "Brassards (Intelligence mineure)", { int = 3 }, "butin : Chasse-marée Aileron noir (Forêt des Pins-Argentés)", { new = true }),
  E(1248459, 90, 9, "Brassards (Pouvoir de guérison mineur)", { heal = 8 }, "butin : Sectateur de la Rive noire (Orneval)", { new = true }),
  E(7859, 120, 9, "Brassards (Esprit inférieur)", { spi = 3 }, "butin : monstres niv. 16-26"),
  E(13622, 150, 9, "Brassards (Intelligence inférieure)", { int = 3 }, "maître Expert"),
  E(13642, 165, 9, "Brassards (Esprit)", { spi = 5 }, "maître Expert"),
  E(1248498, 205, 9, "Brassards (Pouvoir de guérison inférieur)", { heal = 16 }, "Désolace : Molkar / Gorhak (totems centaures) ou quête « Mysterious Mysticism » ?", { new = true }),
  E(13822, 210, 9, "Brassards (Intelligence)", { int = 5 }, "maître Expert"),
  E(13846, 220, 9, "Brassards (Esprit supérieur)", { spi = 7 }, "butin : monstres niv. 36-50"),
  E(23801, 290, 9, "Brassards (Régénération de mana)", { mp5 = 4 }, "Aube d'argent, Honoré ?"),
  E(1248661, 300, 9, "Brassards (Intelligence excellente)", { int = 9 }, "faveur marchande (240), Honoré", { new = true }),
  E(23802, 300, 9, "Brassards (Pouvoir de guérison)", { heal = 24 }, "Aube d'argent, Révéré ?"),
  -- torse
  E(7443, 20, 5, "Plastron (Intelligence mineure)", { int = 2 }, "butin niv. 9-20, Jessara Cordell (Hurlevent), Nata Dawnstrider (Pitons-du-Tonnerre)"),
  E(7776, 80, 5, "Plastron (Intelligence inférieure)", { int = 3 }, "Kithas (Orgrimmar), Lilly (Pins-Argentés), Sorcière des mers Irequeue (Orneval)"),
  E(13607, 145, 5, "Plastron (Intelligence)", { int = 4 }, "maître Compagnon"),
  E(13626, 150, 5, "Plastron (Caractéristiques mineures)", { sta = 1, int = 1, spi = 1 }, "maître Expert"),
  E(13663, 185, 5, "Plastron (Intelligence supérieure)", { int = 6 }, "maître Expert"),
  E(13700, 200, 5, "Plastron (Caractéristiques inférieures)", { sta = 2, int = 2, spi = 2 }, "maître Expert"),
  E(13941, 245, 5, "Plastron (Caractéristiques)", { sta = 3, int = 3, spi = 3 }, "maître Artisan ?"),
  E(20025, 300, 5, "Plastron (Caractéristiques supérieures)", { sta = 4, int = 4, spi = 4 }, "butin (classique) ?"),
  -- cou (nouveau dans Forever)
  E(1249057, 210, 2, "Collier (Puissance des sorts)", { heal = 6 }, "faveur marchande (120), Amical", { new = true }),
  E(1249058, 210, 2, "Collier (Pouvoir de guérison)", { heal = 11 }, "faveur marchande (120), Amical", { new = true }),
  -- pieds, mains
  E(13687, 190, 8, "Bottes (Esprit inférieur)", { spi = 3 }, "butin : monstres niv. 35-40"),
  E(20024, 275, 8, "Bottes (Esprit)", { spi = 5 }, "butin (classique) ?"),
  E(25079, 300, 10, "Gants (Pouvoir de guérison)", { heal = 30 }, "butin : Temple d'Ahn'Qiraj ?"),
  -- armes
  E(13380, 110, 16, "Arme 2M (Esprit inférieur)", { spi = 3 }, "butin : monstres niv. 12-26", { two = true }),
  E(7793, 100, 16, "Arme 2M (Intelligence inférieure)", { int = 3 }, "Tilli Thistlefuzz (Forgefer), Kithas, Leo Sarn", { two = true }),
  E(20035, 300, 16, "Arme 2M (Esprit majeur)", { spi = 9 }, "butin (classique) ?", { two = true }),
  E(20036, 300, 16, "Arme 2M (Intelligence majeure)", { int = 9 }, "butin (classique) ?", { two = true }),
  E(1248607, 300, 16, "Arme 2M (Puissance des sorts supérieure)", { heal = 55 }, "faveur marchande (240), Honoré", { two = true, new = true }),
  E(1248636, 300, 16, "Arme 2M (Puissance des soins supérieure)", { heal = 100 }, "faveur marchande (240), Honoré", { two = true, new = true }),
  E(23803, 300, 16, "Arme (Esprit puissant)", { spi = 20 }, "Confrérie du thorium ? (classique)"),
  E(22750, 300, 16, "Arme (Pouvoir de guérison)", { heal = 55 }, "classique : à vérifier dans Forever"),
  E(1219579, 300, 17, "Main gauche (Sagesse)", { int = 6, spi = 5 }, "faveur marchande (240), Honoré", { off = true, new = true }),
}

-- Emplacements à enchanter (ordre d'affichage)
D.enchantSlots = { 5, 9, 2, 10, 8, 16, 17 }

-- Patrons de couture et objets à connaître. id : numéro donné par le guide (objet fabriqué ou patron : le diagnostic le dit) ;
-- heal : intéressant pour un soigneur (à confirmer en jeu par ForeverHeal quand l'objet est connu)
local function P(skill, name, id, src, extra)
  local p = { skill = skill, name = name, id = id, src = src }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
D.patterns = {
  tailoring = {
    P(20, "Bannière de faction", nil, "maître ou quête d'introduction du camp (feu de camp : Esprit du groupe)", { camp = true }),
    P(140, "Rouet", 279943, "plan sur la Sentinelle instable (Montagnes d'Alterac) ; remplace la bannière", { camp = true }),
    P(300, "Métier à tisser", 279959, "source non précisée", { camp = true }),
    P(105, "Gants de méditation", 4318, "maître Compagnon", { heal = true }),
    P(125, "Gants de vraie foi", 7049, "butin", { heal = true }),
    P(125, "Robe d'Arcana", 5770, "butin : Enchanteur défias (Bois de la Pénombre), Rive noire (Sombrivage)", { heal = true }),
    P(110, "Robe immaculée", 253961, "faveur marchande (30)", { heal = true, new = true }),
    P(100, "Diadème immaculé", 253949, "faveur marchande (30)", { heal = true, new = true }),
    P(125, "Jambières immaculées", 253987, "faveur marchande (30)", { heal = true, new = true }),
    P(75, "Gants immaculés", 253913, "faveur marchande (30)", { heal = true, new = true }),
    P(60, "Bottes immaculées", 253889, "faveur marchande (30)", { heal = true, new = true }),
    P(85, "Écharpe immaculée", 253925, "faveur marchande (30)", { heal = true, new = true }),
    P(75, "Robe immaculée filigranée", 253901, "butin : Mortemines, Donjon d'Ombrecroc, Gouffre de Ragefeu", { heal = true, new = true }),
    P(100, "Jambières immaculées filigranées", 253937, "butin : La Prison, Brassenoire, Ombrecroc, Mortemines", { heal = true, new = true }),
    P(125, "Diadème immaculé filigrané", 253975, "butin : Monastère écarlate, La Prison, Brassenoire, Kraal de Tranchebauge", { heal = true, new = true }),
    P(60, "Gilet fil-tempête azur", 277034, "Druides de la Noctegriffe (Zéphras), Honoré", { heal = true, new = true }),
    P(60, "Jambières fil-tempête azur", 277038, "Druides de la Noctegriffe (Zéphras), Honoré", { heal = true, new = true }),
    P(175, "Capuche fil-tempête azur", 277054, "Archimage Alvareaux (Alterac), Kirin Tor Amical", { heal = true, new = true }),
    P(175, "Épaulettes fil-tempête azur", 277055, "Archimage Alvareaux (Alterac), Kirin Tor Amical", { heal = true, new = true }),
    P(190, "Gants en tisse-rêve", 10019, "maître Expert", { heal = true }),
    P(190, "Gilet en tisse-rêve", 10021, "maître Expert", { heal = true }),
    P(205, "Diadème en tisse-rêve", 10041, "maître Expert", { heal = true }),
    P(195, "Épaulières de lumière-du-Néant", 254059, "faveur marchande (60), Amical", { heal = true, new = true }),
    P(205, "Crispins de lumière-du-Néant", 254071, "faveur marchande (60), Amical", { heal = true, new = true }),
    P(215, "Corde cintrée radieuse", 254091, "faveur marchande (60), Amical", { heal = true, new = true }),
    P(250, "Crispins en étoffe runique", 254124, "Pexmit (Mont Hyjal, 10 po)", { new = true }),
    P(265, "Gilet en étoffe lunaire", nil, "à confirmer (guide)", { heal = true }),
    P(280, "Épaulières en étoffe lunaire", nil, "à confirmer (guide)", { heal = true }),
    P(285, "Diadème en étoffe lunaire", nil, "à confirmer (guide)", { heal = true }),
    P(300, "Habit de vraie foi", nil, "butin (classique : Stratholme ?)", { heal = true }),
    P(300, "Robe de l'archimage", nil, "butin", { heal = true }),
    P(300, "Habits de conviction (prêtre, ensemble de raid)", nil, "Aisarra Nightmeadow (Mont Hyjal), Essence malléable de la nature", { heal = true, new = true }),
  },
  enchanting = {
    P(20, "Luth enchanté", 279976, "maître (feu de camp : armure, caractéristiques, résistances)", { camp = true }),
    P(140, "Récupérateur arcanique", 279985, "plan : Rath'mael, Ombre de l'archimage, Charlga Trancheflanc ; améliore le désenchantement", { camp = true }),
    P(300, "Forge arcanique", 279987, "source inconnue", { camp = true }),
    P(1, "Bâtonnet runique en cuivre", 6218, "connu dès l'apprentissage", { rod = true }),
    P(100, "Bâtonnet runique en argent", 6339, "maître Compagnon", { rod = true }),
    P(150, "Bâtonnet runique en or", 11130, "maître Expert", { rod = true }),
    P(200, "Bâtonnet runique en vrai-argent", 11145, "maître Expert", { rod = true }),
    P(290, "Bâtonnet runique en arcanite", 16207, "Lorelae Wintersong (Reflet-de-Lune)", { rod = true }),
    P(140, "Bâton des âmes", 249393, "faveur marchande (45) : +11 End., +11 Esprit, +34 soins", { heal = true, new = true }),
    P(140, "Orbe des âmes", 249395, "faveur marchande (45) : +6 Esprit, +13 soins", { heal = true, new = true }),
    P(220, "Bâton onirique", 249454, "faveur marchande (120) : +19 End., +19 Esprit, +105 soins", { heal = true, new = true }),
    P(220, "Jarre d'essence distordue", 249456, "faveur marchande (120) : +8 End., +8 Esprit, +19 soins", { heal = true, new = true }),
    P(275, "Baguette brillante", 249385, "+7 Intelligence, +9 soins", { heal = true, new = true }),
    P(300, "Torche de lumière", 279246, "+11 Esprit, +17 soins", { heal = true, new = true }),
  },
}

-- Les rangs et feux de camp : objets à vérifier dans le diagnostic
D.checkItems = { 279972, 279973, 279943, 279959, 279976, 279985, 279987, 247786, 249385, 279246 }

-- Capitale la plus proche selon la race (maîtres Apprenti et Compagnon des deux métiers)
D.capital = {
  Human = "Hurlevent", Dwarf = "Forgefer", Gnome = "Forgefer", NightElf = "Darnassus",
  Orc = "Orgrimmar", Troll = "Orgrimmar", Tauren = "Pitons-du-Tonnerre", Scourge = "Fossoyeuse", Undead = "Fossoyeuse",
}
D.capitalEn = {
  Human = "Stormwind", Dwarf = "Ironforge", Gnome = "Ironforge", NightElf = "Darnassus",
  Orc = "Orgrimmar", Troll = "Orgrimmar", Tauren = "Thunder Bluff", Scourge = "Undercity", Undead = "Undercity",
}

-- Étoffes : sur quels monstres (humanoïdes) les trouver, par niveau
D.cloth = {
  [2589] = { 5, 15 }, [2592] = { 15, 25 }, [4306] = { 25, 35 }, [4338] = { 35, 45 }, [14047] = { 45, 60 },
}

-- Fenêtre « à ta portée » : objets jusqu'à ton niveau + 5, recettes jusqu'à ta compétence + 30
D.nearLevel, D.nearSkill = 5, 30
