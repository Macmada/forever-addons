local _, ns = ...
local L = ns.L
local Print = ns.Print

local W, H = 560, 600
local COLORS = { ok = { 0.25, 0.8, 0.3 }, info = { 0.6, 0.6, 0.6 }, warn = { 1, 0.6, 0.1 }, bad = { 0.95, 0.2, 0.2 } }
local ui
local state = { ctx = nil, reason = nil }

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
  label:SetWidth(440)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return cb
end

function ns.FormatMoney(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local fr = ns.lang ~= "en"
  if g > 0 then return string.format(fr and "%d po %d pa" or "%dg %ds", g, s) end
  if s > 0 then return string.format(fr and "%d pa %d pc" or "%ds %dc", s, c) end
  return string.format(fr and "%d pc" or "%dc", c)
end

local function RoleLabel(res)
  if ns.db.role == "auto" then return string.format(L.role_auto, L["role_" .. ns.AutoRole(res.class)]) end
  return L["role_" .. ns.db.role]
end

----------------------------------------------------------------------
-- Lignes de la fiche (réutilisées)
----------------------------------------------------------------------
local rows, used = {}, 0
local function GetRow()
  used = used + 1
  local r = rows[used]
  if not r then
    r = CreateFrame("Button", nil, ui.content)
    r:SetHeight(20)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(10, 10)
    r.dot:SetPoint("LEFT", 4, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", 20, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", 42, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(true)
    r:SetScript("OnEnter", function(self)
      if self.itemID then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[used] = r
  end
  r:Show()
  return r
end

local headers, hused = {}, 0
local function GetHeader()
  hused = hused + 1
  local h = headers[hused]
  if not h then
    h = ui.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetJustifyH("LEFT")
    headers[hused] = h
  end
  h:Show()
  return h
end

local function Render(res)
  for _, r in ipairs(rows) do r:Hide() end
  for _, h in ipairs(headers) do h:Hide() end
  used, hused = 0, 0
  local y = -4
  local width = ui.content:GetWidth()
  local nWarn, nInfo = 0, 0
  local function Header(text)
    local h = GetHeader()
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 2, y - 6)
    h:SetText(text)
    y = y - 26
  end
  local function Row(r)
    local row = GetRow()
    local c = COLORS[r.status] or COLORS.info
    row.dot:SetColorTexture(c[1], c[2], c[3], 1)
    row.icon:SetShown(r.icon ~= nil)
    if r.icon then row.icon:SetTexture(r.icon) end
    row.itemID = r.itemID or r.id
    row.text:SetWidth(width - 50)
    row.text:SetText(r.text)
    local h = math.max(20, row.text:GetStringHeight() + 4)
    row:SetHeight(h)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("RIGHT", ui.content, "RIGHT", 0, 0)
    y = y - h - 2
  end
  for _, s in ipairs(res.sections) do
    if #s.rows > 0 then
      Header(L["sec_" .. s.key])
      for _, r in ipairs(s.rows) do
        Row(r)
        if r.status == "warn" or r.status == "bad" then nWarn = nWarn + 1 elseif r.status == "info" then nInfo = nInfo + 1 end
      end
    end
  end
  Header(L.sec_shopping)
  if #res.shopping == 0 then
    Row({ status = "ok", text = L.shopEmpty })
  else
    for _, it in ipairs(res.shopping) do Row({ status = "info", icon = it.icon, itemID = it.id, text = string.format(L.shopLine, it.qty, it.name) }) end
  end
  ui.content:SetHeight(-y + 8)
  ui.summary:SetText((nWarn == 0) and ("|cff40cc4d" .. L.allGood .. "|r") or string.format(L.summary, nWarn, nInfo))
  ui.title:SetText(res.context == "raid" and L.titleRaid or L.title)
  ui.ctxBtn:SetText(L["ctx_" .. res.context])
  ui.roleBtn:SetText(string.format(L.role, RoleLabel(res)))
  ui.reason:SetText(state.reason or "")
end

----------------------------------------------------------------------
-- Fenêtre
----------------------------------------------------------------------
local function CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverPrepFrame", UIParent, "BasicFrameTemplateWithInset")
  ns.ui = ui
  ui:SetSize(W, H)
  ui:SetPoint("CENTER", 220, 40)
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverPrepFrame")
  ui:Hide()
  ui.title = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ui.title:SetPoint("TOPLEFT", 12, -6)
  ui.reason = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ui.reason:SetPoint("TOPLEFT", 16, -32)

  ui.ctxBtn = MakeButton(ui, "", 90, function()
    state.ctx = ((state.ctx or ns.Context()) == "raid") and "dungeon" or "raid"
    ns.db.context = state.ctx
    ns.Refresh()
  end)
  ui.ctxBtn:SetPoint("TOPLEFT", 14, -50)
  ui.roleBtn = MakeButton(ui, "", 230, function()
    local order = { "auto", "tank", "heal", "melee", "caster" }
    local cur = 1
    for i, r in ipairs(order) do if r == ns.db.role then cur = i end end
    ns.db.role = order[cur % #order + 1]
    ns.Refresh()
  end)
  ui.roleBtn:SetPoint("LEFT", ui.ctxBtn, "RIGHT", 6, 0)
  ui.refreshBtn = MakeButton(ui, L.refresh, 90, function() ns.Refresh() end)
  ui.refreshBtn:SetPoint("LEFT", ui.roleBtn, "RIGHT", 6, 0)
  ui.helpBtn = MakeButton(ui, L.help, 26, function() ns.RunTour() end)
  ui.helpBtn:SetPoint("TOPRIGHT", -14, -50)
  ui.optBtn = MakeButton(ui, L.options, 80, function() ns.ShowOptions() end)
  ui.optBtn:SetPoint("RIGHT", ui.helpBtn, "LEFT", -4, 0)

  local sf = CreateFrame("ScrollFrame", nil, ui, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 12, -80)
  sf:SetPoint("BOTTOMRIGHT", -32, 36)
  ui.scroll = sf
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(W - 50, 10)
  sf:SetScrollChild(content)
  ui.content = content
  ui.summary = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  ui.summary:SetPoint("BOTTOMLEFT", 16, 14)
  ui.closeBtn = MakeButton(ui, L.close, 90, function() ui:Hide() end)
  ui.closeBtn:SetPoint("BOTTOMRIGHT", -14, 10)
  ui:SetScript("OnShow", function()
    ns.Refresh()
    if not ns.db.tourDone then C_Timer.After(0.3, function() if ui:IsShown() then ns.RunTour() end end) end
  end)
  return ui
end

----------------------------------------------------------------------
-- Bouton flottant : ouvre la fiche à la main ; sa bordure prend la couleur de l'état (vert, orange, rouge)
----------------------------------------------------------------------
local float
local function CreateFloat()
  if float then return float end
  float = CreateFrame("Button", "ForeverPrepFloatButton", UIParent)
  ns.floatButton = float
  float:SetSize(40, 40)
  float:SetFrameStrata("MEDIUM")
  float:SetClampedToScreen(true)
  float:SetMovable(true)
  float:RegisterForDrag("LeftButton")
  float:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local p = ns.db.float
  float:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 300, p.y or -150)
  float.ring = float:CreateTexture(nil, "BACKGROUND")
  float.ring:SetPoint("TOPLEFT", -3, 3)
  float.ring:SetPoint("BOTTOMRIGHT", 3, -3)
  float.ring:SetColorTexture(0.6, 0.6, 0.6, 1)
  float.icon = float:CreateTexture(nil, "ARTWORK")
  float.icon:SetAllPoints()
  float.icon:SetTexture("Interface\\Icons\\INV_Potion_51")
  float:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  float.label = float:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  float.label:SetPoint("TOP", float, "BOTTOM", 0, -2)
  float.label:SetText(L.floatLabel)
  float:SetScript("OnDragStart", function(self) self:StartMoving() end)
  float:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    ns.db.float.point, ns.db.float.x, ns.db.float.y = point, x, y
  end)
  float:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.ShowOptions(true) else ns.Toggle() end
  end)
  float:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ForeverPrep", 1, 0.82, 0)
    if self.summary then GameTooltip:AddLine(self.summary, 1, 1, 1, true) end
    GameTooltip:AddLine(L.floatTip, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  float:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return float
end

function ns.UpdateFloat()
  if not ns.db then return end
  if not ns.db.float.shown then
    if float then float:Hide() end
    return
  end
  CreateFloat():Show()
  local res = ns.Analyze()
  local c = COLORS[res.worst] or COLORS.info
  float.ring:SetColorTexture(c[1], c[2], c[3], 1)
  local nWarn = 0
  for _, sct in ipairs(res.sections) do
    for _, r in ipairs(sct.rows) do if r.status == "warn" or r.status == "bad" then nWarn = nWarn + 1 end end
  end
  float.summary = (nWarn == 0) and L.allGood or string.format(L.summary, nWarn, #res.shopping)
end

function ns.Refresh()
  if not ui or not ui:IsShown() then return end
  local inInstance = IsInInstance()
  local ctx = inInstance and ns.Context() or (state.ctx or ns.db.context)
  local res = ns.Analyze(ctx)
  ui.current = res
  Render(res)
end

-- Ouverture automatique (Core.lua)
function ns.Show(res, reason)
  CreateUI()
  if reason == "instance" then state.reason = string.format(L.reason_instance, GetRealZoneText() or "")
  elseif reason then state.reason = L["reason_" .. reason] end
  ui:Show()
  ns.Refresh()
end

function ns.Toggle()
  CreateUI()
  if ui:IsShown() then ui:Hide() else state.reason = nil; ui:Show() end
end

----------------------------------------------------------------------
-- Options
----------------------------------------------------------------------
local opt
function ns.ShowOptions(standalone)
  if not ui then CreateUI() end
  if standalone and not ui:IsShown() then ui:Show() end
  if not opt then
    opt = CreateFrame("Frame", "ForeverPrepOptionsFrame", ui, "BasicFrameTemplateWithInset")
    opt:SetSize(500, 300)
    opt:SetPoint("CENTER", ui, "CENTER", 0, 0)
    opt:SetFrameStrata("DIALOG")
    local t = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 12, -6)
    t:SetText(L.optTitle)
    local y = -34
    local function C(text, get, set)
      local cb = MakeCheck(opt, text, get, set)
      cb:SetPoint("TOPLEFT", 16, y)
      y = y - 28
    end
    C(L.optAutoInstance, function() return ns.db.autoInstance end, function(v) ns.db.autoInstance = v end)
    C(L.optAutoReady, function() return ns.db.autoReady end, function(v) ns.db.autoReady = v end)
    C(L.optAutoLFG, function() return ns.db.autoLFG end, function(v) ns.db.autoLFG = v end)
    C(L.optMerchant, function() return ns.db.merchant end, function(v) ns.db.merchant = v end)
    C(L.optMinimap, function() return not ns.db.minimap.hide end, function(v) ns.db.minimap.hide = not v; ns.UpdateMinimapButton() end)
    C(L.optFloat, function() return ns.db.float.shown end, function(v) ns.db.float.shown = v; ns.UpdateFloat() end)
    local note = opt:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 20, y - 6)
    note:SetText(L.optOnlyIfMissing)
    local close = MakeButton(opt, L.close, 100, function() opt:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -14, 12)
    opt:Hide()
  end
  opt:SetShown(not opt:IsShown())
