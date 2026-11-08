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
heal.db.manaAlert = true
SlashCmdList.FOREVERHEAL("alerte test")
check(ForeverHealManaAlert:IsShown() and ForeverHealManaAlert.text:GetText():find("23", 1, true) and rawget(ForeverHealManaAlert, "bar"),
      "/fheal alerte test : aperçu avec texte et barre de mana")
ForeverHealManaAlert.GetCenter = function() return 640, 300 end
ForeverHealManaAlert.scripts.OnDragStop(ForeverHealManaAlert)
check(heal.db.alertPos and heal.db.alertPos[1] == 640, "alerte déplacée : position retenue")
ForeverHealManaAlert:Hide()
check(root.TestReport():find("[OK] Jeu — mana comparée par le jeu", 1, true), "auto-test : comparaison par le jeu testée")

check(root.ProbeText():find("secretPowerOutOfCombat = true", 1, true), "sonde : mana secrète hors combat relevée")
-- sonde : vie d'un allié secrète, affichage essayé sans calcul
do
  local saveH, saveM, saveMax = _G.UnitHealth, _G.UnitHealthMissing, _G.UnitHealthMax
  _G.UnitHealth, _G.UnitHealthMax = function() return SECRET end, function() return SECRET end
  _G.UnitHealthMissing = function() return SECRET end
  local text = root.ProbeText()
  check(text:find('missing = "secrète"', 1, true) and text:find('shown = "UnitHealthMissing"', 1, true)
        and text:find('healthMax = "secrète"', 1, true), "sonde : vie manquante secrète relevée")
  check(text:find('setText = "OK"', 1, true) and text:find('concat = "refusé', 1, true), "sonde : essais d'affichage notés (texte accepté, calcul refusé)")
  _G.UnitHealth, _G.UnitHealthMissing, _G.UnitHealthMax = saveH, saveM, saveMax
end

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

-- rôle choisi (le client ne donne pas les talents) : poids d'Équipement selon classe et rôle
local loot = root.mods.ForeverLoot
W.class = "WARRIOR"
check(table.concat(root.ClassRoles(), ",") == "tank,melee", "guerrier : rôles tank et mêlée")
root.SetRole("tank")
local w, role = loot.Weights()
check(role == "tank" and w.ITEM_MOD_DEFENSE_SKILL_RATING_SHORT and (w.ITEM_MOD_STAMINA_SHORT or 0) >= 1, "guerrier tank : défense et endurance comptent")
root.SetRole("melee")
w = loot.Weights()
check((w.ITEM_MOD_STRENGTH_SHORT or 0) == 1 and not w.ITEM_MOD_DEFENSE_SKILL_RATING_SHORT, "guerrier mêlée : force d'abord")
W.class = "PRIEST"
check(table.concat(root.ClassRoles(), ",") == "heal,caster", "prêtre : soins ou ombre")
root.SetRole("caster")
local nl2 = root.NowLines()
local hasPriest = false
for _, l in ipairs(nl2) do if l.kind == "head" and l.title == root.L.secPriest then hasPriest = true end end
check(not hasPriest, "prêtre ombre : pas de section soins sur Maintenant")
root.SetRole("auto")

