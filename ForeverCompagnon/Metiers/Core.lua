local ADDON, ns = ...; if ns.Module then ADDON, ns = ns.Module("ForeverMetiers") end
local L = ns.L
local D = ns.Data

-- ForeverMetiers : montée de la couture et de l'enchantement (d'après la fenêtre du métier), ce qui sert ton prêtre
-- (enchantements, pièces de couture évaluées par ForeverHeal), désenchantement, recettes et temps de recharge.

local db, gdb
function ns.Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cffe6b84dForeverMetiers|r " .. msg)
end

local Instant = function(x) return ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(x) end
local Info = function(x) return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(x) end
ns.Instant, ns.Info = Instant, Info
local function ItemID(link) return link and tonumber(link:match("item:(%d+)")) end
local function SpellID(link) return link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)")) end
ns.ItemID = ItemID

local function Norm(s)
  if not s then return nil end
  s = s:lower():gsub("%s+", " ")
  s = s:gsub("^ ", "")
  s = s:gsub(" $", "")
  return s
end
ns.Norm = Norm

-- Nom d'un sort : C_Spell (client moderne de Forever) ou GetSpellInfo (classique)
function ns.SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
  end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function CharKey() return (UnitName("player") or "?") .. " - " .. (GetRealmName and GetRealmName() or "?") end
ns.CharKey = CharKey

function ns.ProfKey(name, skillLine)
  if skillLine then
    for k, p in pairs(D.profs) do if p.skill == skillLine then return k end end
  end
  local n = Norm(name)
  if not n then return nil end
  for k, p in pairs(D.profs) do
    for _, x in ipairs(p.names) do if Norm(x) == n then return k end end
  end
end
function ns.ProfName(k) return ns.LocOpt("prof_" .. k) or (D.profs[k] and D.profs[k].names[ns.lang == "en" and 2 or 1]) or k end

function ns.ItemName(id)
  local name = id and Info(id)
  if not name and id and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  return name or D.matNames[id] or ("#" .. tostring(id))
end

function ns.Money(c)
  if not c then return "?" end
  c = math.floor(c + 0.5)
  if c >= 10000 then return string.format(L.money, math.floor(c / 10000), math.floor(c / 100) % 100) end
  if c >= 100 then return string.format(L.moneyS, math.floor(c / 100), c % 100) end
  return string.format(L.moneyC, c)
end

function ns.Duration(s)
  s = math.max(0, math.floor(s))
  if s >= 86400 then return string.format(L.day, math.floor(s / 86400), math.floor(s / 3600) % 24) end
  if s >= 3600 then return string.format(L.hour, math.floor(s / 3600), math.floor(s / 60) % 60) end
  return string.format(L.min, math.max(1, math.floor(s / 60)))
end

----------------------------------------------------------------------
-- Compétences et rangs
----------------------------------------------------------------------
function ns.RankOf(max)
  for i, r in ipairs(D.ranks) do if (max or 0) <= r.cap then return i, r end end
  return #D.ranks, D.ranks[#D.ranks]
end

function ns.Trainer(k, rankKey)
  local tr = D.profs[k] and D.profs[k].trainers
  local t = tr and tr[rankKey]
  if not t then return string.format(L.trainerAny, ns.ProfName(k)) end
  return t[UnitFactionGroup("player") or ""] or t.all or string.format(L.trainerAny, ns.ProfName(k))
end

-- { rank, max, cur = rang actuel, next = rang suivant ou nil }
function ns.RankInfo(k)
  local s = db.skills[k]
  if not s then return nil end
  local i, cur = ns.RankOf(s.max)
  return { rank = s.rank, max = s.max, cur = cur, next = D.ranks[i + 1] }
end

function ns.CheckRank(k)
  local ri = ns.RankInfo(k)
  if not (ri and ri.next and db.rankReminder) then return end
  if ri.rank >= ri.max - 10 then
    local key = k .. ri.max
    if db.rankWarned[key] then return end
    db.rankWarned[key] = true
    ns.Print(L.rankSoon, ns.ProfName(k), ri.rank, ri.max, L["rank_" .. ri.next.key], ns.Trainer(k, ri.next.key))
  end
end

function ns.SetSkill(k, rank, max)
  if not (k and rank) then return end
  local s = db.skills[k] or {}
  s.rank, s.max, s.t = rank, max or s.max or 75, time()
  db.skills[k] = s
  gdb.chars[CharKey()] = gdb.chars[CharKey()] or {}
  gdb.chars[CharKey()][k] = rank
  ns.CheckRank(k)
end

