# Nodewalker

**Farm smarter. Craft cheaper. Earn more.**

A profession and gathering companion for WoW Forever: gathering routes on a Diablo-style map overlay, profession leveling plans priced from the auction house, missing recipes and where they come from, crafting profit, Fishing and Cooking together, and consumables for every class.

- CurseForge: <https://www.curseforge.com/wow/addons/nodewalker>
- [Quick start](QUICK_START.md) · [FAQ](FAQ.md) · [Changelog](CHANGELOG.md)
- Bugs and ideas: [GitHub issues](https://github.com/Vx1125/Nodewalker/issues)

![Gathering overlay](screenshots/overlay.jpg)

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
| `/nw plan` | Route tab |
| `/nw guide` | Farm Guide |
| `/nw prof` | Professions |
| `/nw consumes` | Consumes |
| `/nw journal` | Fishing Journal |
| `/nw fishhud` | Fishing HUD on or off |
| `/nw options` | Settings |
| `/nw import` | Import GatherMate2 spots |
| `/nw import help` | The GatherMate2 import steps |
| `/nw status` | Spots and route in this zone |
| `/nw reset session` | Restart the session panel |
| `/nw next` | Skip the route's next stop |
| `/nw hide <herb>` · `/nw show <herb>` · `/nw hidden` | Hide or show one herb or vein |

`/nodewalker` works the same as `/nw`. Key bindings: Toggle overlay, Toggle route planner, Skip to next stop, Toggle fishing HUD, Fishing Journal. The Smart Fishing key is set in Settings › Fishing.

## Credits

Minimap tile tables in `OpenMapData/` come from [OpenMap](https://github.com/openmap-world/openmap) (MIT, see `LICENSES/`).
Recipe data: SeeMeta's WoW Forever recipe database.
The full recipe list, sources and trainer fees are derived from [One For All](https://www.curseforge.com/wow/addons/oneforall) by Smoergi (GPL-3.0-or-later, see `LICENSES/`).
Consumable lists follow Method's and Wowhead's WoW Forever class guides.

## License

GPL-3.0-or-later. See `LICENSE`.

Working on the code: see [DEVELOPMENT.md](DEVELOPMENT.md).
