#!/bin/sh
# Copie les modules communs (tools/*.lua) dans les addons. --check : échoue si une copie diffère.
#   Diag.lua : diagnostic (tous) ; Hub.lua : icône commune « Forever » (tous) ; Tour.lua : tutoriel (addons qui en ont un) ;
#   ATT.lua : sources d'All The Things (ForeverMetiers, ForeverLoot)
set -e
cd "$(dirname "$0")/.."
ALL="ForeverGFX ForeverMacros ForeverGazette ForeverPrep ForeverHeal ForeverLoot ForeverMetiers"
TOUR="ForeverGFX ForeverMacros ForeverGazette ForeverPrep"
sync() { # fichier addons...
  f="$1"; shift
  for a in "$@"; do
    if [ "$CHECK" = 1 ]; then
      cmp -s "tools/$f" "$a/$f" || { echo "$a/$f diffère de tools/$f (lance tools/sync-shared.sh)"; exit 1; }
    else
      cp "tools/$f" "$a/$f"
    fi
  done
}
[ "$1" = "--check" ] && CHECK=1
sync Diag.lua $ALL
sync Hub.lua $ALL
sync Tour.lua $TOUR
sync ATT.lua ForeverMetiers ForeverLoot
sync Widgets.lua ForeverGazette ForeverPrep ForeverHeal
echo "modules communs : ok"
