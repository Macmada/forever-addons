# Forever Addons

Des addons World of Warcraft pour **WoW Forever**, **TBC Anniversary** et **retail**, avec un seul dossier par addon pour les trois clients.

| Addon | Commande | Rôle |
|---|---|---|
| **ForeverGFX** | `/gfx` | Réglages graphiques en un clic, réglage automatique selon tes FPS, mode expert pour toutes les variables |
| **ForeverMacros** | `/fmac` | macros prêtes par classe (TBC/Forever et retail), constructeur pas à pas, vérification de syntaxe, sauvegarde des macros |
| **ForeverGazette** | `/gazette` | la gazette de ton personnage : les moments forts de chaque journée de jeu, mis en page comme un journal |
| **ForeverHeal** | `/fheal` | (WoW Forever, prêtre) ce que chaque caractéristique et chaque objet change vraiment, en clair : PV, mana, soins par seconde, autonomie |
| **ForeverPrep** | `/prep` | (WoW Forever seulement) prêt pour le donjon ? consommables, composants, améliorations, équipement selon ta classe, ton rôle et ton niveau, liste de courses et achat chez le marchand |

## Installation

### Avec WowUp (mises à jour automatiques)

Dans WowUp, **Get Addons → Install from URL**, colle `https://github.com/Macmada/forever-addons` puis installe : tous les addons arrivent ensemble (ForeverPrep et ForeverHeal ne se chargent que sur WoW Forever) et WowUp propose chaque nouvelle version.

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

- **Macros prêtes** : 60 macros pour les 9 classes de TBC (utilisées sur Forever et TBC Anniversary) et 77 macros pour les 13 classes du retail actuel (`LibraryRetail.lua`). Les sorts sont référencés par numéro, le nom est donc retrouvé dans la langue du client. Une macro dont un sort n'existe pas dans le jeu lancé est masquée (ex. Intervention sur Forever).
- **Créer pas à pas** : sort, cible, touche modificatrice, options, ou mode séquence (totems, rotations sur temps de recharge global).
- **Éditeur** avec vérification en direct : longueur en octets, crochets, commandes, conditions, cibles, sorts introuvables.
- **Sauvegarde / restauration** de toutes les macros sous forme de texte.

Commandes : `/fmac`, `/fmac tuto`, `/fmac minimap`.

## ForeverGazette

Pendant que tu joues, l'addon note les moments forts de ton personnage ; chaque journée de jeu devient une édition de journal, avec une **une** (le plus grand moment du jour, choisi par importance) et des rubriques. Un journal par personnage.

