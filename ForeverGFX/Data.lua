local _, ns = ...

-- cat    = catégorie
-- desc   = description FR, en = description EN
-- range  = { min, max, pas } -> curseur (ou case à cocher si 0..1 pas 1)
-- values = libellés des valeurs -> liste déroulante
-- risky  = changement lourd : déclenche le retour auto de sécurité
-- restart = nécessite « Redémarrer graphismes »
-- Une variable listée ici n'apparaît que si elle existe dans le client.

local LEVEL4 = { [0] = { "Bas", "Low" }, [1] = { "Correct", "Fair" }, [2] = { "Bon", "Good" }, [3] = { "Élevé", "High" } }

ns.Descriptions = {
  -- Préréglage
  graphicsQuality = { cat = "Préréglage", range = { 1, 10, 1 }, risky = true,
    desc = "Préréglage global du jeu (1 à 10). Règle-le en premier, affine ensuite.",
    en = "Game's global preset (1 to 10). Set it first, then fine-tune." },

  -- Réglages du menu
  graphicsShadowQuality = { cat = "Ombres", risky = true,
    values = { [0] = { "Bas", "Low" }, [1] = { "Correct", "Fair" }, [2] = { "Bon", "Good" },
               [3] = { "Élevé", "High" }, [4] = { "Ultra", "Ultra" }, [5] = { "Ultra élevé", "Ultra High" } },
    desc = "Méthode et qualité des ombres. Le réglage le plus coûteux en GPU après l'éclairage.",
    en = "Shadow method and quality. The most GPU-hungry setting after lighting." },
  graphicsLiquidDetail = { cat = "Eau", values = LEVEL4,
    desc = "Détail de l'eau (reflets, réfraction, vagues).",
    en = "Water detail (reflections, refraction, waves)." },
  graphicsParticleDensity = { cat = "Effets", range = { 0, 5, 1 },
    desc = "Densité des particules : fumée, feu, poussière, effets d'ambiance.",
    en = "Particle density: smoke, fire, dust, ambient effects." },
  graphicsSSAO = { cat = "Éclairage", range = { 0, 4, 1 }, risky = true,
    desc = "Occlusion ambiante : assombrit les recoins et zones de contact. Gros gain de relief, coût GPU notable.",
    en = "Ambient occlusion: darkens corners and contact areas. Big depth boost, notable GPU cost." },
  graphicsDepthEffects = { cat = "Effets", range = { 0, 3, 1 },
    desc = "Effets de profondeur : flou de distance, rayons de soleil, brume.",
    en = "Depth effects: distance blur, sun shafts, haze." },
  graphicsComputeEffects = { cat = "Effets", range = { 0, 4, 1 }, risky = true,
    desc = "Effets calculés par compute shaders (brouillard volumétrique, particules avancées).",
    en = "Compute shader effects (volumetric fog, advanced particles)." },
  graphicsOutlineMode = { cat = "Interface", range = { 0, 2, 1 },
    desc = "Contour lumineux autour des unités et objets ciblés ou survolés.",
    en = "Glow outline around targeted or hovered units and objects." },
  graphicsTextureResolution = { cat = "Textures",
    values = { [0] = { "Bas", "Low" }, [1] = { "Correct", "Fair" }, [2] = { "Élevé", "High" } },
    desc = "Résolution des textures. Mets au maximum : 12 Go de VRAM suffisent largement.",
    en = "Texture resolution. Max it out: 12 GB of VRAM is plenty." },
  graphicsSpellDensity = { cat = "Effets", range = { 0, 5, 1 },
    desc = "Quantité d'effets de sorts affichés (les tiens et ceux des autres).",
    en = "Amount of spell effects shown (yours and others')." },
  graphicsProjectedTextures = { cat = "Effets", range = { 0, 1, 1 },
    desc = "Textures projetées au sol (zones de sorts, cercles de boss). À garder activé.",
    en = "Ground-projected textures (spell areas, boss circles). Keep enabled." },
  graphicsViewDistance = { cat = "Distance", range = { 0, 9, 1 },
    desc = "Distance d'affichage du monde. Coûte surtout du CPU.",
    en = "World view distance. Mostly CPU-bound." },
  graphicsEnvironmentDetail = { cat = "Distance", range = { 0, 9, 1 },
    desc = "Détail des objets du décor (arbres, rochers, bâtiments) et distance de leur niveau de détail.",
    en = "Detail of scenery objects (trees, rocks, buildings) and their level-of-detail distance." },
  graphicsGroundClutter = { cat = "Végétation", range = { 0, 9, 1 },
    desc = "Densité et distance de l'herbe et des petits objets au sol (version menu).",
    en = "Density and distance of grass and small ground objects (menu version)." },

  -- Végétation
  groundEffectDensity = { cat = "Végétation", range = { 16, 256, 16 },
    desc = "Densité de l'herbe, des fleurs et des détails au sol. 256 = maximum utile.",
    en = "Density of grass, flowers and ground details. 256 = useful maximum." },
  groundEffectDist = { cat = "Végétation", range = { 0, 500, 10 },
    desc = "Distance jusqu'à laquelle l'herbe est dessinée. Valeur courante : 140.",
    en = "Distance up to which grass is drawn. Common value: 140." },

  -- Distance
  farclip = { cat = "Distance", range = { 0, 10000, 100 },
    desc = "Distance de vue maximale. Souvent pilotée par graphicsViewDistance sur les clients récents.",
    en = "Maximum view distance. Often driven by graphicsViewDistance on recent clients." },
  horizonStart = { cat = "Distance",
    desc = "Distance à partir de laquelle le décor lointain passe en basse définition.",
    en = "Distance where far scenery switches to low detail." },
  entityLodDist = { cat = "Distance",
    desc = "Distance de bascule vers des modèles simplifiés pour personnages et créatures.",
    en = "Distance where characters and creatures switch to simplified models." },
  terrainLodDist = { cat = "Distance",
    desc = "Distance de bascule vers un terrain simplifié.",
    en = "Distance where terrain switches to a simplified mesh." },
  wmoLodDist = { cat = "Distance",
    desc = "Distance de bascule vers des bâtiments (WMO) simplifiés.",
    en = "Distance where buildings (WMO) switch to simplified models." },
  lodObjectCullSize = { cat = "Distance",
    desc = "Taille sous laquelle les petits objets lointains sont masqués. Plus bas = plus d'objets au loin.",
    en = "Size below which small distant objects are hidden. Lower = more distant objects." },

  -- Ombres
  shadowTextureSize = { cat = "Ombres", risky = true,
    desc = "Résolution des cartes d'ombres (ex. 2048, 4096). Plus haut = ombres plus nettes.",
    en = "Shadow map resolution (e.g. 2048, 4096). Higher = sharper shadows." },
  shadowMode = { cat = "Ombres",
    desc = "Méthode d'ombrage utilisée par le moteur.",
    en = "Shadowing method used by the engine." },
  shadowSoft = { cat = "Ombres", range = { 0, 1, 1 },
    desc = "Ombres adoucies (bords progressifs).",
    en = "Soft shadows (gradual edges)." },
  shadowRt = { cat = "Ombres", range = { 0, 3, 1 }, risky = true,
    desc = "Ombres en ray tracing (0 = désactivé). En bêta Forever, parfois indisponible même sur RTX.",
    en = "Ray-traced shadows (0 = off). Sometimes unavailable in the Forever beta, even on RTX." },

  -- Éclairage
  SSAO = { cat = "Éclairage",
    desc = "Réglage bas niveau de l'occlusion ambiante.",
    en = "Low-level ambient occlusion setting." },
  sunShafts = { cat = "Éclairage", range = { 0, 2, 1 },
    desc = "Rayons de soleil volumétriques à travers les feuillages et le brouillard.",
    en = "Volumetric sun shafts through foliage and fog." },
  volumeFog = { cat = "Éclairage", range = { 0, 1, 1 },
    desc = "Brouillard volumétrique.",
    en = "Volumetric fog." },
  volumeFogLevel = { cat = "Éclairage", range = { 0, 3, 1 },
    desc = "Qualité du brouillard volumétrique.",
    en = "Volumetric fog quality." },
  ffxGlow = { cat = "Éclairage", range = { 0, 1, 1 },
    desc = "Halo lumineux (bloom) autour des sources de lumière.",
    en = "Glow (bloom) around light sources." },

  -- Image
  gamma = { cat = "Image", range = { 0.3, 2.8, 0.05 },
    desc = "Gamma de l'image (1 = par défaut).",
    en = "Image gamma (1 = default)." },
  Contrast = { cat = "Image", range = { 0, 100, 1 },
    desc = "Contraste (50 = par défaut). 60 fait ressortir les brumes de Forever.",
    en = "Contrast (50 = default). 60 makes Forever's haze stand out." },
  Brightness = { cat = "Image", range = { 0, 100, 1 },
    desc = "Luminosité (50 = par défaut).",
    en = "Brightness (50 = default)." },

  -- Anti-aliasing
  renderScale = { cat = "Anti-aliasing", range = { 0.5, 2.0, 0.05 }, risky = true,
    desc = "Échelle de rendu. Au-dessus de 1 = suréchantillonnage (plus net, coûteux). Alternative : le DLDSR du pilote NVIDIA.",
    en = "Render scale. Above 1 = supersampling (sharper, costly). Alternative: NVIDIA driver DLDSR." },
  ResampleQuality = { cat = "Anti-aliasing", range = { 0, 4, 1 },
    desc = "Filtre utilisé quand renderScale n'est pas à 1 (bilinéaire, bicubique, FSR…).",
    en = "Filter used when renderScale is not 1 (bilinear, bicubic, FSR…)." },
  ResampleSharpness = { cat = "Anti-aliasing", range = { 0, 2, 0.1 },
    desc = "Netteté appliquée lors du redimensionnement de l'image.",
    en = "Sharpening applied when resampling the image." },
  MSAAQuality = { cat = "Anti-aliasing", risky = true,
    desc = "Antialiasing multiéchantillon. Valeur encodée : préfère le menu du jeu pour la régler.",
    en = "Multisample anti-aliasing. Encoded value: prefer the game menu to set it." },
  MSAAAlphaTest = { cat = "Anti-aliasing", range = { 0, 1, 1 },
    desc = "Lisse aussi les textures transparentes (feuillages, grillages).",
    en = "Also smooths transparent textures (foliage, fences)." },
  ffxAntiAliasingMode = { cat = "Anti-aliasing",
    values = { [0] = { "Aucun", "None" }, [1] = { "FXAA bas", "FXAA Low" }, [2] = { "FXAA haut", "FXAA High" },
               [3] = { "CMAA", "CMAA" }, [4] = { "CMAA2", "CMAA2" } },
    desc = "Anti-aliasing en post-traitement. CMAA2 est le meilleur.",
    en = "Post-process anti-aliasing. CMAA2 is the best." },

  -- Textures
  textureFilteringMode = { cat = "Textures",
    values = { [0] = { "Bilinéaire", "Bilinear" }, [1] = { "Trilinéaire", "Trilinear" },
               [2] = { "Anisotrope 2x", "Anisotropic 2x" }, [3] = { "Anisotrope 4x", "Anisotropic 4x" },
               [4] = { "Anisotrope 8x", "Anisotropic 8x" }, [5] = { "Anisotrope 16x", "Anisotropic 16x" } },
    desc = "Filtrage des textures vues en biais. Coût quasi nul sur une carte récente : mets 16x.",
    en = "Filtering of textures seen at an angle. Nearly free on a modern GPU: use 16x." },
  worldBaseMip = { cat = "Textures", range = { 0, 2, 1 },
    desc = "Niveau de détail de base des textures du monde (0 = pleine résolution).",
    en = "Base detail level of world textures (0 = full resolution)." },
  componentTextureLevel = { cat = "Textures",
    desc = "Qualité des textures composées des personnages (armures, tenues).",
    en = "Quality of composited character textures (armor, outfits)." },

  -- Eau
  waterDetail = { cat = "Eau", range = { 0, 3, 1 },
    desc = "Détail de l'eau, réglage bas niveau.",
    en = "Water detail, low-level setting." },
  rippleDetail = { cat = "Eau", range = { 0, 2, 1 },
    desc = "Ondulations à la surface de l'eau.",
    en = "Ripples on the water surface." },
  reflectionMode = { cat = "Eau", range = { 0, 3, 1 },
    desc = "Ce qui se reflète dans l'eau (du ciel seul jusqu'au décor complet).",
    en = "What water reflects (from sky only to full scenery)." },

  -- Effets
  particleDensity = { cat = "Effets",
    desc = "Densité des particules, réglage bas niveau.",
    en = "Particle density, low-level setting." },
  weatherDensity = { cat = "Effets", range = { 0, 3, 1 },
    desc = "Intensité de la météo (pluie, neige, tempêtes de sable).",
    en = "Weather intensity (rain, snow, sandstorms)." },
  projectedTextures = { cat = "Effets", range = { 0, 1, 1 },
    desc = "Textures projetées au sol, réglage bas niveau.",
    en = "Ground-projected textures, low-level setting." },
  spellClutter = { cat = "Effets",
    desc = "Masque des effets de sorts quand il y en a trop à l'écran (-1 = automatique).",
    en = "Hides spell effects when too many are on screen (-1 = automatic)." },
  physicsLevel = { cat = "Effets", range = { 0, 2, 1 },
    desc = "Physique des capes, cheveux et tissus.",
    en = "Physics for capes, hair and cloth." },

  -- Performances
  maxFPS = { cat = "Performances", range = { 0, 500, 5 },
    desc = "Limite d'images par seconde (0 = illimité). Une limite stable est plus fluide qu'un FPS qui yo-yote.",
    en = "Frame rate cap (0 = unlimited). A steady cap feels smoother than a bouncing frame rate." },
  maxFPSBk = { cat = "Performances", range = { 0, 200, 5 },
    desc = "Limite d'images par seconde quand le jeu est en arrière-plan.",
    en = "Frame rate cap while the game is in the background." },
  targetFPS = { cat = "Performances", range = { 0, 240, 5 },
    desc = "FPS cible : le jeu baisse la qualité dynamiquement pour l'atteindre (si useTargetFPS = 1).",
    en = "Target FPS: the game lowers quality dynamically to reach it (if useTargetFPS = 1)." },
  useTargetFPS = { cat = "Performances", range = { 0, 1, 1 },
    desc = "Ajustement dynamique pour viser targetFPS. À laisser désactivé pour une qualité constante.",
    en = "Dynamic adjustment toward targetFPS. Leave off for constant quality." },
  vsync = { cat = "Performances", range = { 0, 1, 1 },
    desc = "Synchronisation verticale. Avec un écran G-Sync, préfère désactivé + limite de FPS sous la fréquence de l'écran.",
    en = "Vertical sync. With a G-Sync monitor, prefer off + a FPS cap just below the refresh rate." },
  LowLatencyMode = { cat = "Performances",
    values = { [0] = { "Désactivé", "None" }, [1] = { "Intégré", "Built-in" },
               [2] = { "NVIDIA Reflex", "NVIDIA Reflex" }, [3] = { "Reflex + Boost", "Reflex + Boost" } },
    desc = "Mode faible latence. Sur RTX, NVIDIA Reflex réduit le délai entre ta souris et l'écran.",
    en = "Low latency mode. On RTX, NVIDIA Reflex reduces mouse-to-screen delay." },
  gxApi = { cat = "Performances", restart = true,
    desc = "API graphique (D3D12, D3D11…). Garde D3D12. Nécessite un redémarrage graphique.",
    en = "Graphics API (D3D12, D3D11…). Keep D3D12. Requires a graphics restart." },
}

