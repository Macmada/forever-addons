local ADDON, ns = ...
local D = ns.Data

-- Modèle du soigneur : relevé des caractéristiques (« snapshot »), conversions apprises sur ton personnage,
-- sorts lus dans le jeu, mélange de sorts d'après tes lancers réels, et calcul des mesures.

local db
function ns.Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cff7fffaaForeverHeal|r " .. msg)
end

----------------------------------------------------------------------
-- Relevé des caractéristiques actuelles (valeurs données par le jeu)
----------------------------------------------------------------------
function ns.Snapshot()
  local S = {}
  S.level = UnitLevel("player")
  S.sta = select(2, UnitStat("player", 3)) or 0
  S.int = select(2, UnitStat("player", 4)) or 0
  S.spi = select(2, UnitStat("player", 5)) or 0
  S.hp = UnitHealthMax("player") or 0
  S.mana = UnitPowerMax("player", 0) or 0
  S.heal = (GetSpellBonusHealing and GetSpellBonusHealing()) or 0
  S.crit = ((GetSpellCritChance and GetSpellCritChance(2)) or 0) / 100        -- école Sacré
  local base, casting = 0, 0
  if GetManaRegen then base, casting = GetManaRegen() end
  S.regenOut, S.regenIn = base or 0, casting or 0                             -- mana par seconde, hors / pendant incantation
  local _, armor = UnitArmor("player")
  S.armor = armor or 0
  S.res = {}
  for school = 2, 6 do S.res[school] = select(2, UnitResistance("player", school)) or 0 end
  return S
end

----------------------------------------------------------------------
-- Conversions (apprises)
----------------------------------------------------------------------
function ns.Rates(S)
  local r = {}
  local learned = db and db.rates or {}
  r.hpPerSta = learned.hpPerSta or D.defaults.hpPerSta
  r.manaPerInt = learned.manaPerInt or D.defaults.manaPerInt
  r.regenPerSpi = learned.regenPerSpi or D.defaults.regenPerSpi
  local lvl = math.max(S.level or 60, 10)
  r.intPerCrit = learned.intPerCrit or (D.defaults.intPerCritAt60 * lvl / 60)       -- pour 1 %
  -- part de la régénération conservée pendant l'incantation (talent Méditation, objets « mana toutes les 5 s »)
  r.castFrac = (S.regenOut and S.regenOut > 0) and math.min(1, (S.regenIn or 0) / S.regenOut) or 0
  r.learned = learned
  return r
end

