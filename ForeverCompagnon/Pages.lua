local _, root = ...
local K = root.Kit

-- ForeverCompagnon 4.0 : les onglets Équipement, Donjon et Soins de la fenêtre principale (Main.lua), dans le même style.
-- Les données viennent des moteurs de chaque partie (lignes d'Équipement, analyse de la préparation, modèle des soins) ;
-- seul l'affichage est neuf. Une liste qui défile, faite de quatre sortes de lignes : titre, objet ou action, case à
-- cocher, texte.

local FR = root.FR
local T = FR and {
  now = "À mon niveau", goal = "Objectif 60", spec = "Spé : %s",
  nowHelp = "Meilleure pièce que tu peux obtenir d'ici le niveau %d, par emplacement. Clic droit : y aller.",
  dungeon = "Donjon", raid = "Raid", ready = "%d / %d prêt", go = "Y aller", guide = "Guide-moi",
  prepAuto = "Coché tout seul quand le jeu le voit (sacs, sorts, réparation).", prepIn = "Dans l'instance : %s",
  hps = "soins par seconde", oom = "à plein régime, sans boire", never = "jamais à sec", mana = "mana · régén. %s / s",
  spells = "Tes soins", spellsHint = "efficacité = points soignés par point de mana",
  helps = "Ce qui t'aide le plus", helpLine = "%s : %s soignés de plus avant d'être à sec",
  heal = "soin %s · %s s · %s mana", eff = "%s / mana",
  best = "le plus efficace", fast = "urgence", hot = "en mouvement", group = "groupe",
  noHeal = "Pas de sort de soin connu pour ta classe.", combat = "En combat : dernier état connu.",
  shift = "Maj+clic : lien dans la discussion", more = "Tout voir",
  hpsShort = "soins/s", oomShort = "autonomie", neverShort = "jamais à sec", manaShort = "mana", healShort = "%s · %s s · %s mana",
} or {
  now = "At my level", goal = "Level 60 goal", spec = "Spec: %s",
  nowHelp = "Best piece you can get up to level %d, per slot. Right-click: go there.",
  dungeon = "Dungeon", raid = "Raid", ready = "%d / %d ready", go = "Go", guide = "Guide me",
  prepAuto = "Ticked automatically when the game sees it (bags, spells, repairs).", prepIn = "In the instance: %s",
  hps = "healing per second", oom = "at full pace, without drinking", never = "never out of mana", mana = "mana · regen %s / s",
  spells = "Your heals", spellsHint = "efficiency = healing per mana point",
  helps = "What helps you most", helpLine = "%s: %s more healing before running dry",
  heal = "heal %s · %s s · %s mana", eff = "%s / mana",
  best = "most efficient", fast = "emergency", hot = "on the move", group = "group",
  noHeal = "No known healing spell for your class.", combat = "In combat: last known state.",
  shift = "Shift+click: link in chat", more = "See all",
  hpsShort = "heal/s", oomShort = "lasts", neverShort = "never dry", manaShort = "mana", healShort = "%s · %s s · %s mana",
}
root.PagesText = T

local C = root.Theme
local U = root.UI
local PAD = 16
root.Pages = {}

local function Num(v, dec)
  local m = 10 ^ (dec or 0)
  local s = tostring(math.floor((v or 0) * m + 0.5) / m)
  if FR then s = s:gsub("%.", ",") end
  return s
end
local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

----------------------------------------------------------------------
-- Boutons à bascule (vue, contexte) et bouton simple
----------------------------------------------------------------------
local function Segment(parent, labels, onPick)
  local f = U.Box(parent, C.card)
  f:SetHeight(28)
  f.buttons = {}
  local x = 3
  for i, label in ipairs(labels) do
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(22)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.fs = U.Text(b, 12, C.muted, "GameFontNormalSmall")
    b.fs:SetPoint("CENTER")
    b.fs:SetText(label)
    b:SetWidth(math.max(80, (b.fs:GetStringWidth() or 70) + 24))
    b:SetPoint("LEFT", x, 0)
    x = x + b:GetWidth() + 2
    b:SetScript("OnClick", function() onPick(i) end)
    f.buttons[i] = b
  end
  f:SetWidth(x + 1)
  function f.Select(self, n)
    for i, b in ipairs(self.buttons) do
      local on = i == n
      if on then U.Fill(b.bg, C.gold) else b.bg:SetColorTexture(0, 0, 0, 0) end
      local c = on and C.bg or C.muted
      b.fs:SetTextColor(c[1], c[2], c[3])
    end
  end
  return f
end

local function Button(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(26)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  U.Fill(b.bg, { 0.125, 0.141, 0.176 })
  K.Border(b, 0.23, 0.25, 0.29, 1)
  b.fs = U.Text(b, 12, C.text, "GameFontHighlightSmall")
  b.fs:SetPoint("CENTER")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0.3, 0.08)
  function b.SetLabel(self, t) self.fs:SetText(t); self:SetWidth((self.fs:GetStringWidth() or 80) + 24) end
  b:SetScript("OnClick", onClick)
  return b
end

----------------------------------------------------------------------
-- Liste qui défile : { kind = "head" | "card" | "check" | "info", … }
----------------------------------------------------------------------
local function List(parent)
  local L = {}
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(10, 10)
  scroll:SetScrollChild(content)
  L.scroll, L.content = scroll, content
  local pools = { head = {}, card = {}, check = {}, info = {} }
  local used = {}

  local function New(kind)
    if kind == "card" then
      local b = U.MakeRow(content)
      b:SetHeight(44)
      b:SetScript("OnClick", function(self, button)
        local l = self.line
        if not l then return end
        if IsShiftKeyDown() and l.link and _G.ChatEdit_InsertLink then _G.ChatEdit_InsertLink(l.link); return end
        if button == "RightButton" or not l.onClick then if l.onRight then l.onRight() end
        else l.onClick() end
      end)
      return b
    elseif kind == "check" then
      local b = CreateFrame("Button", nil, content)
      b:SetHeight(34)
      b.bg = b:CreateTexture(nil, "BACKGROUND")
      b.bg:SetAllPoints()
      U.Fill(b.bg, C.card)
      K.Border(b, C.line[1], C.line[2], C.line[3], 1)
      b.box = b:CreateTexture(nil, "ARTWORK")
      b.box:SetSize(18, 18)
      b.box:SetPoint("LEFT", 10, 0)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(22, 22)
      b.icon:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
      b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      b.action = U.Text(b, 12, C.blue, "GameFontNormalSmall")
      b.action:SetPoint("RIGHT", -12, 0)
      b.action:SetJustifyH("RIGHT")
      b.note = U.Text(b, 11, C.muted, "GameFontHighlightSmall")
      b.note:SetJustifyH("RIGHT")
      b.text = U.Text(b, 13, C.text, "GameFontHighlight")
      b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
      b.text:SetWordWrap(false)
      b:SetScript("OnClick", function(self) if self.line and self.line.onClick then self.line.onClick() end end)
      b:SetScript("OnEnter", U.Tip)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      return b
    elseif kind == "head" then
      local f = CreateFrame("Frame", nil, content)
      f:SetHeight(26)
      f.icon = f:CreateTexture(nil, "ARTWORK")
      f.icon:SetSize(18, 18)
      f.icon:SetPoint("BOTTOMLEFT", 0, 4)
      f.title = U.Text(f, 11, C.goldL, "GameFontNormalSmall")
      f.right = U.Text(f, 11, C.muted, "GameFontHighlightSmall")
      f.right:SetPoint("BOTTOMRIGHT", 0, 6)
      f.right:SetJustifyH("RIGHT")
      f.right:SetWordWrap(false)
      return f
    else
      local f = CreateFrame("Frame", nil, content)
      f.text = U.Text(f, 11, C.muted, "GameFontHighlightSmall")
      f.text:SetPoint("TOPLEFT", 0, 0)
      f.text:SetPoint("RIGHT", 0, 0)
      f.text:SetWordWrap(true)
      return f
    end
  end

  local function Get(kind)
    used[kind] = (used[kind] or 0) + 1
    local pool = pools[kind]
    local r = pool[used[kind]]
    if not r then r = New(kind); pool[used[kind]] = r end
    r:Show()
    return r
  end

  -- lignes affichées d'une sorte (tests, diagnostic)
  function L.Shown(kind)
    local out = {}
    for i = 1, used[kind] or 0 do out[#out + 1] = pools[kind][i] end
    return out
  end

  function L.Render(lines)
    for kind, pool in pairs(pools) do for _, r in ipairs(pool) do r:Hide(); r.line = nil end; used[kind] = 0 end
    local width = (scroll:GetWidth() or 0)
    if width < 100 then width = 500 end
    content:SetWidth(width)
    local y = 0
    for _, l in ipairs(lines) do
      local r = Get(l.kind == "slot" and "head" or l.kind)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y)
      r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
      r.line = l
      if l.kind == "card" then
        root.SetHomeRow(r, l, l.action or "")
        y = y + 44 + 6
      elseif l.kind == "check" then
        if l.done then r.box:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        elseif l.status == "warn" then r.box:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
        else r.box:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady") end
        r.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.icon:SetShown(l.icon ~= nil)
        local c = l.done and C.muted or C.text
        r.text:SetTextColor(c[1], c[2], c[3])
        r.text:SetText(l.label or "")
        r.action:SetText(l.action or "")
        r.note:SetText(l.note or "")
        r.note:ClearAllPoints()
        r.note:SetPoint("RIGHT", r.action, "LEFT", (l.action and l.action ~= "") and -12 or 0, 0)
        r.text:SetPoint("RIGHT", r.note, "LEFT", -12, 0)
        y = y + 34 + 5
      elseif l.kind == "head" or l.kind == "slot" then
        r.icon:SetShown(l.icon ~= nil)
        if l.icon then r.icon:SetTexture(l.icon) end
        r.title:ClearAllPoints()
        if l.icon then r.title:SetPoint("LEFT", r.icon, "RIGHT", 6, 0) else r.title:SetPoint("BOTTOMLEFT", 0, 6) end
        r.title:SetText(string.upper(Plain(l.title or l.text or "")))
        r.right:SetText(Plain(l.right or ""))
        r.title:SetWordWrap(false)
        if (l.right or "") ~= "" then r.title:SetPoint("RIGHT", r.right, "LEFT", -8, 0) end
        r:SetHeight(y == 0 and 20 or 30)
        y = y + (y == 0 and 20 or 30) + 4
      else
        r.text:SetText(l.display or l.text or "")
        local h = math.max(14, (r.text:GetStringHeight() or 14))
        r:SetHeight(h)
        y = y + h + 8
      end
    end
    content:SetHeight(math.max(10, y))
  end
  return L
end
root.UI.List = List

-- Ligne d'objet ou d'action : la même que l'Accueil, avec un bouton au choix
function root.SetHomeRow(b, l, action)
  b.line = l
  b.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  local qc = (l.quality and l.quality >= 2 and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[l.quality]) or nil
  for _, t in ipairs(b.ring) do
    if qc then t:SetColorTexture(qc.r, qc.g, qc.b, 1) else t:SetColorTexture(C.line[1], C.line[2], C.line[3], 1) end
  end
  b.name:SetText(l.name or "")
  if qc then b.name:SetTextColor(qc.r, qc.g, qc.b) else b.name:SetTextColor(C.text[1], C.text[2], C.text[3]) end
  local sub = l.source or ""
  if l.tags and l.tags ~= "" then sub = l.tags .. (sub ~= "" and ("  " .. sub) or "") end
  b.sub:SetText(sub)
  b.action:SetText(action)
  local ac = l.actionColor or C.blue
  b.action:SetTextColor(ac[1], ac[2], ac[3])
  b.pill:Hide()
  b.gain:SetText(l.gain or "")
  b.gain:ClearAllPoints()
  b.gain:SetPoint("RIGHT", b.action, "LEFT", action ~= "" and -12 or 0, 0)
  local right = (b.gain:GetStringWidth() or 0) + (b.action:GetStringWidth() or 0) + 52
  b.name:SetPoint("RIGHT", b, "RIGHT", -right, 0)
  b.sub:SetPoint("RIGHT", b, "RIGHT", -right, 0)
  b:Show()
end

local function ListArea(f, top)
  local list = List(f)
  list.scroll:SetPoint("TOPLEFT", PAD, top)
  list.scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, 8)
  return list
