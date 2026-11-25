# Nodewalker UI design standard

The look and layout settled in 1.1.17. New features follow it; changes to it need a real usability reason.

## Layout

- **Left:** navigation and selection (professions, herbs and ore, specs).
- **Centre:** browsing, comparing and progression (plans, recipe lists, zone tables).
- **Right:** what's selected, its numbers, and the main action for it.
- **Tooltips:** explanations, how numbers are worked out, why a button is off.
- **Folding sections / help buttons:** longer reference (controls, commands, profession notes).

Show information, not instructions. No paragraphs on a page; a short label, and the rest on hover.

## Colours (`NW.STYLE` in Widgets.lua; `S.HEX` for text codes)

| Use | Hex |
|---|---|
| Main frame | #141311 |
| Panels, buttons | #201E1A |
| Title bar, column headers, section headings, status bar | #242019 |
| Border (1 px) | #51432B |
| Lists and maps | #181714 |
| Accent gold | #D6B266 |
| Text | #E0DBD0 |
| Secondary text | #938C80 |
| Good / have / cheaper | #94BA78 |
| Bad / short / unknown price | #D17665 |
| Hovered row | gold wash at 7% (the highlight layer draws over text) |
| Selected row | #38301E with a 2 px gold left edge |

Skill-up colours (orange, yellow, green, grey) mean skill-ups only. Item names may use their quality colour.

## Type and sizes

- Font: the game's standard font. 17 headers, 13–14 values, 12 body, 11 secondary, 10 captions.
- Window 1020 × 622; title bar 38; tab bar 32; page padding 16; panel gap 10–12.
- Rows: 38–40 two-line, 24 compact headings and table rows, 26 shopping rows, 16–17 dense lists.
- Icons: 20–24 in rows, 16 in material lists, 38–40 in headers.

## Components (Widgets.lua)

- `UI.Button` (plain or `"primary"` gold), `UI.Check` (gold tick on dark bronze), `UI.Slider` (label left, value right with units), `UI.Dropdown`, `UI.CheckMenu` (less-used filters), `UI.Heading`, `UI.Section` (panel with header strip), `UI.RowHighlight`, `UI.RowStripe`, `UI.Tip`.
- Scroll bars: thin bronze track, gold thumb.
- Folding headings: +/– icon, name in gold, count right, header background.
- Settings are grouped under one Settings tab: General, Appearance, Gathering, Routes, Herbs & Ore. Settings that depend on another are greyed out (value kept) while it's off.

## Money

- `NW.Money(c)` full; `"gs"` gold and silver for summaries; `"mid"` keeps silver under 10g; `true` short.
- Estimates carry `~`. A total missing prices carries a red `+?`. An unknown price is "No price" or "–", never zero.
- Resale, profit and gold per hour are estimates, and say so on hover.

## Gathering overlay

The overlay is a map for getting around, not a second window. It keeps its own cyan route; the window's gold and bronze aren't forced onto it.

- **Route:** cyan (`C.route`) with a dark underline. Legs near you are brightest and thickest (3.5 px, 95%) and carry direction arrows. Further out they thin (2.5 px, then 1.5 px) and fade, down to 18% at the map's edge. Nothing animates.
- **No "next stop" highlight.** It was removed on purpose: a highlighted stop read as "a herb is here" when nothing was.
- **Marker states**, using the game's herb and ore icons:
  - **Confirmed up:** seen on your minimap or in the world recently. Full opacity, green edge and soft glow.
  - **Known spot:** a saved location with no recent sighting. Faded (`fadedAlpha`, 35%). Never drawn as available.
  - **Gathered:** a small grey dot until the gathered node cooldown ends. Can be hidden ("Show gathered spots", off in Minimal).
- **Detection radius:** a thin dashed ring showing your minimap's range, the area live nodes can appear in. It is not a gathering range.
- **Player:** the game's arrow at the centre.
- **Zone banner:** shows the route (stops and approximate loop time), or how many spots are known. Why nothing shows (a profession not learned, or your filters) goes on its own line, so the banner never contradicts itself. Gone after about 7 seconds.
- **Session panel:** only what you've actually gathered: duration, nodes, loops, and value at Auctionator prices, all marked ~. Never the route's theoretical rate.
- **Presets:**

| | Terrain | Ring | Compass | Session | Gathered spots |
|---|---|---|---|---|---|
| Farming | 40% | on | on | on | shown |
| Questing | 20% | off | off | off | shown |
| Minimal | off | off | off | off | hidden |

  Presets only change settings when you click one.
- **Performance:** markers and lines come from pools. A full redraw happens at most every 0.15 s; in between, the map slides by how far you've moved. Terrain tiles are cached per tile.

## Fishing and Cooking

Fishing isn't a craft, so it has its own page in the same space (centre list, right details), drawn by `Professions/Fishing.lua`. Cooking keeps the craft layout.

- **Fishing header:** skill / cap, rank, and effective skill in Fishing blue (`F.BLUE`, #7AA0C1) when gear or a lure adds to it. Next rank on the right: name, skill, level.
- **Three views:** Leveling, Fish Finder, Fishing + Cooking, styled like a craft's views.
- **Leveling:** a folding heading per rank (Apprentice 1-75 ... Artisan 225-300), the training row first, then one row per zone with up to five fish icons. Your faction's cities first, the other faction's last and dimmed. Clicking a zone shows its details on the right; nothing is truncated into a list of names.
- **Location details:** recommended skill, "Zone minimum: not published" (WoW Forever doesn't publish it), lure for the range, fish "Caught here" (named by a source) apart from "Also at this skill" (by skill range only), what they cook, and your skill, gear and lure bonus, effective skill. One action: Show on map (opens the zone; no pin, the data is by zone).
- **Fish Finder:** search and a Filters menu (Catchable now, Used in Cooking, In my plan). Rows: icon, name, bag count, fished-from skill, auction price. Details: where, when (coast, night, day) if a source says, recipes using it.
- **Fishing + Cooking:** both professions on two lines with thin bars (Fishing blue, Cooking gold) and a Target each; a Fish mode (Catch them / Catch or buy) and an Options menu. The plan in folding phases; each step one row with a status mark (tick done, red cross blocked with the reason on the right, gold arrow next). Finished phases fold and dim. The right panel follows the selected step: a fish (have / need / left with a blue bar, where, other fish that work), a cook step (ingredients have/need), training, a recipe (one source per line), fishing to a skill (zones, lure). What you'll pay and what the catch is worth stay at the bottom.
- **Cooking:** the craft layout. An Ingredients dropdown (All ingredients, Fish recipes, No fish) sits where the resale choice is for other crafts. The shopping list adds a Fish group and calls the rest "Meat and other"; clicking a fish away from the auction house opens it in the Fish Finder. A "Fishing + Cooking plan" button under the list opens the same shared plan as Fishing's tab.
- **Numbers:** fish counts are estimates (`~`); catch counts for fishing skill-ups and catch rates are never shown, because nobody publishes them for WoW Forever. A fish's market value is shown as "worth", never as money you pay.
