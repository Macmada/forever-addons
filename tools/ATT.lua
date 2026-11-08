local _, ns = ...

-- Où obtenir les objets et les recettes, commun aux parties de ForeverCompagnon (copié par tools/sync-shared.sh).
-- Données intégrées : extrait de la base WoW Forever d'All The Things (licence MIT), Data/Sources.lua, régénéré à chaque
-- version par tools/att_extract.lua : plus besoin d'installer ATT. Les noms (PNJ, zones, donjons, quêtes, monnaies)
-- sont demandés au jeu, dans sa langue, et les noms de PNJ sont gardés une fois connus.
local A = {}
ns.ATT = A

local FR = GetLocale() == "frFR"
local STANDING = { { 42000, FR and "Exalté" or "Exalted" }, { 21000, FR and "Révéré" or "Revered" },
                   { 9000, FR and "Honoré" or "Honored" }, { 3000, FR and "Amical" or "Friendly" }, { 0, FR and "Neutre" or "Neutral" } }
A.SKILL = { tailoring = 197, enchanting = 333, alchemy = 171, blacksmithing = 164, leatherworking = 165, engineering = 202,
            cooking = 185, firstaid = 129, herbalism = 182, mining = 186, skinning = 393, fishing = 356 }
local T = FR and { quest = "quête", object = "objet", npc = "PNJ", crafted = "fabriqué", dungeon = "donjon", raid = "raid",
                   currency = "monnaie #", with = " avec ", gold = "%d po", silver = "%d pa",
                   entrance = "%s (entrée : %s)" }
              or { quest = "quest", object = "object", npc = "NPC", crafted = "crafted", dungeon = "dungeon", raid = "raid",
                   currency = "currency #", with = " with ", gold = "%dg", silver = "%ds",
                   entrance = "%s (entrance: %s)" }

local function DB() local r = ns.root or ns; return r.Sources end
function A.Available() return DB() ~= nil end

-- Faction du joueur au sens d'ATT (champ r : 1 Horde, 2 Alliance)
local function MyR() return UnitFactionGroup("player") == "Horde" and 1 or 2 end
local function Mine(src) local e = src[6]; return not (e and e.r and e.r ~= MyR()) end

----------------------------------------------------------------------
-- Noms, demandés au jeu
----------------------------------------------------------------------
local npcCache = {}
local function NpcCache()
  local r = ns.root or ns
  if r.db then r.db.npcNames = r.db.npcNames or {}; return r.db.npcNames end
  return npcCache
end
function A.NpcName(id)
  if not id or id <= 0 then return nil end
  local cache = NpcCache()
  if cache[id] then return cache[id] end
  local TI = C_TooltipInfo
  if TI and TI.GetHyperlink then
    local ok, data = pcall(TI.GetHyperlink, "unit:Creature-0-0-0-0-" .. id .. "-0000000000")
    local line = ok and type(data) == "table" and data.lines and data.lines[1]
    local name = line and line.leftText
    if type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then
      cache[id] = name
      return name
    end
  end
end
function A.MapName(id)
  if not id or id <= 0 or not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, id)
  return ok and type(info) == "table" and info.name or nil
