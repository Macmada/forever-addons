local _, ns = ...

-- All The Things (facultatif), commun à ForeverMetiers et ForeverLoot (copié tel quel par tools/sync-shared.sh).
-- ATT a une base propre à WoW Forever (livrée sous le nom « Camelot », tirée des données du jeu) : pour chaque objet et
-- recette, le PNJ, la quête, la zone, le coût, la réputation et le niveau d'apprentissage. ATT n'a pas d'API publique :
-- on lit ses structures internes (_G.ATTC : SearchForField, parent, text…) sous pcall, et on se tait si elles changent.
local A = {}
ns.ATT = A

local FR = GetLocale() == "frFR"
local STANDING = { { 42000, FR and "Exalté" or "Exalted" }, { 21000, FR and "Révéré" or "Revered" },
                   { 9000, FR and "Honoré" or "Honored" }, { 3000, FR and "Amical" or "Friendly" }, { 0, FR and "Neutre" or "Neutral" } }
A.SKILL = { tailoring = 197, enchanting = 333 }

local function App()
  local a = _G.ATTC
  if type(a) == "table" and type(a.SearchForField) == "function" then return a end
end
function A.Available() return App() ~= nil end

local function Get(g, k)
  local ok, v = pcall(function() return g[k] end)
  if ok then return v end
end

