local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end

-- Équipement du prêtre soigneur (3.8.0, refait de zéro à la demande du joueur) :
--   * une seule mesure, la valeur en « puissance des soins » avec les poids du simulateur wowsims/forever (Sacré ou
--     Discipline, soins de raid ou mono-cible) : 1 point de soins = 1 ; l'infobulle détaille chaque caractéristique ;
--   * tous les objets de Forever qu'un prêtre peut porter (Items.lua, tiré de wowsims), pas seulement ceux déjà vus :
--     on connaît leurs caractéristiques, leur niveau et leur provenance sans attendre que le jeu les charge ;
--   * « Maintenant » : la meilleure amélioration de chaque emplacement jusqu'à ton niveau + l'écart choisi, et où l'avoir ;
--   * « Objectif 60 » : la liste de référence (kami-labs, calculée avec wowsims), ta progression, et le meilleur calculé
--     quand il diffère (objets de la phase en cours seulement).
-- Les autres classes et rôles gardent l'évaluation par poids de Core.lua.

local P = {}
ns.Priest = P
local L = ns.L
local D = ns.Data

P.PHASE = 1             -- phase de Forever en cours (raids annoncés « le mois prochain » au lancement du 04/11/2026)
P.SPAN = 3              -- « Maintenant » : jusqu'à ton niveau + 3 par défaut

-- Poids de wowsims/forever (ui/specs/priest/healer/presets.ts), 1 = un point de puissance des soins ; l'endurance ne
-- compte que pour départager deux objets égaux.
-- Ordre des caractéristiques dans Items.lua : soins, intelligence, esprit, mp5, critique, hâte, endurance
P.PROFILES = {
  holy_raid = { 1.0, 0.30, 0.25, 0.60, 0.23, 0.48, 0.01 },
  holy_st = { 1.0, 0.35, 0.30, 0.60, 0.30, 0.50, 0.01 },
  disc_raid = { 1.0, 0.20, 0.10, 0.19, 0.48, 0.10, 0.01 },
  disc_st = { 1.0, 0.20, 0.15, 0.40, 0.70, 0.15, 0.01 },
}
P.PROFILE_ORDER = { "holy_raid", "holy_st", "disc_raid", "disc_st" }
P.STAT_KEYS = { "statHeal", "statInt", "statSpi", "statMp5", "statCrit", "statHaste", "statSta" }

