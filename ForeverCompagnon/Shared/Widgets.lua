-- Généré par tools/sync-shared.sh depuis tools/Widgets.lua : ne pas modifier ici.
local _, root = ...
root.Shared.Widgets = function(...)
local _, ns = ...

-- Éléments d'interface communs aux fenêtres Forever (copié tel quel par tools/sync-shared.sh), dans le style de WoW :
-- onglets dorés, actions en icônes avec leur nom, cadres fins, titres en lettres de livre, pastilles d'état (appel).
-- Rien ne dépend d'un modèle propre à une version du jeu : textures et couleurs simples, présentes partout.
local K = {}
ns.Kit = K

K.GOLD = { 1, 0.82, 0 }
K.TITLE_FONT = "Fonts\\MORPHEUS.TTF"          -- police des titres de quêtes et des livres

-- Cadre fin (quatre traits) autour d'une zone
function K.Border(parent, r, g, b, a, layer)
  local t = {}
  for i = 1, 4 do
    t[i] = parent:CreateTexture(nil, layer or "BORDER")
    t[i]:SetColorTexture(r, g, b, a)
  end
  t[1]:SetPoint("TOPLEFT"); t[1]:SetPoint("TOPRIGHT"); t[1]:SetHeight(1)
  t[2]:SetPoint("BOTTOMLEFT"); t[2]:SetPoint("BOTTOMRIGHT"); t[2]:SetHeight(1)
  t[3]:SetPoint("TOPLEFT"); t[3]:SetPoint("BOTTOMLEFT"); t[3]:SetWidth(1)
  t[4]:SetPoint("TOPRIGHT"); t[4]:SetPoint("BOTTOMRIGHT"); t[4]:SetWidth(1)
  return t
end

-- Fond sombre encadré d'or (bandeaux, barres)
function K.Panel(frame, alpha)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.10, 0.07, 0.04, alpha or 0.85)
  K.Border(frame, 0.55, 0.42, 0.18, 0.9)
  return bg
end

function K.Tooltip(btn, title, text)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title, K.GOLD[1], K.GOLD[2], K.GOLD[3])
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Onglet : or sur fond sombre, souligné quand il est actif
function K.Tab(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(26)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.fs:SetPoint("CENTER", 0, 1)
  b.fs:SetText(text)
  b:SetWidth(math.max(96, (b.fs:GetStringWidth() or 80) + 28))
  b.line = b:CreateTexture(nil, "ARTWORK")
  b.line:SetPoint("BOTTOMLEFT", 4, 0)
  b.line:SetPoint("BOTTOMRIGHT", -4, 0)
  b.line:SetHeight(2)
  b.line:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
  K.Border(b, 0.55, 0.42, 0.18, 0.9)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0.3, 0.12)
  function b.SetActive(self, on)
    self.active = on
    self.bg:SetColorTexture(on and 0.32 or 0.08, on and 0.22 or 0.06, on and 0.08 or 0.04, 0.95)
    self.fs:SetTextColor(on and 1 or 0.85, on and 0.9 or 0.72, on and 0.55 or 0.4)
    self.line:SetShown(on)
  end
  function b.SetLabel(self, t)
    self.fs:SetText(t)
    self:SetWidth(math.max(96, (self.fs:GetStringWidth() or 80) + 28))
  end
  b:SetScript("OnClick", onClick)
  b:SetActive(false)
  return b
end

-- Action en icône, avec son nom dessous et une bulle d'aide
function K.Action(parent, icon, label, tip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(30, 30)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexture(icon)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  K.Border(b, 0.55, 0.42, 0.18, 1, "OVERLAY")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
  b.label:SetText(label)
  K.Tooltip(b, label, tip)
  b:SetScript("OnClick", onClick)
  return b
end

-- Titre en lettres de livre ; si le client n'a pas la police, on garde celle de l'objet
function K.TitleFont(fs, size, fontObject)
  fs:SetFontObject(fontObject or "GameFontNormal")
  local ok = fs:SetFont(K.TITLE_FONT, size, "")
  if ok == false then fs:SetFontObject(fontObject or "GameFontNormal") end
end

-- Pastille d'état, comme l'appel du chef de groupe : prêt (coche verte), à faire (point d'interrogation), manque (croix)
local STATUS_TEX = { ok = "Interface\\RaidFrame\\ReadyCheck-Ready", warn = "Interface\\RaidFrame\\ReadyCheck-Waiting",
                     bad = "Interface\\RaidFrame\\ReadyCheck-NotReady", info = "Interface\\FriendsFrame\\InformationIcon" }
K.STATUS_TEX = STATUS_TEX
function K.SetStatus(tex, status)
  tex:SetTexture(STATUS_TEX[status] or STATUS_TEX.info)
  if status == "info" then tex:SetVertexColor(0.85, 0.85, 0.85) else tex:SetVertexColor(1, 1, 1) end
end

-- Icônes de rôle (texture des rôles de la recherche de groupe) ; nil si inconnue
local ROLE_COORDS = { tank = { 0, 19 / 64, 22 / 64, 41 / 64 }, heal = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
                      melee = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 }, caster = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } }
