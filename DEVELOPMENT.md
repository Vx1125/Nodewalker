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
One key, set in Settings › Fishing, applied as an override binding (`SetOverrideBindingClick`) so the game's own key bindings are never changed. A key already bound to something asks for a second press. Each press clicks the hidden secure button `NodewalkerSmartFish`, whose action is set out of combat from the current state:

1. no pole on, and a fishing set or a pole in your bags: a macro of `/equipslot` lines;
2. lures on (Settings › Fishing › Lure), no temporary enchant on the pole, and a lure in your bags: `/use item:<lure>` then `/use 16`;
3. otherwise: the Fishing spell.

While the Fishing channel runs, the key is pointed at `INTERACTTARGET` and `SoftTargetInteract` is set to 3 (restored when the channel ends), so the same key reels in through the game's soft-target interact. The game gives addons no bite signal: the HUD says "press when it splashes", nothing more. Nothing happens without a key press, and bindings and secure buttons aren't changed in combat (queued for `PLAYER_REGEN_ENABLED`).

Researched: EzFishing Forever and Fishing-OneKey (MIT) do the same cast / interact switch; FishFry Forever (all rights reserved) wasn't read for code.

- **Gear:** "Use what I'm wearing" saves your pole and, if ticked, head, hands and feet (per character, `charDB.fishGear`). Without a saved set, the best pole in your bags (`SF.POLES`, else +0). Before equipping, what you wore in the main hand, off hand and the set's slots is saved (`charDB.fishPrev`), but never while you already have a pole on. Restore puts back what's in your bags and names what isn't.
- **Lures:** No lure, My preferred lure (optionally another if you're out), or Strongest I carry. Bonuses from Method's WoW Forever guide. A lure isn't replaced while one is on. The lure's name shows only if Nodewalker put it on (the game reports only that an enchant is there and its time left). Alerts: 30 seconds left, expired, under 3 left, preferred one missing; each once.

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
Start with your first cast or catch (Settings: Start one when I cast), or not at all (Sessions off). Fishing time adds the gap between casts and catches only when it's 2 minutes or less, so AFK time doesn't count. 20 minutes without fishing ends a session at your last activity. Pause, Resume, End and Delete are in the Journal's Sessions view.

### Fishing + Cooking in the HUD
`SF.Target()` runs `F.Build()` only after bags, skills or recipes change (never per catch) and shows the plan's current fish: have, ~need, a bar. When it fills and the next step is to cook, "Collection complete. Next: Cook …".

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
