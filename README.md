# Nodewalker

**Gather. Craft. Profit. Prepare.**

Your complete profession companion for WoW Forever. Nodewalker plans profession leveling at auction prices, finds every material and where to farm it, draws gathering routes on a Diablo-style see-through map, shows which crafts are worth making, keeps each character's shopping list in one place, and tracks your consumables.

- CurseForge: <https://www.curseforge.com/wow/addons/nodewalker>
- [Quick start](QUICK_START.md) · [FAQ](FAQ.md) · [Changelog](CHANGELOG.md)
- Bugs and ideas: [GitHub issues](https://github.com/Vx1125/Nodewalker/issues)

![Farming overlay](screenshots/overlay.jpg)

## Features

- **Professions:** a 1-300 leveling plan for every crafting profession (Cheapest, Fewest crafts or Known recipes), steps by rank, trainers on your map, one shopping list minus your bags, Auctionator search, crafting from the plan. Gathering guides for Herbalism, Mining and Skinning; a Smelting view for Mining.
- **Material Finder:** every material and each way to get it: Herbalism and Mining zones, Skinning and Creature loot hunting grounds, world objects, Fishing, vendors and crafting. Zone maps, routes and collection targets.
- **Farming Overlay:** a see-through, click-through map with soft edges, known spots and live minimap nodes, your route with direction, a compass bar, presets (Farming, Questing, Minimal) and a session panel. Routes loop past every known spot and go around avoid zones you draw.
- **Characters:** every character's saved shopping list; what an alt still needs, what you can send, Prepare mail at a mailbox, Auctionator searches and farming targets for another character's needs.
- **Missing Recipes:** what you don't know yet and where it comes from, filtered by source, with reputation and your faction's trainers and vendors.
- **Profit:** material value, sale price after the auction cut, net profit and return, a batch calculator, disenchant value for gear.
- **Find a Craft:** any recipe in any profession, its materials after your bags and the item's auction price.
- **Consumes:** lists for every class and spec, for leveling or raiding, Best, Budget or Use what I own, stock for a session, craft or buy, saved loadouts.
- **Consume Tracker:** a small on-screen bar: missing and expiring buffs, counts, durations, cooldowns, ready-check reminder, click to use.
- **Fishing:** Smart Fishing (one key: gear, lure, cast, reel in), fishing gear sets, lures, a HUD, the Fishing Journal, and Fishing + Cooking together.

Nodewalker never gathers, moves, fishes, buys, mails or crafts by itself. Every action is a key press or click of yours.

## Install

Install from CurseForge, or copy the `Nodewalker` folder into `World of Warcraft\_forever_\Interface\AddOns`.

| | Addon | What it adds | Without it |
|---|---|---|---|
| Required | none | | |
| Recommended | Auctionator | Auction prices everywhere; the Search buttons | Vendor prices; the rest estimated (~) or "No price" |
| Optional | GatherMate2 + GatherMate2_Data | One-time import of known spots (`/nw import`) | Nodewalker learns spots as you gather |

Client: WoW Forever (interface 16001).

## Commands

| Command | Opens |
|---|---|
| `/nw` | Overlay on or off |
| `/nw prof` | Professions |
| `/nw guide` | Material Finder |
| `/nw plan` | Routes (in Material Finder) |
| `/nw consumes` | Consumes |
| `/nw buffs` | Consume Tracker on or off |
| `/nw journal` | Fishing Journal |
| `/nw fishhud` | Fishing HUD on or off |
| `/nw options` | Settings |
| `/nw window` | The Nodewalker window |
| `/nw import` · `/nw import help` | Import GatherMate2 spots, and the steps |
| `/nw status` | Spots and route in this zone |
| `/nw next` | Skip the route's next stop |
| `/nw reset session` | Restart the session panel |
| `/nw hide <herb>` · `/nw show <herb>` · `/nw hidden` | Hide or show one herb or vein |
| `/nw buffs debug` · `/nw buffs auras` · `/nw buffs learned` · `/nw buffs reset` | What the tracker reads, every buff on you with its spell ID, the buffs it has learned, and forgetting them |
| `/nw perf` · `/nw perf on` · `/nw perf off` | Timings and memory, for bug reports |

`/nodewalker` works the same as `/nw`.

**Key bindings** (Key Bindings › AddOns › Nodewalker): Toggle overlay, Toggle Routes, Skip to next stop, Smart Fishing, Toggle fishing HUD, Fishing Journal. Smart Fishing can also be set in Settings › Fishing.

## How Consumes chooses

- **Activity: Leveling** builds a list for your level: the best of each kind (food, elixirs, potions, oils and stones, scrolls, bandages by First Aid skill) you can use now, from items in the game whose recipe you can reach at your level. It moves up as you level; the next one and the level it unlocks at are in the row's tooltip.
- **Activity: Raiding** is your spec's level-60 list, from the guides credited below.
- Both lists are in categories (Food, Elixirs, Weapon, Potions, Bandages, Utility, Situational, Camp), and each row has a tier. **Core** rows start ticked; **optional** and **situational** ones only count once you tick them.
- Healers level by questing, so a healing spec's leveling list is its class's solo list, with the healing elixir and potion as optional.
- **Strategy: Best** takes the strongest; **Budget** the raid budget list, or when leveling the cheapest priced one within 10 levels of yours; **Use what I own** puts what's in your bags first.
- **Loadouts** save your spec, activity, strategy, stock, choices and targets per character.
- Stock is an estimate: buffs by the duration the game gives, other items at a rough rate an hour. Deaths aren't counted.

## Consume Tracker

Settings › Consumes (or `/nw buffs`) turns on a small bar of the consumables in your Consumes loadout. Each icon shows what's on you and for how long, how many you carry, and a coloured edge when it's expiring (gold) or missing while you carry one (red); one you've run out of is faded. Potions, runes and bandages get their own optional row with their cooldowns; they're never "missing". Click an icon to use the item; right-click opens it in Consumes.

Buffs are recognised by spell ID: the item's own use spell from the game, or the buff Nodewalker saw you get when you used it (food's Well Fed, weapon enchants). One it hasn't confirmed yet shows as unknown, never as missing. In combat the game hides your buffs from addons, so the tracker counts down what it saw before the pull.

