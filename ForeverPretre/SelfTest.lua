local _, root = ...
local L = root.L
local G = root.Game

-- Auto-test en jeu (/fp test) : chaque fonction importante est essayée pour de vrai sur ce client, et le rapport
-- (à copier) dit ce qui marche, ce qui échoue et ce qui n'a pas pu être testé (marchand fermé, fenêtre de métier fermée…).
-- Un test renvoie true / false (+ détail), ou nil + raison s'il ne peut pas être fait maintenant.

root.tests = {}
function root.Test(group, label, fn) root.tests[#root.tests + 1] = { group = group, label = label, fn = fn } end

local function Mod(name) return root.mods[name] end
local function Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- Lien avec le jeu
root.Test("Jeu", "objets des sacs lisibles", function()
  local n, first = 0, nil
  G.EachBagItem(function(_, _, id) n = n + 1; first = first or id end)
  if n == 0 then return false, "aucun objet trouvé dans les sacs (" .. tostring(G.used.bagSlots) .. ")" end
  local name = G.ItemInfo(first)
  return true, n .. " objets ; premier : " .. tostring(name or first) .. " (" .. tostring(G.used.bagItemID) .. ")"
end)
root.Test("Jeu", "équiper un objet possible", function()
  local f = G.Get("C_Item.EquipItemByName") or G.Get("EquipItemByName")
  local alt = (G.Has("C_Container.PickupContainerItem") or G.Has("PickupContainerItem")) and G.Has("AutoEquipCursorItem")
  if not f and not alt then return false, "ni EquipItemByName ni le repli par le sac" end
  return true, f and (G.Has("C_Item.EquipItemByName") and "C_Item.EquipItemByName" or "EquipItemByName") or "repli par le sac"
end)
root.Test("Jeu", "marchand lisible", function()
  if not (MerchantFrame and MerchantFrame:IsShown()) then return nil, "parle à un marchand puis relance /fp test" end
  local n = G.MerchantCount()
  if n == 0 then return false, "0 article (" .. tostring(G.used.merchantCount) .. ")" end
  local name, _, price = G.MerchantItem(1)
  if not name then return false, "article 1 illisible (" .. tostring(G.used.merchant) .. ")" end
  return true, n .. " articles ; 1er : " .. name .. " à " .. tostring(price) .. " (" .. tostring(G.used.merchant) .. ")"
end)
root.Test("Jeu", "nom d'un sort (Soins inférieurs)", function()
  local n = G.SpellName(2050)
  return n ~= nil, tostring(n) .. " (" .. tostring(G.used.spellName) .. ")"
end)
root.Test("Jeu", "mana lisible hors combat", function()
  if InCombatLockdown() then return nil, "en combat" end
  local cur, max = G.Mana()
  if not max then return false, "valeur secrète ou absente" end
  return true, tostring(cur) .. " / " .. tostring(max)
end)
root.Test("Jeu", "addons de données", function()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  local list = {}
  for _, a in ipairs({ "AllTheThings", "DungeonJournal", "Auctionator", "TomTom" }) do
    list[#list + 1] = a .. (loaded and loaded(a) and " oui" or " non")
  end
  return true, table.concat(list, ", ")
end)

-- Parties
root.Test("Soins", "relevé du prêtre", function()
  local ns = Mod("ForeverHeal")
  local S = ns.Snapshot()
  local M = ns.Metrics(S, ns.Mix())
  return (S.mana or 0) > 0, string.format("mana %s, soins/s %.1f, %d sorts connus", tostring(S.mana), M.hps or 0, Count(ns.KnownSpells()))
end)
root.Test("Équipement", "objets portés et sacs analysés", function()
  local ns = Mod("ForeverLoot")
  local c = ns.Candidates()
  return #c > 0, #c .. " objets"
end)
root.Test("Équipement", "améliorations à ton niveau", function()
  local ns = Mod("ForeverLoot")
  local n = 0
  for _, l in ipairs(ns.NearLines(5)) do if l.kind == "card" then n = n + 1 end end
  return true, n .. " suggestion(s) jusqu'au niveau " .. math.min(60, UnitLevel("player") + 5) .. (ns.DJ() and "" or " (DungeonJournal absent)")
end)
root.Test("Préparation", "fiche de préparation", function()
  local res = Mod("ForeverPrep").Analyze()
  local rows, todo = 0, 0
  for _, s in ipairs(res.sections) do
    for _, r in ipairs(s.rows) do rows = rows + 1; if r.status == "warn" or r.status == "bad" then todo = todo + 1 end end
  end
  return rows > 0, rows .. " lignes, " .. todo .. " à faire, " .. #res.shopping .. " achat(s)"
end)
root.Test("Métiers", "métiers lus", function()
  local ns = Mod("ForeverMetiers")
  ns.ReadSkills()
  local list = {}
  for k, v in pairs(ns.db and ns.db.skills or {}) do list[#list + 1] = k .. " " .. tostring(v.rank) .. "/" .. tostring(v.max) end
  return true, #list > 0 and table.concat(list, ", ") or "aucun métier"
end)
root.Test("Métiers", "fenêtre de métier lue", function()
  local ns = Mod("ForeverMetiers")
  local api = ns.TradeAPI()
  local f = api and api.frame and api.frame()
  if not (f and f:IsShown()) then return nil, "ouvre ta fenêtre de couture ou d'enchantement puis relance /fp test" end
  local ok, sc = pcall(ns.Scan, api)
  if not ok then return false, tostring(sc) end
  local n = 0
  for _ in pairs(sc and sc.recipes or {}) do n = n + 1 end
  return sc ~= nil and sc.prof ~= nil, "méthode " .. tostring(api.kind) .. ", métier " .. tostring(sc and (sc.prof or sc.name)) .. ", " .. n .. " recettes"
end)
root.Test("Maintenant", "écran Maintenant", function()
  local lines = root.NowLines()
  return #root.nowErrors == 0, #lines .. " lignes" .. (#root.nowErrors > 0 and (" ; " .. table.concat(root.nowErrors, " ; ")) or "")
end)
root.Test("Jeu", "actions bloquées depuis la connexion", function()
  local b = _G.ForeverBlockedActions or {}
  return #b == 0, #b == 0 and "aucune" or table.concat(b, " | ")
end)

function root.TestReport()
  local out = { "### ForeverPretre " .. tostring(((C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata)(root.ROOT, "Version"))
                .. " — auto-test du " .. date("%Y-%m-%d %H:%M"),
                "Client : " .. select(1, GetBuildInfo()) .. " (" .. select(2, GetBuildInfo()) .. "), niveau " .. UnitLevel("player")
                .. (InCombatLockdown() and ", EN COMBAT" or "") }
  local nOk, nKo, nSkip = 0, 0, 0
  for _, t in ipairs(root.tests) do
    local ok, res, detail = pcall(t.fn)
    local tag
    if not ok then tag, detail = L.ko, "erreur : " .. tostring(res); nKo = nKo + 1
    elseif res == nil then tag = L.skip; nSkip = nSkip + 1
    elseif res then tag = L.ok; nOk = nOk + 1
    else tag = L.ko; nKo = nKo + 1 end
    out[#out + 1] = string.format("[%s] %s — %s : %s", tag, t.group, t.label, tostring(detail or ""))
  end
  table.insert(out, 3, string.format("Bilan : %d OK, %d échec(s), %d non testé(s)", nOk, nKo, nSkip))
  return table.concat(out, "\n"), nKo
end

function root.RunTests()
  local text = root.TestReport()
  root.ShowText(L.testTitle, text)
end
