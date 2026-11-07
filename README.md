# Forever Addons

Des addons World of Warcraft pour **WoW Forever** (et seulement WoW Forever depuis la v3.0.3).

| Addon | Commande | Rôle |
|---|---|---|
| **ForeverGFX** | `/gfx` | Réglages graphiques en un clic, réglage automatique selon tes FPS, mode expert pour toutes les variables |
| **ForeverMacros** | `/fmac` | macros prêtes par classe, constructeur pas à pas, vérification de syntaxe, sauvegarde des macros |
| **ForeverCompagnon** | `/fp` | toutes classes, races et factions, en une fenêtre : **Maintenant** (le plus utile à ton niveau, avec ton rôle), **Équipement** (`/floot`), **Préparation** (`/prep`), **Métiers** (`/metiers`, tous les métiers), **Soins** (`/fheal`, prêtre, druide, paladin, chaman), **Addons** utiles ; auto-test et sonde du client |

## Installation

### Avec WowUp (mises à jour automatiques)

Dans WowUp, **Get Addons → Install from URL**, colle `https://github.com/Macmada/forever-addons` puis installe : tous les addons arrivent ensemble (ForeverCompagnon ne se charge que sur WoW Forever) et WowUp propose chaque nouvelle version.

**Depuis la v3.0.0**, ForeverHeal, ForeverLoot, ForeverPrep et ForeverMetiers sont réunis dans un seul addon, appelé **ForeverCompagnon** depuis la v3.1.0 (ForeverPrêtre avant). Les anciens dossiers (ForeverHeal, ForeverLoot, ForeverPrep, ForeverMetiers, ForeverPretre) sont remplacés par une coquille vide qui se désactive toute seule : tu peux les supprimer. Les réglages repartent de zéro.

### À la main

1. Télécharge les archives de la dernière version dans l'onglet **Releases**.
2. Dézippe chaque dossier dans le dossier AddOns de ton client :
   - dossier `Interface\AddOns` du client WoW Forever
3. Lance le jeu : un tutoriel s'ouvre à la première utilisation. Les icônes autour de la minicarte (longue-vue et note) ouvrent les addons.

## ForeverGFX

- **Vue simple** : six niveaux de qualité expliqués, un bouton « Appliquer ». Sans confirmation, l'ancien réglage revient tout seul au bout de 15 secondes.
- **Trouver le meilleur réglage** : choisis un objectif de FPS, l'addon teste les niveaux et garde le plus beau qui reste fluide.
- **Outils** : mesure de FPS, compteur à l'écran, bascule automatique selon le contexte (monde, ville, donjon, raid, JcJ), annulation et historique.
- **Mode expert** : toutes les variables graphiques du client, classées par catégorie, avec descriptions, profils, export/import et comparaison.

Commandes : `/gfx`, `/gfx tune 60`, `/gfx fps`, `/gfx preset ultra`, `/gfx undo`, `/gfx tuto`, `/gfx minimap`, `/gfx lang fr|en`.

## ForeverMacros

- **Macros prêtes** : 60 macros pour les 9 classes. Les sorts sont référencés par numéro, le nom est donc retrouvé dans la langue du client. Une macro dont un sort n'existe pas dans le jeu lancé est masquée (ex. Intervention sur Forever).
- **Créer pas à pas** : sort, cible, touche modificatrice, options, ou mode séquence (totems, rotations sur temps de recharge global).
- **Éditeur** avec vérification en direct : longueur en octets, crochets, commandes, conditions, cibles, sorts introuvables.
- **Sauvegarde / restauration** de toutes les macros sous forme de texte.

Commandes : `/fmac`, `/fmac tuto`, `/fmac minimap`.

## ForeverCompagnon (WoW Forever)

Une seule fenêtre pour ton personnage, **quelle que soit sa classe, sa race ou sa faction**, ouverte par `/fp` (ou `/compagnon`) ou l'icône Forever. À gauche, une barre d'onglets (Soins seulement pour les soigneurs) :

