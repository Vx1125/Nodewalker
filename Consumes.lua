-- Nodewalker: raid consumables by spec, with what you have and what each costs
local ADDON, NW = ...
local UI, S = NW.UI, NW.STYLE

-- { item, effect, tier }: tier "full" or "budget" shows on that list only.
-- Lists follow the WoW Forever guides (Method, Wowhead); see README.
local PROT = { "Protection", {
  { 13457, "Absorbs 1950-3250 fire", "full" },
  { 13456, "Absorbs 1950-3250 frost", "full" },
  { 13458, "Absorbs 1950-3250 nature", "full" },
  { 13459, "Absorbs 1950-3250 shadow", "full" },
  { 13461, "Absorbs 1950-3250 arcane", "full" },
} }
local HEALER_PRIEST = {
  { "Flask", {
    { 13511, "+2000 mana", "full" },
  } },
  { "Elixirs", {
    { 250333, "+40 healing", "full" },
    { 250332, "Healing", "budget" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250347, "+18 Spirit" },
    { 9179, "+25 Int", "budget" },
  } },
  { "Food", {
    { 249870, "+44 healing", "full" },
    { 249869, "+33 healing", "budget" },
  } },
  { "Weapon oil", {
    { 20748, "15 mana / 5s, +30 healing", "full" },
    { 20749, "+36 healing, 1% spell crit", "full" },
    { 20747, "10 mana / 5s, +20 healing", "budget" },
  } },
  { "Potions", {
    { 13444, "1350-2250 mana", "full" },
    { 13443, "900-1500 mana", "budget" },
    { 250949, "+88 healing for 30s", "full" },
    { 250948, "Healing for 30s", "budget" },
    { 18253, "1440-1760 health and mana", "full" },
  } },
}
local WARRIOR_STONES = { "Weapon", {
  { 12404, "+8 damage, sharp" },
  { 12643, "+8 damage, blunt" },
  { 18262, "+2% crit", "full" },
} }

