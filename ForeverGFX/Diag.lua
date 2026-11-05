local ADDON, ns = ...

-- Diagnostic commun aux addons Forever (copié tel quel dans chaque addon par tools/sync-shared.sh) :
-- un texte à copier-coller à Claude, avec ce que le client donne vraiment (versions, sorts, objets, valeurs),
-- pour adapter les addons à WoW Forever (base classique modifiée). Chaque addon fournit ns.DiagCollect(add).

local FR = GetLocale() == "frFR"
local T = {
  title = FR and "Diagnostic %s : copie ce texte (Ctrl+A puis Ctrl+C) et colle-le à Claude"
             or "%s diagnostic: copy this text (Ctrl+A then Ctrl+C) and paste it to Claude",
  close = FR and "Fermer" or "Close",
  selectAll = FR and "Tout sélectionner" or "Select all",
  button = "Diag",
  tip = FR and "Diagnostic : ouvre un texte à copier-coller à Claude, avec ce que ton client WoW Forever donne vraiment, pour adapter l'addon."
           or "Diagnostic: opens a text to copy and paste to Claude, with what your WoW Forever client really provides, to adapt the addon.",
}

local function Meta(addon, field)
  local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return f and f(addon, field)
end

local function Loaded(addon)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(addon) end
  return IsAddOnLoaded and IsAddOnLoaded(addon)
end

local function Header(add)
  local v, build, d, iface = GetBuildInfo()
  add("### " .. ADDON .. " " .. tostring(Meta(ns.ROOT or ADDON, "Version") or "?") .. (ns.ROOT and (" (" .. ns.ROOT .. ")") or "") .. " — diagnostic du " .. date("%Y-%m-%d %H:%M"))
  add(string.format("Client : %s build %s (%s), interface %s, langue %s", tostring(v), tostring(build), tostring(d), tostring(iface), GetLocale()))
  local _, race = UnitRace("player")
  local _, class = UnitClass("player")
  add(string.format("Personnage : niveau %s, %s %s, %s, royaume %s", tostring(UnitLevel("player")), tostring(race), tostring(class),
    tostring(UnitFactionGroup("player")), tostring(GetRealmName and GetRealmName() or "?")))
  local list = {}
  for _, a in ipairs({ "ForeverGFX", "ForeverMacros", "ForeverGazette", "ForeverPrep", "ForeverHeal", "ForeverLoot", "ForeverMetiers" }) do
    if Loaded(a) then list[#list + 1] = a .. " " .. tostring(Meta(a, "Version") or "?") end
  end
  add("Addons Forever chargés : " .. table.concat(list, ", "))
end

-- Nombre utilisable, ou nil : sur le client de Forever, certaines valeurs (mana, vie… en combat) sont « secrètes » :
-- toute opération dessus provoque une erreur (« attempt to perform arithmetic on a secret number value », 05/11/2026)
function ns.Plain(v)
  if type(v) ~= "number" then return nil end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then return nil end
    if ok then return v end
  end
  local ok = pcall(function() return v + 0 end)
  return ok and v or nil
end

-- Croix de fermeture sûre : celle du modèle BasicFrameTemplate passe par HideUIPanel, réservé à Blizzard en combat
-- (« Échec d'une action d'interface », 05/11/2026) ; on cache simplement la fenêtre
function ns.SafeClose(f)
  if not f then return end
  local c = rawget(f, "CloseButton") or f.CloseButton
  if type(c) ~= "table" then
    local name = type(f.GetName) == "function" and f:GetName()
    c = type(name) == "string" and _G[name .. "CloseButton"] or nil
  end
  if type(c) == "table" and type(c.SetScript) == "function" then c:SetScript("OnClick", function() f:Hide() end) end
end

-- Actions bloquées par le jeu (« … a été bloqué à cause d'une action qui n'est utilisable que par l'IU de Blizzard ») :
-- notées avec le nom de la fonction, pour le diagnostic. Une seule fenêtre commune à tous les addons Forever.
local blocked = _G.ForeverBlockedActions
if not blocked then
  blocked = {}
  _G.ForeverBlockedActions = blocked
  local bf = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do pcall(bf.RegisterEvent, bf, e) end
  bf:SetScript("OnEvent", function(_, event, addon, func)
    if #blocked < 30 then
      blocked[#blocked + 1] = string.format("%s %s %s %s", date("%H:%M:%S"), tostring(event), tostring(addon), tostring(func))
    end
  end)
end

-- Lignes du diagnostic (en-tête + section de l'addon) ; une erreur est écrite dans le texte au lieu de bloquer
function ns.DiagText()
  local lines = {}
  local function add(s) lines[#lines + 1] = tostring(s) end
  local ok, err = pcall(Header, add)
  if not ok then add("Erreur en-tête : " .. tostring(err)) end
  add("Actions bloquées par le jeu depuis la connexion : " .. (#blocked == 0 and "aucune" or ""))
  for _, b in ipairs(blocked) do add("  " .. b) end
  if ns.DiagCollect then
    ok, err = pcall(ns.DiagCollect, add)
    if not ok then add("Erreur pendant le diagnostic : " .. tostring(err)) end
  end
  return table.concat(lines, "\n"), lines
end

local frame
function ns.ShowDiag()
  local text = ns.DiagText()
  if not frame then
    local name = ADDON .. "DiagFrame"
    frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    ns.SafeClose(frame)
    frame:SetSize(680, 480)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOPLEFT", 12, -6)
    frame.title:SetPoint("RIGHT", -30, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetText(string.format(T.title, ADDON))
    local sf = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -32)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(0)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(620)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Hide() end)
    sf:SetScrollChild(eb)
    frame.edit = eb
    local sel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sel:SetSize(150, 22)
    sel:SetPoint("BOTTOMLEFT", 14, 12)
    sel:SetText(T.selectAll)
    sel:SetScript("OnClick", function() eb:SetFocus(); eb:HighlightText() end)
    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(110, 22)
    close:SetPoint("BOTTOMRIGHT", -14, 12)
    close:SetText(T.close)
    close:SetScript("OnClick", function() frame:Hide() end)
  end
  frame.edit:SetText(text)
  frame:Show()
  frame.edit:SetFocus()
  frame.edit:HighlightText()
  ns.lastDiag = text
end

-- Petits outils pour les sections
function ns.DiagSpell(id)
  local name
  if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) else name = GetSpellInfo(id) end
  local known = (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
  return name, known
end

function ns.DiagItem(id)
  local inst = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local _, itemType, subType, equipLoc, icon, classID, subID = inst(id)
  if not icon then return nil end
  local name, _, quality, ilvl, minLevel = info(id)
  return { name = name, quality = quality, ilvl = ilvl, minLevel = minLevel, type = itemType, sub = subType,
           equipLoc = equipLoc, classID = classID, subID = subID }
end

-- Bouton « Diag » pour les fenêtres des addons (dans la barre de titre, à gauche du « ? » ou de la croix)
function ns.MakeDiagButton(parent, rightOf)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(44, 20)
  b:SetText(T.button)
  if rightOf then b:SetPoint("RIGHT", rightOf, "LEFT", -2, 0) else b:SetPoint("TOPRIGHT", -28, -2) end
  b:SetFrameLevel(((rightOf or parent):GetFrameLevel() or 1) + (rightOf and 0 or 60))
  b:SetScript("OnClick", function() ns.ShowDiag() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(T.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end
