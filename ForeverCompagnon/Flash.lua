local _, root = ...
local L = root.L
local K = root.Kit

-- « Flash » : quand tes caractéristiques changent (nouvel objet équipé, hors combat), un cadre doré apparaît à côté de
-- ton personnage (ou contre ta fiche personnage si elle est ouverte) : l'objet équipé, une ligne par caractéristique
-- (icône, valeur en vert ou en rouge, ce que ça change), et pour un soigneur le résultat sur tes soins. Effets : éclat
-- d'étoile, lignes qui glissent l'une après l'autre, chiffres qui montent au-dessus de ta tête comme du texte de combat.
-- Pour toutes les classes : un soigneur passe par la partie Soins (lignes « +35 Endurance » +350 PV »), les autres par
-- le relevé générique ci-dessous. Glisser pour le déplacer (position retenue), clic droit pour le fermer,
-- /fp flash place pour revenir à la place automatique.

local F = {}
root.Flash = F

local ICON = {
  str = "Interface\\Icons\\Spell_Nature_Strength", agi = "Interface\\Icons\\Ability_Rogue_QuickRecovery",
  sta = "Interface\\Icons\\Spell_Holy_WordFortitude", int = "Interface\\Icons\\Spell_Holy_MagicalSentry",
  spi = "Interface\\Icons\\Spell_Holy_DivineSpirit", armor = "Interface\\Icons\\INV_Chest_Chain_05",
  hp = "Interface\\Icons\\Spell_Holy_Heal", mana = "Interface\\Icons\\INV_Potion_76", heal = "Interface\\Icons\\Spell_Holy_GreaterHeal",
  sp = "Interface\\Icons\\Spell_Fire_FlameBolt", ap = "Interface\\Icons\\Ability_Warrior_BattleShout",
  crit = "Interface\\Icons\\Ability_CriticalStrike", mp5 = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
  res = "Interface\\Icons\\Spell_Holy_PrayerOfFireProtection", dodge = "Interface\\Icons\\Ability_Rogue_Feint",
  result = "Interface\\Icons\\Spell_Holy_FlashHeal",
}
F.ICON = ICON

local frame, floaters = nil, {}
local ROW_H = 30

local function Pos()
  local cf = _G.CharacterFrame
  frame:ClearAllPoints()
  local hp = _G.ForeverHealPanel
  if root.db and root.db.flashPos then                                  -- position choisie (glissée) : toujours là
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", root.db.flashPos[1], root.db.flashPos[2])
  elseif cf and cf:IsShown() then
    frame:SetPoint("TOPLEFT", (hp and hp:IsShown()) and hp or cf, "TOPRIGHT", 8, -20)
  else
    frame:SetPoint("LEFT", UIParent, "CENTER", 90, 60)            -- à droite du personnage
  end
end

local function Anim(region, kind, a, b, dur, delay)
  local g = region:CreateAnimationGroup()
  local an = g:CreateAnimation(kind)
  an:SetDuration(dur)
  if delay then an:SetStartDelay(delay) end
  if kind == "Alpha" then an:SetFromAlpha(a); an:SetToAlpha(b)
  elseif kind == "Translation" then an:SetOffset(a, b)
  elseif kind == "Scale" then
    if an.SetScaleFrom then an:SetScaleFrom(a, a); an:SetScaleTo(b, b) else an:SetScale(b, b) end
  end
  if an.SetSmoothing then an:SetSmoothing("OUT") end
  return g, an
end

local function Row(i)
  frame.rows = frame.rows or {}
  local r = frame.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, frame)
  r:SetSize(300, ROW_H)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(24, 24)
  r.icon:SetPoint("LEFT", 12, 0)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.value = r:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  r.value:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 2)
  r.value:SetJustifyH("LEFT")
  r.detail = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.detail:SetPoint("TOPLEFT", r.value, "BOTTOMLEFT", 0, -1)
  r.detail:SetJustifyH("LEFT")
  r.detail:SetTextColor(0.85, 0.8, 0.65)
  r.inA = Anim(r, "Alpha", 0, 1, 0.3)
  r.inT = Anim(r, "Translation", -24, 0, 0.3)
  frame.rows[i] = r
  return r
end

