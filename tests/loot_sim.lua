-- Simulation hors jeu de ForeverLoot (Lua 5.1). Lancer depuis la racine : lua5.1 tests/loot_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local equipped
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
  [120] = { "Collier de Hache-tripes", "INVTYPE_NECK", 4, 0, 3, 0, 900, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20 }, 61 },  -- sans niveau requis
  [121] = { "Robe de la Horde", "INVTYPE_ROBE", 4, 1, 3, 38, 300, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 45 } },
  [122] = { "Gants du boss horde", "INVTYPE_HAND", 4, 1, 3, 38, 300, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 40 } },
  [16693] = { "Collerette de dévot", "INVTYPE_HEAD", 4, 1, 3, 57, 900, { ITEM_MOD_INTELLECT_SHORT = 20, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20 } },
}
local function Link(id) local it = ITEMS[id]; return string.format("|cff0070dd|Hitem:%d::::::::60:::::::|h[%s]|h|r", id, it[1]) end
local function ID(x) if type(x) == "number" then return x end return tonumber(tostring(x):match("item:(%d+)")) end
_G.GetItemInfoInstant = function(x) local id = ID(x); local it = ITEMS[id]; if not it then return nil end; return id, "t", "s", it[2], "icon" .. id, it[3], it[4] end
_G.GetItemInfo = function(x) local id = ID(x); local it = ITEMS[id]; if not it then return nil end
  return it[1], Link(id), it[5], it[9] or 40, it[6], "t", "s", 1, it[2], "icon", it[7] end
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
-- Sections 1 à 8 : l'évaluation par poids et objets vus (autres classes et rôles). Le prêtre soigneur a son moteur
-- (Priest.lua, base wowsims) : section 9, à la fin.
local priestActive = ns.Priest.Active
ns.Priest.Active = function() return false end
-- liste de référence d'avant (15/11) pour ces sections ; la vraie (kami-labs du 20/11) est vérifiée en section 9
local realRef = ns.Data.reference.PRIEST
ns.Data.reference.PRIEST = {
  { slot = 1, id = 16693, zone = "scholo", boss = "Sombre Maître Gandling" },
  { slot = 2, id = 22149, zone = "dm", boss = "quête « La vendetta de Falrin »", ench = "Pouvoir de guérison" },
  { slot = 11, id = 13345, zone = "strat", boss = "Baron Rivendare" },
}

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
ns.ForgetMemo()                                         -- DungeonJournal arrivé : résultats recalculés
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

