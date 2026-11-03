-- Simulation hors jeu de ForeverGazette (Lua 5.1) : API WoW imitée, journée de jeu fictive, vérifications.
-- Lancer depuis la racine du dépôt : lua5.1 tests/gazette_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local unpack = unpack or table.unpack

----------------------------------------------------------------------
-- Imitation de l'API
----------------------------------------------------------------------
local frames, timers = {}, {}
local clock = 1000.0
local function noop() end
local function Obj(kind)
  local o = { __kind = kind, scripts = {}, events = {}, shown = false, w = 500, h = 10, text = "" }
  return setmetatable(o, { __index = function(t, k)
    local m = ({
      SetScript = function(self, n, f) self.scripts[n] = f end,
      GetScript = function(self, n) return self.scripts[n] end,
      RegisterEvent = function(self, e) self.events[e] = true end,
      Show = function(self) local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end,
      Hide = function(self) self.shown = false end,
      SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
      IsShown = function(self) return self.shown end,
      IsVisible = function(self) return self.shown end,
      GetWidth = function(self) return self.w end,
      SetWidth = function(self, w) self.w = w end,
      SetSize = function(self, w, h) self.w, self.h = w, h end,
      SetHeight = function(self, h) self.h = h end,
      GetHeight = function(self) return self.h end,
      SetText = function(self, s) self.text = s end,
      GetText = function(self) return self.text end,
      GetStringHeight = function(self) local n = 1; for _ in tostring(self.text):gmatch("\n") do n = n + 1 end; return 14 * n end,
      CreateFontString = function() return Obj("FontString") end,
      CreateTexture = function() return Obj("Texture") end,
      CreateAnimationGroup = function() return Obj("AnimationGroup") end,
      CreateAnimation = function() return Obj("Animation") end,
      GetChecked = function(self) return self.checked end,
      SetChecked = function(self, v) self.checked = v end,
      GetCenter = function() return 100, 100 end,
      GetEffectiveScale = function() return 1 end,
      GetBottom = function() return 300 end,
      GetFrameLevel = function() return 1 end,
    })[k]
    if m then return m end
    return noop
  end })
