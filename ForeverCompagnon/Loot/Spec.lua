local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverLoot") end

-- Équipement par spé (3.8.0 prêtre soigneur, 3.9.0 paladin toutes spés), refait de zéro à la demande du joueur :
--   * une mesure par spé : la valeur d'un objet en points, somme de ses caractéristiques pondérées (poids du simulateur
--     wowsims/forever quand il les publie, sinon estimés, dit dans l'interface) ; l'infobulle détaille ;
--   * tous les objets de Forever que la classe peut porter (Items.lua, tiré de wowsims), pas seulement ceux déjà vus ;
--   * « Maintenant » : la meilleure amélioration de chaque emplacement jusqu'à ton niveau + l'écart choisi, et où l'avoir ;
--   * « Objectif 60 » : la liste de référence de la spé (kami-labs, simulée avec wowsims), ta progression ; un calcul ne
--     la contredit pas (22/11/2026 : aucun jeu de poids ne retrouve plus de 8 des 16 choix du prêtre : bonus de set,
--     mana sur tout un combat, effets) ; le meilleur calculé ne remplace qu'une pièce hors de ta portée (autre camp).
-- Les autres classes gardent l'évaluation par poids de Core.lua.

local S = {}
ns.Spec = S
ns.Priest = S                 -- ancien nom (3.8.0)
local L = ns.L
local D = ns.Data

S.PHASE = 1                   -- phase de Forever en cours (raids annoncés « le mois prochain » au lancement du 04/11/2026)

-- Caractéristiques (n° de wowsims, proto/common.proto) ; 100 = DPS de l'arme
local STR, AGI, STA, INT, HEAL, SPD, HOLY, SPI, AP, HIT, CRIT, HASTE = 0, 1, 2, 3, 4, 5, 9, 13, 14, 17, 18, 19
local ARP, EXP, DEF, BLOCK, BVAL, DODGE, PARRY, ARMOR, BARMOR, MP5, DPS = 20, 21, 22, 23, 24, 25, 26, 27, 28, 31, 100
S.STAT_NAME = { [STR] = "statStr", [AGI] = "statAgi", [STA] = "statSta", [INT] = "statInt", [HEAL] = "statHeal",
                [SPD] = "statSpd", [HOLY] = "statHoly", [SPI] = "statSpi", [AP] = "statAp", [HIT] = "statHit",
                [CRIT] = "statCrit", [HASTE] = "statHaste", [ARP] = "statArp", [EXP] = "statExp", [DEF] = "statDef",
                [BLOCK] = "statBlock", [BVAL] = "statBval", [DODGE] = "statDodge", [PARRY] = "statParry",
                [ARMOR] = "statArmor", [BARMOR] = "statArmor", [MP5] = "statMp5", [DPS] = "statDps" }
S.STAT_ORDER = { HEAL, SPD, HOLY, STR, AGI, STA, INT, SPI, MP5, AP, HIT, CRIT, HASTE, EXP, ARP, DEF, DODGE, PARRY, BLOCK,
                 BVAL, ARMOR, BARMOR, DPS }

