local ADDON, NW = ...

-- OpenMap's data tables (OpenMapData\) build a few entries from OpenMap's own
-- texture folder; give them a harmless prefix. Those entries become strings,
-- and the overlay skips anything that isn't a game file ID.
NW.Media = NW.Media or { tex = "Interface\\AddOns\\Nodewalker\\" }

-- Known gathering nodes: English name -> { kind, required skill }.
-- WoW Forever may change some requirements; a skill learned in game
-- (NodewalkerDB.learnedSkill) overrides these. Nodes not listed here are
-- learned the first time you gather them, with an unknown skill.
NW.NODES = {
  -- Herbs
  ["Peacebloom"] = { "herb", 1 },
  ["Silverleaf"] = { "herb", 1 },
  ["Earthroot"] = { "herb", 15 },
  ["Mageroyal"] = { "herb", 50 },
  ["Briarthorn"] = { "herb", 70 },
  ["Stranglekelp"] = { "herb", 85 },
  ["Bruiseweed"] = { "herb", 100 },
  ["Wild Steelbloom"] = { "herb", 115 },
  ["Grave Moss"] = { "herb", 120 },
  ["Kingsblood"] = { "herb", 125 },
  ["Liferoot"] = { "herb", 150 },
  ["Fadeleaf"] = { "herb", 160 },
  ["Goldthorn"] = { "herb", 170 },
  ["Khadgar's Whisker"] = { "herb", 185 },
  ["Wintersbite"] = { "herb", 195 },
  ["Firebloom"] = { "herb", 205 },
  ["Purple Lotus"] = { "herb", 210 },
  ["Arthas' Tears"] = { "herb", 220 },
  ["Sungrass"] = { "herb", 230 },
  ["Blindweed"] = { "herb", 235 },
  ["Ghost Mushroom"] = { "herb", 245 },
  ["Gromsblood"] = { "herb", 250 },
  ["Golden Sansam"] = { "herb", 260 },
  ["Dreamfoil"] = { "herb", 270 },
  ["Mountain Silversage"] = { "herb", 280 },
  ["Plaguebloom"] = { "herb", 285 },
  ["Icecap"] = { "herb", 290 },
  ["Black Lotus"] = { "herb", 300 },
  ["Dreamroot"] = { "herb", nil },

  -- Ore
  ["Copper Vein"] = { "ore", 1 },
  ["Tin Vein"] = { "ore", 65 },
  ["Incendicite Mineral Vein"] = { "ore", 65 },
  ["Silver Vein"] = { "ore", 75 },
  ["Ooze Covered Silver Vein"] = { "ore", 75 },
  ["Lesser Bloodstone Deposit"] = { "ore", 75 },
  ["Iron Deposit"] = { "ore", 125 },
  ["Indurium Mineral Vein"] = { "ore", 150 },
  ["Gold Vein"] = { "ore", 155 },
  ["Ooze Covered Gold Vein"] = { "ore", 155 },
  ["Mithril Deposit"] = { "ore", 175 },
  ["Ooze Covered Mithril Deposit"] = { "ore", 175 },
  ["Truesilver Deposit"] = { "ore", 230 },
  ["Ooze Covered Truesilver Deposit"] = { "ore", 230 },
  ["Dark Iron Deposit"] = { "ore", 230 },
  ["Small Thorium Vein"] = { "ore", 245 },
  ["Ooze Covered Thorium Vein"] = { "ore", 245 },
  ["Rich Thorium Vein"] = { "ore", 275 },
  ["Ooze Covered Rich Thorium Vein"] = { "ore", 275 },
  ["Hakkari Thorium Vein"] = { "ore", 275 },
  ["Cold Iron Deposit"] = { "ore", nil },
}

