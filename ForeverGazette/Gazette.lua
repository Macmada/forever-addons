local _, ns = ...

-- Mise en page : une journée (ou une semaine) d'événements -> liste de blocs { kind, text, link }.
-- kinds : masthead, edition, headline, lede, photo, section, line, item, stats, note.
-- Les mêmes blocs servent à l'affichage en jeu, à l'export (Markdown / texte) et au partage dans la discussion.

local MONTHS = {
  fr = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" },
  en = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" },
}
local WEEKDAYS = {   -- date("*t").wday : 1 = dimanche
  fr = { "dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi" },
  en = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" },
}
local SECTION_LIMIT = 8

local function Lang() return (ns.lang == "en") and "en" or "fr" end
local function T() return ns.Templates[Lang()] end
local function Tone() return T()[ns.db and ns.db.tone or "serious"] or T().serious end

local function DayTime(key)
  local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
  return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end
ns.DayTime = DayTime

function ns.FormatDate(key, short)
  local t = date("*t", DayTime(key))
  local lang = Lang()
  if short then
    local wd = WEEKDAYS[lang][t.wday]
    return (lang == "fr") and string.format("%s %d", wd:sub(1, 3) .. ".", t.day)
                           or string.format("%s %d", wd:sub(1, 3) .. ".", t.day)
  end
  if lang == "fr" then
    return string.format("%s %d %s %d", WEEKDAYS.fr[t.wday], t.day, MONTHS.fr[t.month], t.year)
  end
  return string.format("%s, %s %d, %d", WEEKDAYS.en[t.wday], MONTHS.en[t.month], t.day, t.year)
end

function ns.FormatPlaytime(sec)
  sec = math.floor((sec or 0) / 60)
  local h, m = math.floor(sec / 60), sec % 60
  if h > 0 then return string.format("%d h %02d", h, m) end
  return string.format("%d min", m)
end

function ns.FormatGold(copper)
  copper = math.floor(copper or 0)
  local g, s = math.floor(copper / 10000), math.floor(copper / 100) % 100
  local fr = Lang() == "fr"
  if g > 0 then
    if s > 0 then return string.format(fr and "%d po %d pa" or "%dg %ds", g, s) end
    return string.format(fr and "%d po" or "%dg", g)
  end
  local c = copper % 100
  if s > 0 then return string.format(fr and "%d pa %d pc" or "%ds %dc", s, c) end
  return string.format(fr and "%d pc" or "%dc", c)
end

