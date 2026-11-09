local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverHeal") end
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

-- Soigneur pris en charge (prêtre, druide, paladin, chaman : sorts dans Data.lua)
local function IsPriest() return ns.Data.classes[select(2, UnitClass("player"))] ~= nil end

----------------------------------------------------------------------
-- Lignes « +45 Endurance » +450 PV » pour un écart de caractéristiques
----------------------------------------------------------------------
function ns.ConversionLines(d, S, rates, mix)
  local lines, keys = {}, {}
  lines.keys = keys                       -- caractéristique de chaque ligne (icônes du cadre « Flash »)
  local priest = IsPriest()
  local main = mix and mix[1] and mix[1].spell
  if (d.sta or 0) ~= 0 then lines[#lines + 1] = string.format(L.conv_sta, Signed(d.sta), Signed(d.sta * rates.hpPerSta)); keys[#lines] = "sta" end
  if (d.int or 0) ~= 0 and priest then
    lines[#lines + 1] = string.format(L.conv_int, Signed(d.int), Signed(d.int * rates.manaPerInt), Signed(d.int / rates.intPerCrit, 2))
    keys[#lines] = "int"
  end
  if (d.spi or 0) ~= 0 and priest then
    local out = d.spi * rates.regenPerSpi
    local inC = out * rates.castFrac
    lines[#lines + 1] = string.format(L.conv_spi, Signed(d.spi), Signed(out, 2),
      math.abs(inC) >= 0.005 and string.format(L.conv_spiIn, Signed(inC, 2)) or "")
    keys[#lines] = "spi"
  end
  if (d.heal or 0) ~= 0 and priest and main then
    lines[#lines + 1] = string.format(L.conv_heal, Signed(d.heal), Signed(d.heal * main.coef * main.mult * main.targets), main.name)
    keys[#lines] = "heal"
  end
  if (d.mp5 or 0) ~= 0 and priest then lines[#lines + 1] = string.format(L.conv_mp5, Signed(d.mp5), Signed(d.mp5 / 5, 2)); keys[#lines] = "mp5" end
  if (d.crit or 0) ~= 0 and priest then lines[#lines + 1] = string.format(L.conv_crit, Signed(d.crit, 1)); keys[#lines] = "crit" end
  if (d.hp or 0) ~= 0 then lines[#lines + 1] = string.format(L.conv_hp, Signed(d.hp)); keys[#lines] = "hp" end
  if (d.mana or 0) ~= 0 then lines[#lines + 1] = string.format(L.conv_mana, Signed(d.mana)); keys[#lines] = "mana" end
  if (d.armor or 0) ~= 0 then
    local lvl = S.level or 60
    local before = S.armor / (S.armor + 400 + 85 * lvl)
    local after = (S.armor + d.armor) / (S.armor + d.armor + 400 + 85 * lvl)
    lines[#lines + 1] = string.format(L.conv_armor, Signed(d.armor), Signed(-(after - before) * 100, 1, true))
    keys[#lines] = "armor"
  end
  for s = 2, 6 do
    local v = d.res and d.res[s] or 0
    if v ~= 0 then lines[#lines + 1] = string.format(L.conv_res, Signed(v), L["res" .. s]); keys[#lines] = "res" end
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
  local flash = ns.root and ns.root.Flash
  if ns.db.announceWhere ~= "chat" and flash and #lines > 0 then
    -- cadre « Flash » de ForeverCompagnon : à côté du personnage, une ligne par caractéristique, résultat sur tes soins
    local rows = {}
    for i, l in ipairs(lines) do rows[#rows + 1] = { lines.keys[i] or "result", l } end
    flash.Show({ item = flash.lastItem, rows = rows, result = res })
    ns.lastAnnounce = lines
    if res then lines[#lines + 1] = res end
    return
  end
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

-- Panneau visuel : tuiles, barres des sorts, barres des gains, ligne de caractéristiques (09/11/2026 : moins de texte)
local vis = { rows = {}, tiles = {} }
local function VRow()
  vis.used = vis.used + 1
  local r = vis.rows[vis.used]
  if not r then
    r = CreateFrame("Frame", nil, panel.child)
    r:SetHeight(24)
    r:EnableMouse(true)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("LEFT", 28, 0)
    r.name:SetWidth(128)
    r.name:SetJustifyH("LEFT")
    if r.name.SetWordWrap then r.name:SetWordWrap(false) end
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetPoint("LEFT", 160, 0)
    r.bg:SetSize(130, 10)
    r.bg:SetColorTexture(1, 1, 1, 0.08)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("LEFT", r.bg, "LEFT", 0, 0)
    r.bar:SetHeight(10)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.right:SetPoint("RIGHT", -6, 0)
    r.right:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tip[1], 1, 0.82, 0)
      for i = 2, #self.tip do GameTooltip:AddLine(self.tip[i], 1, 1, 1, true) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    vis.rows[vis.used] = r
  end
  r:Show()
  return r
end

local function RenderVisual(d)
  for _, k in ipairs({ "head", "fs" }) do for _, o in ipairs(pool[k]) do o:Hide() end; pused[k] = 0 end
  for _, r in ipairs(vis.rows) do r:Hide() end
  for _, t in ipairs(vis.tiles) do t:Hide() end
  vis.used = 0
  local width = panel.child:GetWidth()
  if type(width) ~= "number" or width <= 0 then width = 380 end
  local y = -4
  if not d.priest then
    local f = PLine(); f:SetWidth(width - 14); f:SetText(L.notPriest); f:SetPoint("TOPLEFT", 10, y)
    panel.child:SetHeight(60)
    return
  end
  -- tuiles
  local gap, n = 6, #d.tiles
  local tw = (width - 8 - gap * (n - 1)) / n
  for i, td in ipairs(d.tiles) do
    local t = vis.tiles[i]
    if not t then
      t = CreateFrame("Frame", nil, panel.child)
      t:SetHeight(52)
      t:EnableMouse(true)
      t.bg = t:CreateTexture(nil, "BACKGROUND")
      t.bg:SetAllPoints()
      t.bg:SetColorTexture(0.12, 0.1, 0.08, 0.9)
      t.top = t:CreateTexture(nil, "ARTWORK")
      t.top:SetPoint("TOPLEFT", 1, -1); t.top:SetPoint("TOPRIGHT", -1, -1); t.top:SetHeight(3)
      t.value = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
      t.value:SetPoint("TOP", 0, -9)
      t.value:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 17, "OUTLINE")
      t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      t.label:SetPoint("BOTTOM", 0, 6)
      t.label:SetTextColor(0.85, 0.78, 0.6)
      t:SetScript("OnEnter", function(self)
        if not self.tipText then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.tipText, 1, 1, 1, 1, true)
        GameTooltip:Show()
      end)
      t:SetScript("OnLeave", function() GameTooltip:Hide() end)
      vis.tiles[i] = t
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", 4 + (i - 1) * (tw + gap), y)
    t:SetWidth(tw)
    t.value:SetText(td.value)
    t.label:SetText(td.label)
    t.tipText = td.tip
    if td.warn then t.top:SetColorTexture(1, 0.66, 0.24, 1) else t.top:SetColorTexture(0.25, 0.85, 0.38, 1) end
    t:Show()
  end
  y = y - 62
  local function Head(title, icon, rest)
    local h = PHead()
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, y - 2)
    h:SetPoint("RIGHT", panel.child, "RIGHT", 0, 0)
    h.icon:SetTexture(icon)
    h.fs:SetText(title)
    h.rest:SetText(rest or "")
    y = y - 32
  end
  local function Row(icon, name, frac, color, right, tip)
    local r = VRow()
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, y)
    r:SetPoint("RIGHT", panel.child, "RIGHT", 0, 0)
    r.icon:SetShown(icon ~= nil)
    if icon then r.icon:SetTexture(icon) end
    r.name:SetText(name)
    local room = math.max(60, width - 160 - 108)            -- 108 : place du chiffre de droite (« +433 soignés »)
    r.bg:SetWidth(room)
    local bw = math.max(1, room * math.max(0, math.min(1, frac or 0)))
    r.bar:SetWidth(bw)
    r.bar:SetColorTexture(color[1], color[2], color[3], 0.9)
    r.right:SetText(right or "")
    r.tip = tip
    y = y - 26
  end
  -- tes sorts
  Head(L.v_spells, "Interface\\Icons\\Spell_Holy_LesserHeal",
       GREY .. ((d.observed or 0) >= 15 and string.format(L.v_spellsObserved, d.observed) or L.v_spellsDefault) .. "|r")
  for _, sp in ipairs(d.spells) do
    local icon = sp.id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sp.id) or nil
    Row(icon, sp.name, sp.share, { 1, 0.78, 0.3 }, Fmt(sp.share * 100) .. " %  ·  " .. Fmt(sp.avg),
        { sp.name, string.format(L.v_spellTip, Fmt(sp.share * 100), Fmt(sp.normal), Fmt(sp.avg)) })
  end
  -- ce qui t'aide le plus
  Head(L.v_worth, "Interface\\Icons\\INV_Misc_Coin_02")
  local top = math.max(1, d.gains[1] and d.gains[1].healed or 1)
  for i, g in ipairs(d.gains) do
    local best = i == 1 and g.healed > 0
    Row(nil, (best and GREEN or "") .. g.label .. (best and "|r" or ""), g.healed / top, best and { 0.25, 0.85, 0.38 } or { 0.45, 0.6, 0.45 },
        (best and GREEN or "") .. string.format(L.v_healed, Signed(g.healed)) .. (best and "|r" or ""),
        { g.label, string.format(L.v_gainTip, Signed(g.hps, 1), g.oom, Signed(g.healed)), best and L.v_bestTip or nil })
  end
  Row(nil, GREY .. d.survival.label .. "|r", 0, { 0.5, 0.5, 0.5 }, GREY .. string.format(L.v_survival, Signed(d.survival.hp)) .. "|r",
      { d.survival.label, L.v_survivalTip })
  -- caractéristiques, en une ligne (conversions au survol)
  y = y - 6
  local r = VRow()
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", 0, y)
  r:SetPoint("RIGHT", panel.child, "RIGHT", 0, 0)
  r.icon:Hide(); r.bar:SetWidth(1); r.bar:SetColorTexture(0, 0, 0, 0); r.bg:SetWidth(1); r.bg:SetColorTexture(0, 0, 0, 0)
  r.name:SetWidth(width - 20)
  r.name:SetText(GREY .. d.footer .. "|r")
  r.right:SetText("")
  r.tip = { L.v_footerTitle, d.footerTip }
  y = y - 26
  panel.child:SetHeight(-y + 8)
  -- remet le fond des barres pour la prochaine fois (la ligne de caractéristiques l'a effacé)
  r.restore = true
end
ns._RenderVisual = RenderVisual

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
  -- (onglets « Mon soigneur » / « Mes sacs » retirés le 09/11/2026 : « Mes sacs » ne servait pas ; les améliorations des
  -- sacs sont dans l'onglet Équipement et dans « À faire »)

  -- actions en icônes
  panel.whereBtn = K.Action(panel, "Interface\\Icons\\INV_Letter_03", "", L.tipWhere, function(self)
    ns.db.announceWhere = (ns.db.announceWhere == "screen") and "chat" or "screen"
    self.label:SetText(L["whereShort_" .. ns.db.announceWhere])
  end)
  panel.whereBtn:SetPoint("TOPRIGHT", -18, -30)
  -- (bouton « Oublier » retiré le 09/11/2026 : la répartition des sorts se refait toute seule ; /fheal oublier reste)
  -- (bouton « Macros » retiré le 09/11/2026 : les conseils de rangs demandent les montants soignés du journal de combat,
  -- interdit aux addons sur Forever ; il n'a jamais rien créé)

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

-- Données du panneau visuel : tuiles, sorts (part d'usage, soin moyen), gains triés, ligne de caractéristiques
function ns.PanelData()
  local S = ns.Snapshot()
  local rates = ns.Rates(S)
  local mix = ns.Mix()
  local M = ns.Metrics(S, mix)
  local d = { priest = IsPriest(), S = S, M = M, rates = rates }
  if not d.priest then return d end
  d.tiles = {
    { value = Fmt(M.hps, 0), label = L.v_hps, tip = string.format(L.p_hps, Fmt(M.hps, 1)) },
    { value = (M.oom and M.oom ~= math.huge) and Duration(M.oom) or "OK", label = L.v_oom,
      tip = M.healedBeforeOom and string.format(L.p_oomTotal, Fmt(M.healedBeforeOom)) or L.noOomTip,
      warn = M.oom and M.oom < 60 },
    { value = Fmt(M.perCast), label = L.v_perCast, tip = string.format(L.p_perCast, Fmt(M.perCast)) },
    { value = Fmt(S.mana), label = string.format(L.v_mana, Fmt(S.regenOut, 1)),
      tip = string.format(L.p_mana, Fmt(S.mana), Fmt(S.regenOut, 1), Fmt(S.regenIn, 1)) },
  }
  d.spells = {}
  for _, m in ipairs(mix) do
    d.spells[#d.spells + 1] = { name = m.spell.name, share = m.share or 0, avg = m.avg or 0, normal = m.normal or 0,
                                id = m.spell.id }
  end
  d.observed = mix.observed or 0
  local gains = {
    { "+10 " .. L.int, { int = 10 } }, { "+10 " .. L.spi, { spi = 10 } }, { "+10 " .. L.heal, { heal = 10 } },
    { "+5 " .. L.mp5, { mp5 = 5 } }, { "+1 " .. L.crit, { crit = 1 } },
  }
  d.gains = {}
  for _, g in ipairs(gains) do
    local A = ns.Metrics(ns.Apply(S, g[2], rates), mix)
    d.gains[#d.gains + 1] = { label = g[1], healed = (A.healedBeforeOom or 0) - (M.healedBeforeOom or 0), hps = A.hps - M.hps,
                              oom = DurationDelta(M.oom, A.oom) }
  end
  table.sort(d.gains, function(a, b) if a.healed ~= b.healed then return a.healed > b.healed end return a.hps > b.hps end)
  d.survival = { label = "+10 " .. L.sta, hp = 10 * rates.hpPerSta }
  d.footer = string.format(L.v_footer, Fmt(S.hp), Fmt(M.armorReduc * 100, 1), Fmt(S.heal), Fmt(S.crit * 100, 1))
  d.footerTip = string.format(L.p_rates, Fmt(rates.hpPerSta, 1), Fmt(rates.manaPerInt, 1), Fmt(rates.intPerCrit, 1))
  return d
end

function ns.UpgradesRaw()
  local out = { H(L.upTitle), "|cffa0a0a0" .. L.upIntro .. "|r" }
  local list = ns.BagUpgrades()
  if #list == 0 then out[#out + 1] = L.upNone end
  for _, u in ipairs(list) do
    local cur = GetInventoryItemLink("player", u.slot)
    local regen = (u.cmp.after.regenOut or 0) - (u.cmp.before.regenOut or 0)
    local extra = {}
    if math.abs(regen) >= 0.01 then extra[#extra + 1] = string.format(L.upRegen, Signed(regen, 2)) end
    if (u.d.sta or 0) ~= 0 then extra[#extra + 1] = string.format(L.upSta, Signed(u.d.sta)) end
    if (u.d.armor or 0) ~= 0 then extra[#extra + 1] = string.format(L.upArmor, Signed(u.d.armor)) end
    out[#out + 1] = string.format(L.upLine, u.link, cur or L.upEmpty, Signed(u.hps, 1), Signed(u.healed))
                    .. (#extra > 0 and (", " .. table.concat(extra, ", ")) or "")
  end
  return table.concat(out, "\n")
end

-- Un calcul qui échoue s'affiche dans le panneau (et dans le diagnostic) au lieu de le laisser figé (05/11/2026)
function ns.RefreshPanel()
  if not panel or not panel:IsShown() then return end
  for _, r in ipairs(vis.rows) do
    r:Hide()
    if r.restore then r.restore = nil; r.bg:SetColorTexture(1, 1, 1, 0.08); r.name:SetWidth(128) end
  end
  for _, t in ipairs(vis.tiles) do t:Hide() end
  if panel.mode ~= "upgrades" then
    local ok, d = pcall(ns.PanelData)
    if ok and d then
      local ok2, err = pcall(RenderVisual, d)
      if ok2 then return end
      d = err
    end
    ns.lastPanelError = tostring(d)
    RenderPanel("|cffff6a5a" .. string.format(L.panelError, tostring(d)) .. "|r")
    return
  end
  local ok, text = pcall(ns.UpgradesRaw)
  if not ok then
    ns.lastPanelError = tostring(text)
    text = "|cffff6a5a" .. string.format(L.panelError, tostring(text)) .. "|r"
  end
  RenderPanel(text)
end


local alert
-- Alerte bien visible (06/11/2026 : noyée dans le texte de combat) : cadre sombre à bordure orange qui pulse, icône de
-- potion, texte gros et contouré, barre de mana remplie par le jeu (valeur secrète passée telle quelle), sous le centre
-- de l'écran pour ne pas se mêler aux chiffres de combat. Glisser pour la déplacer (position retenue).
local function Alert()
  if not alert then
    alert = CreateFrame("Frame", "ForeverHealManaAlert", UIParent)
    alert:SetSize(440, 64)
    local p = ns.db.alertPos
    if p then alert:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2]) else alert:SetPoint("CENTER", 0, -190) end
    alert:SetFrameStrata("HIGH")
    alert:SetMovable(true)
    alert:EnableMouse(true)
    alert:RegisterForDrag("LeftButton")
    alert:SetScript("OnDragStart", alert.StartMoving)
    alert:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local x, y = self:GetCenter()
      if type(x) == "number" then ns.db.alertPos = { x, y } end
    end)
    alert.bg = alert:CreateTexture(nil, "BACKGROUND")
    alert.bg:SetAllPoints()
    alert.bg:SetColorTexture(0.08, 0.02, 0.0, 0.85)
    alert.border = K and K.Border(alert, 1, 0.45, 0.1, 1, "BORDER") or {}
    -- lueur qui pulse autour du cadre
    alert.glow = alert:CreateTexture(nil, "BACKGROUND", nil, -1)
    alert.glow:SetPoint("TOPLEFT", -10, 10)
    alert.glow:SetPoint("BOTTOMRIGHT", 10, -10)
    alert.glow:SetColorTexture(1, 0.35, 0.05, 0.35)
    alert.glow:SetBlendMode("ADD")
    local g = alert.glow.CreateAnimationGroup and alert.glow:CreateAnimationGroup()
    local a = g and g:CreateAnimation("Alpha")
    if a then
      g:SetLooping("BOUNCE")
      a:SetFromAlpha(0.15); a:SetToAlpha(1); a:SetDuration(0.6)
      alert.pulse = g
    end
    alert.icon = alert:CreateTexture(nil, "ARTWORK")
    alert.icon:SetSize(44, 44)
    alert.icon:SetPoint("LEFT", 10, 0)
    alert.icon:SetTexture("Interface\\Icons\\INV_Potion_76")
    alert.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    alert.text:SetPoint("TOPLEFT", alert.icon, "TOPRIGHT", 10, 0)
    alert.text:SetPoint("RIGHT", -10, 0)
    alert.text:SetJustifyH("LEFT")
    local fo = _G.GameFontNormalHuge
    local font = fo and fo.GetFont and select(1, fo:GetFont())
    if font then pcall(alert.text.SetFont, alert.text, font, 20, "OUTLINE") end
    if alert.text.SetWordWrap then alert.text:SetWordWrap(false) end           -- une seule ligne, au-dessus de la barre
    alert.bar = CreateFrame("StatusBar", nil, alert)
    alert.bar:SetPoint("BOTTOMLEFT", alert.icon, "BOTTOMRIGHT", 10, 0)
    alert.bar:SetPoint("RIGHT", -10, 0)
    alert.bar:SetHeight(10)
    alert.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    alert.bar:SetStatusBarColor(0.2, 0.45, 1)
    alert.bar.bg = alert.bar:CreateTexture(nil, "BACKGROUND")
    alert.bar.bg:SetAllPoints()
    alert.bar.bg:SetColorTexture(0, 0, 0, 0.6)
  end
  return alert
end

-- Barre de mana : valeurs passées telles quelles au jeu (secrètes sur Forever, l'addon ne les lit pas)
local function FillBar(a)
  if type(rawget(a, "bar")) ~= "table" then return end
  local max = UnitPowerMax("player", 0)
  if not (pcall(a.bar.SetMinMaxValues, a.bar, 0, max) and pcall(a.bar.SetValue, a.bar, UnitPower("player", 0))) then a.bar:Hide()
  else a.bar:Show() end
end

-- Mana secrète (WoW Forever) : pas de compte à rebours possible ; c'est le jeu qui décide si la mana est sous le seuil
-- (courbe donnée à UnitPowerPercent, voir Compat.lua) et l'alerte « Mana basse : 23 % (190 / 821) » apparaît en combat.
local function SecretManaAlert()
  local G = ns.Game
  if not (G and InCombatLockdown()) then if alert then alert:Hide() end return end
  local color = G.ManaBelowColor(ns.db.manaLowPct or 0.3)
  if not color then if alert then alert:Hide() end return end
  local a = Alert()
  local text = G.ManaText(L.manaLowFmt) or L.manaLow
  a.text:SetText(text)
  a.text:SetTextColor(1, 0.6, 0.15)
  FillBar(a)
  a:Show()
  if type(rawget(a, "pulse")) == "table" and not a.pulse:IsPlaying() then a.pulse:Play() end
  ns.alertShown = G.ApplyAlpha(a, color, 0)
end

function ns.UpdateManaAlert()
  if not ns.db.manaAlert or not ns.Data.classes[select(2, UnitClass("player"))] then if alert then alert:Hide() end return end
  local cur, max = ns.Plain(UnitPower("player", 0)), ns.Plain(UnitPowerMax("player", 0))
  if not (cur and max) then return SecretManaAlert() end
  local left = InCombatLockdown() and ns.ManaTimeLeft()
  local pct = cur / math.max(max, 1)
  if not left or left > ns.db.manaAlertSeconds or pct > 0.6 then
    if alert then alert:Hide() end
    return
  end
  Alert()
  alert:SetAlpha(1)
  alert.text:SetText(string.format(L.manaAlert, math.floor(left + 0.5)))
  if left <= 8 then alert.text:SetTextColor(1, 0.25, 0.25) else alert.text:SetTextColor(1, 0.65, 0.1) end
  FillBar(alert)
  alert:Show()
  if type(rawget(alert, "pulse")) == "table" and not alert.pulse:IsPlaying() then alert.pulse:Play() end
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
  elseif (cmd == "alerte" or cmd == "alert") and arg == "test" then
    -- aperçu de 8 s, hors combat, pour la voir et la placer (glisser)
    local a = Alert()
    a.text:SetText(string.format(L.manaLowFmt, 23, 190, 821))
    a.text:SetTextColor(1, 0.6, 0.15)
    a:SetAlpha(1)
    FillBar(a)
    a:Show()
    if type(rawget(a, "pulse")) == "table" then a.pulse:Play() end
    C_Timer.After(8, function() if not InCombatLockdown() then a:Hide() end end)
  elseif cmd == "alerte" or cmd == "alert" then
    local pct = tonumber(arg)
    if pct and pct > 0 and pct < 100 then ns.db.manaLowPct = pct / 100; ns.db.manaAlert = true
    else ns.db.manaAlert = not ns.db.manaAlert end
    Print(L.optManaAlert .. " : " .. (ns.db.manaAlert and L.on or L.off))
    if ns.db.manaAlert and not ns.ManaReadable() then Print(L.manaSecretClient, math.floor((ns.db.manaLowPct or 0.3) * 100 + 0.5)) end
  elseif cmd == "chat" then ns.db.announceWhere = "chat"; Print(string.format(L.optWhere, L.where_chat))
  elseif cmd == "panneau" or cmd == "panel" then
    ns.db.panel = not ns.db.panel; Print(L.optPanel .. " : " .. (ns.db.panel and L.on or L.off))
  elseif cmd == "oublier" or cmd == "forget" then
    wipe(ns.db.usage); wipe(ns.db.mult); ns.db.effective = { total = 0, over = 0 }; Print(L.resetDone)
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then ns.lang, ns.db.lang = arg, arg; ns.RefreshPanel()
  else Print(L.helpText) end
end

function ForeverHeal_OnCompartmentClick() ns.TogglePanel() end
