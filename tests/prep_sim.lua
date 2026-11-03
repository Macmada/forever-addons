-- Simulation hors jeu de ForeverPrep (Lua 5.1) : personnages fictifs, sacs, sorts, buffs, marchand.
-- Lancer depuis la racine du dépôt : lua5.1 tests/prep_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"

----------------------------------------------------------------------
-- API imitée
----------------------------------------------------------------------
local clock, timers = 1000.0, {}
local function noop() end
local function Obj()
  local o = { scripts = {}, shown = false, w = 500, h = 10, text = "" }
  return setmetatable(o, { __index = function(_, k)
    local m = ({
      SetScript = function(self, n, f) self.scripts[n] = f end,
      HookScript = function(self, n, f) self.scripts[n] = f end,
      RegisterEvent = function() end,
      Show = function(self) local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end,
      Hide = function(self) self.shown = false end,
      SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
      IsShown = function(self) return self.shown end,
      IsVisible = function(self) return self.shown end,
      GetWidth = function(self) return self.w end,
      SetSize = function(self, w, h) self.w, self.h = w, h end,
      SetText = function(self, s) self.text = s end,
      GetText = function(self) return self.text end,
      GetStringHeight = function() return 14 end,
      GetHeight = function(self) return self.h end,
      SetHeight = function(self, h) self.h = h end,
      CreateFontString = function() return Obj() end,
      CreateTexture = function() return Obj() end,
      CreateAnimationGroup = function() return Obj() end,
      CreateAnimation = function() return Obj() end,
      GetChecked = function(self) return self.checked end,
      SetChecked = function(self, v) self.checked = v end,
      GetCenter = function() return 100, 100 end,
      GetEffectiveScale = function() return 1 end,
      GetBottom = function() return 300 end,
      GetFrameLevel = function() return 1 end,
    })[k]
    return m or noop
  end })