-- The item each node gives, for its icon on the map
NW.NODE_ITEMS = {
  ["Peacebloom"] = 2447, ["Silverleaf"] = 765, ["Earthroot"] = 2449, ["Mageroyal"] = 785,
  ["Briarthorn"] = 2450, ["Stranglekelp"] = 3820, ["Bruiseweed"] = 2453, ["Wild Steelbloom"] = 3355,
  ["Grave Moss"] = 3369, ["Kingsblood"] = 3356, ["Liferoot"] = 3357, ["Fadeleaf"] = 3818,
  ["Goldthorn"] = 3821, ["Khadgar's Whisker"] = 3358, ["Wintersbite"] = 3819, ["Firebloom"] = 4625,
  ["Purple Lotus"] = 8831, ["Arthas' Tears"] = 8836, ["Sungrass"] = 8838, ["Blindweed"] = 8839,
  ["Ghost Mushroom"] = 8845, ["Gromsblood"] = 8846, ["Golden Sansam"] = 13464, ["Dreamfoil"] = 13463,
  ["Mountain Silversage"] = 13465, ["Plaguebloom"] = 13466, ["Icecap"] = 13467, ["Black Lotus"] = 13468,

  ["Copper Vein"] = 2770, ["Tin Vein"] = 2771, ["Silver Vein"] = 2775, ["Ooze Covered Silver Vein"] = 2775,
  ["Iron Deposit"] = 2772, ["Gold Vein"] = 2776, ["Ooze Covered Gold Vein"] = 2776,
  ["Mithril Deposit"] = 3858, ["Ooze Covered Mithril Deposit"] = 3858,
  ["Truesilver Deposit"] = 7911, ["Ooze Covered Truesilver Deposit"] = 7911,
  ["Small Thorium Vein"] = 10620, ["Ooze Covered Thorium Vein"] = 10620,
  ["Rich Thorium Vein"] = 10620, ["Ooze Covered Rich Thorium Vein"] = 10620, ["Hakkari Thorium Vein"] = 10620,
  ["Dark Iron Deposit"] = 11370, ["Incendicite Mineral Vein"] = 3340,
  ["Lesser Bloodstone Deposit"] = 4278, ["Indurium Mineral Vein"] = 5833,
}

-- Icon for a node: its item's icon, else the Find Herbs / Find Minerals icon.
local iconCache = {}
local KIND_SPELL = { herb = 2383, ore = 2580 } -- Find Herbs, Find Minerals
local KIND_FALLBACK = { herb = "Interface\\Icons\\INV_Misc_Flower_02", ore = "Interface\\Icons\\Spell_Nature_Earthquake" }

local function itemIcon(itemID)
  if C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
    if ok and icon then return icon end
  end
  if GetItemIcon then
    local ok, icon = pcall(GetItemIcon, itemID)
    if ok and icon then return icon end
  end
end

local function spellIcon(spellID)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
    if ok and icon then return icon end
  end
  if GetSpellTexture then
    local ok, icon = pcall(GetSpellTexture, spellID)
    if ok and icon then return icon end
  end
end

function NW.NodeIcon(name, kind)
  local key = (name or "?") .. "|" .. (kind or "?")
  local icon = iconCache[key]
  if icon ~= nil then return icon or nil end
  local itemID = name and NW.NODE_ITEMS[name]
  icon = itemID and itemIcon(itemID)
  if not icon and kind and KIND_SPELL[kind] then icon = spellIcon(KIND_SPELL[kind]) or KIND_FALLBACK[kind] end
  iconCache[key] = icon or false
  return icon
end

-- Colours, as r, g, b
NW.COLORS = {
  herbFill = { 0.18, 0.48, 0.23 }, herbEdge = { 0.61, 0.88, 0.54 },
  oreFill  = { 0.54, 0.35, 0.13 }, oreEdge  = { 0.94, 0.72, 0.41 },
  route    = { 0.37, 0.83, 0.88 },
  gold     = { 0.91, 0.77, 0.42 },
  next     = { 1.00, 0.90, 0.66 },
  picked   = { 0.45, 0.45, 0.45 },
}

-- Skill-up colour of a gathering node at the player's skill, in Classic's
-- steps: orange to required+25, yellow to +50, green to +100, then grey.
function NW.SkillColor(req, skill)
  if not req or not skill then return "unknown" end
  if skill < req then return "red" end
  if skill < req + 25 then return "orange" end
  if skill < req + 50 then return "yellow" end
  if skill < req + 100 then return "green" end
  return "grey"
end

