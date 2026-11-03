local ADDON, ns = ...
local L = ns.L

-- Collecte des moments forts, par personnage (ForeverGazetteDB, SavedVariablesPerCharacter).
-- Une « journée » = une date locale (AAAA-MM-JJ). Les événements sont stockés bruts ; les textes sont
-- générés à l'affichage (Gazette.lua), si bien qu'un changement de ton s'applique aussi aux anciennes éditions.

local db
local playerGUID
local bband = (bit and bit.band) or function(a, b)       -- repli sans bibliothèque bit (non utilisé en jeu)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + p end
    a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
  end
  return r
end

local SCORE = {
  level = 50, levelmax = 100, boss = 70, rare = 40, dungeon = 35, zone = 15,
  loot_legendary = 100, loot_epic = 60, loot_rare = 12, death = 25, pvp = 15,
  duel_win = 20, duel_loss = 10, rep = 30, skill = 25, recipe = 5, money = 30,
  achievement = 25, quest = 3,
}
ns.SCORE = SCORE
local SHOT_MIN, SHOT_MIN_ALL = 60, 35     -- score à partir duquel une photo est prise
local SHOTS_PER_DAY = 6
local MONEY_STEPS = { 10, 100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000, 250000, 1000000 }  -- en pièces d'or
local SKILL_STEPS = { [75] = true, [150] = true, [225] = true, [300] = true, [375] = true, [450] = true, [525] = true }
local AFFIL_GROUP = 0x7        -- COMBATLOG_OBJECT_AFFILIATION_MINE | PARTY | RAID

----------------------------------------------------------------------
-- Outils
----------------------------------------------------------------------
local function Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cffd4af37ForeverGazette|r " .. msg)
end
ns.Print = Print

function ns.Trim(s) return ((s or ""):match("^%s*(.-)%s*$")) end

function ns.Today() return date("%Y-%m-%d") end

