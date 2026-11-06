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
UIParent.shown = true
_G.UISpecialFrames, _G.StaticPopupDialogs, _G.SlashCmdList = {}, {}, {}
_G.StaticPopup_Show = function() end
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
local uiAtShot
_G.Screenshot = function() shots = shots + 1; uiAtShot = UIParent.shown end
_G.InCombatLockdown = function() return false end
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
_G.date = _G.date or os.date
_G.time = _G.time or os.time
_G.UnitRace = _G.UnitRace or function() return "Humain", "Human" end
_G.UnitClass = _G.UnitClass or function() return "Prêtre", "PRIEST" end
_G.UnitFactionGroup = _G.UnitFactionGroup or function() return "Alliance" end
_G.GetRealmName = _G.GetRealmName or function() return "Forever" end
_G.GetBuildInfo = _G.GetBuildInfo or function() return "1.16.0", "60000", "Nov 1 2026", 16001 end
_G.GetAddOnMetadata = function(_, f) return f == "Version" and "test" or nil end
_G.IsAddOnLoaded = function() return true end
_G.ChatFontNormal = _G.ChatFontNormal or {}
local ns = {}
for _, f in ipairs({ "Locale", "Diag", "Templates", "Core", "Gazette", "Tour", "Widgets", "UI" }) do
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
clock = clock + 2; RunTimers(); clock = clock + 0.2; RunTimers()
check(Has("boss").shot and Has("boss").shot:match("^WoWScrnShot_%d+_%d+%.jpg$"), "photo de une prise pour le boss : " .. tostring(Has("boss").shot))
check(shots == 1, "Screenshot() appelé une fois")
check(uiAtShot == false, "interface masquée au moment de la capture (photos sans interface)")
Fire("SCREENSHOT_SUCCEEDED"); clock = clock + 1; RunTimers()
check(UIParent.shown == true, "interface rétablie après la capture")
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
local exb = ForeverGazetteDB.exports.days[today].blocks
local withShot, epicQ
for _, x in ipairs(exb) do
  if x.f and x.k ~= "photo" then withShot = x end
  if x.q == 4 then epicQ = x end
  assert(not x.t:find("|c%x") and not x.t:find("|H"), "bloc exporté sans codes : " .. x.t)