------------------------------------------------------------------------
-- Herb Guide: where each herb is worth farming. Compiled from Wowhead's
-- Classic herb farming guides and WoW Forever herbalism guides (Gfinity,
-- Warcraft Tavern, wow-professions). Zone names are matched to the game's
-- maps at run time; the guide tab ranks them with your own node data.
------------------------------------------------------------------------
NW.HERB_GUIDE = {
  { "Peacebloom", "Open fields away from trees and rocks.", {
    { "The Barrens", "North of the Crossroads" }, { "Durotar" }, { "Mulgore" },
    { "Tirisfal Glades" }, { "Elwynn Forest" }, { "Dun Morogh" }, { "Teldrassil" }, { "Zephras Isle" } } },
  { "Silverleaf", "At the base of trees and shrubs.", {
    { "Durotar", "Along the mountain edges" }, { "The Barrens", "Around the oases" },
    { "Loch Modan", "West side and the two central islands" }, { "Tirisfal Glades" }, { "Elwynn Forest" }, { "Mulgore" } } },
  { "Earthroot", "On rocky walls, ledges and small cliffs.", {
    { "The Barrens", "NE shoreline, western mountains, pirates south of Ratchet" },
    { "Westfall" }, { "Loch Modan" }, { "Silverpine Forest" }, { "Durotar" }, { "Tirisfal Glades" } } },
  { "Mageroyal", "Open ground, often near water. Can drop Swiftthistle.", {
    { "The Barrens", "Best zone; work the oases" }, { "Westfall", "Easy loop" },
    { "Ashenvale", "South half, south and west of the road" }, { "Darkshore" }, { "Silverpine Forest" } } },
  { "Briarthorn", "At the base of trees. Gives Swiftthistle about 40% of the time.", {
    { "Duskwood", "Loop Raven Hill, Vul'Gol Ogre Mound, Yorgen Farmstead; watch for elite Mor'Ladim" },
    { "The Barrens", "Higher-level edges" }, { "Darkshore" }, { "Loch Modan" }, { "Redridge Mountains" },
    { "Ashenvale" }, { "Westfall" } } },
  { "Stranglekelp", "Underwater only; bring water breathing.", {
    { "Darkshore", "Coast south of Auberdine" }, { "Ashenvale", "Bay near Zoram'gar" },
    { "The Barrens", "Bays from Ratchet to Northwatch" }, { "Wetlands", "Coast; murlocs near Menethil" },
    { "Stranglethorn Vale" } } },
  { "Bruiseweed", "Next to fences, barrels, building corners and jagged rocks.", {
    { "Hillsbrad Foothills", "Loop Hillsbrad Fields toward Southshore; SW gnoll ridges" },
    { "Stonetalon Mountains", "Grimtotem camps, Windshear Crag, around Charred Vale" },
    { "Wetlands" }, { "Ashenvale" } } },
  { "Wild Steelbloom", "Only on rocks and high perches; look up.", {
    { "Arathi Highlands", "Run the northern wall back and forth" },
    { "Stonetalon Mountains", "N-S road past the northern Grimtotem camps" }, { "Stranglethorn Vale" } } },
  { "Grave Moss", "Only in graveyards.", {
    { "Duskwood", "Tranquil Gardens and Raven Hill cemeteries" }, { "Desolace", "Kodo Graveyard" },
    { "Wetlands", "Ironbrand's Tomb, south of Dun Modr" } } },
  { "Kingsblood", "Large open fields; easy to spot.", {
    { "Stranglethorn Vale", "Best, but busy" }, { "Hillsbrad Foothills", "Fields about 20 yd off the road" },
    { "Arathi Highlands" }, { "Wetlands" }, { "The Riverglades" } } },
  { "Liferoot", "Grows in strings along rivers and shores.", {
    { "Stranglethorn Vale", "River north and south of Lake Nazferiti, coast to Booty Bay" },
    { "Wetlands", "From the river mouth east of Dun Algaz into the swamp" }, { "The Riverglades" } } },
  { "Fadeleaf", "Hides in shrubs; zoom the minimap in.", {
    { "Arathi Highlands", "Three small loops you can link" },
    { "Swamp of Sorrows", "With Blindweed" }, { "Dustwallow Marsh" }, { "The Hinterlands" } } },
  { "Goldthorn", "On rocks and hillsides.", {
    { "Stranglethorn Vale", "South of Grom'gol and the ogre camps" },
    { "Arathi Highlands", "Northern wall, Thoradin's Wall to east of Hammerfall" },
    { "Swamp of Sorrows", "Walk the walls" }, { "Feralas" }, { "The Hinterlands" } } },
  { "Khadgar's Whisker", "Base of trees, stumps and shrubs, near camps.", {
    { "Stranglethorn Vale", "Lake Nazferiti, troll, Kurzen and ogre camps" },
    { "Arathi Highlands", "Dabyrie Farm and Witherbark Village" }, { "The Hinterlands" }, { "Shen'Dralas" } } },
  { "Wintersbite", "Only on snow.", {
    { "Alterac Mountains", "Snow outside the Ruins of Alterac" } } },
  { "Firebloom", "Dry ground; pairs with Purple Lotus in Tanaris.", {
    { "Tanaris", "Spread out; none in the bug areas" },
    { "Blasted Lands", "Middle band south of Nethergarde; skip the Tainted Scar" },
    { "Searing Gorge" }, { "Burning Steppes", "Compact, fewer nodes" } } },
  { "Purple Lotus", "Ruins and open ground. Can drop Wildvine.", {
    { "Azshara", "Road to and around the Ruins of Eldarath" },
    { "The Hinterlands", "SE ruins past Jintha'Alor" }, { "Tanaris", "Safer; with Firebloom" }, { "Feralas" } } },
  { "Arthas' Tears", "Open fields, best near (not in) farms.", {
    { "Western Plaguelands", "Farms and Sorrow Hill" }, { "Eastern Plaguelands" }, { "Felwood" } } },
  { "Sungrass", "Open ground, yellow-brown grass.", {
    { "Feralas" }, { "Azshara", "South route passes Eldarath for Purple Lotus" },
    { "The Hinterlands", "Side trip to Skulk Rock for Ghost Mushroom" }, { "Blasted Lands" }, { "Un'Goro Crater" } } },
  { "Blindweed", "Shores of hillocks and waterways; island-hop.", {
    { "Swamp of Sorrows", "Best by far" }, { "Un'Goro Crater", "A few in the north" }, { "Feralas" } } },
  { "Ghost Mushroom", "In caves.", {
    { "The Hinterlands", "Skulk Rock caves, about 3x the spawns of Desolace" },
    { "Desolace", "Cave maze leading to Maraudon" } } },
  { "Gromsblood", "Near demon camps.", {
    { "Felwood", "South tip, up the west wall through Jaedenar to Felpaw Village" },
    { "Blasted Lands", "Rim of the Dark Portal" }, { "Desolace", "Mannoroc Coven" }, { "Ashenvale" } } },
  { "Golden Sansam", "Open fields, spread evenly.", {
    { "Un'Goro Crater", "Loop the open ground, skip rocks" }, { "Azshara" }, { "Feralas" },
    { "The Hinterlands" }, { "Burning Steppes" } } },
  { "Dreamfoil", "Open fields, rarely near rocks.", {
    { "Un'Goro Crater", "Same loop as Golden Sansam" }, { "Azshara" }, { "Felwood" }, { "Silithus" } } },
  { "Mountain Silversage", "Mountain edges; expect climbing.", {
    { "Winterspring", "With Icecap" }, { "Un'Goro Crater", "Outer edges or around the volcano" },
    { "Azshara" }, { "Silithus" }, { "Burning Steppes" }, { "Mount Hyjal" } } },
  { "Plaguebloom", "Near, not on, mountains and caverns.", {
    { "Eastern Plaguelands", "Along the mountains" },
    { "Western Plaguelands", "Farms in the middle strip; not Andorhal or the Hearthglen road" }, { "Felwood" } } },
  { "Icecap", "Snow; most abundant south of Everlook.", {
    { "Winterspring", "Central route is safest; south has more spawns and elites" } } },
  { "Black Lotus", "Rare; often near elites. Respawn is slow.", {
    { "Burning Steppes" }, { "Winterspring" }, { "Eastern Plaguelands" }, { "Silithus" }, { "Mount Hyjal" } } },
}

