local _, root = ...
local L = root.L
local G = root.Game

-- Sonde du client : quelles fonctions de WoW existent vraiment sur ce client (WoW Forever est un client moderne
-- habillé en classique). Le rapport (/fp sonde) se colle tel quel : c'est du Lua, il devient le profil du client
-- dans les tests hors jeu (tests/forever_client.lua). Relevé à chaque connexion, gardé dans ForeverCompagnonDB.probe.

-- Fonctions utilisées par les addons (ou leurs remplaçantes connues)
root.PROBE_APIS = {
  -- objets et sacs
  "GetItemInfo", "C_Item.GetItemInfo", "GetItemInfoInstant", "C_Item.GetItemInfoInstant", "GetItemStats", "C_Item.GetItemStats",
  "EquipItemByName", "C_Item.EquipItemByName", "AutoEquipCursorItem", "PickupContainerItem", "C_Container.PickupContainerItem",
  "UseContainerItem", "C_Container.UseContainerItem", "GetContainerNumSlots", "C_Container.GetContainerNumSlots",
  "GetContainerItemID", "C_Container.GetContainerItemID", "GetContainerItemLink", "C_Container.GetContainerItemLink",
  "GetItemCooldown", "C_Container.GetItemCooldown", "C_Item.GetItemCooldown", "GetItemCount", "C_Item.GetItemCount",
  -- marchand
  "GetMerchantItemInfo", "C_MerchantFrame.GetItemInfo", "GetMerchantNumItems", "C_MerchantFrame.GetNumItems",
  "BuyMerchantItem", "GetMerchantItemLink", "GetMerchantItemID",
  -- sorts et grimoire
  "GetSpellInfo", "C_Spell.GetSpellInfo", "C_Spell.GetSpellName", "GetSpellDescription", "C_Spell.GetSpellDescription",
  "GetSpellPowerCost", "C_Spell.GetSpellPowerCost", "GetNumSpellTabs", "C_SpellBook.GetNumSpellBookSkillLines",
  "GetSpellBonusHealing", "GetSpellCritChance", "GetManaRegen", "IsSpellKnown", "C_SpellBook.IsSpellKnown",
  -- métiers
  "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetProfessionInfo", "GetTradeSkillLine", "GetNumTradeSkills",
  "GetCraftInfo", "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetRecipeSchematic",
  "C_TradeSkillUI.GetChildProfessionInfo", "C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.OpenRecipe",
  -- combat, valeurs secrètes
  "CombatLogGetCurrentEventInfo", "C_CombatLog.GetCurrentEventInfo", "issecretvalue", "UnitPower", "UnitPowerMax",
  "UnitPowerPercent", "C_CurveUtil.CreateColorCurve", "CreateColor",
  -- vie des alliés (affichage de la vie manquante sur les barres de soins)
  "UnitHealth", "UnitHealthMax", "UnitHealthMissing", "UnitHealthPercent", "UnitGetIncomingHeals", "UnitGetTotalAbsorbs",
  "CreateUnitHealPredictionCalculator", "AbbreviateNumbers", "AbbreviateLargeNumbers", "C_StringUtil.TruncateWhenZero",
  "C_CurveUtil.CreateCurve",
  -- réputation, carte, communauté
  "GetFactionInfoByID", "C_Reputation.GetFactionDataByID", "C_Map.GetBestMapForUnit", "C_Map.SetUserWaypoint",
  "C_SuperTrack.SetSuperTrackedUserWaypoint", "C_Minimap.SetTracking", "SetTracking", "C_Club.GetClubMembers",
  -- divers
  "C_AddOns.GetAddOnMetadata", "GetAddOnMetadata", "C_AddOns.IsAddOnLoaded", "IsAddOnLoaded", "C_AddOns.DisableAddOn",
  "GetInventoryItemLink", "GetInventoryItemTexture", "GetInventorySlotInfo", "C_Timer.After", "hooksecurefunc",
}