- **Ce qui est noté** : niveaux, boss de donjon et de raid, élites rares, premiers passages dans une zone ou un donjon, objets rares, épiques et légendaires, paliers d'or, morts (avec le coupable : ennemi, chute, noyade…), victoires JcJ et duels, paliers de réputation, paliers de métier et recettes, hauts faits (retail), quêtes rendues, compagnons de groupe.
- **Bilan du jour** : temps de jeu, expérience, quêtes, ennemis vaincus, morts, or gagné et dépensé, zones parcourues.
- **Photo de une** : capture d'écran automatique au moment fort (niveaux, boss, épiques ; option pour tous les grands moments ; 6 par jour au plus). L'édition donne le nom du fichier du dossier `Screenshots`.
- **Trois tons** : *sérieux* (chronique d'aventurier), *tabloïd* (presse à scandale), *épique* (récit de barde). Changer de ton réécrit aussi les anciennes éditions.
- **Rubrique Donjons** : chaque passage en donjon ou en raid (boss, durée, morts du groupe, tes soins et ton excédent), dans les trois tons.
- **Sommaire** de toutes les éditions, **L'Hebdo** (les 7 derniers jours), **export** Markdown ou texte, **partage** dans le canal de guilde, de groupe ou en « Dire ».
- **Démonstration** : `/gazette demo` affiche une édition d'exemple sans rien enregistrer.

Commandes : `/gazette`, `/gazette hebdo`, `/gazette sommaire`, `/gazette export`, `/gazette partager guilde|groupe|dire`, `/gazette ton serieux|tabloid|epique`, `/gazette photo on|off`, `/gazette pdf`, `/gazette demo`, `/gazette minimap`, `/gazette lang fr|en`, `/gazette tuto` (alias `/gaz`).

### PDF et image avec tes captures, Discord (compagnon)

Un addon ne peut ni écrire de fichier ni lire tes captures d'écran : le compagnon `tools/gazette-discord` (Python 3 + Pillow, archive `ForeverGazette-Discord` de chaque version) lit la sauvegarde de l'addon et fait de chaque édition **une page de journal en PDF et en image, avec tes captures** (une, photos des grands moments, rubriques en colonnes, bilan), rangée dans `Documents\ForeverGazette`, et peut la poster sur Discord. Dans le jeu, le bouton **PDF** (`/gazette pdf`) enregistre la gazette pour qu'elle soit prête dans la minute. Mode d'emploi : [tools/gazette-discord/README.md](tools/gazette-discord/README.md).

## ForeverHeal (WoW Forever, prêtre)

Pour jouer soigneur en sachant ce que vaut chaque point : l'addon traduit les caractéristiques en effets concrets.

- **Infobulle des objets** : par rapport à ce que tu portes (la meilleure des deux places pour les anneaux et bijoux, l'arme + la main gauche pour une arme à deux mains), par exemple « +35 Endurance → +350 PV », « +15 Intelligence → +225 mana, +0,30 % critique », « +22 soins → +19 par Soins supérieurs », « +4 mana / 5 s → +0,80 mana/s, même en incantant », puis « Soin moyen +17 · +7,2 soins/s · autonomie +2 s (+1 085 PV soignés avant d'être à sec) ».
- **Panneau à côté de la fiche personnage** : tes PV, mana, régénération, bonus aux soins, critique, taux de soins effectifs ; tes sorts de référence ; soins par seconde, soin moyen, autonomie ; « ce que vaut » +10 dans chaque caractéristique et la plus utile pour toi en ce moment.
- **Annonce à chaque changement** (hors combat), à l'écran ou dans la discussion : « +30 Endurance → +360 PV ».
- **Conseiller de rangs** : d'après ton excédent de soins réel par rang, « Soins supérieurs r4 : 38 % d'excédent → le rang 2 suffirait : −120 mana par lancer », et un bouton qui crée les macros de rang correspondantes (sur le survol, sinon la cible).
- **Alerte de mana en combat** : « Mana : à sec dans ~14 s », d'après ta consommation réelle des 12 dernières secondes (orange, puis rouge sous 8 s).
- **Mieux dans mes sacs ?** : les objets de tes sacs qu'un prêtre peut porter et qui amélioreraient tes soins ou ton autonomie, emplacement par emplacement.
- **Calé sur ton personnage** : les conversions (PV par Endurance, mana par Intelligence, Intelligence pour 1 % de critique, régénération par l'Esprit) sont mesurées à chaque changement d'équipement ; les montants des sorts sont lus dans le jeu ; ton **mélange de sorts** vient de tes lancers réels (part du temps passé sur chaque sort) et l'effet de tes talents est mesuré sur tes vrais soins.

Commandes : `/fheal` (panneau), `/fheal sacs`, `/fheal macros`, `/fheal alerte`, `/fheal infobulle`, `/fheal annonce`, `/fheal ecran|chat`, `/fheal panneau`, `/fheal oublier`, `/fheal lang fr|en`.

## ForeverPrep (WoW Forever)

Avant un donjon ou un raid, une fiche compare ce que tu as à ce qu'il faut pour **ta classe, ton rôle et ton niveau** : vert = prêt, orange = à faire, rouge = manque important, gris = conseil.

- **Consommables** : potions de soins et de mana, nourriture, boisson (classes à mana), bandages, nourriture « Bien nourri », élixirs et flacons (raid), au **meilleur rang utilisable à ton niveau** ; pierres de soins et nourriture/eau du mage comptées.
- **Composants de classe** : fragments d'âme, runes et plumes (mage), bougies (prêtre), graines du rang de Renaissance connu et baies (druide), symboles (paladin), ankh (chaman), poudres et poisons (voleur), flèches ou balles selon l'arme (chasseur) ; seulement si tu connais le sort qui les utilise.
- **Améliorations** : tes buffs personnels (armures, Feu intérieur, aura, aspect…), ceux que tu donnes au groupe et qui manquent à quelqu'un (nommé), familier/démon, poisons et imprégnations d'arme, pierre ou huile conseillée.
- **Équipement et personnage** : durabilité, place dans les sacs, emplacements vides, points de talent, **rappel du maître de classe** (nouveaux rangs de sorts tous les 2 niveaux), pierre de foyer.
- **Donjon ou raid** (quantités adaptées), **rôle** deviné par les talents et modifiable.
- **Liste de courses**, et **chez un marchand** qui vend ces objets : achat de toute la liste en un clic (avec confirmation et prix).
- S'ouvre toute seule (s'il manque quelque chose) à l'entrée d'un donjon ou d'un raid, lors d'un appel (ready check) et d'une recherche de groupe ou de donjon. Chaque déclencheur se coupe dans les options.
- **Bouton « Prépa » à l'écran** pour la lancer quand tu veux : déplaçable, sa bordure est verte, orange ou rouge selon ton état ; clic droit = options ; `/prep bouton` pour le masquer ou le remettre.
- Les objets sont vérifiés auprès du jeu au chargement (nom, niveau requis) : un objet absent de Forever est ignoré.

Commandes : `/prep`, `/prep raid`, `/prep donjon`, `/prep role auto|tank|soigneur|physique|magique`, `/prep bouton`, `/prep minimap`, `/prep lang fr|en`, `/prep tuto`.

## Icône commune « Forever »

Une seule icône autour de la minicarte pour tous les addons : un clic ouvre un menu (Gazette, Prépa donjon, Soins, Macros, Graphismes). À la première connexion, elle remplace les icônes séparées. `/forever separees` remet une icône par addon, `/forever commune` revient à l'icône commune, `/forever minimap` la masque. La commande `minimap` de chaque addon réaffiche aussi son icône séparée.

## Diagnostic (pour adapter les addons à WoW Forever)

Chaque addon a un **bouton « Diag »** dans la barre de titre de sa fenêtre (et une commande `diag`) qui ouvre une fenêtre avec un texte à copier (Ctrl+A puis Ctrl+C) et à coller à Claude : ce que ton client donne vraiment, pour corriger les bases d'après le jeu réel plutôt que d'après les règles classiques.

| Commande | Contenu |
|---|---|
| `/gfx diag` | valeur de chaque variable graphique gérée, celles absentes du client, et les variables graphiques du client pas encore gérées |
| `/fmac diag` | sorts des macros prêtes trouvés ou absents dans ce client, classe par classe |
| `/gazette diag` | événements acceptés ou refusés, fonctions disponibles, textes du jeu (butin, métiers, duels), boss détectés et comment, derniers moments notés |
| `/prep diag` | chaque objet de la base (vrai nom et niveau requis, écarts signalés), objets absents, sorts de classe, consommables de tes sacs inconnus de la base, analyse actuelle |
| `/fheal diag` | relevé du jeu et conversions mesurées, sorts de soin avec leur description brute et ce que l'addon en lit, sorts de soin du grimoire inconnus de la base, caractéristiques de chaque pièce portée |

Chaque texte commence par la version du client, le numéro d'interface, la langue, le personnage et les addons chargés. Le module est commun (`tools/Diag.lua`, copié dans chaque addon par `tools/sync-shared.sh`, comme l'icône commune `tools/Hub.lua` et le tutoriel `tools/Tour.lua`).