------------------------------------------------------------------------
-- Ore guide: same shape as the herb guide. A fourth field lists the other
-- node names that count as the same ore (ooze-covered veins).
------------------------------------------------------------------------
NW.ORE_GUIDE = {
  { "Copper Vein", "Along hills and cliff faces in every starting zone.", {
    { "Durotar", "Mountain edges all the way round" }, { "Mulgore" }, { "Elwynn Forest" }, { "Dun Morogh" },
    { "Tirisfal Glades" }, { "Darkshore" }, { "The Barrens", "Hills around the Crossroads" } } },
  { "Tin Vein", "Hillsides and caves. Can spawn as Silver instead.", {
    { "The Barrens", "Southern hills and the Stagnant Oasis" }, { "Hillsbrad Foothills", "Mountain rim, both sides" },
    { "Redridge Mountains" }, { "Loch Modan" }, { "Stonetalon Mountains" }, { "Ashenvale" }, { "Wetlands" },
    { "Thousand Needles" } } },
  { "Silver Vein", "Rare; takes the place of a Tin or Iron node.", {
    { "Hillsbrad Foothills" }, { "The Barrens" }, { "Thousand Needles" }, { "Stonetalon Mountains" },
    { "Ashenvale" }, { "Arathi Highlands" } }, { "Ooze Covered Silver Vein" } },
  { "Iron Deposit", "Canyon walls and caves. Can spawn as Gold instead.", {
    { "Arathi Highlands", "Mountain rim and the troll and ogre caves" }, { "Thousand Needles", "Canyon walls" },
    { "Desolace" }, { "Alterac Mountains" }, { "Stranglethorn Vale" }, { "Badlands" }, { "Dustwallow Marsh" } } },
  { "Gold Vein", "Rare; takes the place of an Iron or Mithril node.", {
    { "Arathi Highlands" }, { "Badlands" }, { "Stranglethorn Vale" }, { "Alterac Mountains" }, { "Tanaris" },
    { "The Hinterlands" } }, { "Ooze Covered Gold Vein" } },
  { "Mithril Deposit", "Mountain edges and caves. Can spawn as Truesilver instead.", {
    { "Badlands", "Outer rim; short loop" }, { "Tanaris", "Mountain rim and the insect hives" },
    { "The Hinterlands" }, { "Burning Steppes" }, { "Felwood" }, { "Searing Gorge" }, { "Feralas" },
    { "Azshara" } }, { "Ooze Covered Mithril Deposit" } },
  { "Truesilver Deposit", "Rare; takes the place of a Mithril or Thorium node.", {
    { "Badlands" }, { "Tanaris" }, { "Burning Steppes" }, { "Winterspring" }, { "Felwood" },
    { "Un'Goro Crater" } }, { "Ooze Covered Truesilver Deposit" } },
  { "Dark Iron Deposit", "Few outdoors; most are inside Blackrock Depths and Molten Core.", {
    { "Searing Gorge", "The Cauldron and the slag pit" }, { "Burning Steppes" } } },
  { "Small Thorium Vein", "Everywhere in level 50+ zones.", {
    { "Un'Goro Crater", "Outer wall, all the way round" }, { "Burning Steppes" }, { "Winterspring" },
    { "Eastern Plaguelands" }, { "Western Plaguelands" }, { "Felwood" }, { "Silithus" }, { "Searing Gorge" },
    { "Azshara" } }, { "Ooze Covered Thorium Vein" } },
  { "Rich Thorium Vein", "Caves and high ground. Chance of Arcane Crystal.", {
    { "Winterspring", "Caves and the southern canyon" }, { "Eastern Plaguelands" },
    { "Un'Goro Crater", "Fire Plume Ridge and the outer wall" }, { "Burning Steppes" }, { "Silithus", "The hives" },
    { "Azshara" }, { "Western Plaguelands" } }, { "Ooze Covered Rich Thorium Vein" } },
}
