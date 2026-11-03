# Journal des versions

## Prochaine version
- Compagnon : `oui` / `non` acceptés dans `gazette_discord.ini` (en plus de `yes` / `no`) ; l'exemple les utilise.


## ForeverGFX 2.2.1 / ForeverLoot 1.1
- ForeverLoot : **liste de référence de WoW Forever** à la place de celle du classique — prêtre soigneur niveau 60 avant les raids, d'après la liste de kami-labs.fr (calculée le 02/11/2026 avec le simulateur wowsims/forever) : ensemble du dévot, Peau du Fauve, étoffe lunaire, Sceau de Rivendare, Miséricorde de calcinite, Livre des morts, et les nouveautés de Forever (Anneau de canaliste, Champ de sérénité, Baguette brillante), avec l'**enchantement conseillé** pour chaque pièce.
- Autres addons : inchangés (numéro de ForeverGFX aligné sur le tag).

## ForeverGFX 2.2.0 / ForeverMacros 1.5 / ForeverGazette 1.4 / ForeverPrep 1.2 / ForeverHeal 1.2 / ForeverLoot 1.0
- **Nouvel addon ForeverLoot** (`/floot`, `/bis`, WoW Forever) : BiS calculé pour ton personnage à partir des objets réellement vus (modèle de ForeverHeal pour le prêtre, poids simplifiés pour les autres classes), liste de référence du prêtre soigneur (classique, avant les raids, à vérifier pour Forever), conseil BESOIN / Cupidité sur les jets de butin, meilleure récompense de quête mise en évidence, butin des donjons noté par boss pour tous tes personnages, lignes dans les infobulles.
- **Icône commune « Forever »** autour de la minicarte : un clic ouvre le menu des cinq addons ; elle remplace les icônes séparées à la première connexion (`/forever separees` pour les remettre, `/forever commune` pour revenir).
- ForeverHeal : **conseiller de rangs** (excédent mesuré par rang, rang inférieur qui suffirait, mana économisée, création des macros de rang en un clic) ; **alerte de mana en combat** (« à sec dans ~14 s ») ; **meilleurs objets de tes sacs** (tissu, dague, masse, bâton, baguette) ; panneau défilant ; infobulles mémorisées (recalculées seulement quand tes caractéristiques, ton équipement ou tes sorts changent).
- ForeverGazette : **rubrique Donjons** (boss, durée, morts du groupe, tes soins et ton excédent), suivie de l'entrée à la sortie, même après un /reload.
- ForeverPrep : analyses regroupées (au plus une toutes les 2,5 s) et suspendues en combat.
- Compagnon 1.3 : **démarrage automatique sous Windows** (`installer-demarrage.bat` / `retirer-demarrage.bat`, journal dans un fichier).
- Publication : notes de version tirées de ce journal ; modules communs (`tools/Diag.lua`, `Hub.lua`, `Tour.lua`) ; simulations de ForeverGFX et ForeverMacros, les cinq addons testés à chaque push.

## ForeverGFX 2.1.9 / ForeverMacros 1.4 / ForeverGazette 1.3 / ForeverPrep 1.1 / ForeverHeal 1.1
- **Commande de diagnostic dans tous les addons** (`/gfx diag`, `/fmac diag`, `/gazette diag`, `/prep diag`, `/fheal diag`) : un texte à copier-coller à Claude avec ce que le client WoW Forever donne vraiment (versions, variables, sorts, objets, textes du jeu, valeurs mesurées), pour adapter les addons à cette base classique modifiée. Module commun `tools/Diag.lua`. **Bouton « Diag »** dans la barre de titre de chaque fenêtre (à gauche du « ? »), pour lancer le diagnostic sans commande écrite.

## ForeverGFX 2.1.8 / ForeverMacros 1.3 / ForeverGazette 1.2 / ForeverPrep 1.0 / ForeverHeal 1.0
- **Nouvel addon ForeverHeal** (`/fheal`, WoW Forever, prêtre) : ce que chaque caractéristique et chaque objet change vraiment, en clair. Infobulle des objets comparée à ce que tu portes (« +35 Endurance → +350 PV », « +22 soins → +19 par Soins supérieurs », puis soin moyen, soins par seconde, autonomie), panneau à côté de la fiche personnage (mesures, sorts de référence, ce que vaut +10 dans chaque caractéristique), annonce à chaque changement hors combat. Conversions mesurées sur ton personnage, montants des sorts lus dans le jeu, mélange de sorts et effet des talents tirés de tes lancers réels.
- Autres addons : inchangés (numéro de ForeverGFX aligné sur le tag).

