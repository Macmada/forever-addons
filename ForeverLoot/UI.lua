local _, ns = ...
local L = ns.L
local D = ns.Data
local Print = ns.Print

local W, H = 640, 580
local ui
local tab = "bis"

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function Zone(key)
  local z = D.zones[key]
  if not z then return key or "?" end
  return ns.lang == "en" and z[2] or z[1]
end

local SRC = { equipped = "srcEquipped", bags = "srcBags", loot = "srcLoot", roll = "srcRoll", chat = "srcChat",
              quest = "srcQuest", vendor = "srcVendor", tooltip = "srcTooltip", ref = "srcRef" }

----------------------------------------------------------------------
-- Lignes de la liste (réutilisées)
----------------------------------------------------------------------
local rows, used = {}, 0
local function Row()
  used = used + 1
  local r = rows[used]
  if not r then
    r = CreateFrame("Button", nil, ui.content)
    r:SetHeight(20)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 26, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
      if self.link and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
    end)
    rows[used] = r
  end
  r:Show()
  return r
end

local function Render(lines)
  for _, r in ipairs(rows) do r:Hide() end
  used = 0
  local y = -4
  for _, l in ipairs(lines) do
    local r = Row()
    r.link = l.link
    local icon = l.link and select(5, ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(l.link))
    r.icon:SetShown(icon ~= nil)
    if icon then r.icon:SetTexture(icon) end
    r.text:SetFontObject(l.header and "GameFontNormal" or (l.sub and "GameFontNormalSmall" or "GameFontHighlightSmall"))
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", icon and 26 or (l.header and 2 or 12), 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetText(l.text)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, y)
    r:SetPoint("RIGHT", ui.content, "RIGHT", 0, 0)
    local h = l.header and 24 or 20
    r:SetHeight(h)
    y = y - h - (l.header and 2 or 0)
  end
  ui.content:SetHeight(-y + 8)
end

