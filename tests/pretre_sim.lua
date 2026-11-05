-- ForeverPretre chargé comme dans le jeu (un seul addon, ADDON_LOADED « ForeverPretre »), sur le profil du client
-- de WoW Forever (tests/forever_client.lua) : fenêtre unique, écran Maintenant, sonde, auto-test, anciens dossiers.
-- Lancer depuis la racine : lua5.1 tests/pretre_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check
local profile = dofile("tests/forever_client.lua")
W.client(profile)

-- prêtre de niveau 12 avec quelques objets
W.class, W.level = "PRIEST", 12
_G.UnitGUID = function() return "Player-1" end
_G.UnitPower = function() return 300 end
_G.UnitPowerMax = function() return 400 end
_G.UnitHealthMax = function() return 250 end
_G.UnitStat = function(_, i) return 20, 20 + i end
_G.UnitArmor = function() return 120, 120 end
_G.UnitResistance = function() return 0, 0 end
_G.GetManaRegen = function() return 4, 1 end
_G.GetSpellBonusHealing = function() return 10 end
_G.GetSpellCritChance = function() return 2 end
local bag = { [0] = { 6948, 2589, 858 } }
_G.C_Container = {
  GetContainerNumSlots = function(b) return bag[b] and #bag[b] or 0 end,
  GetContainerItemID = function(b, s) return bag[b] and bag[b][s] end,
  GetContainerItemLink = function(b, s) local id = bag[b] and bag[b][s]; return id and ("|cffffffff|Hitem:" .. id .. "::::::::12:::::|h[Objet " .. id .. "]|h|r") end,
  PickupContainerItem = function() end,
  GetItemCooldown = function() return 0, 0, 1 end,
}
_G.C_Item = _G.C_Item or {}
_G.C_Item.GetItemInfo = function(x)
  local id = tonumber(tostring(x):match("(%d+)"))
  if not id then return nil end
  return "Objet " .. id, "|Hitem:" .. id .. "|h", 1, 5, 1, "Armor", "Cloth", 1, "", "Interface\\Icons\\INV_Misc_QuestionMark", 10
end
_G.C_Item.GetItemInfoInstant = function(x) local id = tonumber(tostring(x):match("(%d+)")); return id, "Armor", "Cloth", "", "Interface\\Icons\\INV_Misc_QuestionMark", 4, 1 end
_G.C_Item.GetItemCount = function() return 1 end
_G.C_Item.EquipItemByName = function(l) W.equipped = l end
_G.GetItemInfo, _G.GetItemInfoInstant = _G.C_Item.GetItemInfo, _G.C_Item.GetItemInfoInstant
_G.GetItemCount = function() return 1 end
_G.GetInventoryItemLink = function() return nil end
_G.UnitExists = function(u) return u == "player" end
_G.IsInGroup, _G.IsInRaid, _G.GetNumGroupMembers = function() return false end, function() return false end, function() return 0 end
_G.UnitBuff = function() return nil end
_G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end, GetBuffDataByIndex = function() return nil end }
_G.GetInventoryItemDurability = function() return nil end
_G.C_Spell = { GetSpellName = function(id) return "Sort " .. id end, GetSpellInfo = function(id) return { name = "Sort " .. id, castTime = 1500 } end }

-- anciens dossiers (coquilles) : se désactivent tout seuls
local disabled = {}
_G.C_AddOns.DisableAddOn = function(a) disabled[a] = true end
for _, a in ipairs({ "ForeverHeal", "ForeverLoot", "ForeverPrep", "ForeverMetiers" }) do
  assert(loadfile(a .. "/Obsolete.lua"))(a, {})
end
check(disabled.ForeverHeal and disabled.ForeverMetiers, "anciens dossiers : remplacés par une coquille qui se désactive")

-- chargement complet
local root = W.load("ForeverPretre")
W.fire("ADDON_LOADED", "ForeverPretre")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD")
W.run(5)
for _, name in ipairs(root.order) do
  check(root.mods[name] and root.mods[name].db, name .. " : chargé et initialisé dans ForeverPretre")