NW.CONSUMES = {
  {
    key = "paladin-holy", class = "PALADIN", label = "Holy Paladin",
    groups = {
      { "Flask", {
        { 13511, "+2000 mana", "full" },
      } },
      { "Elixirs", {
        { 250333, "+40 healing", "full" },
        { 250332, "Healing", "budget" },
        { 250341, "20 mana / 5s", "full" },
        { 20007, "12 mana / 5s", "budget" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 9179, "+25 Int", "budget" },
      } },
      { "Food", {
        { 249870, "+44 healing", "full" },
        { 249869, "+33 healing", "budget" },
      } },
      { "Weapon oil", {
        { 20749, "+36 healing, 1% spell crit", "full" },
        { 20748, "15 mana / 5s, +30 healing", "full" },
        { 20747, "10 mana / 5s, +20 healing", "budget" },
      } },
      { "Potions", {
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
        { 250949, "+88 healing for 30s", "full" },
        { 250948, "Healing for 30s", "budget" },
        { 18253, "1440-1760 health and mana", "full" },
      } },
    },
  },
  { key = "priest-holy", class = "PRIEST", label = "Holy Priest", groups = HEALER_PRIEST },
  { key = "priest-disc", class = "PRIEST", label = "Discipline Priest", groups = HEALER_PRIEST },
  {
    key = "priest-shadow", class = "PRIEST", label = "Shadow Priest",
    groups = {
      { "Flask", {
        { 13512, "+150 spell damage", "full" },
      } },
      { "Elixirs", {
        { 9264, "+40 shadow damage" },
        { 13454, "+35 spell damage", "full" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 250341, "20 mana / 5s", "full" },
        { 20007, "12 mana / 5s", "budget" },
        { 250347, "+18 Spirit" },
        { 250335, "+400 health", "full" },
        { 20004, "20 health / 5s", "full" },
        { 13445, "+450 armor", "full" },
      } },
      { "Food", {
        { 13935, "+28 spell damage", "full" },
        { 13931, "+22 spell damage", "budget" },
      } },
      { "Weapon oil", {
        { 20749, "+36 spell damage, 1% spell crit", "full" },
        { 20750, "Spell damage", "budget" },
      } },
      { "Potions", {
        { 250937, "+47 spell damage for 30s", "full" },
        { 250936, "Spell damage for 30s", "budget" },
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
        { 250954, "+105 spell damage vs elementals", "full" },
        { 250953, "For mass AoE", "full" },
        { 3387, "Immune to physical for 6s", "full" },
        { 5634, "Immune to stuns, roots for 30s", "full" },
      } },
      PROT,
    },
  },
  {
    key = "priest-smite", class = "PRIEST", label = "Smite Priest",
    groups = {
      { "Flask", {
        { 13512, "+150 spell damage", "full" },
      } },
      { "Elixirs", {
        { 13454, "+35 spell damage" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 250341, "20 mana / 5s", "full" },
        { 20007, "12 mana / 5s", "budget" },
        { 250347, "+18 Spirit", "full" },
      } },
      { "Food", {
        { 13935, "+28 spell damage", "full" },
        { 13931, "+22 spell damage", "budget" },
      } },
      { "Weapon oil", {
        { 20749, "+36 spell damage, 1% spell crit", "full" },
        { 20750, "Spell damage", "budget" },
      } },
      { "Potions", {
        { 250937, "+47 spell damage for 30s", "full" },
        { 250936, "Spell damage for 30s", "budget" },
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
      } },
    },
  },
  {
    key = "warrior-prot", class = "WARRIOR", label = "Protection Warrior",
    groups = {
      { "Flask", {
        { 274275, "+60 Sta, harder to dodge or parry", "full" },
        { 13510, "+1200 health", "full" },
        { 13513, "+25 all resistances", "full" },
      } },
      { "Elixirs", {
        { 250329, "+400 health, +500 armor" },
        { 13445, "+450 armor" },
        { 20004, "20 health / 5s", "full" },
        { 13453, "+18 Str, +18 Sta", "full" },
        { 13452, "+25 Agi, 2% crit", "full" },
        { 250351, "+25 Str, 2% crit", "full" },
        { 246948, "+35 attack power", "full" },
        { 12820, "+35 attack power" },
        { 9088, "Enemies take more damage", "full" },
        { 250335, "+400 health", "budget" },
      } },
      { "Food", {
        { 250068, "+20 Sta" },
        { 12217, "Chance to breathe fire" },
      } },
      WARRIOR_STONES,
      { "Potions", {
        { 13455, "+2000 armor for 2 min" },
        { 13446, "1050-1750 health", "full" },
        { 3928, "700-900 health", "budget" },
        { 13442, "45-75 rage, +60 Str for 20s", "full" },
        { 3387, "Immune to physical for 6s", "full" },
        { 5634, "Immune to stuns, roots for 30s", "full" },
        { 9036, "+50 all resistances for 3 min", "full" },
      } },
      PROT,
    },
  },
  {
    key = "warrior-dps", class = "WARRIOR", label = "Arms / Fury Warrior",
    groups = {
      { "Flask", {
        { 274275, "+60 Sta, harder to dodge or parry", "full" },
        { 274274, "+60 Sta, 4% crit", "full" },
      } },
      { "Elixirs", {
        { 250351, "+25 Str, 2% crit", "full" },
        { 13452, "+25 Agi, 2% crit", "full" },
        { 246948, "+35 attack power" },
        { 12820, "+35 attack power" },
        { 9206, "+25 Str", "budget" },
        { 9187, "+25 Agi", "budget" },
      } },
      { "Food", {
        { 13934, "+40 attack power", "full" },
        { 13932, "+40 attack power", "full" },
        { 250071, "+20 Str", "budget" },
      } },
      WARRIOR_STONES,
      { "Potions", {
        { 13442, "45-75 rage, +60 Str for 20s" },
        { 250943, "+80 attack power for 30s", "full" },
        { 13446, "1050-1750 health", "full" },
        { 3928, "700-900 health", "budget" },
        { 5634, "Immune to stuns, roots for 30s", "full" },
        { 3387, "Immune to physical for 6s", "full" },
      } },
    },
  },
  {
    key = "warlock", class = "WARLOCK", label = "Warlock",
    groups = {
      { "Flask", {
        { 13512, "+150 spell damage", "full" },
        { 274274, "+60 Sta, 4% crit", "full" },
      } },
      { "Elixirs", {
        { 9264, "+40 shadow damage" },
        { 13454, "+35 spell damage", "full" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 9155, "Spell damage", "budget" },
      } },
      { "Food", {
        { 13935, "+28 spell damage", "full" },
        { 13931, "+22 spell damage", "budget" },
      } },
      { "Weapon oil", {
        { 20749, "+36 spell damage, 1% spell crit", "full" },
        { 20750, "Spell damage", "budget" },
      } },
      { "Potions", {
        { 250937, "+47 spell damage for 30s", "full" },
        { 250936, "Spell damage for 30s", "budget" },
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
        { 20008, "Breaks stuns and roots", "full" },
        { 18253, "1440-1760 health and mana", "full" },
      } },
      { "Other", {
        { 12662, "Mana for health" },
      } },
    },
  },
}

