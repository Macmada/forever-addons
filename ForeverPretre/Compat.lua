local _, root = ...

-- Lien avec le jeu : une seule façon d'appeler chaque fonction de WoW, quel que soit le client.
-- Le client de WoW Forever est moderne : beaucoup de fonctions classiques n'existent plus (EquipItemByName,
-- GetMerchantItemInfo, GetTradeSkillLine…), d'autres sont interdites (journal de combat) ou rendent des valeurs secrètes
-- en combat (mana). Chaque fonction ici essaie la version moderne, puis la classique, puis un repli, et note la méthode
-- utilisée (root.Game.used) pour la sonde et l'auto-test.

local G = { used = {} }
root.Game = G

-- Chemin « C_Item.EquipItemByName » ou « EquipItemByName » -> la fonction, ou nil
function G.Get(path)
  local t = _G
  for part in tostring(path):gmatch("[^%.]+") do
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[part] end)
    if not ok then return nil end
    t = v
  end
  return t
end
function G.Has(path) return type(G.Get(path)) == "function" end

-- Première fonction présente parmi les chemins ; note laquelle pour le rapport
local function Pick(key, ...)
  for i = 1, select("#", ...) do
    local p = select(i, ...)
    local f = G.Get(p)
    if type(f) == "function" then G.used[key] = p; return f end
  end
  G.used[key] = nil
end

-- Nombre utilisable, ou nil si le jeu donne une valeur secrète (en combat sur Forever)
function G.Plain(v)
  if v == nil then return nil end
  if issecretvalue then
    local ok, s = pcall(issecretvalue, v)
    if ok and s then return nil end
  end
  local ok, n = pcall(function() return v + 0 end)
  if ok then return n end
end

function G.ItemInfo(x) local f = Pick("itemInfo", "C_Item.GetItemInfo", "GetItemInfo"); if f then return f(x) end end
function G.ItemInstant(x) local f = Pick("itemInstant", "C_Item.GetItemInfoInstant", "GetItemInfoInstant"); if f then return f(x) end end
function G.ItemID(link)
  if type(link) == "number" then return link end
  local id = G.ItemInstant(link)
  return id or tonumber(tostring(link):match("item:(%d+)"))
end

function G.SpellName(id)
  local f = Pick("spellName", "C_Spell.GetSpellName", "GetSpellInfo")
  if f then return (f(id)) end
end

-- Sacs : nombre de cases, objet d'une case
function G.BagSlots(bag) local f = Pick("bagSlots", "C_Container.GetContainerNumSlots", "GetContainerNumSlots"); return f and f(bag) or 0 end
function G.BagItemID(bag, slot) local f = Pick("bagItemID", "C_Container.GetContainerItemID", "GetContainerItemID"); return f and f(bag, slot) end
function G.BagItemLink(bag, slot) local f = Pick("bagItemLink", "C_Container.GetContainerItemLink", "GetContainerItemLink"); return f and f(bag, slot) end

-- Parcourt les sacs (0 à 4) : fn(bag, slot, id) ; s'arrête si fn renvoie vrai
function G.EachBagItem(fn)
  for bag = 0, 4 do
    for slot = 1, (G.BagSlots(bag) or 0) do
      local id = G.BagItemID(bag, slot)
      if id and fn(bag, slot, id) then return bag, slot, id end
    end
  end
end
function G.FindInBags(id)
  local bag, slot = G.EachBagItem(function(_, _, i) return i == id end)
  return bag, slot
end

-- Équiper un objet (bouton « Équiper » de l'alerte de ForeverLoot). Renvoie true, ou false et la raison
-- (« combat », « introuvable »). Sur le client de Forever, EquipItemByName n'existe plus qu'en C_Item.
function G.Equip(link)
  if not link then return false, "introuvable" end
  if InCombatLockdown and InCombatLockdown() then return false, "combat" end
  local byName = Pick("equip", "C_Item.EquipItemByName", "EquipItemByName")
  if byName and pcall(byName, link) then return true end
  local bag, slot = G.FindInBags(G.ItemID(link))
  local pick = Pick("pickup", "C_Container.PickupContainerItem", "PickupContainerItem")
  if bag and pick and AutoEquipCursorItem then
    G.used.equip = "PickupContainerItem + AutoEquipCursorItem"
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
    pick(bag, slot)
    AutoEquipCursorItem()
    return true
  end
  return false, "introuvable"
end

-- Article d'un marchand, avec les valeurs de l'ancienne GetMerchantItemInfo :
-- nom, icône, prix, lot, disponibles, achetable, utilisable, coût spécial
function G.MerchantItem(i)
  local old = Pick("merchant", "GetMerchantItemInfo")
  if old then return old(i) end
  local f = Pick("merchant", "C_MerchantFrame.GetItemInfo")
  if f then
    local ok, t = pcall(f, i)
    if ok and type(t) == "table" then
      return t.name, t.texture, t.price, t.stackCount, t.numAvailable, t.isPurchasable, t.isUsable, t.hasExtendedCost
    end
  end
end
function G.MerchantCount() local f = Pick("merchantCount", "C_MerchantFrame.GetNumItems", "GetMerchantNumItems"); return f and f() or 0 end

-- Recharge d'un objet (pierre de foyer, potions)
function G.ItemCooldown(id)
  local f = Pick("itemCooldown", "C_Container.GetItemCooldown", "C_Item.GetItemCooldown", "GetItemCooldown")
  if f then return f(id) end
end

-- Mana actuelle / max : nombres, ou nil si secrets (en combat sur Forever)
function G.Mana()
  return G.Plain(UnitPower and UnitPower("player", 0)), G.Plain(UnitPowerMax and UnitPowerMax("player", 0))
end