function K.SetRole(tex, role)
  local c = ROLE_COORDS[role]
  if not c then tex:Hide(); return end
  tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
  tex:SetTexCoord(c[1], c[2], c[3], c[4])
  tex:Show()
end

-- Barre de titre : petite icône et nom en or (remplace le titre blanc du modèle) ; renvoie le texte du titre
function K.Dress(frame, icon, text)
  local logo = frame:CreateTexture(nil, "OVERLAY")
  logo:SetSize(16, 16)
  logo:SetPoint("TOPLEFT", 8, -4)
  logo:SetTexture(icon)
  logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  title:SetText(text or "")
  frame.kitLogo, frame.kitTitle = logo, title
  return title
end

-- Fond sombre encadré d'or derrière une zone existante (liste, panneau) : un cadre posé dessous, mêmes ancres
function K.Backdrop(parent, region, alpha, inset)
  local f = CreateFrame("Frame", nil, parent)
  inset = inset or 4
  f:SetPoint("TOPLEFT", region, "TOPLEFT", -inset, inset)
  f:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", inset, -inset)
  f:SetFrameLevel(math.max(0, (region:GetFrameLevel() or 1) - 1))
  K.Panel(f, alpha or 0.55)
  return f
end

-- Ligne de liste en titre de rubrique : lettres de livre et filet doré. À appeler APRÈS row.text:SetText.
-- Le titre a son propre texte (row.kitHead) : dans WoW, une police posée par SetFont l'emporte ensuite sur SetFontObject,
-- donc un texte de ligne réutilisé ne doit jamais recevoir la police des titres (lignes illisibles, 05/11/2026).
function K.StyleHeader(row, on, size)
  if not row.kitRule then
    row.kitRule = row:CreateTexture(nil, "ARTWORK")
    row.kitRule:SetPoint("BOTTOMLEFT", 0, 1)
    row.kitRule:SetPoint("BOTTOMRIGHT", 0, 1)
    row.kitRule:SetHeight(1)
    row.kitRule:SetColorTexture(0.65, 0.48, 0.16, 0.8)
  end
  if on and not row.kitHead then
    row.kitHead = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    K.TitleFont(row.kitHead, size or 15, "GameFontNormal")
    row.kitHead:SetJustifyH("LEFT")
  end
  row.kitRule:SetShown(on)
  if row.kitHead then
    row.kitHead:SetShown(on)
    if on then
      row.kitHead:ClearAllPoints()
      row.kitHead:SetAllPoints(row.text)
      row.kitHead:SetText(row.text:GetText())
    end
  end
  row.text:SetAlpha(on and 0 or 1)
end

----------------------------------------------------------------------
-- Liste de cartes (ForeverMetiers…) : bandeaux de rubrique, cartes d'objets, lignes d'information.
-- Éléments : { kind = "head", icon, crop, title, right, link, onClick }
--            { kind = "card", icon, quality, name, tags, source, gain, gainSub, link, star, onClick, onRight }
--            { kind = "info", display (ou text), boss }
----------------------------------------------------------------------
K.QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
              [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }

