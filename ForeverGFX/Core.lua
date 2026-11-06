local ADDON, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- API (client moderne, avec repli)
----------------------------------------------------------------------
local CV = C_CVar or {}
local GetCVar = CV.GetCVar or GetCVar
local SetCVar = CV.SetCVar or SetCVar
local GetCVarInfo = CV.GetCVarInfo or GetCVarInfo
ns.GetCVar = GetCVar
ns.SetCVarRaw = SetCVar
ns.GetAllCommands = (C_Console and C_Console.GetAllCommands) or ConsoleGetAllCommands
ns.CAT_GRAPHICS = (Enum and Enum.ConsoleCategory and Enum.ConsoleCategory.Graphics) or 1
ns.TYPE_CVAR = (Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar) or 0

ns.state = { lastLabel = nil }
ns.history = {}

-- Points d'accroche remplacés par l'interface
ns.Refresh = function() end
ns.OnBench = function() end
ns.ShowBenchResults = function() end

----------------------------------------------------------------------
-- Outils
----------------------------------------------------------------------
function ns.Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cff66ccffForeverGFX|r " .. msg)
end

function ns.Same(a, b)
  if a == b then return true end
  local na, nb = tonumber(a), tonumber(b)
  return na ~= nil and nb ~= nil and math.abs(na - nb) < 1e-6
end

function ns.Info(name)
  local ok, value, default, _, _, locked, _, readOnly = pcall(GetCVarInfo, name)
  if not ok then return nil end
  return value, default, locked, readOnly
end

function ns.FormatNum(n)
  n = tonumber(n)
  if not n then return "" end
  if n == math.floor(n) then return tostring(math.floor(n)) end
  local s = string.format("%.3f", n)
  s = s:gsub("0+$", "")
  s = s:gsub("%.$", "")
  return s
end

local D = {}
for k, v in pairs(ns.Descriptions) do D[k:lower()] = v end
function ns.Meta(name) return D[name:lower()] end

----------------------------------------------------------------------
-- Catégories
----------------------------------------------------------------------
ns.CAT_ORDER = { "Préréglage", "Anti-aliasing", "Textures", "Éclairage", "Ombres", "Eau",
  "Effets", "Végétation", "Distance", "Image", "Performances", "Interface", "Autres (jeu)" }
ns.CAT_RANK = {}
for i, c in ipairs(ns.CAT_ORDER) do ns.CAT_RANK[c] = i end

local PATTERNS = {
  { "Image", { "gamma", "brightness", "contrast" } },
  { "Ombres", { "shadow" } },
  { "Eau", { "water", "liquid", "ripple", "reflect", "refract" } },
  { "Anti-aliasing", { "msaa", "antialias", "resample", "renderscale", "sharp", "cmaa", "fxaa" } },
  { "Textures", { "texture", "mip", "aniso", "filtering" } },
  { "Végétation", { "grass", "groundeffect", "clutter", "foliage", "doodad" } },
  { "Éclairage", { "ssao", "light", "sun", "fog", "glow", "bloom", "hdr", "exposure", "ambient" } },
  { "Effets", { "particle", "spell", "weather", "projected", "physics", "effect", "ragdoll" } },
  { "Distance", { "lod", "dist", "farclip", "horizon", "cull", "view" } },
  { "Performances", { "fps", "vsync", "latency", "gx", "frame", "gpu", "thread" } },
}

function ns.CatOf(name)
  local m = ns.Meta(name)
  if m and m.cat then return m.cat end
  local l = name:lower()
  for _, rule in ipairs(PATTERNS) do
    for _, pat in ipairs(rule[2]) do
      if l:find(pat, 1, true) then return rule[1] end
    end
  end
  return "Autres (jeu)"
end

function ns.CatName(cat)
  if ns.lang == "en" then return ns.CAT_EN[cat] or cat end
  return cat
end

function ns.Describe(e)
  local m = e.meta
  if m and m.desc then return ns.Pick(m.desc, m.en) end
  if e.help and e.help ~= "" then return e.help end
  return "|cff888888" .. L.noDesc .. "|r"
end