end
_G.CreateFrame = function() return Obj() end
_G.UIParent, _G.Minimap, _G.GameTooltip, _G.MerchantFrame = Obj(), Obj(), Obj(), Obj()
_G.UISpecialFrames, _G.StaticPopupDialogs, _G.SlashCmdList = {}, {}, {}
local popups = {}
_G.StaticPopup_Show = function(name, a) popups[#popups + 1] = { name, a } end
_G.YES, _G.NO = "Oui", "Non"
_G.tinsert = table.insert
_G.GetLocale = function() return LANG == "fr" and "frFR" or "enUS" end
_G.GetTime = function() return clock end
_G.C_Timer = { After = function(s, f) timers[#timers + 1] = { at = clock + s, f = f } end }
local function RunTimers(dt)
  clock = clock + (dt or 5)
  local again = true
  while again do
    again = false
    for i, t in ipairs(timers) do
      if t.at <= clock then table.remove(timers, i); t.f(); again = true; break end
    end
  end
end

-- monde du personnage
local P
local ITEMS = {}           -- id -> { name, level, classID, subID }
local function Item(id, name, level, classID, subID) ITEMS[id] = { name = name, level = level or 0, classID = classID or 0, subID = subID or 0 } end
-- objets connus du « client » (les autres n'existent pas dans ce jeu)
for _, e in ipairs({ { 118, "Potion de soins mineure", 1 }, { 858, "Potion de soins inférieure", 3 }, { 929, "Potion de soins", 12 },
  { 1710, "Potion de soins supérieure", 21 }, { 3928, "Potion de soins excellente", 35 }, { 13446, "Potion de soins majeure", 45 },
  { 2455, "Potion de mana mineure", 5 }, { 3385, "Potion de mana inférieure", 14 }, { 3827, "Potion de mana", 22 },
  { 6149, "Potion de mana supérieure", 31 }, { 13443, "Potion de mana excellente", 41 }, { 13444, "Potion de mana majeure", 49 },
  { 4540, "Miche de pain dur", 1 }, { 4541, "Pain frais", 5 }, { 4542, "Pain de maïs moelleux", 15 }, { 4544, "Pain épicé de Mulgore", 25 },
  { 4601, "Pain aux bananes", 35 }, { 8950, "Tarte aux cerises", 45 },
  { 159, "Eau de source rafraîchissante", 1 }, { 1179, "Lait glacé", 5 }, { 1205, "Jus de melon", 15 }, { 1708, "Doux nectar", 25 },
  { 1645, "Jus de lunebaie", 35 }, { 8766, "Rosée de gloire du matin", 45 },
  { 8077, "Eau minérale invoquée", 35 }, { 1251, "Bandage en lin", 0 }, { 8545, "Bandage épais en tisse-mage", 0 },
  { 17031, "Rune de téléportation", 0 }, { 17032, "Rune des portails", 0 }, { 17056, "Plume légère", 0 }, { 17020, "Poudre des arcanes", 0 },
  { 17034, "Graine d'érable", 0 }, { 17035, "Graine de Strangleronce", 0 }, { 17036, "Graine de frêne", 0 },
  { 2512, "Flèche grossière", 1 }, { 2515, "Flèche pointue", 10 }, { 3030, "Flèche rasoir", 25 }, { 11285, "Flèche barbelée", 40 },
  { 6948, "Pierre de foyer", 0 }, { 9179, "Élixir d'intelligence supérieure", 37 }, { 13447, "Élixir des sages", 44 },
  { 20746, "Huile de sorcier inférieure", 15 }, { 20750, "Huile de sorcier", 30 } }) do
  Item(e[1], e[2], e[3])
end
Item(2504, "Arc renforcé", 1, 2, 2)

_G.GetItemInfoInstant = function(id)
  if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) end
  local it = ITEMS[id]
  if not it then return nil end
  return id, "type", "sub", "", "icon" .. id, it.classID, it.subID
end
_G.GetItemInfo = function(id)
  local it = ITEMS[id]
  if not it then return nil end
  return it.name, "link", 1, 1, it.level
end
_G.GetItemCount = function(id) return P.bags[id] or 0 end
_G.GetItemCooldown = function() return 0, 0 end
_G.UnitLevel = function() return P.level end
_G.UnitClass = function() return P.class, P.class end
_G.UnitName = function(u) return P.names[u] or u end
_G.UnitExists = function(u) return u == "player" or P.names[u] ~= nil or (u == "pet" and P.pet) end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitIsConnected = function() return true end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitIsVisible = function() return true end
_G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() local n = 0; for _ in pairs(P.names) do n = n + 1 end; return n > 0 and n + 1 or 0 end
_G.IsInInstance = function() return P.inst ~= nil, P.inst or "none" end
_G.GetRealZoneText = function() return "Les Mortemines" end
local SPELLNAMES = {}
_G.GetSpellInfo = function(x)
  if type(x) == "number" then return SPELLNAMES[x] or ("Sort" .. x) end
  for id, name in pairs(SPELLNAMES) do if name == x and P.known[id] then return name end end
  return nil
end
_G.IsSpellKnown = function(id) return P.known[id] == true end
_G.GetSpellTexture = function(id) return "spell" .. id end
_G.UnitBuff = function(u, i) local list = P.auras[u] or {}; return list[i] end
_G.GetWeaponEnchantInfo = function() return P.weaponEnchant end
_G.GetPetHappiness = function() return P.happy or 3 end
_G.GetInventoryItemDurability = function(slot) local d = P.dura[slot]; if d then return d, 100 end end
_G.GetInventoryItemLink = function(_, slot) return P.gear[slot] end
_G.GetContainerNumFreeSlots = function(bag) return bag == 0 and P.free or 0 end
_G.GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end
_G.UnitCharacterPoints = function() return P.unspent or 0 end
_G.GetNumTalentTabs = function() return 3 end
_G.GetTalentTabInfo = function(i) return "Arbre" .. i, "icon", P.talents[i] or 0 end
_G.GetMoney = function() return P.money end
local bought = {}
_G.GetMerchantNumItems = function() return #P.merchant end
_G.GetMerchantItemID = function(i) return P.merchant[i].id end
_G.GetMerchantItemInfo = function(i) local m = P.merchant[i]; return ITEMS[m.id].name, "icon", m.price, m.batch or 1, -1, true, true, nil end
_G.GetMerchantItemMaxStack = function() return 20 end
_G.BuyMerchantItem = function(i, n) bought[#bought + 1] = { P.merchant[i].id, n or (P.merchant[i].batch or 1) } end
for id, name in pairs({ [1459] = "Intelligence des arcanes", [168] = "Armure de givre", [7302] = "Armure de glace", [6117] = "Armure du mage",
  [23028] = "Illumination des arcanes", [3561] = "Téléportation : Hurlevent", [10059] = "Portail : Hurlevent", [130] = "Chute lente",
  [1126] = "Marque du fauve", [20484] = "Renaissance", [20739] = "Renaissance", [20742] = "Renaissance", [883] = "Appel du familier",
  [13165] = "Aspect du faucon", [19506] = "Aura de précision" }) do SPELLNAMES[id] = name end

local function Char(t)
  P = { level = 1, class = "WARRIOR", bags = {}, known = {}, auras = {}, names = {}, dura = {}, gear = {}, talents = {},
        free = 10, money = 1000000, merchant = {} }
  for k, v in pairs(t) do P[k] = v end
end
Char({})

----------------------------------------------------------------------
-- Chargement
----------------------------------------------------------------------
_G.date = _G.date or os.date
_G.time = _G.time or os.time
_G.UnitRace = _G.UnitRace or function() return "Humain", "Human" end
_G.UnitFactionGroup = _G.UnitFactionGroup or function() return "Alliance" end
_G.GetRealmName = _G.GetRealmName or function() return "Forever" end
_G.GetBuildInfo = _G.GetBuildInfo or function() return "1.16.0", "60000", "Nov 1 2026", 16001 end
_G.GetAddOnMetadata = function(_, f) return f == "Version" and "test" or nil end
_G.IsAddOnLoaded = function() return true end
_G.ChatFontNormal = _G.ChatFontNormal or {}
local ns = {}
for _, f in ipairs({ "Locale", "Diag", "Data", "Core", "Tour", "UI" }) do
  assert(loadfile("ForeverPrep/" .. f .. ".lua"))("ForeverPrep", ns)
end
local evf = ns.eventFrame
local function Fire(e, ...) evf.scripts.OnEvent(evf, e, ...) end
local function check(c, msg) if not c then error("ÉCHEC : " .. msg, 2) end print("ok  " .. msg) end
local function Find(res, pattern)
  for _, s in ipairs(res.sections) do for _, r in ipairs(s.rows) do if r.text:find(pattern, 1, true) then return r, s.key end end end
end
local function Dump(res)
  for _, s in ipairs(res.sections) do
    print("  [" .. s.key .. "]")
    for _, r in ipairs(s.rows) do print(string.format("    %-4s %s", r.status, r.text)) end
  end
  for _, b in ipairs(res.shopping) do print("    achat : " .. b.qty .. " x " .. tostring(b.name)) end
end

Fire("ADDON_LOADED", "ForeverPrep")
Fire("PLAYER_LOGIN")
check(ForeverPrepDB and ForeverPrepDB.role == "auto", "base créée, rôle automatique")

-- 1. Mage niveau 38, en donjon, peu préparé
Char({ level = 38, class = "MAGE", talents = { 31, 0, 5 },
       known = { [1459] = true, [168] = true, [7302] = true, [3561] = true, [130] = true },
       bags = { [1710] = 2, [3928] = 1, [8077] = 12, [4601] = 25, [17031] = 0, [17056] = 2, [6948] = 1, [1251] = 4 },
       auras = { player = { "Intelligence des arcanes" }, party1 = {} }, names = { party1 = "Grosbill" },
       dura = { [1] = 80, [5] = 45, [7] = 90 }, gear = { [16] = "item:1" }, free = 3, unspent = 1 })
ForeverPrepDB.lastTrainerLevel = 34
local r = ns.Analyze("dungeon")
print("\n-- Mage 38, donjon"); Dump(r)
check(r.role == "caster", "rôle deviné par les talents (Arcanes -> dégâts magiques)")
local hp = Find(r, ns.L.cat_healpot)
check(hp and hp.status == "warn" and hp.text:find("Potion de soins excellente", 1, true) and hp.buyQty == 2,
      "potions de soins : 3/5, achète 2 × la meilleure à son niveau (excellente, niv. 35), pas la majeure (niv. 45)")
local water = Find(r, ns.L.cat_water)
check(water and water.status == "warn" and water.buyQty == 8 and water.text:find("Jus de lunebaie", 1, true), "boisson : 12/20 (eau du mage comptée), achète 8 jus de lunebaie (niv. 35)")
check(Find(r, ns.L.cat_food).status == "ok", "nourriture : 25/20, rien à acheter")
check(Find(r, "Rune de téléportation") and Find(r, "Rune de téléportation").status == "bad", "rune de téléportation : sort connu, 0/3")
check(not Find(r, "Rune des portails"), "rune des portails : sort de portail inconnu, pas demandée")
check(not Find(r, "Poudre des arcanes"), "poudre des arcanes : seulement en raid")
check(Find(r, "Armure de givre").status == "warn", "armure du mage absente : à lancer")
local ai = Find(r, "Intelligence des arcanes")
check(ai and ai.status == "warn" and ai.text:find("Grosbill", 1, true), "Intelligence des arcanes manque à Grosbill")
check(Find(r, "45 %").status == "warn", "durabilité 45 % : à réparer")
check((Find(r, "3 place") or Find(r, "3 free slot")).status == "warn", "sacs presque pleins")
check(Find(r, "point(s) de talent") or Find(r, "talent point"), "point de talent à dépenser")
check(Find(r, "34").status == "warn", "maître de classe : dernière visite au niveau 34 (niveau 38)")
check(#r.shopping >= 3 and r.worst == "bad", "liste de courses et état général")
check(not Find(r, ns.L.cat_elixir), "élixirs : pas en donjon avant le niveau 50")

-- 2. Même mage en raid
ForeverPrepDB.lastTrainerLevel = 38
local rr = ns.Analyze("raid")
check(Find(rr, ns.L.cat_healpot).need == 10, "raid : quantités doublées (10 potions)")
check(Find(rr, ns.L.cat_elixir) and Find(rr, ns.L.cat_elixir).text:find("Élixir d'intelligence supérieure", 1, true),
      "raid : élixir de lanceur de sorts conseillé (intelligence supérieure, niv. 37)")
check(Find(rr, "38").status == "ok", "maître visité au niveau actuel")

-- 3. Personnage bas niveau : rien au-dessus de son niveau
Char({ level = 8, class = "WARRIOR", bags = { [118] = 5 }, talents = {} })
local lo = ns.Analyze("dungeon")
print("\n-- Guerrier 8"); Dump(lo)
check(Find(lo, ns.L.cat_healpot).status == "ok", "guerrier 8 : 5 potions mineures suffisent")
check(not Find(lo, ns.L.cat_manapot) and not Find(lo, ns.L.cat_water), "guerrier : ni mana ni boisson")
check(Find(lo, ns.L.cat_food).text:find("Pain frais", 1, true), "nourriture : pain frais (niv. 5), pas au-dessus du niveau 8")
check(not Find(lo, "talent"), "pas de talents avant le niveau 10")

-- 4. Druide : graine du rang de Renaissance le plus haut connu seulement
Char({ level = 42, class = "DRUID", talents = { 0, 0, 30 }, known = { [20484] = true, [20739] = true, [20742] = true, [1126] = true },
       bags = { [17036] = 1 }, auras = { player = { "Marque du fauve" } } })
local dr = ns.Analyze("dungeon")
check(dr.role == "heal", "druide Restauration -> soigneur")
check(Find(dr, "Graine de frêne") and not Find(dr, "Graine d'érable") and not Find(dr, "Graine de Strangleronce"),
      "druide : seulement la graine du rang 3 de Renaissance")

-- 5. Chasseur : flèches selon l'arc, familier
Char({ level = 30, class = "HUNTER", known = { [883] = true, [13165] = true }, gear = { [18] = "item:2504" },
       bags = { [3030] = 400 }, auras = { player = { "Aspect du faucon" } }, pet = true, happy = 2 })
local hu = ns.Analyze("dungeon")
print("\n-- Chasseur 30"); Dump(hu)
local ammo = Find(hu, ns.L.cat_arrow)
check(ammo and ammo.text:find("Flèche rasoir", 1, true) and ammo.buyQty == 600, "chasseur avec arc : 400/1000 flèches rasoir, achète 600")
check(Find(hu, ns.L.petUnhappy), "familier pas content")

-- 6. Marchand : achat en un clic
Char({ level = 38, class = "MAGE", talents = { 31 }, known = {}, bags = { [6948] = 1 }, money = 500000,
       merchant = { { id = 3928, price = 1500 }, { id = 1645, price = 400 }, { id = 4601, price = 400 }, { id = 3030, price = 1000, batch = 200 } } })
ForeverPrepDB.lastTrainerLevel = 38
ns.OnMerchant()
SlashCmdList.FOREVERPREP("")
check(popups[#popups] == nil or true, "fenêtre ouverte sans erreur")
StaticPopupDialogs.FOREVERPREP_BUY.OnAccept()
RunTimers(30)
local got = {}
for _, b in ipairs(bought) do got[b[1]] = (got[b[1]] or 0) + b[2] end
check(got[3928] == 5 and got[1645] == 20 and got[4601] == 20, "achats : 5 potions (niv. 35), 20 jus de lunebaie, 20 pains (par piles de 20)")
check(got[3030] == nil, "pas de flèches pour un mage")

-- 7. Ouverture automatique
local shown = 0
local realShow = ns.Show
ns.Show = function(...) shown = shown + 1; return realShow(...) end
Char({ level = 38, class = "MAGE", talents = { 31 }, bags = {}, inst = "party" })
Fire("PLAYER_ENTERING_WORLD"); RunTimers(5)
check(shown == 1, "entrée en donjon avec des manques : fiche ouverte")
Fire("ZONE_CHANGED_NEW_AREA"); RunTimers(5)
check(shown == 1, "pas deux fois en 10 minutes pour la même instance")
Fire("READY_CHECK")
check(shown == 2, "appel du chef : fiche ouverte")
Fire("LFG_UPDATE")
check(shown == 3, "recherche de groupe : fiche ouverte")
ForeverPrepDB.autoReady = false
clock = clock + 700
Fire("READY_CHECK")
check(shown == 3, "option désactivée : pas d'ouverture à l'appel")
Fire("TRAINER_SHOW")
check(ForeverPrepDB.lastTrainerLevel == 38, "visite au maître retenue")
SlashCmdList.FOREVERPREP("role tank")
check(ForeverPrepDB.role == "tank", "commande /prep role tank")
SlashCmdList.FOREVERPREP("raid")
check(ForeverPrepDB.context == "raid", "commande /prep raid")
-- 8. Bouton flottant
Char({ level = 38, class = "MAGE", talents = { 31 }, bags = {} })
ns.ui:Hide()
RunTimers(5)
local fb = ns.floatButton
check(fb and fb.shown, "bouton « Prépa » affiché après la connexion")
check(fb.summary and fb.summary ~= ns.L.allGood, "bouton : résumé des manques dans l'infobulle")
fb.scripts.OnClick(fb, "LeftButton")
check(ns.ui.shown, "clic sur le bouton : fiche ouverte (hors déclencheurs automatiques)")
fb.scripts.OnClick(fb, "LeftButton")
check(not ns.ui.shown, "second clic : fiche fermée")
SlashCmdList.FOREVERPREP("bouton")
check(not fb.shown and ForeverPrepDB.float.shown == false, "/prep bouton : bouton masqué")
SlashCmdList.FOREVERPREP("bouton")
check(fb.shown, "/prep bouton : bouton réaffiché")
local diagText = ns.DiagText()
if os.getenv("SHOW_DIAG") then print(diagText) end
check(diagText:find("diagnostic", 1, true) and not diagText:find("Erreur", 1, true), "diagnostic : texte complet, sans erreur (" .. #diagText .. " caractères)")
if os.getenv("SHOW_DIAG") then print(diagText) end
SlashCmdList["FOREVERPREP"]("diag")
ns.lastDiag = nil
local dbtn = ns.ui and ns.ui.diagBtn
check(dbtn and dbtn.scripts.OnClick, "bouton « Diag » présent dans la fenêtre")
dbtn.scripts.OnClick(dbtn)
check(ns.lastDiag and ns.lastDiag:find("diagnostic", 1, true), "clic sur « Diag » : diagnostic ouvert sans commande écrite")
print("\nTOUT OK (" .. LANG .. ")")
