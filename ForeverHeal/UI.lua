local _, ns = ...
local L = ns.L
local Print = ns.Print

local GREEN, RED, GREY = "|cff40d860", "|cffff5050", "|cffa0a0a0"

----------------------------------------------------------------------
-- Nombres « humains » (virgule décimale en français, signe, milliers)
----------------------------------------------------------------------
local function Fmt(v, dec)
  dec = dec or 0
  local s = string.format("%." .. dec .. "f", math.abs(v))
  local int, frac = s:match("^(%d+)%.?(%d*)$")
  int = int:reverse():gsub("(%d%d%d)", "%1" .. (ns.lang == "en" and "," or " ")):reverse():gsub("^[ ,]", "")
  if frac and frac ~= "" then int = int .. (ns.lang == "en" and "." or ",") .. frac end
  return int
end
function ns.Num(v, dec) return Fmt(v, dec) end
function ns.Signed(v, dec, invert)
  dec = dec or 0
  if math.abs(v) < 0.5 * 10 ^ (-dec) then return GREY .. "0|r" end
  local good = (v > 0) ~= (invert == true)
  return (good and GREEN or RED) .. (v > 0 and "+" or "−") .. Fmt(v, dec) .. "|r"
end
local Signed = ns.Signed

local function Duration(sec)
  if not sec then return "—" end
  if sec == math.huge then return L.unlimited end
  if sec >= 120 then return string.format(L.min, Fmt(sec / 60, 1)) end
  return string.format(L.sec, Fmt(sec, 0))
end
ns.Duration = Duration

local function DurationDelta(a, b)
  if a == math.huge or b == math.huge then
    if a == b then return GREY .. L.unlimited .. "|r" end
    return (b == math.huge and GREEN .. L.unlimited or RED .. Duration(b)) .. "|r"
  end
  if not a or not b then return GREY .. "—|r" end
  local d = b - a
  if math.abs(d) >= 120 then return Signed(d / 60, 1) .. " min" end
  return Signed(d, 0) .. " s"
end

local function IsPriest() return select(2, UnitClass("player")) == "PRIEST" end