## ForeverGFX 2.1.7 / ForeverMacros 1.3 / ForeverGazette 1.2 / ForeverPrep 1.0
- **Nouvel addon ForeverPrep** (`/prep`, WoW Forever seulement) : « Prêt pour le donjon ? ». Consommables au meilleur rang utilisable à ton niveau (soins, mana, nourriture, boisson, bandages, nourriture de stats, élixirs et flacons en raid), composants de classe (selon les sorts connus), améliorations personnelles et de groupe, familier, poisons/imprégnations, durabilité, sacs, emplacements vides, talents, rappel du maître de classe, pierre de foyer. Donjon ou raid, rôle deviné par les talents. Liste de courses et achat en un clic chez le marchand. Ouverture automatique (s'il manque quelque chose) à l'entrée d'une instance, à l'appel et lors d'une recherche de groupe/donjon. **Bouton « Prépa » à l'écran** (déplaçable, couleur selon ton état : vert, orange, rouge) pour lancer la préparation à la main, en plus de l'icône de minicarte et de `/prep`.
- ForeverGFX, ForeverMacros, ForeverGazette : inchangés (numéro de ForeverGFX aligné sur le tag).

## ForeverGFX 2.1.6 / ForeverMacros 1.3 / ForeverGazette 1.2
- ForeverGazette : **photos sans l'interface** (option activée par défaut) : l'interface est masquée une fraction de seconde le temps de la capture, comme Alt+Z, puis rétablie (hors combat seulement ; rétablie aussi dès qu'un combat commence).
- Compagnon 1.2 : **écrans ultra-larges (21:9, 32:9, ex. Samsung G9 en 5120×1440)** : les captures sont recadrées au centre (2,35:1 pour la une, 1,9:1 pour les autres photos) au lieu de devenir des bandeaux très fins ; décodage réduit des JPEG 5K (plus rapide).
- ForeverGFX, ForeverMacros : inchangés (numéro de ForeverGFX aligné sur le tag).

## ForeverGFX 2.1.5 / ForeverMacros 1.3 / ForeverGazette 1.1
- ForeverGazette : **PDF et image de chaque édition, avec tes captures d'écran**. Bouton « PDF » (et `/gazette pdf`) : la gazette est enregistrée (rechargement de l'interface) et le compagnon, sur ton PC, en fait dans la minute une page de journal (une avec sa photo, rubriques sur deux colonnes, photos des autres grands moments, bilan) en PDF et PNG, rangée dans `Documents\ForeverGazette` et postée sur Discord en image si tu veux. Un addon ne peut pas écrire de fichier lui-même : c'est le compagnon qui les fabrique.
- ForeverGazette : icônes des objets dans la page en jeu ; L'Hebdo a ses photos ; titre du journal en majuscules accentuées (« SPÉCIAL ») ; photos du niveau et de l'épique dans la démo.
- Compagnon 1.1 (`tools/gazette-discord`) : PDF/PNG (Pillow), Discord facultatif (image, PDF, texte ou image + texte), polices vérifiées pour les accents.
- ForeverGFX, ForeverMacros : inchangés (numéro de ForeverGFX aligné sur le tag).

## ForeverGFX 2.1.4 / ForeverMacros 1.3 / ForeverGazette 1.0
- **Nouvel addon ForeverGazette** (`/gazette`) : la gazette de ton personnage. Chaque journée de jeu devient une édition de journal : une (le plus grand moment du jour), rubriques (exploits, voyages, butin et fortune, nécrologie, carnet mondain, métiers, quêtes) et bilan du jour.
  - Moments notés : niveaux, boss, élites rares, nouvelles zones et donjons, objets rares/épiques/légendaires, paliers d'or, morts (avec le coupable), victoires JcJ, duels, réputation, métiers, recettes, hauts faits (retail), quêtes, compagnons de groupe.
  - Photo de une (capture d'écran automatique), trois tons (sérieux, tabloïd, épique), sommaire, L'Hebdo, export Markdown/texte, partage en guilde, en groupe ou en « Dire », édition de démonstration (`/gazette demo`), tutoriel, icône de minicarte, français et anglais.
  - Compagnon Discord (`tools/gazette-discord`, archive `ForeverGazette-Discord`) : poste chaque édition dans un salon par webhook, avec la photo.
- ForeverGFX, ForeverMacros : inchangés (numéro de ForeverGFX aligné sur le tag).

## ForeverGFX 2.1.3 / ForeverMacros 1.3
- ForeverMacros : bibliothèque propre au retail (77 macros, 13 classes dont Chevalier de la mort, Moine, Chasseur de démons et Évocateur ; sorts vérifiés pour Midnight). Forever et TBC Anniversary gardent la bibliothèque TBC.
- ForeverMacros : les macros dont un sort n'existe pas dans le jeu lancé sont masquées (nombre indiqué sous la liste).
- ForeverMacros : les avertissements propres à Midnight (marqueurs, canaux de discussion) ne s'affichent plus que sur retail (ils apparaissaient à tort sur Forever).
- ForeverGFX : inchangé (numéro aligné sur le tag).

## ForeverGFX 2.1.2 / ForeverMacros 1.2
- Publication : WowUp reconnaît le client Forever (type « forever » dans release.json, au lieu de « classic »).

## ForeverGFX 2.1.1 / ForeverMacros 1.2
- Publication : archive commune ForeverAddons (installable et mise à jour par WowUp depuis GitHub, avec release.json), chaque addon garde son propre numéro de version.

## ForeverGFX 2.1 / ForeverMacros 1.2
- ForeverGFX : réglage automatique selon un objectif de FPS, compteur de FPS à l'écran, liste expert plus rapide (recherche précalculée).
- ForeverMacros : recherche dans les macros prêtes, sauvegarde et restauration de toutes les macros.
- Les deux : compatibilité LibDataBroker / LibDBIcon, version des données sauvegardées.

## ForeverGFX 2.0 / ForeverMacros 1.1
- Vue simple pour débutants, tutoriel guidé, icônes de minicarte.
- ForeverMacros : 60 macros prêtes pour les 9 classes, mode séquence.
- Compatibilité TBC Anniversary.

## ForeverGFX 1.x / ForeverMacros 1.0
- Premières versions : liste des variables graphiques, préréglages, profils ; constructeur et vérification de macros.
