local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverPrep") end
local L = ns.L
local Print = ns.Print

local COLORS = { ok = { 0.25, 0.8, 0.3 }, info = { 0.6, 0.6, 0.6 }, warn = { 1, 0.6, 0.1 }, bad = { 0.95, 0.2, 0.2 } }
local D = ns.Data

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

function ns.FormatMoney(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local fr = ns.lang ~= "en"
  if g > 0 then return s > 0 and string.format(fr and "%d po %d pa" or "%dg %ds", g, s) or string.format(fr and "%d po" or "%dg", g) end
  if s > 0 then return c > 0 and string.format(fr and "%d pa %d pc" or "%ds %dc", s, c) or string.format(fr and "%d pa" or "%ds", s) end
  return string.format(fr and "%d pc" or "%dc", c)
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
  if nav and nav.Go(v.mapID, v.x, v.y, v.name) then return "arrow" end
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
  if InCombatLockdown and InCombatLockdown() then return end
  local res = ns.Analyze()
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
  -- rouge : un obligatoire manque ; orange : obligatoires faits, il manque du facultatif ; vert : tout est fait
  -- (les conseils seuls ne comptent pas : vert)
  local worst = (res.worst == "bad" or res.worst == "warn") and res.worst or "ok"
  local c = COLORS[worst]
  float.ring:SetColorTexture(c[1], c[2], c[3], 1)
  float.state = worst
  local nMust, nOpt = 0, 0
  for _, sct in ipairs(res.sections) do
    for _, r in ipairs(sct.rows) do if r.status == "bad" then nMust = nMust + 1 elseif r.status == "warn" then nOpt = nOpt + 1 end end
  end
  float.summary = (worst == "ok") and L.allGood
                  or (worst == "bad" and string.format(L.bannerMust, nMust) or string.format(L.bannerOpt, nOpt))
end

-- 4.0 : la fiche est l'onglet Donjon de la fenêtre (Pages.lua) ; ici, on le redessine
function ns.Refresh()
  if ns.root and ns.root.RefreshNow then ns.root.RefreshNow() end
end

-- Sortie du combat (appelé par Core.lua)
function ns.AfterCombat()
  if ns.pendingAfterCombat then ns.pendingAfterCombat = nil; ns.Refresh() end
end

-- Ouverture automatique (Core.lua) et à la main : l'onglet Donjon
function ns.Show(_, reason)
  if ns.root and ns.root.Open then ns.root.prepReason = reason; ns.root.Open("prep") end
end
function ns.Toggle()
  if not (ns.root and ns.root.Open) then return end
  local f = _G.ForeverCompagnonFrame
  if f and f:IsShown() and ns.root.CurrentPage() == "prep" then f:Hide() else ns.root.Open("prep") end
end
function ns.ShowOptions() if ns.root and ns.root.ShowOptions then ns.root.ShowOptions() end end

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
ns.OnLoaded = function()
  StaticPopupDialogs["FOREVERPREP_BUY"] = {
    text = L.buyConfirm, button1 = YES, button2 = NO,
    OnAccept = function() BuyAll() end,
    timeout = 0, whileDead = false, hideOnEscape = true,
  }
end
ns.OnLogin = function()
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
    if ns.root and ns.root.Open then ns.root.Open("prep") end
  elseif cmd == "role" and ROLE_ALIASES[arg] then
    ns.db.role = ROLE_ALIASES[arg]
    if ns.root and ns.root.Open then ns.root.Open("prep") end
  elseif cmd == "diag" then
    ns.ShowDiag()
  elseif cmd == "bouton" or cmd == "button" then
    ns.db.float.shown = not ns.db.float.shown
    ns.UpdateFloat()
    Print(ns.db.float.shown and L.floatShown or L.floatHidden)
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then
    ns.lang, ns.db.lang = arg, arg
    ns.Refresh()
  else
    Print(L.helpText)
  end
end

function ForeverPrep_OnCompartmentClick() ns.Toggle() end
