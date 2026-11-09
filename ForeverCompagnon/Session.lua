local _, root = ...
local L = root.L

-- Suivi de session : XP gagnée (et rythme par heure), or gagné et dépensé, quêtes rendues, donjons faits. Une session
-- continue après un /reload ou une courte déconnexion (moins de 20 min) ; sinon la précédente est gardée et résumée à la
-- connexion suivante. « Prochain niveau dans ~35 min » : d'après ton rythme réel (au moins 5 min de jeu et de l'XP).

local S = {}
root.Session = S
local GAP = 20 * 60          -- au-delà, nouvelle session
local MIN_TIME = 5 * 60      -- rythme fiable à partir de 5 min

local function Plain(v)
  if v == nil then return nil end
  if root.Game and root.Game.Plain then return root.Game.Plain(v) end
  return v
end
local function Now() return (_G.GetServerTime and _G.GetServerTime()) or time() end

local cur                     -- session en cours (ForeverCompagnonDB.session)
local lastXP, lastMax, lastLevel, lastMoney, lastTick

local function New()
  return { start = Now(), lastSeen = Now(), elapsed = 0, xp = 0, moneyIn = 0, moneyOut = 0, quests = 0, dungeons = {},
           nDungeons = 0, startLevel = UnitLevel("player") }
end

local function Snapshot()
  lastXP, lastMax = Plain(UnitXP("player")), Plain(UnitXPMax("player"))
  lastLevel = UnitLevel("player")
  lastMoney = Plain(GetMoney())
end

function S.Start()
  local db = root.db
  if not db then return end
  local s = db.session
  if s and s.lastSeen and Now() - s.lastSeen < GAP then
    cur = s
  else
    if s and (s.elapsed or 0) >= 60 then
      db.lastSession = s
      S.announceLast = true
    end
    cur = New()
    db.session = cur
  end
  Snapshot()
  lastTick = GetTime()
end

local function Tick()
  if not cur then return end
  local t = GetTime()
  local dt = t - (lastTick or t)
  lastTick = t
  if dt > 0 and dt < 120 then cur.elapsed = cur.elapsed + dt end
  cur.lastSeen = Now()
end

local function OnXP()
  if not cur then return end
  local xp, max, level = Plain(UnitXP("player")), Plain(UnitXPMax("player")), UnitLevel("player")
  if xp and lastXP then
    local gained
    if level > (lastLevel or level) and lastMax then gained = (lastMax - lastXP) + xp
    else gained = xp - lastXP end
    if gained and gained > 0 then cur.xp = cur.xp + gained end
  end
  lastXP, lastMax, lastLevel = xp, max, level
end

local function OnMoney()
  if not cur then return end
  local m = Plain(GetMoney())
  if m and lastMoney then
    local d = m - lastMoney
    if d > 0 then cur.moneyIn = cur.moneyIn + d elseif d < 0 then cur.moneyOut = cur.moneyOut - d end
  end
  lastMoney = m
end

local function OnZone()
  if not cur then return end
  local inInst, kind = IsInInstance()
  if not inInst or (kind ~= "party" and kind ~= "raid") then return end
  local name = _G.GetInstanceInfo and _G.GetInstanceInfo()
  if issecretvalue and select(2, pcall(issecretvalue, name)) == true then return end
  if type(name) == "string" and name ~= "" and not cur.dungeons[name] then
    cur.dungeons[name] = true
    cur.nDungeons = (cur.nDungeons or 0) + 1
  end
end

S.OnZone = OnZone

-- XP par heure et secondes jusqu'au prochain niveau (nil tant que le rythme n'est pas fiable)
function S.Rate(s)
  s = s or cur
  if not s or (s.elapsed or 0) < MIN_TIME or (s.xp or 0) <= 0 then return nil end
  return s.xp / s.elapsed * 3600
