local _, NW = ...

------------------------------------------------------------------------
-- Gathering guides: where to go at each skill range (Fishing has its own
-- page and data: Professions/Fishing.lua).
-- Zone suggestions follow the usual Classic paths (Wowhead, wow-professions)
-- and the WoW Forever herbalism changes; nodes link to routes.
------------------------------------------------------------------------
NW.GATHER_GUIDE = {
  herbalism = {
    intro = "Pick every herb on the way. The Farm Guide ranks zones from your own nodes.",
    brackets = {
      { 1, 70, { "Peacebloom", "Silverleaf", "Earthroot" }, { "Durotar", "Mulgore", "Tirisfal Glades", "Elwynn Forest", "Dun Morogh", "Teldrassil" } },
      { 70, 115, { "Mageroyal", "Briarthorn", "Silverleaf" }, { "The Barrens", "Silverpine Forest", "Westfall", "Darkshore", "Loch Modan" } },
      { 115, 170, { "Bruiseweed", "Wild Steelbloom", "Kingsblood", "Stranglekelp" }, { "Hillsbrad Foothills", "Stonetalon Mountains", "Ashenvale", "Wetlands" } },
      { 170, 205, { "Liferoot", "Fadeleaf", "Goldthorn", "Kingsblood" }, { "Arathi Highlands", "Stranglethorn Vale", "Swamp of Sorrows" } },
      { 205, 230, { "Khadgar's Whisker", "Goldthorn", "Fadeleaf" }, { "Arathi Highlands", "The Hinterlands", "Stranglethorn Vale" } },
      { 230, 270, { "Firebloom", "Purple Lotus", "Sungrass", "Arthas' Tears" }, { "Tanaris", "Feralas", "The Hinterlands", "Western Plaguelands" } },
      { 270, 300, { "Sungrass", "Gromsblood", "Golden Sansam", "Dreamfoil" }, { "Felwood", "Un'Goro Crater", "Azshara", "Blasted Lands" } },
    },
  },
  mining = {
    intro = "Mine every vein on the route. Smelting gives skill-ups early: Copper to 70, Tin to 75, Bronze to 115.",
    brackets = {
      { 1, 65, { "Copper Vein" }, { "Durotar", "Elwynn Forest", "Dun Morogh", "Mulgore", "Tirisfal Glades", "Darkshore" } },
      { 65, 125, { "Tin Vein", "Silver Vein", "Copper Vein" }, { "The Barrens", "Westfall", "Redridge Mountains", "Loch Modan", "Silverpine Forest", "Hillsbrad Foothills" } },
      { 125, 175, { "Iron Deposit", "Gold Vein", "Tin Vein" }, { "Arathi Highlands", "Desolace", "Thousand Needles", "Badlands", "Stranglethorn Vale" } },
      { 175, 245, { "Mithril Deposit", "Truesilver Deposit", "Iron Deposit" }, { "Badlands", "Searing Gorge", "The Hinterlands", "Tanaris", "Felwood" } },
      { 245, 300, { "Small Thorium Vein", "Rich Thorium Vein", "Mithril Deposit" }, { "Un'Goro Crater", "Burning Steppes", "Winterspring", "Silithus", "Eastern Plaguelands" } },
    },
  },
  skinning = {
    intro = "Skin everything you kill. Journeyman at 75, Expert at 150, Artisan at 225.",
    brackets = {
      { 1, 50, nil, { "Durotar", "Dun Morogh", "Mulgore", "Elwynn Forest", "Teldrassil", "Tirisfal Glades" }, "Boars, scorpids, wolves and cats" },
      { 50, 75, nil, { "The Barrens", "Loch Modan", "Westfall", "Darkshore" }, "Hyenas, plainstriders, bears and boars" },
      { 75, 150, nil, { "The Barrens", "Wetlands", "Ashenvale", "Hillsbrad Foothills" }, "Thunderheads, zhevras, crocolisks and raptors" },
      { 150, 200, nil, { "Thousand Needles", "Arathi Highlands", "Alterac Mountains", "Stranglethorn Vale" }, "Crystalhides, striders, thrashers and tigers" },
      { 200, 225, nil, { "Feralas", "Tanaris", "Badlands" }, "Longtooth runners, Ironfur bears and gorillas" },
      { 225, 300, nil, { "Un'Goro Crater", "Winterspring", "Burning Steppes", "Felwood" }, "Pterrordaxes, diemetradons and devilsaurs" },
    },
  },
}

-- Cooking recipes that use a fish, for the fishing + cooking plan
function NW.CookFish(fishID)
  local out = {}
  for _, r in ipairs(NW.RECIPES.cooking or {}) do
    for _, re in ipairs(r.reagents) do
      if re[1] == fishID then out[#out + 1] = r break end
    end
  end
  table.sort(out, function(a, b) return a.yellow < b.yellow end)
  return out
end

-- Known spots for a set of node names in each zone, best first
function NW.RankZonesForNodes(names, zones)
  local want = {}
  for _, n in ipairs(names) do want[n] = true end
  local rows, seen = {}, {}
  local function count(id)
    local n = 0
    for _, nd in ipairs(NW.db.nodes[id] or {}) do if want[nd.name] then n = n + 1 end end
    return n
  end
  for _, z in ipairs(zones) do
    local id = NW.ZoneID and NW.ZoneID(z)
    if id and not seen[id] then
      seen[id] = true
      rows[#rows + 1] = { name = z, mapID = id, count = count(id) }
    elseif not id then
      rows[#rows + 1] = { name = z, count = 0 }
    end
  end
  table.sort(rows, function(a, b) return a.count > b.count end)
  return rows
end