end
check(#exb > 10 and withShot and epicQ, "blocs exportés pour le PDF (photo du boss sur sa ligne, qualité épique)")
local reloaded = false
_G.ReloadUI = function() reloaded = true end
-- WoW Forever : ReloadUI est interdit aux addons ; la gazette est préparée et le joueur tape /reload
local saveBI = _G.GetBuildInfo
_G.GetBuildInfo = function() return "1.60.1", "70790", "Nov 3 2026", 16001 end
local said
local savePrint = _G.print
_G.print = function(...) said = table.concat({ ... }, " "); savePrint(...) end
ns.db.exports = nil
SlashCmdList.FOREVERGAZETTE("pdf")
_G.print = savePrint
check(not reloaded and ns.db.exports and said and said:find("/reload", 1, true),
      "WoW Forever : PDF préparé, « tape /reload » (jamais ReloadUI, interdit)")
-- TBC Anniversary : rechargement après confirmation, comme avant
_G.GetBuildInfo = function() return "2.5.5", "60000", "Nov 1 2026", 20505 end
SlashCmdList.FOREVERGAZETTE("pdf")
StaticPopupDialogs.FOREVERGAZETTE_PDF.OnAccept()
check(reloaded, "TBC : bouton PDF, export puis rechargement de l'interface")
_G.GetBuildInfo = saveBI
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
local diagText = ns.DiagText()
if os.getenv("SHOW_DIAG") then print(diagText) end
check(diagText:find("diagnostic", 1, true) and not diagText:find("Erreur", 1, true), "diagnostic : texte complet, sans erreur (" .. #diagText .. " caractères)")
if os.getenv("SHOW_DIAG") then print(diagText) end
SlashCmdList["FOREVERGAZETTE"]("diag")
-- Passage en donjon : entrée, boss, mort d'un membre, soins, sortie
ForeverGazetteDB.days[today] = nil
state.zone, state.inInstance, state.itype = "Ombrecroc", true, "party"
Fire("ZONE_CHANGED_NEW_AREA")
check(ForeverGazetteDB.run and ForeverGazetteDB.run.zone == "Ombrecroc", "passage en donjon : suivi commencé")
Fire("ENCOUNTER_END", 2, "Arugal", 1, 5, 1)
Log("UNIT_DIED", "", nil, 0, "Player-3-DDDD", "Lyra")
cleu = { 0, "UNIT_DIED", false, "", nil, 0, 0, "Player-3-DDDD", "Lyra", 0x512, 0 }
Fire("COMBAT_LOG_EVENT_UNFILTERED")
for _ = 1, 10 do
  cleu = { 0, "SPELL_HEAL", false, "Player-1-AAAA", "Machin", 0x511, 0, "Player-3-DDDD", "Lyra", 0x512, 0, 2061, "Soins rapides", 2, 1000, 200, 0, false }
  Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
check(#ForeverGazetteDB.run.bosses == 1 and ForeverGazetteDB.run.deaths == 1 and ForeverGazetteDB.run.heal == 8000, "boss, mort du groupe et soins comptés")
ForeverGazetteDB.run.start = time() - 1500
state.zone, state.inInstance, state.itype = "Forêt des Pins-Argentés", false, "none"
Fire("ZONE_CHANGED_NEW_AREA")
local runEv
for _, e in ipairs(ForeverGazetteDB.days[today].events) do if e.k == "run" then runEv = e end end
check(runEv and runEv.v.bosses == 1 and not ForeverGazetteDB.run, "sortie : passage noté (1 boss), suivi terminé")
ForeverGazetteDB.tone = "serious"
local runMd = ns.ToText(ns.BuildEdition(today), "md")
print(runMd:match("### Donjons.-\n\n") or runMd:match("### Dungeons.-\n\n") or runMd)
check(runMd:find("Ombrecroc : 1 boss en 25 min", 1, true) or runMd:find("Ombrecroc: 1 boss(es) in 25 min", 1, true) or runMd:find("Ombrecroc", 1, true),
      "rubrique Donjons dans l'édition")
check(runMd:find("8 000 PV soignés (20 % d'excédent)", 1, true) or runMd:find("8,000 HP healed (20% overheal)", 1, true), "soins du passage : total et excédent")
ns.lastDiag = nil
local dbtn = ns.ui and ns.ui.diagBtn
check(dbtn and dbtn.scripts.OnClick, "bouton « Diag » présent dans la fenêtre")
dbtn.scripts.OnClick(dbtn)
check(ns.lastDiag and ns.lastDiag:find("diagnostic", 1, true), "clic sur « Diag » : diagnostic ouvert sans commande écrite")
-- titre : deux passages de niveau dans la journée, le titre annonce le dernier (capture du 05/11/2026 : « Niveau 2 » au niveau 3)
local now = time()
local lv = { events = { { t = now - 900, k = "level", v = { level = 2 }, s = 50 }, { t = now - 300, k = "level", v = { level = 3 }, s = 50 } },
             stats = { play = 1800, level = 3 } }
local hb = ns.BuildEdition(ns.Today(), lv, 1)
local head
for _, b in ipairs(hb) do if b.kind == "headline" then head = b.text end end
check(head and head:find("3", 1, true) and not head:find("2", 1, true), "titre : le dernier niveau atteint (« " .. tostring(head) .. " »)")
local secs = {}
for _, b in ipairs(hb) do if b.kind == "section" then secs[#secs + 1] = b.sec end end
check(#secs >= 1 and secs[#secs] == "stats", "rubriques marquées pour leur icône (bilan : stats)")
-- fenêtre : onglets et barre de navigation
ns.ShowDay(ns.Today())
check(ns.ui.tabDay.active and not ns.ui.tabIndex.active and ns.ui.navLabel:GetText() == ns.FormatDate(ns.Today()),
      "fenêtre : onglet « Édition du jour » actif, date au milieu de la barre")
ns.ShowIndex()
check(ns.ui.tabIndex.active and not ns.ui.tabDay.active and ns.ui.backBtn:IsShown() and not ns.ui.prevBtn:IsShown(),
      "fenêtre : onglet Sommaire actif, bouton Retour, pas de Veille")
ns.ShowDay(ns.Today())
check(ns.ui.exportBtn.label:GetText() == ns.L.export and ns.ui.pdfBtn.label:GetText() == ns.L.pdf, "actions en icônes avec leur nom dessous")

-- regroupements (PDF du 05/11/2026) : 5 passages de niveau = une ligne, 12 recettes = une ligne ; accord « a-t-elle »
local evs = {}
for lv = 2, 7 do evs[#evs + 1] = { t = now - 1000 + lv * 10, k = "level", v = { level = lv }, s = 50 } end
for i = 1, 12 do evs[#evs + 1] = { t = now - 900 + i, k = "recipe", v = { recipe = "Recette " .. i }, s = 8 } end
evs[#evs + 1] = { t = now - 100, k = "zone", v = { zone = "Forgefer" }, s = 15 }
local saveSex, saveTone = _G.UnitSex, ns.db.tone
_G.UnitSex = function() return 3 end
ns.db.tone = "tabloid"
local gb = ns.BuildEdition(ns.Today(), { events = evs, stats = { play = 6700, level = 7 } }, 1)
local all, nRecipe, nLevel = {}, 0, 0
for _, b in ipairs(gb) do
  all[#all + 1] = b.text
  if b.kind == "line" and b.text:find("Recette", 1, true) then nRecipe = nRecipe + 1 end
  if b.kind == "line" and b.text:find("niveau", 1, true) then nLevel = nLevel + 1 end
end
local gtxt = table.concat(all, "\n")
check(nRecipe <= 1 and gtxt:find("12", 1, true), "12 recettes : une seule ligne avec le compte")
check(nLevel <= 1 and gtxt:find("2", 1, true) and gtxt:find("7", 1, true), "niveaux 2 à 7 : une seule ligne (ou le gros titre)")
check(not gtxt:find("a-t-e ", 1, true) and not gtxt:find("dit-e)", 1, true), "accord : jamais « a-t-e » ni « dit-e »")
if LANG == "fr" then check(gtxt:find("a-t-elle", 1, true), "accord : « a-t-elle triché ? » pour une prêtresse") end
_G.UnitSex, ns.db.tone = saveSex, saveTone

-- gazette du 05/11/2026 : Forgefer et la salle des Thanes apparaissaient deux fois (« Vue pour la première fois » + « Aperçu »)
local dup = {
  { t = now - 50, k = "dungeon", v = { zone = "Forgefer" }, s = 35 },
  { t = now - 40, k = "zone", v = { zone = "Forgefer" }, s = 15 },
  { t = now - 30, k = "zone", v = { zone = "Dun Morogh" }, s = 15 },
  { t = now - 20, k = "zone", v = { zone = "Dun Morogh" }, s = 15 },
}
local nForge, nDun = 0, 0
for _, b in ipairs(ns.BuildEdition(ns.Today(), { events = dup, stats = { play = 60, level = 7 } }, 1)) do
  if b.text and b.text:find("Forgefer", 1, true) then nForge = nForge + 1 end
  if b.text and b.text:find("Dun Morogh", 1, true) then nDun = nDun + 1 end
end
check(nForge == 1 and nDun == 1, "un lieu n'apparaît qu'une fois dans la gazette")
-- une ville vue comme « scénario » par le client de Forever n'est pas un donjon
local saveII, saveZT = _G.IsInInstance, _G.GetRealZoneText
_G.IsInInstance = function() return true, "scenario" end
_G.GetRealZoneText = function() return "La salle des Thanes" end
ns.db.seen.zones["La salle des Thanes"], ns.db.seen.instances["La salle des Thanes"] = nil, nil
pcall(Fire, "ZONE_CHANGED_NEW_AREA")
check(not ns.db.seen.instances["La salle des Thanes"] and ns.db.seen.zones["La salle des Thanes"], "ville en « scénario » : simple visite, pas un donjon")
_G.IsInInstance, _G.GetRealZoneText = saveII, saveZT

-- client de Forever : C_CombatLog.GetCurrentEventInfo est réservé à Blizzard (appel bloqué) : jamais appelé
local blocked = 0
local saveCL = _G.CombatLogGetCurrentEventInfo
_G.CombatLogGetCurrentEventInfo = nil
_G.C_CombatLog = { GetCurrentEventInfo = function() blocked = blocked + 1 end }
local okCL = pcall(Fire, "COMBAT_LOG_EVENT_UNFILTERED")
check(okCL and blocked == 0, "client de Forever : C_CombatLog.GetCurrentEventInfo (protégé) jamais appelé")
_G.C_CombatLog, _G.CombatLogGetCurrentEventInfo = nil, saveCL
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