-- Apprend une conversion à partir de deux relevés (changement d'équipement) ; moyenne glissante, bornes de sécurité.
local function Learn(key, value, lo, hi)
  if not value or value ~= value or value < lo or value > hi then return end
  local old = db.rates[key]
  db.rates[key] = old and (old * 0.7 + value * 0.3) or value
end

function ns.LearnFrom(a, b)
  if not db then return end
  local dSta, dInt, dSpi = b.sta - a.sta, b.int - a.int, b.spi - a.spi
  if dSta ~= 0 and math.abs(dSta) >= 3 and b.int == a.int then Learn("hpPerSta", (b.hp - a.hp) / dSta, 5, 20) end
  if dInt ~= 0 and math.abs(dInt) >= 3 then
    Learn("manaPerInt", (b.mana - a.mana) / dInt, 8, 25)
    local dCrit = (b.crit - a.crit) * 100
    if dCrit > 0 then Learn("intPerCrit", dInt / dCrit, 5, 200) end
  end
  if dSpi ~= 0 and math.abs(dSpi) >= 3 and b.regenOut ~= a.regenOut then
    Learn("regenPerSpi", (b.regenOut - a.regenOut) / dSpi, 0.02, 0.5)
  end
end

----------------------------------------------------------------------
-- Sorts : rang le plus haut connu, montants lus dans la description, coût et temps d'incantation du jeu
----------------------------------------------------------------------
local function Known(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  return IsSpellKnown and IsSpellKnown(id) or false
end

local function Description(id)
  if C_Spell and C_Spell.GetSpellDescription then return C_Spell.GetSpellDescription(id) end
  if GetSpellDescription then return GetSpellDescription(id) end
end

-- Nombres d'une description (« Rend 924 à 1039 points de vie », « 1 245 » avec espaces de milliers)
local function Numbers(text)
  local out = {}
  text = (text or ""):gsub("(%d)[%s\194\160](%d%d%d)", "%1%2")
  for n in text:gmatch("(%d+)") do out[#out + 1] = tonumber(n) end
  return out
end

-- name, castSeconds, cost
local function SpellGame(id)
  local name, castMs, cost
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(id)
    if info then name, castMs = info.name, info.castTime end
  else
    local n, _, _, ms = GetSpellInfo(id)
    name, castMs = n, ms
  end
  local costs = (C_Spell and C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(id)) or (GetSpellPowerCost and GetSpellPowerCost(id))
  if costs then
    for _, c in ipairs(costs) do if c.type == 0 or c.name == "MANA" then cost = c.cost end end
  end
  return name, (castMs or 0) / 1000, cost or 0
end

-- Description d'un sort de soin utilisable par le modèle
function ns.SpellModel(family, rankIndex)
  local fam = D.families[family]
  local rank = fam.ranks[rankIndex]
  local id = rank[1]
  local name, cast, cost = SpellGame(id)
  local nums = Numbers(Description(id))
  local avg
  if fam.hot then avg = nums[1]                           -- « … 450 points de vie en 15 sec »
  elseif nums[1] and nums[2] and nums[2] >= nums[1] then avg = (nums[1] + nums[2]) / 2
  else avg = nums[1] end
  if not avg then return nil end
  local baseCast = rank[3] or fam.base
  local coef
  if fam.hot then coef = fam.hot / 15 else coef = math.min(baseCast, 3.5) / 3.5 end
  if fam.targets then coef = coef / 3 end
  if rank[2] < 20 then coef = coef * (1 - (20 - rank[2]) * 0.0375) end      -- pénalité des sorts de bas niveau
  local mult = (db and db.mult and db.mult[family]) or 1
  return {
    id = id, family = family, rank = rankIndex, name = name or family, base = avg, coef = coef,
    cast = fam.hot and D.defaults.gcd or math.max(cast, D.defaults.gcd), cost = cost, targets = fam.targets or 1,
    canCrit = not fam.hot, mult = mult,
  }
end

-- Rang le plus haut connu de chaque famille
function ns.KnownSpells()
  local out = {}
  for _, family in ipairs(D.ORDER) do
    local ranks = D.families[family].ranks
    for i = #ranks, 1, -1 do
      if Known(ranks[i][1]) then
        local m = ns.SpellModel(family, i)
        if m then out[family] = m end
        break
      end
    end
  end
  return out
end

-- Famille d'un numéro de sort
local familyOf = {}
for family, fam in pairs(D.families) do
  for i, r in ipairs(fam.ranks) do familyOf[r[1]] = { family = family, rank = i } end
end
ns.familyOf = familyOf

----------------------------------------------------------------------
-- Mélange de sorts : d'après tes lancers (part du temps passé à incanter chaque famille)
----------------------------------------------------------------------
function ns.Mix(spells)
  spells = spells or ns.KnownSpells()
  local usage = db and db.usage or {}
  local total, n = 0, 0
  for family, u in pairs(usage) do
    if spells[family] then total = total + u.casts * spells[family].cast; n = n + u.casts end
  end
  local mix = {}
  if n >= 15 and total > 0 then
    for family, u in pairs(usage) do
      if spells[family] and u.casts > 0 then mix[#mix + 1] = { spell = spells[family], share = u.casts * spells[family].cast / total } end
    end
    mix.observed = math.floor(n + 0.5)
  else
    -- pas encore assez de lancers observés : soin principal 70 %, Soins rapides 30 %
    local main = spells.greater or spells.heal or spells.lesser
    if main and spells.flash then
      mix[1] = { spell = main, share = 0.7 }
      mix[2] = { spell = spells.flash, share = 0.3 }
    elseif main or spells.flash then
      mix[1] = { spell = main or spells.flash, share = 1 }
    end
    mix.observed = math.floor(n + 0.5)
  end
  table.sort(mix, function(a, b) return a.share > b.share end)
  return mix
end

----------------------------------------------------------------------
-- Mesures
----------------------------------------------------------------------
function ns.Metrics(S, mix)
  mix = mix or ns.Mix()
  local M = { hp = S.hp, mana = S.mana, crit = S.crit, heal = S.heal }
  local hps, mps, castsPerSec, healPerCast = 0, 0, 0, 0
  for _, m in ipairs(mix) do
    local sp, w = m.spell, m.share
    local normal = (sp.base + sp.coef * S.heal) * sp.mult * sp.targets
    local avg = normal * (sp.canCrit and (1 + (D.defaults.critMult - 1) * S.crit) or 1)
    hps = hps + w * avg / sp.cast
    mps = mps + w * sp.cost / sp.cast
    castsPerSec = castsPerSec + w / sp.cast
    m.normal, m.avg = normal, avg
  end
  if castsPerSec > 0 then
    for _, m in ipairs(mix) do healPerCast = healPerCast + (m.share / m.spell.cast) / castsPerSec * m.avg end
  end
  M.hps, M.mps, M.perCast = hps, mps, healPerCast
  M.main = mix[1] and mix[1].spell
  M.mainNormal = mix[1] and mix[1].normal or 0
  M.mainAvg = mix[1] and mix[1].avg or 0
  local net = mps - S.regenIn
  if mps <= 0 then M.oom = nil
  elseif net <= 0 then M.oom = math.huge
  else M.oom = S.mana / net end
  M.healedBeforeOom = (M.oom and M.oom ~= math.huge) and hps * M.oom or nil
  local lvl = S.level or 60
  M.armorReduc = S.armor / (S.armor + 400 + 85 * lvl)              -- face à un ennemi de ton niveau
  M.regenOut, M.regenIn = S.regenOut, S.regenIn
  return M
end

-- Relevé modifié par des écarts de caractéristiques (objet, simulation)
function ns.Apply(S, d, rates)
  rates = rates or ns.Rates(S)
  local T = {}
  for k, v in pairs(S) do T[k] = v end
  T.res = {}
  for k, v in pairs(S.res or {}) do T.res[k] = v + ((d.res and d.res[k]) or 0) end
  local dSta, dInt, dSpi = d.sta or 0, d.int or 0, d.spi or 0
  T.sta, T.int, T.spi = S.sta + dSta, S.int + dInt, S.spi + dSpi
  T.hp = S.hp + dSta * rates.hpPerSta + (d.hp or 0)
  T.mana = S.mana + dInt * rates.manaPerInt + (d.mana or 0)
  T.heal = S.heal + (d.heal or 0)
  T.crit = S.crit + (dInt / rates.intPerCrit + (d.crit or 0)) / 100
  local spiRegen = dSpi * rates.regenPerSpi
  local mp5 = (d.mp5 or 0) / 5
  T.regenOut = S.regenOut + spiRegen + mp5
  T.regenIn = S.regenIn + spiRegen * rates.castFrac + mp5
  T.armor = S.armor + (d.armor or 0)
  return T
end

----------------------------------------------------------------------
-- Caractéristiques d'un objet (API du jeu, puis lecture de l'infobulle pour soins / mana / critique)
----------------------------------------------------------------------
local scan
local function ScanLines(setup)
  if not scan then
    scan = CreateFrame("GameTooltip", "ForeverHealScanTip", nil, "GameTooltipTemplate")
  end
  scan:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  scan:ClearLines()
  setup(scan)
  local lines = {}
  for i = 1, scan:NumLines() do
    local fs = _G["ForeverHealScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    if t then lines[#lines + 1] = t:lower() end
  end
  scan:Hide()
  return lines
end

-- Chaque ligne compte une fois par caractéristique (premier motif qui correspond)
local function FromLines(lines, st)
  for _, line in ipairs(lines) do
    for key, pats in pairs(D.tooltipPatterns) do
      for _, p in ipairs(pats) do
        local n = line:match(p)
        if n then st[key] = (st[key] or 0) + tonumber(n); break end
      end
    end
  end
end

local STATKEYS = {
  ITEM_MOD_STAMINA_SHORT = "sta", ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
  RESISTANCE0_NAME = "armor", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal", ITEM_MOD_SPELL_POWER_SHORT = "heal",
  ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
  ITEM_MOD_HEALTH_SHORT = "hp", ITEM_MOD_MANA_SHORT = "mana",
}

-- link : lien d'objet ; slot : emplacement porté (lit l'objet équipé, enchantement compris)
function ns.ItemStats(link, slot)
  local st = { res = {} }
  if slot then link = GetInventoryItemLink("player", slot) end
  if not link then return st end
  local get = (C_Item and C_Item.GetItemStats) or GetItemStats
  local raw = get and get(link) or {}
  for k, v in pairs(raw) do
    local key = STATKEYS[k]
    if key then st[key] = (st[key] or 0) + v end
    local school = k:match("^RESISTANCE(%d)_NAME$")
    if school and school ~= "0" then st.res[tonumber(school)] = (st.res[tonumber(school)] or 0) + v end
  end
  local apiHeal, apiMp5 = st.heal, st.mp5
  local lines = ScanLines(function(tt) if slot then tt:SetInventoryItem("player", slot) else tt:SetHyperlink(link) end end)
  local fromTip = { res = {} }
  FromLines(lines, fromTip)
  -- l'infobulle complète ce que l'API ne donne pas (effets « Équipé : » des versions classiques, enchantements)
  if not apiHeal and fromTip.heal then st.heal = fromTip.heal end
  if not apiMp5 and fromTip.mp5 then st.mp5 = fromTip.mp5 end
  if fromTip.spellCrit then st.crit = fromTip.spellCrit end
  return st
end

local function Diff(a, b)            -- a - b
  local d = { res = {} }
  for _, k in ipairs({ "sta", "int", "spi", "armor", "heal", "mp5", "crit", "hp", "mana" }) do d[k] = (a[k] or 0) - (b[k] or 0) end
  for s = 2, 6 do d.res[s] = ((a.res or {})[s] or 0) - ((b.res or {})[s] or 0) end
  return d
end
ns.Diff = Diff

-- Écart si l'objet remplaçait ce que tu portes ; pour les anneaux et bijoux, la meilleure des deux places
function ns.CompareItem(link)
  local equipLoc = select(4, ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(link))
  local slots = equipLoc and D.slots[equipLoc]
  if not slots then return nil end
  local new = ns.ItemStats(link)
  local S = ns.Snapshot()
  local rates = ns.Rates(S)
  local mix = ns.Mix()
  local before = ns.Metrics(S, mix)
  local best
  for _, slot in ipairs(slots) do
    local old = ns.ItemStats(nil, slot)
    if slots.two then
      local off = ns.ItemStats(nil, 17)
      for k, v in pairs(off) do if type(v) == "number" then old[k] = (old[k] or 0) + v end end
    end
    local d = Diff(new, old)
    local after = ns.Metrics(ns.Apply(S, d, rates), mix)
    local cand = { slot = slot, d = d, before = before, after = after, equipped = GetInventoryItemLink("player", slot) ~= nil }
    if not best or after.hps - before.hps > best.after.hps - best.before.hps then best = cand end
  end
  return best
end

----------------------------------------------------------------------
-- Suivi du jeu réel : lancers (mélange) et montants (talents, soins effectifs)
----------------------------------------------------------------------
function ns.OnCast(spellID)
  local f = familyOf[spellID]
  if not f or not db then return end
  local u = db.usage[f.family] or { casts = 0 }
  db.usage[f.family] = u
  -- poids dégressif : les 300 derniers lancers comptent le plus
  for _, other in pairs(db.usage) do other.casts = other.casts * 0.997 end
  u.casts = u.casts + 1
end

function ns.OnHeal(spellID, amount, overheal, crit, periodic)
  local f = familyOf[spellID]
  if not f or not db then return end
  db.effective.total = db.effective.total + (amount or 0)
  db.effective.over = db.effective.over + (overheal or 0)
  -- correction des talents : montant réel non critique / montant prévu (soins directs seulement)
  if crit or periodic then return end
  local sp = ns.SpellModel(f.family, f.rank)
  if not sp then return end
  local predicted = sp.base + sp.coef * (ns.Snapshot().heal)
  if predicted <= 0 then return end
  local ratio = amount / predicted
  if ratio >= 0.85 and ratio <= 1.6 then
    local old = db.mult[f.family]
    db.mult[f.family] = old and (old * 0.9 + ratio * 0.1) or ratio
  end
end

----------------------------------------------------------------------
-- Base, événements
----------------------------------------------------------------------
local function InitDB()
  ForeverHealDB = ForeverHealDB or {}
  db = ForeverHealDB
  ns.db = db
  db.version = db.version or 1
  db.rates = db.rates or {}
  db.usage = db.usage or {}
  db.mult = db.mult or {}
  db.effective = db.effective or { total = 0, over = 0 }
  if db.tooltip == nil then db.tooltip = true end
  if db.panel == nil then db.panel = true end
  if db.announce == nil then db.announce = true end
  db.announceWhere = db.announceWhere or "screen"
  db.minimap = db.minimap or { angle = 120, hide = false }
  if db.lang then ns.lang = db.lang end
end
ns._InitDB = InitDB

local ev = CreateFrame("Frame")
ns.eventFrame = ev
local handlers = {}
local playerGUID
local last, pending

-- Changement de caractéristiques : relevé avant/après, apprentissage et annonce (hors combat)
local function StatsChanged()
  if pending then return end
  pending = true
  C_Timer.After(0.6, function()
    pending = nil
    local now = ns.Snapshot()
    if last and not InCombatLockdown() then
      if ns.equipChanged then ns.LearnFrom(last, now) end
      if ns.Announce then ns.Announce(last, now) end
    end
    ns.equipChanged = nil
    if not InCombatLockdown() then last = now end
    if ns.RefreshPanel then ns.RefreshPanel() end
  end)
end
ns.StatsChanged = StatsChanged

handlers.PLAYER_LOGIN = function()
  playerGUID = UnitGUID("player")
  C_Timer.After(3, function() last = ns.Snapshot() end)
  if ns.OnLogin then ns.OnLogin() end
end
handlers.PLAYER_EQUIPMENT_CHANGED = function() ns.equipChanged = true; StatsChanged() end
handlers.UNIT_STATS = function(unit) if unit == "player" then StatsChanged() end end
handlers.UNIT_MAXHEALTH = handlers.UNIT_STATS
handlers.UNIT_MAXPOWER = handlers.UNIT_STATS
handlers.PLAYER_REGEN_ENABLED = function() last = ns.Snapshot() end   -- après un combat : nouvelle base, sans annonce
handlers.PLAYER_LEVEL_UP = function() C_Timer.After(1, function() last = ns.Snapshot() end) end
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID) if unit == "player" then ns.OnCast(spellID) end end
handlers.COMBAT_LOG_EVENT_UNFILTERED = function()
  if not CombatLogGetCurrentEventInfo then return end
  local _, sub, _, src, _, _, _, _, _, _, _, spellID, _, _, amount, over, _, crit = CombatLogGetCurrentEventInfo()
  if src ~= playerGUID then return end
  if sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then ns.OnHeal(spellID, amount, over, crit, sub == "SPELL_PERIODIC_HEAL") end
end

ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    InitDB()
    for e in pairs(handlers) do pcall(ev.RegisterEvent, ev, e) end
    if ns.OnLoaded then ns.OnLoaded() end
    return
  end
  local h = handlers[event]
  if h then h(...) end
end)
ns._handlers = handlers
ns._setLast = function(s) last = s end
