-- Simulation hors jeu de ForeverMetiers (Lua 5.1). Lancer depuis la racine : lua5.1 tests/metiers_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check

-- Objets : id -> { nom, emplacement, classe, sous-classe, qualité, niveau d'objet, niveau requis, caractéristiques }
local ITEMS = {
  [4338] = { "Étoffe de tisse-mage", "", 7, 5, 1, 35, 0 },
  [4339] = { "Rouleau de tisse-mage", "", 7, 5, 1, 35, 0 },
  [4305] = { "Rouleau d'étoffe de soie", "", 7, 5, 1, 30, 0 },
  [4291] = { "Bobine de soie", "", 7, 5, 1, 30, 0 },
  [7057] = { "Épaulières vertes en soie", "INVTYPE_SHOULDER", 4, 1, 2, 30, 25, { heal = 0 } },
  [4318] = { "Gants de méditation", "INVTYPE_HAND", 4, 1, 2, 27, 22, { heal = 12 } },
  [2576] = { "Chemise blanche en lin", "INVTYPE_BODY", 4, 0, 1, 5, 1 },
  [14342] = { "Étoffe lunaire", "", 7, 5, 1, 50, 0 },
  [10940] = { "Poussière étrange", "", 7, 12, 1, 10, 0 },
  [11083] = { "Poussière d'âme", "", 7, 12, 1, 30, 0 },
  [100] = { "Robe du novice", "INVTYPE_ROBE", 4, 1, 2, 25, 20 },
  [101] = { "Brassards du novice", "INVTYPE_WRIST", 4, 1, 2, 25, 20 },
  [102] = { "Bâton de chêne", "INVTYPE_2HWEAPON", 2, 10, 2, 25, 20 },
  [110] = { "Cape usée", "INVTYPE_CLOAK", 4, 1, 2, 22, 17 },                    -- à désenchanter
  [111] = { "Robe bleue du soigneur", "INVTYPE_ROBE", 4, 1, 3, 30, 25, { heal = 30 } }, -- amélioration : à garder
  [112] = { "Épée rouillée", "INVTYPE_WEAPON", 2, 7, 2, 31, 26 },                -- arme : essence
  [113] = { "Chemise verte", "INVTYPE_BODY", 4, 0, 2, 20, 15 },                  -- chemise : jamais désenchantée
  [500] = { "Patron : Gants de méditation", "", 9, 2, 2, 22, 0 },
  [501] = { "Patron : Gants de vraie foi", "", 9, 2, 2, 25, 0 },
  [502] = { "Patron : Robe d'Arcana", "", 9, 2, 2, 25, 0 },
}
local function Link(id, ench)
  local it = ITEMS[id]
  return string.format("|cff1eff00|Hitem:%d:%s::::::::60:::::::|h[%s]|h|r", id, ench or "", it[1])
end
local function ID(x) if type(x) == "number" then return x end return tonumber(tostring(x):match("item:(%d+)")) end
_G.GetItemInfoInstant = function(x) local id = ID(x); local it = ITEMS[id]; if not it then return nil end; return id, "t", "s", it[2], "icon" .. id, it[3], it[4] end
_G.GetItemInfo = function(x) local id = ID(x); local it = ITEMS[id]; if not it then return nil end
  return it[1], Link(id), it[5], it[6], it[7], "t", "s", 1, it[2], "icon", 10 end
_G.GetSpellInfo = function(id) return ({ [13262] = "Désenchanter", [1248459] = "Enchantement de brassards (Pouvoir de guérison mineur)" })[id] end
_G.UnitFactionGroup = function() return "Alliance" end

-- équipement : robe enchantée, brassards nus, bâton à deux mains nu
local GEAR = { [5] = Link(100, "1883"), [9] = Link(101), [16] = Link(102) }
_G.GetInventoryItemLink = function(_, slot) return GEAR[slot] end
local BAGS = { Link(110), Link(111), Link(112), Link(113) }
_G.GetContainerNumSlots = function(bag) return bag == 0 and #BAGS or 0 end
_G.GetContainerItemLink = function(bag, s) return bag == 0 and BAGS[s] or nil end
local COUNT = { [4305] = { 4, 6 }, [4291] = { 0, 0 }, [4338] = { 12, 12 } }
_G.GetItemCount = function(id, bank) local c = COUNT[id] or { 0, 0 }; return bank and c[2] or c[1] end
_G.GameTooltip.GetItem = function(self) return ITEMS[ID(self.link)][1], self.link end
_G.GameTooltip.AddLine = function(self, s) self.lines = self.lines or {}; self.lines[#self.lines + 1] = s end
_G.ChatEdit_InsertLink = function() end

-- ForeverHeal imité : les soins de l'objet comptent ; EvaluateStats : soins + intelligence + esprit
_G.ForeverHealAPI = { version = 2,
  Evaluate = function(link)
    local it = ITEMS[ID(link)]
    local h = it and it[8] and it[8].heal or 0
    return { slot = 1, hps = h / 10, healed = h * 10, hp = 0, score = h / 3 }
  end,
  EvaluateStats = function(d)
    local s = (d.heal or 0) * 0.3 + (d.int or 0) * 0.2 + (d.spi or 0) * 0.15
    return { hps = s, healed = s * 50, hp = (d.sta or 0) * 10, score = s * 30 }
  end }
-- Auctionator et Syndicator imités
_G.Auctionator = { API = { v1 = {
  GetAuctionPriceByItemID = function(_, id) return ({ [4338] = 2000, [4305] = 900, [10940] = 300, [11083] = 1200 })[id] end,
  GetVendorPriceByItemID = function(_, id) return ({ [4291] = 400 })[id] end } } }
_G.Syndicator = { API = { IsReady = function() return true end,
  GetInventoryInfoByItemID = function(id)
    if id == 4305 then return { characters = { { character = "Reroll", bags = 3, bank = 5, mail = 0 } }, guilds = {} } end
    return { characters = {}, guilds = {} }
  end } }

-- lignes de compétence : couture 148/150, enchantement 95/150
local SKILLS = { { "Métiers", true }, { "Couture", false, false, 148, 0, 0, 150 }, { "Enchantement", false, false, 95, 0, 0, 150 } }
_G.GetNumSkillLines = function() return #SKILLS end
_G.GetSkillLineInfo = function(i) return unpack(SKILLS[i]) end

-- fenêtre de couture (TradeSkill)
local TRADE = {
  { "Tissu", "header" },
  { "Épaulières vertes en soie", "medium", 0, 7057, { { 4305, 5, 4 }, { 4291, 2, 0 } } },
  { "Rouleau de tisse-mage", "optimal", 2, 4339, { { 4338, 5, 12 } } },
  { "Gants de méditation", "easy", 1, 4318, { { 4305, 3, 4 } } },
  { "Chemise blanche en lin", "trivial", 5, 2576, {} },
  { "Étoffe lunaire", "trivial", 0, 14342, {}, 3600 },
}
_G.TradeSkillFrame = W.Obj("TradeSkillFrame")
_G.GetTradeSkillLine = function() return "Couture", 148, 150 end
_G.GetNumTradeSkills = function() return #TRADE end
_G.GetTradeSkillInfo = function(i) local t = TRADE[i]; return t[1], t[2], t[3] end
_G.GetTradeSkillItemLink = function(i) return TRADE[i][4] and Link(TRADE[i][4]) end
_G.GetTradeSkillNumReagents = function(i) return #(TRADE[i][5] or {}) end
_G.GetTradeSkillReagentInfo = function(i, j) local g = TRADE[i][5][j]; return ITEMS[g[1]][1], "tex", g[2], g[3] end
_G.GetTradeSkillReagentItemLink = function(i, j) return Link(TRADE[i][5][j][1]) end
_G.GetTradeSkillCooldown = function(i) return TRADE[i][6] end
local selected
_G.TradeSkillFrame_SetSelection = function(i) selected = i end

-- fenêtre d'enchantement (Craft, comme le client classique)
local CRAFT = {
  { "Enchantement de brassards (Endurance mineure)", "optimal", 3, 7457, { { 10940, 2, 6 } }, "Enchante des brassards : +3 Endurance." },
  { "Enchantement de brassards (Pouvoir de guérison mineur)", "medium", 1, 1248459, { { 11083, 1, 1 } },
    "Enchante définitivement des brassards pour augmenter jusqu'à +8 aux soins et +3 aux dégâts des sorts." },
  { "Enchantement d'arme (Clairvoyance)", "easy", 0, 1248757, { { 11083, 4, 1 } }, "Chance d'augmenter votre Esprit de 100 % pendant 10 s." },
}
_G.CraftFrame = W.Obj("CraftFrame")
_G.GetCraftDisplaySkillLine = function() return "Enchantement", 95, 150 end
_G.GetNumCrafts = function() return #CRAFT end
_G.GetCraftInfo = function(i) local t = CRAFT[i]; return t[1], "", t[2], t[3] end
_G.GetCraftItemLink = function(i) return "|cffffffff|Henchant:" .. CRAFT[i][4] .. "|h[" .. CRAFT[i][1] .. "]|h|r" end
_G.GetCraftNumReagents = function(i) return #CRAFT[i][5] end
_G.GetCraftReagentInfo = function(i, j) local g = CRAFT[i][5][j]; return ITEMS[g[1]][1], "tex", g[2], g[3] end
_G.GetCraftReagentItemLink = function(i, j) return Link(CRAFT[i][5][j][1]) end
_G.GetCraftDescription = function(i) return CRAFT[i][6] end

W.class, W.level = "PRIEST", 30
local ns = W.load("ForeverMetiers")
ns.root.Sources = nil      -- guides seuls ici ; les sources intégrées sont testées plus bas (8b) et dans compagnon_sim
W.fire("ADDON_LOADED", "ForeverMetiers")
W.fire("PLAYER_LOGIN")
W.run(3)
local L = ns.L
check(ForeverMetiersDB and ForeverMetiersGlobalDB and ForeverMetiersGlobalDB.cooldowns, "bases créées (personnage et compte)")

-- 1. compétences et rappel du maître
check(ns.db.skills.tailoring and ns.db.skills.tailoring.rank == 148 and ns.db.skills.enchanting.rank == 95, "compétences lues sans ouvrir les métiers (couture 148, enchantement 95)")
local warned = false
for _, p in ipairs(W.printed) do if p:find("Lawrence Schneider", 1, true) then warned = true end end
check(warned, "couture 148/150 : rappel du maître Expert (Lawrence Schneider, Hurlevent)")
local ri = ns.RankInfo("enchanting")
check(ri.cur.key == "journeyman" and ri.next.key == "expert" and ri.next.level == 20, "enchantement : rang Compagnon, prochain Expert (niveau 20)")

-- 2. fenêtre de couture : lecture, meilleurs crafts, panneau à côté
W.fire("TRADE_SKILL_SHOW")
W.fire("TRADE_SKILL_UPDATE")
W.run(1)
local sc = ns.lastScan
check(sc and sc.prof == "tailoring" and #sc.recipes == 5, "fenêtre de couture lue (5 recettes, titre ignoré)")
local adv = ns.Advise(sc, 5)
check(adv[1].r.name == "Rouleau de tisse-mage" and adv[1].perPoint and adv[1].perPoint == 10000,
      "meilleur craft : Rouleau de tisse-mage (orange, faisable, 1 po par point)")
check(adv[2].r.name == "Gants de méditation" and adv[2].upgrade, "ensuite : Gants de méditation (faisables, amélioration pour le prêtre)")
check(adv[3].r.name == "Épaulières vertes en soie" and adv[3].guide and adv[3].r.avail == 0, "Épaulières vertes (étape du guide 145-150) : composants manquants, après les faisables")
for _, e in ipairs(adv) do check(e.r.type ~= "trivial", "recette grise exclue : " .. e.r.name) end
check(ns.side and ns.side:IsShown(), "panneau de conseils affiché à côté de la fenêtre du métier")
local row
for _, r in ipairs(ns.side.list.cards) do if r.onClick and not row then row = r end end
check(row and ns.side.list.infos[1]:GetText():find("Lawrence", 1, true), "panneau : rappel du maître en tête, puis cartes cliquables")
check(row.name:GetText() == "Rouleau de tisse-mage" and row.gain:GetText():find(ns.Money(10000), 1, true), "carte : meilleur craft avec son coût par point à droite")
row.onClick()
check(selected == 3, "clic : la recette est sélectionnée dans la fenêtre du métier")
check(ForeverMetiersGlobalDB.cooldowns[ns.CharKey()]["Étoffe lunaire"], "temps de recharge relevé (Étoffe lunaire)")

-- 3. liste de courses de l'étape 145-150 (Syndicator : rerolls ; Auctionator : prix)
local sh = ns.Shopping("tailoring")
check(sh and sh.st.from == 145 and sh.crafts == 2, "étape du guide 145-150 : 2 fabrications restantes")
local silk, spool = sh.items[1], sh.items[2]
check(silk.id == 4305 and silk.need == 10 and silk.bags == 4 and silk.bank == 2 and silk.alts == 8 and silk.missing == 4,
      "soie : 10 à prévoir, 4 sacs + 2 banque, 8 sur un reroll, il en manque 4")
check(spool.vendor and spool.missing == 4 and sh.cost == 4 * 900 + 4 * 400, "bobine de soie (fournisseur) ; coût de ce qui manque : 5 pa 20 pc")
W.fire("TRADE_SKILL_CLOSE")
check(not ns.side:IsShown(), "panneau masqué à la fermeture du métier")

-- 4. fenêtre d'enchantement (API Craft du classique), description lue
W.fire("CRAFT_SHOW")
W.run(1)
check(ns.lastScan.prof == "enchanting" and ns.lastScan.kind == "craft", "fenêtre d'enchantement lue (API Craft)")
check(ns.db.enchStats[1248459] and ns.db.enchStats[1248459].heal == 8, "description lue : brassards Pouvoir de guérison mineur = +8 soins")
check(ns.db.enchStats[1248757] == nil, "effet aléatoire (Clairvoyance) : pas de valeur inventée")
check(ns.Known("enchanting", { spell = 1248459 }) and not ns.Known("enchanting", { spell = 1248498 }), "formules connues relevées par numéro de sort")

-- 5. pour toi : enchantements de l'équipement, pièces de couture
local ench = {}
for _, a in ipairs(ns.EnchantAdvice()) do ench[a.slot] = a end
check(ench[5].enchanted and not ench[9].enchanted, "torse enchanté, brassards sans enchantement")
check(ench[9].known and ench[9].known.e.spell == 1248459, "brassards : tu sais faire Pouvoir de guérison mineur")
check(ench[9].learn and ench[9].learn.gain.score > ench[9].known.gain.score, "brassards : mieux à apprendre (" .. ench[9].learn.e.name .. ")")
check(not ench[9].soon, "brassards : rien d'apprenable maintenant qui batte ce que tu sais faire")
check(ench[5].soon and ench[5].soon.e.spell == 7776, "torse : apprenable dès maintenant, Plastron (Intelligence inférieure, 80)")
check(ench[16].learn and ench[16].learn.e.two, "bâton à deux mains : enchantement d'arme 2M proposé (" .. ench[16].learn.e.name .. ")")
check(not ench[17].any, "rien en main gauche : aucun enchantement proposé")
local ups = ns.TailorUpgrades()
check(ups[1] and ups[1].id == 4318 and ups[1].known, "couture : Gants de méditation (connus) t'améliorent")

-- 6. désenchantement
local de = ns.DECandidates()
local ids = {}
for _, c in ipairs(de) do ids[c.id] = c end
check(ids[110] and ids[112] and not ids[111] and not ids[113], "à désenchanter : cape et épée ; robe (amélioration) et chemise exclues")
check(ids[110].res.items[1] == 10940 and ids[112].res.items[1] == 11134 and ids[112].res.items[2] == 11083,
      "cape niv. 22 -> poussière étrange ; épée niv. 31 -> essence mystique inférieure d'abord, poussière d'âme")
check(ids[110].ok and ids[112].ok and ids[112].res.skill == 75 and de[1].id == 110, "compétence requise : 75 pour l'épée (tu as 95) ; tri par niveau d'objet")
ns.ShowTab("de")
check(ns.deMacro and ns.deMacro:find("/cast Désenchanter", 1, true) and ns.deMacro:find("/use 0 1", 1, true), "bouton : macro Désenchanter sur le premier objet (sac 0, case 1)")
local deLines = ns.DELines()
for _, l in ipairs(deLines) do if l.onRight then l.onRight(); break end end
local first = ns.DECandidates()[1]
check(ns.db.keep[110] and (not first or first.id ~= 110), "clic droit : objet gardé, plus proposé")

-- 7. onglets remplis
local function Txt(lines) local t = {}; for _, l in ipairs(lines) do t[#t + 1] = l.text end; return table.concat(t, "\n") end
local lv = Txt(ns.LevelLines())
check(lv:find("148", 1, true) and lv:find("Épaulières vertes en soie", 1, true) and lv:find("Rouleau de tisse-mage", 1, true), "onglet Montée : rang, étape du guide, meilleurs crafts gardés")
local fy = Txt(ns.ForYouLines())
check(fy:find("Pouvoir de guérison", 1, true) and fy:find("Gants de méditation", 1, true), "onglet Pour toi : enchantements et couture")
local rc = Txt(ns.RecipeLines())
check(rc:find(L.recKnown, 1, true) and not rc:find("Récupérateur arcanique", 1, true) and not rc:find("Torche de lumière", 1, true)
      and rc:find("Étoffe lunaire", 1, true), "onglet Recettes : à ta portée seulement (pas le récupérateur à 140 pour un enchanteur à 95), recharges")
ns.showAll = true
rc = Txt(ns.RecipeLines())
check(rc:find("Récupérateur arcanique", 1, true) and rc:find("Torche de lumière", 1, true), "« Tout afficher » : catalogue complet")
ns.showAll = false
-- « Que faire ? » et « Pour toi » : rien au-delà de ta portée (capture du 05/11/2026 : compétence 300 et niveau 45 pour un niveau 5)
local fy3 = Txt(ns.ForYouLines())
check(not fy3:find("(300)", 1, true) and not fy3:find("Pouvoir de guérison)", 1, true) or fy3:find("mineur", 1, true),
      "Pour toi : pas d'enchantement de compétence 300 proposé")
local todo = Txt(ns.LevelLines())
check(todo:find("Épaulières vertes en soie", 1, true) and todo:find(L.todoUsefulTitle, 1, true), "Que faire ? : étape en cours et prochaine chose utile")

-- 8. infobulles : patron appris, patron utile au prêtre, patron appris par un reroll, composant de l'étape
GameTooltip.link, GameTooltip.lines = Link(500), {}
ns.OnTooltipItem(GameTooltip)
check(GameTooltip.lines[1] == L.tipKnown, "infobulle : Gants de méditation déjà appris")
GameTooltip.link, GameTooltip.lines = Link(501), {}
ns.OnTooltipItem(GameTooltip)
local t = table.concat(GameTooltip.lines, "|")
check(t:find("148", 1, true) and t:find(L.tipHeal, 1, true), "infobulle : Gants de vraie foi pas encore appris, utile pour ton prêtre")
ForeverMetiersGlobalDB.known["Reroll - Forever"] = { tailoring = { [ns.Norm("Robe d'Arcana")] = true } }
GameTooltip.link, GameTooltip.lines = Link(502), {}
ns.OnTooltipItem(GameTooltip)
check(GameTooltip.lines[1]:find("Reroll", 1, true), "infobulle : Robe d'Arcana apprise par ton reroll")
GameTooltip.link, GameTooltip.lines = Link(4305), {}
ns.OnTooltipItem(GameTooltip)
check(GameTooltip.lines[1] and GameTooltip.lines[1]:find("145", 1, true), "infobulle : soie utile à l'étape 145-150")

-- 8b. Sources intégrées (base WoW Forever d'All The Things, Data/Sources.lua) : ici une base d'essai, même format ;
-- noms demandés au jeu (PNJ par infobulle, zones par la carte, monnaies, réputations)
_G.C_CurrencyInfo = { GetCurrencyInfo = function(id) return id == 3402 and { name = "Faveur marchande" } or nil end }
_G.C_Reputation = { GetFactionDataByID = function(id) return id == 2586 and { name = "Administration commerciale d'Azeroth" } or nil end }
local NPCN = { [250001] = "Alynsia", [250002] = "Bénéris", [1346] = "Georgio Bolero" }
_G.C_TooltipInfo = { GetHyperlink = function(link)
  local id = tonumber(link:match("Creature%-0%-0%-0%-0%-(%d+)"))
  return NPCN[id] and { lines = { { leftText = NPCN[id] } } } or nil
end }
_G.C_Map = { GetMapInfo = function(id) return ({ [1453] = { name = "Hurlevent" }, [1454] = { name = "Orgrimmar" } })[id] end }
local realSources = ns.root.Sources
ns.root.Sources = { rev = "essai", instances = {}, npcs = {},
  items = { [249503] = { { "vendor", 250001, 1453, 50, 50, { cost = { { "c", 3402, 120 } }, rep = { 2586, 3000 }, r = 2 } },
                         { "vendor", 250002, 1454, 40, 40, { cost = { { "c", 3402, 120 } }, rep = { 2587, 3000 }, r = 1 } } } },
  recipes = { [333] = { [1249058] = { 249503, 225, 250001, 1453, "vendor" }, [99999] = { 0, 50, 0, 0, "craft" } },
              [197] = { [3851] = { 0, 140, 1346, 1453, "trainer" }, [3863] = { 4355, 165, 250001, 1453, "vendor" },
                        [8784] = { 0, 105, 1346, 1453, "trainer" } } } }
_G.C_Spell = _G.C_Spell or {}
local saveSN = _G.C_Spell.GetSpellName
local SPN = { [3851] = "Ceinture azur en soie", [3863] = "Cape glaciale", [8784] = "Gants de méditation" }
_G.C_Spell.GetSpellName = function(id) return SPN[id] or (saveSN and saveSN(id)) end
check(ns.ATT.Available(), "sources intégrées présentes")
local src = ns.ATT.Source("recipeID", 1249058)
check(src and src.text:find("^Alynsia — Hurlevent %(120 Faveur marchande, ") and src.text:find("Administration commerciale d'Azeroth)", 1, true) and src.learnedAt == 225,
      "collier de soins chez Alynsia (Hurlevent), 120 faveurs, Amical — « " .. tostring(src and src.text) .. " »")
local collier
for _, e in ipairs(ns.Data.healEnchants) do if e.spell == 1249058 then collier = e end end
check(not src.text:find("Bénéris", 1, true), "le marchand de la Horde (Bénéris, Orgrimmar) n'est pas montré à un Alliance")
check(ns.EntrySkill(collier) == 225 and collier.skill == 210, "compétence de la base (225) préférée à celle du guide (210)")
local now, soon = ns.ATTLearnable("tailoring")
check(#now == 1 and now[1].name == "Ceinture azur en soie" and #soon == 1 and soon[1].name == "Cape glaciale",
      "à apprendre maintenant en couture 148 : Ceinture azur (140) ; bientôt : Cape glaciale (165) ; Gants de méditation déjà connus")
ns.showAll = true            -- le collier (compétence 225) est hors de portée d'un enchanteur à 95 : catalogue complet
local rc2 = Txt(ns.RecipeLines())
ns.showAll = false
check(rc2:find("Georgio Bolero", 1, true) and rc2:find("Alynsia", 1, true), "onglet Recettes : sources intégrées")
check(ns.DiagText():find("Sources intégrées", 1, true), "diagnostic : sources intégrées")
ns.root.Sources = nil
check(ns.ATT.Source("recipeID", 1) == nil, "sans base : rien affiché, aucune erreur")
check(Txt(ns.RecipeLines()) ~= nil, "onglet Recettes sans planter sans base")
ns.root.Sources = realSources
_G.C_Spell.GetSpellName = saveSN
_G.C_TooltipInfo, _G.C_Map = nil, nil

-- 8c. client moderne de Forever : pas de GetNumSkillLines, métiers par GetProfessions / GetProfessionInfo
_G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
_G.GetProfessions = function() return 3, 7, nil, nil, nil end
_G.GetProfessionInfo = function(i) if i == 3 then return "Couture", "icon", 152, 225 end return "Enchantement", "icon", 97, 150 end
ns.ReadSkills()
check(ns.db.skills.tailoring.rank == 152 and ns.db.skills.tailoring.max == 225 and ns.db.skills.enchanting.rank == 97,
      "client moderne : couture 152/225 et enchantement 97 lus par GetProfessions")
_G.GetSpellInfo = nil
_G.C_Spell = { GetSpellName = function(id) return ({ [13262] = "Désenchanter", [1248459] = "Enchantement de brassards (Pouvoir de guérison mineur)" })[id] end }
check(ns.SpellName(13262) == "Désenchanter" and ns.DEMacro({ bag = 1, slot = 2 }):find("/cast Désenchanter", 1, true), "client moderne : nom du sort par C_Spell.GetSpellName")

-- 8d. bouton sécurisé « Désenchanter » : hors de la fenêtre, jamais montré / caché en combat (sinon action bloquée)
ns.ShowTab("de")
local de = ns.ui.deBtn
check(de:IsShown(), "bouton Désenchanter affiché dans l'onglet")
W.combat = true
ns.ui:Hide()
check(de:IsShown() and ns.deHidePending, "fenêtre fermée en combat : le bouton sécurisé n'est pas touché")
W.combat = false
W.fire("PLAYER_REGEN_ENABLED")
check(not de:IsShown(), "sortie du combat : bouton caché")

-- 8e. ton cas (capture du 05/11/2026) : prêtre niveau 5, aucun métier appris
local saveSkills, saveLevel = ns.db.skills, W.level
ns.db.skills = {}
W.level = 5
local todo5 = Txt(ns.LevelLines())
check(todo5:find(L.todoLearn_tailoring, 1, true) and todo5:find(L.todoLearn_enchanting, 1, true) and (todo5:find("Hurlevent", 1, true) or todo5:find("Stormwind", 1, true)),
      "niveau 5 sans métier : « Apprendre la couture » chez le maître de la capitale la plus proche")
check(todo5:find(L.todoClothTitle, 1, true) and todo5:find(L.todoFirstCraftE, 1, true), "puis étoffe de lin, et bâtonnet runique pour l'enchantement")
local fy5 = Txt(ns.ForYouLines())
for _, bad in ipairs({ "Brassards (Pouvoir de guérison)", "Arme 2M (Puissance des soins supérieure)", "Gants (Pouvoir de guérison)" }) do
  check(not fy5:find(bad, 1, true), "niveau 5 : pas de « " .. bad .. " » (compétence 300)")
end
ns.db.skills, W.level = saveSkills, saveLevel

-- 8f. client moderne de Forever : pas de GetTradeSkillLine (erreur Core.lua:143 le 05/11/2026), lecture par C_TradeSkillUI
local saveT = { GetTradeSkillLine, GetNumTradeSkills }
_G.GetTradeSkillLine, _G.GetNumTradeSkills = nil, nil
local RECS = {
  [101] = { name = "Rouleau de tisse-mage", relativeDifficulty = 0, numAvailable = 2, learned = true, out = 4339, reag = { { 4338, 5 } } },
  [102] = { name = "Gants de méditation", relativeDifficulty = 2, numAvailable = 1, learned = true, out = 4318, reag = { { 4305, 3 } } },
  [103] = { name = "Recette pas apprise", relativeDifficulty = 0, numAvailable = 0, learned = false, out = 2576, reag = {} },
}
_G.C_TradeSkillUI = {
  GetChildProfessionInfo = function() return { professionName = "Couture", skillLevel = 150, maxSkillLevel = 225 } end,
  GetAllRecipeIDs = function() return { 101, 102, 103 } end,
  GetRecipeInfo = function(id) local r = RECS[id]; return r and { name = r.name, relativeDifficulty = r.relativeDifficulty, numAvailable = r.numAvailable, learned = r.learned } end,
  GetRecipeOutputItemData = function(id) return { itemID = RECS[id].out, hyperlink = Link(RECS[id].out) } end,
  GetRecipeSchematic = function(id) local t = {}; for _, g in ipairs(RECS[id].reag) do t[#t + 1] = { reagents = { { itemID = g[1] } }, quantityRequired = g[2] } end
    return { reagentSlotSchematics = t } end,
  GetRecipeCooldown = function() return nil end,
  OpenRecipe = function(id) _G.openedRecipe = id; return true end,
}
_G.ProfessionsFrame = W.Obj("ProfessionsFrame")
W.fire("TRADE_SKILL_SHOW")
W.run(1)
check(not ns.lastScanError and ns.lastScan and ns.lastScan.kind == "modern" and ns.lastScan.prof == "tailoring" and #ns.lastScan.recipes == 2,
      "client moderne : couture lue par C_TradeSkillUI (2 recettes apprises, la non apprise ignorée)")
local adv2 = ns.Advise(ns.lastScan, 5)
check(adv2[1] and adv2[1].r.name == "Rouleau de tisse-mage" and adv2[1].r.type == "optimal", "difficulté lue (orange) et meilleur craft")
ns.API.modern.select(adv2[1].r.index)
check(_G.openedRecipe == 101, "clic : la recette est ouverte dans la fenêtre des métiers")
-- en jeu (06/11/2026, « métier nil, 0 recettes ») : le client donne un autre nom, ou rien sur le métier ouvert
_G.C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "Couture classique", professionID = 2540, parentProfessionID = 197, skillLevel = 60, maxSkillLevel = 75 } end
ns.lastScan = nil
W.fire("TRADE_SKILL_SHOW"); W.run(1)
check(ns.lastScan and ns.lastScan.prof == "tailoring" and #ns.lastScan.recipes == 2, "« Couture classique » (n° 197) : reconnue comme la couture")
_G.C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "Tailleur de la Vallée", professionID = 999, skillLevel = 60, maxSkillLevel = 75 } end
ns.lastScan = nil
W.fire("TRADE_SKILL_SHOW"); W.run(1)
check(ns.lastScan and ns.lastScan.prof == nil and ns.lastScan.name == "Tailleur de la Vallée", "nom inconnu : rien d'inventé, nom gardé pour le diagnostic")
_G.C_TradeSkillUI.GetChildProfessionInfo = function() return nil end
_G.C_TradeSkillUI.GetProfessionInfoByRecipeID = function() return { professionName = "Couture", parentProfessionID = 197 } end
ns.lastScan = nil
W.fire("TRADE_SKILL_SHOW"); W.run(1)
check(ns.lastScan and ns.lastScan.prof == "tailoring" and #ns.lastScan.recipes == 2 and ns.lastScan.rank, "rien sur le métier ouvert : déduit de sa première recette, niveau de GetProfessions")
_G.GetTradeSkillLine, _G.GetNumTradeSkills = saveT[1], saveT[2]
_G.C_TradeSkillUI = nil

-- 9. diagnostic, icône commune, commandes
local diag = ns.DiagText()
check((diag:find("API craft", 1, true) or diag:find("API modern", 1, true)) and diag:find("méthode de lecture", 1, true) and diag:find("1248459 = Enchantement de brassards", 1, true) and diag:find("Auctionator : présent", 1, true)
      and not diag:find("Erreur", 1, true), "diagnostic complet")
SlashCmdList.FOREVERMETIERS("recettes")
check(ns.ui:IsShown(), "/metiers recettes")
check(ns.ui.tabs.recipes.active and not ns.ui.tabs.level.active, "onglet Recettes actif (style Forever)")
ns.ShowTab("foryou")
local wrist
for _, c in ipairs(ns.ui.list.cards) do
  if c:IsShown() and c.name:GetText():find(ns.L.slot9, 1, true) then wrist = c end
end
check(wrist and wrist.tags:GetText() == ns.L.enchMissing and wrist.gain:GetText():find(ns.L.cardHps, 1, true),
      "carte « Poignets » : sans enchantement, gain du meilleur enchantement à droite")
ns.ui.optBtn.scripts.OnClick(ns.ui.optBtn)
check(_G.ForeverMetiersOptionsFrame and _G.ForeverMetiersOptionsFrame:IsShown(), "options dans une petite fenêtre")
W.rprint("\nTOUT OK (" .. LANG .. ")")
