These data tables come unchanged from OpenMap (https://github.com/openmap-world/openmap),
commit 0f4d2e4b6fe82b9032618fd3b824eaaa5b36dcef, MIT License (see ../LICENSES/OpenMap-LICENSE.txt).

  Minimap.lua      the game's minimap tile file IDs, per continent (WoW Forever build 1.60.1.70245)
  CaveMinimap.lua  caves, mines and underground cities as the game's minimap draws them inside
  Reveal.lua       the explored-area pieces of each zone's map, so the Route map shows it fully explored

They hold file IDs and positions only; the pictures themselves are the game's own and are
loaded from your WoW client. Entries that point at OpenMap's own edited pictures are skipped.
If a WoW Forever patch changes these files, take fresh copies from OpenMap.