end
-- Noms des donjons et raids (numéros du journal des donjons, absent du client de Forever) : sans eux, on n'aurait que la
-- zone de l'entrée (« Forêt des Pins argentés » au lieu du Donjon d'Ombrecroc)
local INSTANCES = {
  [63] = { "Les Mortemines", "The Deadmines" }, [64] = { "Donjon d'Ombrecroc", "Shadowfang Keep" },
  [226] = { "Gouffre de Ragefeu", "Ragefire Chasm" }, [227] = { "Profondeurs de Brassenoire", "Blackfathom Deeps" },
  [228] = { "Profondeurs de Rochenoire", "Blackrock Depths" }, [229] = { "Pic de Rochenoire", "Blackrock Spire" },
  [230] = { "Hache-Tripes", "Dire Maul" }, [231] = { "Gnomeregan", "Gnomeregan" }, [232] = { "Maraudon", "Maraudon" },
  [233] = { "Souilles de Tranchebauge", "Razorfen Downs" }, [234] = { "Kraal de Tranchebauge", "Razorfen Kraul" },
  [236] = { "Stratholme", "Stratholme" }, [237] = { "Le temple d'Atal'Hakkar", "The Temple of Atal'Hakkar" },
  [238] = { "La Prison", "The Stockade" }, [239] = { "Uldaman", "Uldaman" },
  [240] = { "Cavernes des Lamentations", "Wailing Caverns" }, [241] = { "Zul'Farrak", "Zul'Farrak" },
  [246] = { "Scholomance", "Scholomance" }, [316] = { "Monastère Écarlate", "Scarlet Monastery" },
  [760] = { "Repaire d'Onyxia", "Onyxia's Lair" },
}
A.INSTANCES = INSTANCES
function A.InstanceName(id)
  if EJ_GetInstanceInfo then
    local ok, name = pcall(EJ_GetInstanceInfo, id)
    if ok and type(name) == "string" and name ~= "" then return name end
  end
  local known = INSTANCES[id]
  if known then return known[FR and 1 or 2] end
  -- donjon propre à Forever, sans nom connu : « donjon (entrée : Les Paluns) », jamais le seul nom de la zone
  local inst = DB() and DB().instances[id]
  local zone = inst and A.MapName(inst[1])
  local what = inst and inst[5] == 1 and T.raid or T.dungeon
  return zone and string.format(T.entrance, what, zone) or nil
end
function A.QuestName(id)
  local Q = C_QuestLog
  if not (Q and Q.GetTitleForQuestID) then return nil end
  local ok, t = pcall(Q.GetTitleForQuestID, id)
  if ok and type(t) == "string" and t ~= "" then return t end
  if Q.RequestLoadQuestByID then pcall(Q.RequestLoadQuestByID, id) end
end
local function ItemName(id)
  local n = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id)
  if not n and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  return n or ("#" .. id)
end
local function FactionName(id)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, id)
    if ok and type(d) == "table" and d.name then return d.name end
  end
  if GetFactionInfoByID then return (GetFactionInfoByID(id)) end
end
local function Money(c)
  local g, s = math.floor(c / 10000), math.floor(c / 100) % 100
  if g > 0 then return string.format(T.gold, g) end
  return string.format(T.silver, s)
end