-- 5c. Sources intégrées (base WoW Forever d'All The Things, Data/Sources.lua) : où obtenir chaque objet de la référence ;
-- noms demandés au jeu (infobulle du PNJ, donjon)
_G.C_TooltipInfo = { GetHyperlink = function(link)
  if link:find("%-10440%-") then return { lines = { { leftText = "Baron Rivendare" } } } end
end }
_G.EJ_GetInstanceInfo = function(id) if id == 236 then return "Stratholme" end end
_G.C_QuestLog = { GetTitleForQuestID = function() return nil end, RequestLoadQuestByID = function() end }
_G.C_Map = { GetMapInfo = function(id) return { name = "Carte " .. id } end }
check(ns.ATTWhere(13345) == "Baron Rivendare — Stratholme", "sources intégrées : Sceau de Rivendare sur le Baron Rivendare (Stratholme)")
local w = ns.ATTWhere(22149)
check(w and (w:find("quête", 1, true) or w:find("quest", 1, true)) and not w:find("Quest #", 1, true), "quête pas encore chargée : « quête » sans numéro (« " .. tostring(w) .. " »)")
local al = {}
for _, l in ipairs(ns.BisLines()) do al[#al + 1] = l.text end
check(table.concat(al, "\n"):find("Baron Rivendare — Stratholme", 1, true), "onglet BiS : source intégrée")
_G.C_TooltipInfo, _G.EJ_GetInstanceInfo, _G.C_QuestLog, _G.C_Map = nil, nil, nil, nil

-- 5d. « À mon niveau » (05/11/2026) : meilleurs objets portables jusqu'à ton niveau + N, et où les avoir
local function NT(lines) local t = {}; for _, l in ipairs(lines) do t[#t + 1] = l.text end; return table.concat(t, "\n") end
local n5 = NT(ns.NearLines(5))
check(n5:find("Gants de l'oracle", 1, true) and n5:find("Salle des thanes", 1, true) and not n5:find("Gants de l'avenir", 1, true)
      and not n5:find("Collerette de dévot", 1, true), "À mon niveau (40, +5) : gants de l'oracle (38, La Salle des thanes), pas les objets de niveau 55-57")
-- faction et niveau de la source (05/11/2026 : collier de Hache-tripes et objets de la Horde proposés à un Alliance niveau 5)
local db2 = {}
for k, v in pairs(ForeverDungeonJournal_NS.DB) do db2[k] = v end
db2["Hache-tripes"] = { level = "55-60", bosses = {}, quests = { { name = "La vendetta", faction = "Both", rewardItems = { { 120, "Collier", 3 } } } } }
db2["Kraal"] = { level = "25-35", bosses = { { name = "Chef horde", factionOnly = "Horde", loot = { { 122, "Gants", "Mains", 3 } } } },
                 quests = { { name = "Pour la Horde", faction = "Horde", level = 30, rewardItems = { { 121, "Robe", 3 } } } } }
ForeverDungeonJournal_NS.DB = db2
ns.version = ns.version + 1
local nf = NT(ns.NearLines(5))
check(not nf:find("Collier de Hache-tripes", 1, true), "À mon niveau : pas de collier sans niveau requis d'un donjon de niveau 55-60")
check(not nf:find("Robe de la Horde", 1, true) and not nf:find("Gants du boss horde", 1, true), "À mon niveau (Alliance) : ni quête ni boss réservés à la Horde")
local saveFG = _G.UnitFactionGroup
_G.UnitFactionGroup = function() return "Horde" end
ns.version = ns.version + 1
check(NT(ns.NearLines(5)):find("Robe de la Horde", 1, true), "contrôle : un personnage de la Horde, lui, voit la récompense de la Horde")
_G.UnitFactionGroup = saveFG
ns.version = ns.version + 1
local dlf = NT(ns.DungeonLines())
check(not dlf:find("Robe de la Horde", 1, true), "onglet Donjons (Alliance) : pas de récompense de quête de la Horde")
local n0 = NT(ns.NearLines(0))
check(n0:find("Gants de l'oracle", 1, true), "À mon niveau (40) : déjà portable")
SlashCmdList.FOREVERLOOT("")
check(ns.ui.nearBtn.active and ns.ui.spanBtns[0].active, "/floot : onglet « À mon niveau » (ton niveau par défaut)")
ns.ui.spanBtns[10].scripts.OnClick(ns.ui.spanBtns[10])
check(ns.nearSpan == 10 and ns.ui.spanBtns[10].active, "choix « +10 niveaux »")
check(ns.db.nearSpan == 10, "choix retenu d'une fois sur l'autre")
local tl = ns.NearTiles()
check(#tl == 4 and tl[1].label == ns.L.tileUp and ns.ui.tiles[1]:IsShown(), "« À mon niveau » : 4 tuiles (améliorations, meilleur gain, sacs, donjon)")
ns.ui.dunBtn.scripts.OnClick(ns.ui.dunBtn)
check(not ns.ui.tiles[1]:IsShown(), "onglet Donjons : pas de tuiles")
ns.ui.nearBtn.scripts.OnClick(ns.ui.nearBtn)

-- 5e. alerte quand tu ramasses un objet qui t'améliore (05/11/2026)
_G.EquipItemByName = function(l) equipped = l end
_G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
_G.LOOT_ITEM_PUSHED_SELF = "Vous recevez l'objet : %s."
ns.lastLootAlert = nil
W.fire("CHAT_MSG_LOOT", "Grosbill reçoit le butin : " .. Link(101) .. ".")
W.run(1)
check(not ns.lastLootAlert, "butin d'un autre joueur : pas d'alerte")
W.fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. Link(105) .. ".")
W.run(1)
check(not ns.lastLootAlert, "objet sans intérêt (os rongé) : pas d'alerte")
W.fire("CHAT_MSG_LOOT", "Vous recevez l'objet : " .. Link(101) .. ".")
W.run(1)
check(ns.lastLootAlert and ns.lastLootAlert.link == Link(101) and not ns.lastLootAlert.later and ForeverLootUpgradeAlert:IsShown(),
      "récompense de quête qui t'améliore : alerte à l'écran")
ForeverLootUpgradeAlert.equip.scripts.OnClick(ForeverLootUpgradeAlert.equip)
check(equipped == Link(101) and not ForeverLootUpgradeAlert:IsShown(), "bouton Équiper : l'objet est équipé")
-- client de Forever : pas d'EquipItemByName global, seulement C_Item.EquipItemByName
local rAlert = ns.lastLootAlert.eval
local saveE = _G.EquipItemByName
_G.EquipItemByName, equipped = nil, nil
_G.C_Item = _G.C_Item or {}
_G.C_Item.EquipItemByName = function(l) equipped = l end
ns.ShowLootAlert(Link(101), rAlert, false)
ForeverLootUpgradeAlert.equip.scripts.OnClick(ForeverLootUpgradeAlert.equip)
check(equipped == Link(101) and not ForeverLootUpgradeAlert:IsShown(), "client moderne : Équiper passe par C_Item.EquipItemByName")
-- ni l'un ni l'autre : on prend l'objet dans le sac puis AutoEquipCursorItem
_G.C_Item.EquipItemByName, equipped = nil, nil
local picked
_G.C_Container = _G.C_Container or {}
local saveCC = { n = _G.C_Container.GetContainerNumSlots, i = _G.C_Container.GetContainerItemID, p = _G.C_Container.PickupContainerItem }
_G.C_Container.GetContainerNumSlots = function(b) return b == 2 and 4 or 0 end
_G.C_Container.GetContainerItemID = function(b, sl) return (b == 2 and sl == 3) and 101 or nil end
_G.C_Container.PickupContainerItem = function(b, sl) picked = b .. ":" .. sl end
_G.AutoEquipCursorItem = function() equipped = picked end
ns.ShowLootAlert(Link(101), rAlert, false)
ForeverLootUpgradeAlert.equip.scripts.OnClick(ForeverLootUpgradeAlert.equip)
check(equipped == "2:3" and not ForeverLootUpgradeAlert:IsShown(), "sans EquipItemByName : objet pris dans le sac et équipé")
_G.C_Container.GetContainerNumSlots, _G.C_Container.GetContainerItemID, _G.C_Container.PickupContainerItem = saveCC.n, saveCC.i, saveCC.p
_G.EquipItemByName = saveE
ns.lastLootAlert = nil
W.fire("CHAT_MSG_LOOT", "Vous recevez le butin : " .. Link(106) .. ".")
W.run(1)
check(ns.lastLootAlert and ns.lastLootAlert.later, "objet de niveau 55 qui t'améliore : « à garder pour le niveau 55 »")

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
check(diag:find("Liste de référence", 1, true) and diag:find("16693", 1, true) and not diag:find("Erreur", 1, true), "diagnostic complet")
SlashCmdList.FOREVERLOOT("donjons")
check(ns.ui:IsShown(), "/floot donjons")
check(ns.ui.dunBtn.active and not ns.ui.bisBtn.active, "onglet Donjons actif (style Forever)")
-- cartes d'objets (fenêtre refaite le 05/11/2026) : nom en couleur de qualité, gain en grand, étoile des références
ns.ShowTab("bis")
local robe, ref, torse
for _, c in ipairs(ns._view.cards) do
  if c:IsShown() and c.name:GetText() == "Robe du soigneur" then robe = c end
  if c:IsShown() and c.star:IsShown() then ref = c end
end
for _, h in ipairs(ns._view.slots) do if h:IsShown() and h.title:GetText() == ns.L.slot5 then torse = h end end
check(robe and robe.gain:GetText():find(ns.L.cardHps, 1, true), "carte : Robe du soigneur avec son gain en soins/s")
check(ref, "carte de référence marquée d'une étoile")
check(torse, "titre d'emplacement « " .. ns.L.slot5 .. " »")
ns.ui.optBtn.scripts.OnClick(ns.ui.optBtn)
check(_G.ForeverLootOptionsFrame and _G.ForeverLootOptionsFrame:IsShown(), "bouton Options : options dans une petite fenêtre")
-- gros chiffre d'une carte : jamais une perte en titre d'une amélioration
do
  local G = ns._GainParts
  local t, sub = G({ method = "heal", hps = 0, regen = -0.5, healed = 43, hp = 10 })
  check(t:find("43", 1, true) and not t:find("−", 1, true) and sub:find("−0", 1, true), "perte de mana en détail, gain (soignés) en titre : " .. t)
  t = G({ method = "heal", hps = 0, regen = 0, armor = 35 })
  check(t:find("35", 1, true), "survie : le vrai gain (armure) en titre : " .. t)
  t = G({ method = "heal", hps = 0, regen = 0.3, healed = 10 })
  check((t:find("0.30", 1, true) or t:find("0,30", 1, true)) and true, "mana hors combat en titre s'il est positif : " .. t)
end
-- 9. Prêtre soigneur : base wowsims (Items.lua), points de soins, Maintenant, Objectif 60
do
  ns.Priest.Active = priestActive
  ns.Data.reference.PRIEST = realRef
  local P = ns.Priest
  W.class, W.level = "PRIEST", 40
  for k in pairs(GEAR) do GEAR[k] = nil end
  for k in pairs(BAGS) do BAGS[k] = nil end
  ns.db.priestProfile = nil
  ns.version = ns.version + 1; P.Forget(); ns.ForgetMemo()
  check(P.Active() and ns.Items and ns.ItemsInfo.count > 1500, "prêtre soigneur : base wowsims chargée (" .. ns.ItemsInfo.count .. " objets)")
  local function near(a, b) return math.abs(a - b) < 0.01 end
  -- Collerette de dévot : 20 soins, 24 int, 15 esprit, 13 endurance ; Sacré, soins de groupe : 20 + 24×0,30 + 15×0,25 + 13×0,01
  check(near(P.ItemEP(16693), 31.08), "points de soins de la Collerette de dévot (poids wowsims) : " .. P.ItemEP(16693))
  check(near((P.Gain(16693)), 31.08), "gain = sa valeur quand la tête est vide")
  ns.db.priestProfile = "disc_st"
  check(near(P.ItemEP(16693), 20 + 24 * 0.2 + 15 * 0.15 + 0.13), "profil Discipline une cible : autres poids")
  ns.db.priestProfile = nil
  -- ce qu'on ne propose pas : l'autre camp, la phase suivante, le JcJ seul
  check(P.Obtainable(271945), "Protège-mains de Theramore : Alliance, proposés")
  _G.UnitFactionGroup = function() return "Horde" end
  check(not P.Obtainable(271945), "Horde : pas les Protège-mains de Theramore (Alliance exalté)")
  _G.UnitFactionGroup = function() return "Alliance" end
  local phase2, pvp
  for id, it in pairs(ns.Items) do
    if it[5] > P.PHASE then phase2 = phase2 or id end
    if #it[9] > 0 and it[9][1][1] == "pvp" and #it[9] == 1 then pvp = pvp or id end
  end
  check(phase2 and not P.Obtainable(phase2) and pvp and not P.Obtainable(pvp), "phase suivante et JcJ seul : jamais proposés")
  -- provenances en clair
  check((P.SourceText(16693) or ""):find("Scholomance", 1, true), "provenance : boss et donjon (" .. tostring(P.SourceText(16693)) .. ")")
  check((P.SourceText(15802) or ""):find(LANG == "en" and "Tailoring" or "Couture", 1, true), "provenance : artisanat (" .. tostring(P.SourceText(15802)) .. ")")
  check((P.SourceText(271945) or ""):find(LANG == "en" and "Exalted" or "exalté", 1, true), "provenance : réputation exalté")
  -- Maintenant : niveau 40, jusqu'à 43 ; un objet de tes sacs hors base (vert aléatoire) compte aussi
  GEAR[5] = Link(100)
  BAGS[1] = Link(101)
  ns.version = ns.version + 1; P.Forget(); ns.ForgetMemo()
  local bis = ns.BiS(2, 43)
  local nSlots, tooHigh, unsorted = 0, false, false
  for _, s in pairs(bis) do
    nSlots = nSlots + 1
    for i, c in ipairs(s.items) do
      if (c.eval.minLevel or 0) > 43 then tooHigh = true end
      if i > 1 and c.eval.score > s.items[i - 1].eval.score + 1 then unsorted = true end
    end
  end
  check(nSlots >= 12 and not tooHigh and not unsorted, "Maintenant : " .. nSlots .. " emplacements, rien au-dessus du niveau 43, trié par gain")
  local robe
  local all = ns.BiS(99, 43)
  for _, c in ipairs(all[5] and all[5].items or {}) do if c.id == 101 then robe = c end end
  check(robe and robe.src == "bags" and near(robe.eval.score, (30 + 15 * 0.3) - 5 * 0.3), "torse : la robe de tes sacs (hors base) évaluée par ses caractéristiques")
  local e = ns.Evaluate(P.Link(16693))
  check(e and e.method == "ep" and e.minLevel == 57 and ns.GainText(e):find(ns.L.cardEp, 1, true), "infobulles et jets : même mesure (points de soins)")
  -- écrans
  ns.ShowTab("near")
  local txt = {}
  for _, l in ipairs(ns.NearLines(3)) do txt[#txt + 1] = l.text or "" end
  txt = table.concat(txt, "\n")
  check(txt:find(string.format(ns.L.nowIntro, 43), 1, true), "onglet Maintenant : introduction")
  check(ns.ui.nearBtn.fs:GetText() == ns.L.tabNow and ns.ui.bisBtn.fs:GetText() == ns.L.tabGoal and not ns.ui.dunBtn:IsShown(), "onglets « Maintenant » et « Objectif 60 », plus d'onglet Donjons")
  local goal = {}
  for _, l in ipairs(ns.GoalLines()) do goal[#goal + 1] = l.text or "" end
  goal = table.concat(goal, "\n")
  check(goal:find(string.format(ns.L.goalDone, 0, 16), 1, true), "Objectif 60 : 0/16 emplacements de la référence")
  check(goal:find("Collerette de dévot", 1, true) and goal:find("Theramore Handwraps", 1, true), "Objectif 60 : la référence de kami-labs (Collerette de dévot, Protège-mains de Theramore)")
  check(not goal:find(" " .. ns.L.goalBest .. " — ", 1, true) and not goal:find(ns.L.slot17, 1, true),
        "Alliance : aucune pièce de la référence remplacée par un calcul, pas de main gauche (bâton à deux mains)")
  _G.UnitFactionGroup = function() return "Horde" end
  local hgoal = {}
  for _, l in ipairs(ns.GoalLines()) do hgoal[#hgoal + 1] = l.text or "" end
  hgoal = table.concat(hgoal, "\n")
  check(select(2, hgoal:gsub(" " .. ns.L.goalBest .. " — ", "")) == 1, "Horde : les Protège-mains de Theramore (Alliance) remplacés par le meilleur calculé, et seulement eux")
  _G.UnitFactionGroup = function() return "Alliance" end
  GEAR[1] = P.Link(16693)
  P.Forget()
  goal = {}
  for _, l in ipairs(ns.GoalLines()) do goal[#goal + 1] = l.text or "" end
  check(table.concat(goal, "\n"):find(string.format(ns.L.goalDone, 1, 16), 1, true), "Collerette portée : 1/16")
  -- profil : le bouton passe au suivant
  ns.Refresh()
  ns.ui.profileBtn.scripts.OnClick(ns.ui.profileBtn)
  check(ns.db.priestProfile == "holy_st" and ns.ui.profileBtn:IsShown(), "bouton de profil : Sacré une cible")
  ns.db.priestProfile = nil
end
-- 10. Paladin, toutes spés (même moteur, profils par spé)
do
  local S = ns.Spec
  W.class, W.level = "PALADIN", 30
  for k in pairs(GEAR) do GEAR[k] = nil end
  for k in pairs(BAGS) do BAGS[k] = nil end
  ns.db.specProfile = nil
  ns.version = ns.version + 1; S.Forget(); ns.ForgetMemo()
  check(S.Active() and #S.Profiles() == 4 and S.Profile() == "pal_holy", "paladin : 4 profils (Sacré, Protection, Vindicte, Shockadin), Sacré par défaut")
  check(S.CanWear(16693) and not S.CanWear(12640) and S.CanWear(12640, 50), "paladin : tissu oui, plaques seulement à partir du niveau 40")
  W.class = "PRIEST"
  check(not S.CanWear(12640, 60) and not S.CanWear(19321, 60), "prêtre : ni plaques ni bouclier")
  W.class, W.level = "PALADIN", 50
  S.SetProfile("pal_ret")
  local bis = ns.BiS(3, 53)
  local oneHand = bis[17] ~= nil
  for _, c in ipairs(bis[16] and bis[16].items or {}) do if ns.Items[c.id] and ns.Items[c.id][1] ~= 116 then oneHand = true end end
  check(not oneHand and bis[16] and #bis[16].items > 0, "Vindicte : armes à deux mains seulement, pas de main gauche")
  local goal = {}
  for _, l in ipairs(ns.GoalLines()) do goal[#goal + 1] = l.text or "" end
  goal = table.concat(goal, "\n")
  check(goal:find(string.format(ns.L.goalDone, 0, 16), 1, true) and goal:find("Lionheart Helm", 1, true) and goal:find("The Unstoppable Force", 1, true),
        "Objectif 60 Vindicte : liste de kami-labs (Heaume Cœur-de-lion, La Force irrésistible)")
  check(not goal:find(ns.L.slot17, 1, true), "Vindicte : pas de ligne main gauche (arme à deux mains)")
  -- Alliance : les pièces des Profanateurs (Horde) sont remplacées par le meilleur calculé
  check(select(2, goal:gsub(" " .. ns.L.goalBest .. " — ", "")) >= 3, "Alliance : pièces Horde de la référence remplacées par un calcul")
  S.SetProfile("pal_prot")
  goal = {}
  for _, l in ipairs(ns.GoalLines()) do goal[#goal + 1] = l.text or "" end
  goal = table.concat(goal, "\n")
  check(goal:find(string.format(ns.L.goalDone, 0, 17), 1, true) and goal:find("The Immovable Object", 1, true), "Objectif 60 Protection : 17 pièces dont L'Objet inébranlable")
  check(S.ItemEP(19321) > S.ItemEP(16693), "Protection : un bouclier vaut plus qu'une coiffe de tissu de soigneur")
  S.SetProfile("pal_holy")
  check(S.ItemEP(16693) > S.ItemEP(12640), "Sacré : la Collerette de dévot (soins) vaut plus que le Heaume Cœur-de-lion (force)")
  ns.ShowTab("bis")
  ns.Refresh()
  ns.ui.profileBtn.scripts.OnClick(ns.ui.profileBtn)
  check(S.Profile() == "pal_prot" and ns.ui.profileBtn.fs:GetText():find(ns.L.profile_pal_prot, 1, true), "bouton de spé : Sacré -> Protection")
  ns.db.specProfile = nil
  W.class, W.level = "PRIEST", 40
end
W.rprint("\nTOUT OK (" .. LANG .. ")")
