local _, ns = ...

-- {S} = sort principal, {S2} = sort alternatif (remplacés par les cases du constructeur)
ns.Templates = {
  { label = "Séquence (totems, rotation sur GCD)", label_en = "Sequence (totems, GCD rotation)", mode = "seq", delay = 15,
    desc = "Bascule en mode séquence : un appui = un sort. Remise à zéro après 15 s ou hors combat.",
    desc_en = "Switches to sequence mode: one press = one spell. Resets after 15 s or out of combat.",
    body = "" },
  { label = "Soin / buff au survol", label_en = "Mouseover heal / buff",
    desc = "Lance sur l'allié survolé (cadres de groupe ou monde), sinon sur ta cible.",
    desc_en = "Casts on the hovered ally (party frames or world), otherwise on your target.",
    body = "#showtooltip\n/cast [@mouseover,help,nodead][] {S}" },
  { label = "Dégâts au survol", label_en = "Mouseover damage",
    desc = "Lance sur l'ennemi survolé sans changer de cible.",
    desc_en = "Casts on the hovered enemy without switching target.",
    body = "#showtooltip\n/cast [@mouseover,harm,nodead][] {S}" },
  { label = "Interruption sur focus", label_en = "Focus interrupt",
    desc = "Coupe ton incantation et interrompt ton focus, sinon ta cible.",
    desc_en = "Stops your cast and interrupts your focus, otherwise your target.",
    body = "#showtooltip\n/stopcasting\n/cast [@focus,harm,nodead][] {S}" },
  { label = "Sort au sol sous le curseur", label_en = "Ground spell at cursor",
    desc = "Pose le sort directement sous la souris, sans cercle de ciblage.",
    desc_en = "Drops the spell right under the mouse, no targeting circle.",
    body = "#showtooltip\n/cast [@cursor] {S}" },
  { label = "Sort sur soi", label_en = "Self cast",
    desc = "Lance toujours sur toi, quelle que soit ta cible.",
    desc_en = "Always casts on yourself, whatever your target.",
    body = "#showtooltip\n/cast [@player] {S}" },
  { label = "Résurrection au survol", label_en = "Mouseover resurrection",
    desc = "Ressuscite l'allié mort survolé, sinon ta cible.",
    desc_en = "Resurrects the hovered dead ally, otherwise your target.",
    body = "#showtooltip\n/cast [@mouseover,help,dead][] {S}" },
  { label = "Bijoux + gros CD", label_en = "Trinkets + big cooldown",
    desc = "Active tes deux bijoux en même temps que ton sort de burst.",
    desc_en = "Uses both trinkets together with your burst spell.",
    body = "#showtooltip {S}\n/use 13\n/use 14\n/cast {S}" },
  { label = "Attaque auto + sort", label_en = "Auto attack + spell",
    desc = "Lance l'attaque automatique en même temps que le sort.",
    desc_en = "Starts auto attack together with the spell.",
    body = "#showtooltip\n/startattack\n/cast {S}" },
  { label = "Deux sorts sur une touche (Maj)", label_en = "Two spells on one key (Shift)",
    desc = "Sort alternatif en maintenant Maj, sort principal sinon.",
    desc_en = "Alternate spell while holding Shift, main spell otherwise.",
    body = "#showtooltip\n/cast [mod:shift] {S2}; {S}" },
  { label = "Descendre de monture + sort", label_en = "Dismount + spell",
    desc = "Descend de monture si besoin puis lance le sort.",
    desc_en = "Dismounts if needed, then casts the spell.",
    body = "#showtooltip\n/dismount [mounted]\n/cast {S}" },
  { label = "Définir le focus au survol", label_en = "Set focus on mouseover",
    desc = "Met l'unité survolée en focus, sinon ta cible.",
    desc_en = "Sets the hovered unit as focus, otherwise your target.",
    body = "/focus [@mouseover,exists][]" },
  { label = "Familier : attaquer le survol", label_en = "Pet: attack mouseover",
    desc = "Envoie ton familier sur l'ennemi survolé, sinon sur ta cible.",
    desc_en = "Sends your pet at the hovered enemy, otherwise your target.",
    body = "/petattack [@mouseover,harm,nodead][]" },
}

-- Cibles du constructeur
ns.Targets = {
  { key = "t_target", cond = nil },
  { key = "t_mo_help", cond = "@mouseover,help,nodead" },
  { key = "t_mo_harm", cond = "@mouseover,harm,nodead" },
  { key = "t_cursor", cond = "@cursor", noFallback = true },
  { key = "t_focus_harm", cond = "@focus,harm,nodead" },
  { key = "t_focus_help", cond = "@focus,help,nodead" },
  { key = "t_player", cond = "@player", noFallback = true },
}

local function Set(list)
  local t = {}
  for _, v in ipairs(list) do t[v] = true end
  return t
end

ns.KnownCommands = Set({
  "/cast", "/use", "/castsequence", "/castrandom", "/userandom", "/stopcasting", "/stopattack",
  "/startattack", "/stopmacro", "/target", "/tar", "/targetenemy", "/targetfriend", "/targetlasttarget",
  "/targetexact", "/targetparty", "/targetraid", "/cleartarget", "/focus", "/clearfocus", "/assist",
  "/petattack", "/petfollow", "/petpassive", "/petdefensive", "/petassist", "/petstay", "/petmoveto",
  "/petautocaston", "/petautocastoff", "/petautocasttoggle", "/cancelaura", "/cancelform",
  "/dismount", "/equip", "/equipslot", "/equipset", "/click", "/run", "/script", "/console",
  "/say", "/s", "/yell", "/y", "/party", "/p", "/raid", "/ra", "/rw", "/raidwarning", "/instance",
  "/i", "/guild", "/g", "/officer", "/o", "/emote", "/e", "/me", "/whisper", "/w", "/tell", "/t",
  "/reply", "/r", "/targetmarker", "/tm", "/worldmarker", "/wm", "/clearworldmarker", "/cwm",
  "/readycheck", "/roll", "/random", "/rnd", "/sit", "/stand", "/follow", "/f", "/invite",
  "/leavevehicle", "/summonpet", "/randompet", "/randomfavoritepet", "/dismisspet", "/use",
  "/startattack", "/swapactionbar", "/changeactionbar", "/stopspelltarget", "/cancelqueuedspell",
})


ns.KnownConditions = Set({
  "target", "mod", "modifier", "harm", "help", "exists", "dead", "combat", "mounted", "flying",
  "flyable", "advflyable", "stealth", "form", "stance", "indoors", "outdoors", "swimming", "group",
  "pet", "channeling", "btn", "button", "spec", "talent", "known", "equipped", "worn", "vehicleui",
  "unithasvehicleui", "canexitvehicle", "petbattle", "extrabar", "overridebar", "possessbar",
  "shapeshift", "bonusbar", "actionbar", "bar", "resting", "pvptalent", "cursor", "party", "raid",
  "bonus",
})

-- Unités reconnues (motifs Lua)
ns.UnitPatterns = {
  "^player$", "^target$", "^focus$", "^mouseover$", "^cursor$", "^pet$", "^none$", "^vehicle$",
  "^party[1-4]$", "^raid%d+$", "^arena[1-5]$", "^boss[1-8]$", "^partypet[1-4]$", "^raidpet%d+$",
  "^%a+target$", "^%a+%dtarget$", "^npc$", "^anchor$",
}
