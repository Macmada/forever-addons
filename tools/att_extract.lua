-- Extrait de la base WoW Forever d'All The Things (« Camelot », https://github.com/ATTWoWAddon/AllTheThings, licence MIT)
-- les données dont ForeverCompagnon a besoin, pour se passer d'ATT en jeu : où obtenir chaque objet (boss, PNJ, vendeur
-- et prix, quête, objet, zone et coordonnées, faction, réputation) et les recettes de chaque métier.
--
-- Les fichiers d'ATT sont du code Lua qui construit un arbre (zone > PNJ > objet…). Ils sont exécutés dans un bac à sable :
-- seules les fonctions factices ci-dessous y sont visibles (ni io, ni os, ni chargement de code).
--
-- Usage : lua5.1 tools/att_extract.lua <dossier db/Camelot d'ATT> <révision d'ATT> > ForeverCompagnon/Data/Sources.lua

local dir, rev = arg[1], arg[2] or "?"
assert(dir, "usage : lua5.1 tools/att_extract.lua <db/Camelot> [révision]")

-- Objet « magique » : appelable et indexable à volonté (pour _.OnTooltipDB.X, _.Settings…)
local magic
magic = setmetatable({}, { __index = function() return magic end, __call = function() return magic end })

-- Constructeurs d'ATT : un nœud { kind, id, id2, fields, children }
local KIND = {
  CreateItem = "item", CreateItemSource = "itemsource", CreateRecipe = "recipe", CreateNPC = "npc", CreateEncounter = "enc",
  CreateInstance = "inst", CreateMap = "map", CreateQuest = "quest", CreateObject = "obj", CreateProfession = "prof",
  CreateCustomHeader = "header", CreateHeader = "header", CreateCategory = "header", CreateFilter = "header",
  CreateCharacterClass = "class", CreateFaction = "faction", CreateExpansion = "header",
}
local function Ctor(kind)
  return function(...)
    local node = { kind = kind, fields = {} }
    local nums = {}
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if type(v) == "number" then nums[#nums + 1] = v
      elseif type(v) == "table" and v ~= magic then node.fields = v end
    end
    node.id, node.id2 = nums[1], nums[2]
    -- enfants : champ g, ou directement la liste du tableau (h(-59, { n(…), n(…) }))
    node.children = node.fields.g or ((type(node.fields[1]) == "table" and node.fields[1].kind) and node.fields) or {}
    return node
  end
end

local handlers = {}
local U = setmetatable({}, { __index = function(_, k)
  if k == "AddEventHandler" then return function(_, fn) handlers[#handlers + 1] = fn end end
  if type(k) == "string" and k:find("^Create") then return Ctor(KIND[k] or "other") end
  return magic
end, __newindex = function() end })

local FILES = { "Character", "Craftables", "ExpansionFeatures", "Holidays", "Instances", "PVP", "Professions",
                "Promotions", "WorldDrops", "Zones" }
for _, f in ipairs(FILES) do
  local fh = assert(io.open(dir .. "/Categories/" .. f .. ".lua", "rb"))
  local text = fh:read("*a"):gsub("^\239\187\191", "")           -- marque d'ordre des octets UTF-8
  fh:close()
  local chunk = assert(loadstring(text, "=" .. f))
  setfenv(chunk, { pairs = pairs, ipairs = ipairs, type = type, select = select, tonumber = tonumber, tostring = tostring,
                   math = { floor = math.floor, min = math.min, max = math.max }, string = { format = string.format } })
  chunk("AllTheThings", U)
end
local categories = {}
for _, fn in ipairs(handlers) do fn(categories) end

----------------------------------------------------------------------
-- Parcours : pour chaque objet ou recette, son contexte (PNJ, boss, quête, objet, zone ou donjon)
----------------------------------------------------------------------
local items, recipes, npcs, instances = {}, {}, {}, {}
local nItems, nSources = 0, 0

local function FirstCoord(c)
  if type(c) ~= "table" then return nil end
  for map, list in pairs(c) do
    if type(map) == "number" and type(list) == "table" and type(list[1]) == "table" then
      return map, list[1][1], list[1][2]
    elseif type(list) == "table" and list[1] and list[2] and list[3] then
      return list[3], list[1], list[2]
    end
  end
end

local function Cost(c)
  if type(c) == "number" then return { { "g", c } } end
  if type(c) ~= "table" then return nil end
  local out = {}
  for _, x in ipairs(c) do
    if type(x) == "table" and (x[1] == "g" or x[1] == "i" or x[1] == "c") then out[#out + 1] = { x[1], x[2], x[3] } end
  end
  return #out > 0 and out or nil
end

local function Walk(node, ctx)
  if type(node) ~= "table" or not node.kind then return end
  local f = node.fields
  local c = {}
  for k, v in pairs(ctx) do c[k] = v end
  if f.r then c.r = f.r end
  if f.minReputation then c.rep = f.minReputation end
  if f.races then c.races = f.races end
  if f.lvl then c.lvl = type(f.lvl) == "table" and f.lvl[1] or f.lvl end
  if f.requireSkill then c.skill = f.requireSkill end
  local k = node.kind
  if k == "header" and node.id == -58 then c.vendors = true end      -- en-tête « Vendeurs » d'ATT
  if k == "map" then c.map, c.inst = node.id, nil
  elseif k == "inst" then
    c.inst = node.id; c.map = (type(f.maps) == "table" and f.maps[1]) or c.map
    local m, x, y = FirstCoord(f.coords)                -- entrée du donjon sur la carte de la zone
    instances[node.id] = { m or 0, x and math.floor(x * 10 + 0.5) / 10 or 0, y and math.floor(y * 10 + 0.5) / 10 or 0,
                           type(f.lvl) == "table" and f.lvl[1] or f.lvl or 0, f.isRaid and 1 or 0 }
  elseif k == "enc" then c.enc = node.id; c.npc = f.npcID or (type(f.crs) == "table" and f.crs[1]) or c.npc; c.kind = "boss"
  elseif k == "npc" and node.id and node.id > 0 then
    c.npc, c.kind = node.id, "npc"
    local m, x, y = FirstCoord(f.coords)
    if m then c.cmap, c.x, c.y = m, x, y; npcs[node.id] = { m, x, y } end
  elseif k == "quest" then
    c.quest, c.kind = node.id, "quest"
    c.npc = type(f.qgs) == "table" and f.qgs[1] or c.npc
    local m, x, y = FirstCoord(f.coords)
    if m then c.cmap, c.x, c.y = m, x, y end
  elseif k == "obj" then
    c.obj, c.kind = node.id, "obj"
    local m, x, y = FirstCoord(f.coords)
    if m then c.cmap, c.x, c.y = m, x, y end
  elseif k == "prof" then c.prof = node.id
  end

  local itemID = (k == "item" and node.id) or (k == "itemsource" and node.id2) or (k == "recipe" and node.id2) or f.itemID
  if (k == "item" or k == "itemsource" or (k == "recipe" and itemID)) and itemID then
    -- source : un objet sous un PNJ avec un coût = vendeur ; sous un PNJ ou un boss sans coût = butin ; sous une quête = récompense
    local cost = Cost(f.cost)
    local kind = c.kind or (c.prof and "craft") or "zone"
    if kind == "npc" then kind = (cost or c.vendors) and "vendor" or "drop" end
    local src = { kind, c.npc or c.obj or c.quest or 0, c.cmap or c.map or 0, c.x and math.floor(c.x * 10 + 0.5) / 10 or 0,
                  c.y and math.floor(c.y * 10 + 0.5) / 10 or 0 }
    local extra = {}
    if c.inst then extra.inst = c.inst end
    if c.enc then extra.enc = c.enc end
    if kind == "quest" then extra.q = c.quest end
    if cost then extra.cost = cost end
    if c.r then extra.r = c.r end
    if c.rep then extra.rep = c.rep end
    if c.lvl then extra.lvl = c.lvl end
    if kind == "craft" and c.prof then extra.prof = c.prof end
    if next(extra) then src[6] = extra end
    local list = items[itemID]
    if not list then list = {}; items[itemID] = list; nItems = nItems + 1 end
    if #list < 6 then
      local key = table.concat({ src[1], src[2], src[3] }, ":")
      local dup = false
      for _, s in ipairs(list) do if table.concat({ s[1], s[2], s[3] }, ":") == key then dup = true end end
      if not dup then list[#list + 1] = src; nSources = nSources + 1 end
    end
  end
  if k == "recipe" and node.id then
    local skill = c.skill or c.prof
    if skill then
      recipes[skill] = recipes[skill] or {}
      local seen = recipes[skill][node.id]
      if not seen then
        recipes[skill][node.id] = { itemID or 0, f.learnedAt or f.rank or 0, c.npc or 0, c.cmap or c.map or 0, c.kind or "trainer",
                                    Cost(f.cost), c.r, c.rep }
      end
    end
  end
  -- marchand qui liste ses articles par renvoi (sym = { { "select", "itemID", id, id… } })
  if k == "npc" and node.id and node.id > 0 and type(f.sym) == "table" then
    for _, sy in ipairs(f.sym) do
      if type(sy) == "table" and sy[1] == "select" and sy[2] == "itemID" then
        for j = 3, #sy do
          if type(sy[j]) == "number" then
            Walk({ kind = "item", id = sy[j], fields = {}, children = {} }, (function()
              local cc = {}
              for kk, vv in pairs(c) do cc[kk] = vv end
              cc.vendors = true
              return cc
            end)())
          end
        end
      end
    end
  end
  for _, ch in ipairs(node.children) do Walk(ch, c) end
end

for name, root in pairs(categories) do
  if type(root) == "table" and root.kind then Walk(root, {})
  elseif type(root) == "table" then for _, n in ipairs(root) do Walk(n, {}) end end
end

----------------------------------------------------------------------
-- Sortie : un fichier Lua compact pour ForeverCompagnon
----------------------------------------------------------------------
local function S(v)
  if type(v) == "number" then
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.1f", v)
  elseif type(v) == "string" then return string.format("%q", v)
  elseif type(v) == "table" then
    local out, n = {}, #v
    for i = 1, n do out[#out + 1] = S(v[i]) end
    local keys = {}
    for kk in pairs(v) do if type(kk) ~= "number" or kk > n or kk < 1 then keys[#keys + 1] = kk end end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, kk in ipairs(keys) do
      out[#out + 1] = (type(kk) == "string" and kk:match("^[%a_][%w_]*$") and kk or ("[" .. S(kk) .. "]")) .. "=" .. S(v[kk])
    end
    return "{" .. table.concat(out, ",") .. "}"
  end
  return "nil"
end

local function Sorted(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

io.write("-- Généré par tools/att_extract.lua depuis la base WoW Forever d'All The Things (révision ", rev, ")\n")
io.write("-- https://github.com/ATTWoWAddon/AllTheThings, licence MIT, (c) AllTheThings WoW Addon. Ne pas modifier à la main.\n")
io.write("-- Sources d'un objet : { genre, PNJ/objet/quête, carte, x, y, { inst, enc, q, cost, r (1 Horde, 2 Alliance), rep, lvl, prof } }\n")
io.write("-- genres : boss, drop (butin d'un PNJ), vendor, quest, obj, craft, zone. Recettes : [métier][sort] = { objet, appris à,\n")
io.write("-- PNJ, carte, genre, coût, faction, réputation }. PNJ : [id] = { carte, x, y }. Donjons : [id] = { carte de l'entrée,\n")
io.write("-- x, y, niveau, raid }.\n")
io.write("local _, root = ...\n")
io.write("root.Sources = { rev = ", S(rev), ", items = {\n")
for _, id in ipairs(Sorted(items)) do io.write("[", id, "]=", S(items[id]), ",\n") end
io.write("}, recipes = {\n")
for _, skill in ipairs(Sorted(recipes)) do
  io.write("[", skill, "]={\n")
  for _, spell in ipairs(Sorted(recipes[skill])) do io.write("[", spell, "]=", S(recipes[skill][spell]), ",\n") end
  io.write("},\n")
end
io.write("}, instances = {\n")
for _, id in ipairs(Sorted(instances)) do io.write("[", id, "]=", S(instances[id]), ",\n") end
io.write("}, npcs = {\n")
for _, id in ipairs(Sorted(npcs)) do io.write("[", id, "]=", S(npcs[id]), ",\n") end
io.write("} }\n")
io.stderr:write(string.format("ATT %s : %d objets, %d sources, %d PNJ placés, recettes : ", rev, nItems, nSources,
  (function() local n = 0; for _ in pairs(npcs) do n = n + 1 end; return n end)()))
for _, skill in ipairs(Sorted(recipes)) do
  local n = 0; for _ in pairs(recipes[skill]) do n = n + 1 end
  io.stderr:write(skill, "=", n, " ")
end
io.stderr:write("\n")
