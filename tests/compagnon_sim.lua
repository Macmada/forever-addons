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

-- (anciens dossiers ForeverHeal, ForeverLoot, ForeverPrep, ForeverMetiers, ForeverPretre retirés en 3.5.8)

-- chargement complet
-- gestionnaire d'erreurs du jeu (le relevé des erreurs de tous les addons s'y chaîne)
local blizzHandled = {}
local handler = function(msg) blizzHandled[#blizzHandled + 1] = msg end
_G.geterrorhandler = function() return handler end
_G.seterrorhandler = function(f) handler = f end
_G.debugstack = function() return "[string \"@Interface/AddOns/Questie/Modules/Map.lua\"]:42: in function <...>\n[C]: in function 'pcall'" end
local function GameError(msg) return geterrorhandler()(msg) end
_G.hooksecurefunc = _G.hooksecurefunc or function(name, f)
  local orig = _G[name]
  _G[name] = function(...) local r = { orig(...) }; f(...); return unpack(r) end
end
local root = W.load("ForeverCompagnon")
W.fire("ADDON_LOADED", "ForeverCompagnon")
_G.CharacterFrame = W.Obj("CharacterFrame")
W.fire("PLAYER_LOGIN")
W.fire("PLAYER_ENTERING_WORLD")
W.run(5)
check(rawget(root, "Sources") == nil and (W.dataLoads or 0) == 0, "sources intégrées (850 Ko) pas chargées à la connexion")
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
check(_G.ForeverPrepMinimapButton == nil, "4.0 : plus d'icône séparée de Prépa (une seule icône Forever)")

-- écran Maintenant
SlashCmdList.FOREVERCOMPAGNON("")
check(root.Sources and W.dataLoads == 1, "sources chargées une fois, au premier besoin (écran Maintenant)")
check(ForeverCompagnonFrame and ForeverCompagnonFrame:IsShown(), "/fp : écran Maintenant")
local lines, _, tiles = root.NowLines()
check(lines[1].kind == "head" and lines[1].title == root.L.secTodo and #root.nowErrors == 0,
      "Maintenant : « À faire » en premier, sans erreur (" .. table.concat(root.nowErrors, " ; ") .. ")")
local footers = 0
for _, l in ipairs(lines) do if l.footer then footers = footers + 1 end end
check(footers == 3, "Maintenant : liens vers les 3 onglets en bas")
check(#tiles >= 3 and #tiles <= 4, "Maintenant : " .. #tiles .. " tuiles en haut")

-- 3.7.0 : plus de suivi de session (XP) ni de Métiers
check(root.Session == nil and root.mods.ForeverMetiers == nil, "suivi de session et Métiers retirés")
for _, t in ipairs(tiles) do check(t.kind ~= "session", "pas de tuile de session") end
check(_G.ForeverCompagnonSessionSheet == nil, "pas de bandeau de session sous la fiche du personnage")
check(ForeverCompagnonFrame.counters and ForeverCompagnonFrame.counters[1].value:GetText() ~= nil, "compteurs affichés")
check(not (ForeverCompagnonRail and ForeverCompagnonRail:IsShown()), "4.0 : Accueil sans barre à côté (onglets dans la fenêtre)")
local F = ForeverCompagnonFrame
local tabsShown = 0
for _, b in ipairs(F.tabs) do if b:IsShown() then tabsShown = tabsShown + 1 end end
check(#F.tabs == 4 and tabsShown == 4, "4.0 : 4 onglets (prêtre : Soins visible)")
local acts, counters = root.HomeData()
check(#acts <= 5 and #counters == 3, "4.0 : Accueil = 3 compteurs et " .. #acts .. " action(s) (5 au plus)")
for i, a in ipairs(acts) do
  check(F.rows[i]:IsShown() and F.rows[i].action:GetText() == root.HomeAction(a), "4.0 : ligne " .. i .. " « " .. tostring(a.name) .. " » bouton " .. tostring(root.HomeAction(a)))
end
check(F.subBtn.fs:GetText():find("12", 1, true) ~= nil, "4.0 : en-tête avec le niveau")
root.ShowToolsMenu()
check(ForeverCompagnonToolsMenu:IsShown() and ForeverCompagnonToolsMenu.rows[1]:IsShown(), "4.0 : menu Outils ouvert")
local mr = ForeverCompagnonToolsMenu.rows[1]
mr.scripts.OnEnter(mr)
check(mr.hover:IsShown(), "menu Outils : survol derrière le texte (il ne le masque plus)")
mr.scripts.OnLeave(mr)
for _, r in ipairs(ForeverCompagnonToolsMenu.rows) do
  if r:IsShown() and r.title:GetText() == root.MainText.mAddons then r:GetScript("OnClick")(r) end
end
check(ForeverCompagnonAddonsFrame and ForeverCompagnonAddonsFrame:IsShown() and not ForeverCompagnonToolsMenu:IsShown(), "4.0 : menu Outils > Addons")
ForeverCompagnonAddonsFrame:Hide()
-- hôtel des ventes : l'amélioration la plus rentable (points par pièce d'or) que tu peux payer
do
  local loot = root.mods.ForeverLoot
  local cand
  for _, sl in pairs(loot.BiS(5, UnitLevel("player"))) do
    for _, c in ipairs(sl.items) do if c.src ~= "bags" and not cand then cand = c end end
  end
  check(cand ~= nil, "hôtel des ventes : un objet candidat à ton niveau")
  local saveA, saveM = _G.Auctionator, _G.GetMoney
  _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return id == cand.id and 25000 or nil end } } }
  _G.GetMoney = function() return 100000 end
  loot.ForgetMemo()
  local ah
  for _, l in ipairs(root.NowLines()) do if l.ah then ah = l end end
  check(ah and ah.source:find(root.Coins(25000), 1, true) and root.HomeAction(ah) == root.MainText.ah,
        "Accueil : « Hôtel des ventes : … » avec le prix (" .. tostring(ah and ah.source) .. ")")
  _G.GetMoney = function() return 100 end
  local none = true
  for _, l in ipairs(root.NowLines()) do if l.ah then none = false end end
  check(none, "hôtel des ventes : rien si tu ne peux pas payer")
  _G.Auctionator, _G.GetMoney = saveA, saveM