end
function S.ETA()
  local rate = S.Rate()
  if not rate or UnitLevel("player") >= 60 then return nil end
  local xp, max = Plain(UnitXP("player")), Plain(UnitXPMax("player"))
  if not (xp and max) or max <= 0 then return nil end
  return (max - xp) / rate * 3600
end

local function Dur(sec)
  sec = math.floor((sec or 0) + 0.5)
  local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
  if h > 0 then return string.format("%d h %02d", h, m) end
  return math.max(1, m) .. " min"
end
S.Dur = Dur
local function Num(n)
  local s = tostring(math.floor((n or 0) + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (out:gsub("^ ", ""))
end
local function Money(c)
  c = math.floor(c or 0)
  if _G.GetCoinTextureString then return _G.GetCoinTextureString(c) end
  local g, sv, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  if g > 0 then return string.format("%d po %d pa", g, sv) end
  if sv > 0 then return string.format("%d pa %d pc", sv, cu) end
  return cu .. " pc"
end

-- Récapitulatif d'une session (en cours par défaut)
function S.Recap(s)
  s = s or cur
  if not s then return L.sessNone end
  local parts = { string.format(L.sessXP, Num(s.xp)) }
  local rate = S.Rate(s)
  if rate then parts[#parts] = parts[#parts] .. string.format(L.sessRate, Num(rate)) end
  if (s.moneyIn or 0) > 0 then parts[#parts + 1] = string.format(L.sessIn, Money(s.moneyIn)) end
  if (s.moneyOut or 0) > 0 then parts[#parts + 1] = string.format(L.sessOut, Money(s.moneyOut)) end
  if (s.quests or 0) > 0 then parts[#parts + 1] = string.format(L.sessQuests, s.quests) end
  local names = {}
  for n in pairs(s.dungeons or {}) do names[#names + 1] = n end
  table.sort(names)
  if #names > 0 then parts[#parts + 1] = string.format(L.sessDungeons, #names, table.concat(names, ", ")) end
  local lv = UnitLevel("player")
  if s.startLevel and s ~= root.db.lastSession and lv > s.startLevel then parts[#parts + 1] = string.format(L.sessLevels, s.startLevel, lv) end
  return string.format(L.sessHead, Dur(s.elapsed)) .. table.concat(parts, " · ")
end

-- Tuile de l'écran Maintenant : prochain niveau
function S.Tile()
  if UnitLevel("player") >= 60 then return nil end
  local eta = S.ETA()
  local tip = { title = L.sessTitle, lines = { S.Recap() } }
  local zones = root.Quests and root.Quests.Available() and root.Quests.Zones(1) or {}
  if zones[1] then tip.lines[#tip.lines + 1] = string.format(L.sessZone, zones[1].name, #zones[1].quests) end
  if not eta then tip.lines[#tip.lines + 1] = L.sessWait end
  return { value = eta and ("~" .. Dur(eta)) or "…", label = string.format(L.sessNext, UnitLevel("player") + 1),
           color = { 0.4, 0.75, 1 }, tip = tip, onClick = function() root.Print(S.Recap()) end }
end

function S.Command()
  root.Print(S.Recap())
  if root.db and root.db.lastSession then root.Print(L.sessLastLabel .. S.Recap(root.db.lastSession)) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA",
                     "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    if event == "PLAYER_LEVEL_UP" then C_Timer.After(0.5, OnXP) else OnXP() end
  elseif event == "PLAYER_MONEY" then OnMoney()
  elseif event == "QUEST_TURNED_IN" then if cur then cur.quests = cur.quests + 1 end
  elseif event == "PLAYER_LOGOUT" then Tick()
  else OnZone() end
end)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(15, Tick) end

root.OnLogin(function()
  S.Start()
  if S.announceLast and root.db.lastSession then
    S.announceLast = nil
    C_Timer.After(5, function() root.Print(L.sessLastLabel .. S.Recap(root.db.lastSession)) end)
  end
end)
