local ADDON, ns = ...; if ns.Module then ADDON, ns = ns.Module("ForeverLoot") end
local L = ns.L
local D = ns.Data

-- ForeverLoot : évaluation des objets pour ton personnage, mémoire des objets vus, butin des donjons,
-- conseils de jet de butin et de récompense de quête.

local db, gdb
function ns.Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cffe6b84dForeverLoot|r " .. msg)
end

-- Gain minimal pour parler d'amélioration (même seuil que ForeverHeal)
ns.MIN_GAIN = 0.1

local Instant = function(x) return ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(x) end
local Info = function(x) return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(x) end
local function ItemID(link) return link and tonumber(link:match("item:(%d+)")) end
ns.ItemID = ItemID

----------------------------------------------------------------------
-- Ce que la classe peut porter
----------------------------------------------------------------------
function ns.Wearable(link)
  local _, _, _, equipLoc, _, classID, subID = Instant(link)
  if not equipLoc or not D.slots[equipLoc] then return false, "slot" end
  local _, class = UnitClass("player")
  local level = UnitLevel("player")
  if classID == 4 then
    if subID == 0 then return true end
    if subID == 6 then return D.shield[class] == true, "armor" end
    local a = D.armor[class] or { 1 }
    local max = (a[2] and level < a[2]) and a[3] or a[1]
    return subID <= max, "armor"
  elseif classID == 2 then
    return (D.weapons[class] or {})[subID] == true, "weapon"
  end
  return false, "class"
end

local function MinLevel(link) return select(5, Info(link)) end

----------------------------------------------------------------------
-- Évaluation : modèle de ForeverHeal pour le prêtre, sinon poids simplifiés
----------------------------------------------------------------------
local function Stats(link)
  local get = (C_Item and C_Item.GetItemStats) or GetItemStats
  return (get and get(link)) or {}
end

local function WeightScore(stats, w)
  local s = 0
  for k, v in pairs(stats) do s = s + (w[k] or 0) * v end
  return s
end

local cache, cacheN = {}, 0
ns.version = 0