end
local shared = true
for _, name in ipairs(root.order) do
  local ns = root.mods[name]
  shared = shared and ns.Kit and ns.DiagText and ns.SafeClose and ns.Plain and ns.Game == root.Game
end
check(shared and root.mods.ForeverPrep.ATT and root.mods.ForeverPrep.StartTour ~= nil or shared, "modules communs (diag, composants, lien avec le jeu) dans chaque partie")
check(ForeverHub and ForeverHub.entries.ForeverPretre and not ForeverHub.entries.ForeverLoot, "icône Forever : une seule entrée pour le prêtre")
check(root.mods.ForeverPrep.db.minimap.hide, "icône séparée de Prépa masquée")

-- écran Maintenant
SlashCmdList.FOREVERPRETRE("")
check(ForeverPretreNowFrame and ForeverPretreNowFrame:IsShown(), "/fp : écran Maintenant")
local lines = root.NowLines()
local heads = 0
for _, l in ipairs(lines) do if l.kind == "head" then heads = heads + 1 end end
check(heads == 4 and #root.nowErrors == 0, "Maintenant : 4 sections sans erreur (" .. table.concat(root.nowErrors, " ; ") .. ")")
check(ForeverPretreRail and ForeverPretreRail:IsShown(), "barre d'onglets affichée à côté")

-- onglets : une fenêtre à la fois
root.Open("loot")
check(ForeverLootFrame:IsShown() and not ForeverPretreNowFrame:IsShown() and ForeverPretreRail:IsShown(), "onglet Équipement : remplace Maintenant")
SlashCmdList.FOREVERPREP("")
check(ForeverPrepFrame:IsShown() and not ForeverLootFrame:IsShown() and ForeverPretreRail:IsShown(), "/prep : passe aussi par la barre")
root.Open("heal")
check(ForeverHealPanel:IsShown() and not ForeverPrepFrame:IsShown(), "onglet Soins")
root.Open("metiers")
check(ForeverMetiersFrame:IsShown() and not ForeverHealPanel:IsShown(), "onglet Métiers")
ForeverMetiersFrame:Hide()
check(not ForeverPretreRail:IsShown(), "fermer la fenêtre ferme la barre")
root.Toggle()
check(ForeverMetiersFrame:IsShown(), "réouverture : dernier onglet")
ForeverMetiersFrame:Hide()

-- en combat : pas de recalcul
W.combat = true
local again, stale = root.NowLines()
check(stale and #again > 0, "en combat : dernier état, sans recalcul")
W.combat = false

-- sonde : du Lua qui redevient un profil de client
root.ShowProbe()
local text = ForeverPretreTextFrame.edit:GetText()
local fn = (loadstring or load)(text)
local p = fn and fn()
check(p and p.absent and p.present and #p.present > 10, "sonde : rapport en Lua réutilisable comme profil de test")
local absentSet = {}
for _, a in ipairs(p.absent) do absentSet[a] = true end
check(absentSet.EquipItemByName and absentSet.GetMerchantItemInfo and not absentSet["C_Item.EquipItemByName"], "sonde : voit les fonctions absentes du client")

-- auto-test : aucune erreur Lua, chaque ligne a un statut
local report = root.TestReport()
check(not report:find("erreur :", 1, true), "auto-test : aucun test ne plante")
check(report:find("Bilan :", 1, true) and report:find("non testé", 1, true), "auto-test : bilan, et « non testé » pour le marchand fermé")
check(report:find("C_Item.EquipItemByName", 1, true), "auto-test : équiper par C_Item.EquipItemByName")

-- diagnostic commun : chaque partie
local d = root.DiagText()
check(d:find("ForeverHeal", 1, true) and d:find("ForeverMetiers", 1, true) and d:find("Lien avec le jeu", 1, true), "diagnostic commun avec chaque partie")

-- équiper depuis l'alerte (lien avec le jeu)
check(root.Game.Equip("|Hitem:6948|h") and W.equipped, "équiper par le lien avec le jeu")

if os.getenv("SHOW") then W.rprint(report) end
W.rprint("\nTOUT OK (" .. LANG .. ")")