end
-- tournée en ville : maître, marchand et hôtel des ventes en un trajet, le plus proche d'abord
do
  local Nav, prep = root.Nav, root.mods.ForeverPrep
  local sv = { Player = Nav.Player, World = Nav.World, Due = prep.TrainerDue, An = prep.Analyze, V = prep.ATT.Vendors, R = _G.IsResting }
  Nav.Player = function() return 0, 0, 0 end
  Nav.World = function(_, x, y) return 0, x * 10, y * 10 end            -- 1 point de carte = 10 m
  prep.TrainerDue = function() return { { name = "Soins" } }, 100, { mapID = 1, x = 50, y = 0, npc = "Maître" } end
  prep.Analyze = function() return { shopping = { { id = 1, name = "Eau" }, { id = 2, name = "Pain" } }, sections = {} } end
  prep.ATT.Vendors = function(id) return { { name = "Aubergiste", mapID = 1, x = 10, y = 0 }, { name = "Loin", mapID = 1, x = 900, y = 0 } } end
  root.db.auctionHouses = { a = { mapID = 1, x = 30, y = 0, faction = UnitFactionGroup("player") } }
  local stops = root.TourStops(true)
  check(#stops == 3 and stops[1].title == "Aubergiste" and stops[2].title == root.TourText.ah and stops[3].title == "Maître",
        "tournée : 3 arrêts dans l'ordre le plus court (marchand, HV, maître), marchand trop loin écarté")
  check(#stops[1].what == 2, "tournée : un seul arrêt pour les deux achats chez le même marchand")
  _G.IsResting = function() return true end
  local tl
  for _, l in ipairs(root.NowLines()) do if l.tour then tl = l end end
  check(tl and root.HomeAction(tl) == root.MainText.route, "Accueil en ville : ligne « Tournée en ville »")
  check(root.StartTour(stops) and Nav.route and #Nav.route.steps == 3 and Nav.target.title == "Aubergiste", "tournée : la flèche part vers le 1er arrêt")
  Nav.Arrived()
  check(Nav.target.title == root.TourText.ah, "tournée : arrivé, la flèche passe au 2e arrêt")
  Nav.Clear()
  Nav.Player, Nav.World, prep.TrainerDue, prep.Analyze, prep.ATT.Vendors, _G.IsResting = sv.Player, sv.World, sv.Due, sv.An, sv.V, sv.R
  root.db.auctionHouses = nil
end
-- fiche collée au personnage (touche C) : nouveau style (4.0)
_G.CharacterFrame.scripts.OnShow(_G.CharacterFrame)
check(ForeverCompagnonSheet and ForeverCompagnonSheet:IsShown() and not (_G.ForeverHealPanel and _G.ForeverHealPanel:IsShown()),
      "C : fiche Soins de ForeverCompagnon, plus l'ancien panneau")
check(ForeverCompagnonSheet.counters[1].value:GetText() ~= nil and #ForeverCompagnonSheet.list.Shown("head") >= 1, "fiche : chiffres et rubriques")
_G.CharacterFrame.scripts.OnHide(_G.CharacterFrame)
check(not ForeverCompagnonSheet:IsShown(), "fermer la fiche du personnage ferme la fiche Soins")
ForeverCompagnonSheet.scripts.OnDragStop(ForeverCompagnonSheet)
check(root.db.sheetPos ~= nil, "fiche Soins déplacée : place retenue")
SlashCmdList.FOREVERCOMPAGNON("fiche place")
check(root.db.sheetPos == nil, "/fp fiche place : retour à côté de la fiche du personnage")
-- panneau Options du jeu (Échap > Options > AddOns)
SlashCmdList.FOREVERCOMPAGNON("options")
check(ForeverCompagnonOptions ~= nil, "/fp options : panneau ForeverCompagnon créé")
ForeverCompagnonOptions.scripts.OnShow(ForeverCompagnonOptions)
local nChecks = 0
for _, cb in ipairs(ForeverCompagnonOptions.checks) do if cb:IsShown() then nChecks = nChecks + 1 end end
check(nChecks >= 8, "Options : " .. nChecks .. " réglages (Fenêtre, Équipement, Donjon, Soins)")
local prepDb = root.mods.ForeverPrep.db
local before = prepDb.autoInstance
for _, cb in ipairs(ForeverCompagnonOptions.checks) do
  if cb.label:GetText() == root.mods.ForeverPrep.L.optAutoInstance then cb:SetChecked(not before); cb.scripts.OnClick(cb) end
end
check(prepDb.autoInstance == (not before), "Options : la case écrit le réglage de la partie")
prepDb.autoInstance = before

-- onglets : tout dans la même fenêtre (4.0)
root.Open("loot")
check(F:IsShown() and root.CurrentPage() == "loot" and F.pages.loot:IsShown() and not F.home:IsShown(), "onglet Équipement : dans la fenêtre")
check(F.tabs[2].line:IsShown() and not F.tabs[1].line:IsShown(), "onglet Équipement souligné")
check(not (_G.ForeverLootFrame and _G.ForeverLootFrame:IsShown()), "ancienne fenêtre d'équipement plus ouverte")
F.pages.loot.seg.buttons[2]:GetScript("OnClick")()
check(root.lootView == "goal", "Équipement : vue Objectif 60")
F.pages.loot.seg.buttons[1]:GetScript("OnClick")()
SlashCmdList.FOREVERPREP("")
check(root.CurrentPage() == "prep" and F.pages.prep:IsShown(), "/prep : onglet Donjon de la fenêtre")
check(F.pages.prep.done:GetText():match("^%d+ / %d+"), "Donjon : compteur « prêt » (" .. tostring(F.pages.prep.done:GetText()) .. ")")
root.Open("heal")
check(root.CurrentPage() == "heal" and F.pages.heal.counters[1].value:GetText() ~= nil, "onglet Soins : chiffres affichés")
check(#F.pages.heal.list.Shown("head") >= 1, "onglet Soins : rubrique « Tes soins »")
root.Open("prep")
check(#F.pages.prep.list.Shown("check") >= 1 and #F.pages.prep.list.Shown("head") >= 1, "onglet Donjon : rubriques et cases (" .. #F.pages.prep.list.Shown("check") .. " cases)")
local mustRow
for _, r in ipairs(F.pages.prep.list.Shown("check")) do if r.line.onMust then mustRow = mustRow or r end end
check(mustRow and mustRow.must:IsShown(), "onglet Donjon : case « obligatoire » sur les lignes réglables")
local keyMust = mustRow.line
mustRow.must:SetChecked(not keyMust.must)
mustRow.must.scripts.OnClick(mustRow.must)
local flipped
for _, r in ipairs(F.pages.prep.list.Shown("check")) do if r.line.label == keyMust.label then flipped = r.line.must end end
check(flipped == (not keyMust.must), "case « obligatoire » : réglage changé et fiche recalculée")
-- maître de classe sur Forever : le 2e retour est le type (« available »), pas un rang
local pdb = root.mods.ForeverPrep.db
local savedTrainer = pdb.trainer
pdb.trainer = { services = { { name = "Brûlure de mana", rank = "available", level = 1, cost = 10 }, { name = "Soins", rank = "used", level = 1, cost = 5 } } }
local due = root.mods.ForeverPrep.TrainerDue()
check(#due == 1 and due[1].rank == nil, "maître de classe : « available » n'est pas un rang, « used » déjà appris")
pdb.trainer = savedTrainer
root.Open("loot")
check(#F.pages.loot.list.Shown("card") + #F.pages.loot.list.Shown("info") >= 1, "onglet Équipement : lignes affichées")
root.Open("heal")
F:Hide()
root.Toggle()
check(F:IsShown() and root.CurrentPage() == "heal", "réouverture : dernier onglet")
F:Hide()
root.Open("metiers")
check(ForeverCompagnonFrame:IsShown() and root.db.lastTab == "now" and root.CurrentPage() == "now", "ancien onglet Métiers : Accueil à la place")
ForeverCompagnonFrame:Hide()

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
check(d:find("ForeverHeal", 1, true) and d:find("ForeverPrep", 1, true) and d:find("Lien avec le jeu", 1, true), "diagnostic commun avec chaque partie")

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
SlashCmdList.FOREVERCOMPAGNON("addons")
check(ForeverCompagnonAddonsFrame:IsShown(), "/fp addons : fenêtre Addons (4.0 : dans le menu Outils)")
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
local _, _, tl2 = root.NowLines()
local hasHps = false
for _, t in ipairs(tl2) do if t.kind == "hps" then hasHps = true end end
check(not hasHps, "prêtre ombre : pas de tuile soins sur Maintenant")
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
check(not cardGo or (not cardGo.source:find(root.mods.ForeverLoot.L.goTag, 1, true) and not (cardGo.tags or ""):find(root.mods.ForeverLoot.L.goTag, 1, true)),
      "« y aller » : épingle sur l'icône et infobulle, plus de texte qui chevauche le gain")
check(root.mods.ForeverLoot.HasPlace(272406) and root.mods.ForeverLoot.GoTo(272406) and nav.target.mapID == 1434,
      "Équipement : clic droit sur l'anneau de canaliste, flèche vers son vendeur")
-- clic droit dans la fenêtre Équipement (elle dessine ses propres cartes : le clic droit n'arrivait pas, 06/11/2026)
nav.Clear()
local lootNs = root.mods.ForeverLoot
local realNear = lootNs.NearLines
lootNs.NearLines = function() return { { kind = "card", name = "Anneau d'essai", source = "Vendeur — Vallée", onRight = function() lootNs.GoTo(272406) end } } end
lootNs.ShowTab("near")
lootNs.NearLines = realNear
local rc = ForeverCompagnonFrame.pages.loot.list.Shown("card")[1]
check(rc ~= nil and rc.action:GetText() == root.PagesText.go, "onglet Équipement : une carte avec « Y aller »")
rc.scripts.OnClick(rc, "RightButton")
check(nav.target ~= nil, "onglet Équipement : clic droit sur la carte, la flèche est posée")
nav.Clear()
ForeverCompagnonFrame:Hide()
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

-- « À faire » : maître de classe (sorts à apprendre d'après la dernière visite), donjons et zones (clic : itinéraire)
do
  local prep, loot = root.mods.ForeverPrep, root.mods.ForeverLoot
  _G.GetNumTrainerServices = function() return 3 end
  _G.GetTrainerServiceInfo = function(i) return ({ "Soins rapides", "Rénovation", "Soins supérieurs" })[i], i == 2 and "Rang 3" or "", i == 3 and "unavailable" or "available" end
  _G.GetTrainerServiceLevelReq = function(i) return ({ 12, 12, 40 })[i] end
  _G.GetTrainerServiceCost = function() return 1500 end
  _G.IsTradeskillTrainer = function() return false end
  W.fire("TRAINER_SHOW")
  local due = prep.TrainerDue()
  check(due and #due == 2 and due[2].rank == "Rang 3", "maître de classe : 2 sorts à ton niveau retenus (pas celui du niveau 40)")
  local saveWhere = loot.WhereToGo
  loot.WhereToGo = function() return { { key = "i64", name = "Donjon d'Ombrecroc", kind = "dungeon", level = 14, mapID = 1421, x = 36.6, y = 65.6,
    items = { { c = { link = "|Hitem:6320|h[Torque de sorcier]|h", id = 6320 }, eval = { method = "heal", hps = 0.1, score = 3 } } },
    quests = {}, nQuests = 0, score = 3 } } end
  local went
  local saveGo = root.Nav.Go
  root.Nav.Go = function(m, x, y, t) went = t end
  local lines = root.NowLines()
  local trainer, place
  for _, l in ipairs(lines) do
    if l.trainer then trainer = l end
    if l.place then place = l end
  end
  check(trainer and trainer.gain:find("2", 1, true) and trainer.source:find("Soins rapides", 1, true), "À faire : maître de classe, 2 sorts")
  check(place and place.name:find("Ombrecroc", 1, true) and place.tags:find("14", 1, true) and place.tip.title == "Donjon d'Ombrecroc",
        "À faire : donjon d'après tes améliorations, niveau et détail dans l'infobulle")
  place.onClick()
  check(went == "Donjon d'Ombrecroc", "clic sur le donjon : itinéraire le plus rapide")
  root.Nav.Go, loot.WhereToGo = saveGo, saveWhere
  _G.GetNumTrainerServices = nil
  prep.db.trainer = nil
end

-- performance : une actualisation de l'écran Maintenant ne recalcule la liste des objets qu'une fois, la suivante pas du tout
do
  local loot = root.mods.ForeverLoot
  loot.ForgetMemo()
  local before = loot.candidatesBuilt or 0
  root.NowLines()
  local first = (loot.candidatesBuilt or 0) - before
  root.NowLines()
  local second = (loot.candidatesBuilt or 0) - before - first
  check(first <= 1 and second == 0, "Maintenant : objets évalués une fois par actualisation (" .. first .. "), pas à la suivante (" .. second .. ")")
end
-- performance : l'infobulle d'un objet n'est lue qu'une fois (avant la 3.5.3 : à chaque évaluation, objet porté compris)
do
  local heal = root.mods.ForeverHeal
  local links = {}
  for i = 1, 40 do links[i] = "|cffffffff|Hitem:" .. (7000 + i) .. "::::::::12:::::|h[Objet " .. (7000 + i) .. "]|h|r" end
  local saveInst = C_Item.GetItemInfoInstant
  C_Item.GetItemInfoInstant = function(x) local id = tonumber(tostring(x):match("(%d+)")); return id, "Armor", "Cloth", "INVTYPE_HAND", "Interface\\Icons\\INV_Misc_QuestionMark", 4, 1 end
  heal.scanCount = 0
  for _, l in ipairs(links) do ForeverHealAPI.Evaluate(l) end
  local first = heal.scanCount
  heal.scanCount = 0
  for _, l in ipairs(links) do ForeverHealAPI.Evaluate(l) end
  C_Item.GetItemInfoInstant = saveInst
  check(first > 0 and first <= 41 * 2 and heal.scanCount == 0, "infobulles lues une fois par objet (" .. first .. " pour 40 objets), aucune à la 2e évaluation (" .. heal.scanCount .. ")")
end

-- niveaux des donjons : ceux du jeu (recherche de groupe), noms rapprochés (« Mortemines » = « Les Mortemines »)
do
  local loot = root.mods.ForeverLoot
  _G.C_LFGList = { GetAvailableActivities = function() return { 1, 2, 3 } end,
                   GetActivityInfoTable = function(id) return ({ { fullName = "Donjon d'Ombrecroc", minLevelSuggestion = 20, maxLevelSuggestion = 30 },
                     { fullName = "Mortemines", minLevelSuggestion = 17, maxLevelSuggestion = 26 },
                     { fullName = "Cavernes des lamentations", minLevelSuggestion = 15, maxLevelSuggestion = 24 } })[id] end }
  W.fire("LFG_LIST_AVAILABILITY_UPDATE")                 -- le jeu signale que la liste est prête
  local r = loot.DungeonRange("Donjon d'Ombrecroc", 14)
  check(r and r[1] == 20 and r[2] == 30 and r[3] == "jeu", "niveau d'Ombrecroc pris dans le jeu (20-30), pas la base classique (14)")
  r = loot.DungeonRange("Les Mortemines", 10)
  check(r and r[1] == 17 and r[2] == 26, "Les Mortemines = Mortemines du jeu (17-26)")
  r = loot.DungeonRange("Cavernes des Lamentations", 10)
  check(r and r[1] == 15, "majuscules sans effet (Cavernes des lamentations)")
  check(loot.DungeonRange("Donjon inconnu", 33)[3] == "ATT", "donjon inconnu du jeu : base ATT en dernier recours")
  -- pastille : plage du jeu, orange si trop haut pour toi
  local saveWhere = loot.WhereToGo
  loot.WhereToGo = function() return { { key = "i64", name = "Donjon d'Ombrecroc", kind = "dungeon", level = 20, maxLevel = 30, mapID = 1421, x = 36.6, y = 65.6,
    items = { { c = { link = "|Hitem:6320|h[Torque]|h", id = 6320 }, eval = { method = "heal", hps = 0.1, score = 3 } } }, quests = {}, nQuests = 0, score = 3 } } end
  local place
  for _, l in ipairs(root.NowLines()) do if l.place then place = l end end
  check(place and place.tags:find("20-30", 1, true) and place.tags:find("ffaa3c", 1, true), "pastille « niv. 20-30 », orange au niveau 12")
  loot.WhereToGo = saveWhere
  _G.C_LFGList = nil
end

-- quêtes à ton niveau (Questie) : regroupées par zone, trop hautes exclues, clic : donneur le plus proche
do
  local quests = { [1] = { 11, 101 }, [2] = { 12, 101 }, [3] = { 13, 102 }, [4] = { 30, 101 }, [5] = { 12, 103 } }
  local npcs = { [101] = { name = "Gryan", spawns = { [40] = { { 56.3, 47.5 } } } }, [102] = { name = "Gryan bis", spawns = { [40] = { { 52, 50 } } } },
                 [103] = { name = "Garde", spawns = { [12] = { { 40, 60 } } } } }
  _G.QuestieLoader = { _modules = {
    AvailableQuests = { __availableQuests = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true } },
    QuestieDB = { GetQuest = function(id) local q = quests[id]; return q and { name = "Quête " .. id, questLevel = q[1], requiredLevel = q[1] - 3, Starts = { NPC = { q[2] } } } end,
                  GetNPC = function(_, id) return npcs[id] end },
    ZoneDB = { GetUiMapIdByAreaId = function(_, a) return ({ [40] = 1436, [12] = 1429 })[a] end },
  } }
  root.Quests.Forget()
  check(root.Quests.Available(), "Questie présent : quêtes lisibles")
  local zs = root.Quests.Zones(2)
  check(#zs == 2 and #zs[1].quests == 3 and zs[1].lo == 11 and zs[1].hi == 13, "zones de quêtes : 3 à ton niveau dans la première, la quête niveau 30 exclue")
  local ql
  for _, l in ipairs(root.NowLines()) do if l.quests then ql = ql or l end end
  check(ql and ql.gain:find("3", 1, true) and ql.tags:find("11-13", 1, true) and ql.tip.lines[1][1]:find("Quête", 1, true),
        "À faire : « Quêtes : zone », 3 quêtes, niv. 11-13, liste au survol")
  local went
  local saveGo = root.Nav.Go
  root.Nav.Go = function(m, x, y, t) went = t end
  ql.onClick()
  check(went and went:find("Gryan", 1, true), "clic : itinéraire vers le donneur")
  root.Nav.Go = saveGo
  _G.QuestieLoader = nil
  root.Quests.Forget()
  check(not root.Quests.Available() and #root.Quests.Zones(2) == 0, "sans Questie : rien")
end

-- infobulles d'objets : une seule accroche, parties dans l'ordre, une erreur n'arrête pas les autres
do
  local seen = {}
  root.HookItemTooltip(0, function() seen[#seen + 1] = "avant"; error("panne volontaire") end)
  root.HookItemTooltip(9, function() seen[#seen + 1] = "après" end)
  local run = GameTooltip.scripts and GameTooltip.scripts.OnTooltipSetItem
  check(run ~= nil, "infobulle : accroche posée sur GameTooltip")
  if run then run(GameTooltip) end
  check(seen[1] == "avant" and seen[2] == "après", "infobulle : parties appelées dans l'ordre, une erreur n'arrête pas les suivantes")
end

-- itinéraire le plus rapide : maître de vol proche -> vol -> à pied, points de vol appris à l'ouverture d'un maître de vol
do
  local N = root.Nav
  local saveMap, saveTaxi, saveId = _G.C_Map, _G.C_TaxiMap, _G.GetTaxiMapID
  local player = { 0.10, 0.10 }
  _G.C_Map = {
    GetBestMapForUnit = function() return 1 end,
    GetPlayerMapPosition = function() return CreateVector2D(player[1], player[2]) end,
    GetWorldPosFromMapPos = function(map, v) local x, y = v:GetXY(); return 0, CreateVector2D(x * 1000, y * 1000) end,
    GetMapInfo = function(id) return { name = "Zone " .. id } end,
  }
  _G.GetPlayerFacing = function() return 0 end
  _G.GetTaxiMapID = function() return 1 end
  _G.C_TaxiMap = { GetAllTaxiNodes = function() return {
    { name = "Près de toi", position = CreateVector2D(0.12, 0.12), state = 0 },
    { name = "Près du donjon", position = CreateVector2D(0.93, 0.93), state = 1 },
    { name = "Inconnu", position = CreateVector2D(0.50, 0.95), state = 2 } } end }
  _G.Enum.FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 }
  N.Clear()
  local plan = N.Plan(1, 95, 95)
  check(plan.walk and not plan.fly, "aucun point de vol connu : à pied")
  W.fire("TAXIMAP_OPENED")
  local known = N.Taxi()
  check(known["Près de toi"] and known["Près du donjon"] and not known["Inconnu"], "points de vol appris à l'ouverture du maître de vol (sauf ceux pas encore découverts)")
  plan = N.Plan(1, 95, 95)
  check(plan.fly and plan.fly.from.name == "Près de toi" and plan.fly.to.name == "Près du donjon" and plan.fly.time < plan.walk,
        "plus rapide en vol : maître de vol proche, vol jusqu'au plus proche du but")
  check(N.Plan(1, 14, 14).fly == nil, "but tout près : à pied")
  N.Go(1, 95, 95, "Donjon d'Ombrecroc")
  check(N.target and N.target.title:find("Près de toi", 1, true) and N.route, "étape 1 : flèche vers le maître de vol")
  N.Arrived()
  check(N.route.wait and N.route.wait:find("Près du donjon", 1, true), "au maître de vol : « prends le vol vers… »")
  W.fire("PLAYER_CONTROL_GAINED")
  W.run(2)
  check(N.target and N.target.title == "Donjon d'Ombrecroc" and not N.route, "après le vol : flèche vers le donjon")
  N.Clear()
  -- autre continent : bateau de ta faction (Alliance : Menethil), puis la flèche vers le but
  local saveWP = C_Map.GetWorldPosFromMapPos
  local KALIMDOR = { [1439] = true, [1445] = true, [1413] = true, [1411] = true, [99] = true }
  C_Map.GetWorldPosFromMapPos = function(map, v) local x, y = v:GetXY(); return KALIMDOR[map] and 1 or 0, CreateVector2D(x * 1000 + map, y * 1000) end
  _G.UnitFactionGroup = function() return "Alliance" end
  local plan = N.Plan(99, 50, 50, "Cavernes des Lamentations")
  local boat
  for _, st in ipairs(plan.steps or {}) do if st.kind == "boat" then boat = st end end
  check(plan.other and boat and boat.transport.kind == "boat" and boat.from.name:find("Menethil", 1, true), "autre continent : bateau de Menethil (Alliance)")
  _G.UnitFactionGroup = function() return "Horde" end
  plan = N.Plan(99, 50, 50, "x")
  local zep
  for _, st in ipairs(plan.steps or {}) do if st.kind == "boat" then zep = st end end
  check(zep and (zep.transport.kind == "zeppelin" or zep.transport.side == "both"), "Horde : zeppelin (ou bateau neutre), jamais Menethil")
  _G.UnitFactionGroup = function() return "Alliance" end
  N.Go(99, 50, 50, "Cavernes des Lamentations")
  local guard = 0
  while N.route and N.route.steps[N.route.i].kind ~= "boat" and guard < 5 do N.Arrived(); W.fire("PLAYER_CONTROL_GAINED"); W.run(2); guard = guard + 1 end
  check(N.route and N.target.title:find(boat.to.name, 1, true), "flèche vers le quai du bateau")
  N.Arrived()
  check(N.route.wait and N.route.wait:find(boat.to.name, 1, true), "au quai : « prends le bateau pour… »")
  C_Map.GetBestMapForUnit = function() return boat.to.mapID end
  player = { boat.to.x / 100, boat.to.y / 100 }
  N.Watch()
  check(N.target and (not N.route or N.route.steps[N.route.i].kind ~= "boat"), "débarqué : la suite de l'itinéraire")
  N.Clear()
  C_Map.GetWorldPosFromMapPos = saveWP
  C_Map.GetBestMapForUnit = function() return 1 end
  player = { 0.10, 0.10 }
  -- monture : possédée (journal des montures), vitesse mesurée sur la monture
  root.db.mountSpeed = nil
  _G.C_MountJournal = { GetMountIDs = function() return { 7 } end,
                        GetMountInfoByID = function() return "Cheval", 1, "", false, true, 0, false, false, 1, false, true end }
  check(N.HasMount() and math.abs(N.Speed() - 7 * 1.6) < 0.01, "monture possédée : vitesse estimée (60 %)")
  _G.IsMounted, _G.GetUnitSpeed = function() return true end, function() return 14 end
  N.MeasureMount()
  check(root.db.mountSpeed == 14 and N.Speed() == 14, "vitesse sur monture mesurée : utilisée pour l'itinéraire")
  _G.C_MountJournal, _G.IsMounted, _G.GetUnitSpeed = nil, nil, nil
  root.db.mountSpeed = nil
  check(N.Speed() == 7, "sans monture : la course")
  SlashCmdList.FOREVERCOMPAGNON("vols")
  _G.C_Map, _G.C_TaxiMap, _G.GetTaxiMapID = saveMap, saveTaxi, saveId
  root.db.taxi = nil
end

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
  _G.HealBot_Config_Spells = { EnabledKeyCombo = { Left = "S:2050^Soins inférieurs", Button4 = "S:9^Perso", CtrlRight = "S:8^Mon sort" } }
  local setSpell = 0
  _G.HealBot_Action_SetSpell = function() setSpell = setSpell + 1 end
  _G.HEALBOT_SORTBY_GROUP = "Groupe"     -- traduit après le chargement des données (rangées sous « Group »)
  _G.HEALBOT_WORD_SOLO, _G.HEALBOT_WORD_PARTY = "Solo", "Party"
  for _, n in ipairs({ 10, 15, 20, 25, 40 }) do _G["HEALBOT_OPTIONS_RAID" .. n] = "Raid" .. n end
  _G.HEALBOT_OPTIONS_RAID40 = "Raid 40"
  local skinText = "Skin\nGroup\nAuthor~v!Monti\nGeneral~t!{OFREQ=0.07,HIDEPARTYF=\"false\",HIDERAIDF=\"true\"}\nIcons~f~1!{RCEN=\"true\",SHOWCLASS=\"false\",SHOWROLE=\"true\"}\nBarText~f~1!{HLTHONBAR=\"false\",AHEIGHT=10,HLTHTYPE=1,NUMFORMAT1=11,SHOWROLE=\"false\",HEIGHT=13}\n" ..
                   "HealBar~f~1!{HEIGHT=40,GRPCOLS=\"false\",WIDTH=110}\nHealBar~d!2~3~\nHealGroups~f~8!{FRAME=7,STATE=\"true\",NAME=\"Pets\"}\n" ..
                   "BarSort~f~1!{SUBORDER=6,RAIDORDER=3}\nBarVisibility~f~1!{ALERTIC=0.95,ALERTOC=0.9}\n" ..
                   "IconSets^1~f~1!{DEBUFFANCHOR=1,BUFFANCHOR=2,MAXDICONS=4,MAXBICONS=6}\nIconSets^1~d!2~3~"
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

  -- « Configurer HealBot » (28/11/2026) : choix du style A/B/C avec aperçu, puis les skins modernes, jamais les clics
  W.combat = true
  HB.InstallModern("A")
  check(loaded["Forever Moderne"] == nil, "en combat : rien n'est touché")
  W.combat = false
  local clicksBefore = {}
  for k, v in pairs(HealBot_Config_Spells.EnabledKeyCombo) do clicksBefore[k] = v end
  HB.Setup()
  local ch = _G.ForeverCompagnonHealBotStyle
  check(ch and ch:IsShown() and #ch.buttons == 3 and ch.buttons[2].preview, "Configurer HealBot : fenêtre de choix A, B, C avec aperçus")
  ch.buttons[2].scripts.OnClick(ch.buttons[2])
  check(root.db.healbotStyle == "B" and loaded["Forever Moderne"]:find("NUMCOLS=5", 1, true) and not ch:IsShown(), "style B : cartes côte à côte (5 colonnes)")
  SlashCmdList.FOREVERCOMPAGNON("healbot c")
  check(root.db.healbotStyle == "C" and loaded["Forever Moderne"]:find("HEIGHT=18", 1, true), "/fp healbot c : barres fines")
  ch.buttons[1].scripts.OnClick(ch.buttons[1])
  check(loaded["Forever Moderne"] and loaded["Forever Moderne Raid"] and current == "Forever Moderne", "Configurer HealBot : skins modernes installés")
  local same = setSpell == 0
  for k, v in pairs(HealBot_Config_Spells.EnabledKeyCombo) do if clicksBefore[k] ~= v then same = false end end
  for k in pairs(clicksBefore) do if HealBot_Config_Spells.EnabledKeyCombo[k] == nil then same = false end end
  check(same, "Configurer HealBot : aucun clic lu ni changé (HealBot_Action_SetSpell jamais appelé)")
  check(blizz == 0 and HealBot_Config.SkinDefault["Forever Moderne"].Solo and HealBot_Config.SkinDefault["Forever Moderne Raid"].Raid10
        and not HealBot_Config.SkinDefault.Group.Party, "skins modernes choisis pour seul, groupe et raid")
  W.fire("LEARNED_SPELL_IN_TAB"); W.run(3)
  check(setSpell == 0, "nouveau sort appris : les clics ne sont plus touchés")
  SlashCmdList.FOREVERCOMPAGNON("healbot annuler")
  check(HealBot_Config.SkinDefault.Group.Party and current == "Standard", "/fp healbot annuler : skins d'avant remis")
  Healbot_Config_Skins.Current_Skin = "Forever Moderne"
  SlashCmdList.FOREVERCOMPAGNON("healbot diag")
  local ex = HB.ExportText()
  check(ex:find("Icons~f~1!{", 1, true) and ex:find("HealGroups = {", 1, true), "/fp healbot export : texte du skin « Group » et réglages du skin actif")
  SlashCmdList.FOREVERCOMPAGNON("healbot export")
  check(root.textFrame and root.textFrame:IsShown(), "/fp healbot export : fenêtre à copier")
  -- skin « Forever Moderne » : apparence seulement, les clics ne bougent pas (demande du joueur, 28/11/2026)
  local pf = HB.PatchFrames("Skin\nGroup\nHealBar~f~1!{HEIGHT=40,WIDTH=110}\nHealBar~d!2~3~7~8~\nFrame~f~7!{BACKA=0.83}",
                            "Forever Moderne", { ["HealBar~f~7"] = { HEIGHT = 18 }, ["Frame~f~7"] = { BACKA = 0.7 } })
  check(pf:find("HealBar~d!2~3~8~", 1, true) and pf:find("HealBar~f~7!{HEIGHT=18,WIDTH=110}", 1, true) and pf:find("Frame~f~7!{BACKA=0.7}", 1, true),
        "skin moderne : cadre des familiers réglé à part (ligne de copie corrigée)")
  local before = {}
  for k, v in pairs(_G.HealBot_Config_Spells.EnabledKeyCombo) do before[k] = v end
  local nb = 0
  for _ in pairs(before) do nb = nb + 1 end
  SlashCmdList.FOREVERCOMPAGNON("healbot moderne")
  local mt = loaded["Forever Moderne"]
  check(mt and mt:find("IconSets^1~f~1!{", 1, true) and mt:find("DEBUFFANCHOR=1", 1, true) and mt:find("BUFFANCHOR=2", 1, true),
        "skin moderne importé : débuffs à gauche, buffs à droite")
  check(current == "Forever Moderne" and HealBot_Config.SkinDefault["Forever Moderne"].Party, "skin moderne : choisi pour le groupe")
  local mr = loaded["Forever Moderne Raid"]
  check(mr and mr:find("GRPCOLS=\"true\"", 1, true) and mr:find("BUFFANCHOR=2", 1, true) and HealBot_Config.SkinDefault["Forever Moderne Raid"]["Raid 40"],
        "skin moderne raid : importé (groupes en colonnes, buffs à droite) et choisi pour les raids")
  local same, na = true, 0
  for k, v in pairs(_G.HealBot_Config_Spells.EnabledKeyCombo) do na = na + 1; if before[k] ~= v then same = false end end
  check(same and na == nb, "skin moderne : clics strictement inchangés (" .. nb .. " clic(s))")
  SlashCmdList.FOREVERCOMPAGNON("healbot moderne annuler")
  check(not HealBot_Config.SkinDefault["Forever Moderne"] or not HealBot_Config.SkinDefault["Forever Moderne"].Party, "skin moderne : annuler remet les skins d'avant")
  Healbot_Config_Skins.Current_Skin = "Standard"
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
  _G.IsPlayerSpell, _G.C_Spell = saveIPS, saveSpell
  root.Game.used.spellName = nil
  for _, k in ipairs({ "HealBot_Config_Spells", "HealBot_Action_SetSpell", "HealBot_Config", "HealBot_Share_SkinLoad" }) do _G[k] = nil end
end

-- 3.6.0 : relevé des erreurs de tous les addons, journal horodaté gardé dans la sauvegarde, rapport complet
do
  local D = root.Debug
  check(D and handler ~= nil, "relevé des erreurs installé (gestionnaire chaîné)")
  local before = #D.session.items
  SlashCmdList.FOREVERCOMPAGNON("erreurs effacer")          -- part d'un relevé vide (les tests d'avant ont pu en noter)
  wipe(blizzHandled)
  GameError("Interface/AddOns/HealBot/HealBot_Action.lua:812: attempt to compare secret number value")
  GameError("Interface/AddOns/HealBot/HealBot_Action.lua:812: attempt to compare secret number value")
  check(#blizzHandled == 2, "le gestionnaire de Blizzard reçoit toujours les erreurs")
  W.combat = true
  for _ = 1, 20 do W.fire("ADDON_ACTION_BLOCKED", "Questie", "Button:SetPassThroughButtons()") end
  W.fire("PLAYER_REGEN_ENABLED")
  W.combat = false
  local items = D.session.items
  if os.getenv("DBG") then for i, e in ipairs(items) do io.stderr:write("ITEM ", i, " ", e.kind, " ", e.addon, " ", e.n, " ", tostring(e.func or e.msg), "\n") end end
  check(#items == 2 and items[1].addon == "HealBot" and items[1].n == 2, "erreur Lua : addon trouvé dans le chemin, comptée 2 fois")
  check(items[2].addon == "Questie" and items[2].n == 20 and items[2].combat == 20, "action bloquée : 20 fois, en combat")
  local text = D.ErrorsText(true)
  check(text:find("Questie/issues/8304", 1, true), "conseil du problème connu de Questie")
  check(text:find("HealBot", 1, true) and (text:find("secrète", 1, true) or text:find("secret", 1, true)), "conseil pour une valeur secrète")
  local logText = D.LogText()
  check(logText:find("×20", 1, true), "journal : la même action bloquée regroupée (×20)")
  check(root.db.debug and root.db.debug.log == D.log() and #root.db.debug.log >= 3, "journal gardé dans ForeverCompagnonDB (fichier de sauvegarde)")
  check(D.Summary(items):find("Questie 20", 1, true), "résumé : Questie 20 en tête")
  local full = D.FullReport()
  check(full:find("Addons installés", 1, true) or full:find("Installed addons", 1, true), "rapport complet : liste des addons")
  check(full:find("auto-test", 1, true) and full:find("sonde", 1, true), "rapport complet : auto-test et sonde inclus")
  SlashCmdList.FOREVERCOMPAGNON("erreurs")
  check(ForeverCompagnonTextFrame:IsShown(), "/fp erreurs : fenêtre à copier")
  SlashCmdList.FOREVERCOMPAGNON("log")
  SlashCmdList.FOREVERCOMPAGNON("rapport")
  SlashCmdList.FOREVERCOMPAGNON("erreurs muet")
  check(root.db.debugQuiet == true, "/fp erreurs muet : chat coupé")
  SlashCmdList.FOREVERCOMPAGNON("erreurs muet")
  -- session suivante : l'ancienne passe dans l'historique
  local saved = root.db.debug.current
  check(saved == D.session, "session en cours gardée dans la sauvegarde")
  SlashCmdList.FOREVERCOMPAGNON("erreurs effacer")
  check(#D.session.items == 0, "/fp erreurs effacer")
  -- 3.6.1 : message sans chemin (erreur de HealBot du 15/11/2026) : la ligne du relevé lui-même est retirée de la pile,
  -- l'erreur est attribuée au premier addon qui reste (avant : ForeverCompagnon s'accusait lui-même)
  local saveStack = _G.debugstack
  _G.debugstack = function() return table.concat({
    "[Interface/AddOns/ForeverCompagnon/Debug.lua]:171: in function <Interface/AddOns/ForeverCompagnon/Debug.lua:170>",
    "[C]: ?", "[C]: in function 'SetPredictedValues'",
    "[Interface/AddOns/HealBot/HealBot_ForeverPrediction.lua]:97: in function <...terface/AddOns/HealBot/HealBot_ForeverPrediction.lua:85>" }, "\n") end
  GameError("bad argument #3 to '?' (Current Field: [health], Usage: self:SetPredictedValues(predictedValues). Secret values are only allowed during untainted execution for this argument.)")
  _G.debugstack = saveStack
  local hb = D.session.items[#D.session.items]
  check(hb.addon == "HealBot" and not hb.stack:find("Debug.lua", 1, true), "erreur sans chemin : attribuée à HealBot, pas à ForeverCompagnon")
  check(D.Advice(hb):find("HealBot", 1, true) and D.Advice(hb) ~= D.T.oursIt, "conseil du bug connu de HealBot")
  -- 3.6.2 : protection de la prédiction des soins d'HealBot (couleur « selon la vie » + vie secrète du groupe)
  local HBm = root.HealBot
  _G.HealBot_Forever_UpdatePrediction = function(button)
    if button == "secret" then error("bad argument #3 to '?' (Current Field: [health], Usage: self:SetPredictedValues(predictedValues). Secret values are only allowed during untainted execution for this argument.)") end
    return true
  end
  check(HBm.GuardPrediction() and HBm.guard.installed, "protection HealBot installée sur sa fonction globale")
  local okG, resG = pcall(_G.HealBot_Forever_UpdatePrediction, "secret")
  check(okG and resG == false and HBm.guard.absorbed == 1, "erreur de prédiction absorbée : HealBot passe à sa barre simple")
  check(_G.HealBot_Forever_UpdatePrediction("ok") == true, "sans erreur : résultat d'HealBot inchangé")
  check(D.ErrorsText():find("Protection HealBot", 1, true) or D.ErrorsText():find("HealBot guard", 1, true), "/fp erreurs : protection HealBot et nombre d'erreurs absorbées")
  SlashCmdList.FOREVERCOMPAGNON("healbot protection")
  check(root.db.healbotGuard == false and not pcall(_G.HealBot_Forever_UpdatePrediction, "secret"), "/fp healbot protection : coupée, l'erreur repasse")
  SlashCmdList.FOREVERCOMPAGNON("healbot protection")
  check(HBm.MODERN["BarIACol~f~1"].IC == 3 and HBm.MODERN_RAID["BarIACol~f~1"].IC == 3, "skins Forever Moderne : couleur des soins entrants par classe")
  _G.HealBot_Forever_UpdatePrediction = nil
  -- le jeu affiche « grand nombre d'erreurs » : /fp erreurs s'ouvre tout seul, texte sélectionné, une fois par session
  ForeverCompagnonTextFrame:Hide()
  StaticPopup_Show("TOO_MANY_LUA_ERRORS")
  W.run(1)
  check(ForeverCompagnonTextFrame:IsShown(), "fenêtre « grand nombre d'erreurs » du jeu : /fp erreurs ouvert automatiquement")
  ForeverCompagnonTextFrame:Hide()
  StaticPopup_Show("TOO_MANY_LUA_ERRORS")
  W.run(1)
  check(not ForeverCompagnonTextFrame:IsShown(), "une seule fois par session")
  check(root.textFrame and root.textFrame.copy, "bouton « Copier pour Claude »")
  root.textFrame.copy.scripts.OnClick(root.textFrame.copy)
  W.cvars.scriptErrors = "0"
  SlashCmdList.FOREVERCOMPAGNON("erreurs afficher")
  check(W.cvars.scriptErrors == "1", "/fp erreurs afficher : erreurs Lua affichées par le jeu")
  SlashCmdList.FOREVERCOMPAGNON("erreurs afficher")
  check(W.cvars.scriptErrors == "0", "/fp erreurs afficher : de nouveau coupé")
  -- une erreur dans le gestionnaire ne doit jamais casser le jeu
  local okNil = pcall(GameError, nil)
  check(okNil, "erreur sans message : rien ne casse")
  check(before >= 0, "relevé avant le test : " .. before .. " élément(s)")
end

if os.getenv("SHOW") then W.rprint(report) end
W.rprint("\nTOUT OK (" .. LANG .. ")")
