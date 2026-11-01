⚙️ DOCUMENT DE GAME DESIGN : INVENTAIRE, ÉCONOMIE ET CRAFT (PHASE 6 V2)
1. Architecture de l'Inventaire (Nouveau Prérequis)
Avant de coder le craft, il faut construire le système de gestion des billes.

Données (DataStore) : Le joueur possède un dictionnaire listant l'ID de la bille et la quantité possédée (ex: { "standard": 15, "slime": 2 }).

UI Inventaire Global : Une grille affichant toutes les billes débloquées et leur quantité en stock.

UI Deck Actif : 10 emplacements (slots) fixes représentant les billes prêtes à être jouées.

Logique d'équipement : Le joueur peut cliquer sur une bille de son Inventaire pour l'ajouter à un slot vide du Deck. Il peut cliquer sur une bille du Deck pour la déséquiper (la renvoyer dans l'Inventaire).

2. Conditions Initiales et Sécurité (Anti-Softlock)

Inventaire de départ : 1 Bille Standard.

Deck de départ : 1 Bille Standard équipée (9 slots vides).

Portefeuille de départ : 10 Pièces.

Revenu passif : +1 Pièce / seconde (géré côté serveur) pour garantir qu'un joueur ne soit jamais totalement bloqué s'il détruit toutes ses billes.

3. Les 4 Types de Billes

Standard (Tier 1) : Physique normale.

Slime (Tier 2) : Rebond extrême. Très chaotique, parcours imprévisible.

Lourde (Tier 3) : Masse élevée, rebondit peu, pousse les autres billes.

Explosive (Tier 4) : Déclenche une impulsion physique qui expulse les autres billes de sa trajectoire.

4. Boutique et Système de Blueprints (Plans de fabrication)

Boutique de Base : Achat de la Bille Standard pour 10 Pièces.

Blueprints (Déblocage unique en Pièces) :

Blueprint "Bille Slime" : Coût = 500 Pièces.

Blueprint "Bille Lourde" : Coût = 2 000 Pièces.

Blueprint "Bille Explosive" : Coût = 8 000 Pièces.

5. Recettes de Craft (Le "Sink" d'inventaire)
Le craft consomme définitivement les billes de l'inventaire. Le serveur vérifie que la bille n'est pas actuellement équipée dans le Deck avant de la détruire.

Recette Bille Slime : 5 Billes Standards.

Recette Bille Lourde : 3 Billes Slimes + 10 Billes Standards.

Recette Bille Explosive : 2 Billes Lourdes + 5 Billes Slimes + 20 Billes Standards.

6. Logique UI de Crafting et Expérience Utilisateur (UX)

Vérification de l'état : Si le Blueprint n'est pas possédé, le bouton affiche un cadenas et le prix (ex: 🔒 Bille Slime (500 Pièces)).

Vérification des ingrédients : Affiche les composants requis (ex: Billes Standards : 2/5). En rouge si insuffisant, en vert si suffisant.

Sécurité Serveur (Sanity Check) :

Le client demande la fusion.

Le serveur vérifie que le plan est débloqué.

Le serveur vérifie que les quantités requises sont dans l'inventaire (et non dans le Deck).

Le serveur déduit les ingrédients, ajoute la nouvelle bille, sauvegarde, et met à jour l'UI du client.

Ce document met en lumière la dépendance claire : le système de craft ne peut pas exister sans que le système d'Inventaire et de Deck ne soit totalement fonctionnel pour différencier les "billes en stock" (utilisables pour le craft) des "billes équipées" (protégées du craft).