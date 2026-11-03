# ForeverGazette → Discord

Ce petit programme poste les éditions de **ForeverGazette** dans un salon Discord, avec la photo de une.

L'addon ne peut ni écrire de fichier ni aller sur Internet : il range ses éditions dans sa sauvegarde
(`WTF\Account\<compte>\<royaume>\<personnage>\SavedVariables\ForeverGazette.lua`), que le jeu écrit **à la déconnexion
ou après un `/reload`**. Le programme lit ce fichier sur ton PC et envoie ce qui est nouveau.

## Installation (Windows)

1. Installe [Python 3](https://www.python.org/downloads/) (coche « Add Python to PATH »).
2. Mets le dossier `gazette-discord` où tu veux (par ex. `Documents\gazette-discord`).
3. Dans Discord : **Paramètres du salon → Intégrations → Webhooks → Nouveau webhook**, puis **Copier l'URL du webhook**.
   Choisis le salon où tu veux lire ta gazette (celui de friday, par exemple).
4. Copie `gazette_discord.example.ini` en `gazette_discord.ini` et remplis :
   - `webhook` : l'URL copiée (garde-la pour toi : elle permet de poster dans le salon) ;
   - `wow_dirs` : le dossier du client qui contient `WTF` et `Screenshots`, par ex.
     `C:\Program Files (x86)\World of Warcraft\_anniversary_` ; plusieurs dossiers séparés par `;` (Forever, TBC…).
5. Essai sans rien envoyer : `python gazette_discord.py --today --dry-run`

## Utilisation

| Commande | Effet |
|---|---|
| `python gazette_discord.py` | poste les éditions des jours terminés pas encore postées |
| `python gazette_discord.py --today` | poste aussi l'édition du jour, puis la **met à jour** (même message) si elle change |
| `python gazette_discord.py --weekly` | poste aussi l'Hebdo (une fois par jour) |
| `python gazette_discord.py --watch --today --weekly` | tourne en continu : vérifie chaque minute |

Le plus simple : lancer `--watch --today --weekly` en même temps que le jeu (raccourci ou tâche planifiée
« À l'ouverture de session »). Après chaque déconnexion ou `/reload`, la gazette du jour arrive dans Discord.

## Bon à savoir

- Ce qui a été posté est noté dans `gazette_discord_state.json` : rien n'est posté deux fois. Une édition d'un jour terminé
  n'est plus modifiée, sauf si elle avait été postée pendant ce jour-là (elle reçoit alors sa version finale).
- La photo de une est cherchée dans le dossier `Screenshots` du client (nom exact, ou à 5 secondes près). Une capture de plus de 9 Mo
  est ignorée (limite des webhooks Discord).
- Les messages n'envoient aucune mention (@).
- Seulement certains personnages : `characters = Machin, Bidule` dans le fichier `.ini`.