end

----------------------------------------------------------------------
-- Équipement : « À mon niveau » (lignes de ForeverLoot) et « Objectif 60 » (liste de référence)
----------------------------------------------------------------------
root.Pages.loot = {
  Create = function(f)
    f.seg = Segment(f, { T.now, T.goal }, function(i)
      root.lootView = (i == 2) and "goal" or "now"
      root.RefreshNow()
    end)
    f.seg:SetPoint("TOPLEFT", PAD, -12)
    f.spec = Button(f, function()
      local loot = root.mods.ForeverLoot
      if loot and loot.Spec then loot.Spec.NextProfile(); root.RefreshNow() end
    end)
    f.spec:SetPoint("TOPRIGHT", -PAD, -13)
    f.help = U.Text(f, 11, C.muted, "GameFontHighlightSmall")
    f.help:SetPoint("TOPLEFT", f.seg, "BOTTOMLEFT", 0, -8)
    f.help:SetPoint("RIGHT", -PAD, 0)
    f.list = ListArea(f, -72)
  end,
  Refresh = function(f)
    local loot = root.mods.ForeverLoot
    if not loot then return end
    local goal = root.lootView == "goal"
    f.seg:Select(goal and 2 or 1)
    local spec = loot.Spec and loot.Spec.Active() and loot.Spec.Profile()
    f.spec:SetShown(spec and true or false)
    if spec then f.spec:SetLabel(string.format(T.spec, loot.L["profile_" .. spec] or spec)) end
    local level = UnitLevel("player")
    local src
    if goal then src = (loot.Spec and loot.Spec.Active()) and loot.GoalLines() or loot.BisLines()
    else src = loot.NearLines() end
    local lines = {}
    for _, l in ipairs(src) do
      if l.kind == "card" then
        local c = {}
        for k, v in pairs(l) do c[k] = v end
        c.action = l.onRight and T.go or ""
        c.gain = l.gain
        lines[#lines + 1] = c
      elseif l.kind == "slot" then
        lines[#lines + 1] = { kind = "head", title = l.title, right = l.right, icon = l.icon }
      elseif l.kind == "info" and not l.hidden and (l.display or "") ~= "" then
        lines[#lines + 1] = { kind = "info", display = l.display }
      end
    end
    -- la première ligne d'information sert d'aide : affichée sous les boutons
    local help = goal and "" or string.format(T.nowHelp, math.min(60, level + (loot.nearSpan or 5)))
    if lines[1] and lines[1].kind == "info" then help = Plain(lines[1].display); table.remove(lines, 1) end
    f.help:SetText(help .. "  " .. T.shift)
    f.list.Render(lines)
  end,
}

----------------------------------------------------------------------
-- Donjon : la fiche de préparation en liste à cocher
----------------------------------------------------------------------
local lastPrep
root.Pages.prep = {
  Create = function(f)
    f.card = U.Box(f, C.card)
    f.card:SetPoint("TOPLEFT", PAD, -12)
    f.card:SetPoint("RIGHT", -PAD, 0)
    f.card:SetHeight(48)
    f.title = U.Text(f.card, 14, C.goldL, "GameFontNormal")
    K.TitleFont(f.title, 14, "GameFontNormal")
    f.title:SetTextColor(C.goldL[1], C.goldL[2], C.goldL[3])
    f.title:SetPoint("TOPLEFT", 12, -8)
    f.sub = U.Text(f.card, 11, C.muted, "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.done = U.Text(f.card, 13, C.text, "GameFontHighlight")
    f.done:SetPoint("TOPRIGHT", -12, -8)
    f.done:SetJustifyH("RIGHT")
    f.barBg = f.card:CreateTexture(nil, "ARTWORK")
    f.barBg:SetSize(120, 6)
    f.barBg:SetPoint("TOPRIGHT", f.done, "BOTTOMRIGHT", 0, -5)
    U.Fill(f.barBg, C.line)
    f.bar = f.card:CreateTexture(nil, "OVERLAY")
    f.bar:SetHeight(6)
    f.bar:SetPoint("LEFT", f.barBg, "LEFT")
    U.Fill(f.bar, C.green)
    f.seg = Segment(f, { T.dungeon, T.raid }, function(i)
      local prep = root.mods.ForeverPrep
      if prep and prep.db then prep.db.context = (i == 2) and "raid" or "dungeon" end
      root.RefreshNow()
    end)
    f.seg:SetPoint("TOPLEFT", f.card, "BOTTOMLEFT", 0, -10)
    f.guide = Button(f, function()
      local prep = root.mods.ForeverPrep
      if prep and prep.GuideToVendor then prep.GuideToVendor() end
    end)
    f.guide:SetPoint("TOPRIGHT", f.card, "BOTTOMRIGHT", 0, -11)
    f.guide:SetLabel(T.guide)
    f.list = ListArea(f, -112)
  end,
  Refresh = function(f)
    local prep = root.mods.ForeverPrep
    if not prep then return end
    local inInstance = IsInInstance()
    local ctx = inInstance and prep.Context() or (prep.db and prep.db.context) or "dungeon"
    local res
    if InCombatLockdown() and lastPrep then res = lastPrep; root.pageStatus = T.combat
    else res = prep.Analyze(ctx); lastPrep = res; root.pageStatus = "" end
    local PL = prep.L
    f.seg:Select(ctx == "raid" and 2 or 1)
    f.seg:SetShown(not inInstance)
    f.title:SetText(inInstance and string.format(T.prepIn, GetRealZoneText() or "") or (ctx == "raid" and T.raid or T.dungeon))
    f.sub:SetText(T.prepAuto)
    local lines, total, ok = {}, 0, 0
    for _, s in ipairs(res.sections or {}) do
      if s.rows and #s.rows > 0 then
        lines[#lines + 1] = { kind = "head", title = PL["sec_" .. s.key] or s.key }
        for _, r in ipairs(s.rows) do
          local title, detail = tostring(r.text or ""):match("^(.-)%s+—%s+(.+)$")
          if r.status == "info" then
            lines[#lines + 1] = { kind = "info", display = r.text }
          else
            total = total + 1
            local done = r.status == "ok"
            if done then ok = ok + 1 end
            local buy = r.buyID and (r.buyQty or 0) > 0
            lines[#lines + 1] = { kind = "check", done = done, status = r.status, icon = r.icon, label = Plain(title or r.text),
                                  note = detail and Plain(detail) or nil, action = buy and T.guide or nil,
                                  tip = { title = Plain(title or r.text), lines = { detail and Plain(detail) or nil } },
                                  onClick = buy and function() if prep.GuideToVendor then prep.GuideToVendor() end end or nil }
          end
        end
      end
    end
    f.done:SetText(string.format(T.ready, ok, total))
    f.bar:SetWidth(math.max(1, 120 * (total > 0 and ok / total or 1)))
    f.guide:SetShown(#(res.shopping or {}) > 0)
    f.list.Render(lines)
  end,
}

----------------------------------------------------------------------
-- Soins : trois chiffres, tes sorts, ce qui t'aide le plus
----------------------------------------------------------------------
-- Chiffres et lignes de l'onglet Soins (aussi la fiche collée au personnage, Sheet plus bas) ; nil : pas de soins
local function HealView(compact)
  local ns = root.mods.ForeverHeal
  if not (ns and ns.PanelData) then return nil end
  local d = ns.PanelData()
  if not d.priest then return nil end
  local M, S = d.M, d.S
  local dry = M.oom and M.oom ~= math.huge
  local vals = {
    { Num(M.hps), compact and T.hpsShort or T.hps, C.green },
    { dry and (M.oom >= 60 and string.format("%d min", math.floor(M.oom / 60)) or (math.floor(M.oom) .. " s")) or "OK",
      compact and (dry and T.oomShort or T.neverShort) or (dry and T.oom or T.never), (M.oom and M.oom < 60) and C.orange or C.green },
    { Num(S.mana), compact and T.manaShort or string.format(T.mana, Num(S.regenOut, 1)), C.blue },
  }
  local lines = { { kind = "head", title = T.spells, right = (not compact) and T.spellsHint or nil } }
  local spells = {}
  for _, m in pairs(ns.KnownSpells()) do
    local amount = (m.base + m.coef * (S.heal or 0)) * (m.mult or 1) * (m.targets or 1)
    spells[#spells + 1] = { m = m, amount = amount, eff = (m.cost and m.cost > 0) and amount / m.cost or 0 }
  end
  table.sort(spells, function(x, y) return x.eff > y.eff end)
  local fastest
  for _, sp in ipairs(spells) do if sp.m.canCrit and (not fastest or sp.m.cast < fastest.m.cast) then fastest = sp end end
  for i, sp in ipairs(spells) do
    local m = sp.m
    local tag, col = "", C.muted
    if i == 1 then tag, col = T.best, C.green
    elseif sp == fastest then tag, col = T.fast, C.orange
    elseif m.targets and m.targets > 1 then tag = T.group
    elseif not m.canCrit then tag = T.hot end
    local icon
    local get = (C_Spell and C_Spell.GetSpellTexture) or _G.GetSpellTexture
    if get then local okI, tex = pcall(get, m.id); if okI then icon = tex end end
    local card = { kind = "card", icon = icon or "Interface\\Icons\\Spell_Holy_Heal", name = m.name,
                   source = string.format(T.heal, Num(sp.amount), Num(m.cast, 1), Num(m.cost or 0)),
                   gain = string.format(T.eff, FR and (string.format("%.1f", sp.eff):gsub("%.", ",")) or string.format("%.1f", sp.eff)), action = tag, actionColor = col,
                   tip = { title = m.name, lines = { string.format(T.heal, Num(sp.amount), Num(m.cast, 1), Num(m.cost or 0)), T.spellsHint } } }
    if compact then
      -- fiche étroite : pas de colonne « conseil » ; il passe sous le nom, en couleur
      card.source = string.format(T.healShort, Num(sp.amount), Num(m.cast, 1), Num(m.cost or 0))
      if tag ~= "" then card.source = "|cff" .. U.Hex(col) .. tag .. "|r · " .. card.source end
      card.action = ""
    end
    lines[#lines + 1] = card
  end
  if #(d.gains or {}) > 0 then
    lines[#lines + 1] = { kind = "head", title = T.helps }
    for i, g in ipairs(d.gains) do
      if i <= 3 and (g.healed or 0) > 0 then
        lines[#lines + 1] = { kind = "info", display = "|cff" .. U.Hex(C.text) .. string.format(T.helpLine, g.label, Num(g.healed)) .. "|r" }
      end
    end
  end
  if d.footer then lines[#lines + 1] = { kind = "info", display = d.footer } end
  return vals, lines
end
root.HealView = HealView

local function SetCounters(counters, vals)
  for i, c in ipairs(counters) do
    c:Show()
    c.value:SetText(vals[i][1])
    c.label:SetText(vals[i][2])
    U.Fill(c.top, vals[i][3])
  end
end

root.Pages.heal = {
  Create = function(f)
    local cw = math.floor((f:GetWidth() > 100 and f:GetWidth() or 558) - 2 * PAD - 20) / 3
    f.counters = {}
    for i = 1, 3 do
      local c = U.MakeCounter(f)
      c:SetSize(cw, 54)
      c:SetPoint("TOPLEFT", PAD + (i - 1) * (cw + 10), -14)
      f.counters[i] = c
    end
    f.list = ListArea(f, -82)
  end,
  Refresh = function(f)
    local vals, lines = HealView()
    if not vals then
      for _, c in ipairs(f.counters) do c:Hide() end
      f.list.Render({ { kind = "info", display = T.noHeal } })
      return
    end
    SetCounters(f.counters, vals)
    f.list.Render(lines)
  end,
}

----------------------------------------------------------------------
-- Fiche collée au personnage (touche C) : l'onglet Soins en plus étroit, même style que la fenêtre
----------------------------------------------------------------------
local sheet
local SW, SH = 360, 430
local function Sheet()
  if sheet then return sheet end
  sheet = CreateFrame("Frame", "ForeverCompagnonSheet", UIParent)
  sheet:SetSize(SW, SH)
  sheet:SetFrameStrata("HIGH")
  sheet:EnableMouse(true)
  -- déplaçable (glisser), place retenue ; /fp fiche place : retour à côté de la fiche du personnage
  sheet:SetMovable(true)
  sheet:SetClampedToScreen(true)
  sheet:RegisterForDrag("LeftButton")
  sheet:SetScript("OnDragStart", sheet.StartMoving)
  sheet:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetLeft(), self:GetTop()
    if root.db and type(x) == "number" and type(y) == "number" then root.db.sheetPos = { x = x, y = y } end
  end)
  sheet:Hide()
  sheet.bg = sheet:CreateTexture(nil, "BACKGROUND")
  sheet.bg:SetAllPoints()
  U.Fill(sheet.bg, C.bg, 0.97)
  K.Border(sheet, C.frame[1], C.frame[2], C.frame[3], 1)
  local head = CreateFrame("Frame", nil, sheet)
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(40)
  head.bg = head:CreateTexture(nil, "BACKGROUND")
  head.bg:SetAllPoints()
  U.Fill(head.bg, C.head)
  local icon = head:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24)
  icon:SetPoint("LEFT", 12, 0)
  icon:SetTexture("Interface\\Icons\\Spell_Holy_GreaterHeal")
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local title = U.Text(head, 14, C.goldL, "GameFontNormal")
  K.TitleFont(title, 14, "GameFontNormal")
  title:SetTextColor(C.goldL[1], C.goldL[2], C.goldL[3])
  title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  title:SetText(root.MainText.heal)
  local more = Button(head, function() root.Open("heal") end)
  more:SetPoint("RIGHT", -10, 0)
  more:SetLabel(T.more)
  local cw = math.floor((SW - 2 * 12 - 2 * 6) / 3)
  sheet.counters = {}
  for i = 1, 3 do
    local c = U.MakeCounter(sheet)
    c:SetSize(cw, 50)
    c:SetPoint("TOPLEFT", 12 + (i - 1) * (cw + 6), -52)
    c.value:SetFont(c.value:GetFont(), 16, "")
    c.label:SetFont(c.label:GetFont(), 10, "")
    sheet.counters[i] = c
  end
  sheet.list = List(sheet)
  sheet.list.scroll:SetPoint("TOPLEFT", 12, -112)
  sheet.list.scroll:SetPoint("BOTTOMRIGHT", -32, 10)
  sheet:SetScript("OnShow", function() root.RefreshSheet() end)
  return sheet
end

function root.RefreshSheet()
  if not (sheet and sheet:IsShown()) then return end
  local vals, lines = HealView(true)
  if not vals then sheet:Hide(); return end
  SetCounters(sheet.counters, vals)
  sheet.list.Render(lines)
end

-- Appelé par la partie Soins à l'ouverture et à la fermeture de la fiche du personnage
function root.ShowSheet(anchor)
  if not HealView() then return false end
  Sheet()
  sheet:ClearAllPoints()
  local pos = root.db and root.db.sheetPos
  if pos and pos.x and pos.y then sheet:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  -- à droite de la fiche du personnage, sans couvrir ses onglets de droite (27/11/2026 : -30 les cachait)
  elseif anchor then sheet:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 40, -12)
  else sheet:SetPoint("CENTER") end
  if sheet:IsShown() then root.RefreshSheet() else sheet:Show() end
  return true
end
function root.HideSheet() if sheet then sheet:Hide() end end