local function Create()
  if frame then return frame end
  frame = CreateFrame("Button", "ForeverCompagnonFlash", UIParent)
  frame:SetSize(340, 120)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving(); self.dragging = true end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.dragging = false
    local x, y = self:GetCenter()
    if root.db and type(x) == "number" then root.db.flashPos = { x, y } end      -- position retenue (même fiche ouverte)
  end)
  frame:RegisterForClicks("RightButtonUp")
  frame:SetScript("OnClick", function(self) self:Hide() end)                       -- clic droit : fermer
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.flashTitle)
    GameTooltip:AddLine(L.flashTip, 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- fond : sombre, filet doré, lueur en haut
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints()
  frame.bg:SetColorTexture(0.05, 0.04, 0.02, 0.82)
  K.Border(frame, 0.85, 0.65, 0.2, 1, "BORDER")
  frame.shine = frame:CreateTexture(nil, "ARTWORK")
  frame.shine:SetPoint("TOPLEFT", 1, -1)
  frame.shine:SetPoint("TOPRIGHT", -1, -1)
  frame.shine:SetHeight(36)
  frame.shine:SetColorTexture(1, 0.8, 0.3, 0.12)
  -- éclat d'étoile derrière l'icône de l'objet
  frame.star = frame:CreateTexture(nil, "OVERLAY")
  frame.star:SetSize(90, 90)
  frame.star:SetTexture("Interface\\Cooldown\\star4")
  frame.star:SetBlendMode("ADD")
  frame.starA = Anim(frame.star, "Alpha", 1, 0, 0.9)
  frame.starS = Anim(frame.star, "Scale", 0.3, 1.8, 0.9)
  -- en-tête : objet équipé
  frame.item = CreateFrame("Frame", nil, frame)
  frame.item:SetSize(36, 36)
  frame.item:SetPoint("TOPLEFT", 10, -10)
  frame.itemIcon = frame.item:CreateTexture(nil, "ARTWORK")
  frame.itemIcon:SetAllPoints()
  frame.itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  frame.itemBorder = K.Border(frame.item, 1, 1, 1, 1, "OVERLAY")
  frame.star:SetPoint("CENTER", frame.item, "CENTER")
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOPLEFT", frame.item, "TOPRIGHT", 10, -2)
  frame.title:SetText(L.flashTitle)
  K.TitleFont(frame.title, 15, "GameFontNormal")
  frame.itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.itemName:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
  frame.itemName:SetWidth(250)
  frame.itemName:SetJustifyH("LEFT")
  frame.inA = Anim(frame, "Alpha", 0, 1, 0.25)
  frame.inT = Anim(frame, "Translation", -30, 0, 0.35)
  frame:SetScript("OnUpdate", function(self, el)
    if self:IsMouseOver() or self.dragging then return end   -- survol ou déplacement : reste affiché
    self.t = (self.t or 0) + el
    if self.t > 7 then self:SetAlpha(math.max(0, 1 - (self.t - 7) / 1.2)) end
    if self.t > 8.2 then self:Hide() end
  end)
  frame:Hide()
  return frame
end

-- Chiffre qui monte au-dessus du personnage (comme le texte de combat)
local function Float(text, r, g, b, delay)
  local f
  for _, x in ipairs(floaters) do if not x:IsShown() then f = x; break end end
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(300, 30)
    f:SetFrameStrata("HIGH")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.text:SetPoint("CENTER")
    f.up = Anim(f, "Translation", 0, 110, 2.2)
    f.fade = Anim(f, "Alpha", 1, 0, 0.9, 1.3)
    f.up:SetScript("OnFinished", function() f:Hide() end)
    floaters[#floaters + 1] = f
  end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 70 - (delay or 0) * 60)
  f.text:SetText(text)
  f.text:SetTextColor(r, g, b)
  f:SetAlpha(1)
  f:Show()
  if C_Timer and delay and delay > 0 then
    f:Hide()
    C_Timer.After(delay, function() f:Show(); f.up:Play(); f.fade:Play() end)
  else
    f.up:Play(); f.fade:Play()
  end
end

-- data = { item = lien ou nil, rows = { { key, text } }, result = texte ou nil }
-- text « +35 Endurance » +350 PV » : la partie avant » en grand, le reste en petit dessous
function F.Show(data)
  if not data or not data.rows or #data.rows == 0 then return end
  if root.db and root.db.flash == false then return end
  local f = Create()
  -- objet équipé
  local link = data.item
  local name, q, icon
  if link then
    local r = { root.Game.ItemInfo(link) }
    name, q, icon = r[1], r[3], r[10]
    if not icon then icon = select(5, root.Game.ItemInstant(link)) end
  end
  f.itemIcon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Bag_10")
  local qc = K.QUALITY[q or 1] or K.QUALITY[1]
  for _, t in ipairs(f.itemBorder) do t:SetColorTexture(qc[1], qc[2], qc[3], 1) end
  f.itemName:SetText(link or name or L.flashNoItem)
  local rows = {}
  for _, r in ipairs(data.rows) do rows[#rows + 1] = r end
  if data.result then rows[#rows + 1] = { "result", data.result } end
  local y = -54
  for i, r in ipairs(rows) do
    local row = Row(i)
    local key, text = r[1], r[2]
    local big, small = text:match("^(.-)%s*»%s*(.+)$")
    big, small = big or text, small or ""
    -- une seule couleur par ligne : couleurs déjà incluses par la partie Soins retirées (« -6 » rouge, « Endurance » vert)
    big = big:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local neg = big:find("^%s*%-") or big:find("^%s*\226\136\146")         -- « - » ou « − »
    row.icon:SetTexture(ICON[key] or ICON.result)
    -- résultat (long) : plus petit, sur deux lignes si besoin ; jamais plus large que le cadre
    row.value:SetFontObject(key == "result" and "GameFontHighlight" or "GameFontNormalLarge")
    row.value:SetWidth(f:GetWidth() - 60)
    if row.value.SetWordWrap then row.value:SetWordWrap(key == "result") end
    row.value:SetText(big)
    if key == "result" then row.value:SetTextColor(0.4, 0.85, 1)
    elseif neg then row.value:SetTextColor(1, 0.35, 0.3) else row.value:SetTextColor(0.35, 1, 0.4) end
    row.detail:SetWidth(f:GetWidth() - 60)
    row.detail:SetText(small)
    local vh = row.value:GetStringHeight()
    vh = (type(vh) == "number" and vh > 0) and vh or 16
    local rh = math.max(ROW_H, vh + (small ~= "" and 16 or 6))
    row:SetHeight(rh)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, y)
    row:SetAlpha(0)
    row:Show()
    y = y - rh - 2
    C_Timer.After(0.15 + i * 0.12, function() row:SetAlpha(1); row.inA:Play(); row.inT:Play() end)
    -- chiffre qui monte au-dessus du personnage (seulement la valeur, pas le résultat)
    if key ~= "result" and i <= 4 then
      Float(big, neg and 1 or 0.35, neg and 0.35 or 1, neg and 0.3 or 0.4, (i - 1) * 0.25)
    end
  end
  for i = #rows + 1, #(f.rows or {}) do f.rows[i]:Hide() end
  f:SetHeight(-y + 10)
  Pos()
  f.t = 0
  f:SetAlpha(1)
  f:Show()
  f.inA:Play(); f.inT:Play()
  f.starA:Play(); f.starS:Play()
  if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST) or 31578) end
  F.last = { item = link, rows = rows }
