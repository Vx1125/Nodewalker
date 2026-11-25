# Nodewalker FAQ

**Do I need Auctionator?**
No, but it's recommended. Auctionator gives Nodewalker auction prices for leveling costs, Profit, Consumes, Find a Craft, the Farm Guide's gold per hour and the session panel, and makes the Search buttons work. Without it, vendor items keep their vendor price and everything else shows an estimate (~) or "No price". Prices are from Auctionator's last scan, so scan now and then.

**Do I need GatherMate2?**
No. GatherMate2 with GatherMate2_Data lets you import thousands of known spots at once (`/nw import`). Nodewalker keeps its own copy, so you can turn GatherMate2 off afterwards. Without it, Nodewalker learns spots as you gather and as nodes show on your minimap, so routes and the Farm Guide fill in as you play.

**Can I use Nodewalker without a gathering profession?**
Yes. Leveling, Missing recipes, Profit, Consumes and Find a Craft work for every profession. The overlay, routes and Farm Guide are for Herbalism and Mining. By default the overlay only shows what you can gather (**Only my professions** in `/nw options`).

**Does Nodewalker gather for me, or move my character?**
No. It shows where to go and what's there. You walk, gather, buy and craft yourself. The Auctionator buttons fill in a search; you choose what to buy.

**How are routes made?**
From the spots Nodewalker knows in that zone. It picks as few stops as it takes for every spot to be within sight of one, then orders them into a short loop. Where a loop can't close, it goes there and back. Avoid zones you draw are routed around.

**Are the spots on the map guaranteed to have a node?**
No. A faded marker is a spot where a node has spawned before. A green marker is a node on your minimap right now. Gathered spots turn grey until the node can respawn. Other players and spawn timers decide what's actually up.

**How are leveling costs worked out?**
For each skill range, Nodewalker picks recipes by your strategy (Cheapest, Fewest crafts or Known recipes) and counts crafts from each recipe's skill-up chance. Materials are priced at Auctionator's lowest listing or the vendor price, minus what's in your bags, plus training and recipe costs. Resale value is shown beside the cost as an estimate. Real costs differ: prices move and skill-ups are random.

**Are crafting profits guaranteed?**
No. Profit is the current lowest listing, minus the auction cut, minus material costs. It tells you which crafts are worth looking at, not what will sell.

**Why are some prices missing?**
Auctionator hasn't seen the item listed, or isn't installed. Scan the auction house and they fill in. Totals missing a price show a red "+?".

**Can I change how the overlay looks?**
Yes. `/nw options`: size, opacity, zoom, terrain colour, the minimap range ring, compass, session panel, gathered spots, and which herbs and ore show. Farming, Questing and Minimal set several of these at once.

**How do I change or rebuild a route?**
Open the Route tab (`/nw plan`). **Optimize loop** rebuilds it from the spots you know now. **Draw avoid zone** and **Clear avoid zones** steer it. Building a zone's route from the Farm Guide replaces it too.

**Which game versions are supported?**
WoW Forever (interface 16001).

**How do I report a bug?**
On [GitHub issues](https://github.com/Vx1125/Nodewalker/issues), or in the comments on CurseForge. Say what you did, what you expected, and paste any Lua error.
