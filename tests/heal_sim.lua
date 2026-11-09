-- Simulation hors jeu de ForeverHeal (Lua 5.1) : prêtre fictif, sorts, objets, changements d'équipement.
-- Lancer depuis la racine du dépôt : lua5.1 tests/heal_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local unpack = unpack or table.unpack

local clock, timers = 1000.0, {}
local function noop() end
local function Obj(name)
  local o = { scripts = {}, shown = false, w = 400, h = 10, text = "", lines = {} }
  if name then _G[name] = o end
  return setmetatable(o, { __index = function(_, k)
    local m = ({
      SetScript = function(self, n, f) self.scripts[n] = f end,
      HookScript = function(self, n, f) self.scripts[n] = f end,
      RegisterEvent = function() end,
      Show = function(self) local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end,
      Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
      SetText = function(self, s) self.text = s end,
      GetText = function(self) return self.text end,
      CreateFontString = function() return Obj() end,
      CreateTexture = function() return Obj() end,
      AddLine = function(self, s) self.lines[#self.lines + 1] = s end,
      NumLines = function(self) return #self.lines end,
      ClearLines = function(self) self.lines = {} end,
    })[k]
    return m or noop
  end })
end
_G.CreateFrame = function(_, name) return Obj(name) end
_G.UIParent, _G.GameTooltip, _G.ItemRefTooltip, _G.CharacterFrame = Obj(), Obj(), Obj(), Obj()
_G.SlashCmdList = {}
_G.GetLocale = function() return LANG == "fr" and "frFR" or "enUS" end
_G.GetTime = function() return clock end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.C_Timer = { After = function(s, f) timers[#timers + 1] = { at = clock + s, f = f } end }
local function Run(dt)
  clock = clock + (dt or 2)
  local again = true
  while again do
    again = false
    for i, t in ipairs(timers) do if t.at <= clock then table.remove(timers, i); t.f(); again = true; break end end
  end
end

-- le prêtre
local P = { class = "PRIEST", level = 50, sta = 150, int = 220, spi = 180, hpPerSta = 10, base_hp = 1000, base_mana = 800,
            heal = 200, crit = 6.0, regenOut = 8, regenIn = 1.2, armor = 900, combat = false, gear = {} }
local function HP() return P.base_hp + P.sta * P.hpPerSta end
local function MANA() return P.base_mana + P.int * 15 end
_G.UnitClass = function() return P.class, P.class end
_G.UnitLevel = function() return P.level end
_G.UnitStat = function(_, i) local v = ({ [3] = P.sta, [4] = P.int, [5] = P.spi })[i] or 0; return v, v end
_G.UnitHealthMax = function() return HP() end
_G.UnitPowerMax = function() return MANA() end
_G.GetSpellBonusHealing = function() return P.heal end
_G.GetSpellCritChance = function() return P.crit end
_G.GetManaRegen = function() return P.regenOut, P.regenIn end
_G.UnitArmor = function() return P.armor, P.armor end
_G.UnitResistance = function() return 0, 0 end
_G.UnitGUID = function() return "Player-1" end
_G.InCombatLockdown = function() return P.combat end
local KNOWN = { [2060] = true, [10963] = true, [10916] = true, [10928] = true, [10960] = true }
_G.IsSpellKnown = function(id) return KNOWN[id] == true end
local SPELLS = {
  [2060] = { "Soins supérieurs", 3000, 314, "Rend de 899 à 1013 points de vie à une cible alliée." },
  [10963] = { "Soins supérieurs", 3000, 370, "Rend de 1166 à 1314 points de vie à une cible alliée." },
  [10916] = { "Soins rapides", 1500, 300, "Rend de 652 à 799 points de vie à une cible alliée." },
  [10928] = { "Rénovation", 0, 280, "Rend 700 points de vie à la cible en 15 sec." },
  [10960] = { "Prière de soins", 3000, 760, "Rend de 1 041 à 1 099 points de vie aux membres du groupe." },
}
_G.GetSpellInfo = function(id) local s = SPELLS[id]; if s then return s[1], nil, nil, s[2] end end
_G.GetSpellDescription = function(id) local s = SPELLS[id]; return s and s[4] end
_G.GetSpellPowerCost = function(id) local s = SPELLS[id]; return s and { { type = 0, cost = s[3] } } end
-- objets
local ITEMS = {
  robe = { loc = "INVTYPE_ROBE", stats = { ITEM_MOD_STAMINA_SHORT = 45, ITEM_MOD_INTELLECT_SHORT = 15, RESISTANCE0_NAME = 80 },
           tip = { "Robe de test", "Équipé : Augmente les soins prodigués par les sorts et effets de 22 au maximum.",
                   "Équipé : Rend 4 points de mana toutes les 5 sec." } },
  old = { loc = "INVTYPE_CHEST", stats = { ITEM_MOD_STAMINA_SHORT = 10, RESISTANCE0_NAME = 120 }, tip = { "Vieille tunique" } },
  ring = { loc = "INVTYPE_FINGER", stats = { ITEM_MOD_SPIRIT_SHORT = 12 }, tip = { "Anneau d'esprit" } },
  plate = { loc = "INVTYPE_CHEST", cls = 4, sub = 4, stats = { ITEM_MOD_STAMINA_SHORT = 60, ITEM_MOD_INTELLECT_SHORT = 30 }, tip = { "Cuirasse" } },
  -- capture du 05/11/2026 : robe +1 Esprit +2 armure (ici des gants) pas vue comme une amélioration
  gantsold = { loc = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 4 }, tip = { "Gants râpés" } },
  gantsmoine = { loc = "INVTYPE_HAND", stats = { ITEM_MOD_SPIRIT_SHORT = 1, RESISTANCE0_NAME = 6 }, tip = { "Gants de moine" } },
}
P.gear[5] = "item:old"
_G.GetInventoryItemLink = function(_, slot) return P.gear[slot] end
_G.GetItemInfoInstant = function(link) local it = ITEMS[link:match("item:(%w+)")]; return 1, "", "", it and it.loc, "icon", it and (it.cls or 4), it and (it.sub or 1) end
_G.GetItemInfo = function() return "x", "l", 3, 50, 45 end
P.bags = { "item:robe", "item:plate" }
_G.GetContainerNumSlots = function(bag) return bag == 0 and #P.bags or 0 end
_G.GetContainerItemLink = function(bag, slot) return bag == 0 and P.bags[slot] or nil end
P.manaCur = 4000
_G.UnitPower = function() return P.manaCur end
_G.GetSpellSubtext = function(id) return ({ [2060] = "Rang 1", [10963] = "Rang 2" })[id] end
local MACROS = {}
_G.GetMacroIndexByName = function(n) for i, m in ipairs(MACROS) do if m.name == n then return i end end return 0 end
_G.CreateMacro = function(n, _, body) MACROS[#MACROS + 1] = { name = n, body = body }; return #MACROS end
_G.EditMacro = function(i, n, _, body) MACROS[i] = { name = n, body = body } end
_G.GetItemStats = function(link) local it = ITEMS[link:match("item:(%w+)")]; local t = {}; for k, v in pairs(it and it.stats or {}) do t[k] = v end; return t end
local scanLines = {}
local function SetTipLines(tt, key)
  scanLines = {}
  for i, l in ipairs((ITEMS[key] or {}).tip or {}) do
    scanLines[i] = l
    _G["ForeverHealScanTipTextLeft" .. i] = { GetText = function() return l end }
  end
  tt.lines = scanLines
end
_G.GameTooltip.GetItem = function(self) return "x", self.link end

-- chargement
_G.date = _G.date or os.date
_G.time = _G.time or os.time
_G.UnitRace = _G.UnitRace or function() return "Humain", "Human" end
_G.UnitFactionGroup = _G.UnitFactionGroup or function() return "Alliance" end
_G.GetRealmName = _G.GetRealmName or function() return "Forever" end
_G.GetBuildInfo = _G.GetBuildInfo or function() return "1.16.0", "60000", "Nov 1 2026", 16001 end
_G.GetAddOnMetadata = function(_, f) return f == "Version" and "test" or nil end
_G.IsAddOnLoaded = function() return true end
_G.ChatFontNormal = _G.ChatFontNormal or {}
local ns = dofile("tests/compagnon_load.lua")("ForeverHeal")
-- infobulle de lecture : relie SetHyperlink / SetInventoryItem à nos objets
local realCF = _G.CreateFrame
_G.CreateFrame = function(kind, name, ...)
  local f = realCF(kind, name, ...)
  if name == "ForeverHealScanTip" then
    f.SetHyperlink = function(self, link) SetTipLines(self, link:match("item:(%w+)")) end
    f.SetInventoryItem = function(self, _, slot) local l = P.gear[slot]; SetTipLines(self, l and l:match("item:(%w+)")) end
    f.NumLines = function() return #scanLines end
  end
  return f
end
local evf = ns.eventFrame
local function Fire(e, ...) evf.scripts.OnEvent(evf, e, ...) end
local function check(c, msg) if not c then error("ÉCHEC : " .. msg, 2) end print("ok  " .. msg) end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

Fire("ADDON_LOADED", "ForeverHeal")
Fire("PLAYER_LOGIN"); Run(4)

-- 1. sorts et mesures
local spells = ns.KnownSpells()
check(spells.greater and spells.greater.base == 1240 and math.abs(spells.greater.coef - 3 / 3.5) < 1e-6, "Soins supérieurs r2 : 1240 en moyenne (description), coefficient 3/3,5")
check(spells.prayer and spells.prayer.base == 1070, "Prière de soins : « 1 041 à 1 099 » lu malgré l'espace des milliers")
check(spells.renew and spells.renew.cast == 1.5 and not spells.renew.canCrit, "Rénovation : instantané (temps global), pas de critique")
local S = ns.Snapshot()
local M = ns.Metrics(S)
check(math.abs(M.mainNormal - (1240 + 200 * 3 / 3.5)) < 0.01, "soin normal = base + coefficient × bonus aux soins")
check(M.hps > 300 and M.hps < 600, "soins par seconde plausibles (" .. math.floor(M.hps) .. ")")
check(M.oom and M.oom > 20 and M.oom < 200, "autonomie plausible (" .. math.floor(M.oom) .. " s)")

-- 2. comparaison d'objet et infobulle
GameTooltip.link = "item:robe"
GameTooltip.lines = {}
ns.OnTooltipItem(GameTooltip)
local tip = strip(table.concat(GameTooltip.lines, "\n"))
print("\n" .. tip .. "\n")
check(tip:find("+35 Endurance » +350 PV", 1, true) or tip:find("+35 Stamina » +350 HP", 1, true), "robe vs tunique : +35 Endurance » +350 PV (45 − 10)")
check(tip:find("+225 mana", 1, true), "+15 Intelligence → +225 mana")
check(tip:find("+22", 1, true) and (tip:find("par Soins supérieurs", 1, true) or tip:find("per Soins supérieurs", 1, true)), "+22 soins (lu dans l'infobulle) → par Soins supérieurs")
check(tip:find("mana / 5", 1, true), "+4 mana / 5 s lu dans l'infobulle")
check(tip:find("armure", 1, true) or tip:find("armor", 1, true), "armure : −40 → plus de dégâts physiques")
check(tip:find("soins/s", 1, true) or tip:find("HPS", 1, true), "ligne de résultat : soins par seconde et autonomie")
GameTooltip.link = "item:ring"; GameTooltip.lines = {}
ns.OnTooltipItem(GameTooltip)
check(strip(table.concat(GameTooltip.lines, "\n")):find("+12", 1, true), "anneau d'Esprit : comparé à un emplacement d'anneau vide")

-- 3. apprentissage des conversions sur un changement d'équipement (12 PV par point ici)
P.hpPerSta = 12
local before = ns.Snapshot()
ns._setLast(before)
P.sta = P.sta + 30
Fire("PLAYER_EQUIPMENT_CHANGED"); Run(1)
check(ns.db.rates.hpPerSta and math.abs(ns.db.rates.hpPerSta - 12) < 0.01, "PV par Endurance appris sur le personnage : 12")
check(ns.lastAnnounce and strip(ns.lastAnnounce[1]):find("+30", 1, true) and strip(ns.lastAnnounce[1]):find("+360", 1, true),
      "annonce : +30 Endurance → +360 PV")
check(#ns.lastAnnounce == 1 and ns.lastAnnounce[1]:find("»", 1, true) and not ns.lastAnnounce[1]:find("→", 1, true),
      "annonce : pas de ligne « Soin moyen 0 · 0 soins/s » quand les soins ne changent pas ; flèche » (la police du jeu n'a pas →)")

-- 4. en combat : pas d'annonce
ns.lastAnnounce = nil
P.combat = true
P.int = P.int + 20
Fire("UNIT_STATS", "player"); Run(1)
check(ns.lastAnnounce == nil, "en combat : pas d'annonce")
P.combat = false
Fire("PLAYER_REGEN_ENABLED")

-- 5. jeu réel : mélange de sorts et correction des talents
for _ = 1, 20 do Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 10916) end
for _ = 1, 10 do Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 10963) end
local mix = ns.Mix()
check(mix.observed >= 28 and mix.observed <= 30 and #mix == 2, "mélange observé : ~30 lancers (les anciens pèsent un peu moins), 2 sorts")
local shareG
for _, m in ipairs(mix) do if m.spell.family == "greater" then shareG = m.share end end
check(shareG and math.abs(shareG - 0.5) < 0.02, "part de Soins supérieurs ≈ 50 % du temps (10 × 3 s contre 20 × 1,5 s)")
local predicted = 1240 + 200 * 3 / 3.5
for _ = 1, 40 do
  _G.CombatLogGetCurrentEventInfo = function() return 0, "SPELL_HEAL", false, "Player-1", "", 0, 0, "x", "", 0, 0, 10963, "", 2, predicted * 1.1, 100, 0, false end
  Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
check(math.abs(ns.db.mult.greater - 1.1) < 0.02, "talents mesurés : Soins supérieurs × 1,10 (Soins spirituels)")
check(ns.db.effective.over > 0, "excédent de soins mesuré")

-- 6. panneau
CharacterFrame.scripts.OnShow()
local panelText = strip(ns.PanelText())
print(panelText .. "\n")
check(panelText:find("Soins rapides", 1, true) and (panelText:find("plus utile", 1, true) or panelText:find("Most useful", 1, true)),
      "panneau : sorts de référence et caractéristique la plus utile")

-- 7. autre classe : survie seulement
P.class = "WARRIOR"
check(strip(ns.PanelText()):find(LANG == "fr" and "prêtre" or "priest", 1, true), "autre classe : message, survie seulement")
P.class = "PRIEST"
SlashCmdList.FOREVERHEAL("chat")
check(ns.db.announceWhere == "chat", "/fheal chat")
local diagText = ns.DiagText()
if os.getenv("SHOW_DIAG") then print(diagText) end
check(diagText:find("diagnostic", 1, true) and not diagText:find("Erreur", 1, true), "diagnostic : texte complet, sans erreur (" .. #diagText .. " caractères)")
if os.getenv("SHOW_DIAG") then print(diagText) end
SlashCmdList["FOREVERHEAL"]("diag")
-- 8. conseiller de rangs : Soins supérieurs r2 avec beaucoup d'excédent -> le r1 suffit
for _ = 1, 60 do
  _G.CombatLogGetCurrentEventInfo = function() return 0, "SPELL_HEAL", false, "Player-1", "", 0, 0, "x", "", 0, 0, 10963, "", 2, 1500, 1100, 0, false end
  Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
local adv
for _, a in ipairs(ns.RankAdvice()) do if a.family == "greater" then adv = a end end
check(adv and adv.better and adv.better.rank == 1 and adv.saving == 56, "conseil : Soins supérieurs r2 avec beaucoup d'excédent -> rang 1 suffit, −56 mana")
check(strip(ns.PanelText()):find("le rang 1", 1, true) or strip(ns.PanelText()):find("rank 1", 1, true), "conseil affiché dans le panneau")
_G.IsAddOnLoaded = function(n) return n == "HealBot" end
check(strip(ns.PanelText()):find("HealBot", 1, true) and strip(ns.PanelText()):find("Soins supérieurs(Rang 1)", 1, true), "HealBot chargé : conseil « remplace par Soins supérieurs(Rang 1) » dans ses sorts")
_G.IsAddOnLoaded = function() return false end
check(not strip(ns.PanelText()):find("HealBot", 1, true), "sans HealBot : pas de ligne HealBot")
ns.MakeMacros()
check(MACROS[1] and MACROS[1].name == "SoinsSup 1" and MACROS[1].body:find("Soins supérieurs(Rang 1)", 1, true), "macro de rang créée : " .. tostring(MACROS[1] and MACROS[1].body))
ns.MakeMacros()
check(#MACROS == 1, "second clic : macro mise à jour, pas de doublon")
-- 9. objets des sacs : la robe (tissu) oui, la cuirasse (plaques) non
local ups = ns.BagUpgrades()
check(#ups == 1 and ups[1].link == "item:robe", "meilleurs objets des sacs : robe proposée, plaques ignorées")
check(strip(ns.UpgradesText()):find("item:robe", 1, true), "liste des objets des sacs affichée")
P.gear[10] = "item:gantsold"
table.insert(P.bags, "item:gantsmoine")
local found
for _, u in ipairs(ns.BagUpgrades()) do if u.link == "item:gantsmoine" then found = u end end
check(found, "sacs : +1 Esprit +2 armure compte comme une amélioration (régénération hors combat, armure)")
check(strip(ns.UpgradesText()):find(LANG == "fr" and "mana/s hors combat" or "mana/s out of combat", 1, true), "sacs : gain de mana hors combat affiché")
check(ForeverHealAPI.Evaluate("item:gantsmoine").score > 0.1, "API : même score pour ForeverLoot (alerte de butin)")
table.remove(P.bags)
P.gear[10] = nil
-- 10. alerte de mana en combat
P.combat = true
Fire("PLAYER_REGEN_DISABLED")
for i = 0, 10 do
  clock = clock + 1
  P.manaCur = 1500 - i * 100
  Fire("UNIT_POWER_FREQUENT", "player", "MANA")
end
check(ns.ManaTimeLeft() and ns.ManaTimeLeft() < 10, "alerte de mana : à sec dans ~" .. math.floor(ns.ManaTimeLeft() or -1) .. " s")
check(_G.ForeverHealManaAlert and _G.ForeverHealManaAlert.shown, "alerte affichée à l'écran en combat")
P.combat = false
Fire("PLAYER_REGEN_ENABLED")
check(not _G.ForeverHealManaAlert.shown, "alerte masquée après le combat")
-- 10b. client de Forever : mana « secrète » en combat (05/11/2026 : 36 erreurs « arithmetic on a secret number value »)
-- une vraie « valeur secrète » fait échouer tout calcul : imitée par une table sans opérations
local SECRET = setmetatable({}, { __tostring = function() return "<secret number>" end })
local snapBefore = ns.Snapshot()
P.combat = true
P.manaCur = SECRET
local okSecret, errSecret = pcall(function()
  for _ = 1, 5 do Fire("UNIT_POWER_FREQUENT", "player", "MANA") end
  ns.UpdateManaAlert()
end)
check(okSecret, "mana secrète en combat : aucune erreur (" .. tostring(errSecret) .. ")")
check(ns.manaSecret and not (_G.ForeverHealManaAlert and _G.ForeverHealManaAlert.shown), "alerte de mana en veille, rien d'affiché")
local okSnap, snapIn = pcall(ns.Snapshot)
check(okSnap and snapIn.mana == snapBefore.mana, "relevé en combat : le dernier relevé hors combat est réutilisé")
P.combat = false
P.manaCur = 4000
Fire("PLAYER_REGEN_ENABLED")

-- 11. cache des infobulles
local before = ns.tooltipStats.computed
GameTooltip.link = "item:robe"; GameTooltip.lines = {}; ns.OnTooltipItem(GameTooltip)
GameTooltip.lines = {}; ns.OnTooltipItem(GameTooltip)
check(ns.tooltipStats.computed == before + 1 and ns.tooltipStats.cached >= 1, "infobulle : calculée une fois, puis reprise du cache")
ns.lastDiag = nil
local dbtn = ns.panel and ns.panel.diagBtn
check(dbtn and dbtn.scripts.OnClick, "bouton « Diag » présent dans la fenêtre")
dbtn.scripts.OnClick(dbtn)
check(ns.lastDiag and ns.lastDiag:find("diagnostic", 1, true), "clic sur « Diag » : diagnostic ouvert sans commande écrite")
-- 11b. client de Forever : pas de CombatLogGetCurrentEventInfo, et C_CombatLog.GetCurrentEventInfo réservé à Blizzard
-- (l'appeler bloque l'addon) : il ne doit jamais être appelé
local blockedCalls = 0
local saveCL = _G.CombatLogGetCurrentEventInfo
_G.CombatLogGetCurrentEventInfo = nil
_G.C_CombatLog = { GetCurrentEventInfo = function() blockedCalls = blockedCalls + 1 end }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
check(blockedCalls == 0, "client de Forever : C_CombatLog.GetCurrentEventInfo (protégé) jamais appelé")
_G.C_CombatLog, _G.CombatLogGetCurrentEventInfo = nil, saveCL

-- 11c. panneau : onglets « Mon prêtre » / « Mes sacs » (le bouton « Retour au panneau » restait sans effet, 05/11/2026)
local pnl = ns.panel
pnl:Show()
check(rawget(pnl, "tabBags") == nil and rawget(pnl, "mode") == nil, "panneau : plus d'onglet « Mes sacs » (une seule vue)")
local realRaw, realData = ns.PanelRaw, ns.PanelData
ns.PanelRaw = function() error("test de panne") end
ns.PanelData = function() error("test de panne") end
ns.RefreshPanel()
check(ns.lastPanelError and ns.lastPanelError:find("test de panne", 1, true), "calcul en échec : erreur gardée et affichée dans le panneau")
check(ns.DiagText():find("Calcul du panneau : ERREUR", 1, true), "diagnostic : le calcul du panneau en échec est signalé")
ns.PanelRaw, ns.PanelData = realRaw, realData
ns.RefreshPanel()
-- panneau visuel : tuiles, sorts, gains triés (le plus utile d'abord), ligne de caractéristiques
local pd = ns.PanelData()
check(#pd.tiles == 4 and #pd.spells > 0 and #pd.gains == 5 and pd.gains[1].healed >= pd.gains[#pd.gains].healed and pd.footer,
      "panneau visuel : 4 tuiles, sorts, gains triés du plus utile au moins utile")
check(rawget(pnl, "macroBtn") == nil, "bouton Macros retiré (conseils de rangs impossibles sur Forever)")
check(ns.DiagText():find("Calcul du panneau : ok", 1, true), "diagnostic : calcul du panneau ok")

-- 12. API pour les autres addons : écart de caractéristiques seul (enchantement)
local e16 = ForeverHealAPI.EvaluateStats({ heal = 16 })
local eSta = ForeverHealAPI.EvaluateStats({ sta = 10 })
check(ForeverHealAPI.version >= 2 and e16 and e16.hps > 0 and eSta and eSta.hp > 0 and eSta.hps == 0,
      string.format("API EvaluateStats : +16 soins -> %+.1f soins/s ; +10 Endurance -> %+d PV", e16.hps, eSta.hp))
print("\nTOUT OK (" .. LANG .. ")")
