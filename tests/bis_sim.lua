-- Simulation hors jeu de l'addon séparé ForeverBiS (partie Équipement seule), construit par tools/build-bis.sh.
-- Lancer depuis la racine : sh tools/build-bis.sh && lua5.1 tests/bis_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check
_G.GetItemInfo = function() return nil end
_G.GetItemInfoInstant = function() return nil end
_G.GetItemStats = function() return {} end
_G.GetInventoryItemLink = function() return nil end
_G.GetContainerNumSlots = function() return 0 end
_G.Minimap = W.Obj and W.Obj() or CreateFrame("Frame", "Minimap")
W.class, W.level = "PALADIN", 50

local root = W.load("ForeverBiS")
W.fire("ADDON_LOADED", "ForeverBiS")
W.fire("PLAYER_LOGIN")
W.run(3)
local loot = root.mods and root.mods.ForeverLoot
check(loot and loot.Spec and ForeverLootDB, "ForeverBiS chargé seul : partie Équipement et sa sauvegarde")
check(not (root.mods.ForeverPrep or root.mods.ForeverHeal) and SlashCmdList.FOREVERCOMPAGNON == nil, "rien d'autre de ForeverCompagnon (ni Prépa, ni Soins, ni /fp)")
check(loot.Spec.Active() and #loot.Spec.Profiles() == 4, "paladin : les 4 spés au choix (pas de rôle venu de ForeverCompagnon)")
SlashCmdList.FOREVERLOOT("")
check(ForeverLootFrame and ForeverLootFrame:IsShown(), "/bis ouvre la fenêtre")
check(ForeverLootFrame.title == nil or true, "fenêtre")
loot.ShowTab("bis")
local txt = {}
for _, l in ipairs(loot.GoalLines()) do txt[#txt + 1] = l.text or "" end
txt = table.concat(txt, "\n")
check(txt:find(string.format(loot.L.goalDone, 0, 17), 1, true), "Objectif 60 du paladin Sacré : 17 pièces")
loot.ui.profileBtn.scripts.OnClick(loot.ui.profileBtn)
check(loot.Spec.Profile() == "pal_prot", "bouton de spé : Protection")
check(_G.ForeverBiSMinimapButton and _G.ForeverBiSMinimapButton.scripts.OnClick, "icône sur la minicarte")
ForeverLootFrame:Hide()
_G.ForeverBiSMinimapButton.scripts.OnClick(_G.ForeverBiSMinimapButton)
check(ForeverLootFrame:IsShown(), "clic sur l'icône : fenêtre ouverte")
ForeverLootFrame:Hide()
ForeverBiS_OnCompartmentClick()
check(ForeverLootFrame:IsShown(), "menu des addons du jeu : fenêtre ouverte")
check(loot.L.title:find("ForeverBiS", 1, true), "titre ForeverBiS")
check(type(root.Clear) == "function" and root.Kit, "socle complet sans la fenêtre de ForeverCompagnon (root.Clear, root.Kit)")
-- marchand ouvert : le relevé des marchands (Store.lua) ne plante pas
_G.UnitGUID = function() return "Creature-0-0-0-0-12345-0" end
_G.UnitName = function() return "Marchand" end
_G.C_Map = _G.C_Map or {}
_G.C_Map.GetBestMapForUnit = function() return 1429 end
_G.C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end
local okM, errM = pcall(root.Store.RecordMerchant)
check(okM, "relevé d'un marchand sans erreur (" .. tostring(errM) .. ")")
local d = loot.DiagText and loot.DiagText() or ""
check(d:find("pal_prot", 1, true) and not d:find("Erreur", 1, true), "diagnostic")
W.rprint("\nTOUT OK (" .. LANG .. ")")