----------------------------------------------------------------------
-- Remplissage des modèles
----------------------------------------------------------------------
local function Pick(list, seed)
  if type(list) ~= "table" or #list == 0 then return nil end
  return list[(math.floor(seed or 0) % #list) + 1]
end

-- Contractions françaises après remplissage : « à Les Mortemines » -> « aux Mortemines », « de Le » -> « du »…
local CONTRACT = { { "([%s'’])à Les ", "%1aux " }, { "([%s'’])à Le ", "%1au " }, { "([%s'’])de Les ", "%1des " },
                   { "([%s'’])de Le ", "%1du " }, { "([%s'’])en Les ", "%1aux " }, { "([%s'’])en Le ", "%1au " }, { "^À Les ", "Aux " }, { "^À Le ", "Au " } }

local function Fill(tpl, vars)
  local s = tpl:gsub("{(%w+)}", function(k)
    local v = vars[k]
    if v == nil then return "" end
    return tostring(v)
  end)
  if Lang() == "fr" then
    s = " " .. s
    for _, c in ipairs(CONTRACT) do s = s:gsub(c[1], c[2]) end
    s = s:sub(2)
  end
  return s
end
ns.Fill = Fill

local function KillerText(k)
  local t = T()
  if not k or k == "@unknown" then return t.unknownKiller end
  local key = k:match("^@(%w+)$")
  if key then return t[key] or t.unknownKiller end
  return k
end

local function Vars(ev, d)
  local v = {}
  for k, x in pairs(ev.v or {}) do v[k] = x end
  v.name = (ns.playerName and ns.playerName()) or UnitName("player")
  v.e = (Lang() == "fr" and UnitSex and UnitSex("player") == 3) and "e" or ""
  v.plevel = (d and d.stats and d.stats.level) or UnitLevel("player")
  v.playtime = d and ns.FormatPlaytime(d.stats.play) or ""
  if ev.k == "death" then v.killer = KillerText(v.killer) end
  if v.gold then v.gold = ns.FormatGold(v.gold) end
  return v
end

local function Template(kind, which)
  local tone = Tone()
  local e = tone[kind] or T().serious[kind]
  if not e then return nil end
  return e[which] or e.line or e.head
end

function ns.Headline(ev, d)
  return Fill(Pick(Template(ev.k, "head"), ev.t) or ev.k, Vars(ev, d))
end

local function Line(ev, d)
  return Fill(Pick(Template(ev.k, "line"), ev.t + 1) or ev.k, Vars(ev, d))
end

----------------------------------------------------------------------
-- Événements de la journée (avec le « carnet mondain » calculé)
----------------------------------------------------------------------
local function Companions(d)
  local list = d.stats and d.stats.companions or {}
  if #list == 0 then return nil end
  local shown = {}
  for i = 1, math.min(#list, 5) do shown[i] = list[i] end
  local names = table.concat(shown, ", ")
  if #list > 5 then names = names .. string.format(" (+%d)", #list - 5) end
  return { t = 0, k = "companions", v = { names = names }, s = 10 }
end

local function Events(d)
  local out = {}
  for _, e in ipairs(d.events or {}) do out[#out + 1] = e end
  local c = Companions(d)
  if c then out[#out + 1] = c end
  return out
end

local function Top(events)
  local best
  for _, e in ipairs(events) do
    if not best or e.s > best.s or (e.s == best.s and e.t < best.t) then best = e end
  end
  return best
end

function ns.EditionNumber(key)
  local keys = {}
  for k, d in pairs(ns.db.days) do
    if #(d.events or {}) > 0 or (d.stats and d.stats.play or 0) >= 300 then keys[#keys + 1] = k end
  end
  table.sort(keys)
  for i, k in ipairs(keys) do if k == key then return i end end
  return #keys + 1
end

function ns.EditionKeys()
  local keys = {}
  for k, d in pairs(ns.db.days) do
    if #(d.events or {}) > 0 or (d.stats and d.stats.play or 0) >= 300 then keys[#keys + 1] = k end
  end
  table.sort(keys)
  return keys
end

-- Gros titre d'une journée (sommaire, partage)
function ns.DayHeadline(key, d)
  d = d or ns.db.days[key]
  if not d then return nil end
  local top = Top(Events(d))
  if top and top.s >= 10 then return ns.Headline(top, d), top end
  return Fill(Pick(Tone().quiet.head, DayTime(key)), { name = UnitName("player") }), nil
end

----------------------------------------------------------------------
-- Construction de l'édition
----------------------------------------------------------------------
local function StatsBlocks(blocks, st, title)
  local t = T().stats
  local function add(tpl, vars) blocks[#blocks + 1] = { kind = "stats", text = Fill(tpl, vars) } end
  blocks[#blocks + 1] = { kind = "section", text = title }
  if st.days then add(t.days, { count = st.days }) end
  add(t.playtime, { playtime = ns.FormatPlaytime(st.play) })
  if (st.xp or 0) > 0 then add(t.xp, { count = st.xp }) end
  if (st.quests or 0) > 0 then add(t.quests, { count = st.quests }) end
  if (st.kills or 0) > 0 then add(t.kills, { count = st.kills }) end
  add(t.deaths, { count = st.deaths or 0 })
  if (st.earned or 0) > 0 then add(t.earned, { gold = ns.FormatGold(st.earned) }) end
  if (st.spent or 0) > 0 then add(t.spent, { gold = ns.FormatGold(st.spent) }) end
  local nz = 0
  for _ in pairs(st.zones or {}) do nz = nz + 1 end
  if nz > 0 then add(t.zones, { count = nz }) end
  if st.level then add(t.level, { level = st.level }) end
end

-- key : date de l'édition ; d : données (par défaut db.days[key]) ; number : numéro forcé (démo)
function ns.BuildEdition(key, d, number)
  d = d or ns.db.days[key]
  if not d then return nil end
  local t, tone = T(), Tone()
  local name = UnitName("player")
  local blocks = {}
  local events = Events(d)
  local top = Top(events)
  if top and top.s < 10 then top = nil end

  blocks[#blocks + 1] = { kind = "masthead", text = Fill(t.masthead[ns.db.tone] or t.masthead.serious, { name = name }) }
  blocks[#blocks + 1] = { kind = "edition", text = Fill(t.edition, { count = number or ns.EditionNumber(key), date = ns.FormatDate(key) }) }
  if top then
    blocks[#blocks + 1] = { kind = "headline", text = ns.Headline(top, d), link = top.v and top.v.item }
  else
    blocks[#blocks + 1] = { kind = "headline", text = Fill(Pick(tone.quiet.head, DayTime(key)), { name = name }) }
  end
  blocks[#blocks + 1] = { kind = "lede", text = Fill(Pick(tone.lede, DayTime(key)), Vars({ t = 0, v = {} }, d)) }
  local shot = (top and top.shot)
  if not shot then
    for _, e in ipairs(d.events or {}) do if e.shot then shot = e.shot break end end
  end
  if shot then blocks[#blocks + 1] = { kind = "photo", text = Fill(t.photo, { item = shot }), file = shot } end

  -- rubriques
  local bySection = {}
  for _, e in ipairs(events) do
    if e ~= top then
      local s = ns.SECTION_OF[e.k] or "exploits"
      bySection[s] = bySection[s] or {}
      table.insert(bySection[s], e)
    end
  end
  for _, s in ipairs(ns.SECTION_ORDER) do
    local list = bySection[s]
    if list and #list > 0 then
      if s ~= "quests" then table.sort(list, function(a, b) if a.s ~= b.s then return a.s > b.s end return a.t < b.t end)
      else table.sort(list, function(a, b) return a.t < b.t end) end
      blocks[#blocks + 1] = { kind = "section", text = t.sections[s] }
      local limit = (s == "quests") and 5 or SECTION_LIMIT
      for i = 1, math.min(#list, limit) do
        local e = list[i]
        blocks[#blocks + 1] = { kind = (e.v and e.v.item) and "item" or "line", text = Line(e, d), link = e.v and e.v.item }
      end
      if #list > limit then blocks[#blocks + 1] = { kind = "note", text = Fill(t.questsMore, { count = #list - limit }) } end
    end
  end
  StatsBlocks(blocks, d.stats or {}, t.sections.stats)
  return blocks, top
end

----------------------------------------------------------------------
-- L'Hebdo : 7 jours se terminant le jour « key »
----------------------------------------------------------------------
function ns.WeekKeys(key)
  local base = DayTime(key)
  local keys = {}
  for i = 6, 0, -1 do keys[#keys + 1] = date("%Y-%m-%d", base - i * 86400) end
  return keys
end

function ns.BuildWeekly(key)
  local t = T()
  local name = UnitName("player")
  local keys = ns.WeekKeys(key)
  local all, total = {}, { play = 0, xp = 0, quests = 0, kills = 0, deaths = 0, earned = 0, spent = 0, zones = {}, days = 0 }
  for _, k in ipairs(keys) do
    local d = ns.db.days[k]
    if d then
      local st = d.stats or {}
      if (st.play or 0) > 0 or #(d.events or {}) > 0 then total.days = total.days + 1 end
      for _, f in ipairs({ "play", "xp", "quests", "kills", "deaths", "earned", "spent" }) do total[f] = total[f] + (st[f] or 0) end
      for z in pairs(st.zones or {}) do total.zones[z] = true end
      total.level = st.level or total.level
      for _, e in ipairs(Events(d)) do all[#all + 1] = { e = e, d = d, key = k } end
    end
  end
  if total.days == 0 then return nil end
  table.sort(all, function(a, b) if a.e.s ~= b.e.s then return a.e.s > b.e.s end return a.e.t < b.e.t end)
  local blocks = {}
  blocks[#blocks + 1] = { kind = "masthead", text = Fill(t.weeklyMasthead[ns.db.tone] or t.weeklyMasthead.serious, { name = name }) }
  blocks[#blocks + 1] = { kind = "edition", text = Fill(t.weeklyRange, { from = ns.FormatDate(keys[1]), to = ns.FormatDate(keys[7]) }) }
  if all[1] then
    blocks[#blocks + 1] = { kind = "headline", text = ns.Headline(all[1].e, all[1].d), link = all[1].e.v and all[1].e.v.item }
  end
  blocks[#blocks + 1] = { kind = "section", text = t.sections.weeklyTop }
  local n = 0
  for i = 2, #all do
    local x = all[i]
    if x.e.s >= 15 and n < 10 then
      n = n + 1
      blocks[#blocks + 1] = { kind = (x.e.v and x.e.v.item) and "item" or "line",
                              text = ns.FormatDate(x.key, true) .. " — " .. ns.Headline(x.e, x.d), link = x.e.v and x.e.v.item }
    end
  end
  StatsBlocks(blocks, total, t.sections.weeklyStats)
  return blocks
end

----------------------------------------------------------------------
-- Conversions texte
----------------------------------------------------------------------
-- Retire couleurs et liens (« |cff..|Hitem:..|h[Nom]|h|r » -> « [Nom] »)
function ns.StripCodes(s)
  s = s:gsub("|c[^|]*|H.-|h(.-)|h|r", "%1")
  s = s:gsub("|H.-|h(.-)|h", "%1")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
  return s
end

-- Majuscules qui gèrent les lettres accentuées (string.upper ne touche pas aux octets UTF-8)
local ACCENTS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë", ["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["ç"] = "Ç",
                  ["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ö"] = "Ö", ["û"] = "Û", ["ù"] = "Ù", ["ü"] = "Ü", ["ÿ"] = "Ÿ", ["œ"] = "Œ", ["æ"] = "Æ" }
function ns.Upper(s)
  s = s:upper()
  for lower, upper in pairs(ACCENTS) do s = s:gsub(lower, upper) end
  return s
end

function ns.ToText(blocks, fmt)
  local md = fmt == "md"
  local out = {}
  local function add(s) out[#out + 1] = s end
  for _, b in ipairs(blocks) do
    local text = ns.StripCodes(b.text)
    if b.kind == "masthead" then add(md and ("# " .. ns.Upper(text)) or ns.Upper(text))
    elseif b.kind == "edition" then add(md and ("*" .. text .. "*") or text); add("")
    elseif b.kind == "headline" then add(md and ("## " .. text) or ("== " .. text .. " =="))
    elseif b.kind == "lede" then add(md and ("> " .. text) or text); add("")
    elseif b.kind == "photo" then add(md and ("📷 " .. text) or text); add("")
    elseif b.kind == "section" then
      if #out > 0 and out[#out] ~= "" then add("") end
      add(md and ("### " .. text) or ("-- " .. text .. " --"))
    elseif b.kind == "line" or b.kind == "item" or b.kind == "stats" then add("• " .. text)
    elseif b.kind == "note" then add(md and ("_" .. text .. "_") or text)
    end
  end
  return table.concat(out, "\n")
end

-- Coupe une chaîne à n octets sans casser un caractère UTF-8
local function Cut(s, n)
  if #s <= n then return s end
  local i = n
  while i > 0 do
    local b = s:byte(i + 1)
    if not b or b < 0x80 or b >= 0xC0 then break end
    i = i - 1
  end
  return s:sub(1, i - 1) .. "…"
end
ns.Cut = Cut

-- Lignes pour le canal de discussion : sans couleurs (sauf liens d'objets), 255 octets au plus.
function ns.ChatLines(blocks, max)
  local lines = {}
  local mast, head
  for _, b in ipairs(blocks) do
    if b.kind == "masthead" then mast = ns.StripCodes(b.text)
    elseif b.kind == "headline" then head = b end
  end
  local function clean(b)
    local s = b.text
    local link = b.link
    if link then s = s:gsub("|c[^|]*|H.-|h.-|h|r", "\0") end
    s = ns.StripCodes(s)
    if link then s = s:gsub("%z", function() return link end) end
    return s
  end
  if mast then lines[#lines + 1] = Cut("[" .. mast .. "]", 250) end
  if head then lines[#lines + 1] = clean(head) end
  for _, b in ipairs(blocks) do
    if #lines >= (max or 8) then break end
    if b.kind == "line" or b.kind == "item" then lines[#lines + 1] = "• " .. clean(b) end
  end
  for i, l in ipairs(lines) do
    if #l > 255 then lines[i] = (l:find("|H")) and Cut(ns.StripCodes(l), 250) or Cut(l, 250) end
  end
  return lines
end

----------------------------------------------------------------------
-- Exports pour le compagnon Discord (lus dans le fichier SavedVariables à la déconnexion)
----------------------------------------------------------------------
function ns.WriteExports()
  local db = ns.db
  if not db then return end
  local ex = { name = UnitName("player"), realm = GetRealmName and GetRealmName() or "", written = time(), days = {} }
  local limit = date("%Y-%m-%d", time() - 8 * 86400)
  for _, k in ipairs(ns.EditionKeys()) do
    if k >= limit then
      local blocks = ns.BuildEdition(k)
      if blocks then
        local shot
        for _, b in ipairs(blocks) do if b.file then shot = b.file end end
        ex.days[k] = { md = ns.ToText(blocks, "md"), headline = ns.StripCodes(ns.DayHeadline(k) or ""), shot = shot }
      end
    end
  end
  local today = ns.Today()
  local wk = ns.BuildWeekly(today)
  if wk then ex.weekly = { key = today, md = ns.ToText(wk, "md") } end
  db.exports = ex
end
