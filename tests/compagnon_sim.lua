-- ForeverCompagnon chargé comme dans le jeu (un seul addon, ADDON_LOADED « ForeverCompagnon »), sur le profil du client
-- de WoW Forever (tests/forever_client.lua) : fenêtre unique, écran Maintenant, sonde, auto-test, anciens dossiers.
-- Lancer depuis la racine : lua5.1 tests/compagnon_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check
local profile = dofile("tests/forever_client.lua")

-- prêtre de niveau 12 avec quelques objets
W.class, W.level = "PRIEST", 12
_G.UnitGUID = function() return "Player-1" end
-- mana actuelle secrète, même hors combat (sonde du 06/11/2026) : toute opération dessus échoue
local SECRET = setmetatable({}, { __add = function() error("attempt to perform arithmetic on a secret number value") end,
                                  __sub = function() error("secret") end, __div = function() error("secret") end,
                                  __lt = function() error("secret") end, __le = function() error("secret") end })
_G.issecretvalue = function(v) return v == SECRET end
_G.UnitPower = function() return profile.secretPowerOutOfCombat and SECRET or 300 end
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
_G.GetInventoryItemLink = function() return nil end
_G.UnitExists = function(u) return u == "player" end
_G.IsInGroup, _G.IsInRaid, _G.GetNumGroupMembers = function() return false end, function() return false end, function() return 0 end
_G.UnitBuff = function() return nil end
_G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end, GetBuffDataByIndex = function() return nil end }
_G.GetInventoryItemDurability = function() return nil end
_G.C_Spell = { GetSpellName = function(id) return "Sort " .. id end, GetSpellInfo = function(id) return { name = "Sort " .. id, castTime = 1500 } end }

-- comparaison par le jeu (UnitPowerPercent + courbe en escalier), comme sur Forever
W.manaFrac = 0.2
_G.Enum = _G.Enum or {}
_G.Enum.LuaCurveType = { Linear = 0, Step = 1 }
_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGBA = function(self) return self.r, self.g, self.b, self.a end } end
_G.C_CurveUtil = { CreateColorCurve = function()
  local c = { pts = {} }
  function c:SetType(t) self.type = t end
  function c:AddPoint(x, col) table.insert(self.pts, { x = x, col = col }) end
  return c
end }
_G.CurveConstants = { ScaleTo100 = { scale100 = true } }
_G.UnitPowerPercent = function(unit, kind, predicted, curve)
  if type(predicted) == "table" then curve = predicted end          -- l'autre ordre des arguments
  if curve.scale100 then return SECRET end
  local col
  for _, p in ipairs(curve.pts) do if W.manaFrac >= p.x then col = p.col end end
  return col
end

