local _, root = ...

-- HealBot Continued habillé par ForeverCompagnon, avec les fonctions d'HealBot lui-même (aucun fichier d'HealBot n'est
-- modifié ni copié) : skins « Forever Moderne » (seul et groupe) et « Forever Moderne Raid », vie perdue sur les barres,
-- protection de la prédiction des soins, relevé des réglages. Depuis le 28/11/2026, ForeverCompagnon ne touche plus du
-- tout aux sorts affectés aux clics (demande du joueur) : seule l'apparence change.

local HB = {}
root.HealBot = HB

local FR = root.FR
local T = FR and {
  notLoaded = "HealBot n'est pas chargé : active-le dans l'onglet Addons (puis /reload).",
  combat = "En combat : réessaie à la fin du combat.",
  skinFail = "Skins HealBot : import impossible (%s skin introuvable).",
  noBackup = "HealBot : aucune sauvegarde à remettre.",
  deficitOn = "HealBot : vie manquante affichée en rouge sur les barres.", deficitOff = "HealBot : vie manquante masquée.",
  button = "Configurer HealBot", buttonTip = "Installe les skins « Forever Moderne » (groupe et raid). Les sorts de tes clics ne changent pas. Annuler : /fp healbot annuler",
  modernDone = "HealBot : skins « Forever Moderne » (seul et groupe) et « Forever Moderne Raid » installés, style %s (clics inchangés). Pour les partager : HealBot, Partager, Exporter le skin. Annuler : /fp healbot annuler",
  modernUndone = "HealBot : skins d'avant remis (les skins « Forever Moderne » restent dans la liste d'HealBot).",
  chooseTitle = "Skin HealBot : choisis ton style", chooseNote = "Apparence seulement : les sorts de tes clics ne changent pas.",
  styleA = "A — Liste moderne", styleAD = "une ligne par joueur, débuffs à gauche, buffs à droite",
  styleB = "B — Cartes en ligne", styleBD = "cartes côte à côte, à poser sous ton personnage",
  styleC = "C — Barres fines", styleCD = "le plus épuré : barres fines, petites icônes", current = "(actuel)",
} or {
  notLoaded = "HealBot is not loaded: enable it in the Addons tab (then /reload).",
  combat = "In combat: try again after the fight.",
  skinFail = "HealBot skins: import failed (%s skin not found).",
  noBackup = "HealBot: no backup to restore.",
  deficitOn = "HealBot: missing health shown in red on the bars.", deficitOff = "HealBot: missing health hidden.",
  button = "Set up HealBot", buttonTip = "Installs the \"Forever Moderne\" skins (party and raid). Your click spells don't change. Undo: /fp healbot annuler",
  modernDone = "HealBot: \"Forever Moderne\" (solo and party) and \"Forever Moderne Raid\" skins installed, style %s (clicks unchanged). To share them: HealBot, Share, Export skin. Undo: /fp healbot annuler",
  modernUndone = "HealBot: previous skins restored (the \"Forever Moderne\" skins stay in HealBot's list).",
  chooseTitle = "HealBot skin: pick your style", chooseNote = "Look only: your click spells don't change.",
  styleA = "A — Modern list", styleAD = "one row per player, debuffs left, buffs right",
  styleB = "B — Cards in a row", styleBD = "cards side by side, to place under your character",
  styleC = "C — Thin bars", styleCD = "the cleanest: thin bars, small icons", current = "(current)",
}
HB.T = T

function HB.Available()
  return type(_G.HealBot_Share_SkinLoad) == "function" and type(_G.HealBot_Config) == "table"
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

