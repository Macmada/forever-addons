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
  if S.OnXP then S.OnXP(); S.OnMoney() end                    -- rattrapage si un relevé était illisible
  if S.UpdateSheet then S.UpdateSheet() end
end

-- En combat, Forever peut rendre l'XP (et l'or) illisibles : on garde alors le dernier relevé lisible et on rattrape
-- l'écart au relevé lisible suivant (sortie de combat, tic de 15 s), sinon l'XP des monstres serait perdue.
local function OnXP()
  if not (cur and _G.UnitXP and _G.UnitXPMax) then return end
  local xp, max, level = Plain(UnitXP("player")), Plain(UnitXPMax("player")), UnitLevel("player")
  if not xp then return end                                   -- illisible : on attend, sans oublier lastXP
  if lastXP then
    local gained
    if level > (lastLevel or level) and lastMax then gained = (lastMax - lastXP) + xp
    else gained = xp - lastXP end
    if gained and gained > 0 then cur.xp = cur.xp + gained end
  end
  lastXP, lastLevel = xp, level
  if max then lastMax = max end
end

local function OnMoney()
  if not (cur and _G.GetMoney) then return end
  local m = Plain(GetMoney())
  if not m then return end
  if lastMoney then
    local d = m - lastMoney
    if d > 0 then cur.moneyIn = cur.moneyIn + d elseif d < 0 then cur.moneyOut = cur.moneyOut - d end
  end
  lastMoney = m
end
S.OnXP, S.OnMoney = OnXP, OnMoney

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

-- Bandeau de tuiles sous la fiche du personnage (C), sur toute sa largeur : XP gagnée, XP/h, prochain niveau (barre :
-- avancée dans le niveau), or net, quêtes et donjons. Survol : récapitulatif complet ; clic : récapitulatif dans le chat.
local sheet
local function Short(c)                                       -- or court : « 74 pa », « 1 po 50 pa », « 120 po »
  local a = math.abs(math.floor(c or 0))
  if a >= 10000 then
    local g, sv = math.floor(a / 10000), math.floor(a / 100) % 100
    if g < 100 and sv > 0 then return g .. " po " .. sv .. " pa" end
    return g .. " po"
  end
  if a >= 100 then return math.floor(a / 100) .. " pa" end
  return a .. " pc"
end

function S.SheetDefs()
  local s = cur
  if not s then return {} end
  local tip = { title = L.sessTitle, lines = { S.Recap() } }
  local zones = root.Quests and root.Quests.Available() and root.Quests.Zones(1) or {}
  if zones[1] then tip.lines[#tip.lines + 1] = string.format(L.sessZone, zones[1].name, #zones[1].quests) end
  if root.db and root.db.lastSession then tip.lines[#tip.lines + 1] = "|cffaaaaaa" .. L.sessLastLabel .. S.Recap(root.db.lastSession) .. "|r" end
  tip.lines[#tip.lines + 1] = "|cff80ccff" .. L.sessSheetClick .. "|r"
  local click = function() S.Command() end
  local BLUE, GREEN, GOLD, RED = { 0.4, 0.75, 1 }, { 0.3, 0.9, 0.5 }, { 1, 0.82, 0 }, { 1, 0.4, 0.3 }
  local defs = {}
  local function Add(value, label, color, frac)
    defs[#defs + 1] = { value = value, label = label, color = color, frac = frac, tip = tip, onClick = click }
  end
  Add("+" .. Num(s.xp), string.format(L.sessSheetXP, Dur(s.elapsed)), BLUE)
  local rate = S.Rate(s)
  Add(rate and Num(rate) or "…", L.sessSheetRate, BLUE)
  local lv = UnitLevel("player")
  if lv < 60 then
    local eta = S.ETA()
    local xp, max = Plain(_G.UnitXP and UnitXP("player")), Plain(_G.UnitXPMax and UnitXPMax("player"))
    Add(eta and ("~" .. Dur(eta)) or "…", string.format(L.sessNext, lv + 1), GREEN, (xp and max and max > 0) and xp / max or nil)
  end
  local net = (s.moneyIn or 0) - (s.moneyOut or 0)
  Add((net >= 0 and "+" or "-") .. Short(net), L.sessSheetMoney, net >= 0 and GOLD or RED)
  local nd = s.nDungeons or 0
  Add(tostring(s.quests or 0), nd > 0 and string.format(L.sessSheetQD, nd) or L.sessSheetQuests, GOLD)
  return defs
end

function S.UpdateSheet()
  if not (sheet and sheet:IsShown()) then return end
  sheet.tiles.Render(S.SheetDefs(), 6, -6, sheet:GetWidth() - 12, 6)
end

local function CreateSheet(cf)
  local K = root.Kit
  sheet = CreateFrame("Frame", "ForeverCompagnonSessionSheet", cf)
  sheet:SetHeight(64)
  sheet:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", 0, -4)
  sheet:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 0, -4)
  if sheet:GetWidth() < 200 then sheet:SetWidth(math.max(cf:GetWidth() or 0, 340)) end
  K.Panel(sheet, 0.85)
  sheet.tiles = K.Tiles(sheet, 5, 52)
  sheet:SetScript("OnShow", S.UpdateSheet)
  sheet:SetScript("OnSizeChanged", S.UpdateSheet)
end

function S.AttachSheet()
  local cf = _G.CharacterFrame
  if not cf or sheet or not root.Kit then return end
  CreateSheet(cf)
  S.UpdateSheet()
end

function S.Command()
  root.Print(S.Recap())
  if root.db and root.db.lastSession then root.Print(L.sessLastLabel .. S.Recap(root.db.lastSession)) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA",
                     "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    if event == "PLAYER_LEVEL_UP" then C_Timer.After(0.5, OnXP) else OnXP() end
  elseif event == "PLAYER_MONEY" then OnMoney()
  elseif event == "QUEST_TURNED_IN" then if cur then cur.quests = cur.quests + 1 end
  elseif event == "PLAYER_LOGOUT" then Tick()
  elseif event == "PLAYER_REGEN_ENABLED" then OnXP(); OnMoney()
  else OnZone() end
end)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(15, Tick) end

root.OnLogin(function()
  S.Start()
  S.AttachSheet()
  if S.announceLast and root.db.lastSession then
    S.announceLast = nil
    C_Timer.After(5, function() root.Print(L.sessLastLabel .. S.Recap(root.db.lastSession)) end)
  end
end)