-- Préréglages intégrés, appliqués dans l'ordre (graphicsQuality d'abord).
local function Menu(q, tex, shadow, liquid, particle, ssao, depth, compute, spell, view, env, clutter)
  return {
    { "graphicsQuality", q },
    { "graphicsTextureResolution", tex },
    { "graphicsShadowQuality", shadow },
    { "graphicsLiquidDetail", liquid },
    { "graphicsParticleDensity", particle },
    { "graphicsSSAO", ssao },
    { "graphicsDepthEffects", depth },
    { "graphicsComputeEffects", compute },
    { "graphicsSpellDensity", spell },
    { "graphicsProjectedTextures", 1 },
    { "graphicsViewDistance", view },
    { "graphicsEnvironmentDetail", env },
    { "graphicsGroundClutter", clutter },
  }
end

local function With(base, extra)
  local t = {}
  for _, v in ipairs(base) do t[#t + 1] = v end
  for _, v in ipairs(extra) do t[#t + 1] = v end
  return t
end

local ULTRA = Menu(10, 2, 5, 3, 5, 4, 3, 4, 5, 9, 9, 9)

ns.Presets = {
  { key = "perf", label = "Performance", label_en = "Performance",
    desc = "Fluidité avant tout : ombres et effets réduits, textures restées hautes.",
    desc_en = "Smoothness first: reduced shadows and effects, textures kept high.",
    values = With(Menu(3, 2, 1, 1, 2, 0, 0, 1, 3, 4, 4, 3), {
      { "textureFilteringMode", 4 }, { "ffxAntiAliasingMode", 2 },
      { "groundEffectDensity", 64 }, { "renderScale", 1 } }) },

  { key = "equilibre", label = "Équilibré", label_en = "Balanced",
    desc = "Bon compromis : éclairage et ombres moyens, distance de vue correcte.",
    desc_en = "Good compromise: medium lighting and shadows, decent view distance.",
    values = With(Menu(6, 2, 3, 2, 3, 2, 1, 2, 4, 6, 6, 6), {
      { "textureFilteringMode", 5 }, { "ffxAntiAliasingMode", 4 }, { "MSAAAlphaTest", 1 },
      { "groundEffectDensity", 128 }, { "renderScale", 1 } }) },

  { key = "qualite", label = "Qualité", label_en = "Quality",
    desc = "Très beau sans tout pousser au maximum : la bonne base pour une RTX 4070 Super.",
    desc_en = "Very pretty without maxing everything: a good base for an RTX 4070 Super.",
    values = With(Menu(8, 2, 4, 3, 4, 3, 2, 3, 5, 8, 8, 8), {
      { "textureFilteringMode", 5 }, { "ffxAntiAliasingMode", 4 }, { "MSAAAlphaTest", 1 },
      { "groundEffectDensity", 192 }, { "groundEffectDist", 100 }, { "renderScale", 1 } }) },

  { key = "ultra", label = "Ultra", label_en = "Ultra",
    desc = "Tout au maximum, herbe dense comprise. Si ça saccade en ville, baisse d'abord l'éclairage et les ombres.",
    desc_en = "Everything maxed, dense grass included. If cities stutter, lower lighting and shadows first.",
    values = With(ULTRA, {
      { "textureFilteringMode", 5 }, { "ffxAntiAliasingMode", 4 }, { "MSAAAlphaTest", 1 },
      { "groundEffectDensity", 256 }, { "groundEffectDist", 140 }, { "renderScale", 1 } }) },

  { key = "ultraplus", label = "Ultra + SSAA", label_en = "Ultra + SSAA",
    desc = "Ultra avec rendu interne à 150 % : image très nette, très coûteux. Pour du 1080p ou 1440p.",
    desc_en = "Ultra with 150% internal rendering: very sharp, very costly. For 1080p or 1440p.",
    values = With(ULTRA, {
      { "textureFilteringMode", 5 }, { "ffxAntiAliasingMode", 4 }, { "MSAAAlphaTest", 1 },
      { "groundEffectDensity", 256 }, { "groundEffectDist", 140 }, { "renderScale", 1.5 } }) },

  { key = "raid", label = "Raid / ville", label_en = "Raid / city",
    desc = "Pour les foules : beau décor, mais ombres, effets de sorts et herbe allégés pour un FPS stable.",
    desc_en = "For crowds: nice scenery, but lighter shadows, spell effects and grass for steady FPS.",
    values = With(Menu(7, 2, 3, 2, 3, 2, 1, 2, 3, 6, 7, 4), {
      { "textureFilteringMode", 5 }, { "ffxAntiAliasingMode", 4 }, { "MSAAAlphaTest", 1 },
      { "groundEffectDensity", 64 }, { "renderScale", 1 } }) },
}