function ns.ValueLabel(meta, value)
  local n = tonumber(value)
  local pair = meta and meta.values and n and meta.values[n]
  if pair then return ns.Pick(pair[1], pair[2]) end
  return tostring(value)
end

----------------------------------------------------------------------
-- Application des valeurs + historique
----------------------------------------------------------------------
local pending = {}

local function Track(name, now)
  local _, default = ns.Info(name)
  if ns.Same(now, default) then ns.db.overrides[name] = nil else ns.db.overrides[name] = now end
end

-- Applique une valeur. batch (optionnel) collecte l'ancienne valeur pour l'annulation.
function ns.SetValue(name, value, batch, silent)
  value = tostring(value)
  if InCombatLockdown() then
    pending[name] = value
    if not silent then ns.Print(L.combatQueued, name) end
    return
  end
  local old = GetCVar(name)
  local ok = pcall(SetCVar, name, value)
  local now = GetCVar(name)
  if not ok or now == nil then
    if not silent then ns.Print(L.failed, name, value) end
    return false
  end
  if not silent and not ns.Same(now, value) then ns.Print(L.adjusted, name, tostring(now)) end
  if batch and old ~= nil and not ns.Same(old, now) then
    batch.changes[#batch.changes + 1] = { name = name, old = old, new = now }
  end
  Track(name, now)

  -- Le préréglage du jeu réécrit les réglages du menu : on oublie nos surcharges graphics*
  if name:lower() == "graphicsquality" then
    for k in pairs(CopyTable(ns.db.overrides)) do
      local l = k:lower()
      if l ~= "graphicsquality" and l:find("^graphics") then ns.db.overrides[k] = nil end
    end
  end

  local m = ns.Meta(name)
  if m and m.restart and not silent then ns.Print(L.needRestart, name) end
  return true, now
end

function ns.NewBatch(label) return { label = label, changes = {}, time = time() } end

function ns.Commit(batch)
  if batch and #batch.changes > 0 then
    table.insert(ns.history, batch)
    if #ns.history > 50 then table.remove(ns.history, 1) end
    return batch
  end
end

function ns.Revert(batch)
  if InCombatLockdown() then return ns.Print(L.inCombat) end
  for i = #batch.changes, 1, -1 do
    local c = batch.changes[i]
    ns.SetValue(c.name, c.old, nil, true)
  end
  for i = #ns.history, 1, -1 do
    if ns.history[i] == batch then table.remove(ns.history, i) break end
  end
  ns.Refresh(true)
end

function ns.Undo()
  local b = ns.history[#ns.history]
  if not b then return ns.Print(L.nothingUndo) end
  ns.Revert(b)
  ns.Print(L.undone, b.label)
end

-- Retour auto de sécurité
local function IsRisky(batch)
  for _, c in ipairs(batch.changes) do
    local m = ns.Meta(c.name)
    if m and m.risky then return true end
  end
end

function ns.MaybeAskKeep(batch, force)
  if not (batch and ns.db.safeRevert and #batch.changes > 0) then return end
  if force or IsRisky(batch) then StaticPopup_Show("FOREVERGFX_KEEP", nil, nil, batch) end
end

-- Changement d'une seule variable depuis l'interface
function ns.ChangeFromUI(name, value)
  local b = ns.NewBatch(name .. " = " .. tostring(value))
  ns.SetValue(name, value, b)
  if ns.Commit(b) then ns.MaybeAskKeep(b, false) end
  ns.state.lastLabel = L.manual
  ns.db.lastLabel = L.manual
  ns.Refresh(true)
end

-- Applique un ensemble complet { {nom, valeur}, ... } en partant d'une base propre
function ns.ApplySet(list, label, fromUI, quiet)
  if InCombatLockdown() then ns.Print(L.inCombat) return false end
  local b = ns.NewBatch(label)
  local inSet = {}
  for _, p in ipairs(list) do inSet[p[1]:lower()] = true end
  for name in pairs(CopyTable(ns.db.overrides)) do
    if not inSet[name:lower()] then
      local _, default = ns.Info(name)
      if default ~= nil then ns.SetValue(name, default, b, true) end
    end
  end
  local applied, skipped = 0, 0
  for _, p in ipairs(list) do
    if ns.Info(p[1]) ~= nil then
      ns.SetValue(p[1], p[2], b, true)
      applied = applied + 1
    else
      skipped = skipped + 1
    end
  end
  ns.Commit(b)
  ns.state.lastLabel = label
  ns.db.lastLabel = label
  if not quiet then
    ns.Print(L.applied, label, applied, skipped > 0 and string.format(L.missing, skipped) or "")
  end
  if fromUI then ns.MaybeAskKeep(b, true) end
  ns.Refresh(true)
  return true
end

function ns.ResetAll()
  if InCombatLockdown() then return ns.Print(L.inCombat) end
  local b = ns.NewBatch(L.resetAll)
  for name in pairs(CopyTable(ns.db.overrides)) do
    local _, default = ns.Info(name)
    if default ~= nil then ns.SetValue(name, default, b, true) end
  end
  wipe(ns.db.overrides)
  ns.Commit(b)
  ns.Print(L.resetDone)
  ns.Refresh(true)
end

----------------------------------------------------------------------
-- Préréglages et profils
----------------------------------------------------------------------
function ns.PresetLabel(p) return ns.Pick(p.label, p.label_en) end

function ns.PresetByKey(key)
  key = key and key:lower()
  for _, p in ipairs(ns.Presets or {}) do
    if p.key == key or p.label:lower() == key or (p.label_en and p.label_en:lower() == key) then return p end
  end
end

function ns.ApplyPreset(p, fromUI)
  return ns.ApplySet(p.values, string.format(L.presetPrefix, ns.PresetLabel(p)), fromUI)
end

function ns.ProfileNames()
  local names = {}
  for k in pairs(ns.db.profiles) do names[#names + 1] = k end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

-- Profil (table nom -> valeur) vers liste ordonnée, graphicsQuality en premier
function ns.ProfileList(map)
  local list = {}
  for k, v in pairs(map) do
    if k:lower() == "graphicsquality" then list[#list + 1] = { k, v } end
  end
  for k, v in pairs(map) do
    if k:lower() ~= "graphicsquality" then list[#list + 1] = { k, v } end
  end
  return list
end

function ns.SaveProfile(name)
  if not name or name == "" then return ns.Print(L.noProfileName) end
  ns.db.profiles[name] = CopyTable(ns.db.overrides)
  ns.Print(L.profileSaved, name)
end

function ns.LoadProfile(name, fromUI)
  local p = name and ns.db.profiles[name]
  if not p then return ns.Print(L.unknownProfile, tostring(name)) end
  return ns.ApplySet(ns.ProfileList(p), string.format(L.profilePrefix, name), fromUI)
end

function ns.DeleteProfile(name)
  if not (name and ns.db.profiles[name]) then return ns.Print(L.unknownProfile, tostring(name)) end
  ns.db.profiles[name] = nil
  ns.Print(L.profileDeleted, name)
end

-- Cibles utilisées par la bascule auto : "preset:clé" ou "profile:nom"
function ns.ResolveTarget(t)
  if not t or t == "" then return end
  local kind, id = t:match("^(%a+):(.+)$")
  if kind == "preset" then
    local p = ns.PresetByKey(id)
    if p then return p.values, string.format(L.presetPrefix, ns.PresetLabel(p)) end
  elseif kind == "profile" then
    local m = ns.db.profiles[id]
    if m then return ns.ProfileList(m), string.format(L.profilePrefix, id) end
  end
end

function ns.TargetLabel(t)
  local _, label = ns.ResolveTarget(t)
  return label or L.ctxNone
end

----------------------------------------------------------------------
-- Export / import / comparaison
----------------------------------------------------------------------
function ns.Export(map)
  local keys = {}
  for k in pairs(map) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return a:lower() < b:lower() end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(map[k]) end
  return "FGFX1:" .. table.concat(parts, ";")
end

function ns.Import(text)
  text = (text or ""):gsub("%s+", "")
  local body = text:match("^FGFX1:(.*)$")
  if not body then return nil end
  local map, n = {}, 0
  for pair in body:gmatch("[^;]+") do
    local k, v = pair:match("^([%w_]+)=(.+)$")
    if k then map[k] = v; n = n + 1 end
  end
  return map, n
end

-- Lignes « nom : actuel » cible » pour ce qui diffère
function ns.Compare(map)
  local names, seen = {}, {}
  local function add(k) if not seen[k:lower()] then seen[k:lower()] = true; names[#names + 1] = k end end
  for k in pairs(map) do add(k) end
  for k in pairs(ns.db.overrides) do add(k) end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  local lines = {}
  for _, k in ipairs(names) do
    local cur, default = ns.Info(k)
    if cur ~= nil then
      local target = map[k] or default
      if not ns.Same(cur, target) then
        lines[#lines + 1] = string.format("%s : %s » %s", k, tostring(cur), tostring(target))
      end
    end
  end
  return lines
end

----------------------------------------------------------------------
-- Bascule automatique selon le contexte
----------------------------------------------------------------------
ns.CONTEXTS = { "world", "city", "dungeon", "raid", "pvp" }

function ns.GetContext()
  local inInstance, kind = IsInInstance()
  if inInstance then
    if kind == "raid" then return "raid" end
    if kind == "pvp" or kind == "arena" then return "pvp" end
    return "dungeon"
  end
  if IsResting() then return "city" end
  return "world"
end

local lastCtx
function ns.CheckContext(force)
  local c = ns.db and ns.db.context
  if not (c and c.enabled) then lastCtx = nil return end
  if InCombatLockdown() then ns.ctxPending = true return end
  local ctx = ns.GetContext()
  if ctx == lastCtx and not force then return end
  lastCtx = ctx
  local list, label = ns.ResolveTarget(c.map[ctx])
  if list then
    ns.ApplySet(list, label, false, true)
    ns.Print(L.ctxSwitched, L["ctx_" .. ctx], label)
  end
end

----------------------------------------------------------------------
-- Mesure de FPS
----------------------------------------------------------------------
local bench = { running = false }
ns.bench = bench
local benchFrame = CreateFrame("Frame")
benchFrame:Hide()

local function FinishBench()
  bench.running = false
  benchFrame:Hide()
  local times, n = bench.times, #bench.times
  local cb = bench.callback
  bench.callback = nil
  if n < 10 then
    if cb then cb(nil) end
    ns.OnBench()
    return
  end
  local sorted = CopyTable(times)
  table.sort(sorted, function(a, b) return a > b end)
  local k = math.max(1, math.floor(n * 0.01))
  local sum = 0
  for i = 1, k do sum = sum + sorted[i] end
  local r = {
    label = ns.state.lastLabel or L.manual,
    avg = n / bench.elapsed,
    low = k / sum,
    min = 1 / sorted[1],
    zone = GetRealZoneText() or "?",
    time = date("%d/%m %H:%M"),
  }
  if cb then
    cb(r)
    ns.OnBench()
    return
  end
  table.insert(ns.db.bench, 1, r)
  while #ns.db.bench > 20 do table.remove(ns.db.bench) end
  ns.Print(L.benchResult, r.label, r.avg, r.low, r.min, r.zone)
  ns.OnBench()
  ns.ShowBenchResults()
end

benchFrame:SetScript("OnUpdate", function(_, elapsed)
  if bench.warm > 0 then bench.warm = bench.warm - elapsed return end
  bench.elapsed = bench.elapsed + elapsed
  bench.times[#bench.times + 1] = elapsed
  local left = math.max(0, math.ceil(bench.duration - bench.elapsed))
  if left ~= bench.left then bench.left = left; ns.OnBench() end
  if bench.elapsed >= bench.duration then FinishBench() end
end)

-- Mesure interne silencieuse : rappelle cb(résultat) à la fin
function ns.Measure(duration, warm, cb)
  if bench.running then return false end
  bench.running, bench.duration, bench.elapsed = true, duration, 0
  bench.warm, bench.times, bench.left, bench.callback = warm or 2, {}, duration, cb
  benchFrame:Show()
  ns.OnBench()
  return true
end

function ns.MeasureCancel()
  bench.running, bench.callback = false, nil
  benchFrame:Hide()
  ns.OnBench()
end

function ns.BenchToggle(duration)
  if ns.tuner and ns.tuner.running then return ns.Print(L.tuneBusy) end
  if bench.running then
    bench.running = false
    benchFrame:Hide()
    ns.Print(L.benchCancel)
    ns.OnBench()
    return
  end
  duration = math.max(5, math.min(120, tonumber(duration) or 30))
  bench.running, bench.duration, bench.elapsed = true, duration, 0
  bench.warm, bench.times, bench.left = 2, {}, duration
  benchFrame:Show()
  ns.Print(L.benchStart, duration)
  ns.OnBench()
end


----------------------------------------------------------------------
-- Réglage automatique : garde le plus beau niveau qui atteint l'objectif
----------------------------------------------------------------------
local TUNE_ORDER = { "ultra", "qualite", "equilibre", "perf" }
ns.TUNE_STEPS = #TUNE_ORDER
ns.tuner = { running = false }

function ns.TunerStart(target)
  local t = ns.tuner
  if t.running then
    t.running = false
    ns.MeasureCancel()
    ns.Print(L.tuneCancel)
    ns.Refresh(true)
    return
  end
  if bench.running then return ns.Print(L.tuneBusy) end
  if InCombatLockdown() then return ns.Print(L.inCombat) end
  target = tonumber(target) or 60
  t.running, t.target, t.step = true, target, 0
  ns.Print(L.tuneStart, target)

  local Finish
  local function NextStep()
    if not t.running then return end
    if InCombatLockdown() then
      t.running = false
      ns.Print(L.tuneCombat)
      ns.Refresh(true)
      return
    end
    t.step = t.step + 1
    local p = ns.PresetByKey(TUNE_ORDER[t.step] or "")
    if not p then return Finish(nil) end
    ns.ApplySet(p.values, string.format(L.presetPrefix, ns.PresetLabel(p)), false, true)
    ns.Measure(12, 3, function(r)
      if not t.running then return end
      if r then ns.Print(L.tuneStep, ns.PresetLabel(p), r.avg, r.low) end
      if r and r.avg >= t.target and r.low >= t.target * 0.6 then Finish(p) else NextStep() end
    end)
  end

  function Finish(p)
    t.running = false
    if p then
      ns.Print(L.tuneDone, ns.PresetLabel(p))
    else
      local perf = ns.PresetByKey("perf")
      if perf then ns.ApplySet(perf.values, string.format(L.presetPrefix, ns.PresetLabel(perf)), false, true) end
      ns.Print(L.tuneNone)
    end
    ns.Refresh(true)
    ns.OnBench()
  end

  NextStep()
end

----------------------------------------------------------------------
-- Fenêtres de confirmation (créées après le choix de la langue)
----------------------------------------------------------------------
local function InitPopups()
  StaticPopupDialogs["FOREVERGFX_KEEP"] = {
    text = L.keepConfirm, button1 = L.keep, button2 = L.revert,
    OnAccept = function() end,
    OnCancel = function(_, data)
      if data then ns.Revert(data); ns.Print(L.reverted) end
    end,
    timeout = 15, whileDead = true, hideOnEscape = false, showAlert = true,
  }
  StaticPopupDialogs["FOREVERGFX_RESET"] = {
    text = L.resetConfirm, button1 = YES, button2 = NO,
    OnAccept = function() ns.ResetAll() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopupDialogs["FOREVERGFX_PRESET"] = {
    text = L.presetConfirm, button1 = YES, button2 = NO,
    OnAccept = function(_, data) ns.ApplyPreset(data, true) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopupDialogs["FOREVERGFX_OVERWRITE"] = {
    text = L.overwriteConfirm, button1 = YES, button2 = NO,
    OnAccept = function(_, data) ns.SaveProfile(data) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopupDialogs["FOREVERGFX_DELPROFILE"] = {
    text = L.deleteConfirm, button1 = YES, button2 = NO,
    OnAccept = function(_, data) ns.DeleteProfile(data); ns.Refresh(true) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
end


----------------------------------------------------------------------
-- LibDataBroker / LibDBIcon (facultatif, fournis par d'autres addons)
----------------------------------------------------------------------
function ns.SetupBroker()
  local LS = _G.LibStub
  local LDB = LS and LS("LibDataBroker-1.1", true)
  if not LDB then return end
  local obj = LDB:NewDataObject("ForeverGFX", {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
    OnClick = function(_, button)
      if button == "RightButton" then ns.BenchToggle() else ns.ToggleUI() end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("ForeverGFX", 1, 0.82, 0)
      tt:AddLine(L.minimapTip1, 1, 1, 1)
      tt:AddLine(L.minimapTip2, 1, 1, 1)
    end,
  })
  local DBI = LS("LibDBIcon-1.0", true)
  if obj and DBI then
    ns.db.ldbIcon = ns.db.ldbIcon or { hide = ns.db.minimap.hide }
    DBI:Register("ForeverGFX", obj, ns.db.ldbIcon)
    ns.dbi = DBI
    if ns.HideOwnMinimapButton then ns.HideOwnMinimapButton() end
    ns.minimapButton = DBI.GetMinimapButton and DBI:GetMinimapButton("ForeverGFX") or ns.minimapButton
  end
end

----------------------------------------------------------------------
-- Commandes
----------------------------------------------------------------------
SLASH_FOREVERGFX1 = "/gfx"
SLASH_FOREVERGFX2 = "/forevergfx"
SlashCmdList.FOREVERGFX = function(msg)
  local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ns.ToggleUI()
  elseif cmd == "diag" then
    ns.ShowDiag()
  elseif cmd == "preset" then
    local p = ns.PresetByKey(arg)
    if p then ns.ApplyPreset(p, false)
    else
      local keys = {}
      for _, q in ipairs(ns.Presets) do keys[#keys + 1] = q.key end
      ns.Print(L.presetList, table.concat(keys, ", "))
    end
  elseif cmd == "save" and arg ~= "" then
    ns.SaveProfile(arg)
  elseif cmd == "load" and arg ~= "" then
    ns.LoadProfile(arg, false)
  elseif cmd == "del" and arg ~= "" then
    ns.DeleteProfile(arg)
  elseif cmd == "list" then
    local names = ns.ProfileNames()
    ns.Print(L.profiles, #names > 0 and table.concat(names, ", ") or L.none)
  elseif cmd == "tuto" or cmd == "tutorial" then
    if not (ns.mainFrame and ns.mainFrame:IsShown()) then ns.ToggleUI() end
    ns.db.expert = false
    if ns.ApplyView then ns.ApplyView() end
    ns.RunTour()
  elseif cmd == "expert" then
    ns.db.expert = not ns.db.expert
    if ns.ApplyView then ns.ApplyView() end
  elseif cmd == "undo" then
    ns.Undo()
  elseif cmd == "bench" then
    ns.BenchToggle(arg)
  elseif cmd == "auto" then
    ns.ShowContext()
  elseif cmd == "fps" then
    ns.db.overlay = not ns.db.overlay
    ns.UpdateOverlay()
  elseif cmd == "tune" then
    ns.TunerStart(arg)
  elseif cmd == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    if ns.dbi then
      ns.db.ldbIcon.hide = ns.db.minimap.hide
      if ns.db.minimap.hide then ns.dbi:Hide("ForeverGFX") else ns.dbi:Show("ForeverGFX") end
    end
    ns.UpdateMinimapButton()
    ns.Print(ns.db.minimap.hide and L.minimapHidden or L.minimapShown)
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then
    ns.db.lang = arg
    ns.Print(L.langSet, arg)
  else
    ns.Print(L.help)
  end
end

-- Compartiment des addons
function ForeverGFX_OnCompartmentClick(_, button)
  if button == "RightButton" then ns.BenchToggle() else ns.ToggleUI() end
end

----------------------------------------------------------------------
-- Événements
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_UPDATE_RESTING")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "ADDON_LOADED" and a1 == ADDON then
    ForeverGFXDB = ForeverGFXDB or {}
    local db = ForeverGFXDB
    ns.db = db
    db.overrides = db.overrides or {}
    db.profiles = db.profiles or {}
    db.favorites = db.favorites or {}
    db.bench = db.bench or {}
    db.context = db.context or { enabled = false, map = {} }
    db.context.map = db.context.map or {}
    db.minimap = db.minimap or { angle = 215, hide = false }
    if db.reapply == nil then db.reapply = true end
    if db.safeRevert == nil then db.safeRevert = true end
    if db.collapsed == nil then db.collapsed = { ["Autres (jeu)"] = true } end
    -- Version des données sauvegardées (pour de futures migrations)
    db.version = db.version or 2
    if db.lang then ns.lang = db.lang end
    ns.state.lastLabel = db.lastLabel
    InitPopups()
    if ns.InitUI then ns.InitUI() end
    if ns.UpdateOverlay then ns.UpdateOverlay() end

  elseif event == "PLAYER_LOGIN" then
    ns.SetupBroker()

  elseif event == "PLAYER_ENTERING_WORLD" then
    if not ns.db then return end
    if (a1 or a2) and ns.db.reapply then
      local n = 0
      for name, value in pairs(CopyTable(ns.db.overrides)) do
        if ns.Info(name) ~= nil then ns.SetValue(name, value, nil, true); n = n + 1 end
      end
      if n > 0 then ns.Print(L.reappliedN, n) end
    end
    ns.CheckContext(a1 or a2)

  elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UPDATE_RESTING" then
    if ns.db then ns.CheckContext() end

  elseif event == "PLAYER_REGEN_ENABLED" then
    for name, value in pairs(pending) do ns.SetValue(name, value, nil, true) end
    wipe(pending)
    if ns.ctxPending then ns.ctxPending = false; ns.CheckContext() end
    ns.Refresh(true)
  end
end)

----------------------------------------------------------------------
-- Diagnostic (/gfx diag) : valeurs réelles des variables du client, pour adapter l'addon à WoW Forever
----------------------------------------------------------------------
local GFX_KEYWORDS = { "graphics", "shadow", "raytrac", "ssao", "texture", "particle", "liquid", "light", "fsr", "dlss", "xess",
                       "render", "vrs", "msaa", "aa", "projected", "weather", "sunshaft", "fog", "farclip", "lod", "density",
                       "spell", "ssr", "reflection", "volumetric", "outline", "resample", "sharpen", "vsync", "maxfps", "contrast",
                       "brightness", "gamma" }
function ns.DiagCollect(add)
  local names = {}
  for k in pairs(ns.Descriptions) do names[#names + 1] = k end
  table.sort(names)
  local CVa = C_CVar or {}
  local missing = {}
  add("")
  add("## Variables gérées par ForeverGFX (" .. #names .. ")")
  for _, n in ipairs(names) do
    local v = ns.GetCVar(n)
    if v == nil then
      missing[#missing + 1] = n
    else
      local def = CVa.GetCVarDefault and CVa.GetCVarDefault(n)
      add(n .. " = " .. tostring(v) .. (def and (" (défaut " .. tostring(def) .. ")") or ""))
    end
  end
  add("Absentes de ce client : " .. (#missing > 0 and table.concat(missing, ", ") or "aucune"))
  if ConsoleGetAllCommands then
    local known = {}
    for _, n in ipairs(names) do known[n:lower()] = true end
    local cvarType = (Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar) or 0
    local extra = {}
    for _, c in ipairs(ConsoleGetAllCommands()) do
      local n = c.command
      if n and not known[n:lower()] and (c.commandType == nil or c.commandType == cvarType) then
        local l = n:lower()
        local hit = l:sub(1, 2) == "gx" or l:sub(1, 2) == "rt"
        for _, kw in ipairs(GFX_KEYWORDS) do if l:find(kw, 1, true) then hit = true break end end
        if hit then
          local v = ns.GetCVar(n)
          if v ~= nil then extra[#extra + 1] = n .. " = " .. tostring(v) end
        end
      end
    end
    table.sort(extra)
    add("")
    add("## Variables graphiques du client non gérées par ForeverGFX (" .. #extra .. ")")
    for _, e in ipairs(extra) do add(e) end
  end
  add("")
  add(string.format("FPS actuel : %.0f", GetFramerate()))
end
