local _, root = ...

-- Tournée en ville : ce que l'Accueil te demande de faire à pied près d'ici (maître de classe, marchands de la liste de
-- courses, hôtel des ventes) en un seul trajet, dans l'ordre le plus court ; la flèche passe d'un arrêt au suivant.
-- Seulement les arrêts sur ton continent à moins de MAX_YARDS (une ville et ses abords).

local MAX_YARDS = 1500
local FR = root.FR
local T = FR and {
  title = "Tournée en ville : %d arrêts", trainer = "maître de classe", ah = "hôtel des ventes", start = "Tournée : %s.",
  tip = "Un seul trajet, dans l'ordre le plus court ; la flèche passe d'un arrêt au suivant. Clic : partir.",
} or {
  title = "Town round: %d stops", trainer = "class trainer", ah = "auction house", start = "Round: %s.",
  tip = "One trip, shortest order; the arrow moves on to the next stop. Click: go.",
}
root.TourText = T

local function Dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- Hôtels des ventes visités (position du joueur à l'ouverture), par continent
local ev = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function()
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  local x, y
  if pos and pos.GetXY then x, y = pos:GetXY() elseif pos then x, y = pos.x, pos.y end
  if not x or (issecretvalue and issecretvalue(x)) or not root.db then return end
  root.db.auctionHouses = root.db.auctionHouses or {}
  local key = map .. ":" .. math.floor(x * 20) .. ":" .. math.floor(y * 20)       -- un seul relevé par endroit
  root.db.auctionHouses[key] = { mapID = map, x = x * 100, y = y * 100, faction = UnitFactionGroup("player") }
end)

local function NearestAH()
  local list = {}
  local me = UnitFactionGroup("player")
  for _, p in pairs(root.db and root.db.auctionHouses or {}) do
    if not p.faction or p.faction == me then list[#list + 1] = { mapID = p.mapID, x = p.x, y = p.y, name = T.ah } end
  end
  return root.Nav.Closest(list)
end

-- Arrêts : { mapID, x, y, title, what } ; ahWanted : une amélioration à l'hôtel des ventes est proposée
function root.TourStops(ahWanted)
  local Nav = root.Nav
  if not (Nav and Nav.Player) then return {} end
  local pc, px, py = Nav.Player()
  if not pc then return {} end
  local stops = {}
  local function Add(p, title, what)
    if not (p and p.mapID and p.x and p.y) then return end
    local c, wx, wy = Nav.World(p.mapID, p.x, p.y)
    if c ~= pc or Dist(px, py, wx, wy) > MAX_YARDS then return end
    for _, s in ipairs(stops) do
      if s.title == title then s.what[#s.what + 1] = what; return end           -- même marchand : un arrêt
    end
    stops[#stops + 1] = { mapID = p.mapID, x = p.x, y = p.y, title = title, what = { what }, wx = wx, wy = wy }
  end
  local prep = root.mods.ForeverPrep
  if prep and prep.TrainerDue then
    local ok, due, _, t = pcall(prep.TrainerDue)
    if ok and due and #due > 0 and t and t.mapID then Add(t, t.npc or T.trainer, T.trainer) end
  end
  if prep and prep.Analyze and prep.ATT then
    local ok, res = pcall(prep.Analyze)
    for _, it in ipairs(ok and res and res.shopping or {}) do
      local vendors = prep.ATT.Vendors(it.id)
      local best = Nav.Closest(vendors)
      if best then Add(best, best.name or "?", it.name or "?") end
    end
  end
  if ahWanted then
    local ah = NearestAH()
    if ah then Add(ah, T.ah, T.ah) end
  end
  -- ordre : le plus proche d'abord, puis le plus proche du précédent
  local ordered, cx, cy = {}, px, py
  while #stops > 0 do
    local bi, bd = 1, math.huge
    for i, s in ipairs(stops) do
      local d = Dist(cx, cy, s.wx, s.wy)
      if d < bd then bi, bd = i, d end
    end
    local s = table.remove(stops, bi)
    ordered[#ordered + 1] = s
    cx, cy = s.wx, s.wy
  end
  return ordered
end

function root.StartTour(stops)
  stops = stops or root.TourStops(true)
  if #stops == 0 then return false end
  local names = {}
  for _, s in ipairs(stops) do names[#names + 1] = s.title end
  root.Print(T.start, table.concat(names, ", "))
  return root.Nav.Route(stops)
end

-- Ligne de l'Accueil (Now.lua) : seulement à partir de 2 arrêts
function root.TourTodo(lines, ahWanted)
  local stops = root.TourStops(ahWanted)
  if #stops < 2 then return end
  local parts, tip = {}, { title = string.format(T.title, #stops), lines = { { T.tip, 0.85, 0.78, 0.6 } } }
  for i, s in ipairs(stops) do
    parts[#parts + 1] = s.title
    tip.lines[#tip.lines + 1] = { i .. ". " .. s.title .. "  |cffa0a0a0" .. table.concat(s.what, ", ") .. "|r", 1, 1, 1 }
  end
  table.insert(lines, 2, { kind = "card", icon = "Interface\\Icons\\INV_Misc_Map_01", quality = 1, nameColor = { 1, 1, 1 },
                           name = string.format(T.title, #stops), source = table.concat(parts, " · "), tour = true, tip = tip,
                           onClick = function() root.StartTour(stops) end, onRight = function() root.StartTour(stops) end })
  return true
end