-- flèche intégrée (à la TomTom) : direction, distance, arrivée, /fp way, « y aller » depuis la base intégrée
local nav = root.Nav
local PX, PY, FACE = 50, 50, 0                  -- joueur au centre de la carte 1434, regard vers le nord
_G.CreateVector2D = function(x, y) return { GetXY = function() return x, y end } end
_G.C_Map = _G.C_Map or {}
_G.C_Map.GetBestMapForUnit = function() return 1434 end
_G.C_Map.GetPlayerMapPosition = function() return CreateVector2D(PX / 100, PY / 100) end
-- carte 1434 : 1 % = 10 yards ; le haut de la carte (y petit) est le nord, la gauche (x petit) l'ouest
_G.C_Map.GetWorldPosFromMapPos = function(map, v) local x, y = v:GetXY(); return map == 9999 and 2 or 1, CreateVector2D((0.5 - y) * 1000, (0.5 - x) * 1000) end
_G.C_Map.GetMapInfo = function(id) return { name = "Vallée de Strangleronce" } end
_G.GetPlayerFacing = function() return FACE end
nav.Set(1434, 50, 40, "Au nord")
local d, a = nav.Bearing()
check(math.abs(d - 100) < 0.1 and math.abs(a) < 0.01, "flèche : but 100 m droit devant (nord)")
FACE = math.pi / 2                                -- le joueur regarde à l'ouest : le but est à sa droite
d, a = nav.Bearing()
check(math.abs(a + math.pi / 2) < 0.01, "flèche : le joueur tourne à l'ouest, la flèche pointe à droite")
nav.Set(1434, 60, 50, "À l'est")
FACE = 0
d, a = nav.Bearing()
check(math.abs(a + math.pi / 2) < 0.01 and math.abs(d - 100) < 0.1, "flèche : but à l'est = à droite")
ForeverCompagnonArrow.scripts.OnUpdate(ForeverCompagnonArrow, 1)
check(ForeverCompagnonArrow:IsShown() and ForeverCompagnonArrow.dist:GetText():find("100", 1, true), "flèche affichée avec la distance")
PX = 60
ForeverCompagnonArrow.scripts.OnUpdate(ForeverCompagnonArrow, 1)
check(ForeverCompagnonArrow.dist:GetText() == root.L.navArrived, "arrivé au but")
nav.Set(9999, 10, 10, "Ailleurs")
ForeverCompagnonArrow.scripts.OnUpdate(ForeverCompagnonArrow, 1)
check(ForeverCompagnonArrow.dist:GetText():find("Vallée", 1, true), "but sur un autre continent : dit la zone")
SlashCmdList.FOREVERCOMPAGNON("way 42.5 63 Coffre")
check(nav.target and nav.target.x == 42.5 and nav.target.y == 63 and nav.target.title == "Coffre", "/fp way 42.5 63 Coffre")
SlashCmdList.FOREVERCOMPAGNONWAY("12 34")
check(nav.target and nav.target.x == 12 and nav.target.y == 34, "/way sans TomTom : même commande")
SlashCmdList.FOREVERCOMPAGNON("way")
check(not nav.target and not ForeverCompagnonArrow:IsShown(), "/fp way : flèche effacée")
-- « y aller » : Anneau de canaliste (272406), vendu dans la Vallée de Strangleronce (base intégrée)
local cardGo
for _, l in ipairs(root.mods.ForeverLoot.NearLines(60)) do if l.onRight and l.source then cardGo = l end end
check(not cardGo or (cardGo.source:find(root.mods.ForeverLoot.L.goTag, 1, true) and not (cardGo.tags or ""):find(root.mods.ForeverLoot.L.goTag, 1, true)),
      "« clic droit : y aller » sur la ligne de la source, plus dans les étiquettes (chevauchement du gain)")
check(root.mods.ForeverLoot.HasPlace(272406) and root.mods.ForeverLoot.GoTo(272406) and nav.target.mapID == 1434,
      "Équipement : clic droit sur l'anneau de canaliste, flèche vers son vendeur")
