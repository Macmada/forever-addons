local _, root = ...

-- Surveillance des erreurs de TOUS les addons (15/11/2026, après le client 1.60.1 : avalanche d'erreurs sans
-- message lisible, « Vos add-ons subissent un grand nombre d'erreurs ») :
--  * erreurs Lua (gestionnaire d'erreurs du jeu chaîné, le comportement normal est gardé), actions bloquées par le jeu
--    (ADDON_ACTION_BLOCKED / FORBIDDEN) et avertissements Lua, avec l'addon en cause, le nombre de fois, l'heure et si
--    c'était en combat ;
--  * gardées d'une session à l'autre (les 3 dernières), pour voir si un problème revient ;
--  * une seule ligne dans le chat par addon et par session, avec un conseil quand le problème est connu ;
--  * un JOURNAL horodaté (ce que WoW n'a pas) : erreurs, actions bloquées et contexte (connexion, /reload, zone,
--    combats, niveau), gardé dans le fichier de sauvegarde de l'addon, donc lisible sur le PC hors du jeu :
--    WTF\Account\<compte>\SavedVariables\ForeverCompagnon.lua, ForeverCompagnonDB.debug.log (écrit par le jeu à la
--    déconnexion et à chaque /reload ; pas après un plantage du jeu) ;
--  * /fp erreurs (résumé), /fp erreurs effacer, /fp erreurs muet, /fp log, /fp rapport (rapport complet à copier).

local FR = GetLocale() == "frFR"
local D = {}
root.Debug = D

local MAX = 80                     -- problèmes différents gardés par session
local KEEP = 3                     -- sessions précédentes gardées
local LOG_MAX = 800                -- lignes du journal gardées (toutes sessions)
local session = { start = date("%Y-%m-%d %H:%M"), items = {} }
D.session = session
local byKey = {}
local told = {}                    -- addon -> déjà signalé dans le chat cette session
local ready = false                -- chat disponible (après la connexion)
local pending = {}

local T = FR and {
  kind_error = "erreur Lua", kind_blocked = "action bloquée", kind_forbidden = "action interdite", kind_warning = "avertissement",
  chat = "%s : %s (%s). Détails et conseil : /fp erreurs",
  chatQuiet = "Signalement des erreurs dans le chat : %s (/fp erreurs muet pour changer)",
  on = "activé", off = "coupé", cleared = "Relevé des erreurs effacé.",
  title = "ForeverCompagnon — erreurs des addons (copie ce texte pour Claude)",
  reportTitle = "ForeverCompagnon — rapport complet (Ctrl+A, Ctrl+C, puis colle-le à Claude)",
  none = "Aucune erreur ni action bloquée depuis la connexion.",
  head = "### Erreurs et actions bloquées — session du %s (client %s, build %s)",
  times = "%d fois", inCombat = "dont %d en combat", last = "dernière à %s",
  advice = "Conseil", stack = "pile",
  prev = "### Sessions précédentes", prevLine = "%s : %s",
  updateIt = "mets %s à jour dans WowUp ; si ça continue, signale-le à son auteur avec ce texte",
  oursIt = "erreur de ForeverCompagnon : envoie ce rapport à Claude (/fp rapport)",
  blizz = "fichier de Blizzard : souvent provoqué par un addon qui a touché à cette fenêtre (voir la pile)",
  unknownAddon = "addon inconnu",
  addonsHead = "### Addons installés (%d, dont %d chargés)", cvars = "Réglages : affichage des erreurs Lua %s, journal des contaminations (taintLog) %s",
} or {
  kind_error = "Lua error", kind_blocked = "blocked action", kind_forbidden = "forbidden action", kind_warning = "warning",
  chat = "%s: %s (%s). Details and advice: /fp erreurs",
  chatQuiet = "Error notices in chat: %s (/fp erreurs muet to change)",
  on = "on", off = "off", cleared = "Error log cleared.",
  title = "ForeverCompagnon — addon errors (copy this text for Claude)",
  reportTitle = "ForeverCompagnon — full report (Ctrl+A, Ctrl+C, then paste it to Claude)",
  none = "No error or blocked action since login.",
  head = "### Errors and blocked actions — session of %s (client %s, build %s)",
  times = "%d times", inCombat = "%d in combat", last = "last at %s",
  advice = "Advice", stack = "stack",
  prev = "### Previous sessions", prevLine = "%s: %s",
  updateIt = "update %s in WowUp; if it keeps happening, report it to its author with this text",
  oursIt = "ForeverCompagnon error: send this report to Claude (/fp rapport)",
  blizz = "Blizzard file: often caused by an addon that touched this window (see the stack)",
  unknownAddon = "unknown addon",
  addonsHead = "### Installed addons (%d, %d loaded)", cvars = "Settings: Lua error display %s, taint log %s",
}
D.T = T

-- Problèmes connus (motif dans le message ou la fonction) : explication et quoi faire
D.KNOWN = {
  { find = "SetPassThroughButtons", addon = "Questie",
    fr = "bug connu de Questie depuis le client 1.60.1 : ses icônes de la carte du monde touchent une fonction réservée en combat. Sans conséquence (les icônes ne réagissent pas pendant le combat). Mets Questie à jour ; suivi : github.com/Questie/Questie/issues/8304",
    en = "known Questie bug since client 1.60.1: its world map icons call a function reserved in combat. Harmless (icons do not react during combat). Update Questie; tracking: github.com/Questie/Questie/issues/8304" },
  { find = "SetPropagateMouseClicks",
    fr = "même cause que le bug de Questie (carte du monde ouverte en combat, client 1.60.1) : sans conséquence, mets l'addon à jour",
    en = "same cause as the Questie bug (world map open in combat, client 1.60.1): harmless, update the addon" },
  { find = "Auras cannot be accessed when secret",
    fr = "depuis le client 1.60.1, les améliorations (buffs) ne se lisent plus en combat. Corrigé dans ForeverCompagnon 3.5.13 ; pour un autre addon, mets-le à jour",
    en = "since client 1.60.1, auras can no longer be read in combat. Fixed in ForeverCompagnon 3.5.13; for another addon, update it" },
  { find = "secret",
    fr = "valeur « secrète » du client Forever (vie, mana, noms ou auras en combat) : l'addon en cause doit être adapté ; mets-le à jour",
    en = "Forever client « secret » value (health, mana, names or auras in combat): the addon must be adapted; update it" },
  { find = "attempt to call a nil value",
    fr = "fonction absente de ce client (souvent retirée par un patch) : l'addon en cause doit être mis à jour",
    en = "function missing from this client (often removed by a patch): the addon must be updated" },
}

local function AddonOf(text)
  if type(text) ~= "string" then return nil end
  return text:match("[Aa]dd[Oo]ns[/\\]([^/\\\"%]:]+)")
end

local function Advice(e)
  local hay = (e.msg or "") .. " " .. (e.func or "")
  for _, k in ipairs(D.KNOWN) do
    if hay:find(k.find, 1, true) and (not k.addon or k.addon == e.addon) then return FR and k.fr or k.en end
  end
  if e.addon == root.ROOT or (e.addon or ""):find("^Forever") then return T.oursIt end
  if (e.addon or ""):find("^Blizzard_") then return T.blizz end
  if e.addon and e.addon ~= "?" then return string.format(T.updateIt, e.addon) end
end
D.Advice = Advice

local function Now() return date("%H:%M:%S") end
local function Combat() return InCombatLockdown and InCombatLockdown() and true or false end

----------------------------------------------------------------------
-- Journal horodaté : une ligne par événement ; la même ligne répétée dans la minute est regroupée (« ×20 »)
----------------------------------------------------------------------
local log = {}                     -- remplacé par ForeverCompagnonDB.debug.log au chargement
local last = { key = nil, n = 0, at = 0, index = 0, base = nil }
function D.Log(cat, text)
  local ok = pcall(function()
    text = tostring(text or ""):gsub("[\r\n]+", " ")
    if #text > 300 then text = text:sub(1, 300) .. "…" end
    local key = cat .. "|" .. text
    local t = time and time() or 0
    if key == last.key and t - last.at <= 60 and log[last.index] then
      last.n, last.at = last.n + 1, t
      log[last.index] = last.base .. string.format(" (×%d, jusqu'à %s)", last.n, date("%H:%M:%S"))
      return
    end
    local line = date("%Y-%m-%d %H:%M:%S") .. (Combat() and " [combat]" or "") .. " " .. cat .. " " .. text
    log[#log + 1] = line
    while #log > LOG_MAX do table.remove(log, 1) end
    last.key, last.n, last.at, last.index, last.base = key, 1, t, #log, line
  end)
  return ok
end
D.log = function() return log end

local function Tell(e)
  if not ready then pending[#pending + 1] = e; return end
  if told[e.addon or "?"] or (root.db and root.db.debugQuiet) then return end
  told[e.addon or "?"] = true
  local what = e.kind == "error" and e.msg or (e.func or e.msg or "")
  if #what > 90 then what = what:sub(1, 87) .. "…" end
  root.Print(T.chat, e.addon or T.unknownAddon, T["kind_" .. e.kind] or e.kind, what)
end

-- Relève un problème ; ne doit JAMAIS lever d'erreur (appelé depuis le gestionnaire d'erreurs du jeu)
function D.Record(kind, msg, addon, func, stack)
  msg = tostring(msg or "")
  local first = msg:gsub("\r", ""):match("^[^\n]*") or ""
  if #first > 400 then first = first:sub(1, 400) end
  addon = addon or AddonOf(first) or AddonOf(stack) or "?"
  local key = kind .. "|" .. addon .. "|" .. (func or first)
  local e = byKey[key]
  if e then
    D.Log(string.upper(T["kind_" .. kind] or kind), addon .. " : " .. (func or first))
    e.n, e.last = e.n + 1, Now()
    if Combat() then e.combat = e.combat + 1 end
    return e
  end
  if #session.items >= MAX then return nil end
  D.Log(string.upper(T["kind_" .. kind] or kind), addon .. " : " .. (func or first))
  e = { kind = kind, addon = addon, msg = first, func = func, n = 1, first = Now(), last = Now(), combat = Combat() and 1 or 0,
        stack = type(stack) == "string" and stack:sub(1, 1200) or nil }
  byKey[key] = e
  session.items[#session.items + 1] = e
  Tell(e)
  return e
end

-- Gestionnaire d'erreurs du jeu : chaîné (celui d'avant, de Blizzard ou de BugGrabber, garde la main)
local Summary, Meta
local mine
local function Hook()
  if not (geterrorhandler and seterrorhandler) then return end
  local prev = geterrorhandler()
  if prev == mine then return end
  mine = function(msg, ...)
    pcall(function()
      D.Record("error", msg, nil, nil, debugstack and debugstack(3, 12, 0) or nil)
    end)
    if prev then return prev(msg, ...) end
  end
  seterrorhandler(mine)
end
Hook()

local ef = CreateFrame("Frame")
-- actions bloquées : reçues de la fenêtre commune du diagnostic (Shared/Diag.lua), abonnée une seule fois pour tous
_G.ForeverOnBlocked = function(event, addon, func)
  if event ~= "ADDON_ACTION_BLOCKED" and event ~= "ADDON_ACTION_FORBIDDEN" then return end
  D.Record(event == "ADDON_ACTION_BLOCKED" and "blocked" or "forbidden", tostring(func), tostring(addon or "?"), tostring(func))
end
for _, e in ipairs({ "LUA_WARNING", "PLAYER_LOGIN", "PLAYER_LOGOUT",
                     "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                     "PLAYER_LEVEL_UP", "PLAYER_DEAD" }) do pcall(ef.RegisterEvent, ef, e) end
local combatFrom
local function Zone()
  local z = GetRealZoneText and GetRealZoneText() or "?"
  local inInst, kind
  if IsInInstance then inInst, kind = IsInInstance() end     -- « a and f() » ne garderait que la 1re valeur
  return tostring(z) .. (inInst and (" (" .. tostring(kind) .. ")") or "")
end
ef:SetScript("OnEvent", function(_, event, a, b)
  if event == "PLAYER_REGEN_DISABLED" then combatFrom = date("%H:%M:%S"); return
  elseif event == "PLAYER_REGEN_ENABLED" then
    if combatFrom then D.Log("COMBAT", combatFrom .. "–" .. date("%H:%M:%S") .. " — " .. Zone()) end
    combatFrom = nil; return
  elseif event == "PLAYER_ENTERING_WORLD" then
    if a then
      local v, build = GetBuildInfo()
      D.Log("CONNEXION", string.format("%s %s, client %s (%s), niveau %s, %s", root.ROOT, tostring(Meta and Meta(root.ROOT, "Version") or "?"),
        tostring(v), tostring(build), tostring(UnitLevel and UnitLevel("player")), Zone()))
    elseif b then D.Log("RELOAD", "/reload — " .. Zone())
    else D.Log("ZONE", Zone()) end
    return
  elseif event == "ZONE_CHANGED_NEW_AREA" then D.Log("ZONE", Zone()); return
  elseif event == "PLAYER_LEVEL_UP" then D.Log("NIVEAU", tostring(a)); return
  elseif event == "PLAYER_DEAD" then D.Log("MORT", Zone()); return
  elseif event == "PLAYER_LOGOUT" then D.Log("FIN", "déconnexion ou /reload : " .. Summary(session.items)); return
  end
  if event == "PLAYER_LOGIN" then
    Hook()                                                  -- un addon chargé après nous a pu remplacer le gestionnaire
    C_Timer.After(5, function()
      ready = true
      for _, e in ipairs(pending) do Tell(e) end
      wipe(pending)
    end)
  elseif event == "LUA_WARNING" then
    pcall(D.Record, "warning", b, nil, nil, nil)
  end
end)

-- Sauvegarde : la session en cours est gardée dans ForeverCompagnonDB ; les précédentes passent dans l'historique
root.OnLoaded(function()
  local db = root.db
  db.debug = db.debug or { sessions = {} }
  local old = db.debug.current
  if old and old.items and #old.items > 0 then
    table.insert(db.debug.sessions, 1, old)
    while #db.debug.sessions > KEEP do table.remove(db.debug.sessions) end
  end
  db.debug.current = session
  -- journal : on reprend celui de la sauvegarde, en y ajoutant ce qui a été noté avant le chargement
  db.debug.log = db.debug.log or {}
  for _, line in ipairs(log) do db.debug.log[#db.debug.log + 1] = line end
  log = db.debug.log
  while #log > LOG_MAX do table.remove(log, 1) end
  last.key, last.index = nil, 0
end)

----------------------------------------------------------------------
-- Textes
----------------------------------------------------------------------
local function ItemLine(e)
  local bits = { string.format(T.times, e.n) }
  if e.combat > 0 then bits[#bits + 1] = string.format(T.inCombat, e.combat) end
  bits[#bits + 1] = string.format(T.last, e.last)
  local what = e.kind == "error" and e.msg or (e.func or e.msg)
  return string.format("- [%s] %s — %s (%s)", T["kind_" .. e.kind] or e.kind, e.addon, what, table.concat(bits, ", "))
end

function Summary(items)
  local by, order = {}, {}
  for _, e in ipairs(items or {}) do
    if not by[e.addon] then by[e.addon] = 0; order[#order + 1] = e.addon end
    by[e.addon] = by[e.addon] + e.n
  end
  table.sort(order, function(x, y) return by[x] > by[y] end)
  local parts = {}
  for _, a in ipairs(order) do parts[#parts + 1] = a .. " " .. by[a] end
  return table.concat(parts, ", ")
end
D.Summary = Summary

function D.ErrorsText(withStacks)
  local v, build = GetBuildInfo()
  local out = { string.format(T.head, session.start, tostring(v), tostring(build)) }
  if #session.items == 0 then out[#out + 1] = T.none end
  local items = {}
  for _, e in ipairs(session.items) do items[#items + 1] = e end
  table.sort(items, function(x, y) return x.n > y.n end)
  for _, e in ipairs(items) do
    out[#out + 1] = ItemLine(e)
    local adv = Advice(e)
    if adv then out[#out + 1] = "    " .. T.advice .. " : " .. adv end
    if withStacks ~= false and e.stack and e.kind == "error" then
      local n = 0
      for line in e.stack:gmatch("[^\n]+") do
        n = n + 1
        if n > 6 then break end
        out[#out + 1] = "    " .. T.stack .. " : " .. line
      end
    end
  end
  local prev = root.db and root.db.debug and root.db.debug.sessions or {}
  if #prev > 0 then
    out[#out + 1] = ""
    out[#out + 1] = T.prev
    for _, s in ipairs(prev) do out[#out + 1] = string.format(T.prevLine, tostring(s.start), Summary(s.items)) end
  end
  return table.concat(out, "\n")
end

function Meta(a, f) local g = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata; return g and g(a, f) end
local function Loaded(a)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(a) end
  return IsAddOnLoaded and IsAddOnLoaded(a)
end

function D.AddonsText()
  local num = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
  local info = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
  if not (num and info) then return "" end
  if UpdateAddOnMemoryUsage and not Combat() then pcall(UpdateAddOnMemoryUsage) end
  local loadedRows, otherRows, nLoaded = {}, {}, 0
  for i = 1, num() do
    local name, _, _, loadable, reason = info(i)
    if name then
      local ok, isLoaded = pcall(Loaded, name)
      local version = Meta(name, "Version")
      if ok and isLoaded then
        nLoaded = nLoaded + 1
        local mem = GetAddOnMemoryUsage and select(2, pcall(GetAddOnMemoryUsage, name))
        loadedRows[#loadedRows + 1] = string.format("  %s %s%s", name, tostring(version or ""),
          type(mem) == "number" and string.format(" (%.0f Ko)", mem) or "")
      else
        otherRows[#otherRows + 1] = string.format("  %s %s — %s", name, tostring(version or ""), tostring(reason or (loadable and "non chargé" or "désactivé")))
      end
    end
  end
  local out = { string.format(T.addonsHead, #loadedRows + #otherRows, nLoaded) }
  for _, r in ipairs(loadedRows) do out[#out + 1] = r end
  for _, r in ipairs(otherRows) do out[#out + 1] = r end
  local cv = (C_CVar and C_CVar.GetCVar) or GetCVar
  if cv then out[#out + 1] = string.format(T.cvars, tostring(cv("scriptErrors")), tostring(cv("taintLog"))) end
  return table.concat(out, "\n")
end

function D.LogText(n)
  n = n or 300
  local out = { FR and string.format("### Journal (%d dernières lignes sur %d ; aussi dans SavedVariables\\ForeverCompagnon.lua)", math.min(n, #log), #log)
                  or string.format("### Log (last %d lines of %d; also in SavedVariables\\ForeverCompagnon.lua)", math.min(n, #log), #log) }
  for i = math.max(1, #log - n + 1), #log do out[#out + 1] = log[i] end
  return table.concat(out, "\n")
end

function D.FullReport()
  local parts = { D.ErrorsText(true), "", D.AddonsText(), "", D.LogText(200) }
  local function try(f)
    local ok, text = pcall(f)
    parts[#parts + 1] = ""
    parts[#parts + 1] = ok and tostring(text) or ("(erreur : " .. tostring(text) .. ")")
  end
  if root.TestReport then try(function() return (root.TestReport()) end) end
  if root.DiagText then try(function() return (root.DiagText()) end) end
  if root.ProbeText then try(root.ProbeText) end
  return table.concat(parts, "\n")
end

function D.Command(arg)
  arg = (arg or ""):lower()
  if arg == "effacer" or arg == "clear" then
    wipe(session.items); wipe(byKey); wipe(told)
    if root.db and root.db.debug then root.db.debug.sessions = {} end
    root.Print(T.cleared)
  elseif arg == "log" or arg == "journal" then
    root.ShowText(FR and "ForeverCompagnon — journal" or "ForeverCompagnon — log", D.LogText(400))
  elseif arg == "log effacer" or arg == "journal effacer" or arg == "log clear" then
    wipe(log); last.key, last.index = nil, 0
    root.Print(T.cleared)
  elseif arg == "muet" or arg == "mute" then
    root.db.debugQuiet = not root.db.debugQuiet
    root.Print(T.chatQuiet, root.db.debugQuiet and T.off or T.on)
  else
    root.ShowText(T.title, D.ErrorsText(true))
  end
end

function D.ShowReport()
  root.ShowText(T.reportTitle, D.FullReport())
end
