# Journal des versions

## ForeverGFX 2.1.7 / ForeverMacros 1.3 / ForeverGazette 1.2 / ForeverPrep 1.0
- **Nouvel addon ForeverPrep** (`/prep`, WoW Forever seulement) : « Prêt pour le donjon ? ». Consommables au meilleur rang utilisable à ton niveau (soins, mana, nourriture, boisson, bandages, nourriture de stats, élixirs et flacons en raid), composants de classe (selon les sorts connus), améliorations personnelles et de groupe, familier, poisons/imprégnations, durabilité, sacs, emplacements vides, talents, rappel du maître de classe, pierre de foyer. Donjon ou raid, rôle deviné par les talents. Liste de courses et achat en un clic chez le marchand. Ouverture automatique (s'il manque quelque chose) à l'entrée d'une instance, à l'appel et lors d'une recherche de groupe/donjon.
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
