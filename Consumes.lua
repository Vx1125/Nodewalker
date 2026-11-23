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
local RUNES = { "Runes", {
  { 12662, "900-1500 mana for health", "full" },
  { 20520, "900-1500 mana for health", "full" },
} }
local HEALER_PRIEST = {
  { "Flask", {
    { 13511, "+2000 mana", "full" },
  } },
  { "Elixirs", {
    { 250333, "+40 healing", "full" },
    { 250332, "+30 healing", "budget" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 13447, "+18 Int, +18 Spirit", "full" },
    { 250347, "+18 Spirit", "budget" },
    { 9179, "+25 Int", "budget" },
  } },
  { "Drink", {
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
  RUNES,
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
        { 250332, "+30 healing", "budget" },
        { 250341, "20 mana / 5s", "full" },
        { 20007, "12 mana / 5s", "budget" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 9179, "+25 Int", "budget" },
      } },
      { "Drink", {
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
      RUNES,
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
        { 250335, "+400 health", "full", "health" },
        { 20004, "20 health / 5s", "full" },
        { 13445, "+450 armor", "full" },
      } },
      { "Food", {
        { 13935, "+28 spell damage", "full" },
        { 13931, "+22 spell damage", "budget" },
      } },
      { "Weapon oil", {
        { 20749, "+36 spell damage, 1% spell crit", "full" },
        { 20750, "+24 spell damage", "budget" },
      } },
      { "Potions", {
        { 250937, "+47 spell damage for 30s", "full" },
        { 250936, "+28 spell damage for 30s", "budget" },
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
        { 250954, "+105 spell damage vs elementals", "full" },
        { 250953, "For mass AoE", "full" },
        { 3387, "Immune to physical for 6s", "full" },
        { 5634, "Immune to stuns, roots for 30s", "full" },
      } },
      PROT,
      RUNES,
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
        { 20750, "+24 spell damage", "budget" },
      } },
      { "Potions", {
        { 250937, "+47 spell damage for 30s", "full" },
        { 250936, "+28 spell damage for 30s", "budget" },
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
      } },
      RUNES,
    },
  },
  {
    key = "warrior-prot", class = "WARRIOR", label = "Protection Warrior",
    groups = {
      { "Flask", {
        { 274275, "Stamina, harder to dodge or parry", "full" },
        { 13510, "+1200 health", "full" },
        { 13513, "+25 all resistances", "full" },
      } },
      { "Elixirs", {
        { 250329, "+400 health, +500 armor", nil, "health" },
        { 13445, "+450 armor" },
        { 20004, "20 health / 5s", "full" },
        { 13453, "+18 Str, +18 Sta", "full" },
        { 13452, "+25 Agi, 2% crit", "full", "crit" },
        { 250351, "+25 Str, 2% crit", "full", "crit" },
        { 246948, "+35 attack power", "full", "ap" },
        { 12820, "+35 attack power", nil, "ap" },
        { 9088, "Enemies take more damage", "full" },
        { 250335, "+400 health", "budget", "health" },
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
        { 274275, "Stamina, harder to dodge or parry", "full" },
        { 274274, "Stamina and crit", "full" },
      } },
      { "Elixirs", {
        { 250351, "+25 Str, 2% crit", "full", "crit" },
        { 13452, "+25 Agi, 2% crit", "full", "crit" },
        { 246948, "+35 attack power", nil, "ap" },
        { 12820, "+35 attack power", nil, "ap" },
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
        { 274274, "Stamina and crit", "full" },
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
        { 20750, "+24 spell damage", "budget" },
      } },
      { "Potions", {
        { 250937, "+47 spell damage for 30s", "full" },
        { 250936, "+28 spell damage for 30s", "budget" },
        { 13444, "1350-2250 mana", "full" },
        { 13443, "900-1500 mana", "budget" },
        { 20008, "Breaks stuns and roots", "full" },
        { 18253, "1440-1760 health and mana", "full" },
      } },
      RUNES,
    },
  },
}

-- Shared rows
local CASTER_FOOD = { "Food", { { 13935, "+28 spell damage", "full" }, { 13933, "+28 spell damage", "full" }, { 13931, "+22 spell damage", "budget" } } }
local CASTER_OIL = { "Weapon oil", { { 20749, "+36 spell damage, 1% spell crit", "full" }, { 20750, "+24 spell damage", "budget" } } }
local HEAL_FOOD = { "Drink", { { 249870, "+44 healing", "full" }, { 249869, "+33 healing", "budget" } } }
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
  { 250936, "+28 spell damage for 30s", "budget" },
  { 13444, "1350-2250 mana", "full" },
  { 13443, "900-1500 mana", "budget" },
  { 250954, "+105 spell damage vs elementals", "full" },
  { 250953, "For mass AoE", "full" },
} }
local MELEE_FOOD = { "Food", { { 20452, "+20 Str", "full" }, { 13934, "+40 attack power", "full" }, { 13932, "+40 attack power", "full" }, { 250071, "+20 Str", "budget" } } }
local AGI_FOOD = { "Food", { { 13932, "+40 attack power", "full" }, { 13934, "+40 attack power", "full" }, { 250072, "+20 Agi" } } }

