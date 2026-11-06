local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverPrep") end
local L = ns.L
local Print = ns.Print

local W, H = 600, 660
local COLORS = { ok = { 0.25, 0.8, 0.3 }, info = { 0.6, 0.6, 0.6 }, warn = { 1, 0.6, 0.1 }, bad = { 0.95, 0.2, 0.2 } }
local K = ns.Kit
local D = ns.Data
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

local function RoleKey(res)
  if ns.db.role == "auto" then return ns.AutoRole(res.class) end
  return ns.db.role
end

local function RoleLabel(res)
  if ns.db.role == "auto" then return string.format(L.role_auto, L["role_" .. ns.AutoRole(res.class)]) end
  return L["role_" .. ns.db.role]
end

local SECTION_ICON = {
  consumables = "Interface\\Icons\\INV_Potion_54", reagents = "Interface\\Icons\\INV_Misc_Bag_07",
  buffs = "Interface\\Icons\\Spell_Holy_WordFortitude", gear = "Interface\\Icons\\INV_Chest_Chain",
  character = "Interface\\Icons\\INV_Misc_Rune_01", shopping = "Interface\\Icons\\INV_Misc_Coin_01",
}

----------------------------------------------------------------------
-- Lignes de la fiche (réutilisées) : pastille d'état comme l'appel, icône de l'objet, texte ; une ligne sur deux plus claire
----------------------------------------------------------------------
local rows, used = {}, 0
local function GetRow()
  used = used + 1
  local r = rows[used]
  if not r then
    r = CreateFrame("Button", nil, ui.content)
    r:SetHeight(22)
    r.stripe = r:CreateTexture(nil, "BACKGROUND")
    r.stripe:SetAllPoints()
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(16, 16)
    r.dot:SetPoint("LEFT", 6, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 28, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", 54, 0)
    r.text:SetPoint("RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(true)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.3, 0.08)
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

-- Titre de rubrique : icône, nom en lettres de livre, filet doré
local headers, hused = {}, 0
local function GetHeader()
  hused = hused + 1
  local h = headers[hused]
  if not h then
    h = CreateFrame("Frame", nil, ui.content)
    h:SetHeight(26)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(20, 20)
    h.icon:SetPoint("LEFT", 2, 0)
    h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.fs:SetPoint("LEFT", h.icon, "RIGHT", 8, 0)
    K.TitleFont(h.fs, 16, "GameFontNormal")
    h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.count:SetPoint("RIGHT", -6, 0)
    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetPoint("BOTTOMLEFT", 0, 0)
    h.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    h.rule:SetHeight(1)
    h.rule:SetColorTexture(0.65, 0.48, 0.16, 0.8)
    headers[hused] = h
  end
  h:Show()
  return h
end

local function Render(res)
  for _, r in ipairs(rows) do r:Hide() end
  for _, h in ipairs(headers) do h:Hide() end
  used, hused = 0, 0
  if res.message then
    -- message seul (combat sans analyse précédente, erreur d'analyse) : bandeau et titres remplis quand même
    K.SetStatus(ui.bannerIcon, "warn")
    ui.bannerText:SetTextColor(1, 0.75, 0.3)
    ui.bannerText:SetText(res.message)
    ui.bannerSub:SetText(string.format(L.bannerSub, res.level or 0, RoleLabel(res)))
    ui.summary:SetText("")
    ui.title:SetText(res.context == "raid" and L.titleRaid or L.title)
    ui.tabDungeon:SetActive(res.context ~= "raid")
    ui.tabRaid:SetActive(res.context == "raid")
    ui.roleBtn.fs:SetText(string.format(L.role, RoleLabel(res)))
    K.SetRole(ui.roleBtn.icon, RoleKey(res))
    ui.content:SetHeight(10)
    return
  end
  local y = -4
  local width = ui.content:GetWidth()
  local nWarn, nInfo, stripe = 0, 0, 0
  local function Header(key, text, nTodo)
    local h = GetHeader()
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 0, y - 6)
    h:SetPoint("RIGHT", ui.content, "RIGHT", 0, 0)
    h.icon:SetTexture(SECTION_ICON[key] or SECTION_ICON.consumables)
    h.fs:SetText(text)
    h.count:SetText(nTodo and nTodo > 0 and ("|cffff9a1a" .. string.format(L.todoCount, nTodo) .. "|r") or "")
    y = y - 34
    stripe = 0
  end
  local function Row(r, noStatus)
    local row = GetRow()
    stripe = stripe + 1
    row.stripe:SetColorTexture(1, 1, 1, stripe % 2 == 0 and 0.04 or 0)
    row.dot:SetShown(not noStatus)
    if not noStatus then K.SetStatus(row.dot, r.status) end
    row.icon:SetShown(r.icon ~= nil)
    if r.icon then row.icon:SetTexture(r.icon) end
    row.itemID = r.itemID or r.id
    row.text:SetWidth(width - 60)
    local c = (r.status == "bad" and "|cffff6a5a") or (r.status == "warn" and "|cffffc860") or ""
    row.text:SetText(c ~= "" and (c .. r.text .. "|r") or r.text)
    local h = math.max(22, row.text:GetStringHeight() + 6)
    row:SetHeight(h)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("RIGHT", ui.content, "RIGHT", 0, 0)
    y = y - h - 1
  end
  for _, s in ipairs(res.sections) do
    if #s.rows > 0 then
      local todo = 0
      for _, r in ipairs(s.rows) do if r.status == "warn" or r.status == "bad" then todo = todo + 1 end end
      Header(s.key, L["sec_" .. s.key], todo)
      for _, r in ipairs(s.rows) do
        Row(r)
        if r.status == "warn" or r.status == "bad" then nWarn = nWarn + 1 elseif r.status == "info" then nInfo = nInfo + 1 end
      end
    end
  end
  Header("shopping", L.sec_shopping)
  if #res.shopping == 0 then
    Row({ status = "ok", text = L.shopEmpty })
  else
    for _, it in ipairs(res.shopping) do
      local price = it.price and (" |cffffd100" .. ns.FormatMoney(it.price * it.qty) .. "|r |cffa0a0a0(" .. (it.estimated and "~" or "")
                    .. string.format(L.priceUnit, ns.FormatMoney(it.price)) .. ")|r") or ""
      local where = it.vendor and ("  |cff66ccff" .. (L["vendor_" .. it.vendor] or "") .. "|r") or ""
      Row({ icon = it.icon, itemID = it.id, text = string.format(L.shopLine, it.qty, it.name) .. price .. where }, true)
    end
    if res.shopCost then Row({ text = "|cffffd100" .. string.format(L.shopTotal, ns.FormatMoney(res.shopCost)) .. "|r" }, true) end
    Row({ text = "|cffa0a0a0" .. L.shopHint .. "|r" }, true)
  end
  ui.content:SetHeight(-y + 8)
  -- bandeau d'état : prêt (vert), presque (orange), pas prêt (rouge)
  local worst = res.worst or (nWarn > 0 and "warn" or "ok")
  K.SetStatus(ui.bannerIcon, worst == "info" and "ok" or worst)
  local c = COLORS[worst == "info" and "ok" or worst] or COLORS.ok
  ui.bannerText:SetTextColor(c[1], c[2], c[3])
  ui.bannerText:SetText((nWarn == 0) and (res.context == "raid" and L.bannerOkRaid or L.bannerOk)
                        or string.format(worst == "bad" and L.bannerBad or L.bannerWarn, nWarn))
  ui.bannerSub:SetText((state.stale and ("|cffffc860" .. L.combatStale .. "|r · ") or "") .. (state.reason and (state.reason .. " · ") or "")
                       .. string.format(L.bannerSub, res.level, RoleLabel(res)))
  ui.summary:SetText((nWarn == 0) and ("|cff40cc4d" .. L.allGood .. "|r") or string.format(L.summary, nWarn, nInfo))
  ui.title:SetText(res.context == "raid" and L.titleRaid or L.title)
  ui.tabDungeon:SetActive(res.context ~= "raid")
  ui.tabRaid:SetActive(res.context == "raid")
  ui.roleBtn.fs:SetText(string.format(L.role, RoleLabel(res)))
  K.SetRole(ui.roleBtn.icon, RoleKey(res))
  ui.reason:SetText(state.reason or "")
end

----------------------------------------------------------------------
-- Fenêtre
----------------------------------------------------------------------
local function CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverPrepFrame", UIParent, "BasicFrameTemplateWithInset")
  ns.SafeClose(ui)
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
  local logo = ui:CreateTexture(nil, "OVERLAY")
  logo:SetSize(16, 16)
  logo:SetPoint("TOPLEFT", 8, -4)
  logo:SetTexture("Interface\\Icons\\INV_Potion_51")
  logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  ui.title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ui.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  ui.diagBtn = ns.MakeDiagButton(ui)

  -- bandeau : prêt ou pas, en grand
  local banner = CreateFrame("Frame", nil, ui)
  banner:SetPoint("TOPLEFT", 12, -30)
  banner:SetPoint("TOPRIGHT", -12, -30)
  banner:SetHeight(52)
  K.Panel(banner, 0.9)
  ui.banner = banner
  ui.bannerIcon = banner:CreateTexture(nil, "ARTWORK")
  ui.bannerIcon:SetSize(34, 34)
  ui.bannerIcon:SetPoint("LEFT", 10, 0)
  ui.bannerText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ui.bannerText:SetPoint("TOPLEFT", ui.bannerIcon, "TOPRIGHT", 10, 0)
  ui.bannerText:SetPoint("RIGHT", -10, 0)
  ui.bannerText:SetJustifyH("LEFT")
  K.TitleFont(ui.bannerText, 19, "GameFontNormalLarge")
  ui.bannerSub = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.bannerSub:SetPoint("BOTTOMLEFT", ui.bannerIcon, "BOTTOMRIGHT", 10, 0)
  ui.bannerSub:SetPoint("RIGHT", -10, 0)
  ui.bannerSub:SetJustifyH("LEFT")
  ui.reason = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")   -- gardé pour le tutoriel ; affiché dans bannerSub
  ui.reason:Hide()

  -- onglets Donjon / Raid, rôle, actions en icônes
  local function SetCtx(c) state.ctx = c; ns.db.context = c; ns.Refresh() end
  ui.tabDungeon = K.Tab(ui, L.ctx_dungeon, function() SetCtx("dungeon") end)
  ui.tabDungeon:SetPoint("TOPLEFT", 14, -92)
  ui.tabRaid = K.Tab(ui, L.ctx_raid, function() SetCtx("raid") end)
  ui.tabRaid:SetPoint("LEFT", ui.tabDungeon, "RIGHT", 4, 0)
  ui.ctxBtn = ui.tabDungeon
  ui.roleBtn = K.Tab(ui, "", function()
    local order = { "auto", "tank", "heal", "melee", "caster" }
    local cur = 1
    for i, r in ipairs(order) do if r == ns.db.role then cur = i end end
    ns.db.role = order[cur % #order + 1]
    ns.Refresh()
  end)
  ui.roleBtn:SetWidth(210)
  ui.roleBtn:SetPoint("LEFT", ui.tabRaid, "RIGHT", 12, 0)
  ui.roleBtn.icon = ui.roleBtn:CreateTexture(nil, "OVERLAY")
  ui.roleBtn.icon:SetSize(18, 18)
  ui.roleBtn.icon:SetPoint("LEFT", 6, 0)
  ui.roleBtn.fs:ClearAllPoints()
  ui.roleBtn.fs:SetPoint("LEFT", 28, 1)
  K.Tooltip(ui.roleBtn, L.roleTipTitle, L.roleTip)
  ui.helpBtn = K.Action(ui, "Interface\\Icons\\INV_Misc_QuestionMark", L.helpLabel, L.tipHelp, function() ns.RunTour() end)
  ui.helpBtn:SetPoint("TOPRIGHT", -18, -90)
  ui.optBtn = K.Action(ui, "Interface\\Icons\\INV_Misc_Gear_01", L.options, L.tipOptions, function() ns.ShowOptions() end)
  ui.optBtn:SetPoint("RIGHT", ui.helpBtn, "LEFT", -22, 0)
  ui.refreshBtn = K.Action(ui, "Interface\\Icons\\Spell_Holy_Renew", L.refresh, L.tipRefresh, function() ns.Refresh() end)
  ui.refreshBtn:SetPoint("RIGHT", ui.optBtn, "LEFT", -22, 0)
  ui.guideBtn = K.Action(ui, "Interface\\Icons\\INV_Misc_Map_01", L.guideLabel, L.tipGuide, function() ns.GuideToVendor() end)
  ui.guideBtn:SetPoint("RIGHT", ui.refreshBtn, "LEFT", -22, 0)

  -- la fiche, sur fond sombre encadré d'or
  local sheet = CreateFrame("Frame", nil, ui)
  sheet:SetPoint("TOPLEFT", 12, -138)
  sheet:SetPoint("BOTTOMRIGHT", -12, 40)
  K.Panel(sheet, 0.55)
  local sf = CreateFrame("ScrollFrame", nil, sheet, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 8, -6)
  sf:SetPoint("BOTTOMRIGHT", -28, 6)
  ui.scroll = sf
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(W - 24 - 40, 10)
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
-- « Guide-moi » : suivi des marchands sur la minicarte, et repère vers le plus proche si All The Things le connaît
----------------------------------------------------------------------
local function TrackingCount()
  if C_Minimap and C_Minimap.GetNumTrackingTypes then return C_Minimap.GetNumTrackingTypes() end
  return GetNumTrackingTypes and GetNumTrackingTypes() or 0
end
local function TrackingInfo(i)
  if C_Minimap and C_Minimap.GetTrackingInfo then
    local a, _, c = C_Minimap.GetTrackingInfo(i)
    if type(a) == "table" then return a.name, a.active end
    return a, c
  end
  if GetTrackingInfo then local n, _, active = GetTrackingInfo(i); return n, active end
end
local function SetTrack(i)
  if C_Minimap and C_Minimap.SetTracking then pcall(C_Minimap.SetTracking, i, true)
  elseif SetTracking then pcall(SetTracking, i, true) end
end

-- Active le suivi des marchands utiles ; renvoie les noms activés
function ns.EnableTracking(kinds)
  local wanted = {}
  for kind in pairs(kinds) do
    for _, key in ipairs(D.tracking[kind] or {}) do
      local name = _G[key] or key
      if type(name) == "string" then wanted[name:lower()] = true end
    end
  end
  local on = {}
  for i = 1, TrackingCount() do
    local name, active = TrackingInfo(i)
    if type(name) == "string" and wanted[name:lower()] then
      if not active then SetTrack(i) end
      on[#on + 1] = name
    end
  end
  return on
end

local function PlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local map = C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return map end
  local x, y = pos:GetXY()
  return map, (x or 0) * 100, (y or 0) * 100
end

local function Waypoint(v)
  -- flèche intégrée de ForeverCompagnon (Nav.lua), sinon TomTom, sinon le repère du jeu
  local nav = ns.root and ns.root.Nav
  if nav and nav.Set(v.mapID, v.x, v.y, v.name) then return "arrow" end
  local TT = _G.TomTom
  if TT and TT.AddWaypoint then
    local ok = pcall(TT.AddWaypoint, TT, v.mapID, v.x / 100, v.y / 100, { title = v.name, persistent = false })
    if ok then return "TomTom" end
  end
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(v.mapID, v.x / 100, v.y / 100))
    if ok then
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
      return "map"
    end
  end
end

function ns.GuideToVendor()
  -- analyse à jour hors combat ; en combat, la dernière (le jeu cache alors une partie des informations)
  local res = (InCombatLockdown and InCombatLockdown() and ui and ui.current) or ns.Analyze()
  if not res or #res.shopping == 0 then return Print(L.guideNothing) end
  local kinds = {}
  for _, it in ipairs(res.shopping) do if it.vendor then kinds[it.vendor] = true end end
  local on = ns.EnableTracking(kinds)
  -- marchand le plus proche (sources intégrées) : par distance réelle si la flèche sait où tu es, sinon sur ta carte
  local map, px, py = PlayerPos()
  local best, bestD
  if ns.ATT and ns.ATT.Available() then
    local all = {}
    for _, it in ipairs(res.shopping) do
      for _, v in ipairs(ns.ATT.Vendors(it.id)) do all[#all + 1] = v end
    end
    local nav = ns.root and ns.root.Nav
    local c, d
    if nav then c, d = nav.Closest(all) end
    if c and d and d < math.huge then best = c
    else
      for _, v in ipairs(all) do
        if v.mapID == map and px then
          local dd = (v.x - px) ^ 2 + (v.y - py) ^ 2
          if not bestD or dd < bestD then best, bestD = v, dd end
        end
      end
    end
  end
  ns.lastGuide = { tracking = on, vendor = best }
  if best then
    local how = Waypoint(best)
    Print(L.guideVendor, best.name, best.x, best.y, (how == "arrow" and L.guideArrow) or (how == "TomTom" and L.guideTomTom) or (how and L.guideMap or ""))
  end
  if #on > 0 then Print(L.guideTracking, table.concat(on, ", "))
  elseif not best then Print(L.guideNone) end
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
  if not ns.db or (InCombatLockdown and InCombatLockdown()) then return end
  if not ns.db.float.shown then
    if float then float:Hide() end
    return
  end
  CreateFloat():Show()
  local okA, res = pcall(ns.Analyze)
  if not okA or type(res) ~= "table" then return end
  local c = COLORS[res.worst] or COLORS.info
  float.ring:SetColorTexture(c[1], c[2], c[3], 1)
  local nWarn = 0
  for _, sct in ipairs(res.sections) do
    for _, r in ipairs(sct.rows) do if r.status == "warn" or r.status == "bad" then nWarn = nWarn + 1 end end
  end
  float.summary = (nWarn == 0) and L.allGood or string.format(L.summary, nWarn, #res.shopping)
end

-- En combat, le jeu cache aux addons une partie des informations (buffs, ressources) : pas d'analyse ; on montre la
-- dernière faite avant le combat, et la fiche se met à jour à la sortie du combat (fenêtre vide le 05/11/2026).
function ns.Refresh()
  if not ui or not ui:IsShown() then return end
  local inInstance = IsInInstance()
  local ctx = inInstance and ns.Context() or (state.ctx or ns.db.context)
  if InCombatLockdown and InCombatLockdown() then
    ns.pendingAfterCombat = true
    if ui.current then
      state.stale = true
      Render(ui.current)
    else
      Render({ context = ctx, level = UnitLevel("player"), class = select(2, UnitClass("player")), sections = {}, shopping = {},
               worst = "info", message = L.combatEmpty })
    end
    return
  end
  local ok, res = pcall(ns.Analyze, ctx)
  if not ok or type(res) ~= "table" then
    Render({ context = ctx, level = UnitLevel("player"), class = select(2, UnitClass("player")), sections = {}, shopping = {},
             worst = "warn", message = string.format(L.analyzeError, tostring(res)) })
    return
  end
  state.stale = nil
  ui.current = res
  Render(res)
end

-- Sortie du combat : fiche ouverte mise à jour (appelé par Core.lua)
function ns.AfterCombat()
  if ns.pendingAfterCombat then ns.pendingAfterCombat = nil; ns.Refresh() end
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
    ns.SafeClose(opt)
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
  for _, s in ipairs(res.ahWanted or {}) do want[s.id] = want[s.id] or s end
  local offers = {}
  for i = 1, ns.Game.MerchantCount() do
    local id = MerchantItemID(i)
    if id and want[id] then
      local name, texture, price, batch, numAvailable, _, _, extendedCost = ns.MerchantItemInfo(i)
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
      local buy = BuyMerchantItem or (C_MerchantFrame and C_MerchantFrame.BuyItem)
      if buy then
        if offer.batch > 1 then buy(offer.index) else buy(offer.index, n) end
      end
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
    ns.SafeClose(mp)
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
    { target = function() return ui.banner end, title = L.t4t, text = L.t4 },
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
  elseif cmd == "diag" then
    ns.ShowDiag()
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
