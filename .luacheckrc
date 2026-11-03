-- Configuration luacheck pour les addons WoW (Lua 5.1)
std = "lua51"
max_line_length = false
unused_args = false
self = false

-- Variables globales écrites par les addons
globals = {
  "ForeverGFXDB", "ForeverMacrosDB", "ForeverGazetteDB", "ForeverPrepDB", "ForeverHealDB",
  "SLASH_FOREVERGFX1", "SLASH_FOREVERGFX2", "SLASH_FOREVERMACROS1", "SLASH_FOREVERMACROS2",
  "ForeverGFX_OnCompartmentClick", "ForeverMacros_OnCompartmentClick",
  "SLASH_FOREVERGAZETTE1", "SLASH_FOREVERGAZETTE2", "ForeverGazette_OnCompartmentClick",
  "SLASH_FOREVERPREP1", "SLASH_FOREVERPREP2", "ForeverPrep_OnCompartmentClick",
  "SLASH_FOREVERHEAL1", "SLASH_FOREVERHEAL2", "ForeverHeal_OnCompartmentClick",
  "ForeverHub", "SLASH_FOREVERHUB1", "ForeverHealAPI", "ForeverLootDB", "ForeverLootGlobalDB", "ForeverDungeonJournal_NS", "Syndicator",
  "SLASH_FOREVERLOOT1", "SLASH_FOREVERLOOT2", "ForeverLoot_OnCompartmentClick",
  "SlashCmdList", "StaticPopupDialogs", "UISpecialFrames",
}

-- API WoW lue (présente sur Forever, TBC Anniversary et retail, ou testée avant usage)
read_globals = {
  "C_AddOns", "C_CVar", "C_Console", "C_Item", "C_Spell", "C_Timer", "ChatFontNormal",
  "ClearCursor", "ConsoleExec", "ConsoleGetAllCommands", "CopyTable", "CreateFrame",
  "CreateMacro", "DeleteMacro", "EditMacro", "Enum", "GameTooltip", "GetBuildInfo", "GetCVar",
  "GetCVarInfo", "GetCursorInfo", "GetCursorPosition", "GetFramerate", "GetItemInfo",
  "GetItemInfoInstant", "GetLocale", "GetMacroIndexByName", "GetMacroInfo", "GetNumMacros",
  "GetRealZoneText", "GetSpellInfo", "HideUIPanel", "InCombatLockdown", "IsAddOnLoaded",
  "IsInInstance", "IsResting", "IsShiftKeyDown", "LOCALIZED_CLASS_NAMES_MALE",
  "MAX_ACCOUNT_MACROS", "MAX_CHARACTER_MACROS", "MacroFrame", "Minimap", "NO", "PickupMacro",
  "RestartGx", "SetCVar", "Settings", "SettingsPanel", "StaticPopup_Show", "UIParent",
  "UnitClass", "YES", "date", "time", "tinsert", "wipe",
  -- ForeverGazette
  "bit", "C_QuestLog", "C_Reputation", "ChatEdit_InsertLink", "CombatLogGetCurrentEventInfo",
  "DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT", "ERR_LEARN_RECIPE_S", "GetAchievementInfo",
  "GetFactionInfo", "GetMaxPlayerLevel", "GetMoney", "GetNumFactions", "GetNumGroupMembers",
  "GetNumPartyMembers", "GetNumRaidMembers", "GetRealmName", "GetTime", "GetTitleText", "IsInGuild",
  "IsInRaid", "LOOT_ITEM_SELF", "Screenshot", "SendChatMessage", "SKILL_RANK_UP", "UNKNOWNOBJECT",
  "UnitExists", "UnitGUID", "UnitIsPlayer", "UnitLevel", "UnitName", "UnitSex", "UnitXP", "UnitXPMax",
  "UnitClassification", "GetRealZoneText", "ReloadUI", "GetItemIcon", "CANCEL", "InCombatLockdown",
  -- ForeverPrep
  "C_Container", "C_Spell", "C_UnitAuras", "BuyMerchantItem", "GetContainerNumFreeSlots", "GetContainerNumSlots",
  "GetInventoryItemDurability", "GetInventoryItemLink", "GetItemCooldown", "GetItemCount", "GetItemInfoInstant",
  "GetMerchantItemID", "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantItemMaxStack", "GetMerchantNumItems",
  "GetNumTalentTabs", "GetPetHappiness", "GetSpellTexture", "GetTalentTabInfo", "GetUnspentTalentPoints",
  "GetWeaponEnchantInfo", "IsPlayerSpell", "IsSpellKnown", "MerchantFrame", "UnitBuff", "UnitCharacterPoints",
  "UnitIsConnected", "UnitIsDeadOrGhost", "UnitIsUnit", "UnitIsVisible",
  -- ForeverHeal
  "CharacterFrame", "GetItemStats", "GetManaRegen", "GetSpellBonusHealing", "GetSpellCritChance", "GetSpellDescription",
  "GetSpellPowerCost", "ItemRefTooltip", "TooltipDataProcessor", "UnitArmor", "UnitHealthMax", "UnitPowerMax",
  "UnitResistance", "UnitStat", "WorldFrame",
  -- diagnostic
  "GetAddOnMetadata", "UnitRace", "UnitFactionGroup", "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemName",
  "GetSpellBookItemInfo", "GetContainerItemLink", "GetNumMacros", "GetFramerate", "DEFAULT_CHAT_FRAME", "UnitPower", "GetSpellSubtext", "GetMacroIndexByName", "CreateMacro", "EditMacro",
  "GetLootSlotLink", "GetNumLootItems", "GetLootRollItemLink", "GetNumQuestChoices", "GetQuestItemLink", "UnitIsDead",
}
