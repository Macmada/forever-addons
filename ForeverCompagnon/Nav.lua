local _, root = ...
local L = root.L

-- Flèche de navigation intégrée (à la TomTom) : une flèche à l'écran qui pointe vers le but, avec la distance en mètres
-- de jeu (yards) et le temps à pied, plus le repère natif du jeu sur la carte. Utilisée par « Guide-moi » (Préparation),
-- les sources des objets (Équipement, Métiers) et la commande /fp way x y [nom] (ou /way si TomTom n'est pas là).
--
-- Positions : C_Map.GetWorldPosFromMapPos donne des coordonnées du monde (x vers le nord, y vers l'ouest) ;
-- GetPlayerFacing : 0 = nord, sens inverse des aiguilles d'une montre. Dans les donjons, le jeu cache la position :
-- la flèche dit alors seulement le nom du but.

local N = { target = nil }
root.Nav = N
local frame
local RUN = 7                       -- vitesse de course (yards par seconde)
local FLY = 26                      -- vol de maître de vol, détours compris (yards par seconde, estimation)
local FLY_EXTRA = 20                -- décollage, atterrissage, dialogue avec le maître de vol (secondes)
local G = root.Game

-- Vitesse de déplacement : course, ou monture (le jeu ne dit pas si tu en as une : à partir du niveau 40)
function N.Speed()
  local lvl = UnitLevel and UnitLevel("player") or 1
  return RUN * ((lvl >= 40) and 1.6 or 1)
end

local function Vec(x, y)
  if CreateVector2D then return CreateVector2D(x, y) end
  return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
local function XY(v)
  if not v then return nil end
  if v.GetXY then return v:GetXY() end
  return v.x, v.y
end

-- Position du monde d'un point de carte (x, y en 0-100) : continent, nord, ouest
function N.World(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and mapID) then return nil end
  local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, Vec(x / 100, y / 100))
  if not ok or not pos then return nil end
  local wx, wy = XY(pos)
  return cont, wx, wy
end

-- Position du joueur : continent, nord, ouest (nil dans un donjon ou si le jeu la cache)
function N.Player()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local map = C_Map.GetBestMapForUnit("player")
  if not map then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not ok or not pos then return nil end
  local px, py = XY(pos)
  if not px or (issecretvalue and issecretvalue(px)) then return nil end
  return N.World(map, px * 100, py * 100)
end

-- Distance (yards) et angle de la flèche (radians, sens inverse des aiguilles, 0 = devant) vers le but
function N.Bearing()
  local t = N.target
  if not t then return nil end
  local pc, px, py = N.Player()
  local tc, tx, ty = N.World(t.mapID, t.x, t.y)
  if not (pc and tc) then return nil, nil, "unknown" end
  if pc ~= tc then return nil, nil, "continent" end
  local dn, dw = tx - px, ty - py
  local dist = math.sqrt(dn * dn + dw * dw)
  local facing = GetPlayerFacing and GetPlayerFacing()
  if not facing or (issecretvalue and issecretvalue(facing)) then return dist, nil, "nofacing" end
  local angle = math.atan2(dw, dn) - facing          -- direction du but par rapport au regard du joueur
  return dist, angle
end

local function Fmt(sec)
  sec = math.floor(sec + 0.5)
  if sec >= 60 then return string.format("%d min %02d s", math.floor(sec / 60), sec % 60) end
  return sec .. " s"
end

local function Update(self, elapsed)
  self.acc = (self.acc or 0) + (elapsed or 0)
  if self.acc < 0.05 then return end
  self.acc = 0
  local t = N.target
  if not t then self:Hide(); return end
  local dist, angle, why = N.Bearing()
  if dist and dist < 5 then
    self.arrow:SetRotation(0)
    self.arrow:SetVertexColor(0.3, 1, 0.3)
    self.dist:SetText(L.navArrived)
    if not self.arrivedAt then
      self.arrivedAt = GetTime()
      if N.route then N.Arrived() end
    elseif GetTime() - self.arrivedAt > 4 and N.target and not N.route then N.Clear() end
    return
  end
  self.arrivedAt = nil
  if angle then
    self.arrow:Show()
    self.arrow:SetRotation(angle)
    -- couleur : vert droit devant, jaune de côté, rouge derrière
    local a = math.abs(((angle + math.pi) % (2 * math.pi)) - math.pi)
    local f = a / math.pi
    self.arrow:SetVertexColor(math.min(1, 2 * f), math.min(1, 2 * (1 - f)), 0.2)
  else
    self.arrow:Hide()
  end
  if N.route and N.route.waitTaxi then
    self.dist:SetText(string.format(L.navTakeFlight, N.route.waitTaxi))
  elseif dist then
    self.dist:SetText(string.format(L.navDist, math.floor(dist + 0.5), Fmt(dist / N.Speed())))
  elseif why == "continent" then
    self.dist:SetText(string.format(L.navOtherContinent, t.zone or "?"))
  else
    self.dist:SetText(string.format(L.navNoPos, t.zone or "?"))
  end
end

local function Create()
  if frame then return frame end
  frame = CreateFrame("Button", "ForeverCompagnonArrow", UIParent)
  frame:SetSize(150, 104)
  local p = root.db and root.db.arrowPos
  if p then frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p[1], p[2]) else frame:SetPoint("TOP", 0, -140) end
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("RightButtonUp")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if root.db and type(x) == "number" then root.db.arrowPos = { x, y } end
  end)
  frame:SetScript("OnClick", function() N.Clear() end)
  frame.arrow = frame:CreateTexture(nil, "ARTWORK")
  frame.arrow:SetSize(56, 56)
  frame.arrow:SetPoint("TOP", 0, 0)
  frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOP", frame.arrow, "BOTTOM", 0, -2)
  frame.title:SetWidth(240)
  frame.dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.dist:SetPoint("TOP", frame.title, "BOTTOM", 0, -2)
  frame:SetScript("OnUpdate", Update)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(N.target and N.target.title or "")
    GameTooltip:AddLine(L.navTip, 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame:Hide()
  return frame
end

-- Va vers (carte, x, y en 0-100) ; repère natif du jeu aussi posé sur la carte
function N.Set(mapID, x, y, title)
  if not (mapID and x and y) then return false end
  local zone = root.Game and root.Game.MapName and root.Game.MapName(mapID)
  if not zone and C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    zone = ok and info and info.name or nil
  end
  N.target = { mapID = mapID, x = x, y = y, title = title or zone or "?", zone = zone }
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    pcall(function()
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
  end
  local f = Create()
  f.title:SetText(N.target.title .. (zone and (" |cffa0a0a0(" .. zone .. string.format(" %.1f, %.1f", x, y) .. ")|r") or ""))
  f.arrivedAt = nil
  f:Show()
  return true
end

function N.Clear()
  N.target = nil
  N.route = nil
  if frame then frame:Hide() end
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
end

-- Le plus proche d'une liste de lieux { name, mapID, x, y } (même continent que toi d'abord)
function N.Closest(places)
  local pc, px, py = N.Player()
  local best, bestD
  for _, p in ipairs(places or {}) do
    local c, x, y = N.World(p.mapID, p.x, p.y)
    local d
    if pc and c == pc then d = math.sqrt((x - px) ^ 2 + (y - py) ^ 2) else d = math.huge end
    if not best or d < bestD then best, bestD = p, d end
  end
  return best, bestD
end

-- /fp way 42.5 63 Nom du lieu ; /fp way (efface)
function N.Command(msg)
  local x, y, title = (msg or ""):match("^%s*([%d%.]+)[%s,]+([%d%.]+)%s*(.-)%s*$")
  x, y = tonumber(x), tonumber(y)
  if not (x and y) then N.Clear(); root.Print(L.navCleared); return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then root.Print(L.navNoMap); return end
  N.Set(map, x, y, title ~= "" and title or nil)
end

root.OnLogin(function()
  -- /way si TomTom n'est pas installé (même syntaxe : /way 42 63 nom)
  if not (SlashCmdList.TOMTOM_WAY or SlashCmdList.TOMTOM) then
    SLASH_FOREVERCOMPAGNONWAY1 = "/way"
    SlashCmdList.FOREVERCOMPAGNONWAY = N.Command
  end
end)

----------------------------------------------------------------------
-- Itinéraire le plus rapide : à pied, ou maître de vol le plus proche -> vol -> à pied. Les points de vol sont appris
-- sur ton personnage quand tu ouvres la carte d'un maître de vol (le jeu ne les donne qu'à ce moment-là).
----------------------------------------------------------------------
local function CharKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
local function Taxi()
  if not root.db then return {} end
  root.db.taxi = root.db.taxi or {}
  root.db.taxi[CharKey()] = root.db.taxi[CharKey()] or {}
  return root.db.taxi[CharKey()]
