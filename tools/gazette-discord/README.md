# Compagnon ForeverGazette : PDF, image et Discord

Ce petit programme fait de chaque édition de **ForeverGazette** une vraie page de journal, **en PDF et en image, avec tes
captures d'écran**, et peut la poster dans un salon Discord.

Pourquoi un programme à part ? Un addon WoW ne peut ni écrire de fichier ni lire tes captures d'écran : il range ses éditions
dans sa sauvegarde (`WTF\Account\<compte>\<royaume>\<personnage>\SavedVariables\ForeverGazette.lua`), que le jeu écrit
**à la déconnexion, après un `/reload` ou avec le bouton « PDF » de la gazette**. Le compagnon lit ce fichier sur ton PC.

## Installation (Windows)

1. Installe [Python 3](https://www.python.org/downloads/) (coche « Add Python to PATH »).
2. Installe Pillow (pour le PDF et l'image) : `python -m pip install pillow`
3. Mets le dossier `gazette-discord` où tu veux (par ex. `Documents\gazette-discord`).
4. Copie `gazette_discord.example.ini` en `gazette_discord.ini` et remplis au moins `wow_dirs` : le dossier du client qui
   contient `WTF` et `Screenshots`, par ex. `C:\Program Files (x86)\World of Warcraft\_anniversary_` (plusieurs dossiers
   séparés par `;`).
5. Facultatif, Discord : **Paramètres du salon → Intégrations → Webhooks → Nouveau webhook → Copier l'URL**, à mettre dans
   `webhook`.
6. **Démarrage automatique** : double-clique sur `installer-demarrage.bat`. Le compagnon se lance tout de suite, en fond (sans fenêtre),
   et à chaque ouverture de session Windows ; son journal est `gazette_discord.log`. Pour annuler : `retirer-demarrage.bat`.
   (À la main : `python gazette_discord.py --watch --today --weekly`.)

## En jeu

Clique sur **PDF** dans la gazette (ou `/gazette pdf`) : l'interface se recharge pour enregistrer, et dans la minute
tu trouves dans `Documents\ForeverGazette\<royaume>\<personnage>\` :

- `2026-11-03.pdf` : l'édition mise en page (une avec la photo, rubriques sur deux colonnes, photos des autres grands moments, bilan) ;
- `2026-11-03.png` : la même page en image (`-p2.png`… si l'édition tient sur plusieurs pages) ;
- `hebdo\2026-11-03.pdf` et `.png` : L'Hebdo (avec `--weekly`).

Sans clic, la même chose se fait à chaque déconnexion.

## Commandes

| Commande | Effet |
|---|---|
| `python gazette_discord.py` | traite les éditions des jours terminés pas encore faites |
| `python gazette_discord.py --today` | aussi l'édition du jour, refaite (et reposée sur Discord) si elle change |
| `python gazette_discord.py --weekly` | aussi L'Hebdo |
| `python gazette_discord.py --watch --today --weekly` | tourne en continu, vérifie chaque minute |
| `python gazette_discord.py --dry-run --today` | montre ce qui serait fait, sans rien écrire ni envoyer |

## Bon à savoir

- Écran ultra-large (21:9, 32:9 comme un Samsung G9) : les captures sont recadrées au centre (là où est ton personnage) pour garder des photos bien proportionnées.
- Les photos sont cherchées dans le dossier `Screenshots` du client (nom exact, ou à 5 secondes près). Format conseillé :
  JPEG (réglage par défaut du jeu).
- Ce qui a été traité est noté dans `gazette_discord_state.json` : rien n'est fait deux fois. Une édition d'un jour terminé
  n'est plus refaite, sauf si elle avait été faite pendant ce jour-là (elle reçoit alors sa version finale).
- Sur Discord, `discord = image` poste la page en image (lisible directement dans le salon) ; `discord_pdf = yes` joint le PDF.
  Aucune mention (@) n'est envoyée. Une image ou un PDF de plus de 9 Mo n'est pas joint (limite des webhooks).
- Sans Pillow, le compagnon poste seulement le texte (et la photo de une) sur Discord.
- Seulement certains personnages : `characters = Machin, Bidule` dans le fichier `.ini`.
