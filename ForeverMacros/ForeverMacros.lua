local ADDON, ns = ...
local L = ns.L

local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or 120
local MAX_CHAR = MAX_CHARACTER_MACROS or 18
local QUESTION_ICON = 134400 -- point d'interrogation : icône dynamique avec #showtooltip

local db, ui
local interface = select(4, GetBuildInfo()) or 0
ns.isTBC = interface >= 20000 and interface < 30000
local st = { editIndex = nil, perChar = false }

----------------------------------------------------------------------
-- Outils
----------------------------------------------------------------------
local function Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cff66ccffForeverMacros|r " .. msg)
end

local function Trim(s) return ((s or ""):match("^%s*(.-)%s*$")) end

local function SpellName(id)
  if not id then return end
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and n then return n end
  end
end

local function ItemName(id)
  if C_Item and C_Item.GetItemNameByID then
    local ok, n = pcall(C_Item.GetItemNameByID, id)
    if ok and n then return n end
  end
  if GetItemInfo then
    local ok, n = pcall(GetItemInfo, id)
    if ok and n then return n end
  end
end

local function SpellExists(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if ok and info then return true end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, name)
    if ok and n then return true end
  end
  return false
end

local function ItemExists(name)
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if f then
    local ok, id = pcall(f, name)
    if ok and id then return true end
  end
  return false
end

----------------------------------------------------------------------
-- Construction de la macro
----------------------------------------------------------------------
local function Brackets(conds)
  local s = ""
  for _, c in ipairs(conds) do s = s .. "[" .. c .. "]" end
  return s
end

