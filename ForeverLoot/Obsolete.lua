-- Ancien addon, fusionné dans ForeverPretre (v3.0.0). Ce fichier remplace son code : il se désactive pour la
-- prochaine connexion et prévient une fois. Les anciens fichiers éventuellement restés dans le dossier ne sont plus chargés.
local ADDON = ...
local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
if disable then pcall(disable, ADDON) end
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  local FR = GetLocale() == "frFR"
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Forever|r " .. string.format(FR
    and "%s fait maintenant partie de ForeverPrêtre (/fp) : l'ancien dossier est désactivé, tu peux le supprimer."
    or "%s is now part of ForeverPriest (/fp): the old folder is disabled, you can delete it.", ADDON))
end)
