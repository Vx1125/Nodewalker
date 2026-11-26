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

## Smart Fishing, Journal and HUD

### Smart Fishing (`Professions/SmartFishing.lua`)
One key, a normal game binding (`CLICK NodewalkerSmartFish:LeftButton`): Key Bindings › AddOns › Smart Fishing, or the button in Settings › Fishing (a key or a controller button), which sets the same binding (a key already bound to something asks for a second press, then moves). A key set in Settings by an earlier version moves to the game binding at login. Each press clicks the hidden secure button `NodewalkerSmartFish`, whose action is set out of combat from the current state:

1. no pole on, and a fishing set or a pole in your bags: a macro of `/equipslot` lines;
2. lures on (Settings › Fishing › Lure), no temporary enchant on the pole, and a lure in your bags: `/use item:<lure>` then `/use 16`;
3. otherwise: the Fishing spell.

While the Fishing channel runs, the key is pointed at `INTERACTTARGET` and `SoftTargetInteract` is set to 3 (its earlier value is saved in the settings and put back when the channel ends, after combat, or at the next login), so the same key reels in through the game's soft-target interact. The game gives addons no bite signal: the HUD says "Press on the splash", nothing more. Nothing happens without a key press, and bindings and secure buttons aren't changed in combat (queued for `PLAYER_REGEN_ENABLED`).

Researched: EzFishing Forever and Fishing-OneKey (MIT) do the same cast / interact switch; FishFry Forever (all rights reserved) wasn't read for code.

