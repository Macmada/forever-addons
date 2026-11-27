local _, root = ...
local L = root.L

-- « Maintenant » : en haut, quelques tuiles (un chiffre chacune) ; dessous, « À faire » : des actions écrites comme des
-- phrases (maître de classe, donjons et zones d'après tes améliorations et tes quêtes, achats), un seul
-- chiffre à droite, le détail dans l'infobulle ; un clic lance l'itinéraire le plus rapide (Nav.Go), un clic droit ouvre
-- l'onglet. Chaque partie est protégée : une erreur devient une ligne lisible (et un point du diagnostic). En combat,
-- rien n'est recalculé (valeurs secrètes sur Forever) : l'écran garde le dernier état connu.

local last, lastTiles
root.nowErrors = {}

local GREEN, ORANGE, GOLD = { 0.25, 0.85, 0.38 }, { 1, 0.66, 0.24 }, { 1, 0.82, 0 }
local function Gray(s) return "|cffa0a0a0" .. s .. "|r" end
local function Num(v, dec) local m = 10 ^ (dec or 0); return tostring(math.floor((v or 0) * m + 0.5) / m) end
local function Dur(s)
  if not s or s == math.huge then return nil end
  s = math.floor(s + 0.5)
  if s >= 60 then return string.format("%d min", math.floor(s / 60)) end
  return s .. " s"
end
local function Money(c)
  if not c or c <= 0 then return nil end
  if _G.GetCoinTextureString then return _G.GetCoinTextureString(c) end
  local g, sv = math.floor(c / 10000), math.floor(c / 100) % 100
  return (g > 0 and (g .. " po ") or "") .. sv .. " pa"
end
local function Chip(text, hex) return "|cff" .. hex .. text .. "|r" end
local function Safe(name, f, ...)
  local ok, a = pcall(f, ...)
  if ok then return a end
  root.nowErrors[#root.nowErrors + 1] = name .. " : " .. tostring(a)
  return nil
end

----------------------------------------------------------------------
-- Tuiles : { value, label, color, open, tip }
----------------------------------------------------------------------
local function HealTiles(out)
  local ns = root.mods.ForeverHeal
  if not (ns and ns.Snapshot and ns.Metrics) or ns.inactive or (root.Role() and root.Role() ~= "heal") then return end
  local S = ns.Snapshot()
  local M = ns.Metrics(S, ns.Mix and ns.Mix() or nil)
  local lines = { string.format(L.regen, Num(S.regenOut, 1)) }
  if S.mana then lines[#lines + 1] = Num(S.mana) .. " mana" end
  out[#out + 1] = { value = Num(M.hps, 0), label = L.tileHps, color = GREEN, open = "heal", kind = "hps",
                    tip = { title = string.format(L.hps, Num(M.hps, 1)), lines = lines } }
  local oom = Dur(M.oom)
  out[#out + 1] = { value = oom or "OK", label = oom and L.tileAuto or L.tileNever, open = "heal", kind = "auto",
                    color = (M.oom and M.oom < 60) and ORANGE or GREEN,
                    tip = { title = oom and string.format(L.oom, oom) or L.noOom } }
end

local function Upgrades()
  local ns = root.mods.ForeverLoot
  if not (ns and ns.BiS) then return 0 end
  local n = 0
  for _, s in pairs(ns.BiS(1, UnitLevel("player"))) do if #s.items > 0 then n = n + 1 end end
  return n
end

function root.NowTiles(prepRes, places)
  local out = {}
  Safe("soins", HealTiles, out)
  local up = Safe("équipement", Upgrades) or 0
  out[#out + 1] = { value = tostring(up), label = L.tileUp, color = up > 0 and GOLD or GREEN, open = "loot", kind = "up" }
  local buy = prepRes and #(prepRes.shopping or {}) or 0
  out[#out + 1] = { value = tostring(buy), label = L.tileBuy, color = buy > 0 and ORANGE or GREEN, open = "prep", kind = "buy" }
  if #out < 4 then
    out[#out + 1] = { value = tostring(#(places or {})), label = L.tilePlaces, color = GOLD, open = "loot", kind = "places" }
  end
  while #out > 4 do table.remove(out) end
  return out
end

----------------------------------------------------------------------
-- « À faire »
----------------------------------------------------------------------
local function Go(mapID, x, y, title)
  if mapID and x and y and root.Nav then root.Nav.Go(mapID, x, y, title) end
end

local function TrainerTodo(lines)
  local ns = root.mods.ForeverPrep
  local level = UnitLevel("player")
  if not (ns and ns.TrainerDue) or level < 2 then return end
  local due, cost, t = ns.TrainerDue()
  local tip = { title = L.todoTrainer, lines = {} }
  local source, gain
  if due then
    if #due == 0 then return end
    local names = {}
    for i, sv in ipairs(due) do
      local n = sv.name .. (sv.rank and (" (" .. sv.rank .. ")") or "")
      if i <= 3 then names[#names + 1] = n end
      tip.lines[#tip.lines + 1] = { n, 1, 1, 1 }
    end
    source = table.concat(names, ", ") .. (#due > 3 and ", …" or "")
    gain = string.format(L.todoTrainerSpells, #due)
    local m = Money(cost)
    if m then tip.lines[#tip.lines + 1] = { string.format(L.todoTrainerCost, m), 1, 0.82, 0 } end
  else
    -- maître jamais ouvert : les sorts arrivent aux niveaux pairs
    local lastLvl = ns.db and ns.db.lastTrainerLevel
    if level % 2 == 1 or (lastLvl and lastLvl >= level) then return end
    source = L.todoTrainerLikely
    tip.lines[#tip.lines + 1] = { L.todoTrainerNoPos, 0.8, 0.8, 0.8 }
  end
  if t and t.mapID then tip.lines[#tip.lines + 1] = { L.clickGo, 0.85, 0.78, 0.6 } end
  lines[#lines + 1] = { kind = "card", icon = "Interface\\Icons\\INV_Misc_Book_09", quality = 1, name = L.todoTrainer,
                        nameColor = { 1, 1, 1 }, source = source, gain = gain and ("|cffffd100" .. gain .. "|r") or nil, tip = tip,
                        trainer = true,
                        onClick = function() if t and t.mapID then Go(t.mapID, t.x, t.y, t.npc or L.todoTrainer) else root.Open("prep") end end,
                        onRight = function() root.Open("prep") end }
end

local function PlaceTodo(lines, places)
  local loot = root.mods.ForeverLoot
  local level = UnitLevel("player")
  for _, p in ipairs(places or {}) do
    local isDj = p.kind == "dungeon"
    local entrance = isDj and p.mapID and loot.ATT and loot.ATT.MapName and loot.ATT.MapName(p.mapID)
    local tags = { Chip(isDj and L.tagDungeon or L.tagZone, isDj and "66ccff" or "d8c8a0") }
    if p.level and p.level > 0 then
      local txt = p.maxLevel and string.format(L.tagRange, p.level, p.maxLevel) or string.format(L.tagLevel, p.level)
      local col = (level < p.level and "ffaa3c") or ((p.maxLevel and level > p.maxLevel - 3) and "a0a0a0") or "40d860"
      tags[#tags + 1] = Chip(txt, col)
    end
    local src = {}
    if entrance then src[#src + 1] = entrance end
    src[#src + 1] = string.format(L.placeItems, #p.items)
    if p.nQuests > 0 then src[#src + 1] = string.format(L.placeQuests, p.nQuests) end
    local best = p.items[1]
    local gain = (best and loot._GainParts) and (loot._GainParts(best.eval)) or ""
    local tip = { title = p.name, lines = {} }
    if entrance then tip.lines[#tip.lines + 1] = { string.format(L.placeEntrance, entrance), 0.7, 0.7, 0.7 } end
    for _, it in ipairs(p.items) do
      local name = it.c.link and it.c.link:match("%[(.-)%]") or "?"
      local g = loot._GainParts and (loot._GainParts(it.eval)) or ""
      local q = it.quest and loot.ATT and loot.ATT.QuestName and loot.ATT.QuestName(it.quest)
      tip.lines[#tip.lines + 1] = { name .. "  " .. g .. (q and Gray("  (" .. q .. ")") or ""), 0.4, 0.8, 1 }
    end
    if p.mapID then tip.lines[#tip.lines + 1] = { L.clickGo, 0.85, 0.78, 0.6 } end
    tip.lines[#tip.lines + 1] = { L.rightOpen, 0.85, 0.78, 0.6 }
    lines[#lines + 1] = { kind = "card", icon = isDj and "Interface\\Icons\\INV_Misc_Head_Dragon_01" or "Interface\\Icons\\INV_Misc_Map_01",
                          quality = 1, nameColor = { 1, 1, 1 }, name = string.format(isDj and L.todoDungeon or L.todoZone, p.name),
                          tags = table.concat(tags, "  "), source = table.concat(src, " · "), gain = gain, tip = tip, place = p,
                          onClick = function() if p.mapID then Go(p.mapID, p.x, p.y, p.name) else root.Open("loot") end end,
                          onRight = function() root.Open("loot"); if loot.ShowTab then loot.ShowTab("near") end end }
  end
end

-- Amélioration déjà dans tes sacs : l'équiper (clic)
local function BagTodo(lines)
  local loot = root.mods.ForeverLoot
  if not (loot and loot.BiS) then return end
  local level = UnitLevel("player")
  local n = 0
  for _, s in pairs(loot.BiS(1, level)) do
    local c = s.items[1]
    if c and c.src == "bags" and n < 2 then
      n = n + 1
      local name = c.link and c.link:match("%[(.-)%]") or "?"
      local gain = loot._GainParts and (loot._GainParts(c.eval)) or ""
      lines[#lines + 1] = { kind = "card", link = c.link, icon = select(5, root.Game.ItemInstant(c.link)), quality = 2,
                            name = string.format(L.todoEquip, name), nameColor = { 1, 1, 1 }, source = L.todoEquipSrc, gain = gain,
                            equip = true, onClick = function() root.Game.Equip(c.link) end,
                            onRight = function() root.Open("loot") end }
    end
  end
end

-- Prix à l'hôtel des ventes d'un objet (Auctionator, sinon le relevé de ForeverCompagnon) ; nil si jamais vu
function root.AHPrice(id)
  local prep = root.mods.ForeverPrep
  if not (id and prep and prep.Price) then return nil end
  local ok, p = pcall(prep.Price, id, true)
  if ok and type(p) == "number" and p > 0 then return p end
end
local function Coins(c)
  local prep = root.mods.ForeverPrep
  return (prep and prep.FormatMoney) and prep.FormatMoney(c) or (Money(c) or "")
end
root.Coins = Coins

-- Amélioration à acheter à l'hôtel des ventes : la plus rentable (points par pièce d'or) parmi celles que tu peux payer
local function AHTodo(lines)
  local loot = root.mods.ForeverLoot
  if not (loot and loot.BiS) then return end
  local level = UnitLevel("player")
  local money = (GetMoney and GetMoney()) or 0
  local found = {}
  for _, s in pairs(loot.BiS(5, level)) do
    for _, c in ipairs(s.items) do
      if c.src ~= "bags" and not (loot.Owned and loot.Owned(c.id)) then
        local price = root.AHPrice(c.id)
        local gain = c.eval and c.eval.score or 0
        if price and price <= money and gain > 0 then
          found[#found + 1] = { c = c, price = price, gain = gain, ratio = gain / math.max(price / 10000, 0.01) }
          break                                      -- un objet par emplacement : le meilleur trouvé à l'HV
        end
      end
    end
  end
  if #found == 0 then return end
  table.sort(found, function(a, b) return a.ratio > b.ratio end)
  local best = found[1]
  local name = best.c.link and best.c.link:match("%[(.-)%]") or "?"
  local ratio = string.format("%.1f", best.ratio)
  if root.FR then ratio = ratio:gsub("%.", ",") end
  local tip = { title = string.format(L.todoAH, name), lines = { { L.todoAHTip, 0.85, 0.78, 0.6 } } }
  if #found > 1 then
    tip.lines[#tip.lines + 1] = { L.todoAHMore, 1, 0.82, 0 }
    for i = 2, math.min(#found, 6) do
      local f = found[i]
      tip.lines[#tip.lines + 1] = { (f.c.link and f.c.link:match("%[(.-)%]") or "?") .. " : " .. Coins(f.price), 1, 1, 1 }
    end
  end
  local gain = loot._GainParts and (loot._GainParts(best.c.eval)) or ""
  lines[#lines + 1] = { kind = "card", link = best.c.link, icon = select(5, root.Game.ItemInstant(best.c.link)), quality = 2,
                        name = string.format(L.todoAH, name), nameColor = { 1, 1, 1 },
                        source = string.format(L.todoAHSrc, Coins(best.price), ratio), gain = gain, tip = tip, ah = true,
                        onClick = function() root.Open("loot") end, onRight = function() root.Open("loot") end }
end

-- Amélioration vendue par un PNJ (sources intégrées) : l'acheter (clic : y aller)
local function VendorTodo(lines)
  local loot = root.mods.ForeverLoot
  if not (loot and loot.BiS and loot.ATT and loot.ATT.Available() and loot.ATT.Vendors) then return end
  local level = UnitLevel("player")
  local n = 0
  for _, s in pairs(loot.BiS(2, level)) do
    for _, c in ipairs(s.items) do
      if n < 1 and c.src ~= "bags" and not loot.Owned(c.id) then
        local vendors = loot.ATT.Vendors(c.id)
        if #vendors > 0 then
          n = n + 1
          local best = root.Nav and root.Nav.Closest(vendors) or vendors[1]
          local name = c.link and c.link:match("%[(.-)%]") or "?"
          local gain = loot._GainParts and (loot._GainParts(c.eval)) or ""
          lines[#lines + 1] = { kind = "card", link = c.link, icon = select(5, root.Game.ItemInstant(c.link)), quality = 2,
                                name = string.format(L.todoBuyItem, name), nameColor = { 1, 1, 1 }, source = best and best.name or nil,
                                gain = gain, vendor = true, onClick = function() if best then Go(best.mapID, best.x, best.y, best.name) end end,
                                onRight = function() root.Open("loot") end }
        end
      end
    end
  end
end

-- Quêtes à ton niveau (Questie) : zones avec le plus de quêtes disponibles, clic : itinéraire vers le donneur le plus proche
local function QuestTodo(lines)
  local Q = root.Quests
  if not (Q and Q.Available()) then return end
  local level = UnitLevel("player")
  for _, z in ipairs(Q.Zones(2)) do
    local tip = { title = z.name, lines = {} }
    for i, q in ipairs(z.quests) do
      if i <= 10 then
        local col = (q.level > level + 1 and { 1, 0.66, 0.24 }) or (q.level < level - 1 and { 0.6, 0.8, 0.6 }) or { 1, 1, 0.6 }
        tip.lines[#tip.lines + 1] = { "[" .. q.level .. "] " .. q.name, col[1], col[2], col[3] }
      end
    end
    if #z.quests > 10 then tip.lines[#tip.lines + 1] = { string.format(L.todoQuestsMore, #z.quests - 10), 0.7, 0.7, 0.7 } end
    if z.giver then tip.lines[#tip.lines + 1] = { string.format(L.todoQuestsGiver, z.giver.name or "?"), 0.85, 0.78, 0.6 } end
    local range = z.lo == z.hi and string.format(L.tagLevel, z.lo):gsub("%+", "") or string.format(L.tagRange, z.lo, z.hi)
    lines[#lines + 1] = { kind = "card", icon = "Interface\\GossipFrame\\AvailableQuestIcon", quality = 1, nameColor = { 1, 1, 1 },
                          name = string.format(L.todoQuests, z.name),
                          tags = Chip(L.tagQuests, "ffd100") .. "  " .. Chip(range, "40d860"),
                          source = z.giver and string.format(L.todoQuestsGiver, z.giver.name or "?") or nil,
                          gain = "|cffffd100" .. string.format(L.todoQuestsN, #z.quests) .. "|r", tip = tip, quests = true,
                          onClick = function() if z.giver then Go(z.giver.mapID, z.giver.x, z.giver.y, z.giver.name) end end }
  end
end

local function BuyTodo(lines, res)
  local ns = root.mods.ForeverPrep
  local n = 0
  for _, s in ipairs(res and res.sections or {}) do
    for _, r in ipairs(s.rows or {}) do
      if r.status == "bad" and r.mandatory ~= false and n < 3 and not r.trainer then     -- obligatoires seulement
        n = n + 1
        local title, detail = tostring(r.text):match("^(.-)%s+—%s+(.+)$")
        local tipLines = {}
        if detail then tipLines[#tipLines + 1] = detail end
        tipLines[#tipLines + 1] = { L.rightOpen, 0.85, 0.78, 0.6 }
        lines[#lines + 1] = { kind = "card", icon = r.icon or "Interface\\Icons\\INV_Misc_QuestionMark", quality = 1,
                              name = title or r.text, source = detail, nameColor = r.status == "bad" and { 1, 0.42, 0.35 } or { 1, 0.78, 0.38 },
                              tip = { title = title or r.text, lines = tipLines }, buy = true,
                              onClick = function()
                                if ns.GuideToVendor and #(res.shopping or {}) > 0 then ns.GuideToVendor() else root.Open("prep") end
                              end,
                              onRight = function() root.Open("prep") end }
      end
    end
  end
end

local function Footer(lines)
  for _, t in ipairs({ { "loot", L.loot, "Interface\\Icons\\INV_Chest_Cloth_17" }, { "prep", L.prep, "Interface\\Icons\\INV_Potion_51" },
                       { "heal", L.heal, "Interface\\Icons\\Spell_Holy_GreaterHeal" } }) do
    lines[#lines + 1] = { kind = "head", icon = t[3], title = t[2], text = t[2], right = "|cffd8c8a0" .. L.more .. " »|r",
                          onClick = function() root.Open(t[1]) end, footer = true }
  end
end

function root.NowLines()
  if InCombatLockdown and InCombatLockdown() and last then return last, true, lastTiles end
  wipe(root.nowErrors)
  local prep = root.mods.ForeverPrep
  local res = (prep and prep.Analyze) and Safe("préparation", prep.Analyze) or nil
  local loot = root.mods.ForeverLoot
  local places = (loot and loot.WhereToGo) and Safe("lieux", loot.WhereToGo, 3) or {}
  local lines = { { kind = "head", icon = "Interface\\Icons\\INV_Misc_Note_01", title = L.secTodo, text = L.secTodo } }
  local before = #lines
  Safe("maître de classe", TrainerTodo, lines)
  Safe("équiper", BagTodo, lines)
  Safe("hôtel des ventes", AHTodo, lines)
  Safe("lieux", PlaceTodo, lines, places)
  Safe("quêtes", QuestTodo, lines)
  Safe("marchand", VendorTodo, lines)
  Safe("achats", BuyTodo, lines, res)
  -- en ville (repos) : la tournée qui enchaîne maître, marchands et hôtel des ventes, en tête
  if IsResting and IsResting() and root.TourTodo then
    local ah = false
    for _, l in ipairs(lines) do if l.ah then ah = true end end
    Safe("tournée", root.TourTodo, lines, ah)
  end
  if #lines == before then lines[#lines + 1] = { kind = "info", text = Gray(L.noTodo) } end
  local tiles = root.NowTiles(res, places)
  for _, e in ipairs(root.nowErrors) do lines[#lines + 1] = { kind = "info", text = "|cffff6a5a" .. string.format(L.err, e) .. "|r" } end
  Footer(lines)
  last, lastTiles = lines, tiles
  return lines, false, tiles
end

-- La fenêtre (en-tête, onglets, Accueil) est dans Main.lua : root.RefreshNow, root.ShowNow.

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
local pending = false
ev:SetScript("OnEvent", function(_, event)
  if event ~= "PLAYER_REGEN_ENABLED" and InCombatLockdown and InCombatLockdown() then return end
  -- un seul recalcul pour une série de changements rapprochés (butin ramassé, achats)
  local f, sh = _G.ForeverCompagnonFrame, _G.ForeverCompagnonSheet
  if ((f and f:IsShown()) or (sh and sh:IsShown())) and not pending then
    pending = true
    C_Timer.After(1, function()
      pending = false
      root.RefreshNow()
      if root.RefreshSheet then root.RefreshSheet() end
    end)
  end
end)