-- Shared rows
local CASTER_FOOD = { "Food", { { 13935, "+28 spell damage", "full" }, { 13931, "+22 spell damage", "budget" } } }
local CASTER_OIL = { "Weapon oil", { { 20749, "+36 spell damage, 1% spell crit", "full" }, { 20750, "Spell damage", "budget" } } }
local HEAL_FOOD = { "Food", { { 249870, "+44 healing", "full" }, { 249869, "+33 healing", "budget" } } }
local HEAL_OIL = { "Weapon oil", {
  { 20749, "+36 healing, 1% spell crit", "full" },
  { 20748, "15 mana / 5s, +30 healing", "full" },
  { 20747, "10 mana / 5s, +20 healing", "budget" },
} }
local HEAL_POTS = { "Potions", {
  { 13444, "1350-2250 mana", "full" },
  { 13443, "900-1500 mana", "budget" },
  { 250949, "+88 healing for 30s", "full" },
  { 250948, "Healing for 30s", "budget" },
  { 18253, "1440-1760 health and mana", "full" },
} }
local CASTER_POTS = { "Potions", {
  { 250937, "+47 spell damage for 30s", "full" },
  { 250936, "Spell damage for 30s", "budget" },
  { 13444, "1350-2250 mana", "full" },
  { 13443, "900-1500 mana", "budget" },
  { 250954, "+105 spell damage vs elementals", "full" },
  { 250953, "For mass AoE", "full" },
} }
local MELEE_FOOD = { "Food", { { 13934, "+40 attack power", "full" }, { 13932, "+40 attack power", "full" }, { 250071, "+20 Str", "budget" } } }
local AGI_FOOD = { "Food", { { 13932, "+40 attack power", "full" }, { 13934, "+40 attack power", "full" }, { 250072, "+20 Agi" } } }

