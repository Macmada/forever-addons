local ADDON, ns = ...
local L = ns.L
local D = ns.Data

-- Analyse « prêt pour le donjon ? » : consommables, composants, améliorations, équipement, personnage.
-- Résultat : { context, role, level, sections = { { key, rows = { status, icon, text, buyID, buyQty } } }, shopping, worst }
-- status : "ok", "info" (conseil), "warn" (à faire), "bad" (manque important).

local db
local RANK = { ok = 0, info = 1, warn = 2, bad = 3 }
ns.RANK = RANK

function ns.Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cff7fd4ffForeverPrep|r " .. msg)
end

----------------------------------------------------------------------
-- Objets et sorts (avec repli entre les versions de l'API)
----------------------------------------------------------------------
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local pendingItems = {}

-- name, niveau requis, icône ; nil si l'objet n'existe pas dans ce client
function ns.Item(id, hintLevel)
  local _, _, _, _, icon = GetInstant(id)
  if not icon then return nil end
  local name, _, _, _, minLevel = GetInfo(id)
  if not name then
    pendingItems[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return { id = id, name = "#" .. id, level = hintLevel or 1, icon = icon, loading = true }
  end
  return { id = id, name = name, level = (minLevel and minLevel > 0) and minLevel or (hintLevel or 1), icon = icon }
end

function ns.Count(id) return GetCount(id) or 0 end

function ns.SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return (GetSpellInfo(id))
end

-- Sort connu (ce rang précis)
function ns.KnowsRank(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  return IsSpellKnown and IsSpellKnown(id) or false
end

-- Sort connu, n'importe quel rang (recherche par nom dans le grimoire)
function ns.KnowsAny(list)
  for _, id in ipairs(list) do
    if ns.KnowsRank(id) then return true end
    local name = ns.SpellName(id)
    if name then
      local info
      if C_Spell and C_Spell.GetSpellInfo then info = C_Spell.GetSpellInfo(name) else info = GetSpellInfo(name) end
      if info then return true end
    end
  end
  return false
end

-- Noms des améliorations présentes sur une unité
function ns.Buffs(unit)
  local names = {}
  for i = 1, 40 do
    local name
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
      name = a and a.name
    elseif UnitBuff then
      name = UnitBuff(unit, i)
    end
    if not name then break end
    names[name] = true
  end
  return names
end

local function HasAny(buffs, spells)
  for _, id in ipairs(spells) do
    local n = ns.SpellName(id)
    if n and buffs[n] then return true end
  end
  return false
end

-- Toi et les membres du groupe présents (connectés, vivants, visibles)
function ns.GroupUnits()
  local units = { "player" }
  local raid = IsInRaid and IsInRaid()
  local n = raid and ((GetNumGroupMembers and GetNumGroupMembers()) or 0) or 4
  for i = 1, n do
    local u = (raid and "raid" or "party") .. i
    if UnitExists(u) and not UnitIsUnit(u, "player") and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsVisible(u) then
      units[#units + 1] = u
    end
  end
  return units
end

----------------------------------------------------------------------
-- Contexte et rôle
----------------------------------------------------------------------
function ns.Context()
  local inInstance, itype = IsInInstance()
  if inInstance and itype == "raid" then return "raid" end
  if inInstance and itype == "party" then return "dungeon" end
  return db and db.context or "dungeon"
end

function ns.AutoRole(class)
  local map = D.roleByTree[class]
  if not map then return "melee" end
  local best, bestPts = 1, -1
  if GetNumTalentTabs and GetTalentTabInfo then
    for i = 1, GetNumTalentTabs() do
      -- classique : nom, icône, points dépensés ; versions récentes : id, nom, description, icône, points
      local r = { GetTalentTabInfo(i) }
      local pts = (type(r[1]) == "string" and tonumber(r[3])) or tonumber(r[5]) or 0
      if pts > bestPts then best, bestPts = i, pts end
    end
  end
  if bestPts <= 0 then
    -- sans talents : classes de soin/mana -> caster, sinon melee
    if class == "PRIEST" then return "heal" end
    if class == "MAGE" or class == "WARLOCK" or class == "DRUID" or class == "SHAMAN" then return "caster" end
    return "melee"
  end
  return map[best] or "melee"
end

function ns.Role()
  local class = select(2, UnitClass("player"))
  if db and db.role and db.role ~= "auto" then return db.role end
  return ns.AutoRole(class)
end

----------------------------------------------------------------------
-- Lignes
----------------------------------------------------------------------
local function Status(have, need, optional)
  if have >= need then return "ok" end
  if optional then return "info" end
  if have >= math.ceil(need / 2) then return "warn" end
  return "bad"
end

-- Meilleur objet utilisable d'une liste, et total possédé (tous rangs utilisables, + extras)
local function Pool(list, extras, level)
  local best, have, any = nil, 0, false
  for _, e in ipairs(list or {}) do
    local it = ns.Item(e[1], e[2])
    if it then
      any = true
      if it.level <= level then
        have = have + ns.Count(e[1])
        if not best or it.level >= best.level then best = it end
      end
    end
  end
  for _, e in ipairs(extras or {}) do
    local it = ns.Item(e[1], e[2])
    if it and it.level <= level then have = have + ns.Count(e[1]) end
  end
  return best, have, any
end

local function CountRow(label, best, have, need, optional, noBuy)
  local st = Status(have, need, optional)
  local row = { status = st, icon = best and best.icon, have = have, need = need }
  local name = best and best.name or "?"   -- meilleur rang utilisable (à égalité de niveau : le dernier de la liste)
  if st == "ok" then
    row.text = string.format(L.rowOk, label, have, need)
  elseif noBuy or not best then
    row.text = string.format(L.rowMissingNoBuy, label, have, need)
  else
    row.text = string.format(L.rowMissing, label, have, need, need - have, name)
    row.buyID, row.buyQty, row.buyName = best.id, need - have, best.name
  end
  row.itemID = best and best.id
  return row
end

----------------------------------------------------------------------
-- Analyse
----------------------------------------------------------------------
function ns.Analyze(ctx, roleOverride)
  ctx = ctx or ns.Context()
  local ci = (ctx == "raid") and 2 or 1
  local level = UnitLevel("player")
  local class = select(2, UnitClass("player"))
  local role = roleOverride or ns.Role()
  local mana = D.manaClass[class]
  local res = { context = ctx, role = role, level = level, class = class, sections = {}, shopping = {} }
  local function Section(key)
    local s = { key = key, rows = {} }
    res.sections[#res.sections + 1] = s
    return s
  end

  -- 1. Consommables
  local cons = Section("consumables")
  for _, cat in ipairs(D.consumables) do
    if (not cat.mana or mana) and level >= (cat.minLevel or 1) then
      local best, have, any = Pool(cat.items, cat.extra, level)
      if any then
        cons.rows[#cons.rows + 1] = CountRow(L["cat_" .. cat.key], best, have, cat.need[ci], cat.optional, cat.noBuy)
      end
    end
  end
  -- élixirs : en raid, ou en donjon à partir du niveau 50 (conseil)
  if ctx == "raid" or level >= 50 then
    local best, have = Pool(D.elixirs[role], nil, level)
    if best then
      cons.rows[#cons.rows + 1] = CountRow(L.cat_elixir, best, have, D.elixirNeed[ci], ctx ~= "raid")
    end
  end

  -- 2. Composants de classe (et munitions, poisons)
  local reag = Section("reagents")
  for _, r in ipairs(D.reagents[class] or {}) do
    local need = r.need[ci]
    if need > 0 and ns.KnowsAny(r.spells) and not (r.unless and ns.KnowsAny(r.unless)) then
      local it = ns.Item(r.item)
      if it then
        reag.rows[#reag.rows + 1] = CountRow(it.name, it, ns.Count(r.item), need)
      end
    end
  end
  if class == "ROGUE" and level >= 20 then
    local best, have = Pool(D.poisons, nil, level)
    if best then reag.rows[#reag.rows + 1] = CountRow(L.cat_poison, best, have, D.poisonNeed[ci]) end
  end
  if class == "HUNTER" then
    local link = GetInventoryItemLink("player", 18)
    if link then
      local _, _, _, _, _, classID, subID = GetInstant(link)
      local kind = (classID == 2 and (subID == 2 or subID == 18)) and "arrow" or ((classID == 2 and subID == 3) and "bullet") or nil
      if kind then
        local best, have = Pool(D.ammo[kind], nil, level)
        if best then reag.rows[#reag.rows + 1] = CountRow(L["cat_" .. kind], best, have, D.ammoNeed[ci]) end
      end
    end
  end

  -- 3. Améliorations
  local buffs = Section("buffs")
  local mine = ns.Buffs("player")
  for _, b in ipairs(D.buffs[class] or {}) do
    if (not b.role or b.role == role) and level >= (b.minLevel or 1) then
      if b.pet then
        local petSpells = (class == "HUNTER") and { 883 } or { 688, 697, 712, 691 }   -- Appel du familier / démons
        if ns.KnowsAny(petSpells) then
          if not UnitExists("pet") then
            buffs.rows[#buffs.rows + 1] = { status = "warn", text = L.petMissing }
          elseif b.happy and GetPetHappiness and (GetPetHappiness() or 3) < 3 then
            buffs.rows[#buffs.rows + 1] = { status = "warn", text = L.petUnhappy }
          else
            buffs.rows[#buffs.rows + 1] = { status = "ok", text = L.petOk }
          end
        end
      elseif b.weapon then
        local hasMH = GetWeaponEnchantInfo and GetWeaponEnchantInfo()
        local label = b.poisons and L.weaponPoison or L.weaponImbue
        buffs.rows[#buffs.rows + 1] = { status = hasMH and "ok" or "warn",
                                        text = hasMH and string.format(L.buffOk, label) or string.format(L.buffMissing, label) }
      elseif ns.KnowsAny(b.spells) then
        local name = ns.SpellName(b.spells[1]) or "?"
        local icon = GetSpellTexture and GetSpellTexture(b.spells[1])
        if b.self then
          local ok = HasAny(mine, b.spells)
          buffs.rows[#buffs.rows + 1] = { status = ok and "ok" or "warn", icon = icon,
                                          text = ok and string.format(L.buffOk, name) or string.format(L.buffMissing, name) }
        elseif b.group then
          local missing = {}
          for _, u in ipairs(ns.GroupUnits()) do
            if not HasAny(ns.Buffs(u), b.spells) then missing[#missing + 1] = UnitName(u) end
          end
          if #missing == 0 then
            buffs.rows[#buffs.rows + 1] = { status = "ok", icon = icon, text = string.format(L.groupBuffOk, name) }
          else
            buffs.rows[#buffs.rows + 1] = { status = "warn", icon = icon,
                                            text = string.format(L.groupBuffMissing, name, table.concat(missing, ", ")) }
          end
        end
      end
    end
  end
  -- amélioration d'arme (pierre, huile) : conseil pour les rôles qui en profitent
  local boostRole = (role == "tank") and "melee" or role
  if (class == "WARRIOR" or class == "PALADIN" or ((class == "MAGE" or class == "WARLOCK" or class == "PRIEST" or class == "DRUID") and role ~= "tank" and role ~= "melee"))
     and D.weaponBoost[boostRole] then
    local hasMH = GetWeaponEnchantInfo and GetWeaponEnchantInfo()
    local best, have = Pool(D.weaponBoost[boostRole], nil, level)
    if best and not hasMH then
      local row = { status = "info", icon = best.icon, itemID = best.id }
      if have > 0 then row.text = string.format(L.boostApply, best.name)
      else
        row.text = string.format(L.boostBuy, best.name)
        row.buyID, row.buyQty, row.buyName = best.id, (ci == 2) and 3 or 1, best.name
      end
      buffs.rows[#buffs.rows + 1] = row
    end
  end

  -- 4. Équipement
  local gear = Section("gear")
  local minPct = 100
  for slot = 1, 18 do
    local cur, max = GetInventoryItemDurability(slot)
    if cur and max and max > 0 then
      local pct = math.floor(cur * 100 / max)
      if pct < minPct then minPct = pct end
    end
  end
  local durBad = (ctx == "raid") and 50 or 25
  gear.rows[#gear.rows + 1] = { status = (minPct < durBad and "bad") or (minPct < 60 and "warn") or "ok",
                                text = string.format(minPct < 60 and L.durabilityLow or L.durabilityOk, minPct) }
  local free, total = 0, 0
  for bag = 0, 4 do
    local f = (C_Container and C_Container.GetContainerNumFreeSlots) and C_Container.GetContainerNumFreeSlots(bag)
              or (GetContainerNumFreeSlots and GetContainerNumFreeSlots(bag)) or 0
    local t = (C_Container and C_Container.GetContainerNumSlots) and C_Container.GetContainerNumSlots(bag)
              or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
    free, total = free + (f or 0), total + (t or 0)
  end
  gear.rows[#gear.rows + 1] = { status = (free == 0 and "bad") or (free < 4 and "warn") or "ok",
                                text = string.format(L.bags, free, total) }
  if level >= 20 then
    local empty = {}
    for _, slot in ipairs({ 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }) do
      if not GetInventoryItemLink("player", slot) then empty[#empty + 1] = L["slot" .. slot] or tostring(slot) end
    end
    if #empty > 0 then
      gear.rows[#gear.rows + 1] = { status = "info", text = string.format(L.emptySlots, table.concat(empty, ", ")) }
    end
  end

  -- 5. Personnage
  local char = Section("character")
  local unspent = 0
  if UnitCharacterPoints then unspent = UnitCharacterPoints("player") or 0
  elseif GetUnspentTalentPoints then unspent = GetUnspentTalentPoints() or 0 end
  if level >= 10 then
    char.rows[#char.rows + 1] = { status = unspent > 0 and "warn" or "ok",
                                  text = unspent > 0 and string.format(L.talentsUnspent, unspent) or L.talentsOk }
  end
  if level >= 4 then
    local last = db and db.lastTrainerLevel
    if not last then
      char.rows[#char.rows + 1] = { status = "info", text = L.trainerUnknown }
    elseif level >= last + 2 then
      char.rows[#char.rows + 1] = { status = "warn", text = string.format(L.trainerDue, last) }
    else
      char.rows[#char.rows + 1] = { status = "ok", text = string.format(L.trainerOk, last) }
    end
  end
  local hs = ns.Count(D.HEARTHSTONE)
  if hs == 0 then
    char.rows[#char.rows + 1] = { status = "info", text = L.hearthMissing }
  else
    local start, dur = GetItemCooldown(D.HEARTHSTONE)
    local left = (start and start > 0 and dur) and (start + dur - GetTime()) or 0
    char.rows[#char.rows + 1] = { status = left > 60 and "info" or "ok",
                                  text = left > 60 and string.format(L.hearthCooldown, math.ceil(left / 60)) or L.hearthOk }
  end

  -- liste de courses et état général
  local worst = "ok"
  for _, s in ipairs(res.sections) do
    for _, r in ipairs(s.rows) do
      if RANK[r.status] > RANK[worst] then worst = r.status end
      if r.buyID and r.buyQty and r.buyQty > 0 then
        res.shopping[#res.shopping + 1] = { id = r.buyID, qty = r.buyQty, name = r.buyName, icon = r.icon }
      end
    end
  end
  res.worst = worst
  return res
end

----------------------------------------------------------------------
-- Base, événements
----------------------------------------------------------------------
local function InitDB()
  ForeverPrepDB = ForeverPrepDB or {}
  db = ForeverPrepDB
  ns.db = db
  db.version = db.version or 1
  db.role = db.role or "auto"
  db.context = db.context or "dungeon"
  if db.autoInstance == nil then db.autoInstance = true end
  if db.autoReady == nil then db.autoReady = true end
  if db.autoLFG == nil then db.autoLFG = true end
  if db.merchant == nil then db.merchant = true end
  db.minimap = db.minimap or { angle = 160, hide = false }
  if db.lang then ns.lang = db.lang end
end
ns._InitDB = InitDB

local ev = CreateFrame("Frame")
ns.eventFrame = ev
local handlers = {}
local lastAuto = {}

-- Ouverture automatique : seulement s'il manque quelque chose, et pas plus d'une fois par 10 min par motif
function ns.AutoShow(reason, key)
  if not db then return end
  key = reason .. ":" .. tostring(key or "")
  if lastAuto[key] and GetTime() - lastAuto[key] < 600 then return end
  local res = ns.Analyze()
  if RANK[res.worst] < RANK.warn then return end
  lastAuto[key] = GetTime()
  if ns.Show then ns.Show(res, reason) end
end

handlers.PLAYER_ENTERING_WORLD = function()
  local inInstance, itype = IsInInstance()
  if db.autoInstance and inInstance and (itype == "party" or itype == "raid") then
    C_Timer.After(4, function() ns.AutoShow("instance", GetRealZoneText()) end)
  end
end
handlers.ZONE_CHANGED_NEW_AREA = handlers.PLAYER_ENTERING_WORLD
handlers.READY_CHECK = function() if db.autoReady then ns.AutoShow("ready", GetTime()) end end
local function LFG() if db.autoLFG then ns.AutoShow("lfg") end end
handlers.LFG_UPDATE = LFG
handlers.LFG_PROPOSAL_SHOW = LFG
handlers.LFG_LIST_ACTIVE_ENTRY_UPDATE = function(created) if created then LFG() end end
handlers.TRAINER_SHOW = function()
  db.lastTrainerLevel = UnitLevel("player")
  if ns.Refresh then ns.Refresh() end
end
handlers.PLAYER_LEVEL_UP = function() if ns.Refresh then C_Timer.After(1, ns.Refresh) end end
handlers.MERCHANT_SHOW = function() if db.merchant and ns.OnMerchant then ns.OnMerchant() end end
handlers.MERCHANT_CLOSED = function() if ns.OnMerchantClosed then ns.OnMerchantClosed() end end
local refreshPending
local function SoonRefresh()
  if refreshPending or not ns.Refresh then return end
  refreshPending = true
  C_Timer.After(0.5, function() refreshPending = nil; ns.Refresh() end)
end
handlers.BAG_UPDATE_DELAYED = SoonRefresh
handlers.UNIT_AURA = function(unit) if unit == "player" then SoonRefresh() end end
handlers.GET_ITEM_INFO_RECEIVED = function(id)
  if id and pendingItems[id] then pendingItems[id] = nil; SoonRefresh() end
end
handlers.PLAYER_LOGIN = function()
  -- fenêtres de recherche de groupe/donjon : la fiche s'ouvre avec elles (seulement s'il manque quelque chose)
  for _, name in ipairs({ "LFGParentFrame", "PVEFrame", "LFGListingFrame", "LFGBrowseFrame", "GroupFinderFrame", "LFDParentFrame" }) do
    local f = _G[name]
    if f and f.HookScript then f:HookScript("OnShow", function() LFG() end) end
  end
  if ns.OnLogin then ns.OnLogin() end
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
