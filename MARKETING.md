# Nodewalker: CurseForge presentation

What goes on the CurseForge page besides the description (`CURSEFORGE.md`), and what to check before saying it.

## Summary (CurseForge "Summary" field)

> Farm smarter, level professions for less, and find crafts worth making: short gathering routes on a Diablo-style map overlay, and profession plans priced from Auctionator. For WoW Forever.

188 characters.

## Gallery

In this order. The first image is the overlay in the game world, because nothing else on CurseForge looks like it.

| # | File | Title | Caption |
|---|---|---|---|
| 1 | overlay.jpg | Gathering GPS | Follow your gathering route without leaving the game world. |
| 2 | professions.jpg | Profession leveling | Plan the cheapest way to your target skill at today's auction prices. |
| 3 | herb-guide.jpg | Farm Guide | Compare zones for any herb or ore and build the route in one click. |
| 4 | profit.jpg | Profit | Find crafts worth a look, after the auction cut. |
| 5 | missing-recipes.jpg | Missing recipes | Every recipe you don't know yet, and where to get it. |
| 6 | consumes.jpg | Consumes | Raid stock for your class and spec: have, need, craft or buy. |
| 7 | find-a-craft.jpg | Find a Craft | What any craft costs to have made, after what's in your bags. |
| 8 | routes.jpg | Routes | Short loops past every known spot, around the places you'd rather avoid. |
| 9 | settings.jpg | Settings | Farming, Questing or Minimal, or tune every part of the overlay. |

`banner.jpg` stays at the top of the description, not in the gallery. Remove `profession-window.jpg` from the gallery: it shows the old layout from before 1.1.17.

## GIF 1: Gathering GPS (primary)

12–15 s, 15 fps, 1280 px wide. No narration; one caption at a time, bottom left, gold on dark.

| Time | Shot | Caption |
|---|---|---|
| 0–2 s | Farm Guide open, Herbs. Click Peacebloom (or any herb with lots of known spots). | Pick an herb |
| 2–4 s | Click a zone row (the one you're standing in). The preview map draws its loop. | Pick a zone |
| 4–5 s | Click **Build route**. | Build the route |
| 5–6 s | Close the window, type `/nw`. The overlay fades in. | |
| 6–11 s | Ride along the cyan line, a few known spots ahead, the compass bar showing stops. One node goes green as it reaches your minimap. | Follow it |
| 11–14 s | Gather the node. Its marker turns into a grey dot; the session panel's count goes up. | Gathered spots grey out |

Framing: full 1920×1080 game, UI scale default, overlay in Farming preset at about 50% of the screen. Daylight zone with clear terrain (Elwynn, Mulgore, Tirisfal). Mounted for the ride, unmounted to gather. Hide other addons' frames and chat.

## GIF 2: Profession leveling

10–15 s, same settings.

| Time | Shot | Caption |
|---|---|---|
| 0–2 s | Professions tab, click Tailoring (or First Aid). | Pick a profession |
| 2–4 s | Drag **Target skill** to 225, or click 225. | Choose your target |
| 4–7 s | The plan fills in by rank; scroll a little. Hold on the estimated cost at the top. | Cheapest path at today's prices |
| 7–10 s | Hover the shopping list: recipes to buy, materials, bag counts. | Minus what's in your bags |
| 10–13 s | At the auction house, click **Search missing**; Auctionator's shopping list opens. | One search for the rest |

Framing: the Nodewalker window centred at Window scale 100%, auction house open behind it for the last shot. A character with some materials in bags, so the bag counts show.

## Claims to check in game before publishing

- Compass bar shows the route's stops ahead of you.
- Gathered node turns grey and stays grey for the Gathered node cooldown.
- Session panel counts the node and its value.
- **Show on map** on a missing recipe pins its trainer or vendor.
- **Craft** from a leveling step opens the craft.
- Profit counts disenchant value for gear.
- Consumes, My level, at a low level: no food whose recipe is only sold above your level (1.1.20).
- **Search missing** opens Auctionator's search with the current Auctionator release.

## Release readiness (1.1.20)

Fixed in this pass:

- README listed old commands and missed `/nw import help`, `/nw reset session`, `/nw hidden`. Now a full table; debug commands moved to DEVELOPMENT.md.
- README had a placeholder for the CurseForge link. Now linked.
- No player FAQ or quick start. Added `FAQ.md` and `QUICK_START.md` (shipped in the zip).
- Leveling and Consumes buttons are "Search missing", not "Search missing in Auctionator", while recipes are on the list. Docs use the shorter name.
- Dev docs (`DEVELOPMENT.md`, `MARKETING.md`, `UI_DESIGN_STANDARD.md`) are kept out of the package.

To do on CurseForge (by hand):

- Paste `CURSEFORGE.md` into the description and the summary above into Summary.
- Add links: Issues → https://github.com/Vx1125/Nodewalker/issues, Source → https://github.com/Vx1125/Nodewalker.
- Gallery: reorder and add titles and captions from the table above (they're file names now); remove `profession-window.jpg`.
- The Main File showed 1.1.19 just after 1.1.20 uploaded. Check it's 1.1.20 once CurseForge has processed the file.

Checked and fine:

- Version: VERSION 1.1.20, CHANGELOG has 1.1.20, the toc's version comes from the tag.
- Client: interface 16001; CurseForge lists WoW Forever 1.60.1.
- Dependencies: the toc lists GatherMate2 and Auctionator as optional only; nothing is required. The docs say the same.
- License: GPL-3.0-or-later in the toc, LICENSE, README and the description (CurseForge shows GPLv3). Unchanged.
- Name: "Nodewalker" everywhere.
- Economic claims: every price, profit, resale and gold-per-hour figure is called an estimate; none promises a sale.
- Resource claims: known spots are described as where nodes have spawned, never as nodes that are up.