local function Collect()
  local p = { present = {}, absent = {} }
  local version, build, _, iface = GetBuildInfo()
  p.client = string.format("%s (%s), interface %s", tostring(version), tostring(build), tostring(iface))
  p.date = date("%Y-%m-%d %H:%M")
  for _, path in ipairs(root.PROBE_APIS) do
    if G.Has(path) then p.present[#p.present + 1] = path else p.absent[#p.absent + 1] = path end
  end
  local old = root.db and root.db.probe
  if old then p.secretPowerInCombat = old.secretPowerInCombat end
  if not (InCombatLockdown and InCombatLockdown()) then
    local v = UnitPower and UnitPower("player", 0)
    p.secretPowerOutOfCombat = v ~= nil and G.Plain(v) == nil
  end
  return p
end

-- Vie d'un allié (groupe, sinon cible, sinon toi) : chaque valeur est-elle secrète, et le jeu accepte-t-il de l'afficher ?
-- Rien n'est calculé ni comparé sur une valeur secrète : seulement issecretvalue, et des essais d'affichage sous pcall.
local function Short(err) return (tostring(err or ""):gsub("^.-:%d+: ", ""):sub(1, 70)) end
function root.HealthProbe()
  local unit = (UnitExists and UnitExists("party1") and "party1") or (UnitExists and UnitExists("target") and "target") or "player"
  local secret = _G.issecretvalue or function() return false end
  local r = { unit = unit, combat = InCombatLockdown and InCombatLockdown() or false,
              instance = (IsInInstance and select(2, IsInInstance())) or "?" }
  local function State(name, ...)
    local f = G.Get(name)
    if type(f) ~= "function" then return "absente" end
    local ok, v = pcall(f, ...)
    if not ok then return "erreur : " .. Short(v) end
    if v == nil then return "nil" end
    return secret(v) and "secrète" or "lisible"
  end
  r.health = State("UnitHealth", unit)
  r.healthMax = State("UnitHealthMax", unit)
  r.missing = State("UnitHealthMissing", unit)
  r.percent = State("UnitHealthPercent", unit, true, _G.CurveConstants and _G.CurveConstants.ScaleTo100)
  -- essais d'affichage de la vie manquante (sinon de la vie) dans un texte invisible
  local get = G.Get("UnitHealthMissing") or G.Get("UnitHealth")
  r.shown = get == G.Get("UnitHealthMissing") and "UnitHealthMissing" or "UnitHealth"
  local fs = (root.probeFS or UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
  root.probeFS = fs
  fs:Hide()
  local function Try(fn)
    if type(get) ~= "function" then return "absente" end
    local ok, err = pcall(fn, get(unit))
    return ok and "OK" or ("refusé : " .. Short(err))
  end
  r.setText = Try(function(v) fs:SetText(v) end)
  r.setFormatted = Try(function(v) fs:SetFormattedText("-%d", v) end)
  r.format = Try(function(v) fs:SetText(string.format("-%d", v)) end)
  r.concat = Try(function(v) fs:SetText("-" .. v) end)
  r.abbrev = Try(function(v) fs:SetText(AbbreviateNumbers(v)) end)
  return r
end

-- En combat : la mana est-elle secrète ? (relevé une fois par combat, sans calcul dessus)
local function CheckSecret()
  if not (root.db and root.db.probe) then return end
  local v = UnitPower and UnitPower("player", 0)
  root.db.probe.secretPowerInCombat = G.Plain(v) == nil and v ~= nil
end

function root.ProbeText()
  local p = (root.db and root.db.probe) or Collect()
  local out = { "-- ForeverCompagnon, sonde du client " .. p.client .. ", " .. p.date,
                "-- " .. L.testHelp, "return {", "  client = \"" .. p.client .. "\"," }
  out[#out + 1] = "  secretPowerInCombat = " .. tostring(p.secretPowerInCombat) .. ","
  out[#out + 1] = "  secretPowerOutOfCombat = " .. tostring(p.secretPowerOutOfCombat) .. ","
  local okH, h = pcall(root.HealthProbe)
  if okH and h then
    out[#out + 1] = string.format("  health = { unit = %q, combat = %s, instance = %q,", h.unit, tostring(h.combat), tostring(h.instance))
    for _, k in ipairs({ "health", "healthMax", "missing", "percent", "shown", "setText", "setFormatted", "format", "concat", "abbrev" }) do
      out[#out + 1] = string.format("    %s = %q,", k, tostring(h[k]))
    end
    out[#out + 1] = "  },"
  else
    out[#out + 1] = "  health = " .. string.format("%q", "erreur : " .. tostring(h)) .. ","
  end
  out[#out + 1] = "  absent = {"
  for _, a in ipairs(p.absent) do out[#out + 1] = "    \"" .. a .. "\"," end
  out[#out + 1] = "  },"
  out[#out + 1] = "  present = {"
  for _, a in ipairs(p.present) do out[#out + 1] = "    \"" .. a .. "\"," end
  out[#out + 1] = "  },"
  out[#out + 1] = "}"
  return table.concat(out, "\n")
end

function root.ShowProbe()
  if root.db then root.db.probe = Collect() end
  root.ShowText(L.probeTitle, root.ProbeText())
end

root.OnLogin(function() if root.db then root.db.probe = Collect() end end)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function() C_Timer.After(1, CheckSecret) end)

-- Fenêtre de texte à copier (sonde, auto-test)
local tf
function root.ShowText(title, text)
  if not tf then
    tf = CreateFrame("Frame", "ForeverCompagnonTextFrame", UIParent, "BasicFrameTemplateWithInset")
    root.SafeClose(tf)
    tf:SetSize(640, 460)
    tf:SetPoint("CENTER")
    tf:SetFrameStrata("FULLSCREEN_DIALOG")
    tf:SetMovable(true)
    tf:EnableMouse(true)
    tf:RegisterForDrag("LeftButton")
    tf:SetScript("OnDragStart", tf.StartMoving)
    tf:SetScript("OnDragStop", tf.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverCompagnonTextFrame")
    tf.title = root.Kit.Dress(tf, "Interface\\Icons\\INV_Misc_Spyglass_02", "")
    local sf = CreateFrame("ScrollFrame", nil, tf, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -32)
    sf:SetPoint("BOTTOMRIGHT", -32, 14)
    tf.edit = CreateFrame("EditBox", nil, sf)
    tf.edit:SetMultiLine(true)
    tf.edit:SetFontObject(ChatFontNormal)
    tf.edit:SetWidth(580)
    tf.edit:SetAutoFocus(false)
    tf.edit:SetScript("OnEscapePressed", function() tf:Hide() end)
    sf:SetScrollChild(tf.edit)
  end
  tf.title:SetText(title)
  tf.edit:SetText(text)
  tf:Show()
  tf.edit:SetFocus()
  tf.edit:HighlightText()
end