end
_G.CreateFrame = function(kind) local f = Obj(kind); frames[#frames + 1] = f; return f end
_G.UIParent, _G.Minimap, _G.GameTooltip = Obj("Frame"), Obj("Frame"), Obj("GameTooltip")
_G.UISpecialFrames, _G.StaticPopupDialogs, _G.SlashCmdList = {}, {}, {}
_G.ChatFontNormal = {}
_G.YES, _G.NO, _G.UNKNOWNOBJECT = "Oui", "Non", "Inconnu"
_G.tinsert, _G.wipe = table.insert, function(t) for k in pairs(t) do t[k] = nil end return t end
_G.bit = { band = function(a, b)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + p end
    a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
  end
  return r
end }
_G.GetLocale = function() return LANG == "fr" and "frFR" or "enUS" end
_G.GetBuildInfo = function() return "1.0", "1", "", 20505 end
_G.GetTime = function() return clock end
_G.time, _G.date = os.time, os.date
_G.print = print
_G.C_Timer = { After = function(s, f) timers[#timers + 1] = { at = clock + s, f = f } end, NewTicker = function() return {} end }
local function RunTimers()
  local again = true
  while again do
    again = false
    for i, t in ipairs(timers) do
      if t.at <= clock then table.remove(timers, i); t.f(); again = true; break end
    end
  end
end
local state = { level = 19, xp = 1000, xpmax = 20000, money = 95 * 10000, zone = "Elwynn", inInstance = false, itype = "none",
                guild = true, group = {}, sex = 2 }
_G.UnitLevel = function(u) if u == "player" then return state.level end return state.units[u] and state.units[u].lvl end
_G.UnitXP = function() return state.xp end
_G.UnitXPMax = function() return state.xpmax end
_G.GetMoney = function() return state.money end
_G.UnitName = function(u) if u == "player" then return "Machin" end local x = state.units[u]; return x and x.name end
_G.UnitGUID = function(u) if u == "player" then return "Player-1-AAAA" end local x = state.units[u]; return x and x.guid end
_G.UnitExists = function(u) return u == "player" or state.units[u] ~= nil end
_G.UnitIsPlayer = function(u) local x = state.units[u]; return u == "player" or (x and x.player) end
_G.UnitClassification = function(u) local x = state.units[u]; return x and x.c or "normal" end
_G.UnitSex = function() return state.sex end
_G.GetRealZoneText = function() return state.zone end
_G.IsInInstance = function() return state.inInstance, state.itype end
_G.IsInGuild = function() return state.guild end
_G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() return #state.group > 0 and #state.group + 1 or 0 end
_G.GetRealmName = function() return "Forever" end
_G.GetCVar = function() return "jpeg" end
local shots, chat = 0, {}
_G.Screenshot = function() shots = shots + 1 end
_G.SendChatMessage = function(msg, ch) chat[#chat + 1] = { msg, ch } end
_G.GetNumFactions = function() return #state.factions end
_G.GetFactionInfo = function(i) local f = state.factions[i]; return f[1], "", f[2], 0, 0, 0, false, false, false, false, true end
state.factions = { { "Hurlevent", 4 }, { "Forgefer", 5 } }
state.units = {}
local cleu
_G.CombatLogGetCurrentEventInfo = function() return unpack(cleu) end
_G.C_QuestLog = { GetTitleForQuestID = function(id) return "Quête " .. id end }
if LANG == "fr" then
  _G.LOOT_ITEM_SELF = "Vous recevez le butin : %s."
  _G.LOOT_ITEM_SELF_MULTIPLE = "Vous recevez le butin : %sx%d."
  _G.SKILL_RANK_UP = "Votre compétence en %s est maintenant de %d."
  _G.ERR_LEARN_RECIPE_S = "Vous avez appris à fabriquer un nouvel objet : %s."
  _G.DUEL_WINNER_KNOCKOUT = "%1$s a vaincu %2$s lors d'un duel"
  _G.DUEL_WINNER_RETREAT = "%2$s s'est enfui devant %1$s lors d'un duel"
  _G.FACTION_STANDING_LABEL5, _G.FACTION_STANDING_LABEL6 = "Amical", "Honoré"
else
  _G.LOOT_ITEM_SELF = "You receive loot: %s."
  _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
  _G.SKILL_RANK_UP = "Your skill in %s has increased to %d."
  _G.ERR_LEARN_RECIPE_S = "You have learned how to create a new item: %s."
  _G.DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
  _G.DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
  _G.FACTION_STANDING_LABEL5, _G.FACTION_STANDING_LABEL6 = "Friendly", "Honored"
end

----------------------------------------------------------------------
-- Chargement de l'addon (même ordre que le .toc)
----------------------------------------------------------------------
local ns = {}
for _, f in ipairs({ "Locale", "Templates", "Core", "Gazette", "Tour", "UI" }) do
  local chunk = assert(loadfile("ForeverGazette/" .. f .. ".lua"))
  chunk("ForeverGazette", ns)
end
local evf = ns.eventFrame
local function Fire(e, ...) evf.scripts.OnEvent(evf, e, ...) end
local function Log(sub, src, srcName, srcFlags, dst, dstName, p12)
  cleu = { 0, sub, false, src, srcName, srcFlags, 0, dst, dstName, 0, 0, p12 }
  Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
local function check(cond, msg) if not cond then error("ÉCHEC : " .. msg, 2) end print("ok  " .. msg) end

Fire("ADDON_LOADED", "ForeverGazette")
check(ForeverGazetteDB and ForeverGazetteDB.tone == "serious", "base créée, ton sérieux par défaut")
Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD")
check(ForeverGazetteDB.seen.zones.Elwynn, "zone de départ marquée vue sans article (première installation)")
clock = clock + 6; RunTimers()                               -- scan initial réputation / groupe
check(ForeverGazetteDB.seen.rep.Hurlevent == 4, "réputations initiales enregistrées sans article")

local L = ns.L
local today = ns.Today()
local function Events() return ForeverGazetteDB.days[today] and ForeverGazetteDB.days[today].events or {} end
local function Has(kind) for _, e in ipairs(Events()) do if e.k == kind then return e end end end

-- nouvelle zone
state.zone = "Marche de l'Ouest"; Fire("ZONE_CHANGED_NEW_AREA")
check(Has("zone"), "nouvelle zone notée")
-- donjon + boss par le journal de combat
state.zone, state.inInstance, state.itype = "Les Mortemines", true, "party"; Fire("ZONE_CHANGED_NEW_AREA")
check(Has("dungeon"), "premier donjon noté")
state.units.target = { guid = "Creature-0-1-VC", name = "Edwin VanCleef", c = "elite", lvl = -1 }
Fire("PLAYER_TARGET_CHANGED")
Log("SPELL_DAMAGE", "Player-1-AAAA", "Machin", 0x511, "Creature-0-1-VC", "Edwin VanCleef")
Log("UNIT_DIED", "", nil, 0, "Creature-0-1-VC", "Edwin VanCleef")
check(Has("boss") and Has("boss").v.target == "Edwin VanCleef", "boss vaincu noté (crâne + élite en instance)")
clock = clock + 2; RunTimers()
check(Has("boss").shot and Has("boss").shot:match("^WoWScrnShot_%d+_%d+%.jpg$"), "photo de une prise pour le boss : " .. tostring(Has("boss").shot))
check(shots == 1, "Screenshot() appelé une fois")
ENCOUNTER = Fire("ENCOUNTER_END", 1, "Edwin VanCleef", 1, 5, 1)
local n = 0; for _, e in ipairs(Events()) do if e.k == "boss" then n = n + 1 end end
check(n == 1, "pas de doublon entre UNIT_DIED et ENCOUNTER_END")
-- victoires : compteur
Log("PARTY_KILL", "Player-1-AAAA", "Machin", 0x511, "Creature-0-1-X", "Défias")
check(ForeverGazetteDB.days[today].stats.kills == 1, "ennemi vaincu compté")
-- butin épique et bleu, objet gris ignoré
local epic = "|cffa335ee|Hitem:18832::::::::60:::::::|h[Lame de brutalité]|h|r"
local blue = "|cff0070dd|Hitem:10413::::::::40:::::::|h[Gantelets]|h|r"
local grey = "|cff9d9d9d|Hitem:1::::::::1:::::::|h[Os]|h|r"
Fire("CHAT_MSG_LOOT", string.format(_G.LOOT_ITEM_SELF, epic))
Fire("CHAT_MSG_LOOT", string.format(_G.LOOT_ITEM_SELF_MULTIPLE, blue, 2))
Fire("CHAT_MSG_LOOT", string.format(_G.LOOT_ITEM_SELF, grey))
Fire("CHAT_MSG_LOOT", "Bidule reçoit le butin : " .. epic .. ".")
check(Has("loot_epic") and Has("loot_rare"), "butins épique et rare notés")
local nl = 0; for _, e in ipairs(Events()) do if e.k:find("^loot") then nl = nl + 1 end end
check(nl == 2, "objet gris et butin d'un autre joueur ignorés")
check(ns.LinkQuality("|cnIQ4:|Hitem:1|h[X]|h|r") == 4, "qualité du nouveau format de lien (|cnIQ4:)")
-- mort par chute
state.inInstance, state.itype, state.zone = false, "none", "Les Carmines"
Log("ENVIRONMENTAL_DAMAGE", "", nil, 0, "Player-1-AAAA", "Machin", "Falling")
Fire("PLAYER_DEAD")
check(Has("death") and Has("death").v.killer == "@fall", "mort par chute notée")
-- niveau
state.level = 20; Fire("PLAYER_LEVEL_UP", 20)
check(Has("level") and Has("level").s == 80, "niveau 20 noté avec le bonus de dizaine")
-- métier, recette, duel
Fire("CHAT_MSG_SKILL", string.format(_G.SKILL_RANK_UP, LANG == "fr" and "Forge" or "Blacksmithing", 150))
check(Has("skill") and Has("skill").v.rank == 150, "palier de métier noté")
Fire("CHAT_MSG_SYSTEM", string.format(_G.ERR_LEARN_RECIPE_S, "Épée en cuivre"))
check(Has("recipe"), "recette notée")
Fire("CHAT_MSG_SYSTEM", (_G.DUEL_WINNER_KNOCKOUT:gsub("%%1%$s", "Machin"):gsub("%%2%$s", "Grosbill")))
check(Has("duel_win") and Has("duel_win").v.target == "Grosbill", "duel gagné (format positionnel)")
Fire("CHAT_MSG_SYSTEM", (_G.DUEL_WINNER_RETREAT:gsub("%%1%$s", "Lyra"):gsub("%%2%$s", "Machin")))
check(Has("duel_loss") and Has("duel_loss").v.target == "Lyra", "duel perdu par abandon (arguments inversés)")
-- réputation
state.factions[1][2] = 6; Fire("UPDATE_FACTION"); clock = clock + 3; RunTimers()
check(Has("rep") and Has("rep").v.standing == _G.FACTION_STANDING_LABEL6, "palier de réputation noté")
-- or
state.money = 120 * 10000; Fire("PLAYER_MONEY")
check(Has("money") and Has("money").v.gold == 100 * 10000, "palier de 100 po noté")
check(ForeverGazetteDB.days[today].stats.earned == 25 * 10000, "or gagné compté")
-- quête, groupe, JcJ
Fire("QUEST_TURNED_IN", 42, 100, 0)
check(Has("quest") and ForeverGazetteDB.days[today].stats.quests == 1, "quête rendue notée")
state.group = { 1 }; state.units.party1 = { name = "Thorgal", player = true, guid = "Player-1-BBBB" }
Fire("GROUP_ROSTER_UPDATE")
check(ForeverGazetteDB.days[today].stats.companions[1] == "Thorgal", "compagnon de groupe noté")
Log("PARTY_KILL", "Player-1-AAAA", "Machin", 0x511, "Player-2-CCCC", "Orcdur")
check(Has("pvp"), "victoire JcJ notée")
-- expérience
state.xp = 5000; Fire("PLAYER_XP_UPDATE")
check(ForeverGazetteDB.days[today].stats.xp == 4000, "expérience comptée")

----------------------------------------------------------------------
-- Édition, hebdo, exports
----------------------------------------------------------------------
local blocks, top = ns.BuildEdition(today)
check(blocks and top and top.k == "level", "la une est le niveau 20 (score le plus haut)")
local md = ns.ToText(blocks, "md")
print("\n" .. md .. "\n")
check(md:find("Lame de brutalité", 1, true) and not md:find("|H", 1, true), "export Markdown sans codes de couleur")
check(not md:find("à Les", 1, true) and not md:find(" à Le ", 1, true), "contractions françaises (aux, au)")
ForeverGazetteDB.tone = "epic"
local mdEpic = ns.ToText(ns.BuildEdition(today), "md")
check(not mdEpic:find("en Les", 1, true), "contractions françaises, ton épique (en Les -> aux)")
ForeverGazetteDB.tone = "serious"
check(md:find("Nécrologie", 1, true) or md:find("Obituaries", 1, true), "rubrique nécrologie présente")
for _, tone in ipairs(ns.TONES) do
  ForeverGazetteDB.tone = tone
  local b = ns.BuildEdition(today)
  local left
  for _, x in ipairs(b) do if x.text:find("{%w+}") then left = x.kind .. " : " .. x.text end end
  check(not left, "ton " .. tone .. " : aucune variable non remplie" .. (left and (" -> " .. left) or ""))
end
ForeverGazetteDB.tone = "tabloid"
local wk = ns.BuildWeekly(today)
check(wk and ns.ToText(wk, "md"):find("#", 1, true), "édition hebdomadaire construite")
local lines = ns.ChatLines(ns.BuildEdition(today), 8)
local bad
for _, l in ipairs(lines) do if #l > 255 then bad = l end; if l:find("|c%x") and not l:find("|Hitem") then bad = l end end
check(#lines >= 3 and not bad, "lignes de discussion valides (" .. #lines .. ")")
ns.Share("GUILD"); clock = clock + 10; RunTimers()
check(#chat == #lines and chat[1][2] == "GUILD", "partage en guilde : " .. #chat .. " message(s)")
Fire("PLAYER_LOGOUT")
check(ForeverGazetteDB.exports and ForeverGazetteDB.exports.days[today] and ForeverGazetteDB.exports.days[today].shot,
      "export pour le compagnon écrit à la déconnexion, avec la photo")
-- démo et interface (imitée)
SlashCmdList.FOREVERGAZETTE("demo")
SlashCmdList.FOREVERGAZETTE("")
SlashCmdList.FOREVERGAZETTE("sommaire")
SlashCmdList.FOREVERGAZETTE("hebdo")
SlashCmdList.FOREVERGAZETTE("ton epique")
check(ForeverGazetteDB.tone == "epic", "commande /gazette ton epique")
SlashCmdList.FOREVERGAZETTE("export")
-- anti-doublon et ménage
local before = #Events()
Fire("PLAYER_LEVEL_UP", 20)
check(#Events() == before, "même niveau deux fois : un seul article")
ForeverGazetteDB.days["2000-01-01"] = { events = {}, stats = {} }
ns._InitDB()
check(ForeverGazetteDB.days["2000-01-01"] == nil, "vieilles éditions supprimées au chargement")
check(ns.Upper("L'Écho Croustillant — spécial çà") == "L'ÉCHO CROUSTILLANT — SPÉCIAL ÇÀ", "majuscules accentuées")
ForeverGazetteDB.tone = "tabloid"
if LANG == "fr" then check(ns.ToText(ns.BuildEdition(today, ns.DemoDay(), 42), "md"):find("SPÉCIAL", 1, true), "titre du journal en majuscules accentuées") end
print("\nTOUT OK (" .. LANG .. ")")

-- Écrit la base au format SavedVariables du jeu (pour tester le compagnon Discord)
local out = arg and arg[2]
if out then
  local function q(s)
    return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  end
  local function dump(v, indent)
    if type(v) == "table" then
      local parts, n = { "{\n" }, 0
      for k, x in pairs(v) do
        if type(k) == "number" then n = n + 1; parts[#parts + 1] = indent .. "\t" .. dump(x, indent .. "\t") .. ", -- [" .. k .. "]\n"
        else parts[#parts + 1] = indent .. "\t[" .. q(k) .. "] = " .. dump(x, indent .. "\t") .. ",\n" end
      end
      parts[#parts + 1] = indent .. "}"
      return table.concat(parts)
    elseif type(v) == "string" then return q(v)
    else return tostring(v) end
  end
  Fire("PLAYER_LOGOUT")
  local f = assert(io.open(out, "w"))
  f:write("\nForeverGazetteDB = " .. dump(ForeverGazetteDB, "") .. "\n")
  f:close()
  print("SavedVariables écrit : " .. out)
end