- **Maintenant** : la question « que faire maintenant ? » à ton niveau, avec ton **rôle** à choisir (tank, soins, dégâts en mêlée ou en sorts : le client de Forever ne donne pas les talents aux addons ; il règle l'équipement et la préparation) : tes soins si tu soignes (soins/s, autonomie, régénération), les 4 meilleures améliorations d'équipement à portée (jusqu'à 5 niveaux au-dessus) et où les obtenir, ce qu'il manque avant un donjon avec le bouton **Guide-moi vers le vendeur**, et la prochaine étape de tes métiers. Un clic sur une ligne ouvre le détail. En combat, l'écran garde le dernier état (rien n'est recalculé).
- **Soins**, **Équipement**, **Préparation**, **Métiers** : les anciens addons, décrits ci-dessous (mêmes commandes).
- **Autonome** (depuis la 3.2.0) : plus besoin d'autres addons.
  - **Où obtenir chaque objet et recette** : la base WoW Forever d'All The Things ([licence MIT](ForeverCompagnon/Data/LICENSE-AllTheThings.txt)) est incluse (`ForeverCompagnon/Data/Sources.lua`, ~13 000 objets, butin des boss, vendeurs et prix, quêtes, recettes de tous les métiers), régénérée avant chaque version par `tools/update-att-data.sh`. Un addon ne peut pas aller sur Internet depuis le jeu : les données sont livrées avec lui. Les noms (PNJ, zones, donjons, quêtes) sont demandés au jeu, dans ta langue.
  - **Flèche de navigation** (à la TomTom) : vers le vendeur de « Guide-moi », vers le lieu d'un objet ou d'une recette (clic droit sur sa ligne), ou `/fp way 42 63 [nom]` (`/way` si TomTom n'est pas installé). Distance, temps à pied, couleur selon la direction ; repère du jeu posé sur la carte aussi. Clic droit pour l'effacer, glisser pour la déplacer.
  - **Prix** : bouton « Relever les prix » sur l'hôtel des ventes (relevé complet, une fois toutes les 15 minutes).
  - **Banque et rerolls** : retenus par l'addon (banque à chaque ouverture).
  - All The Things, DungeonJournal, Auctionator, Syndicator et TomTom deviennent facultatifs (Auctionator et Syndicator sont encore utilisés en plus s'ils sont là).
- **Cadre des changements** : quand tu équipes un objet (hors combat), un cadre doré apparaît à côté de ton personnage (ou contre ta fiche personnage si elle est ouverte) : l'objet, une ligne par caractéristique avec son icône, la valeur en vert ou en rouge et ce que ça change (« +12 Endurance » +120 PV », armure en % de dégâts évités ; pour un soigneur, soins/s et autonomie), un éclat d'étoile, et les valeurs qui montent au-dessus de ta tête comme du texte de combat. Survol : reste affiché ; glisser : déplacer (position retenue) ; clic droit : fermer ; `/fp flash place` : place automatique. `/fp flash` l'active ou le coupe, `/fp flash test` en montre un aperçu.
- **Addons** (`/fp addons`) : les addons intégrés (plus nécessaires) et ceux qui complètent celui-ci sur Forever (HealBot, Questie, Full Mana Forever, Forever Cooldown Manager) : actif, désactivé ou absent, ce qu'il apporte, son adresse à copier, bouton « Activer » (au prochain `/reload`).
- **Auto-test** (`/fp test`) : essaie pour de vrai chaque fonction importante sur ton client (sacs, équiper, marchand, sorts, mana, métiers, chaque partie) et donne un rapport à copier.
- **Sonde** (`/fp sonde`) : la liste des fonctions de WoW présentes ou absentes sur ton client, à coller telle quelle : elle devient le profil du client dans les tests hors jeu (`tests/forever_client.lua`).
- **Diag** (`/fp diag`) : le diagnostic de toutes les parties en un seul texte.

Le **lien avec le jeu** (`ForeverCompagnon/Compat.lua`) est le seul endroit qui appelle les fonctions du jeu qui diffèrent entre clients (équiper, marchand, sacs, sorts, mana secrète en combat) ; la sonde et l'auto-test disent quelle méthode a été retenue.

### Soins (ex-ForeverHeal) : prêtre, druide, paladin, chaman

Pour jouer soigneur en sachant ce que vaut chaque point : l'addon traduit les caractéristiques en effets concrets.

- **Infobulle des objets** : par rapport à ce que tu portes (la meilleure des deux places pour les anneaux et bijoux, l'arme + la main gauche pour une arme à deux mains), par exemple « +35 Endurance → +350 PV », « +15 Intelligence → +225 mana, +0,30 % critique », « +22 soins → +19 par Soins supérieurs », « +4 mana / 5 s → +0,80 mana/s, même en incantant », puis « Soin moyen +17 · +7,2 soins/s · autonomie +2 s (+1 085 PV soignés avant d'être à sec) ».
- **Panneau à côté de la fiche personnage** : tes PV, mana, régénération, bonus aux soins, critique, taux de soins effectifs ; tes sorts de référence ; soins par seconde, soin moyen, autonomie ; « ce que vaut » +10 dans chaque caractéristique et la plus utile pour toi en ce moment.
- **Annonce à chaque changement** (hors combat), à l'écran ou dans la discussion : « +30 Endurance → +360 PV ».
- **Conseiller de rangs** (avec, si HealBot est installé, quoi changer dans ses sorts) : d'après ton excédent de soins réel par rang, « Soins supérieurs r4 : 38 % d'excédent → le rang 2 suffirait : −120 mana par lancer », et un bouton qui crée les macros de rang correspondantes (sur le survol, sinon la cible).
- **Alerte de mana en combat** : « Mana : à sec dans ~14 s », d'après ta consommation réelle des 12 dernières secondes (orange, puis rouge sous 8 s).
- **Mieux dans mes sacs ?** : les objets de tes sacs qu'un prêtre peut porter et qui amélioreraient tes soins ou ton autonomie, emplacement par emplacement.
- **Calé sur ton personnage** : les conversions (PV par Endurance, mana par Intelligence, Intelligence pour 1 % de critique, régénération par l'Esprit) sont mesurées à chaque changement d'équipement ; les montants des sorts sont lus dans le jeu ; ton **mélange de sorts** vient de tes lancers réels (part du temps passé sur chaque sort) et l'effet de tes talents est mesuré sur tes vrais soins.

Commandes : `/fheal` (panneau), `/fheal sacs`, `/fheal macros`, `/fheal alerte`, `/fheal infobulle`, `/fheal annonce`, `/fheal ecran|chat`, `/fheal panneau`, `/fheal oublier`, `/fheal lang fr|en`.

### Équipement (ex-ForeverLoot)

Équipement et butin, évalués **pour ton personnage** : modèle de soins pour un soigneur, sinon poids des caractéristiques selon ta **classe et ton rôle** (tank : endurance, armure, défense ; mêlée : force ou agilité et DPS de l'arme ; sorts : puissance des sorts, toucher…) :

- **BiS calculé** : chaque objet croisé (infobulles, butin, jets, récompenses de quête, marchands, butin des autres) est mémorisé et évalué ; l'onglet BiS montre, emplacement par emplacement, les meilleurs objets connus et où ils ont été vus, avec la **liste de référence de WoW Forever** (prêtre soigneur niveau 60 avant les raids, liste de kami-labs.fr calculée avec le simulateur wowsims/forever) et l'enchantement conseillé pour chaque pièce.
- **Jets de butin** : conseil « BESOIN » ou « Cupidité » au-dessus de la fenêtre de jet, avec le gain (« +3,5 soins/s ») ou la raison (ta classe ne peut pas le porter, niveau trop élevé, pas mieux).
- **Récompenses de quête** : la meilleure pour toi est mise en évidence, sinon la plus chère à revendre.
- **Butin des donjons** : ce que chaque boss lâche, noté au fil de tes donjons (pour tous tes personnages), objets intéressants pour toi en vert.
- Ce que chaque classe peut porter est pris en compte (types d'armure selon le niveau, armes, boucliers).
- **Avec DungeonJournal** (facultatif) : le butin de chaque boss et les récompenses de quête de ses donjons, nouveaux donjons de Forever compris, entrent dans le BiS et l'onglet Donjons. **Avec Syndicator** (facultatif) : un objet déjà dans ta banque, ton courrier ou sur un autre personnage est signalé. **Avec All The Things** (facultatif) : où obtenir chaque objet du BiS.

Commandes : `/floot` (ou `/bis`), `/floot donjons`, `/floot diag`, `/floot lang fr|en`.

### Métiers (ex-ForeverMetiers)

**Tous les métiers** : compétence et rang, rappel du maître quand le plafond approche, meilleurs crafts d'après les couleurs de la fenêtre du métier (coût par point avec Auctionator), recettes à apprendre maintenant (All The Things), métiers conseillés pour ta classe tant que tu n'as pas tes deux métiers principaux. En plus, pour la couture et l'enchantement, un guide pas à pas pensé pour un soigneur :

- **Montée** : à l'ouverture de la fenêtre du métier, un panneau à côté donne les **meilleurs crafts** d'après les couleurs réelles du jeu (faisables d'abord, orange, étape du guide, coût par point avec les prix d'Auctionator) ; un clic sélectionne la recette. L'**étape du guide** (parcours 1-300 de mamytwink.com) et la **liste de courses** : ce qu'il faut pour la finir, ce que tu as dans tes sacs, ta banque et sur tes rerolls (Syndicator), ce qui manque et son coût. **Rappel du maître** (Compagnon, Expert, Artisan) quand tu approches du plafond, avec où le trouver et le niveau requis.
- **Pour toi** : pour chaque pièce portée, enchantée ou non, le meilleur enchantement de soigneur que tu sais faire, celui à apprendre dès maintenant et le meilleur à viser, **chiffrés en soins/s par ForeverHeal** (description du jeu lue quand tu connais la formule) ; les pièces de couture (recettes connues et patrons du guide) qui t'améliorent.
- **Désenchanter** : ce qui peut l'être dans tes sacs (jamais une amélioration pour toi, ni chemise ou tabard), ce que ça donne et la compétence requise ; bouton « Désenchanter le premier » ; clic droit sur une ligne pour garder l'objet.
- **Recettes** : feux de camp de Forever (bannière, rouet, luth, récupérateur arcanique…), bâtonnets runiques, enchantements de soigneur et patrons utiles, avec où les obtenir (maître, butin, faveur marchande, réputation) et si tu les connais ; **temps de recharge** de tous tes personnages.
- **Infobulles** : un patron ou une formule dit s'il est déjà appris, par quel reroll, ou s'il est utile à ton prêtre ; un composant dit à quelle étape de ta montée il sert.

**Avec All The Things** (facultatif) : où apprendre chaque recette (PNJ, quête, zone, coût, réputation) et à quelle compétence, d'après la base de WoW Forever d'ATT, et la liste de toutes les recettes à apprendre maintenant.

Les données des guides viennent de la bêta : l'addon s'appuie d'abord sur ce que la fenêtre du métier donne vraiment, et le bouton **Diag** dit ce qui diffère.

Commandes : `/metiers` (montée), `/metiers pourtoi`, `/metiers de`, `/metiers recettes`, `/metiers garder`, `/metiers diag`, `/metiers lang fr|en`.

### Préparation (ex-ForeverPrep)

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

Une seule icône autour de la minicarte pour tous les addons : un clic ouvre un menu (Compagnon, Macros, Graphismes). À la première connexion, elle remplace les icônes séparées. `/forever separees` remet une icône par addon, `/forever commune` revient à l'icône commune, `/forever minimap` la masque. La commande `minimap` de chaque addon réaffiche aussi son icône séparée.

## Diagnostic (pour adapter les addons à WoW Forever)

Chaque addon a un **bouton « Diag »** dans la barre de titre de sa fenêtre (et une commande `diag`) qui ouvre une fenêtre avec un texte à copier (Ctrl+A puis Ctrl+C) et à coller à Claude : ce que ton client donne vraiment, pour corriger les bases d'après le jeu réel plutôt que d'après les règles classiques.

| Commande | Contenu |
|---|---|
| `/gfx diag` | valeur de chaque variable graphique gérée, celles absentes du client, et les variables graphiques du client pas encore gérées |
| `/fmac diag` | sorts des macros prêtes trouvés ou absents dans ce client, classe par classe |
| `/prep diag` | chaque objet de la base (vrai nom et niveau requis, écarts signalés), objets absents, sorts de classe, consommables de tes sacs inconnus de la base, analyse actuelle |
| `/floot diag` | numéro de chaque objet de la liste de référence et son nom dans ce client (les numéros non vérifiés sont signalés), nombre d'objets vus, butin noté par donjon |
| `/fp diag` | toutes les parties de ForeverCompagnon d'un coup, avec les méthodes retenues par le lien avec le jeu |
| `/fp test` / `/fp sonde` | auto-test en jeu de chaque fonction / fonctions présentes et absentes du client |
| `/fheal diag` | relevé du jeu et conversions mesurées, sorts de soin avec leur description brute et ce que l'addon en lit, sorts de soin du grimoire inconnus de la base, caractéristiques de chaque pièce portée |

Chaque texte commence par la version du client, le numéro d'interface, la langue, le personnage et les addons chargés. Le module est commun (`tools/Diag.lua`, copié dans chaque addon par `tools/sync-shared.sh`, comme l'icône commune `tools/Hub.lua` et le tutoriel `tools/Tour.lua` ; dans ForeverCompagnon, une seule copie enveloppée, `ForeverCompagnon/Shared/`, appliquée à chaque partie).

## Compatibilité

Les addons ne visent que **WoW Forever** : chaque `.toc` déclare `## Interface: 16000, 16001`. Le client de Forever est un client moderne (API du retail habillée en classique) : beaucoup de fonctions classiques n'existent pas (`GetItemInfo`, `GetSpellInfo`…) et certaines valeurs sont secrètes en combat ou tout le temps (mana actuelle). `tools/forever_api_check.py` vérifie le code contre la liste complète de l'API du client. Si une mise à jour du jeu change le numéro d'interface, ajoute-le à la ligne `## Interface:` (`/dump select(4, GetBuildInfo())` en jeu pour l'obtenir).

## Développement

- `luacheck ForeverGFX ForeverMacros ForeverCompagnon` vérifie le code (lancé automatiquement à chaque push).
- `lua5.1 tests/prep_sim.lua fr` (et `en`), `tests/heal_sim.lua`, `tests/loot_sim.lua`, `tests/metiers_sim.lua`, `tests/gfx_sim.lua` et `tests/macros_sim.lua` simulent chaque addon avec une API WoW imitée (chaque partie de ForeverCompagnon seule, par `tests/compagnon_load.lua`) ; `tests/compagnon_sim.lua` charge ForeverCompagnon comme dans le jeu, sur le profil du client Forever (`tests/forever_client.lua`, issu de `/fp sonde`) ; `tests/classes_sim.lua` le charge pour les 9 classes, côté Alliance et Horde. `tests/wowmock.lua` : API WoW imitée commune. Lancés aussi à chaque push.
- `python3 tools/forever_api_check.py` : appels à des fonctions absentes du client de WoW Forever (sans repli) ou interdites aux addons, d'après la liste de l'API du client relevée par Thunderz ([forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit), MIT) dans `tests/data/forever_api.json`. Lancé aussi à chaque push.
- Publier une version : `git tag v2.1.0 && git push --tags`. GitHub Actions inscrit la version dans les TOC et attache les archives à la release (ForeverMacros et ForeverCompagnon gardent le numéro de leur TOC).

---

## English

WoW addons for **WoW Forever** only. **ForeverGFX** (`/gfx`) offers one-click graphics presets, automatic tuning toward a target FPS, an FPS counter, context-based switching and an expert view of every graphics variable. **ForeverMacros** (`/fmac`) offers ready-made class macros (localized automatically through spell IDs), a step-by-step builder with a sequence mode, live syntax checking and macro backup/restore. **ForeverCompanion** (`/fp`, WoW Forever) gathers healing, gear, dungeon prep and professions in one window with a "Now" screen (what to do at your level), an in-game self-test and a client probe. Its healing part (`/fheal`) turns stats and items into plain effects (HP, mana, healing per second, mana longevity) in item tooltips, a character-sheet panel and change announcements, calibrated on your character and your real spell usage. Its preparation part (`/prep`) checks your dungeon/raid readiness by class, role and level (consumables at the best usable rank, class reagents, buffs, gear, trainer reminder) with a shopping list and one-click vendor purchase. All addons are fully translated (French and English) and include a guided tutorial.

## Licence

Distribué sous licence [MIT](LICENSE) : libre d'utilisation, de modification et de redistribution, à condition de conserver la mention de copyright.