end

----------------------------------------------------------------------
-- Chez le marchand : les objets de la liste qu'il vend, achat en un clic
----------------------------------------------------------------------
local mp
local function MerchantItemID(i)
  if GetMerchantItemID then return GetMerchantItemID(i) end
  local link = GetMerchantItemLink(i)
  return link and tonumber(link:match("item:(%d+)"))
end

local function Offers()
  local res = ns.Analyze()
  local want = {}
  for _, s in ipairs(res.shopping) do want[s.id] = s end
  local offers = {}
  for i = 1, GetMerchantNumItems() do
    local id = MerchantItemID(i)
    if id and want[id] then
      local name, texture, price, batch, numAvailable, _, _, extendedCost = GetMerchantItemInfo(i)
      batch = (batch and batch > 0) and batch or 1
      if not extendedCost and (numAvailable == -1 or (numAvailable or 0) > 0) then
        local qty = want[id].qty
        local batches = math.ceil(qty / batch)
        offers[#offers + 1] = { index = i, id = id, name = name, icon = texture, qty = batches * batch,
                                batch = batch, batches = batches, cost = batches * (price or 0) }
      end
    end
  end
  return offers
end

local buying = false
local function Buy(offer, done)
  -- par lots (flèches par 200…) ou par piles, un appel toutes les 0,3 s
  local calls = {}
  if offer.batch > 1 then
    for _ = 1, offer.batches do calls[#calls + 1] = 1 end
  else
    local maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(offer.index)) or 20
    local left = offer.qty
    while left > 0 do
      local n = math.min(left, maxStack)
      calls[#calls + 1] = n
      left = left - n
    end
  end
  for k, n in ipairs(calls) do
    C_Timer.After((k - 1) * 0.3, function()
      if offer.batch > 1 then BuyMerchantItem(offer.index) else BuyMerchantItem(offer.index, n) end
      if k == #calls then
        Print(L.merchantBought, offer.qty, offer.name or "?")
        if done then done() end
      end
    end)
  end
end

local function BuyAll()
  if buying then return end
  local offers = Offers()
  local total = 0
  for _, o in ipairs(offers) do total = total + o.cost end
  if total > GetMoney() then return Print(L.merchantNoMoney) end
  buying = true
  local i = 0
  local function nextOffer()
    i = i + 1
    if offers[i] then Buy(offers[i], nextOffer) else buying = false; C_Timer.After(0.5, ns.OnMerchant) end
  end
  nextOffer()
end

function ns.OnMerchant()
  if not MerchantFrame then return end
  if not mp then
    mp = CreateFrame("Frame", "ForeverPrepMerchantFrame", MerchantFrame, "BasicFrameTemplateWithInset")
    mp:SetSize(300, 120)
    mp:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 4, 0)
    mp.title = mp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mp.title:SetPoint("TOPLEFT", 12, -6)
    mp.title:SetText(L.merchantTitle)
    mp.lines = {}
    mp.buyAll = MakeButton(mp, "", 260, function() StaticPopup_Show("FOREVERPREP_BUY", mp.totalText) end)
    mp.buyAll:SetPoint("BOTTOM", 0, 10)
  end
  local offers = Offers()
  if #offers == 0 then mp:Hide() return end
  for _, l in ipairs(mp.lines) do l:Hide() end
  local total = 0
  for n, o in ipairs(offers) do
    local l = mp.lines[n]
    if not l then
      l = CreateFrame("Frame", nil, mp)
      l:SetSize(276, 20)
      l.icon = l:CreateTexture(nil, "ARTWORK")
      l.icon:SetSize(18, 18)
      l.icon:SetPoint("LEFT")
      l.text = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      l.text:SetPoint("LEFT", 22, 0)
      l.text:SetPoint("RIGHT", -64, 0)
      l.text:SetJustifyH("LEFT")
      l.btn = MakeButton(l, L.merchantBuy, 60, nil)
      l.btn:SetPoint("RIGHT")
      mp.lines[n] = l
    end
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", 12, -30 - (n - 1) * 22)
    l.icon:SetTexture(o.icon)
    l.text:SetText(string.format("%d × %s — %s", o.qty, o.name or "?", ns.FormatMoney(o.cost)))
    l.btn:SetScript("OnClick", function() if not buying then Buy(o, function() C_Timer.After(0.5, ns.OnMerchant) end) end end)
    l:Show()
    total = total + o.cost
  end
  mp.totalText = ns.FormatMoney(total)
  mp.buyAll:SetText(string.format(L.merchantBuyAll, mp.totalText))
  mp:SetHeight(70 + #offers * 22)
  mp:Show()
end

function ns.OnMerchantClosed() if mp then mp:Hide() end end

----------------------------------------------------------------------
-- Tutoriel, minicarte, commandes
----------------------------------------------------------------------
function ns.RunTour()
  CreateUI()
  if not ui:IsShown() then ui:Show() end
  ns.StartTour({
    { target = function() return ui.scroll end, title = L.t1t, text = L.t1 },
    { target = function() return ui.ctxBtn end, title = L.t2t, text = L.t2 },
    { target = function() return ui.roleBtn end, title = L.t3t, text = L.t3 },
    { target = function() return ui.summary end, title = L.t4t, text = L.t4 },
    { target = function() return ui.optBtn end, title = L.t5t, text = L.t5 },
    { target = function() return ns.minimapButton end, title = L.t6t, text = L.t6 },
    { target = function() return ns.floatButton end, title = L.t7t, text = L.t7 },
  }, function() ns.db.tourDone = true end)
end

local mmb, dbi
local ICON = "Interface\\Icons\\INV_Potion_51"
local function PlaceMinimapButton()
  local a = math.rad(ns.db.minimap.angle or 160)
  local r = (Minimap:GetWidth() / 2) + 10
  mmb:ClearAllPoints()
  mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.UpdateMinimapButton()
  if dbi then
    ns.db.ldbIcon.hide = ns.db.minimap.hide
    if ns.db.minimap.hide then dbi:Hide("ForeverPrep") else dbi:Show("ForeverPrep") end
    return
  end
  if not mmb then return end
  mmb:SetShown(not ns.db.minimap.hide)
  PlaceMinimapButton()
end

local function CreateMinimapButton()
  if not Minimap then return end
  mmb = CreateFrame("Button", "ForeverPrepMinimapButton", Minimap)
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
    GameTooltip:AddLine("ForeverPrep", 1, 0.82, 0)
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
  local obj = LDB:NewDataObject("ForeverPrep", {
    type = "launcher", icon = ICON,
    OnClick = function() ns.Toggle() end,
    OnTooltipShow = function(tt) tt:AddLine("ForeverPrep", 1, 0.82, 0); tt:AddLine(L.minimapTip1, 1, 1, 1) end,
  })
  local DBI = LS("LibDBIcon-1.0", true)
  if obj and DBI then
    ns.db.ldbIcon = ns.db.ldbIcon or { hide = ns.db.minimap.hide }
    DBI:Register("ForeverPrep", obj, ns.db.ldbIcon)
    dbi = DBI
    if mmb then mmb:Hide() end
    ns.minimapButton = DBI.GetMinimapButton and DBI:GetMinimapButton("ForeverPrep") or ns.minimapButton
  end
end

ns.OnLoaded = function()
  CreateMinimapButton()
  StaticPopupDialogs["FOREVERPREP_BUY"] = {
    text = L.buyConfirm, button1 = YES, button2 = NO,
    OnAccept = function() BuyAll() end,
    timeout = 0, whileDead = false, hideOnEscape = true,
  }
end
ns.OnLogin = function()
  SetupBroker()
  C_Timer.After(3, ns.UpdateFloat)
end

local ROLE_ALIASES = { auto = "auto", tank = "tank", soigneur = "heal", heal = "heal", healer = "heal",
                       physique = "melee", physical = "melee", melee = "melee", magique = "caster", magic = "caster", caster = "caster" }

SLASH_FOREVERPREP1 = "/prep"
SLASH_FOREVERPREP2 = "/foreverprep"
SlashCmdList.FOREVERPREP = function(msg)
  msg = ((msg or ""):match("^%s*(.-)%s*$")):lower()
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" then
    ns.Toggle()
  elseif cmd == "raid" or cmd == "donjon" or cmd == "dungeon" then
    ns.db.context = (cmd == "raid") and "raid" or "dungeon"
    state.ctx = ns.db.context
    CreateUI(); ui:Show(); ns.Refresh()
  elseif cmd == "role" and ROLE_ALIASES[arg] then
    ns.db.role = ROLE_ALIASES[arg]
    CreateUI(); ui:Show(); ns.Refresh()
  elseif cmd == "bouton" or cmd == "button" then
    ns.db.float.shown = not ns.db.float.shown
    ns.UpdateFloat()
    Print(ns.db.float.shown and L.floatShown or L.floatHidden)
  elseif cmd == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    ns.UpdateMinimapButton()
    Print(ns.db.minimap.hide and L.minimapHidden or L.minimapShown)
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then
    ns.lang, ns.db.lang = arg, arg
    ns.Refresh()
  elseif cmd == "tuto" or cmd == "tutorial" then
    ns.RunTour()
  else
    Print(L.helpText)
  end
end

function ForeverPrep_OnCompartmentClick() ns.Toggle() end
