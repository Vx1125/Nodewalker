![Nodewalker](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/banner.jpg)

# Farm smarter. Craft cheaper. Earn more.

**Nodewalker is a profession and gathering companion for WoW Forever.**

Follow a short gathering route on a see-through map over the game world. Level any profession the cheapest way at today's auction prices. See which recipes you're missing and where they come from, and which crafts are worth a look. Nothing to alt-tab for.

Leveling a profession, getting ready for raid night, or out picking herbs and ore for the evening: Nodewalker helps you decide what to do next.

## Gathering GPS

![Gathering overlay](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/overlay.jpg)

- A Diablo-style map in the middle of your screen, see-through and click-through
- Herb and ore spots with the game's own icons
- **Seen now** (on your minimap) lights up green; **known spots** from earlier stay faded. A known spot is where a node has spawned before, not a promise one is there now
- Your route in cyan: brightest near you, with direction arrows
- A compass bar with the route's stops ahead of you
- A ring showing your minimap's range, where live nodes can show up
- Gathered spots turn grey until they can respawn
- Session panel: time, nodes gathered, loops, and their value at Auctionator prices
- Presets: **Farming**, **Questing**, **Minimal**
- Fades while you move; can hide in combat and in cities

## Routes

![Route planner](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/routes.jpg)

- A short loop with every known spot in sight along the way
- Built for you when you enter a zone; **Optimize loop** rebuilds it
- Draw avoid zones on a large, fully explored map, and the route goes around them

## Farm Guide

![Farm Guide](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/herb-guide.jpg)

- The best zones for each herb and ore, side by side: known spots, loop time, spots per minute, estimated gold per hour
- A map preview of each zone's loop
- One click builds the route
- **Both** view for Herbalism and Mining together

Loop times and gold per hour are worked out from known spots and current prices. What you actually gather depends on spawns and other players.

## Profession Leveling

![Leveling](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/professions.jpg)

- A plan to your target skill for every profession, at today's prices
- Choose a strategy: **Cheapest**, **Fewest crafts**, or **Known recipes**
- Steps grouped by rank, with each trainer one click from your map
- Crafts per step, from each recipe's skill-up chance
- One shopping list: recipes to buy, materials and vendor supplies, minus what's in your bags
- Estimated total cost, with resale value beside it
- One click to search Auctionator for what's missing; craft straight from the plan

Costs and craft counts are estimates: prices move and skill-ups are random.

## Missing Recipes

![Missing recipes](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/missing-recipes.jpg)

- The recipes you don't know yet, and where each comes from
- Filter by source: trainer, Merchant's Favor, vendor, drop
- Your faction's trainers and vendors, shown on your map
- Recipes with many drop sources read "World Drop or AH"

## Profit

![Profit](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/profit.jpg)

- What each recipe's materials cost and what the result lists for, after the auction cut
- Sort by profit, return, cheapest materials, or how many your bags can make now
- Click a recipe for its materials and what each costs
- Counts disenchant value for gear

Listing prices aren't sales. Profit here means worth a look, not guaranteed gold.

## Consumes

![Consumes](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/consumes.jpg)

- Consumables for every class and spec
- **My level**: the best you can use, and get, while leveling
- Stock for a 2, 3 or 4 hour raid: what you have against what you need
- Craft or buy, side by side, with the materials needed
- One Auctionator search for everything you're short of
- Saved per character

## Find a Craft

![Find a craft](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/find-a-craft.jpg)

- Any recipe in any profession, to have someone make it
- What the materials cost, what's left after your bags, and the auction price ready-made

## Also

![Settings](https://raw.githubusercontent.com/Vx1125/Nodewalker/main/screenshots/settings.jpg)

- Gathering and Fishing guides by skill range
- A Nodewalker button on your profession window
- Minimap and AddOns menu button, key bindings
- Every overlay setting: size, opacity, terrain, markers, ring, compass, session panel

## Quick start

**Start gathering:** `/nw guide` › pick an herb or ore › click a zone › **Build route** › go there and type `/nw` › follow the cyan line.

**Level a profession:** `/nw prof` › pick a profession › **Leveling** › set your target skill › buy what's on the list (**Search missing**) › follow the steps.

**Find crafts worth making:** `/nw prof` › pick a profession › **Profit** › sort by profit › click a recipe for its materials.

## Requirements

- **Required:** nothing else. Nodewalker works on its own.
- **Recommended: Auctionator.** Auction prices for leveling costs, profit, consumes, the Farm Guide and the session panel, and the Search buttons. Without it, vendor items keep their vendor price and the rest show as estimates (~) or "No price".
- **Optional: GatherMate2 + GatherMate2_Data.** A one-time import of thousands of known spots (`/nw import`). Without it, Nodewalker learns spots as you gather and as they show on your minimap. You can turn GatherMate2 off after the import.

Prices come from Auctionator's last scan, so scan the auction house now and then.

## FAQ

**Does it gather or move for me?** No. It shows where to go; you walk, gather, buy and craft.

**Are the spots guaranteed to have a node?** No. Faded spots are where nodes have spawned before. Green ones are on your minimap right now.

**Do I need a gathering profession?** Only for the overlay, routes and Farm Guide. Leveling, Profit, Consumes and Find a Craft work for everyone.

**Why do some items say "No price"?** Auctionator hasn't seen them listed. Scan the auction house and they fill in.

**How do I change a route?** Open the Route tab: **Optimize loop** to rebuild it, or draw avoid zones and it goes around them.

**Which game versions?** WoW Forever.

**Found a bug?** [Report it on GitHub](https://github.com/Vx1125/Nodewalker/issues) with what you did and any error text.

## Commands

`/nw` overlay · `/nw plan` routes · `/nw guide` Farm Guide · `/nw prof` professions · `/nw consumes` · `/nw options` · `/nw import` GatherMate2 · `/nw status` · `/nw reset session`

## Credits

Minimap tiles and map reveal data: [OpenMap](https://github.com/openmap-world/openmap) (MIT). Recipe data: SeeMeta and One For All by Smoergi (GPL-3.0-or-later). Consumable lists follow Method's and Wowhead's WoW Forever guides.

GPL-3.0-or-later.
