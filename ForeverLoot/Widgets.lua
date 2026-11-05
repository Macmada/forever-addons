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

-- Ligne de liste en titre de rubrique : lettres de livre et filet doré (row.text, row.kitRule créé au besoin)
function K.StyleHeader(row, on, size)
  if not row.kitRule then
    row.kitRule = row:CreateTexture(nil, "ARTWORK")
    row.kitRule:SetPoint("BOTTOMLEFT", 0, 1)
    row.kitRule:SetPoint("BOTTOMRIGHT", 0, 1)
    row.kitRule:SetHeight(1)
    row.kitRule:SetColorTexture(0.65, 0.48, 0.16, 0.8)
  end
  row.kitRule:SetShown(on)
  if on then K.TitleFont(row.text, size or 15, "GameFontNormal") end
end
