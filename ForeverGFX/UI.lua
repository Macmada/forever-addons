local _, ns = ...
local L = ns.L

local ROW_H, VISIBLE = 54, 8
local W, H = 940, 84 + 8 * 54 + 124
local FAV = "__FAV__"
local ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"

local ui
local offset = 0
local entries, filtered, display = {}, {}, {}
local state = { search = "", modifiedOnly = false, allCategories = false }

----------------------------------------------------------------------
-- Petits constructeurs
----------------------------------------------------------------------
local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Tip(frame, title, text)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 1, 0.82, 0)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MakeCheck(parent, label, x, y, get, set, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  fs:SetText(label)
  cb:SetChecked(get())
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  if tip then Tip(cb, label, tip) end
  return cb
end

local function MakeSlider(parent, width)
  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 16)
  s:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = s:GetThumbTexture()
  if thumb then thumb:SetSize(32, 32) end
  s:SetObeyStepOnDrag(true)
  return s
end

----------------------------------------------------------------------
-- Menu déroulant maison (indépendant des API de menus qui changent)
----------------------------------------------------------------------
local menu, catcher

local function HideMenu()
  if menu then menu:Hide() end
  if catcher then catcher:Hide() end
end

function ns.OpenMenu(anchor, items, onSelect)
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

----------------------------------------------------------------------
-- Fenêtre de texte (export, import, comparaison, historique, mesures)
----------------------------------------------------------------------
local tw
function ns.ShowText(title, text, onAccept)
  if not tw then
    tw = CreateFrame("Frame", "ForeverGFXTextFrame", UIParent, "BasicFrameTemplateWithInset")
    tw:SetSize(600, 400)
    tw:SetPoint("CENTER", 60, -30)
    tw:SetFrameStrata("FULLSCREEN")
    tw:SetMovable(true)
    tw:SetClampedToScreen(true)
    tw:EnableMouse(true)
    tw:RegisterForDrag("LeftButton")
    tw:SetScript("OnDragStart", tw.StartMoving)
    tw:SetScript("OnDragStop", tw.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverGFXTextFrame")

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

function ns.ShowBenchResults()
  local lines = {}
  for _, r in ipairs(ns.db.bench) do
    lines[#lines + 1] = r.time .. "  " .. string.format(L.benchResult, r.label, r.avg, r.low, r.min, r.zone)
  end
  ns.ShowText(L.benchTitle, #lines > 0 and table.concat(lines, "\n") or L.benchEmpty)
end

local function ShowHistory()
  local lines = {}
  for i = #ns.history, 1, -1 do
    local b = ns.history[i]
    lines[#lines + 1] = date("%H:%M:%S", b.time) .. "  " .. b.label .. "  (" .. #b.changes .. ")"
    for _, c in ipairs(b.changes) do
      lines[#lines + 1] = "      " .. c.name .. " : " .. tostring(c.old) .. " » " .. tostring(c.new)
    end
  end
  ns.ShowText(L.historyTitle, #lines > 0 and table.concat(lines, "\n") or L.historyEmpty)
end

----------------------------------------------------------------------
-- Fenêtre de bascule automatique
----------------------------------------------------------------------
local cw
local function TargetItems(current)
  local items = { { text = L.ctxNone, value = "", checked = (current or "") == "" } }
  for _, p in ipairs(ns.Presets) do
    local v = "preset:" .. p.key
    items[#items + 1] = { text = string.format(L.presetPrefix, ns.PresetLabel(p)), value = v, checked = current == v }
  end
  for _, n in ipairs(ns.ProfileNames()) do
    local v = "profile:" .. n
    items[#items + 1] = { text = string.format(L.profilePrefix, n), value = v, checked = current == v }
  end
  return items
end

function ns.ShowContext()
  if not cw then
    cw = CreateFrame("Frame", "ForeverGFXContextFrame", UIParent, "BasicFrameTemplateWithInset")
    cw:SetSize(480, 300)
    cw:SetPoint("CENTER", 40, 40)
    cw:SetFrameStrata("FULLSCREEN")
    cw:SetMovable(true)
    cw:SetClampedToScreen(true)
    cw:EnableMouse(true)
    cw:RegisterForDrag("LeftButton")
    cw:SetScript("OnDragStart", cw.StartMoving)
    cw:SetScript("OnDragStop", cw.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverGFXContextFrame")

    local title = cw:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText(L.ctxTitle)

    MakeCheck(cw, L.ctxEnable, 16, -32,
      function() return ns.db.context.enabled end,
      function(v)
        ns.db.context.enabled = v
        ns.CheckContext(true)
        cw.Update()
        if ns.UpdateSimple then ns.UpdateSimple() end
      end)

    local hint = cw:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 20, -60)
    hint:SetWidth(440)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.ctxHint)

    cw.buttons = {}
    for i, ctx in ipairs(ns.CONTEXTS) do
      local y = -96 - (i - 1) * 32
      local fs = cw:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetPoint("TOPLEFT", 22, y - 4)
      fs:SetText(L["ctx_" .. ctx])
      local b = MakeButton(cw, "", 230, nil)
      b:SetPoint("TOPLEFT", 220, y)
      b:SetScript("OnClick", function(self)
        ns.OpenMenu(self, TargetItems(ns.db.context.map[ctx]), function(v)
          ns.db.context.map[ctx] = (v ~= "") and v or nil
          cw.Update()
          ns.CheckContext(true)
        end)
      end)
      cw.buttons[ctx] = b
    end

    cw.current = cw:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cw.current:SetPoint("BOTTOMLEFT", 20, 16)

    function cw.Update()
      for ctx, b in pairs(cw.buttons) do b:SetText(ns.TargetLabel(ns.db.context.map[ctx])) end
      cw.current:SetText(string.format(L.ctxCurrent, L["ctx_" .. ns.GetContext()]))
    end
    cw:SetScript("OnShow", cw.Update)
  end
  cw:Show()
  cw.Update()
end

----------------------------------------------------------------------
-- Liste des variables
----------------------------------------------------------------------
local function BuildEntries()
  wipe(entries)
  local seen = {}
  local cmds = {}
  if ns.GetAllCommands then
    local ok, res = pcall(ns.GetAllCommands)
    if ok and type(res) == "table" then cmds = res end
  end
  local function add(name, help)
    local value, _, locked, readOnly = ns.Info(name)
    if value ~= nil and not locked and not readOnly then
      local e = { name = name, help = help, meta = ns.Meta(name), cat = ns.CatOf(name) }
      -- Texte de recherche précalculé une fois (évite de tout recalculer à chaque frappe)
      e.search = (name .. " " .. ns.CatName(e.cat) .. " " .. ns.Describe(e) .. " " .. (help or "")):lower()
      entries[#entries + 1] = e
      seen[name:lower()] = true
    end
  end
  for _, c in ipairs(cmds) do
    local name = c.command
    if name and c.commandType == ns.TYPE_CVAR
       and (state.allCategories or c.category == ns.CAT_GRAPHICS or ns.Meta(name)) then
      add(name, c.help)
    end
  end
  for key in pairs(ns.Descriptions) do
    if not seen[key:lower()] then add(key) end
  end
  table.sort(entries, function(a, b)
    local ra, rb = ns.CAT_RANK[a.cat] or 99, ns.CAT_RANK[b.cat] or 99
    if ra ~= rb then return ra < rb end
    return a.name:lower() < b.name:lower()
  end)
end

local function Refilter()
  wipe(filtered)
  wipe(display)
  local s = state.search:lower()
  local db = ns.db
  for _, e in ipairs(entries) do
    local ok = s == "" or e.search:find(s, 1, true)
    if ok and state.modifiedOnly then
      -- On n'interroge le jeu que si le filtre « modifiées » est actif
      local value, default = ns.Info(e.name)
      ok = value ~= nil and not ns.Same(value, default)
    end
    if ok then filtered[#filtered + 1] = e end
  end
  local forceOpen = s ~= "" or state.modifiedOnly

  local function section(cat, list)
    if #list == 0 then return end
    local collapsed = not forceOpen and db.collapsed[cat] and true or false
    display[#display + 1] = { header = cat, count = #list, collapsed = collapsed }
    if not collapsed then
      for _, e in ipairs(list) do display[#display + 1] = e end
    end
  end

  local favs = {}
  for _, e in ipairs(filtered) do if db.favorites[e.name] then favs[#favs + 1] = e end end
  section(FAV, favs)

  local i = 1
  while i <= #filtered do
    local cat, group = filtered[i].cat, {}
    while i <= #filtered and filtered[i].cat == cat do
      group[#group + 1] = filtered[i]
      i = i + 1
    end
    section(cat, group)
  end
end

local function Kind(e, value)
  local m = e.meta
  if m and m.values then return "dd" end
  if m and m.range then
    if m.range[1] == 0 and m.range[2] == 1 and m.range[3] == 1 then return "check" end
    return "slider"
  end
  if tonumber(value) then return "step" end
  return "none"
end

local function Snap(v, step)
  return math.floor(v / step + 0.5) * step
end

local function StepValue(row, dir)
  local e = row.entry
  local value = e and tonumber(ns.GetCVar(e.name))
  if not value then return end
  ns.ChangeFromUI(e.name, ns.FormatNum(value + dir))
end

local function CreateRow(parent, i)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row:SetPoint("RIGHT")
  row:EnableMouse(true)
  row:EnableMouseWheel(true)

  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)

  -- En-tête de catégorie
  row.hdrBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.hdrBg:SetPoint("TOPLEFT", 0, -12)
  row.hdrBg:SetPoint("BOTTOMRIGHT", 0, 4)
  row.hdrBg:SetColorTexture(0.25, 0.45, 0.85, 0.25)
  row.hdr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  row.hdr:SetPoint("LEFT", 10, -4)
  row:SetScript("OnMouseDown", function(self)
    if self.headerCat then
      ns.db.collapsed[self.headerCat] = (not ns.db.collapsed[self.headerCat]) or nil
      ns.Refresh(true)
    end
  end)

  -- Favori
  row.star = CreateFrame("Button", nil, row)
  row.star:SetSize(16, 16)
  row.star:SetPoint("TOPLEFT", 6, -4)
  row.star.tex = row.star:CreateTexture(nil, "ARTWORK")
  row.star.tex:SetAllPoints()
  row.star.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
  row.star:SetScript("OnClick", function()
    local e = row.entry
    if not e then return end
    ns.db.favorites[e.name] = (not ns.db.favorites[e.name]) or nil
    ns.Refresh(true)
  end)
  Tip(row.star, L.favTip)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.name:SetPoint("LEFT", row.star, "RIGHT", 6, 0)

  row.def = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.def:SetPoint("TOPRIGHT", -8, -6)

  row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.desc:SetPoint("TOPLEFT", 6, -22)
  row.desc:SetWidth(470)
  row.desc:SetHeight(28)
  row.desc:SetJustifyH("LEFT")
  row.desc:SetJustifyV("TOP")
  row.desc:SetWordWrap(true)
  if row.desc.SetMaxLines then row.desc:SetMaxLines(2) end

  -- Contrôles (de droite à gauche)
  row.reset = MakeButton(row, L.default, 62, function()
    local e = row.entry
    if not e then return end
    local _, default = ns.Info(e.name)
    if default ~= nil then ns.ChangeFromUI(e.name, default) end
  end)
  row.reset:SetPoint("BOTTOMRIGHT", -6, 6)

  row.edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  row.edit:SetSize(64, 20)
  row.edit:SetPoint("RIGHT", row.reset, "LEFT", -8, 0)
  row.edit:SetAutoFocus(false)
  row.edit:SetJustifyH("CENTER")
  row.edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    if row.entry then ns.ChangeFromUI(row.entry.name, self:GetText()) end
  end)
  row.edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    if row.entry then self:SetText(ns.GetCVar(row.entry.name) or "") end
  end)

  row.plus = MakeButton(row, "+", 22, function() StepValue(row, 1) end)
  row.plus:SetPoint("RIGHT", row.edit, "LEFT", -8, 0)
  row.minus = MakeButton(row, "-", 22, function() StepValue(row, -1) end)
  row.minus:SetPoint("RIGHT", row.plus, "LEFT", -2, 0)

  row.slider = MakeSlider(row, 160)
  row.slider:SetPoint("RIGHT", row.edit, "LEFT", -10, 0)
  row.slider:SetScript("OnValueChanged", function(self, v)
    if self.updating or not row.entry then return end
    local r = row.entry.meta.range
    row.edit:SetText(ns.FormatNum(Snap(v, r[3])))
    self.dirty = true
  end)
  row.slider:SetScript("OnMouseUp", function(self)
    if self.dirty and row.entry then
      self.dirty = false
      local r = row.entry.meta.range
      ns.ChangeFromUI(row.entry.name, ns.FormatNum(Snap(self:GetValue(), r[3])))
    end
  end)

  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetPoint("RIGHT", row.edit, "LEFT", -10, 0)
  row.check:SetScript("OnClick", function(self)
    if row.entry then ns.ChangeFromUI(row.entry.name, self:GetChecked() and 1 or 0) end
  end)

  row.dd = MakeButton(row, "", 150, function(self)
    local e = row.entry
    if not e then return end
    local cur = tonumber(ns.GetCVar(e.name))
    local keys = {}
    for k in pairs(e.meta.values) do keys[#keys + 1] = k end
    table.sort(keys)
    local items = {}
    for _, k in ipairs(keys) do
      items[#items + 1] = { text = k .. " — " .. ns.ValueLabel(e.meta, k), value = k, checked = cur == k }
    end
    ns.OpenMenu(self, items, function(v) ns.ChangeFromUI(e.name, v) end)
  end)
  row.dd:SetPoint("RIGHT", row.edit, "LEFT", -10, 0)

  row:SetScript("OnEnter", function(self)
    local e = self.entry
    if not e then return end
    local value, default = ns.Info(e.name)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:AddLine(e.name, 1, 0.82, 0)
    if e.meta and e.meta.desc then GameTooltip:AddLine(ns.Pick(e.meta.desc, e.meta.en), 1, 1, 1, true) end
    if e.help and e.help ~= "" then GameTooltip:AddLine(L.gameHelp .. e.help, 0.6, 0.8, 1, true) end
    GameTooltip:AddDoubleLine(L.current, ns.ValueLabel(e.meta, value), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.default, ns.ValueLabel(e.meta, default), 0.7, 0.7, 0.7, 1, 1, 1)
    local r = e.meta and e.meta.range
    if r then
      GameTooltip:AddDoubleLine(L.range, string.format(L.rangeTo, ns.FormatNum(r[1]), ns.FormatNum(r[2])),
        0.7, 0.7, 0.7, 1, 1, 1)
    end
    if ns.db.overrides[e.name] then GameTooltip:AddLine(L.reappliedTip, 0.4, 1, 0.4) end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnMouseWheel", function(_, delta)
    ui.slider:SetValue(ui.slider:GetValue() - delta * 2)
  end)
  return row
end

local CONTROLS = { "slider", "check", "dd", "plus", "minus" }

local function ShowOnly(row, kind)
  row.slider:SetShown(kind == "slider")
  row.check:SetShown(kind == "check")
  row.dd:SetShown(kind == "dd")
  row.plus:SetShown(kind == "step")
  row.minus:SetShown(kind == "step")
end

local function SetHeaderMode(row, on)
  row.hdr:SetShown(on)
  row.hdrBg:SetShown(on)
  for _, k in ipairs({ "star", "name", "def", "desc", "edit", "reset" }) do row[k]:SetShown(not on) end
  if on then for _, k in ipairs(CONTROLS) do row[k]:Hide() end end
end

local function FillRow(row, e)
  local value, default = ns.Info(e.name)
  local modified = not ns.Same(value, default)
  local fav = ns.db.favorites[e.name]
  row.star.tex:SetDesaturated(not fav)
  row.star.tex:SetAlpha(fav and 1 or 0.3)
  row.name:SetText((modified and "|cffff9933" or "|cffffd100") .. e.name .. "|r")
  row.def:SetText(string.format(L.defaultFmt, ns.ValueLabel(e.meta, default)))
  row.desc:SetText(ns.Describe(e))
  if not row.edit:HasFocus() then row.edit:SetText(tostring(value or "")) end
  row.reset:SetEnabled(modified)

  local kind = Kind(e, value)
  ShowOnly(row, kind)
  if kind == "slider" then
    local r = e.meta.range
    local v = tonumber(value) or r[1]
    local s = row.slider
    s.updating = true
    s:SetMinMaxValues(math.min(r[1], v), math.max(r[2], v))
    s:SetValueStep(r[3])
    s:SetValue(v)
    s.updating = false
    s.dirty = false
  elseif kind == "check" then
    row.check:SetChecked(tonumber(value) == 1)
  elseif kind == "dd" then
    row.dd:SetText(ns.ValueLabel(e.meta, value))
  end
end

local function UpdateRows()
  if not ui then return end
  for i = 1, VISIBLE do
    local row = ui.rows[i]
    local item = display[offset + i]
    row.entry, row.headerCat = nil, nil
    if not item then
      row:Hide()
    elseif item.header then
      row.headerCat = item.header
      SetHeaderMode(row, true)
      local name = (item.header == FAV) and L.favorites or ns.CatName(item.header)
      row.hdr:SetText((item.collapsed and "|cffaaaaaa[+]|r  " or "|cffaaaaaa[-]|r  ")
        .. name .. "  |cff888888(" .. item.count .. ")|r")
      row:Show()
    else
      SetHeaderMode(row, false)
      row.entry = item
      FillRow(row, item)
      row:Show()
    end
  end
  ui.slider:SetMinMaxValues(0, math.max(0, #display - VISIBLE))
  ui.count:SetText(string.format(L.count, #filtered, #entries))
end

function ns.Refresh(keepScroll)
  if ns.UpdateSimple then ns.UpdateSimple() end
  if not ui or not ui:IsShown() then return end
  Refilter()
  if not keepScroll then
    offset = 0
    ui.slider:SetValue(0)
  end
  UpdateRows()
end

----------------------------------------------------------------------
-- Fenêtre principale
----------------------------------------------------------------------
local function CreateUI()
  ui = CreateFrame("Frame", "ForeverGFXFrame", UIParent, "BasicFrameTemplateWithInset")
  ui:SetSize(W, H)
  ui:SetPoint("CENTER")
  ui:SetFrameStrata("DIALOG")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  ui:Hide()
  tinsert(UISpecialFrames, "ForeverGFXFrame")

  local title = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -6)
  title:SetText(L.title)

  -- Ligne du haut : recherche et options
  local search = CreateFrame("EditBox", nil, ui, "SearchBoxTemplate")
  search:SetSize(220, 22)
  search:SetPoint("TOPLEFT", 18, -36)
  search:SetAutoFocus(false)
  if search.Instructions then search.Instructions:SetText(L.search) end
  search:HookScript("OnTextChanged", function(self)
    state.search = self:GetText() or ""
    ns.Refresh()
  end)

  MakeCheck(ui, L.modifiedOnly, 256, -35,
    function() return state.modifiedOnly end,
    function(v) state.modifiedOnly = v; ns.Refresh() end)
  MakeCheck(ui, L.allCats, 400, -35,
    function() return state.allCategories end,
    function(v) state.allCategories = v; BuildEntries(); ns.Refresh() end)
  MakeCheck(ui, L.reapply, 550, -35,
    function() return ns.db.reapply end,
    function(v) ns.db.reapply = v end)
  MakeCheck(ui, L.safe, 740, -35,
    function() return ns.db.safeRevert end,
    function(v) ns.db.safeRevert = v end, L.safeTip)

  -- Deuxième ligne : aide, compteur, replier / déplier
  local hint = ui:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 20, -66)
  hint:SetText(L.hint)

  local bCollapse = MakeButton(ui, L.collapseAll, 100, function()
    for _, e in ipairs(entries) do ns.db.collapsed[e.cat] = true end
    ns.db.collapsed[FAV] = true
    ns.Refresh()
  end)
  bCollapse:SetPoint("TOPRIGHT", -34, -60)
  local bExpand = MakeButton(ui, L.expandAll, 100, function()
    wipe(ns.db.collapsed)
    ns.Refresh()
  end)
  bExpand:SetPoint("RIGHT", bCollapse, "LEFT", -6, 0)
  ui.count = ui:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.count:SetPoint("RIGHT", bExpand, "LEFT", -10, 0)

  -- Liste
  local list = CreateFrame("Frame", nil, ui)
  list:SetPoint("TOPLEFT", 12, -84)
  list:SetSize(W - 54, VISIBLE * ROW_H)
  list:EnableMouseWheel(true)
  ui.rows = {}
  for i = 1, VISIBLE do ui.rows[i] = CreateRow(list, i) end

  local slider = CreateFrame("Slider", nil, ui, "BackdropTemplate")
  slider:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
  slider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
  slider:SetWidth(16)
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
    offset = math.floor(v + 0.5)
    UpdateRows()
  end)
  ui.slider = slider
  list:SetScript("OnMouseWheel", function(_, delta)
    slider:SetValue(slider:GetValue() - delta * 2)
  end)

  -- Préréglages
  local prLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  prLabel:SetPoint("BOTTOMLEFT", 18, 88)
  prLabel:SetText(L.presets)
  local last
  for _, p in ipairs(ns.Presets) do
    local b = MakeButton(ui, ns.PresetLabel(p), 118, function()
      StaticPopup_Show("FOREVERGFX_PRESET", ns.PresetLabel(p), nil, p)
    end)
    if last then b:SetPoint("LEFT", last, "RIGHT", 6, 0) else b:SetPoint("LEFT", prLabel, "RIGHT", 10, 0) end
    Tip(b, ns.PresetLabel(p), ns.Pick(p.desc, p.desc_en) .. "\n\n|cff99ccff" .. L.presetTip .. "|r")
    last = b
  end

  -- Profils
  local pLabel = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pLabel:SetPoint("BOTTOMLEFT", 18, 54)
  pLabel:SetText(L.profile)

  local prev = MakeButton(ui, "<", 24)
  prev:SetPoint("LEFT", pLabel, "RIGHT", 8, 0)
  local box = CreateFrame("EditBox", nil, ui, "InputBoxTemplate")
  box:SetSize(150, 20)
  box:SetPoint("LEFT", prev, "RIGHT", 10, 0)
  box:SetAutoFocus(false)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local nextB = MakeButton(ui, ">", 24)
  nextB:SetPoint("LEFT", box, "RIGHT", 6, 0)
  Tip(prev, L.cycleHint)
  Tip(nextB, L.cycleHint)

  local function Cycle(dir)
    local names = ns.ProfileNames()
    if #names == 0 then return ns.Print(L.noProfiles) end
    local cur, idx = box:GetText(), nil
    for i, n in ipairs(names) do if n == cur then idx = i end end
    if not idx then idx = (dir > 0) and 0 or 1 end
    idx = ((idx - 1 + dir) % #names) + 1
    box:SetText(names[idx])
  end
  prev:SetScript("OnClick", function() Cycle(-1) end)
  nextB:SetScript("OnClick", function() Cycle(1) end)

  local function Name() return ((box:GetText() or ""):match("^%s*(.-)%s*$")) end

  local bSave = MakeButton(ui, L.save, 92, function()
    local n = Name()
    if n == "" then return ns.Print(L.noProfileName) end
    if ns.db.profiles[n] then StaticPopup_Show("FOREVERGFX_OVERWRITE", n, nil, n) else ns.SaveProfile(n) end
  end)
  bSave:SetPoint("LEFT", nextB, "RIGHT", 12, 0)
  local bLoad = MakeButton(ui, L.load, 84, function() ns.LoadProfile(Name(), true) end)
  bLoad:SetPoint("LEFT", bSave, "RIGHT", 4, 0)
  local bDel = MakeButton(ui, L.delete, 88, function()
    local n = Name()
    if ns.db.profiles[n] then StaticPopup_Show("FOREVERGFX_DELPROFILE", n, nil, n)
    else ns.Print(L.unknownProfile, n) end
  end)
  bDel:SetPoint("LEFT", bLoad, "RIGHT", 4, 0)
  local bExport = MakeButton(ui, L.export, 88, function()
    local n = Name()
    local map, label = ns.db.overrides, L.exportCurrent
    if n ~= "" then
      if not ns.db.profiles[n] then return ns.Print(L.unknownProfile, n) end
      map, label = ns.db.profiles[n], n
    end
    ns.ShowText(string.format(L.exportTitle, label), ns.Export(map))
  end)
  bExport:SetPoint("LEFT", bDel, "RIGHT", 16, 0)
  local bImport = MakeButton(ui, L.import, 88, function()
    ns.ShowText(L.importTitle, "", function(text)
      local map, count = ns.Import(text)
      if not map then return ns.Print(L.importBad) end
      local n = Name()
      if n == "" then n = L.importedName end
      ns.db.profiles[n] = map
      box:SetText(n)
      ns.Print(L.imported, n, count)
    end)
  end)
  bImport:SetPoint("LEFT", bExport, "RIGHT", 4, 0)
  local bCompare = MakeButton(ui, L.compare, 92, function()
    local n = Name()
    local p = ns.db.profiles[n]
    if not p then return ns.Print(L.unknownProfile, n) end
    local lines = ns.Compare(p)
    ns.ShowText(string.format(L.compareTitle, n), #lines > 0 and table.concat(lines, "\n") or L.compareSame)
  end)
  bCompare:SetPoint("LEFT", bImport, "RIGHT", 4, 0)

  -- Ligne du bas : actions
  local bReset = MakeButton(ui, L.resetAll, 130, function() StaticPopup_Show("FOREVERGFX_RESET") end)
  bReset:SetPoint("BOTTOMRIGHT", -14, 14)
  local bGx = MakeButton(ui, L.restartGx, 160, function()
    if RestartGx then pcall(RestartGx) else ConsoleExec("gxRestart") end
  end)
  bGx:SetPoint("RIGHT", bReset, "LEFT", -6, 0)
  local bCtx = MakeButton(ui, L.context, 120, function() ns.ShowContext() end)
  bCtx:SetPoint("RIGHT", bGx, "LEFT", -6, 0)
  Tip(bCtx, L.ctxTitle, L.ctxHint)
  ui.benchBtn = MakeButton(ui, L.bench, 130, function()
    if IsShiftKeyDown() then ns.ShowBenchResults() else ns.BenchToggle() end
  end)
  ui.benchBtn:SetPoint("RIGHT", bCtx, "LEFT", -6, 0)
  Tip(ui.benchBtn, L.bench, L.benchTip)
  local bHist = MakeButton(ui, L.history, 100, ShowHistory)
  bHist:SetPoint("RIGHT", ui.benchBtn, "LEFT", -6, 0)
  local bUndo = MakeButton(ui, L.undo, 120, function() ns.Undo() end)
  bUndo:SetPoint("RIGHT", bHist, "LEFT", -6, 0)

  ui:SetScript("OnShow", function()
    BuildEntries()
    ns.Refresh()
    ns.OnBench()
    if ns.OnMainShow then ns.OnMainShow() end
  end)
  ui:HookScript("OnHide", function() if ns.TourShown() then ns.EndTour() end end)
  ns.mainFrame = ui
  if ns.BuildSimple then ns.BuildSimple(ui) end
  ui:SetScript("OnHide", HideMenu)
end

function ns.OnBench()
  if ns.UpdateSimple then ns.UpdateSimple() end
  if not ui then return end
  local b = ns.bench
  if b.running then
    ui.benchBtn:SetText(string.format(L.benchRunning, b.left or b.duration))
  else
    ui.benchBtn:SetText(L.bench)
  end
end

function ns.ToggleUI()
  if not ui then CreateUI() end
  ui:SetShown(not ui:IsShown())
end

----------------------------------------------------------------------
-- Bouton de minicarte
----------------------------------------------------------------------
local mmb
local function PlaceMinimapButton()
  local a = math.rad(ns.db.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 10
  mmb:ClearAllPoints()
  mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.HideOwnMinimapButton()
  if mmb then mmb:Hide() end
end

function ns.UpdateMinimapButton()
  if not mmb then return end
  if ns.dbi then mmb:Hide() return end
  mmb:SetShown(not ns.db.minimap.hide)
  PlaceMinimapButton()
end

local function CreateMinimapButton()
  if not Minimap then return end
  mmb = CreateFrame("Button", "ForeverGFXMinimapButton", Minimap)
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
  icon:SetTexture(ICON)
  local border = mmb:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  mmb:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.BenchToggle() else ns.ToggleUI() end
  end)
  mmb:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      PlaceMinimapButton()
    end)
  end)
  mmb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mmb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ForeverGFX", 1, 0.82, 0)
    GameTooltip:AddLine(L.minimapTip1, 1, 1, 1)
    GameTooltip:AddLine(L.minimapTip2, 1, 1, 1)
    GameTooltip:AddLine(L.minimapTip3, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ns.UpdateMinimapButton()
end

----------------------------------------------------------------------
-- Panneau Options > AddOns
----------------------------------------------------------------------
local function RegisterSettings()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local panel = CreateFrame("Frame")
  local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", 16, -16)
  fs:SetText(L.settingsText)
  local b = MakeButton(panel, L.open, 180, function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if not ui then CreateUI() end
    ui:Show()
  end)
  b:SetPoint("TOPLEFT", 16, -44)
  local cat = Settings.RegisterCanvasLayoutCategory(panel, "ForeverGFX")
  Settings.RegisterAddOnCategory(cat)
end

function ns.InitUI()
  RegisterSettings()
  CreateMinimapButton()
end
