#!/bin/sh
# Construit l'addon séparé ForeverBiS : la partie Équipement de ForeverCompagnon seule (BiS par spé), avec son socle
# (Root, Compat, Nav, Store, modules communs Diag, Widgets, ATT). Mêmes fichiers que ForeverCompagnon : rien à maintenir
# à part. Sortie : ./ForeverBiS (ignoré par git) ; --zip : dist/ForeverBiS-v<version>.zip avec ForeverCompagnon_Data
# (sources d'All The Things : noms dans ta langue, itinéraires ; facultatif).
set -e
cd "$(dirname "$0")/.."
VER="$(sed -n 's/^## Version: //p' ForeverCompagnon/ForeverCompagnon.toc | tr -d '\r')"
rm -rf ForeverBiS
mkdir -p ForeverBiS/Shared ForeverBiS/Loot
cp ForeverCompagnon/Root.lua ForeverCompagnon/Compat.lua ForeverCompagnon/Nav.lua ForeverCompagnon/Store.lua ForeverBiS/
cp ForeverCompagnon/Shared/Diag.lua ForeverCompagnon/Shared/Widgets.lua ForeverCompagnon/Shared/ATT.lua ForeverBiS/Shared/
cp ForeverCompagnon/Loot/*.lua ForeverCompagnon/Loot/LICENSE-wowsims.txt ForeverBiS/Loot/
cp tools/bis/Bootstrap.lua ForeverBiS/
LOOT="$(grep -E '^Loot\\' ForeverCompagnon/ForeverCompagnon.toc | tr -d '\r')"
{
  printf '## Interface: 16000, 16001\n'
  printf '## Title: ForeverBiS\n'
  printf "## Notes: Meilleur équipement par spé pour WoW Forever (prêtre soigneur ; paladin Sacré, Protection, Vindicte) : quoi viser à ton niveau, où l'obtenir, et la liste BiS niveau 60.\n"
  printf '## Notes-enUS: Best gear by spec for WoW Forever (holy priest; holy, protection, retribution paladin): what to aim for at your level, where to get it, and the level 60 BiS list.\n'
  printf '## Author: ForeverGFX\n'
  printf '## Version: %s\n' "$VER"
  printf '## SavedVariables: ForeverCompagnonDB, ForeverLootGlobalDB\n'
  printf '## SavedVariablesPerCharacter: ForeverLootDB\n'
  printf '## IconTexture: Interface\\Icons\\INV_Chest_Plate16\n'
  printf '## AddonCompartmentFunc: ForeverBiS_OnCompartmentClick\n\n'
  printf 'Root.lua\nShared\\Diag.lua\nShared\\Widgets.lua\nShared\\ATT.lua\nCompat.lua\nNav.lua\nStore.lua\n'
  printf '%s\n' "$LOOT"
  printf 'Bootstrap.lua\n'
} > ForeverBiS/ForeverBiS.toc
echo "ForeverBiS $VER construit ($(find ForeverBiS -name '*.lua' | wc -l) fichiers Lua)"
if [ "$1" = "--zip" ]; then
  mkdir -p dist
  rm -f "dist/ForeverBiS-v$VER.zip"
  if command -v zip >/dev/null; then zip -qr "dist/ForeverBiS-v$VER.zip" ForeverBiS ForeverCompagnon_Data
  else python3 -m zipfile -c "dist/ForeverBiS-v$VER.zip" ForeverBiS ForeverCompagnon_Data; fi
  echo "dist/ForeverBiS-v$VER.zip"
fi