-- Caractéristiques lues dans le jeu (objet absent d'Items.lua : vert aléatoire « de soins », nouveauté…)
local CLIENT = {
  ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1, ITEM_MOD_SPELL_POWER_SHORT = 1,
  ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPIRIT_SHORT = 3,
  ITEM_MOD_MANA_REGENERATION_SHORT = 4, ITEM_MOD_POWER_REGEN0_SHORT = 4,
  ITEM_MOD_CRIT_RATING_SHORT = 5, ITEM_MOD_SPELL_CRIT_RATING_SHORT = 5, ITEM_MOD_CRIT_SPELL_RATING_SHORT = 5,
  ITEM_MOD_HASTE_RATING_SHORT = 6, ITEM_MOD_SPELL_HASTE_RATING_SHORT = 6, ITEM_MOD_HASTE_SPELL_RATING_SHORT = 6,
  ITEM_MOD_STAMINA_SHORT = 7,
}

local Info = function(x) return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(x) end
local function ItemID(link) return link and tonumber(tostring(link):match("item:(%d+)")) end

function P.Active()
  local _, class = UnitClass("player")
  if class ~= "PRIEST" or not ns.Items then return false end
  local role = ns.Role()
  return role == nil or role == "heal"
end

function P.Profile()
  local k = ns.db and ns.db.priestProfile
  return (k and P.PROFILES[k]) and k or "holy_raid"
end

-- Caractéristiques { soins, int, esprit, mp5, crit, hâte, endurance } : base intégrée d'abord, sinon le jeu
function P.Stats(x)
  local id = type(x) == "number" and x or ItemID(x)
  local it = id and ns.Items[id]
  if it then return it[7], true end
  if type(x) ~= "string" then return nil end
  local get = (C_Item and C_Item.GetItemStats) or GetItemStats
  local raw = get and get(x)
  if type(raw) ~= "table" then return nil end
  local v = { 0, 0, 0, 0, 0, 0, 0 }
  for k, n in pairs(raw) do
    local i = CLIENT[k]
    -- « puissance des sorts » d'un objet de classique : soins et dégâts ; « soins » seul : la valeur la plus haute gagne
    if i then v[i] = (i == 1) and math.max(v[i], n) or (v[i] + n) end
  end
  return v, false
end

function P.EP(stats, profile)
  if not stats then return 0 end
  local w = P.PROFILES[profile or P.Profile()]
  local s = 0
  for i = 1, 7 do s = s + (w[i] or 0) * (stats[i] or 0) end
  return s
end

function P.ItemEP(x)
  local st = P.Stats(x)
  return P.EP(st), st
end

-- Emplacements du jeu pour un objet de la base (bâton : 16, à deux mains)
local function SlotsOf(code)
  if code == 11 then return { 11, 12 } elseif code == 13 then return { 13, 14 }
  elseif code == 116 then return { 16 }, true end
  return { code }
end
P.SlotsOf = SlotsOf

-- Niveau auquel un objet devient utilisable (récompense sans niveau requis : niveau d'objet - 5). wowsims met souvent 1
-- aux nouveaux objets de Forever (n° 270000 et plus) au lieu du vrai niveau : un objet de niveau 62 « dès le niveau 1 »
-- (22/11/2026) ; 1 ou 0 avec un niveau d'objet au-dessus de 10 est donc remplacé par niveau d'objet - 5.
function P.ReqLevel(id)
  local it = ns.Items[id]
  if not it then return nil end
  if it[2] > 1 or (it[2] == 1 and (it[3] or 0) <= 10) then return it[2] end
  return math.max(1, (it[3] or 1) - 5)
end

-- Sait-on où l'obtenir ? (provenance de wowsims, ou lieu connu d'All The Things)
function P.Known(id)
  local it = ns.Items[id]
  if it and #it[9] > 0 then return true end
  return (ns.HasPlace and ns.HasPlace(id)) and true or false
end

local function MyFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return (f == "Alliance" and 1) or (f == "Horde" and 2) or 0
end

-- Peut-on l'obtenir ? (faction, phase, provenances : JcJ seul exclu, marchand ou réputation de l'autre camp exclus)
function P.Obtainable(id)
  local it = ns.Items[id]
  if not it then return true end
  local me = MyFaction()
  if it[5] > P.PHASE then return false, "phase" end
  if it[6] ~= 0 and me ~= 0 and it[6] ~= me then return false, "faction" end
  local src = it[9]
  if #src == 0 then return true end
  for _, s in ipairs(src) do
    local k = s[1]                                   -- JcJ seul : jamais proposé
    if k == "vendor" then if s[5] == 0 or me == 0 or s[5] == me then return true end
    elseif k == "rep" then if s[4] == 0 or me == 0 or s[4] == me then return true end
    elseif k == "quest" then if s[4] == 0 or me == 0 or s[4] == me then return true end
    elseif k ~= "pvp" then return true end
  end
  return false, "source"
end

----------------------------------------------------------------------
-- Provenance en clair (dans ta langue quand le jeu la donne)
----------------------------------------------------------------------
local PROF = { tailoring = 197, leatherworking = 165, enchanting = 333, blacksmithing = 164, engineering = 202, alchemy = 171 }
local PROF_FR = { tailoring = "Couture", leatherworking = "Travail du cuir", enchanting = "Enchantement", blacksmithing = "Forge",
                  engineering = "Ingénierie", alchemy = "Alchimie", other = "Artisanat" }
local PROF_EN = { tailoring = "Tailoring", leatherworking = "Leatherworking", enchanting = "Enchanting", blacksmithing = "Blacksmithing",
                  engineering = "Engineering", alchemy = "Alchemy", other = "Crafted" }
local REP_FR = { [4] = "neutre", [5] = "amical", [6] = "honoré", [7] = "révéré", [8] = "exalté" }
local REP_EN = { [4] = "Neutral", [5] = "Friendly", [6] = "Honored", [7] = "Revered", [8] = "Exalted" }

