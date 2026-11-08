-- ForeverCompagnon chargé pour chaque classe, Alliance et Horde, sur le profil du client de WoW Forever : rien ne plante,
-- les onglets suivent la classe (Soins : prêtre), chaque écran se construit, l'auto-test ne trouve aucune erreur Lua.
-- Lancer depuis la racine : lua5.1 tests/classes_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local rprint = print
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local RACES = { Alliance = { "Human", "Humain" }, Horde = { "Orc", "Orc" } }
local profile = dofile("tests/forever_client.lua")
local n = 0

for _, faction in ipairs({ "Alliance", "Horde" }) do
  for _, class in ipairs(CLASSES) do
    local W = dofile("tests/wowmock.lua")(LANG)
    local check = function(c, msg) if not c then error("ÉCHEC (" .. class .. ", " .. faction .. ") : " .. msg, 2) end end
    W.class, W.level = class, 24
    _G.UnitFactionGroup = function() return faction end
    _G.UnitRace = function() return RACES[faction][2], RACES[faction][1] end
    _G.UnitGUID = function() return "Player-1" end
    _G.UnitPower = function() return 100 end
    _G.UnitPowerMax = function() return 400 end
    _G.UnitHealthMax = function() return 300 end
    _G.UnitStat = function(_, i) return 20, 20 + i end
    _G.UnitArmor = function() return 300, 300 end
    _G.UnitResistance = function() return 0, 0 end
    _G.GetManaRegen = function() return 4, 1 end
    _G.GetSpellBonusHealing = function() return 0 end
    _G.GetSpellCritChance = function() return 2 end
    _G.UnitExists = function(u) return u == "player" end
    _G.IsInGroup, _G.IsInRaid, _G.GetNumGroupMembers = function() return false end, function() return false end, function() return 0 end
    _G.C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
    _G.GetInventoryItemDurability = function() return nil end
    _G.C_Container = { GetContainerNumSlots = function(b) return b == 0 and 2 or 0 end,
                       GetContainerItemID = function(_, s) return ({ 6948, 2589 })[s] end,
                       GetContainerItemLink = function(_, s) return "|Hitem:" .. ({ 6948, 2589 })[s] .. "|h" end,
                       GetItemCooldown = function() return 0, 0, 1 end }
    _G.C_Item = { GetItemInfo = function(x) local id = tonumber(tostring(x):match("(%d+)")); if id then return "Objet " .. id, "|Hitem:" .. id .. "|h", 1, 5, 1, "Armor", "Cloth", 1, "", "icone", 10 end end,
                  GetItemInfoInstant = function(x) local id = tonumber(tostring(x):match("(%d+)")); return id, "Armor", "Cloth", "", "icone", 4, 1 end,
                  GetItemCount = function() return 1 end, EquipItemByName = function() end }
    _G.C_Spell = { GetSpellName = function(id) return "Sort " .. id end, GetSpellInfo = function(id) return { name = "Sort " .. id, castTime = 2500 } end,
                   GetSpellDescription = function() return "Soigne la cible de 100 à 120 points de vie." end,
                   GetSpellPowerCost = function() return { { cost = 50, type = 0 } } end }
    _G.IsSpellKnown = function() return true end
    _G.IsPlayerSpell = function() return true end
    _G.GetProfessions = function() return nil end
    _G.GetInventoryItemLink = function() return nil end
    _G.GetInventoryItemTexture = function() return nil end
    _G.GetInventorySlotInfo = function() return 1, "icone" end
    W.client(profile)

    local root = W.load("ForeverCompagnon")
    W.fire("ADDON_LOADED", "ForeverCompagnon")
    W.fire("PLAYER_LOGIN")
    W.fire("PLAYER_ENTERING_WORLD")
    W.run(5)
    for _, name in ipairs(root.order) do check(root.mods[name].db, name .. " initialisé") end
    local HEALERS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }
    check((HEALERS[class] == true) == not root.mods.ForeverHeal.inactive, "Soins actif seulement pour les soigneurs")
    if HEALERS[class] then
      local heal = root.mods.ForeverHeal
      local spells = heal.KnownSpells()
      check(next(spells) ~= nil, "Soins : sorts de la classe reconnus")
      local M = heal.Metrics(heal.Snapshot(), heal.Mix())
      check((M.hps or 0) > 0, "Soins : soins par seconde calculés (" .. tostring(M.hps) .. ")")
      root.SetRole("heal")
      local _, _, nowTiles = root.NowLines()
      local hps = false
      for _, t in ipairs(nowTiles) do if t.kind == "hps" then hps = true end end
      check(hps, "Maintenant : tuile des soins pour un soigneur")
    end
    SlashCmdList.FOREVERCOMPAGNON("")
    check(ForeverCompagnonNowFrame:IsShown(), "écran Maintenant")
    local lines = root.NowLines()
    check(#root.nowErrors == 0, "Maintenant sans erreur : " .. table.concat(root.nowErrors, " ; "))
    for _, r in ipairs(root.ClassRoles()) do
      root.SetRole(r)
      local w = root.mods.ForeverLoot.Weights()
      check(next(w) ~= nil, "poids d'équipement pour le rôle " .. r)
      check(#root.mods.ForeverLoot.NearLines(5) > 0, "Équipement à ton niveau, rôle " .. r)
    end
    check(#root.ClassRoles() >= 1, "au moins un rôle")
    for _, key in ipairs({ "loot", "prep", "metiers", "addons" }) do root.Open(key) end
    if class == "PRIEST" then root.Open("heal") end
    check(#root.mods.ForeverMetiers.LevelLines() > 1, "Métiers : métiers conseillés pour la classe")
    -- cadre « Flash » : un objet équipé change les caractéristiques (relevé générique, ou partie Soins pour un soigneur)
    local bonus = 0
    _G.UnitStat = function(_, i) return 20, 20 + i + (i == 3 and bonus or 0) end
    _G.GetInventoryItemLink = function(_, slot) return slot == 5 and "|cff1eff00|Hitem:6948|h[Robe]|h|r" or nil end
    W.run(3)
    bonus = 12
    W.fire("PLAYER_EQUIPMENT_CHANGED", 5)
    W.fire("UNIT_INVENTORY_CHANGED", "player")
    W.run(3)
    if not HEALERS[class] then
      check(ForeverCompagnonFlash and ForeverCompagnonFlash:IsShown(), "cadre Flash affiché après un changement d'équipement")
      local rows = root.Flash.last and root.Flash.last.rows or {}
      check(rows[1] and rows[1][1] == "sta" and rows[1][2]:find("+12", 1, true), "Flash : +12 Endurance (" .. tostring(rows[1] and rows[1][2]) .. ")")
      check(root.Flash.last.item and root.Flash.last.item:find("Robe", 1, true), "Flash : objet équipé affiché")
    end
    local report = root.TestReport()
    check(not report:find("erreur :", 1, true), "auto-test sans erreur Lua :\n" .. report)
    n = n + 1
  end
end
rprint("ok  " .. n .. " personnages (9 classes x Alliance/Horde) : chargement, Maintenant, rôles, Équipement, Métiers, auto-test")
rprint("\nTOUT OK (" .. LANG .. ")")
