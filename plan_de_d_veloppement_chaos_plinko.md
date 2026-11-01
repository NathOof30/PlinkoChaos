# Roadmap de Développement : Chaos Plinko

Ce document définit l'ordre chronologique de développement des systèmes du jeu. Chaque phase doit être testée et validée avant de passer à la suivante.

## Phase 1 : Environnement et Setup de Base
*Objectif : Mettre en place la scène physique sans aucun code complexe.*
1. **Architecture du projet :** Création des dossiers dans `ReplicatedStorage` (pour les événements partagés, modules) et `ServerScriptService` (pour la logique serveur).
2. **Construction du Plateau :** Modélisation avec les `Parts` de base de Roblox (Le mur de fond, les clous/obstacles en quinconce, les murs latéraux).
3. **Zones de Réception :** Création des bacs en bas du plateau avec des valeurs multiplicatrices visuellement définies (ex: x0.5 au centre, x10 aux extrémités).

## Phase 2 : Le "Core Drop" (Mécanique Physique)
*Objectif : Pouvoir lâcher une bille et la voir tomber dans un bac.*
1. **Spawner Serveur :** Un script qui instancie une bille (Part sphérique) en haut du plateau à une position donnée.
2. **Hitboxes de Réception :** Scripts de type `Touched` sur les bacs en bas du plateau.
3. **Cycle de vie de la bille :** Lorsqu'une bille touche un bac, le serveur identifie la bille, lit le multiplicateur du bac, puis détruit la bille proprement pour éviter le lag.

## Phase 3 : DataStore et Économie de Base
*Objectif : Gérer l'argent du joueur et le sauvegarder.*
1. **Leaderstats :** Création de l'interface par défaut de Roblox en haut à droite pour afficher les "Pièces".
2. **DataStoreService :** Script pour charger l'argent à la connexion du joueur et le sauvegarder à la déconnexion.
3. **Connexion Core Drop / Économie :** Mettre à jour l'argent du joueur lorsqu'une de ses billes touche un bac multiplicateur (Valeur de base de la bille * Multiplicateur du bac).

## Phase 4 : Système d'Inventaire et du "Deck" (Loadout)
*Objectif : Implémenter la limite des 10 billes équipées.*
1. **Structure de Données :** Étendre le DataStore pour sauvegarder les billes possédées par le joueur et son "Deck" actuel.
2. **Logique d'État (Cooldown physique) :** 
   - Le joueur a 10 "Slots". 
   - État 1 : *Prêt* (La bille peut être lancée).
   - État 2 : *En chute* (La bille est sur le plateau).
   - Retour à l'état *Prêt* quand la bille est détruite dans un bac.
3. **UI Client (Interface) :** Une barre en bas de l'écran affichant les 10 billes. Clic pour lancer la bille, ce qui grise l'icône jusqu'à ce qu'elle atteigne le bas.

## Phase 5 : Les Capacités (Billes Spéciales)
*Objectif : Casser la monotonie avec des physiques différentes.*
1. **Système de Modules :** Créer un `ModuleScript` (dictionnaire) répertoriant les propriétés de chaque bille (Masse, Rebond, Capacité spéciale).
2. **La Bille Lourde :** Modification de la `CustomPhysicalProperties` lors de la génération.
3. **La Bille Explosive :** Ajout d'un script embarqué dans la bille qui déclenche une `Explosion` (qui repousse sans faire de dégâts) après 3 rebonds.

## Phase 6 : Le Crafting et l'Arbre de Progression
*Objectif : Créer la boucle de rétention et réguler l'économie.*
1. **Boutique de Base (Achat) :** UI pour acheter des billes standards avec des Pièces.
2. **Système de Blueprints (Plans) :** Ajout des plans débloqués dans le DataStore.
3. **UI et Logique de Fusion (Craft) :** Interface permettant de sélectionner des billes de l'inventaire, de vérifier si le joueur a le bon plan, de détruire les billes requises et de générer la nouvelle Bille Spéciale.

## Phase 7 : Game Feel et Polish (Juice)
*Objectif : Rendre le jeu satisfaisant et addictif.*
1. **Sons :** Bruitages sur les collisions de billes (clous, autres billes) avec variation de fréquence (Pitch). Bruitage de caisse enregistreuse à l'arrivée.
2. **Particules :** Confettis ou étincelles colorées lorsqu'une bille touche un multiplicateur élevé.
3. **Notifications UI :** Texte flottant indiquant le montant gagné lors d'un drop réussi.