-- clic droit dans la fenêtre Équipement (elle dessine ses propres cartes : le clic droit n'arrivait pas, 06/11/2026)
nav.Clear()
local lootNs = root.mods.ForeverLoot
local realNear = lootNs.NearLines
lootNs.NearLines = function() return { { kind = "card", name = "Anneau d'essai", source = "Vendeur — Vallée", onRight = function() lootNs.GoTo(272406) end } } end
lootNs.ShowTab("near")
lootNs.Refresh()
lootNs.NearLines = realNear
local rc
for _, c in ipairs(lootNs._view.cards) do if c:IsShown() and c.onRight then rc = c end end
check(rc ~= nil, "fenêtre Équipement : une carte avec « y aller »")
rc.scripts.OnClick(rc, "RightButton")
check(nav.target ~= nil, "fenêtre Équipement : clic droit sur la carte, la flèche est posée")
nav.Clear()
ForeverLootFrame:Hide()
-- marchands visités retenus (position, articles) et proposés par Guide-moi
_G.UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-4-5611-0000" or "Player-1" end
_G.UnitName = function(u) return u == "npc" and "Aubergiste de la Colline" or "Machin" end
_G.GetMerchantNumItems = function() return 2 end
_G.GetMerchantItemID = function(i) return ({ 1205, 159 })[i] end
_G.GetMerchantItemLink = function() return nil end
PX, PY = 52, 31
W.fire("MERCHANT_SHOW")
W.run(1)
local vs = root.mods.ForeverPrep.ATT.Vendors(1205)
local mine
for _, v in ipairs(vs) do if v.name == "Aubergiste de la Colline" then mine = v end end
check(mine and mine.mapID == 1434 and math.abs(mine.x - 52) < 0.1, "marchand visité retenu : il vend du jus de melon, à ta position")
_G.UnitGUID = function() return "Player-1" end
_G.UnitName = function() return "Machin" end

-- sans DungeonJournal : butin des donjons tiré des sources intégrées
local djl = root.mods.ForeverLoot.DJItems()
local scholo
for _, it in ipairs(djl) do if it.id == 16693 then scholo = it end end
check(#djl > 500 and scholo and scholo.inst == 246 and scholo.level, "butin des donjons sans DungeonJournal : " .. #djl .. " objets (Collerette de dévot : Scholomance)")

-- sans Syndicator ni Auctionator : inventaire (sacs, banque, rerolls) et prix relevés par ForeverCompagnon
local store = root.Store
_G.C_Item.GetItemCount = function(id, bank) if id == 2589 then return bank and 25 or 5 end return 0 end
local BANK = { [-1] = { 2589, 2589 } }
local realCC = _G.C_Container
_G.C_Container = setmetatable({
  GetContainerNumSlots = function(b) if BANK[b] then return #BANK[b] end return realCC.GetContainerNumSlots(b) end,
  GetContainerItemID = function(b, sl) if BANK[b] then return BANK[b][sl] end return realCC.GetContainerItemID(b, sl) end,
  GetContainerItemInfo = function(b, sl) if BANK[b] then return { itemID = BANK[b][sl], stackCount = 10 } end
    local id = realCC.GetContainerItemID(b, sl); return id and { itemID = id, stackCount = 1 } end,
}, { __index = realCC })
W.fire("BANKFRAME_OPENED")
local b, bk, alts = store.Count(2589)
check(b == 5 and bk == 20 and alts == 0, "banque relevée à l'ouverture : 5 en sacs, 20 en banque")
root.db.inv["Reroll - Forever"] = { bags = { [2589] = 7 }, bank = { [14047] = 3 } }
b, bk, alts = store.Count(2589)
check(alts == 7 and store.Owned(2589):find("Reroll", 1, true), "reroll : 7 étoffes de lin chez Reroll")
local mb, mbank, malts = root.mods.ForeverMetiers.Count(2589)
check(mb == 5 and mbank == 20 and malts == 7, "Métiers : composants comptés sans Syndicator (sacs, banque, rerolls)")
check(root.mods.ForeverLoot.Owned(14047):find("Reroll", 1, true), "Équipement : objet chez un reroll, sans Syndicator")
_G.C_Container = realCC
-- hôtel des ventes : bouton, relevé complet, prix unitaire le plus bas
_G.AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame")
local replicated = 0
local AUC = { { 2589, 20, 400 }, { 2589, 10, 150 }, { 14047, 5, 5000 } }      -- objet, quantité, prix d'achat immédiat
_G.C_AuctionHouse = { ReplicateItems = function() replicated = replicated + 1 end,
  GetNumReplicateItems = function() return #AUC end,
  GetReplicateItemInfo = function(i) local a = AUC[i + 1]; return "x", "t", a[2], 1, true, 1, "", 0, 0, a[3], 0, false, nil, "", "", 0, a[1], true end }
W.fire("AUCTION_HOUSE_SHOW")
check(ForeverCompagnonScanButton, "hôtel des ventes : bouton « Relever les prix »")
ForeverCompagnonScanButton.scripts.OnClick()
check(replicated == 1 and store.scan.running, "relevé demandé au jeu")
W.fire("REPLICATE_ITEM_LIST_UPDATE")
W.run(1)
check(store.Price(2589) == 15 and store.Price(14047) == 1000, "prix unitaire le plus bas : lin 15 pc, étoffe runique 1000 pc")
ForeverCompagnonScanButton.scripts.OnClick()
check(replicated == 1, "deuxième relevé refusé avant 15 minutes (limite du jeu)")
check(root.mods.ForeverMetiers.Price(2589) == 15, "Métiers : prix relevé par ForeverCompagnon sans Auctionator")
check(root.mods.ForeverPrep.Price(2589, true) == 15, "Préparation : prix de l'hôtel des ventes relevé")
_G.C_AuctionHouse, _G.AuctionHouseFrame = nil, nil

-- cadre « Flash » pour un soigneur : lignes de la partie Soins, avec leur icône et le résultat sur les soins
local heal2 = root.mods.ForeverHeal
heal2.db.announce, heal2.db.announceWhere = true, "screen"
local A = heal2.Snapshot()
local B = {}
for k, v in pairs(A) do B[k] = v end
B.sta, B.int, B.res = A.sta + 10, A.int + 6, A.res
root.Flash.lastItem = "|cff0070dd|Hitem:6948|h[Robe de l'essai]|h|r"
heal2.Announce(A, B)
local fl = root.Flash.last
check(ForeverCompagnonFlash:IsShown() and fl and fl.rows[1][1] == "sta" and fl.rows[2][1] == "int", "soigneur : cadre Flash avec Endurance et Intelligence")
check(fl.item and fl.item:find("Robe de l'essai", 1, true), "soigneur : objet équipé affiché dans le cadre")
check(ForeverCompagnonFlash.rows[1].value:GetText():find("+10", 1, true) and ForeverCompagnonFlash.rows[1].detail:GetText() ~= "",
      "ligne : valeur en grand, effet en petit dessous")
root.Flash.Show({ rows = { { "sta", "|cffff6a5a-6|r Endurance » |cffff6a5a-60|r PV" } }, result = string.rep("Soin moyen +1 · +0,4 soins/s ", 4) })
check(not ForeverCompagnonFlash.rows[1].value:GetText():find("|c", 1, true), "Flash : une seule couleur par ligne (couleurs incluses retirées)")
check(ForeverCompagnonFlash.rows[2].value:GetText():find("Soin moyen", 1, true), "Flash : ligne de résultat affichée (sur deux lignes si longue)")
SlashCmdList.FOREVERCOMPAGNON("flash")
check(root.db.flash == false, "/fp flash : cadre désactivé")
ForeverCompagnonFlash:Hide()
root.Flash.Show({ rows = { { "sta", "+1 Endurance" } } })
check(not ForeverCompagnonFlash:IsShown(), "désactivé : rien ne s'affiche")
SlashCmdList.FOREVERCOMPAGNON("flash")
SlashCmdList.FOREVERCOMPAGNON("flash test")
check(ForeverCompagnonFlash:IsShown(), "/fp flash test : aperçu du cadre")
ForeverCompagnonFlash.GetCenter = function() return 900, 500 end
ForeverCompagnonFlash.scripts.OnDragStart(ForeverCompagnonFlash)
ForeverCompagnonFlash.scripts.OnDragStop(ForeverCompagnonFlash)
check(root.db.flashPos and root.db.flashPos[1] == 900, "cadre glissé : position retenue")
SlashCmdList.FOREVERCOMPAGNON("flash place")
check(root.db.flashPos == nil, "/fp flash place : retour à la place automatique")
ForeverCompagnonFlash:Hide()

-- en donjon, la cible est secrète (nom, classement, niveau) : butin noté sans jamais prendre un secret comme clé
-- (erreur en jeu le 06/11/2026 : « attempted to index a table that cannot be indexed with secret keys », Les Mortemines)
local lootMod = root.mods.ForeverLoot
local saveII2, saveZT2, saveInfo = _G.IsInInstance, _G.GetRealZoneText, _G.C_Item.GetItemInfo
_G.IsInInstance = function() return true, "party" end
_G.GetRealZoneText = function() return "Les Mortemines" end
_G.UnitExists = function() return true end
_G.UnitIsDead = function() return true end
_G.UnitIsPlayer = function() return false end
_G.UnitName = function(u) if u == "target" then return SECRET end return "Machin" end
_G.UnitClassification = function() return SECRET end
_G.UnitLevel = function(u) if u == "target" then return SECRET end return 12 end
_G.GetNumLootItems = function() return 1 end
_G.GetLootSlotLink = function() return "|cff1eff00|Hitem:9775|h[Cordelière de bandit du tigre]|h|r" end
_G.C_Item.GetItemInfo = function(x) local r = { saveInfo(x) }; r[3] = 2; return unpack(r) end
W.fire("ENCOUNTER_END", 1, "Rhahk'Zor", 1, 5, 1)
local okLoot, errLoot = pcall(W.fire, "LOOT_OPENED")
check(okLoot, "butin en donjon avec cible secrète : aucune erreur (" .. tostring(errLoot) .. ")")
local z = lootMod.gdb.dungeons["Les Mortemines"]
local secretKey = false
for k in pairs(z or {}) do if k == SECRET then secretKey = true end end
check(z and not secretKey and z["Rhahk'Zor"] and z["Rhahk'Zor"][9775], "butin rangé sous le boss de la rencontre (Rhahk'Zor), jamais sous un nom secret")
_G.IsInInstance, _G.GetRealZoneText, _G.C_Item.GetItemInfo = saveII2, saveZT2, saveInfo
_G.UnitName = function(u) return u == "npc" and "?" or "Machin" end
_G.UnitLevel = function() return 12 end

-- équiper depuis l'alerte (lien avec le jeu)
check(root.Game.Equip("|Hitem:6948|h") and W.equipped, "équiper par le lien avec le jeu")

-- noms des donjons : jamais la seule zone de l'entrée (le client de Forever n'a pas le journal des donjons)
do
  local A = root.mods.ForeverLoot.ATT
  local fr = LANG == "fr"
  check(A.InstanceName(64) == (fr and "Donjon d'Ombrecroc" or "Shadowfang Keep") and A.InstanceName(240) == (fr and "Cavernes des Lamentations" or "Wailing Caverns"),
        "donjons nommés (Ombrecroc, Cavernes des Lamentations), pas la zone de l'entrée")
end

-- HealBot : clics du prêtre et skins groupe/raid, par les fonctions d'HealBot (imitées ici)
do
  local HB = root.HealBot
  local names = { [2050] = "Soins inférieurs", [2052] = "Soins inférieurs", [2053] = "Soins inférieurs", [2054] = "Soins",
                  [2061] = "Soins rapides", [139] = "Rénovation", [17] = "Mot de pouvoir : Bouclier", [528] = "Guérison des maladies",
                  [527] = "Dissipation de la magie", [2006] = "Résurrection", [1243] = "Mot de pouvoir : Robustesse" }
  local known = { [2050] = true, [2052] = true, [2053] = true, [139] = true, [17] = true, [528] = true, [2006] = true, [1243] = true }
  local saveIPS, saveSpell = _G.IsPlayerSpell, _G.C_Spell
  _G.IsPlayerSpell = function(id) return known[id] == true end
  _G.C_Spell = { GetSpellName = function(id) return names[id] end, GetSpellSubtext = function(id)
    return ({ [2050] = "Rang 1", [2052] = "Rang 2", [2053] = "Rang 3" })[id] end }
  root.Game.used.spellName = nil
  check(not HB.Available(), "HealBot absent : rien n'est touché")
  -- HealBot imité : un nom connu (avec ou sans rang) devient « S:numéro^nom »
  local byName = { ["Soins inférieurs(Rang 2)"] = 2052 }
  for id, n in pairs(names) do if known[id] or id == 2054 or id == 2061 or id == 527 then byName[n] = byName[n] or id end end
  _G.HealBot_Config_Spells = { EnabledKeyCombo = { Left = "S:2050^Soins inférieurs", Button4 = "S:9^Perso", CtrlRight = "S:8^Mon sort" } }
  local refreshed = 0
  _G.HealBot_Action_SetSpell = function(t, combo, text)
    assert(t == "ENABLED")
    local id = byName[text] and (known[byName[text]] or text:find("Rang")) and byName[text]
    HealBot_Config_Spells.EnabledKeyCombo[combo] = id and ("S:" .. id .. "^" .. text) or text
  end
  _G.HealBot_Timers_Set = function(_, t) if t == "PrepSetAllAttribs" then refreshed = refreshed + 1 end end
  _G.HEALBOT_SORTBY_GROUP = "Groupe"     -- traduit après le chargement des données (rangées sous « Group »)
  _G.HEALBOT_WORD_SOLO, _G.HEALBOT_WORD_PARTY = "Solo", "Party"
  for _, n in ipairs({ 10, 15, 20, 25, 40 }) do _G["HEALBOT_OPTIONS_RAID" .. n] = "Raid" .. n end
  _G.HEALBOT_OPTIONS_RAID40 = "Raid 40"
  local skinText = "Skin\nGroup\nAuthor~v!Monti\nGeneral~t!{OFREQ=0.07,HIDEPARTYF=\"false\",HIDERAIDF=\"true\"}\nIcons~f~1!{RCEN=\"true\",SHOWCLASS=\"false\",SHOWROLE=\"true\"}\nBarText~f~1!{HLTHONBAR=\"false\",AHEIGHT=10,HLTHTYPE=1,NUMFORMAT1=11,SHOWROLE=\"false\",HEIGHT=13}\n" ..
                   "HealBar~f~1!{HEIGHT=40,GRPCOLS=\"false\",WIDTH=110}\nHealBar~d!2~3~\nHealGroups~f~8!{FRAME=7,STATE=\"true\",NAME=\"Pets\"}\n" ..
                   "BarSort~f~1!{SUBORDER=6,RAIDORDER=3}\nBarVisibility~f~1!{ALERTIC=0.95,ALERTOC=0.9}"
  _G.HealBot_Config_SkinsData = { Group = "PACK", ["Raid 40"] = "PACK40", Standard = "PACKSTD" }
  local first = true
  _G.HealBot_Util_Decompress = function(s) if first then first = false; return nil end; if s == "PACK" then return skinText end
    if s == "PACK40" then return (skinText:gsub("\nGroup\n", "\nRaid 40\n", 1)) end
    if s == "PACKSTD" then return "Skin\nStandard\n" end
    return s end
  local loaded = {}
  _G.HealBot_Share_SkinLoad = function(text, internal)
    assert(internal == false)
    local name = text:match("^[^\n]+\n([^\n]+)")
    loaded[name] = text
    -- comme HealBot : ancien skin renuméroté, les familiers passent de la ligne 8 à la 10, avec l'état de l'ancienne ligne 10
    Healbot_Config_Skins.HealGroups[name] = { [3] = { NAME = "Raid", FRAME = 1, STATE = true }, [10] = { NAME = "Pets", FRAME = 1, STATE = true } }
    Healbot_Config_Skins.Healing[name] = { GROUPPETS = true }
  end
  _G.HealBot_Config = { SkinDefault = { Group = { Party = true, Solo = true }, ["Raid 40"] = { ["Raid 40"] = true } } }
  _G.Healbot_Config_Skins = { Current_Skin = "Standard", HealGroups = {}, Healing = {} }
  _G.HealBot_Globals = { OverrideFrames = { USE = 2, HIDEPARTYF = true, HIDERAIDF = true } }
  local current, blizz = nil, 0
  _G.HealBot_Timers_ToggleBlizzardFrames = function() blizz = blizz + 1 end
  _G.HealBot_Options_Set_Current_Skin = function(n) current = n end
  check(HB.Available(), "HealBot chargé : reconnu")

  -- niveau 15 : Soins inférieurs au clic gauche, rang 2 (moins cher) en Maj+gauche
  W.combat = true
  HB.Setup()
  check(HealBot_Config_Spells.EnabledKeyCombo.Right == nil, "en combat : rien n'est touché, reporté à la fin du combat")
  W.combat = false
  W.fire("PLAYER_REGEN_ENABLED")
  local c = HealBot_Config_Spells.EnabledKeyCombo
  check(c.Left == "S:2050^Soins inférieurs" and c.ShiftLeft == "S:2052^Soins inférieurs(Rang 2)", "niveau 15 : Soins inférieurs (gauche), rang 2 en Maj+gauche")
  check(c.Right == "S:139^Rénovation" and c.ShiftRight == "S:17^Mot de pouvoir : Bouclier" and c.Middle == "S:528^Guérison des maladies",
        "Rénovation (droit), Bouclier (Maj+droit), Guérison des maladies (milieu)")
  check(c.CtrlLeft == "S:2006^Résurrection" and c.CtrlMiddle == "S:1243^Mot de pouvoir : Robustesse" and c.AltLeft == nil,
        "Résurrection (Ctrl+gauche), Robustesse (Ctrl+milieu, jamais Alt : touche « soi-même » de WoW)")
  check(c.Button4 == "S:9^Perso" and c.CtrlRight == "S:8^Mon sort" and c.ShiftMiddle == nil, "clics non prévus laissés tels quels (bouton 4, Ctrl+droit)")
  check(refreshed >= 1, "HealBot relit ses clics")
  local st = HB.Store()
  check(st.clicks and st.clicks.Left == "S:2050^Soins inférieurs" and st.clicks.Right == nil, "sauvegarde des clics d'avant")
  -- skins
  local g, r = loaded["Forever Groupe"], loaded["Forever Raid"]
  check(g and r, "skins « Forever Groupe » et « Forever Raid » importés par HealBot")
  check(g and g:find("HLTHTYPE=3", 1, true) and g:find("HLTHONBAR=\"true\"", 1, true) and g:find("AHEIGHT=10", 1, true)
        and g:find(",HEIGHT=12", 1, true) and g:find("SHOWROLE=\"true\"", 1, true) and g:find("IGNOREONFULL=\"true\"", 1, true),
        "skin : vie en % affichée, rôles, autres réglages intacts (AHEIGHT)")
  check(g and g:find('Icons~f~1!{RCEN="true",SHOWCLASS="true",SHOWROLE="true"}', 1, true)
        and g:find('General~t!{OFREQ=0.07,HIDEPARTYF="false",HIDERAIDF="false"}', 1, true), "skin : icône de rôle, cadres de Blizzard gardés en secours")
  check(blizz == 1 and HealBot_Globals.OverrideFrames.HIDEPARTYF == false and HealBot_Globals.OverrideFrames.HIDERAIDF == false,
        "cadres de WoW gardés en secours (skin et réglage global d'HealBot), relus tout de suite")
  check(g and g:find('HealGroups~f~8!{FRAME=7,STATE="false",NAME="Pets"}', 1, true), "skin groupe : sans familiers (infobulle d'HealBot qui plante)")
  check(g and g:find('HealBar~f~1!{HEIGHT=38,GRPCOLS="false",WIDTH=130,CMARGIN=3,RMARGIN=3,TEXTURE="Smooth v2"}', 1, true) and g:find("HealBar~d!2~3~", 1, true), "skin groupe : barres lisses 130×38")
  check(r and r:find("WIDTH=90", 1, true) and r:find("GRPCOLS=\"true\"", 1, true) and r:find("NAME=\"Pets\"", 1, true)
        and r:find("STATE=\"false\"", 1, true) and r:find("SUBORDER=5", 1, true), "skin raid : colonnes par groupe, sans familiers, tri par rôle")
  local sd = HealBot_Config.SkinDefault
  check(sd["Forever Groupe"].Party and sd["Forever Groupe"].Solo and sd["Forever Raid"].Raid10 and sd["Forever Raid"]["Raid 40"]
        and not sd.Group.Party and not sd["Raid 40"]["Raid 40"], "HealBot passe seul sur Forever Groupe / Forever Raid")
  check(current == "Forever Groupe", "skin actif : Forever Groupe (hors raid)")
  local hg = Healbot_Config_Skins.HealGroups["Forever Groupe"]
  check(hg[10].STATE == false and hg[3].STATE == true and Healbot_Config_Skins.Healing["Forever Groupe"].GROUPPETS == false
        and Healbot_Config_Skins.HealGroups["Forever Raid"][10].STATE == false, "familiers retirés par leur nom après l'import (HealBot renumérote)")
  Healbot_Config_Skins.Current_Skin = "Forever Groupe"
  SlashCmdList.FOREVERCOMPAGNON("healbot diag")
  Healbot_Config_Skins.Current_Skin = "Standard"

  -- ancienne version : Robustesse posée sur Alt+gauche -> libérée et déplacée ; un Alt+clic changé à la main reste
  c.AltLeft = "S:1243^Mot de pouvoir : Robustesse"; st.set.AltLeft = c.AltLeft
  c.AltRight = "S:5^Perso"; st.set.AltRight = "S:4^Ancien"
  HB.Update()
  check(c.AltLeft == nil and st.set.AltLeft == nil and c.CtrlMiddle == "S:1243^Mot de pouvoir : Robustesse", "ancien Alt+gauche libéré, Robustesse sur Ctrl+milieu")
  check(c.AltRight == "S:5^Perso", "Alt+clic changé à la main : gardé")
  c.AltRight = nil
  -- niveau 16 : Soins appris -> clic gauche mis à jour ; un clic changé à la main n'est pas touché
  c.Right = "S:7^Mon choix"
  known[2054] = true
  HB.Update()
  check(c.Left == "S:2054^Soins" and c.ShiftLeft == "S:2050^Soins inférieurs", "niveau 16 : Soins (gauche), Soins inférieurs (Maj+gauche)")
  check(c.Right == "S:7^Mon choix", "clic changé à la main : gardé")
  -- niveau 18 et 20 : Dissipation, Soins rapides
  known[527], known[2061] = true, true
  HB.Update()
  check(c.ShiftMiddle == "S:527^Dissipation de la magie" and c.ShiftLeft == "S:2061^Soins rapides", "niveau 18-20 : Dissipation (Maj+milieu), Soins rapides (Maj+gauche)")
  check(HB.ComboLabel("ShiftLeft") == (LANG == "fr" and "Maj+Clic gauche" or "Shift+Left click"), "nom des clics lisible")
  -- annuler
  HB.Restore()
  check(c.Left == "S:2050^Soins inférieurs" and c.Right == nil and c.Button4 == "S:9^Perso" and HealBot_Config.SkinDefault.Group.Party
        and HealBot_Config.SkinDefault["Forever Raid"] == nil
        and current == "Standard", "annuler : clics et skins d'avant remis")
  check(not HB.Restore(), "annuler deux fois : rien à remettre")
  -- vie manquante sur les barres : valeur secrète passée telle quelle au texte, jamais lue
  local secretStr = setmetatable({}, { __concat = function() error("secret") end, __eq = function() error("secret") end })
  _G.UnitHealthMissing = function() return SECRET end
  _G.C_StringUtil = { TruncateWhenZero = function(v) assert(v == SECRET); return secretStr end }
  _G.UnitIsConnected = function(u) return u ~= "party2" end
  local function Btn(unit) return { unit = unit, gref = { Top = CreateFrame("Frame"), Bar = CreateFrame("StatusBar") } } end
  _G.HealBot_Unit_Button = { a = Btn("party1"), b = Btn("party2") }
  HB.UpdateDeficits()
  check(HealBot_Unit_Button.a.fcDeficit and HealBot_Unit_Button.a.fcDeficit:GetText() == secretStr, "vie manquante : texte du jeu posé sur la barre (sans être lu)")
  check(HealBot_Unit_Button.b.fcDeficit:GetText() == "", "membre hors ligne : rien")
  SlashCmdList.FOREVERCOMPAGNON("healbot chiffres")
  check(HealBot_Unit_Button.a.fcDeficit:GetText() == "" and root.db.healbotDeficit == false, "/fp healbot chiffres : masqué")
  SlashCmdList.FOREVERCOMPAGNON("healbot chiffres")
  check(HealBot_Unit_Button.a.fcDeficit:GetText() == secretStr, "/fp healbot chiffres : réaffiché")
  W.run(1)
  _G.HealBot_Unit_Button, _G.UnitHealthMissing, _G.C_StringUtil, _G.UnitIsConnected = nil, nil, nil, nil
  -- autre classe
  W.class = "MAGE"
  check(not HB.Setup(), "autre classe : pas de configuration automatique")
  W.class = "PRIEST"
  _G.IsPlayerSpell, _G.C_Spell = saveIPS, saveSpell
  root.Game.used.spellName = nil
  for _, k in ipairs({ "HealBot_Config_Spells", "HealBot_Action_SetSpell", "HealBot_Config", "HealBot_Share_SkinLoad" }) do _G[k] = nil end
end

if os.getenv("SHOW") then W.rprint(report) end
W.rprint("\nTOUT OK (" .. LANG .. ")")
