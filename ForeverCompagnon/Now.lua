local _, root = ...
local L = root.L
local K = root.Kit

-- « Maintenant » : en haut, quelques tuiles (un chiffre chacune) ; dessous, « À faire » : des actions écrites comme des
-- phrases (maître de classe, donjons et zones d'après tes améliorations et tes quêtes, fabrication, achats), un seul
-- chiffre à droite, le détail dans l'infobulle ; un clic lance l'itinéraire le plus rapide (Nav.Go), un clic droit ouvre
-- l'onglet. Chaque partie est protégée : une erreur devient une ligne lisible (et un point du diagnostic). En combat,
-- rien n'est recalculé (valeurs secrètes sur Forever) : l'écran garde le dernier état connu.

local W, H = 600, 560
local ui, last, lastTiles
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
                                gain = gain, onClick = function() if best then Go(best.mapID, best.x, best.y, best.name) end end,
                                onRight = function() root.Open("loot") end }
        end
      end
    end
  end
end

-- Métiers : rang suivant à apprendre (compétence et niveau atteints) ; Secourisme si tu n'as aucun bandage
local function ProfTodo(lines, res)
  local m = root.mods.ForeverMetiers
  if not (m and m.RankInfo and m.Learned) then return end
  local level = UnitLevel("player")
  for _, k in ipairs(m.Learned()) do
    local ri = m.RankInfo(k)
    if ri and ri.next and ri.rank >= ri.next.skill and level >= ri.next.level then
      local ML = m.L or {}
      lines[#lines + 1] = { kind = "card", icon = m.Data and m.Data.profs[k] and ("Interface\\Icons\\" .. m.Data.profs[k].icon) or "Interface\\Icons\\INV_Misc_Book_09",
                            quality = 1, nameColor = { 1, 1, 1 },
                            name = string.format(L.todoProfRank, m.ProfName(k), ML["rank_" .. ri.next.key] or ri.next.key),
                            source = string.format(L.todoProfRankSrc, ri.rank, ri.max, ri.next.cap) .. (m.Trainer and (" · " .. m.Trainer(k, ri.next.key)) or ""),
                            onClick = function() root.Open("metiers") end, onRight = function() root.Open("metiers") end }
    end
  end
  local needBandage = false
  for _, sec in ipairs(res and res.sections or {}) do
    for _, r in ipairs(sec.rows or {}) do
      if r.kind == "bandage" or (r.status == "warn" and tostring(r.text):lower():find("bandage", 1, true)) then needBandage = true end
    end
  end
  local skills = m.db and m.db.skills or {}
  if needBandage and not skills.firstaid then
    lines[#lines + 1] = { kind = "card", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", quality = 1, nameColor = { 1, 1, 1 },
                          name = L.todoFirstAid, source = L.todoFirstAidSrc, firstaid = true,
                          onClick = function() root.Open("metiers") end, onRight = function() root.Open("metiers") end }
  end
end