-- Rôle du personnage (choisi sur l'écran Maintenant ou dans Préparation) ; nil hors de ForeverCompagnon
function ns.Role() return ns.root and ns.root.Role and ns.root.Role() or nil end
function ns.Weights()
  local _, class = UnitClass("player")
  local byRole = D.roleWeights and D.roleWeights[class]
  local role = ns.Role()
  return (byRole and role and byRole[role]) or D.weights[class] or D.weights.WARRIOR, role
end

function ns.Evaluate(link)
  if not link then return nil end
  local key = link .. "#" .. ns.version .. "#" .. tostring(ns.Role())
  if cache[key] ~= nil then return cache[key] or nil end
  local r
  local wear, why = ns.Wearable(link)
  local _, class = UnitClass("player")
  local _, _, _, equipLoc = Instant(link)
  local slots = equipLoc and D.slots[equipLoc]
  if slots then
    r = { wearable = wear, why = why, minLevel = MinLevel(link) }
    local api = _G.ForeverHealAPI
    local role = ns.Role()
    local healer = class == "PRIEST" or class == "DRUID" or class == "PALADIN" or class == "SHAMAN"
    if healer and (role == nil and class == "PRIEST" or role == "heal") and api and api.Evaluate then
      local e = api.Evaluate(link)
      if e then
        r.method, r.slot, r.score, r.hps, r.healed, r.hp = "heal", e.slot, e.score, e.hps, e.healed, e.hp
        r.regen, r.armor = e.regen, e.armor
      end
    end
    if not r.method then
      local w = ns.Weights()
      local new = WeightScore(Stats(link), w)
      local best
      for _, slot in ipairs(slots) do
        local cur = GetInventoryItemLink("player", slot)
        local old = cur and WeightScore(Stats(cur), w) or 0
        if slots.two then
          local off = GetInventoryItemLink("player", 17)
          if off then old = old + WeightScore(Stats(off), w) end
        end
        if not best or new - old > best.score then best = { slot = slot, score = new - old } end
      end
      r.method, r.slot, r.score = "weights", best.slot, best.score
    end
  end
  if cacheN > 5000 then wipe(cache); cacheN = 0 end      -- 500 avant la 3.5.3 : vidé en plein calcul (700+ objets)
  cache[key] = r or false
  cacheN = cacheN + 1
  return r
end

-- Résumé humain d'une évaluation
function ns.GainText(r)
  if not r then return "" end
  if r.method == "heal" then
    local parts = {}
    if math.abs(r.hps or 0) >= 0.05 then parts[#parts + 1] = string.format(L.gainHps, ns.Signed(r.hps, 1)) end
    if math.abs(r.healed or 0) >= 1 then parts[#parts + 1] = string.format(L.gainHealed, ns.Signed(r.healed)) end
    if math.abs(r.hp or 0) >= 1 then parts[#parts + 1] = string.format(L.gainHp, ns.Signed(r.hp)) end
    if math.abs(r.regen or 0) >= 0.01 then parts[#parts + 1] = string.format(L.gainRegen, ns.Signed(r.regen, 2)) end
    if math.abs(r.armor or 0) >= 1 then parts[#parts + 1] = string.format(L.gainArmor, ns.Signed(r.armor)) end
    return #parts > 0 and table.concat(parts, ", ") or L.gainNone
  end
  return string.format(L.gainPoints, ns.Signed(r.score, 1))
end

function ns.Signed(v, dec)
  dec = dec or 0
  if math.abs(v) < 0.5 * 10 ^ (-dec) then return "|cffa0a0a00|r" end
  local s = string.format("%." .. dec .. "f", math.abs(v))
  if ns.lang ~= "en" then s = s:gsub("%.", ",") end
  return (v > 0 and "|cff40d860+" or "|cffff5050−") .. s .. "|r"
end

----------------------------------------------------------------------
-- Mémoire des objets vus et du butin des donjons
----------------------------------------------------------------------
local function Remember(link, src, where)
  local id = ItemID(link)
  if not id or not db then return end
  local _, _, _, equipLoc = Instant(link)
  if not equipLoc or not D.slots[equipLoc] then return end
  local quality = select(3, Info(link))
  if quality and quality < 2 then return end                       -- gris et blancs ignorés
  local e = db.seen[id] or {}
  e.link, e.src, e.where, e.t = link, src, where or e.where, time()
  if not db.seen[id] then db.seenCount = (db.seenCount or 0) + 1 end
  db.seen[id] = e
  if db.seenCount > 1500 then                                      -- ménage : les plus anciens
    local list = {}
    for k, v in pairs(db.seen) do list[#list + 1] = { k = k, t = v.t or 0 } end
    table.sort(list, function(a, b) return a.t < b.t end)
    for i = 1, 300 do db.seen[list[i].k] = nil end
    db.seenCount = db.seenCount - 300
  end
end
ns.Remember = Remember

local function Where()
  local inInstance = IsInInstance()
  return inInstance and GetRealZoneText() or nil
end

-- Butin d'un boss (ou d'un monstre en donjon) : gardé pour tous tes personnages
function ns.RecordDungeonLoot(zone, boss, link)
  local id = ItemID(link)
  if not (zone and id and gdb) then return end
  local quality = select(3, Info(link))
  if quality and quality < 2 then return end
  zone, boss = ns.Clear(zone), ns.Clear(boss)                 -- noms secrets en donjon : jamais pris comme clé
  if not zone then return end
  gdb.dungeons[zone] = gdb.dungeons[zone] or {}
  local z = gdb.dungeons[zone]
  boss = boss or "?"
  z[boss] = z[boss] or {}
  local e = z[boss][id] or { n = 0 }
  e.link, e.n, e.t = link, e.n + 1, time()
  z[boss][id] = e
end

----------------------------------------------------------------------
-- Conseils
----------------------------------------------------------------------
-- Jet de butin : « besoin » si tu peux le porter et qu'il améliore ton équipement
function ns.RollAdvice(link)
  local r = ns.Evaluate(link)
  if not r then return "greed", L.adviceNotGear end
  if not r.wearable then return "greed", L.adviceNotWearable end
  if (r.minLevel or 0) > UnitLevel("player") + 5 then return "greed", string.format(L.adviceTooHigh, r.minLevel) end
  if (r.score or 0) > ns.MIN_GAIN then return "need", ns.GainText(r) end
  return "greed", L.adviceNoGain
end

-- Récompenses de quête : la meilleure pour toi, sinon la plus chère à revendre
function ns.QuestChoice(links)
  local best, bestScore, dear, dearPrice
  for i, link in ipairs(links) do
    local r = link and ns.Evaluate(link)
    if r and r.wearable and (r.score or 0) > ns.MIN_GAIN and (r.minLevel or 0) <= UnitLevel("player") and (not bestScore or r.score > bestScore) then
      best, bestScore = i, r.score
    end
    local price = link and select(11, Info(link)) or 0
    if not dearPrice or (price or 0) > dearPrice then dear, dearPrice = i, price or 0 end
  end
  if best then return best, "best" end
  return dear, "price"
end

----------------------------------------------------------------------
-- Événements
----------------------------------------------------------------------
local function InitDB()
  ForeverLootDB = ForeverLootDB or {}
  db = ForeverLootDB
  ns.db = db
  db.version = db.version or 1
  db.seen = db.seen or {}
  if db.rollHelp == nil then db.rollHelp = true end
  if db.lootAlert == nil then db.lootAlert = true end
  if db.questHelp == nil then db.questHelp = true end
  if db.tooltipHint == nil then db.tooltipHint = true end
  if db.higher == nil then db.higher = true end
  if db.nearSpan == nil then db.nearSpan = 0 end          -- « Jusqu'au niveau » : ton niveau par défaut, puis ton choix retenu
  ns.nearSpan = db.nearSpan
  db.minimap = db.minimap or { angle = 250, hide = false }
  if db.lang then ns.lang = db.lang end
  ForeverLootGlobalDB = ForeverLootGlobalDB or {}
  gdb = ForeverLootGlobalDB
  ns.gdb = gdb
  gdb.dungeons = gdb.dungeons or {}
end
ns._InitDB = InitDB

local ev = CreateFrame("Frame")
ns.eventFrame = ev
local handlers = {}
local lastBoss

local function Bump() ns.version = ns.version + 1 end
handlers.PLAYER_EQUIPMENT_CHANGED = function() Bump(); if ns.Refresh then ns.Refresh() end end
handlers.PLAYER_LEVEL_UP = Bump
handlers.CHARACTER_POINTS_CHANGED = Bump
handlers.ENCOUNTER_END = function(_, name, _, _, success) if ns.Clear(success) == 1 then lastBoss = ns.Clear(name) end end
handlers.LOOT_OPENED = function()
  local zone = Where()
  local boss
  if UnitExists("target") and UnitIsDead("target") and not UnitIsPlayer("target") then
    -- en donjon, le jeu rend la cible secrète (nom, classement, niveau) : on prend alors le boss de la rencontre finie
    boss = ns.Clear(UnitName("target"))
    local c = ns.Clear(UnitClassification("target"))
    local lvl = ns.Plain(UnitLevel("target"))
    if boss and not (c == "worldboss" or c == "elite" or c == "rareelite" or lvl == -1) and boss ~= lastBoss then boss = nil end
    if not boss and not c then boss = lastBoss end
  end
  for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
    local link = GetLootSlotLink(i)
    if link then
      Remember(link, "loot", zone)
      if zone and boss then ns.RecordDungeonLoot(zone, boss, link) end
    end
  end
end
handlers.START_LOOT_ROLL = function(rollID)
  local link = GetLootRollItemLink(rollID)
  if not link then return end
  Remember(link, "roll", Where())
  if Where() then ns.RecordDungeonLoot(Where(), lastBoss or "?", link) end
  if db.rollHelp and ns.ShowRollAdvice then ns.ShowRollAdvice(rollID, link) end
end
-- Messages « tu reçois » du jeu (butin, objet poussé par une quête, objet créé) transformés en motifs
local selfPatterns
local function SelfPatterns()
  if selfPatterns then return selfPatterns end
  selfPatterns = {}
  local fr = GetLocale() == "frFR"
  local defaults = {
    LOOT_ITEM_SELF = fr and "Vous recevez le butin : %s." or "You receive loot: %s.",
    LOOT_ITEM_SELF_MULTIPLE = fr and "Vous recevez le butin : %sx%d." or "You receive loot: %sx%d.",
    LOOT_ITEM_PUSHED_SELF = fr and "Vous recevez l'objet : %s." or "You receive item: %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = fr and "Vous recevez l'objet : %sx%d." or "You receive item: %sx%d.",
  }
  for key, def in pairs(defaults) do
    local t = _G[key] or def
    t = t:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1"):gsub("%%s", "(.+)"):gsub("%%d", "%%d+")
    selfPatterns[#selfPatterns + 1] = "^" .. t
  end
  return selfPatterns
end
function ns.IsSelfLoot(msg)
  for _, p in ipairs(SelfPatterns()) do if msg:find(p) then return true end end
  return false
end

-- Objet reçu : amélioration pour toi ? (une seule alerte par objet en 15 s)
local recentAlerts = {}
function ns.CheckLootUpgrade(link)
  local id = ItemID(link)
  if not (db and db.lootAlert and id) then return end
  if recentAlerts[id] and GetTime() - recentAlerts[id] < 15 then return end
  local r = ns.Evaluate(link)
  if not (r and r.wearable and (r.score or 0) > ns.MIN_GAIN) then return end
  recentAlerts[id] = GetTime()
  local later = (r.minLevel or 0) > UnitLevel("player")
  ns.lastLootAlert = { link = link, eval = r, later = later }
  if ns.ShowLootAlert then ns.ShowLootAlert(link, r, later) end
end

handlers.CHAT_MSG_LOOT = function(msg)
  local link = msg and msg:match("(|c[^|]*|Hitem:.-|h.-|h|r)")
  if link then
    Remember(link, "chat", Where())
    if Where() then ns.RecordDungeonLoot(Where(), lastBoss or "?", link) end
    -- c'est toi qui le reçois : amélioration ? (petit délai : l'objet arrive dans les sacs)
    if ns.IsSelfLoot(msg) then C_Timer.After(0.5, function() ns.CheckLootUpgrade(link) end) end
  end
end
local function QuestLinks()
  local links = {}
  for i = 1, (GetNumQuestChoices and GetNumQuestChoices() or 0) do links[i] = GetQuestItemLink("choice", i) end
  return links
end
handlers.QUEST_COMPLETE = function()
  local links = QuestLinks()
  for _, l in ipairs(links) do if l then Remember(l, "quest") end end
  if db.questHelp and #links > 1 and ns.ShowQuestChoice then ns.ShowQuestChoice(links) end
end
handlers.QUEST_DETAIL = function()
  for _, l in ipairs(QuestLinks()) do if l then Remember(l, "quest") end end
end
handlers.MERCHANT_SHOW = function()
  for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
    local l = GetMerchantItemLink(i)
    if l then Remember(l, "vendor") end
  end
end
handlers.PLAYER_LOGIN = function() if ns.OnLogin then ns.OnLogin() end end
local infoPending
handlers.GET_ITEM_INFO_RECEIVED = function()
  if infoPending or not (ns.ui and ns.ui:IsShown()) then return end
  infoPending = true
  C_Timer.After(1.5, function() infoPending = nil; if ns.Refresh then ns.Refresh() end end)
end

ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON and ... ~= ns.ROOT then return end
    InitDB()
    for e in pairs(handlers) do pcall(ev.RegisterEvent, ev, e) end
    if ns.OnLoaded then ns.OnLoaded() end
    return
  end
  local h = handlers[event]
  if h then h(...) end
end)
ns._handlers = handlers

----------------------------------------------------------------------
-- Autres addons (facultatifs) : DungeonJournal (butin par boss de Forever), Syndicator (banque, autres personnages)
----------------------------------------------------------------------
-- DungeonJournal : ForeverDungeonJournal_NS.DB[donjon].bosses[i] = { name, loot = { { id, nom, emplacement, qualité } } },
-- et .quests[i].rewardItems. Lu tel quel dans le jeu (rien n'est copié). Renvoie nil si l'addon est absent.
function ns.DJ()
  local fdj = _G.ForeverDungeonJournal_NS
  if type(fdj) ~= "table" or type(fdj.DB) ~= "table" then return nil end
  return fdj
end

function ns.DJName(fdj, key)
  if fdj.LocalizeDungeonName then
    local ok, n = pcall(fdj.LocalizeDungeonName, key)
    if ok and n then return n end
  end
  return key
end

-- Premier nombre d'un niveau DungeonJournal (« 13-20 » ou 15)
local function FirstNum(v) return tonumber(v) or (type(v) == "string" and tonumber(v:match("%d+"))) or nil end

-- Liste à plat du butin de DungeonJournal : { id, dungeon, boss (ou quête), quest, level (niveau du donjon ou de la quête),
-- faction (« Alliance » / « Horde » si réservé à un camp) }
local djCache

-- Même liste tirée des sources intégrées (base WoW Forever d'All The Things), quand DungeonJournal n'est pas installé :
-- butin des boss et des PNJ des donjons, récompenses des quêtes de donjon. Noms demandés au jeu ; liste refaite tant que
-- des noms manquent (le jeu les donne peu à peu).
local srcCache
local function SourceItems()
  local src = ns.root and (ns.root.Sources or (ns.root.LoadSources and ns.root.LoadSources()))
  if not (src and ns.ATT) then return {} end
  if srcCache and not (srcCache.partial and GetTime() - srcCache.t > 30) then return srcCache.list end
  local list, partial = {}, false
  local dnames, bnames = {}, {}
  for id, srcs in pairs(src.items) do
    for _, s in ipairs(srcs) do
      local e = s[6]
      if e and e.inst and (s[1] == "boss" or s[1] == "drop" or s[1] == "quest") then
        if dnames[e.inst] == nil then dnames[e.inst] = ns.ATT.InstanceName(e.inst) or false end
        local who
        if s[1] == "quest" then who = ns.ATT.QuestName(e.q or s[2]) or (ns.lang == "en" and "quest" or "quête")
        else
          if bnames[s[2]] == nil then bnames[s[2]] = ns.ATT.NpcName(s[2]) or false end
          who = bnames[s[2]] or nil
          if not who then partial = true; who = "?" end
        end
        local inst = src.instances[e.inst]
        list[#list + 1] = { id = id, dungeon = dnames[e.inst] or "?", boss = who, quest = s[1] == "quest" or nil,
                            level = e.lvl or (inst and inst[4] ~= 0 and inst[4]) or nil,
                            faction = (e.r == 1 and "Horde") or (e.r == 2 and "Alliance") or nil, inst = e.inst }
      end
    end
  end
  srcCache = { list = list, partial = partial, t = GetTime() }
  return list
end
ns.SourceItems = SourceItems

function ns.DJItems()
  local fdj = ns.DJ()
  if not fdj then return SourceItems() end
  if djCache and djCache.src == fdj.DB then return djCache.list end
  local list = {}
  for key, d in pairs(fdj.DB) do
    if type(d) == "table" then
      local dname = ns.DJName(fdj, key)
      for _, b in ipairs(type(d.bosses) == "table" and d.bosses or {}) do
        for _, it in ipairs(type(b.loot) == "table" and b.loot or {}) do
          if type(it) == "table" and type(it[1]) == "number" then
            list[#list + 1] = { id = it[1], dungeon = dname, boss = b.name or "?", level = FirstNum(d.level), faction = b.factionOnly }
          end
        end
      end
      for _, q in ipairs(type(d.quests) == "table" and d.quests or {}) do
        for _, it in ipairs(type(q.rewardItems) == "table" and q.rewardItems or {}) do
          if type(it) == "table" and type(it[1]) == "number" then
            list[#list + 1] = { id = it[1], dungeon = dname, boss = q.name or "?", quest = true, level = FirstNum(q.level) or FirstNum(d.level),
                                faction = (q.faction == "Alliance" or q.faction == "Horde") and q.faction or nil }
          end
        end
      end
    end
  end
  djCache = { src = fdj.DB, list = list }
  return list
end

-- Syndicator : où se trouve un objet (ta banque, ton courrier, tes autres personnages) ; nil si absent
function ns.Owned(id)
  local S = _G.Syndicator
  if not (S and S.API and S.API.GetInventoryInfoByItemID) then
    return ns.root and ns.root.Store and ns.root.Store.Owned(id) or nil      -- inventaire retenu par ForeverCompagnon
  end
  if S.API.IsReady and not S.API.IsReady() then return nil end
  local ok, info = pcall(S.API.GetInventoryInfoByItemID, id, true, false)
  if not ok or type(info) ~= "table" then return nil end
  local me = UnitName("player")
  local out = {}
  for _, c in ipairs(info.characters or {}) do
    local where = {}
    if c.character == me then
      if (c.bank or 0) > 0 then where[#where + 1] = L.ownBank end
      if (c.mail or 0) > 0 then where[#where + 1] = L.ownMail end
      if #where > 0 then out[#out + 1] = table.concat(where, ", ") end
    elseif (c.bags or 0) + (c.bank or 0) + (c.mail or 0) + (c.equipped or 0) > 0 then
      out[#out + 1] = string.format(L.ownOther, c.character)
    end
  end
  for _, g in ipairs(info.guilds or {}) do
    if (g.bank or 0) > 0 then out[#out + 1] = string.format(L.ownGuild, g.guild) end
  end
  if #out == 0 then return nil end
  return table.concat(out, " ; ")
end

-- All The Things : où obtenir un objet (base Forever d'ATT), mémorisé ; nil si ATT est absent ou ne sait pas
local attCache = {}
-- Lieux où obtenir un objet (sources intégrées) et flèche vers le plus proche
local placeCache = {}
function ns.HasPlace(id)
  if placeCache[id] == nil then placeCache[id] = (ns.ATT and ns.ATT.Available() and #ns.ATT.Places(id) > 0) or false end
  return placeCache[id]
end
function ns.GoTo(id)
  local nav = ns.root and ns.root.Nav
  if not (nav and ns.ATT) then return false end
  local best = nav.Closest(ns.ATT.Places(id))
  if not best then return false end
  return (nav.Go(best.mapID, best.x, best.y, best.name))
end

function ns.ATTWhere(id)
  if not (id and ns.ATT.Available()) then return nil end
  if attCache[id] == nil then
    local s = ns.ATT.Source("itemID", id, 1)
    if s and s.partial then return s.text end          -- noms pas encore donnés par le jeu : redemandés plus tard
    attCache[id] = (s and s.text) or false
  end
  return attCache[id] or nil
end

----------------------------------------------------------------------
-- BiS : meilleurs objets connus par emplacement (portés, sacs, vus, référence, DungeonJournal)
----------------------------------------------------------------------
local candMemo
function ns.ForgetCandidates() candMemo = nil end
function ns.Candidates()
  if candMemo and GetTime() - candMemo.t < 10 and candMemo.k == tostring(ns.version) .. tostring(UnitFactionGroup and UnitFactionGroup("player")) then
    return candMemo.v
  end
  ns.candidatesBuilt = (ns.candidatesBuilt or 0) + 1
  local list, seenIds = {}, {}
  local function add(link, src, where, ref)
    local id = ItemID(link)
    if not id or seenIds[id] then return end
    seenIds[id] = true
    local e = { link = link, id = id, src = src, where = where, ref = ref }
    list[#list + 1] = e
    return e
  end
  for slot = 1, 18 do
    local l = GetInventoryItemLink("player", slot)
    if l then add(l, "equipped") end
  end
  for bag = 0, 4 do
    local n = (C_Container and C_Container.GetContainerNumSlots) and C_Container.GetContainerNumSlots(bag)
              or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
    for s = 1, n do
      local l = (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(bag, s)
                or (GetContainerItemLink and GetContainerItemLink(bag, s))
      if l then add(l, "bags") end
    end
  end
  local _, class = UnitClass("player")
  local refById = {}
  for _, r in ipairs(D.reference[class] or {}) do
    refById[r.id] = r
    local _, link = Info(r.id)
    if link then add(link, "ref", nil, r) elseif C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.id) end
  end
  for _, e in pairs(db.seen) do if e.link then add(e.link, e.src, e.where) end end
  -- DungeonJournal : seulement ce que ta classe peut porter et ce que ta faction peut obtenir ; objets pas encore chargés
  -- demandés au jeu (visibles au rafraîchissement)
  local asked = 0
  local myFaction = UnitFactionGroup("player")
  for _, it in ipairs(ns.DJItems()) do
    if not seenIds[it.id] and not (it.faction and myFaction and it.faction ~= myFaction) then
      local _, _, _, equipLoc = Instant(it.id)
      if equipLoc and D.slots[equipLoc] then
        local _, link = Info(it.id)
        if link then
          if ns.Wearable(link) then
            local e = add(link, it.quest and "djquest" or "dj", it.dungeon .. " — " .. it.boss)
            if e then e.srcLevel = it.level end
          end
        elseif asked < 50 and C_Item and C_Item.RequestLoadItemDataByID then
          C_Item.RequestLoadItemDataByID(it.id)
          asked = asked + 1
        end
      end
    end
  end
  for _, c in ipairs(list) do c.ref = c.ref or refById[c.id] end   -- une référence déjà portée reste marquée
  candMemo = { t = GetTime(), v = list, k = tostring(ns.version) .. tostring(UnitFactionGroup and UnitFactionGroup("player")) }
  return list
end

-- slot -> { meilleurs candidats (gain > 0, triés) }, et l'objet de référence de cet emplacement
-- Niveau auquel un objet devient utile : son niveau requis, ou (objet sans niveau requis, ex. récompense de quête de haut
-- niveau) son niveau d'objet moins 5
function ns.ReqLevel(link)
  local _, _, _, ilvl, minLevel = Info(link)
  if minLevel and minLevel > 0 then return minLevel end
  if ilvl and ilvl > 0 then return math.max(1, ilvl - 5) end
  return 0
end

-- maxLevel : seulement les objets utilisables jusqu'à ce niveau (onglet « À mon niveau ») ; sinon réglage « niveau supérieur »
-- Résultats mémorisés : l'écran Maintenant et les onglets demandent plusieurs fois la même chose à chaque actualisation
-- (des centaines d'objets évalués à chaque fois : ralentissements en 3.5.0). Oubliés quand tes sacs, ton équipement ou ton
-- niveau changent, et au plus tard au bout de 10 s.
local memo = { bis = {}, where = {} }
local forgetRanges
function ns.ForgetMemo() memo.bis, memo.where = {}, {}; ns.ForgetCandidates(); if forgetRanges then forgetRanges() end end
local function Fresh(m) return m and GetTime() - m.t < 10 end
-- ce qui change les résultats : réglages (version), niveau, faction, classe, rôle
local function State()
  return table.concat({ tostring(ns.version), tostring(UnitLevel("player")), tostring(UnitFactionGroup and UnitFactionGroup("player")),
                        tostring(select(2, UnitClass("player"))), tostring(ns.Role()) }, ":")
end

function ns.BiS(limit, maxLevel)
  local mkey = tostring(limit) .. ":" .. tostring(maxLevel) .. ":" .. State()
  if Fresh(memo.bis[mkey]) then return memo.bis[mkey].v end
  local out = {}
  for _, c in ipairs(ns.Candidates()) do
    local r = ns.Evaluate(c.link)
    if r and r.slot and (r.wearable or c.ref) then
      local slot = (r.slot == 12) and 11 or ((r.slot == 14) and 13 or r.slot)
      local okLevel
      if maxLevel then
        -- objet et source (donjon, quête) à ta portée
        okLevel = ns.ReqLevel(c.link) <= maxLevel and (c.srcLevel or 0) <= maxLevel
      else okLevel = db.higher or (r.minLevel or 0) <= UnitLevel("player") end
      if okLevel then
        out[slot] = out[slot] or { items = {}, refs = {} }
        c.eval = r
        if c.ref then table.insert(out[slot].refs, c) end
        if c.src ~= "equipped" and (r.score or 0) > ns.MIN_GAIN and r.wearable then table.insert(out[slot].items, c) end
      end
    end
  end
  for _, s in pairs(out) do
    table.sort(s.items, function(a, b) return a.eval.score > b.eval.score end)
    while #s.items > (limit or 3) do table.remove(s.items) end
  end
  memo.bis[mkey] = { t = GetTime(), v = out }
  return out
end

----------------------------------------------------------------------
-- Niveaux d'un donjon sur Forever : d'abord le jeu (recherche de groupe : « Donjon d'Ombrecroc (20 - 30) »), puis
-- DungeonJournal (fait pour Forever, « 13-20 »), en dernier la base classique d'All The Things (minimum seulement).
----------------------------------------------------------------------
local function NormName(n)
  n = tostring(n or ""):lower():gsub("\226\128\153", "'")
  n = n:gsub("^%s+", ""):gsub("%s+$", "")
  for _, art in ipairs({ "les ", "le ", "la ", "l'", "the " }) do
    if n:sub(1, #art) == art then n = n:sub(#art + 1); break end
  end
  return n
end
ns.NormName = NormName

local lfgRanges, lfgTried
local function LFGRanges()
  if lfgRanges then return lfgRanges end
  if lfgTried and GetTime() - lfgTried < 60 then return {} end
  lfgTried = GetTime()
  local out = {}
  local LF = _G.C_LFGList
  if LF and LF.GetAvailableActivities and LF.GetActivityInfoTable then
    local ok, ids = pcall(LF.GetAvailableActivities)
    if ok and type(ids) == "table" then
      for _, id in ipairs(ids) do
        local ok2, info = pcall(LF.GetActivityInfoTable, id)
        if ok2 and type(info) == "table" then
          local lo = info.minLevelSuggestion or info.minLevel
          local hi = info.maxLevelSuggestion or info.maxLevel
          lo = (type(lo) == "number" and lo > 0) and lo or nil
          hi = (type(hi) == "number" and hi > 0) and hi or nil
          for _, n in ipairs({ info.fullName, info.shortName }) do
            if n and lo then out[NormName(n)] = { lo, hi, "jeu" } end
          end
        end
      end
      if next(out) then lfgRanges = out end       -- vide : le jeu n'a peut-être pas encore chargé la liste
    end
  end
  return out
end

local rangeMemo, djRanges, djSrc = {}, nil, nil
forgetRanges = function() rangeMemo = {}; if not lfgRanges then lfgTried = nil end end
local function DJRanges()
  local fdj = ns.DJ()
  if not fdj then return {} end
  if djRanges and djSrc == fdj.DB then return djRanges end
  local dj = {}
  for k, d in pairs(fdj.DB) do
    if type(d) == "table" and d.level then
      local lo, hi = tostring(d.level):match("(%d+)%D+(%d+)")
      lo = tonumber(lo) or tonumber(d.level)
      if lo then dj[NormName(ns.DJName(fdj, k))] = { lo, tonumber(hi), "DungeonJournal" } end
    end
  end
  djRanges, djSrc = dj, fdj.DB
  return dj
end

-- { min, max, source } ou nil (mémorisé ; le niveau du jeu remplace les autres dès que la liste du jeu est chargée)
function ns.DungeonRange(name, instLevel)
  local key = NormName(name)
  local mk = key .. ":" .. tostring(instLevel)
  local m = rangeMemo[mk]
  if m and (m.r and m.r[3] == "jeu" or lfgRanges or (lfgTried and GetTime() - lfgTried < 60)) then return m.r or nil end
  local function find(t)
    if t[key] then return t[key] end
    for k, v in pairs(t) do if #k > 4 and (k:find(key, 1, true) or key:find(k, 1, true)) then return v end end
  end
  local r = find(LFGRanges()) or find(DJRanges())
  if not r and instLevel and instLevel > 0 then r = { instLevel, nil, "ATT" } end
  rangeMemo[mk] = { r = r or false }
  return r
end

----------------------------------------------------------------------
-- Où aller : donjons et zones qui ont le plus d'améliorations pour toi (objets de boss, butin, récompenses de quêtes pas
-- encore faites), à ta portée (niveau du lieu jusqu'à ton niveau + 3). Achats et fabrications n'en font pas partie.
-- { key, name, kind = "dungeon"|"zone", level, mapID, x, y, items = { {c, eval} }, quests = { id = true }, nQuests, score }
----------------------------------------------------------------------
function ns.WhereToGo(max)
  local wkey = tostring(max) .. ":" .. State()
  if Fresh(memo.where[wkey]) then return memo.where[wkey].v end
  local level = UnitLevel("player")
  local reach = math.min(60, level + 3)
  local places, order = {}, {}
  local bis = ns.BiS(2, reach)
  for _, s in pairs(bis) do
    for _, c in ipairs(s.items) do
      if c.src ~= "bags" and c.src ~= "equipped" and not ns.Owned(c.id) then
        local where = (ns.ATT and ns.ATT.Available() and ns.ATT.Where) and ns.ATT.Where(c.id) or {}
        if #where == 0 and (c.src == "dj" or c.src == "djquest") and c.where then
          local dname = c.where:match("^(.-) — ") or c.where
          where = { { key = "dj:" .. dname, name = dname, kind = "dungeon", level = c.srcLevel } }
        end
        local seen = {}
        for _, w in ipairs(where) do
          if w.kind == "dungeon" and not w.range then
            local r = ns.DungeonRange(w.name, w.level)
            w.range = r or false
            if r then w.level, w.maxLevel = r[1], r[2] end
          end
          local okLevel = (w.level or 0) <= level + 2 and not (w.maxLevel and level > w.maxLevel)
          if not seen[w.key] and not w.raid and okLevel then
            seen[w.key] = true
            local p = places[w.key]
            if not p then
              p = { key = w.key, name = w.name, kind = w.kind, level = w.level, maxLevel = w.maxLevel, mapID = w.mapID, x = w.x, y = w.y,
                    items = {}, quests = {}, nQuests = 0, score = 0 }
              places[w.key] = p
              order[#order + 1] = p
            end
            if w.level and (not p.level or w.level < p.level) and w.kind ~= "dungeon" then p.level = w.level end
            p.items[#p.items + 1] = { c = c, eval = c.eval, quest = w.quest }
            if w.quest and not p.quests[w.quest] then p.quests[w.quest] = true; p.nQuests = p.nQuests + 1 end
            p.score = p.score + (c.eval and c.eval.score or 0)
          end
        end
      end
    end
  end
  local function fits(p) return (p.level or 0) <= level and not (p.maxLevel and level > p.maxLevel) end
  table.sort(order, function(a, b)
    if fits(a) ~= fits(b) then return fits(a) end
    if a.score ~= b.score then return a.score > b.score end
    return a.name < b.name
  end)
  for _, p in ipairs(order) do table.sort(p.items, function(a, b) return (a.eval.score or 0) > (b.eval.score or 0) end) end
  while #order > (max or 3) do table.remove(order) end
  memo.where[wkey] = { t = GetTime(), v = order }
  return order
end

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN",
                       "LFG_LIST_AVAILABILITY_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function() ns.ForgetMemo() end)
end
