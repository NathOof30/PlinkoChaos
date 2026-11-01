# Mettre en place Rojo pour PlinkoChaos

Ce guide prépare un environnement Roblox avec **VS Code**, **Rojo**, **Aftman** et
**Roblox Studio** dans :

```text
C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos\
```

Il explique aussi la limite importante de Rojo : la synchronisation en direct
est principalement **des fichiers vers Studio**. Rojo n'est pas un système de
synchronisation bidirectionnelle automatique comme Git.

## 1. Ce qui doit être installé

Il faut distinguer trois éléments :

1. **Rojo CLI** : programme utilisé dans PowerShell pour servir ou construire le
   projet.
2. **Plugin Rojo pour Roblox Studio** : interface qui se connecte au serveur
   lancé par `rojo serve`.
3. **Extension VS Code Rojo** : optionnelle ; elle facilite le lancement et
   l'arrêt du serveur, mais ne remplace ni le CLI ni le plugin Studio.

Le CLI et le plugin Studio doivent idéalement utiliser la même version majeure
et, de préférence, la même version mineure.

## 2. Vérifier les outils actuels

Ouvre un nouveau PowerShell et exécute :

```powershell
aftman --version
rojo --version
```

Si `rojo` n'est pas reconnu, utilise le chemin d'installation Aftman :

```powershell
& "$HOME\.aftman\bin\rojo.exe" --version
```

Dans l'installation actuelle, Aftman est en version `0.3.0` et Rojo en
version `7.5.1`.

> `aftman exec` n'est pas une commande disponible dans cette version
> d'Aftman. Il faut donc exécuter `rojo` directement.

## 3. Mettre à jour Aftman ou choisir une alternative

Aftman fonctionne encore, mais son dépôt n'est plus maintenu. Pour un nouveau
projet, il est recommandé de surveiller une migration vers un gestionnaire
actuellement maintenu, comme Rokit ou mise-en-place.

Pour continuer avec Aftman sans modifier l'installation existante :

```powershell
aftman self-update
```

Si cette commande ne met rien à jour, ce n'est pas bloquant : Aftman peut
continuer à installer Rojo.

## 4. Créer le projet PlinkoChaos

Dans PowerShell :

```powershell
New-Item -ItemType Directory -Path "C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos" -Force
Set-Location "C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos"
```

Initialise ensuite le manifeste Aftman :

```powershell
aftman init
```

Ajoute Rojo. Pour un environnement reproductible, épingle une version au lieu
de demander une version flottante :

```powershell
aftman add rojo-rbx/rojo@7.7.1
```

La commande `aftman add` crée ou met à jour `aftman.toml` et installe l'outil.
Si `7.7.1` n'est pas encore la version disponible au moment de l'installation,
consulte la page officielle des releases Rojo et remplace ce numéro par la
version stable publiée.

Vérifie le résultat :

```powershell
aftman list
rojo --version
```

Si le terminal ne voit pas encore le dossier Aftman dans le `PATH`, ferme et
rouvre PowerShell, ou utilise directement :

```powershell
& "$HOME\.aftman\bin\rojo.exe" --version
```

## 5. Installer ou mettre à jour le plugin Rojo dans Studio

### Méthode recommandée : plugin depuis une release

1. Ouvre la page officielle :
   <https://github.com/rojo-rbx/rojo/releases>
2. Ouvre la release correspondant à la version du CLI installée.
3. Télécharge l'asset `Rojo.rbxm`.
4. Dans Roblox Studio, ouvre **Plugins > Plugins Folder**.
5. Ferme Roblox Studio.
6. Remplace l'ancien fichier/plugin Rojo par `Rojo.rbxm`.
7. Relance Roblox Studio.

Si Studio affiche deux boutons Rojo ou deux versions du plugin, supprime
l'ancienne copie du dossier des plugins avant de relancer Studio.

Une autre possibilité est la page du plugin Roblox :

<https://create.roblox.com/marketplace/asset/16057023315/Rojo>

Dans tous les cas, vérifie dans Studio que le plugin est bien chargé depuis
**Plugins** et qu'il affiche sa version.

## 6. Générer la structure du jeu

Dans le dossier du projet :

```powershell
Set-Location "C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos"
rojo init
```

Si la commande demande un nom, indique `PlinkoChaos`. Elle doit créer un
manifeste de projet, généralement `default.project.json`.

Une structure de départ conseillée est :

```text
PlinkoChaos/
├── aftman.toml
├── default.project.json
├── src/
│   ├── client/
│   ├── server/
│   └── shared/
└── README.md
```

N'ajoute pas les fichiers générés (`*.rbxlx`) au dépôt Git sauf si tu veux
explicitement versionner une place exportée.

