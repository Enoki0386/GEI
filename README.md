# GEI - Garbage Empire Incremental

GEI est une base Roblox Rojo pour un jeu simulator / incremental / idle. Le repo est la source principale du code, et Roblox Studio sert surtout a tester le jeu via Rojo.

## Lancer avec Rojo

1. Installer Rojo si besoin : <https://rojo.space/docs/installation/>
2. Dans ce dossier, lancer :

```powershell
rojo serve
```

3. Dans Roblox Studio, ouvrir le plugin Rojo.
4. Se connecter au serveur Rojo local.
5. Lancer Play pour tester.

Le projet Rojo s'appelle `GEI` dans `default.project.json`.

## Structure

```txt
src/
|-- ReplicatedStorage/
|   |-- GameData.luau
|   |-- Remotes/
|   |-- Shared/
|   `-- Tools/
|-- ServerScriptService/
|   |-- Core/
|   |   |-- MapBuilder.server.luau
|   |   |-- PlayerManager.server.luau
|   |   `-- EventManager.server.luau
|   `-- Systems/
|       |-- SpawnManager.server.luau
|       |-- WasteNodeManager.server.luau
|       |-- SellZoneManager.server.luau
|       |-- ShopManager.server.luau
|       `-- BackpackManager.server.luau
|-- StarterGui/
|   `-- MainHUD/
|-- StarterPlayer/
|   `-- StarterPlayerScripts/
|       |-- ClientManager.client.luau
|       |-- ToolClient.client.luau
|       |-- ShopClient.client.luau
|       `-- TutorialClient.client.luau
`-- Workspace/
```

## Map de depart

La premiere map est creee automatiquement par :

```txt
src/ServerScriptService/Core/MapBuilder.server.luau
```

Ce script cree ou met a jour sans doublonner :

- `Workspace.SpawnLocation`
- `Workspace.LobbyFloor`
- `Workspace.SpawnSurface1`
- `Workspace.WasteZone`
- `Workspace.SellZone`
- `Workspace.BuyZone`
- `Workspace.MapDecor`

Layout actuel :

- centre / arriere : lobby et `SpawnLocation`
- devant : `SpawnSurface1`, la zone officielle de spawn des Waste Nodes
- gauche : `SellZone`
- droite : `BuyZone`
- autour : bordures, chemins, kiosques simples, labels `SELL`, `SHOP`, `WASTE AREA`

## Modifier la map

Les positions, tailles, couleurs et noms de zones sont dans `MapBuilder.server.luau`, section :

```lua
-- CONFIGURATION FACILE A MODIFIER
```

Les valeurs importantes :

- `MAP_CONFIG.LobbyFloor.Position` et `MAP_CONFIG.LobbyFloor.Size`
- `MAP_CONFIG.WasteArea.Position` et `MAP_CONFIG.WasteArea.Size`
- `MAP_CONFIG.SellZone.Position` et `MAP_CONFIG.SellZone.Size`
- `MAP_CONFIG.BuyZone.Position` et `MAP_CONFIG.BuyZone.Size`
- `MAP_CONFIG.SpawnLocation.Position`

Les memes positions de fallback sont aussi gardees dans `src/ReplicatedStorage/GameData.luau`, section `GameData.World`, pour que les scripts serveur aient des valeurs coherentes si la map doit etre creee en urgence pendant un test.

## Modifier SpawnSurface1

La taille et la position principales de `SpawnSurface1` sont ici :

```txt
src/ServerScriptService/Core/MapBuilder.server.luau
```

Dans `MAP_CONFIG.WasteArea`.

Le spawn dynamique des Waste Nodes utilise toujours le nom officiel :

```lua
GameData.Spawn.SurfaceName -- "SpawnSurface1"
```

Les Waste Nodes ne spawnent pas dans le lobby : ils sont places uniquement sur `Workspace.SpawnSurface1`, avec une distance minimale par rapport aux joueurs et aux autres Waste Nodes.

