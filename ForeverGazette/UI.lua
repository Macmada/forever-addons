local _, ns = ...
local L = ns.L
local Print = ns.Print

-- Fenêtre de la gazette : une page de journal sur parchemin, dans le style de l'interface de WoW : onglets (édition,
-- sommaire, hebdo), navigation par jour, actions en icônes avec leur nom, rubriques illustrées, bilan en encadré.

local W, H = 640, 700
local PAPER = { 0.93, 0.88, 0.74 }
local INK = { 0.16, 0.11, 0.06 }
local INK_SOFT = { 0.38, 0.29, 0.18 }
local RED = { 0.45, 0.10, 0.06 }

local ui
local state = { mode = "day", key = nil }

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function MakeCheck(parent, text, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  label:SetWidth(470)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  cb.label = label
  cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return cb
end

local K = ns.Kit
local Border, MakeTab, MakeAction = K.Border, K.Tab, K.Action

----------------------------------------------------------------------
-- Mise en page des blocs sur le papier
----------------------------------------------------------------------
local pool = { fs = {}, btn = {}, rule = {}, tex = {} }
local used = { fs = 0, btn = 0, rule = 0, tex = 0 }

-- Textes en lettres de livre : réserve à part par taille (une police posée par SetFont ne se retire plus ensuite)
local tpool, tused = {}, {}
local function ResetPool()
  for _, kind in ipairs({ "fs", "btn", "rule", "tex" }) do
    for _, o in ipairs(pool[kind]) do o:Hide() end
    used[kind] = 0
  end
  for size, list in pairs(tpool) do
    for _, o in ipairs(list) do o:Hide() end
    tused[size] = 0
  end
end

local function GetTitleFS(size, fontObject)
  tpool[size] = tpool[size] or {}
  tused[size] = (tused[size] or 0) + 1
  local fs = tpool[size][tused[size]]
  if not fs then
    fs = ui.content:CreateFontString(nil, "OVERLAY", fontObject)
    fs:SetJustifyV("TOP")
    fs:SetSpacing(2)
    K.TitleFont(fs, size, fontObject)
    tpool[size][tused[size]] = fs
  end
  fs:ClearAllPoints()
  fs:Show()
  return fs
end

local function GetFS()
  used.fs = used.fs + 1
  local fs = pool.fs[used.fs]
  if not fs then
    fs = ui.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(2)
    pool.fs[used.fs] = fs
  end
  fs:ClearAllPoints()
  fs:Show()
  return fs
end

local function GetBtn()
  used.btn = used.btn + 1
  local b = pool.btn[used.btn]
  if not b then
    b = CreateFrame("Button", nil, ui.content)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("TOPLEFT", 0, 1)
    b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.fs:SetPoint("TOPLEFT")
    b.fs:SetJustifyH("LEFT")
    b.fs:SetJustifyV("TOP")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
      if self.onClick then return self.onClick() end
      if self.link and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
    end)
    pool.btn[used.btn] = b
  end
  b:ClearAllPoints()
  b.link, b.onClick = nil, nil
  b:Show()
  return b
end

local function GetRule()
  used.rule = used.rule + 1
  local r = pool.rule[used.rule]
  if not r then
    r = ui.content:CreateTexture(nil, "ARTWORK")
    pool.rule[used.rule] = r
  end
  r:ClearAllPoints()
  r:Show()
  return r
end