-- Profils : classe, rôle (celui de ForeverCompagnon), liste de référence, poids, origine des poids
-- Prêtre : wowsims/forever, ui/specs/priest/healer/presets.ts. Paladin Vindicte : ui/specs/paladin/retribution/presets.ts
-- (en points de puissance d'attaque). Paladin Sacré et Protection : wowsims ne publie pas de poids : estimés (soins :
-- comme le prêtre, critique plus forte (Illumination) ; tank : endurance, défense, esquive, parade, blocage, armure).
S.PROFILES = {
  holy_raid = { class = "PRIEST", role = "heal", ref = "PRIEST", src = "wowsims",
                w = { [HEAL] = 1.0, [INT] = 0.30, [SPI] = 0.25, [MP5] = 0.60, [CRIT] = 0.23, [HASTE] = 0.48, [STA] = 0.01 } },
  holy_st = { class = "PRIEST", role = "heal", ref = "PRIEST", src = "wowsims",
              w = { [HEAL] = 1.0, [INT] = 0.35, [SPI] = 0.30, [MP5] = 0.60, [CRIT] = 0.30, [HASTE] = 0.50, [STA] = 0.01 } },
  disc_raid = { class = "PRIEST", role = "heal", ref = "PRIEST", src = "wowsims",
                w = { [HEAL] = 1.0, [INT] = 0.20, [SPI] = 0.10, [MP5] = 0.19, [CRIT] = 0.48, [HASTE] = 0.10, [STA] = 0.01 } },
  disc_st = { class = "PRIEST", role = "heal", ref = "PRIEST", src = "wowsims",
              w = { [HEAL] = 1.0, [INT] = 0.20, [SPI] = 0.15, [MP5] = 0.40, [CRIT] = 0.70, [HASTE] = 0.15, [STA] = 0.01 } },
  pal_holy = { class = "PALADIN", role = "heal", ref = "PALADIN_holy", src = "estimate",
               w = { [HEAL] = 1.0, [INT] = 0.45, [MP5] = 0.70, [CRIT] = 0.55, [HASTE] = 0.35, [SPI] = 0.05, [STA] = 0.01 } },
  pal_prot = { class = "PALADIN", role = "tank", ref = "PALADIN_prot", src = "estimate",
               w = { [STA] = 1.0, [DEF] = 1.3, [DODGE] = 1.1, [PARRY] = 0.9, [BLOCK] = 0.6, [BVAL] = 0.2, [ARMOR] = 0.05,
                     [BARMOR] = 0.05, [AGI] = 0.5, [STR] = 0.3, [HIT] = 0.4, [SPD] = 0.2, [HOLY] = 0.2, [INT] = 0.1,
                     [EXP] = 0.3, [DPS] = 1.0 } },
  pal_ret = { class = "PALADIN", role = "melee", ref = "PALADIN_ret", src = "wowsims", twoHand = true,
              w = { [STR] = 2.4, [AGI] = 2.23, [INT] = 2.06, [SPD] = 2.36, [HOLY] = 1.95, [AP] = 1, [HIT] = 6.83, [CRIT] = 3.08,
                    [HASTE] = 22.87, [ARP] = 0.24, [EXP] = 5.1, [MP5] = 0.23, [DPS] = 13.85, [STA] = 0.05 } },
  pal_shock = { class = "PALADIN", role = "melee", ref = "PALADIN_shock", src = "wowsims", twoHand = true,
                w = { [STR] = 2.5, [AGI] = 3.11, [INT] = 4.53, [SPD] = 5.78, [HOLY] = 4.98, [AP] = 1, [HIT] = 10.25, [CRIT] = 4.66,
                      [HASTE] = 4.06, [ARP] = 0.26, [EXP] = 6.2, [MP5] = 0.01, [DPS] = 13.04, [STA] = 0.05 } },
}
S.ORDER = { PRIEST = { "holy_raid", "holy_st", "disc_raid", "disc_st" }, PALADIN = { "pal_holy", "pal_prot", "pal_ret", "pal_shock" } }
local MASK = { PRIEST = 1, PALADIN = 2 }

-- Ce que chaque classe peut porter : armures, armes (n° de wowsims), main gauche, distance
local WEAR = {
  PRIEST = { armor = { [0] = true, [1] = true }, weapons = { [2] = true, [4] = true, [8] = true }, off = { [5] = true }, ranged = 105 },
  PALADIN = { armor = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = 40 },      -- plaques à partir du niveau 40
              weapons = { [1] = true, [4] = true, [6] = true, [9] = true }, off = { [5] = true, [7] = true }, ranged = 107 },
}