local function ZoneName(zoneId)
  if not zoneId or zoneId == 0 then return nil end
  if C_Map and C_Map.GetAreaInfo then
    local ok, n = pcall(C_Map.GetAreaInfo, zoneId)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  return ns.ItemZones and ns.ItemZones[zoneId]
end
local function NpcName(id, fallback)
  if id and id > 0 and ns.ATT and ns.ATT.NpcName then
    local ok, n = pcall(ns.ATT.NpcName, id)
    if ok and n then return n end
  end
  return fallback ~= "" and fallback or nil
end
local function QuestName(id, fallback)
  if id and id > 0 and ns.ATT and ns.ATT.QuestName then
    local ok, n = pcall(ns.ATT.QuestName, id)
    if ok and n then return n end
  end
  return fallback ~= "" and fallback or nil
end

-- Une provenance : texte, genre (boss, trash, quest, vendor, craft, rep, world, pvp), lieu (zone) ; la plus utile d'abord
function P.Sources(id)
  local it = ns.Items[id]
  local out = {}
  if not it then return out end
  local me = MyFaction()
  for _, s in ipairs(it[9]) do
    local k, e = s[1], nil
    if k == "drop" then
      local zone = ZoneName(s[3])
      local who = (s[2] > 0) and NpcName(s[2], s[4]) or nil
      if s[4] == "Trash" or (not who and zone) then
        e = { kind = "trash", text = string.format(L.srcTrash, zone or "?"), zone = zone, zoneId = s[3] }
      elseif zone then e = { kind = "boss", text = (who or "?") .. " — " .. zone, zone = zone, zoneId = s[3] }
      else e = { kind = "world", text = L.srcWorld } end
    elseif k == "quest" and (s[4] == 0 or me == 0 or s[4] == me) then
      e = { kind = "quest", text = string.format(L.srcQuestNamed, QuestName(s[2], s[3]) or "?"), quest = s[2] }
    elseif k == "vendor" and (s[5] == 0 or me == 0 or s[5] == me) then
      local zone = ZoneName(s[3])
      e = { kind = "vendor", text = string.format(L.srcVendorNamed, NpcName(s[2], s[4]) or "?") .. (zone and (" — " .. zone) or ""), zone = zone }
    elseif k == "craft" then
      e = { kind = "craft", text = string.format(L.srcCraft, (ns.lang ~= "en" and PROF_FR or PROF_EN)[s[2]] or s[2]), prof = PROF[s[2]] }
    elseif k == "rep" and (s[4] == 0 or me == 0 or s[4] == me) then
      local fname = ns.ItemFactions and ns.ItemFactions[s[2]] or "?"
      if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, fd = pcall(C_Reputation.GetFactionDataByID, s[2])
        if ok and type(fd) == "table" and fd.name then fname = fd.name end
      end
      e = { kind = "rep", text = string.format(L.srcRep, fname, (ns.lang ~= "en" and REP_FR or REP_EN)[s[3]] or tostring(s[3])) }
    elseif k == "pvp" then e = { kind = "pvp", text = L.srcPvp } end
    if e then out[#out + 1] = e end
  end
  local rank = { boss = 1, quest = 2, vendor = 3, trash = 4, craft = 5, rep = 6, world = 7, pvp = 8 }
  table.sort(out, function(a, b) return (rank[a.kind] or 9) < (rank[b.kind] or 9) end)
  return out
end

function P.SourceText(id)
  local s = P.Sources(id)
  if #s == 0 then return ns.ATTWhere and ns.ATTWhere(id) or nil end
  local t = s[1].text
  if #s > 1 then t = t .. string.format(L.srcMore, #s - 1) end
  return t
end

-- Lien utilisable tout de suite (le jeu n'a pas toujours chargé l'objet : lien construit avec le nom de la base)
function P.Link(id)
  local _, link = Info(id)
  if link then return link end
  local it = ns.Items[id]
  local q = it and it[4] or 1
  local col = ({ [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" })[q] or "ffffffff"
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return "|c" .. col .. "|Hitem:" .. id .. "::::::::::::|h[" .. (it and it[8] or ("item " .. id)) .. "]|h|r"
end

----------------------------------------------------------------------
-- Ce que tu portes, et le gain d'un objet
----------------------------------------------------------------------
local function WornEP(slot)
  local l = GetInventoryItemLink("player", slot)
  return l and P.ItemEP(l) or 0, l
end

-- Gain d'un objet (n° ou lien) par rapport à ce que tu portes : (gain, emplacement remplacé)
function P.Gain(x)
  local id = type(x) == "number" and x or ItemID(x)
  local it = id and ns.Items[id]
  local code
  if it then code = it[1]
  else
    local _, _, _, equipLoc = ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(x)
    local s = equipLoc and D.slots[equipLoc]
    if not s then return nil end
    code = s.two and 116 or s[1]
  end
  local ep = P.ItemEP(it and id or x)
  local slots, two = SlotsOf(code)
  if two then
    return ep - WornEP(16) - WornEP(17), 16
  end
  if #slots == 2 then
    local a, la = WornEP(slots[1])
    local b, lb = WornEP(slots[2])
    if ItemID(la) == id or ItemID(lb) == id then return 0, slots[1] end      -- déjà porté
    if a <= b then return ep - a, slots[1] end
    return ep - b, slots[2]
  end
  if code == 17 then
    -- main gauche avec un bâton : il faudrait aussi une arme à une main (voir « Armes »)
    local main = GetInventoryItemLink("player", 16)
    local mid = ItemID(main)
    if mid and ns.Items[mid] and ns.Items[mid][1] == 116 then return ep - WornEP(16), 17, true end
  end
  return ep - WornEP(slots[1]), slots[1]
end

-- Même forme que ns.Evaluate (Core.lua) : utilisé par les infobulles, jets de butin, quêtes, alertes
function P.Evaluate(link)
  local id = ItemID(link)
  local gain, slot, pair = P.Gain(id and ns.Items[id] and id or link)
  if not gain then return nil end
  local ep, st = P.ItemEP(id and ns.Items[id] and id or link)
  local wear = ns.Wearable(link)
  if id and ns.Items[id] then wear = true end
  return { wearable = wear, method = "ep", slot = slot, score = gain, ep = ep, stats = st, pair = pair,
           minLevel = (id and P.ReqLevel(id)) or select(5, Info(link)) }
end

----------------------------------------------------------------------
-- Candidats : base intégrée + sacs (objets hors base : verts aléatoires, nouveautés)
----------------------------------------------------------------------
local function Bags()
  local out = {}
  for bag = 0, 4 do
    local n = (C_Container and C_Container.GetContainerNumSlots) and C_Container.GetContainerNumSlots(bag)
              or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
    for s = 1, n do
      local l = (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(bag, s)
                or (GetContainerItemLink and GetContainerItemLink(bag, s))
      if l then out[#out + 1] = l end
    end
  end
  return out
end

local memo
function P.Forget() memo = nil end

-- slot -> { items = { c } } trié par gain, jusqu'au niveau maxLevel (nil : objectif 60), comme ns.BiS
function P.BiS(limit, maxLevel)
  local key = tostring(limit) .. ":" .. tostring(maxLevel) .. ":" .. P.Profile() .. ":" .. tostring(UnitLevel("player"))
              .. ":" .. tostring(ns.version)
  if memo and memo.k == key and GetTime() - memo.t < 10 then return memo.v end
  local out = {}
  local inBags = {}
  local function push(c)
    local slot = c.eval.slot
    slot = (slot == 12) and 11 or ((slot == 14) and 13 or slot)
    out[slot] = out[slot] or { items = {}, refs = {} }
    table.insert(out[slot].items, c)
  end
  local equipped = {}
  for s = 1, 18 do local id = ItemID(GetInventoryItemLink("player", s)); if id then equipped[id] = true end end
  for _, l in ipairs(Bags()) do
    local id = ItemID(l)
    if id and not inBags[id] and not equipped[id] then
      local r = P.Evaluate(l)
      local req = r and (r.minLevel or 0) or 999
      if r and r.wearable and r.score > ns.MIN_GAIN and req <= (maxLevel or 60) then
        inBags[id] = true
        push({ link = l, id = id, src = "bags", eval = r, where = ns.Items[id] and P.SourceText(id) or nil })
      end
    end
  end
  for id in pairs(ns.Items) do
    if not inBags[id] and not equipped[id] then
      local req = P.ReqLevel(id)
      if req <= (maxLevel or 60) and P.Obtainable(id) and P.Known(id) then
        local gain, slot, pair = P.Gain(id)
        if gain and gain > ns.MIN_GAIN then
          -- lien et provenance seulement pour les objets gardés (plus bas) : pas des centaines de demandes au jeu
          push({ id = id, src = "data", eval = { wearable = true, method = "ep", slot = slot, score = gain, pair = pair,
                 ep = (P.ItemEP(id)), stats = ns.Items[id][7], minLevel = req } })
        end
      end
    end
  end
  for _, s in pairs(out) do
    table.sort(s.items, function(a, b)
      if a.src ~= b.src and (a.src == "bags" or b.src == "bags") and math.abs(a.eval.score - b.eval.score) < 1 then return a.src == "bags" end
      return a.eval.score > b.eval.score
    end)
    while #s.items > (limit or 3) do table.remove(s.items) end
    for _, c in ipairs(s.items) do
      if not c.link then c.link = P.Link(c.id) end
      if c.where == nil then c.where = P.SourceText(c.id) or false end
    end
  end
  memo = { k = key, t = GetTime(), v = out }
  return out
end

----------------------------------------------------------------------
-- Objectif 60 : la référence, ta progression, et le meilleur calculé
----------------------------------------------------------------------
local function Have(id)
  for s = 1, 18 do if ItemID(GetInventoryItemLink("player", s)) == id then return "worn" end end
  for _, l in ipairs(Bags()) do if ItemID(l) == id then return "bags" end end
  local o = ns.Owned and ns.Owned(id)
  if o then return "owned", o end
  return nil
end
P.Have = Have

-- { { slot, ref = entrée de D.reference (ou nil), refHave, best = { id, ep } (meilleur obtenable niveau 60, phase en cours) } }
function P.Goal()
  local rows, bySlot = {}, {}
  for _, slot in ipairs(D.slotOrder) do
    local row = { slot = slot, refs = {} }
    bySlot[slot] = row
    rows[#rows + 1] = row
  end
  for _, r in ipairs(D.reference.PRIEST or {}) do
    local slot = (r.slot == 12) and 11 or ((r.slot == 14) and 13 or r.slot)
    if bySlot[slot] then table.insert(bySlot[slot].refs, r) end
  end
  local best = {}
  for id, it in pairs(ns.Items) do
    if P.Obtainable(id) and P.Known(id) then
      for _, s in ipairs(SlotsOf(it[1])) do
        local slot = (s == 12) and 11 or ((s == 14) and 13 or s)
        if s ~= 12 and s ~= 14 then          -- anneaux et bijoux : comptés une fois
          local ep = P.ItemEP(id)
          best[slot] = best[slot] or {}
          table.insert(best[slot], { id = id, ep = ep })
        end
      end
    end
  end
  for slot, list in pairs(best) do
    table.sort(list, function(a, b) return a.ep > b.ep end)
    if bySlot[slot] then bySlot[slot].best = { list[1], list[2] } end
  end
  return rows
end

-- Détail d'un gain : « +12 soins, +4 mp5 (×0,6) … »
function P.Detail(stats, ref)
  if not stats then return "" end
  local w = P.PROFILES[P.Profile()]
  local parts = {}
  for i = 1, 6 do
    local v = (stats[i] or 0) - (ref and ref[i] or 0)
    if math.abs(v) >= 1 then
      parts[#parts + 1] = string.format("%s%d %s", v > 0 and "+" or "", v, L[P.STAT_KEYS[i]]) .. (i > 1 and string.format(" (×%s)", tostring(w[i]):gsub("%.", ",")) or "")
    end
  end
  return table.concat(parts, ", ")
end

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function() P.Forget() end)
end