-- Icônes des rubriques (et fonds d'encadré)
local function GetTex(layer)
  used.tex = used.tex + 1
  local t = pool.tex[used.tex]
  if not t then
    t = ui.content:CreateTexture(nil, layer or "ARTWORK")
    pool.tex[used.tex] = t
  end
  t:SetDrawLayer(layer or "ARTWORK")
  t:SetTexCoord(0, 1, 0, 1)
  t:ClearAllPoints()
  t:Show()
  return t
end

local function ItemIcon(link)
  if not link then return nil end
  local ok, tex
  if C_Item and C_Item.GetItemIconByID then ok, tex = pcall(C_Item.GetItemIconByID, link) end
  if (not ok or not tex) and GetItemIcon then ok, tex = pcall(GetItemIcon, link) end
  return ok and tex or nil
end

local SECTION_ICON = {
  dungeons = "Interface\\Icons\\INV_Misc_Head_Dragon_01", exploits = "Interface\\Icons\\Ability_Warrior_BattleShout",
  travel = "Interface\\Icons\\INV_Misc_Map_01", loot = "Interface\\Icons\\INV_Misc_Coin_02",
  death = "Interface\\Icons\\Ability_Rogue_FeignDeath", social = "Interface\\Icons\\INV_Letter_02",
  craft = "Interface\\Icons\\Trade_BlackSmithing", quests = "Interface\\GossipFrame\\ActiveQuestIcon",
  stats = "Interface\\Icons\\INV_Misc_PocketWatch_01", weeklyTop = "Interface\\Icons\\INV_Misc_Book_09",
  weeklyStats = "Interface\\Icons\\INV_Misc_PocketWatch_01",
}

local STYLE = {
  masthead = { font = "GameFontNormalHuge", title = 30, color = INK, justify = "CENTER", gap = 2 },
  edition = { font = "GameFontNormalSmall", color = INK_SOFT, justify = "CENTER", gap = 6, ruleAfter = true },
  headline = { font = "GameFontNormalLarge", title = 21, color = RED, justify = "CENTER", gap = 6 },
  lede = { font = "GameFontHighlight", color = INK_SOFT, justify = "CENTER", gap = 10 },
  photo = { font = "GameFontHighlightSmall", color = INK_SOFT, justify = "CENTER", gap = 8 },
  section = { font = "GameFontNormal", title = 17, color = RED, justify = "LEFT", gap = 6, top = 12 },
  line = { font = "GameFontHighlight", color = INK, justify = "LEFT", gap = 4, indent = 26 },
  item = { font = "GameFontHighlight", color = INK, justify = "LEFT", gap = 4, indent = 26 },
  note = { font = "GameFontHighlightSmall", color = INK_SOFT, justify = "LEFT", gap = 3, indent = 26 },
  index = { font = "GameFontHighlight", color = INK, justify = "LEFT", gap = 6, indent = 8 },
}

-- Bilan en encadré, sur deux colonnes : « Temps de jeu » à gauche, « 30 min » à droite de chaque case
local function StatsBox(list, width, y)
  local cols, rowH, pad = 2, 18, 8
  local rows = math.ceil(#list / cols)
  local boxH = rows * rowH + pad * 2
  local bg = GetTex("BACKGROUND")
  bg:SetColorTexture(0.55, 0.40, 0.20, 0.13)
  bg:SetPoint("TOPLEFT", 10, y)
  bg:SetSize(width - 20, boxH)
  for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "TOPLEFT", "TOPRIGHT", -boxH } }) do
    local r = GetRule()
    r:SetColorTexture(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3], 0.6)
    r:SetHeight(1)
    r:SetPoint("TOPLEFT", 10, y + edge[3])
    r:SetPoint("TOPRIGHT", -10, y + edge[3])
  end
  local colW = (width - 20 - pad * 2) / cols
  for i, text in ipairs(list) do
    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
    local label, value = text:match("^(.-)%s*:%s*(.+)$")
    local x, yy = 10 + pad + c * colW, y - pad - r * rowH
    local a = GetFS()
    a:SetFontObject("GameFontHighlightSmall")
    a:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
    a:SetJustifyH("LEFT")
    a:SetWidth(colW * 0.62)
    a:SetText(label or text)
    a:SetPoint("TOPLEFT", x, yy)
    if value then
      local v = GetFS()
      v:SetFontObject("GameFontNormal")
      v:SetTextColor(INK[1], INK[2], INK[3])
      v:SetJustifyH("RIGHT")
      v:SetWidth(colW * 0.38 - 10)
      v:SetText(value)
      v:SetPoint("TOPLEFT", x + colW * 0.62, yy)
    end
  end
  return y - boxH - 6
end

