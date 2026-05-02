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
├── ReplicatedStorage/
│   ├── GameData.luau
│   ├── Remotes/
│   ├── Shared/
│   └── Tools/
├── ServerScriptService/
│   ├── Core/
│   │   ├── PlayerManager.server.luau
│   │   └── EventManager.server.luau
│   └── Systems/
│       ├── SpawnManager.server.luau
│       ├── WasteNodeManager.server.luau
│       ├── SellZoneManager.server.luau
│       ├── ShopManager.server.luau
│       └── BackpackManager.server.luau
├── StarterGui/
│   └── MainHUD/
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── ClientManager.client.luau
│       ├── ToolClient.client.luau
│       ├── ShopClient.client.luau
│       └── TutorialClient.client.luau
└── Workspace/
```

## Objets Workspace

Au lancement, `SpawnManager.server.luau` cree automatiquement si besoin :

- `Workspace.SpawnSurface1`
- `Workspace.WasteZone`
- `Workspace.SellZone`
- `Workspace.BuyZone`
- `Workspace.SpawnLocation`
- `Workspace.GEIBaseplate`

Les Waste Nodes spawnent uniquement sur `SpawnSurface1`. Le systeme evite les joueurs et garde une distance minimale entre les piles.

## Tester le MVP

1. Appuyer sur Play dans Studio.
2. Le joueur spawn dans la zone de depart.
3. Cliquer sur une pile de Waste a portee.
4. Le Waste perd des HP numeriques au-dessus de lui.
5. Quand il est detruit, le sac gagne du Waste et peut parfois gagner des Diamonds.
6. Marcher sur `SellZone` pour vendre automatiquement.
7. Marcher sur `BuyZone` pour ouvrir le Shop.
8. Acheter/equiper des outils et sacs si le joueur a assez de Cash.

L'outil de depart est `Brush`. Il peut etre equipe avec la touche `1` ou via la barre custom en bas de l'ecran.

## Modifier les configs

Tout se trouve dans `src/ReplicatedStorage/GameData.luau`, section :

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
- positions et tailles des zones : `GameData.World`

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
