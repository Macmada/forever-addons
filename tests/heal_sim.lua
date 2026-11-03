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
local KNOWN = { [10963] = true, [10916] = true, [10928] = true, [10960] = true }
_G.IsSpellKnown = function(id) return KNOWN[id] == true end
local SPELLS = {
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
}
P.gear[5] = "item:old"
_G.GetInventoryItemLink = function(_, slot) return P.gear[slot] end
_G.GetItemInfoInstant = function(link) local it = ITEMS[link:match("item:(%w+)")]; return 1, "", "", it and it.loc end
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
local ns = {}
for _, f in ipairs({ "Locale", "Data", "Core", "UI" }) do assert(loadfile("ForeverHeal/" .. f .. ".lua"))("ForeverHeal", ns) end
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
check(tip:find("+35 Endurance → +350 PV", 1, true) or tip:find("+35 Stamina → +350 HP", 1, true), "robe vs tunique : +35 Endurance → +350 PV (45 − 10)")
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
print("\nTOUT OK (" .. LANG .. ")")