-- Caractéristiques lues dans le jeu (objet absent d'Items.lua : vert aléatoire, nouveauté…)
local CLIENT = {
  ITEM_MOD_STRENGTH_SHORT = STR, ITEM_MOD_AGILITY_SHORT = AGI, ITEM_MOD_STAMINA_SHORT = STA, ITEM_MOD_INTELLECT_SHORT = INT,
  ITEM_MOD_SPIRIT_SHORT = SPI, ITEM_MOD_SPELL_HEALING_DONE_SHORT = HEAL, ITEM_MOD_SPELL_POWER_SHORT = "sp",
  ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = SPD, ITEM_MOD_MANA_REGENERATION_SHORT = MP5, ITEM_MOD_POWER_REGEN0_SHORT = MP5,
  ITEM_MOD_ATTACK_POWER_SHORT = AP, ITEM_MOD_HIT_RATING_SHORT = HIT, ITEM_MOD_HIT_MELEE_RATING_SHORT = HIT,
  ITEM_MOD_CRIT_RATING_SHORT = CRIT, ITEM_MOD_SPELL_CRIT_RATING_SHORT = CRIT, ITEM_MOD_CRIT_SPELL_RATING_SHORT = CRIT,
  ITEM_MOD_CRIT_MELEE_RATING_SHORT = CRIT, ITEM_MOD_HASTE_RATING_SHORT = HASTE, ITEM_MOD_SPELL_HASTE_RATING_SHORT = HASTE,
  ITEM_MOD_EXPERTISE_RATING_SHORT = EXP, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = DEF, ITEM_MOD_DODGE_RATING_SHORT = DODGE,
  ITEM_MOD_PARRY_RATING_SHORT = PARRY, ITEM_MOD_BLOCK_RATING_SHORT = BLOCK, ITEM_MOD_BLOCK_VALUE_SHORT = BVAL,
  RESISTANCE0_NAME = ARMOR, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = DPS,
}

local Info = function(x) return ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(x) end
local Instant = function(x) return ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(x) end
local function ItemID(link) return link and tonumber(tostring(link):match("item:(%d+)")) end
local function Class() return select(2, UnitClass("player")) end

----------------------------------------------------------------------
-- Profil en cours (spé)
----------------------------------------------------------------------
-- Rôle donné par ForeverCompagnon (écran Maintenant) ; nil dans l'addon séparé ForeverBiS
local function RoleOf() return ns.Role and ns.Role() or nil end

function S.Profiles()
  local list, role = {}, RoleOf()
  for _, k in ipairs(S.ORDER[Class()] or {}) do
    if not role or S.PROFILES[k].role == role then list[#list + 1] = k end
  end
  return list
end

function S.Active()
  if not ns.Items or not S.ORDER[Class()] then return false end
  return #S.Profiles() > 0
end

function S.Profile()
  local list = S.Profiles()
  if #list == 0 then return nil end
  local saved = ns.db and (ns.db.specProfile or {})[Class()]
  if not saved and Class() == "PRIEST" then saved = ns.db and ns.db.priestProfile end        -- réglage de la 3.8.0
  for _, k in ipairs(list) do if k == saved then return k end end
  return list[1]
end

function S.SetProfile(k)
  if not (ns.db and S.PROFILES[k]) then return end
  ns.db.specProfile = ns.db.specProfile or {}
  ns.db.specProfile[Class()] = k
  if Class() == "PRIEST" then ns.db.priestProfile = k end
  ns.version = (ns.version or 0) + 1
  S.Forget()
  if ns.ForgetMemo then ns.ForgetMemo() end
end

-- Profil suivant (bouton « Calcul » / « Spé »)
function S.NextProfile()
  local list, cur = S.Profiles(), S.Profile()
  for i, k in ipairs(list) do
    if k == cur then S.SetProfile(list[i % #list + 1]); return end
  end
end

----------------------------------------------------------------------
-- Valeur d'un objet
----------------------------------------------------------------------
-- Caractéristiques { [n°] = valeur } : base intégrée d'abord, sinon le jeu
function S.Stats(x)
  local id = type(x) == "number" and x or ItemID(x)
  local it = id and ns.Items[id]
  if it then return it[7], true end
  if type(x) ~= "string" then return nil end
  local get = (C_Item and C_Item.GetItemStats) or GetItemStats
  local raw = get and get(x)
  if type(raw) ~= "table" then return nil end
  local v = {}
  for k, n in pairs(raw) do
    local i = CLIENT[k]
    if i == "sp" then                      -- « puissance des sorts » de classique : soins et dégâts
      v[HEAL] = math.max(v[HEAL] or 0, n); v[SPD] = math.max(v[SPD] or 0, n)
    elseif i == HEAL then v[HEAL] = math.max(v[HEAL] or 0, n)
    elseif i then v[i] = (v[i] or 0) + n end
  end
  return v, false
end

function S.EP(stats, profile)
  if not stats then return 0 end
  local p = S.PROFILES[profile or S.Profile() or ""]
  if not p then return 0 end
  local s = 0
  for k, v in pairs(stats) do s = s + (p.w[k] or 0) * v end
  return s
end

function S.ItemEP(x)
  local st = S.Stats(x)
  return S.EP(st), st
end

-- Emplacements du jeu pour un code de la base (116 : arme à deux mains, en main droite)
local function SlotsOf(code)
  if code == 11 then return { 11, 12 } elseif code == 13 then return { 13, 14 }
  elseif code == 116 then return { 16 }, true end
  return { code }
end
S.SlotsOf = SlotsOf

-- Niveau auquel un objet devient utilisable. wowsims met souvent 1 aux nouveaux objets de Forever (n° 270000 et plus)
-- au lieu du vrai niveau (22/11/2026) : 1 ou 0 avec un niveau d'objet au-dessus de 10 = niveau d'objet - 5.
function S.ReqLevel(id)
  local it = ns.Items[id]
  if not it then return nil end
  if it[2] > 1 or (it[2] == 1 and (it[3] or 0) <= 10) then return it[2] end
  return math.max(1, (it[3] or 1) - 5)
end

local function MyFaction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return (f == "Alliance" and 1) or (f == "Horde" and 2) or 0
end

-- Ta classe peut-elle le porter (maintenant ou plus tard : les plaques à partir du niveau 40) ?
function S.CanWear(id, level)
  local it = ns.Items[id]
  local cls = Class()
  if not (it and WEAR[cls]) then return false end
  local mask = MASK[cls]
  if math.floor(it[14] / mask) % 2 ~= 1 then return false end
  local w = WEAR[cls]
  local code, armor, wt = it[1], it[12] or 0, it[13] or 0
  if code == 18 then return wt == w.ranged end
  if code == 17 then return w.off[wt] == true end          -- objet tenu en main gauche ou bouclier (pas d'ambidextrie)
  if code == 16 or code == 116 then return w.weapons[wt] == true end
  local a = w.armor[armor]
  if a == true then return true end
  if type(a) == "number" then return (level or UnitLevel("player")) >= a end
  return false
end

-- Arme qui convient à la spé : la Vindicte joue à deux mains (ni arme à une main, ni main gauche)
function S.FitsSpec(id)
  local it = ns.Items[id]
  local p = S.PROFILES[S.Profile() or ""]
  if not (it and p and p.twoHand) then return true end
  return it[1] ~= 16 and it[1] ~= 17
end

-- Peut-on l'obtenir ? (faction, phase, provenances ; JcJ seul exclu sauf pour une liste de référence)
function S.Obtainable(id, allowPvp)
  local it = ns.Items[id]
  if not it then return true end
  local me = MyFaction()
  if it[5] > S.PHASE then return false, "phase" end
  if it[6] ~= 0 and me ~= 0 and it[6] ~= me then return false, "faction" end
  local src = it[9]
  if #src == 0 then return true end
  for _, s in ipairs(src) do
    local k = s[1]
    if k == "vendor" then if s[5] == 0 or me == 0 or s[5] == me then return true end
    elseif k == "rep" then if s[4] == 0 or me == 0 or s[4] == me then return true end
    elseif k == "quest" then if s[4] == 0 or me == 0 or s[4] == me then return true end
    elseif k == "pvp" then if allowPvp then return true end
    else return true end
  end
  return false, "source"
end

-- Sait-on où l'obtenir ? (provenance de wowsims, ou lieu connu d'All The Things)
function S.Known(id)
  local it = ns.Items[id]
  if it and #it[9] > 0 then return true end
  return (ns.HasPlace and ns.HasPlace(id)) and true or false
end

----------------------------------------------------------------------
-- Provenance en clair (dans ta langue quand le jeu la donne)
----------------------------------------------------------------------
local PROF_FR = { tailoring = "Couture", leatherworking = "Travail du cuir", enchanting = "Enchantement", blacksmithing = "Forge",
                  engineering = "Ingénierie", alchemy = "Alchimie", other = "Artisanat" }
local PROF_EN = { tailoring = "Tailoring", leatherworking = "Leatherworking", enchanting = "Enchanting", blacksmithing = "Blacksmithing",
                  engineering = "Engineering", alchemy = "Alchemy", other = "Crafted" }
local REP_FR = { [4] = "neutre", [5] = "amical", [6] = "honoré", [7] = "révéré", [8] = "exalté" }
local REP_EN = { [4] = "Neutral", [5] = "Friendly", [6] = "Honored", [7] = "Revered", [8] = "Exalted" }

local function ZoneName(zoneId)
  if not zoneId or zoneId == 0 then return nil end
  if C_Map and C_Map.GetAreaInfo then
    local ok, n = pcall(C_Map.GetAreaInfo, zoneId)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  return ns.ItemZones and ns.ItemZones[zoneId]
end
local function NpcName(id, fallback)
  if id and id > 0 and ns.ATT and ns.ATT.NpcName then
    local ok, n = pcall(ns.ATT.NpcName, id)
    if ok and n then return n end
  end
  return fallback ~= "" and fallback or nil
end
local function QuestName(id, fallback)
  if id and id > 0 and ns.ATT and ns.ATT.QuestName then
    local ok, n = pcall(ns.ATT.QuestName, id)
    if ok and n then return n end
  end
  return fallback ~= "" and fallback or nil
end

-- Provenances : texte, genre (boss, trash, quest, vendor, craft, rep, world, pvp), lieu ; la plus utile d'abord
function S.Sources(id)
  local it = ns.Items[id]
  local out = {}
  if not it then return out end
  local me = MyFaction()
  for _, s in ipairs(it[9]) do
    local k, e = s[1], nil
    if k == "drop" then
      local zone = ZoneName(s[3])
      local who = (s[2] > 0) and NpcName(s[2], s[4]) or nil
      if s[4] == "Trash" or (not who and zone) then
        e = { kind = "trash", text = string.format(L.srcTrash, zone or "?"), zone = zone }
      elseif zone then e = { kind = "boss", text = (who or "?") .. " — " .. zone, zone = zone }
      else e = { kind = "world", text = L.srcWorld } end
    elseif k == "quest" and (s[4] == 0 or me == 0 or s[4] == me) then
      e = { kind = "quest", text = string.format(L.srcQuestNamed, QuestName(s[2], s[3]) or "?"), quest = s[2] }
    elseif k == "vendor" and (s[5] == 0 or me == 0 or s[5] == me) then
      local zone = ZoneName(s[3])
      e = { kind = "vendor", text = string.format(L.srcVendorNamed, NpcName(s[2], s[4]) or "?") .. (zone and (" — " .. zone) or ""), zone = zone }
    elseif k == "craft" then
      e = { kind = "craft", text = string.format(L.srcCraft, (ns.lang ~= "en" and PROF_FR or PROF_EN)[s[2]] or s[2]) }
    elseif k == "rep" and (s[4] == 0 or me == 0 or s[4] == me) then
      local fname = ns.ItemFactions and ns.ItemFactions[s[2]] or "?"
      if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, fd = pcall(C_Reputation.GetFactionDataByID, s[2])
        if ok and type(fd) == "table" and fd.name then fname = fd.name end
      end
      e = { kind = "rep", text = string.format(L.srcRep, fname, (ns.lang ~= "en" and REP_FR or REP_EN)[s[3]] or tostring(s[3])) }
    elseif k == "pvp" then e = { kind = "pvp", text = L.srcPvp } end
    if e then out[#out + 1] = e end
  end
  local rank = { boss = 1, quest = 2, vendor = 3, trash = 4, craft = 5, rep = 6, world = 7, pvp = 8 }
  table.sort(out, function(a, b) return (rank[a.kind] or 9) < (rank[b.kind] or 9) end)
  return out
end

function S.SourceText(id)
  local s = S.Sources(id)
  if #s == 0 then return ns.ATTWhere and ns.ATTWhere(id) or nil end
  local t = s[1].text
  if #s > 1 then t = t .. string.format(L.srcMore, #s - 1) end
  return t
end

-- Lien utilisable tout de suite (objet pas encore chargé par le jeu : lien construit avec le nom de la base)
function S.Link(id)
  local _, link = Info(id)
  if link then return link end
  local it = ns.Items[id]
  local q = it and it[4] or 1
  local col = ({ [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" })[q] or "ffffffff"
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return "|c" .. col .. "|Hitem:" .. id .. "::::::::::::|h[" .. (it and it[8] or ("item " .. id)) .. "]|h|r"
end

----------------------------------------------------------------------
-- Gain face à ce que tu portes
----------------------------------------------------------------------
local function WornEP(slot)
  local l = GetInventoryItemLink("player", slot)
  return l and S.ItemEP(l) or 0, l
end

-- (gain, emplacement remplacé, main gauche avec une arme à deux mains)
function S.Gain(x)
  local id = type(x) == "number" and x or ItemID(x)
  local it = id and ns.Items[id]
  local code
  if it then code = it[1]
  else
    local _, _, _, equipLoc = Instant(x)
    local s = equipLoc and D.slots[equipLoc]
    if not s then return nil end
    code = s.two and 116 or s[1]
  end
  local ep = S.ItemEP(it and id or x)
  local slots, two = SlotsOf(code)
  if two then return ep - WornEP(16) - WornEP(17), 16 end
  if #slots == 2 then
    local a, la = WornEP(slots[1])
    local b, lb = WornEP(slots[2])
    if ItemID(la) == id or ItemID(lb) == id then return 0, slots[1] end        -- déjà porté
    if a <= b then return ep - a, slots[1] end
    return ep - b, slots[2]
  end
  if code == 17 then
    local mid = ItemID(GetInventoryItemLink("player", 16))
    if mid and ns.Items[mid] and ns.Items[mid][1] == 116 then return ep - WornEP(16), 17, true end
  end
  return ep - WornEP(slots[1]), slots[1]
end

-- Même forme que ns.Evaluate (Core.lua) : infobulles, jets de butin, récompenses de quête, alertes
function S.Evaluate(link)
  local id = ItemID(link)
  local known = id and ns.Items[id]
  local gain, slot, pair = S.Gain(known and id or link)
  if not gain then return nil end
  local ep, st = S.ItemEP(known and id or link)
  local wear = known and S.CanWear(id) or (not known and ns.Wearable(link))
  return { wearable = wear and true or false, method = "ep", slot = slot, score = gain, ep = ep, stats = st, pair = pair,
           minLevel = (known and S.ReqLevel(id)) or select(5, Info(link)) }
end

----------------------------------------------------------------------
-- Candidats : base intégrée + sacs (objets hors base : verts aléatoires, nouveautés)
----------------------------------------------------------------------
local function Bags()
  local out = {}
  for bag = 0, 4 do
    local n = (C_Container and C_Container.GetContainerNumSlots) and C_Container.GetContainerNumSlots(bag)
              or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
    for s = 1, n do
      local l = (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(bag, s)
                or (GetContainerItemLink and GetContainerItemLink(bag, s))
      if l then out[#out + 1] = l end
    end
  end
  return out
end

local memo
function S.Forget() memo = nil end

-- slot -> { items = { c } } trié par gain, jusqu'au niveau maxLevel (nil : 60), comme ns.BiS
function S.BiS(limit, maxLevel)
  local key = table.concat({ tostring(limit), tostring(maxLevel), tostring(S.Profile()), tostring(UnitLevel("player")),
                             tostring(ns.version), tostring(MyFaction()) }, ":")
  if memo and memo.k == key and GetTime() - memo.t < 10 then return memo.v end
  local out = {}
  local inBags = {}
  local function push(c)
    local slot = c.eval.slot
    slot = (slot == 12) and 11 or ((slot == 14) and 13 or slot)
    out[slot] = out[slot] or { items = {}, refs = {} }
    table.insert(out[slot].items, c)
  end
  local equipped = {}
  for s = 1, 18 do local id = ItemID(GetInventoryItemLink("player", s)); if id then equipped[id] = true end end
  local top = maxLevel or 60
  for _, l in ipairs(Bags()) do
    local id = ItemID(l)
    if id and not inBags[id] and not equipped[id] then
      local r = S.Evaluate(l)
      if r and r.wearable and r.score > ns.MIN_GAIN and (r.minLevel or 0) <= top then
        inBags[id] = true
        push({ link = l, id = id, src = "bags", eval = r, where = ns.Items[id] and S.SourceText(id) or nil })
      end
    end
  end
  for id in pairs(ns.Items) do
    if not inBags[id] and not equipped[id] then
      local req = S.ReqLevel(id)
      if req <= top and S.CanWear(id, top) and S.FitsSpec(id) and S.Obtainable(id) and S.Known(id) then
        local gain, slot, pair = S.Gain(id)
        if gain and gain > ns.MIN_GAIN then
          -- lien et provenance seulement pour les objets gardés (plus bas) : pas des centaines de demandes au jeu
          push({ id = id, src = "data", eval = { wearable = true, method = "ep", slot = slot, score = gain, pair = pair,
                 ep = (S.ItemEP(id)), stats = ns.Items[id][7], minLevel = req } })
        end
      end
    end
  end
  for _, s in pairs(out) do
    table.sort(s.items, function(a, b)
      if a.src ~= b.src and (a.src == "bags" or b.src == "bags") and math.abs(a.eval.score - b.eval.score) < 1 then return a.src == "bags" end
      return a.eval.score > b.eval.score
    end)
    while #s.items > (limit or 3) do table.remove(s.items) end
    for _, c in ipairs(s.items) do
      if not c.link then c.link = S.Link(c.id) end
      if c.where == nil then c.where = S.SourceText(c.id) or false end
    end
  end
  memo = { k = key, t = GetTime(), v = out }
  return out
end

----------------------------------------------------------------------
-- Objectif 60 : la référence de la spé, ta progression, et le meilleur calculé
----------------------------------------------------------------------
local function Have(id)
  for s = 1, 18 do if ItemID(GetInventoryItemLink("player", s)) == id then return "worn" end end
  for _, l in ipairs(Bags()) do if ItemID(l) == id then return "bags" end end
  local o = ns.Owned and ns.Owned(id)
  if o then return "owned", o end
  return nil
end
S.Have = Have

function S.RefKey()
  local p = S.PROFILES[S.Profile() or ""]
  return p and p.ref
end

-- { { slot, refs = { entrées de D.reference[clé] }, best = { { id, ep }, … } } }
function S.Goal()
  local rows, bySlot = {}, {}
  for _, slot in ipairs(D.slotOrder) do
    local row = { slot = slot, refs = {} }
    bySlot[slot] = row
    rows[#rows + 1] = row
  end
  for _, r in ipairs(D.reference[S.RefKey() or ""] or {}) do
    local slot = (r.slot == 12) and 11 or ((r.slot == 14) and 13 or r.slot)
    if bySlot[slot] then table.insert(bySlot[slot].refs, r) end
  end
  local best = {}
  for id, it in pairs(ns.Items) do
    if S.CanWear(id, 60) and S.FitsSpec(id) and S.Obtainable(id) and S.Known(id) then
      for _, s in ipairs(SlotsOf(it[1])) do
        if s ~= 12 and s ~= 14 then             -- anneaux et bijoux : comptés une fois
          best[s] = best[s] or {}
          table.insert(best[s], { id = id, ep = (S.ItemEP(id)) })
        end
      end
    end
  end
  for slot, list in pairs(best) do
    table.sort(list, function(a, b) return a.ep > b.ep end)
    if bySlot[slot] then bySlot[slot].best = { list[1], list[2] } end
  end
  return rows
end

-- Détail d'une valeur : « +12 soins, +4 mp5 (×0,6) … » (caractéristiques qui comptent pour la spé)
function S.Detail(stats)
  if not stats then return "" end
  local p = S.PROFILES[S.Profile() or ""]
  if not p then return "" end
  local parts = {}
  for _, k in ipairs(S.STAT_ORDER) do
    local v, w = stats[k], p.w[k]
    if v and w and w > 0 and math.abs(v) >= 1 then
      local val = (k == DPS) and string.format("%.1f", v) or string.format("%d", v)
      if ns.lang ~= "en" then val = val:gsub("%.", ",") end
      parts[#parts + 1] = "+" .. val .. " " .. L[S.STAT_NAME[k]] .. (w ~= 1 and string.format(" (×%s)", (tostring(w):gsub("%.", ","))) or "")
    end
  end
  return table.concat(parts, ", ")
end

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", function() S.Forget() end)
end
