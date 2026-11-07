#!/bin/sh
# Copie les modules communs (tools/*.lua) dans les addons. --check : échoue si une copie diffère.
#   Diag.lua : diagnostic ; Hub.lua : icône commune « Forever » ; Tour.lua : tutoriel ; ATT.lua : sources d'All The Things ;
#   Widgets.lua : composants d'interface.
# ForeverCompagnon (Soins, Équipement, Préparation, Métiers en un seul addon) : une seule copie de chaque module, enveloppée
# dans une fonction (ForeverCompagnon/Shared/*.lua) que chaque module appelle avec son propre espace de noms.
set -e
cd "$(dirname "$0")/.."
SEP="ForeverGFX ForeverMacros"
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
wrap() { # fichier : ForeverCompagnon/Shared/<fichier>, même code dans une fonction
  f="$1"; n="${f%.lua}"; out="ForeverCompagnon/Shared/$f"
  tmp="$(mktemp)"
  { printf -- '-- Généré par tools/sync-shared.sh depuis tools/%s : ne pas modifier ici.\n' "$f"
    printf 'local _, root = ...\nroot.Shared.%s = function(...)\n' "$n"
    cat "tools/$f"
    printf '\nend\n'; } > "$tmp"
  if [ "$CHECK" = 1 ]; then
    cmp -s "$tmp" "$out" || { rm -f "$tmp"; echo "$out n'est pas à jour (lance tools/sync-shared.sh)"; exit 1; }
    rm -f "$tmp"
  else
    mkdir -p ForeverCompagnon/Shared
    mv "$tmp" "$out"
  fi
}
[ "$1" = "--check" ] && CHECK=1
sync Diag.lua $SEP
sync Hub.lua $SEP
sync Tour.lua ForeverGFX ForeverMacros
sync Widgets.lua $SEP
for f in Diag.lua Hub.lua Tour.lua ATT.lua Widgets.lua; do wrap "$f"; done
echo "modules communs : ok"