----------------------------------------------------------------------
-- Lignes « +45 Endurance » +450 PV » pour un écart de caractéristiques
----------------------------------------------------------------------
function ns.ConversionLines(d, S, rates, mix)
  local lines = {}
  local priest = IsPriest()
  local main = mix and mix[1] and mix[1].spell
  if (d.sta or 0) ~= 0 then lines[#lines + 1] = string.format(L.conv_sta, Signed(d.sta), Signed(d.sta * rates.hpPerSta)) end
  if (d.int or 0) ~= 0 and priest then
    lines[#lines + 1] = string.format(L.conv_int, Signed(d.int), Signed(d.int * rates.manaPerInt), Signed(d.int / rates.intPerCrit, 2))
  end
  if (d.spi or 0) ~= 0 and priest then
    local out = d.spi * rates.regenPerSpi
    local inC = out * rates.castFrac
    lines[#lines + 1] = string.format(L.conv_spi, Signed(d.spi), Signed(out, 2),
      math.abs(inC) >= 0.005 and string.format(L.conv_spiIn, Signed(inC, 2)) or "")
  end
  if (d.heal or 0) ~= 0 and priest and main then
    lines[#lines + 1] = string.format(L.conv_heal, Signed(d.heal), Signed(d.heal * main.coef * main.mult * main.targets), main.name)
  end
  if (d.mp5 or 0) ~= 0 and priest then lines[#lines + 1] = string.format(L.conv_mp5, Signed(d.mp5), Signed(d.mp5 / 5, 2)) end
  if (d.crit or 0) ~= 0 and priest then lines[#lines + 1] = string.format(L.conv_crit, Signed(d.crit, 1)) end
  if (d.hp or 0) ~= 0 then lines[#lines + 1] = string.format(L.conv_hp, Signed(d.hp)) end
  if (d.mana or 0) ~= 0 then lines[#lines + 1] = string.format(L.conv_mana, Signed(d.mana)) end
  if (d.armor or 0) ~= 0 then
    local lvl = S.level or 60
    local before = S.armor / (S.armor + 400 + 85 * lvl)
    local after = (S.armor + d.armor) / (S.armor + d.armor + 400 + 85 * lvl)
    lines[#lines + 1] = string.format(L.conv_armor, Signed(d.armor), Signed(-(after - before) * 100, 1, true))
  end
  for s = 2, 6 do
    local v = d.res and d.res[s] or 0
    if v ~= 0 then lines[#lines + 1] = string.format(L.conv_res, Signed(v), L["res" .. s]) end
  end
  return lines
end

-- Ligne de résultat : soin moyen, soins/s, autonomie
function ns.ResultLine(before, after)
  if not IsPriest() or (before.hps == 0 and after.hps == 0) then return nil end
  -- rien ne change pour tes soins (armure, résistances…) : pas de ligne « Soin moyen 0 · 0 soins/s »
  local sameOom = (before.oom == after.oom) or (before.oom and after.oom and math.abs(after.oom - before.oom) < 0.5)
  if math.abs(after.perCast - before.perCast) < 0.5 and math.abs(after.hps - before.hps) < 0.05 and sameOom then return nil end
  local line = string.format(L.res_line, Signed(after.perCast - before.perCast), Signed(after.hps - before.hps, 1),
                             DurationDelta(before.oom, after.oom))
  if before.healedBeforeOom and after.healedBeforeOom then
    line = line .. string.format(L.res_total, Signed(after.healedBeforeOom - before.healedBeforeOom))
  end
  return line
end

----------------------------------------------------------------------
-- Infobulles des objets
----------------------------------------------------------------------
-- Résultats mémorisés par objet ; effacés quand tes caractéristiques, ton équipement ou ton mélange de sorts changent
local cache, cacheN = {}, 0
ns.tooltipStats = { computed = 0, cached = 0 }

local function Compute(link)
  local ok, cmp = pcall(ns.CompareItem, link)
  if not ok or not cmp then return false end
  local S = ns.Snapshot()
  local rates = ns.Rates(S)
  local lines = ns.ConversionLines(cmp.d, S, rates, ns.Mix())
  local res = ns.ResultLine(cmp.before, cmp.after)
  if #lines == 0 and not res then return false end
  local equipped = GetInventoryItemLink("player", cmp.slot)
  return { header = equipped and string.format(L.vs, equipped) or L.vsEmpty, lines = lines, res = res }
end

local function OnTooltipItem(tt)
  if not ns.db or not ns.db.tooltip or tt == _G.ForeverHealScanTip then return end
  local _, link = tt:GetItem()
  if not link then return end
  local key = link .. "#" .. tostring(ns.statVersion or 0)
  local entry = cache[key]
  if entry == nil then
    entry = Compute(link)
    if cacheN >= 300 then wipe(cache); cacheN = 0 end
    cache[key] = entry
    cacheN = cacheN + 1
    ns.tooltipStats.computed = ns.tooltipStats.computed + 1
  else
    ns.tooltipStats.cached = ns.tooltipStats.cached + 1
  end
  if not entry then return end
  tt:AddLine(" ")
  tt:AddLine(entry.header, 0.5, 1, 0.67)
  for _, l in ipairs(entry.lines) do tt:AddLine(l, 1, 1, 1, true) end
  if entry.res then tt:AddLine(entry.res, 1, 1, 1, true) end
  tt:Show()
end
ns.OnTooltipItem = OnTooltipItem

local function HookTooltips()
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
-- Annonces à chaque changement (hors combat)
----------------------------------------------------------------------
local toast
local function ShowToast(lines)
  if not toast then
    toast = CreateFrame("Frame", "ForeverHealToast", UIParent)
    toast:SetSize(600, 120)
    toast:SetPoint("TOP", 0, -150)
    toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toast.text:SetPoint("TOP")
    toast.text:SetWidth(600)
    toast.text:SetSpacing(3)
    toast:SetScript("OnUpdate", function(self, el)
      self.t = (self.t or 0) + el
      if self.t > 6 then self:SetAlpha(math.max(0, 1 - (self.t - 6) / 1.5)) end
      if self.t > 7.5 then self:Hide() end
    end)
  end
  toast.text:SetText(table.concat(lines, "\n"))
  toast.t = 0
  toast:SetAlpha(1)
  toast:Show()
end

function ns.Announce(a, b)
  if not ns.db.announce then return end
  local d = {
    sta = b.sta - a.sta, int = b.int - a.int, spi = b.spi - a.spi, heal = b.heal - a.heal, armor = b.armor - a.armor,
    crit = 0, res = {},
  }
  for s = 2, 6 do d.res[s] = (b.res[s] or 0) - (a.res[s] or 0) end
  -- écarts non expliqués par les caractéristiques (mana / 5 s, critique directe)
  local rates = ns.Rates(a)
  local spiPart = d.spi * rates.regenPerSpi
  local mp5 = ((b.regenIn - a.regenIn) - spiPart * rates.castFrac) * 5
  if math.abs(mp5) >= 1 and math.abs(b.regenIn - a.regenIn) > 0.05 then d.mp5 = math.floor(mp5 + 0.5) end
  local critDirect = ((b.crit - a.crit) * 100) - d.int / rates.intPerCrit
  if math.abs(critDirect) >= 0.5 then d.crit = critDirect end
  local any = false
  for _, k in ipairs({ "sta", "int", "spi", "heal", "armor", "mp5" }) do if (d[k] or 0) ~= 0 then any = true end end
  if d.crit ~= 0 then any = true end
  for s = 2, 6 do if d.res[s] ~= 0 then any = true end end
  if not any then return end
  local mix = ns.Mix()
  local lines = ns.ConversionLines(d, a, rates, mix)
  local res = ns.ResultLine(ns.Metrics(a, mix), ns.Metrics(b, mix))
  if res then lines[#lines + 1] = res end
  if #lines == 0 then return end
  if ns.db.announceWhere == "chat" then
    for _, l in ipairs(lines) do Print(l) end
  else
    ShowToast(lines)
  end
  ns.lastAnnounce = lines
end

----------------------------------------------------------------------
-- Panneau à côté de la fiche personnage
----------------------------------------------------------------------
local panel
local K = ns.Kit
local SECTION_ICON = {}
local function SectionIcons()
  SECTION_ICON[L.p_stats] = "Interface\\Icons\\Spell_Holy_InnerFire"
  SECTION_ICON[L.p_mix] = "Interface\\Icons\\Spell_Holy_LesserHeal"
  SECTION_ICON[L.p_results] = "Interface\\Icons\\Spell_Holy_GreaterHeal"
  SECTION_ICON[L.p_ranks] = "Interface\\Icons\\Spell_Holy_FlashHeal"
  SECTION_ICON[L.p_worth] = "Interface\\Icons\\INV_Misc_Coin_02"
  SECTION_ICON[L.upTitle] = "Interface\\Icons\\INV_Misc_Bag_10"
end

-- Panneau : titres de rubrique (icône, lettres de livre, filet doré) et lignes, recréés à chaque affichage
local pool = { head = {}, fs = {} }
local pused = { head = 0, fs = 0 }
local function PHead()
  pused.head = pused.head + 1
  local h = pool.head[pused.head]
  if not h then
    h = CreateFrame("Frame", nil, panel.child)
    h:SetHeight(26)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(20, 20)
    h.icon:SetPoint("LEFT", 2, 0)
    h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.fs:SetPoint("LEFT", h.icon, "RIGHT", 8, 0)
    K.TitleFont(h.fs, 15, "GameFontNormal")
    h.rest = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.rest:SetPoint("LEFT", h.fs, "RIGHT", 6, 0)
    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetPoint("BOTTOMLEFT"); h.rule:SetPoint("BOTTOMRIGHT"); h.rule:SetHeight(1)
    h.rule:SetColorTexture(0.65, 0.48, 0.16, 0.8)
    pool.head[pused.head] = h
  end
  h:Show()
  return h
end
local function PLine()
  pused.fs = pused.fs + 1
  local f = pool.fs[pused.fs]
  if not f then
    f = panel.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f:SetJustifyH("LEFT")
    f:SetJustifyV("TOP")
    f:SetSpacing(2)
    pool.fs[pused.fs] = f
  end
  f:ClearAllPoints()
  f:Show()
  return f
end

-- text : le texte du panneau (titres marqués \1titre\2suite)
local function RenderPanel(text)
  for _, k in ipairs({ "head", "fs" }) do for _, o in ipairs(pool[k]) do o:Hide() end; pused[k] = 0 end
  local width = panel.child:GetWidth()
  if type(width) ~= "number" or width <= 0 then width = 380 end
  local y = -2
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local title, rest = line:match("^\1(.-)\2(.*)$")
    if title then
      local h = PHead()
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 0, y - 4)
      h:SetPoint("RIGHT", panel.child, "RIGHT", 0, 0)
      h.icon:SetTexture(SECTION_ICON[title] or SECTION_ICON[L.p_stats])
      h.fs:SetText(title)
      h.rest:SetText(rest or "")
      y = y - 34
    elseif line == "" then
      y = y - 4
    else
      local f = PLine()
      f:SetWidth(width - 14)
      f:SetText(line)
      f:SetPoint("TOPLEFT", 10, y)
      local fh = f:GetStringHeight()
      y = y - ((type(fh) == "number" and fh > 0) and fh or 12) - 3
    end
  end
  panel.child:SetHeight(-y + 8)
end

local function CreatePanel()
  if panel then return panel end
  SectionIcons()
  panel = CreateFrame("Frame", "ForeverHealPanel", UIParent, "BasicFrameTemplateWithInset")
  ns.SafeClose(panel)
  ns.panel = panel
  panel:SetSize(440, 600)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("HIGH")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:Hide()
  local logo = panel:CreateTexture(nil, "OVERLAY")
  logo:SetSize(16, 16)
  logo:SetPoint("TOPLEFT", 8, -4)
  logo:SetTexture("Interface\\Icons\\Spell_Holy_GreaterHeal")
  logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  title:SetText(L.panelTitle)
  panel.diagBtn = ns.MakeDiagButton(panel)

  -- onglets : ton prêtre / tes sacs
  local function SetMode(m) panel.mode = m; ns.RefreshPanel() end
  panel.tabMain = K.Tab(panel, L.tabMain, function() SetMode(nil) end)
  panel.tabMain:SetPoint("TOPLEFT", 14, -32)
  panel.tabBags = K.Tab(panel, L.tabBags, function() SetMode("upgrades") end)
  panel.tabBags:SetPoint("LEFT", panel.tabMain, "RIGHT", 4, 0)
  panel.upBtn = panel.tabBags

  -- actions en icônes
  panel.whereBtn = K.Action(panel, "Interface\\Icons\\INV_Letter_03", "", L.tipWhere, function(self)
    ns.db.announceWhere = (ns.db.announceWhere == "screen") and "chat" or "screen"
    self.label:SetText(L["whereShort_" .. ns.db.announceWhere])
  end)
  panel.whereBtn:SetPoint("TOPRIGHT", -18, -30)
  panel.resetBtn = K.Action(panel, "Interface\\Icons\\Spell_Holy_DispelMagic", L.resetShort, L.reset, function()
    wipe(ns.db.usage); wipe(ns.db.mult); ns.db.effective = { total = 0, over = 0 }
    Print(L.resetDone); ns.RefreshPanel()
  end)
  panel.resetBtn:SetPoint("RIGHT", panel.whereBtn, "LEFT", -22, 0)
  panel.macroBtn = K.Action(panel, "Interface\\Icons\\INV_Misc_Note_01", L.macrosShort, L.btnMacros, function() ns.MakeMacros() end)
  panel.macroBtn:SetPoint("RIGHT", panel.resetBtn, "LEFT", -22, 0)

  local sheet = CreateFrame("Frame", nil, panel)
  sheet:SetPoint("TOPLEFT", 12, -76)
  sheet:SetPoint("BOTTOMRIGHT", -12, 12)
  K.Panel(sheet, 0.55)
  local sf = CreateFrame("ScrollFrame", nil, sheet, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 8, -6)
  sf:SetPoint("BOTTOMRIGHT", -28, 6)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(380, 10)
  sf:SetScrollChild(child)
  panel.child = child
  panel:SetScript("OnShow", function()
    panel.whereBtn.label:SetText(L["whereShort_" .. ns.db.announceWhere])
    ns.RefreshPanel()
  end)
  return panel
end

-- titre de rubrique, marqué pour l'affichage (\1titre\2) ; ns.PanelText() rend le texte lisible
local function H(t) return "\1" .. t .. "\2" end

-- HealBot Continued chargé ? (le conseil de rangs indique alors aussi quoi changer dans ses sorts)
local function HealBotLoaded()
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded("HealBot") end
  return IsAddOnLoaded and IsAddOnLoaded("HealBot") or false
end

local function Readable(t) return (t:gsub("\1(.-)\2", "|cffffd100%1|r")) end
ns.Readable = Readable

function ns.PanelText() return Readable(ns.PanelRaw()) end
function ns.UpgradesText() return Readable(ns.UpgradesRaw()) end

function ns.PanelRaw()
  local S = ns.Snapshot()
  local rates = ns.Rates(S)
  local mix = ns.Mix()
  local M = ns.Metrics(S, mix)
  local out = {}
  local function add(s) out[#out + 1] = s end
  add(H(L.p_stats))
  add(string.format(L.p_hp, Fmt(S.hp), Fmt(M.armorReduc * 100, 1)))
  if not IsPriest() then add(""); add(L.notPriest); return table.concat(out, "\n") end
  add(string.format(L.p_mana, Fmt(S.mana), Fmt(S.regenOut, 1), Fmt(S.regenIn, 1)))
  add(string.format(L.p_heal, Fmt(S.heal), Fmt(S.crit * 100, 1)))
  local eff = ns.db.effective
  if eff.total > 0 then add(string.format(L.p_eff, Fmt((1 - eff.over / eff.total) * 100))) end
  add("")
  add(H(L.p_mix) .. " " .. GREY .. "(" .. ((mix.observed or 0) >= 15 and string.format(L.p_mixObserved, mix.observed)
                                           or string.format(L.p_mixDefault, mix.observed or 0)) .. ")|r")
  for _, m in ipairs(mix) do
    add(string.format(L.p_mixLine, m.spell.name, Fmt(m.share * 100), Fmt(m.normal or 0), Fmt(m.avg or 0)))
  end
  add("")
  add(H(L.p_results))
  add(string.format(L.p_hps, Fmt(M.hps, 1)))
  add(string.format(L.p_perCast, Fmt(M.perCast)))
  add(string.format(L.p_oom, Duration(M.oom)) .. (M.healedBeforeOom and (" — " .. string.format(L.p_oomTotal, Fmt(M.healedBeforeOom))) or ""))
  add("")
  add(H(L.p_ranks))
  local advice = ns.RankAdvice()
  if #advice == 0 then add(GREY .. L.p_rankNone .. "|r") end
  for _, a in ipairs(advice) do
    local label = (a.model and a.model.name or a.family) .. " r" .. a.rank
    if a.better then
      add(string.format(L.p_rankAdvice, label, Fmt(a.overPct * 100), Fmt(a.useful), a.better.rank, Fmt(a.betterNormal), a.saving))
      if HealBotLoaded() then
        local sub = (C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(a.better.id))
                    or (GetSpellSubtext and GetSpellSubtext(a.better.id)) or ("r" .. a.better.rank)
        add("   " .. string.format(L.p_rankHealBot, a.model.name, a.better.name .. "(" .. sub .. ")"))
      end
    elseif a.overPct >= 0.15 then
      add(string.format(L.p_rankKeep, label, Fmt(a.overPct * 100), Fmt(a.useful)))
    else
      add(string.format(L.p_rankOk, label, Fmt(a.overPct * 100)))
    end
  end
  add("")
  add(H(L.p_worth))
  local gains = {
    { "+10 " .. L.sta, { sta = 10 } }, { "+10 " .. L.int, { int = 10 } }, { "+10 " .. L.spi, { spi = 10 } },
    { "+10 " .. L.heal, { heal = 10 } }, { "+5 " .. L.mp5, { mp5 = 5 } }, { "+1 " .. L.crit, { crit = 1 } },
  }
  local best, bestVal
  for _, g in ipairs(gains) do
    local A = ns.Metrics(ns.Apply(S, g[2], rates), mix)
    local healed = (A.healedBeforeOom or 0) - (M.healedBeforeOom or 0)
    if g[2].sta then
      add(string.format(L.p_worthSurvival, g[1], Signed(g[2].sta * rates.hpPerSta)))
    else
      add(string.format(L.p_worthLine, g[1], Signed(A.hps - M.hps, 1), DurationDelta(M.oom, A.oom), Signed(healed)))
    end
    local val = (M.oom and M.oom ~= math.huge) and healed or (A.hps - M.hps)
    if g[2].sta == nil and (not bestVal or val > bestVal) then best, bestVal = g[1], val end
  end
  if best then add(string.format(L.p_best, GREEN .. best .. "|r")) end
  add("")
  local lr = ns.db.rates
  add(GREY .. string.format(L.p_rates, Fmt(rates.hpPerSta, 1), Fmt(rates.manaPerInt, 1), Fmt(rates.intPerCrit, 1))
      .. ((not lr.hpPerSta and not lr.manaPerInt) and L.p_ratesDefault or "") .. "|r")
  return table.concat(out, "\n")
end

function ns.UpgradesRaw()
  local out = { H(L.upTitle) }
  local list = ns.BagUpgrades()
  if #list == 0 then out[#out + 1] = L.upNone end
  for _, u in ipairs(list) do
    local cur = GetInventoryItemLink("player", u.slot)
    out[#out + 1] = string.format(L.upLine, u.link, cur or L.upEmpty, Signed(u.hps, 1), Signed(u.healed))
  end
  return table.concat(out, "\n")
end

-- Un calcul qui échoue s'affiche dans le panneau (et dans le diagnostic) au lieu de le laisser figé (05/11/2026)
function ns.RefreshPanel()
  if not panel or not panel:IsShown() then return end
  panel.tabMain:SetActive(panel.mode ~= "upgrades")
  panel.tabBags:SetActive(panel.mode == "upgrades")
  local ok, text = pcall(panel.mode == "upgrades" and ns.UpgradesRaw or ns.PanelRaw)
  if not ok then
    ns.lastPanelError = tostring(text)
    text = "|cffff6a5a" .. string.format(L.panelError, tostring(text)) .. "|r"
  end
  RenderPanel(text)
end

function ns.MakeMacros()
  local n, why = ns.CreateRankMacros()
  if why == "combat" then return Print(L.macrosCombat) end
  if why == "full" then Print(L.macrosFull) end
  Print(n > 0 and string.format(L.macrosDone, n) or L.macrosNone)
end

local alert
function ns.UpdateManaAlert()
  if not ns.db.manaAlert or select(2, UnitClass("player")) ~= "PRIEST" then if alert then alert:Hide() end return end
  local left = InCombatLockdown() and ns.ManaTimeLeft()
  local pct = UnitPower("player", 0) / math.max(UnitPowerMax("player", 0), 1)
  if not left or left > ns.db.manaAlertSeconds or pct > 0.6 then
    if alert then alert:Hide() end
    return
  end
  if not alert then
    alert = CreateFrame("Frame", "ForeverHealManaAlert", UIParent)
    alert:SetSize(400, 40)
    alert:SetPoint("CENTER", 0, -120)
    alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    alert.text:SetPoint("CENTER")
  end
  alert.text:SetText(string.format(L.manaAlert, math.floor(left + 0.5)))
  if left <= 8 then alert.text:SetTextColor(1, 0.25, 0.25) else alert.text:SetTextColor(1, 0.65, 0.1) end
  alert:Show()
  ns.alertShown = true
end

local function AttachToCharacterFrame()
  if not CharacterFrame then return end
  CharacterFrame:HookScript("OnShow", function()
    if not ns.db.panel then return end
    CreatePanel()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -30, -12)
    panel:Show()
  end)
  CharacterFrame:HookScript("OnHide", function() if panel and panel.attached ~= false then panel:Hide() end end)
end

function ns.TogglePanel()
  CreatePanel()
  if panel:IsShown() then panel:Hide() else panel:ClearAllPoints(); panel:SetPoint("CENTER"); panel:Show() end
end

----------------------------------------------------------------------
-- Démarrage, commandes
----------------------------------------------------------------------
ns.OnLoaded = function() end
ns.OnLogin = function()
  HookTooltips()
  AttachToCharacterFrame()
  local LS = _G.LibStub
  local LDB = LS and LS("LibDataBroker-1.1", true)
  if LDB then
    LDB:NewDataObject("ForeverHeal", { type = "launcher", icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",
      OnClick = function() ns.TogglePanel() end,
      OnTooltipShow = function(tt) tt:AddLine("ForeverHeal", 1, 0.82, 0) end })
  end
end

SLASH_FOREVERHEAL1 = "/fheal"
SLASH_FOREVERHEAL2 = "/foreverheal"
SlashCmdList.FOREVERHEAL = function(msg)
  msg = ((msg or ""):match("^%s*(.-)%s*$")):lower()
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" then ns.TogglePanel()
  elseif cmd == "infobulle" or cmd == "tooltip" then
    ns.db.tooltip = not ns.db.tooltip; Print(L.optTooltip .. " : " .. (ns.db.tooltip and L.on or L.off))
  elseif cmd == "annonce" or cmd == "announce" then
    ns.db.announce = not ns.db.announce; Print(L.optAnnounce .. " : " .. (ns.db.announce and L.on or L.off))
  elseif cmd == "ecran" or cmd == "écran" or cmd == "screen" then ns.db.announceWhere = "screen"; Print(string.format(L.optWhere, L.where_screen))
  elseif cmd == "diag" then ns.ShowDiag()
  elseif cmd == "alerte" or cmd == "alert" then
    ns.db.manaAlert = not ns.db.manaAlert; Print(L.optManaAlert .. " : " .. (ns.db.manaAlert and L.on or L.off))
  elseif cmd == "macros" then ns.MakeMacros()
  elseif cmd == "sacs" or cmd == "bags" then
    CreatePanel(); panel.mode = "upgrades"
    if not panel:IsShown() then panel:ClearAllPoints(); panel:SetPoint("CENTER"); panel:Show() else ns.RefreshPanel() end
  elseif cmd == "chat" then ns.db.announceWhere = "chat"; Print(string.format(L.optWhere, L.where_chat))
  elseif cmd == "panneau" or cmd == "panel" then
    ns.db.panel = not ns.db.panel; Print(L.optPanel .. " : " .. (ns.db.panel and L.on or L.off))
  elseif cmd == "oublier" or cmd == "forget" then
    wipe(ns.db.usage); wipe(ns.db.mult); ns.db.effective = { total = 0, over = 0 }; Print(L.resetDone)
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then ns.lang, ns.db.lang = arg, arg; ns.RefreshPanel()
  else Print(L.helpText) end
end

function ForeverHeal_OnCompartmentClick() ns.TogglePanel() end
