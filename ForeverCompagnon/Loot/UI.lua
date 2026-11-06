local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end
local L = ns.L
local D = ns.Data
local Print = ns.Print
local K = ns.Kit

-- Fenêtre de ForeverLoot : une fiche par emplacement (comme la fiche personnage), et pour chaque emplacement des cartes
-- d'objets : icône encadrée de la couleur de qualité, nom, d'où il vient, et le gain pour toi en grand à droite.

local W, H = 700, 640
local ui
local tab = "near"

local function Zone(key)
  local z = D.zones[key]
  if not z then return key or "?" end
  return ns.lang == "en" and z[2] or z[1]
end

local SRC = { equipped = "srcEquipped", bags = "srcBags", loot = "srcLoot", roll = "srcRoll", chat = "srcChat",
              quest = "srcQuest", vendor = "srcVendor", tooltip = "srcTooltip", ref = "srcRef", dj = "srcDj", djquest = "srcDjQuest" }
local SLOT_NAME = { [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [5] = "ChestSlot", [6] = "WaistSlot", [7] = "LegsSlot",
                    [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot", [11] = "Finger0Slot", [13] = "Trinket0Slot",
                    [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot" }
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
                  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }
local Instant = function(x) return ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(x) end
local Info = function(x) return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(x) end

-- Gain en deux parties : le grand chiffre (soins/s ou points) et le détail
local function GainParts(r)
  if not r then return "", "" end
  if r.method == "heal" then
    local sub = {}
    if math.abs(r.healed or 0) >= 1 then sub[#sub + 1] = string.format(L.cardHealed, ns.Signed(r.healed)) end
    if math.abs(r.hp or 0) >= 1 then sub[#sub + 1] = string.format(L.cardHp, ns.Signed(r.hp)) end
    if math.abs(r.armor or 0) >= 1 then sub[#sub + 1] = string.format(L.gainArmor, ns.Signed(r.armor)) end
    if math.abs(r.hps or 0) < 0.05 then
      -- pas de soins en plus : la régénération hors combat (Esprit) est le gain principal, sinon la survie
      if math.abs(r.regen or 0) >= 0.01 then return ns.Signed(r.regen, 2) .. " |cffd8c8a0" .. L.cardRegen .. "|r", table.concat(sub, " · ") end
      return L.cardNoHps, table.concat(sub, " · ")
    end
    return ns.Signed(r.hps, 1) .. " |cffd8c8a0" .. L.cardHps .. "|r", table.concat(sub, " · ")
  end
  return ns.Signed(r.score, 1) .. " |cffd8c8a0" .. L.cardPoints .. "|r", ""
end

----------------------------------------------------------------------
-- Éléments réutilisés : cartes, titres d'emplacement, lignes d'information
----------------------------------------------------------------------
local cards, slots, infos = {}, {}, {}
local cu, su, iu = 0, 0, 0
ns._view = { cards = cards, slots = slots }          -- pour les simulations

local function Card()
  cu = cu + 1
  local c = cards[cu]
  if not c then
    c = CreateFrame("Button", nil, ui.content)
    c:SetHeight(46)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.3, 0.10)
    c.iconFrame = CreateFrame("Frame", nil, c)
    c.iconFrame:SetSize(36, 36)
    c.iconFrame:SetPoint("LEFT", 8, 0)
    c.icon = c.iconFrame:CreateTexture(nil, "ARTWORK")
    c.icon:SetPoint("TOPLEFT", 1, -1)
    c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.qborder = K.Border(c.iconFrame, 1, 1, 1, 1, "OVERLAY")
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOPLEFT", c.iconFrame, "TOPRIGHT", 10, -2)
    c.name:SetJustifyH("LEFT")
    c.tags = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.tags:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
    c.tags:SetJustifyH("LEFT")
    c.src = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.src:SetPoint("BOTTOMLEFT", c.iconFrame, "BOTTOMRIGHT", 10, 2)
    c.src:SetJustifyH("LEFT")
    c.src:SetTextColor(0.72, 0.66, 0.55)
    c.gain = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    c.gain:SetPoint("TOPRIGHT", -10, -6)
    c.gain:SetJustifyH("RIGHT")
    c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.sub:SetPoint("BOTTOMRIGHT", -10, 6)
    c.sub:SetJustifyH("RIGHT")
    c.sub:SetTextColor(0.72, 0.66, 0.55)
    c.star = c:CreateTexture(nil, "OVERLAY")
    c.star:SetSize(14, 14)
    c.star:SetPoint("TOPLEFT", c.iconFrame, "TOPLEFT", -5, 5)
    c.star:SetTexture("Interface\\COMMON\\FavoritesIcon")
    c:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        GameTooltip:Show()
      end
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnClick", function(self, button)
      if self.link and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link); return end
      if button == "RightButton" and self.onRight then self.onRight() end          -- clic droit : y aller (flèche)
    end)
    cards[cu] = c
  end
  c:Show()
  return c
end

local function SlotHead()
  su = su + 1
  local h = slots[su]
  if not h then
    h = CreateFrame("Button", nil, ui.content)
    h:SetHeight(34)
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints()
    h.bg:SetColorTexture(0.32, 0.22, 0.08, 0.35)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(26, 26)
    h.icon:SetPoint("LEFT", 6, 0)
    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", h.icon, "RIGHT", 8, 0)
    K.TitleFont(h.title, 17, "GameFontNormal")
    h.worn = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.worn:SetPoint("RIGHT", -10, 0)
    h.worn:SetJustifyH("RIGHT")
    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetPoint("BOTTOMLEFT"); h.rule:SetPoint("BOTTOMRIGHT"); h.rule:SetHeight(1)
    h.rule:SetColorTexture(0.75, 0.56, 0.18, 0.9)
    h:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        GameTooltip:Show()
      end
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slots[su] = h
  end
  h:Show()
  return h
end

local function InfoLine()
  iu = iu + 1
  local f = infos[iu]
  if not f then
    f = ui.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f:SetJustifyH("LEFT")
    infos[iu] = f
  end
  f:ClearAllPoints()
  f:Show()
  return f
end

local function Render(lines)
  for _, o in ipairs(cards) do o:Hide() end
  for _, o in ipairs(slots) do o:Hide() end
  for _, o in ipairs(infos) do o:Hide() end
  cu, su, iu = 0, 0, 0
  local width = ui.content:GetWidth()
  if type(width) ~= "number" or width <= 0 then width = W - 70 end
  local y, stripe = -6, 0
  for _, l in ipairs(lines) do
    if l.kind == "slot" or l.kind == "dungeon" then
      local h = SlotHead()
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 0, y - 6)
      h:SetPoint("RIGHT", ui.content, "RIGHT", 0, 0)
      h.icon:SetTexture(l.icon)
      if l.iconCrop then h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) else h.icon:SetTexCoord(0, 1, 0, 1) end
      h.title:SetText(l.title)
      h.worn:SetText(l.right or "")
      h.link = l.link
      y = y - 44
      stripe = 0
    elseif l.kind == "card" then
      local c = Card()
      stripe = stripe + 1
      c.bg:SetColorTexture(1, 1, 1, stripe % 2 == 0 and 0.035 or 0.0)
      c.link, c.onRight = l.link, l.onRight
      local q = QUALITY[l.quality or 1] or QUALITY[1]
      for _, t in ipairs(c.qborder) do t:SetColorTexture(q[1], q[2], q[3], 1) end
      c.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      c.name:SetText(l.name or "?")
      c.name:SetTextColor(q[1], q[2], q[3])
      c.tags:SetText(l.tags or "")
      c.src:SetText(l.source or "")
      c.src:SetWidth(width - 230)
      c.gain:SetText(l.gain or "")
      c.sub:SetText(l.gainSub or "")
      -- nom et étiquettes sans chevaucher le gain : coupés s'ils sont trop longs
      local gw = c.gain:GetStringWidth()
      gw = (type(gw) == "number" and gw) or 0
      local room = width - 70 - (gw > 0 and gw + 24 or 0)
      local nw = c.name:GetStringWidth()
      nw = (type(nw) == "number" and nw) or 0
      if nw > room then c.name:SetWidth(math.max(60, room)); nw = room else c.name:SetWidth(0) end
      if c.name.SetWordWrap then c.name:SetWordWrap(false) end
      if c.tags.SetWordWrap then c.tags:SetWordWrap(false) end
      c.tags:SetWidth(math.max(1, room - nw - 8))
      c.tags:SetShown(room - nw - 8 > 30)
      c.star:SetShown(l.ref and true or false)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 6, y)
      c:SetPoint("RIGHT", ui.content, "RIGHT", 0, 0)
      y = y - 48
    else
      -- information ou ligne simple
      local f = InfoLine()
      f:SetFontObject(l.boss and "GameFontNormal" or "GameFontHighlightSmall")
      f:SetWidth(width - 24)
      f:SetText(l.display or l.text)
      f:SetPoint("TOPLEFT", l.boss and 8 or 14, y - (l.boss and 4 or 2))
      local fh = f:GetStringHeight()
      y = y - ((type(fh) == "number" and fh > 0) and fh or 12) - (l.boss and 8 or 5)
    end
  end
  ui.content:SetHeight(-y + 10)
