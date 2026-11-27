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
  { "Food", {
    { 238639, "+55 healing, +10 Sta", "full" }, { 249870, "+44 healing", "full" },
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
    { 250948, "+62 healing for 30s", "budget" },
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
      { "Food", {
        { 238639, "+55 healing, +10 Sta", "full" }, { 249870, "+44 healing", "full" },
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
        { 250948, "+62 healing for 30s", "budget" },
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
        { 250936, "+33 spell damage for 30s", "budget" },
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
        { 250936, "+33 spell damage for 30s", "budget" },
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
        { 274275, "+30 Sta, harder to dodge in Hyjal", "full" },
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
        { 274275, "+30 Sta, harder to dodge in Hyjal", "full" },
        { 274274, "+30 Sta, 2% crit in Hyjal", "full" },
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
        { 274274, "+30 Sta, 2% crit in Hyjal", "full" },
      } },
      { "Elixirs", {
        { 9264, "+40 shadow damage" },
        { 13454, "+35 spell damage", "full" },
        { 250337, "+25 Int, 2% crit", "full" },
        { 9155, "+20 spell damage", "budget" },
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
        { 250936, "+33 spell damage for 30s", "budget" },
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
local HEAL_FOOD = { "Food", { { 238639, "+55 healing, +10 Sta", "full" }, { 249870, "+44 healing", "full" }, { 249869, "+33 healing", "budget" } } }
local HEAL_OIL = { "Weapon oil", {
  { 20749, "+36 healing, 1% spell crit", "full" },
  { 20748, "15 mana / 5s, +30 healing", "full" },
  { 20747, "10 mana / 5s, +20 healing", "budget" },
} }
local HEAL_POTS = { "Potions", {
  { 13444, "1350-2250 mana", "full" },
  { 13443, "900-1500 mana", "budget" },
  { 250949, "+88 healing for 30s", "full" },
  { 250948, "+62 healing for 30s", "budget" },
  { 18253, "1440-1760 health and mana", "full" },
} }
local CASTER_POTS = { "Potions", {
  { 250937, "+47 spell damage for 30s", "full" },
  { 250936, "+33 spell damage for 30s", "budget" },
  { 13444, "1350-2250 mana", "full" },
  { 13443, "900-1500 mana", "budget" },
  { 250954, "+105 spell damage vs elementals", "full" },
  { 250953, "For mass AoE", "full" },
} }
local MELEE_FOOD = { "Food", { { 238637, "+25 Str, +10 Sta", "full" }, { 20452, "+20 Str", "full" }, { 13934, "+40 attack power", "full" }, { 13932, "+40 attack power", "full" }, { 250071, "+20 Str", "budget" } } }
local AGI_FOOD = { "Food", { { 238638, "+25 Agi, +10 Sta", "full" }, { 13932, "+40 attack power", "full" }, { 13934, "+40 attack power", "full" }, { 250072, "+20 Agi" } } }

local function add(t) NW.CONSUMES[#NW.CONSUMES + 1] = t end

add({ key = "paladin-prot", class = "PALADIN", label = "Protection Paladin", groups = {
  { "Flask", {
    { 274275, "+30 Sta, harder to dodge in Hyjal", "full" },
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
  { "Flask", { { 274275, "+30 Sta, harder to dodge in Hyjal", "full" }, { 274274, "+30 Sta, 2% crit in Hyjal", "full" } } },
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
  { "Flask", { { 13511, "+2000 mana", "full" }, { 274276, "+30 Sta, 2% haste in Hyjal", "full" } } },
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
    { 250948, "+62 healing for 30s", "budget" },
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
  { "Flask", { { 274274, "+30 Sta, 2% crit in Hyjal", "full" }, { 274273, "+30 Sta, 2% hit in Hyjal", "full" } } },
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
  { "Potions", { { 250943, "+80 attack power for 30s", "full" }, { 250942, "+56 attack power for 30s", "budget" }, { 13446, "1050-1750 health" } } },
} })
add({ key = "druid-bear", class = "DRUID", label = "Feral Druid (Bear)", groups = {
  { "Flask", { { 274275, "+30 Sta, harder to dodge in Hyjal", "full" }, { 13510, "+1200 health", "full" } } },
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
  { "Flask", { { 274274, "+30 Sta, 2% crit in Hyjal", "full" }, { 274273, "+30 Sta, 2% hit in Hyjal", "full" } } },
  { "Elixirs", {
    { 250328, "+25 Agi, +25 Int", "full" },
    { 13452, "+25 Agi, 2% crit", "full", "crit" },
    { 9187, "+25 Agi", "budget" },
  } },
  AGI_FOOD,
  { "Potions", {
    { 250943, "+80 attack power for 30s", "full" },
    { 250955, "+180 attack power vs beasts", "full" },
    { 250942, "+56 attack power for 30s", "budget" },
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
  { "Flask", { { 274273, "+30 Sta, 2% hit in Hyjal", "full" }, { 274274, "+30 Sta, 2% crit in Hyjal", "full" } } },
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
    { 250942, "+56 attack power for 30s", "budget" },
    { 13446, "1050-1750 health", "full" },
    { 3928, "700-900 health", "budget" },
    { 5634, "Immune to stuns, roots for 30s", "full" },
    { 3387, "Immune to physical for 6s", "full" },
  } },
  { "Poisons", { { 8928, "Main hand" }, { 20844, "Off hand" } } },
  { "Other", { { 7676, "100 energy" }, { 14530, "2000 health over 8s" } } },
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
  { "Flask", { { 13512, "+150 spell damage", "full" }, { 274274, "+30 Sta, 2% crit in Hyjal", "full" } } },
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
-- Search AH works only at the auction house
NW.On("AUCTION_HOUSE_SHOW", function() if page:IsShown() then page.dirty = true end end)
NW.On("AUCTION_HOUSE_CLOSED", function() if page:IsShown() then page.dirty = true end end)
page:SetScript("OnUpdate", function(self) if self.dirty then self.dirty = false refresh() end end)

local selectedItem
local offset = 0

-- How many of each an hour of raiding uses up, by heading
local PER_HOUR = { Flask = 0.5, Elixirs = 1, Food = 2, Drink = 2, ["Weapon oil"] = 2, Weapon = 2, Poisons = 2, Potions = 5,
  Protection = 1, Runes = 3, Other = 3 }
-- Headings where you only ever use one of the rows
-- (runes share a cooldown with healthstones but aren't exclusive: you can use one, then another)
local PICK_ONE = { Flask = true, Food = true, Drink = true, ["Weapon oil"] = true, Weapon = true }
-- Sections that are there to browse, not to stock
local OPTIONAL = { Situational = true, Camp = true }
-- Raid lists: long buffs are core (ticked to start); items you use now and then are optional,
-- the protection potions situational. Nothing is ranked beyond the guides' own order.
local RAID_TIER = { Potions = "optional", Runes = "optional", Other = "optional", Protection = "situational" }
-- What can run together, shown beside each heading
local HINT = {
  Flask = "one at a time",
  Elixirs = "stack together, and with a flask",
  Food = "one at a time",
  Drink = "one at a time",
  Poisons = "one per weapon",
  Runes = "one per cooldown, shared with healthstones",
  ["Weapon oil"] = "one per weapon",
  Weapon = "one per weapon",
  Potions = "share a cooldown",
  Protection = "share the potion cooldown",
  Recommended = "best you can use at your level",
  ["Also helpful"] = "for your other buff slots",
  Situational = "when the fight calls for it",
  Bandages = "by your First Aid skill",
  Camp = "at a campfire, 1 hour shared cooldown",
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

-- Your loadout, per list: { ["set:<slot>"] = chosen id (false: none), [id] = ticked }.
-- Unset means the list's own choice: the first row of a slot, every other row
-- except the browse-only sections.
local function picksOf(key)
  local all = st().consumePick
  if not all then all = {} st().consumePick = all end
  local p = all[key] or {}
  all[key] = p
  -- runes used to be one of a slot: the one you picked stays ticked
  local r = p["set:Runes"]
  if r ~= nil then
    if r and p[r] == nil then p[r] = true end
    p["set:Runes"] = nil
  end
  return p
end
-- Targets you set by hand, per list: [id] = how many
local function qtyOf(key)
  local all = st().consumeQty
  if not all then all = {} st().consumeQty = all end
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
  -- the game writes plurals as "1 |4hour:hrs;"
  text = text:gsub("|4([^:;]*):[^;]*;", "%1"):lower()
  -- a cooldown isn't how long it lasts: "(1 hour cooldown)", "1 hour shared cooldown"
  text = text:gsub("%([^%)]*cooldown[^%)]*%)", ""):gsub("%d+ %a+ shared cooldown", ""):gsub("%d+ %a+ cooldown", "")
  local h = text:match("(%d+) ho?u?rs?")
  if h then return tonumber(h) * 60 end
  local m = tonumber(text:match("(%d+) min"))
  if m and m >= 10 then return m end
end

------------------------------------------------------------------------
-- Leveling: the best of each kind you can use at your level
------------------------------------------------------------------------
-- Ladders run best first. A { } entry is a set of equals: the one in your
-- bags, or the cheapest, is shown.
local LADDER = {
  strength = { 250351, 9206, 13453, 250349, 3391, 2454 },
  agility = { 13452, 250328, 9187, 8949, 3390, 2457 },
  intellect = { 250337, 9179, 13447, 250354, 250353, 3383 },
  spirit = { 250347, 250346, 250345, 250344 },
  spell = { 13454, 9155, 250342, 247754 },
  healing = { 250333, 250332, 250331, 250330 },
  regen = { 250341, 20007, 250340, 250339 },
  health = { 250335, 250334, 3825, 2458 },
  armor = { 250329, 13445, 8951, 3389, 5997 },
  troll = { 20004, 3826, 3388, 3382 },
  fire = { 6373 },
  frost = { 17708 },
  shadow = { 9264 },
  holy = { 21546 },
  nature = { 250343 },
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
  sStr = { 10310, 4426, 2289, 954 },
  sAgi = { 10309, 4425, 1477, 3012 },
  sInt = { 10308, 4419, 2290, 955 },
  sSpi = { 10306, 4424, 1712, 1181 },
  sSta = { 10307, 4422, 1711, 1180 },
  sArm = { 10305, 4421, 1478, 3013 },
  fStr = { { 238637 }, { 250071, 250070, 20452, 13934 }, { 13932 }, { 250065 }, { 250074, 274976, 8364 }, { 5480, 2685 }, { 4592 }, { 3726, 3220, 2687, 724 }, { 787 }, { 2888, 2681, 6890 } },
  fAgi = { { 238638 }, { 250072, 250069, 13934 }, { 13932 }, { 12212, 18045 }, { 13928, 13929 }, { 13851, 20074, 3728 }, { 8364 }, { 3664, 3727, 12209, 1017 }, { 4592 }, { 2684, 3662 }, { 787 }, { 2680 } },
  fSpell = { { 13935, 13933 }, { 13931, 6887 }, { 274971 }, { 4457, 250073, 12216 }, { 21217 }, { 12210 }, { 21072 }, { 2683, 1082, 250077 }, { 2682, 12224, 5477, 250079 } },
  fHeal = { 238639, 249870, 249869, 249868, 249867, 249866, 249865 },
  fArmor = { 286152 },
  rum = { 21151, { 21114, 17048 }, 20709 },
  instant = { 8928, 8927, 8926, 6950, 6949, 6947 }, deadly = { 20844, 8985, 8984, 2893, 2892 },
  familiar = { 277493, 277483, 275069 },
  wheel = { 279944 }, lodestone = { 279960 }, chair = { 279979 }, well = { 279956 }, bannerH = { 279972 }, bannerA = { 279973 },
  bandage = { 14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251 },
  freeAction = { 5634 }, swift = { 2459 }, stoneshield = { 13455, 4623 }, invuln = { 3387 },
  rejuv = { 18253, 2456 }, discolored = { 247242, 247241, 247240, 247239, 4596 },
  resist = { 9036, 3384 }, wicked = { 250336 },
  fSta = { { 250068, 250081 }, { 17222, 12218, 16766 }, { 12215, 250078, 6038 }, { 3665, 5527, 3666, 12214, 3729 }, { 3663, 250080, 12213, 5526, 5479 }, { 6888, 5472, 5474, 5525 } },
}
-- { level, effect } as the Forever client reports them (/nw harvest)
local ITEM = {
  [250351] = { 55, "+25 Str, 2% crit" }, [9206] = { 48, "+25 Str" }, [13453] = { 45, "+18 Str, +18 Sta" }, [250349] = { 45, "+10 Str" },
  [3391] = { 20, "+8 Str" }, [2454] = { 1, "+4 Str" }, [13452] = { 46, "+25 Agi, 2% crit" }, [250328] = { 55, "+25 Agi, +25 Int" },
  [9187] = { 38, "+25 Agi" }, [8949] = { 27, "+15 Agi" }, [3390] = { 18, "+8 Agi" }, [2457] = { 2, "+4 Agi" }, [250337] = { 55, "+25 Int, 2% crit" },
  [9179] = { 37, "+25 Int" }, [13447] = { 38, "+18 Int, +18 Spirit" }, [250354] = { 45, "+10 Int" }, [250353] = { 25, "+6 Int" },
  [3383] = { 10, "+3 Int" }, [250347] = { 55, "+18 Spirit" }, [250346] = { 45, "+10 Spirit" }, [250345] = { 25, "+6 Spirit" },
  [250344] = { 5, "+3 Spirit" }, [13454] = { 47, "+35 spell damage" }, [9155] = { 37, "+20 spell damage" }, [250342] = { 25, "+15 spell damage" },
  [247754] = { 1, "+5 spell damage" }, [250333] = { 55, "+40 healing" }, [250332] = { 45, "+30 healing" }, [250331] = { 25, "+20 healing" },
  [250330] = { 5, "+10 healing" }, [250341] = { 55, "20 mana / 5s" }, [20007] = { 40, "12 mana / 5s" }, [250340] = { 25, "6 mana / 5s" },
  [250339] = { 5, "3 mana / 5s" }, [250335] = { 55, "+400 health" }, [250334] = { 45, "+200 health" }, [3825] = { 25, "+120 health" },
  [2458] = { 2, "+27 health" }, [250329] = { 55, "+400 health, 500 armor" }, [13445] = { 43, "+450 armor" }, [8951] = { 29, "+250 armor" },
  [3389] = { 16, "+150 armor" }, [5997] = { 1, "+50 armor" }, [20004] = { 53, "20 health / 5s" }, [3826] = { 26, "12 health / 5s" },
  [3388] = { 15, "6 health / 5s" }, [3382] = { 1, "2 health / 5s" }, [6373] = { 18, "+10 fire damage" }, [17708] = { 28, "+15 frost damage" },
  [9264] = { 40, "+40 shadow damage" }, [21546] = { 40, "+40 holy damage" }, [250343] = { 55, "+40 nature damage" },
  [13446] = { 45, "1050-1750 health" }, [3928] = { 35, "700-900 health" }, [1710] = { 21, "455-585 health" }, [929] = { 12, "280-360 health" },
  [858] = { 3, "140-180 health" }, [118] = { 1, "70-90 health" }, [13444] = { 49, "1350-2250 mana" }, [13443] = { 41, "900-1500 mana" },
  [6149] = { 31, "700-900 mana" }, [3827] = { 22, "455-585 mana" }, [3385] = { 14, "280-360 mana" }, [2455] = { 5, "140-180 mana" },
  [250943] = { 55, "+80 attack power, 30s" }, [250942] = { 45, "+56 attack power, 30s" }, [250941] = { 35, "+40 attack power, 30s" },
  [250940] = { 25, "+28 attack power, 30s" }, [250939] = { 15, "+18 attack power, 30s" }, [250938] = { 5, "+12 attack power, 30s" },
  [250937] = { 55, "+47 spell damage, 30s" }, [250936] = { 45, "+33 spell damage, 30s" }, [250935] = { 35, "+23 spell damage, 30s" },
  [250934] = { 25, "+16 spell damage, 30s" }, [250933] = { 15, "+11 spell damage, 30s" }, [250932] = { 5, "+7 spell damage, 30s" },
  [250949] = { 55, "+88 healing, 30s" }, [250948] = { 45, "+62 healing, 30s" }, [250947] = { 35, "+44 healing, 30s" },
  [250946] = { 25, "+31 healing, 30s" }, [250945] = { 15, "+20 healing, 30s" }, [250944] = { 5, "+13 healing, 30s" }, [13442] = { 46, "45-75 rage" },
  [5633] = { 25, "30-60 rage" }, [5631] = { 4, "20-40 rage" }, [12404] = { 35, "+8 damage, sharp" }, [7964] = { 25, "+6 damage, sharp" },
  [2871] = { 15, "+4 damage, sharp" }, [2863] = { 5, "+3 damage, sharp" }, [2862] = { 1, "+2 damage, sharp" }, [12643] = { 35, "+8 damage, blunt" },
  [7965] = { 25, "+6 damage, blunt" }, [3241] = { 15, "+4 damage, blunt" }, [3240] = { 5, "+3 damage, blunt" }, [3239] = { 1, "+2 damage, blunt" },
  [20749] = { 45, "+36 spell, 1% crit" }, [20750] = { 40, "+24 spell damage" }, [20746] = { 30, "+16 spell damage" },
  [20744] = { 5, "+8 spell damage" }, [20748] = { 45, "15 mana / 5s, +30 healing" }, [20747] = { 40, "10 mana / 5s, +20 healing" },
  [20745] = { 20, "5 mana / 5s, +10 healing" }, [10310] = { 55, "+17 Str" }, [4426] = { 40, "+13 Str" }, [2289] = { 25, "+9 Str" },
  [954] = { 10, "+5 Str" }, [10309] = { 55, "+17 Agi" }, [4425] = { 40, "+13 Agi" }, [1477] = { 25, "+9 Agi" }, [3012] = { 10, "+5 Agi" },
  [10308] = { 50, "+16 Int" }, [4419] = { 35, "+12 Int" }, [2290] = { 20, "+8 Int" }, [955] = { 5, "+4 Int" }, [10306] = { 45, "+15 Spirit" },
  [4424] = { 30, "+11 Spirit" }, [1712] = { 15, "+7 Spirit" }, [1181] = { 1, "+3 Spirit" }, [10307] = { 50, "+16 Sta" }, [4422] = { 35, "+12 Sta" },
  [1711] = { 20, "+8 Sta" }, [1180] = { 5, "+4 Sta" }, [10305] = { 45, "+240 armor" }, [4421] = { 30, "+180 armor" }, [1478] = { 15, "+120 armor" },
  [3013] = { 1, "+60 armor" }, [250071] = { 45, "+20 Str" }, [20452] = { 45, "+20 Str" }, [13934] = { 45, "+40 attack power" },
  [13932] = { 35, "+40 attack power" }, [250065] = { 35, "+15 Str" }, [250074] = { 25, "+10 Str" }, [274976] = { 25, "+10 Str" },
  [8364] = { 25, "+20 attack power" }, [5480] = { 15, "+5 Str" }, [2685] = { 15, "+5 Str" }, [4592] = { 5, "+10 attack power" },
  [3726] = { 5, "+3 Str" }, [3220] = { 5, "+3 Str" }, [2687] = { 5, "+3 Str" }, [724] = { 5, "+3 Str" }, [787] = { 1, "+6 attack power" },
  [2888] = { 1, "+1 Str" }, [2681] = { 1, "+1 Str" }, [6890] = { 1, "+1 Str" }, [250072] = { 45, "+20 Agi" }, [12212] = { 35, "+15 Agi" },
  [18045] = { 35, "+15 Agi" }, [13928] = { 35, "+1% crit" }, [13929] = { 35, "+1% crit" }, [13851] = { 25, "+10 Agi" }, [20074] = { 25, "+10 Agi" },
  [3728] = { 25, "+10 Agi" }, [3664] = { 15, "+5 Agi" }, [3727] = { 15, "+5 Agi" }, [12209] = { 15, "+5 Agi" }, [1017] = { 15, "+5 Agi" },
  [2684] = { 5, "+3 Agi" }, [3662] = { 5, "+3 Agi" }, [2680] = { 1, "+1 Agi" }, [13935] = { 45, "+28 spell damage" },
  [13933] = { 45, "+28 spell damage" }, [13931] = { 35, "+22 spell damage" }, [6887] = { 35, "+22 spell damage" },
  [274971] = { 25, "+14 spell damage" }, [4457] = { 25, "+10 Int" }, [250073] = { 25, "+10 Int" }, [12216] = { 25, "+10 Int" },
  [21217] = { 30, "+7 spell damage" }, [12210] = { 15, "+5 Int" }, [21072] = { 10, "+4 spell damage" }, [2683] = { 5, "+3 Int" },
  [1082] = { 5, "+3 Int" }, [250077] = { 5, "+3 Int" }, [2682] = { 1, "+1 Int" }, [12224] = { 1, "+1 Int" }, [5477] = { 1, "+1 Int" },
  [250079] = { 1, "+1 Int" }, [249870] = { 45, "+44 healing" }, [249869] = { 35, "+33 healing" }, [249866] = { 5, "+7 healing" },
  [249865] = { 1, "+2 healing" }, [250068] = { 45, "+20 Sta" }, [250081] = { 45, "+20 Sta" }, [17222] = { 35, "+15 Sta" },
  [12218] = { 35, "+15 Sta" }, [16766] = { 35, "+15 Sta" }, [12215] = { 25, "+10 Sta" }, [250078] = { 25, "+10 Sta" }, [6038] = { 25, "+10 Sta" },
  [3665] = { 15, "+5 Sta" }, [5527] = { 15, "+5 Sta" }, [3666] = { 15, "+5 Sta" }, [12214] = { 15, "+5 Sta" }, [3729] = { 15, "+5 Sta" },
  [3663] = { 1, "+3 Sta" }, [250080] = { 5, "+3 Sta" }, [12213] = { 5, "+3 Sta" }, [5526] = { 5, "+3 Sta" }, [5479] = { 5, "+3 Sta" },
  [6888] = { 1, "+1 Sta" }, [5472] = { 1, "+1 Sta" }, [5474] = { 1, "+1 Sta" }, [5525] = { 1, "+1 Sta" },
  [238637] = { 55, "+25 Str, +10 Sta" }, [238638] = { 55, "+25 Agi, +10 Sta" }, [238639] = { 55, "+55 healing, +10 Sta" },
  [250070] = { 45, "+20 Str" }, [250069] = { 45, "+20 Agi" }, [249868] = { 25, "+22 healing" }, [249867] = { 15, "+11 healing" },
  [21151] = { 0, "+15 Sta, with food" }, [21114] = { 0, "+10 Sta, with food" }, [17048] = { 0, "+10 Sta, with food" },
  [20709] = { 0, "+5 Sta, with food" },
  [8928] = { 60, "main hand" }, [8927] = { 52, "main hand" }, [8926] = { 44, "main hand" }, [6950] = { 36, "main hand" },
  [6949] = { 28, "main hand" }, [6947] = { 20, "main hand" },
  [20844] = { 60, "off hand" }, [8985] = { 54, "off hand" }, [8984] = { 46, "off hand" }, [2893] = { 38, "off hand" }, [2892] = { 30, "off hand" },
  [277493] = { 25, "+12 Int" }, [277483] = { 16, "+6 Int" }, [275069] = { 5, "+2 Int" },
  [279944] = { 0, "+34 Str" }, [279960] = { 0, "+90 attack power" }, [279979] = { 0, "+2% crit" }, [279956] = { 0, "29 mana / 5s" },
  [279972] = { 0, "+32 Spirit" }, [279973] = { 0, "+32 Spirit" },
  [286152] = { 35, "+150 armor" }, [250336] = { 55, "9 hp, 10 mana / 5s" },
  [5634] = { 20, "no stuns, roots 30s" }, [2459] = { 5, "+50% run speed, 15s" },
  [13455] = { 46, "+2000 armor, 2 min" }, [4623] = { 33, "+1000 armor, 90s" }, [3387] = { 45, "physical immune, 6s" },
  [18253] = { 50, "1440-1760 health, mana" }, [2456] = { 5, "90-150 health, mana" },
  [247242] = { 35, "1500-1700 burst heal" }, [247241] = { 21, "975-1105 burst heal" },
  [247240] = { 12, "600-680 burst heal" }, [4596] = { 5, "150-170 burst heal" },
  [247239] = { 3, "300-340 burst heal" },
  [9036] = { 32, "+50 resistances, 3 min" }, [3384] = { 12, "+25 resistances, 3 min" },
  [14530] = { 0, "2000 health" }, [14529] = { 0, "1360 health" }, [8545] = { 0, "1104 health" }, [8544] = { 0, "800 health" },
  [6451] = { 0, "640 health" }, [6450] = { 0, "400 health" }, [3531] = { 0, "301 health" }, [3530] = { 0, "161 health" },
  [2581] = { 0, "114 health" }, [1251] = { 0, "66 health" },
}
-- { label, ladder, uses per hour, "or" set }
local function slot(label, ladder, perHour, set) return { label, ladder, perHour, set } end
local STONES = { slot("Weapon", "sharp", 2, "stone"), slot("Weapon", "blunt", 2, "stone") }
local ROLES = {
  str = {
    { slot("Food", "fStr", 2), slot("Elixir", "strength"), slot("Elixir", "agility"), STONES, slot("Potion", "healpot", 3) },
    { slot("Elixir", "health"), slot("Elixir", "armor"), slot("Elixir", "troll"),
      slot("Potion", "frenzy", 3), slot("Scroll", "sStr", 2), slot("Scroll", "sAgi", 2) },
  },
  agi = {
    { slot("Food", "fAgi", 2), slot("Elixir", "agility"), slot("Elixir", "strength"), STONES, slot("Potion", "healpot", 3) },
    { slot("Elixir", "health"), slot("Elixir", "troll"),
      slot("Potion", "frenzy", 3), slot("Scroll", "sAgi", 2), slot("Scroll", "sStr", 2) },
  },
  tank = {
    { slot("Food", "fSta", 2), slot("Elixir", "health"), slot("Elixir", "armor"), STONES, slot("Potion", "healpot", 3) },
    { slot("Elixir", "strength"), slot("Elixir", "agility"), slot("Elixir", "troll"),
      slot("Scroll", "sSta", 2), slot("Scroll", "sArm", 2) },
  },
  caster = {
    { slot("Food", "fSpell", 2), slot("Elixir", "spell"), slot("Elixir", "intellect"),
      slot("Oil", "wizard", 2), slot("Potion", "manapot", 3), slot("Potion", "healpot", 3) },
    { "school", slot("Elixir", "regen"), slot("Elixir", "spirit"), slot("Elixir", "health"),
      slot("Potion", "blast", 3), slot("Scroll", "sInt", 2), slot("Scroll", "sSpi", 2) },
  },
  heal = {
    { slot("Food", "fHeal", 2), slot("Elixir", "healing"), slot("Elixir", "regen"), slot("Elixir", "intellect"),
      slot("Oil", "manaoil", 2), slot("Potion", "manapot", 3) },
    { slot("Elixir", "spirit"), slot("Elixir", "health"), slot("Potion", "mender", 3),
      slot("Potion", "healpot", 3), slot("Scroll", "sInt", 2), slot("Scroll", "sSpi", 2) },
  },
}
local ROLE_OF = {
  ["paladin-holy"] = "heal", ["priest-holy"] = "heal", ["priest-disc"] = "heal", ["druid-resto"] = "heal", ["shaman-resto"] = "heal",
  ["priest-shadow"] = "caster", ["priest-smite"] = "caster", warlock = "caster", mage = "caster", ["druid-balance"] = "caster", ["shaman-ele"] = "caster",
  ["warrior-dps"] = "str", ["paladin-ret"] = "str", ["shaman-enh"] = "str",
  rogue = "agi", hunter = "agi", ["druid-cat"] = "agi",
  ["warrior-prot"] = "tank", ["paladin-prot"] = "tank", ["druid-bear"] = "tank",
}
-- Raid healers: mana potions are core (copied, so lists that share a group aren't changed)
do
  local MANA_POT = { [13444] = true, [13443] = true }
  for _, list in ipairs(NW.CONSUMES) do
    if ROLE_OF[list.key] == "heal" then
      for gi, g in ipairs(list.groups) do
        if g[1] == "Potions" then
          local items = {}
          for i, c in ipairs(g[2]) do
            items[i] = MANA_POT[c[1]] and { c[1], c[2], c[3], c[4], c[5], c[6], "core" } or c
          end
          list.groups[gi] = { g[1], items }
        end
      end
    end
  end
end
-- A caster's own school
local SCHOOL = {
  mage = { slot("Elixir", "fire"), slot("Elixir", "frost") }, warlock = { slot("Elixir", "shadow"), slot("Elixir", "fire") },
  ["priest-shadow"] = { slot("Elixir", "shadow") }, ["priest-smite"] = { slot("Elixir", "holy") },
  ["druid-balance"] = { slot("Elixir", "nature") }, ["shaman-ele"] = { slot("Elixir", "nature") },
}
-- no weapon stones, or no mana, for these
local NO_STONE = { hunter = true, ["druid-cat"] = true, ["druid-bear"] = true }
local MANA_TOO = { ["paladin-ret"] = true, ["shaman-enh"] = true, hunter = true, ["paladin-prot"] = true, ["druid-cat"] = true,
  ["druid-bear"] = true }

-- First Aid skill each bandage needs
local BANDAGE = { [14530] = 225, [14529] = 200, [8545] = 175, [8544] = 150, [6451] = 125, [6450] = 100, [3531] = 75, [3530] = 50,
  [2581] = 20, [1251] = 1 }
-- Level an item needs: the game's word when it has it, else the harvested one.
-- For a bandage it's First Aid skill.
local function levelOf(id)
  if BANDAGE[id] then return BANDAGE[id] end
  local _, _, _, _, minLevel = NW.ItemInfo(id)
  return minLevel or (ITEM[id] and ITEM[id][1]) or 99
end
-- Lowest level of each zone (Warcraft Wiki, "Zones by level (original)"), so
-- leveling picks skip recipes sold or dropped only in zones above you
local ZONE_MIN = {
  ["Alterac Mountains"] = 30, ["Arathi Highlands"] = 30, ["Badlands"] = 35, ["Blasted Lands"] = 45, ["Silverpine Forest"] = 10,
  ["Western Plaguelands"] = 51, ["Eastern Plaguelands"] = 53, ["Hillsbrad Foothills"] = 20, ["The Hinterlands"] = 40,
  ["Searing Gorge"] = 45, ["Burning Steppes"] = 50, ["Deadwind Pass"] = 55, ["Duskwood"] = 18, ["Loch Modan"] = 10,
  ["Redridge Mountains"] = 15, ["Stranglethorn Vale"] = 30, ["Swamp of Sorrows"] = 35, ["Westfall"] = 10, ["Wetlands"] = 20,
  ["The Barrens"] = 10, ["Darkshore"] = 10, ["Ashenvale"] = 18, ["Thousand Needles"] = 25, ["Stonetalon Mountains"] = 15,
  ["Desolace"] = 30, ["Feralas"] = 40, ["Dustwallow Marsh"] = 35, ["Tanaris"] = 40, ["Azshara"] = 45, ["Felwood"] = 48,
  ["Un'Goro Crater"] = 48, ["Moonglade"] = 55, ["Silithus"] = 55, ["Winterspring"] = 55, ["Riverglades"] = 35,
}
-- Whether you can get the recipe at your level: known, from a trainer, or from
-- at least one vendor or drop of your faction in a zone you're high enough for
local function reachable(id, level)
  local r, key = NW.RecipeFor(id)
  if not r or not r.where or r.src == "trainer" or r.src == "rank" then return true end
  local known = NW.charDB.known and NW.charDB.known[key]
  if known and known[r.name] then return true end
  local fac = (UnitFactionGroup and UnitFactionGroup("player")) == "Alliance" and "A" or "H"
  local any = false
  for tok in r.where:gmatch("[^;]+") do
    local c, rest = tok:sub(1, 1), tok:sub(2)
    if tok == "F" or tok == "S" or tok == "T" or tok == "B" or c == "+" then return true end
    if c == "V" then
      local f = rest:sub(1, 1)
      rest = (f == "*" or f == fac) and rest:sub(2) or nil
    elseif c ~= "D" then rest = nil end
    if rest then
      any = true
      local zone = rest:match(", ([^,]+)$")
      if zone and zone ~= "?" and (ZONE_MIN[zone] or 0) <= level then return true end
    elseif c == "V" or c == "Q" then any = true end
  end
  return not any
end
-- Best item on a ladder you're high enough for, and the next better one
-- with the level it unlocks at
local function bestForBest(ladder, level)
  local nextId, nextAt
  for _, e in ipairs(LADDER[ladder]) do
    local group = type(e) == "table" and e or { e }
    local pick, pickCost, lowest
    for _, id in ipairs(group) do
      local need = levelOf(id)
      if NW.NOT_YET and NW.NOT_YET[id] then
        -- not in the game yet
      elseif need <= level and (NW.ItemCount(id) or 0) > 0 then return id, nextId, nextAt
      elseif need <= level and not reachable(id, level) then
        -- its recipe comes only from zones above you
      elseif need <= level then
        local cost, src = NW.Price(id)
        if src == "est" then cost = nil end
        if not pick or (cost and (not pickCost or cost < pickCost)) then pick, pickCost = id, cost or pickCost end
      elseif not lowest or need < levelOf(lowest) then
        lowest = id
      end
    end
    if pick then return pick, nextId, nextAt end
    -- too high for now: the soonest of these is what to look forward to
    if lowest and levelOf(lowest) < 99 and (not nextAt or levelOf(lowest) < nextAt) then nextId, nextAt = lowest, levelOf(lowest) end
  end
end

-- How the level list picks, by strategy (README, Consumes):
--   best:   the strongest you can use now (one in your bags first among equals, else the cheapest)
--   budget: one you carry, else the cheapest priced one you can use (unpriced ones skipped; none priced: best)
--   own:    the strongest one you carry and can use, else best
-- "Can use": your level (First Aid skill for bandages), in the game, and its recipe reachable at your level.
NW.ConsumeLevelOf = levelOf -- (/nw harvest and the tests check recommendations against it)
local function eligible(id, level)
  return levelOf(id) <= level and not (NW.NOT_YET and NW.NOT_YET[id]) and reachable(id, level)
end
local function bestFor(ladder, level, strategy)
  local id, nextId, nextAt = bestForBest(ladder, level)
  if strategy ~= "budget" and strategy ~= "own" then return id, nextId, nextAt end
  local cheap, cheapCost
  for _, e in ipairs(LADDER[ladder]) do
    for _, x in ipairs(type(e) == "table" and e or { e }) do
      -- one you carry counts if you can use it, wherever its recipe comes from (rungs run best first)
      if (NW.ItemCount(x) or 0) > 0 and levelOf(x) <= level and not (NW.NOT_YET and NW.NOT_YET[x]) then return x, nextId, nextAt end
      if eligible(x, level) then
        if strategy == "budget" then
          local c, src = NW.Price(x)
          if c and src ~= "est" and (not cheapCost or c < cheapCost) then cheap, cheapCost = x, c end
        end
      end
    end
  end
  return cheap or id, nextId, nextAt
end

local function playerLevel() return UnitLevel and UnitLevel("player") or 60 end

-- The same shape as a raid list, built for your level
local upgradeOf = {} -- [item shown] = { next item, level or skill, is a bandage }
local altOf = {}     -- [item shown, no price] = a priced one of the same kind you can use
-- The leveling list, in categories (Food, Elixirs, Weapon, ...) like the raid lists. Each row
-- has a tier: core (the role's first list: ticked unless you untick it), optional (the role's
-- second list), situational (the fight decides). Only core rows start ticked.
-- Healers level by questing, not healing: a healing spec gets its class's solo list (paladins
-- melee, the rest caster), with the healing elixir and potion as optional.
local CATEGORY = { Food = "Food", Elixir = "Elixirs", Weapon = "Weapon", Oil = "Weapon", Poison = "Poisons",
  Potion = "Potions", Bandage = "Bandages", Scroll = "Utility", Drink = "Utility", Camp = "Camp" }
local CATEGORY_ORDER = { "Food", "Elixirs", "Weapon", "Poisons", "Potions", "Bandages", "Utility", "Situational", "Camp" }
local function levelList(spec, strategy)
  local level = playerLevel()
  wipe(upgradeOf)
  wipe(altOf)
  local roleKey = ROLE_OF[spec.key] or "str"
  local healer = roleKey == "heal"
  if healer then roleKey = spec.class == "PALADIN" and "str" or "caster" end
  local role = ROLES[roleKey]
  local out = { key = spec.key .. ":level", label = ("%s  ·  level %d"):format(spec.label, level), groups = {} }
  local firstAid = NW.ProfSkill("firstaid")
  local byCat, seen = {}, {}
  local function put(sl, tier, cat)
    if sl == "school" then
      for _, x in ipairs(SCHOOL[spec.key] or {}) do put(x, tier, cat) end
    elseif type(sl[1]) == "table" then
      if not NO_STONE[spec.key] then for _, x in ipairs(sl) do put(x, tier, cat) end end
    else
      local skill = sl[2] == "bandage"
      local id, nextId, nextAt = bestFor(sl[2], skill and (firstAid or 0) or level, strategy)
      if nextId and id then upgradeOf[id] = { nextId, nextAt, skill } end
      -- no price for it: the strongest priced one of the kind you can use, as a suggestion
      local p, src = id and NW.Price(id)
      if id and not (p and src ~= "est") then
        local lv = skill and (firstAid or 0) or level
        for _, rung in ipairs(LADDER[sl[2]]) do
          for _, x in ipairs(type(rung) == "table" and rung or { rung }) do
            local px, sx = NW.Price(x)
            if not altOf[id] and x ~= id and px and sx ~= "est" and eligible(x, lv) then altOf[id] = x end
          end
        end
      end
      if id and not seen[id] then
        seen[id] = true
        local fx = ITEM[id] and ITEM[id][2] or ""
        local c = cat or CATEGORY[sl[1]] or "Utility"
        byCat[c] = byCat[c] or {}
        -- (c[6], the ladder: your pick and target follow the kind as the item upgrades with your level)
        table.insert(byCat[c], { id, fx ~= "" and fx or sl[1], nil, sl[4], sl[3], sl[2], tier })
      end
    end
  end
  for _, sl in ipairs(role[1] or {}) do put(sl, "core") end
  if healer then put(slot("Potion", "manapot", 3), "core") end
  if MANA_TOO[spec.key] then put(slot("Potion", "manapot", 3), "core") end
  if firstAid then put(slot("Bandage", "bandage", 3), "core") end
  if spec.key == "rogue" then put(slot("Poison", "instant", 2), "core") put(slot("Poison", "deadly", 2), "core") end
  for _, sl in ipairs(role[2] or {}) do put(sl, "optional") end
  if healer then put(slot("Elixir", "healing"), "optional") put(slot("Potion", "mender", 3), "optional") end
  if spec.class == "WARRIOR" or spec.key == "druid-bear" then put(slot("Potion", "rage", 3), "optional") end
  if roleKey == "tank" then put(slot("Food", "fArmor", 2), "optional") end
  if spec.key == "mage" then put(slot("Scroll", "familiar"), "optional") end
  put(slot("Drink", "rum", 4), "optional")
  if MANA_TOO[spec.key] then put(slot("Elixir", "wicked"), "optional") end
  -- situational: the fight decides
  local mana = MANA_TOO[spec.key] or roleKey == "caster" or healer or spec.class == "DRUID"
  put(slot("Potion", "freeAction"), "situational", "Situational") put(slot("Potion", "swift"), "situational", "Situational")
  put(slot("Potion", "discolored"), "situational", "Situational")
  if mana then put(slot("Potion", "rejuv"), "situational", "Situational") end
  if roleKey == "tank" or roleKey == "str" then put(slot("Potion", "stoneshield"), "situational", "Situational") end
  if roleKey == "tank" then put(slot("Potion", "invuln"), "situational", "Situational") end
  put(slot("Potion", "resist"), "situational", "Situational")
  -- campfire items: a shared cooldown, browse only
  local campRole = ROLE_OF[spec.key] or "str"
  if roleKey == "str" or roleKey == "tank" then put(slot("Camp", "wheel", 1, "camp"), "optional") put(slot("Camp", "lodestone", 1, "camp"), "optional") end
  if roleKey == "agi" then put(slot("Camp", "lodestone", 1, "camp"), "optional") end
  if roleKey == "caster" or campRole == "heal" then put(slot("Camp", "well", 1, "camp"), "optional") end
  if roleKey ~= "tank" then put(slot("Camp", "chair", 1, "camp"), "optional") end
  if campRole == "heal" then
    put(slot("Camp", UnitFactionGroup and UnitFactionGroup("player") == "Alliance" and "bannerA" or "bannerH", 1, "camp"), "optional")
  end
  for _, c in ipairs(CATEGORY_ORDER) do
    if byCat[c] then out.groups[#out.groups + 1] = { c, byCat[c] } end
  end
  return out
end

-- /nw harvest: saves what the game says about every consumable Nodewalker
-- knows (name, level, use text), so the ladders can be checked against it
function NW.HarvestConsumes(all)
  local ids = {}
  for _, key in ipairs({ "alchemy", "cooking", "firstaid", "blacksmithing", "enchanting", "engineering" }) do
    for _, r in ipairs(NW.RECIPES[key] or {}) do if r.item then ids[r.item] = true end end
  end
  for _, l in ipairs(NW.CONSUMES) do
    for _, g in ipairs(l.groups) do for _, c in ipairs(g[2]) do ids[c[1]] = true end end
  end
  for _, ladder in pairs(LADDER) do
    for _, e in ipairs(ladder) do
      if type(e) == "table" then for _, id in ipairs(e) do ids[id] = true end else ids[e] = true end
    end
  end
  local start
  -- /nw harvest all: every consumable the client knows, crafted or not. The
  -- client can say what kind of thing an item ID is without asking the server.
  if all then
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local at, LAST = 0, 300000
    NW.Print("Harvest: looking through every item for consumables...")
    local function scan()
      for _ = 1, 5000 do
        at = at + 1
        local ok, _, _, _, _, _, classID = pcall(instant, at)
        if ok and classID == 0 then ids[at] = true end
      end
      if at < LAST then C_Timer.After(0.02, scan) else start() end
    end
    C_Timer.After(0, scan)
  else
    C_Timer.After(0, function() start() end)
  end
  -- The game sends item and spell text only when asked, a little at a time:
  -- ask in batches, wait for each answer, then save whatever came back.
  start = function()
  local queue = {}
  for id in pairs(ids) do queue[#queue + 1] = id end
  table.sort(queue)
  local out = NW.db.harvest or {}
  NW.db.harvest = out
  local function record(id)
    local name, _, _, _, minLevel, class, sub = NW.ItemInfo(id)
    local text = name and useText(id)
    if text then out[id] = { name = name, level = minLevel, class = class, sub = sub, text = text } end
  end
  local function ask(id)
    if not (Item and Item.CreateFromItemID) then record(id) return end
    local item = Item:CreateFromItemID(id)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
      local _, spellID = (C_Item and C_Item.GetItemSpell or GetItemSpell)(id)
      if spellID and Spell and Spell.CreateFromSpellID then
        Spell:CreateFromSpellID(spellID):ContinueOnSpellLoad(function() record(id) end)
      else
        record(id)
      end
    end)
  end
  local at, total = 0, #queue
  NW.Print(("Harvest: asking the game about %d items. About %d seconds."):format(total, math.ceil(total / 60) + 6))
  local function step()
    for _ = 1, 30 do
      at = at + 1
      if queue[at] then pcall(ask, queue[at]) end
    end
    if at < total then
      C_Timer.After(0.5, step)
    else
      C_Timer.After(6, function()
        for _, id in ipairs(queue) do if not out[id] then pcall(record, id) end end
        local n = 0
        for _ in pairs(out) do n = n + 1 end
        NW.Print(("Harvest: %d usable items saved (%d checked). /reload to write them to disk."):format(n, total))
      end)
    end
  end
  step()
  end
end

-- Which list: "level", "raid" or "budget". Below 60 it starts on your level.
-- What you're preparing for, and how to choose: Activity (Leveling, Raiding) and Strategy
-- (Best, Budget, Use what I own). The old one-dropdown List setting reads into them.
local function activity()
  local a = st().consumeActivity
  if a then return a end
  local m = st().consumeList
  if m == "level" then return "level" end
  if m == "raid" or m == "budget" then return "raid" end
  return playerLevel() < 60 and "level" or "raid"
end
local function strategy()
  local s = st().consumeStrategy
  if s then return s end
  return (st().consumeList == "budget" or (st().consumeList == nil and st().consumeBudget)) and "budget" or "best"
end
-- the list to build: "level", "raid" or "budget"
local function listMode()
  if activity() == "level" then return "level" end
  return strategy() == "budget" and "budget" or "raid"
end

------------------------------------------------------------------------
-- Layout: filters across the top, the list on the left, the selected
-- consumable on the right, a status bar along the bottom
------------------------------------------------------------------------
local PAD, GAP = S.PAD, 12
local PAGE_W, PAGE_H = UI.CONTENT_W, UI.CONTENT_H
local LIST_W = 652
local DET_W = PAGE_W - PAD * 2 - GAP - LIST_W
local TOP = 46                 -- filters sit above the panels
local STATUS_H = 32
local PANEL_H = PAGE_H - TOP - GAP - STATUS_H - PAD
local HEAD_H = 24              -- column header strip
local ITEM_H, GROUP_H = 34, 24
local BODY_H = PANEL_H - HEAD_H - 2
-- right edges of the number columns, from the list's left
local COL_HAVE, COL_CRAFT, COL_BUY = 462, 552, LIST_W - 16

local H = S.HEX

local specItems = {}
for _, l in ipairs(NW.CONSUMES) do specItems[#specItems + 1] = { l.key, l.label } end
local specDrop = UI.Dropdown(page, 190, "Spec", specItems, function() return currentList().key end, function(v)
  st().consumeSpec = v
  selectedItem = nil
  offset = 0
  refresh()
end, 150)
specDrop:SetPoint("TOPLEFT", PAD, -12)
local stockDrop = UI.Dropdown(page, 158, "Stock", { { 0, "One of each" }, { 1, "1-hour session" }, { 2, "2-hour session" },
  { 3, "3-hour session" }, { 4, "4-hour session" } },
  function() return math.min(4, st().consumeHours or 0) end, function(v)
    st().consumeHours = v
    refresh()
  end, 112, "An estimate for a session of play. Buffs by the duration the game gives; potions, runes, food and the like at a rough rate an hour. Deaths aren't counted. A target you set by hand stays.")
stockDrop:SetPoint("LEFT", specDrop, "RIGHT", 16, 0)
local function listChanged() selectedItem = nil offset = 0 refresh() end
local actDrop = UI.Dropdown(page, 146, "Activity", { { "level", "Leveling" }, { "raid", "Raiding" } },
  activity, function(v) st().consumeActivity = v listChanged() end, 90,
  "Leveling: the best of each kind you can use at your level, and it moves up as you level. Raiding: your spec's level-60 raid list.")
actDrop:SetPoint("LEFT", stockDrop, "RIGHT", 16, 0)
local budget = UI.Dropdown(page, 178, "Strategy", { { "best", "Best" }, { "budget", "Budget" }, { "own", "Use what I own" } },
  strategy, function(v) st().consumeStrategy = v listChanged() end, 116,
  "Best: the strongest you can use. Budget: the raid budget list; leveling, one you carry or else the cheapest you can use. Use what I own: what's in your bags first. Your own picks always stay.")
budget:SetPoint("LEFT", actDrop, "RIGHT", 16, 0)

-- Saved loadouts (per character): the spec, activity, strategy, stock, your choices and your targets.
-- On the leveling list choices follow the kind, so a saved loadout adapts as you level; on a raid
-- list they're the exact items.
local function loadouts()
  local l = st().consumeLoadouts
  if not l then l = {} st().consumeLoadouts = l end
  return l
end
local function copy(src) local o = {} for k, v in pairs(src or {}) do o[k] = v end return o end
local loadBtn = UI.Button(page, "Loadouts", 110, nil, 22)
loadBtn:SetPoint("LEFT", budget, "RIGHT", 16, 0)
page.loadBtn = loadBtn
local loadMenu = UI.Panel("NodewalkerLoadoutMenu", UIParent, 230, 10)
if UISpecialFrames then tinsert(UISpecialFrames, "NodewalkerLoadoutMenu") end -- (Escape closes it)
loadMenu:SetFrameStrata("FULLSCREEN_DIALOG")
loadMenu:SetClampedToScreen(true)
loadMenu:Hide()
loadMenu.rows = {}
local MAX_LOADOUTS = 10
local function listKeyNow()
  return currentList().key .. (listMode() == "level" and ":level" or (listMode() == "budget" and ":budget" or ""))
end
local function saveLoadout()
  local spec = currentList()
  local name = ("%s · %s · %s"):format(spec.label, activity() == "level" and "Leveling" or "Raiding",
    ({ best = "Best", budget = "Budget", own = "My bags" })[strategy()] or "")
  local key = listKeyNow()
  local l = loadouts()
  local entry = { name = name, spec = spec.key, activity = activity(), strategy = strategy(), hours = st().consumeHours or 0,
    listKey = key, picks = copy(picksOf(key)), qty = copy(qtyOf(key)), level = playerLevel() }
  for i, x in ipairs(l) do if x.name == name then l[i] = entry st().consumeLoadout = name return end end
  if #l >= MAX_LOADOUTS then table.remove(l, 1) end
  l[#l + 1] = entry
  st().consumeLoadout = name
end
local function applyLoadout(x)
  st().consumeSpec, st().consumeActivity, st().consumeStrategy, st().consumeHours = x.spec, x.activity, x.strategy, x.hours
  local allP, allQ = st().consumePick or {}, st().consumeQty or {}
  st().consumePick, st().consumeQty = allP, allQ
  allP[x.listKey], allQ[x.listKey] = copy(x.picks), copy(x.qty)
  st().consumeLoadout = x.name
  selectedItem, offset = nil, 0
  refresh()
end
local function loadRow(i)
  local r = loadMenu.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, loadMenu)
  r:SetHeight(20)
  r:SetPoint("TOPLEFT", 1, -4 - (i - 1) * 20)
  r:SetPoint("RIGHT", -1, 0)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.text = UI.Text(r, 12, S.text)
  r.text:SetPoint("LEFT", 8, 0)
  r.text:SetPoint("RIGHT", -8, 0)
  r.text:SetWordWrap(false)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.12)
  r:SetScript("OnEnter", function(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(self.tipTitle or "", 1, 1, 1)
    GameTooltip:AddLine(self.tip, S.dim[1], S.dim[2], S.dim[3], true) GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  loadMenu.rows[i] = r
  return r
end
local function openLoadouts()
  local l = loadouts()
  local n = 0
  for i, x in ipairs(l) do
    n = i
    local r = loadRow(i)
    r.text:SetText(x.name)
    r.text:SetTextColor(unpack(st().consumeLoadout == x.name and S.gold or S.text))
    r.tipTitle = x.name
    r.tip = (x.activity == "level" and "Adapts as you level: your choices follow each kind." or "The exact items you chose.")
      .. ("\nSaved at level %d. Click: load (replaces your current choices for that list). Right-click: delete."):format(x.level or 0)
    r:SetScript("OnClick", function(_, button)
      if button == "RightButton" then
        table.remove(l, i)
        if st().consumeLoadout == x.name then st().consumeLoadout = nil end
        openLoadouts()
        return
      end
      loadMenu:Hide()
      applyLoadout(x)
    end)
    r:Show()
  end
  local r = loadRow(n + 1)
  r.text:SetText("Save current")
  r.text:SetTextColor(unpack(S.gold))
  r.tipTitle, r.tip = "Save current", "Spec, activity, strategy, stock, your choices and targets. Saved under its spec, activity and strategy; saving again replaces it. Ten at most: the oldest goes."
  r:SetScript("OnClick", function() saveLoadout() loadMenu:Hide() refresh() end)
  r:Show()
  for k = n + 2, #loadMenu.rows do loadMenu.rows[k]:Hide() end
  loadMenu:SetHeight(8 + (n + 1) * 20)
  loadMenu:SetScale(loadBtn:GetEffectiveScale() / UIParent:GetEffectiveScale())
  loadMenu:ClearAllPoints()
  loadMenu:SetPoint("TOPLEFT", loadBtn, "BOTTOMLEFT", 0, -2)
  loadMenu:Show()
end
loadBtn:SetScript("OnClick", function() if loadMenu:IsShown() then loadMenu:Hide() else openLoadouts() end end)
loadBtn:HookScript("OnHide", function() loadMenu:Hide() end)
UI.Tip(loadBtn, "Loadouts", function()
  return (st().consumeLoadout and ("Loaded: " .. st().consumeLoadout .. "\n") or "") .. "Save and load your choices and targets."
end)
local title = UI.Text(page, 12, S.dim, "RIGHT")
title:SetPoint("RIGHT", page, "TOPRIGHT", -PAD, -24)
title:SetWidth(110)
title:SetWordWrap(false)

------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------
local listPanel, listHead = UI.Section(page, LIST_W, PANEL_H, "Consumable")
listPanel:SetPoint("TOPLEFT", PAD, -TOP)
for _, c in ipairs({ { "Owned / Target", COL_HAVE }, { "Craft", COL_CRAFT }, { "Buy", COL_BUY } }) do
  local t = UI.Text(listHead, 11, S.dim, "RIGHT")
  t:SetPoint("RIGHT", listHead, "LEFT", c[2] - 1, 0)
  t:SetText(c[1])
end
local body = CreateFrame("Frame", nil, listPanel)
body:SetPoint("TOPLEFT", 1, -1 - HEAD_H)
body:SetPoint("BOTTOMRIGHT", -1, 1)
body:SetClipsChildren(true)
local emptyText = UI.Text(body, 12, S.dim, "CENTER")
emptyText:SetPoint("CENTER")

local thumbLayer = CreateFrame("Frame", nil, body)
thumbLayer:SetAllPoints()
thumbLayer:SetFrameLevel(body:GetFrameLevel() + 20)
local thumb = thumbLayer:CreateTexture(nil, "OVERLAY")
thumb:SetWidth(3)
thumb:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 0.5)

-- Folded headings, remembered. Situational and Camp start folded.
local function folded(name)
  local f = st().consumeFolds
  local v = f and f[name]
  if v == nil then return OPTIONAL[name] or false end
  return v
end
local function setFolded(name, v)
  st().consumeFolds = st().consumeFolds or {}
  st().consumeFolds[name] = v
end

local rows, shown, visible = {}, {}, {}
local function onWheel(_, delta)
  local o = math.max(0, math.min(visible.maxOffset or 0, offset - delta * 2))
  if o ~= offset then offset = o refresh() end
end
body:EnableMouseWheel(true)
body:SetScript("OnMouseWheel", onWheel)

local function rowFor(i)
  local row = rows[i]
  if row then return row end
  row = CreateFrame("Button", nil, body)
  row:SetWidth(LIST_W - 2)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  UI.RowStripe(row)
  UI.RowHighlight(row)
  -- heading parts
  row.groupBg = row:CreateTexture(nil, "BACKGROUND")
  row.groupBg:SetAllPoints()
  row.groupBg:SetColorTexture(unpack(S.header))
  row.fold = row:CreateTexture(nil, "ARTWORK")
  row.fold:SetSize(12, 12)
  row.fold:SetPoint("LEFT", 10, 0)
  row.groupName = UI.Text(row, 12, S.gold)
  row.groupName:SetPoint("LEFT", 28, 0)
  row.groupHint = UI.Text(row, 11, S.dim)
  row.groupHint:SetPoint("LEFT", row.groupName, "RIGHT", 10, 0)
  row.groupCount = UI.Text(row, 11, S.dim, "RIGHT")
  row.groupCount:SetPoint("RIGHT", -16, 0)
  -- item parts: whether it's in your loadout (a round button where you bring one of
  -- a slot, a tick box where it's on its own), then the item
  row.pick = CreateFrame("Button", nil, row, "BackdropTemplate")
  row.pick:SetSize(14, 14)
  row.pick:SetPoint("LEFT", 9, 0)
  UI.Flat(row.pick, S.sunk, S.edge)
  row.pick.tick = row.pick:CreateTexture(nil, "OVERLAY")
  row.pick.tick:SetSize(18, 18)
  row.pick.tick:SetPoint("CENTER", 1, 1)
  row.pick.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  row.pick.tick:SetVertexColor(S.gold[1], S.gold[2], S.gold[3])
  row.pick.dot = row.pick:CreateTexture(nil, "OVERLAY")
  row.pick.dot:SetSize(6, 6)
  row.pick.dot:SetPoint("CENTER")
  row.pick.dot:SetColorTexture(S.gold[1], S.gold[2], S.gold[3], 1)
  row.pick:SetScript("OnClick", function(self) local r = self:GetParent() if r.onPick then r.onPick(r) end end)
  row.onPick = function(r)
    local en = r.entry
    if not en or en.hidden then return end
    local pk = picksOf(shown.listKey)
    if en.set then pk["set:" .. en.set] = (not en.selected) and en.key or false
    else pk[en.key] = not en.selected end
    refresh()
  end
  row.pick:SetScript("OnEnter", function(self)
    local e = self:GetParent().entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.hidden and "Hidden" or (e.set and "One of these" or "In your loadout"), 1, 1, 1)
    if e.hidden then
      GameTooltip:AddLine("Right-click the row to bring it back.", S.dim[1], S.dim[2], S.dim[3], true)
    elseif e.set then
      -- a whole heading (one flask, one food) has its own hint; a set inside Elixirs doesn't stack with itself
      local why = e.set == e.groupName and (HINT[e.groupName] or "one at a time") or "these don't stack with each other"
      GameTooltip:AddLine(("You bring one: %s. Click the picked one again for none."):format(why), S.dim[1], S.dim[2], S.dim[3], true)
    else
      GameTooltip:AddLine("Counted in your stock and shopping list when ticked.", S.dim[1], S.dim[2], S.dim[3], true)
    end
    GameTooltip:Show()
  end)
  row.pick:SetScript("OnLeave", GameTooltip_Hide)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(S.ICON, S.ICON)
  row.icon:SetPoint("LEFT", 30, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = UI.Text(row, 12, S.text)
  row.name:SetPoint("TOPLEFT", 64, -4)
  row.name:SetWidth(COL_HAVE - 64 - 76)
  row.name:SetWordWrap(false)
  row.effect = UI.Text(row, 11, S.dim)
  row.effect:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
  row.effect:SetWidth(COL_HAVE - 64 - 76)
  row.effect:SetWordWrap(false)
  row.have = UI.Text(row, 12, S.text, "RIGHT")
  row.have:SetPoint("RIGHT", row, "LEFT", COL_HAVE, 0)
  row.make = UI.Text(row, 12, S.text, "RIGHT")
  row.make:SetPoint("RIGHT", row, "LEFT", COL_CRAFT, 0)
  row.price = UI.Text(row, 12, S.text, "RIGHT")
  row.price:SetPoint("RIGHT", row, "LEFT", COL_BUY, 0)
  row:SetScript("OnMouseWheel", onWheel)
  row:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item)
    local en = self.entry
    if en and en.key == "lad:bandage" then
      GameTooltip:AddLine(("Chosen by your First Aid skill (%d), not your level."):format(NW.ProfSkill("firstaid") or 0), S.dim[1], S.dim[2], S.dim[3], true)
    end
    -- leveling: what this kind upgrades to, and when
    local up = listMode() == "level" and upgradeOf[self.item]
    if up then
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine("Next", ("%s at %s%d"):format((itemName(up[1])), up[3] and "First Aid " or "level ", up[2]), S.dim[1], S.dim[2], S.dim[3], 0.58, 0.73, 0.47)
    end
    GameTooltip:AddLine((en and en.hidden) and "Right-click: show it again" or "Right-click: hide it", S.dim[1], S.dim[2], S.dim[3])
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self, button)
    if self.group then
      setFolded(self.group, not folded(self.group))
      refresh()
      return
    end
    if not self.item then return end
    if button == "RightButton" then
      local h = hiddenOf(currentList().key .. (listMode() == "level" and ":level" or ""))
      local key = self.entry and self.entry.key or self.item
      if h[key] or h[self.item] then h[key], h[self.item] = nil, nil else h[key] = true end
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
  return row
end

-- Would you make this one rather than buy it?
local function makes(e)
  return e.make and e.m.known and (not e.price or e.make < e.price)
end

------------------------------------------------------------------------
-- Status bar: what's short, what it costs, and the Auctionator search
------------------------------------------------------------------------
local status = CreateFrame("Frame", nil, page, "BackdropTemplate")
status:SetPoint("BOTTOMLEFT", PAD, PAD)
status:SetPoint("BOTTOMRIGHT", -PAD, PAD)
status:SetHeight(STATUS_H)
UI.Flat(status, S.header, S.edge)
local total = UI.Text(status, 12, S.text)
total:SetPoint("LEFT", 12, 0)
total:SetWidth(540)
total:SetWordWrap(false)
local showHidden = false
local hiddenCheck = UI.Check(status, "Show hidden", function() return showHidden end, function(v)
  showHidden = v
  refresh()
end)
hiddenCheck:SetPoint("LEFT", status, "LEFT", 566, 0)
local hint = UI.Text(status, 11, S.dim)
hint:SetPoint("LEFT", status, "LEFT", 566, 0)
hint:SetText("") -- (right-click to hide: in each row's tooltip)
hint:Hide()

-- Everything you're short of, the cheap way: materials for what you'd make,
-- the item itself for the rest
-- What you'd actually buy to restock: for what you'd craft, its materials less what's in your
-- bags (a material that's also on your list only counts the bags beyond its own target); for
-- the rest, the item itself. Shared materials add up once. Returns the list (with the auction
-- house part), the known cost, and how many have no price (never counted as zero).
function page.shopping()
  local want, order, direct = {}, {}, {}
  local function add(id, n, isDirect)
    if n <= 0 then return end
    if not want[id] then want[id] = 0 order[#order + 1] = id end
    want[id] = want[id] + n
    if isDirect then direct[id] = (direct[id] or 0) + n end
  end
  for _, e in ipairs(shown) do
    if e.id and e.selected and not e.hidden and e.short > 0 then
      if makes(e) then
        local crafts = math.ceil(e.short / (e.m.r.yield or 1))
        for _, re in ipairs(e.m.r.reagents) do add(re[1], re[2] * crafts) end
      else
        add(e.id, e.short, true)
      end
    end
  end
  local out = { ah = {}, cost = 0, unknown = 0 }
  for _, id in ipairs(order) do
    -- bags: a listed consumable's own shortage already counts them; for materials, what's spare
    local e = shown.byId[id]
    local bags = NW.ItemCount(id) or 0
    -- (its own bags only: alternatives that fill its slot aren't spare material)
    local spare = (e and e.selected) and math.max(0, e.have - e.need) or bags
    local asMat = want[id] - (direct[id] or 0)
    local buy = (direct[id] or 0) + math.max(0, asMat - spare)
    if buy > 0 then
      local p, src = NW.Price(id)
      if p and src ~= "est" then out.cost = out.cost + p * buy else out.unknown = out.unknown + 1 end
      local n, ok = itemName(id)
      if ok and src ~= "vendor" then out.ah[#out.ah + 1] = { n, buy } end
    end
  end
  return out
end
local searchBtn = UI.Button(status, "Search what's short in Auctionator", 270, function()
  NW.SearchAH(page.shopping().ah)
end, 24, "primary")
if searchBtn.SetMotionScriptsWhileDisabled then searchBtn:SetMotionScriptsWhileDisabled(true) end
UI.Tip(searchBtn, "Search what's short", function()
  if not (NW.HasAuctionator and NW.HasAuctionator()) then return "Needs Auctionator." end
  if not (NW.AHOpen and NW.AHOpen()) then return "Open the auction house first. Materials for what you'd craft (less your bags), the item for the rest." end
  return "Materials for what you'd craft (less what's in your bags), the item itself for the rest."
end)
searchBtn:SetPoint("RIGHT", -4, 0)

------------------------------------------------------------------------
-- Details: the selected consumable
------------------------------------------------------------------------
local function money(c) return NW.Money(c, "mid") end
local det = UI.Section(page, DET_W, PANEL_H, "Details")
det:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", GAP, 0)
local IN = 12
local dIcon = det:CreateTexture(nil, "ARTWORK")
dIcon:SetSize(40, 40)
dIcon:SetPoint("TOPLEFT", IN, -HEAD_H - 12)
dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local dIconEdge = det:CreateTexture(nil, "BORDER")
dIconEdge:SetPoint("TOPLEFT", dIcon, -1, 1)
dIconEdge:SetPoint("BOTTOMRIGHT", dIcon, 1, -1)
dIconEdge:SetColorTexture(unpack(S.edge))
-- the whole item, the game's own tooltip, on its icon
local dIconHit = CreateFrame("Frame", nil, det)
dIconHit:SetAllPoints(dIcon)
dIconHit:EnableMouse(true)
dIconHit:SetScript("OnEnter", function(self)
  if not selectedItem then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetItemByID(selectedItem)
  GameTooltip:Show()
end)
dIconHit:SetScript("OnLeave", GameTooltip_Hide)
local dName = UI.Text(det, 14, S.text)
dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 10, -2)
dName:SetPoint("RIGHT", -IN, 0)
dName:SetWordWrap(false)
local dType = UI.Text(det, 11, S.dim)
dType:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -4)
dType:SetPoint("RIGHT", -IN, 0)
dType:SetWordWrap(false)
-- what it does, short (the game's full text is on the icon), and how long it lasts
local dEffect = UI.Text(det, 11, S.text)
dEffect:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -10)
dEffect:SetWidth(DET_W - IN * 2)
dEffect:SetJustifyV("TOP")
if dEffect.SetMaxLines then dEffect:SetMaxLines(4) end
dEffect:SetSpacing(2)
-- owned / target / short, and the target by hand
local dStock = UI.Text(det, 12, S.text)
dStock:SetPoint("TOPLEFT", dEffect, "BOTTOMLEFT", 0, -10)
dStock:SetWidth(DET_W - IN * 2 - 116) -- (stops short of the target buttons)
dStock:SetWordWrap(false)
local qtyBtns = CreateFrame("Frame", nil, det)
qtyBtns:SetSize(110, 20)
qtyBtns:SetPoint("RIGHT", det, "RIGHT", -IN, 0)
qtyBtns:SetPoint("TOP", dStock, "TOP", 0, 3)
local function setQty(delta)
  local e = selectedItem and shown.byId[selectedItem]
  if not (e and e.selected) then return end
  local q = qtyOf(shown.listKey)
  local n = math.max(0, (q[e.key] or e.want) + delta)
  q[e.key] = n
  refresh()
end
local qMinus = UI.Button(qtyBtns, "-", 22, function() setQty(-1) end, 20)
local qPlus = UI.Button(qtyBtns, "+", 22, function() setQty(1) end, 20)
local qAuto = UI.Button(qtyBtns, "Auto", 50, function()
  local e = selectedItem and shown.byId[selectedItem]
  if e then local q = qtyOf(shown.listKey) q[e.key], q[e.id] = nil, nil refresh() end
end, 20)
qAuto:SetPoint("RIGHT")
qPlus:SetPoint("RIGHT", qAuto, "LEFT", -4, 0)
qMinus:SetPoint("RIGHT", qPlus, "LEFT", -4, 0)
UI.Tip(qMinus, "Target", "One fewer to keep. Your number stays until you click Auto.")
UI.Tip(qPlus, "Target", "One more to keep. Your number stays until you click Auto.")
UI.Tip(qAuto, "Auto", function()
  local e = selectedItem and shown.byId[selectedItem]
  return ("Back to the estimate for your Stock setting%s."):format(e and (" (" .. e.auto .. ")") or "")
end)

-- Craft and Buy side by side; the cheaper one gets the gold edge
local CMP_W = math.floor((DET_W - IN * 2 - 8) / 2)
local function cmpBox(label)
  local b = CreateFrame("Frame", nil, det, "BackdropTemplate")
  b:SetSize(CMP_W, 50)
  UI.Flat(b, S.sunk, S.edge)
  b.label = UI.Text(b, 11, S.dim)
  b.label:SetPoint("TOPLEFT", 8, -7)
  b.label:SetText(label)
  b.tag = UI.Text(b, 10, S.good, "RIGHT")
  b.tag:SetPoint("TOPRIGHT", -8, -8)
  b.value = UI.Text(b, 14, S.text)
  b.value:SetPoint("BOTTOMLEFT", 8, 8)
  b.value:SetWordWrap(false)
  b.src = UI.Text(b, 10, S.dim, "RIGHT")
  b.src:SetWidth(CMP_W - 80)
  b.src:SetWordWrap(false)
  b.src:SetPoint("BOTTOMRIGHT", -8, 10)
  function b:Set(text, best, dim)
    self.value:SetText(text)
    self.value:SetTextColor(unpack(dim and S.dim or best and S.good or S.text))
    self.tag:SetText(best and "Cheapest" or "")
    self:SetBackdropBorderColor(unpack(best and S.gold or S.edge))
  end
  b:EnableMouse(true)
  return b
end
local cmpCraft = cmpBox("Craft")
cmpCraft:SetPoint("TOPLEFT", dStock, "BOTTOMLEFT", 0, -10)
local cmpBuy = cmpBox("Buy")
cmpBuy:SetPoint("LEFT", cmpCraft, "RIGHT", 8, 0)
UI.Tip(cmpCraft, "Craft", function()
  return "One, at today's material prices (what the materials are worth)."
    .. (cmpCraft.pay and ("\nTo pay for your shortage: %s, after the materials in your bags."):format(cmpCraft.pay) or "")
end)
UI.Tip(cmpBuy, "Buy", "One, at the auction house or a vendor, whichever is cheaper.")
local dSave = UI.Text(det, 11, S.dim)
dSave:SetPoint("TOPLEFT", cmpCraft, "BOTTOMLEFT", 0, -7)
dSave:SetWidth(DET_W - IN * 2)
dSave:SetWordWrap(false)

local dRecipe = UI.Text(det, 11, S.text)
dRecipe:SetPoint("TOPLEFT", dSave, "BOTTOMLEFT", 0, -10)
dRecipe:SetWidth(DET_W - IN * 2)
dRecipe:SetJustifyV("TOP")
if dRecipe.SetMaxLines then dRecipe:SetMaxLines(2) end
dRecipe:SetSpacing(2)

-- Materials: the professions' reagent icons (one craft's count; edge red where you're short),
-- each one into the Material Finder, Shift-click to search or link
local reagentTip = {}
function reagentTip.tip(icon)
  local c = icon.ctx
  GameTooltip:SetOwner(icon, "ANCHOR_LEFT")
  if not pcall(GameTooltip.SetItemByID, GameTooltip, icon.id) then GameTooltip:SetText((itemName(icon.id)), 1, 1, 1) end
  GameTooltip:AddLine(" ")
  local d = S.dim
  GameTooltip:AddDoubleLine("Per craft", icon.qty, d[1], d[2], d[3], 1, 1, 1)
  if c.need then GameTooltip:AddDoubleLine("Have / need", ("%d / %d"):format(c.have or 0, c.need), d[1], d[2], d[3], 1, 1, 1) end
  local p, src = NW.Price(icon.id)
  GameTooltip:AddDoubleLine("Price", p and ((src == "vendor" and "Vendor " or "") .. money(p)) or "no price", d[1], d[2], d[3], 1, 1, 1)
  local inFinder = NW.Mat and NW.Mat.Get and NW.Mat.Get(icon.id)
  GameTooltip:AddDoubleLine("Click", inFinder and "where to get it, in Material Finder" or "not in Material Finder", d[1], d[2], d[3], 1, 1, 1)
  GameTooltip:AddDoubleLine("Shift-click", NW.AHOpen and NW.AHOpen() and "search the auction house" or "link in chat", d[1], d[2], d[3], 1, 1, 1)
  GameTooltip:Show()
end
function reagentTip.click(icon)
  local id = icon.id
  if not id then return end
  if IsShiftKeyDown() then
    local n, ok = itemName(id)
    if NW.AHOpen() and ok then NW.SearchAH({ { n, math.max(1, (icon.ctx.need or 1) - (icon.ctx.have or 0)) } }) else NW.ChatLink(id, nil, true) end
    return
  end
  if NW.FindMaterial then NW.FindMaterial(id, "consumes", icon.ctx.need) end
end
local matStrip = UI.ReagentStrip(det, reagentTip, 26)
matStrip:SetPoint("TOPLEFT", dRecipe, "BOTTOMLEFT", 0, -8)
local dMats = UI.Text(det, 11, S.dim)
dMats:SetPoint("TOPLEFT", matStrip, "BOTTOMLEFT", 0, -4)
dMats:SetWidth(DET_W - IN * 2)
dMats:SetWordWrap(false)

-- Getting it, right under Craft and Buy: its materials at the auction house, the item itself
-- at the auction house, and its other sources in the Material Finder
local BTN_W = math.floor((DET_W - IN * 2 - 12) / 3)
local matsBtn = UI.Button(det, "Materials", BTN_W, function()
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
end, 22)
matsBtn:SetPoint("TOPLEFT", cmpCraft, "BOTTOMLEFT", 0, -6)
UI.Tip(matsBtn, "Materials", function()
  if not (selectedItem and NW.RecipeFor(selectedItem)) then return "No known recipe for it, so no materials to search." end
  if not (NW.AHOpen and NW.AHOpen()) then return "Searches the auction house for the materials you're short of. Open the auction house first." end
  return "Searches the auction house for the materials you're short of (vendor materials left out)."
end)
local ahBtn = UI.Button(det, "Search AH", BTN_W, function()
  local n, ok = selectedItem and itemName(selectedItem)
  local e = selectedItem and shown.byId[selectedItem]
  if ok then NW.SearchAH({ { n, (e and e.short > 0) and e.short or 1 } }) end
end, 22)
ahBtn:SetPoint("LEFT", matsBtn, "RIGHT", 6, 0)
UI.Tip(ahBtn, "Search AH", function()
  if not (NW.AHOpen and NW.AHOpen()) then return "Searches the auction house for the item itself. Open the auction house first." end
  return "Searches the auction house for the item itself."
end)
-- other ways to get it (vendors, drops, gathering), in the Material Finder
local findBtn
findBtn = UI.Button(det, "Sources", BTN_W, function()
  if findBtn.id then
    local e = shown.byId[findBtn.id]
    NW.FindMaterial(findBtn.id, "consumes", e and e.short > 0 and e.short or nil)
  end
end, 22)
findBtn:SetPoint("LEFT", ahBtn, "RIGHT", 6, 0)
UI.Tip(findBtn, "Sources", function()
  if not findBtn.id then return "The Material Finder doesn't list this one. A missing recipe or price doesn't mean it can't be had." end
  return "Vendors, drops and other sources in the Material Finder."
end)
for _, bb in ipairs({ matsBtn, ahBtn, findBtn }) do if bb.SetMotionScriptsWhileDisabled then bb:SetMotionScriptsWhileDisabled(true) end end
-- when it has no price: the next one of its kind that does (a suggestion; the list keeps the stronger one)
local dAlt = CreateFrame("Button", nil, det)
dAlt:SetSize(DET_W - IN * 2, 1)
dAlt:SetPoint("TOPLEFT", matsBtn, "BOTTOMLEFT", 0, -6)
dAlt.icon = dAlt:CreateTexture(nil, "ARTWORK")
dAlt.icon:SetSize(16, 16)
dAlt.icon:SetPoint("LEFT")
dAlt.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
dAlt.text = UI.Text(dAlt, 11, S.dim)
dAlt.text:SetPoint("LEFT", 22, 0)
dAlt.text:SetPoint("RIGHT")
dAlt.text:SetWordWrap(false)
dAlt:SetScript("OnEnter", function(self)
  if not self.id then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetItemByID(self.id)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("A priced one of the same kind, if this one is hard to find. Click: where to get it.", S.dim[1], S.dim[2], S.dim[3], true)
  GameTooltip:Show()
end)
dAlt:SetScript("OnLeave", GameTooltip_Hide)
dAlt:SetScript("OnClick", function(self)
  if not self.id then return end
  if not (NW.FindMaterial and NW.FindMaterial(self.id, "consumes")) then
    local n, ok = itemName(self.id)
    if ok and NW.AHOpen() then NW.SearchAH({ { n, 1 } }) end
  end
end)
dSave:ClearAllPoints()
dSave:SetPoint("TOPLEFT", dAlt, "BOTTOMLEFT", 0, -6)

local dEmpty = UI.Text(det, 12, S.dim, "CENTER")
dEmpty:SetPoint("CENTER")
dEmpty:SetWidth(DET_W - 40)

local detailParts = { dIcon, dIconEdge, dIconHit, dName, dType, dEffect, dStock, qtyBtns, cmpCraft, cmpBuy, dSave, dRecipe, matStrip, dMats,
  matsBtn, ahBtn, findBtn, dAlt }


local function drawDetail()
  local id = selectedItem
  local hasItem = id ~= nil
  for _, p in ipairs(detailParts) do p:SetShown(hasItem) end
  dEmpty:SetShown(not hasItem)
  if not hasItem then
    det.header.text:SetText("Details")
    dEmpty:SetText(#shown > 0 and "Everything here is hidden." or "Nothing on this list.")
    return
  end
  local e = shown.byId[id]
  det.header.text:SetText(e and e.groupName or "Details")
  dIcon:SetTexture(NW.ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
  local name, loaded = itemName(id)
  local q, iType, iSub
  if loaded then
    local info = { (C_Item and C_Item.GetItemInfo or GetItemInfo)(id) }
    q, iType, iSub = info[3], info[6], info[7]
  end
  local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  dName:SetText(name)
  if qc then dName:SetTextColor(qc.r, qc.g, qc.b) else dName:SetTextColor(unpack(S.text)) end
  -- its category and tier (the game's own subtype is often just "Other" for these)
  if e then
    dType:SetText(e.groupName .. (e.tier ~= "core" and not OPTIONAL[e.groupName] and ("  ·  " .. e.tier) or ""))
  else
    local sub = iSub and iSub ~= iType and iSub or iType
    dType:SetText((sub and sub ~= "Other") and sub or "")
  end

  -- what it does: the list's short line, else the game's first sentence; how long, from the game's text
  local fx = e and e.effect and e.effect:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local use = useText(id)
  local short = (fx and fx ~= "") and fx or (use and (use:match("^(.-%.)%s") or use)) or ""
  local mins = minutesOf(id)
  local lines = { short }
  if mins then lines[#lines + 1] = H.dim .. "Lasts " .. ((mins >= 60 and mins % 60 == 0) and (("%d hr"):format(mins / 60)) or (("%d min"):format(mins))) .. "|r" end
  local up = listMode() == "level" and upgradeOf[id]
  if up then lines[#lines + 1] = ("%sNext|r %s at %s%d"):format(H.good, (itemName(up[1])), up[3] and "First Aid " or "level ", up[2]) end
  dEffect:SetText(table.concat(lines, "\n"))

  -- stock: owned (what fills the slot), target, and what's short
  local shortN = e and e.short or 0
  if e and e.selected then
    local have = e.setHave or e.have
    local col = have < e.need and H.bad or H.good
    dStock:SetText(("%sOwned|r %s%d|r   %sTarget|r %d%s   %s"):format(H.dim, col, have, H.dim, e.need, e.manual and "*" or "",
      shortN > 0 and (H.bad .. shortN .. " short|r") or (H.good .. "stocked|r")))
  else
    dStock:SetText(("%sOwned|r %d   %snot in your loadout|r"):format(H.dim, e and e.have or (NW.ItemCount(id) or 0), H.dim))
  end
  qtyBtns:SetShown(e ~= nil and e.selected == true)
  qAuto:SetEnabled(e ~= nil and e.manual == true)

  -- craft or buy
  local vendor, ah = NW.PriceParts(id)
  local m = makeInfo(id)
  local craft = m and m.cost
  local buy, buySrc = nil, nil
  if ah and (not vendor or ah <= vendor) then buy, buySrc = ah, "Auction House" elseif vendor then buy, buySrc = vendor, "Vendor" end
  local canMake = m and m.skill and m.known
  local craftBest = craft and canMake and (not buy or craft < buy)
  -- only a real choice gets the outline: buying beats a craft you could do
  local buyBest = buy and craft and canMake and buy <= craft
  -- exact (gold, silver, copper as needed) so the two never read the same while one is cheaper
  local exact = function(c)
    c = math.floor((c or 0) + 0.5)
    local g, s2, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t" end
    if s2 > 0 then parts[#parts + 1] = s2 .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t" end
    if cp > 0 or #parts == 0 then parts[#parts + 1] = cp .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t" end
    return table.concat(parts, " ")
  end
  if craft then
    cmpCraft:Set(exact(craft), craftBest, not canMake)
  else
    cmpCraft:Set(m and "No price" or "No known recipe", false, true)
  end
  cmpBuy.src:SetText(buySrc == "Vendor" and "Vendor" or buySrc and "AH" or "")
  cmpCraft.src:SetText("")
  cmpCraft.pay = nil
  if buy then cmpBuy:Set(exact(buy), buyBest) else cmpBuy:Set("No AH price", false, true) end
  -- no price: a priced one of the same kind (the level list's ladder, or the raid list's own alternatives)
  local alt
  if not buy then
    if listMode() == "level" then alt = altOf[id]
    elseif e then
      for _, g in ipairs(currentList().groups) do
        if g[1] == e.groupName then
          for _, c in ipairs(g[2]) do
            local pc, sc = NW.Price(c[1])
            local hid = hiddenOf(currentList().key)[c[1]]
            if not alt and not hid and c[1] ~= id and pc and sc ~= "est" and not (NW.NOT_YET and NW.NOT_YET[c[1]]) and (not e.set or c[4] == e.set or PICK_ONE[g[1]]) then alt = c[1] end
          end
        end
      end
    end
  end
  dAlt.id = alt
  dAlt:SetHeight(alt and 20 or 1)
  dAlt.icon:SetShown(alt ~= nil)
  if alt then
    dAlt.icon:SetTexture(NW.ItemIcon(alt) or "Interface\\Icons\\INV_Misc_QuestionMark")
    dAlt.text:SetText(("%sOr|r %s  %s"):format(H.dim, (itemName(alt)), exact((NW.Price(alt)))))
  else
    dAlt.text:SetText("")
  end
  -- where else it comes from: the Material Finder, when it knows the item
  findBtn.id = (NW.Mat and NW.Mat.Get and NW.Mat.Get(id)) and id or nil
  if craft and buy and canMake then
    local diff = math.abs(buy - craft)
    local how = craft < buy and "Crafting" or "Buying"
    dSave:SetText(diff > 0 and ("%s saves %s each%s"):format(how, exact(diff),
      shortN > 0 and ("  ·  %s for %d"):format(exact(diff * shortN), shortN) or "") or "Same either way")
  elseif craft and buy and m.skill and not m.known then
    dSave:SetText("Learn the recipe to craft it")
  elseif m and not m.skill then
    dSave:SetText(("Needs %s"):format(NW.PROF_BY_KEY[m.key] and NW.PROF_BY_KEY[m.key].name or "the profession"))
  else
    dSave:SetText("")
  end

  -- recipe and materials
  local r, key = NW.RecipeFor(id)
  matStrip:Begin()
  if not r then
    dRecipe:SetText("")
    matStrip:Finish(DET_W - IN * 2)
    dMats:SetText("")
    return
  end
  local prof = NW.PROF_BY_KEY[key]
  local req = r.orange or r.yellow
  local line = ("%s%s|r%s"):format(H.gold, prof and prof.name or "", req and req > 0 and (" " .. req) or "")
  if m.skill then
    if m.known then
      line = line .. "  " .. H.good .. "Recipe known|r"
    elseif not m.scanned then
      line = line .. "  " .. H.dim .. "open it once to check recipes|r"
    else
      line = line .. "  " .. H.bad .. "Recipe not known|r\n" .. H.dim .. (NW.RecipeSourceText(key, r) or "") .. "|r"
    end
  else
    line = line .. "  " .. H.dim .. "not your profession|r"
  end
  if (r.yield or 1) > 1 then line = line .. ("  %s· makes %d|r"):format(H.dim, r.yield) end
  dRecipe:SetText(line)
  -- materials for the shortage (or one craft when you're stocked), with what you'd still pay
  local crafts = math.max(1, math.ceil(math.max(1, shortN) / (r.yield or 1)))
  local pay, payUnknown = 0, false
  for _, re in ipairs(r.reagents) do
    local need = re[2] * crafts
    local have = NW.ItemCount(re[1]) or 0
    local ic = matStrip:Add(re[1], re[2], have >= need and "ok" or "short")
    ic.ctx.need, ic.ctx.have = need, have
    local p = NW.Price(re[1])
    if have < need then
      if p then pay = pay + p * (need - have) else payUnknown = true end
    end
  end
  matStrip:Finish(DET_W - IN * 2)
  if shortN > 0 and craft then
    cmpCraft.pay = (pay > 0 and money(pay) or "nothing") .. (payUnknown and " +?" or "")
    UI.FitText(cmpCraft.src, pay > 0 and ("pay " .. money(pay) .. (payUnknown and "+?" or "")) or (payUnknown and "pay ?" or "in bags"), 10, 8)
  end
  dMats:SetText(("For %d craft%s%s"):format(crafts, crafts == 1 and "" or "s", shortN > 0 and (" · " .. shortN .. " short") or ""))
end

refresh = function()
  if not page:IsShown() then return end
  local list = currentList()
  local mode = listMode()
  local strat = strategy()
  if mode == "level" then list = levelList(list, strat) end
  title:SetText(("Level %d"):format(playerLevel()))
  budget:Refresh()
  actDrop:Refresh()
  specDrop:Refresh()
  stockDrop:Refresh()
  local wantBudget = mode == "budget"
  local hours = math.min(4, st().consumeHours or 0) -- (an old 5-hour setting reads as 4, as the menu shows)
  local hidden = hiddenOf(list.key)
  -- your loadout and hand-set targets belong to this list (raid best and budget differ)
  local listKey = list.key .. (mode == "budget" and ":budget" or "")
  local picks, qty = picksOf(listKey), qtyOf(listKey)
  local nHidden = 0
  for _ in pairs(hidden) do nHidden = nHidden + 1 end
  if nHidden == 0 then showHidden = false end
  wipe(shown)
  shown.byId = {}
  shown.listKey = listKey
  local sum, shortCount, nPicked, nStocked, nUnpriced = 0, 0, 0, 0, 0
  for _, g in ipairs(list.groups) do
    local at = #shown + 1
    local group = { header = g[1], short = 0, n = 0 }
    shown[at] = group
    local perHour = PER_HOUR[g[1]] or 1
    local sets, setOrder = {}, {}
    -- what isn't in the game yet is left out; if that was the whole best
    -- tier of a slot, the budget rows stand in for it
    local notYet = NW.NOT_YET or {}
    local bestLeft = false
    for _, c in ipairs(g[2]) do if c[3] ~= "budget" and not notYet[c[1]] then bestLeft = true end end
    for _, c in ipairs(g[2]) do
      local tier = c[3]
      if not bestLeft then tier = nil end
      if notYet[c[1]] then tier = "none" end
      -- hidden, like picks, follows the kind on the leveling list (an item id from before still counts)
      local key = c[6] and ("lad:" .. c[6]) or c[1]
      local isHidden = (hidden[key] or hidden[c[1]]) and true or false
      if tier ~= "none" and (not tier or (tier == "budget") == (wantBudget and true or false)) and (showHidden or not isHidden) then
        local price, src = NW.Price(c[1])
        if src == "est" then price = nil end
        local have = NW.ItemCount(c[1]) or 0
        local m = makeInfo(c[1])
        -- only what you could make yourself counts as a way to get it
        local make = m and m.skill and m.cost or nil
        -- the estimate: a buff with a stated duration is counted exactly; the rest at a rate an hour
        local auto = hours > 0 and math.max(1, math.ceil((c[5] or perHour) * hours)) or 1
        local lasts = hours > 0 and minutesOf(c[1])
        if lasts then auto = math.max(1, math.ceil(hours * 60 / lasts)) end
        -- your pick and target: by item on raid lists, by kind on the level list (it upgrades as you level)
        local q = qty[key] or qty[c[1]]
        local mine = q or auto
        local e = { id = c[1], key = key, effect = c[2], price = price, have = have, make = make, m = m, auto = auto, manual = q ~= nil,
          need = 0, short = 0, hidden = isHidden, groupName = g[1], tier = c[7] or (mode ~= "level" and RAID_TIER[g[1]]) or "core" }
        e.want = mine
        shown[#shown + 1] = e
        shown.byId[e.id] = e
        -- nice to have: shown with what you carry, never counted unless you tick it
        if OPTIONAL[g[1]] then e.optional = true end
        -- a slot you fill with one of several (one flask, one food, one of a kind of elixir)
        local set = (PICK_ONE[g[1]] and g[1]) or c[4]
        if set then
          e.set = set
          if not sets[set] then sets[set] = {} setOrder[#setOrder + 1] = set end
          table.insert(sets[set], e)
        else
          local p = picks[e.key]
          -- unset: the list's choice (core rows only); Use what I own ticks only what you carry
          if p == nil then p = not e.optional and e.tier == "core" and (strat ~= "own" or have > 0) end
          e.selected = p and not isHidden
        end
      end
    end
    -- each slot: the one you picked (or the list's first), filled by any of them you carry
    for _, set in ipairs(setOrder) do
      local list2 = sets[set]
      local chosen = picks["set:" .. set]
      local lead
      if chosen ~= false then
        for _, e in ipairs(list2) do if not e.hidden and (e.key == chosen or e.id == chosen) then lead = e end end
        if not lead and chosen == nil and strat == "own" then
          -- Use what I own: the one you carry most of
          for _, e in ipairs(list2) do if not e.hidden and e.have > 0 and (not lead or e.have > lead.have) then lead = e end end
        end
        if not lead and not (list2[1] and (list2[1].optional or list2[1].tier ~= "core")) then
          for _, e in ipairs(list2) do if not e.hidden then lead = e break end end
        end
      end
      local carried = 0
      for _, e in ipairs(list2) do if not e.hidden then carried = carried + e.have end end
      for _, e in ipairs(list2) do
        e.selected = e == lead
        e.alt = not e.selected
        if e.selected then e.setHave = carried end
      end
    end
    for k = at + 1, #shown do
      local e = shown[k]
      group.n = group.n + 1
      if e.selected then
        e.need = e.want
        e.short = math.max(0, e.need - (e.setHave or e.have))
        nPicked = nPicked + 1
        if e.short > 0 then
          local cheapest = makes(e) and e.make or e.price
          if not cheapest then nUnpriced = nUnpriced + 1 end
          shortCount = shortCount + 1
          group.short = group.short + 1
        else
          nStocked = nStocked + 1
        end
      end
    end
    if #shown == at then shown[at] = nil end -- nothing on this list for the slot
  end

  -- what the list shows: headings, and the rows of open ones
  wipe(visible)
  local firstItem
  local cur
  for _, e in ipairs(shown) do
    if e.header then
      cur = e
      visible[#visible + 1] = e
    else
      firstItem = firstItem or (not e.hidden and e.id)
      if not folded(cur.header) then visible[#visible + 1] = e end
    end
  end
  -- something is always selected while there's anything to show
  if not (selectedItem and shown.byId[selectedItem]) then selectedItem = firstItem end

  -- the furthest you can scroll and still fill the list
  local hsum, maxOffset, totalH = 0, 0, 0
  for i = #visible, 1, -1 do
    local h = visible[i].header and GROUP_H or ITEM_H
    totalH = totalH + h
    if maxOffset == 0 then
      hsum = hsum + h
      if hsum > BODY_H then maxOffset = i end
    end
  end
  visible.maxOffset = maxOffset
  offset = math.max(0, math.min(offset, maxOffset))

  for _, row in ipairs(rows) do row:Hide() end
  local y, n, stripe = 0, 0, false
  for i = offset + 1, #visible do
    local e = visible[i]
    local h = e.header and GROUP_H or ITEM_H
    if y + h > BODY_H then break end
    n = n + 1
    local row = rowFor(n)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetHeight(h)
    row:Show()
    y = y + h
    local isGroup = e.header ~= nil
    row.groupBg:SetShown(isGroup)
    row.fold:SetShown(isGroup)
    row.groupName:SetShown(isGroup)
    row.groupHint:SetShown(isGroup)
    row.groupCount:SetShown(isGroup)
    row.icon:SetShown(not isGroup)
    row.pick:SetShown(not isGroup)
    row.name:SetShown(not isGroup)
    row.effect:SetShown(not isGroup)
    row.have:SetShown(not isGroup)
    row.make:SetShown(not isGroup)
    row.price:SetShown(not isGroup)
    if isGroup then
      stripe = false
      row.group, row.item, row.entry = e.header, nil, nil
      row:SetAlpha(1)
      row:SetSelected(false)
      row:SetStripe(false)
      local f = folded(e.header)
      row.fold:SetTexture("Interface\\Buttons\\UI-" .. (f and "Plus" or "Minus") .. "Button-Up")
      row.groupName:SetText(e.header)
      row.groupHint:SetText(HINT[e.header] or "")
      row.groupCount:SetText(e.short > 0 and (H.bad .. e.short .. " short|r") or (f and (e.n .. "") or ""))
    else
      stripe = not stripe
      row.group = nil
      row:SetStripe(stripe)
      -- not in your loadout: quieter, but its art stays in colour
      row:SetAlpha(e.hidden and 0.45 or 1)
      row.item, row.short, row.entry = e.id, e.short, e
      row:SetSelected(e.id == selectedItem)
      row.icon:SetTexture(NW.ItemIcon(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.icon:SetAlpha(e.selected and 1 or 0.7)
      row.pick.tick:SetShown(e.selected and not e.set)
      -- one of a slot: a gold dot in the box when picked; on its own: a tick
      row.pick.dot:SetShown(e.set ~= nil and e.selected)
      UI.Flat(row.pick, e.selected and S.select or S.sunk, e.set and S.gold or S.edge)
      if e.set then row.pick:SetBackdropBorderColor(S.gold[1], S.gold[2], S.gold[3], 0.45) end
      row.pick:SetAlpha(e.hidden and 0.4 or 1)
      row.name:SetText(itemName(e.id))
      row.name:SetTextColor(unpack(e.selected and S.text or S.dim))
      -- the first sentence; the whole effect is in the item's tooltip
      local eff = e.effect and e.effect:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or ""
      eff = eff:match("^[^\n]*") or eff
      eff = eff:match("^(.-%.)%s") or eff
      -- its tier, where the heading doesn't already say it
      if e.tier ~= "core" and not OPTIONAL[e.groupName] then eff = eff .. "  " .. H.dim .. "· " .. e.tier .. "|r" end
      UI.FitText(row.effect, eff, 11, 10)
      -- green only where it's the cheaper way; grey where you don't know the recipe
      local cheaperMake = e.make and e.m.known and (not e.price or e.make < e.price)
      local mk = ""
      if e.make then
        local col = (not e.m.known and H.dim) or (cheaperMake and H.good) or H.text
        mk = col .. NW.Money(e.make, "gs"):gsub("|r", "|r" .. col) .. "|r"
      end
      row.make:SetText(mk)
      local buyCol = (e.price and e.make and e.m.known and not cheaperMake) and H.good or H.text
      row.price:SetText(e.price and (buyCol .. NW.Money(e.price, "gs"):gsub("|r", "|r" .. buyCol) .. "|r") or (H.dim .. "–|r"))
      -- owned / target for what you bring (red below target); just what you own for the rest
      local have = e.selected and e.setHave or e.have
      if e.selected then
        local col = have < e.need and H.bad or H.good
        row.have:SetText(("%s%d|r%s / %d%s|r"):format(col, have, H.dim, e.need, e.manual and "*" or ""))
      else
        row.have:SetText(have > 0 and ("%d"):format(have) or (H.dim .. "0|r"))
      end
    end
  end
  emptyText:SetShown(#visible == 0)
  emptyText:SetText("Nothing on this list.")

  thumb:SetShown(maxOffset > 0)
  if maxOffset > 0 then
    local th = math.max(20, BODY_H * BODY_H / totalH)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", -2, -((BODY_H - th) * offset / maxOffset))
  end

  hiddenCheck:SetShown(nHidden > 0)
  hiddenCheck:Refresh()
  -- the cost and unknown prices: what you'd actually buy (materials in your bags taken off)
  local shop = page.shopping()
  sum, nUnpriced = shop.cost, shop.unknown
  -- your loadout in a line: what you bring, what's ready, what's short and its known cost
  local parts = { ("%d selected"):format(nPicked) }
  if nStocked > 0 then parts[#parts + 1] = ("%s%d stocked|r"):format(H.good, nStocked) end
  if shortCount > 0 then parts[#parts + 1] = ("%s%d below target|r"):format(H.bad, shortCount) end
  if sum > 0 then parts[#parts + 1] = "~" .. money(sum) .. (nUnpriced > 0 and (H.bad .. "+?|r") or "") .. " to restock" end
  if nUnpriced > 0 then parts[#parts + 1] = ("%s%d unknown price%s|r"):format(H.dim, nUnpriced, nUnpriced == 1 and "" or "s") end
  if nPicked > 0 and shortCount == 0 then parts[#parts + 1] = H.good .. "all stocked|r" end
  UI.FitText(total, table.concat(parts, ("  %s·|r  "):format(H.dim)), 12, 10)
  -- (Auctionator searches only while the auction house is open)
  searchBtn:SetEnabled(shortCount > 0 and #shop.ah > 0 and NW.AHOpen and NW.AHOpen() and NW.HasAuctionator and NW.HasAuctionator() or false)
  drawDetail()
  if selectedItem then
    matsBtn:SetEnabled(NW.RecipeFor(selectedItem) ~= nil and (NW.AHOpen and NW.AHOpen() or false))
    local _, ok = itemName(selectedItem)
    ahBtn:SetEnabled(ok and NW.AHOpen and NW.AHOpen() or false)
    findBtn:SetEnabled(findBtn.id ~= nil)
  end
end
