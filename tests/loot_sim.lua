-- Simulation hors jeu de ForeverLoot (Lua 5.1). Lancer depuis la racine : lua5.1 tests/loot_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check

-- Objets : id -> { nom, emplacement, classe, sous-classe, qualité, niveau, prix de vente, caractéristiques }
local ITEMS = {
  [100] = { "Robe usée", "INVTYPE_ROBE", 4, 1, 2, 30, 50, { ITEM_MOD_INTELLECT_SHORT = 5 } },
  [101] = { "Robe du soigneur", "INVTYPE_ROBE", 4, 1, 3, 35, 300, { ITEM_MOD_INTELLECT_SHORT = 15, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30 } },
  [102] = { "Cuirasse lourde", "INVTYPE_CHEST", 4, 4, 3, 35, 2500, { ITEM_MOD_STRENGTH_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 15 } },
  [103] = { "Bâton de lumière", "INVTYPE_2HWEAPON", 2, 10, 3, 34, 900, { ITEM_MOD_INTELLECT_SHORT = 20, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 40 } },
  [104] = { "Épée longue", "INVTYPE_WEAPON", 2, 7, 3, 34, 1200, { ITEM_MOD_STRENGTH_SHORT = 10 } },
  [105] = { "Os rongé", "INVTYPE_TRINKET", 15, 0, 0, 1, 1, {} },
  [106] = { "Gants de l'avenir", "INVTYPE_HAND", 4, 1, 4, 55, 800, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 60 } },
  [13345] = { "Sceau de Rivendare", "INVTYPE_FINGER", 4, 0, 3, 58, 900, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 26 } },
  [107] = { "Gants de l'oracle", "INVTYPE_HAND", 4, 1, 3, 38, 400, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 25 } },
  [108] = { "Gantelets de plaques", "INVTYPE_HAND", 4, 4, 3, 38, 400, { ITEM_MOD_STRENGTH_SHORT = 20 } },
  [109] = { "Bâton du pèlerin", "INVTYPE_2HWEAPON", 2, 10, 3, 38, 900, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 50 } },
  [22149] = { "Perles de mojo ogre", "INVTYPE_NECK", 4, 0, 3, 60, 900, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20 } },
  [16693] = { "Collerette de dévot", "INVTYPE_HEAD", 4, 1, 3, 57, 900, { ITEM_MOD_INTELLECT_SHORT = 20, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20 } },
}
local function Link(id) local it = ITEMS[id]; return string.format("|cff0070dd|Hitem:%d::::::::60:::::::|h[%s]|h|r", id, it[1]) end
local function ID(x) if type(x) == "number" then return x end return tonumber(tostring(x):match("item:(%d+)")) end
_G.GetItemInfoInstant = function(x) local id = ID(x); local it = ITEMS[id]; if not it then return nil end; return id, "t", "s", it[2], "icon" .. id, it[3], it[4] end
_G.GetItemInfo = function(x) local id = ID(x); local it = ITEMS[id]; if not it then return nil end
  return it[1], Link(id), it[5], 40, it[6], "t", "s", 1, it[2], "icon", it[7] end
