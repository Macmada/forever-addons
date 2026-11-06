local _, root = ...
local G = root.Game

-- HealBot Continued configuré pour le prêtre, avec les fonctions d'HealBot lui-même (aucun fichier d'HealBot n'est
-- modifié ni copié) :
--  * clics : chaque clic reçoit le bon sort d'après les sorts connus (« Soins » sans rang = rang le plus haut, donc rien
--    à refaire à chaque nouveau rang) ; à chaque nouveau sort (Soins rapides, Dissipation…), les clics que tu n'as pas
--    changés toi-même sont mis à jour ;
--  * cadres : deux skins importés par la fonction d'import d'HealBot, « Forever Groupe » (seul et en groupe) et
--    « Forever Raid » (raid de 10 à 40), tirés de ses skins « Groupe » et « Raid 40 » avec des réglages de soigneur
--    (vie manquante affichée, rôles, tri par groupe puis rôle, alerte à 90 %) ;
--  * sauvegarde : les clics et le choix des skins d'avant sont gardés ; « /fp healbot annuler » les remet.

local HB = {}
root.HealBot = HB

local FR = root.FR
local T = FR and {
  notLoaded = "HealBot n'est pas chargé : active-le dans l'onglet Addons (puis /reload).",
  combat = "En combat : HealBot sera configuré à la fin du combat.",
  notPriest = "La configuration automatique d'HealBot est prévue pour le prêtre.",
  done = "HealBot configuré : %d clic(s) réglé(s), skins « Forever Groupe » et « Forever Raid ». Annuler : /fp healbot annuler",
  skinFail = "Skins HealBot : import impossible (%s skin introuvable).",
  doneClicks = "HealBot : %d clic(s) réglé(s). Annuler : /fp healbot annuler",
  updated = "HealBot : %s sur %s (nouveau sort).",
  restored = "HealBot : clics et skins d'avant remis.",
  noBackup = "HealBot : aucune sauvegarde à remettre.",
  planTitle = "Clics HealBot prévus à ton niveau :",
  kept = "%s : laissé tel quel (changé par toi)",
  deficitOn = "HealBot : vie manquante affichée en rouge sur les barres.", deficitOff = "HealBot : vie manquante masquée.",
  button = "Configurer HealBot", buttonTip = "Règle les clics de soins et les cadres de groupe/raid d'HealBot pour ton prêtre (sauvegarde avant, /fp healbot annuler).",
  Left = "Clic gauche", Right = "Clic droit", Middle = "Clic milieu", Shift = "Maj+", Ctrl = "Ctrl+", Alt = "Alt+",
} or {
  notLoaded = "HealBot is not loaded: enable it in the Addons tab (then /reload).",
  combat = "In combat: HealBot will be set up after the fight.",
  notPriest = "The automatic HealBot setup is made for priests.",
  done = "HealBot set up: %d click(s), skins \"Forever Groupe\" and \"Forever Raid\". Undo: /fp healbot annuler",
  skinFail = "HealBot skins: import failed (%s skin not found).",
  doneClicks = "HealBot: %d click(s) set. Undo: /fp healbot annuler",
  updated = "HealBot: %s on %s (new spell).",
  restored = "HealBot: previous clicks and skins restored.",
  noBackup = "HealBot: no backup to restore.",
  planTitle = "HealBot clicks planned at your level:",
  kept = "%s: left as is (changed by you)",
  deficitOn = "HealBot: missing health shown in red on the bars.", deficitOff = "HealBot: missing health hidden.",
  button = "Set up HealBot", buttonTip = "Sets HealBot's healing clicks and party/raid frames for your priest (backup first, /fp healbot annuler).",
  Left = "Left click", Right = "Right click", Middle = "Middle click", Shift = "Shift+", Ctrl = "Ctrl+", Alt = "Alt+",
}
HB.T = T

HB.SKIN_GROUP, HB.SKIN_RAID = "Forever Groupe", "Forever Raid"

