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
  if cacheN > 500 then wipe(cache); cacheN = 0 end
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
handlers.ENCOUNTER_END = function(_, name, _, _, success) if success == 1 then lastBoss = name end end
handlers.LOOT_OPENED = function()
  local zone = Where()
  local boss
  if UnitExists("target") and UnitIsDead("target") and not UnitIsPlayer("target") then
    boss = UnitName("target")
    local c = UnitClassification("target")
    if not (c == "worldboss" or c == "elite" or c == "rareelite" or UnitLevel("target") == -1) and boss ~= lastBoss then boss = nil end
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
function ns.DJItems()
  local fdj = ns.DJ()
  if not fdj then return {} end
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
  if not (S and S.API and S.API.GetInventoryInfoByItemID) then return nil end
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
function ns.ATTWhere(id)
  if not (id and ns.ATT.Available()) then return nil end
  if attCache[id] == nil then
    local s = ns.ATT.Source("itemID", id, 1)
    attCache[id] = (s and s.text) or false
  end
  return attCache[id] or nil
end

----------------------------------------------------------------------
-- BiS : meilleurs objets connus par emplacement (portés, sacs, vus, référence, DungeonJournal)
----------------------------------------------------------------------
function ns.Candidates()
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
function ns.BiS(limit, maxLevel)
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
  return out
end
