# Forever Addons

Deux addons World of Warcraft compatibles **WoW Forever**, **TBC Anniversary** et **retail**, avec un seul dossier par addon pour les trois clients.

| Addon | Commande | Rôle |
|---|---|---|
| **ForeverGFX** | `/gfx` | Réglages graphiques en un clic, réglage automatique selon tes FPS, mode expert pour toutes les variables |
| **ForeverMacros** | `/fmac` | 60 macros prêtes par classe, constructeur pas à pas, vérification de syntaxe, sauvegarde des macros |

## Installation

### Avec WowUp (mises à jour automatiques)

Dans WowUp, **Get Addons → Install from URL**, colle `https://github.com/Macmada/forever-addons` puis installe : les deux addons arrivent ensemble et WowUp propose chaque nouvelle version.

### À la main

1. Télécharge les archives de la dernière version dans l'onglet **Releases**.
2. Dézippe chaque dossier dans le dossier AddOns de ton client :
   - WoW Forever : dossier `Interface\AddOns` du client Forever
   - TBC Anniversary : `World of Warcraft\_anniversary_\Interface\AddOns`
   - Retail : `World of Warcraft\_retail_\Interface\AddOns`
3. Lance le jeu : un tutoriel s'ouvre à la première utilisation. Les icônes autour de la minicarte (longue-vue et note) ouvrent les addons.

## ForeverGFX

- **Vue simple** : six niveaux de qualité expliqués, un bouton « Appliquer ». Sans confirmation, l'ancien réglage revient tout seul au bout de 15 secondes.
- **Trouver le meilleur réglage** : choisis un objectif de FPS, l'addon teste les niveaux et garde le plus beau qui reste fluide.
- **Outils** : mesure de FPS, compteur à l'écran, bascule automatique selon le contexte (monde, ville, donjon, raid, JcJ), annulation et historique.
- **Mode expert** : toutes les variables graphiques du client, classées par catégorie, avec descriptions, profils, export/import et comparaison.

Commandes : `/gfx`, `/gfx tune 60`, `/gfx fps`, `/gfx preset ultra`, `/gfx undo`, `/gfx tuto`, `/gfx minimap`, `/gfx lang fr|en`.

## ForeverMacros

- **Macros prêtes** : 60 macros pour les 9 classes de TBC. Les sorts sont référencés par numéro, le nom est donc retrouvé dans la langue du client.
- **Créer pas à pas** : sort, cible, touche modificatrice, options, ou mode séquence (totems, rotations sur temps de recharge global).
- **Éditeur** avec vérification en direct : longueur en octets, crochets, commandes, conditions, cibles, sorts introuvables.
- **Sauvegarde / restauration** de toutes les macros sous forme de texte.

Commandes : `/fmac`, `/fmac tuto`, `/fmac minimap`.

## Compatibilité

Chaque `.toc` déclare les numéros d'interface des trois clients sur une seule ligne `## Interface:`. Le code teste la présence des fonctions récentes (`C_CVar`, `C_Spell`, `Settings`…) et se replie sur les anciennes si besoin. Si une mise à jour du jeu change le numéro d'interface, ajoute-le à cette ligne (`/dump select(4, GetBuildInfo())` en jeu pour l'obtenir).

| Client | Interface |
|---|---|
| WoW Forever | 16000, 16001 |
| TBC Anniversary | 20504, 20505 |
| Retail (Midnight) | 120100 à 120200 |

## Développement

- `luacheck ForeverGFX ForeverMacros` vérifie le code (lancé automatiquement à chaque push).
- Publier une version : `git tag v2.1.0 && git push --tags`. GitHub Actions inscrit la version dans les TOC et attache les deux archives à la release.

---

## English

Two WoW addons for **WoW Forever**, **TBC Anniversary** and **retail** (one folder per addon for all three clients). **ForeverGFX** (`/gfx`) offers one-click graphics presets, automatic tuning toward a target FPS, an FPS counter, context-based switching and an expert view of every graphics variable. **ForeverMacros** (`/fmac`) offers 60 ready-made class macros (localized automatically through spell IDs), a step-by-step builder with a sequence mode, live syntax checking and macro backup/restore. Both addons are fully translated (French and English) and include a guided tutorial.

## Licence

Distribué sous licence [MIT](LICENSE) : libre d'utilisation, de modification et de redistribution, à condition de conserver la mention de copyright.
