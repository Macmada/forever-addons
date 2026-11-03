#!/bin/sh
# Copie le module de diagnostic commun (tools/Diag.lua) dans chaque addon. --check : échoue si une copie diffère.
set -e
cd "$(dirname "$0")/.."
for a in ForeverGFX ForeverMacros ForeverGazette ForeverPrep ForeverHeal; do
  if [ "$1" = "--check" ]; then
    cmp -s tools/Diag.lua "$a/Diag.lua" || { echo "$a/Diag.lua diffère de tools/Diag.lua (lance tools/sync-diag.sh)"; exit 1; }
  else
    cp tools/Diag.lua "$a/Diag.lua"
  fi
done
echo "Diag.lua : ok"