function ns.Build(main, alt)
  local b = db.builder
  main = Trim(main)
  if main == "" then main = L.placeholder end
  alt = Trim(alt)
  local t = ns.Targets[b.target] or ns.Targets[1]
  local fallback = b.fallback and not t.noFallback

  local lines = {}
  if b.tooltip then lines[#lines + 1] = "#showtooltip" end
  if b.stop then lines[#lines + 1] = "/stopcasting" end
  if b.attack then lines[#lines + 1] = "/startattack" end

  local segs = {}
  if alt ~= "" then
    local m = "mod:" .. b.mod
    local conds = {}
    if t.cond then
      conds[#conds + 1] = m .. "," .. t.cond
      if fallback then conds[#conds + 1] = m end
    else
      conds[#conds + 1] = m
    end
    segs[#segs + 1] = Brackets(conds) .. " " .. alt
  end
  local conds = {}
  if t.cond then
    conds[#conds + 1] = t.cond
    if fallback then conds[#conds + 1] = "" end
  end
  local br = Brackets(conds)
  segs[#segs + 1] = (br ~= "" and (br .. " ") or "") .. main
  lines[#lines + 1] = b.action .. " " .. table.concat(segs, "; ")
  return table.concat(lines, "\n")
end

function ns.BuildSequence(spells)
  local b = db.builder
  local list = {}
  for _, sp in ipairs(spells) do
    sp = Trim(sp)
    if sp ~= "" then list[#list + 1] = sp end
  end
  if #list == 0 then list[1] = L.placeholder end

  local resets = {}
  local delay = tonumber(b.seqDelay)
  if delay and delay > 0 then resets[#resets + 1] = tostring(math.floor(delay)) end
  if b.seqCombat then resets[#resets + 1] = "combat" end
  if b.seqTarget then resets[#resets + 1] = "target" end
  if b.seqShift then resets[#resets + 1] = "shift" end
  if b.seqCtrl then resets[#resets + 1] = "ctrl" end
  if b.seqAlt then resets[#resets + 1] = "alt" end

  local lines = {}
  if b.tooltip then lines[#lines + 1] = "#showtooltip" end
  if b.stop then lines[#lines + 1] = "/stopcasting" end
  if b.attack then lines[#lines + 1] = "/startattack" end
  lines[#lines + 1] = "/castsequence "
    .. (#resets > 0 and ("reset=" .. table.concat(resets, "/") .. " ") or "")
    .. table.concat(list, ", ")
  return table.concat(lines, "\n")
end

function ns.FillTemplate(tpl, main, alt)
  main = Trim(main)
  alt = Trim(alt)
  if main == "" then main = L.placeholder end
  if alt == "" then alt = L.placeholder2 end
  local body = tpl.body:gsub("{S2}", function() return alt end)
  body = body:gsub("{S}", function() return main end)
  return body
end

----------------------------------------------------------------------
-- Vérification
----------------------------------------------------------------------
local PLACEHOLDERS = { NomDuSort = true, SortAlternatif = true, SpellName = true, AltSpell = true }
local RESETS = { combat = true, target = true, shift = true, ctrl = true, alt = true }

local function UnitKnown(unit)
  unit = unit:lower()
  for _, p in ipairs(ns.UnitPatterns) do
    if unit:find(p) then return true end
  end
  return false
end

function ns.Validate(body)
  local errs, warns, infos = {}, {}, {}
  local len = #body
  if len > 255 then errs[#errs + 1] = string.format(L.errLength, len)
  elseif len > 230 then warns[#warns + 1] = string.format(L.warnLength, len) end

  local hasTooltip, hasCast = false, false
  local n = 0
  for line in (body .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    local l = Trim(line)
    local first = l:sub(1, 1)
    if first == "#" then
      local meta = (l:match("^#(%S+)") or ""):lower()
      if meta == "showtooltip" or meta == "show" then hasTooltip = true
      else warns[#warns + 1] = string.format(L.warnMeta, n) end
    elseif first == "/" then
      local cmd = (l:match("^(/%S+)") or "/"):lower()
      local rest = l:sub(#cmd + 1)
      if not ns.KnownCommands[cmd] then warns[#warns + 1] = string.format(L.warnCmd, n, cmd) end
      if cmd == "/cast" or cmd == "/use" or cmd == "/castsequence" or cmd == "/castrandom" then hasCast = true end

      local _, open = rest:gsub("%[", "")
      local _, close = rest:gsub("%]", "")
      local balanced = open == close
      if not balanced then
        errs[#errs + 1] = string.format(L.errBrackets, n)
      else
        for inside in rest:gmatch("%[(.-)%]") do
          for tok in inside:gmatch("[^,]+") do
            tok = Trim(tok)
            if tok ~= "" then
              local unit = tok:match("^@(.+)$") or tok:match("^[Tt]arget=(.+)$")
              if unit then
                if not UnitKnown(Trim(unit)) then warns[#warns + 1] = string.format(L.warnUnit, n, unit) end
              else
                local key = (tok:match("^(%a+)") or ""):lower()
                local base = key
                if key ~= "" and not ns.KnownConditions[key] then
                  base = (key:sub(1, 2) == "no") and key:sub(3) or key
                  if not ns.KnownConditions[base] then warns[#warns + 1] = string.format(L.warnCond, n, tok) end
                end
                -- Arguments de mod: shift, ctrl, alt (combinables) ou nom de raccourci en majuscules
                if base == "mod" or base == "modifier" then
                  local args = tok:match(":(.+)$")
                  if args then
                    for a in args:gmatch("[^/]+") do
                      local rest2 = a:lower():gsub("[lr]?shift", ""):gsub("[lr]?ctrl", ""):gsub("[lr]?alt", ""):gsub("meta", "")
                      local ok = (rest2 == "" and a ~= "") or a:match("^[A-Z_]+$")
                      if not ok then warns[#warns + 1] = string.format(L.warnCond, n, tok) break end
                    end
                  end
                end
              end
            end
          end
        end
      end

      if balanced and (cmd == "/castsequence" or cmd == "/castrandom" or cmd == "/userandom") then
        for seg in rest:gmatch("[^;]+") do
          local body2 = Trim((seg:gsub("%b[]", "")))
          local reset, after = body2:match("^reset=(%S+)%s*(.*)$")
          if reset then
            for r in reset:gmatch("[^/]+") do
              if not (tonumber(r) or RESETS[r:lower()]) then
                warns[#warns + 1] = string.format(L.warnReset, n, r)
              end
            end
            body2 = after
          end
          for name in body2:gmatch("[^,]+") do
            name = Trim(name):gsub("^!", "")
            if name ~= "" and not tonumber(name) then
              if PLACEHOLDERS[name] then
                warns[#warns + 1] = string.format(L.warnPlaceholder, n, name)
              elseif not SpellExists(name) and not ItemExists(name) then
                warns[#warns + 1] = string.format(L.warnSpell, n, name)
              end
            end
          end
        end
      end

      if balanced and (cmd == "/cast" or cmd == "/use") then
        for seg in rest:gmatch("[^;]+") do
          local name = Trim((seg:gsub("%b[]", "")))
          name = name:gsub("^!", "")
          if name ~= "" and not tonumber(name) then
            if PLACEHOLDERS[name] then
              warns[#warns + 1] = string.format(L.warnPlaceholder, n, name)
            elseif not SpellExists(name) and not (cmd == "/use" and ItemExists(name)) then
              warns[#warns + 1] = string.format(L.warnSpell, n, name)
            end
          end
        end
      end
      -- Limites propres aux clients récents (Midnight) : sans objet sur TBC Anniversary
      if not ns.isTBC then
        if ns.MarkerCommands[cmd] then infos[#infos + 1] = string.format(L.infoMarker, n) end
        if ns.ChatCommands[cmd] then infos[#infos + 1] = string.format(L.infoChat, n) end
      end
    end
  end
  if hasCast and not hasTooltip then infos[#infos + 1] = L.warnNoTooltip end
  return errs, warns, infos
end

----------------------------------------------------------------------
-- Gestion des macros du jeu
----------------------------------------------------------------------
local function MacroItems()
  local items = { { text = L.newMacro, value = 0, checked = st.editIndex == nil } }
  local g, c = GetNumMacros()
  for i = 1, g do
    local name = GetMacroInfo(i)
    if name then
      items[#items + 1] = { text = name .. "  |cff888888" .. L.general .. "|r", value = i, checked = st.editIndex == i }
    end
  end
  for i = 1, c do
    local idx = MAX_ACCOUNT + i
    local name = GetMacroInfo(idx)
    if name then
      items[#items + 1] = { text = name .. "  |cff888888" .. L.character .. "|r", value = idx, checked = st.editIndex == idx }
    end
  end
  items[#items + 1] = { text = "|cff99ccff" .. L.backupAll .. "|r", value = -1 }
  items[#items + 1] = { text = "|cff99ccff" .. L.restoreAll .. "|r", value = -2 }
  return items
end

local UpdateStatus, BuildLibrary, BuildTabs, SetTab

local BackupAll, RestoreFrom, ShowText
local function LoadMacro(idx)
  if idx == -1 then return BackupAll() end
  if idx == -2 then return ShowText(L.restoreTitle, "", RestoreFrom) end
  if idx == 0 then
    st.editIndex = nil
    ui.nameBox:SetText("")
    ui.body:SetText("")
  else
    local name, _, body = GetMacroInfo(idx)
    if not name then return end
    st.editIndex = idx
    st.perChar = idx > MAX_ACCOUNT
    ui.nameBox:SetText(name)
    ui.body:SetText(body or "")
  end
  UpdateStatus()
end

local function CreateNew(name, body)
  local g, c = GetNumMacros()
  if st.perChar and c >= MAX_CHAR then return Print(L.full, L.character) end
  if not st.perChar and g >= MAX_ACCOUNT then return Print(L.full, L.general) end
  local ok, idx = pcall(CreateMacro, name, QUESTION_ICON, body, st.perChar)
  if not ok or not idx then return Print(L.full, st.perChar and L.character or L.general) end
  Print(L.created, name, st.perChar and L.character or L.general)
  return idx
end

local function Save()
  if InCombatLockdown() then return Print(L.inCombat) end
  local name = Trim(ui.nameBox:GetText())
  if name == "" then return Print(L.needName) end
  local body = ui.body:GetText()
  if #body > 255 then return Print(L.tooLong) end

  if st.editIndex and GetMacroInfo(st.editIndex) then
    local wasChar = st.editIndex > MAX_ACCOUNT
    if wasChar == st.perChar then
      local idx = EditMacro(st.editIndex, name, nil, body)
      st.editIndex = idx or st.editIndex
      Print(L.saved, name)
    else
      -- Changement de portée : on crée la nouvelle puis on supprime l'ancienne
      local old = st.editIndex
      if CreateNew(name, body) then
        DeleteMacro(old)
        st.editIndex = GetMacroIndexByName(name)
      end
    end
  else
    local idx = CreateNew(name, body)
    if idx then st.editIndex = idx end
  end
  UpdateStatus()
end

local function Place()
  if InCombatLockdown() then return Print(L.inCombat) end
  if not (st.editIndex and GetMacroInfo(st.editIndex)) then return Print(L.noMacro) end
  PickupMacro(st.editIndex)
  Print(L.placeHint)
end

----------------------------------------------------------------------
-- Interface : petits constructeurs
----------------------------------------------------------------------
local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Label(parent, text, x, y, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function MakeCheck(parent, label, x, y, key, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  cb.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.label:SetText(label)
  cb:SetChecked(db.builder[key])
  cb:SetScript("OnClick", function(self)
    db.builder[key] = self:GetChecked() and true or false
    if onChange then onChange() end
  end)
  return cb
end

local menu, catcher
local function HideMenu()
  if menu then menu:Hide() end
  if catcher then catcher:Hide() end
end

local function OpenMenu(anchor, items, onSelect)
  if not menu then
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:SetScript("OnClick", HideMenu)
    catcher:Hide()
    menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    menu:SetBackdropColor(0.05, 0.05, 0.08, 0.96)
    menu.buttons = {}
  end
  local width = 160
  for i, it in ipairs(items) do
    local b = menu.buttons[i]
    if not b then
      b = CreateFrame("Button", nil, menu)
      b:SetHeight(18)
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.text:SetPoint("LEFT", 8, 0)
      b.text:SetJustifyH("LEFT")
      menu.buttons[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 18)
    b:SetPoint("RIGHT", menu, "RIGHT", -6, 0)
    b.text:SetText((it.checked and "|cff66ff66> |r" or "   ") .. it.text)
    width = math.max(width, b.text:GetStringWidth() + 30)
    b:SetScript("OnClick", function() HideMenu(); onSelect(it.value) end)
    b:Show()
  end
  for i = #items + 1, #menu.buttons do menu.buttons[i]:Hide() end
  menu:SetSize(width + 12, #items * 18 + 12)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  catcher:Show()
  menu:Show()
end

-- Case qui accepte un sort ou un objet glissé depuis le grimoire ou les sacs
local function TakeCursor(box)
  local kind, a, _, c = GetCursorInfo()
  local name
  if kind == "spell" then
    name = SpellName(c) or SpellName(a)
  elseif kind == "item" then
    name = ItemName(a)
  end
  if name then
    box:SetText(name)
    ClearCursor()
    return true
  end
end

local function MakeSpellBox(parent, width)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(width, 20)
  box:SetAutoFocus(false)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnReceiveDrag", function(self) TakeCursor(self) end)
  box:SetScript("OnMouseDown", function(self) if GetCursorInfo() then TakeCursor(self) end end)
  return box
end

----------------------------------------------------------------------
-- Fenêtre principale
----------------------------------------------------------------------
local function UpdateChecks()
  local body = ui.body:GetText()
  ui.count:SetText(string.format(L.count, #body))
  ui.count:SetTextColor(#body > 255 and 1 or 0.7, #body > 255 and 0.3 or 0.7, #body > 255 and 0.3 or 0.7)
  local errs, warns, infos = ns.Validate(body)
  local lines = {}
  for _, m in ipairs(errs) do lines[#lines + 1] = "|cffff5555" .. m .. "|r" end
  for _, m in ipairs(warns) do lines[#lines + 1] = "|cffffaa33" .. m .. "|r" end
  for _, m in ipairs(infos) do lines[#lines + 1] = "|cff99bbff" .. m .. "|r" end
  while #lines > 8 do table.remove(lines) end
  ui.checks:SetText(#lines > 0 and table.concat(lines, "\n") or L.noIssue)
end

function UpdateStatus()
  if not ui then return end
  if st.editIndex and GetMacroInfo(st.editIndex) then
    ui.status:SetText(string.format(L.editing, (GetMacroInfo(st.editIndex))))
  else
    st.editIndex = nil
    ui.status:SetText(L.creating)
  end
  ui.scopeBtn:SetText(st.perChar and L.character or L.general)
  ui.delBtn:SetEnabled(st.editIndex ~= nil)
  ui.placeBtn:SetEnabled(st.editIndex ~= nil)
end

local function ApplyMode()
  local seq = db.builder.mode == "seq"
  for _, w in ipairs(ui.simpleWidgets) do w:SetShown(not seq) end
  for _, w in ipairs(ui.seqWidgets) do w:SetShown(seq) end
  ui.modeBtn:SetText(seq and L.mode_seq or L.mode_simple)
end

local function RefreshBuilder()
  ApplyMode()
  local b = db.builder
  local t = ns.Targets[b.target] or ns.Targets[1]
  ui.actionBtn:SetText(b.action == "/use" and L.act_use or L.act_cast)
  ui.targetBtn:SetText(L[t.key])
  ui.modBtn:SetText(L["m_" .. b.mod])
  ui.fallback:SetEnabled(not t.noFallback)
  ui.fallback.label:SetAlpha(t.noFallback and 0.4 or 1)
end


----------------------------------------------------------------------
-- Bibliothèque de macros prêtes
----------------------------------------------------------------------
local LIB_ROWS, LIB_H = 6, 64
local libOffset = 0

local function ClassName(file)
  local loc = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]
  if loc then return loc end
  local fb = ns.ClassNamesFallback[file]
  return fb and ns.Pick(fb[1], fb[2]) or file
end

function ns.ResolveLib(entry)
  local missing
  local body = entry.body:gsub("{(%d+)}", function(id)
    local n = SpellName(tonumber(id))
    if not n then
      missing = missing or ("#" .. id)
      return "#" .. id
    end
    if not missing and not SpellExists(n) then missing = n end
    return n
  end)
  return body, missing
end

local libSearch = ""
local function LibEntries()
  local all = ns.Library[db.libClass] or {}
  if libSearch == "" then return all end
  local out = {}
  for _, e in ipairs(all) do
    local hay = (ns.Pick(e.title, e.title_en) .. " " .. ns.Pick(e.desc, e.desc_en)):lower()
    if hay:find(libSearch, 1, true) then out[#out + 1] = e end
  end
  return out
end

local function ShowInEditor(entry)
  local body = ns.ResolveLib(entry)
  local name = ns.Pick(entry.short, entry.short_en)
  local existing = GetMacroIndexByName(name)
  st.editIndex = (existing and existing > 0) and existing or nil
  st.perChar = true
  ui.nameBox:SetText(name)
  ui.body:SetText(body)
  UpdateStatus()
end

local function CreateFromLibrary(entry)
  if InCombatLockdown() then return Print(L.inCombat) end
  local body = ns.ResolveLib(entry)
  local name = ns.Pick(entry.short, entry.short_en)
  local existing = GetMacroIndexByName(name)
  local idx
  if existing and existing > 0 then
    idx = EditMacro(existing, name, nil, body) or existing
    Print(L.libExists, name)
  else
    st.perChar = true
    idx = CreateNew(name, body)
  end
  if idx then
    st.editIndex = idx
    ui.nameBox:SetText(name)
    ui.body:SetText(body)
    UpdateStatus()
    PickupMacro(idx)
    Print(L.libCreated, name)
  end
end

local function UpdateLibrary()
  if not ui or not ui.libRows then return end
  local list = LibEntries()
  ui.classBtn:SetText(ClassName(db.libClass))
  for i = 1, LIB_ROWS do
    local row = ui.libRows[i]
    local e = list[libOffset + i]
    row.entry = e
    if e then
      local _, missing = ns.ResolveLib(e)
      row.title:SetText(ns.Pick(e.title, e.title_en))
      row.desc:SetText(ns.Pick(e.desc, e.desc_en))
      row.status:SetText(missing and string.format(L.libMissing, missing) or L.libReady)
      row:Show()
    else
      row:Hide()
    end
  end
  ui.libSlider:SetMinMaxValues(0, math.max(0, #list - LIB_ROWS))
end

function BuildLibrary(parent)
  local lp = CreateFrame("Frame", nil, parent)
  lp:SetPoint("TOPLEFT", 0, -50)
  lp:SetSize(430, 560)
  ui.libraryPanel = lp

  local intro = lp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  intro:SetPoint("TOPLEFT", 18, -6)
  intro:SetWidth(396)
  intro:SetJustifyH("LEFT")
  local introText = L.libIntro
  if interface >= 100000 then introText = introText .. "\n|cffffaa33" .. L.libRetail .. "|r" end
  intro:SetText(introText)

  local classLabel = Label(lp, L.class, 18, -54)
  classLabel:ClearAllPoints()
  classLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -12)
  ui.classBtn = MakeButton(lp, "", 180, function(self)
    local items = {}
    for _, c in ipairs(ns.LibraryOrder) do
      items[#items + 1] = { text = ClassName(c), value = c, checked = db.libClass == c }
    end
    OpenMenu(self, items, function(v)
      db.libClass = v
      libOffset = 0
      ui.libSlider:SetValue(0)
      UpdateLibrary()
    end)
  end)
  ui.classBtn:SetPoint("LEFT", classLabel, "LEFT", 62, 0)

  local search = CreateFrame("EditBox", nil, lp, "SearchBoxTemplate")
  search:SetSize(140, 20)
  search:SetPoint("LEFT", ui.classBtn, "RIGHT", 12, 0)
  search:SetAutoFocus(false)
  if search.Instructions then search.Instructions:SetText(L.libSearch) end
  search:HookScript("OnTextChanged", function(self)
    libSearch = (self:GetText() or ""):lower()
    libOffset = 0
    ui.libSlider:SetValue(0)
    UpdateLibrary()
  end)

  local area = CreateFrame("Frame", nil, lp)
  area:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", -4, -14)
  area:SetSize(386, LIB_ROWS * LIB_H)
  area:EnableMouseWheel(true)

  ui.libRows = {}
  for i = 1, LIB_ROWS do
    local row = CreateFrame("Frame", nil, area, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 0, -(i - 1) * LIB_H)
    row:SetSize(386, LIB_H - 4)
    row:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    row:SetBackdropColor(0.1, 0.1, 0.14, 0.8)
    row:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.8)
    row:EnableMouse(true)
    row:EnableMouseWheel(true)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", 8, -7)
    row.title:SetWidth(250)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("TOPRIGHT", -8, -8)
    row.status:SetWidth(120)
    row.status:SetJustifyH("RIGHT")
    row.status:SetWordWrap(false)
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.desc:SetPoint("TOPLEFT", 8, -24)
    row.desc:SetWidth(250)
    row.desc:SetHeight(30)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetJustifyV("TOP")
    row.desc:SetWordWrap(true)
    if row.desc.SetMaxLines then row.desc:SetMaxLines(2) end

    row.create = MakeButton(row, L.createPlace, 64, function() if row.entry then CreateFromLibrary(row.entry) end end)
    row.create:SetPoint("BOTTOMRIGHT", -6, 6)
    row.view = MakeButton(row, L.view, 54, function() if row.entry then ShowInEditor(row.entry) end end)
    row.view:SetPoint("RIGHT", row.create, "LEFT", -4, 0)

    row:SetScript("OnEnter", function(self)
      if not self.entry then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(ns.Pick(self.entry.title, self.entry.title_en), 1, 0.82, 0)
      GameTooltip:AddLine(ns.Pick(self.entry.desc, self.entry.desc_en), 1, 1, 1, true)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L.libPreview, 0.6, 0.8, 1)
      for line in (ns.ResolveLib(self.entry) .. "\n"):gmatch("(.-)\n") do GameTooltip:AddLine(line, 0.9, 0.9, 0.9) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnMouseWheel", function(_, d) ui.libSlider:SetValue(ui.libSlider:GetValue() - d) end)
    ui.libRows[i] = row
  end

  local slider = CreateFrame("Slider", nil, lp, "BackdropTemplate")
  slider:SetPoint("TOPLEFT", area, "TOPRIGHT", 4, 0)
  slider:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 4, 0)
  slider:SetWidth(14)
  slider:SetOrientation("VERTICAL")
  slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  slider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  slider:SetMinMaxValues(0, 0)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(0)
  slider:SetScript("OnValueChanged", function(_, v)
    libOffset = math.floor(v + 0.5)
    UpdateLibrary()
  end)
  ui.libSlider = slider
  area:SetScript("OnMouseWheel", function(_, d) slider:SetValue(slider:GetValue() - d) end)
  lp:SetScript("OnShow", UpdateLibrary)
end

----------------------------------------------------------------------
-- Onglets
----------------------------------------------------------------------
function SetTab(n)
  db.tab = n
  ui.libraryPanel:SetShown(n == 1)
  ui.builderPanel:SetShown(n == 2)
  for i, b in ipairs(ui.tabs) do
    if i == n then b:LockHighlight() else b:UnlockHighlight() end
  end
  if n == 1 then UpdateLibrary() end
end

function BuildTabs()
  ui.tabs = {}
  local t1 = MakeButton(ui, L.tabLibrary, 190, function() SetTab(1) end)
  t1:SetPoint("TOPLEFT", 18, -30)
  local t2 = MakeButton(ui, L.tabBuilder, 190, function() SetTab(2) end)
  t2:SetPoint("LEFT", t1, "RIGHT", 6, 0)
  ui.tabs = { t1, t2 }
end

----------------------------------------------------------------------
-- Tutoriel
----------------------------------------------------------------------
function ns.RunTour()
  if not ui then return end
  ns.StartTour({
    { target = function() return ui.tabs[1] end, title = L.t1t, text = L.t1, before = function() SetTab(1) end },
    { target = function() return ui.classBtn end, title = L.t2t, text = L.t2 },
    { target = function() return ui.libRows[1].create end, title = L.t3t, text = L.t3 },
    { target = function() return ui.tabs[2] end, title = L.t4t, text = L.t4 },
    { target = function() return ui.editorBox end, title = L.t5t, text = L.t5 },
    { target = function() return ui.saveBtn end, title = L.t6t, text = L.t6 },
    { target = function() return ns.minimapButton end, title = L.t7t, text = L.t7 },
    { target = function() return ui.helpBtn end, title = L.t8t, text = L.t8 },
  }, function() db.tourDone = true end)
end

----------------------------------------------------------------------
-- Bouton de minicarte
----------------------------------------------------------------------
local mmb
local function PlaceMinimapButton()
  local a = math.rad(db.minimap.angle or 190)
  local r = (Minimap:GetWidth() / 2) + 10
  mmb:ClearAllPoints()
  mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local dbi
local function UpdateMinimapButton()
  if not mmb then return end
  if dbi then mmb:Hide() return end
  mmb:SetShown(not db.minimap.hide)
  PlaceMinimapButton()
end

local function CreateMinimapButton()
  if not Minimap then return end
  mmb = CreateFrame("Button", "ForeverMacrosMinimapButton", Minimap)
  ns.minimapButton = mmb
  mmb:SetSize(31, 31)
  mmb:SetFrameStrata("MEDIUM")
  mmb:SetFrameLevel(8)
  mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmb:RegisterForDrag("LeftButton")
  mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = mmb:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  local border = mmb:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mmb:SetScript("OnClick", function() ns.Toggle() end)
  mmb:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      PlaceMinimapButton()
    end)
  end)
  mmb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mmb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ForeverMacros", 1, 0.82, 0)
    GameTooltip:AddLine(L.minimapTip1, 1, 1, 1)
    GameTooltip:AddLine(L.minimapTip3, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UpdateMinimapButton()
end


----------------------------------------------------------------------
-- Fenêtre de texte et sauvegarde de toutes les macros
----------------------------------------------------------------------
local tw
function ShowText(title, text, onAccept)
  if not tw then
    tw = CreateFrame("Frame", "ForeverMacrosTextFrame", UIParent, "BasicFrameTemplateWithInset")
    tw:SetSize(600, 400)
    tw:SetPoint("CENTER", 60, -30)
    tw:SetFrameStrata("FULLSCREEN")
    tw:SetMovable(true)
    tw:SetClampedToScreen(true)
    tw:EnableMouse(true)
    tw:RegisterForDrag("LeftButton")
    tw:SetScript("OnDragStart", tw.StartMoving)
    tw:SetScript("OnDragStop", tw.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverMacrosTextFrame")
    tw.title = tw:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tw.title:SetPoint("TOPLEFT", 12, -6)
    tw.title:SetPoint("RIGHT", -30, 0)
    tw.title:SetJustifyH("LEFT")
    local sf = CreateFrame("ScrollFrame", nil, tw, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -32)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(540)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
    tw.edit = eb
    tw.ok = MakeButton(tw, L.ok, 110, function()
      if tw.onAccept then tw.onAccept(eb:GetText()) end
      tw:Hide()
    end)
    tw.ok:SetPoint("BOTTOMRIGHT", -14, 12)
    tw.close = MakeButton(tw, L.close, 110, function() tw:Hide() end)
    tw.close:SetPoint("RIGHT", tw.ok, "LEFT", -6, 0)
  end
  tw.title:SetText(title)
  tw.edit:SetText(text or "")
  tw.onAccept = onAccept
  tw.ok:SetShown(onAccept ~= nil)
  tw:Show()
  tw.edit:SetFocus()
  if not onAccept then tw.edit:HighlightText() end
end

local function Escape(body) return (body:gsub("\\", "\\\\"):gsub("\n", "\\n")) end
local function Unescape(body)
  return (body:gsub("\\(.)", function(c) if c == "n" then return "\n" end return c end))
end

function BackupAll()
  local lines = { "FMAC1" }
  local g, c = GetNumMacros()
  for i = 1, g do
    local name, _, body = GetMacroInfo(i)
    if name then lines[#lines + 1] = "M:g:" .. name .. "=" .. Escape(body or "") end
  end
  for i = 1, c do
    local name, _, body = GetMacroInfo(MAX_ACCOUNT + i)
    if name then lines[#lines + 1] = "M:c:" .. name .. "=" .. Escape(body or "") end
  end
  ShowText(L.backupTitle, table.concat(lines, "\n"))
end

function RestoreFrom(text)
  if InCombatLockdown() then return Print(L.inCombat) end
  text = text or ""
  if not text:match("^%s*FMAC1") then return Print(L.restoreBad) end
  local created, updated, skipped = 0, 0, 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local scope, name, body = line:match("^M:([gc]):(.-)=(.*)$")
    if scope and name ~= "" then
      body = Unescape(body)
      local existing = GetMacroIndexByName(name)
      if existing and existing > 0 then
        EditMacro(existing, name, nil, body)
        updated = updated + 1
      else
        local g, c = GetNumMacros()
        local perChar = scope == "c"
        if (perChar and c >= MAX_CHAR) or (not perChar and g >= MAX_ACCOUNT) then
          skipped = skipped + 1
        else
          local ok, idx = pcall(CreateMacro, name, QUESTION_ICON, body, perChar)
          if ok and idx then created = created + 1 else skipped = skipped + 1 end
        end
      end
    end
  end
  Print(L.restored, created, updated, skipped)
  UpdateStatus()
end

local function CreateUI()
  ui = CreateFrame("Frame", "ForeverMacrosFrame", UIParent, "BasicFrameTemplateWithInset")
  ui:SetSize(860, 600)
  ui:SetPoint("CENTER")
  ui:SetFrameStrata("DIALOG")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  ui:SetScript("OnHide", HideMenu)
  ui:Hide()
  tinsert(UISpecialFrames, "ForeverMacrosFrame")

  local title = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -6)
  title:SetText(L.title)

  local sep = ui:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.12)
  sep:SetPoint("TOPLEFT", 430, -34)
  sep:SetSize(1, 540)

  ----------------------------------------------------------------
  -- Constructeur (gauche)
  ----------------------------------------------------------------
  local bp = CreateFrame("Frame", nil, ui)
  bp:SetPoint("TOPLEFT", 0, -50)
  bp:SetSize(430, 560)
  ui.builderPanel = bp
  ui.simpleWidgets, ui.seqWidgets = {}, {}
  local function S(w) ui.simpleWidgets[#ui.simpleWidgets + 1] = w; return w end
  local function Q(w) ui.seqWidgets[#ui.seqWidgets + 1] = w; return w end
  local function SC(cb) S(cb); S(cb.label); return cb end
  local function QC(cb) Q(cb); Q(cb.label); return cb end

  local bHint = bp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  bHint:SetPoint("TOPLEFT", 18, -6)
  bHint:SetWidth(396)
  bHint:SetJustifyH("LEFT")
  bHint:SetText(L.builderHint)
  Label(bp, L.mode, 200, -40, "GameFontHighlight")
  ui.modeBtn = MakeButton(bp, "", 130, function(self)
    OpenMenu(self, {
      { text = L.mode_simple, value = "simple", checked = db.builder.mode ~= "seq" },
      { text = L.mode_seq, value = "seq", checked = db.builder.mode == "seq" },
    }, function(v) db.builder.mode = v; RefreshBuilder() end)
  end)
  ui.modeBtn:SetPoint("TOPLEFT", 260, -36)

  Label(bp, L.template, 18, -66)
  local tplBtn = MakeButton(bp, L.templatePick, 290, nil)
  tplBtn:SetPoint("TOPLEFT", 120, -62)
  ui.tplDesc = bp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.tplDesc:SetPoint("TOPLEFT", 120, -88)
  ui.tplDesc:SetWidth(290)
  ui.tplDesc:SetJustifyH("LEFT")

  -- Mode simple
  S(Label(bp, L.spell, 18, -122))
  ui.spellBox = S(MakeSpellBox(bp, 280))
  ui.spellBox:SetPoint("TOPLEFT", 126, -118)
  local drag = S(bp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
  drag:SetPoint("TOPLEFT", 120, -142)
  drag:SetWidth(290)
  drag:SetJustifyH("LEFT")
  drag:SetText(L.dragHint)

  S(Label(bp, L.action, 18, -170))
  ui.actionBtn = S(MakeButton(bp, "", 200, function(self)
    OpenMenu(self, {
      { text = L.act_cast, value = "/cast", checked = db.builder.action == "/cast" },
      { text = L.act_use, value = "/use", checked = db.builder.action == "/use" },
    }, function(v) db.builder.action = v; RefreshBuilder() end)
  end))
  ui.actionBtn:SetPoint("TOPLEFT", 120, -166)

  S(Label(bp, L.target, 18, -202))
  ui.targetBtn = S(MakeButton(bp, "", 290, function(self)
    local items = {}
    for i, t in ipairs(ns.Targets) do items[#items + 1] = { text = L[t.key], value = i, checked = db.builder.target == i } end
    OpenMenu(self, items, function(v) db.builder.target = v; RefreshBuilder() end)
  end))
  ui.targetBtn:SetPoint("TOPLEFT", 120, -198)
  ui.fallback = SC(MakeCheck(bp, L.fallback, 116, -224, "fallback"))

  S(Label(bp, L.modifier, 18, -262))
  ui.modBtn = S(MakeButton(bp, "", 80, function(self)
    OpenMenu(self, {
      { text = L.m_shift, value = "shift", checked = db.builder.mod == "shift" },
      { text = L.m_ctrl, value = "ctrl", checked = db.builder.mod == "ctrl" },
      { text = L.m_alt, value = "alt", checked = db.builder.mod == "alt" },
    }, function(v) db.builder.mod = v; RefreshBuilder() end)
  end))
  ui.modBtn:SetPoint("TOPLEFT", 140, -258)
  S(Label(bp, L.altSpell, 18, -292, "GameFontHighlightSmall"))
  ui.altBox = S(MakeSpellBox(bp, 230))
  ui.altBox:SetPoint("TOPLEFT", 176, -288)

  -- Mode séquence
  Q(Label(bp, L.seqSpells, 18, -118))
  local seqHint = Q(bp:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
  seqHint:SetPoint("TOPLEFT", 18, -134)
  seqHint:SetWidth(400)
  seqHint:SetJustifyH("LEFT")
  seqHint:SetText(L.seqHint)
  ui.seqBoxes = {}
  for i = 1, 6 do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local x, y = 18 + col * 205, -166 - row * 26
    Q(Label(bp, i .. ".", x, y - 4, "GameFontHighlightSmall"))
    local box = Q(MakeSpellBox(bp, 172))
    box:SetPoint("TOPLEFT", x + 22, y)
    ui.seqBoxes[i] = box
  end

  Q(Label(bp, L.seqReset, 18, -250))
  local cbDelay = QC(MakeCheck(bp, L.seqDelay, 14, -268, "seqUseDelay"))
  ui.delayBox = Q(CreateFrame("EditBox", nil, bp, "InputBoxTemplate"))
  ui.delayBox:SetSize(32, 20)
  ui.delayBox:SetPoint("LEFT", cbDelay.label, "RIGHT", 8, 0)
  ui.delayBox:SetAutoFocus(false)
  ui.delayBox:SetNumeric(true)
  ui.delayBox:SetMaxLetters(3)
  ui.delayBox:SetScript("OnTextChanged", function(self) db.builder.seqDelayValue = tonumber(self:GetText()) end)
  ui.delayBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  local secs = Q(bp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
  secs:SetPoint("LEFT", ui.delayBox, "RIGHT", 4, 0)
  secs:SetText(L.seqSeconds)
  QC(MakeCheck(bp, L.seqCombat, 230, -268, "seqCombat"))
  QC(MakeCheck(bp, L.seqTarget, 14, -292, "seqTarget"))
  Q(Label(bp, L.seqRestart, 230, -298, "GameFontHighlightSmall"))
  QC(MakeCheck(bp, L.m_shift, 230, -312, "seqShift"))
  QC(MakeCheck(bp, L.m_ctrl, 290, -312, "seqCtrl"))
  QC(MakeCheck(bp, L.m_alt, 350, -312, "seqAlt"))

  local function SeqSpells()
    local t = {}
    for i = 1, 6 do t[i] = ui.seqBoxes[i]:GetText() end
    return t
  end
  local function BuildSeq()
    local b = db.builder
    b.seqDelay = b.seqUseDelay and b.seqDelayValue or nil
    return ns.BuildSequence(SeqSpells())
  end

  tplBtn:SetScript("OnClick", function(self)
    local items = {}
    for i, t in ipairs(ns.Templates) do items[#items + 1] = { text = ns.Pick(t.label, t.label_en), value = i } end
    OpenMenu(self, items, function(i)
      local t = ns.Templates[i]
      self:SetText(ns.Pick(t.label, t.label_en))
      ui.tplDesc:SetText(ns.Pick(t.desc, t.desc_en))
      if t.mode == "seq" then
        local b = db.builder
        b.mode, b.seqUseDelay, b.seqDelayValue, b.seqCombat = "seq", true, t.delay or 15, true
        ui.delayBox:SetText(tostring(b.seqDelayValue))
        RefreshBuilder()
        ui.body:SetText(BuildSeq())
      else
        if db.builder.mode == "seq" then db.builder.mode = "simple"; RefreshBuilder() end
        ui.body:SetText(ns.FillTemplate(t, ui.spellBox:GetText(), ui.altBox:GetText()))
      end
    end)
  end)

  -- Options communes
  MakeCheck(bp, L.optTooltip, 14, -346, "tooltip")
  MakeCheck(bp, L.optStop, 14, -370, "stop")
  MakeCheck(bp, L.optAttack, 14, -394, "attack")

  local gen = MakeButton(bp, L.generate, 250, function()
    local first
    if db.builder.mode == "seq" then
      ui.body:SetText(BuildSeq())
      first = Trim(ui.seqBoxes[1]:GetText())
    else
      ui.body:SetText(ns.Build(ui.spellBox:GetText(), ui.altBox:GetText()))
      first = Trim(ui.spellBox:GetText())
    end
    if Trim(ui.nameBox:GetText()) == "" and first ~= "" then ui.nameBox:SetText(first) end
  end)
  gen:SetPoint("TOPLEFT", 90, -434)

  BuildLibrary(ui)
  BuildTabs()

  ----------------------------------------------------------------
  -- Éditeur (droite)
  ----------------------------------------------------------------
  Label(ui, L.editor, 448, -34, "GameFontNormalLarge")
  local eHint = ui:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  eHint:SetPoint("TOPLEFT", 540, -36)
  eHint:SetWidth(300)
  eHint:SetJustifyH("LEFT")
  eHint:SetText(L.editorHint)
  ui.status = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.status:SetPoint("TOPRIGHT", -34, -38)

  local macrosBtn = MakeButton(ui, L.macros, 160, function(self)
    OpenMenu(self, MacroItems(), LoadMacro)
  end)
  macrosBtn:SetPoint("TOPLEFT", 448, -62)

  Label(ui, L.name, 448, -100)
  ui.nameBox = CreateFrame("EditBox", nil, ui, "InputBoxTemplate")
  ui.nameBox:SetSize(160, 20)
  ui.nameBox:SetPoint("TOPLEFT", 500, -96)
  ui.nameBox:SetAutoFocus(false)
  ui.nameBox:SetMaxLetters(16)
  ui.nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  ui.nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  Label(ui, L.scope, 680, -100)
  ui.scopeBtn = MakeButton(ui, "", 100, function(self)
    OpenMenu(self, {
      { text = L.general, value = false, checked = not st.perChar },
      { text = L.character, value = true, checked = st.perChar },
    }, function(v) st.perChar = v; UpdateStatus() end)
  end)
  ui.scopeBtn:SetPoint("TOPLEFT", 740, -96)

  local box = CreateFrame("Frame", nil, ui, "BackdropTemplate")
  ui.editorBox = box
  box:SetPoint("TOPLEFT", 446, -126)
  box:SetSize(398, 190)
  box:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(0, 0, 0, 0.6)
  local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 8, -8)
  sf:SetPoint("BOTTOMRIGHT", -28, 8)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetFontObject(ChatFontNormal)
  eb:SetWidth(356)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnTextChanged", UpdateChecks)
  sf:SetScrollChild(eb)
  sf:EnableMouse(true)
  sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
  ui.body = eb

  ui.count = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.count:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -4, -4)

  Label(ui, L.checks, 448, -340)
  ui.checks = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.checks:SetPoint("TOPLEFT", 448, -360)
  ui.checks:SetWidth(396)
  ui.checks:SetJustifyH("LEFT")
  ui.checks:SetJustifyV("TOP")

  local saveBtn = MakeButton(ui, L.save, 120, Save)
  ui.saveBtn = saveBtn
  saveBtn:SetPoint("BOTTOMLEFT", 448, 16)
  ui.placeBtn = MakeButton(ui, L.place, 140, Place)
  ui.placeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
  ui.delBtn = MakeButton(ui, L.delete, 110, function()
    if st.editIndex then
      local name = GetMacroInfo(st.editIndex)
      StaticPopup_Show("FOREVERMACROS_DELETE", name, nil, st.editIndex)
    end
  end)
  ui.delBtn:SetPoint("LEFT", ui.placeBtn, "RIGHT", 6, 0)

  ui.helpBtn = MakeButton(ui, "?", 24, function() ns.RunTour() end)
  ui.helpBtn:SetPoint("TOPRIGHT", -28, -2)
  ui.helpBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(L.helpTip); GameTooltip:Show()
  end)
  ui.helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  ui:HookScript("OnHide", function() if ns.TourShown() then ns.EndTour() end end)

  ui:SetScript("OnShow", function()
    SetTab(db.tab or 1)
    if not db.tourDone then C_Timer.After(0.2, function() if ui:IsShown() then ns.RunTour() end end) end
    ui.delayBox:SetText(tostring(db.builder.seqDelayValue or 15))
    RefreshBuilder()
    UpdateStatus()
    UpdateChecks()
  end)
end

function ns.Toggle()
  if not ui then CreateUI() end
  ui:SetShown(not ui:IsShown())
end

----------------------------------------------------------------------
-- Bouton dans la fenêtre de macros de Blizzard
----------------------------------------------------------------------
local hooked
local function HookMacroFrame()
  if hooked or not MacroFrame then return end
  hooked = true
  local b = MakeButton(MacroFrame, L.openFromMacro, 90, function()
    if not ui then CreateUI() end
    ui:Show()
  end)
  b:SetPoint("TOPRIGHT", MacroFrame, "TOPRIGHT", -30, -26)
  b:SetFrameLevel(MacroFrame:GetFrameLevel() + 10)
end

local function SetupBroker()
  local LS = _G.LibStub
  local LDB = LS and LS("LibDataBroker-1.1", true)
  if not LDB then return end
  local obj = LDB:NewDataObject("ForeverMacros", {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    OnClick = function() ns.Toggle() end,
    OnTooltipShow = function(tt)
      tt:AddLine("ForeverMacros", 1, 0.82, 0)
      tt:AddLine(L.minimapTip1, 1, 1, 1)
    end,
  })
  local DBI = LS("LibDBIcon-1.0", true)
  if obj and DBI then
    db.ldbIcon = db.ldbIcon or { hide = db.minimap.hide }
    DBI:Register("ForeverMacros", obj, db.ldbIcon)
    dbi = DBI
    if mmb then mmb:Hide() end
    ns.minimapButton = DBI.GetMinimapButton and DBI:GetMinimapButton("ForeverMacros") or ns.minimapButton
  end
end

----------------------------------------------------------------------
-- Commandes, compartiment, événements
----------------------------------------------------------------------
SLASH_FOREVERMACROS1 = "/fmac"
SLASH_FOREVERMACROS2 = "/forevermacros"
SlashCmdList.FOREVERMACROS = function(msg)
  msg = Trim(msg):lower()
  if msg == "minimap" then
    db.minimap.hide = not db.minimap.hide
    if dbi then
      db.ldbIcon.hide = db.minimap.hide
      if db.minimap.hide then dbi:Hide("ForeverMacros") else dbi:Show("ForeverMacros") end
    end
    UpdateMinimapButton()
    Print(db.minimap.hide and L.minimapHidden or L.minimapShown)
  elseif msg == "tuto" or msg == "tutorial" then
    if not ui then CreateUI() end
    ui:Show()
    ns.RunTour()
  elseif msg == "help" or msg == "?" then
    Print(L.help)
  else
    ns.Toggle()
  end
end

function ForeverMacros_OnCompartmentClick() ns.Toggle() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" then
    SetupBroker()
  elseif name == ADDON then
    ForeverMacrosDB = ForeverMacrosDB or {}
    db = ForeverMacrosDB
    db.builder = db.builder or {}
    local b = db.builder
    b.action = b.action or "/cast"
    b.target = b.target or 2
    b.mod = b.mod or "shift"
    if b.fallback == nil then b.fallback = true end
    if b.tooltip == nil then b.tooltip = true end
    b.mode = b.mode or "simple"
    if b.seqUseDelay == nil then b.seqUseDelay = true end
    if b.seqCombat == nil then b.seqCombat = true end
    b.seqDelayValue = b.seqDelayValue or 15
    if db.lang then ns.lang = db.lang end
    db.version = db.version or 2
    db.minimap = db.minimap or { angle = 190, hide = false }
    db.libClass = db.libClass or select(2, UnitClass("player"))
    if not ns.Library[db.libClass] then db.libClass = "WARRIOR" end
    CreateMinimapButton()

    StaticPopupDialogs["FOREVERMACROS_DELETE"] = {
      text = L.deleteConfirm, button1 = YES, button2 = NO,
      OnAccept = function(_, idx)
        if InCombatLockdown() then return Print(L.inCombat) end
        local n = GetMacroInfo(idx)
        DeleteMacro(idx)
        Print(L.deleted, tostring(n))
        st.editIndex = nil
        if ui then ui.nameBox:SetText(""); ui.body:SetText(""); UpdateStatus() end
      end,
      timeout = 0, whileDead = true, hideOnEscape = true,
    }

    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_MacroUI"))
      or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_MacroUI"))
    if loaded then HookMacroFrame() end
  elseif name == "Blizzard_MacroUI" then
    HookMacroFrame()
  end
end)
