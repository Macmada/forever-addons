local _, root = ...
local L = root.L
local G = root.Game

-- Ce que ForeverCompagnon retient tout seul, pour se passer de Syndicator et d'Auctionator (ils restent utilisés s'ils
-- sont installés) :
--   * inventaire de chaque personnage : sacs (à chaque changement) et banque (quand tu l'ouvres) ;
--   * prix de l'hôtel des ventes : bouton « Relever les prix » sur la fenêtre de l'hôtel des ventes (relevé complet du
--     jeu, permis une fois toutes les 15 minutes), prix unitaire le plus bas de chaque objet, par royaume.
-- Tout est dans ForeverCompagnonDB (commun aux personnages du compte).

local S = {}
root.Store = S

local function Realm() return (GetRealmName and GetRealmName()) or "?" end
local function Me() return (UnitName("player") or "?") .. " - " .. Realm() end
local function DB()
  local db = root.db
  if not db then return nil end
  db.inv = db.inv or {}
  db.prices = db.prices or {}
  return db
end

----------------------------------------------------------------------
-- Inventaire
----------------------------------------------------------------------
local function ReadBags(bags)
  local out = {}
  for _, bag in ipairs(bags) do
    for slot = 1, (G.BagSlots(bag) or 0) do
      local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
      local id = info and info.itemID or G.BagItemID(bag, slot)
      if id then out[id] = (out[id] or 0) + ((info and info.stackCount) or 1) end
    end
  end
  return out
end

-- Sacs de la banque : -1 (banque), sacs de banque classiques (5 à 11), onglets de banque du client moderne
local function BankBags()
  local list, seen = { -1 }, { [-1] = true }
  for b = 5, 11 do if not seen[b] then list[#list + 1] = b; seen[b] = true end end
  if Enum and Enum.BagIndex then
    for k, v in pairs(Enum.BagIndex) do
      if type(k) == "string" and type(v) == "number" and (k:find("Bank") or k:find("Reagent")) and not k:find("Account") and not seen[v] then
        list[#list + 1] = v; seen[v] = true
      end
    end
  end
  return list
end

function S.RecordBags()
  local db = DB()
  if not db then return end
  local c = db.inv[Me()] or {}
  c.bags = ReadBags({ 0, 1, 2, 3, 4 })
  c.t = time()
  db.inv[Me()] = c
end
function S.RecordBank()
  local db = DB()
  if not db then return end
  local c = db.inv[Me()] or {}
  c.bank = ReadBags(BankBags())
  c.bankT = time()
  db.inv[Me()] = c
end

-- Compte d'un objet : sacs (en direct), banque (relevée), autres personnages (sacs + banque relevés), et leur liste
function S.Count(id)
  local bags = G.ItemCount(id) or 0
  local db = DB()
  local me = db and db.inv[Me()]
  local bank = (me and me.bank and me.bank[id]) or math.max(0, (G.ItemCount(id, true) or bags) - bags)
  local alts, who = 0, {}
  for key, c in pairs(db and db.inv or {}) do
    if key ~= Me() then
      local n = ((c.bags and c.bags[id]) or 0) + ((c.bank and c.bank[id]) or 0)
      if n > 0 then alts = alts + n; who[#who + 1] = key:match("^(.-) %- ") or key end
    end
  end
  return bags, bank, alts, who
end

-- « dans ta banque ; chez Machin » (ou nil)
function S.Owned(id)
  local _, bank, _, who = S.Count(id)
  local out = {}
  if bank > 0 then out[#out + 1] = L.ownBank end
  for _, name in ipairs(who) do out[#out + 1] = string.format(L.ownOther, name) end
  return #out > 0 and table.concat(out, " ; ") or nil
end

----------------------------------------------------------------------
-- Marchands visités : position (la tienne quand tu lui parles) et articles, pour « Guide-moi » (la base intégrée ne
-- connaît surtout que les marchands des capitales)
----------------------------------------------------------------------
function S.RecordMerchant()
  local db = DB()
  if not db then return end
  local guid = UnitGUID and UnitGUID("npc")
  guid = root.Clear(guid)
  local npcID = guid and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
  if not npcID then return end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  local x, y
  if pos then x, y = pos:GetXY() end
  if not (map and x and not (issecretvalue and issecretvalue(x))) then return end
  local items = {}
  local idf = (C_MerchantFrame and C_MerchantFrame.GetItemID) or GetMerchantItemID
  for i = 1, G.MerchantCount() do
    local id = idf and idf(i)
    if id then items[id] = true end
  end
  db.vendors = db.vendors or {}
  db.vendors[npcID] = { name = root.Clear(UnitName("npc")) or "?", map = map, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10,
                        items = items, t = time(), r = UnitFactionGroup("player") == "Horde" and 1 or 2 }
end

-- Marchands retenus qui vendent un objet : { { name, mapID, x, y, kind = "vendor" } } (ta faction)
function S.Vendors(itemID)
  local out = {}
  local myR = UnitFactionGroup("player") == "Horde" and 1 or 2
  for _, v in pairs(DB() and DB().vendors or {}) do
    if v.items and v.items[itemID] and (not v.r or v.r == myR) then
      out[#out + 1] = { name = v.name or "?", mapID = v.map, x = v.x, y = v.y, kind = "vendor" }
    end
  end
  return out
end

----------------------------------------------------------------------
-- Prix de l'hôtel des ventes
----------------------------------------------------------------------
function S.Price(id)
  local db = DB()
  local p = db and db.prices[Realm()] and db.prices[Realm()][id]
  return p and p[1] or nil, p and p[2] or nil
end

local scan = { running = false }
S.scan = scan
local SCAN_EVERY = 15 * 60

local function FinishScan(prices, n)
  local db = DB()
  if db then
    db.prices[Realm()] = db.prices[Realm()] or {}
    local t = time()
    for id, p in pairs(prices) do db.prices[Realm()][id] = { p, t } end
    db.lastScan = t
  end
  scan.running, scan.reading = false, false
  local count = 0
  for _ in pairs(prices) do count = count + 1 end
  root.Print(L.scanDone, count, n)
  if scan.button then scan.button:Enable() end
end

-- Lit le relevé complet par paquets (il peut compter des dizaines de milliers d'enchères)
local function ReadReplicate()
  local AH = C_AuctionHouse
  local n = AH.GetNumReplicateItems() or 0
  local prices, i = {}, 0
  local function step()
    local last = math.min(n - 1, i + 1500)
    for k = i, last do
      local r = { AH.GetReplicateItemInfo(k) }
      local count, buyout, itemID = r[3], r[10], r[17]
      if itemID and buyout and buyout > 0 and count and count > 0 then
        local unit = math.floor(buyout / count)
        if not prices[itemID] or unit < prices[itemID] then prices[itemID] = unit end
      end
    end
    i = last + 1
    if i < n then C_Timer.After(0, step) else FinishScan(prices, n) end
  end
  step()
end

function S.StartScan()
  local AH = C_AuctionHouse
  if not (AH and AH.ReplicateItems and AH.GetNumReplicateItems and AH.GetReplicateItemInfo) then root.Print(L.scanNoApi); return end
  local db = DB()
  local wait = db and db.lastScan and (db.lastScan + SCAN_EVERY - time())
  if wait and wait > 0 then root.Print(L.scanWait, math.ceil(wait / 60)); return end
  if scan.running then return end
  scan.running = true
  if scan.button then scan.button:Disable() end
  root.Print(L.scanStart)
  AH.ReplicateItems()
end

local function ScanButton()
  local AHF = _G.AuctionHouseFrame or _G.AuctionFrame
  if not AHF or scan.button then return end
  local b = CreateFrame("Button", "ForeverCompagnonScanButton", AHF, "UIPanelButtonTemplate")
  b:SetSize(170, 22)
  b:SetPoint("TOPRIGHT", AHF, "TOPRIGHT", -30, -1)
  b:SetText(L.scanButton)
  b:SetScript("OnClick", S.StartScan)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L.scanButton)
    GameTooltip:AddLine(L.scanTip, 0.8, 0.8, 0.8, true)
    local db = DB()
    if db and db.lastScan then GameTooltip:AddLine(string.format(L.scanLast, date("%d/%m %H:%M", db.lastScan)), 0.6, 0.8, 1) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  scan.button = b
end

----------------------------------------------------------------------
-- Événements
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
local bankOpen = false
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "MERCHANT_SHOW",
                     "AUCTION_HOUSE_SHOW", "REPLICATE_ITEM_LIST_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local pending = false
ev:SetScript("OnEvent", function(_, event)
  if event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" then
    if pending then return end
    pending = true
    C_Timer.After(2, function()
      pending = false
      S.RecordBags()
      if bankOpen then S.RecordBank() end
    end)
  elseif event == "BANKFRAME_OPENED" then bankOpen = true; S.RecordBank()
  elseif event == "BANKFRAME_CLOSED" then bankOpen = false
  elseif event == "MERCHANT_SHOW" then C_Timer.After(0.5, S.RecordMerchant)
  elseif event == "AUCTION_HOUSE_SHOW" then ScanButton()
  elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
    if scan.running and not scan.reading then
      scan.reading = true                    -- remis à false à la fin de la lecture (FinishScan)
      ReadReplicate()
    end
  end
end)
root.OnLogin(function() C_Timer.After(3, S.RecordBags) end)