function K.CardList(parent, width)
  local self = { cards = {}, heads = {}, infos = {} }
  local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(width, 10)
  sf:SetScrollChild(content)
  self.scroll, self.content = sf, content
  local cu, hu, iu = 0, 0, 0

  -- infobulle : l'objet (lien), sinon le détail de la ligne (tip = { title, lines = { texte ou { texte, r, g, b } } })
  local function Tip(f)
    f:SetScript("OnEnter", function(o)
      if o.link then
        GameTooltip:SetOwner(o, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, o.link)
        GameTooltip:Show()
      elseif o.tip then
        GameTooltip:SetOwner(o, "ANCHOR_RIGHT")
        GameTooltip:SetText(o.tip.title or "", K.GOLD[1], K.GOLD[2], K.GOLD[3])
        for _, ln in ipairs(o.tip.lines or {}) do
          if type(ln) == "table" then GameTooltip:AddLine(ln[1], ln[2] or 1, ln[3] or 1, ln[4] or 1, true)
          else GameTooltip:AddLine(ln, 1, 1, 1, true) end
        end
        GameTooltip:Show()
      end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local function Card()
    cu = cu + 1
    local c = self.cards[cu]
    if not c then
      c = CreateFrame("Button", nil, content)
      c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      c.bg = c:CreateTexture(nil, "BACKGROUND")
      c.bg:SetAllPoints()
      local hl = c:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 0.82, 0.3, 0.10)
      c.bar = c:CreateTexture(nil, "ARTWORK")
      c.bar:SetPoint("TOPLEFT", 0, -3)
      c.bar:SetPoint("BOTTOMLEFT", 0, 3)
      c.bar:SetWidth(4)
      c.iconFrame = CreateFrame("Frame", nil, c)
      c.iconFrame:SetSize(34, 34)
      c.iconFrame:SetPoint("LEFT", 12, 0)
      c.icon = c.iconFrame:CreateTexture(nil, "ARTWORK")
      c.icon:SetPoint("TOPLEFT", 1, -1)
      c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
      c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      c.qborder = K.Border(c.iconFrame, 1, 1, 1, 1, "OVERLAY")
      c.star = c:CreateTexture(nil, "OVERLAY")
      c.star:SetSize(14, 14)
      c.star:SetPoint("TOPLEFT", c.iconFrame, "TOPLEFT", -5, 5)
      c.star:SetTexture("Interface\\COMMON\\FavoritesIcon")
      c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      c.name:SetPoint("TOPLEFT", c.iconFrame, "TOPRIGHT", 10, -1)
      c.name:SetJustifyH("LEFT")
      c.tags = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      c.tags:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
      c.tags:SetJustifyH("LEFT")
      c.src = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      c.src:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
      c.src:SetJustifyH("LEFT")
      c.src:SetJustifyV("TOP")
      c.src:SetTextColor(0.72, 0.66, 0.55)
      c.gain = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      c.gain:SetPoint("TOPRIGHT", -10, -6)
      c.gain:SetJustifyH("RIGHT")
      c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      c.sub:SetPoint("TOPRIGHT", c.gain, "BOTTOMRIGHT", 0, -2)
      c.sub:SetJustifyH("RIGHT")
      c.sub:SetTextColor(0.72, 0.66, 0.55)
      Tip(c)
      c:SetScript("OnClick", function(o, button)
        if o.link and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(o.link); return end
        if button == "RightButton" then if o.onRight then o.onRight() end elseif o.onClick then o.onClick() end
      end)
      self.cards[cu] = c
    end
    c:Show()
    return c
  end

  local function Head()
    hu = hu + 1
    local h = self.heads[hu]
    if not h then
      h = CreateFrame("Button", nil, content)
      h:SetHeight(28)
      h.bg = h:CreateTexture(nil, "BACKGROUND")
      h.bg:SetAllPoints()
      h.bg:SetColorTexture(0.32, 0.22, 0.08, 0.12)
      h.icon = h:CreateTexture(nil, "ARTWORK")
      h.icon:SetSize(20, 20)
      h.icon:SetPoint("LEFT", 4, 0)
      h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      h.title:SetPoint("LEFT", h.icon, "RIGHT", 8, 0)
      K.TitleFont(h.title, 15, "GameFontNormal")
      h.right = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      h.right:SetPoint("RIGHT", -10, 0)
      h.right:SetJustifyH("RIGHT")
      h.rule = h:CreateTexture(nil, "ARTWORK")
      h.rule:SetPoint("BOTTOMLEFT"); h.rule:SetPoint("BOTTOMRIGHT"); h.rule:SetHeight(1)
      h.rule:SetColorTexture(0.75, 0.56, 0.18, 0.9)
      Tip(h)
      h:SetScript("OnClick", function(o) if o.onClick then o.onClick() end end)
      self.heads[hu] = h
    end
    h:Show()
    return h
  end

  local function Info()
    iu = iu + 1
    local f = self.infos[iu]
    if not f then
      f = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      f:SetJustifyH("LEFT")
      f:SetJustifyV("TOP")
      f:SetSpacing(2)
      self.infos[iu] = f
    end
    f:ClearAllPoints()
    f:Show()
    return f
  end

  function self.Render(lines)
    for _, o in ipairs(self.cards) do o:Hide() end
    for _, o in ipairs(self.heads) do o:Hide() end
    for _, o in ipairs(self.infos) do o:Hide() end
    cu, hu, iu = 0, 0, 0
    local w = content:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = width end
    local y, stripe = -6, 0
    for _, l in ipairs(lines) do
      if l.kind == "head" then
        local h = Head()
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 0, y - 6)
        h:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        h.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if l.crop ~= false then h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) else h.icon:SetTexCoord(0, 1, 0, 1) end
        h.title:SetText(l.title or "")
        h.right:SetText(l.right or "")
        h.link, h.onClick, h.tip = l.link, l.onClick, l.tip
        y = y - 36
        stripe = 0
      elseif l.kind == "card" then
        local c = Card()
        stripe = stripe + 1
        c.bg:SetColorTexture(1, 1, 1, stripe % 2 == 0 and 0.035 or 0.0)
        c.link, c.onClick, c.onRight, c.tip = l.link, l.onClick, l.onRight, l.tip
        local q = K.QUALITY[l.quality or 1] or K.QUALITY[1]
        for _, t in ipairs(c.qborder) do t:SetColorTexture(q[1], q[2], q[3], 1) end
        c.icon:SetTexture(l.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        c.name:SetText(l.name or "?")
        if l.nameColor then c.name:SetTextColor(l.nameColor[1], l.nameColor[2], l.nameColor[3])
        else c.name:SetTextColor(q[1], q[2], q[3]) end
        c.tags:SetText(l.tags or "")
        c.gain:SetText(l.gain or "")
        c.sub:SetText(l.gainSub or "")
        local gw = c.gain:GetStringWidth()
        gw = (type(gw) == "number" and gw or 0)
        local sw = c.sub:GetStringWidth()
        gw = math.max(gw, (type(sw) == "number" and sw or 0))
        c.src:SetWidth(math.max(120, w - 74 - (gw > 0 and gw + 20 or 0)))
        c.src:SetText(l.source or "")
        -- nom et étiquettes sur une ligne, sans chevaucher le gain à droite : coupés (« … ») s'ils sont trop longs
        local room = w - 74 - (gw > 0 and gw + 24 or 0)
        local nw = c.name:GetStringWidth()
        nw = (type(nw) == "number" and nw) or 0
        if nw > room then c.name:SetWidth(math.max(60, room)); nw = room else c.name:SetWidth(0) end
        if c.name.SetWordWrap then c.name:SetWordWrap(false) end
        if c.tags.SetWordWrap then c.tags:SetWordWrap(false) end
        c.tags:SetWidth(math.max(1, room - nw - 8))
        c.tags:SetShown(room - nw - 8 > 30)
        local sh = c.src:GetStringHeight()
        sh = (type(sh) == "number" and sh > 0) and sh or 12
        local hgt = math.max(44, 22 + ((l.source and l.source ~= "") and sh or 0) + 6)
        c:SetHeight(hgt)
        c.star:SetShown(l.star and true or false)
        local bar = l.bar
        if not bar then
          local nc = l.nameColor
          if nc and nc[1] > 0.9 and nc[2] < 0.5 then bar = { 0.95, 0.3, 0.25 }
          elseif tostring(l.gain or ""):find("40d860", 1, true) or tostring(l.gain or ""):find("^|cff40") then bar = { 0.25, 0.85, 0.38 }
          else bar = { 0.85, 0.66, 0.2 } end
        end
        c.bar:SetColorTexture(bar[1], bar[2], bar[3], 0.9)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", 4, y)
        c:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        y = y - hgt - 2
      else
        local f = Info()
        f:SetFontObject(l.boss and "GameFontNormal" or "GameFontHighlightSmall")
        f:SetWidth(w - 24)
        f:SetText(l.display or l.text or "")
        f:SetPoint("TOPLEFT", l.boss and 8 or 14, y - (l.boss and 4 or 2))
        local fh = f:GetStringHeight()
        y = y - ((type(fh) == "number" and fh > 0) and fh or 12) - (l.boss and 8 or 6)
      end
    end
    content:SetHeight(-y + 10)
  end
  return self
end

-- Tuiles (un chiffre en grand, un mot dessous, une barre de couleur en haut) : écran Maintenant, Équipement, Métiers,
-- Addons, Soins. tiles = K.Tiles(parent, n, height) ; tiles.Render(defs, x, y, width) place les tuiles en rangée.
-- def = { value, label, color = {r,g,b}, tip = "texte" ou { title, lines = {…} }, onClick, icon, frac (0-1, barre
-- de progression en bas), open (ancien champ : clic -> root.Open) }. Les tuiles en trop sont masquées.
function K.Tiles(parent, n, height)
  local self = { list = {} }
  height = height or 52
  local font = (_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
  for i = 1, n do
    local t = CreateFrame("Button", nil, parent)
    t:SetHeight(height)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetColorTexture(0.12, 0.1, 0.08, 0.9)
    t.top = t:CreateTexture(nil, "ARTWORK")
    t.top:SetPoint("TOPLEFT", 1, -1)
    t.top:SetPoint("TOPRIGHT", -1, -1)
    t.top:SetHeight(3)
    t.fill = t:CreateTexture(nil, "ARTWORK")
    t.fill:SetPoint("BOTTOMLEFT", 1, 1)
    t.fill:SetHeight(3)
    K.Border(t, 0.45, 0.37, 0.24, 1, "BORDER")
    local hl = t:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.3, 0.08)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(22, 22)
    t.icon:SetPoint("LEFT", 8, 2)
    t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    t.value = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    t.value:SetFont(font, 17, "OUTLINE")
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.label:SetTextColor(0.85, 0.78, 0.6)
    if t.label.SetWordWrap then t.label:SetWordWrap(false) end
    t:SetScript("OnClick", function(o) if o.onClick then o.onClick() end end)
    t:SetScript("OnEnter", function(o)
      local tip = o.tip
      if not tip then return end
      GameTooltip:SetOwner(o, "ANCHOR_BOTTOM")
      if type(tip) == "table" then
        GameTooltip:SetText(tip.title or "", K.GOLD[1], K.GOLD[2], K.GOLD[3])
        for _, ln in ipairs(tip.lines or {}) do GameTooltip:AddLine(ln, 1, 1, 1, true) end
      else
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
      end
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t:Hide()
    self.list[i] = t
  end

  function self.Render(defs, x, y, width, gap)
    defs = defs or {}
    gap = gap or 6
    local count = math.max(1, math.min(#defs, n))
    local tw = (width - gap * (count - 1)) / count
    for i, t in ipairs(self.list) do
      local d = defs[i]
      t:SetShown(d ~= nil)
      if d then
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * (tw + gap), y)
        t:SetWidth(tw)
        local off = d.icon and 12 or 0
        t.icon:SetShown(d.icon ~= nil)
        if d.icon then t.icon:SetTexture(d.icon) end
        t.value:ClearAllPoints()
        t.value:SetPoint("TOP", off, -9)
        t.label:ClearAllPoints()
        t.label:SetPoint("BOTTOM", off, 7)
        t.label:SetWidth(tw - 8 - off)
        t.value:SetText(d.value or "")
        t.label:SetText(d.label or "")
        local c = d.color or { 0.25, 0.85, 0.38 }
        t.top:SetColorTexture(c[1], c[2], c[3], 1)
        t.fill:SetShown(d.frac ~= nil)
        if d.frac then
          t.fill:SetColorTexture(c[1], c[2], c[3], 0.6)
          t.fill:SetWidth(math.max(1, (tw - 2) * math.max(0, math.min(1, d.frac))))
        end
        t.tip, t.onClick = d.tip, d.onClick
      end
    end
  end
  function self.Hide() for _, t in ipairs(self.list) do t:Hide() end end
  function self.Shown() return self.list[1] and self.list[1]:IsShown() end
  self.tiles = self.list
  return self
end

end
