# Developing Nodewalker

- UI rules: [UI_DESIGN_STANDARD.md](UI_DESIGN_STANDARD.md)
- CurseForge page text: [CURSEFORGE.md](CURSEFORGE.md) (paste into the project description)
- Gallery, GIFs and claims to check in game: [MARKETING.md](MARKETING.md)

## Releasing

1. Add the changes to `CHANGELOG.md`, one short line each.
2. Put the new version in `VERSION` (e.g. `1.1.21`) and push to `main`.
   The GitHub Action tags `v1.1.21`, packages the addon and uploads it to CurseForge.
   Pushing a `v1.1.21` tag works too.
3. If a release run sits queued with no jobs, don't re-run it without checking: it once uploaded twice.

Needs the repository secret `CF_API_KEY` (a CurseForge API token), and
Settings › Actions › General › Workflow permissions set to "Read and write".

## Debug commands

| Command | Does |
|---|---|
| `/nw terrain` | Which minimap tiles this zone uses |
| `/nw continent <id> <folder>` | Point a continent at a minimap folder |
| `/nw frame` | Names the frame under the mouse |
| `/nw harvest` · `/nw harvest all` | Saves the game's level and effect text for consumables |

## Fishing and Cooking

### Cooking
Cooking runs through the same planner as every craft (`NW.BuildPlan`). It isn't limited to fish: every recipe in `Professions/Cooking.lua` counts, priced from Auctionator and vendors, minus your bags. `NW.CookAllow(recipe, skill)` filters recipes for Cooking only:

- standalone: `settings.cookSource` = nil (all), `"fish"` (a fish in it), `"nofish"`;
- the combined plan: fish you can catch by then, vendor supplies, and meat or other ingredients only if allowed.

`NW.CookAllowKey()` is part of the plan cache key.

### Fishing data (`Professions/Fishing.lua`)
- `F.RANKS`: WoW Forever ranks. Journeyman 50 / level 10 (trainer), Expert 125 / level 20 (book from Old Man Heming, Booty Bay, 1g), Artisan 225 / level 35 (Nat Pagle's quest, four quest fish). Source: Method's WoW Forever fishing guide.
- `F.BRACKETS`: zones by skill range, from wow-professions.com's WoW Forever guide, with the lure each range suggests.
- `F.FISH[itemID]`: `skill` (where the guides fish it), `zones` (only where a source names them), `bracket` (only known by skill range), `note` (coast, night, day, lakes). Fish with neither are ones the cooking data uses but no source places: shown as "Not in Nodewalker's fishing data", and never planned as catches.
- Links: fish → zones (`F.zonesFor`), zone → fish (`F.fishIn`), fish → recipes (`NW.CookFish`), recipe → fish (`F.fishInRecipe`).

### Combined plan (`F.Build`)
1. Runs `NW.BuildPlan("cooking", now, target)` with the combined rules. A fish counts as catchable at skill point `s` if its `skill` ≤ the Fishing you'll have by the end of that rank (your target, or your skill if higher).
2. Splits the result into phases by rank (0-75, 75-150, 150-225, 225-300). In each: learn, train Fishing, train Cooking, recipes, vendor supplies, other ingredients, fish to the phase's skill, catch each fish, cook each step.
3. Bags are handed out to the steps in order, so owned fish and supplies count once.
4. Steps are done only from what the game says: skill, max skill, known recipes, bag counts. Blocked steps say why (level, Fishing skill, no recipe with these options) and are skipped when picking the next step.
5. Money: training, recipes, vendor supplies, bought ingredients and bought fish are what you pay. Caught fish show their auction value separately. An unknown price is "+?", never zero.

Recalculates on bags, skill lines, new recipes and equipment changes (half-second debounce, only while the page is open).

### Known limits
- No zone fishing skill: WoW Forever doesn't publish it, so only the guides' recommended ranges are shown.
- No catch counts for fishing skill-ups, and no catch rates: the plan gives a skill to reach instead.
- Effective skill is the game's own modifier (gear, lure, buffs together). Gear and lure can't be told apart, only whether a lure is on the pole.
- "Show on map" opens the zone: fishing data is by zone, not by spot. No fishing pool routes.
- Fish zones for six fish are WoW Forever-specific (Method); the rest are by skill range only.

### Tests
`fish_test.lua` (scratchpad harness) covers: neither, either or both professions learned; both from 1; one ahead of the other; one maxed; near caps; non-fish allowed; buying fish; no bought recipes; no vendor supplies; owned fish; low level (training blocked); targets below 300; the three standalone Cooking filters; every Fishing view, row and fold; the craft pages after Fishing. Every plan is checked: no cooking before its skill, no fish above the Fishing you'll have, no bought fish unless allowed, no non-vendor ingredient unless allowed. Needs the game: map opening, lure detection, live updates while fishing and cooking, effective skill readout.
