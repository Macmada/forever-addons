local _, root = ...
local L = root.L
local G = root.Game

-- Sonde du client : quelles fonctions de WoW existent vraiment sur ce client (WoW Forever est un client moderne
-- habillé en classique). Le rapport (/fp sonde) se colle tel quel : c'est du Lua, il devient le profil du client
-- dans les tests hors jeu (tests/forever_client.lua). Relevé à chaque connexion, gardé dans ForeverPretreDB.probe.

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

-- En combat : la mana est-elle secrète ? (relevé une fois par combat, sans calcul dessus)
local function CheckSecret()
  if not (root.db and root.db.probe) then return end
  local v = UnitPower and UnitPower("player", 0)
  root.db.probe.secretPowerInCombat = G.Plain(v) == nil and v ~= nil
end

function root.ProbeText()
  local p = (root.db and root.db.probe) or Collect()
  local out = { "-- ForeverPretre, sonde du client " .. p.client .. ", " .. p.date,
                "-- " .. L.testHelp, "return {", "  client = \"" .. p.client .. "\"," }
  out[#out + 1] = "  secretPowerInCombat = " .. tostring(p.secretPowerInCombat) .. ","
  out[#out + 1] = "  secretPowerOutOfCombat = " .. tostring(p.secretPowerOutOfCombat) .. ","
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
    tf = CreateFrame("Frame", "ForeverPretreTextFrame", UIParent, "BasicFrameTemplateWithInset")
    root.SafeClose(tf)
    tf:SetSize(640, 460)
    tf:SetPoint("CENTER")
    tf:SetFrameStrata("FULLSCREEN_DIALOG")
    tf:SetMovable(true)
    tf:EnableMouse(true)
    tf:RegisterForDrag("LeftButton")
    tf:SetScript("OnDragStart", tf.StartMoving)
    tf:SetScript("OnDragStop", tf.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverPretreTextFrame")
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