-- Coût et réputation lisibles : « 120 Faveur marchande, Amical avec Administration commerciale d'Azeroth »
local function Extra(e)
  if not e then return nil end
  local out = {}
  for _, c in ipairs(e.cost or {}) do
    if c[1] == "c" then
      local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(c[2])
      out[#out + 1] = (c[3] or 1) .. " " .. ((info and info.name) or (T.currency .. tostring(c[2])))
    elseif c[1] == "i" then out[#out + 1] = (c[3] or 1) .. " " .. ItemName(c[2])
    elseif c[1] == "g" and type(c[2]) == "number" then out[#out + 1] = Money(c[2]) end
  end
  local rep = e.rep
  if type(rep) == "table" and rep[1] then
    local st = STANDING[#STANDING][2]
    for _, s in ipairs(STANDING) do if (rep[2] or 0) >= s[1] then st = s[2]; break end end
    out[#out + 1] = st .. T.with .. (FactionName(rep[1]) or ("#" .. rep[1]))
  end
  return #out > 0 and table.concat(out, ", ") or nil
end

-- Lieu d'une source : donjon, sinon zone (carte des coordonnées)
local function Place(src)
  local e = src[6]
  if e and e.inst then return A.InstanceName(e.inst) end
  return A.MapName(src[3])
end

-- Texte d'une source ; good = source précise (PNJ, boss, quête, objet, fabrication)
local function SourceText(src)
  local kind, id = src[1], src[2]
  local e = src[6] or {}
  local who, partial
  if kind == "boss" or kind == "drop" or kind == "vendor" then who = A.NpcName(id); partial = not who; who = who or T.npc
  elseif kind == "quest" then local q = A.QuestName(e.q or id); partial = not q; who = T.quest .. " " .. (q or "")
  elseif kind == "obj" then who = T.object
  elseif kind == "craft" then return T.crafted, true
  else return Place(src), false end
  local place = Place(src)
  local txt = who:gsub("%s+$", "") .. (place and (" — " .. place) or "")
  local extra = Extra(e)
  return txt .. (extra and (" (" .. extra .. ")") or ""), true, partial or not place
end

-- Sources d'un objet (field « itemID ») ou d'une recette (« recipeID », numéro du sort) : texte « … ; … », weak (zone
-- seulement), learnedAt (recettes)
function A.Source(field, id, max)
  local db = DB()
  if not (db and id) then return nil end
  local learnedAt, list
  if field == "recipeID" then
    for _, recs in pairs(db.recipes) do
      local r = recs[id]
      if r then
        learnedAt = r[2]
        if r[3] and r[3] > 0 then list = { { r[5] == "vendor" and "vendor" or "drop", r[3], r[4], 0, 0, { cost = r[6], r = r[7], rep = r[8] } } } end
        if r[1] and r[1] > 0 and db.items[r[1]] then list = db.items[r[1]] end
        break
      end
    end
  else
    list = db.items[id]
  end
  local paths, seen, weak, partial = {}, {}, nil, false
  for _, src in ipairs(list or {}) do
    if Mine(src) then
      local txt, good, part = SourceText(src)
      partial = partial or (good and part)
      if txt and good and not seen[txt] then seen[txt] = true; paths[#paths + 1] = txt
      elseif txt and not weak then weak = txt end
    end
  end
  while #paths > (max or 2) do table.remove(paths) end
  if #paths == 0 and not learnedAt and not weak then return nil end
  return { text = #paths > 0 and table.concat(paths, " ; ") or nil, weak = (#paths == 0) and weak or nil,
           learnedAt = tonumber(learnedAt), collected = false, partial = partial }
end

-- Toutes les recettes d'un métier (skillID : 197 couture, 333 enchantement…) : { spell, item, name, learnedAt }
local recipeCache = {}
function A.Recipes(skillID)
  local db = DB()
  if not (db and skillID and db.recipes[skillID]) then return {} end
  if recipeCache[skillID] then return recipeCache[skillID] end
  local list = {}
  for spell, r in pairs(db.recipes[skillID]) do
    if not (r[7] and r[7] ~= MyR()) then
      local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)) or (r[1] > 0 and ItemName(r[1])) or nil
      list[#list + 1] = { spell = spell, item = r[1] > 0 and r[1] or nil, name = name, learnedAt = tonumber(r[2]) or 0 }
    end
  end
  table.sort(list, function(x, y) return x.learnedAt < y.learnedAt end)
  recipeCache[skillID] = list
  return list
end

-- Lieux où obtenir un objet, pour y aller (flèche) : { { name, mapID, x, y, kind } }, ta faction seulement ;
-- un objet de donjon renvoie l'entrée du donjon
function A.Places(itemID, kinds)
  local db = DB()
  local out = {}
  for _, src in ipairs(db and db.items[itemID] or {}) do
    if Mine(src) and (not kinds or kinds[src[1]]) then
      local e = src[6] or {}
      local inst = e.inst and db.instances[e.inst]
      if src[3] > 0 and src[4] > 0 then
        out[#out + 1] = { name = A.NpcName(src[2]) or SourceText(src), mapID = src[3], x = src[4], y = src[5], kind = src[1] }
      elseif inst and inst[1] > 0 then
        out[#out + 1] = { name = A.InstanceName(e.inst) or T.dungeon, mapID = inst[1], x = inst[2], y = inst[3], kind = src[1] }
      elseif src[2] > 0 and db.npcs[src[2]] then
        local p = db.npcs[src[2]]
        out[#out + 1] = { name = A.NpcName(src[2]) or T.npc, mapID = p[1], x = p[2], y = p[3], kind = src[1] }
      end
    end
  end
  return out
end
-- Où aller pour obtenir un objet : donjon (boss, butin d'un PNJ du donjon) ou zone (quête, butin d'un PNJ dehors).
-- Achats et fabrications n'en font pas partie (ce sont d'autres actions). Une quête déjà faite est ignorée.
-- { key, name, kind = "dungeon"|"zone", level (niveau du donjon ou de la quête), raid, mapID, x, y, quest (numéro) }
local function QuestDone(q)
  local Q = C_QuestLog
  if not (q and Q and Q.IsQuestFlaggedCompleted) then return false end
  local ok, done = pcall(Q.IsQuestFlaggedCompleted, q)
  return ok and done == true
end
function A.Where(itemID)
  local db = DB()
  local out = {}
  for _, src in ipairs(db and db.items[itemID] or {}) do
    local kind, e = src[1], src[6] or {}
    if Mine(src) and kind ~= "vendor" and kind ~= "craft" and kind ~= "obj" then
      local inst = e.inst and db.instances[e.inst]
      if inst then
        out[#out + 1] = { key = "i" .. e.inst, name = A.InstanceName(e.inst) or T.dungeon, kind = "dungeon", level = inst[4],
                          raid = inst[5] == 1, mapID = inst[1], x = inst[2], y = inst[3] }
      elseif kind == "quest" and src[3] > 0 then
        local q = e.q or src[2]
        if not QuestDone(q) then
          out[#out + 1] = { key = "m" .. src[3], name = A.MapName(src[3]) or T.quest, kind = "zone", level = e.lvl,
                            mapID = src[3], x = src[4], y = src[5], quest = q }
        end
      elseif (kind == "drop" or kind == "boss") and src[3] > 0 then
        out[#out + 1] = { key = "m" .. src[3], name = A.MapName(src[3]) or T.npc, kind = "zone", mapID = src[3], x = src[4], y = src[5] }
      end
    end
  end
  return out
end
function A.Vendors(itemID)
  local out = A.Places(itemID, { vendor = true })
  local store = ns.root and ns.root.Store
  if store and store.Vendors then for _, v in ipairs(store.Vendors(itemID)) do out[#out + 1] = v end end   -- marchands visités
  return out
end

-- Où apprendre une recette (numéro du sort) : son PNJ placé, sinon les lieux de son patron
function A.RecipePlaces(spell)
  local db = DB()
  if not db then return {} end
  for _, recs in pairs(db.recipes) do
    local r = recs[spell]
    if r then
      if not (r[7] and r[7] ~= MyR()) and r[3] and db.npcs[r[3]] then
        local p = db.npcs[r[3]]
        return { { name = A.NpcName(r[3]) or T.npc, mapID = p[1], x = p[2], y = p[3], kind = r[5] } }
      end
      if r[1] and r[1] > 0 then return A.Places(r[1]) end
      return {}
    end
  end
  return {}
end

function A.Diag(add)
  local db = DB()
  if not db then add("Sources (All The Things intégré) : absentes"); return end
  local n = 0
  for _ in pairs(db.items) do n = n + 1 end
  local t = {}
  for k, id in pairs(A.SKILL) do local c = #A.Recipes(id); if c > 0 then t[#t + 1] = k .. " " .. c end end
  table.sort(t)
  local cached = 0
  for _ in pairs(NpcCache()) do cached = cached + 1 end
  add("Sources intégrées (All The Things " .. tostring(db.rev) .. ", MIT) : " .. n .. " objets ; recettes : " .. table.concat(t, ", ")
      .. " ; noms de PNJ connus : " .. cached .. (_G.ATTC and " ; addon All The Things aussi installé" or ""))
end