-- Transforme une chaîne de format du jeu (« Your skill in %s has increased to %d. », « %1$s has defeated %2$s »)
-- en motif Lua ; renvoie aussi l'ordre des captures (pour les formats positionnels).
function ns.FormatToPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  local order, n = {}, 0
  local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  -- « $ » vient d'être échappé : « %1$s » est devenu « %1%$s »
  pat = pat:gsub("%%(%d)%%%$([sd])", function(i, t)
    order[#order + 1] = tonumber(i)
    return t == "d" and "\1d" or "\1s"
  end)
  pat = pat:gsub("%%([sd])", function(t)
    n = n + 1
    order[#order + 1] = n
    return t == "d" and "\1d" or "\1s"
  end)
  pat = pat:gsub("\1s", "(.+)"):gsub("\1d", "(%%d+)")
  return "^" .. pat .. "$", order
end

-- Applique un motif de ns.FormatToPattern et renvoie les captures dans l'ordre des arguments du format.
function ns.MatchFormat(msg, pat, order)
  if not pat or not msg then return nil end
  local caps = { msg:match(pat) }
  if #caps == 0 then return nil end
  local out = {}
  for i, argIndex in ipairs(order) do out[argIndex] = caps[i] end
  return out
end

local QUALITY_BY_COLOR = {
  ff9d9d9d = 0, ffffffff = 1, ff1eff00 = 2, ff0070dd = 3, ffa335ee = 4, ffff8000 = 5, ffe6cc80 = 6, ff00ccff = 7,
}

-- Qualité d'un lien d'objet : couleur classique (|cffa335ee) ou nouveau format (|cnIQ4:), sinon GetItemInfo.
function ns.LinkQuality(link)
  if not link then return nil end
  local q = link:match("|cnIQ(%d+):")
  if q then return tonumber(q) end
  local color = link:match("^|c(%x%x%x%x%x%x%x%x)")
  if color and QUALITY_BY_COLOR[color:lower()] then return QUALITY_BY_COLOR[color:lower()] end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getInfo then
    local _, _, quality = getInfo(link)
    return quality
  end
end

function ns.MaxLevel()
  if GetMaxPlayerLevel then
    local ok, v = pcall(GetMaxPlayerLevel)
    if ok and v and v > 0 then return v end
  end
  local iface = select(4, GetBuildInfo())
  if iface < 20000 then return 60 elseif iface < 30000 then return 70 end
  return 80
end

local function Group(flags) return flags and bband(flags, AFFIL_GROUP) ~= 0 end

----------------------------------------------------------------------
-- Base de données
----------------------------------------------------------------------
local function Day(key)
  key = key or ns.Today()
  local d = db.days[key]
  if not d then
    d = { events = {}, stats = { play = 0, xp = 0, quests = 0, kills = 0, deaths = 0, earned = 0, spent = 0,
                                 zones = {}, companions = {}, level = UnitLevel("player") } }
    db.days[key] = d
  end
  return d
end
ns.Day = Day

local function InitDB()
  local fresh = ForeverGazetteDB == nil
  ForeverGazetteDB = ForeverGazetteDB or {}
  db = ForeverGazetteDB
  ns.db = db
  db.version = db.version or 1
  db.tone = db.tone or "serious"
  if db.shots == nil then db.shots = true end
  if db.shotsAll == nil then db.shotsAll = false end
  if db.toast == nil then db.toast = true end
  if db.shotsNoUI == nil then db.shotsNoUI = true end
  db.keepDays = db.keepDays or 365
  db.minimap = db.minimap or { angle = 215, hide = false }
  db.days = db.days or {}
  db.seen = db.seen or {}
  local s = db.seen
  s.zones = s.zones or {}
  s.instances = s.instances or {}
  s.rep = s.rep or {}
  s.skills = s.skills or {}
  if db.lang then ns.lang = db.lang end
  -- ménage des vieilles éditions
  local limit = date("%Y-%m-%d", time() - db.keepDays * 86400)
  for k in pairs(db.days) do
    if k < limit then db.days[k] = nil end
  end
  return fresh
end

----------------------------------------------------------------------
-- Enregistrement d'un moment
----------------------------------------------------------------------
local recent = {}      -- anti-doublon : clé -> GetTime()
local lastShot = 0

local function ShotName()
  local fmt = (GetCVar and GetCVar("screenshotFormat")) or "jpeg"
  local ext = (fmt == "png" and "png") or (fmt == "tga" and "tga") or "jpg"
  return date("WoWScrnShot_%m%d%y_%H%M%S") .. "." .. ext
end

local function MaybeShot(ev, d)
  if not db.shots or not Screenshot then return end
  if ev.s < (db.shotsAll and SHOT_MIN_ALL or SHOT_MIN) then return end
  d.shots = d.shots or 0
  if d.shots >= SHOTS_PER_DAY or GetTime() - lastShot < 10 then return end
  d.shots = d.shots + 1
  lastShot = GetTime()
  C_Timer.After(1.2, function()          -- laisse l'animation (niveau, butin) apparaître à l'écran
    -- Sans interface (comme Alt+Z) : seulement hors combat, le jeu bloque sinon les cadres protégés.
    local hide = db.shotsNoUI and UIParent and UIParent:IsShown() and not InCombatLockdown()
    if hide then
      UIParent:Hide()
      ns.uiHiddenForShot = true
      C_Timer.After(2, ns.RestoreUI)        -- filet de sécurité si le jeu ne confirme pas la capture
    end
    C_Timer.After(hide and 0.1 or 0, function()   -- une image sans interface est d'abord affichée
      ev.shot = ShotName()
      ns.diag.shots = ns.diag.shots + 1
      Screenshot()
      if not hide then Print(L.shot, ev.shot) else ns.pendingShotName = ev.shot end
    end)
  end)
end

function ns.RestoreUI()
  if not ns.uiHiddenForShot then return end
  ns.uiHiddenForShot = nil
  if UIParent and not UIParent:IsShown() then UIParent:Show() end
  if ns.pendingShotName then Print(L.shot, ns.pendingShotName); ns.pendingShotName = nil end
end

-- kind : type (voir SCORE) ; v : variables de l'article ; key : anti-doublon ; bonus : ajouté au score.
function ns.Record(kind, v, key, bonus)
  if not db then return end
  key = kind .. ":" .. tostring(key or "")
  local now = GetTime()
  if recent[key] and now - recent[key] < 30 then return end
  recent[key] = now
  local d = Day()
  local ev = { t = time(), k = kind, v = v or {}, s = (SCORE[kind] or 5) + (bonus or 0) }
  ev.v.zone = ev.v.zone or GetRealZoneText()
  d.events[#d.events + 1] = ev
  MaybeShot(ev, d)
  if db.toast and ev.s >= SCORE.zone and ns.Headline then
    Print(L.noted, ns.Headline(ev, d))
  end
  if ns.OnRecord then ns.OnRecord() end
  return ev
end

----------------------------------------------------------------------
-- Suivi : temps de jeu, expérience, or
----------------------------------------------------------------------
local lastTick, lastXP, lastXPMax, lastMoney

local function Tick()
  local now = GetTime()
  if lastTick then
    local d = Day()
    d.stats.play = d.stats.play + math.min(now - lastTick, 120)
    d.stats.level = UnitLevel("player")
  end
  lastTick = now
end

local function OnXP()
  local cur, max = UnitXP("player"), UnitXPMax("player")
  if lastXP then
    local delta = cur - lastXP
    if delta < 0 then delta = (lastXPMax - lastXP) + cur end      -- passage de niveau
    if delta > 0 then Day().stats.xp = Day().stats.xp + delta end
  end
  lastXP, lastXPMax = cur, max
end

local function MoneyStep(copper)
  local gold, step = copper / 10000, 0
  for _, g in ipairs(MONEY_STEPS) do
    if gold >= g then step = g end
  end
  return step
end

local function OnMoney()
  local cur = GetMoney()
  if lastMoney then
    local delta = cur - lastMoney
    local st = Day().stats
    if delta > 0 then st.earned = st.earned + delta elseif delta < 0 then st.spent = st.spent - delta end
  end
  lastMoney = cur
  local step = MoneyStep(cur)
  if step > (db.seen.money or 0) then
    if db.seen.money then ns.Record("money", { gold = step * 10000 }, step) end
    db.seen.money = step
  end
end

----------------------------------------------------------------------
-- Zones et donjons
----------------------------------------------------------------------
local function OnZone(silent)
  local zone = GetRealZoneText()
  if not zone or zone == "" then return end
  Day().stats.zones[zone] = true
  local inInstance, itype = IsInInstance()
  if inInstance and (itype == "party" or itype == "raid" or itype == "scenario") then
    if not db.seen.instances[zone] then
      db.seen.instances[zone] = true
      if not silent then ns.Record("dungeon", { zone = zone }, zone, itype == "raid" and 10 or 0) end
    end
  elseif not db.seen.zones[zone] then
    db.seen.zones[zone] = true
    if not silent and not inInstance then ns.Record("zone", { zone = zone }, zone) end
  end
end

----------------------------------------------------------------------
-- Combat : ennemis notables, coupable d'une mort, victoires JcJ
----------------------------------------------------------------------
local unitInfo, engaged, infoCount = {}, {}, 0
local lastHit

local function NoteUnit(unit)
  if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
  local guid = UnitGUID(unit)
  if not guid or unitInfo[guid] then return end
  if infoCount > 400 then wipe(unitInfo); infoCount = 0 end
  infoCount = infoCount + 1
  unitInfo[guid] = { c = UnitClassification(unit), lvl = UnitLevel(unit), name = UnitName(unit),
                     boss = unit:find("^boss") ~= nil }
end
ns.NoteUnit = NoteUnit

local function Notable(info)
  if not info then return nil end
  local inInstance = IsInInstance()
  if info.boss or info.c == "worldboss" or (inInstance and info.lvl == -1 and info.c == "elite") then return "boss" end
  if info.c == "rareelite" or info.c == "rare" then return "rare" end
end

local ENV_KEYS = { Falling = "@fall", Drowning = "@drown", Fatigue = "@fatigue", Fire = "@fire", Lava = "@lava", Slime = "@slime",
                   FALLING = "@fall", DROWNING = "@drown", FATIGUE = "@fatigue", FIRE = "@fire", LAVA = "@lava", SLIME = "@slime" }

local function OnCombatLog(...)
  local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, _, _, p12 = ...
  if CombatLogGetCurrentEventInfo then
    _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName, _, _, p12 = CombatLogGetCurrentEventInfo()
  end
  if not sub then return end
  if dstGUID == playerGUID then
    if sub == "ENVIRONMENTAL_DAMAGE" then
      lastHit = { name = ENV_KEYS[p12] or "@unknown", t = GetTime() }
    elseif sub:find("_DAMAGE$") and srcName and srcGUID ~= playerGUID then
      lastHit = { name = srcName, t = GetTime() }
    end
    return
  end
  if sub:find("_DAMAGE$") and Group(srcFlags) and dstGUID and not dstGUID:find("^Player") then
    if not engaged[dstGUID] then
      local n = 0
      for _ in pairs(engaged) do n = n + 1 end
      if n > 300 then wipe(engaged) end
    end
    engaged[dstGUID] = GetTime()
  elseif sub == "PARTY_KILL" and Group(srcFlags) then
    Day().stats.kills = Day().stats.kills + 1
    if dstGUID and dstGUID:find("^Player") then
      ns.Record("pvp", { target = dstName }, dstGUID)
    end
  elseif sub == "UNIT_DIED" and dstGUID and engaged[dstGUID] then
    engaged[dstGUID] = nil
    local info = unitInfo[dstGUID]
    local kind = Notable(info)
    if kind == "boss" then ns.diag.bossLog = ns.diag.bossLog + 1 elseif kind == "rare" then ns.diag.rareLog = ns.diag.rareLog + 1 end
    if kind then
      local raid = select(2, IsInInstance()) == "raid"
      ns.Record(kind, { target = info.name or dstName }, info.name or dstName,
                (kind == "boss" and raid and 20) or (info.c == "rareelite" and 5) or 0)
    end
  end
end

local function OnDead()
  local d = Day()
  d.stats.deaths = d.stats.deaths + 1
  local killer = (lastHit and GetTime() - lastHit.t < 10) and lastHit.name or "@unknown"
  local first = d.stats.deaths == 1
  ns.Record("death", { killer = killer }, d.stats.deaths, first and 0 or -10)
end

----------------------------------------------------------------------
-- Messages : butin, métiers, recettes, duels
----------------------------------------------------------------------
local patterns = {}

local function BuildPatterns()
  local function add(list, name)
    local fmt = _G[name]
    local pat, order = ns.FormatToPattern(fmt)
    if pat then list[#list + 1] = { pat, order } end
  end
  patterns.loot = {}
  for _, n in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
                       "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_BONUS_ROLL_SELF" }) do
    add(patterns.loot, n)
  end
  patterns.skill, patterns.recipe, patterns.duelKO, patterns.duelFled = {}, {}, {}, {}
  add(patterns.skill, "SKILL_RANK_UP")
  add(patterns.recipe, "ERR_LEARN_RECIPE_S")
  add(patterns.duelKO, "DUEL_WINNER_KNOCKOUT")
  add(patterns.duelFled, "DUEL_WINNER_RETREAT")
end

local function First(list, msg)
  for _, p in ipairs(list or {}) do
    local caps = ns.MatchFormat(msg, p[1], p[2])
    if caps then return caps end
  end
end

local function OnLoot(msg)
  if not First(patterns.loot, msg) then return end
  local link = msg:match("(|c[^|]*|Hitem:.-|h.-|h|r)")
  if not link then return end
  local q = ns.LinkQuality(link)
  if not q or q < 3 then return end
  local kind = (q == 5 or q == 6) and "loot_legendary" or (q == 4 and "loot_epic") or "loot_rare"
  ns.Record(kind, { item = link }, link)
end

local function OnSkill(msg)
  local c = First(patterns.skill, msg)
  if not c then return end
  local skill, rank = c[1], tonumber(c[2])
  if not skill or not rank then return end
  db.seen.skills[skill] = rank
  if SKILL_STEPS[rank] then ns.Record("skill", { skill = skill, rank = rank }, skill .. rank, rank >= 300 and 10 or 0) end
end

local function OnSystem(msg)
  local c = First(patterns.recipe, msg)
  if c then return ns.Record("recipe", { recipe = c[1] }, c[1]) end
  local me = UnitName("player")
  c = First(patterns.duelKO, msg) or First(patterns.duelFled, msg)
  if c then
    local winner, loser = c[1], c[2]
    if winner == me then ns.Record("duel_win", { target = loser }, loser)
    elseif loser == me then ns.Record("duel_loss", { target = winner }, winner) end
  end
end

----------------------------------------------------------------------
-- Réputation, groupe, quêtes, niveaux, hauts faits
----------------------------------------------------------------------
local function StandingLabel(id)
  local female = UnitSex and UnitSex("player") == 3
  return (female and _G["FACTION_STANDING_LABEL" .. id .. "_FEMALE"]) or _G["FACTION_STANDING_LABEL" .. id] or tostring(id)
end

local function ScanReputation()
  local list = {}
  if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
    for i = 1, C_Reputation.GetNumFactions() do
      local f = C_Reputation.GetFactionDataByIndex(i)
      if f and not f.isHeader and f.name and f.reaction then list[f.name] = f.reaction end
    end
  elseif GetNumFactions and GetFactionInfo then
    for i = 1, GetNumFactions() do
      local name, _, standing, _, _, _, _, _, isHeader, _, hasRep = GetFactionInfo(i)
      if name and standing and (not isHeader or hasRep) then list[name] = standing end
    end
  end
  local initial = next(db.seen.rep) == nil
  for name, standing in pairs(list) do
    local before = db.seen.rep[name]
    if not initial and before and standing > before and standing >= 5 then
      ns.Record("rep", { faction = name, standing = StandingLabel(standing) }, name .. standing,
                (standing >= 8 and 40) or (standing == 7 and 15) or 0)
    end
    db.seen.rep[name] = math.max(before or 0, standing)
  end
end

local repPending
local function QueueReputation()
  if repPending then return end
  repPending = true
  C_Timer.After(2, function() repPending = nil; ScanReputation() end)
end

local function ScanGroup()
  local n = (GetNumGroupMembers and GetNumGroupMembers()) or ((GetNumRaidMembers and GetNumRaidMembers()) or 0)
  if n == 0 and GetNumPartyMembers then n = GetNumPartyMembers() end
  if n == 0 then return end
  local prefix = (IsInRaid and IsInRaid()) and "raid" or "party"
  local me = UnitName("player")
  local comp = Day().stats.companions
  local count = (prefix == "raid") and n or math.min(n, 4)
  for i = 1, count do
    local unit = prefix .. i
    if UnitExists(unit) and UnitIsPlayer(unit) then
      local name = UnitName(unit)
      if name and name ~= me and name ~= UNKNOWNOBJECT then
        local found = false
        for _, c in ipairs(comp) do if c == name then found = true break end end
        if not found and #comp < 40 then comp[#comp + 1] = name end
      end
    end
  end
end

local lastQuestTitle
local function QuestTitle(id)
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local t = C_QuestLog.GetTitleForQuestID(id)
    if t and t ~= "" then return t end
  end
  if C_QuestLog and C_QuestLog.GetQuestInfo then
    local t = C_QuestLog.GetQuestInfo(id)
    if t and t ~= "" then return t end
  end
  return lastQuestTitle
end

local function OnLevel(level)
  level = tonumber(level) or UnitLevel("player")
  Day().stats.level = level
  if level >= ns.MaxLevel() then
    ns.Record("levelmax", { level = level }, level)
  else
    ns.Record("level", { level = level }, level, (level % 10 == 0) and 30 or 0)
  end
end

----------------------------------------------------------------------
-- Événements
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev
ns.registered = {}
ns.diag = { encounterEnd = 0, bossLog = 0, rareLog = 0, deaths = 0, shots = 0 }
local function Safe(e) ns.registered[e] = pcall(ev.RegisterEvent, ev, e) end

local handlers = {}
handlers.PLAYER_LOGIN = function()
  playerGUID = UnitGUID("player")
  BuildPatterns()
  lastXP, lastXPMax, lastMoney = UnitXP("player"), UnitXPMax("player"), GetMoney()
  if db.seen.money == nil then db.seen.money = MoneyStep(lastMoney) end
  Tick()
  C_Timer.NewTicker(30, Tick)
  C_Timer.After(5, function() ScanReputation(); ScanGroup() end)
  if ns.OnLogin then ns.OnLogin() end
end
handlers.PLAYER_ENTERING_WORLD = function() OnZone(ns.freshInstall); ns.freshInstall = nil end
handlers.ZONE_CHANGED_NEW_AREA = function() OnZone() end
handlers.PLAYER_LEVEL_UP = function(level) OnLevel(level) end
handlers.PLAYER_XP_UPDATE = OnXP
handlers.PLAYER_MONEY = OnMoney
handlers.PLAYER_DEAD = OnDead
handlers.COMBAT_LOG_EVENT_UNFILTERED = OnCombatLog
handlers.PLAYER_TARGET_CHANGED = function() NoteUnit("target") end
handlers.UPDATE_MOUSEOVER_UNIT = function() NoteUnit("mouseover") end
handlers.NAME_PLATE_UNIT_ADDED = function(unit) NoteUnit(unit) end
handlers.INSTANCE_ENCOUNTER_ENGAGE_UNIT = function() for i = 1, 5 do NoteUnit("boss" .. i) end end
handlers.ENCOUNTER_END = function(_, name, _, _, success)
  ns.diag.encounterEnd = ns.diag.encounterEnd + 1
  ns.diag.lastEncounter = tostring(name) .. " (réussite : " .. tostring(success) .. ")"
  if success == 1 and name then
    local raid = select(2, IsInInstance()) == "raid"
    ns.Record("boss", { target = name }, name, raid and 20 or 0)
  end
end
handlers.CHAT_MSG_LOOT = OnLoot
handlers.CHAT_MSG_SKILL = OnSkill
handlers.CHAT_MSG_SYSTEM = OnSystem
handlers.UPDATE_FACTION = QueueReputation
handlers.GROUP_ROSTER_UPDATE = ScanGroup
handlers.PARTY_MEMBERS_CHANGED = ScanGroup
handlers.RAID_ROSTER_UPDATE = ScanGroup
handlers.QUEST_COMPLETE = function() if GetTitleText then lastQuestTitle = GetTitleText() end end
handlers.QUEST_TURNED_IN = function(id)
  local d = Day()
  d.stats.quests = d.stats.quests + 1
  local title = QuestTitle(id)
  if title then ns.Record("quest", { target = title }, id or title) end
end
handlers.ACHIEVEMENT_EARNED = function(id)
  if not GetAchievementInfo then return end
  local _, name, points = GetAchievementInfo(id)
  if name then ns.Record("achievement", { ach = name }, id, math.min(tonumber(points) or 0, 50)) end
end
handlers.SCREENSHOT_SUCCEEDED = function() C_Timer.After(0.05, ns.RestoreUI) end
handlers.SCREENSHOT_FAILED = function() ns.RestoreUI(); Print("Screenshot failed.") end
handlers.PLAYER_REGEN_DISABLED = function() ns.RestoreUI() end   -- combat qui commence : interface rétablie tout de suite
handlers.PLAYER_LOGOUT = function() if ns.WriteExports then ns.WriteExports() end end

ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    ns.freshInstall = InitDB()
    for e in pairs(handlers) do Safe(e) end
    if ns.OnLoaded then ns.OnLoaded() end
    return
  end
  local h = handlers[event]
  if h then h(...) end
end)

-- Pour les tests hors jeu
ns._handlers = handlers
ns._InitDB = InitDB