## Data sources

Nodewalker ships reference data from these sources; each has a notice in `LICENSES/`.

| Data | Source | Licence | Files |
|---|---|---|---|
| Minimap tile tables and map reveal | [OpenMap](https://github.com/openmap-world/openmap) | MIT | `OpenMapData/` |
| Recipes, reagents, skill colours, recipe items, trainer fees, smelting | [OneForAll – Forever](https://www.curseforge.com/wow/addons/oneforall-forever) 6.3.0 by Smoergi, from the WoW Forever client database, QuestieDB/Questie (GPL-3.0) and ProfessionDB (MIT) | GPL-3.0-or-later | `Professions/Catalog.lua`, the profession lists, `Mining.lua` |
| Creature levels and types, skinning and reference loot, Classic recipe sources, smelting trainers | [cMaNGOS classic-db](https://github.com/cmangos/classic-db) @ 13e9337 | GPL-3.0 | `Materials/SourceData.lua`, profession lists |
| Creature and object spawns, loot chances, vendors | [pfQuest](https://github.com/shagu/pfQuest) by Shagu @ 104f356 | MIT | `Materials/SourceData.lua` |
| Smelting skill-up colours | [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Forever_mining_techniques) contributors | CC BY-SA 4.0 (separate file) | `Professions/SmeltingColours.lua` |

Game facts also come from guides and sites, used as facts only (no text or images): Forever learn levels from wowtbc.gg (via One For All), new Forever recipe sources from Wowhead and other guides (each override records its evidence), consumable lists from Method's and Wowhead's WoW Forever class guides, fishing from Method and wow-professions, and herb and ore zones from Wowhead, Gfinity, Warcraft Tavern and wow-professions guides.

Creature, object and loot data is WoW Classic 1.12 data and is labelled as such in game. World of Warcraft content remains Blizzard's and is not covered by these licences.

## Development

- Plain Lua and frames, no libraries; LibDBIcon is used for the minimap button only when another addon loads it.
- `Materials/SourceData.lua` and the profession files are generated: change `tools/build_sources.py`, `tools/build_recipes.lua` or their inputs and rebuild, never edit them by hand. `tools/test_sources.py` and `tools/test_recipes.py` check the output.
- Every push runs a Lua 5.1 syntax check. Releases are tagged from `VERSION` and packaged to CurseForge by GitHub Actions.

## License

GPL-3.0-or-later. See `LICENSE`. Dataset licences are in `LICENSES/`.
