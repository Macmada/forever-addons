local _, root = ...
local L = root.L
local K = root.Kit

-- « Maintenant » : le plus utile à ton niveau, pris dans chaque partie. Chaque section est protégée : une erreur
-- devient une ligne lisible (et un point du diagnostic) au lieu de vider l'écran. En combat, rien n'est recalculé :
-- l'écran garde le dernier état connu (les valeurs du jeu sont secrètes en combat sur Forever).

local W, H = 600, 560
local ui, last
root.nowErrors = {}

local function Gray(s) return "|cffa0a0a0" .. s .. "|r" end
local function Num(v, dec) local m = 10 ^ (dec or 0); return tostring(math.floor((v or 0) * m + 0.5) / m) end
local function Dur(s)
  if not s or s == math.huge then return nil end
  s = math.floor(s + 0.5)
  if s >= 60 then return string.format("%d min %02d s", math.floor(s / 60), s % 60) end
  return s .. " s"
end
local function Head(lines, icon, title, key)
  lines[#lines + 1] = { kind = "head", icon = icon, title = title, text = title,
                        right = key and ("|cffd8c8a0" .. L.more .. " »|r") or nil,
                        onClick = key and function() root.Open(key) end or nil }
end

-- Chaque section : fonction(lines) ; renvoie rien
local SECTIONS = {}

SECTIONS[#SECTIONS + 1] = function(lines)
  local ns = root.mods.ForeverHeal
  if not (ns and ns.Snapshot and ns.Metrics) then return end
  Head(lines, "Interface\\Icons\\Spell_Holy_GreaterHeal", L.secPriest)
  local S = ns.Snapshot()
  local M = ns.Metrics(S, ns.Mix and ns.Mix() or nil)
  local oom = Dur(M.oom)
  lines[#lines + 1] = { kind = "card", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", quality = 1,
                        name = string.format(L.hps, Num(M.hps, 1)),
                        source = (oom and string.format(L.oom, oom) or L.noOom) .. " · " .. string.format(L.regen, Num(S.regenOut, 1)),
                        gain = S.mana and (Num(S.mana) .. " mana") or nil,
                        onClick = function() root.Open("heal") end }
end

SECTIONS[#SECTIONS + 1] = function(lines)
  local ns = root.mods.ForeverLoot
  if not (ns and ns.NearLines) then return end
  Head(lines, "Interface\\Icons\\INV_Chest_Cloth_17", L.secGear, "loot")
  local n = 0
  for _, l in ipairs(ns.NearLines(5)) do
    if l.kind == "card" and n < 4 then
      n = n + 1
      local c = {}
      for k, v in pairs(l) do c[k] = v end
      c.onClick = function() root.Open("loot"); if ns.ShowTab then ns.ShowTab("near") end end
      lines[#lines + 1] = c
    end
  end
  if n == 0 then lines[#lines + 1] = { kind = "info", text = Gray(string.format(L.noGear, math.min(60, UnitLevel("player") + 5))) } end
end

SECTIONS[#SECTIONS + 1] = function(lines)
  local ns = root.mods.ForeverPrep
  if not (ns and ns.Analyze) then return end
  Head(lines, "Interface\\Icons\\INV_Potion_51", L.secBuy, "prep")
  local res = ns.Analyze()
  local n = 0
  for _, s in ipairs(res.sections or {}) do
    for _, r in ipairs(s.rows or {}) do
      if (r.status == "warn" or r.status == "bad") and n < 5 then
        n = n + 1
        lines[#lines + 1] = { kind = "card", icon = r.icon or "Interface\\Icons\\INV_Misc_QuestionMark", quality = 1,
                              name = r.text, nameColor = r.status == "bad" and { 1, 0.42, 0.35 } or { 1, 0.78, 0.38 },
                              onClick = function() root.Open("prep") end }
      end
    end
  end
  if n == 0 then lines[#lines + 1] = { kind = "info", text = Gray(L.allGood) } end
  if #(res.shopping or {}) > 0 and ns.GuideToVendor then
    lines[#lines + 1] = { kind = "card", icon = "Interface\\Icons\\INV_Misc_Map_01", quality = 1, name = L.guide,
                          nameColor = { 0.4, 0.85, 1 }, source = string.format(L.guideSub, #res.shopping),
                          onClick = function() ns.GuideToVendor() end }
  end
end

SECTIONS[#SECTIONS + 1] = function(lines)
  local ns = root.mods.ForeverMetiers
  if not (ns and ns.LevelLines) then return end
  Head(lines, "Interface\\Icons\\Trade_Tailoring", L.secProf, "metiers")
  local n = 0
  for _, l in ipairs(ns.LevelLines()) do
    if l.kind ~= "head" and n < 6 and not (n == 0 and l.kind == "info") then   -- sans l'introduction de l'onglet
      n = n + 1
      lines[#lines + 1] = l
    end
  end
  if n == 0 then lines[#lines + 1] = { kind = "info", text = Gray(L.noProf) } end
end

function root.NowLines()
  if InCombatLockdown and InCombatLockdown() and last then return last, true end
  local lines = { { kind = "info", text = "|cffd8c8a0" .. string.format(L.nowIntro, UnitLevel("player")) .. "|r" } }
  wipe(root.nowErrors)
  for i, sec in ipairs(SECTIONS) do
    local ok, err = pcall(sec, lines)
    if not ok then
      root.nowErrors[#root.nowErrors + 1] = "section " .. i .. " : " .. tostring(err)
      lines[#lines + 1] = { kind = "info", text = "|cffff6a5a" .. string.format(L.err, tostring(err)) .. "|r" }
    end
  end
  last = lines
  return lines, false
end

function root.RefreshNow()
  if not (ui and ui:IsShown()) then return end
  local lines, stale = root.NowLines()
  ui.status:SetText(stale and ("|cffffc860" .. L.combat .. "|r") or "")
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
  ui.status = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.status:SetPoint("TOPLEFT", 18, -62)
  ui.list = K.CardList(ui, W - 60)
  ui.list.scroll:SetPoint("TOPLEFT", 16, -80)
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