-- fonctions absentes du client de Forever retirées (après les imitations ci-dessus)
W.client(profile)
check(_G.GetItemInfo == nil and _G.IsAddOnLoaded == nil and _G.GetItemCount == nil, "profil du client Forever appliqué (" .. #profile.absent .. " fonctions absentes)")

-- anciens dossiers (coquilles) : se désactivent tout seuls
local disabled = {}
_G.C_AddOns.DisableAddOn = function(a) disabled[a] = true end
for _, a in ipairs({ "ForeverHeal", "ForeverLoot", "ForeverPrep", "ForeverMetiers", "ForeverPretre" }) do
  assert(loadfile(a .. "/Obsolete.lua"))(a, {})
end
check(disabled.ForeverHeal and disabled.ForeverMetiers and disabled.ForeverPretre, "anciens dossiers : remplacés par une coquille qui se désactive")

-- chargement complet
local root = W.load("ForeverCompagnon")
W.fire("ADDON_LOADED", "ForeverCompagnon")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD")
W.run(5)
for _, name in ipairs(root.order) do
  check(root.mods[name] and root.mods[name].db, name .. " : chargé et initialisé dans ForeverCompagnon")
end
local shared = true
for _, name in ipairs(root.order) do
  local ns = root.mods[name]
  shared = shared and ns.Kit and ns.DiagText and ns.SafeClose and ns.Plain and ns.Game == root.Game
end
check(shared and root.mods.ForeverPrep.ATT and root.mods.ForeverPrep.StartTour ~= nil or shared, "modules communs (diag, composants, lien avec le jeu) dans chaque partie")
check(ForeverHub and ForeverHub.entries.ForeverCompagnon and not ForeverHub.entries.ForeverLoot, "icône Forever : une seule entrée pour le prêtre")
check(root.mods.ForeverPrep.db.minimap.hide, "icône séparée de Prépa masquée")

-- écran Maintenant
SlashCmdList.FOREVERCOMPAGNON("")
check(ForeverCompagnonNowFrame and ForeverCompagnonNowFrame:IsShown(), "/fp : écran Maintenant")
local lines = root.NowLines()
local heads = 0
for _, l in ipairs(lines) do if l.kind == "head" then heads = heads + 1 end end
check(heads == 4 and #root.nowErrors == 0, "Maintenant : 4 sections sans erreur (" .. table.concat(root.nowErrors, " ; ") .. ")")
check(ForeverCompagnonRail and ForeverCompagnonRail:IsShown(), "barre d'onglets affichée à côté")

-- onglets : une fenêtre à la fois
root.Open("loot")
check(ForeverLootFrame:IsShown() and not ForeverCompagnonNowFrame:IsShown() and ForeverCompagnonRail:IsShown(), "onglet Équipement : remplace Maintenant")
SlashCmdList.FOREVERPREP("")
check(ForeverPrepFrame:IsShown() and not ForeverLootFrame:IsShown() and ForeverCompagnonRail:IsShown(), "/prep : passe aussi par la barre")
root.Open("heal")
check(ForeverHealPanel:IsShown() and not ForeverPrepFrame:IsShown(), "onglet Soins")
root.Open("metiers")
check(ForeverMetiersFrame:IsShown() and not ForeverHealPanel:IsShown(), "onglet Métiers")
ForeverMetiersFrame:Hide()
check(not ForeverCompagnonRail:IsShown(), "fermer la fenêtre ferme la barre")
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
local text = ForeverCompagnonTextFrame.edit:GetText()
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

-- mana secrète même hors combat : dite clairement, rien ne plante
check(report:find("mana actuelle secrète même hors combat", 1, true), "auto-test : mana secrète hors combat signalée comme limite du client")
check(root.mods.ForeverHeal.DiagText():find("secrète même hors combat", 1, true), "diagnostic des soins : mana secrète hors combat signalée")
local heal = root.mods.ForeverHeal
heal.UpdateManaAlert()
check(not (ForeverHealManaAlert and ForeverHealManaAlert:IsShown()), "hors combat : pas d'alerte de mana")
W.combat = true
local alphas = {}
W.manaFrac = 0.2
heal.UpdateManaAlert()
local a = ForeverHealManaAlert
local setA = a.SetAlpha
a.SetAlpha = function(self, v) alphas[#alphas + 1] = v; return setA(self, v) end
heal.UpdateManaAlert()
check(a:IsShown() and alphas[#alphas] == 1, "en combat, mana à 20 % : le jeu rend l'alerte visible (seuil 30 %)")
W.manaFrac = 0.8
heal.UpdateManaAlert()
check(alphas[#alphas] == 0, "en combat, mana à 80 % : le jeu la rend invisible")
W.fire("UNIT_POWER_FREQUENT", "player", "MANA")
check(true, "événement de mana en combat : pas d'erreur")
W.combat = false
heal.UpdateManaAlert()
check(not a:IsShown(), "après le combat : alerte cachée")
heal.db.manaAlert = true
SlashCmdList.FOREVERHEAL("alerte 25")
check(heal.db.manaLowPct == 0.25 and heal.db.manaAlert, "/fheal alerte 25 : seuil à 25 %")
check(heal.DiagText():find("disponible, UnitPowerPercent", 1, true), "diagnostic : alerte par le jeu disponible")
check(root.TestReport():find("[OK] Jeu — mana comparée par le jeu", 1, true), "auto-test : comparaison par le jeu testée")

check(root.ProbeText():find("secretPowerOutOfCombat = true", 1, true), "sonde : mana secrète hors combat relevée")

-- onglet Addons : reconnus par dossier, titre (DungeonJournal) ou variable globale ; activer un addon désactivé
local installed = { { "AllTheThings", "All The Things" }, { "FDJ", "|cff00ff00Dungeon Journal|r (Forever)" }, { "TomTom", "TomTom" } }
local enabled = {}
_G.C_AddOns.GetNumAddOns = function() return #installed end
_G.C_AddOns.GetAddOnInfo = function(i) return installed[i][1], installed[i][2] end
_G.C_AddOns.IsAddOnLoaded = function(n) return n == "AllTheThings" or n == "FDJ" end
_G.C_AddOns.EnableAddOn = function(n) enabled[n] = true end
local byKey = {}
for _, e in ipairs(root.ADDONS) do byKey[e.key] = e end
check(root.AddonStatus(byKey.dj) == "on", "Addons : DungeonJournal reconnu par son titre (dossier « FDJ »)")
check(root.AddonStatus(byKey.tomtom) == "off" and root.AddonStatus(byKey.questie) == "absent", "Addons : TomTom désactivé, Questie absent")
root.Open("addons")
check(ForeverCompagnonAddonsFrame:IsShown() and ForeverCompagnonRail:IsShown(), "onglet Addons dans la barre")
local alines = root.AddonLines()
local tomCard
for _, l in ipairs(alines) do if l.kind == "card" and l.name == "TomTom" then tomCard = l end end
check(tomCard and tomCard.onClick, "Addons : une ligne par addon, cliquable")
tomCard.onClick()
check(ForeverCompagnonAddonsFrame.url:GetText():find("curseforge.com/wow/addons/tomtom", 1, true), "clic : adresse affichée à copier")
check(ForeverCompagnonAddonsFrame.enable:IsShown(), "addon désactivé : bouton Activer")
ForeverCompagnonAddonsFrame.enable.scripts.OnClick()
check(enabled.TomTom, "Activer : TomTom activé pour le prochain /reload")
check(root.TestReport():find("DungeonJournal oui [FDJ]", 1, true), "auto-test : DungeonJournal trouvé même sous un autre nom de dossier")
W.class = "WARRIOR"
local warrior = table.concat((function() local t = {} for _, l in ipairs(root.AddonLines()) do t[#t + 1] = l.name or "" end return t end)(), ",")
check(not warrior:find("HealBot", 1, true) and not warrior:find("Full Mana", 1, true), "guerrier : ni HealBot ni Full Mana proposés")
W.class = "PRIEST"
ForeverCompagnonAddonsFrame:Hide()

-- Métiers : tous les métiers, conseils selon la classe
local met = root.mods.ForeverMetiers
local profs = {}
_G.GetProfessions = function() return profs[1], profs[2], nil, profs[4], profs[5] end
local PINFO = { [1] = { "Forge", 164, 120, 150 }, [2] = { "Minage", 186, 140, 150 }, [5] = { "Cuisine", 185, 30, 75 } }
_G.GetProfessionInfo = function(i) local p = PINFO[i]; return p[1], "icone", p[3], p[4], 0, 0, p[2] end
_G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
W.class = "WARRIOR"
profs = { 1, 2, nil, nil, 5 }
met.ReadSkills()
check(met.db.skills.blacksmithing and met.db.skills.mining and met.db.skills.cooking and not met.db.skills.tailoring,
      "guerrier : forge, minage et cuisine lus (par numéro de métier)")
local function Txt(lines) local t = {} for _, l in ipairs(lines) do t[#t + 1] = (l.title or "") .. " " .. (l.name or "") .. " " .. (l.text or "") .. " " .. (l.source or "") end return table.concat(t, "\n") end
local wl = Txt(met.LevelLines())
local PN = met.ProfName
check(wl:find(PN("blacksmithing"), 1, true) and wl:find(PN("mining"), 1, true) and wl:find(PN("cooking"), 1, true), "guerrier : ses trois métiers dans « Que faire ? »")
check(not wl:find(PN("tailoring"), 1, true) and not wl:find(PN("enchanting"), 1, true), "guerrier : ni couture ni enchantement proposés")
check(wl:find("maître", 1, true) or wl:find("trainer", 1, true), "forge 120/150 : rappel du maître, sans données propres")
check(not wl:find("todoLearn_", 1, true) and not wl:find("prof_", 1, true), "aucun texte manquant affiché")
profs = { nil, nil, nil, nil, 5 }
met.ReadSkills()
check(not met.db.skills.blacksmithing, "métier abandonné : retiré")
local nl = Txt(met.LevelLines())
check(nl:find(PN("mining"), 1, true) and nl:find(PN("blacksmithing"), 1, true),
      "guerrier sans métier principal : minage et forge conseillés")
W.class = "PRIEST"
local pl = Txt(met.LevelLines())
check(pl:find(PN("tailoring"), 1, true) and pl:find(PN("enchanting"), 1, true), "prêtre sans métier : couture et enchantement conseillés")

-- équiper depuis l'alerte (lien avec le jeu)
check(root.Game.Equip("|Hitem:6948|h") and W.equipped, "équiper par le lien avec le jeu")

if os.getenv("SHOW") then W.rprint(report) end
W.rprint("\nTOUT OK (" .. LANG .. ")")