- **Gear:** "Use what I'm wearing" saves your pole and, if ticked, head, hands and feet (per character, `charDB.fishGear`). Without a saved set, the best pole in your bags (`SF.POLES`, else +0). Before equipping, what you wore in the main hand, off hand and the set's slots is saved (`charDB.fishPrev`). With a pole already on, only set slots not yet saved are added, so your normal gear is never replaced by fishing gear. While no pole is on, your weapons are also noted (`charDB.fishNormal`), so a pole put on by hand can be swapped back. The HUD's gear button swaps both ways. Restore puts back what's in your bags, names what isn't, and the snapshot is cleared once everything is back on. The settings page and HUD Gear buttons and Restore are ordinary buttons using `EquipItemByName` (out of combat); the only visible secure button is the HUD's Lure button, parented to `UIParent` and placed by coordinates, so the HUD and the window never become protected in combat.
- **Lures:** No lure, My preferred lure (optionally another if you're out), or Strongest I carry. Bonuses from Method's WoW Forever guide. A lure isn't replaced while one is on. The lure's name shows only if Nodewalker put it on (the game reports only that an enchant is there and its time left). Alerts: 30 seconds left, expired, under 3 left, preferred one missing; each once.

- **Quiet while fishing** (off by default): on cast, `Sound_MusicVolume` and `Sound_AmbienceVolume` go to 0 and `Sound_SFXVolume` to 1. The old values are saved in the settings (`fishQuietSaved`) and put back when the pole comes off, 90 seconds after the last cast, when the option is turned off, or at the next login.

### Catch attribution (`Professions/FishJournal.lua`)
- A loot window counts only if `IsFishingLoot()` says so. Clients without it: only a window from a `GameObject` within 4 seconds of your Fishing channel ending.
- Items count as their slot is emptied (`LOOT_SLOT_CLEARED`): autoloot and manual loot alike, nothing for an item left behind in full bags, nothing twice (`LOOT_READY` and `LOOT_OPENED` open the same window once).
- Purchases, mail, trades, crafting, creature loot and bank moves never come through a fishing loot window, so they're never counted.
- Kinds come from the game's item classes: the fish catalog or Trade Goods › Cooking is a fish; then gear, containers, junk (poor quality), trade goods, other.
- Rare means the game's own quality (rare or better), never "caught few".

### Storage
Per character in `db.chars[name-realm].fishLog`, schema `v = 1`:
- `items[id] = { n, first, last, k }`;
- `zones[mapID] = { n, fish, t, last, items }` (mapID 0: unknown);
- `spots[mapID][cell] = { [id] = n }`: 2% cells, at most 400 per map, only when the game gives a position;
- `sessions`: last 100, summaries with the value when they ended;
- `recent`: last 100 catches with subzone, skill, effective skill and the lure if Nodewalker put it on.

No prices are kept per catch. "All characters" adds the characters' logs up when you look. The open session is `charDB.fishSession`; it survives a reload and ends at login if it's been idle over 20 minutes.

### Sessions
Start with your first cast or catch (Settings: Start one when I cast), or not at all (Sessions off). Fishing time adds the gap between casts and catches only when it's 2 minutes or less, so AFK time doesn't count. 20 minutes without fishing ends a session at your last activity (checked every second, not only on the next cast). Pause, Resume, End and Delete are in the Journal's Sessions view.

### Fishing + Cooking in the HUD
`SF.Target()` runs `F.Build()` only after bags, skills or recipes change, at most once every 5 seconds and shows the plan's current fish: have, ~need, a bar. When it fills and the next step is to cook, "Collection complete. Next: Cook …".

### Known limits
- Reeling needs the game's interact targeting to reach the bobber (line of sight, range). If it can't, click the bobber.
- No bite detection, no auto-cast, no auto-reel, by design and because the game doesn't allow it.
- Pool identification isn't recorded: the game doesn't say which pool a catch came from.
- Lure bonus and gear bonus are one number from the game (`ProfBonus`).
- `IsFishingLoot` missing: the fallback can't tell a fishing loot window opened more than 4 seconds after the channel.

### Tests
`sfish_test.lua` (scratchpad harness):
- Catches: a fishing window with a fish, coins and a second item; creature loot; full bags; several fish in one catch; junk and a rare item; the `IsFishingLoot` fallback (game object, creature, too late); a zone change with no position.
- Sessions: auto start, pause, active time, rollover after 20 minutes, end, delete.
- Smart Fishing: no pole, equip, snapshot kept while in gear, lure (strongest, preferred, missing, alternative, already on), the key click, interact while the bobber is out and back, combat queueing, restore and missing items, saving worn gear.
- HUD, notices, 100k synthetic catches (bounded detail, view speed), every Journal view, sort, row and scope, the open session, Fish Finder history, the settings page.

Needs the game: casting and reeling with the key, interact targeting on the bobber, equipping and restoring, putting a lure on, real loot windows (autoloot and manual), the HUD's look and position.

## Material Finder

The Farm Guide tab became Material Finder (tab key still `guide`, so saved tabs, `/nw guide` and the Route tab's button keep working). Herb and ore zone ranking, the preview loop and **Build route** are the Farm Guide's code, unchanged (`rankZones` in `Guide.lua`), now reached by picking an herb or ore.

### Files
| File | Does |
|---|---|
| `Materials/SourceData.lua` | Generated. Creatures, spawns, ordinary and skinning loot, vendors. Don't edit by hand. |
| `Materials/Catalog.lua` | `NW.Mat`: categories, materials and their providers, search, collection objectives. |
| `Materials/Hunt.lua` | `NW.Hunt`: Hunting Grounds: sources, density, clusters, routes, progress, overlay drawing. |
| `Materials/GatherLog.lua` | `NW.GatherLog`: loot attribution and the per-character gathering log. |
| `Materials/HUD.lua` | Adds objective and hunting-route lines (with Next / Skip) to the session panel. |
| `Guide.lua` | The Material Finder page. |
| `tools/build_sources.py` | Builds `SourceData.lua` (not packaged). |

### Providers
A material has every provider that applies; none is forced into one:

- **nodes**: herbs and ore (`NODE_ITEMS`, the herb and ore guides, your spots). One material per item: Thorium Ore covers Small, Rich, Ooze Covered and Hakkari veins.
- **fishing**: `NW.FISHING.FISH`, only fish with a skill or zones. Fish Finder and the Fishing + Cooking plan stay where they are.
- **skin**, **loot**: `NW.SRC.items[id].skin` / `.loot`. Ordinary loot and skinning loot are separate lists from separate tables; a leather drop from a humanoid is loot, not skinning.
- **vendor**: Engine's vendor price table plus vendor NPCs from the source data.
- **craft**: `NW.RecipeFor(id)`.
- The auction house is the **Search AH** action, not a provider.

Categories are the material's first fitting kind (herb, ore, leather, fish, cloth, meat, elemental, reagent, vendor, crafted). Only categories with materials are shown. There's no Enchanting category: no disenchanting data Nodewalker could trust.

### Source data (`tools/build_sources.py`)
- **pfQuest** (MIT, Shagu, `LICENSES/pfQuest-MIT.txt`): creature spawn coordinates (zone %, respawn), ordinary loot chances, vendors.
- **cMaNGOS classic-db** (GPL-3, compatible with Nodewalker's GPL-3.0-or-later): creature levels, types, ranks, skinning loot (groups and references resolved to a chance per item).
- Both are **WoW Classic 1.12**, not WoW Forever. The page and tooltips say "Classic data". WoW Forever-only zones (Riverglades, Zephras Isle) and materials (Pristine Hide, Fel Leather and the like) have no creature data: they show no hunting grounds rather than made-up ones.
- Read as text, never executed. Outdoor zones only. Kept: skinning chances ≥ 3%, ordinary loot ≥ 1% (cloth ≥ 3%), the 80 creatures per material with the most chance × spawns. Left to their own providers: crafted items, vendor goods, herbs, ore, stone and gems. Spawns are 1% map cells.
- Rebuild: clone both repositories, decompress `Full_DB/ClassicDB_*.sql.gz`, then `python3 -I tools/build_sources.py <pfQuest> <classicdb.sql> .` About 370 KB, 145 materials, 2,068 creatures, 90 vendor-sold reagents.
- Skinning skill a creature needs: WoW Classic's rule (1 to level 10, then (level − 10) × 10 to 20, then level × 5), labelled as such.

### Hunting Grounds (`NW.Hunt`)
- **Density**: each known spawn point counts its creature's chance (0.6 for 60%). Bins are 3% of the map. Labelled "Known spawns × drop chance". Not creatures alive now, not guaranteed drops.
- **Filters**: creatures friendly to your faction, elites and rares (optional), and for skinning, creatures above your skill (optional, on by default).
- **Clusters**: the densest bin starts a ground; bins within 2 bins (6%) join it; repeat. Under 3 spawn points: counted as scattered. Up to 8 per zone. Centre is the chance-weighted centroid; radius is the furthest spawn point, at least 40 yards.
- **Routes**: grounds with at least a third of the best one's density, up to 6, nearest to you first, nearest next, then 2-opt. A loop. Straight-line yards, not paths; one ground is "stay and hunt".
- **Progress**: current, upcoming, hunted, skipped. Only **Next** / **Skip** move it (session panel). Standing inside the current ground shows "here". Revisit times use the Classic respawn times.
- **Sorting**: Most spawns (density), Nearest my level, My history (your log). Each says its basis on hover.
- **Overlay**: `Overlay.lua` calls `NW.Hunt.DrawOverlay` on each rebuild (not each frame) with its own line pool: muted gold ring for the current ground, bronze for upcoming, grey for done, bright cyan leg into the current ground, muted cyan for the rest, numbers at the centres. Off in Settings › Gathering.
- Cached per material, method and filters; cleared on skill and level changes.

### Selection state (`Guide.lua`, `sel`)
One table holds the selection: category, search text, material ID, source, zone (or vendor), the profession it was opened from, the shopping-list amount (`need`, kept only for the material it came with), and a short trail for ingredient navigation (`hist`, at most 5, no repeats). The map tab is `settings.huntMap`. Each refresh validates top-down: the material must be in the list on screen (category + search), else the first result or none; the source must be one the material has; the zone must be in that source's rows, else the first. So no part of the page can show a material the list doesn't. An active hunting route (`charDB.hunt`) is separate: browsing never stops it; only Stop route does. The old defect: the material was looked up in the whole catalog by ID, so a category switch left the previous material (and its zones and map) on screen.

### Layout
The centre column splits the page height between the materials (5 to 12 rows) and the source table (4 to 8 rows): the table's rows, the creature fold and the filters are sized first, the list takes the rest, and a short list gives its spare room back to the table. **Expand map** scales the same map frame up over the centre and header (no second renderer); it ends when you pick another material or a source without a map. Actions sit right under the map's caption (or under the recipe workspace). What the selected source needs (profession, skill) is beside its switch: "Mining not learned · preview only" never blocks a preview.

### Herb and ore value
"g/h" is **theoretical**: every known spot up every lap, two items each, Auctionator prices, a mounted loop with no gathering time. Known spots are where nodes have spawned, not nodes up at once, so it's an upper bound, never income. Nodes without a price are left out and the figure is marked partial (+), never counted as zero. There is no observed gold per hour yet: the gathering log has no time per zone.

### Mixed routes
**Also pick other herbs and ore** adds only nodes you can gather now (profession learned, skill at least the node's requirement) on top of your filters; the selected herb or ore itself is always in, learned or not, so a route can be previewed. A mixed route says so on the map. Targets never change with it.

### Interactive hunting grounds
- **Sorts** (`H.SORTS`): Most per clear (spawn points × drop chance × average count, the items if every known spawn were killed once; not per hour), Most spawn points, Nearest my level, Nearest to me (straight line to the zone's middle, same continent), My history. Ties go to per clear, then name.
- **Grounds**: click a ring (Known Sources, Heatmap or Route) to select it: the ring turns bright gold, the creature list shows only that ground's creatures, the side column shows its levels, spawn points, Skinning needed, Classic respawn and what you collected inside it. Actions: Farm this area (a one-ground route), Add to route / Remove from route (when this material's route is active here), Show on map. Click it again or the map's empty space to clear.
- **Creatures**: click one in the list to show only its known spawn points (other grounds faint); click again or Show all to restore. The list scrolls with the mouse wheel ("1-3 of 14").
- **Route edits** (`H.AddGround`, `H.RemoveStop`, `H.SetStart`, `H.Reverse`, `H.StartSingle`): adding inserts where the loop grows least; states and hunted times stay with their stops; an edited route is marked custom, and Restore rebuilds the suggested one. One route engine (Hunt.lua).
- No zoom or pan: the window map has none to reuse. Expand map is the larger view.

### Data notes (second pass)
- The cMaNGOS skinning loot table also holds Herbalism, Mining and Engineering loot from creatures flagged for them (`CreatureTypeFlags` 0x100, 0x200, 0x8000), and lists a Sheep (a critter) as skinnable for Wool Cloth. Both are left out of skinning now: no cloth has a Skinning source.
- Respawn times are cMaNGOS/pfQuest's Classic spawn timers, shown as "Respawn (Classic)"; WoW Forever's may differ. Kept because they're the only figure there is and they're labelled.
- Spawn points are de-duplicated to 1% map cells, so stacked spawns count once.
- Recipe colours: the profession window's colour for each recipe at your skill pins its thresholds (`db.colorSeen`), applied to the leveling data and the catalog at login and after each scan.

### Collection objectives (`charDB.matGoals`)
`{ id, mode, n, base, from }`, at most 8. **Own** (`total`): have n in bags and bank. **Collect** (`more`): n more than you had when it was set (`base`). Progress is read from `GetItemCount(id, true)` every time, never from the log. Opening from a shopping list fills in the missing count as **Collect**; nothing is set until you click Track, and an existing target is only changed by Update. **Tracked** on the left lists them.

### Loot attribution (`NW.GatherLog`)
- `skin`: a creature loot window within 3 s of your Skinning cast (`UNIT_SPELLCAST_SUCCEEDED`, spells 8613/8617/8618/10768 or the same name).
- `herb` / `ore`: a game object window within 3 s of Herb Gathering / Mining.
- `loot`: a creature window with no Skinning cast before it. The loot before skinning is ordinary loot; the window after the cast is skinning.
- Nothing for chests without a gathering cast, containers, Pick Pocket, fishing (the Fishing Journal's), mail, trades, vendors, the bank or crafting: they don't open a creature or gathering loot window.
- Creature identity from `GetLootSourceInfo`'s GUID. Without that function: only windows right after a gathering cast, with no creature.
- Counted at `LOOT_SLOT_CLEARED`, once per slot; `LOOT_READY` and `LOOT_OPENED` are one window. Loot left in a full bag isn't counted.
- Only materials: Material Finder's catalog or the game's Trade Goods class.
- The combat log isn't used (WoW Forever hides it from addons).

### Storage (`charDB.gatherLog`, v 1)
`items[id] = { n, first, last, m = { skin, loot, herb, ore } }`, `npcs[npc] = { skin, loot, items }` (up to 1,500), `zones[mapID] = { n, items }`, `spots[mapID][cell]` (2% cells, up to 400 per map), `events` (loot windows by method), `recent` (100). Item and creature names are never stored. Fish totals come from the Fishing Journal when shown, never copied. The session panel's session keeps `mats` and `events`; creature materials add to its value at Auctionator or vendor price.

### Economics
Prices come from `NW.Price` (Auctionator, else vendor). A missing price shows "–", never zero. Values are estimates. No gold-per-hour for hunting: no gathering speeds or kill rates to base it on.

### Performance (test harness, texlua 5.3 on the dev box)
- Catalog: 307 materials, under 1 ms.
- Search: 200 keystrokes, 7 ms (one pass over a 307-entry index; rebuilt only when item names arrive).
- Hunting grounds: Heavy Leather, 22 zones with clusters, 9 ms; every creature material and method, 240 ms total (each is computed once, when opened, then cached).
- 100,000 gathering records: 300 ms; the log stays at its caps (1,500 creatures, 400 cells per map, 100 recent).
- Page refresh with that log: 2 ms each.

### Known limits
- Creature data is Classic: spawns, levels and chances can differ in WoW Forever, and Forever-only creatures and zones aren't there.
- Zone coordinates assume WoW Forever's zone maps match Classic's. A zone whose name isn't on your client's map list shows "Not on your client's map list" (The Barrens, if Forever splits it).
- No terrain-aware paths: route lengths are straight lines.
- No respawn or alive detection: "back ~5 min" is the Classic respawn time after you press Next.
- No disenchanting provider and no Enchanting category.
- No combined multi-material routes: one material at a time, a queue of up to 8 targets.

### Tests
`mat_test.lua` (scratchpad harness): every category; each provider on a known material; search by name, partial name, ID, link and "skinning"; grounds and clusters valid for Heavy Leather; skinning skill filter; Raptor Flesh only from loot; every creature material's grounds; plan, length, start, Next, Skip, revisit, "here", overlay drawing; attribution: ordinary loot then skinning the same corpse, late window, chest, herb, Pick Pocket, fishing, gear, no `GetLootSourceInfo`; objectives Own and Collect, clear done, the cap; the page for every category, every provider, every map mode and sort, from a profession, the old entry point, Skinning's brackets; the session panel lines; 100,000 records. Older harnesses (`ui_test`, `tabs_test`, fishing, professions, routes) still pass.

Needs the game: skinning and loot windows (GUIDs, cast timing), creature names and levels against WoW Forever, zone maps lining up with the Classic coordinates, the overlay rings, the session panel's Next / Skip, the page layout at 60–150%.

## Leveling kits

Each crafting profession a character has gets one baseline plan from 1 to 300 (`charDB.planKit[key]`), chosen once at that day's prices and ignoring bags. Every later plan for the profession follows the kit's recipes point for point; prices and bags only change the shopping list. A new kit is chosen on Re-plan, when Strategy, resale or "Include purchasable recipes" changes (`kitSig`), or after the profession reaches the kit's end. What-if plans (the purchasable-recipe comparison, the Fishing + Cooking plan) set `NW.kitHold` so they neither follow nor replace it.
