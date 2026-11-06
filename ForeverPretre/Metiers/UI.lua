local _, ns = ...; if ns.Module then _, ns = ns.Module("ForeverMetiers") end
local L = ns.L
local D = ns.Data
local Print = ns.Print
local K = ns.Kit

-- Fenêtre de ForeverMetiers : bandeaux de rubrique et cartes (icône encadrée de la couleur de qualité, nom, étiquettes,
-- détail dessous, chiffre important à droite), comme ForeverLoot.

local W, H = 700, 640
local ui, side
local tab = "level"

local function MakeButton(parent, text, width, onClick, template)
  local b = CreateFrame("Button", nil, parent, template or "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

local function Gray(s) return "|cffa0a0a0" .. s .. "|r" end
local function Colored(c, s) return c .. s .. "|r" end

local function SpellIcon(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    if ok and t then return t end
  end
  if GetSpellTexture then return GetSpellTexture(id) end
end

-- Objet : nom, lien, qualité, icône (même s'il n'est pas encore chargé)
local function ItemBits(idOrLink)
  if not idOrLink then return nil end
  local name, link, quality = ns.Info(idOrLink)
  local _, _, _, _, icon = ns.Instant(idOrLink)
  if not name and type(idOrLink) == "number" then name = ns.ItemName(idOrLink) end
  return name, link, quality, icon
end

-- Gain de ForeverHeal en deux parties : le grand chiffre et le détail
local function GainParts(r)
  if not r then return "", "" end
  local sub = {}
  if math.abs(r.healed or 0) >= 1 then sub[#sub + 1] = string.format(L.cardHealed, ns.Signed(r.healed)) end
  if math.abs(r.hp or 0) >= 1 then sub[#sub + 1] = string.format(L.cardHp, ns.Signed(r.hp)) end
  if math.abs(r.hps or 0) < 0.05 then return #sub > 0 and Gray(L.cardSurvival) or Gray(L.gainNone), table.concat(sub, " · ") end
  return ns.Signed(r.hps, 1) .. " |cffd8c8a0" .. L.cardHps .. "|r", table.concat(sub, " · ")
end

local DIFF = { optimal = "|cffff8040", medium = "|cffffff00", easy = "|cff40c040", trivial = "|cff808080" }

----------------------------------------------------------------------
-- Onglet Montée
----------------------------------------------------------------------
local function ShopCards(k, lines, max)
  local sh = ns.Shopping(k)
  local s = ns.db.skills[k]
  if not sh then
    if s and s.rank >= 300 then lines[#lines + 1] = { kind = "info", text = Gray(L.guideDone) } end
    return
  end
  local st = sh.st
  local sname, slink, sq, sicon = ItemBits(st.item)
  lines[#lines + 1] = { kind = "card", link = slink, icon = sicon or SpellIcon(st.spell) or D.profs[k].icon, quality = sq or 1,
                        name = (st.item and sname) or ns.SpellName(st.spell or 0) or st.name, nameColor = not st.item and { 1, 0.82, 0 } or nil,
                        tags = Colored("|cff66ccff", string.format(L.tagStep, st.from, st.to)),
                        source = string.format(L.stepCrafts, sh.crafts) .. "  ·  " .. L.guideSource,
                        text = string.format(L.guideStep, st.from, st.to, st.name, sh.crafts) }
  for i, m in ipairs(sh.items) do
    if max and i > max then break end
    local name, link, q, icon = ItemBits(m.id)
    local tags = m.missing > 0 and Colored("|cffff6a5a", string.format(L.tagMissing, m.missing)) or Colored("|cff40d860", L.tagOk)
    lines[#lines + 1] = { kind = "card", link = link, icon = icon, quality = q or 1, name = name or ns.ItemName(m.id), tags = tags,
                          source = string.format(L.shopDetail, m.need, m.bags, m.bank, m.alts > 0 and string.format(L.shopAlts, m.alts) or ""),
                          gain = m.price and ("|cffffd100" .. ns.Money(m.price) .. "|r") or "", gainSub = m.vendor and L.shopVendorShort or (m.price and L.perUnit or ""),
                          text = string.format(L.shopLine, ns.ItemName(m.id), m.need, m.bags, m.bank, m.alts > 0 and string.format(L.shopAlts, m.alts) or "",
                                 m.missing > 0 and string.format(L.shopMissing, m.missing, "") or L.shopOk) }
  end
  if sh.cost > 0 then lines[#lines + 1] = { kind = "info", text = Gray(string.format(L.shopTotal, ns.Money(sh.cost))) } end
end

local function CraftCard(e, onClick)
  local name, link, q, icon = ItemBits(e.item)
  local tags = { (DIFF[e.type] or "") .. (L["diffWord_" .. (e.type or "")] or e.type or "") .. "|r" }
  if e.guide then tags[#tags + 1] = Colored("|cff66ccff", L.tagGuide) end
  if e.de then tags[#tags + 1] = Colored("|cffb070ff", L.tagDE) end
  if e.up then tags[#tags + 1] = Colored("|cff40d860", L.tagUp) end
  return { kind = "card", link = e.link or link, icon = icon or SpellIcon(e.spell) or "Interface\\Icons\\INV_Misc_QuestionMark",
           quality = q or 1, name = e.name or name, nameColor = not e.item and { 1, 0.82, 0 } or nil, tags = table.concat(tags, "  "),
           source = ((e.avail or 0) > 0 and string.format(L.canCraft, e.avail) or L.cantCraft) .. (e.up and ("  ·  " .. e.up) or ""),
           gain = e.perPoint and ("|cffffd100" .. ns.Money(e.perPoint) .. "|r") or "", gainSub = e.perPoint and L.perPointShort or "",
           onClick = onClick, text = e.name }
end

local SrcText

local function Capital()
  local _, race = UnitRace("player")
  return (ns.lang == "en" and D.capitalEn[race or ""]) or D.capital[race or ""] or (ns.lang == "en" and "your capital" or "ta capitale")
end

-- Une étape numérotée, en carte
local function Step(n, icon, title, detail, right, rightSub, tags, link)
  return { kind = "card", icon = icon, quality = 1, name = (n and (n .. ". ") or "") .. title, nameColor = { 1, 0.82, 0 },
           tags = tags, source = detail, gain = right, gainSub = rightSub, link = link, text = title .. " " .. (detail or "") }
end

-- Où trouver une étoffe (humanoïdes du bon niveau)
local function ClothHint(id)
  local c = D.cloth[id]
  if not c then return nil end
  return string.format(L.clothWhere, ns.ItemName(id), c[1], c[2])
end

-- « Que faire ? » pour un métier pas encore appris : apprendre, puis la toute première étape
local function TodoNotLearned(k, lines)
  lines[#lines + 1] = { kind = "head", icon = D.profs[k].icon, title = L["prof_" .. k], right = Gray(L.notLearnedShort),
                        text = string.format(L.notLearned, L["prof_" .. k]) }
  lines[#lines + 1] = Step(1, "Interface\\Icons\\INV_Misc_Book_08", L["todoLearn_" .. k], string.format(L["todoWhere_" .. k], Capital()))
  if k == "tailoring" then
    local _, _, _, icon = ItemBits(2589)
    lines[#lines + 1] = Step(2, icon, L.todoClothTitle, ClothHint(2589))
    local _, _, _, bicon = ItemBits(2996)
    lines[#lines + 1] = Step(3, bicon, L.todoFirstCraftT, L.todoFirstCraftTDetail)
  else
    local _, _, _, ricon = ItemBits(6218)
    lines[#lines + 1] = Step(2, ricon, L.todoFirstCraftE, L.todoFirstCraftEDetail)
    lines[#lines + 1] = Step(3, "Interface\\Icons\\INV_Enchant_Disenchant", L.todoDE, L.todoDEDetail)
  end
end

-- « Que faire ? » pour un métier appris : maître si besoin, étape en cours et ce qui manque, meilleurs crafts, prochaine chose utile
local function TodoLearned(k, lines)
  local ri = ns.RankInfo(k)
  lines[#lines + 1] = { kind = "head", icon = D.profs[k].icon, title = L["prof_" .. k],
                        right = string.format("|cffffd100%d|r / %d  ·  %s", ri.rank, ri.max, L["rank_" .. ri.cur.key]),
                        text = string.format(L.skillLine, L["prof_" .. k], ri.rank, ri.max, L["rank_" .. ri.cur.key]) }
  local n = 0
  local function num() n = n + 1; return n end
  -- maître : seulement quand le plafond approche
  if ri.next and ri.rank >= ri.max - 15 then
    local lvlOk = UnitLevel("player") >= ri.next.level
    lines[#lines + 1] = Step(num(), "Interface\\Icons\\INV_Misc_Book_08", string.format(L.todoTrainer, L["rank_" .. ri.next.key]),
      string.format(L.todoTrainerDetail, ri.next.skill, ri.next.cap, ns.Trainer(k, ri.next.key)), nil, nil,
      lvlOk and Colored("|cff40d860", L.tagReady) or Colored("|cffff6a5a", string.format(L.tagLevelNeeded, ri.next.level)))
  end
  -- étape en cours du guide et ce qui manque
  local sh = ns.Shopping(k)
  if sh then
    local st = sh.st
    local name, link, _, icon = ItemBits(st.item)
    local missing, hints = {}, {}
    for _, m in ipairs(sh.items) do
      if m.missing > 0 then
        missing[#missing + 1] = m.missing .. " " .. ns.ItemName(m.id)
        local h = ClothHint(m.id)
        if h then hints[#hints + 1] = h end
      end
    end
    local detail = string.format(L.todoStepDetail, st.from, st.to)
                   .. "\n" .. (#missing > 0 and (string.format(L.todoMissing, table.concat(missing, ", "))) or ("|cff40d860" .. L.todoAllMats .. "|r"))
                   .. (#hints > 0 and ("\n" .. table.concat(hints, "\n")) or "")
    lines[#lines + 1] = Step(num(), icon or SpellIcon(st.spell) or D.profs[k].icon,
      string.format(L.todoCraft, (st.item and name) or ns.SpellName(st.spell or 0) or st.name, sh.crafts), detail,
      sh.cost > 0 and ("|cffffd100" .. ns.Money(sh.cost) .. "|r") or nil, sh.cost > 0 and L.todoToBuy or nil, nil, link)
    -- composants en détail
    for _, m in ipairs(sh.items) do
      local mname, mlink, q, micon = ItemBits(m.id)
      lines[#lines + 1] = { kind = "card", link = mlink, icon = micon, quality = q or 1, name = mname or ns.ItemName(m.id),
                            tags = m.missing > 0 and Colored("|cffff6a5a", string.format(L.tagMissing, m.missing)) or Colored("|cff40d860", L.tagOk),
                            source = string.format(L.shopDetail, m.need, m.bags, m.bank, m.alts > 0 and string.format(L.shopAlts, m.alts) or ""),
                            gain = m.price and ("|cffffd100" .. ns.Money(m.price) .. "|r") or "", gainSub = m.vendor and L.shopVendorShort or (m.price and L.perUnit or ""),
                            text = string.format(L.shopLine, ns.ItemName(m.id), m.need, m.bags, m.bank, "", "") }
    end
  elseif ri.rank >= 300 then
    lines[#lines + 1] = { kind = "info", text = Gray(L.guideDone) }
  end
  -- meilleurs crafts relevés dans la fenêtre du métier
  local adv = ns.db.lastAdvice[k]
  if adv and adv.items and #adv.items > 0 then
    lines[#lines + 1] = { kind = "info", boss = true, text = "|cffffd100" .. L.bestTitle .. "|r" }
    for i, e in ipairs(adv.items) do if i <= 3 then lines[#lines + 1] = CraftCard(e) end end
    lines[#lines + 1] = { kind = "info", text = string.format(L.bestOld, date("%d/%m %H:%M", adv.t)) }
  elseif not adv then
    lines[#lines + 1] = { kind = "info", text = Gray(string.format(L.skillUnknown, L["prof_" .. k])) }
  end
end

-- Prochaine chose utile pour toi (une seule) : la pièce ou l'enchantement le plus proche au-delà de ta portée
local function NextUseful(lines)
  local _, nextE = ns.EnchantNear()
  local near, nextP = ns.TailorNear()
  if #near > 0 then
    local u = near[1]
    local name, _, q, icon = ItemBits(u.link)
    local gain, sub = GainParts(u.gain)
    lines[#lines + 1] = { kind = "card", link = u.link, icon = icon, quality = q or 2, name = name or "?",
                          tags = Colored("|cff40d860", L.tagNow), source = u.known and L.tailorKnownSrc or ((u.src or "?") .. "  ·  " .. string.format(L.skillTag, u.need or 0)),
                          gain = gain, gainSub = sub, text = name or "" }
  elseif nextP then
    local name, _, q, icon = ItemBits(nextP.link)
    lines[#lines + 1] = { kind = "card", link = nextP.link, icon = icon, quality = q or 2, name = name or "?",
                          tags = Gray(string.format(L.tagFrom, nextP.minLevel or 0, nextP.need or 0)),
                          source = L.todoNextPiece, text = name or "" }
  end
  if nextE then
    lines[#lines + 1] = { kind = "card", icon = SpellIcon(nextE.e.spell) or D.profs.enchanting.icon, quality = 1, name = nextE.e.name, nameColor = { 1, 0.82, 0 },
                          tags = Gray(string.format(L.skillTag, nextE.need)), source = L.todoNextEnch .. "  ·  " .. SrcText(nextE.e), text = nextE.e.name }
  end
end

function ns.LevelLines()
  local lines = {}
  lines[#lines + 1] = { kind = "info", text = "|cffd8c8a0" .. L.todoIntro .. "|r" }
  for _, k in ipairs(D.profOrder) do
    if ns.RankInfo(k) then TodoLearned(k, lines) else TodoNotLearned(k, lines) end
  end
  lines[#lines + 1] = { kind = "head", icon = "Interface\\Icons\\INV_Misc_Note_02", title = L.todoUsefulTitle, text = L.todoUsefulTitle }
  local before = #lines
  NextUseful(lines)
  if #lines == before then lines[#lines + 1] = { kind = "info", text = Gray(L.todoNothing) } end
  if not (_G.Auctionator and _G.Auctionator.API) then lines[#lines + 1] = { kind = "info", text = Gray(L.auctionatorOff) } end
  return lines
end

----------------------------------------------------------------------
-- Onglet Pour toi : seulement ce qui est à ta portée
----------------------------------------------------------------------
function ns.ForYouLines()
  local lines = {}
  lines[#lines + 1] = { kind = "info", text = "|cffd8c8a0" .. string.format(L.nearIntro, ns.LevelWindow(), ns.SkillWindow("tailoring"),
                        ns.SkillWindow("enchanting")) .. "|r" }
  if not ns.HealAPI() then lines[#lines + 1] = { kind = "info", text = Gray(L.healOnly) } end
  -- enchantements : seulement les emplacements où quelque chose est à ta portée
  lines[#lines + 1] = { kind = "head", icon = D.profs.enchanting.icon, title = L.enchTitle, text = L.enchTitle }
  local list, nextE = ns.EnchantNear()
  local shown = 0
  for _, a in ipairs(list) do
    local best = a.known or a.now or a.soon
    if a.link and best then
      shown = shown + 1
      local slotName = L["slot" .. a.slot] or tostring(a.slot)
      local name, _, q, icon = ItemBits(a.link)
      local src = {}
      if a.known then src[#src + 1] = "|cff40d860" .. string.format(L.cardKnown, a.known.e.name) .. "|r" end
      if a.now then src[#src + 1] = string.format(L.cardNow, a.now.e.name, SrcText(a.now.e)) end
      if a.soon then src[#src + 1] = Gray(string.format(L.cardSoon2, a.soon.e.name, a.soon.need)) end
      local gain, sub = GainParts(best.gain)
      lines[#lines + 1] = { kind = "card", link = a.link, icon = icon, quality = q or 1, name = slotName .. " : " .. (name or "?"),
                            tags = a.enchanted and L.enchDone or L.enchMissing, source = table.concat(src, "\n"), gain = gain, gainSub = sub,
                            text = slotName .. " " .. (a.link or "") .. " " .. best.e.name .. " " .. table.concat(src, " ") }
    end
  end
  if shown == 0 then
    lines[#lines + 1] = { kind = "info", text = Gray(nextE and string.format(L.nearNoEnch, nextE.e.name, nextE.need) or L.nearNoEnchAtAll) }
  end
  -- couture : pièces à ta portée
  lines[#lines + 1] = { kind = "head", icon = D.profs.tailoring.icon, title = L.tailorTitle, text = L.tailorTitle }
  local near, nextP = ns.TailorNear()
  for _, u in ipairs(near) do
    local name, _, q, icon = ItemBits(u.link)
    local tags = { (u.minLevel or 0) > UnitLevel("player") and Colored("|cffff9a1a", string.format(L.cardLevel, u.minLevel)) or Gray(string.format(L.cardLevel, u.minLevel or 0)) }
    tags[#tags + 1] = u.known and Colored("|cff40d860", L.tailorKnown) or Colored("|cffffd100", L.tagToLearn)
    local gain, sub = GainParts(u.gain)
    lines[#lines + 1] = { kind = "card", link = u.link, icon = icon, quality = q or 2, name = name or "?", tags = table.concat(tags, "  "),
                          source = u.known and L.tailorKnownSrc or ((u.src or "?") .. "  ·  " .. string.format(L.skillTag, u.need or 0)),
                          gain = gain, gainSub = sub, text = (u.link or "") .. " " .. ns.GainText(u.gain) }
  end
  if #near == 0 then
    local nm = nextP and ItemBits(nextP.link)
    lines[#lines + 1] = { kind = "info", text = Gray(nextP and string.format(L.nearNoPiece, nm or "?", nextP.minLevel or 0, nextP.need or 0) or L.nearNoPieceAtAll) }
  end
  return lines
end

----------------------------------------------------------------------
-- Onglet Désenchanter
----------------------------------------------------------------------
function ns.DELines()
  local lines = {}
  if not ns.db.skills.enchanting then lines[#lines + 1] = { kind = "info", text = Gray(L.deNoEnchanting) } end
  lines[#lines + 1] = { kind = "head", icon = "Interface\\Icons\\INV_Enchant_Disenchant", title = L.deTitleShort, right = Gray(L.deKeepHint), text = L.deTitle }
  local list = ns.DECandidates()
  if #list == 0 then lines[#lines + 1] = { kind = "info", text = Gray(L.deNone) } end
  for _, c in ipairs(list) do
    local res = {}
    for _, id in ipairs(c.res.items) do res[#res + 1] = ns.ItemName(id) end
    local name, _, q, icon = ItemBits(c.link)
    local _, _, _, resIcon = ItemBits(c.res.items[1])
    local tags = { Gray(string.format(L.ilvlTag, c.ilvl)) }
    if not c.ok then tags[#tags + 1] = Colored("|cffff6a5a", string.format(L.skillTag, c.res.skill)) end
    lines[#lines + 1] = { kind = "card", link = c.link, icon = icon, quality = q or 2, name = name or "?", tags = table.concat(tags, "  "),
                          source = string.format(L.deGives, table.concat(res, " / ")),
                          gain = resIcon and ("|T" .. resIcon .. ":22|t") or "",
                          onRight = function() ns.db.keep[c.id] = true; Print(L.deKeep, c.link); ns.Refresh() end,
                          text = string.format(L.deLine, c.link, c.ilvl, table.concat(res, " / "), c.ok and "" or string.format(L.deSkill, c.res.skill)) }
  end
  if ns.db.skills.tailoring and ns.db.skills.enchanting then lines[#lines + 1] = { kind = "info", text = Gray(L.deLoop) } end
  return lines
end

----------------------------------------------------------------------
-- Onglet Recettes
----------------------------------------------------------------------
local function Status(k, entry)
  if ns.Known(k, entry) then return L.recKnown end
  local s = ns.db.skills[k]
  local need = ns.EntrySkill(entry)
  if s and s.rank >= need then return L.recNow end
  return string.format(L.recLater, need)
end

-- Où l'obtenir : All The Things (base Forever) en priorité, sinon le guide
SrcText = function(entry)
  local s = ns.Source(entry)
  if s and s.text then return "|cff66ccffATT|r " .. s.text end
  return entry.src or "?"
end
ns.SrcText = SrcText

local SECTION_ICON = { camp = "Interface\\Icons\\Spell_Fire_Fire", rods = "Interface\\Icons\\INV_Staff_Goldfeathered_01",
                       ench = "Interface\\Icons\\Trade_Engraving", pat = "Interface\\Icons\\Trade_Tailoring",
                       cd = "Interface\\Icons\\INV_Misc_PocketWatch_01" }

ns.showAll = false
function ns.RecipeLines()
  local lines = {}
  lines[#lines + 1] = { kind = "info", text = "|cffd8c8a0" .. (ns.showAll and L.recAllIntro or string.format(L.recNearIntro, D.nearSkill)) .. "|r" }
  local function near(k, p)
    if ns.showAll or ns.Known(k, p) then return true end
    return ns.EntrySkill(p) <= ns.SkillWindow(k)
  end
  local function section(title, icon, k, filter, list)
    local head = title and { kind = "head", icon = icon, title = title, text = title }
    local added = false
    for _, p in ipairs(list) do
      if filter(p) and near(k, p) then
        if head and not added then lines[#lines + 1] = head; added = true end
        local name, link, q, iicon
        if p.id then name, link, q, iicon = ItemBits(p.id) end
        local status = Status(k, p)
        lines[#lines + 1] = { kind = "card", link = link, icon = iicon or SpellIcon(p.spell) or icon, quality = q or 1,
                              name = name or p.name, nameColor = not name and { 1, 0.82, 0 } or nil,
                              tags = status .. (p.new and L.newTag or ""), source = SrcText(p), star = p.heal and not p.camp,
                              text = string.format(L.recLine, status, link or p.name, SrcText(p)) .. (p.new and L.newTag or "") }
      end
    end
  end
  section(L.recTitleCamp, SECTION_ICON.camp, "tailoring", function(p) return p.camp end, D.patterns.tailoring)
  section(nil, nil, "enchanting", function(p) return p.camp end, D.patterns.enchanting)
  section(L.recTitleRods, SECTION_ICON.rods, "enchanting", function(p) return p.rod end, D.patterns.enchanting)
  section(L.recTitleEnch, SECTION_ICON.ench, "enchanting", function() return true end, D.healEnchants)
  section(nil, nil, "enchanting", function(p) return p.heal end, D.patterns.enchanting)
  section(L.recTitlePat, SECTION_ICON.pat, "tailoring", function(p) return p.heal or (not p.camp and p.new) end, D.patterns.tailoring)
  -- toutes les recettes du métier d'après All The Things : à apprendre maintenant, puis bientôt
  if ns.ATT.Available() then
    for _, k in ipairs(D.profOrder) do
      local now, soon = ns.ATTLearnable(k)
      if now then
        local title = string.format(L.attNow, L["prof_" .. k], ns.db.skills[k].rank)
        lines[#lines + 1] = { kind = "head", icon = D.profs[k].icon, title = L["prof_" .. k], right = Gray(L.attNowShort), text = title }
        if #now == 0 then lines[#lines + 1] = { kind = "info", text = Gray(L.attNone) } end
        local function card(r, later)
          local src = ns.ATT.Source("recipeID", r.spell)
          local name, link, q, icon = ItemBits(r.item)
          return { kind = "card", link = link, icon = icon or SpellIcon(r.spell), quality = q or 1, name = r.name or name or "?",
                   nameColor = later and { 0.6, 0.6, 0.6 } or { 1, 0.82, 0 },
                   tags = later and Gray(string.format(L.skillTag, r.learnedAt)) or Colored("|cffffd100", string.format(L.skillTag, r.learnedAt)),
                   source = src and src.text or "?", text = string.format(L.attLine, r.learnedAt, r.name, src and src.text or "?") }
        end
        for i, r in ipairs(now) do
          if i > 15 then lines[#lines + 1] = { kind = "info", text = Gray(string.format(L.attMore, #now - 15)) }; break end
          lines[#lines + 1] = card(r)
        end
        if #soon > 0 then
          lines[#lines + 1] = { kind = "info", boss = true, text = "|cffffd100" .. string.format(L.attSoon, #soon) .. "|r" }
          for i, r in ipairs(soon) do
            if i > 8 then break end
            lines[#lines + 1] = card(r, true)
          end
        end
      end
    end
  else
    lines[#lines + 1] = { kind = "info", text = Gray(L.attOff) }
  end
  -- temps de recharge de tous tes personnages
  lines[#lines + 1] = { kind = "head", icon = SECTION_ICON.cd, title = L.cdTitle, text = L.cdTitle }
  local now, any = time(), false
  for char, list in pairs(ns.gdb.cooldowns) do
    for recipe, t in pairs(list) do
      any = true
      lines[#lines + 1] = { kind = "info", text = char .. " — " .. recipe .. " : " .. (t <= now and L.cdReady or string.format(L.cdLeft, ns.Duration(t - now))) }
    end
  end
  if not any then lines[#lines + 1] = { kind = "info", text = Gray(L.cdNone) } end
  return lines
end

----------------------------------------------------------------------
-- Fenêtre principale
----------------------------------------------------------------------
local TABS = { { "level", "tabLevel" }, { "foryou", "tabForYou" }, { "de", "tabDE" }, { "recipes", "tabRecipes" } }

-- Bouton sécurisé : Désenchanter le premier objet de la liste (macro mise à jour hors combat seulement)
function ns.UpdateDEButton()
  if not (ui and ui.deBtn) then return end
  local first = ns.DECandidates()[1]
  ns.deMacro = first and first.ok and ns.DEMacro(first) or nil
  if InCombatLockdown() then return end
  ui.deBtn:SetAttribute("type", "macro")
  ui.deBtn:SetAttribute("macrotext", ns.deMacro or "")
  ui.deBtn:SetEnabled(ns.deMacro ~= nil)
end

function ns.Refresh()
  if ui and ui:IsShown() then
    local lines = (tab == "foryou" and ns.ForYouLines()) or (tab == "de" and ns.DELines()) or (tab == "recipes" and ns.RecipeLines()) or ns.LevelLines()
    ui.list.Render(lines)
    for _, t in ipairs(TABS) do ui.tabs[t[1]]:SetActive(tab == t[1]) end
    ui.allBtn:SetShown(tab == "recipes")
    ui.allBtn:SetText(ns.showAll and L.showNear or L.showAll)
    if not InCombatLockdown() then ui.deBtn:SetShown(tab == "de") end
    if tab == "de" then ns.UpdateDEButton() end
  end
  if side and side:IsShown() and ns.lastScan and ns.lastScan.prof then ns.RenderSide(ns.lastScan) end
end

local opt
local function ShowOptions()
  if not opt then
    opt = CreateFrame("Frame", "ForeverMetiersOptionsFrame", ui, "BasicFrameTemplateWithInset")
    ns.SafeClose(opt)
    opt:SetSize(420, 150)
    opt:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -10, -70)
    opt:SetFrameStrata("DIALOG")
    K.Dress(opt, "Interface\\Icons\\INV_Misc_Gear_01", L.optTitle)
    local y = -34
    local function C(text, key)
      local cb = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
      cb:SetSize(22, 22)
      cb:SetPoint("TOPLEFT", 14, y)
      local lab = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      lab:SetPoint("LEFT", cb, "RIGHT", 2, 0)
      lab:SetText(text)
      cb:SetScript("OnShow", function(self) self:SetChecked(ns.db[key]) end)
      cb:SetScript("OnClick", function(self) ns.db[key] = self:GetChecked() and true or false; ns.Refresh() end)
      y = y - 28
    end
    C(L.optSide, "side")
    C(L.optTip, "tooltip")
    C(L.optRank, "rankReminder")
    opt:Hide()
  end
  opt:SetShown(not opt:IsShown())
end
ns.ShowOptions = ShowOptions

local function CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverMetiersFrame", UIParent, "BasicFrameTemplateWithInset")
  ns.SafeClose(ui)
  ns.ui = ui
  ui:SetSize(W, H)
  ui:SetPoint("CENTER", -40, 20)
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverMetiersFrame")
  ui:Hide()
  K.Dress(ui, "Interface\\Icons\\Trade_Tailoring", L.title)
  ui.diagBtn = ns.MakeDiagButton(ui)
  ui.tabs = {}
  local prev
  for _, t in ipairs(TABS) do
    local b = K.Tab(ui, L[t[2]], function() tab = t[1]; ns.Refresh() end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -32) end
    ui.tabs[t[1]] = b
    prev = b
  end
  ui.optBtn = K.Action(ui, "Interface\\Icons\\INV_Misc_Gear_01", L.optShort, L.optTip2, function() ShowOptions() end)
  ui.optBtn:SetPoint("TOPRIGHT", -18, -30)
  ui.allBtn = MakeButton(ui, L.showAll, 130, function() ns.showAll = not ns.showAll; ns.Refresh() end)
  ui.allBtn:SetPoint("RIGHT", ui.optBtn, "LEFT", -16, 4)
  ui.allBtn:Hide()
  ui.list = K.CardList(ui, W - 60)
  ui.list.scroll:SetPoint("TOPLEFT", 16, -82)
  ui.list.scroll:SetPoint("BOTTOMRIGHT", -34, 48)
  K.Backdrop(ui, ui.list.scroll, 0.6, 6)
  -- bouton sécurisé rattaché à UIParent, pas à la fenêtre : un enfant sécurisé rendrait la fenêtre impossible à fermer en
  -- combat ; on ne le montre / cache / règle que hors combat
  local de = CreateFrame("Button", "ForeverMetiersDEButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  de:SetFrameStrata("DIALOG")
  de:Hide()
  de:SetSize(220, 26)
  de:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -16, 12)
  de:SetText(L.deButton)
  de:RegisterForClicks("AnyUp", "AnyDown")
  de:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.deButtonTip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  de:SetScript("OnLeave", function() GameTooltip:Hide() end)
  de:HookScript("PostClick", function() C_Timer.After(2, function() if ns.OnBags then ns.OnBags() end end) end)
  ui.deBtn = de
  ui:HookScript("OnHide", function() if not InCombatLockdown() then de:Hide() else ns.deHidePending = true end end)
  ui:SetScript("OnShow", function() ns.Refresh() end)
  return ui
end

function ns.Toggle()
  CreateUI()
  if ui:IsShown() then ui:Hide() else ui:Show() end
end
function ns.ShowTab(t) CreateUI(); tab = t; if ui:IsShown() then ns.Refresh() else ui:Show() end end

----------------------------------------------------------------------
-- Panneau à côté de la fenêtre du métier
----------------------------------------------------------------------
local function CreateSide()
  if side then return side end
  side = CreateFrame("Frame", "ForeverMetiersSide", UIParent, "BasicFrameTemplateWithInset")
  ns.SafeClose(side)
  ns.side = side
  side:SetSize(380, 470)
  side:SetFrameStrata("HIGH")
  side:Hide()
  side.title = K.Dress(side, "Interface\\Icons\\Trade_Tailoring", "")
  side.title:SetPoint("RIGHT", -30, 0)
  side.title:SetJustifyH("LEFT")
  side.list = K.CardList(side, 330)
  side.list.scroll:SetPoint("TOPLEFT", 14, -34)
  side.list.scroll:SetPoint("BOTTOMRIGHT", -32, 40)
  K.Backdrop(side, side.list.scroll, 0.6, 6)
  local more = MakeButton(side, L.more, 90, function() ns.ShowTab("level") end)
  more:SetPoint("BOTTOMRIGHT", -12, 8)
  return side
end

function ns.RenderSide(sc)
  CreateSide()
  local api = ns.API[sc.kind]
  local ri = ns.RankInfo(sc.prof)
  side.title:SetText("ForeverMetiers — " .. L["prof_" .. sc.prof] .. string.format(" %d/%d", sc.rank or 0, sc.max or 0))
  local lines = {}
  if ri and ri.next and ri.rank >= ri.max - 10 then
    lines[#lines + 1] = { kind = "info", text = "|cffff9a1a" .. string.format(L.rankSoon, L["prof_" .. sc.prof], ri.rank, ri.max,
                          L["rank_" .. ri.next.key], ns.Trainer(sc.prof, ri.next.key)) .. "|r" }
  end
  lines[#lines + 1] = { kind = "info", boss = true, text = "|cffffd100" .. L.bestTitle .. "|r" }
  local adv = ns.Advise(sc, 5)
  if #adv == 0 then lines[#lines + 1] = { kind = "info", text = Gray(L.bestNone) } end
  for _, e in ipairs(adv) do
    local card = CraftCard({ name = e.r.name, link = e.r.link, item = e.r.item, spell = e.r.spell, type = e.r.type, avail = e.r.avail,
                             perPoint = e.perPoint, guide = e.guide, de = e.de, up = e.upgrade and ns.GainText(e.upgrade) or nil },
                           function() api.select(e.r.index) end)
    card.text = ns.CraftText(e)
    lines[#lines + 1] = card
  end
  ShopCards(sc.prof, lines, 6)
  side.list.Render(lines)
end

ns.OnScan = function(sc, api)
  if not (sc and ns.db.side) then
    if side then side:Hide() end
    return
  end
  CreateSide()
  local f = api.frame()
  side:ClearAllPoints()
  if f then side:SetPoint("TOPLEFT", f, "TOPRIGHT", -30, -12) else side:SetPoint("CENTER", 300, 0) end
  side:Show()
  ns.RenderSide(sc)
  if ui and ui:IsShown() then ns.Refresh() end
end
ns.OnClose = function() if side then side:Hide() end end
ns.OnBags = function()
  if ui and ui:IsShown() and (tab == "de" or tab == "level") then ns.Refresh() end
  if side and side:IsShown() and ns.lastScan and ns.lastScan.prof then ns.RenderSide(ns.lastScan) end
end

----------------------------------------------------------------------
-- Infobulles : patrons et formules (appris ou non, par qui), composants de l'étape en cours
----------------------------------------------------------------------
local function RecipeProf(classID, subID)
  if classID ~= 9 then return nil end
  if subID == 2 then return "tailoring" elseif subID == 8 then return "enchanting" end
end

local function HealUseful(k, n)
  for _, p in ipairs(D.patterns[k] or {}) do if p.heal and n:find(ns.Norm(p.name), 1, true) then return true end end
  if k == "enchanting" then
    for _, e in ipairs(D.healEnchants) do
      local inner = e.name:match("%((.+)%)")
      local slotWord = e.name:match("^(%S+)")
      if inner and n:find(ns.Norm(inner), 1, true) and n:find(ns.Norm(slotWord), 1, true) then return true end
    end
  end
  return false
end

local function OnTooltipItem(tt)
  if not (ns.db and ns.db.tooltip) or tt == _G.ForeverHealScanTip then return end
  local name, link = tt:GetItem()
  local id = link and ns.ItemID(link)
  if not id then return end
  local _, _, _, _, _, classID, subID = ns.Instant(id)
  local k = RecipeProf(classID, subID)
  if k and name then
    local n = ns.Norm(name:match("^[^:]+:%s*(.+)$") or name)
    local mine = ns.db.known[k]
    if mine and mine[n] then
      tt:AddLine(L.tipKnown, 0.25, 0.85, 0.25)
    else
      local who = {}
      for char, profs in pairs(ns.gdb.known) do
        if char ~= ns.CharKey() and profs[k] and profs[k][n] then who[#who + 1] = char:match("^(.-) %- ") or char end
      end
      if #who > 0 then tt:AddLine(string.format(L.tipAlt, table.concat(who, ", ")), 0.4, 0.8, 1)
      elseif ns.db.skills[k] then
        tt:AddLine(string.format(L.tipUnknown, L["prof_" .. k] .. " " .. ns.db.skills[k].rank), 1, 0.82, 0)
      end
    end
    if HealUseful(k, n) then tt:AddLine(L.tipHeal, 0.4, 0.85, 0.4) end
    return
  end
  for _, pk in ipairs(D.profOrder) do
    local sh = ns.db.skills[pk] and ns.Shopping(pk)
    for _, m in ipairs(sh and sh.items or {}) do
      if m.id == id then
        tt:AddLine(string.format(L.tipMat, L["prof_" .. pk], sh.st.from, sh.st.to, m.need), 0.4, 0.8, 1)
      end
    end
  end
end
ns.OnTooltipItem = OnTooltipItem

ns.OnLogin = function()
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
      if tt == GameTooltip or tt == ItemRefTooltip then OnTooltipItem(tt) end
    end)
  else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
      if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", OnTooltipItem) end
    end
  end
end

----------------------------------------------------------------------
-- Diagnostic, commandes
----------------------------------------------------------------------
function ns.DiagCollect(add)
  add("")
  add("## Métiers lus")
  for _, k in ipairs(D.profOrder) do
    local s = ns.db.skills[k]
    add(string.format("  %s : %s", k, s and string.format("%d/%d", s.rank, s.max) or "absent"))
  end
  if GetNumSkillLines and GetSkillLineInfo then
    local names = {}
    for i = 1, GetNumSkillLines() do
      local n, header = GetSkillLineInfo(i)
      if n and not header then names[#names + 1] = n end
    end
    add("  lignes de compétence : " .. table.concat(names, ", "))
  end
  local sc = ns.lastScan
  add("")
  add("## Dernière fenêtre de métier")
  if ns.lastScanError then add("  ERREUR de lecture : " .. ns.lastScanError) end
  add("  méthode de lecture : " .. tostring(ns.TradeAPI().kind) .. " (C_TradeSkillUI " .. ((C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) and "oui" or "NON") .. ")")
  if not sc then add("  aucune ouverte depuis le chargement")
  else
    add(string.format("  %s (API %s), %s recettes, %s/%s", tostring(sc.name or sc.prof), tostring(sc.kind), tostring(sc.recipes and #sc.recipes or 0),
      tostring(sc.rank), tostring(sc.max)))
    for i, r in ipairs(sc.recipes or {}) do
      if i > 12 then break end
      local reag = {}
      for _, g in ipairs(r.reagents) do reag[#reag + 1] = string.format("%s×%d(%s)", tostring(g.name), g.need, tostring(g.id)) end
      add(string.format("  - %s [%s] dispo %d, objet %s, sort %s, recharge %s : %s", r.name, tostring(r.type), r.avail, tostring(r.item), tostring(r.spell),
        tostring(ns.lastApi and ns.lastApi.cd(r.index)), table.concat(reag, ", ")))
    end
    local step = sc.prof and ns.GuideStep(sc.prof, sc.rank)
    if step then
      local found = false
      for _, r in ipairs(sc.recipes or {}) do if ns.Matches(step, r) then found = r end end
      add(string.format("  étape du guide %d-%d « %s » : %s", step.from, step.to, step.name,
        found and ("trouvée (" .. tostring(found.type) .. ")") or "INTROUVABLE dans la fenêtre"))
    end
  end
  add("")
  add("## Enchantements de soigneur (numéro = nom de ce client ; connu ; gain lu)")
  for _, e in ipairs(D.healEnchants) do
    local name = ns.SpellName(e.spell)
    local st = ns.db.enchStats[e.spell]
    local stTxt = st and (string.format("int %s, esprit %s, soins %s, end. %s", tostring(st.int), tostring(st.spi), tostring(st.heal), tostring(st.sta))) or "-"
    add(string.format("  %d = %s ; %s ; connu %s ; lu : %s", e.spell, tostring(name or "ABSENT"), e.name, tostring(ns.Known("enchanting", e)), stTxt))
  end
  add("")
  add("## Patrons et objets du guide (numéro = nom, classe/sous-classe)")
  local ids = {}
  for _, k in ipairs(D.profOrder) do for _, p in ipairs(D.patterns[k]) do if p.id then ids[#ids + 1] = { p.id, p.name } end end end
  for _, id in ipairs(D.checkItems) do ids[#ids + 1] = { id, "" } end
  for _, x in ipairs(ids) do
    local name = ns.Info(x[1])
    local _, _, _, loc, _, cid, sid = ns.Instant(x[1])
    add(string.format("  %d = %s (%s/%s, %s) — guide : %s", x[1], tostring(name or "ABSENT OU PAS CHARGÉ"), tostring(cid), tostring(sid), tostring(loc), x[2]))
  end
  add("")
  add("Auctionator : " .. ((_G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1) and "présent" or "absent"))
  local S = _G.Syndicator
  add("Syndicator : " .. ((S and S.API) and "présent" or "absent"))
  add("ForeverHeal (évaluation) : " .. (ns.HealAPI() and ("présent, API " .. tostring(_G.ForeverHealAPI.version)) or "absent ou pas prêtre"))
  add("Désenchanter : " .. tostring(ns.SpellName(D.disenchantSpell)))
  local api = {}
  for _, n in ipairs({ "GetNumSkillLines", "GetProfessions", "GetTradeSkillLine", "GetTradeSkillInfo", "GetCraftDisplaySkillLine", "GetCraftInfo",
                       "GetTradeSkillCooldown", "TradeSkillFrame_SetSelection", "CraftFrame_SetSelection", "GetSpellInfo" }) do
    api[#api + 1] = n .. (_G[n] and " oui" or " NON")
  end
  add("API du client : " .. table.concat(api, ", ") .. ", C_TradeSkillUI " .. (_G.C_TradeSkillUI and "oui" or "NON"))
  if GetProfessions and GetProfessionInfo then
    local p = {}
    for _, idx in ipairs({ GetProfessions() }) do
      local n, _, r, m, _, _, line = GetProfessionInfo(idx)
      p[#p + 1] = string.format("%s %s/%s (ligne %s)", tostring(n), tostring(r), tostring(m), tostring(line))
    end
    add("Métiers (GetProfessions) : " .. (#p > 0 and table.concat(p, ", ") or "aucun"))
  end
  ns.ATT.Diag(add)
  if ns.ATT.Available() then
    for _, e in ipairs(D.healEnchants) do
      local s = ns.Source(e)
      if s then add(string.format("  ATT %d : appris à %s, %s%s", e.spell, tostring(s.learnedAt), tostring(s.text), s.weak and (" [peu précis : " .. s.weak .. "]") or "")) end
    end
  end
  local nCd = 0
  for _, list in pairs(ns.gdb.cooldowns) do for _ in pairs(list) do nCd = nCd + 1 end end
  add("Temps de recharge relevés : " .. nCd)
end

SLASH_FOREVERMETIERS1 = "/metiers"
SLASH_FOREVERMETIERS2 = "/fmet"
SlashCmdList.FOREVERMETIERS = function(msg)
  msg = ((msg or ""):match("^%s*(.-)%s*$")):lower()
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" or cmd == "montee" or cmd == "level" then ns.ShowTab("level")
  elseif cmd == "pourtoi" or cmd == "foryou" then ns.ShowTab("foryou")
  elseif cmd == "de" or cmd == "desenchanter" then ns.ShowTab("de")
  elseif cmd == "recettes" or cmd == "recipes" then ns.ShowTab("recipes")
  elseif cmd == "garder" or cmd == "keep" then wipe(ns.db.keep); Print(L.deKeepReset); ns.Refresh()
  elseif cmd == "diag" then ns.ShowDiag()
  elseif cmd == "lang" and (arg == "fr" or arg == "en") then ns.lang, ns.db.lang = arg, arg; ns.Refresh()
  else Print(L.helpText) end
end

function ForeverMetiers_OnCompartmentClick() ns.Toggle() end