-- Sorts du prêtre : numéro du rang 1 (un rang appris reste connu, le rang 1 suffit pour savoir si le sort l'est)
local S = {
  lesser = 2050, heal = 2054, greater = 2060, flash = 2061, renew = 139, shield = 17, prayer = 596,
  cure = 528, abolish = 552, dispel = 527, rez = 2006, fort = 1243,
}
HB.SPELLS = S
local LESSER_RANKS = { 2050, 2052, 2053 }

local function Known(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local ok, v = pcall(C_SpellBook.IsSpellKnown, id)
    if ok and v then return true end
  end
  return IsSpellKnown and IsSpellKnown(id) or false
end
HB.Known = Known

local function Name(id) return G.SpellName(id) end

-- Nom avec rang au format d'HealBot, « Soins inférieurs(Rang 2) »
local function RankedName(id)
  local name = Name(id)
  local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id) or (GetSpellSubtext and GetSpellSubtext(id))
  if name and sub and sub ~= "" then return name .. "(" .. sub .. ")" end
end

-- Clics prévus : { combo HealBot (« ShiftLeft »), nom à donner à HealBot, repli si HealBot ne connaît pas ce nom }
function HB.Plan()
  local out = {}
  local function add(combo, text, fallback) if text then out[#out + 1] = { combo = combo, text = text, fallback = fallback } end end
  -- gros soin efficace au clic gauche ; soin rapide (ou petit rang moins cher) en Maj+gauche
  local main = (Known(S.greater) and "greater") or (Known(S.heal) and "heal") or (Known(S.lesser) and "lesser")
  if main then add("Left", Name(S[main])) end
  if Known(S.flash) then add("ShiftLeft", Name(S.flash))
  elseif main == "heal" then add("ShiftLeft", Name(S.lesser))
  elseif main == "lesser" then
    local best
    for i = #LESSER_RANKS, 1, -1 do if Known(LESSER_RANKS[i]) then best = i; break end end
    if best and best > 1 then add("ShiftLeft", RankedName(LESSER_RANKS[best - 1]), nil) end
  end
  if Known(S.rez) then add("CtrlLeft", Name(S.rez)) end
  if Known(S.fort) then add("AltLeft", Name(S.fort)) end
  if Known(S.renew) then add("Right", Name(S.renew)) end
  if Known(S.shield) then add("ShiftRight", Name(S.shield)) end
  if Known(S.prayer) then add("CtrlRight", Name(S.prayer)) end
  if Known(S.abolish) then add("Middle", Name(S.abolish)) elseif Known(S.cure) then add("Middle", Name(S.cure)) end
  if Known(S.dispel) then add("ShiftMiddle", Name(S.dispel)) end
  return out
end

-- « ShiftLeft » -> « Maj+Clic gauche »
function HB.ComboLabel(combo)
  local mods, button = combo:match("^(%a-)(Left)$")
  if not button then mods, button = combo:match("^(%a-)(Right)$") end
  if not button then mods, button = combo:match("^(%a-)(Middle)$") end
  return (mods and T[mods] or "") .. (T[button] or combo)
end

function HB.Available()
  return type(_G.HealBot_Action_SetSpell) == "function" and type(_G.HealBot_Config_Spells) == "table"
         and type(_G.HealBot_Config_Spells.EnabledKeyCombo) == "table"
end

local function Copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = Copy(v) end
  return c
end

local function Store()
  root.db.healbot = root.db.healbot or {}
  local key = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
  root.db.healbot[key] = root.db.healbot[key] or {}
  return root.db.healbot[key]
end
HB.Store = Store

-- Demande à HealBot de relire ses clics (comme après un import de sorts)
local function Refresh()
  if type(_G.HealBot_Options_SaveSpellsProfile) == "function" then pcall(_G.HealBot_Options_SaveSpellsProfile, "SPELLS") end
  if type(_G.HealBot_Timers_Set) == "function" then
    pcall(_G.HealBot_Timers_Set, "INIT", "SpellsTabText")
    pcall(_G.HealBot_Timers_Set, "INIT", "PrepSetAllAttribs")
  end
end

-- Pose un clic ; vrai si HealBot a reconnu le sort (« S:numéro^nom »)
local function SetOne(combo, text)
  pcall(_G.HealBot_Action_SetSpell, "ENABLED", combo, text)
  local v = _G.HealBot_Config_Spells.EnabledKeyCombo[combo]
  return type(v) == "string" and v:sub(1, 2) == "S:"
end

-- Applique les clics prévus. onlyMine : ne touche qu'aux clics posés par nous et pas changés depuis (mise à jour).
local function ApplyClicks(onlyMine)
  local st = Store()
  st.set = st.set or {}
  local combos = _G.HealBot_Config_Spells.EnabledKeyCombo
  local n, changes = 0, {}
  for _, p in ipairs(HB.Plan()) do
    local current = combos[p.combo]
    local mine = st.set[p.combo] ~= nil and current == st.set[p.combo]
    if not onlyMine or mine or current == nil then
      local function Is(text) return type(current) == "string" and current:match("^S:%d+%^(.*)$") == text end
      if Is(p.text) then
        st.set[p.combo] = current
        n = n + 1
      else
        local wanted = p.text
        local ok = SetOne(p.combo, wanted)
        if not ok and p.fallback then wanted = p.fallback; ok = SetOne(p.combo, wanted) end
        if ok then
          changes[#changes + 1] = { combo = p.combo, text = wanted }
          st.set[p.combo] = combos[p.combo]
          n = n + 1
        else
          combos[p.combo] = current                                -- sort inconnu d'HealBot : on remet l'ancien
        end
      end
    end
  end
  Refresh()
  return n, changes
end

-- Skin tiré d'un skin intégré d'HealBot (texte d'import), réglages remplacés : edits[ligne] = { clé = valeur }
local function Val(v) return type(v) == "string" and ('"' .. v .. '"') or tostring(v) end
local function Patch(text, newName, edits)
  local lines, i = {}, 0
  for l in text:gmatch("[^\n]+") do
    i = i + 1
    if i == 2 then l = newName
    else
      local cmd, body = l:match("^([^!]+)!(%b{})%s*$")
      local e = cmd and edits[cmd]
      if e then
        local pairsOut, seen = {}, {}
        for item in body:sub(2, -2):gmatch("[^,]+") do
          local k = item:match("^([^=]+)=")
          if k and e[k] ~= nil then item = k .. "=" .. Val(e[k]); seen[k] = true end
          pairsOut[#pairsOut + 1] = item
        end
        local extra = {}
        for k in pairs(e) do if not seen[k] then extra[#extra + 1] = k end end
        table.sort(extra)
        for _, k in ipairs(extra) do pairsOut[#pairsOut + 1] = k .. "=" .. Val(e[k]) end
        l = cmd .. "!{" .. table.concat(pairsOut, ",") .. "}"
      end
    end
    lines[#lines + 1] = l
  end
  return table.concat(lines, "\n")
end
HB.Patch = Patch

-- Réglages communs aux deux skins. Sur Forever, la vie des alliés est secrète : HealBot n'affiche que la vie actuelle ou
-- le pourcentage (pas la vie manquante), et le texte de vie était coupé dans ses skins d'origine (HLTHONBAR).
local GOLD = { R = 1, G = 0.82, B = 0.35 }
local COMMON = {
  ["BarText~f~1"] = { HLTHONBAR = "true", HLTHTYPE = 3, IGNOREONFULL = "true", SHOWROLE = "true",          -- vie en %
                      FONT = "Roboto Bold", HEIGHT = 12, OUTLINE = 2, HFONT = "Roboto Bold", HHEIGHT = 11, HOUTLINE = 2 },
  ["BarSort~f~1"] = { RAIDORDER = 3, SUBORDER = 5, SUBPF = "true" },                              -- par groupe, puis rôle
  ["BarVisibility~f~1"] = { ALERTIC = 0.9, ALERTOC = 0.8 },                                       -- alerte sous 90 % en combat
  ["Icons~f~1"] = { SHOWCLASS = "true", SHOWROLE = "true" },        -- icône de rôle (HealBot la met à la place de celle de classe)
  ["General~t"] = { HIDEPARTYF = "false", HIDERAIDF = "false" },     -- cadres de Blizzard gardés (secours si HealBot plante)
  -- habillage : barres lisses, fond sombre, liseré doré et titre du cadre, comme les fenêtres de ForeverCompagnon
  ["BarCol~f~1"] = { HA = 0.95, BA = 0.85, BR = 0.06, BG = 0.06, BB = 0.08 },
  ["Frame~f~1"] = { BACKR = 0.03, BACKG = 0.03, BACKB = 0.05, BACKA = 0.75, BORDERR = GOLD.R, BORDERG = GOLD.G, BORDERB = GOLD.B,
                    BORDERA = 0.7, PADDING = 3 },
  ["HeadBar~f~1"] = { SHOW = "true", TEXTURE = "Smooth v2", HEIGHT = 18, WIDTH = 1, R = 0.18, G = 0.13, B = 0.05, A = 0.9 },
  ["HeadText~f~1"] = { FONT = "Roboto Bold", HEIGHT = 11, OUTLINE = 2, R = GOLD.R, G = GOLD.G, B = GOLD.B, A = 1 },
}
local function With(extra)
  local t = {}
  for k, v in pairs(COMMON) do t[k] = v end
  for k, v in pairs(extra) do t[k] = v end
  return t
end
HB.SKINS = {
  { name = HB.SKIN_GROUP, from = "Group", edits = With({ ["HealBar~f~1"] = { WIDTH = 130, HEIGHT = 38, TEXTURE = "Smooth v2", CMARGIN = 3, RMARGIN = 3 },
                     -- pas de familiers : HealBot Tooltips plante sur eux (un familier n'a pas de classe sur Forever)
                     ["HealGroups~f~8"] = { STATE = "false" } }),
    flags = { "HEALBOT_WORD_SOLO", "HEALBOT_WORD_PARTY" } },
  { name = HB.SKIN_RAID, from = "Raid 40", edits = With({ ["HealBar~f~1"] = { WIDTH = 90, HEIGHT = 32, GRPCOLS = "true", TEXTURE = "Smooth v2", CMARGIN = 2, RMARGIN = 2 },
                                                                          ["HealGroups~f~8"] = { STATE = "false" } }),
    flags = { "HEALBOT_OPTIONS_RAID10", "HEALBOT_OPTIONS_RAID15", "HEALBOT_OPTIONS_RAID20", "HEALBOT_OPTIONS_RAID25", "HEALBOT_OPTIONS_RAID40" } },
}

local function Decompress(s)
  local f = _G.HealBot_Util_Decompress
  if type(f) ~= "function" then return nil end
  local ok, out = pcall(f, s)
  if not (ok and out) then ok, out = pcall(f, s) end           -- 1er appel : HealBot charge sa bibliothèque et ne rend rien
  return ok and out or nil
end

local function ApplySkins()
  local data, load = _G.HealBot_Config_SkinsData, _G.HealBot_Share_SkinLoad
  if type(data) ~= "table" or type(load) ~= "function" or type(_G.HealBot_Config) ~= "table" then return false, "HealBot_Share_SkinLoad" end
  local st = Store()
  local cfg = _G.HealBot_Config
  cfg.SkinDefault = cfg.SkinDefault or {}
  if not st.skinDefault then st.skinDefault = Copy(cfg.SkinDefault) end
  if not st.skin and _G.Healbot_Config_Skins then st.skin = _G.Healbot_Config_Skins.Current_Skin end
  -- skins intégrés d'HealBot, retrouvés par le nom écrit dans leurs données (« Group », « Raid 40 ») : HealBot les range
  -- sous le nom anglais au chargement, puis la traduction renomme ses variables (« Groupe » en français)
  local byName = {}
  for _, packed in pairs(data) do
    local text = type(packed) == "string" and Decompress(packed)
    local n = text and text:match("^[^\n]+\n([^\n]+)")
    if n then byName[n] = text end
  end
  for _, s in ipairs(HB.SKINS) do
    local text = byName[s.from]
    if not text then return false, s.from end
    local ok, err = pcall(load, Patch(text, s.name, s.edits), false)
    if not ok then return false, tostring(err) end
    -- ce skin devient celui d'HealBot pour ces situations (les autres skins perdent ce choix)
    for _, f in ipairs(s.flags) do
      local id = _G[f]
      if id then
        for skin, t in pairs(cfg.SkinDefault) do if type(t) == "table" and skin ~= s.name then t[id] = nil end end
        cfg.SkinDefault[s.name] = cfg.SkinDefault[s.name] or {}
        cfg.SkinDefault[s.name][id] = true
      end
    end
  end
  -- familiers retirés par leur nom, après l'import : HealBot renumérote les groupes de barres d'un ancien skin (les
  -- familiers passent de la ligne 8 à la ligne 10), donc un réglage par numéro de ligne vise le mauvais groupe
  HB.NoPets()
  local want = (IsInRaid and IsInRaid()) and HB.SKIN_RAID or HB.SKIN_GROUP
  if type(_G.HealBot_Options_Set_Current_Skin) == "function" then pcall(_G.HealBot_Options_Set_Current_Skin, want) end
  -- cadres de groupe et de raid de WoW gardés en secours, aussi dans le réglage global d'HealBot (s'il prend le pas sur le skin)
  local o = type(_G.HealBot_Globals) == "table" and _G.HealBot_Globals.OverrideFrames
  if type(o) == "table" then o.HIDEPARTYF, o.HIDERAIDF = false, false end
  -- HealBot relit quels cadres de Blizzard masquer (sinon seulement au prochain changement de groupe)
  if type(_G.HealBot_Options_SetFrames) == "function" then pcall(_G.HealBot_Options_SetFrames) end
  if type(_G.HealBot_Timers_ToggleBlizzardFrames) == "function" then pcall(_G.HealBot_Timers_ToggleBlizzardFrames) end
  return true
end

local PETS = { Pets = true, Vehicle = true }
function HB.NoPets()
  local skins = _G.Healbot_Config_Skins
  if type(skins) ~= "table" then return 0 end
  local n = 0
  for _, name in ipairs({ HB.SKIN_GROUP, HB.SKIN_RAID }) do
    local groups = type(skins.HealGroups) == "table" and skins.HealGroups[name]
    if type(groups) == "table" then
      local petName = _G.HEALBOT_OPTIONS_PETHEALS_en
      for _, g in pairs(groups) do
        if type(g) == "table" and (PETS[g.NAME] or (petName and g.NAME == petName)) and g.STATE ~= false then g.STATE = false; n = n + 1 end
      end
    end
    if type(skins.Healing) == "table" then
      skins.Healing[name] = skins.Healing[name] or {}
      skins.Healing[name].GROUPPETS = false
      skins.Healing[name].SELFPET = false
    end
  end
  if type(_G.HealBot_SetResetFlag) == "function" then pcall(_G.HealBot_SetResetFlag, "SOFT") end
  return n
end

-- Ce qu'HealBot a retenu pour le skin actif (groupes de barres, familiers), à copier pour Claude
function HB.Diag()
  local skins = _G.Healbot_Config_Skins
  if type(skins) ~= "table" then root.Print(T.notLoaded); return end
  local cur = skins.Current_Skin
  root.Print("HealBot : skin actif « %s »", tostring(cur))
  local groups = type(skins.HealGroups) == "table" and skins.HealGroups[cur] or {}
  local ids = {}
  for k in pairs(groups) do ids[#ids + 1] = k end
  table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(ids) do
    local g = groups[k]
    if type(g) == "table" then root.Print("  %s : %s, cadre %s, %s", tostring(k), tostring(g.NAME), tostring(g.FRAME), g.STATE and "affiché" or "masqué") end
  end
  local h = type(skins.Healing) == "table" and skins.Healing[cur] or {}
  root.Print("  familiers avec leur maître : %s", tostring(h.GROUPPETS))
end

local pending
function HB.Setup()
  if not HB.Available() then root.Print(T.notLoaded); return false end
  local _, class = UnitClass("player")
  if class ~= "PRIEST" then root.Print(T.notPriest); return false end
  if InCombatLockdown and InCombatLockdown() then pending = true; root.Print(T.combat); return false end
  local st = Store()
  if not st.clicks then st.clicks = Copy(_G.HealBot_Config_Spells.EnabledKeyCombo) end   -- sauvegarde, une seule fois
  local n = ApplyClicks(false)
  local ok, err = ApplySkins()
  st.auto = true
  if ok then root.Print(T.done, n) else root.Print(T.skinFail, err); root.Print(T.doneClicks, n) end
  return true, n
end

-- Nouveau sort appris : met à jour les clics qu'on a posés et que tu n'as pas changés
function HB.Update()
  local st = root.db and root.db.healbot and Store()
  if not (st and st.auto and HB.Available()) then return end
  if InCombatLockdown and InCombatLockdown() then pending = "update"; return end
  local _, changes = ApplyClicks(true)
  for _, c in ipairs(changes) do root.Print(T.updated, c.text, HB.ComboLabel(c.combo)) end
end

function HB.Restore()
  local st = Store()
  if not (st.clicks and HB.Available()) then root.Print(T.noBackup); return false end
  if InCombatLockdown and InCombatLockdown() then root.Print(T.combat); return false end
  wipe(_G.HealBot_Config_Spells.EnabledKeyCombo)
  for k, v in pairs(st.clicks) do _G.HealBot_Config_Spells.EnabledKeyCombo[k] = v end
  if type(_G.HealBot_Action_ClearSpellCache) == "function" then pcall(_G.HealBot_Action_ClearSpellCache) end
  if st.skinDefault and type(_G.HealBot_Config) == "table" then _G.HealBot_Config.SkinDefault = Copy(st.skinDefault) end
  if st.skin and type(_G.HealBot_Options_Set_Current_Skin) == "function" then pcall(_G.HealBot_Options_Set_Current_Skin, st.skin) end
  Refresh()
  local key = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
  root.db.healbot[key] = nil
  root.Print(T.restored)
  return true
end

function HB.ShowPlan()
  root.Print(T.planTitle)
  local st = root.db and root.db.healbot and Store() or {}
  local combos = HB.Available() and _G.HealBot_Config_Spells.EnabledKeyCombo or {}
  for _, p in ipairs(HB.Plan()) do
    local cur = combos[p.combo]
    if st.set and st.set[p.combo] and cur ~= st.set[p.combo] then root.Print("  " .. T.kept, HB.ComboLabel(p.combo))
    else root.Print("  %s : %s", HB.ComboLabel(p.combo), p.text) end
  end
end

function HB.Command(arg)
  arg = (arg or ""):lower()
  if arg == "annuler" or arg == "undo" or arg == "restore" then HB.Restore()
  elseif arg == "voir" or arg == "plan" or arg == "show" then HB.ShowPlan()
  elseif arg == "chiffres" or arg == "numbers" or arg == "vie" then HB.ToggleDeficit()
  elseif arg == "diag" then HB.Diag()
  else HB.Setup() end
end

----------------------------------------------------------------------
-- Vie manquante sur les barres d'HealBot. Sur Forever, la vie des alliés est secrète : HealBot (et nous) ne peut ni la
-- lire ni calculer avec, donc HealBot n'affiche que le pourcentage. Mais le jeu donne la vie manquante toute prête
-- (UnitHealthMissing) et accepte de l'afficher telle quelle (sonde du 06/11/2026, en combat) : on la pose en rouge à
-- droite de chaque barre, sans jamais la lire. TruncateWhenZero (fonction du jeu) rend un texte vide si personne n'a
-- perdu de vie, puisqu'on ne peut pas comparer la valeur à 0 nous-mêmes.
----------------------------------------------------------------------
local function DeficitText(unit)
  local missing = _G.UnitHealthMissing and _G.UnitHealthMissing(unit)
  if missing == nil then return "" end
  local su = _G.C_StringUtil
  if su and su.TruncateWhenZero then
    local ok, t = pcall(su.TruncateWhenZero, missing)
    if ok and t ~= nil then return t end
  end
  if _G.AbbreviateNumbers then
    local ok, t = pcall(_G.AbbreviateNumbers, missing)
    if ok and t ~= nil then return t end
  end
  return missing
end
HB.DeficitText = DeficitText

local function DeficitOn() return HB.Available and type(_G.UnitHealthMissing) == "function" and not (root.db and root.db.healbotDeficit == false) end

local function DeficitButton(button)
  local top = button.gref and (button.gref.Top or button.gref.Bar)
  if not (top and top.CreateFontString) then return end
  local fs = button.fcDeficit
  if not fs then
    fs = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local font = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(font, 12, "OUTLINE")
    fs:SetPoint("RIGHT", button.gref.Bar or top, "RIGHT", -4, 0)
    fs:SetJustifyH("RIGHT")
    fs:SetTextColor(1, 0.38, 0.38)
    button.fcDeficit = fs
  end
  local unit = button.unit
  if not unit or not DeficitOn() then fs:SetText(""); return end
  local ok = pcall(function()
    local connected = _G.UnitIsConnected and _G.UnitIsConnected(unit)
    if connected == false then fs:SetText(""); return end
    fs:SetText(DeficitText(unit))
  end)
  if not ok then pcall(fs.SetText, fs, DeficitText(unit)) end
end

function HB.UpdateDeficits()
  for _, list in ipairs({ _G.HealBot_Unit_Button, _G.HealBot_Private_Button }) do
    if type(list) == "table" then
      for _, button in pairs(list) do
        if type(button) == "table" then pcall(DeficitButton, button) end
      end
    end
  end
end

function HB.ToggleDeficit()
  root.db.healbotDeficit = (root.db.healbotDeficit == false)
  root.Print(root.db.healbotDeficit and T.deficitOn or T.deficitOff)
  HB.UpdateDeficits()
end

if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(0.25, function() if _G.HealBot_Unit_Button then HB.UpdateDeficits() end end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if pending == true then pending = nil; HB.Setup() elseif pending == "update" then pending = nil; HB.Update() end
    return
  end
  C_Timer.After(2, HB.Update)
end)
