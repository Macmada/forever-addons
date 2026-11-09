#!/bin/sh
# Régénère ForeverCompagnon_Data/Sources.lua depuis la base WoW Forever (« Camelot ») d'All The Things (licence MIT).
# À lancer avant une version : télécharge seulement db/Camelot (clone partiel), extrait, affiche les comptes.
set -e
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone -q --depth 1 --filter=blob:none --sparse https://github.com/ATTWoWAddon/AllTheThings "$TMP/att"
git -C "$TMP/att" sparse-checkout set --no-cone '/db/Camelot/' '/LICENSE' >/dev/null
REV="$(git -C "$TMP/att" rev-parse --short HEAD)"
lua5.1 tools/att_extract.lua "$TMP/att/db/Camelot" "$REV" > ForeverCompagnon_Data/Sources.lua.new
mv ForeverCompagnon_Data/Sources.lua.new ForeverCompagnon_Data/Sources.lua
echo "ForeverCompagnon_Data/Sources.lua : All The Things $REV"