-- Lignes de compétence du personnage (sans ouvrir la fenêtre du métier) : GetSkillLineInfo (classique)
-- ou GetProfessions / GetProfessionInfo (client moderne de Forever)
function ns.ReadSkills()
  local seen = {}
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      local k = not header and ns.ProfKey(name)
      if k then ns.SetSkill(k, rank, max); seen[k] = true end
    end
  elseif GetProfessions and GetProfessionInfo then
    -- métiers principaux, archéologie, pêche, cuisine (et secourisme selon le client) : indices éventuellement nil
    local idx = { GetProfessions() }
    for i = 1, 6 do
      if idx[i] then
        local name, _, rank, max, _, _, skillLine = GetProfessionInfo(idx[i])
        local k = ns.ProfKey(name, skillLine)
        if k then ns.SetSkill(k, rank, max); seen[k] = true end
      end
    end
  else
    return
  end
  for _, k in ipairs(D.allProfOrder) do if not seen[k] then db.skills[k] = nil end end   -- métier abandonné
end

----------------------------------------------------------------------
-- Fenêtre du métier : couture (TradeSkill) et enchantement (Craft dans le client classique, TradeSkill sinon)
----------------------------------------------------------------------
-- forever-api: off (adaptateurs des anciens clients : choisis par ns.TradeAPI seulement si GetTradeSkillLine existe)
ns.API = {
  trade = {
    kind = "trade",
    line = function() return GetTradeSkillLine() end,
    num = function() return GetNumTradeSkills() or 0 end,
    info = function(i) local n, t, a = GetTradeSkillInfo(i); return n, t, a end,
    link = function(i) return GetTradeSkillItemLink and GetTradeSkillItemLink(i) end,
    recipe = function(i) return GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i) end,
    nreag = function(i) return GetTradeSkillNumReagents(i) or 0 end,
    reag = function(i, j) return GetTradeSkillReagentInfo(i, j) end,
    reaglink = function(i, j) return GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j) end,
    cd = function(i) return GetTradeSkillCooldown and GetTradeSkillCooldown(i) end,
    desc = function() return nil end,
    select = function(i)
      if TradeSkillFrame_SetSelection then TradeSkillFrame_SetSelection(i) end
      if TradeSkillFrame_Update then TradeSkillFrame_Update() end
    end,
    frame = function() return _G.TradeSkillFrame end,
  },
  craft = {
    kind = "craft",
    line = function()
      if GetCraftDisplaySkillLine then return GetCraftDisplaySkillLine() end
      if GetCraftSkillLine then return GetCraftSkillLine(1) end
    end,
    num = function() return GetNumCrafts() or 0 end,
    info = function(i) local n, _, t, a = GetCraftInfo(i); return n, t, a end,
    link = function(i) return GetCraftItemLink and GetCraftItemLink(i) end,
    recipe = function(i) return GetCraftRecipeLink and GetCraftRecipeLink(i) end,
    nreag = function(i) return GetCraftNumReagents(i) or 0 end,
    reag = function(i, j) return GetCraftReagentInfo(i, j) end,
    reaglink = function(i, j) return GetCraftReagentItemLink and GetCraftReagentItemLink(i, j) end,
    cd = function() return nil end,
    desc = function(i) return GetCraftDescription and GetCraftDescription(i) end,
    select = function(i)
      if CraftFrame_SetSelection then CraftFrame_SetSelection(i) end
      if CraftFrame_Update then CraftFrame_Update() end
    end,
    frame = function() return _G.CraftFrame end,
  },
}
-- forever-api: on

-- Client moderne de Forever : plus de GetTradeSkillLine ni de Craft (erreur à l'ouverture du métier, 05/11/2026).
-- Lecture par C_TradeSkillUI : recettes apprises (numérotées 1..n ici), difficulté, composants, recharge, sélection.
local function T() return C_TradeSkillUI end
local DIFF = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }
local modern = { kind = "modern", ids = {} }
local function Call(name, ...)
  local f = T() and T()[name]
  if not f then return nil end
  local ok, a, b, c = pcall(f, ...)
  if ok then return a, b, c end