local function Clean(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
  s = s:match("^%s*(.-)%s*$")
  if s == "" or s:find("^%[?Retrieving") or s:find("^%[?Récupération") then return nil end
  if s:find("^Quest #%d+") or s:find("^Quête #%d+") then return nil end     -- quête pas encore chargée par le jeu
  return s
end

-- Groupes d'ATT pour un champ (itemID, recipeID…)
function A.Search(field, id)
  local a = App()
  if not a or not id then return {} end
  local ok, list = pcall(a.SearchForField, field, id)
  if (not ok or type(list) ~= "table" or #list == 0) and type(a.SearchForFieldInAllCaches) == "function" then
    ok, list = pcall(a.SearchForFieldInAllCaches, field, id)
  end
  return (ok and type(list) == "table") and list or {}
end

-- Faction du joueur au sens d'ATT (champ r : 1 Horde, 2 Alliance)
local function MyR() return UnitFactionGroup("player") == "Horde" and 1 or 2 end

-- Chemin lisible : PNJ ou quête, boss, puis zone ou donjon (catégories générales ignorées). good = vraie source ;
-- nil si la source est réservée à l'autre faction.
local function Path(g)
  local parts, p, n, good = {}, Get(g, "parent"), 0, false
  local gr = Get(g, "r")
  if gr and gr ~= MyR() then return nil, false end
  while p and n < 10 do
    n = n + 1
    local pr = Get(p, "r")
    if pr and pr ~= MyR() then return nil, false end
    if not Get(p, "parent") and not (Get(p, "mapID") or Get(p, "instanceID")) then break end   -- racine d'ATT (« ALL THE THINGS »)
    local t = Clean(Get(p, "text") or Get(p, "name"))
    if not t and Get(p, "questID") then t = FR and "quête" or "quest" end
    local isPlace = Get(p, "mapID") or Get(p, "instanceID")
    if Get(p, "npcID") or Get(p, "creatureID") or Get(p, "questID") or Get(p, "encounterID") or Get(p, "objectID") then good = true end
    if t and not Get(p, "headerID") and (#parts < 2 or isPlace) then parts[#parts + 1] = t end
    if isPlace then good = good or #parts > 0; break end
    p = Get(p, "parent")
  end
  return #parts > 0 and table.concat(parts, " — ") or nil, good
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
  if g > 0 then return string.format(FR and "%d po" or "%dg", g) end
  return string.format(FR and "%d pa" or "%ds", s)
end

-- Coût et réputation lisibles : « 120 Faveur marchande, Amical avec Administration commerciale d'Azeroth »
local function Extra(g)
  local out = {}
  local cost = Get(g, "cost")
  if type(cost) == "table" then
    for _, c in ipairs(cost) do
      if type(c) == "table" then
        if c[1] == "c" then
          local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(c[2])
          out[#out + 1] = (c[3] or 1) .. " " .. ((info and info.name) or ((FR and "monnaie #" or "currency #") .. tostring(c[2])))
        elseif c[1] == "i" then
          out[#out + 1] = (c[3] or 1) .. " " .. ItemName(c[2])
        elseif c[1] == "g" and type(c[2]) == "number" then
          out[#out + 1] = Money(c[2])
        end
      end
    end
  elseif type(cost) == "number" and cost > 0 then
    out[#out + 1] = Money(cost)
  end
  local rep = Get(g, "minReputation")
  if type(rep) == "table" and rep[1] then
    local fname = FactionName(rep[1])
    local st = STANDING[#STANDING][2]
    for _, s in ipairs(STANDING) do if (rep[2] or 0) >= s[1] then st = s[2]; break end end
    out[#out + 1] = st .. (FR and " avec " or " with ") .. (fname or ("#" .. rep[1]))
  end
  return #out > 0 and table.concat(out, ", ") or nil
end

-- Sources d'un objet ou d'une recette : texte « PNJ — zone (coût) ; … », niveau d'apprentissage (recettes), connu (ATT)
function A.Source(field, id, max)
  local paths, seen, learnedAt, collected = {}, {}, nil, nil
  local fallback
  for _, g in ipairs(A.Search(field, id)) do
    learnedAt = learnedAt or Get(g, "learnedAt")
    if collected == nil then collected = Get(g, "collected") end
    local path, good = Path(g)
    if path then
      local extra = Extra(g)
      local txt = path .. (extra and (" (" .. extra .. ")") or "")
      if good and not seen[txt] then
        seen[txt] = true
        paths[#paths + 1] = txt
      elseif not fallback then
        fallback = txt
      end
    end
  end
  while #paths > (max or 2) do table.remove(paths) end
  if #paths == 0 and not learnedAt and not fallback then return nil end
  -- text : vraie source (PNJ, quête, boss, zone) ; weak : catégorie générale d'ATT, quand il n'a rien de plus précis
  return { text = #paths > 0 and table.concat(paths, " ; ") or nil, weak = (#paths == 0) and fallback or nil,
           learnedAt = tonumber(learnedAt), collected = collected and true or false }
end

-- Toutes les recettes d'un métier connues d'ATT (skillID : 197 couture, 333 enchantement) : { spell, item, name, learnedAt }
local recipeCache = {}
function A.Recipes(skillID)
  local a = App()
  if not (a and type(a.SearchForFieldContainer) == "function") then return {} end
  if recipeCache[skillID] then return recipeCache[skillID] end
  local ok, cont = pcall(a.SearchForFieldContainer, "recipeID")
  if not ok or type(cont) ~= "table" then return {} end
  local list = {}
  for spell, groups in pairs(cont) do
    if type(spell) == "number" and type(groups) == "table" then
      local g = groups[1]
      if g and Get(g, "requireSkill") == skillID then
        list[#list + 1] = { spell = spell, item = Get(g, "itemID"), name = Clean(Get(g, "name") or Get(g, "text")), learnedAt = tonumber(Get(g, "learnedAt")) or 0 }
      end
    end
  end
  table.sort(list, function(x, y) return x.learnedAt < y.learnedAt end)
  if #list > 0 then recipeCache[skillID] = list end
  return list
end

function A.Diag(add)
  local a = _G.ATTC
  if not a then add("All The Things : absent"); return end
  local t = {}
  for k, id in pairs(A.SKILL) do t[#t + 1] = k .. " " .. #A.Recipes(id) end
  add("All The Things : présent (SearchForField " .. tostring(type(a.SearchForField)) .. ", recettes lues : " .. table.concat(t, ", ") .. ")")
end
