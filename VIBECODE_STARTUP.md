# 🚀 Guide de Démarrage Vibecoding — PlinkoChaos

> **Document de référence pour l'agent IA et le développeur.**  
> À consulter au début de chaque session pour être immédiatement opérationnel, valider l'environnement (Rojo + MCP) et aligner le travail sur la roadmap.

---

## 🎮 1. Rappel Express du Projet : Chaos Plinko

* **Concept :** Jeu de Plinko multijoueur sur plateau géant partagé.
* **Différenciateur :** Physique universelle partagée — les billes des différents joueurs se percutent, se poussent, créent des réactions en chaîne chaotiques et compétitives.
* **Core Loop :**
  1. **Drop :** Lancement d'une bille depuis le sommet (deck joueur).
  2. **Chaos :** Chute physique, rebonds sur les clous et collisions entre billes.
  3. **Récompense :** Arrivée dans un bac multiplicateur (ex: x0.5 au centre, x10 aux bords) -> encaissement de pièces + restitution de la bille.
  4. **Progression / Sink :** Achat de billes standards, fusion (craft avec destruction de billes) pour débloquer des billes spéciales (Lourde, Explosive, etc.).
* **Règle d'or de performance (MVP) :** Deck limité à 10 billes actives max par joueur tant qu'elles n'ont pas atterri (cooldown physique anti-lag).

---

## 🛠️ 2. L'Écosystème Vibecoding : Rojo + MCP Roblox Studio

Le projet fonctionne avec une synergie à deux piliers :

```
                  ┌─────────────────────────────────┐
                  │      Code Local (VS Code)       │
                  │   src/ (client, server, shared) │
                  └────────────────┬────────────────┘
                                   │
                   Rojo Sync (Port 34872) [One-Way: Fichiers -> Studio]
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│                          Roblox Studio                           │
│                      (Place1 / PlinkoChaos)                      │
└──────────────────────────────────▲───────────────────────────────┘
                                   │
                   MCP Roblox Studio [Bidirectionnel]
          (search_game_tree, execute_luau, inspect_instance, etc.)
                                   ▼
                  ┌─────────────────────────────────┐
                  │       Antigravity / Agent IA    │
                  └─────────────────────────────────┘
```

1. **Rojo (Gestion du Code & Arborescence) :**
   - Écriture des scripts dans `src/`.
   - Synchronisation automatique vers Roblox Studio (`default.project.json`).
   - Maintient la base de code propre, versionnable sous Git.

2. **Roblox Studio MCP (Super-pouvoirs de l'Agent IA) :**
   - **Inspection :** `search_game_tree`, `inspect_instance`, `script_read` pour inspecter la scène et l'état des objets en direct.
   - **Action & Génération :** `execute_luau` pour générer du contenu directement dans le viewport (parts, plateaux, clous, models, tests rapides).
   - **Playtest & Debug :** `start_stop_play`, `get_console_output` pour lancer une session de test et lire les erreurs console sans quitter l'éditeur.

---

## ✅ 3. Checklist Rapide de Début de Session

À exécuter dès le lancement pour vérifier que les ponts sont ouverts :

### Étape 1 : Vérification de Rojo
- Tester la présence de Rojo :
  ```powershell
  rojo --version
  ```
  *(Version cible : 7.7.1 géré par Aftman 0.3.0)*
- Vérifier si le serveur Rojo est actif :
  ```powershell
  Get-NetTCPConnection -LocalPort 34872 -ErrorAction SilentlyContinue
  ```
- Si le serveur n'est pas lancé :
  ```powershell
  rojo serve
  ```
- Dans Roblox Studio : S'assurer que le plugin Rojo est connecté (`Connect`).

### Étape 2 : Vérification du MCP Roblox Studio
- Appeler `list_roblox_studios` :
  - Doit retourner l'instance active (ex: `"name": "Place1"`).
- Appeler `get_studio_state` avec le `studio_id` :
  - Vérifier le mode (`Edit`, `Client`, `Server`).
- Appeler un test de lecture :
  - `search_game_tree(path: "Workspace", datamodel_type: "Edit")` pour confirmer la liaison.

---

## 📂 4. Structure du Projet

```text
PlinkoChaos/
├── default.project.json      # Mapping Rojo DataModel
├── aftman.toml               # Dépendances CLI (Rojo)
├── plan_de_d_veloppement_chaos_plinko.md # Feuille de route MVP
├── VIBECODE_STARTUP.md       # Ce fichier de démarrage
├── src/
│   ├── client/               # StarterPlayerScripts
│   │   └── init.client.luau
│   ├── server/               # ServerScriptService
│   │   └── init.server.luau
│   └── shared/               # ReplicatedStorage
│       └── Hello.luau
```

---

## 🎯 5. Focus Actuel : Phase 1 (Environnement & Setup de Base)

L'objectif de la **Phase 1** est de créer la structure du plateau physique sans code de gameplay complexe :

1. **Architecture des Dossiers Studio :**
   - `ReplicatedStorage` : `Shared`, `Events` (RemoteEvents), `Configs`.
   - `ServerScriptService` : `Server`, `Services`.
2. **Construction du Plateau de Plinko :**
   - **Mur de fond (Backboard) :** surface d'appui légèrement inclinée ou verticale.
   - **Murs latéraux & Guide supérieur :** pour canaliser le lâcher de billes.
   - **Réseau de clous (Pins) :** disposition en quinconce (staggered grid) avec `Elasticity` adaptée.
   - **Bacs récepteurs (Slots) :** compartiments en bas avec multiplicateurs attribués (ex: x0.5 au centre, x2, x5, x10 sur les côtés) matérialisés via des Attributs Roblox (`Multiplier`).

> 💡 **Astuce Vibecoding Phase 1 :**  
> Plutôt que de modéliser manuellement des dizaines de clous à la main, nous pouvons utiliser un script Luau exécuté via le MCP (`execute_luau`) pour générer le plateau mathématiquement parfait avec ses dimensions, quinconce, et multiplicateurs dans un dossier `Workspace.PlinkoBoard`.

---

## 📚 6. Documentation & Références Utiles

* 📖 **Rojo Docs :** [rojo.space/docs](https://rojo.space/docs)
* 📖 **Luau Language Reference :** [luau-lang.org](https://luau-lang.org)
* 📖 **Roblox Engine API :** [create.roblox.com/docs/reference/engine](https://create.roblox.com/docs/reference/engine)
* 📋 **Feuille de route complète :** [plan_de_d_veloppement_chaos_plinko.md](file:///c:/Users/natha/OneDrive/Documents/R/ROBLOX/PlinkoChaos/plan_de_d_veloppement_chaos_plinko.md)