## Compatibilité

Chaque `.toc` déclare les numéros d'interface des trois clients sur une seule ligne `## Interface:`. Le code teste la présence des fonctions récentes (`C_CVar`, `C_Spell`, `Settings`…) et se replie sur les anciennes si besoin. Si une mise à jour du jeu change le numéro d'interface, ajoute-le à cette ligne (`/dump select(4, GetBuildInfo())` en jeu pour l'obtenir).

| Client | Interface |
|---|---|
| WoW Forever | 16000, 16001 |
| TBC Anniversary | 20504, 20505 |
| Retail (Midnight) | 120100 à 120200 |

## Développement

- `luacheck ForeverGFX ForeverMacros ForeverGazette ForeverPrep ForeverHeal` vérifie le code (lancé automatiquement à chaque push).
- `lua5.1 tests/gazette_sim.lua fr` (et `en`) simule une journée de jeu avec une API WoW imitée et vérifie l'édition produite ; `tests/prep_sim.lua`, `tests/heal_sim.lua`, `tests/gfx_sim.lua` et `tests/macros_sim.lua` font de même pour les autres addons (`tests/wowmock.lua` : API WoW imitée commune). Lancés aussi à chaque push.
- Publier une version : `git tag v2.1.0 && git push --tags`. GitHub Actions inscrit la version dans les TOC et attache les archives à la release (ForeverMacros, ForeverGazette et ForeverPrep gardent le numéro de leur TOC).

---

## English

Three WoW addons for **WoW Forever**, **TBC Anniversary** and **retail** (one folder per addon for all three clients). **ForeverGFX** (`/gfx`) offers one-click graphics presets, automatic tuning toward a target FPS, an FPS counter, context-based switching and an expert view of every graphics variable. **ForeverMacros** (`/fmac`) offers ready-made class macros (a TBC/Forever set and a retail set) (localized automatically through spell IDs), a step-by-step builder with a sequence mode, live syntax checking and macro backup/restore. **ForeverHeal** (`/fheal`, WoW Forever, priest) turns stats and items into plain effects (HP, mana, healing per second, mana longevity) in item tooltips, a character-sheet panel and change announcements, calibrated on your character and your real spell usage. **ForeverPrep** (`/prep`, WoW Forever only) checks your dungeon/raid readiness by class, role and level (consumables at the best usable rank, class reagents, buffs, gear, trainer reminder) with a shopping list and one-click vendor purchase. **ForeverGazette** (`/gazette`) turns each play day into a newspaper edition of your character's highlights (levels, bosses, rare kills, epic loot, deaths, duels, reputation, professions, gold), with automatic front-page screenshots, three tones (serious, tabloid, epic), a weekly edition, Markdown export, chat sharing and an optional Discord companion script. All addons are fully translated (French and English) and include a guided tutorial.

## Licence

Distribué sous licence [MIT](LICENSE) : libre d'utilisation, de modification et de redistribution, à condition de conserver la mention de copyright.