end
function modern.line()
  local info = Call("GetChildProfessionInfo")
  if type(info) ~= "table" or not info.professionName then info = Call("GetBaseProfessionInfo") end
  -- liste des recettes apprises, refaite à chaque lecture
  wipe(modern.ids)
  for _, id in ipairs(Call("GetAllRecipeIDs") or {}) do
    local ri = Call("GetRecipeInfo", id)
    if type(ri) == "table" and ri.learned ~= false then modern.ids[#modern.ids + 1] = id end
  end
  if type(info) ~= "table" then return nil end
  return info.parentProfessionName or info.professionName, info.skillLevel, info.maxSkillLevel
end
function modern.num() return #modern.ids end
function modern.info(i)
  local ri = Call("GetRecipeInfo", modern.ids[i])
  if type(ri) ~= "table" then return nil end
  local d = DIFF[ri.relativeDifficulty or -1] or (ri.difficulty) or "easy"
  return ri.name, d, ri.numAvailable or 0
end
function modern.link(i)
  local id = modern.ids[i]
  local out = Call("GetRecipeOutputItemData", id)
  if type(out) == "table" and out.hyperlink then return out.hyperlink end
  if type(out) == "table" and out.itemID then return select(2, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(out.itemID)) end
  return Call("GetRecipeItemLink", id)
end
function modern.recipe(i) return Call("GetRecipeLink", modern.ids[i]) or ("|Hspell:" .. tostring(modern.ids[i]) .. "|h|h") end
local function Slots(i)
  local sch = Call("GetRecipeSchematic", modern.ids[i], false)
  return type(sch) == "table" and sch.reagentSlotSchematics or {}
end
function modern.nreag(i) return #Slots(i) end
function modern.reag(i, j)
  local slot = Slots(i)[j]
  local item = slot and slot.reagents and slot.reagents[1] and slot.reagents[1].itemID
  if not item then return nil end
  local name = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(item)
  local have = ((C_Item and C_Item.GetItemCount) or GetItemCount)(item) or 0
  return name or ("#" .. item), nil, slot.quantityRequired or 1, have
end
function modern.reaglink(i, j)
  local slot = Slots(i)[j]
  local item = slot and slot.reagents and slot.reagents[1] and slot.reagents[1].itemID
  return item and ("item:" .. item)
end
function modern.cd(i) return Call("GetRecipeCooldown", modern.ids[i]) end
function modern.desc(i) return Call("GetRecipeDescription", modern.ids[i]) end
function modern.select(i)
  local id = modern.ids[i]
  if not Call("OpenRecipe", id) and Call("SetRecipeSelected", id) == nil then
    local pf = _G.ProfessionsFrame
    if pf and pf.CraftingPage and pf.CraftingPage.SelectRecipe then
      local ri = Call("GetRecipeInfo", id)
      if ri then pcall(pf.CraftingPage.SelectRecipe, pf.CraftingPage, ri) end
    end
  end
end
function modern.frame() return _G.ProfessionsFrame or _G.TradeSkillFrame end
ns.API.modern = modern

-- Méthode de lecture : l'ancienne si le client l'a, sinon la moderne
function ns.TradeAPI()
  if GetTradeSkillLine and GetNumTradeSkills then return ns.API.trade end
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then return modern end
  return ns.API.trade
end

-- Gain de caractéristiques lu dans la description d'un enchantement (« +16 aux soins », « l'Esprit de 5 »…)
local STATPATS = {
  heal = { "jusqu'à %+?(%d+) aux soins", "%+(%d+) aux soins", "(%d+) aux dégâts et aux soins", "healing[^%d]-(%d+)", "(%d+) healing" },
  int = { "%+(%d+) intelligence", "%+(%d+) à l'intelligence", "intelligence[^%d]-(%d+)", "%+(%d+) intellect", "intellect[^%d]-(%d+)" },
  spi = { "%+(%d+) esprit", "%+(%d+) à l'esprit", "esprit[^%d]-(%d+)", "%+(%d+) spirit", "spirit[^%d]-(%d+)" },
  sta = { "%+(%d+) endurance", "%+(%d+) à l'endurance", "endurance[^%d]-(%d+)", "%+(%d+) stamina", "stamina[^%d]-(%d+)" },
  mp5 = { "(%d+) points de mana toutes les 5", "(%d+) mana toutes les 5", "(%d+) mana every 5", "(%d+) mana per 5" },
}
function ns.ParseStats(desc)
  if not desc or desc == "" then return nil end
  local t = desc:lower()
  if t:find("chance", 1, true) then return nil end                      -- effet aléatoire : pas de valeur fixe
  local all = t:match("caractéristiques de (%d+)") or t:match("toutes les caractéristiques[^%d]-(%d+)") or t:match("all stats[^%d]-(%d+)")
  if all then all = tonumber(all); return { sta = all, int = all, spi = all } end
  local d, any = {}, false
  for key, pats in pairs(STATPATS) do
    for _, p in ipairs(pats) do
      local n = t:match(p)
      if n then d[key] = tonumber(n); any = true; break end
    end
  end
  return any and d or nil
end