_G.GetItemStats = function(x) local it = ITEMS[ID(x)]; local t = {}; for k, v in pairs(it and it[8] or {}) do t[k] = v end; return t end
local GEAR = { [5] = Link(100) }
_G.GetInventoryItemLink = function(_, slot) return GEAR[slot] end
local BAGS = {}
_G.GetContainerNumSlots = function(bag) return bag == 0 and #BAGS or 0 end
_G.GetContainerItemLink = function(bag, s) return bag == 0 and BAGS[s] or nil end
_G.GameTooltip.GetItem = function(self) return "x", self.link end
_G.GameTooltip.AddLine = function(self, s) self.lines = self.lines or {}; self.lines[#self.lines + 1] = s end
_G.ChatEdit_InsertLink = function() end
-- modèle de ForeverHeal imité : la valeur de soins de l'objet moins celle de l'objet porté au même emplacement
_G.ForeverHealAPI = { Evaluate = function(link)
  local id = ID(link); local it = ITEMS[id]
  local slots = ({ INVTYPE_ROBE = 5, INVTYPE_CHEST = 5, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPON = 16, INVTYPE_HAND = 10, INVTYPE_NECK = 2, INVTYPE_HEAD = 1, INVTYPE_FINGER = 11 })
  local slot = slots[it[2]] or 13
  local function v(l) if not l then return 0 end local s = ITEMS[ID(l)][8]; return (s.ITEM_MOD_SPELL_HEALING_DONE_SHORT or 0) * 0.1 + (s.ITEM_MOD_INTELLECT_SHORT or 0) * 0.05 end
  local hps = v(link) - v(GEAR[slot])
  return { slot = slot, hps = hps, healed = hps * 100, hp = 0, score = hps * 30 + hps }
end }
W.class, W.level = "PRIEST", 40

local ns = W.load("ForeverLoot")
W.fire("ADDON_LOADED", "ForeverLoot")
W.fire("PLAYER_LOGIN")
W.run(3)
check(ForeverLootDB and ForeverLootGlobalDB and ForeverLootGlobalDB.dungeons, "bases créées (personnage et compte)")

-- 1. ce qu'un prêtre peut porter
check(ns.Wearable(Link(101)) and not ns.Wearable(Link(102)), "prêtre : tissu oui, plaques non")
check(ns.Wearable(Link(103)) and not ns.Wearable(Link(104)), "prêtre : bâton oui, épée non")

-- 2. jets de butin
local a, why = ns.RollAdvice(Link(101))
check(a == "need", "jet : robe du soigneur -> BESOIN (" .. why .. ")")
a, why = ns.RollAdvice(Link(102))
check(a == "greed" and why == ns.L.adviceNotWearable, "jet : cuirasse en plaques -> Cupidité (ta classe ne peut pas la porter)")
a = ns.RollAdvice(Link(106))
check(a == "greed", "jet : objet de niveau 55 pour un niveau 40 -> Cupidité")
_G.GetLootRollItemLink = function() return Link(101) end
_G.GroupLootFrame1 = W.Obj("GroupLootFrame1"); GroupLootFrame1.rollID = 7
W.fire("START_LOOT_ROLL", 7)
check(ns.lastRoll and ns.lastRoll.advice == "need" and GroupLootFrame1.flText, "fenêtre de jet : conseil affiché au-dessus")

-- 3. récompense de quête
local idx, kind = ns.QuestChoice({ Link(102), Link(101), Link(105) })
check(idx == 2 and kind == "best", "quête : la robe (amélioration) plutôt que la cuirasse plus chère")
idx, kind = ns.QuestChoice({ Link(102), Link(104), Link(105) })
check(idx == 1 and kind == "price", "quête sans amélioration : la plus chère à revendre (cuirasse)")
_G.GetNumQuestChoices = function() return 3 end
_G.GetQuestItemLink = function(_, i) return ({ Link(102), Link(101), Link(105) })[i] end
for i = 1, 3 do _G["QuestInfoRewardsFrameQuestInfoItem" .. i] = W.Obj() end
W.fire("QUEST_COMPLETE")
check(ns.lastQuest and ns.lastQuest.index == 2 and QuestInfoRewardsFrameQuestInfoItem2.flGlow, "récompense mise en évidence dans la fenêtre de quête")

-- 4. butin d'un boss en donjon (gardé pour tous les personnages)
W.inInstance, W.instanceType, W.zone = true, "party", "Stratholme"
_G.UnitExists = function(u) return u == "target" end
_G.UnitIsDead = function() return true end
_G.UnitIsPlayer = function() return false end
_G.UnitClassification = function() return "elite" end
_G.UnitName = function(u) return u == "target" and "Baron Rivendare" or "Machin" end
_G.GetNumLootItems = function() return 2 end
_G.GetLootSlotLink = function(i) return ({ Link(13345), Link(105) })[i] end
W.fire("LOOT_OPENED")
local z = ForeverLootGlobalDB.dungeons.Stratholme
check(z and z["Baron Rivendare"] and z["Baron Rivendare"][13345] and not z["Baron Rivendare"][105], "butin du boss noté (objet gris ignoré)")
W.inInstance, W.zone = false, "Hurlevent"

-- 5. BiS : objets vus classés, référence affichée
local bis = ns.BiS(3)
check(bis[5] and bis[5].items[1] and bis[5].items[1].id == 101, "BiS torse : la robe du soigneur vue lors du jet")
check(bis[11] and #bis[11].refs >= 1 and bis[11].refs[1].id == 13345, "BiS anneaux : Sceau de Rivendare de la liste Forever (Baron Rivendare, Stratholme)")
check(not bis[5].items[2] or bis[5].items[2].id ~= 102, "BiS : la cuirasse (plaques) n'est pas proposée")
ns.Toggle()
local lines = ns.BisLines()
local txt = {}
for _, l in ipairs(lines) do txt[#txt + 1] = l.text end
txt = table.concat(txt, "\n")
check(txt:find("Robe du soigneur", 1, true) and txt:find("Rivendare", 1, true) and txt:find("Pouvoir de guérison", 1, true), "onglet BiS rempli (référence Forever, enchantement conseillé)")
local dun = ns.DungeonLines()
local dtxt = {}
for _, l in ipairs(dun) do dtxt[#dtxt + 1] = l.text end
dtxt = table.concat(dtxt, "\n")
check(dtxt:find("Stratholme", 1, true) and dtxt:find("Sceau de Rivendare", 1, true), "onglet Donjons : butin vu et référence")

-- 5b. DungeonJournal (format réel : ForeverDungeonJournal_NS.DB[donjon].bosses[i].loot / quests[i].rewardItems) et Syndicator
_G.ForeverDungeonJournal_NS = {
  DB = { ["Hall of Thanes"] = {
    bosses = { { name = "Faldrim Anvilmar", loot = { { 107, "Oracle Gloves", "Hands, Cloth", 3 }, { 108, "Plate Gauntlets", "Hands, Plate", 3 } } } },
    quests = { { name = "An Ancient Grudge", rewardItems = { { 109, "Pilgrim Staff", 3 } } } },
  } },
  LocalizeDungeonName = function(k) return k == "Hall of Thanes" and "La Salle des thanes" or k end,
}
_G.Syndicator = { API = { IsReady = function() return true end,
  GetInventoryInfoByItemID = function(id)
    if id == 109 then return { characters = { { character = "Machin", bank = 1, bags = 0, mail = 0 } }, guilds = {} } end
    return { characters = {}, guilds = {} }
  end } }
bis = ns.BiS(3)
check(bis[10] and bis[10].items[1] and bis[10].items[1].id == 107 and bis[10].items[1].where:find("Salle des thanes", 1, true),
      "BiS mains : gants de DungeonJournal (La Salle des thanes — Faldrim Anvilmar), plaques ignorées")
local twoHand
for _, c in ipairs(bis[16] and bis[16].items or {}) do if c.id == 109 then twoHand = c end end
check(twoHand and twoHand.src == "djquest", "BiS : bâton, récompense de quête de DungeonJournal")
check(ns.Owned(109) == ns.L.ownBank, "Syndicator : le bâton est dans ta banque")
ns.version = ns.version + 1
local bl = {}
for _, l in ipairs(ns.BisLines()) do bl[#bl + 1] = l.text end
bl = table.concat(bl, "\n")
check(bl:find("Syndicator", 1, true) and bl:find("DungeonJournal", 1, true), "onglet BiS : lignes DungeonJournal et Syndicator")
local dl = {}
for _, l in ipairs(ns.DungeonLines()) do dl[#dl + 1] = l.text end
dl = table.concat(dl, "\n")
check(dl:find("La Salle des thanes", 1, true) and dl:find("Faldrim Anvilmar", 1, true) and dl:find("Gants de l'oracle", 1, true)
      and not dl:find("Gantelets de plaques", 1, true), "onglet Donjons : butin de DungeonJournal pour toi, boss par boss")
check(ns.DiagText():find("DungeonJournal : présent", 1, true), "diagnostic : DungeonJournal détecté")

-- 5c. All The Things : où obtenir chaque objet de la liste de référence
_G.ATTC = { SearchForField = function(field, id)
  if field == "itemID" and id == 13345 then
    return { { itemID = 13345, parent = { encounterID = 456, text = "Baron Rivendare", parent = { instanceID = 236, text = "Stratholme", parent = { headerID = -1, text = "Donjons" } } } } }
  end
end }
check(ns.ATTWhere(13345) == "Baron Rivendare — Stratholme", "ATT : Sceau de Rivendare sur le Baron Rivendare (Stratholme)")
local al = {}
for _, l in ipairs(ns.BisLines()) do al[#al + 1] = l.text end
check(table.concat(al, "\n"):find("ATT[^|]*Baron Rivendare — Stratholme"), "onglet BiS : source d'ATT")
_G.ATTC = nil

-- 6. infobulle d'un objet de référence
GameTooltip.link, GameTooltip.lines = Link(16693), {}
ns.OnTooltipItem(GameTooltip)
check(GameTooltip.lines[1] and GameTooltip.lines[1]:find("ForeverLoot", 1, true), "infobulle : « BiS de référence »")

-- 7. autre classe : modèle simplifié
W.class, W.level = "WARRIOR", 45
ns.version = ns.version + 1
check(ns.Wearable(Link(102)) and ns.Wearable(Link(104)), "guerrier 45 : plaques et épée portables")
local r = ns.Evaluate(Link(102))
check(r and r.method == "weights" and r.score > 0, "guerrier : évaluation par poids simplifiés (" .. string.format("%.1f", r.score) .. " points)")
W.level = 30
ns.version = ns.version + 1
check(not ns.Wearable(Link(102)), "guerrier 30 : pas encore les plaques (niveau 40)")
W.class, W.level = "PRIEST", 40

-- 8. diagnostic, icône commune, commande
local diag = ns.DiagText()
check(diag:find("Liste de référence", 1, true) and diag:find("272406", 1, true) and not diag:find("Erreur", 1, true), "diagnostic complet")
check(ForeverHub and ForeverHub.entries.ForeverLoot, "inscrit dans l'icône commune")
SlashCmdList.FOREVERLOOT("donjons")
check(ns.ui:IsShown(), "/floot donjons")
check(ns.ui.dunBtn.active and not ns.ui.bisBtn.active, "onglet Donjons actif (style Forever)")
W.rprint("\nTOUT OK (" .. LANG .. ")")
