local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end
local L = ns.L
local D = ns.Data
local Print = ns.Print
local K = ns.Kit

-- Équipement : contenu des onglets « À mon niveau » et « Objectif 60 » (affichés par Pages.lua), alerte d'amélioration
-- ramassée, conseils de jet et de récompense de quête, infobulles, diagnostic et commandes.

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
  if r.method == "ep" then                          -- prêtre soigneur : points de soins (Priest.lua)
    return ns.Signed(r.score, 1) .. " |cffd8c8a0" .. L.cardEp .. "|r", ns.Spec.Detail(r.stats)
  end
  if r.method == "heal" then
    local sub = {}
    if math.abs(r.healed or 0) >= 1 then sub[#sub + 1] = string.format(L.cardHealed, ns.Signed(r.healed)) end
    if math.abs(r.hp or 0) >= 1 then sub[#sub + 1] = string.format(L.cardHp, ns.Signed(r.hp)) end
    if math.abs(r.armor or 0) >= 1 then sub[#sub + 1] = string.format(L.gainArmor, ns.Signed(r.armor)) end
    if math.abs(r.hps or 0) < 0.05 then
      -- pas de soins en plus : le gros chiffre est le premier gain positif (mana hors combat, soins avant d'être à sec,
      -- PV, armure) ; une perte n'est jamais le titre d'une amélioration, elle passe dans le détail
      local regen = r.regen or 0
      if regen >= 0.01 then return ns.Signed(regen, 2) .. " |cffd8c8a0" .. L.cardRegen .. "|r", table.concat(sub, " · ") end
      if regen <= -0.01 then sub[#sub + 1] = ns.Signed(regen, 2) .. " " .. L.cardRegen end
      local first = table.remove(sub, 1)
      if first then return first, table.concat(sub, " · ") end
      return L.cardNoHps, ""
    end
    return ns.Signed(r.hps, 1) .. " |cffd8c8a0" .. L.cardHps .. "|r", table.concat(sub, " · ")
  end
  return ns.Signed(r.score, 1) .. " |cffd8c8a0" .. L.cardPoints .. "|r", ""
end
ns._GainParts = GainParts                          -- pour les simulations

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
  local att = (not source) and ns.ATTWhere(c.id)
  if not source and att then source = att end
  -- objet de la base du prêtre (« data ») : la provenance suffit ; sinon, comment tu l'as vu
  local how = c.src ~= "data" and L[SRC[c.src] or "srcTooltip"] or nil
  if not source and not how then source = L.srcUnknown end
  source = (source and how) and (source .. "  ·  " .. how) or source or how
  if ref and ref.ench then source = source .. "  ·  |cffd8c8a0" .. string.format(L.enchTag, ref.ench) .. "|r" end
  local gain, sub = GainParts(c.eval)
  if c.src == "equipped" then gain, sub = "|cff40d860" .. L.refWear:gsub("^ — ", "") .. "|r", "" end
  -- clic droit : la flèche vers le lieu le plus proche où l'obtenir (sources intégrées)
  local go = ns.GoTo and c.src ~= "equipped" and ns.HasPlace(c.id)
  -- « y aller » : petite épingle sur la carte (plus de texte qui chevauche le gain), expliqué au survol
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

-- Prêtre soigneur, « Objectif 60 » : la référence emplacement par emplacement, ta progression, le meilleur calculé
local function SlotIcon(slot)
  local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
  local crop = icon ~= nil
  if not icon and GetInventorySlotInfo and SLOT_NAME[slot] then
    local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_NAME[slot])
    if ok then icon = tex end
  end
  return icon, crop
end

function ns.GoalLines()
  local P = ns.Spec
  local labels = D.referenceLabels[P.RefKey() or ""] or D.referenceLabel
  local label = ns.lang == "en" and labels[2] or labels[1]
  local lines = { { kind = "info", display = "|cffa0a0a0" .. string.format(L.goalIntro, label) .. "|r", text = string.format(L.goalIntro, label) } }
  local nRef, nHave = 0, 0
  local done = #lines
  local goal = P.Goal()
  local twoHanded = false                  -- arme de référence à deux mains : pas de ligne « main gauche »
  for _, row in ipairs(goal) do
    for _, r in ipairs(row.refs) do if ns.Items[r.id] and ns.Items[r.id][1] == 116 then twoHanded = true end end
  end
  for _, row in ipairs(goal) do
    local slot = row.slot
    if not (slot == 17 and twoHanded) then
    local worn = GetInventoryItemLink("player", slot)
    local worn2 = (slot == 11 or slot == 13) and GetInventoryItemLink("player", slot + 1) or nil
    local wornEP = (worn and P.ItemEP(worn) or 0) + (worn2 and P.ItemEP(worn2) or 0)
    if slot == 16 then local off = GetInventoryItemLink("player", 17); if off then wornEP = wornEP + P.ItemEP(off) end end
    local icon, crop = SlotIcon(slot)
    lines[#lines + 1] = { kind = "slot", icon = icon, iconCrop = crop, link = worn, title = L["slot" .. slot] or tostring(slot),
                          right = "|cffa0a0a0" .. string.format(L.goalWornEP, (ns.Signed(wornEP, 1):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%+", ""))) .. "|r",
                          text = (L["slot" .. slot] or "") }
    local refIds = {}
    for _, r in ipairs(row.refs) do
      refIds[r.id] = true
      nRef = nRef + 1
      local have, where = P.Have(r.id)
      if have then nHave = nHave + 1 end
      local link = P.Link(r.id)
      local c = { link = link, id = r.id, src = "ref", eval = P.Evaluate(link), where = P.SourceText(r.id) or ((r.boss and (r.boss .. " — ") or "") .. Zone(r.zone)) }
      local tags = { (have == "worn" and L.goalHave) or (have == "bags" and L.goalBags) or (have == "owned" and string.format(L.goalOwned, where)) or L.goalMissing }
      local ok, why = P.Obtainable(r.id, true)
      if not ok and why == "faction" then tags[#tags + 1] = L.goalOther end
      local req = P.ReqLevel(r.id)
      if req and req > UnitLevel("player") then tags[#tags + 1] = "|cffa0a0a0" .. string.format(L.goalLevel, req) .. "|r" end
      if ns.Items[r.id] and ns.Items[r.id][11] ~= "" then tags[#tags + 1] = "|cffd8c8a0" .. L.goalSet .. "|r" end
      local card = CardFrom(c, r, tags)
      if have == "worn" then card.gain, card.gainSub = L.goalHave, "" end
      card.text = (link:match("%[(.-)%]") or "?") .. " " .. (have or "missing") .. " — " .. (c.where or "")
      lines[#lines + 1] = card
    end
    -- meilleur calculé : seulement si la référence n'est pas à ta portée (autre camp, phase suivante) ou absente.
    -- La référence vient d'une simulation complète (bonus de set, mana sur tout un combat) : un calcul par poids ne la
    -- contredit pas (22/11/2026 : aucun jeu de poids ne retrouve plus de 8 des 16 choix de kami-labs).
    local reachable = false
    for _, r in ipairs(row.refs) do if P.Obtainable(r.id, true) then reachable = true end end
    local b = row.best and row.best[1]
    if b and not refIds[b.id] then
      if not reachable then
        local link = P.Link(b.id)
        local have, where = P.Have(b.id)
        local c = { link = link, id = b.id, src = "data", eval = P.Evaluate(link), where = P.SourceText(b.id) }
        local tags = { "|cff66ccff" .. L.goalCalc .. "|r" }
        if have then tags[#tags + 1] = (have == "worn" and L.goalHave) or (have == "bags" and L.goalBags) or string.format(L.goalOwned, where) end
        local card = CardFrom(c, nil, tags)
        card.text = (link:match("%[(.-)%]") or "?") .. " " .. L.goalBest .. " — " .. (c.where or "")
        lines[#lines + 1] = card
      end
    end
    end
  end
  table.insert(lines, done + 1, { kind = "info", display = "|cffffd100" .. string.format(L.goalDone, nHave, nRef) .. "|r", text = string.format(L.goalDone, nHave, nRef) })
  return lines
end

-- « À mon niveau » : pour chaque emplacement, les 2 meilleurs objets portables jusqu'au niveau choisi, et où les avoir
ns.nearSpan = 0                     -- ton niveau ; le choix est retenu (db.nearSpan)
function ns.NearLines(span)
  span = span or ns.nearSpan
  local level = UnitLevel("player")
  local maxLevel = math.min(60, level + span)
  local lines = {}
  -- (phrase d'introduction remplacée par les tuiles ; gardée dans le texte pour les recherches et les tests)
  if ns.Spec and ns.Spec.Active() then
    lines[#lines + 1] = { kind = "info", display = "|cffa0a0a0" .. string.format(L.nowIntro, maxLevel) .. "|r", text = string.format(L.nowIntro, maxLevel) }
  else
    lines[#lines + 1] = { kind = "info", display = "", text = string.format(L.nearIntro, maxLevel), hidden = true }
  end
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
    local msg = (ns.Spec and ns.Spec.Active()) and string.format(L.nowNothing, maxLevel, table.concat(empty, ", "))
                or string.format(L.nearEmpty, table.concat(empty, ", "))
    lines[#lines + 1] = { kind = "info", display = "|cff808080" .. msg .. "|r", text = msg }
  end
  return lines
end

-- 4.0 : l'affichage est dans l'onglet Équipement de la fenêtre (Pages.lua) ; ici, on le redessine
function ns.Refresh()
  if ns.root and ns.root.RefreshNow then ns.root.RefreshNow() end
end

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

-- 4.0 : options dans le panneau du jeu (Options.lua), fenêtre = onglet Équipement
function ns.ShowOptions() if ns.root and ns.root.ShowOptions then ns.root.ShowOptions() end end
function ns.Toggle() if ns.root and ns.root.Open then ns.root.Open("loot") end end
function ns.ShowTab(t)
  if not (ns.root and ns.root.Open) then return end
  ns.root.lootView = (t == "bis") and "goal" or "now"
  ns.root.Open("loot")
end

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
  ns.root.HookItemTooltip(2, OnTooltipItem)        -- accroche commune (Root.lua)
end

----------------------------------------------------------------------
-- Diagnostic, commandes
----------------------------------------------------------------------
function ns.DiagCollect(add)
  local _, class = UnitClass("player")
  add("")
  add("## Évaluation")
  if ns.Spec and ns.Spec.Active() then
    local I = ns.ItemsInfo or {}
    add(string.format("Méthode : points de soins, profil %s (poids wowsims) ; base wowsims/forever %s du %s, %s objets ; phase %d",
      tostring(ns.Spec.Profile()), tostring(I.commit), tostring(I.date), tostring(I.count), ns.Spec.PHASE))
  else
    add("Méthode : " .. ((class == "PRIEST" and _G.ForeverHealAPI) and "ForeverHeal" or "poids simplifiés (" .. tostring(class) .. ")"))
  end
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
  do
    local names = { "Donjon d'Ombrecroc", "Les Mortemines", "Cavernes des Lamentations", "La Prison", "Profondeurs de Brassenoire" }
    local parts = {}
    for _, n in ipairs(names) do
      local r = ns.DungeonRange and ns.DungeonRange(n)
      parts[#parts + 1] = n .. " " .. (r and (r[1] .. "-" .. tostring(r[2] or "?") .. " (" .. r[3] .. ")") or "?")
    end
    add("Niveaux des donjons : " .. table.concat(parts, " ; "))
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
  elseif cmd == "diag" then ns.ShowDiag()
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then ns.lang, ns.db.lang = arg, arg; ns.Refresh()
  else Print(L.helpText) end
end

function ForeverLoot_OnCompartmentClick() ns.Toggle() end
