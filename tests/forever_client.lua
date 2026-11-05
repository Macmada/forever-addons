-- Profil du client de WoW Forever pour les tests hors jeu : fonctions absentes de ce client.
-- Établi à la main d'après les erreurs vues en jeu (05/11/2026) ; à remplacer par le rapport de « /fp sonde »
-- (même format : il suffit de coller le rapport dans ce fichier).
return {
  client = "WoW Forever (relevé manuel, avant la sonde)",
  secretPowerInCombat = true,
  absent = {
    "EquipItemByName",
    "GetMerchantItemInfo",
    "GetTradeSkillLine",
    "GetNumTradeSkills",
    "GetCraftInfo",
    "CombatLogGetCurrentEventInfo",
    "GetSpellInfo",
    "GetItemCooldown",
    "GetNumSkillLines",
    "GetFactionInfoByID",
  },
  present = {},
}