## 7. Démarrer la synchronisation vers Studio

Dans PowerShell 1, depuis le projet :

```powershell
Set-Location "C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos"
rojo serve default.project.json
```

Le serveur écoute normalement sur le port `34872`.

Dans Roblox Studio :

1. Ouvre une place vide ou la place de développement.
2. Ouvre le plugin **Rojo**.
3. Clique sur **Connect**.
4. Sélectionne le serveur local, normalement `127.0.0.1:34872`.
5. Vérifie que l'arborescence du projet apparaît dans l'Explorer.

Laisse PowerShell et Studio ouverts pendant le développement. Chaque
modification enregistrée dans VS Code est alors envoyée à Studio.

Pour arrêter le serveur, retourne dans PowerShell et appuie sur `Ctrl+C`.

## 8. Workflow recommandé dans les deux sens

### Code et objets contrôlés par les fichiers : VS Code vers Studio

Le workflow normal est :

1. Créer ou modifier les scripts et modules dans `src/`.
2. Enregistrer les fichiers dans VS Code.
3. Observer la mise à jour dans Studio via Rojo.
4. Tester dans Studio.
5. Versionner les fichiers avec Git.

Les suffixes LuaU habituels sont :

```text
*.server.lua   -> Script
*.client.lua   -> LocalScript
*.lua          -> ModuleScript
```

Rojo 7 accepte également les extensions `.luau` selon la configuration et le
mapping du projet.

### Objets créés dans Studio : Studio vers les fichiers

Rojo ne réécrit pas automatiquement toutes les modifications faites dans
Studio vers `src/`. Pour éviter de perdre du travail :

1. Décide si l'objet doit être défini dans le code ou dans Studio.
2. Pour les scripts, crée le fichier dans `src/` et édite-le dans VS Code.
3. Pour un modèle ou un asset créé dans Studio, exporte-le explicitement en
   `.rbxm` ou `.rbxmx`.
4. Place l'asset exporté dans le projet et ajoute son chemin au manifeste
   Rojo.
5. Redémarre `rojo serve` si tu modifies le mapping du manifeste.

Ne modifie pas longuement un objet géré par Rojo dans Studio en pensant que
la modification sera automatiquement sauvegardée dans le projet : une
resynchronisation peut la remplacer.

## 9. Tester le projet sans serveur permanent

Pour produire une place Roblox à partir des fichiers :

```powershell
Set-Location "C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos"
rojo build default.project.json -o PlinkoChaos.rbxlx
```

Ouvre ensuite `PlinkoChaos.rbxlx` dans Studio pour tester une copie exportée.
Le serveur live reste préférable au quotidien, car il évite de refaire un
export à chaque modification.

## 10. Vérifications de bon fonctionnement

Exécute ces commandes dans le dossier du projet :

```powershell
Get-Location
Get-Content .\aftman.toml
aftman list
rojo --version
rojo build default.project.json -o .\PlinkoChaos-test.rbxlx
```

Le dernier fichier doit être créé sans erreur. Supprime ensuite uniquement ce
fichier de test si tu ne veux pas le conserver :

```powershell
Remove-Item ".\PlinkoChaos-test.rbxlx"
```

Puis lance :

```powershell
rojo serve default.project.json
```

Si Studio ne se connecte pas :

- vérifie que le serveur PowerShell est toujours actif ;
- vérifie que le plugin Rojo et le CLI sont de la même release ;
- ferme les anciens serveurs Rojo ;
- vérifie qu'un pare-feu Windows n'a pas bloqué `rojo.exe` ;
- essaie le port explicitement :

  ```powershell
  rojo serve default.project.json --port 34872
  ```

## 11. Commandes quotidiennes

```powershell
Set-Location "C:\Users\natha\OneDrive\Documents\R\ROBLOX\PlinkoChaos"

# Réinstaller les outils déclarés par le projet
aftman install

# Vérifier la version
rojo --version

# Synchroniser vers Studio
rojo serve default.project.json

# Exporter une place
rojo build default.project.json -o PlinkoChaos.rbxlx
```

`aftman install` peut ne rien afficher lorsque Rojo est déjà installé : ce
comportement est normal. La vérification fiable est `aftman list` puis
`rojo --version`.

## Références officielles

- [Installation Rojo](https://rojo.space/docs/v7/getting-started/installation/)
- [Créer un projet Rojo](https://rojo.space/docs/v7/getting-started/new-game/)
- [Détails de synchronisation](https://rojo.space/docs/v7/sync-details/)
- [Releases Rojo](https://github.com/rojo-rbx/rojo/releases)
- [Dépôt Aftman](https://github.com/LPGhatguy/aftman)