----------------------------------------------------------------------
-- Onglets
----------------------------------------------------------------------
function ns.BisLines()
  local lines = {}
  local _, class = UnitClass("player")
  local api = _G.ForeverHealAPI
  lines[#lines + 1] = { text = "|cffa0a0a0" .. ((class == "PRIEST" and api) and L.methodHeal or L.methodWeights) .. "|r" }
  if D.reference[class] then
    lines[#lines + 1] = { text = "|cffa0a0a0" .. string.format(L.refLabel, ns.lang == "en" and D.referenceLabel[2] or D.referenceLabel[1]) .. "|r" }
  end
  local bis = ns.BiS(3)
  for _, slot in ipairs(D.slotOrder) do
    local worn = GetInventoryItemLink("player", slot)
    if slot == 11 or slot == 13 then
      local w2 = GetInventoryItemLink("player", slot + 1)
      worn = (worn or "") .. ((worn and w2) and " + " or "") .. (w2 or "")
      if worn == "" then worn = nil end
    end
    lines[#lines + 1] = { header = true, text = (L["slot" .. slot] or tostring(slot)) .. "  |cffa0a0a0" .. string.format(L.equipped, worn or L.nothing) .. "|r" }
    local s = bis[slot]
    if not s or #s.items == 0 then
      lines[#lines + 1] = { text = "|cffa0a0a0" .. L.noCandidate .. "|r" }
    else
      for _, c in ipairs(s.items) do
        local where = c.where and string.format(L.at, c.where) or ""
        local lvl = (c.eval.minLevel or 0) > UnitLevel("player") and string.format(L.levelReq, c.eval.minLevel) or ""
        lines[#lines + 1] = { link = c.link, text = c.link .. lvl .. " — " .. ns.GainText(c.eval) .. " |cffa0a0a0(" .. (L[SRC[c.src] or "srcTooltip"]) .. where .. ")|r" }
      end
    end
    for _, c in ipairs(s and s.refs or {}) do
      local r = c.ref
      local status = (c.src == "equipped") and L.refWear or ((c.src == "bags") and L.refHave or (" — " .. ns.GainText(c.eval)))
      local boss = r.boss and (r.boss .. ", ") or ""
      lines[#lines + 1] = { link = c.link, text = "|cffe6b84d" .. string.format(L.refLine, c.link, boss, Zone(r.zone), status)
                                                  .. ((r.ok == false) and " |cffff8000(?)|r" or "") .. "|r" }
    end
  end
  return lines
end

function ns.DungeonLines()
  local lines = { { text = "|cffa0a0a0" .. L.dungeonsHelp .. "|r" } }
  local zones = {}
  for zone, bosses in pairs(ns.gdb.dungeons) do zones[zone] = zones[zone] or {}; zones[zone].bosses = bosses end
  local _, class = UnitClass("player")
  for _, r in ipairs(D.reference[class] or {}) do
    local name = Zone(r.zone)
    zones[name] = zones[name] or {}
    zones[name].refs = zones[name].refs or {}
    table.insert(zones[name].refs, r)
  end
  local names = {}
  for z in pairs(zones) do names[#names + 1] = z end
  table.sort(names)
  local any = false
  for _, z in ipairs(names) do
    lines[#lines + 1] = { header = true, text = z }
    local bosses = zones[z].bosses or {}
    local bnames = {}
    for b in pairs(bosses) do bnames[#bnames + 1] = b end
    table.sort(bnames)
    for _, b in ipairs(bnames) do
      lines[#lines + 1] = { sub = true, text = (b == "?") and L.unknownBoss or b }
      for _, e in pairs(bosses[b]) do
        any = true
        local r = ns.Evaluate(e.link)
        local good = r and r.wearable and (r.score or 0) > 0.3
        lines[#lines + 1] = { link = e.link, text = e.link .. " ×" .. e.n .. (good and string.format(L.forYou, ns.GainText(r)) or "") }
      end
    end
    for _, r in ipairs(zones[z].refs or {}) do
      local _, link = ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(r.id)
      if link then
        lines[#lines + 1] = { link = link, text = "|cffe6b84d" .. link .. L.refTag .. (r.boss and (" — " .. r.boss) or "") .. "|r" }
      end
    end
  end
  if not any then table.insert(lines, 2, { text = "|cffa0a0a0" .. L.dungeonsNone .. "|r" }) end
  return lines
end

function ns.Refresh()
  if not ui or not ui:IsShown() then return end
  Render(tab == "dungeons" and ns.DungeonLines() or ns.BisLines())
  ui.bisBtn:SetEnabled(tab ~= "bis")
  ui.dunBtn:SetEnabled(tab ~= "dungeons")
end

local function CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverLootFrame", UIParent, "BasicFrameTemplateWithInset")
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
  local title = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", 12, -6)
  title:SetText(L.title)
  ui.diagBtn = ns.MakeDiagButton(ui)
  ui.bisBtn = MakeButton(ui, L.tabBis, 100, function() tab = "bis"; ns.Refresh() end)
  ui.bisBtn:SetPoint("TOPLEFT", 14, -30)
  ui.dunBtn = MakeButton(ui, L.tabDungeons, 100, function() tab = "dungeons"; ns.Refresh() end)
  ui.dunBtn:SetPoint("LEFT", ui.bisBtn, "RIGHT", 4, 0)
  local sf = CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 12, -58)
  sf:SetPoint("BOTTOMRIGHT", -32, 96)
  ui.scroll = sf
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(W - 52, 10)
  sf:SetScrollChild(content)
  ui.content = content
  -- options
  local y = 88
  local function C(text, key)
    local cb = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("BOTTOMLEFT", 14, y - 22)
    local lab = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lab:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lab:SetText(text)
    cb:SetScript("OnShow", function(self) self:SetChecked(ns.db[key]) end)
    cb:SetScript("OnClick", function(self) ns.db[key] = self:GetChecked() and true or false; ns.version = ns.version + 1; ns.Refresh() end)
    y = y - 20
  end
  C(L.optRoll, "rollHelp")
  C(L.optQuest, "questHelp")
  C(L.optTip, "tooltipHint")
  C(L.optHigher, "higher")
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
      break
    end
  end
  -- le prêtre a déjà le détail de ForeverHeal dans l'infobulle : ligne de gain seulement pour les autres classes
  if not (class == "PRIEST" and _G.ForeverHealAPI) then
    local r = ns.Evaluate(link)
    if r and r.wearable and (r.score or 0) > 0.3 then tt:AddLine(string.format(L.tipGain, ns.GainText(r)), 0.4, 0.85, 0.4, true) end
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
  if cmd == "" or cmd == "bis" then ns.ShowTab("bis")
  elseif cmd == "donjons" or cmd == "dungeons" then ns.ShowTab("dungeons")
  elseif cmd == "diag" then ns.ShowDiag()
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then ns.lang, ns.db.lang = arg, arg; ns.Refresh()
  else Print(L.helpText) end
end

function ForeverLoot_OnCompartmentClick() ns.Toggle() end
