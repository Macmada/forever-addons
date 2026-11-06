-- Charge une partie de ForeverCompagnon seule (ancien addon : ForeverHeal, ForeverLoot, ForeverPrep, ForeverMetiers),
-- comme avant la fusion : socle (Root, modules communs, lien avec le jeu) puis seulement les fichiers de cette partie.
-- Usage : local ns = dofile("tests/compagnon_load.lua")("ForeverHeal")  (l'API imitée doit déjà être en place)
local MODDIR = { ForeverHeal = "Heal", ForeverLoot = "Loot", ForeverPrep = "Prep", ForeverMetiers = "Metiers" }
local function tocFiles()
  local files = {}
  local toc = io.open("ForeverCompagnon/ForeverCompagnon.toc"):read("*a")
  for file in toc:gmatch("\n([%w_\\]+%.lua)") do files[#files + 1] = file end
  return files
end
local function run(file, root) assert(loadfile("ForeverCompagnon/" .. file:gsub("\\", "/")))("ForeverCompagnon", root) end
return function(name, root)
  if not root then
    root = {}
    for _, f in ipairs(tocFiles()) do
      local dir = f:match("^(%w+)\\")
      if not dir and f ~= "Root.lua" and f ~= "Compat.lua" and f ~= "Nav.lua" then break end
      if dir == nil or dir == "Shared" or dir == "Data" then run(f, root) end
    end
  end
  for _, f in ipairs(tocFiles()) do
    if f:match("^(%w+)\\") == MODDIR[name] then run(f, root) end
  end
  return root.mods[name], root
end
