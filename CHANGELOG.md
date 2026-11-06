# Journal des versions

## v3.4.3 (ForeverCompagnon 3.4.3)
- **Cadres de groupe et de raid de Blizzard gardés** à côté d'HealBot, en secours si HealBot a un souci (à ta demande). Reclique sur « Configurer HealBot » pour les faire revenir.

## v3.4.2 (ForeverCompagnon 3.4.2), d'après ta capture
- **Skins HealBot : icône de rôle** (soigneur, tank, dégâts) sur chaque barre : HealBot ne la montre qu'à la place de l'icône de classe, qui était coupée dans ses skins d'origine.
- **Cadre de groupe de Blizzard masqué** dès la configuration (HealBot ne relisait ce réglage qu'au changement de groupe).

## v3.4.1 (ForeverCompagnon 3.4.1)
- **Skins HealBot non importés en français** (« import impossible (HEALBOT_SORTBY_GROUP) ») : HealBot range ses skins intégrés sous leur nom anglais (« Group », « Raid 40 ») au chargement, puis sa traduction renomme ses variables (« Groupe »). Les skins sont maintenant retrouvés par le nom écrit dans leurs données, quelle que soit la langue.
- Le message final ne parle plus des skins quand leur import a échoué.

## v3.4.0 (ForeverCompagnon 3.4.0) : HealBot réglé pour le prêtre
- **Configurer HealBot** (onglet Addons, ligne HealBot, ou `/fp healbot`) : ForeverCompagnon règle HealBot Continued avec les fonctions d'HealBot lui-même.
  - **Clics** d'après tes sorts : gauche = gros soin efficace (Soins inférieurs, puis Soins dès le niveau 16, Soins supérieurs au 40) ; Maj+gauche = soin rapide (Soins inférieurs rang 2 avant le niveau 16, Soins inférieurs ensuite, Soins rapides dès le 20) ; droit = Rénovation ; Maj+droit = Bouclier ; Ctrl+droit = Prière de soins ; milieu = Guérison des maladies (Abolir la maladie) ; Maj+milieu = Dissipation de la magie ; Ctrl+gauche = Résurrection ; Alt+gauche = Robustesse. Sans rang, HealBot lance toujours le rang le plus haut.
  - **Nouveau sort appris** : les clics posés par ForeverCompagnon sont mis à jour tout seuls (jamais en combat) ; un clic que tu as changé toi-même n'est plus touché.
  - **Cadres** : deux skins importés par la fonction d'import d'HealBot, tirés de ses skins « Groupe » et « Raid 40 » : « Forever Groupe » (seul et en groupe, barres 120×36) et « Forever Raid » (raid de 10 à 40, une colonne par groupe, sans familiers). Vie **manquante** affichée (« -432 »), rôles, tri par groupe puis rôle, alerte sous 90 % en combat. HealBot passe tout seul de l'un à l'autre.
  - **Sauvegarde** : tes clics et ton choix de skins d'avant sont gardés ; `/fp healbot annuler` les remet. `/fp healbot voir` liste les clics prévus.

## v3.3.4 (ForeverCompagnon 3.3.4 / ForeverGazette 1.7.2) : noms secrets en donjon
- **Erreur au butin en donjon** (« Loot/Core.lua:174: attempted to index a table that cannot be indexed with secret keys », Les Mortemines) : en donjon, le jeu rend la cible secrète (nom, classement, niveau). Le butin est maintenant rangé sous le boss de la rencontre terminée, et aucune valeur secrète n'est jamais prise comme clé ni comparée.
- Même protection, par précaution, dans la Gazette (ennemis notables, fin de rencontre, compagnons de groupe), la Préparation (membres du groupe sans un buff) et la mémoire des marchands. Nouvelle fonction commune `ns.Clear` (valeur utilisable ou rien).

## v3.3.3 (ForeverCompagnon 3.3.3)
- **Cadre des changements (soigneur)** : une seule couleur par ligne (« −6 Endurance » entièrement en rouge, plus de « −6 » rouge et « Endurance » vert) ; la ligne de résultat (« Soin moyen +1 · +0,4 soins/s · autonomie… ») passe en plus petit sur deux lignes au lieu de déborder du cadre.

## v3.3.2 (ForeverCompagnon 3.3.2), d'après tes tests
- **Fenêtre de métier toujours pas lue** (le jeu disait : métier « », n° 0, aucune recette) : relecture quand le jeu signale que les données sont prêtes (`TRADE_SKILL_DATA_SOURCE_CHANGED`), liste filtrée de la fenêtre si la liste complète est vide, métier déduit de la première recette ou de `GetProfessionChildSkillLineID`. Si ça échoue encore, l'auto-test et `/metiers diag` donnent tout ce que le jeu dit de la fenêtre ouverte.
- **Alerte Mana basse** : le texte tient sur une ligne au-dessus de la barre (« (185 / 821) » passait dessous).

## v3.3.1 (ForeverCompagnon 3.3.1), d'après tes captures
- **Cadre des changements déplaçable** : glisser pour le déplacer (plus besoin de Maj), position retenue même quand la fiche personnage est ouverte ; clic droit pour le fermer ; `/fp flash place` pour revenir à la place automatique.
- **Clic droit « y aller » sans effet dans la fenêtre Équipement** : elle dessine ses propres cartes, qui n'écoutaient que le clic gauche. Corrigé.
- **Guide-moi ne trouvait pas de vendeur** pour la nourriture et la boisson : l'extraction d'All The Things classait les vendeurs sans prix affiché comme « butin ». Les vendeurs sont maintenant reconnus par l'en-tête « Vendeurs » d'ATT et ses listes d'articles (2 061 sources « vendeur » au lieu de 468).
- **Marchands visités retenus** (position et articles) : Guide-moi choisit le plus proche, y compris ceux que la base ne connaît pas (aubergistes hors des capitales).
- **Fenêtre de métier non reconnue** (« métier nil, 0 recettes ») : le métier ouvert est maintenant reconnu par son numéro (couture 197…), par un nom qui contient le sien (« Couture classique »), ou, si le jeu ne dit rien, par sa première recette. L'auto-test et le Diag des Métiers affichent le nom exact donné par le jeu.
- **Alerte « Mana basse » bien plus visible** : cadre sombre à bordure orange qui pulse, icône de potion, texte gros et contouré, **barre de mana** (remplie par le jeu), placée sous le centre de l'écran pour ne pas se mêler au texte de combat ; glisser pour la déplacer (position retenue) ; `/fheal alerte test` pour la voir hors combat.
- Prix affichés sans « 0 pc » inutile (« 10 pa » au lieu de « 10 pa 0 pc »).
- **Écran Maintenant / Équipement** : « clic droit : y aller » passe sur la ligne de la source ; le nom et les étiquettes trop longs sont coupés au lieu de chevaucher le gain (« Kaléidoscope d'œil de serpent »).

## v3.3.0 : cadre des changements de caractéristiques (ForeverCompagnon 3.3.0)
- **Nouveau cadre « Flash »**, pour toutes les classes : quand tu équipes un objet hors combat, un cadre doré apparaît **à côté de ton personnage** (contre ta fiche personnage si elle est ouverte) : l'objet équipé (icône à la couleur de sa qualité), une ligne par caractéristique avec son icône, la valeur en vert ou en rouge en grand et ce qu'elle change dessous, le résultat sur tes soins pour un soigneur. Effets : éclat d'étoile, lignes qui glissent l'une après l'autre, valeurs qui montent au-dessus de ta tête comme du texte de combat, son de butin. Remplace l'ancien texte en haut de l'écran (le choix « dans la discussion » de `/fheal chat` reste).
- `/fp flash` : active ou coupe ; `/fp flash test` : aperçu. Survol pour le garder, clic pour le fermer, Maj+glisser pour le déplacer.
- Classes sans partie Soins : relevé générique (Force, Agilité, Endurance, Intelligence, Esprit, puissance d'attaque et des sorts, soins, critique, armure, PV et mana max).

## v3.2.0 : ForeverCompagnon autonome (ForeverCompagnon 3.2.0)
- **Plus besoin d'autres addons.** La base WoW Forever d'**All The Things** (licence MIT, texte de la licence joint) est **incluse** : où obtenir ~13 000 objets (boss et donjon, PNJ, vendeur et prix, quête, zone et coordonnées, faction, réputation) et les recettes de tous les métiers. Régénérée avant chaque version (`tools/update-att-data.sh`, extracteur `tools/att_extract.lua` qui lit la base d'ATT dans un bac à sable). Noms demandés au jeu, dans ta langue, et retenus.
- **Butin des donjons** sans DungeonJournal : tiré de la même base (1 634 objets).
- **Flèche de navigation intégrée** (à la TomTom) : « Guide-moi » (Préparation) pointe la flèche vers le vendeur le plus proche ; **clic droit** sur un objet (Équipement) ou une recette (Métiers) : flèche vers le lieu le plus proche où l'obtenir ; `/fp way x y [nom]` et `/way` (si TomTom n'est pas là). Distance, temps à pied, arrivée ; repère du jeu sur la carte.
- **Prix** : bouton « Relever les prix » sur l'hôtel des ventes (relevé complet du jeu, une fois toutes les 15 minutes) ; utilisés par la Préparation et les Métiers sans Auctionator.
- **Banque et rerolls** retenus par l'addon (sans Syndicator) : composants comptés partout, objet « chez Machin » signalé.
- **Corrigé** : les Métiers comptaient 0 composant en sac sur Forever (`GetItemCount` n'existe pas sur ce client).
- Onglet Addons : All The Things, DungeonJournal, Auctionator, Syndicator et TomTom rangés dans « Intégrés (plus nécessaires) ». Auto-test : sources, flèche, inventaire et prix.

## v3.1.0 : ForeverCompagnon, toutes classes, races et factions (ForeverCompagnon 3.1.0)
- **ForeverPrêtre devient ForeverCompagnon** (`/fp`, `/compagnon`) : pour **toutes les classes, races et factions**. L'ancien dossier ForeverPretre devient une coquille vide (supprimable) ; réglages remis à zéro.
- **Rôle** à choisir sur l'écran Maintenant (tank, soins, dégâts mêlée, dégâts sorts) : le client de Forever ne donne pas les arbres de talents aux addons. Il règle l'Équipement et la Préparation.
- **Équipement** : poids des caractéristiques par classe **et par rôle** (défense et armure pour un tank, force/agilité et DPS de l'arme en mêlée, puissance des sorts et toucher pour les lanceurs, soins pour les soigneurs).
- **Métiers : tous les métiers** (alchimie, forge, travail du cuir, ingénierie, cuisine, secourisme, herboristerie, minage, dépeçage, pêche, en plus de couture et enchantement) : compétence et rang, rappel du maître, meilleurs crafts d'après la fenêtre du métier, recettes à apprendre (All The Things), métiers conseillés selon la classe (forge + minage pour un guerrier…). Guides pas à pas : couture et enchantement.
- **Soins : druide, paladin et chaman** en plus du prêtre (Toucher guérisseur, Rétablissement, Récupération ; Lumière sacrée, Éclair lumineux ; Vague de soins, Vague de soins inférieurs, Salve de guérison), mêmes calculs (soins/s, autonomie, conseils de rang, infobulles). L'onglet Soins n'apparaît que pour les soigneurs.
- **Onglet Addons** (`/fp addons`) : les addons utiles sur Forever, actifs, désactivés ou absents, ce qu'ils apportent, leur adresse à copier et « Activer ». Corrige l'auto-test qui disait DungeonJournal absent (autre nom de dossier).
- Test des 9 classes, Alliance et Horde, à chaque push (`tests/classes_sim.lua`).

## v3.0.3 (ForeverPretre 3.0.3 / ForeverGazette 1.7.1 / ForeverMacros 1.9.0) : WoW Forever seulement, relevé de forever-addon-kit
- **WoW Forever seulement** : TBC Anniversary et le retail ne sont plus pris en charge. Tous les `.toc` en `## Interface: 16000, 16001`, WowUp ne propose plus les addons que pour Forever, macros prêtes du retail (`LibraryRetail.lua`) et branches propres à TBC/retail retirées (ForeverMacros, ForeverGazette).
- **Contrôle automatique de l'API** (`tools/forever_api_check.py`, à chaque push) : tout appel à une fonction absente du client de WoW Forever sans solution de repli, ou à une fonction interdite aux addons (`ReloadUI`), est refusé. Référence : la liste complète de l'API du client (6 045 fonctions, 269 espaces de noms) relevée par Thunderz dans [forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) (MIT), copiée dans `tests/data/forever_api.json`. Premier passage : aucun appel dangereux, quelques protections rendues explicites.
- **Gazette : bouton PDF** : `ReloadUI()` est interdit aux addons sur Forever (le bouton déclenchait « action bloquée »). Sur Forever, la gazette est préparée et un message dit de taper `/reload` ; sur TBC, rien ne change.
- **Auto-test : sauvegardes relues ?** Le kit a montré qu'en bêta le client ne relisait jamais les sauvegardes des addons ; une nouvelle ligne de `/fp test` le vérifie sur ton client (à refaire après un `/reload`).

## v3.0.2 (ForeverPretre 3.0.2) : alerte « Mana basse » malgré la mana secrète
- WoW Forever cache la mana actuelle aux addons, même hors combat. Le compte à rebours « à sec dans ~N s » reste impossible (il faut calculer sur la valeur), mais **l'alerte revient sous une autre forme** : en combat, « Mana basse : 23 % (190 / 821) » s'affiche sous 30 %. C'est **le jeu** qui compare (courbe en escalier donnée à `UnitPowerPercent`) et affiche les chiffres ; l'addon ne les lit jamais. Technique reprise de Full Mana Forever (KesaObscura, MIT).
- `/fheal alerte 25` : change le seuil (en %) ; `/fheal alerte` : active ou coupe.
- Auto-test : nouvelle ligne « mana comparée par le jeu » ; Diag des soins et sonde : disponibilité de `UnitPowerPercent` et des courbes.

## v3.0.1 (ForeverPretre 3.0.1), d'après ton premier auto-test et ta sonde
- Premier auto-test en jeu : 12 OK, 0 échec, aucune action bloquée. La sonde est devenue le profil du client Forever dans les tests (`tests/forever_client.lua`) : 29 fonctions classiques absentes (`GetItemInfo`, `GetItemCount`, `IsAddOnLoaded`, `GetSpellInfo`…). Tous les appels avaient déjà un repli moderne, et le test complet passe maintenant sur ce vrai profil.
- **Mana actuelle secrète même hors combat** sur WoW Forever (seul le maximum se lit) : l'alerte « à sec dans ~N s » ne peut pas fonctionner sur ce client. C'est maintenant dit clairement (auto-test, Diag des soins, `/fheal alerte`) au lieu d'un silence ; la sonde le relève (`secretPowerOutOfCombat`).

## v3.0.0 : ForeverPrêtre (ForeverGFX 3.0.0 / ForeverPretre 3.0.0 / ForeverGazette 1.7.0)
- **ForeverPrêtre** : ForeverHeal, ForeverLoot, ForeverPrep et ForeverMetiers ne font plus qu'un addon, avec **une seule fenêtre** : une barre d'onglets à gauche (Maintenant, Soins, Équipement, Préparation, Métiers), une seule fenêtre visible à la fois, à la même place. Les commandes restent (`/fheal`, `/floot`, `/prep`, `/metiers`) et passent par la même barre ; nouvelle commande `/fp`. Une seule entrée « Prêtre » dans l'icône Forever.
- **Écran « Maintenant »** : que faire à ton niveau, en un coup d'œil : ton prêtre (soins/s, autonomie, régénération), les meilleures améliorations d'équipement à portée et où les trouver, ce qu'il manque avant un donjon avec « Guide-moi vers le vendeur », la prochaine étape de tes métiers. En combat : dernier état, aucun calcul.
- **Lien avec le jeu** (`Compat.lua`) : un seul endroit pour les fonctions qui diffèrent sur le client de Forever (équiper, marchand, sacs, sorts, mana secrète en combat).
- **Auto-test en jeu** (`/fp test`) : chaque fonction importante essayée pour de vrai sur ton client, rapport à copier (OK, échec, non testé et pourquoi).
- **Sonde du client** (`/fp sonde`) : fonctions présentes et absentes de ton client ; le rapport devient le profil du client Forever dans les tests hors jeu (`tests/forever_client.lua`).
- **Diag commun** (`/fp diag`) : toutes les parties en un texte.
- Les anciens dossiers ForeverHeal, ForeverLoot, ForeverPrep et ForeverMetiers deviennent des coquilles vides qui se désactivent (supprimables). **Les réglages repartent de zéro.**
- **ForeverGazette 1.7.0** : le compagnon PDF/Discord est livré dans le dossier de l'addon (`Companion`) et **se met à jour tout seul** depuis cette copie (au lancement puis toutes les heures). Il faut recopier une dernière fois `gazette_discord.py` et `gazette_render.py` à la main (ceux d'avant ne savent pas se mettre à jour).
- Modules communs : une seule copie dans ForeverPrêtre (`Shared/`), en-têtes de liste cliquables.


## ForeverGFX 2.4.10 / ForeverLoot 2.3.2
- **Bouton « Équiper » de l'alerte sans effet** : le client de WoW Forever n'a plus `EquipItemByName` en global. Le bouton passe par `C_Item.EquipItemByName`, sinon prend l'objet dans le sac et l'équipe ; si l'objet est introuvable, un message le dit (l'alerte reste affichée) au lieu de se fermer sans rien faire.

## ForeverGFX 2.4.9 / ForeverGazette 1.6.2
- **Lieux en double** (gazette du 05/11/2026 : « Vue pour la première fois à Forgefer » puis « Aperçu à Forgefer ») : le client de WoW Forever présente Forgefer et la salle des Thanes comme des « scénarios », que la gazette prenait pour des donjons. Seuls donjons et raids comptent maintenant comme « première fois à… », et chaque lieu n'apparaît qu'une fois par édition (y compris les éditions déjà enregistrées).
- Compagnon PDF : plus de nom de fichier (« WoWScrnShot_….jpg ») sous la photo de une.

## ForeverGFX 2.4.8 / ForeverPrep 1.7.2 / ForeverMetiers 2.2
- ForeverMetiers : **erreur à l'ouverture d'un métier** (« Core.lua:143: attempt to call a nil value ») : le client de WoW Forever n'a plus les anciennes fonctions de métier (`GetTradeSkillLine`, `GetCraftInfo`…). La fenêtre est maintenant lue par l'API moderne `C_TradeSkillUI` (recettes apprises, difficulté, composants et ce que tu en as, recharge, clic pour ouvrir la recette) ; l'ancienne reste utilisée si un client l'a.
- ForeverPrep : **erreur chez le marchand** (« Core.lua:498: attempt to call a nil value ») : `GetMerchantItemInfo` n'existe plus sur le client de WoW Forever ; les articles sont lus par `C_MerchantFrame.GetItemInfo`. Le relevé des prix, le panneau « Tout acheter » et l'achat en un clic fonctionnent de nouveau.
- ForeverMetiers : lecture de la fenêtre du métier protégée ; une erreur éventuelle va dans le Diag (avec la méthode de lecture utilisée) au lieu de se répéter.

## ForeverGFX 2.4.7 / ForeverHeal 2.1.1 / ForeverGazette 1.6.1 (et module commun des autres)
- **« ForeverHeal provoque un grand nombre d'erreurs »** (« attempt to perform arithmetic on a secret number value », 36 fois) : en combat, le client de WoW Forever donne la mana sous forme de **valeur secrète**, inutilisable par les addons. L'alerte de mana en combat se met en veille au lieu de planter, et les calculs de ForeverHeal en combat réutilisent le dernier relevé fait hors combat.
- ForeverGazette : expérience et or comptés seulement quand le jeu donne des valeurs utilisables (même protection).
- Module commun : `ns.Plain` (nombre utilisable ou rien), pour tous les addons ; le Diag de ForeverHeal dit si la mana est secrète en combat.

## ForeverGFX 2.4.6 / ForeverPrep 1.7 / ForeverLoot 2.3 / ForeverHeal 2.1 / ForeverMetiers 2.1.1 / ForeverGazette 1.6
- **ForeverGazette (d'après ton premier PDF)** : « Alain a-t-e triché ? » devient « a-t-elle » / « a-t-il » (nouvelle variable {il}) ; 3 passages de niveau ou plus dans la journée = une seule ligne (« du niveau 2 au niveau 7 ») ; 3 recettes ou plus (maître) = une seule ligne (« 12 recettes apprises, dont… ») ; compagnon PDF : le bilan passe sur une colonne quand une ligne ne tient pas sur deux (plus de « Expérience gagnée : … » coupé).
- **ForeverPrep : à ton niveau, avec les prix, et « Guide-moi »** :
  - la liste de courses ne garde que ce qui **s'achète chez un marchand** (nourriture, eau, composants, munitions, poisons), au meilleur rang utilisable à ton niveau ; les potions et élixirs (pas vendus par les marchands) indiquent « à l'hôtel des ventes ou chez un alchimiste », avec le prix d'Auctionator ; « Tout acheter » les prend quand même si le marchand en vend ;
  - **prix** de chaque achat (prix réel relevé chez le marchand, sinon Auctionator, sinon estimation « ~ ») et **coût total** ;
  - bouton **« Guide-moi »** : active sur la minicarte le suivi des marchands utiles (nourriture et boissons, aubergiste, composants…) et, si All The Things connaît un marchand de l'objet sur ta carte, pose un **repère vers le plus proche** de ta faction (TomTom s'il est installé, sinon le repère du jeu).
- **ForeverLoot : alerte quand tu ramasses un objet qui t'améliore** (butin, récompense de quête, jet gagné) : en haut de l'écran, avec un son, l'icône, le gain et un bouton **« Équiper »** (hors combat) ; « à garder pour le niveau X » s'il faut monter un peu. Option dans les réglages.
- **ForeverHeal : « Mes sacs » voyait trop peu d'améliorations** (une robe +1 Esprit +2 armure était ignorée) : le score compte maintenant aussi la régénération de mana hors combat, l'armure, l'Endurance, l'Intelligence et l'Esprit ; le même score sert à l'infobulle, aux sacs, à ForeverLoot et à l'alerte. Titre de « Mes sacs » raccourci (il débordait).

## ForeverGFX 2.4.5 / ForeverLoot 2.2
- **ForeverLoot ne propose plus d'objets de l'autre faction** : les récompenses de quêtes réservées à la Horde (ou à l'Alliance) et le butin des boss qu'un seul camp peut combattre (indications de DungeonJournal) sont écartés, dans « À mon niveau » comme dans l'onglet Donjons.
- **« À mon niveau » tient compte du niveau de la source** : un objet sans niveau requis (ex. collier de Hache-tripes, récompense de quête) est jugé d'après son niveau d'objet, et un objet dont le donjon ou la quête est au-dessus du niveau choisi n'est plus proposé.

## ForeverGFX 2.4.4 / ForeverMetiers 2.1 / ForeverLoot 2.1
- **ForeverLoot : nouvel onglet « À mon niveau »** (ouvert par défaut, `/floot`) : pour chaque emplacement, **les 2 meilleurs objets pour toi que tu peux porter maintenant ou dans quelques niveaux** (choix : mon niveau, +3, +5, +10 niveaux), avec **où les obtenir** (donjon et boss ou quête d'après DungeonJournal, sinon All The Things) et le gain en soins/s. L'ancien onglet BiS devient « BiS niveau 60 » (`/floot bis`).
- **ForeverMetiers repensé autour de « que faire maintenant, à mon niveau ? »** (au niveau 5, la fenêtre proposait des enchantements de compétence 300 et des pièces de niveau 45) :
  - nouvel onglet **« Que faire ? »** (ouvert par défaut) : des **étapes numérotées** pour chaque métier. Métier pas encore appris : 1. l'apprendre chez le maître de la capitale la plus proche, 2. où trouver la première étoffe (humanoïdes de niveau 5 à 15), 3. la première recette. Métier appris : le maître à aller voir quand le plafond approche (et le niveau requis), l'étape en cours avec **ce qui te manque** et où trouver l'étoffe, les meilleurs crafts, puis **la prochaine chose utile** pour toi ;
  - **« Pour toi »** ne montre plus que ce qui est **à ta portée** : objets jusqu'à ton niveau + 5, recettes jusqu'à ta compétence + 30 (ce que tu sais faire, à apprendre maintenant, bientôt) ; sinon, il dit quelle sera la première chose utile et à quelle compétence ;
  - **« Recettes »** filtré de la même façon, avec un bouton **« Tout afficher »** pour le catalogue complet.

## ForeverGFX 2.4.3 / ForeverMetiers 2.0 (et module d'interface commun des autres)
- **Nouvelle fenêtre ForeverMetiers**, refaite de zéro dans le style de ForeverLoot : bandeaux de rubrique et **cartes** (icône encadrée de la couleur de qualité, nom, étiquettes, détail dessous, chiffre important à droite) :
  - **Montée** : bandeau du métier (compétence, rang), prochain rang en couleur quand il approche, carte de l'étape du guide, **une carte par composant** (« il en manque 4 » en rouge ou « ok » en vert, sacs / banque / rerolls, prix à droite), meilleurs crafts en cartes (couleur de difficulté, guide, à désenchanter, amélioration, coût par point à droite) ;
  - **Pour toi** : une carte par pièce portée (enchantée ou non, ce que tu sais faire, à apprendre maintenant, le meilleur à viser, gain en soins/s à droite) ; pièces de couture en cartes avec leur gain ;
  - **Désenchanter** : une carte par objet, avec ce qu'il donne et l'icône du résultat à droite ; clic droit pour le garder ; bouton « Désenchanter le premier » en bas ;
  - **Recettes** : cartes avec l'état (appris, à apprendre maintenant, compétence requise) et la source ; recettes d'All The Things en cartes ;
  - le **panneau à côté de la fenêtre du métier** utilise les mêmes cartes (clic pour sélectionner la recette) ;
  - les options passent dans une petite fenêtre (icône Options).
- Les cartes et bandeaux sont dans le module d'interface commun (`Kit.CardList`).

## ForeverGFX 2.4.2 / ForeverLoot 2.0
- **Nouvelle fenêtre ForeverLoot**, refaite de zéro :
  - chaque emplacement a son **bandeau** : icône de l'objet porté (ou de l'emplacement vide, comme la fiche personnage), nom en lettres de livre, ce que tu portes à droite ;
  - chaque objet est une **carte** : grande icône encadrée de la couleur de qualité, nom en couleur, étiquettes (niveau requis en rouge, « Référence », « nouveau », banque/rerolls), d'où il vient (boss et donjon, ATT, enchantement conseillé) en dessous, et **le gain pour toi en grand à droite** (« +2,9 soins/s ») avec le détail (soignés avant d'être à sec, PV) ;
  - les références de la liste Forever ont une **étoile** ;
  - en haut, les sources actives en pastilles (ForeverHeal, DungeonJournal, Syndicator, All The Things) ;
  - les options passent dans une petite fenêtre (icône Options) : plus de place pour la liste.
- L'onglet Donjons utilise les mêmes cartes, par donjon et par boss.

## ForeverGFX 2.4.1 / ForeverLoot 1.8.1 / ForeverMetiers 1.6.1 / ForeverGazette 1.5.3 (et modules communs des autres)
- **Lignes illisibles dans ForeverLoot** (certaines en grandes lettres de livre) : une ligne qui avait servi de titre gardait la police des titres quand elle était réutilisée (dans WoW, une police posée directement l'emporte ensuite sur le style). Les titres ont maintenant leur propre texte ; même correction pour ForeverMetiers et la Gazette.
- All The Things : plus de « ALL THE THINGS » (la racine d'ATT) ni de « Quest #6502* » (quête pas encore chargée) comme source.

## ForeverGFX 2.4.0 / ForeverLoot 1.8 / ForeverMetiers 1.6 / ForeverMacros 1.8 / ForeverGazette 1.5.2 / ForeverPrep 1.6.1 / ForeverHeal 2.0.1
- **Même style pour toutes les fenêtres Forever** (comme la Gazette, ForeverPrep et ForeverHeal) :
  - ForeverLoot : titre doré avec icône, **onglets BiS / Donjons**, liste sur fond sombre encadré d'or, emplacements (Tête, Cou…) en lettres de livre avec filet doré ;
  - ForeverMetiers : titre doré, **onglets Montée / Pour toi / Désenchanter / Recettes**, liste encadrée, rubriques en lettres de livre ; même habillage pour le panneau à côté de la fenêtre du métier ;
  - ForeverMacros : titre doré, **onglets Bibliothèque / Constructeur**, bibliothèque encadrée, éditeur de macro bordé d'or ;
  - ForeverGFX : titre doré, liste des réglages encadrée, catégories en bandeaux dorés et lettres de livre, mode simple aux couleurs Forever.
- Module d'interface commun étendu (titre, fond encadré, titres de liste) et partagé par les sept addons.

## ForeverGFX 2.3.8 / ForeverHeal 2.0
- **« Retour au panneau » ne fonctionnait pas** : une erreur de logique (`cond and nil or x` vaut toujours `x` en Lua) laissait le panneau bloqué sur les objets des sacs. Remplacé par deux **onglets « Mon prêtre » / « Mes sacs »** ; la vérification automatique refuse désormais ce motif.
- **Nouveau panneau ForeverHeal**, dans le style des autres fenêtres : onglets, actions en icônes avec leur nom (Macros, Oublier, Annonces : « À l'écran » / « Discussion »), rubriques illustrées (caractéristiques, mélange de sorts, résultats, conseil de rangs, ce que vaut +10…) en lettres de livre sur fond sombre encadré d'or ; plus de texte de bouton coupé.
- Si un calcul du panneau échoue, l'erreur s'affiche dans le panneau et dans le Diag (« Calcul du panneau ») au lieu de le laisser figé.

## ForeverGFX 2.3.7 / ForeverPrep 1.6 / ForeverGazette 1.5.1 / ForeverHeal 1.9 / ForeverLoot 1.7 / ForeverMetiers 1.5 / ForeverMacros 1.7
- **« Échec d'une action d'interface » en fermant une fenêtre par la croix** (en combat) : la croix du modèle standard passe par une fonction réservée à Blizzard en combat ; dans toutes les fenêtres des addons Forever, elle cache maintenant la fenêtre directement.
- ForeverPrep **ouvert en combat : la fiche n'est plus vide**. Le jeu cache une partie des informations aux addons pendant un combat : la fiche montre la dernière analyse faite avant le combat (signalé dans le bandeau) et se met à jour dès la sortie du combat ; une analyse qui échoue s'affiche dans le bandeau au lieu de laisser la fenêtre vide.
- ForeverMetiers : le bouton « Désenchanter le premier » (bouton sécurisé) n'est plus dans la fenêtre elle-même, pour qu'elle puisse être fermée en combat ; il n'est jamais montré ni caché en combat.

## ForeverGFX 2.3.6 / ForeverGazette 1.5 / ForeverPrep 1.5
- **Nouvelle fenêtre de ForeverPrep**, même style :
  - **bandeau d'état** en haut : « Prêt pour le donjon ! » (coche verte), « Presque prêt : 2 point(s) à régler » (orange) ou « Pas encore prêt » (croix rouge), avec ton niveau et ton rôle ;
  - **onglets Donjon / Raid**, **rôle avec son icône** (clic pour en changer), actions en icônes : Actualiser, Options, Aide ;
  - chaque ligne avec la **pastille de l'appel** (coche, point d'interrogation, croix) et l'icône de l'objet ; rubriques illustrées avec le nombre de points à faire ; liste de courses avec rappel du bouton « Tout acheter ».
- ForeverPrep : plus de ligne « Potions de mana » avant le niveau où la première est utilisable (5) ; ce qui ne s'achète pas (bandages, potions de mana…) passe en orange (à faire) au lieu de rouge ; niveaux corrigés d'après le jeu (Élixir des Sages 38, Huile de sorcier inférieure 30, Huile de sorcier 40).
- Éléments d'interface communs (`tools/Widgets.lua`) : onglets, actions en icônes, cadres, pastilles d'état.
- **Nouvelle fenêtre de la Gazette**, dans le style de l'interface de WoW :
  - **onglets** « Édition du jour », « Sommaire », « L'Hebdo » (l'onglet actif est souligné d'or) ;
  - **barre de navigation** : « Veille », la date de l'édition au milieu, « Lendemain », et « Aujourd'hui » quand tu regardes un autre jour ;
  - **actions en icônes** avec leur nom dessous et une bulle d'aide : Exporter, Partager, PDF, Options, Aide ;
  - page sur **parchemin** encadrée d'un filet doré, titres en lettres de livre (police des quêtes), **icône pour chaque rubrique** (exploits, voyages, quêtes, butin, donjons…), **bilan du jour en encadré** sur deux colonnes.
- Le **gros titre** annonce le dernier niveau atteint (au lieu du premier quand il y en a eu plusieurs dans la journée).

## ForeverGFX 2.3.5 / ForeverHeal 1.8 / ForeverGazette 1.4.4 / ForeverPrep 1.4 / ForeverLoot 1.6 / ForeverMetiers 1.4 / ForeverMacros 1.6
- **Vraie cause du message « ForeverHeal a été bloqué à cause d'une action qui n'est utilisable que par l'IU de Blizzard »** (à chaque connexion) : sur le client de WoW Forever, **s'abonner** au journal de combat est interdit aux addons. ForeverHeal et ForeverGazette ne s'y abonnent plus quand le client ne permet pas de le lire.
- Diagnostic de tous les addons : ligne « Actions bloquées par le jeu depuis la connexion », avec l'addon et la fonction en cause, si le jeu en bloque encore une.
- Nouvelle simulation : les sept addons chargés comme sur le client de Forever, aucun abonnement au journal de combat.

## ForeverGFX 2.3.4 / ForeverHeal 1.7 / ForeverLoot 1.5 / ForeverMetiers 1.3
- La **flèche « → » s'affichait en carré** (la police du jeu ne l'a pas) : remplacée par « » » dans tous les addons ; « ≈ » et « ✓ » aussi retirés. La vérification automatique refuse désormais ces caractères.
- ForeverHeal : l'annonce d'un changement qui ne touche pas tes soins (armure, résistances, Endurance) n'affiche plus la ligne inutile « Soin moyen 0 · 0 soins/s · autonomie 0 s ».

## ForeverGFX 2.3.3 / ForeverHeal 1.6 / ForeverGazette 1.4.3
- **Correctif « ForeverHeal a été bloqué à cause d'une action qui n'est utilisable que par l'IU de Blizzard »** : sur le client de WoW Forever, la lecture du journal de combat (`C_CombatLog.GetCurrentEventInfo`, ajoutée en 2.3.2) est réservée à l'interface de Blizzard. ForeverHeal et ForeverGazette ne l'appellent plus.
- Conséquence sur ce client : les soins effectifs, l'excédent et l'effet des talents mesurés par ForeverHeal, et les soins / morts de la rubrique Donjons de la Gazette, restent indisponibles ; le reste fonctionne (le modèle de ForeverHeal utilise les valeurs lues dans le jeu et le mélange de sorts de tes lancers).
- Autres addons : inchangés.

## ForeverGFX 2.3.2 / ForeverPrep 1.3 / ForeverHeal 1.5 / ForeverGazette 1.4.2 / ForeverMetiers 1.2 / ForeverLoot 1.4
Corrections d'après les premiers diagnostics en jeu (05/11/2026, client 1.60.1 build 70790) : le client de WoW Forever utilise l'API moderne de WoW, où plusieurs fonctions classiques n'existent plus.
- ForeverPrep : **erreur à l'analyse** corrigée (`GetItemCooldown` absent : temps de recharge de la pierre de foyer lu par `C_Container`) ; niveaux des pierres de soins (12, 24, 36, 48).
- ForeverHeal et ForeverGazette : **journal de combat** lu par `C_CombatLog.GetCurrentEventInfo` quand `CombatLogGetCurrentEventInfo` manque (soins effectifs, excédent, talents mesurés, rubrique Donjons) ; ForeverHeal lit aussi le grimoire par `C_SpellBook`.
- ForeverMetiers : métiers lus par `GetProfessions` (pas de `GetNumSkillLines` sur ce client) ; noms des sorts par `C_Spell` (Désenchanter, enchantements) ; fenêtre du métier aussi suivie par `TRADE_SKILL_LIST_UPDATE` ; le diagnostic liste les fonctions de métier présentes.
- All The Things (ForeverMetiers, ForeverLoot) : seulement les sources de **ta faction** ; noms de réputation par `C_Reputation` ; une catégorie trop vague d'ATT (« Enchantement — Recettes ») laisse la place au texte du guide.
- ForeverGazette : le diagnostic dit si `C_CombatLog` existe et ce qu'il contient.

## ForeverGFX 2.3.1 / ForeverMetiers 1.1 / ForeverLoot 1.3
- **All The Things** (s'il est installé ; sa base propre à WoW Forever, tirée des données du jeu) :
  - ForeverMetiers : où apprendre chaque recette (PNJ ou quête, zone, coût en faveur marchande, réputation requise) et à quelle compétence, à la place des textes du guide ; onglet Recettes : **toutes les recettes de couture et d'enchantement à apprendre maintenant** et celles des 25 prochains points, avec leur source.
  - ForeverLoot : où obtenir chaque objet du BiS (boss et donjon, PNJ, quête).
- ATT n'ayant pas d'interface publique, ses données sont lues avec précaution : si une mise à jour d'ATT change sa structure, ces lignes disparaissent simplement (le bouton Diag le signale).
- Autres addons : inchangés.

## ForeverGFX 2.3.0 / ForeverMetiers 1.0 / ForeverHeal 1.4
- **Nouvel addon ForeverMetiers** (`/metiers`, WoW Forever) : couture et enchantement.
  - **Montée** : panneau à côté de la fenêtre du métier avec les meilleurs crafts (couleurs réelles du jeu, coût par point avec Auctionator, clic pour sélectionner), étape du guide 1-300 (mamytwink.com) et liste de courses (sacs, banque, rerolls avec Syndicator, ce qui manque et son coût) ; rappel du maître Compagnon / Expert / Artisan avant le plafond.
  - **Pour toi** : enchantements de soigneur pour chaque pièce portée (ce que tu sais faire, à apprendre maintenant, le meilleur à viser), chiffrés par ForeverHeal ; pièces de couture qui t'améliorent.
  - **Désenchanter** : ce qui peut l'être dans tes sacs (jamais une amélioration), résultat attendu, compétence requise, bouton « Désenchanter le premier ».
  - **Recettes** : feux de camp, bâtonnets runiques, enchantements et patrons utiles (nouveautés de Forever comprises) avec leur source ; temps de recharge de tous tes personnages ; infobulles des patrons (appris, par quel reroll, utile au prêtre) et des composants.
- ForeverHeal : `ForeverHealAPI.EvaluateStats` (gain d'un simple bonus de caractéristiques, pour chiffrer les enchantements).
- Icône commune « Forever » : entrée « Métiers ».

## ForeverGFX 2.2.2 / ForeverGazette 1.4.1 / ForeverLoot 1.2 / ForeverHeal 1.3
- ForeverLoot + **DungeonJournal** (s'il est installé) : le butin de chaque boss et les récompenses de quête de ses donjons (dont les nouveaux donjons de Forever) entrent dans le BiS calculé, avec l'endroit où les obtenir ; l'onglet Donjons montre, boss par boss, les objets intéressants pour toi.
- ForeverLoot + **Syndicator** (s'il est installé) : un objet BiS déjà dans ta banque, ton courrier, sur un autre personnage ou en banque de guilde est signalé.
- ForeverHeal + **HealBot** (s'il est installé) : le conseil de rangs dit aussi quoi remplacer dans les sorts de HealBot ; les macros de rang restent.
- Compagnon : `oui` / `non` acceptés dans `gazette_discord.ini` (en plus de `yes` / `no`) ; l'exemple les utilise.
- Compagnon : `installer-demarrage.bat` passe par le lanceur `py` / `pyw` (avec le gestionnaire d'installation de Python, `python` peut n'être qu'un raccourci vers le Microsoft Store et Pillow ne s'installait pas) ; s'arrête avec un message clair si Pillow manque.
- Autres addons : inchangés (numéros alignés sur le tag).


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