local function add(t) NW.CONSUMES[#NW.CONSUMES + 1] = t end

add({ key = "paladin-prot", class = "PALADIN", label = "Protection Paladin", groups = {
  { "Flask", {
    { 274275, "+60 Sta, harder to dodge or parry", "full" },
    { 13510, "+1200 health", "full" },
    { 13512, "+150 spell damage", "full" },
  } },
  { "Elixirs", {
    { 250329, "+400 health, +500 armor" },
    { 13445, "+450 armor" },
    { 13454, "+35 spell damage", "full" },
    { 21546, "Holy damage", "full" },
    { 250351, "+25 Str, 2% crit", "full" },
    { 13452, "+25 Agi, 2% crit", "full" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 12820, "+35 attack power", "full" },
    { 9088, "Enemies take more damage", "full" },
  } },
  { "Food", { { 250068, "+20 Sta" }, { 13935, "+28 spell damage", "full" }, { 12217, "Chance to breathe fire", "full" } } },
  { "Weapon oil", { { 20749, "+36 spell damage, 1% spell crit", "full" }, { 20750, "Spell damage", "budget" } } },
  { "Potions", {
    { 250937, "+47 spell damage for 30s", "full" },
    { 13455, "+2000 armor for 2 min" },
    { 13444, "1350-2250 mana", "full" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
    { 5634, "Immune to stuns, roots for 30s", "full" },
  } },
  { "Other", { { 12662, "Mana for health", "full" }, { 10646, "AoE damage and threat", "full" } } },
  PROT,
} })
add({ key = "paladin-ret", class = "PALADIN", label = "Retribution Paladin", groups = {
  { "Flask", { { 274275, "+60 Sta, harder to dodge or parry", "full" }, { 274274, "+60 Sta, 4% crit", "full" } } },
  { "Elixirs", {
    { 250351, "+25 Str, 2% crit", "full" },
    { 13452, "+25 Agi, 2% crit", "full" },
    { 246948, "+35 attack power" },
    { 12820, "+35 attack power" },
    { 21546, "Holy damage", "full" },
    { 9206, "+25 Str", "budget" },
  } },
  MELEE_FOOD,
  WARRIOR_STONES,
  { "Potions", {
    { 250943, "+80 attack power for 30s", "full" },
    { 13444, "1350-2250 mana", "full" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
    { 5634, "Immune to stuns, roots for 30s", "full" },
  } },
} })
add({ key = "druid-resto", class = "DRUID", label = "Restoration Druid", groups = {
  { "Flask", { { 13511, "+2000 mana", "full" }, { 274276, "+60 Sta, 5% haste", "full" } } },
  { "Elixirs", {
    { 250333, "+40 healing", "full" },
    { 250332, "Healing", "budget" },
    { 13447, "+18 Int, +18 Spirit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
    { 9179, "+25 Int", "budget" },
  } },
  HEAL_FOOD, HEAL_OIL,
  { "Potions", {
    { 13444, "1350-2250 mana", "full" },
    { 13443, "900-1500 mana", "budget" },
    { 250949, "+88 healing for 30s", "full" },
    { 250948, "Healing for 30s", "budget" },
    { 18253, "1440-1760 health and mana", "full" },
    { 20008, "Breaks stuns and roots", "full" },
  } },
} })
add({ key = "druid-balance", class = "DRUID", label = "Balance Druid", groups = {
  { "Flask", { { 13512, "+150 spell damage", "full" } } },
  { "Elixirs", {
    { 13454, "+35 spell damage" },
    { 250343, "Nature damage", "full" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
  } },
  CASTER_FOOD, CASTER_OIL, CASTER_POTS,
} })
add({ key = "druid-cat", class = "DRUID", label = "Feral Druid (Cat)", groups = {
  { "Flask", { { 274274, "+60 Sta, 4% crit", "full" }, { 274273, "+60 Sta, 5% hit", "full" } } },
  { "Elixirs", {
    { 13452, "+25 Agi, 2% crit", "full" },
    { 250351, "+25 Str, 2% crit", "full" },
    { 246948, "+35 attack power" },
    { 12820, "+35 attack power" },
    { 9187, "+25 Agi", "budget" },
    { 9206, "+25 Str", "budget" },
  } },
  AGI_FOOD,
  WARRIOR_STONES,
  { "Potions", { { 250943, "+80 attack power for 30s", "full" }, { 250942, "Attack power for 30s", "budget" }, { 13446, "1050-1750 health" } } },
} })
add({ key = "druid-bear", class = "DRUID", label = "Feral Druid (Bear)", groups = {
  { "Flask", { { 274275, "+60 Sta, harder to dodge or parry", "full" }, { 13510, "+1200 health", "full" } } },
  { "Elixirs", {
    { 250329, "+400 health, +500 armor" },
    { 13445, "+450 armor" },
    { 20004, "20 health / 5s", "full" },
    { 13452, "+25 Agi, 2% crit", "full" },
    { 250351, "+25 Str, 2% crit", "full" },
    { 12820, "+35 attack power" },
    { 9088, "Enemies take more damage", "full" },
    { 9187, "+25 Agi", "budget" },
  } },
  { "Food", { { 250068, "+20 Sta" }, { 250072, "+20 Agi", "full" } } },
  WARRIOR_STONES,
  { "Potions", {
    { 13455, "+2000 armor for 2 min" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
    { 13442, "45-75 rage, +60 Str for 20s", "full" },
    { 5634, "Immune to stuns, roots for 30s", "full" },
  } },
  PROT,
} })
add({ key = "hunter", class = "HUNTER", label = "Hunter", groups = {
  { "Flask", { { 274274, "+60 Sta, 4% crit", "full" }, { 274273, "+60 Sta, 5% hit", "full" } } },
  { "Elixirs", {
    { 250328, "+25 Agi, +25 Int", "full" },
    { 13452, "+25 Agi, 2% crit", "full" },
    { 9187, "+25 Agi", "budget" },
  } },
  AGI_FOOD,
  { "Potions", {
    { 250943, "+80 attack power for 30s", "full" },
    { 250955, "+180 attack power vs beasts", "full" },
    { 250942, "Attack power for 30s", "budget" },
    { 13444, "1350-2250 mana", "full" },
    { 13443, "900-1500 mana", "budget" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
  } },
} })
add({ key = "mage", class = "MAGE", label = "Mage", groups = {
  { "Flask", { { 13512, "+150 spell damage", "full" } } },
  { "Elixirs", {
    { 13454, "+35 spell damage" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 17708, "+15 frost damage", "full" },
    { 6373, "Fire damage", "full" },
    { 9179, "+25 Int", "budget" },
  } },
  CASTER_FOOD, CASTER_OIL, CASTER_POTS,
} })
add({ key = "rogue", class = "ROGUE", label = "Rogue", groups = {
  { "Flask", { { 274273, "+60 Sta, 5% hit", "full" }, { 274274, "+60 Sta, 4% crit", "full" } } },
  { "Elixirs", {
    { 13452, "+25 Agi, 2% crit", "full" },
    { 246948, "+35 attack power" },
    { 12820, "+35 attack power" },
    { 9187, "+25 Agi", "budget" },
  } },
  { "Food", { { 13928, "+1% crit" }, { 250072, "+20 Agi", "full" } } },
  WARRIOR_STONES,
  { "Potions", {
    { 250943, "+80 attack power for 30s", "full" },
    { 250942, "Attack power for 30s", "budget" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
    { 5634, "Immune to stuns, roots for 30s", "full" },
    { 3387, "Immune to physical for 6s", "full" },
  } },
  { "Other", { { 7676, "Restores energy" }, { 14530, "Bandage" } } },
} })
add({ key = "shaman-resto", class = "SHAMAN", label = "Restoration Shaman", groups = {
  { "Flask", { { 13511, "+2000 mana", "full" } } },
  { "Elixirs", {
    { 250333, "+40 healing", "full" },
    { 250332, "Healing", "budget" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 9179, "+25 Int", "budget" },
  } },
  HEAL_FOOD, HEAL_OIL, HEAL_POTS,
} })
add({ key = "shaman-ele", class = "SHAMAN", label = "Elemental Shaman", groups = {
  { "Flask", { { 13512, "+150 spell damage", "full" } } },
  { "Elixirs", {
    { 13454, "+35 spell damage" },
    { 250343, "Nature damage", "full" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
  } },
  CASTER_FOOD, CASTER_OIL, CASTER_POTS,
} })
add({ key = "shaman-enh", class = "SHAMAN", label = "Enhancement Shaman", groups = {
  { "Flask", { { 274274, "+60 Sta, 4% crit", "full" }, { 274275, "+60 Sta, harder to dodge or parry", "full" } } },
  { "Elixirs", {
    { 250351, "+25 Str, 2% crit", "full" },
    { 13452, "+25 Agi, 2% crit", "full" },
    { 246948, "+35 attack power" },
    { 12820, "+35 attack power" },
    { 9206, "+25 Str", "budget" },
  } },
  MELEE_FOOD,
  { "Potions", {
    { 250943, "+80 attack power for 30s", "full" },
    { 13444, "1350-2250 mana", "full" },
    { 13443, "900-1500 mana", "budget" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
  } },
} })
table.sort(NW.CONSUMES, function(x, y)
  if x.class ~= y.class then return x.class < y.class end
  return x.label < y.label
end)

local function st() return NW.db.settings end
local refresh
local page = UI.AddTab("consumes", "Consumes", function() refresh() end)
NW.On("GET_ITEM_INFO_RECEIVED", function() if page:IsShown() then page.dirty = true end end)
NW.On("BAG_UPDATE_DELAYED", function() if page:IsShown() then page.dirty = true end end)
page:SetScript("OnUpdate", function(self) if self.dirty then self.dirty = false refresh() end end)

local LEFT_W, RIGHT_W, ROW_H, MAX_ROWS = 610, 330, 24, 20
local selectedItem
local offset = 0

local head = UI.Heading(page, "", LEFT_W)
head:SetPoint("TOPLEFT", 24, -8)
local budget = UI.Check(page, "Budget", function() return st().consumeBudget end, function(v)
  st().consumeBudget = v
  offset = 0
  refresh()
end)
local specItems = {}
for _, l in ipairs(NW.CONSUMES) do specItems[#specItems + 1] = { l.key, l.label } end
local currentList
local specDrop = UI.Dropdown(page, 190, "Spec", specItems, function() return currentList().key end, function(v)
  st().consumeSpec = v
  selectedItem = nil
  offset = 0
  refresh()
end, 150)
specDrop:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
budget:SetPoint("LEFT", specDrop, "RIGHT", 18, 0)
local total = UI.Text(page, 12, S.dim, "RIGHT")
total:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -12)

local listBox = UI.Box(page, LEFT_W, MAX_ROWS * ROW_H + 2)
listBox:SetPoint("TOPLEFT", specDrop, "BOTTOMLEFT", 0, -8)

-- Right side: the selected consumable
local right = CreateFrame("Frame", nil, page)
right:SetSize(RIGHT_W, 480)
right:SetPoint("TOPLEFT", head, "TOPRIGHT", 28, 0)
local rHead = UI.Heading(right, "", RIGHT_W)
rHead:SetPoint("TOPLEFT")
local detail = UI.Text(right, 12, S.text)
detail:SetPoint("TOPLEFT", rHead, "BOTTOMLEFT", 0, -8)
detail:SetWidth(RIGHT_W)
detail:SetJustifyV("TOP")
detail:SetSpacing(4)
local searchBtn

local function itemName(id)
  local n = NW.ItemName(id)
  if n then return n, true end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return "item " .. id, false
end

function currentList()
  local _, class = UnitClass("player")
  local pick = st().consumeSpec
  local first, mine
  for _, l in ipairs(NW.CONSUMES) do
    first = first or l
    if l.key == pick then return l end
    if l.class == class then mine = mine or l end
  end
  return mine or first
end

-- What can run together, shown beside each heading
local HINT = {
  Flask = "one at a time",
  Elixirs = "stack together, and with a flask",
  Food = "one at a time",
  ["Weapon oil"] = "one per weapon",
  Weapon = "one per weapon",
  Potions = "share a cooldown",
  Protection = "share the potion cooldown",
}
local rows, shown = {}, {}
listBox:EnableMouseWheel(true)
listBox:SetScript("OnMouseWheel", function(_, delta)
  local max = math.max(0, #shown - MAX_ROWS)
  local o = math.max(0, math.min(max, offset - delta * 3))
  if o ~= offset then offset = o refresh() end
end)
local thumb = listBox:CreateTexture(nil, "OVERLAY")
thumb:SetWidth(3)
thumb:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.6)
for i = 1, MAX_ROWS do
  local row = CreateFrame("Button", nil, listBox)
  row:SetSize(LEFT_W - 2, ROW_H)
  row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
  UI.RowHighlight(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 8, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, 12, S.text)
  row.name:SetPoint("LEFT", 34, 0)
  row.name:SetWidth(195)
  row.name:SetWordWrap(false)
  row.effect = UI.Text(row, 11, S.dim)
  row.effect:SetPoint("LEFT", 236, 0)
  row.effect:SetWidth(215)
  row.effect:SetWordWrap(false)
  row.have = UI.Text(row, 12, S.text, "RIGHT")
  row.have:SetPoint("RIGHT", row, "LEFT", 500, 0)
  row.price = UI.Text(row, 12, S.text, "RIGHT")
  row.price:SetPoint("RIGHT", -10, 0)
  row:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    if not self.item then return end
    if IsShiftKeyDown() then
      -- at the auction house it searches; otherwise it links in chat
      local n, ok = itemName(self.item)
      if NW.AHOpen() then
        if ok then NW.SearchAH({ { n, 1 } }) end
      else
        NW.ChatLink(self.item, nil, true)
      end
      return
    end
    selectedItem = self.item
    refresh()
  end)
  rows[i] = row
end

searchBtn = UI.Button(page, "Search missing in Auctionator", RIGHT_W, function()
  local items = {}
  for _, e in ipairs(shown) do
    if e.id and e.have == 0 then
      local n, ok = itemName(e.id)
      if ok then items[#items + 1] = { n, 1 } end
    end
  end
  NW.SearchAH(items)
end)
searchBtn:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", 28, 0)

-- The selected consumable's materials, for making it yourself
local matsBtn = UI.Button(page, "Search materials in Auctionator", RIGHT_W, function()
  local r = selectedItem and NW.RecipeFor(selectedItem)
  if not r then return end
  local items = {}
  for _, re in ipairs(r.reagents) do
    local _, src = NW.Price(re[1])
    local n, ok = itemName(re[1])
    if ok and src ~= "vendor" then items[#items + 1] = { n, math.max(1, re[2] - (NW.ItemCount(re[1]) or 0)) } end
  end
  NW.SearchAH(items)
end)
matsBtn:SetPoint("BOTTOMLEFT", searchBtn, "TOPLEFT", 0, 6)

local function drawDetail()
  local id = selectedItem
  if not id then
    rHead.text:SetText("Consumable")
    detail:SetText("|cff94949aClick one for its prices and materials.|r")
    return
  end
  rHead.text:SetText((itemName(id)))
  local lines = {}
  local vendor, ah, craft = NW.PriceParts(id)
  if ah then lines[#lines + 1] = ("|cff94949aAuction|r  %s"):format(NW.Money(ah)) end
  if vendor then lines[#lines + 1] = ("|cff94949aVendor|r  %s"):format(NW.Money(vendor)) end
  if craft then lines[#lines + 1] = ("|cff94949aMake it|r  %s"):format(NW.Money(craft)) end
  local r, key = NW.RecipeFor(id)
  if r then
    local prof = NW.PROF_BY_KEY[key]
    local req = r.orange or r.yellow
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("|cffe8c46a%s|r%s"):format(prof and prof.name or "", req and req > 0 and (" " .. req) or "")
    for _, re in ipairs(r.reagents) do
      local p = NW.Price(re[1])
      lines[#lines + 1] = ("%d  %s  |cff94949a%s|r"):format(re[2], (itemName(re[1])), p and NW.Money(p * re[2], true) or "?")
    end
    if (r.yield or 1) > 1 then lines[#lines + 1] = ("|cff94949aMakes %d|r"):format(r.yield) end
  end
  detail:SetText(table.concat(lines, "\n"))
end

refresh = function()
  if not page:IsShown() then return end
  local list = currentList()
  head.text:SetText(list.label)
  budget:Refresh()
  specDrop:Refresh()
  local wantBudget = st().consumeBudget
  wipe(shown)
  local sum, missing = 0, 0
  for _, g in ipairs(list.groups) do
    local at = #shown + 1
    shown[at] = { header = g[1] }
    for _, c in ipairs(g[2]) do
      local tier = c[3]
      if not tier or (tier == "budget") == (wantBudget and true or false) then
        local price, src = NW.Price(c[1])
        if src == "est" then price = nil end
        local have = NW.ItemCount(c[1]) or 0
        shown[#shown + 1] = { id = c[1], effect = c[2], price = price, have = have }
        if price then sum = sum + price end
        if have == 0 then missing = missing + 1 end
      end
    end
    if #shown == at then shown[at] = nil end -- nothing on this list for the slot
  end
  offset = math.max(0, math.min(offset, #shown - MAX_ROWS))
  thumb:SetShown(#shown > MAX_ROWS)
  if #shown > MAX_ROWS then
    local h = MAX_ROWS * ROW_H
    thumb:SetHeight(h * MAX_ROWS / #shown)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", -1, -1 - h * offset / #shown)
  end
  for i, row in ipairs(rows) do
    local e = shown[i + offset]
    if not e then
      row:Hide()
    elseif e.header then
      row:Show()
      row.item = nil
      row:SetSelected(false)
      row.icon:Hide()
      row.name:SetText("|cffe8c46a" .. e.header .. "|r")
      row.effect:SetText(HINT[e.header] or "")
      row.have:SetText("")
      row.price:SetText("")
    else
      row:Show()
      row.item = e.id
      row:SetSelected(e.id == selectedItem)
      row.icon:Show()
      row.icon:SetTexture(NW.ItemIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetText((itemName(e.id)))
      row.effect:SetText(e.effect)
      row.have:SetText(e.have > 0 and ("|cff8cdb7a%d|r"):format(e.have) or "|cffeb5c4d0|r")
      row.price:SetText(e.price and NW.Money(e.price, true) or "|cff94949a?|r")
    end
  end
  total:SetText(("One of each %s  ·  Missing %d"):format(NW.Money(sum, true), missing))
  searchBtn:SetEnabled(missing > 0)
  matsBtn:SetShown(selectedItem ~= nil and NW.RecipeFor(selectedItem) ~= nil)
  drawDetail()
end