-- Comme Patch, et un réglage propre à un cadre partagé (« HealBar~f~7 » alors que les cadres 2 à 10 recopient le 1 :
-- « HealBar~d!2~3~…~ ») : le cadre est retiré de la ligne de copie et reçoit sa ligne, faite du cadre 1 modifié
local function PatchFrames(text, newName, edits)
  local out = Patch(text, newName, edits)
  for key, e in pairs(edits) do
    local cmd, n = key:match("^(.-)~f~(%d+)$")
    if cmd and n ~= "1" and not out:find("\n" .. key:gsub("%p", "%%%0") .. "!", 1) then
      local lines = {}
      for l in out:gmatch("[^\n]+") do lines[#lines + 1] = l end
      local base
      for _, l in ipairs(lines) do
        local b = l:match("^" .. cmd:gsub("%p", "%%%0") .. "~f~1!(%b{})%s*$")
        if b then base = b end
      end
      for i, l in ipairs(lines) do
        local list = l:match("^" .. cmd:gsub("%p", "%%%0") .. "~d!(.*)$")
        if base and list and ("~" .. list):find("~" .. n .. "~", 1, true) then
          lines[i] = cmd .. "~d!" .. (("~" .. list):gsub("~" .. n .. "~", "~", 1):sub(2))
          local one = Patch("x\nx\n" .. cmd .. "~f~1!" .. base, "x", { [cmd .. "~f~1"] = e })
          table.insert(lines, i + 1, (one:match("\n(" .. cmd:gsub("%p", "%%%0") .. "~f~1!.*)$"):gsub("~f~1!", "~f~" .. n .. "!", 1)))
          break
        end
      end
      out = table.concat(lines, "\n")
    end
  end
  return out
end
HB.PatchFrames = PatchFrames

local function Decompress(s)
  local f = _G.HealBot_Util_Decompress
  if type(f) ~= "function" then return nil end
  local ok, out = pcall(f, s)
  if not (ok and out) then ok, out = pcall(f, s) end           -- 1er appel : HealBot charge sa bibliothèque et ne rend rien
  return ok and out or nil
end

-- Relevé pour Claude (/fp healbot export) : le texte d'import du skin intégré « Group » d'HealBot (noms exacts des
-- réglages : icônes, barres, groupes) et tous les réglages du skin actif. Sert à écrire un skin sans deviner les noms.
local function Dump(v, depth, out, indent)
  if type(v) ~= "table" then out[#out + 1] = indent .. tostring(v); return end
  if depth > 3 then out[#out + 1] = indent .. "{…}"; return end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local x = v[k]
    if type(x) == "table" then
      out[#out + 1] = indent .. tostring(k) .. " = {"
      Dump(x, depth + 1, out, indent .. "  ")
      out[#out + 1] = indent .. "}"
    elseif type(x) ~= "function" then
      out[#out + 1] = indent .. tostring(k) .. " = " .. tostring(x)
    end
  end
end
function HB.ExportText()
  local out = { "-- HealBot : relevé pour Claude (" .. date("%Y-%m-%d %H:%M") .. ")" }
  local ver = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata and _G.C_AddOns.GetAddOnMetadata("HealBot", "Version")
  out[#out + 1] = "-- version d'HealBot : " .. tostring(ver)
  local data = _G.HealBot_Config_SkinsData
  if type(data) == "table" then
    for _, packed in pairs(data) do
      local text = type(packed) == "string" and Decompress(packed)
      local n = text and text:match("^[^\n]+\n([^\n]+)")
      if n == "Group" then
        out[#out + 1] = "## Skin intégré « Group » (texte d'import)"
        out[#out + 1] = text
      end
    end
  end
  local skins = _G.Healbot_Config_Skins
  if type(skins) == "table" then
    local cur = skins.Current_Skin
    out[#out + 1] = "## Skin actif « " .. tostring(cur) .. " »"
    local cats = {}
    for k, v in pairs(skins) do if type(v) == "table" and v[cur] ~= nil then cats[#cats + 1] = k end end
    table.sort(cats)
    for _, k in ipairs(cats) do
      out[#out + 1] = k .. " = {"
      Dump(skins[k][cur], 1, out, "  ")
      out[#out + 1] = "}"
    end
  end
  return table.concat(out, "\n")
end
function HB.Export()
  if type(_G.Healbot_Config_Skins) ~= "table" then root.Print(T.notLoaded); return end
  root.ShowText("HealBot — relevé pour Claude (Ctrl+A, Ctrl+C)", HB.ExportText())
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

----------------------------------------------------------------------
-- Skin « Forever Moderne » (style A de la maquette, 28/11/2026) : tank, moi, le groupe, puis les familiers en petites
-- barres sous le cadre ; débuffs à gauche, buffs à droite (avec leur durée) ; soins entrants en préremplissage ;
-- fond sombre et liseré doré. Tiré du skin « Group » d'HealBot (noms des réglages relevés par /fp healbot export).
-- NE TOUCHE JAMAIS AUX CLICS (demande du joueur) : seuls le skin et son choix pour « seul » et « groupe » changent.
----------------------------------------------------------------------
HB.SKIN_MODERN = "Forever Moderne"
local GOLDL = { R = 0.94, G = 0.77, B = 0.42 }
HB.MODERN = {
  ["Healing~t"] = { GROUPPETS = "false", SELFPET = "true" },                      -- familiers à part, en bas
  ["General~t"] = { HIDEPARTYF = "false", HIDERAIDF = "false" },
  ["HealGroups~f~1"] = { NAME = "Main tanks", STATE = "true", FRAME = 1 },
  ["HealGroups~f~2"] = { NAME = "Self", STATE = "true", FRAME = 1 },
  ["HealGroups~f~3"] = { NAME = "Raid", STATE = "true", FRAME = 1 },
  ["HealGroups~f~8"] = { NAME = "Pets", STATE = "true", FRAME = 7 },
  ["HealGroups~f~9"] = { STATE = "false" }, ["HealGroups~f~10"] = { STATE = "false" }, ["HealGroups~f~11"] = { STATE = "false" },
  -- 38 de haut : le nom et la vie tiennent sur deux lignes dans la barre (à 30, la vie débordait dessous, 28/11/2026)
  ["HealBar~f~1"] = { WIDTH = 190, HEIGHT = 38, TEXTURE = "Smooth v2", CMARGIN = 2, RMARGIN = 3, NUMCOLS = 1 },
  ["HealBar~f~7"] = { WIDTH = 160, HEIGHT = 20, TEXTURE = "Smooth v2", CMARGIN = 2, RMARGIN = 2, NUMCOLS = 1 },
  -- familiers : nom seul (une ligne), la vie perdue reste affichée par ForeverCompagnon
  ["BarText~f~7"] = { HLTHONBAR = "false", HEIGHT = 10, OFFSET = 0 },
  ["StickyFrames~f~7"] = { STUCK = "true", STUCKTO = 1, STUCKPOINT = "TOPLEFT", STUCKTOPOINT = "BOTTOMLEFT" },
  ["Frame~f~1"] = { BACKR = 0.05, BACKG = 0.055, BACKB = 0.075, BACKA = 0.86, BORDERR = 0.84, BORDERG = 0.66, BORDERB = 0.29,
                    BORDERA = 0.6, PADDING = 3 },
  ["Frame~f~7"] = { BACKR = 0.05, BACKG = 0.055, BACKB = 0.075, BACKA = 0.7, BORDERR = 0.84, BORDERG = 0.66, BORDERB = 0.29,
                    BORDERA = 0.35, PADDING = 2 },
  ["FrameAlias~f~1"] = { SHOW = "true", NAME = root.FR and "Groupe" or "Group", ALIAS = root.FR and "Groupe" or "Group", FONT = "Roboto Bold", SIZE = 11, OUTLINE = 2,
                         R = GOLDL.R, G = GOLDL.G, B = GOLDL.B },
  ["FrameAliasBar~f~1"] = { TEXTURE = "Smooth v2", HEIGHT = 16, R = 0.1, G = 0.11, B = 0.14, A = 0.9 },
  ["HeadBar~f~1"] = { SHOW = "false" },
  ["BarCol~f~1"] = { HA = 0.8, BA = 0.85, BR = 0.105, BG = 0.12, BB = 0.15 },
  -- préremplissage : soins entrants couleur de classe (les modes « selon la vie » sont refusés aux addons sur Forever)
  ["BarIACol~f~1"] = { IC = 3, AC = 3, IA = 0.55 },
  -- nom à gauche, vie à droite (ALIGN/HALIGN : 1 gauche, 2 centre, 3 droite ; 2 = centré sur la capture du 28/11/2026)
  ["BarText~f~1"] = { HLTHONBAR = "true", HLTHTYPE = 3, IGNOREONFULL = "false", INCHEALS = 1, SHOWROLE = "true", CLASSONBAR = "false",
                      FONT = "Roboto Bold", HEIGHT = 12, OUTLINE = 2, HFONT = "Roboto Bold", HHEIGHT = 11, HOUTLINE = 2,
                      ALIGN = 1, HALIGN = 3 },
  ["Icons~f~1"] = { SHOWROLE = "true", SHOWCLASS = "false" },
  -- débuffs ancrés à gauche (1), buffs à droite (2), sur la barre, une seule rangée, durées affichées
  ["IconSets^1~f~1"] = { DEBUFFANCHOR = 1, BUFFANCHOR = 2, DEBUFFONBAR = 1, BUFFONBAR = 1, DSCALE = 0.75, BSCALE = 0.7,
                         MAXDICONS = 3, MAXBICONS = 5, DEBUFFDOUBLE = "false", BUFFDOUBLE = "false" },
  ["IconSetsText^1~f~1"] = { DBSDUR = "true", BUFFSDUR = "true" },
  ["BarSort~f~1"] = { RAIDORDER = 3, SUBORDER = 5, SUBPF = "true" },
  ["BarVisibility~f~1"] = { ALERTIC = 0.9, ALERTOC = 0.8 },
}

-- Version raid (10 à 40) : même habillage, tiré du skin « Raid 40 » d'HealBot ; ses groupes de barres (tanks, groupes de
-- raid en colonnes) sont gardés, seuls l'apparence, les icônes et le préremplissage changent ; barres plus petites
HB.SKIN_MODERN_RAID = "Forever Moderne Raid"
HB.MODERN_RAID = {
  ["General~t"] = { HIDEPARTYF = "false", HIDERAIDF = "false" },
  ["HealBar~f~1"] = { WIDTH = 96, HEIGHT = 36, GRPCOLS = "true", TEXTURE = "Smooth v2", CMARGIN = 2, RMARGIN = 2 },
  ["Frame~f~1"] = HB.MODERN["Frame~f~1"],
  ["FrameAlias~f~1"] = { SHOW = "true", NAME = "Raid", ALIAS = "Raid", FONT = "Roboto Bold", SIZE = 11, OUTLINE = 2, R = GOLDL.R, G = GOLDL.G, B = GOLDL.B },
  ["FrameAliasBar~f~1"] = HB.MODERN["FrameAliasBar~f~1"],
  ["BarCol~f~1"] = HB.MODERN["BarCol~f~1"],
  ["BarIACol~f~1"] = HB.MODERN["BarIACol~f~1"],
  ["BarText~f~1"] = { HLTHONBAR = "true", HLTHTYPE = 3, IGNOREONFULL = "false", INCHEALS = 1, SHOWROLE = "true", CLASSONBAR = "false",
                      FONT = "Roboto Bold", HEIGHT = 11, OUTLINE = 2, HFONT = "Roboto Bold", HHEIGHT = 10, HOUTLINE = 2,
                      ALIGN = 1, HALIGN = 3 },
  ["Icons~f~1"] = HB.MODERN["Icons~f~1"],
  -- barres étroites : 2 débuffs à gauche, 3 buffs à droite, un peu plus petits
  ["IconSets^1~f~1"] = { DEBUFFANCHOR = 1, BUFFANCHOR = 2, DEBUFFONBAR = 1, BUFFONBAR = 1, DSCALE = 0.6, BSCALE = 0.55,
                         MAXDICONS = 2, MAXBICONS = 3, DEBUFFDOUBLE = "false", BUFFDOUBLE = "false" },
  ["IconSetsText^1~f~1"] = HB.MODERN["IconSetsText^1~f~1"],
  ["BarVisibility~f~1"] = HB.MODERN["BarVisibility~f~1"],
}
local MODERN_SKINS = {
  { name = HB.SKIN_MODERN, from = "Group", edits = HB.MODERN, flags = { "HEALBOT_WORD_SOLO", "HEALBOT_WORD_PARTY" } },
  { name = HB.SKIN_MODERN_RAID, from = "Raid 40", edits = HB.MODERN_RAID,
    flags = { "HEALBOT_OPTIONS_RAID10", "HEALBOT_OPTIONS_RAID15", "HEALBOT_OPTIONS_RAID20", "HEALBOT_OPTIONS_RAID25", "HEALBOT_OPTIONS_RAID40" } },
}

-- Trois styles (maquette du 28/11/2026) : A liste moderne, B cartes en ligne, C barres fines. Même habillage, seules
-- la taille et la disposition des barres changent (réglages ajoutés par-dessus ceux du style A).
HB.STYLES = {
  A = { group = {}, raid = {} },
  B = { group = { ["HealBar~f~1"] = { WIDTH = 120, HEIGHT = 42, NUMCOLS = 5, CMARGIN = 4, RMARGIN = 4 },
                  ["HealBar~f~7"] = { WIDTH = 120, HEIGHT = 14, NUMCOLS = 5, CMARGIN = 4, RMARGIN = 2 },
                  ["IconSets^1~f~1"] = { MAXDICONS = 2, MAXBICONS = 3, DSCALE = 0.6, BSCALE = 0.55 } },
        raid = { ["HealBar~f~1"] = { WIDTH = 100, HEIGHT = 36 } } },
  C = { group = { ["HealBar~f~1"] = { WIDTH = 190, HEIGHT = 26, CMARGIN = 2, RMARGIN = 1 },
                  ["HealBar~f~7"] = { WIDTH = 160, HEIGHT = 14, RMARGIN = 1 },
                  ["BarText~f~1"] = { HEIGHT = 9, HHEIGHT = 9, OFFSET = -3, HOFFSET = -4 },
                  ["IconSets^1~f~1"] = { DSCALE = 0.5, BSCALE = 0.45 } },
        raid = { ["HealBar~f~1"] = { WIDTH = 90, HEIGHT = 26 }, ["BarText~f~1"] = { HEIGHT = 9, HHEIGHT = 9, OFFSET = -3, HOFFSET = -4 },
                 ["IconSets^1~f~1"] = { DSCALE = 0.45, BSCALE = 0.4 } } },
}
local function Merge(base, extra)
  local out = {}
  for k, v in pairs(base) do out[k] = Copy(v) end
  for k, v in pairs(extra or {}) do
    out[k] = out[k] or {}
    for kk, vv in pairs(v) do out[k][kk] = vv end
  end
  return out
end
function HB.StyleEdits(style)
  local st = HB.STYLES[style] or HB.STYLES.A
  return Merge(HB.MODERN, st.group), Merge(HB.MODERN_RAID, st.raid)
end

-- Installe les deux skins (style A, B ou C) et les choisit pour seul, groupe et raid. Clics : jamais lus ni écrits ici.
function HB.InstallModern(style)
  style = HB.STYLES[style] and style or (root.db and root.db.healbotStyle) or "A"
  if type(_G.HealBot_Config_SkinsData) ~= "table" or type(_G.HealBot_Share_SkinLoad) ~= "function" or type(_G.HealBot_Config) ~= "table" then
    root.Print(T.notLoaded); return false
  end
  if InCombatLockdown and InCombatLockdown() then root.Print(T.combat); return false end
  local st = Store()
  local cfg = _G.HealBot_Config
  cfg.SkinDefault = cfg.SkinDefault or {}
  if not st.modernBackup then
    st.modernBackup = { default = Copy(cfg.SkinDefault), skin = _G.Healbot_Config_Skins and _G.Healbot_Config_Skins.Current_Skin }
  end
  local byName = {}
  for _, packed in pairs(_G.HealBot_Config_SkinsData) do
    local t = type(packed) == "string" and Decompress(packed)
    local n = t and t:match("^[^\n]+\n([^\n]+)")
    if n then byName[n] = t end
  end
  local groupEdits, raidEdits = HB.StyleEdits(style)
  for _, s in ipairs(MODERN_SKINS) do
    s.edits = (s.name == HB.SKIN_MODERN_RAID) and raidEdits or groupEdits
    local text = byName[s.from]
    if not text then root.Print(T.skinFail, s.from); return false end
    local ok, err = pcall(_G.HealBot_Share_SkinLoad, PatchFrames(text, s.name, s.edits), false)
    if not ok then root.Print(T.skinFail, tostring(err)); return false end
    for _, f in ipairs(s.flags) do
      local id = _G[f]
      if id then
        for skin, t in pairs(cfg.SkinDefault) do if type(t) == "table" and skin ~= s.name then t[id] = nil end end
        cfg.SkinDefault[s.name] = cfg.SkinDefault[s.name] or {}
        cfg.SkinDefault[s.name][id] = true
      end
    end
  end
  if type(_G.HealBot_Options_Set_Current_Skin) == "function" then
    pcall(_G.HealBot_Options_Set_Current_Skin, (IsInRaid and IsInRaid()) and HB.SKIN_MODERN_RAID or HB.SKIN_MODERN)
  end
  if type(_G.HealBot_SetResetFlag) == "function" then pcall(_G.HealBot_SetResetFlag, "SOFT") end
  root.db.healbotStyle = style
  root.db.healbotDeficit = true                                   -- vie perdue affichée sur les barres
  root.Print(T.modernDone, style)
  return true
end

function HB.RemoveModern()
  local st = Store()
  local b = st.modernBackup
  if not b then root.Print(T.noBackup); return false end
  if type(_G.HealBot_Config) == "table" then _G.HealBot_Config.SkinDefault = Copy(b.default) end
  if b.skin and type(_G.HealBot_Options_Set_Current_Skin) == "function" then pcall(_G.HealBot_Options_Set_Current_Skin, b.skin) end
  st.modernBackup = nil
  root.Print(T.modernUndone)
  return true
end

-- Aperçu dessiné d'un style dans la fenêtre de choix : barres couleur de classe, débuffs (carrés de couleur) à gauche,
-- buffs à droite, partie claire = soin en cours
local PREVIEW_UNITS = { { 0.78, 0.61, 0.43, 0.55 }, { 1, 1, 1, 0.92 }, { 0.25, 0.78, 0.92, 0.78 }, { 0.67, 0.83, 0.45, 0.3 } }
local function Box(parent, x, y, w, h, r, g, b, a)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetPoint("TOPLEFT", x, -y)
  t:SetSize(w, h)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end
local function Preview(f, key)
  local function Bar(x, y, w, h, u, i, icons)
    Box(f, x, y, w, h, 0.11, 0.12, 0.15)
    Box(f, x, y, math.max(1, w * u[4]), h, u[1], u[2], u[3], 0.9)
    if i == 1 then Box(f, x + w * u[4], y, w * 0.25, h, u[1], u[2], u[3], 0.35) end     -- soin en cours
    if icons then
      local s = math.max(4, math.floor(h * 0.55))
      if i == 1 or i == 3 then Box(f, x + 2, y + (h - s) / 2, s, s, i == 1 and 0.69 or 0.25, i == 1 and 0.48 or 0.55, i == 1 and 0.23 or 1) end
      for k = 1, (i == 2 and 3 or 2) do Box(f, x + w - k * (s + 1) - 1, y + (h - s) / 2, s, s, 0.37, 0.83, 0.54) end
    end
  end
  if key == "A" then
    for i, u in ipairs(PREVIEW_UNITS) do Bar(0, (i - 1) * 11, 100, 9, u, i, true) end
    Box(f, 12, 45, 88, 5, 0.67, 0.83, 0.45, 0.6)                                            -- familier
  elseif key == "B" then
    for i, u in ipairs(PREVIEW_UNITS) do
      local x = (i - 1) * 26
      Box(f, x, 6, 24, 34, 0.09, 0.1, 0.13)
      Bar(x + 2, 12, 20, 14, u, i, false)
      if i ~= 2 then Box(f, x + 2, 30, 5, 5, 0.25, 0.55, 1) end
      Box(f, x + 15, 30, 7, 5, 0.37, 0.83, 0.54)
    end
  else
    for i, u in ipairs(PREVIEW_UNITS) do Bar(0, (i - 1) * 9 + 4, 100, 4, u, i, false) end
    for i = 1, 4 do Box(f, 102, (i - 1) * 9 + 4, 4, 4, 0.37, 0.83, 0.54) end
  end
end
HB.Preview = Preview

-- « Configurer HealBot » : choix du style (A, B, C), puis les skins modernes, rien d'autre
local chooser
function HB.Setup()
  if not HB.Available() then root.Print(T.notLoaded); return false end
  if not chooser then
    chooser = CreateFrame("Frame", "ForeverCompagnonHealBotStyle", UIParent)
    chooser:SetSize(440, 260)
    chooser:SetPoint("CENTER")
    chooser:SetFrameStrata("DIALOG")
    chooser:EnableMouse(true)
    tinsert(UISpecialFrames, "ForeverCompagnonHealBotStyle")
    local C = root.Theme or { bg = { 0.07, 0.08, 0.1 }, goldL = { 0.94, 0.77, 0.42 }, muted = { 0.64, 0.61, 0.55 }, line = { 0.18, 0.2, 0.24 } }
    local bg = chooser:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.97)
    root.Kit.Border(chooser, 0.84, 0.66, 0.29, 0.8)
    local title = chooser:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(T.chooseTitle)
    local note = chooser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    note:SetText(T.chooseNote)
    local close = CreateFrame("Button", nil, chooser, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() chooser:Hide() end)
    chooser.buttons = {}
    for i, key in ipairs({ "A", "B", "C" }) do
      local b = CreateFrame("Button", nil, chooser)
      b:SetSize(412, 60)
      b:SetPoint("TOPLEFT", 14, -50 - (i - 1) * 66)
      b.bg = b:CreateTexture(nil, "BACKGROUND")
      b.bg:SetAllPoints()
      b.bg:SetColorTexture(0.102, 0.114, 0.141, 1)
      root.Kit.Border(b, C.line[1], C.line[2], C.line[3], 1)
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 0.82, 0.3, 0.08)
      b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      b.name:SetPoint("TOPLEFT", 10, -7)
      b.name:SetText(T["style" .. key])
      b.desc = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.desc:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
      b.desc:SetText(T["style" .. key .. "D"])
      b.desc:SetWidth(250)
      b.desc:SetJustifyH("LEFT")
      b.preview = CreateFrame("Frame", nil, b)
      b.preview:SetSize(110, 52)
      b.preview:SetPoint("RIGHT", -8, -2)
      Preview(b.preview, key)
      b.key = key
      b:SetScript("OnClick", function() chooser:Hide(); HB.InstallModern(key) end)
      chooser.buttons[i] = b
    end
  end
  local cur = root.db and root.db.healbotStyle
  for _, b in ipairs(chooser.buttons) do
    b.name:SetText(T["style" .. b.key] .. ((cur == b.key) and ("  |cffa0a0a0" .. T.current .. "|r") or ""))
  end
  chooser:Show()
  return true
end

----------------------------------------------------------------------
-- Protection de la prédiction des soins d'HealBot (client 1.60.1, 15/11/2026) : HealBot 26.11.14, en mode de couleur
-- « selon la vie » (BarIACol IC/AC = 5 ou 6), passe la vie secrète du groupe à SetPredictedValues, ce que le jeu refuse
-- aux addons : ~3 erreurs par seconde en donjon. HealBot appelle sa fonction par son nom global à chaque fois
-- (HealBot_ForeverFrames.lua:19) ; on l'enveloppe : en cas d'erreur, elle rend false et HealBot passe à sa barre simple
-- (sans couleur selon la vie). Aucun fichier d'HealBot n'est modifié. /fp healbot protection : couper ou remettre.
----------------------------------------------------------------------
HB.guard = { absorbed = 0, installed = false }
local function GuardOn() return not (root.db and root.db.healbotGuard == false) end
function HB.GuardPrediction()
  if HB.guard.installed then return true end
  local orig = _G.HealBot_Forever_UpdatePrediction
  if type(orig) ~= "function" then return false end
  HB.guard.installed, HB.guard.orig = true, orig
  _G.HealBot_Forever_UpdatePrediction = function(button, ...)
    if not GuardOn() then return orig(button, ...) end
    local ok, res = pcall(orig, button, ...)
    if ok then return res end
    HB.guard.absorbed = HB.guard.absorbed + 1
    HB.guard.last = tostring(res):sub(1, 200)
    return false
  end
  return true
end
function HB.GuardText()
  if not HB.guard.installed then return nil end
  return string.format(FR and "Protection HealBot (prédiction des soins) : %s, %d erreur(s) absorbée(s) depuis la connexion"
                          or "HealBot guard (heal prediction): %s, %d error(s) absorbed since login",
    GuardOn() and (FR and "active" or "on") or (FR and "coupée" or "off"), HB.guard.absorbed)
end
local gev = CreateFrame("Frame")
gev:RegisterEvent("ADDON_LOADED")
gev:RegisterEvent("PLAYER_LOGIN")
gev:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" or name == "HealBot" then pcall(HB.GuardPrediction) end
end)

function HB.Command(arg)
  arg = (arg or ""):lower()
  if arg == "protection" or arg == "guard" then
    root.db.healbotGuard = (root.db.healbotGuard == false)
    HB.GuardPrediction()
    root.Print(HB.GuardText() or (FR and "HealBot : fonction de prédiction absente." or "HealBot: prediction function not found."))
  elseif arg == "annuler" or arg == "undo" or arg == "restore" or arg == "moderne annuler" or arg == "modern undo" then HB.RemoveModern()
  elseif arg == "chiffres" or arg == "numbers" or arg == "vie" then HB.ToggleDeficit()
  elseif arg == "diag" then HB.Diag()
  elseif arg == "a" or arg == "b" or arg == "c" then HB.InstallModern(arg:upper())
  elseif arg == "moderne" or arg == "modern" then HB.InstallModern()
  elseif arg == "export" or arg == "releve" or arg == "relevé" then HB.Export()
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