end
N.Taxi = Taxi

-- Carte d'un maître de vol ouverte : chaque point connu (atteignable ou celui-ci) est retenu, avec sa position du monde
function N.LearnTaxi()
  local mapID = G.Get("GetTaxiMapID") and _G.GetTaxiMapID()
  local known = Taxi()
  local n = 0
  local all = G.Get("C_TaxiMap.GetAllTaxiNodes")
  if all and mapID then
    local ok, nodes = pcall(all, mapID)
    if ok and type(nodes) == "table" then
      G.used.taxi = "C_TaxiMap.GetAllTaxiNodes"
      local unreachable = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
      for _, nd in ipairs(nodes) do
        local x, y = XY(nd.position)
        if nd.name and x and nd.state ~= unreachable then
          local c, wx, wy = N.World(mapID, x * 100, y * 100)
          if c then known[nd.name] = { name = nd.name, mapID = mapID, x = x * 100, y = y * 100, c = c, wx = wx, wy = wy }; n = n + 1 end
        end
      end
      return n
    end
  end
  local num = G.Get("NumTaxiNodes")
  if num and mapID then
    G.used.taxi = "NumTaxiNodes"
    for i = 1, num() do
      local name = _G.TaxiNodeName(i)
      local kind = _G.TaxiNodeGetType and _G.TaxiNodeGetType(i)
      local x, y = _G.TaxiNodePosition(i)
      if name and x and kind ~= "NONE" and kind ~= "DISTANT" then
        local c, wx, wy = N.World(mapID, x * 100, y * 100)
        if c then known[name] = { name = name, mapID = mapID, x = x * 100, y = y * 100, c = c, wx = wx, wy = wy }; n = n + 1 end
      end
    end
  end
  return n