## Deplacer SellZone ou BuyZone

Dans `MapBuilder.server.luau` :

- modifier `MAP_CONFIG.SellZone.Position` pour deplacer la vente
- modifier `MAP_CONFIG.BuyZone.Position` pour deplacer le shop

`SellZoneManager.server.luau` et `ShopManager.server.luau` cherchent directement `Workspace.SellZone` et `Workspace.BuyZone`, donc les fonctionnalites suivent automatiquement les parts.

## Tester le MVP

1. Lancer `rojo serve`.
2. Connecter Roblox Studio au serveur Rojo.
3. Appuyer sur Play.
4. Verifier que le joueur spawn dans le lobby.
5. Aller dans `WASTE AREA` et cliquer un Waste Node avec `Brush`.
6. Quand le sac contient du Waste, marcher sur `SELL`.
7. Marcher sur `SHOP` pour ouvrir l'interface tablette.

L'outil de depart est `Brush`. Il peut etre equipe avec la touche `1` ou via la barre custom en bas de l'ecran.

## Modifier les configs gameplay

Tout le gameplay configurable se trouve dans `src/ReplicatedStorage/GameData.luau`, section :

```lua
-- CONFIGURATION FACILE A MODIFIER
```

On peut y modifier :

- nombre maximum de Waste Nodes : `GameData.Spawn.MaxWasteNodes`
- vitesse de spawn : `GameData.Spawn.SpawnInterval`
- HP et recompenses : `GameData.WasteTypes`
- chances de rarete : `RarityWeight`
- chances de Diamonds : `DiamondChance`
- degats / range / cooldown des outils : `GameData.Tools`
- capacite des sacs : `GameData.Backpacks`

## Ajouter un outil

1. Ajouter un id dans `GameData.ToolOrder`.
2. Ajouter une entree dans `GameData.Tools`.

Exemple :

```lua
SuperBrush = {
	Id = "SuperBrush",
	Name = "Super Brush",
	Price = 5000,
	Damage = 100,
	Range = 26,
	Cooldown = 0.35,
	Color = Color3.fromRGB(255, 170, 80),
	Description = "Late-game cleaner.",
}
```

Le Shop et la barre custom se mettent a jour depuis cette config.

## Ajouter un sac

1. Ajouter un id dans `GameData.BackpackOrder`.
2. Ajouter une entree dans `GameData.Backpacks`.

Le sac equipe determine `PlayerData.MaxWaste`. Si aucun modele Roblox n'est disponible, `BackpackManager.server.luau` attache une simple Part au dos du personnage. Plus tard, remplacer cette Part par un vrai modele Toolbox soude au torso.

Important : `Infinite Backpack` n'est pas inclus comme item gratuit. Il pourra etre ajoute plus tard comme gamepass / Robux.

## Ajouter un Waste

1. Ajouter un id dans `GameData.WasteOrder`.
2. Ajouter une entree dans `GameData.WasteTypes`.

Champs importants :

- `MaxHP`
- `WasteReward`
- `DiamondChance`
- `DiamondReward`
- `RarityWeight`
- `RingRadius`
- `VisualSize`

Le spawn choisit les Waste par poids de rarete.

## DataStore en Studio

`PlayerManager.server.luau` tente de charger et sauvegarder les donnees avec DataStore. Si le jeu n'est pas publie ou si API Services n'est pas active, les erreurs sont capturees avec `pcall`, le jeu ne crash pas, et une session de test reste jouable en memoire.

## Regles techniques

- Le serveur valide les attaques : distance, outil equipe, cooldown, target valide et sac non plein.
- `FireServer` est utilise seulement dans les LocalScripts.
- La vente est geree cote serveur via `SellZoneManager.server.luau`.
- Le Cash, les Diamonds, les achats et les degats sont autoritaires serveur.
- Shift Lock est active via `StarterPlayer.EnableMouseLockOption` dans `default.project.json`.