local function add(t) NW.CONSUMES[#NW.CONSUMES + 1] = t end

add({ key = "paladin-prot", class = "PALADIN", label = "Protection Paladin", groups = {
  { "Flask", {
    { 274275, "Stamina, harder to dodge or parry", "full" },
    { 13510, "+1200 health", "full" },
    { 13512, "+150 spell damage", "full" },
  } },
  { "Elixirs", {
    { 250329, "+400 health, +500 armor", nil, "health" },
    { 13445, "+450 armor" },
    { 13454, "+35 spell damage", "full" },
    { 21546, "+40 holy damage", "full" },
    { 250351, "+25 Str, 2% crit", "full", "crit" },
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 12820, "+35 attack power", "full", "ap" },
    { 9088, "Enemies take more damage", "full" },
  } },
  { "Food", { { 250068, "+20 Sta" }, { 13935, "+28 spell damage", "full" }, { 12217, "Chance to breathe fire", "full" } } },
  { "Weapon oil", { { 20749, "+36 spell damage, 1% spell crit", "full" }, { 20750, "+24 spell damage", "budget" } } },
  { "Potions", {
    { 250937, "+47 spell damage for 30s", "full" },
    { 13455, "+2000 armor for 2 min" },
    { 13444, "1350-2250 mana", "full" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
    { 5634, "Immune to stuns, roots for 30s", "full" },
  } },
  RUNES,
  { "Other", { { 10646, "AoE damage and threat", "full" } } },
  PROT,
} })
add({ key = "paladin-ret", class = "PALADIN", label = "Retribution Paladin", groups = {
  { "Flask", { { 274275, "Stamina, harder to dodge or parry", "full" }, { 274274, "Stamina and crit", "full" } } },
  { "Elixirs", {
    { 250351, "+25 Str, 2% crit", "full", "crit" },
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 246948, "+35 attack power", nil, "ap" },
    { 12820, "+35 attack power", nil, "ap" },
    { 21546, "+40 holy damage", "full" },
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
  { "Flask", { { 13511, "+2000 mana", "full" }, { 274276, "Stamina and haste", "full" } } },
  { "Elixirs", {
    { 250333, "+40 healing", "full" },
    { 250332, "+30 healing", "budget" },
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
  RUNES,
} })
add({ key = "druid-balance", class = "DRUID", label = "Balance Druid", groups = {
  { "Flask", { { 13512, "+150 spell damage", "full" } } },
  { "Elixirs", {
    { 13454, "+35 spell damage" },
    { 250343, "+40 nature damage", "full" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
  } },
  CASTER_FOOD, CASTER_OIL, CASTER_POTS,
  RUNES,
} })
add({ key = "druid-cat", class = "DRUID", label = "Feral Druid (Cat)", groups = {
  { "Flask", { { 274274, "Stamina and crit", "full" }, { 274273, "Stamina and hit", "full" } } },
  { "Elixirs", {
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 250351, "+25 Str, 2% crit", "full", "crit" },
    { 246948, "+35 attack power", nil, "ap" },
    { 12820, "+35 attack power", nil, "ap" },
    { 9187, "+25 Agi", "budget" },
    { 9206, "+25 Str", "budget" },
  } },
  AGI_FOOD,
  WARRIOR_STONES,
  { "Potions", { { 250943, "+80 attack power for 30s", "full" }, { 250942, "Attack power for 30s", "budget" }, { 13446, "1050-1750 health" } } },
} })
add({ key = "druid-bear", class = "DRUID", label = "Feral Druid (Bear)", groups = {
  { "Flask", { { 274275, "Stamina, harder to dodge or parry", "full" }, { 13510, "+1200 health", "full" } } },
  { "Elixirs", {
    { 250329, "+400 health, +500 armor", nil, "health" },
    { 13445, "+450 armor" },
    { 20004, "20 health / 5s", "full" },
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 250351, "+25 Str, 2% crit", "full", "crit" },
    { 12820, "+35 attack power", nil, "ap" },
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
  { "Flask", { { 274274, "Stamina and crit", "full" }, { 274273, "Stamina and hit", "full" } } },
  { "Elixirs", {
    { 250328, "+25 Agi, +25 Int", "full" },
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
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
    { 6373, "+10 fire damage", "full" },
    { 9179, "+25 Int", "budget" },
  } },
  CASTER_FOOD, CASTER_OIL, CASTER_POTS,
  RUNES,
} })
add({ key = "rogue", class = "ROGUE", label = "Rogue", groups = {
  { "Flask", { { 274273, "Stamina and hit", "full" }, { 274274, "Stamina and crit", "full" } } },
  { "Elixirs", {
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 246948, "+35 attack power", nil, "ap" },
    { 12820, "+35 attack power", nil, "ap" },
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
  { "Poisons", { { 8928, "Main hand" }, { 20844, "Off hand" } } },
  { "Other", { { 7676, "100 energy" }, { 14530, "Bandage" } } },
} })
add({ key = "shaman-resto", class = "SHAMAN", label = "Restoration Shaman", groups = {
  { "Flask", { { 13511, "+2000 mana", "full" } } },
  { "Elixirs", {
    { 250333, "+40 healing", "full" },
    { 250332, "+30 healing", "budget" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 9179, "+25 Int", "budget" },
  } },
  HEAL_FOOD, HEAL_OIL, HEAL_POTS,
  RUNES,
} })
add({ key = "shaman-ele", class = "SHAMAN", label = "Elemental Shaman", groups = {
  { "Flask", { { 13512, "+150 spell damage", "full" } } },
  { "Elixirs", {
    { 13454, "+35 spell damage" },
    { 250343, "+40 nature damage", "full" },
    { 250337, "+25 Int, 2% crit", "full" },
    { 250341, "20 mana / 5s", "full" },
    { 20007, "12 mana / 5s", "budget" },
  } },
  CASTER_FOOD, CASTER_OIL, CASTER_POTS,
  RUNES,
} })
add({ key = "shaman-enh", class = "SHAMAN", label = "Enhancement Shaman", groups = {
  { "Flask", { { 13512, "+150 spell damage", "full" }, { 274274, "Stamina and crit", "full" } } },
  { "Elixirs", {
    { 250351, "+25 Str, 2% crit", "full", "crit" },
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 246948, "+35 attack power", nil, "ap" },
    { 12820, "+35 attack power", nil, "ap" },
    { 13454, "+35 spell damage", "full" },
    { 250343, "+40 nature damage", "full" },
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

local LEFT_W, RIGHT_W, ROW_H, MAX_ROWS = 610, 330, 24, 18
local selectedItem
local offset = 0

-- How many of each an hour of raiding uses up, by heading
local PER_HOUR = { Flask = 0.5, Elixirs = 1, Food = 2, Drink = 2, ["Weapon oil"] = 2, Weapon = 2, Poisons = 2, Potions = 5,
  Protection = 1, Runes = 3, Other = 3 }
-- Headings where you only ever use one of the rows
local PICK_ONE = { Flask = true, Food = true, Drink = true, ["Weapon oil"] = true, Weapon = true, Runes = true }
-- What can run together, shown beside each heading
local HINT = {
  Flask = "one at a time",
  Elixirs = "stack together, and with a flask",
  Food = "one at a time",
  Drink = "one at a time",
  Poisons = "one per weapon",
  Runes = "own cooldown, shared with healthstones",
  ["Weapon oil"] = "one per weapon",
  Weapon = "one per weapon",
  Potions = "share a cooldown",
  Protection = "share the potion cooldown",
  Suggested = "best you can use at your level",
  ["Also helpful"] = "for your other buff slots",
}

local function itemName(id)
  local n = NW.ItemName(id)
  if n then return n, true end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return "item " .. id, false
end

local function currentList()
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

-- Rows you've hidden, per spec
local function hiddenOf(key)
  local all = st().consumeHidden
  if not all then all = {} st().consumeHidden = all end
  all[key] = all[key] or {}
  return all[key]
end

-- Making it yourself: the recipe, whether you have the profession, whether
-- you know it, and what one costs to make (nil without full prices)
local function makeInfo(id)
  local r, key = NW.RecipeFor(id)
  if not r then return nil end
  local skill = NW.ProfSkill(key)
  local known = NW.charDB.known[key]
  local scanned = known and next(known) ~= nil
  local _, _, craft = NW.PriceParts(id)
  return { r = r, key = key, skill = skill, scanned = scanned, known = known and known[r.name] or false, cost = craft }
end

-- The game's own words for what an item does
local function useText(id)
  local ok, _, spellID = pcall(function() return (C_Item and C_Item.GetItemSpell or GetItemSpell)(id) end)
  if not (ok and spellID) then return nil end
  local ok2, text = pcall(function()
    return (C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)) or (GetSpellDescription and GetSpellDescription(spellID))
  end)
  if ok2 and type(text) == "string" and text ~= "" then return text end
end

-- How long a buff lasts, read from the game's text ("Lasts 30 min", "for 1
-- hour"). Short effects (a 30 second potion) don't count.
local function minutesOf(id)
  local text = useText(id)
  if not text then return nil end
  text = text:lower()
  local h = text:match("(%d+) ho?u?rs?")
  if h then return tonumber(h) * 60 end
  local m = tonumber(text:match("(%d+) min"))
  if m and m >= 10 then return m end
end

-- Herb or ore an item is gathered from, for the Farm Guide
local nodeOfItem
local function nodeFor(itemID)
  if not nodeOfItem then
    nodeOfItem = {}
    for _, guide in ipairs({ NW.HERB_GUIDE, NW.ORE_GUIDE }) do
      for _, e in ipairs(guide) do
        local item = NW.NODE_ITEMS[e[1]]
        if item and not nodeOfItem[item] then nodeOfItem[item] = e[1] end
      end
    end
  end
  return nodeOfItem[itemID]
end

------------------------------------------------------------------------
-- Leveling: the best of each kind you can use at your level
------------------------------------------------------------------------
-- Ladders run best first. The game says what level each item needs, so an
-- item it doesn't know is never offered.
local LADDER = {
  strength = { 250351, 13453, 9206, 250349, 3391, 2454 },
  agility = { 13452, 250328, 9187, 8949, 3390, 2457 },
  intellect = { 250337, 9179, 250354, 250353, 3383 },
  spirit = { 250347, 250346, 250345, 250344 },
  spell = { 13454, 9155, 250342, 247754 },
  healing = { 250333, 250332, 250331, 250330 },
  regen = { 250341, 20007, 250340, 250339 },
  health = { 250335, 250334, 3825, 2458 },
  armor = { 250329, 13445, 8951, 3389, 5997 },
  troll = { 20004, 3826, 3388, 3382 },
  fire = { 6373 }, frost = { 17708 }, shadow = { 9264 }, holy = { 21546 }, nature = { 250343 },
  healpot = { 13446, 3928, 1710, 929, 858, 118 },
  manapot = { 13444, 13443, 6149, 3827, 3385, 2455 },
  frenzy = { 250943, 250942, 250941, 250940, 250939, 250938 },
  blast = { 250937, 250936, 250935, 250934, 250933, 250932 },
  mender = { 250949, 250948, 250947, 250946, 250945, 250944 },
  rage = { 13442, 5633, 5631 },
  sharp = { 12404, 7964, 2871, 2863, 2862 },
  blunt = { 12643, 7965, 3241, 3240, 3239 },
  wizard = { 20749, 20750, 20746, 20744 },
  manaoil = { 20748, 20747, 20745 },
  sStr = { 10310, 4426, 2289, 954 }, sAgi = { 10309, 4425, 1477, 3012 },
  sInt = { 10308, 4419, 2290, 955 }, sSpi = { 10306, 4424, 1712, 1181 },
  sSta = { 10307, 4422, 1711, 1180 }, sArm = { 10305, 4421, 1478, 3013 },
  -- food: the stat foods first, then plain Well Fed food by tier
  fStr = { 250071, 13932, 250065, 13851, 3726, 1017, 2683, 2680 },
  fAgi = { 250072, 13928, 18045, 13851, 3726, 1017, 2683, 2680 },
  fSpell = { 13931, 250075, 250076, 13851, 3726, 1017, 2683, 2680 },
  fHeal = { 249870, 249869, 250075, 250076, 13851, 3726, 1017, 2683, 2680 },
  fSta = { 250068, 17222, 13851, 3726, 1017, 2683, 2680 },
}
-- { label, ladder, uses per hour, "or" set }
local function slot(label, ladder, perHour, set) return { label, ladder, perHour, set } end
local STONES = { slot("Weapon, sharp", "sharp", 2, "stone"), slot("Weapon, blunt", "blunt", 2, "stone") }
local ROLES = {
  str = {
    { slot("Food", "fStr", 2), slot("Elixir, Strength", "strength"), slot("Elixir, Agility", "agility"), STONES, slot("Potion, health", "healpot", 3) },
    { slot("Elixir, Health", "health"), slot("Elixir, Armor", "armor"), slot("Elixir, Health regen", "troll"),
      slot("Potion, attack power", "frenzy", 3), slot("Scroll, Strength", "sStr", 2), slot("Scroll, Agility", "sAgi", 2) },
  },
  agi = {
    { slot("Food", "fAgi", 2), slot("Elixir, Agility", "agility"), slot("Elixir, Strength", "strength"), STONES, slot("Potion, health", "healpot", 3) },
    { slot("Elixir, Health", "health"), slot("Elixir, Health regen", "troll"),
      slot("Potion, attack power", "frenzy", 3), slot("Scroll, Agility", "sAgi", 2), slot("Scroll, Strength", "sStr", 2) },
  },
  tank = {
    { slot("Food", "fSta", 2), slot("Elixir, Health", "health"), slot("Elixir, Armor", "armor"), STONES, slot("Potion, health", "healpot", 3) },
    { slot("Elixir, Strength", "strength"), slot("Elixir, Agility", "agility"), slot("Elixir, Health regen", "troll"),
      slot("Scroll, Stamina", "sSta", 2), slot("Scroll, Armor", "sArm", 2) },
  },
  caster = {
    { slot("Food", "fSpell", 2), slot("Elixir, Spell damage", "spell"), slot("Elixir, Intellect", "intellect"),
      slot("Weapon oil", "wizard", 2), slot("Potion, mana", "manapot", 3), slot("Potion, health", "healpot", 3) },
    { "school", slot("Elixir, Mana regen", "regen"), slot("Elixir, Spirit", "spirit"), slot("Elixir, Health", "health"),
      slot("Potion, spell damage", "blast", 3), slot("Scroll, Intellect", "sInt", 2), slot("Scroll, Spirit", "sSpi", 2) },
  },
  heal = {
    { slot("Food", "fHeal", 2), slot("Elixir, Healing", "healing"), slot("Elixir, Mana regen", "regen"), slot("Elixir, Intellect", "intellect"),
      slot("Weapon oil", "manaoil", 2), slot("Potion, mana", "manapot", 3) },
    { slot("Elixir, Spirit", "spirit"), slot("Elixir, Health", "health"), slot("Potion, healing", "mender", 3),
      slot("Potion, health", "healpot", 3), slot("Scroll, Intellect", "sInt", 2), slot("Scroll, Spirit", "sSpi", 2) },
  },
}
local ROLE_OF = {
  ["paladin-holy"] = "heal", ["priest-holy"] = "heal", ["priest-disc"] = "heal", ["druid-resto"] = "heal", ["shaman-resto"] = "heal",
  ["priest-shadow"] = "caster", ["priest-smite"] = "caster", warlock = "caster", mage = "caster", ["druid-balance"] = "caster", ["shaman-ele"] = "caster",
  ["warrior-dps"] = "str", ["paladin-ret"] = "str", ["shaman-enh"] = "str",
  rogue = "agi", hunter = "agi", ["druid-cat"] = "agi",
  ["warrior-prot"] = "tank", ["paladin-prot"] = "tank", ["druid-bear"] = "tank",
}
-- A caster's own school
local SCHOOL = {
  mage = { slot("Elixir, Fire", "fire"), slot("Elixir, Frost", "frost") }, warlock = { slot("Elixir, Shadow", "shadow"), slot("Elixir, Fire", "fire") },
  ["priest-shadow"] = { slot("Elixir, Shadow", "shadow") }, ["priest-smite"] = { slot("Elixir, Holy", "holy") },
  ["druid-balance"] = { slot("Elixir, Nature", "nature") }, ["shaman-ele"] = { slot("Elixir, Nature", "nature") },
}
-- no weapon stones, or no mana, for these
local NO_STONE = { hunter = true, ["druid-cat"] = true, ["druid-bear"] = true }
local MANA_TOO = { ["paladin-ret"] = true, ["shaman-enh"] = true, hunter = true, ["paladin-prot"] = true }

-- Best item on a ladder you're high enough for; nil until the game has told us
local function bestFor(ladder, level)
  for _, id in ipairs(LADDER[ladder]) do
    local name, _, _, _, minLevel = NW.ItemInfo(id)
    if name and (minLevel or 0) <= level then return id end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
end

local function playerLevel() return UnitLevel and UnitLevel("player") or 60 end

-- The same shape as a raid list, built for your level
local function levelList(spec)
  local level = playerLevel()
  local role = ROLES[ROLE_OF[spec.key] or "str"]
  local out = { key = spec.key .. ":level", label = ("%s  ·  level %d"):format(spec.label, level), groups = {} }
  for gi, heading in ipairs({ "Suggested", "Also helpful" }) do
    local rows = {}
    local function put(sl)
      if sl == "school" then
        for _, x in ipairs(SCHOOL[spec.key] or {}) do put(x) end
      elseif type(sl[1]) == "table" then
        if not NO_STONE[spec.key] then for _, x in ipairs(sl) do put(x) end end
      else
        local id = bestFor(sl[2], level)
        if id then rows[#rows + 1] = { id, sl[1], nil, sl[4], sl[3] } end
      end
    end
    for _, sl in ipairs(role[gi]) do put(sl) end
    if gi == 1 and MANA_TOO[spec.key] then put(slot("Potion, mana", "manapot", 3)) end
    if gi == 2 and spec.class == "WARRIOR" then put(slot("Potion, rage", "rage", 3)) end
    out.groups[gi] = { heading, rows }
  end
  return out
end

-- Which list: "level", "raid" or "budget". Below 60 it starts on your level.
local function listMode()
  local m = st().consumeList
  if m then return m end
  if playerLevel() < 60 then return "level" end
  return st().consumeBudget and "budget" or "raid"
end

------------------------------------------------------------------------
-- Top row
------------------------------------------------------------------------
local head = UI.Heading(page, "", LEFT_W)
head:SetPoint("TOPLEFT", 24, -8)
local specItems = {}
for _, l in ipairs(NW.CONSUMES) do specItems[#specItems + 1] = { l.key, l.label } end
local specDrop = UI.Dropdown(page, 190, "Spec", specItems, function() return currentList().key end, function(v)
  st().consumeSpec = v
  selectedItem = nil
  offset = 0
  refresh()
end, 150)
specDrop:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
local stockDrop = UI.Dropdown(page, 170, "Stock", { { 0, "One of each" }, { 2, "2 hours" }, { 3, "3 hours" }, { 4, "4 hours" } },
  function() return st().consumeHours or 0 end, function(v)
    st().consumeHours = v
    refresh()
  end, 120, "How much to carry: buffs by their duration, potions at 5 an hour.")
stockDrop:SetPoint("LEFT", specDrop, "RIGHT", 18, 0)
local budget = UI.Dropdown(page, 140, "List", { { "level", "My level" }, { "raid", "Raid best" }, { "budget", "Raid budget" } },
  listMode, function(v)
    st().consumeList = v
    st().consumeBudget = v == "budget"
    selectedItem = nil
    offset = 0
    refresh()
  end, 108)
budget:SetPoint("LEFT", stockDrop, "RIGHT", 18, 0)

local listBox = UI.Box(page, LEFT_W, MAX_ROWS * ROW_H + 2)
listBox:SetPoint("TOPLEFT", specDrop, "BOTTOMLEFT", 0, -22)
for _, c in ipairs({ { "Have", 462 }, { "Make", 530 }, { "Buy", LEFT_W - 10 } }) do
  local t = UI.Text(page, 10, S.dim, "RIGHT")
  t:SetPoint("BOTTOMRIGHT", listBox, "TOPLEFT", c[2], 3)
  t:SetText(c[1])
end

-- Under the list: hidden rows on the left, the bill on the right
local showHidden = false
local hiddenCheck = UI.Check(page, "Show hidden", function() return showHidden end, function(v)
  showHidden = v
  refresh()
end, "Right-click a row to hide it, or to bring it back.")
hiddenCheck:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 2, -6)
local hint = UI.Text(page, 11, S.dim)
hint:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 2, -9)
hint:SetText("Right-click: hide a row. \"or\" rows are alternatives: hide the one you don't use.")
local total = UI.Text(page, 12, S.dim, "RIGHT")
total:SetPoint("TOPRIGHT", listBox, "BOTTOMRIGHT", 0, -9)

------------------------------------------------------------------------
-- Right side: the selected consumable
------------------------------------------------------------------------
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
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
  row.effect:SetWidth(180)
  row.effect:SetWordWrap(false)
  row.have = UI.Text(row, 12, S.text, "RIGHT")
  row.have:SetPoint("RIGHT", row, "LEFT", 462, 0)
  row.make = UI.Text(row, 12, S.text, "RIGHT")
  row.make:SetPoint("RIGHT", row, "LEFT", 530, 0)
  row.price = UI.Text(row, 12, S.text, "RIGHT")
  row.price:SetPoint("RIGHT", -10, 0)
  row:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self, button)
    if not self.item then return end
    if button == "RightButton" then
      local h = hiddenOf(currentList().key .. (listMode() == "level" and ":level" or ""))
      h[self.item] = (not h[self.item]) or nil
      refresh()
      return
    end
    if IsShiftKeyDown() then
      -- at the auction house it searches; otherwise it links in chat
      local n, ok = itemName(self.item)
      if NW.AHOpen() then
        if ok then NW.SearchAH({ { n, self.short and self.short > 0 and self.short or 1 } }) end
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

-- Would you make this one rather than buy it?
local function makes(e)
  return e.make and e.m.known and (not e.price or e.make < e.price)
end

-- Everything you're short of, the cheap way: materials for what you'd make,
-- the item itself for the rest
local searchBtn = UI.Button(page, "Search what's short in Auctionator", RIGHT_W, function()
  local want, order = {}, {}
  local function add(id, n)
    if n <= 0 then return end
    if not want[id] then want[id] = 0 order[#order + 1] = id end
    want[id] = want[id] + n
  end
  for _, e in ipairs(shown) do
    if e.id and not e.hidden and e.short > 0 then
      if makes(e) then
        local crafts = math.ceil(e.short / (e.m.r.yield or 1))
        for _, re in ipairs(e.m.r.reagents) do
          local _, src = NW.Price(re[1])
          if src ~= "vendor" then add(re[1], re[2] * crafts) end
        end
      else
        add(e.id, e.short)
      end
    end
  end
  local items = {}
  for _, id in ipairs(order) do
    local n, ok = itemName(id)
    local buy = want[id] - (shown.byId[id] and 0 or (NW.ItemCount(id) or 0)) -- bags already count for the consumables themselves
    if ok and buy > 0 then items[#items + 1] = { n, buy } end
  end
  NW.SearchAH(items)
end, nil, "primary")
searchBtn:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", 28, 0)

-- The selected consumable's materials, for making it yourself
local matsBtn = UI.Button(page, "Search its materials", RIGHT_W, function()
  local r = selectedItem and NW.RecipeFor(selectedItem)
  if not r then return end
  local e = shown.byId[selectedItem]
  local crafts = math.max(1, math.ceil(((e and e.short) or 1) / (r.yield or 1)))
  local items = {}
  for _, re in ipairs(r.reagents) do
    local _, src = NW.Price(re[1])
    local n, ok = itemName(re[1])
    if ok and src ~= "vendor" then items[#items + 1] = { n, math.max(1, re[2] * crafts - (NW.ItemCount(re[1]) or 0)) } end
  end
  NW.SearchAH(items)
end)
matsBtn:SetPoint("BOTTOMLEFT", searchBtn, "TOPLEFT", 0, 6)

-- Gather it instead: opens the Farm Guide on its priciest herb or ore
local farmNode
local farmBtn = UI.Button(page, "", RIGHT_W, function()
  if farmNode then NW.GuideSelectHerb(farmNode) end
end)
farmBtn:SetPoint("BOTTOMLEFT", matsBtn, "TOPLEFT", 0, 6)

local function drawDetail()
  local id = selectedItem
  farmNode = nil
  if not id then
    rHead.text:SetText("Consumable")
    detail:SetText("|cff94949aClick one for its prices and materials.|r")
    return
  end
  rHead.text:SetText((itemName(id)))
  local lines = {}
  local use = useText(id)
  if use then lines[#lines + 1] = "|cff94949a" .. use .. "|r" lines[#lines + 1] = "" end
  local vendor, ah, craft = NW.PriceParts(id)
  if ah then lines[#lines + 1] = ("|cff94949aAuction|r  %s"):format(NW.Money(ah)) end
  if vendor then lines[#lines + 1] = ("|cff94949aVendor|r  %s"):format(NW.Money(vendor)) end
  if craft then lines[#lines + 1] = ("|cff94949aMake it|r  %s"):format(NW.Money(craft)) end
  local r, key = NW.RecipeFor(id)
  if r then
    local prof = NW.PROF_BY_KEY[key]
    local req = r.orange or r.yellow
    local m = makeInfo(id)
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("|cffe8c46a%s|r%s"):format(prof and prof.name or "", req and req > 0 and (" " .. req) or "")
    if m.skill then
      if m.known then
        lines[#lines + 1] = "|cff8cdb7aRecipe known|r"
      elseif not m.scanned then
        lines[#lines + 1] = ("|cff94949aOpen %s once to see which recipes you know|r"):format(prof and prof.name or "it")
      else
        lines[#lines + 1] = "|cffeb5c4dRecipe not known|r"
        lines[#lines + 1] = NW.RecipeSourceText(key, r)
      end
    end
    local best = 0
    for _, re in ipairs(r.reagents) do
      local p = NW.Price(re[1])
      lines[#lines + 1] = ("%d  %s  |cff94949a%s|r"):format(re[2], (itemName(re[1])), p and NW.Money(p * re[2], true) or "?")
      local node = nodeFor(re[1])
      local worth = (p or 1) * re[2]
      if node and worth > best then farmNode, best = node, worth end
    end
    if (r.yield or 1) > 1 then lines[#lines + 1] = ("|cff94949aMakes %d|r"):format(r.yield) end
  end
  detail:SetText(table.concat(lines, "\n"))
end

refresh = function()
  if not page:IsShown() then return end
  local list = currentList()
  local mode = listMode()
  if mode == "level" then list = levelList(list) end
  head.text:SetText(list.label)
  budget:Refresh()
  specDrop:Refresh()
  stockDrop:Refresh()
  local wantBudget = mode == "budget"
  local hours = st().consumeHours or 0
  local hidden = hiddenOf(list.key)
  local nHidden = 0
  for _ in pairs(hidden) do nHidden = nHidden + 1 end
  if nHidden == 0 then showHidden = false end
  wipe(shown)
  shown.byId = {}
  local sum, shortCount = 0, 0
  for _, g in ipairs(list.groups) do
    local at = #shown + 1
    shown[at] = { header = g[1] }
    local perHour = PER_HOUR[g[1]] or 1
    local sets = {}
    for _, c in ipairs(g[2]) do
      local tier = c[3]
      local isHidden = hidden[c[1]] and true or false
      if (not tier or (tier == "budget") == (wantBudget and true or false)) and (showHidden or not isHidden) then
        local price, src = NW.Price(c[1])
        if src == "est" then price = nil end
        local have = NW.ItemCount(c[1]) or 0
        local m = makeInfo(c[1])
        -- only what you could make yourself counts as a way to get it
        local make = m and m.skill and m.cost or nil
        -- a buff with a stated duration is counted exactly
        local mine = hours > 0 and math.max(1, math.ceil((c[5] or perHour) * hours)) or 1
        local lasts = hours > 0 and minutesOf(c[1])
        if lasts then mine = math.max(1, math.ceil(hours * 60 / lasts)) end
        local e = { id = c[1], effect = c[2], price = price, have = have, make = make, m = m,
          need = mine, short = math.max(0, mine - have), hidden = isHidden }
        shown[#shown + 1] = e
        shown.byId[e.id] = e
        -- one or the other: the first row you haven't hidden is the one to
        -- stock, and the rest only show what you already carry
        local set = (PICK_ONE[g[1]] and g[1]) or c[4]
        if set and not isHidden then
          local lead = sets[set]
          if not lead then
            sets[set] = e
            e.setHave = have
          else
            e.alt, e.need, e.short = true, 0, 0
            lead.setHave = lead.setHave + have
            lead.short = math.max(0, lead.need - lead.setHave)
          end
        end
      end
    end
    for k = at + 1, #shown do
      local e = shown[k]
      if not e.hidden and e.short > 0 then
        local cheapest = makes(e) and e.make or e.price
        if cheapest then sum = sum + cheapest * e.short end
        shortCount = shortCount + 1
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
      row:SetAlpha(1)
      row.item = nil
      row:SetSelected(false)
      row.icon:Hide()
      row.name:SetText("|cffe8c46a" .. e.header .. "|r")
      row.effect:SetWidth(330)
      row.effect:SetText(HINT[e.header] or "")
      row.have:SetText("")
      row.make:SetText("")
      row.price:SetText("")
    else
      row:Show()
      row:SetAlpha(e.hidden and 0.4 or 1)
      row.item, row.short = e.id, e.short
      row:SetSelected(e.id == selectedItem)
      row.icon:Show()
      row.icon:SetTexture(NW.ItemIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetText((e.alt and "|cff94949aor|r  " or "") .. (itemName(e.id)))
      row.effect:SetWidth(180)
      row.effect:SetText(e.effect)
      -- green: cheaper to make. Grey: you don't know the recipe yet.
      local mk = ""
      if e.make then
        local col = (not e.m.known and "|cff94949a") or ((not e.price or e.make < e.price) and "|cff8cdb7a") or "|cffe6e6eb"
        mk = col .. NW.Money(e.make, true):gsub("|r", "|r" .. col) .. "|r"
      end
      row.make:SetText(mk)
      local col = (e.alt and (e.have > 0 and "|cff8cdb7a" or "|cff94949a")) or (e.short == 0 and "|cff8cdb7a")
        or (e.have == 0 and "|cffeb5c4d") or "|cffffe633"
      row.have:SetText(e.need > 1 and ("%s%d|r|cff94949a/%d|r"):format(col, e.have, e.need) or ("%s%d|r"):format(col, e.have))
      row.price:SetText(e.price and NW.Money(e.price, true) or "|cff94949a?|r")
    end
  end
  hiddenCheck:SetShown(nHidden > 0)
  hiddenCheck:Refresh()
  hint:SetShown(nHidden == 0)
  total:SetText(shortCount > 0 and ("Short %d  ·  %s to fill"):format(shortCount, NW.Money(sum, true)) or "|cff8cdb7aStocked|r")
  searchBtn:SetEnabled(shortCount > 0)
  drawDetail()
  matsBtn:SetShown(selectedItem ~= nil and NW.RecipeFor(selectedItem) ~= nil)
  farmBtn:SetShown(farmNode ~= nil)
  if farmNode then farmBtn:SetText("Farm " .. farmNode) end
end