function ns.Scan(api)
  local name, rank, max = api.line()
  local k = ns.ProfKey(name)
  ns.lastApi = api
  if not k then ns.lastScan = { name = name, kind = api.kind }; return nil end
  ns.SetSkill(k, rank, max)
  local sc = { prof = k, kind = api.kind, rank = rank, max = max, recipes = {}, t = time() }
  local known = {}
  local products = {}
  local me = CharKey()
  gdb.cooldowns[me] = gdb.cooldowns[me] or {}
  for i = 1, api.num() do
    local rn, typ, avail = api.info(i)
    if rn and typ ~= "header" and typ ~= "subheader" then
      local link = api.link(i)
      local r = { index = i, name = rn, type = typ, avail = avail or 0, link = link, item = ItemID(link), reagents = {} }
      r.spell = SpellID(link) or SpellID(api.recipe(i))
      for j = 1, api.nreag(i) do
        local rname, _, need, have = api.reag(i, j)
        local rl = api.reaglink(i, j)
        r.reagents[#r.reagents + 1] = { name = rname, need = need or 1, have = have or 0, id = ItemID(rl), link = rl }
      end
      local desc = api.desc(i)
      if desc and r.spell then db.enchStats[r.spell] = ns.ParseStats(desc) end
      local cd = api.cd(i)
      if cd and cd > 0 then gdb.cooldowns[me][rn] = time() + cd
      elseif gdb.cooldowns[me][rn] then gdb.cooldowns[me][rn] = nil end
      known[Norm(rn)] = true
      if r.item then known["i" .. r.item] = true; products[#products + 1] = r.item end
      if r.spell then known["s" .. r.spell] = true end
      sc.recipes[#sc.recipes + 1] = r
    end
  end
  db.known[k] = known
  db.products[k] = products
  -- noms appris, pour les infobulles des autres personnages
  gdb.known[me] = gdb.known[me] or {}
  local names = {}
  for key in pairs(known) do if not key:match("^[is]%d+$") then names[key] = true end end
  gdb.known[me][k] = names
  ns.lastScan = sc
  db.lastAdvice[k] = { t = time(), lines = ns.AdviceSummary(sc), items = ns.AdviceItems(sc) }
  return sc
end

-- Source d'une recette ou d'un objet du guide : All The Things d'abord (base Forever), sinon le texte du guide
function ns.Source(entry)
  if not ns.ATT.Available() then return nil end
  if entry.spell then return ns.ATT.Source("recipeID", entry.spell) end
  if entry.id then return ns.ATT.Source("itemID", entry.id) end
end

-- Compétence pour apprendre : celle d'ATT si elle la connaît
function ns.EntrySkill(entry)
  local s = ns.Source(entry)
  return (s and s.learnedAt and s.learnedAt > 0) and s.learnedAt or entry.skill or 0
end

function ns.Known(k, entry)
  local kn = db.known[k]
  if not kn then
    local s = ns.Source(entry)
    return s and s.collected or false
  end
  if entry.spell and kn["s" .. entry.spell] then return true end
  if entry.item and kn["i" .. entry.item] then return true end
  if entry.id and kn["i" .. entry.id] then return true end
  return kn[Norm(entry.name)] == true
end

----------------------------------------------------------------------
-- Évaluation pour ton prêtre (ForeverHeal) ; sans lui, rien n'est chiffré
----------------------------------------------------------------------
function ns.Signed(v, dec)
  dec = dec or 0
  if math.abs(v) < 0.5 * 10 ^ (-dec) then return "|cffa0a0a00|r" end
  local s = string.format("%." .. dec .. "f", math.abs(v))
  if ns.lang ~= "en" then s = s:gsub("%.", ",") end
  return (v > 0 and "|cff40d860+" or "|cffff5050−") .. s .. "|r"
end

function ns.GainText(r)
  if not r then return "?" end
  local parts = {}
  if math.abs(r.hps or 0) >= 0.05 then parts[#parts + 1] = string.format(L.gainHps, ns.Signed(r.hps, 1)) end
  if math.abs(r.healed or 0) >= 1 then parts[#parts + 1] = string.format(L.gainHealed, ns.Signed(r.healed)) end
  if math.abs(r.hp or 0) >= 1 then parts[#parts + 1] = string.format(L.gainHp, ns.Signed(r.hp)) end
  return #parts > 0 and table.concat(parts, ", ") or L.gainNone
end

local function HealAPI()
  local _, class = UnitClass("player")
  local api = _G.ForeverHealAPI
  if class == "PRIEST" and api then return api end
end
ns.HealAPI = HealAPI

-- Objet : amélioration pour toi ? (gain de ForeverHeal) ; nil si non ou si ForeverHeal manque
function ns.Upgrade(link)
  local api = HealAPI()
  if not (api and link) then return nil end
  local _, _, _, _, _, classID, subID = Instant(link)
  if classID == 4 and subID and subID > 1 then return nil end      -- le prêtre ne porte que du tissu (et bijoux, dos)
  local ok, r = pcall(api.Evaluate, link)
  if ok and r and (r.score or 0) > 0.3 then return r end
end

function ns.EnchantStats(e) return db.enchStats[e.spell] or e.d end

function ns.StatGain(d)
  local api = HealAPI()
  if not (api and api.EvaluateStats and d) then return nil end
  local ok, r = pcall(api.EvaluateStats, d)
  if ok then return r end
end

----------------------------------------------------------------------
-- Comptes et prix (Syndicator, Auctionator : facultatifs)
----------------------------------------------------------------------
function ns.Count(id)
  local G = ns.Game
  local bags = G and G.ItemCount(id) or (GetItemCount and GetItemCount(id)) or 0
  local all = G and G.ItemCount(id, true) or (GetItemCount and GetItemCount(id, true)) or bags
  local alts = 0
  local S = _G.Syndicator
  if not (S and S.API) and ns.root and ns.root.Store then          -- sans Syndicator : inventaire retenu par ForeverCompagnon
    local b, bank, a = ns.root.Store.Count(id)
    return b, bank, a
  end
  if S and S.API and S.API.GetInventoryInfoByItemID and (not S.API.IsReady or S.API.IsReady()) then
    local ok, info = pcall(S.API.GetInventoryInfoByItemID, id, true, false)
    if ok and type(info) == "table" then
      local me = UnitName("player")
      for _, c in ipairs(info.characters or {}) do
        if c.character == me then alts = alts + (c.mail or 0)
        else alts = alts + (c.bags or 0) + (c.bank or 0) + (c.mail or 0) end
      end
    end
  end
  return bags, math.max(0, all - bags), alts
end

function ns.Price(id)
  local A = _G.Auctionator
  local api = A and A.API and A.API.v1
  if not api then                                                    -- sans Auctionator : prix relevés par ForeverCompagnon
    return ns.root and ns.root.Store and ns.root.Store.Price(id) or nil
  end
  if D.vendorMats[id] and api.GetVendorPriceByItemID then
    local ok, p = pcall(api.GetVendorPriceByItemID, ADDON, id)
    if ok and p then return p end
  end
  if api.GetAuctionPriceByItemID then
    local ok, p = pcall(api.GetAuctionPriceByItemID, ADDON, id)
    if ok and p then return p end
  end
  if api.GetVendorPriceByItemID then
    local ok, p = pcall(api.GetVendorPriceByItemID, ADDON, id)
    if ok and p then return p end
  end
end

----------------------------------------------------------------------
-- Montée : étape du guide, liste de courses, meilleurs crafts de la fenêtre
----------------------------------------------------------------------
function ns.GuideStep(k, rank)
  for _, st in ipairs(D.routes[k] or {}) do if (rank or 0) < st.to then return st end end
end

function ns.Matches(step, r)
  if not (step and r) then return false end
  if step.item and r.item == step.item then return true end
  if step.spell and r.spell == step.spell then return true end
  return Norm(r.name) == Norm(step.name)
end

-- { st = étape, items = { { id, need, bags, bank, alts, missing, price, vendor } }, cost = coût de ce qui manque }
function ns.Shopping(k)
  local s = db.skills[k]
  if not s then return nil end
  local st = ns.GuideStep(k, s.rank)
  if not st then return nil end
  local frac = (st.to - math.max(s.rank, st.from)) / (st.to - st.from)
  local out = { st = st, items = {}, cost = 0, crafts = math.ceil(st.n * frac) }
  for _, m in ipairs(st.mats) do
    local need = math.ceil(m.n * frac)
    local bags, bank, alts = ns.Count(m.id)
    local missing = math.max(0, need - bags - bank)
    local price = ns.Price(m.id)
    if price and missing > 0 then out.cost = out.cost + price * missing end
    out.items[#out.items + 1] = { id = m.id, need = need, bags = bags, bank = bank, alts = alts, missing = missing, price = price, vendor = D.vendorMats[m.id] }
  end
  return out
end

local CHANCE = { optimal = 1, medium = 0.65, easy = 0.2 }
ns.CHANCE = CHANCE

-- Meilleurs crafts pour monter : faisables d'abord, puis orange, puis l'étape du guide, puis le moins cher par point
function ns.Advise(sc, limit)
  local out = {}
  if not sc then return out end
  local hasEnch = db.skills.enchanting ~= nil
  local step = ns.GuideStep(sc.prof, sc.rank)
  for _, r in ipairs(sc.recipes) do
    local ch = CHANCE[r.type]
    if ch then
      local cost, unknown = 0, false
      for _, g in ipairs(r.reagents) do
        local p = g.id and ns.Price(g.id)
        if p then cost = cost + p * g.need else unknown = true end
      end
      local e = { r = r, chance = ch, guide = ns.Matches(step, r) }
      if not unknown then e.cost, e.perPoint = cost, cost / ch end
      if r.item then
        local _, _, _, loc, _, cid = Instant(r.item)
        if (cid == 2 or cid == 4) and loc and loc ~= "" and not D.noDE[loc] then
          e.de = hasEnch and sc.prof == "tailoring"
          local _, link = Info(r.item)
          e.upgrade = link and ns.Upgrade(link)
        end
      end
      out[#out + 1] = e
    end
  end
  table.sort(out, function(a, b)
    local ca, cb = a.r.avail > 0, b.r.avail > 0
    if ca ~= cb then return ca end
    if a.chance ~= b.chance then return a.chance > b.chance end
    if a.guide ~= b.guide then return a.guide end
    if (a.upgrade ~= nil) ~= (b.upgrade ~= nil) then return a.upgrade ~= nil end
    if a.perPoint and b.perPoint and a.perPoint ~= b.perPoint then return a.perPoint < b.perPoint end
    if (a.perPoint ~= nil) ~= (b.perPoint ~= nil) then return a.perPoint ~= nil end
    return a.r.name < b.r.name
  end)
  while #out > (limit or 5) do table.remove(out) end
  return out
end

function ns.CraftText(e)
  local r = e.r
  return string.format(L.craftLine, r.link or r.name, L["diff_" .. r.type] or r.type,
    r.avail > 0 and string.format(L.canCraft, r.avail) or L.cantCraft,
    e.perPoint and string.format(L.perPoint, ns.Money(e.perPoint)) or "",
    (e.guide and L.guideTag or "") .. (e.de and L.deTag or "") .. (e.upgrade and string.format(L.upTag, ns.GainText(e.upgrade)) or ""))
end

-- Résumé gardé pour l'onglet Montée quand la fenêtre est fermée
-- Même résumé, en données (pour les cartes de l'onglet Montée)
function ns.AdviceItems(sc)
  local out = {}
  for _, e in ipairs(ns.Advise(sc, 5)) do
    out[#out + 1] = { name = e.r.name, link = e.r.link, item = e.r.item, spell = e.r.spell, type = e.r.type, avail = e.r.avail,
                      perPoint = e.perPoint, guide = e.guide, de = e.de, up = e.upgrade and ns.GainText(e.upgrade) or nil }
  end
  return out
end

function ns.AdviceSummary(sc)
  local lines = {}
  for _, e in ipairs(ns.Advise(sc, 5)) do lines[#lines + 1] = ns.CraftText(e) end
  return lines
end

----------------------------------------------------------------------
-- Pour toi : enchantements de l'équipement, pièces de couture
----------------------------------------------------------------------
local function Enchanted(link)
  local e = link and tonumber(link:match("item:%d+:(%d*)") or "")
  return e and e > 0
end
ns.Enchanted = Enchanted

local function Applies(e, slot)
  if e.slot ~= slot then return false end
  local link = GetInventoryItemLink("player", slot)
  if not link then return false end
  local _, _, _, loc = Instant(link)
  if e.two then return loc == "INVTYPE_2HWEAPON" end
  if e.off then return loc == "INVTYPE_HOLDABLE" end
  return true
end

-- slot -> { link, enchanted, known = { e, gain }, learn = { e, gain } }
function ns.EnchantAdvice()
  local out = {}
  local skill = db.skills.enchanting and db.skills.enchanting.rank or 0
  for _, slot in ipairs(D.enchantSlots) do
    local link = GetInventoryItemLink("player", slot)
    local a = { slot = slot, link = link, enchanted = Enchanted(link) }
    if link then
      for _, e in ipairs(D.healEnchants) do
        if Applies(e, slot) then
          a.any = true
          local g = ns.StatGain(ns.EnchantStats(e))
          local score = g and g.score or (e.skill / 1000)
          local c = { e = e, gain = g, score = score }
          if ns.Known("enchanting", e) then
            if not a.known or score > a.known.score then a.known = c end
          else
            if not a.learn or score > a.learn.score or (score == a.learn.score and ns.EntrySkill(e) < ns.EntrySkill(a.learn.e)) then a.learn = c end
            if ns.EntrySkill(e) <= skill and (not a.soon or score > a.soon.score) then a.soon = c end      -- apprenable dès maintenant
          end
        end
      end
      if a.known and a.learn and a.learn.score <= a.known.score then a.learn = nil end
      if a.soon and (a.soon == a.learn or (a.known and a.soon.score <= a.known.score)) then a.soon = nil end
    end
    out[#out + 1] = a
  end
  return out
end

-- Pièces de couture qui t'améliorent : recettes connues (produits relevés) et patrons du guide dont l'objet est connu du jeu
function ns.TailorUpgrades()
  local list, seen = {}, {}
  local function add(id, src, known, skill)
    if not id or seen[id] then return end
    seen[id] = true
    local _, _, _, loc, _, cid = Instant(id)
    if not (cid == 2 or cid == 4) or not loc or loc == "" then return end
    local _, link, _, _, minLevel = Info(id)
    if not link then
      if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
      return
    end
    local up = ns.Upgrade(link)
    if up then list[#list + 1] = { id = id, link = link, gain = up, known = known, src = src, minLevel = minLevel or 0, skill = skill } end
  end
  for _, id in ipairs(db.products.tailoring or {}) do add(id, nil, true) end
  for _, p in ipairs(D.patterns.tailoring) do
    if p.id and not p.camp then add(p.id, p.src, ns.Known("tailoring", p), p.skill) end
  end
  table.sort(list, function(a, b) return a.gain.score > b.gain.score end)
  return list
end

-- Recettes du métier connues d'All The Things, pas encore apprises : maintenant (≤ compétence) et bientôt (jusqu'à +25)
function ns.ATTLearnable(k)
  local s = db.skills[k]
  if not (s and ns.ATT.Available()) then return nil end
  local now, soon = {}, {}
  local skillLine = ns.ATT.SKILL[k] or (D.profs[k] and D.profs[k].skill)
  if not skillLine or (D.profs[k] and D.profs[k].gather) then return nil end
  for _, r in ipairs(ns.ATT.Recipes(skillLine)) do
    if r.name and not ns.Known(k, { spell = r.spell, name = r.name }) then
      if r.learnedAt <= s.rank then now[#now + 1] = r elseif r.learnedAt <= s.rank + 25 then soon[#soon + 1] = r end
    end
  end
  table.sort(now, function(a, b) return a.learnedAt > b.learnedAt end)
  return now, soon
end

----------------------------------------------------------------------
-- « À ta portée » : ce qui sert maintenant ou très bientôt (niveau du personnage, compétence du métier)
----------------------------------------------------------------------
function ns.SkillOf(k) return db.skills[k] and db.skills[k].rank or 0 end
-- Métiers appris, dans l'ordre d'affichage
function ns.Learned()
  local out = {}
  for _, k in ipairs(D.allProfOrder) do if db.skills[k] then out[#out + 1] = k end end
  return out
end
-- Le personnage est-il un prêtre (parties « pour ton soigneur » : enchantements de soins, pièces de couture) ?
function ns.ForHealer() return select(2, UnitClass("player")) == "PRIEST" and _G.ForeverHealAPI ~= nil end
function ns.SkillWindow(k) return ns.SkillOf(k) + D.nearSkill end
function ns.LevelWindow() return UnitLevel("player") + D.nearLevel end

-- Enchantements à ta portée, par emplacement porté : known (tu sais faire), now (apprenable maintenant),
-- soon (dans les 30 prochains points) ; next = le premier utile au-delà (pour dire « à partir de… »)
function ns.EnchantNear()
  local out, nextE = {}, nil
  local skill, win = ns.SkillOf("enchanting"), ns.SkillWindow("enchanting")
  for _, a in ipairs(ns.EnchantAdvice()) do
    local n = { slot = a.slot, link = a.link, enchanted = a.enchanted }
    if a.link then
      for _, e in ipairs(D.healEnchants) do
        local need = ns.EntrySkill(e)
        local applies = false
        if e.slot == a.slot then
          local _, _, _, loc = ns.Instant(a.link)
          applies = (not e.two or loc == "INVTYPE_2HWEAPON") and (not e.off or loc == "INVTYPE_HOLDABLE")
        end
        if applies then
          local g = ns.StatGain(ns.EnchantStats(e))
          local score = g and g.score or (1 / (need + 1))
          if not g or score > 0 then
            local c = { e = e, gain = g, score = score, need = need }
            local key = ns.Known("enchanting", e) and "known" or (need <= skill and "now") or (need <= win and "soon") or nil
            if key then
              if not n[key] or score > n[key].score then n[key] = c end
            elseif not nextE or need < nextE.need then
              nextE = { e = e, need = need, slot = a.slot, gain = g }
            end
          end
        end
      end
    end
    out[#out + 1] = n
  end
  return out, nextE
end

-- Pièces de couture à ta portée (niveau requis ≤ ton niveau + 5, recette ≤ ta compétence + 30) ; next = la première au-delà
function ns.TailorNear()
  local near, nextP = {}, nil
  local lvlWin, win = ns.LevelWindow(), ns.SkillWindow("tailoring")
  for _, u in ipairs(ns.TailorUpgrades()) do
    local need = u.known and 0 or (u.skill or 0)
    for _, p in ipairs(D.patterns.tailoring) do
      if p.id == u.id then need = u.known and 0 or ns.EntrySkill(p) end
    end
    u.need = need
    if (u.minLevel or 0) <= lvlWin and need <= win then near[#near + 1] = u
    elseif not nextP or (u.minLevel or 0) < (nextP.minLevel or 0) then nextP = u end
  end
  return near, nextP
end

----------------------------------------------------------------------
-- Désenchantement
----------------------------------------------------------------------
function ns.DEResult(ilvl, quality, classID)
  local row
  for _, r in ipairs(D.disenchant) do if (ilvl or 0) <= r.max then row = r; break end end
  row = row or D.disenchant[#D.disenchant]
  local res
  if quality == 4 then res = { row.nexus or row.shard }
  elseif quality == 3 then res = { row.shard }
  elseif classID == 2 then res = { row.ess, row.dust }
  else res = { row.dust, row.ess } end
  return { items = res, skill = row.skill }
end

local function BagSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end
local function BagLink(bag, s)
  if C_Container and C_Container.GetContainerItemLink then return C_Container.GetContainerItemLink(bag, s) end
  return GetContainerItemLink and GetContainerItemLink(bag, s)
end

function ns.DECandidates()
  local list = {}
  local skill = db.skills.enchanting and db.skills.enchanting.rank
  for bag = 0, 4 do
    for s = 1, BagSlots(bag) do
      local link = BagLink(bag, s)
      local id = ItemID(link)
      if id and not db.keep[id] then
        local _, _, _, loc, _, classID = Instant(link)
        local _, _, quality, ilvl = Info(link)
        if quality and quality >= 2 and quality <= 4 and (classID == 2 or classID == 4) and loc and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP"
           and not D.noDE[loc] and not ns.Upgrade(link) then
          local res = ns.DEResult(ilvl, quality, classID)
          list[#list + 1] = { bag = bag, slot = s, link = link, id = id, ilvl = ilvl or 0, res = res, ok = (skill or 0) >= res.skill }
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if a.ok ~= b.ok then return a.ok end
    return a.ilvl < b.ilvl
  end)
  return list
end

function ns.DEMacro(c)
  local spell = ns.SpellName(D.disenchantSpell) or (ns.lang == "en" and "Disenchant" or "Désenchanter")
  return "/cast " .. spell .. "\n/use " .. c.bag .. " " .. c.slot
end

----------------------------------------------------------------------
-- Événements
----------------------------------------------------------------------
local function InitDB()
  ForeverMetiersDB = ForeverMetiersDB or {}
  db = ForeverMetiersDB
  ns.db = db
  db.version = db.version or 1
  db.skills = db.skills or {}
  db.known = db.known or {}
  db.products = db.products or {}
  db.enchStats = db.enchStats or {}
  db.lastAdvice = db.lastAdvice or {}
  db.keep = db.keep or {}
  db.rankWarned = db.rankWarned or {}
  if db.side == nil then db.side = true end
  if db.tooltip == nil then db.tooltip = true end
  if db.rankReminder == nil then db.rankReminder = true end
  db.minimap = db.minimap or { angle = 260, hide = false }
  if db.lang then ns.lang = db.lang end
  ForeverMetiersGlobalDB = ForeverMetiersGlobalDB or {}
  gdb = ForeverMetiersGlobalDB
  ns.gdb = gdb
  gdb.cooldowns = gdb.cooldowns or {}
  gdb.known = gdb.known or {}
  gdb.chars = gdb.chars or {}
end
ns._InitDB = InitDB

local ev = CreateFrame("Frame")
ns.eventFrame = ev
local handlers = {}
local pending = {}

-- La fenêtre envoie beaucoup de mises à jour : une lecture au plus toutes les 0,3 s
local function Soon(kind)
  if pending[kind] then return end
  pending[kind] = true
  C_Timer.After(0.3, function()
    pending[kind] = nil
    -- protégé : si une fonction de métier manque sur ce client, l'erreur va dans le diagnostic au lieu de se répéter
    local api = (kind == "trade") and ns.TradeAPI() or ns.API[kind]
    local ok, sc = pcall(ns.Scan, api)
    if not ok then ns.lastScanError = tostring(sc); return end
    ns.lastScanError = nil
    if ns.OnScan then ns.OnScan(sc, api) end
  end)
end
ns.Soon = Soon

handlers.TRADE_SKILL_SHOW = function() Soon("trade") end
handlers.TRADE_SKILL_UPDATE = function() Soon("trade") end
handlers.TRADE_SKILL_LIST_UPDATE = function() Soon("trade") end
handlers.CRAFT_SHOW = function() Soon("craft") end
handlers.CRAFT_UPDATE = function() Soon("craft") end
handlers.TRADE_SKILL_CLOSE = function() if ns.OnClose then ns.OnClose("trade") end end
handlers.CRAFT_CLOSE = function() if ns.OnClose then ns.OnClose("craft") end end
handlers.SKILL_LINES_CHANGED = function() ns.ReadSkills() end
handlers.CHAT_MSG_SKILL = function() ns.ReadSkills() end
local bagPending
handlers.BAG_UPDATE = function()
  if bagPending then return end
  bagPending = true
  C_Timer.After(1, function() bagPending = nil; if ns.OnBags then ns.OnBags() end end)
end
handlers.PLAYER_EQUIPMENT_CHANGED = function() if ns.Refresh then ns.Refresh() end end
handlers.PLAYER_REGEN_ENABLED = function()
  if ns.deHidePending and ns.ui and not ns.ui:IsShown() and ns.ui.deBtn then ns.ui.deBtn:Hide() end
  ns.deHidePending = nil
  if ns.OnBags then ns.OnBags() end
end
handlers.PLAYER_LOGIN = function()
  ns.ReadSkills()
  if ns.OnLogin then ns.OnLogin() end
end

ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON and ... ~= ns.ROOT then return end
    InitDB()
    for e in pairs(handlers) do pcall(ev.RegisterEvent, ev, e) end
    return
  end
  local h = handlers[event]
  if h then h(...) end
end)
ns._handlers = handlers
