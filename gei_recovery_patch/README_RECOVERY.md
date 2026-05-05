# GEI Recovery Patch

But : rendre le projet rejouable après les changements de structure.

Ce patch :
- rend SpawnSurface1/WasteZone robustes même dans les dossiers `SpawnSurfaces` ;
- crée un fallback de sécurité si WasteZone ou SpawnSurface1 manque ;
- évite que les UI client attendent 20 secondes sur des modules optionnels ;
- ajoute un HUD fallback seulement si MainHUD échoue complètement.

Test Studio :
1. Play
2. vérifier HUD Cash/Waste/Diamonds
3. vérifier Waste spawn sur SpawnSurface1
4. attaquer un waste
5. vendre à SellZone
6. ouvrir Inventory
7. aller près de EggHatcher