end

----------------------------------------------------------------------
-- Relevé générique (toutes les classes ; un soigneur passe par la partie Soins, plus précise)
----------------------------------------------------------------------
local function Plain(v) return root.Game.Plain(v) or 0 end
function F.Snapshot()
  local S = {}
  for i, k in ipairs({ "str", "agi", "sta", "int", "spi" }) do S[k] = Plain(select(2, UnitStat("player", i))) end
  S.armor = Plain(select(2, UnitArmor("player")))
  S.hp = Plain(UnitHealthMax("player"))
  S.mana = Plain(UnitPowerMax("player", 0))
  if UnitAttackPower then local b, p, n = UnitAttackPower("player"); S.ap = Plain(b) + Plain(p) - Plain(n) end
  if GetSpellBonusDamage then
    local best = 0
    for school = 2, 7 do best = math.max(best, Plain(GetSpellBonusDamage(school))) end
    S.sp = best
  end
  S.heal = Plain(GetSpellBonusHealing and GetSpellBonusHealing())
  S.crit = Plain(GetCritChance and GetCritChance())
  return S
end

local ORDER = { "str", "agi", "sta", "int", "spi", "ap", "sp", "heal", "crit", "armor", "hp", "mana" }
function F.DiffRows(a, b)
  local rows = {}
  for _, k in ipairs(ORDER) do
    local d = (b[k] or 0) - (a[k] or 0)
    if k == "crit" then d = math.floor(d * 100 + 0.5) / 100 else d = math.floor(d + 0.5) end
    if d ~= 0 and not (k == "mana" and (b.mana or 0) == 0) then
      local sign = d > 0 and "+" or ""
      local val = k == "crit" and (sign .. string.format("%.2f", d) .. " %") or (sign .. d)
      local detail = ""
      if k == "sta" then detail = string.format(L.flash_staHp, sign .. (d * 10))
      elseif k == "int" and (b.mana or 0) > 0 then detail = string.format(L.flash_intMana, sign .. (d * 15))
      elseif k == "armor" then
        local lvl = UnitLevel("player")
        local function red(ar) return ar / (ar + 400 + 85 * lvl) end
        detail = string.format(L.flash_armorRed, string.format("%+.1f", (red(b.armor) - red(a.armor)) * 100))
      end
      rows[#rows + 1] = { k, val .. " " .. L["flash_" .. k] .. (detail ~= "" and (" » " .. detail) or "") }
    end
  end
  return rows
end

local last, pendingItem
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, slot)
  local heal = root.mods.ForeverHeal
  if heal and not heal.inactive then                        -- soigneur : la partie Soins s'en charge (F.Show)
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot then F.lastItem = GetInventoryItemLink("player", slot) end
    return
  end
  if event == "PLAYER_LEVEL_UP" then C_Timer.After(1.5, function() last = F.Snapshot() end); return end
  if InCombatLockdown() then return end
  if event == "PLAYER_EQUIPMENT_CHANGED" then
    pendingItem = slot and GetInventoryItemLink("player", slot) or pendingItem
    C_Timer.After(0.6, function()
      if InCombatLockdown() then return end
      local now = F.Snapshot()
      if last then
        local rows = F.DiffRows(last, now)
        if #rows > 0 then F.Show({ item = pendingItem, rows = rows }) end
      end
      last, pendingItem = now, nil
    end)
  elseif event == "PLAYER_REGEN_ENABLED" then last = F.Snapshot()
  end
end)
root.OnLogin(function() C_Timer.After(2, function() last = F.Snapshot() end) end)