end

----------------------------------------------------------------------
-- Contenu des onglets (chaque élément garde aussi un texte complet, pour les recherches et les tests)
----------------------------------------------------------------------
local function CardFrom(c, ref, extraTags)
  local name, _, quality, _, _, _, _, _, _, icon = Info(c.link)
  local _, _, _, _, iconI = Instant(c.link)
  local tags = {}
  local lvl = c.eval and c.eval.minLevel or 0
  if lvl > UnitLevel("player") then tags[#tags + 1] = "|cffff6a5a" .. string.format(L.cardLevel, lvl) .. "|r" end
  if ref then tags[#tags + 1] = "|cffffd100" .. L.cardRef .. "|r" end
  if ref and ref.new then tags[#tags + 1] = "|cff66ccff" .. L.newTag .. "|r" end
  for _, t in ipairs(extraTags or {}) do tags[#tags + 1] = t end
  local owned = ns.Owned(c.id)
  if owned then tags[#tags + 1] = "|cff66ccff" .. owned .. "|r" end
  -- d'où il vient : boss et donjon (référence, DungeonJournal, butin vu), sinon All The Things, sinon comment tu l'as vu
  local source
  if ref then
    source = (ref.boss and (ref.boss .. " — ") or "") .. Zone(ref.zone)
  elseif c.where then
    source = c.where
  end
  local att = ns.ATTWhere(c.id)
  if not source and att then source = att end
  source = (source and (source .. "  ·  ") or "") .. (L[SRC[c.src] or "srcTooltip"])
  if ref and ref.ench then source = source .. "  ·  |cffd8c8a0" .. string.format(L.enchTag, ref.ench) .. "|r" end
  local gain, sub = GainParts(c.eval)
  if c.src == "equipped" then gain, sub = "|cff40d860" .. L.refWear:gsub("^ — ", "") .. "|r", "" end
  -- clic droit : la flèche vers le lieu le plus proche où l'obtenir (sources intégrées)
  local go = ns.GoTo and c.src ~= "equipped" and ns.HasPlace(c.id)
  if go then source = source .. "  ·  |cff66ccff" .. L.goTag .. "|r" end       -- sur la ligne de la source (place)
  return { kind = "card", link = c.link, ref = ref, name = name or (c.link and c.link:match("%[(.-)%]")) or "?",
           quality = quality or 1, icon = icon or iconI, tags = table.concat(tags, "  "), source = source, gain = gain, gainSub = sub,
           onRight = go and function() ns.GoTo(c.id) end or nil }
end

-- Bandeau des sources : ForeverHeal, DungeonJournal, Syndicator, All The Things (vert = actif)
local function StatusLine(lines)
  local _, class = UnitClass("player")
  local api = _G.ForeverHealAPI
  local fdj = ns.DJ()
  local nd = 0
  if fdj then for _ in pairs(fdj.DB) do nd = nd + 1 end end
  local function chip(on, label)
    return (on and "|TInterface\\COMMON\\Indicator-Green:14|t " or "|TInterface\\COMMON\\Indicator-Gray:14|t ")
           .. (on and label or ("|cff808080" .. label .. "|r"))
  end
  local chips = {
    chip(class == "PRIEST" and api, "ForeverHeal"),
    chip(fdj ~= nil, fdj and string.format(L.chipDJ, nd) or "DungeonJournal"),
    chip(_G.Syndicator and _G.Syndicator.API, "Syndicator"),
    chip(ns.ATT.Available(), "All The Things"),
  }
  local legacy = { (class == "PRIEST" and api) and L.methodHeal or L.methodWeights }
  if D.reference[class] then legacy[#legacy + 1] = string.format(L.refLabel, ns.lang == "en" and D.referenceLabel[2] or D.referenceLabel[1]) end
  legacy[#legacy + 1] = fdj and string.format(L.djOn, nd) or L.djOff
  if _G.Syndicator and _G.Syndicator.API then legacy[#legacy + 1] = L.syndOn end
  if ns.ATT.Available() then legacy[#legacy + 1] = L.attOn end
  lines[#lines + 1] = { kind = "info", display = table.concat(chips, "      "), text = table.concat(legacy, "\n") }
  if D.reference[class] then
    lines[#lines + 1] = { kind = "info", display = "|TInterface\\COMMON\\FavoritesIcon:14|t |cffa0a0a0" .. string.format(L.refLabel, ns.lang == "en" and D.referenceLabel[2] or D.referenceLabel[1]) .. "|r",
                          text = "" }
  end
end

function ns.BisLines()
  local lines = {}
  StatusLine(lines)
  local bis = ns.BiS(3)
  for _, slot in ipairs(D.slotOrder) do
    local worn = GetInventoryItemLink("player", slot)
    local worn2 = (slot == 11 or slot == 13) and GetInventoryItemLink("player", slot + 1) or nil
    local wornTxt = worn and (worn .. (worn2 and (" + " .. worn2) or "")) or worn2
    local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
    local crop = icon ~= nil
    if not icon and GetInventorySlotInfo and SLOT_NAME[slot] then
      local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_NAME[slot])
      if ok then icon = tex end
    end
    lines[#lines + 1] = { kind = "slot", icon = icon, iconCrop = crop, link = worn, title = L["slot" .. slot] or tostring(slot),
                          right = "|cffa0a0a0" .. string.format(L.equipped, wornTxt or L.nothing) .. "|r",
                          text = (L["slot" .. slot] or tostring(slot)) .. "  " .. string.format(L.equipped, wornTxt or L.nothing) }
    local s = bis[slot]
    local shown = {}
    for _, c in ipairs(s and s.items or {}) do
      local card = CardFrom(c, c.ref)
      local att = (not c.where) and ns.ATTWhere(c.id)
      card.text = c.link .. " — " .. ns.GainText(c.eval) .. " (" .. (L[SRC[c.src] or "srcTooltip"]) .. (c.where and string.format(L.at, c.where) or "") .. ")"
                  .. (att and string.format(L.attTag, att) or "") .. (ns.Owned(c.id) and string.format(L.ownTag, ns.Owned(c.id)) or "")
                  .. ((c.ref and c.ref.ench) and (" " .. string.format(L.enchTag, c.ref.ench)) or "")
                  .. (c.ref and (" " .. string.format(L.refLine, "", c.ref.boss and (c.ref.boss .. ", ") or "", Zone(c.ref.zone), "")) or "")
      lines[#lines + 1] = card
      shown[c.id] = true
    end
    for _, c in ipairs(s and s.refs or {}) do
      if not shown[c.id] then
        local r = c.ref
        local card = CardFrom(c, r)
        local att = ns.ATTWhere(c.id)
        card.text = string.format(L.refLine, c.link, r.boss and (r.boss .. ", ") or "", Zone(r.zone), "")
                    .. (r.ench and (" " .. string.format(L.enchTag, r.ench)) or "") .. (att and string.format(L.attTag, att) or "")
        lines[#lines + 1] = card
      end
    end
    if (not s or #s.items == 0) and not (s and #s.refs > 0) then
      lines[#lines + 1] = { kind = "info", display = "|cff808080" .. L.noCandidate .. "|r", text = L.noCandidate }
    end
  end
  return lines
end

-- « À mon niveau » : pour chaque emplacement, les 2 meilleurs objets portables jusqu'au niveau choisi, et où les avoir
ns.nearSpan = 5
function ns.NearLines(span)
  span = span or ns.nearSpan
  local level = UnitLevel("player")
  local maxLevel = math.min(60, level + span)
  local lines = {}
  lines[#lines + 1] = { kind = "info", display = "|cffd8c8a0" .. string.format(L.nearIntro, maxLevel) .. "|r", text = string.format(L.nearIntro, maxLevel) }
  if not ns.DJ() and not (ns.ATT and ns.ATT.Available()) then lines[#lines + 1] = { kind = "info", display = "|cffa0a0a0" .. L.djOff .. "|r", text = L.djOff } end
  local bis = ns.BiS(2, maxLevel)
  local empty = {}
  for _, slot in ipairs(D.slotOrder) do
    local s = bis[slot]
    local items = s and s.items or {}
    if #items == 0 then
      empty[#empty + 1] = L["slot" .. slot] or tostring(slot)
    else
      local worn = GetInventoryItemLink("player", slot)
      local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
      local crop = icon ~= nil
      if not icon and GetInventorySlotInfo and SLOT_NAME[slot] then
        local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_NAME[slot])
        if ok then icon = tex end
      end
      lines[#lines + 1] = { kind = "slot", icon = icon, iconCrop = crop, link = worn, title = L["slot" .. slot] or tostring(slot),
                            right = "|cffa0a0a0" .. string.format(L.equipped, worn or L.nothing) .. "|r",
                            text = (L["slot" .. slot] or "") .. " " .. string.format(L.equipped, worn or L.nothing) }
      for _, c in ipairs(items) do
        local card = CardFrom(c, c.ref)
        card.text = c.link .. " — " .. ns.GainText(c.eval) .. " " .. (c.where or ns.ATTWhere(c.id) or "")
        lines[#lines + 1] = card
      end
    end
  end
  if #empty > 0 then
    lines[#lines + 1] = { kind = "info", display = "|cff808080" .. string.format(L.nearEmpty, table.concat(empty, ", ")) .. "|r",
                          text = string.format(L.nearEmpty, table.concat(empty, ", ")) }
  end
  return lines
end

function ns.DungeonLines()
  local lines = { { kind = "info", display = "|cffa0a0a0" .. L.dungeonsHelp .. "|r", text = L.dungeonsHelp } }
  local zones = {}
  local function Z(name) zones[name] = zones[name] or { bosses = {}, refs = {}, dj = {}, djOrder = {} }; return zones[name] end
  for zone, bosses in pairs(ns.gdb.dungeons) do Z(zone).bosses = bosses end
  local _, class = UnitClass("player")
  for _, r in ipairs(D.reference[class] or {}) do table.insert(Z(Zone(r.zone)).refs, r) end
  local myFaction = UnitFactionGroup("player")
  for _, it in ipairs(ns.DJItems()) do
    local _, link = Info(it.id)
    if link and not (it.faction and myFaction and it.faction ~= myFaction) then
      local r = ns.Evaluate(link)
      if r and r.wearable and (r.score or 0) > ns.MIN_GAIN then
        local z = Z(it.dungeon)
        if not z.dj[it.boss] then z.dj[it.boss] = {}; table.insert(z.djOrder, it.boss) end
        table.insert(z.dj[it.boss], { link = link, eval = r, quest = it.quest, id = it.id })
      end
    end
  end
  local names = {}
  for z in pairs(zones) do names[#names + 1] = z end
  table.sort(names)
  local any = false
  for _, zname in ipairs(names) do
    local zz = zones[zname]
    local nDj = 0
    for _, items in pairs(zz.dj) do nDj = nDj + #items end
    lines[#lines + 1] = { kind = "dungeon", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", iconCrop = true, title = zname,
                          right = nDj > 0 and ("|cff40d860" .. string.format(L.djForYou, nDj) .. "|r") or "", text = zname }
    for _, boss in ipairs(zz.djOrder) do
      lines[#lines + 1] = { kind = "info", boss = true, display = "|cffffd100" .. boss .. "|r", text = boss }
      table.sort(zz.dj[boss], function(a, b) return a.eval.score > b.eval.score end)
      for _, e in ipairs(zz.dj[boss]) do
        any = true
        local card = CardFrom({ link = e.link, id = e.id or ns.ItemID(e.link), eval = e.eval, src = e.quest and "djquest" or "dj", where = zname .. " — " .. boss })
        card.text = e.link .. string.format(L.forYou, ns.GainText(e.eval))
        lines[#lines + 1] = card
      end
    end
    local bnames = {}
    for b in pairs(zz.bosses) do bnames[#bnames + 1] = b end
    table.sort(bnames)
    for _, b in ipairs(bnames) do
      local bname = (b == "?") and L.unknownBoss or b
      lines[#lines + 1] = { kind = "info", boss = true, display = "|cffffd100" .. bname .. "|r |cff808080(" .. L.srcChat .. ")|r", text = bname }
      for _, e in pairs(zz.bosses[b]) do
        any = true
        local r = ns.Evaluate(e.link)
        local good = r and r.wearable and (r.score or 0) > ns.MIN_GAIN
        local card = CardFrom({ link = e.link, id = ns.ItemID(e.link), eval = good and r or nil, src = "loot", where = zname .. " — " .. bname },
                              nil, { "|cffa0a0a0×" .. e.n .. "|r" })
        if not good then card.gain, card.gainSub = "", "" end
        card.text = e.link .. " ×" .. e.n .. (good and string.format(L.forYou, ns.GainText(r)) or "")
        lines[#lines + 1] = card
      end
    end
    for _, r in ipairs(zz.refs) do
      local _, link = Info(r.id)
      if link then
        local card = CardFrom({ link = link, id = r.id, eval = ns.Evaluate(link), src = "ref" }, r)
        card.text = link .. L.refTag .. (r.boss and (" — " .. r.boss) or "")
        lines[#lines + 1] = card
      end
    end
  end
  if not any then table.insert(lines, 2, { kind = "info", display = "|cff808080" .. L.dungeonsNone .. "|r", text = L.dungeonsNone }) end
  return lines
end

function ns.Refresh()
  if not ui or not ui:IsShown() then return end
  Render((tab == "dungeons" and ns.DungeonLines()) or (tab == "bis" and ns.BisLines()) or ns.NearLines())
  ui.nearBtn:SetActive(tab == "near")
  ui.bisBtn:SetActive(tab == "bis")
  ui.dunBtn:SetActive(tab == "dungeons")
  for span, b in pairs(ui.spanBtns) do b:SetActive(ns.nearSpan == span); b:SetShown(tab == "near") end
  ui.spanLabel:SetShown(tab == "near")
  ui.scroll:SetPoint("TOPLEFT", 16, tab == "near" and -112 or -82)
end

----------------------------------------------------------------------
-- Fenêtre, options
----------------------------------------------------------------------
----------------------------------------------------------------------
-- Alerte « amélioration ramassée » : en haut de l'écran, icône, gain, bouton Équiper (hors combat)
----------------------------------------------------------------------
-- Équiper : par le lien avec le jeu (ForeverCompagnon/Compat.lua), qui gère le client de Forever
function ns.EquipLink(link)
  local ok, why = ns.Game.Equip(link)
  if not ok then Print(why == "combat" and L.alertCombat or L.alertNoEquip) end
  return ok
end

local alert
function ns.ShowLootAlert(link, r, later)
  if not alert then
    alert = CreateFrame("Frame", "ForeverLootUpgradeAlert", UIParent)
    alert:SetSize(420, 64)
    alert:SetPoint("TOP", 0, -120)
    alert:SetFrameStrata("HIGH")
    K.Panel(alert, 0.92)
    alert.iconFrame = CreateFrame("Button", nil, alert)
    alert.iconFrame:SetSize(44, 44)
    alert.iconFrame:SetPoint("LEFT", 10, 0)
    alert.icon = alert.iconFrame:CreateTexture(nil, "ARTWORK")
    alert.icon:SetPoint("TOPLEFT", 1, -1)
    alert.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    alert.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    alert.qborder = K.Border(alert.iconFrame, 1, 1, 1, 1, "OVERLAY")
    alert.iconFrame:SetScript("OnEnter", function(self)
      if alert.link then GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); pcall(GameTooltip.SetHyperlink, GameTooltip, alert.link); GameTooltip:Show() end
    end)
    alert.iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    alert.title = alert:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alert.title:SetPoint("TOPLEFT", alert.iconFrame, "TOPRIGHT", 10, -2)
    K.TitleFont(alert.title, 15, "GameFontNormal")
    alert.name = alert:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    alert.name:SetPoint("TOPLEFT", alert.title, "BOTTOMLEFT", 0, -3)
    alert.gain = alert:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alert.gain:SetPoint("TOPLEFT", alert.name, "BOTTOMLEFT", 0, -3)
    alert.equip = CreateFrame("Button", nil, alert, "UIPanelButtonTemplate")
    alert.equip:SetSize(80, 22)
    alert.equip:SetPoint("RIGHT", -10, 0)
    alert.equip:SetText(L.alertEquip)
    alert.equip:SetScript("OnClick", function()
      if ns.EquipLink(alert.link) then alert:Hide() end
    end)
    alert:EnableMouse(true)
    alert:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then alert:Hide() end end)
  end
  local name, _, quality, _, _, _, _, _, _, icon = Info(link)
  local _, _, _, _, iconI = Instant(link)
  local q = QUALITY[quality or 1] or QUALITY[1]
  for _, t in ipairs(alert.qborder) do t:SetColorTexture(q[1], q[2], q[3], 1) end
  alert.link = link
  alert.icon:SetTexture(icon or iconI)
  alert.title:SetText(later and string.format(L.alertLater, r.minLevel) or L.alertTitle)
  alert.title:SetTextColor(later and 1 or 0.25, later and 0.75 or 0.85, later and 0.3 or 0.25)
  alert.name:SetText(link or name or "?")
  local gain, sub = GainParts(r)
  alert.gain:SetText(gain .. ((sub ~= "") and ("  ·  " .. sub) or ""))
  alert.equip:SetShown(not later)
  alert:Show()
  if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960) end
  Print(later and L.alertChatLater or L.alertChat, link, gain)
  alert.shownAt = GetTime()
  C_Timer.After(15, function() if alert.shownAt and GetTime() - alert.shownAt >= 14.5 then alert:Hide() end end)
end

local opt
local function ShowOptions()
  if not opt then
    opt = CreateFrame("Frame", "ForeverLootOptionsFrame", ui, "BasicFrameTemplateWithInset")
    ns.SafeClose(opt)
    opt:SetSize(420, 210)
    opt:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -10, -70)
    opt:SetFrameStrata("DIALOG")
    K.Dress(opt, "Interface\\Icons\\INV_Misc_Gear_01", L.optTitle)
    local y = -34
    local function C(text, key)
      local cb = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
      cb:SetSize(22, 22)
      cb:SetPoint("TOPLEFT", 14, y)
      local lab = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      lab:SetPoint("LEFT", cb, "RIGHT", 2, 0)
      lab:SetText(text)
      cb:SetScript("OnShow", function(self) self:SetChecked(ns.db[key]) end)
      cb:SetScript("OnClick", function(self) ns.db[key] = self:GetChecked() and true or false; ns.version = ns.version + 1; ns.Refresh() end)
      y = y - 28
    end
    C(L.optRoll, "rollHelp")
    C(L.optQuest, "questHelp")
    C(L.optTip, "tooltipHint")
    C(L.optHigher, "higher")
    C(L.optLootAlert, "lootAlert")
    opt:Hide()
  end
  opt:SetShown(not opt:IsShown())
end
ns.ShowOptions = ShowOptions

local function CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverLootFrame", UIParent, "BasicFrameTemplateWithInset")
  ns.SafeClose(ui)
  ns.ui = ui
  ui:SetSize(W, H)
  ui:SetPoint("CENTER", -60, 20)
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverLootFrame")
  ui:Hide()
  K.Dress(ui, "Interface\\Icons\\INV_Misc_Bag_10", L.title)
  ui.diagBtn = ns.MakeDiagButton(ui)
  ui.nearBtn = K.Tab(ui, L.tabNear, function() tab = "near"; ns.Refresh() end)
  ui.nearBtn:SetPoint("TOPLEFT", 14, -32)
  ui.bisBtn = K.Tab(ui, L.tabBis60, function() tab = "bis"; ns.Refresh() end)
  ui.bisBtn:SetPoint("LEFT", ui.nearBtn, "RIGHT", 4, 0)
  ui.dunBtn = K.Tab(ui, L.tabDungeons, function() tab = "dungeons"; ns.Refresh() end)
  ui.dunBtn:SetPoint("LEFT", ui.bisBtn, "RIGHT", 4, 0)
  ui.optBtn = K.Action(ui, "Interface\\Icons\\INV_Misc_Gear_01", L.optShort, L.optTip2, function() ShowOptions() end)
  ui.optBtn:SetPoint("TOPRIGHT", -18, -30)
  -- jusqu'à quel niveau regarder (onglet « À mon niveau »)
  ui.spanLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ui.spanLabel:SetPoint("TOPLEFT", 18, -80)
  ui.spanLabel:SetText(L.spanLabel)
  ui.spanBtns = {}
  local prevSpan
  for _, span in ipairs({ 0, 3, 5, 10 }) do
    local b = K.Tab(ui, span == 0 and L.spanNow or string.format(L.spanPlus, span), function() ns.nearSpan = span; ns.Refresh() end)
    b:SetHeight(22)
    b:SetWidth(96)
    if prevSpan then b:SetPoint("LEFT", prevSpan, "RIGHT", 4, 0) else b:SetPoint("LEFT", ui.spanLabel, "RIGHT", 10, 0) end
    ui.spanBtns[span] = b
    prevSpan = b
  end
  local sf = CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 16, -82)
  sf:SetPoint("BOTTOMRIGHT", -34, 16)
  K.Backdrop(ui, sf, 0.6, 6)
  ui.scroll = sf
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(W - 60, 10)
  sf:SetScrollChild(content)
  ui.content = content
  ui:SetScript("OnShow", function() ns.Refresh() end)
  return ui
end

function ns.Toggle()
  CreateUI()
  if ui:IsShown() then ui:Hide() else ui:Show() end
end
function ns.ShowTab(t) CreateUI(); tab = t; if ui:IsShown() then ns.Refresh() else ui:Show() end end

----------------------------------------------------------------------
-- Jet de butin, récompense de quête, infobulles
----------------------------------------------------------------------
function ns.ShowRollAdvice(rollID, link)
  local advice, why = ns.RollAdvice(link)
  local label = advice == "need" and ("|cff40d860" .. L.adviceNeed .. "|r") or ("|cffffd100" .. L.adviceGreed .. "|r")
  Print(L.rollLine, link, label, why)
  ns.lastRoll = { rollID = rollID, advice = advice, why = why }
  for i = 1, 4 do
    local f = _G["GroupLootFrame" .. i]
    if f and f.rollID == rollID then
      if not f.flText then
        f.flText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.flText:SetPoint("BOTTOM", f, "TOP", 0, 2)
      end
      f.flText:SetText("ForeverLoot : " .. label .. " — " .. why)
      f.flText:Show()
    end
  end
end

function ns.ShowQuestChoice(links)
  local idx, why = ns.QuestChoice(links)
  if not idx then return end
  ns.lastQuest = { index = idx, why = why }
  local link = links[idx]
  if why == "best" then
    Print(L.questBest, link, ns.GainText(ns.Evaluate(link)))
  else
    Print(L.questPrice, link)
  end
  for i = 1, #links do
    local f = _G["QuestInfoRewardsFrameQuestInfoItem" .. i] or _G["QuestInfoItem" .. i]
    if f then
      if not f.flGlow then
        f.flGlow = f:CreateTexture(nil, "OVERLAY")
        f.flGlow:SetAllPoints()
        f.flTag = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.flTag:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -1)
      end
      local on = i == idx
      if on then
        if why == "best" then f.flGlow:SetColorTexture(0.2, 1, 0.3, 0.25) else f.flGlow:SetColorTexture(1, 0.8, 0.2, 0.2) end
        f.flTag:SetText(why == "best" and L.questTag or L.questTagPrice)
      end
      f.flGlow:SetShown(on)
      f.flTag:SetShown(on)
    end
  end
end

local function OnTooltipItem(tt)
  if not ns.db or not ns.db.tooltipHint or tt == _G.ForeverHealScanTip then return end
  local _, link = tt:GetItem()
  local id = link and ns.ItemID(link)
  if not id then return end
  ns.Remember(link, "tooltip")
  local _, class = UnitClass("player")
  for _, r in ipairs(D.reference[class] or {}) do
    if r.id == id then
      tt:AddLine(string.format(L.tipRef, (r.boss and (r.boss .. ", ") or "") .. Zone(r.zone)), 0.9, 0.72, 0.3, true)
      if r.ench then tt:AddLine(string.format(L.enchTag, r.ench), 0.6, 0.6, 0.6, true) end
      break
    end
  end
  -- le prêtre a déjà le détail de ForeverHeal dans l'infobulle : ligne de gain seulement pour les autres classes
  if not (class == "PRIEST" and _G.ForeverHealAPI) then
    local r = ns.Evaluate(link)
    if r and r.wearable and (r.score or 0) > ns.MIN_GAIN then tt:AddLine(string.format(L.tipGain, ns.GainText(r)), 0.4, 0.85, 0.4, true) end
  end
end
ns.OnTooltipItem = OnTooltipItem

ns.OnLoaded = function() end
ns.OnLogin = function()
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
      if tt == GameTooltip or tt == ItemRefTooltip then OnTooltipItem(tt) end
    end)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", OnTooltipItem) end
    end
  end
end

----------------------------------------------------------------------
-- Diagnostic, commandes
----------------------------------------------------------------------
function ns.DiagCollect(add)
  local _, class = UnitClass("player")
  add("")
  add("## Évaluation")
  add("Méthode : " .. ((class == "PRIEST" and _G.ForeverHealAPI) and "ForeverHeal" or "poids simplifiés (" .. tostring(class) .. ")"))
  add("")
  add("## Liste de référence (numéro = nom dans ce client, emplacement)")
  for _, r in ipairs(D.reference[class] or {}) do
    local name, _, quality, _, minLevel = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(r.id)
    local _, _, _, equipLoc = ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(r.id)
    add(string.format("  %d = %s (niv. %s, qualité %s, %s), attendu emplacement %d%s%s", r.id, tostring(name or "ABSENT OU PAS ENCORE CHARGÉ"),
      tostring(minLevel), tostring(quality), tostring(equipLoc), r.slot, r.note and (", guide : " .. r.note) or "", (r.ok == false) and " [NON VÉRIFIÉ]" or ""))
  end
  add("")
  local fdj = ns.DJ()
  if fdj then
    local nd = 0
    for _ in pairs(fdj.DB) do nd = nd + 1 end
    add(string.format("DungeonJournal : présent, %d donjons, %d objets (butin + récompenses de quête)", nd, #ns.DJItems()))
  else
    add("DungeonJournal : absent ; butin des donjons tiré des sources intégrées : " .. #ns.DJItems() .. " objets")
  end
  local S = _G.Syndicator
  add("Syndicator : " .. ((S and S.API) and ("présent, prêt : " .. tostring(S.API.IsReady and S.API.IsReady())) or "absent"))
  ns.ATT.Diag(add)
  for _, r in ipairs(D.reference[class] or {}) do
    local w = ns.ATTWhere(r.id)
    if w then add(string.format("  ATT %d : %s", r.id, w)) end
  end
  add("")
  add("## Objets vus : " .. tostring(ns.db.seenCount or 0))
  add("## Butin des donjons noté (tous personnages)")
  for zone, bosses in pairs(ns.gdb.dungeons) do
    local nb, ni = 0, 0
    for _, items in pairs(bosses) do nb = nb + 1; for _ in pairs(items) do ni = ni + 1 end end
    add(string.format("  %s : %d boss, %d objets", zone, nb, ni))
  end
end

SLASH_FOREVERLOOT1 = "/floot"
SLASH_FOREVERLOOT2 = "/bis"
SlashCmdList.FOREVERLOOT = function(msg)
  msg = ((msg or ""):match("^%s*(.-)%s*$")):lower()
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" or cmd == "niveau" or cmd == "level" then ns.ShowTab("near")
  elseif cmd == "bis" then ns.ShowTab("bis")
  elseif cmd == "donjons" or cmd == "dungeons" then ns.ShowTab("dungeons")
  elseif cmd == "diag" then ns.ShowDiag()
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then ns.lang, ns.db.lang = arg, arg; ns.Refresh()
  else Print(L.helpText) end
end

function ForeverLoot_OnCompartmentClick() ns.Toggle() end