local function CraftTodo(lines)
  local ns = root.mods.ForeverMetiers
  if not (ns and ns.LevelLines) then return end
  for _, l in ipairs(ns.LevelLines()) do
    if l.kind == "card" then
      local c = {}
      for k, v in pairs(l) do c[k] = v end
      c.onRight = function() root.Open("metiers") end
      c.onClick = c.onClick or c.onRight
      lines[#lines + 1] = c
      return
    end
  end
end

local function BuyTodo(lines, res)
  local ns = root.mods.ForeverPrep
  local n = 0
  for _, s in ipairs(res and res.sections or {}) do
    for _, r in ipairs(s.rows or {}) do
      if (r.status == "warn" or r.status == "bad") and n < 3 and not r.trainer then
        n = n + 1
        local title, detail = tostring(r.text):match("^(.-)%s+—%s+(.+)$")
        local tipLines = {}
        if detail then tipLines[#tipLines + 1] = detail end
        tipLines[#tipLines + 1] = { L.rightOpen, 0.85, 0.78, 0.6 }
        lines[#lines + 1] = { kind = "card", icon = r.icon or "Interface\\Icons\\INV_Misc_QuestionMark", quality = 1,
                              name = title or r.text, source = detail, nameColor = r.status == "bad" and { 1, 0.42, 0.35 } or { 1, 0.78, 0.38 },
                              tip = { title = title or r.text, lines = tipLines },
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
                       { "metiers", L.metiers, "Interface\\Icons\\Trade_Tailoring" }, { "heal", L.heal, "Interface\\Icons\\Spell_Holy_GreaterHeal" } }) do
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
  Safe("métiers (rangs)", ProfTodo, lines, res)
  Safe("lieux", PlaceTodo, lines, places)
  Safe("métiers", CraftTodo, lines)
  Safe("marchand", VendorTodo, lines)
  Safe("achats", BuyTodo, lines, res)
  if #lines == before then lines[#lines + 1] = { kind = "info", text = Gray(L.noTodo) } end
  local tiles = root.NowTiles(res, places)
  for _, e in ipairs(root.nowErrors) do lines[#lines + 1] = { kind = "info", text = "|cffff6a5a" .. string.format(L.err, e) .. "|r" } end
  Footer(lines)
  last, lastTiles = lines, tiles
  return lines, false, tiles
end

----------------------------------------------------------------------
-- Fenêtre
----------------------------------------------------------------------
local function Tile(parent)
  local t = CreateFrame("Button", nil, parent)
  t:SetHeight(64)
  t.bg = t:CreateTexture(nil, "BACKGROUND")
  t.bg:SetAllPoints()
  t.bg:SetColorTexture(0.12, 0.1, 0.08, 0.9)
  t.bar = t:CreateTexture(nil, "ARTWORK")
  t.bar:SetPoint("TOPLEFT", 2, -2)
  t.bar:SetPoint("TOPRIGHT", -2, -2)
  t.bar:SetHeight(3)
  local hl = t:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0.3, 0.10)
  t.border = K.Border(t, 0.45, 0.37, 0.24, 1, "BORDER")
  t.value = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  t.value:SetPoint("TOP", 0, -12)
  t.value:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
  t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.label:SetPoint("BOTTOM", 0, 8)
  t.label:SetTextColor(0.85, 0.78, 0.6)
  t:SetScript("OnClick", function(self) if self.open then root.Open(self.open) end end)
  t:SetScript("OnEnter", function(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(self.tip.title or "", 1, 0.82, 0)
    for _, ln in ipairs(self.tip.lines or {}) do GameTooltip:AddLine(ln, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  t:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return t
end

function root.RefreshNow()
  if not (ui and ui:IsShown()) then return end
  local lines, stale, tiles = root.NowLines()
  ui.status:SetText(stale and ("|cffffc860" .. L.combat .. "|r") or "")
  local role = root.Role()
  for _, b in ipairs(ui.roleBtns) do if b.SetActive then b:SetActive(b.role == role) else b.active = (b.role == role) end end
  tiles = tiles or {}
  local n = math.max(1, #tiles)
  local gap = 10
  local tw = (W - 32 - gap * (n - 1)) / n
  for i, t in ipairs(ui.tiles) do
    local d = tiles[i]
    t:SetShown(d ~= nil)
    if d then
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", 16 + (i - 1) * (tw + gap), -100)
      t:SetWidth(tw)
      t.value:SetText(d.value)
      t.label:SetText(d.label)
      t.bar:SetColorTexture(d.color[1], d.color[2], d.color[3], 1)
      t.open, t.tip = d.open, d.tip
    end
  end
  ui.list.Render(lines)
end

local function Create()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverCompagnonNowFrame", UIParent, "BasicFrameTemplateWithInset")
  root.SafeClose(ui)
  ui:SetSize(W, H)
  ui:SetPoint("CENTER", 25, 20)
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverCompagnonNowFrame")
  ui:Hide()
  K.Dress(ui, "Interface\\Icons\\Spell_Holy_PowerWordShield", L.title .. " — " .. L.now)
  ui.head = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ui.head:SetPoint("TOPLEFT", 18, -34)
  K.TitleFont(ui.head, 20, "GameFontNormalLarge")
  ui.head:SetText(L.nowTitle)
  local x = -18
  for _, a in ipairs({ { "Interface\\Icons\\INV_Misc_Note_01", L.diag, function() root.ShowDiag() end },
                       { "Interface\\Icons\\INV_Misc_Spyglass_02", L.probe, function() root.ShowProbe() end },
                       { "Interface\\Icons\\INV_Misc_Gear_08", L.test, function() root.RunTests() end },
                       { "Interface\\Icons\\Spell_ChargePositive", L.refresh, function() last = nil; root.RefreshNow() end } }) do
    local b = K.Action(ui, a[1], a[2], nil, a[3])
    b:SetPoint("TOPRIGHT", x, -30)
    x = x - 52
  end
  -- rôle (le client ne donne pas les talents) : boutons des rôles possibles pour la classe
  ui.roleLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ui.roleLabel:SetPoint("TOPLEFT", 18, -66)
  ui.roleLabel:SetText(L.role)
  ui.roleBtns = {}
  local prev
  for _, r in ipairs(root.ClassRoles()) do
    local b = K.Tab(ui, L["role_" .. r], function() root.SetRole(r) end)
    b:SetHeight(22)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", ui.roleLabel, "RIGHT", 8, 0) end
    K.Tooltip(b, L["role_" .. r], L.roleTip)
    b.role = r
    ui.roleBtns[#ui.roleBtns + 1] = b
    prev = b
  end
  ui.status = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.status:SetPoint("TOPRIGHT", -20, -84)
  ui.tiles = {}
  for i = 1, 4 do ui.tiles[i] = Tile(ui) end
  ui.list = K.CardList(ui, W - 60)
  ui.list.scroll:SetPoint("TOPLEFT", 16, -174)
  ui.list.scroll:SetPoint("BOTTOMRIGHT", -34, 16)
  K.Backdrop(ui, ui.list.scroll, 0.6, 6)
  ui:SetScript("OnShow", function() root.RefreshNow() end)
  return ui
end

function root.ShowNow()
  Create()
  if ui:IsShown() then ui:Hide() else ui:Show() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" and InCombatLockdown and InCombatLockdown() then return end
  if ui and ui:IsShown() then C_Timer.After(0.5, root.RefreshNow) end
end)
