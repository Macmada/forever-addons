local ADDON, root = ...

-- ForeverBiS : la partie Équipement de ForeverCompagnon seule (BiS par spé : prêtre soigneur ; paladin Sacré,
-- Protection, Vindicte, « Shockadin »), pour qui ne veut que ça. Construit par tools/build-bis.sh depuis les mêmes
-- fichiers que ForeverCompagnon : ne pas modifier ici. Ouvrir : /bis (ou /floot), l'icône de la minicarte, ou le menu
-- des addons du jeu.

-- Socle normalement installé par la fenêtre de ForeverCompagnon (Window.lua, absente ici) : diagnostic et composants
-- sur l'espace commun (root.Clear sert au relevé des marchands de Store.lua, root.Kit aux fenêtres communes)
if not root.Clear then root.Shared.Diag(ADDON, root) end
if not root.Kit then root.Shared.Widgets(ADDON, root) end

local loot = root.mods.ForeverLoot
local FR = GetLocale() == "frFR"
-- titre de la fenêtre et des messages
rawset(loot.L, "title", FR and "ForeverBiS — équipement par spé" or "ForeverBiS — gear by spec")
rawset(root.L, "title", "ForeverBiS")

function ForeverBiS_OnCompartmentClick() loot.Toggle() end

-- Icône ronde au bord de la minicarte : clic = fenêtre, glisser = déplacer (angle retenu dans ForeverLootDB)
local function MinimapButton()
  if not (Minimap and CreateFrame) or _G.ForeverBiSMinimapButton then return end
  local db = loot.db or {}
  db.minimap = db.minimap or { angle = 250 }
  local b = CreateFrame("Button", "ForeverBiSMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Chest_Plate16")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  local function Place()
    local a = math.rad(db.minimap.angle or 250)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
  end
  Place()
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", function() loot.Toggle() end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ForeverBiS")
    GameTooltip:AddLine(FR and "Clic : équipement par spé (/bis)" or "Click: gear by spec (/bis)", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

root.OnLogin(function() pcall(MinimapButton) end)
