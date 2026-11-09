local _, root = ...

-- Quêtes à ton niveau, lues dans Questie (facultatif) : les quêtes que Questie juge disponibles pour ton personnage
-- (déjà faites, mauvaise faction ou classe, prérequis manquants : exclues par Questie), regroupées par zone avec leur
-- donneur. Rien n'est créé ni modifié chez Questie : ses modules sont lus tels quels (QuestieLoader._modules).
-- Sans Questie : rien.

local Q = {}
root.Quests = Q

local function Mod(name)
  local QL = _G.QuestieLoader
  local mods = QL and rawget(QL, "_modules")
  return type(mods) == "table" and mods[name] or nil
end

function Q.Available()
  local AQ, DB = Mod("AvailableQuests"), Mod("QuestieDB")
  return AQ and type(AQ.__availableQuests) == "table" and DB and type(DB.GetQuest) == "function" and true or false
end

local function MapName(id)
  if not (id and C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, id)
  return ok and type(info) == "table" and info.name or nil
end

-- Donneur d'une quête : { name, mapID, x, y } (premier PNJ connu de Questie, première position)
local function Giver(DB, ZDB, q)
  local starts = q.Starts or {}
  for _, npcId in ipairs(starts.NPC or {}) do
    local ok, npc = pcall(DB.GetNPC, DB, npcId)
    if ok and type(npc) == "table" and type(npc.spawns) == "table" then
      for areaId, coords in pairs(npc.spawns) do
        local c = type(coords) == "table" and coords[1]
        local mapID = ZDB and ZDB.GetUiMapIdByAreaId and select(2, pcall(ZDB.GetUiMapIdByAreaId, ZDB, areaId))
        if c and type(mapID) == "number" then
          return { name = npc.name, mapID = mapID, x = c[1], y = c[2] }
        end
      end
    end
  end
end

-- Zones avec le plus de quêtes à ton niveau (niveau de la quête entre ton niveau − 2 et + 3), triées : d'abord ton
-- continent et le nombre de quêtes. { mapID, name, quests = { {id, name, level, giver} }, lo, hi, giver }
local memo
function Q.Zones(max)
  if memo and GetTime() - memo.t < 30 then return memo.v end
  local out = {}
  if not Q.Available() then return out end
  local AQ, DB, ZDB = Mod("AvailableQuests"), Mod("QuestieDB"), Mod("ZoneDB")
  local level = UnitLevel("player")
  local zones, order = {}, {}
  local n = 0
  for id in pairs(AQ.__availableQuests) do
    n = n + 1
    if n > 400 then break end                                  -- garde-fou : jamais des milliers de lectures
    local ok, q = pcall(DB.GetQuest, id)
    if ok and type(q) == "table" then
      local ql = tonumber(q.questLevel) or tonumber(q.requiredLevel) or 0
      if ql <= 0 then ql = level end
      if ql >= level - 2 and ql <= level + 3 and (tonumber(q.requiredLevel) or 0) <= level then
        local g = Giver(DB, ZDB, q)
        if g then
          local z = zones[g.mapID]
          if not z then
            z = { mapID = g.mapID, name = MapName(g.mapID) or "?", quests = {}, lo = ql, hi = ql }
            zones[g.mapID] = z
            order[#order + 1] = z
          end
          z.quests[#z.quests + 1] = { id = id, name = q.name or ("#" .. id), level = ql, giver = g }
          z.lo, z.hi = math.min(z.lo, ql), math.max(z.hi, ql)
        end
      end
    end
  end
  -- ton continent d'abord (trajet raisonnable), puis le plus de quêtes
  local N = root.Nav
  local pc = N and N.Player and N.Player()
  for _, z in ipairs(order) do
    local c = N and N.World and N.World(z.mapID, 50, 50)
    z.here = (pc and c == pc) and true or false
    table.sort(z.quests, function(a, b) return a.level < b.level end)
    -- donneur le plus proche de toi parmi ceux de la zone
    local places = {}
    for _, qq in ipairs(z.quests) do places[#places + 1] = qq.giver end
    z.giver = (N and N.Closest and N.Closest(places)) or places[1]
  end
  table.sort(order, function(a, b)
    if a.here ~= b.here then return a.here end
    if #a.quests ~= #b.quests then return #a.quests > #b.quests end
    return a.name < b.name
  end)
  for i = 1, math.min(max or 2, #order) do out[#out + 1] = order[i] end
  memo = { t = GetTime(), v = out }
  return out
end

function Q.Forget() memo = nil end
local f = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "PLAYER_LEVEL_UP" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function() memo = nil end)