local function Render(blocks)
  ResetPool()
  local width = ui.content:GetWidth()
  local y = -12
  blocks = blocks or {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    if b.kind == "stats" then
      local list = {}
      while blocks[i] and blocks[i].kind == "stats" do list[#list + 1] = blocks[i].text; i = i + 1 end
      y = StatsBox(list, width, y)
    else
      local st = STYLE[b.kind] or STYLE.line
      y = y - (st.top or 0)
      local indent = st.indent or 0
      local fs, holder
      local iconW = 0
      if b.kind == "section" then
        -- titre de rubrique : icône, nom en lettres de livre, filet doré dessous
        local icon = SECTION_ICON[b.sec or ""]
        local tex = GetTex("ARTWORK")
        tex:SetSize(20, 20)
        tex:SetPoint("TOPLEFT", 4, y + 1)
        tex:SetTexture(icon or SECTION_ICON.exploits)
        if icon and icon:find("Icons", 1, true) then tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
        indent = 30
      end
      if b.link or b.onClick then
        holder = GetBtn()
        holder.link, holder.onClick = b.link, b.onClick
        -- texte du bouton : normal, ou un texte de titre à part (gros titre lié à un objet)
        local key = st.title and ("tfs" .. st.title)
        if key and not holder[key] then
          holder[key] = holder:CreateFontString(nil, "OVERLAY", st.font)
          holder[key]:SetJustifyV("TOP")
          K.TitleFont(holder[key], st.title, st.font)
        end
        for k, o in pairs(holder) do
          if type(k) == "string" and k:find("^tfs") and type(o) == "table" and o.Hide then o:Hide() end
        end
        holder.fs:SetShown(not key)
        fs = key and holder[key] or holder.fs
        fs:Show()
        local tex = (b.kind == "item") and ItemIcon(b.link)
        holder.icon:SetShown(tex ~= nil)
        if tex then holder.icon:SetTexture(tex); iconW = 22 end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", iconW, 0)
      else
        fs = st.title and GetTitleFS(st.title, st.font) or GetFS()
      end
      if not st.title then fs:SetFontObject(st.font) end
      fs:SetTextColor(st.color[1], st.color[2], st.color[3])
      fs:SetJustifyH(st.justify)
      fs:SetWidth(width - indent - 12 - iconW)
      local text = b.text
      if (b.kind == "line" or b.kind == "item") and iconW == 0 then text = "|cff8a6a2a•|r  " .. b.text end
      fs:SetText(text)
      local h = fs:GetStringHeight()
      if holder then
        holder:SetPoint("TOPLEFT", 6 + indent, y)
        holder:SetSize(width - indent - 12, h)
      else
        fs:SetPoint("TOPLEFT", 6 + indent, y)
      end
      y = y - h - (st.gap or 3)
      if b.kind == "section" then
        local r = GetRule()
        r:SetColorTexture(0.65, 0.48, 0.16, 0.7)
        r:SetHeight(1)
        r:SetPoint("TOPLEFT", 6, y + 2)
        r:SetPoint("TOPRIGHT", -6, y + 2)
        y = y - 4
      end
      if st.ruleAfter then
        for k = 1, 2 do
          local r = GetRule()
          r:SetColorTexture(INK[1], INK[2], INK[3], k == 1 and 0.85 or 0.45)
          r:SetHeight(k == 1 and 2 or 1)
          r:SetPoint("TOPLEFT", 6, y - (k - 1) * 4)
          r:SetPoint("TOPRIGHT", -6, y - (k - 1) * 4)
        end
        y = y - 14
      end
      i = i + 1
    end
  end
  ui.content:SetHeight(math.max(-y + 10, 10))
  ui.scroll:SetVerticalScroll(0)
end

----------------------------------------------------------------------
-- Vues
----------------------------------------------------------------------
local function Message(text)
  Render({ { kind = "masthead", text = L.title }, { kind = "lede", text = text } })
end

local function UpdateNav()
  local keys = ns.EditionKeys()
  local idx
  for i, k in ipairs(keys) do if k == state.key then idx = i end end
  local dayMode = state.mode == "day"
  ui.prevBtn:SetEnabled(dayMode and ((idx and idx > 1) or (not idx and #keys > 0)))
  ui.nextBtn:SetEnabled(dayMode and idx ~= nil and idx < #keys)
  ui.prevBtn:SetShown(dayMode)
  ui.nextBtn:SetShown(dayMode)
  ui.todayBtn:SetShown(dayMode and state.key ~= ns.Today())
  ui.backBtn:SetShown(state.mode ~= "day")
  local label = (state.mode == "index" and L.navIndex) or (state.mode == "weekly" and L.navWeekly)
                or (state.mode == "demo" and L.demoTitle) or ns.FormatDate(state.key or ns.Today())
  ui.navLabel:SetText(label)
  ui.tabDay:SetActive(state.mode == "day" or state.mode == "demo")
  ui.tabIndex:SetActive(state.mode == "index")
  ui.tabWeekly:SetActive(state.mode == "weekly")
end

function ns.ShowDay(key)
  if not ui then ns.CreateUI() end
  state.mode, state.key = "day", key or ns.Today()
  local blocks = ns.BuildEdition(state.key)
  if blocks then Render(blocks)
  elseif #ns.EditionKeys() == 0 then Message(L.noEdition)
  else Message(L.noEditionDay .. "\n\n" .. ns.FormatDate(state.key)) end
  ui.current = blocks
  UpdateNav()
end

local function Step(delta)
  local keys = ns.EditionKeys()
  if #keys == 0 then return end
  local idx
  for i, k in ipairs(keys) do if k == state.key then idx = i end end
  if not idx then
    idx = #keys + 1
    for i, k in ipairs(keys) do if k > state.key then idx = i break end end
    if delta > 0 then idx = idx - 1 end
  end
  idx = math.max(1, math.min(#keys, idx + delta))
  ns.ShowDay(keys[idx])
end

function ns.ShowIndex()
  if not ui then ns.CreateUI() end
  state.mode = "index"
  local keys = ns.EditionKeys()
  local blocks = { { kind = "masthead", text = L.index },
                   { kind = "edition", text = string.format(L.indexTitle, #keys) } }
  for i = #keys, 1, -1 do
    local k = keys[i]
    local head = ns.DayHeadline(k) or ""
    blocks[#blocks + 1] = { kind = "index", text = string.format(L.indexRow, i, ns.FormatDate(k)) .. "\n|cff5c472e" .. head .. "|r",
                            onClick = function() ns.ShowDay(k) end }
  end
  if #keys == 0 then blocks[#blocks + 1] = { kind = "lede", text = L.noEdition } end
  Render(blocks)
  ui.current = nil
  UpdateNav()
end

function ns.ShowWeekly()
  if not ui then ns.CreateUI() end
  state.mode = "weekly"
  local blocks = ns.BuildWeekly(ns.Today())
  if blocks then Render(blocks) else Message(L.weeklyEmpty) end
  ui.current = blocks
  UpdateNav()
end

function ns.ShowDemo()
  if not ui then ns.CreateUI() end
  state.mode = "demo"
  local blocks = ns.BuildEdition(ns.Today(), ns.DemoDay(), 42)
  table.insert(blocks, 1, { kind = "note", text = "|cff8b1a10" .. L.demoTitle .. "|r" })
  Render(blocks)
  ui.current = blocks
  UpdateNav()
  ui:Show()
end

function ns.Refresh()
  if not ui or not ui:IsShown() then return end
  if state.mode == "day" then ns.ShowDay(state.key)
  elseif state.mode == "index" then ns.ShowIndex()
  elseif state.mode == "weekly" then ns.ShowWeekly() end
end
ns.OnRecord = function() if ui and ui:IsShown() and state.mode == "day" and state.key == ns.Today() then ns.Refresh() end end

-- Édition de démonstration (rien n'est enregistré)
function ns.DemoDay()
  local now = time()
  local fr = ns.lang ~= "en"
  local epic = fr and "|cffa335ee|Hitem:18832::::::::60:::::::|h[Lame de brutalité]|h|r"
                   or "|cffa335ee|Hitem:18832::::::::60:::::::|h[Brutality Blade]|h|r"
  local rare = fr and "|cff0070dd|Hitem:10413::::::::40:::::::|h[Gantelets du champion]|h|r"
                   or "|cff0070dd|Hitem:10413::::::::40:::::::|h[Gauntlets of the Champion]|h|r"
  local function E(dt, k, v, s, shot) return { t = now - dt, k = k, v = v, s = s, shot = shot } end
  return {
    events = {
      E(9000, "zone", { zone = fr and "Les Paluns" or "Wetlands" }, 15),
      E(8000, "quest", { target = fr and "Les secrets de la Gorge" or "Secrets of the Gorge" }, 3),
      E(7000, "death", { killer = fr and "Raptor de Mosh'Ogg" or "Mosh'Ogg Raptor", zone = fr and "Strangleronce" or "Stranglethorn Vale" }, 25),
      E(6000, "dungeon", { zone = fr and "Les Mortemines" or "The Deadmines" }, 35),
      E(5000, "boss", { target = "Edwin VanCleef", zone = fr and "Les Mortemines" or "The Deadmines" }, 70, "WoWScrnShot_" .. date("%m%d%y") .. "_213012.jpg"),
      E(4900, "loot_rare", { item = rare }, 12),
      E(3000, "level", { level = 20 }, 80, "WoWScrnShot_" .. date("%m%d%y") .. "_221544.jpg"),
      E(2500, "rep", { faction = fr and "Hurlevent" or "Stormwind", standing = fr and "Honoré" or "Honored" }, 30),
      E(2000, "skill", { skill = fr and "Forge" or "Blacksmithing", rank = 150 }, 25),
      E(1500, "duel_win", { target = "Grosbill" }, 20),
      E(1000, "loot_epic", { item = epic }, 60, "WoWScrnShot_" .. date("%m%d%y") .. "_224010.jpg"),
      E(500, "money", { gold = 1000000 }, 30),
    },
    stats = { play = 3 * 3600 + 25 * 60, xp = 48210, quests = 7, kills = 143, deaths = 1, earned = 1234567, spent = 45600,
              zones = { a = true, b = true, c = true, d = true }, companions = { "Grosbill", "Lyra", "Thorgal" }, level = 20 },
  }
end

----------------------------------------------------------------------
-- Export, partage, options
----------------------------------------------------------------------
local tw
local function ShowExport(blocks)
  if not blocks then return Print(L.noEdition) end
  if not tw then
    tw = CreateFrame("Frame", "ForeverGazetteExportFrame", UIParent, "BasicFrameTemplateWithInset")
    ns.SafeClose(tw)
    tw:SetSize(620, 440)
    tw:SetPoint("CENTER", 40, -20)
    tw:SetFrameStrata("FULLSCREEN")
    tw:SetMovable(true)
    tw:SetClampedToScreen(true)
    tw:EnableMouse(true)
    tw:RegisterForDrag("LeftButton")
    tw:SetScript("OnDragStart", tw.StartMoving)
    tw:SetScript("OnDragStop", tw.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverGazetteExportFrame")
    tw.title = tw:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tw.title:SetPoint("TOPLEFT", 12, -6)
    tw.title:SetPoint("RIGHT", -30, 0)
    tw.title:SetJustifyH("LEFT")
    tw.title:SetText(L.exportTitle)
    local sf = CreateFrame("ScrollFrame", nil, tw, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, -32)
    sf:SetPoint("BOTTOMRIGHT", -32, 44)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(560)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    tw.edit = eb
    local function Set(fmt)
      tw.fmt = fmt
      eb:SetText(ns.ToText(tw.blocks, fmt))
      eb:SetFocus()
      eb:HighlightText()
    end
    tw.md = MakeButton(tw, L.fmtMarkdown, 150, function() Set("md") end)
    tw.md:SetPoint("BOTTOMLEFT", 14, 12)
    tw.plain = MakeButton(tw, L.fmtPlain, 120, function() Set("plain") end)
    tw.plain:SetPoint("LEFT", tw.md, "RIGHT", 6, 0)
    tw.close = MakeButton(tw, L.close, 110, function() tw:Hide() end)
    tw.close:SetPoint("BOTTOMRIGHT", -14, 12)
    tw.Set = Set
  end
  tw.blocks = blocks
  tw:Show()
  tw.Set(tw.fmt or "md")
end
ns.ShowExport = ShowExport

local sharing = false
function ns.Share(channel, blocks)
  blocks = blocks or (ui and ui.current) or ns.BuildEdition(ns.Today())
  if not blocks then return Print(L.noEdition) end
  if sharing then return Print(L.shareBusy) end
  if channel == "GUILD" and not (IsInGuild and IsInGuild()) then return Print(L.shareNoGuild) end
  if channel == "PARTY" then
    if IsInRaid and IsInRaid() then channel = "RAID"
    elseif not ((GetNumGroupMembers and GetNumGroupMembers() > 0) or (GetNumPartyMembers and GetNumPartyMembers() > 0)) then
      return Print(L.shareNoGroup)
    end
  end
  local lines = ns.ChatLines(blocks, channel == "SAY" and 2 or 8)
  if channel == "SAY" then
    -- hors instance, « Dire » n'est permis que sur un clic : un seul message, tout de suite
    SendChatMessage(ns.Cut(table.concat(lines, " — ", 1, math.min(2, #lines)), 250), "SAY")
    return Print(L.shareDone, 1)
  end
  sharing = true
  for i, line in ipairs(lines) do
    C_Timer.After((i - 1) * 0.7, function()
      SendChatMessage(line, channel)
      if i == #lines then sharing = false; Print(L.shareDone, #lines) end
    end)
  end
end

local shareFrame
function ns.ShowShare()
  if not shareFrame then
    shareFrame = CreateFrame("Frame", "ForeverGazetteShareFrame", ui, "BasicFrameTemplateWithInset")
    ns.SafeClose(shareFrame)
    shareFrame:SetSize(240, 150)
    shareFrame:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -20, -60)
    shareFrame:SetFrameStrata("DIALOG")
    local t = shareFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 12, -6)
    t:SetText(L.shareTitle)
    local function B(text, ch, y)
      local b = MakeButton(shareFrame, text, 200, function() shareFrame:Hide(); ns.Share(ch) end)
      b:SetPoint("TOP", 0, y)
      return b
    end
    shareFrame.guild = B(L.shareGuild, "GUILD", -34)
    shareFrame.party = B(L.shareParty, "PARTY", -62)
    shareFrame.say = B(L.shareSay, "SAY", -90)
  end
  shareFrame:SetShown(not shareFrame:IsShown())
end

local opt
function ns.ShowOptions()
  if not opt then
    opt = CreateFrame("Frame", "ForeverGazetteOptionsFrame", ui, "BasicFrameTemplateWithInset")
    ns.SafeClose(opt)
    opt:SetSize(540, 410)
    opt:SetPoint("CENTER", ui, "CENTER", 0, -10)
    opt:SetFrameStrata("DIALOG")
    local t = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 12, -6)
    t:SetText(L.optTitle)
    local y = -36
    local tone = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tone:SetPoint("TOPLEFT", 18, y)
    tone:SetText(L.optTone)
    y = y - 22
    opt.toneBtns = {}
    for _, key in ipairs(ns.TONES) do
      local b = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
      b:SetSize(24, 24)
      b:SetPoint("TOPLEFT", 26, y)
      local lab = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      lab:SetPoint("LEFT", b, "RIGHT", 2, 0)
      lab:SetText(L["tone_" .. key])
      b:SetScript("OnShow", function(self) self:SetChecked(ns.db.tone == key) end)
      b:SetScript("OnClick", function()
        ns.db.tone = key
        for _, o in ipairs(opt.toneBtns) do o:SetChecked(o == b) end
        ns.Refresh()
      end)
      opt.toneBtns[#opt.toneBtns + 1] = b
      y = y - 24
    end
    y = y - 8
    local function C(text, field, after)
      local cb = MakeCheck(opt, text, function() return ns.db[field] end, function(v) ns.db[field] = v; if after then after(v) end end)
      cb:SetPoint("TOPLEFT", 18, y)
      y = y - 28
      return cb
    end
    C(L.optShots, "shots")
    C(L.optShotsAll, "shotsAll")
    C(L.optNoUI, "shotsNoUI")
    C(L.optToast, "toast")
    local mm = MakeCheck(opt, L.optMinimap, function() return not ns.db.minimap.hide end,
                         function(v) ns.db.minimap.hide = not v; ns.UpdateMinimapButton() end)
    mm:SetPoint("TOPLEFT", 18, y)
    y = y - 34
    opt.lang = MakeButton(opt, "", 240, function()
      ns.lang = (ns.lang == "fr") and "en" or "fr"
      ns.db.lang = ns.lang
      Print("/reload")
      opt.lang:SetText(string.format(L.optLang, ns.lang))
      ns.Refresh()
    end)
    opt.lang:SetPoint("TOPLEFT", 18, y)
    opt.lang:SetScript("OnShow", function(self) self:SetText(string.format(L.optLang, ns.lang)) end)
    opt.wipe = MakeButton(opt, L.optWipe, 220, function() StaticPopup_Show("FOREVERGAZETTE_WIPE") end)
    opt.wipe:SetPoint("LEFT", opt.lang, "RIGHT", 12, 0)
    local close = MakeButton(opt, L.close, 110, function() opt:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -14, 12)
    opt:Hide()
  end
  opt:SetShown(not opt:IsShown())
end

----------------------------------------------------------------------
-- Fenêtre principale
----------------------------------------------------------------------
function ns.CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverGazetteFrame", UIParent, "BasicFrameTemplateWithInset")
  ns.SafeClose(ui)
  ns.ui = ui
  ui:SetSize(W, H)
  ui:SetPoint("CENTER")
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverGazetteFrame")
  ui:Hide()
  local logo = ui:CreateTexture(nil, "OVERLAY")
  logo:SetSize(16, 16)
  logo:SetPoint("TOPLEFT", 8, -4)
  logo:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  title:SetText(L.title)
  ui.diagBtn = ns.MakeDiagButton(ui)

  -- onglets : l'édition du jour, le sommaire de toutes les éditions, l'hebdo
  ui.tabDay = MakeTab(ui, L.tabDay, function() ns.ShowDay(state.key or ns.Today()) end)
  ui.tabDay:SetPoint("TOPLEFT", 14, -32)
  ui.tabIndex = MakeTab(ui, L.index, function() ns.ShowIndex() end)
  ui.tabIndex:SetPoint("LEFT", ui.tabDay, "RIGHT", 4, 0)
  ui.tabWeekly = MakeTab(ui, L.weekly, function() ns.ShowWeekly() end)
  ui.tabWeekly:SetPoint("LEFT", ui.tabIndex, "RIGHT", 4, 0)
  ui.indexBtn, ui.weeklyBtn = ui.tabIndex, ui.tabWeekly

  -- actions en icônes, avec leur nom
  ui.helpBtn = MakeAction(ui, "Interface\\Icons\\INV_Misc_QuestionMark", L.helpLabel, L.tipHelp, function() ns.RunTour() end)
  ui.helpBtn:SetPoint("TOPRIGHT", -18, -30)
  ui.optBtn = MakeAction(ui, "Interface\\Icons\\INV_Misc_Gear_01", L.options, L.tipOptions, function() ns.ShowOptions() end)
  ui.optBtn:SetPoint("RIGHT", ui.helpBtn, "LEFT", -22, 0)
  ui.pdfBtn = MakeAction(ui, "Interface\\Icons\\INV_Scroll_05", L.pdf, L.tipPdf, function() StaticPopup_Show("FOREVERGAZETTE_PDF") end)
  ui.pdfBtn:SetPoint("RIGHT", ui.optBtn, "LEFT", -22, 0)
  ui.shareBtn = MakeAction(ui, "Interface\\Icons\\INV_Letter_03", L.share, L.tipShare, function() ns.ShowShare() end)
  ui.shareBtn:SetPoint("RIGHT", ui.pdfBtn, "LEFT", -22, 0)
  ui.exportBtn = MakeAction(ui, "Interface\\Icons\\INV_Scroll_03", L.export, L.tipExport, function() ns.ShowExport(ui.current) end)
  ui.exportBtn:SetPoint("RIGHT", ui.shareBtn, "LEFT", -22, 0)

  -- barre de navigation : « Veille », la date, « Lendemain » ; « Aujourd'hui » et « Retour » selon la vue
  local nav = CreateFrame("Frame", nil, ui)
  nav:SetPoint("TOPLEFT", 12, -78)
  nav:SetPoint("TOPRIGHT", -12, -78)
  nav:SetHeight(28)
  local navBg = nav:CreateTexture(nil, "BACKGROUND")
  navBg:SetAllPoints()
  navBg:SetColorTexture(0.10, 0.07, 0.04, 0.85)
  Border(nav, 0.55, 0.42, 0.18, 0.9)
  ui.nav = nav
  ui.prevBtn = MakeButton(nav, L.prev, 110, function() Step(-1) end)
  ui.prevBtn:SetPoint("LEFT", 4, 0)
  ui.nextBtn = MakeButton(nav, L.next, 110, function() Step(1) end)
  ui.nextBtn:SetPoint("RIGHT", -4, 0)
  ui.navLabel = nav:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ui.navLabel:SetPoint("CENTER")
  ui.todayBtn = MakeButton(nav, L.today, 100, function() ns.ShowDay(ns.Today()) end)
  ui.todayBtn:SetPoint("RIGHT", ui.nextBtn, "LEFT", -6, 0)
  ui.backBtn = MakeButton(nav, L.back, 190, function() ns.ShowDay(state.key) end)
  ui.backBtn:SetPoint("LEFT", 4, 0)

  -- le papier : parchemin de l'interface (ou couleur papier si le client ne l'a pas), filet doré autour
  local paper = CreateFrame("Frame", nil, ui)
  paper:SetPoint("TOPLEFT", 12, -112)
  paper:SetPoint("BOTTOMRIGHT", -12, 12)
  local base = paper:CreateTexture(nil, "BACKGROUND", nil, -8)
  base:SetAllPoints()
  base:SetColorTexture(PAPER[1], PAPER[2], PAPER[3], 1)
  local parch = paper:CreateTexture(nil, "BACKGROUND", nil, -7)
  parch:SetAllPoints()
  local okTex = parch:SetTexture("Interface\\ACHIEVEMENTFRAME\\UI-Achievement-Parchment-Horizontal")
  if okTex == false then parch:Hide() else parch:SetVertexColor(1, 0.96, 0.86, 0.85) end
  Border(paper, 0.55, 0.42, 0.18, 1)
  ui.paper = paper
  local sf = CreateFrame("ScrollFrame", nil, paper, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 10, -8)
  sf:SetPoint("BOTTOMRIGHT", -30, 8)
  ui.scroll = sf
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(W - 24 - 40, 10)
  sf:SetScrollChild(content)
  ui.content = content

  ui:SetScript("OnShow", function()
    if state.mode == "demo" then return end
    ns.ShowDay(state.key or ns.Today())
    if not ns.db.tourDone then C_Timer.After(0.3, function() if ui:IsShown() then ns.RunTour() end end) end
  end)
  return ui
end

function ns.Toggle()
  if not ui then ns.CreateUI() end
  if ui:IsShown() then ui:Hide() else state.mode = "day"; state.key = ns.Today(); ui:Show() end
end

----------------------------------------------------------------------
-- Tutoriel
----------------------------------------------------------------------
function ns.RunTour()
  if not ui then ns.CreateUI() end
  if not ui:IsShown() then ui:Show() end
  ns.StartTour({
    { target = function() return ui.paper end, title = L.t1t, text = L.t1 },
    { target = function() return ui.nav end, title = L.t2t, text = L.t2 },
    { target = function() return ui.indexBtn end, title = L.t3t, text = L.t3 },
    { target = function() return ui.weeklyBtn end, title = L.t4t, text = L.t4 },
    { target = function() return ui.exportBtn end, title = L.t5t, text = L.t5 },
    { target = function() return ui.shareBtn end, title = L.t6t, text = L.t6 },
    { target = function() return ui.optBtn end, title = L.t7t, text = L.t7 },
    { target = function() return ui.pdfBtn end, title = L.t10t, text = L.t10 },
    { target = function() return ns.minimapButton end, title = L.t8t, text = L.t8 },
    { target = function() return ui.helpBtn end, title = L.t9t, text = L.t9 },
  }, function() ns.db.tourDone = true end)
end

----------------------------------------------------------------------
-- Bouton de minicarte (ou LibDBIcon s'il est présent)
----------------------------------------------------------------------
local mmb, dbi
local ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function PlaceMinimapButton()
  local a = math.rad(ns.db.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 10
  mmb:ClearAllPoints()
  mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.UpdateMinimapButton()
  if dbi then
    ns.db.ldbIcon.hide = ns.db.minimap.hide
    if ns.db.minimap.hide then dbi:Hide("ForeverGazette") else dbi:Show("ForeverGazette") end
    return
  end
  if not mmb then return end
  mmb:SetShown(not ns.db.minimap.hide)
  PlaceMinimapButton()
end

local function CreateMinimapButton()
  if not Minimap then return end
  mmb = CreateFrame("Button", "ForeverGazetteMinimapButton", Minimap)
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
  mmb:SetScript("OnClick", function() ns.Toggle() end)
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
    GameTooltip:AddLine("ForeverGazette", 1, 0.82, 0)
    local head = ns.DayHeadline(ns.Today())
    if head and ns.db.days[ns.Today()] then GameTooltip:AddLine(head, 0.9, 0.85, 0.7, true) end
    GameTooltip:AddLine(L.minimapTip1, 1, 1, 1)
    GameTooltip:AddLine(L.minimapTip2, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ns.UpdateMinimapButton()
end

local function SetupBroker()
  local LS = _G.LibStub
  local LDB = LS and LS("LibDataBroker-1.1", true)
  if not LDB then return end
  local obj = LDB:NewDataObject("ForeverGazette", {
    type = "launcher",
    icon = ICON,
    OnClick = function() ns.Toggle() end,
    OnTooltipShow = function(tt)
      tt:AddLine("ForeverGazette", 1, 0.82, 0)
      tt:AddLine(L.minimapTip1, 1, 1, 1)
    end,
  })
  local DBI = LS("LibDBIcon-1.0", true)
  if obj and DBI then
    ns.db.ldbIcon = ns.db.ldbIcon or { hide = ns.db.minimap.hide }
    DBI:Register("ForeverGazette", obj, ns.db.ldbIcon)
    dbi = DBI
    if mmb then mmb:Hide() end
    ns.minimapButton = DBI.GetMinimapButton and DBI:GetMinimapButton("ForeverGazette") or ns.minimapButton
  end
end

----------------------------------------------------------------------
-- Démarrage, commandes
----------------------------------------------------------------------
ns.OnLoaded = function()
  CreateMinimapButton()
  StaticPopupDialogs["FOREVERGAZETTE_PDF"] = {
    text = L.pdfConfirm, button1 = L.pdfGo, button2 = CANCEL or NO,
    OnAccept = function() ns.PrintPDF() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopupDialogs["FOREVERGAZETTE_WIPE"] = {
    text = L.wipeConfirm, button1 = YES, button2 = NO,
    OnAccept = function()
      wipe(ns.db.days)
      ns.db.exports = nil
      Print(L.wiped)
      ns.Refresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
  }
end
ns.OnLogin = function() SetupBroker() end

-- « PDF » : enregistre la gazette (le jeu n'écrit la sauvegarde qu'au rechargement ou à la déconnexion) ;
-- le compagnon (tools/gazette-discord, sur le PC) en fait un PDF et un PNG avec les captures d'écran.
function ns.PrintPDF()
  ns.WriteExports()
  ReloadUI()
end

local ALIASES = {
  hebdo = "weekly", weekly = "weekly", semaine = "weekly",
  sommaire = "index", contents = "index", index = "index",
  export = "export", exporter = "export",
  partager = "share", share = "share",
  ton = "tone", tone = "tone",
  photo = "photo", photos = "photo", screenshot = "photo",
  demo = "demo", ["démo"] = "demo",
  minimap = "minimap", tuto = "tuto", tutorial = "tuto", pdf = "pdf", imprimer = "pdf", print = "pdf",
  lang = "lang", help = "help", aide = "help", ["?"] = "help", diag = "diag",
}
local TONE_ALIASES = { serieux = "serious", ["sérieux"] = "serious", serious = "serious",
                       tabloid = "tabloid", ["tabloïd"] = "tabloid", epique = "epic", ["épique"] = "epic", epic = "epic" }
local CHANNEL_ALIASES = { guilde = "GUILD", guild = "GUILD", groupe = "PARTY", party = "PARTY", raid = "PARTY",
                          dire = "SAY", say = "SAY" }

SLASH_FOREVERGAZETTE1 = "/gazette"
SLASH_FOREVERGAZETTE2 = "/gaz"
SlashCmdList.FOREVERGAZETTE = function(msg)
  msg = ns.Trim(msg):lower()
  local cmd, arg = msg:match("^(%S+)%s*(.-)$")
  local action = ALIASES[cmd or ""]
  if not cmd then
    ns.Toggle()
  elseif action == "weekly" then
    if not ui then ns.CreateUI() end
    ui:Show(); ns.ShowWeekly()
  elseif action == "index" then
    if not ui then ns.CreateUI() end
    ui:Show(); ns.ShowIndex()
  elseif action == "export" then
    ShowExport((ui and ui:IsShown() and ui.current) or ns.BuildEdition(ns.Today()))
  elseif action == "share" then
    ns.Share(CHANNEL_ALIASES[arg] or "GUILD")
  elseif action == "tone" then
    local t = TONE_ALIASES[arg]
    if t then ns.db.tone = t; Print(L["tone_" .. t]); ns.Refresh() else Print(L.helpText) end
  elseif action == "photo" then
    if arg == "on" or arg == "oui" then ns.db.shots = true
    elseif arg == "off" or arg == "non" then ns.db.shots = false
    else ns.db.shots = not ns.db.shots end
    Print(L.optShots .. " : " .. (ns.db.shots and "on" or "off"))
  elseif action == "diag" then
    ns.ShowDiag()
  elseif action == "pdf" then
    StaticPopup_Show("FOREVERGAZETTE_PDF")
  elseif action == "demo" then
    ns.ShowDemo()
  elseif action == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    ns.UpdateMinimapButton()
    Print(ns.db.minimap.hide and L.minimapHidden or L.minimapShown)
  elseif action == "tuto" then
    ns.RunTour()
  elseif action == "lang" and (arg == "fr" or arg == "en") then
    ns.lang = arg
    ns.db.lang = arg
    ns.Refresh()
  else
    Print(L.helpText)
  end
end

function ForeverGazette_OnCompartmentClick() ns.Toggle() end
