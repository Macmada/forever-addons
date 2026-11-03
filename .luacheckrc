-- Configuration luacheck pour les addons WoW (Lua 5.1)
std = "lua51"
max_line_length = false
unused_args = false
self = false

-- Variables globales écrites par les addons
globals = {
  "ForeverGFXDB", "ForeverMacrosDB", "ForeverGazetteDB",
  "SLASH_FOREVERGFX1", "SLASH_FOREVERGFX2", "SLASH_FOREVERMACROS1", "SLASH_FOREVERMACROS2",
  "ForeverGFX_OnCompartmentClick", "ForeverMacros_OnCompartmentClick",
  "SLASH_FOREVERGAZETTE1", "SLASH_FOREVERGAZETTE2", "ForeverGazette_OnCompartmentClick",
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
}