end

local function Dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end
local function Nearest(c, x, y)
  local best, bd
  for _, f in pairs(Taxi()) do
    if f.c == c then
      local d = Dist(f.wx, f.wy, x, y)
      if not bd or d < bd then best, bd = f, d end
    end
  end
  return best, bd
end

-- Plan vers (carte, x, y) : { walk = secondes à pied, fly = { from, to, time } ou nil, other = autre continent }
function N.Plan(mapID, x, y)
  local pc, px, py = N.Player()
  local dc, dx, dy = N.World(mapID, x, y)
  if not (pc and dc) then return { unknown = true } end
  if pc ~= dc then return { other = true } end
  local speed = N.Speed()
  local plan = { walk = Dist(px, py, dx, dy) / speed }
  local a, da = Nearest(pc, px, py)
  local b, db = Nearest(dc, dx, dy)
  if a and b and a ~= b then
    local t = da / speed + Dist(a.wx, a.wy, b.wx, b.wy) / FLY + FLY_EXTRA + db / speed
    if t < plan.walk * 0.8 then plan.fly = { from = a, to = b, time = t } end
  end
  return plan
end

local function Fmt2(sec) return Fmt(sec or 0) end
N.Fmt = Fmt2

-- Va vers un lieu par le chemin le plus rapide : la flèche suit chaque étape toute seule
function N.Go(mapID, x, y, title)
  local plan = N.Plan(mapID, x, y)
  if plan.fly then
    local f = plan.fly
    N.Set(f.from.mapID, f.from.x, f.from.y, string.format(L.navFlightMaster, f.from.name))
    N.route = { step = 1, from = f.from, to = f.to, dest = { mapID = mapID, x = x, y = y, title = title } }
    root.Print(L.navRoute, title or "?", f.from.name, f.to.name, Fmt2(f.time), Fmt2(plan.walk))
    return true, plan
  end
  local ok = N.Set(mapID, x, y, title)
  if ok and plan.walk then root.Print(L.navRouteWalk, title or "?", Fmt2(plan.walk)) end
  return ok, plan
end

-- Étape atteinte : au maître de vol, on attend le vol ; après le vol (ou arrivé près du point d'arrivée), le but
function N.Arrived()
  local r = N.route
  if not r then return end
  if r.step == 1 then
    r.step = 2
    r.waitTaxi = r.to.name
    root.Print(L.navTakeFlight, r.to.name)
  end
end

local function Continue()
  local r = N.route
  if not r then return end
  local d = r.dest
  N.route = nil
  N.Set(d.mapID, d.x, d.y, d.title)
end

local tev = CreateFrame("Frame")
for _, e in ipairs({ "TAXIMAP_OPENED", "PLAYER_CONTROL_GAINED" }) do pcall(tev.RegisterEvent, tev, e) end
tev:SetScript("OnEvent", function(_, event)
  if event == "TAXIMAP_OPENED" then
    local ok, n = pcall(N.LearnTaxi)
    if ok and n and n > 0 then root.taxiLearned = n end
  elseif event == "PLAYER_CONTROL_GAINED" and N.route and N.route.step == 2 then
    -- fin du vol (le jeu rend le contrôle au joueur à l'atterrissage) : on vise le but
    C_Timer.After(1, Continue)
  end
end)
-- secours : déjà près du point d'arrivée (vol pris autrement, ou événement manqué)
local function NearLanding()
  local r = N.route
  if not (r and r.step == 2) then return end
  local pc, px, py = N.Player()
  if pc and pc == r.to.c and Dist(px, py, r.to.wx, r.to.wy) < 150 and not (_G.UnitOnTaxi and _G.UnitOnTaxi("player")) then Continue() end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(2, NearLanding) end

-- /fp vols : tes points de vol connus sur ce continent, le plus proche d'abord
function N.ListTaxi()
  local pc, px, py = N.Player()
  local list = {}
  for _, f in pairs(Taxi()) do list[#list + 1] = f end
  if #list == 0 then root.Print(L.navNoTaxi); return end
  table.sort(list, function(a, b)
    local da = (pc == a.c and px) and Dist(a.wx, a.wy, px, py) or math.huge
    local db = (pc == b.c and px) and Dist(b.wx, b.wy, px, py) or math.huge
    if da ~= db then return da < db end
    return a.name < b.name
  end)
  root.Print(L.navTaxiTitle, #list)
  for _, f in ipairs(list) do
    local d = (pc == f.c and px) and Dist(f.wx, f.wy, px, py)
    root.Print("  %s%s", f.name, d and string.format(" |cffa0a0a0(%d m)|r", math.floor(d + 0.5)) or "")
  end
end
