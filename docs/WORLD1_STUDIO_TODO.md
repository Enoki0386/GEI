# GEI / Garbage Empire — World 1 Studio TODO

Ce patch ajoute la base code du World 1. Pour garder la map visuelle dans Roblox Studio, crée les objets ci-dessous manuellement.

## Admin Panel
- Ton UserId admin est déjà configuré : `1990396002`.
- En jeu : appuie sur `F8`.

## Egg Plaza
Structure attendue :

```text
Workspace
└── EggPlaza
    └── EggHatcher
        └── Main
```

`Main` doit être une `Part` ou contenir une `Part`.

## Zone barriers
Crée ces objets dans Workspace. Ils peuvent être `Part` ou `Model` avec une Part dedans.

```text
Workspace
├── Zone2Barrier
├── Zone3Barrier
├── Zone4Barrier
└── PortalDimension2
```

Conseil visuel :
- barrier = grand mur semi-transparent / warning jaune-noir.
- mets-les sur le chemin principal.
- le code ajoute les ProximityPrompt automatiquement.

## Spawn surfaces
Crée ces surfaces pour les zones :

```text
Workspace
├── SpawnSurface2
├── SpawnSurface3
└── SpawnSurface4
```

Propriétés conseillées :
- Anchored = true
- CanCollide = true
- Size :
  - SpawnSurface2 : 140, 1, 90
  - SpawnSurface3 : 150, 1, 100
  - SpawnSurface4 : 160, 1, 120

## Machine Area
Crée :

```text
Workspace
└── MachineArea
    ├── Recycler
    ├── Crusher
    ├── Compressor
    └── AutoSorter
```

Chaque machine peut être une simple Part/Model. Le code ajoute les prompts automatiquement.

## Diamond Upgrade Shop
Crée :

```text
Workspace
└── UpgradeShop2
    ├── SpeedUpgrade
    ├── DamageUpgrade
    ├── MachineEfficiencyUpgrade
    ├── PetBuffUpgrade
    └── DiamondChanceUpgrade
```

Chaque upgrade peut être un petit podium/part.

## Boss Zone
Crée :

```text
Workspace
└── BossWasteArea
```

Optionnel : crée un objet `BossWaste`. Sinon le code crée un boss sphère fallback pendant le playtest.

## VIP
Crée :

```text
Workspace
└── VIPZone
```

Pour l’instant le GamePassId vaut 0. Le VIP est surtout placeholder + admin access.

## Portal
Crée :

```text
Workspace
└── PortalDimension2
```

Le portail est bloqué tant que BossWaste n’a pas été vaincu.

## Tests rapides
1. Play.
2. F8 ouvre le panel admin.
3. Give Cash, Diamonds, Pet, Crusher.
4. Crée Zone2Barrier et SpawnSurface2 : E sur barrière unlock + TP.
5. Machines : E sur Recycler consomme Waste et donne Cash après délai.
6. UpgradeShop2 : E sur Speed/Damage consomme Diamonds.
7. BossWasteArea : Boss spawn fallback si pas de BossWaste manuel.
8. PortalDimension2 : affiche locked avant boss.
9. Index button : liste pets/wastes.
