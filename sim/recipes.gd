## The workbench recipes and the cooking table as data: what goes in, what comes out, and
## what unlocks it.
##
## A workbench recipe's `inputs` maps item kinds to counts consumed from the stash, then the
## pack. `skill` and `level` are the skill level required; `upgrade` is an outpost upgrade id
## that must be built first, or "" when none is needed. `xp` is experience granted to `skill` per craft.
## `tier` is the metal tier the recipe works; the simulation refuses any recipe above its
## smithing cap (bronze until the Bloomery raises it to iron, or the blast furnace to steel).
## Fur works no metal: its tier is "", which ranks below every tier, so the cap never refuses it;
## nor the top-set pieces (#184), which have no tier and need the Ring-three gate hoist.
##
## A cooking entry is keyed by the raw item and gives the cooked `output`, the cooking
## `level` required, the `xp` per success, and the `burn` percent at that level, which falls
## by Sim.BURN_DROP_PER_LEVEL for every level above it. Engine-free.
class_name RecipeTable
extends RefCounted

const RECIPES := {
	"wooden_club": {
		"label": "Wooden club", "inputs": {"logs": 4}, "output": {"item": "wooden_club", "count": 1},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "", "xp": 10, "tier": ItemTable.TIER_WOODEN,
	},
	"wooden_axe": {
		"label": "Wooden axe", "inputs": {"logs": 3}, "output": {"item": "wooden_axe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "", "xp": 10, "tier": ItemTable.TIER_WOODEN,
	},
	"wooden_pickaxe": {
		"label": "Wooden pickaxe", "inputs": {"logs": 3}, "output": {"item": "wooden_pickaxe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "", "xp": 10, "tier": ItemTable.TIER_WOODEN,
	},
	"fishing_rod": {
		"label": "Fishing rod", "inputs": {"logs": 3}, "output": {"item": "fishing_rod", "count": 1},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "", "xp": 10, "tier": ItemTable.TIER_WOODEN,
	},
	# One ice crystal refines into a pouch of frost shards, a staff's charges.
	"frost_shards": {
		"label": "Frost shards", "inputs": {"ice_crystal": 1}, "output": {"item": "frost_shards", "count": 10},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "", "xp": 8, "tier": ItemTable.TIER_WOODEN,
	},
	"wooden_staff": {
		"label": "Wooden staff", "inputs": {"logs": 3, "ice_crystal": 1}, "output": {"item": "wooden_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "", "xp": 12, "tier": ItemTable.TIER_WOODEN,
	},
	# Armour comes in three pieces; a tier's full set costs what its single armour did (#38).
	"wooden_helm": {
		"label": "Wooden helm", "inputs": {"logs": 2}, "output": {"item": "wooden_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "", "xp": 5, "tier": ItemTable.TIER_WOODEN,
	},
	"wooden_body": {
		"label": "Wooden body", "inputs": {"logs": 4}, "output": {"item": "wooden_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "", "xp": 10, "tier": ItemTable.TIER_WOODEN,
	},
	"wooden_legs": {
		"label": "Wooden legs", "inputs": {"logs": 2}, "output": {"item": "wooden_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "", "xp": 5, "tier": ItemTable.TIER_WOODEN,
	},
	"bronze_bar": {
		"label": "Bronze bar", "inputs": {"copper_ore": 1, "tin_ore": 1}, "output": {"item": "bronze_bar", "count": 1},
		"skill": SkillTable.SMITHING, "level": 1, "upgrade": "forge", "xp": 10, "tier": ItemTable.TIER_BRONZE,
	},
	"arrows": {
		"label": "Arrows", "inputs": {"logs": 2, "bronze_bar": 1}, "output": {"item": "arrows", "count": 25},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "forge", "xp": 10, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_axe": {
		"label": "Bronze axe", "inputs": {"bronze_bar": 1, "logs": 2}, "output": {"item": "bronze_axe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "forge", "xp": 15, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_pickaxe": {
		"label": "Bronze pickaxe", "inputs": {"bronze_bar": 1, "logs": 2}, "output": {"item": "bronze_pickaxe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "forge", "xp": 15, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_sword": {
		"label": "Bronze sword", "inputs": {"bronze_bar": 2, "logs": 1}, "output": {"item": "bronze_sword", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "forge", "xp": 25, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_bow": {
		"label": "Bronze bow", "inputs": {"bronze_bar": 2, "logs": 3}, "output": {"item": "bronze_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "forge", "xp": 25, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_staff": {
		"label": "Bronze staff", "inputs": {"bronze_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "bronze_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "forge", "xp": 25, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_helm": {
		"label": "Bronze helm", "inputs": {"bronze_bar": 1}, "output": {"item": "bronze_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 10, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_body": {
		"label": "Bronze body", "inputs": {"bronze_bar": 2}, "output": {"item": "bronze_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 20, "tier": ItemTable.TIER_BRONZE,
	},
	"bronze_legs": {
		"label": "Bronze legs", "inputs": {"bronze_bar": 1}, "output": {"item": "bronze_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 10, "tier": ItemTable.TIER_BRONZE,
	},
	# Fur: wolf pelts, with the bronze armour once the Armoury is built.
	"fur_hood": {
		"label": "Fur hood", "inputs": {"wolf_pelt": 2}, "output": {"item": "fur_hood", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 10, "tier": "",
	},
	"fur_coat": {
		"label": "Fur coat", "inputs": {"wolf_pelt": 3}, "output": {"item": "fur_coat", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 20, "tier": "",
	},
	"fur_legs": {
		"label": "Fur leggings", "inputs": {"wolf_pelt": 2}, "output": {"item": "fur_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 10, "tier": "",
	},
	# Iron: ring one's iron ore, once the Bloomery is built.
	"iron_bar": {
		"label": "Iron bar", "inputs": {"iron_ore": 2}, "output": {"item": "iron_bar", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "bloomery", "xp": 18, "tier": ItemTable.TIER_IRON,
	},
	# Iron gear takes the bronze shapes, iron bars for bronze bars, a smithing level above.
	"iron_axe": {
		"label": "Iron axe", "inputs": {"iron_bar": 1, "logs": 2}, "output": {"item": "iron_axe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "bloomery", "xp": 22, "tier": ItemTable.TIER_IRON,
	},
	"iron_pickaxe": {
		"label": "Iron pickaxe", "inputs": {"iron_bar": 1, "logs": 2}, "output": {"item": "iron_pickaxe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "bloomery", "xp": 22, "tier": ItemTable.TIER_IRON,
	},
	"iron_sword": {
		"label": "Iron sword", "inputs": {"iron_bar": 2, "logs": 1}, "output": {"item": "iron_sword", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "bloomery", "xp": 36, "tier": ItemTable.TIER_IRON,
	},
	"iron_bow": {
		"label": "Iron bow", "inputs": {"iron_bar": 2, "logs": 3}, "output": {"item": "iron_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "bloomery", "xp": 36, "tier": ItemTable.TIER_IRON,
	},
	"iron_staff": {
		"label": "Iron staff", "inputs": {"iron_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "iron_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "bloomery", "xp": 36, "tier": ItemTable.TIER_IRON,
	},
	"iron_helm": {
		"label": "Iron helm", "inputs": {"iron_bar": 1}, "output": {"item": "iron_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "bloomery", "xp": 15, "tier": ItemTable.TIER_IRON,
	},
	"iron_body": {
		"label": "Iron body", "inputs": {"iron_bar": 2}, "output": {"item": "iron_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "bloomery", "xp": 30, "tier": ItemTable.TIER_IRON,
	},
	"iron_legs": {
		"label": "Iron legs", "inputs": {"iron_bar": 1}, "output": {"item": "iron_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "bloomery", "xp": 15, "tier": ItemTable.TIER_IRON,
	},
	# Steel: iron ore from both rings and coal from ring two, once the blast furnace is built.
	"steel_bar": {
		"label": "Steel bar", "inputs": {"iron_ore": 1, "coal": 2}, "output": {"item": "steel_bar", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "blast_furnace", "xp": 25, "tier": ItemTable.TIER_STEEL,
	},
	"steel_axe": {
		"label": "Steel axe", "inputs": {"steel_bar": 1, "logs": 2}, "output": {"item": "steel_axe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "blast_furnace", "xp": 30, "tier": ItemTable.TIER_STEEL,
	},
	"steel_pickaxe": {
		"label": "Steel pickaxe", "inputs": {"steel_bar": 1, "logs": 2}, "output": {"item": "steel_pickaxe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "blast_furnace", "xp": 30, "tier": ItemTable.TIER_STEEL,
	},
	"steel_sword": {
		"label": "Steel sword", "inputs": {"steel_bar": 2, "logs": 1}, "output": {"item": "steel_sword", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 50, "tier": ItemTable.TIER_STEEL,
	},
	"steel_bow": {
		"label": "Steel bow", "inputs": {"steel_bar": 2, "logs": 3}, "output": {"item": "steel_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 50, "tier": ItemTable.TIER_STEEL,
	},
	"steel_staff": {
		"label": "Steel staff", "inputs": {"steel_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "steel_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 50, "tier": ItemTable.TIER_STEEL,
	},
	"steel_helm": {
		"label": "Steel helm", "inputs": {"steel_bar": 1}, "output": {"item": "steel_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 20, "tier": ItemTable.TIER_STEEL,
	},
	"steel_body": {
		"label": "Steel body", "inputs": {"steel_bar": 1, "troll_hide": 1}, "output": {"item": "steel_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 40, "tier": ItemTable.TIER_STEEL,
	},
	"steel_legs": {
		"label": "Steel legs", "inputs": {"steel_bar": 1}, "output": {"item": "steel_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 20, "tier": ItemTable.TIER_STEEL,
	},
	# Melee top sets (rime steel): the steel recipe of the slot and style plus the style's rare material.
	"emberheart_helm": {
		"label": "Emberheart helm", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "emberheart_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"emberheart_body": {
		"label": "Emberheart body", "inputs": {"rime_steel": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "emberheart_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"emberheart_legs": {
		"label": "Emberheart legs", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "emberheart_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"emberheart_hammer": {
		"label": "Emberheart hammer", "inputs": {"rime_steel": 3, "steel_bar": 2, "logs": 1}, "output": {"item": "emberheart_hammer", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"hoarfrost_helm": {
		"label": "Hoarfrost helm", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "hoarfrost_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hoarfrost_body": {
		"label": "Hoarfrost body", "inputs": {"rime_steel": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "hoarfrost_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"hoarfrost_legs": {
		"label": "Hoarfrost legs", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "hoarfrost_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hoarfrost_greatsword": {
		"label": "Hoarfrost greatsword", "inputs": {"rime_steel": 3, "steel_bar": 2, "logs": 1}, "output": {"item": "hoarfrost_greatsword", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"auroral_helm": {
		"label": "Auroral helm", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "auroral_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"auroral_body": {
		"label": "Auroral body", "inputs": {"rime_steel": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "auroral_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"auroral_legs": {
		"label": "Auroral legs", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "auroral_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"auroral_glaive": {
		"label": "Auroral glaive", "inputs": {"rime_steel": 3, "steel_bar": 2, "logs": 1}, "output": {"item": "auroral_glaive", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"trollbone_helm": {
		"label": "Trollbone helm", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "trollbone_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"trollbone_body": {
		"label": "Trollbone body", "inputs": {"rime_steel": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "trollbone_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"trollbone_legs": {
		"label": "Trollbone legs", "inputs": {"rime_steel": 2, "steel_bar": 1}, "output": {"item": "trollbone_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"trollbone_cleaver": {
		"label": "Trollbone cleaver", "inputs": {"rime_steel": 3, "steel_bar": 2, "logs": 1}, "output": {"item": "trollbone_cleaver", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	# Ranged top sets (frost sinew): the steel recipe of the slot and style plus the style's rare material.
	"ember_hawk_helm": {
		"label": "Ember Hawk hood", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "ember_hawk_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ember_hawk_body": {
		"label": "Ember Hawk jerkin", "inputs": {"frost_sinew": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "ember_hawk_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"ember_hawk_legs": {
		"label": "Ember Hawk kilt", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "ember_hawk_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ember_hawk_bow": {
		"label": "Ember Hawk bow", "inputs": {"frost_sinew": 3, "steel_bar": 2, "logs": 3}, "output": {"item": "ember_hawk_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"ember_hawk_quiver": {
		"label": "Ember Hawk quiver", "inputs": {"frost_sinew": 2, "steel_bar": 2}, "output": {"item": "ember_hawk_quiver", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"auroral_warden_helm": {
		"label": "Auroral Warden hood", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "auroral_warden_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"auroral_warden_body": {
		"label": "Auroral Warden jerkin", "inputs": {"frost_sinew": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "auroral_warden_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"auroral_warden_legs": {
		"label": "Auroral Warden kilt", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "auroral_warden_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"auroral_warden_bow": {
		"label": "Auroral Warden bow", "inputs": {"frost_sinew": 3, "steel_bar": 2, "logs": 3}, "output": {"item": "auroral_warden_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"auroral_warden_quiver": {
		"label": "Auroral Warden quiver", "inputs": {"frost_sinew": 2, "steel_bar": 2}, "output": {"item": "auroral_warden_quiver", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"auroral_warden_cape": {
		"label": "Auroral Warden mantle", "inputs": {"frost_sinew": 2, "steel_bar": 2}, "output": {"item": "auroral_warden_cape", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruin_stalker_helm": {
		"label": "Ruin Stalker mask", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "ruin_stalker_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruin_stalker_body": {
		"label": "Ruin Stalker jerkin", "inputs": {"frost_sinew": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "ruin_stalker_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"ruin_stalker_legs": {
		"label": "Ruin Stalker kilt", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "ruin_stalker_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruin_stalker_bow": {
		"label": "Ruin Stalker bow", "inputs": {"frost_sinew": 3, "steel_bar": 2, "logs": 3}, "output": {"item": "ruin_stalker_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"ruin_stalker_quiver": {
		"label": "Ruin Stalker quiver", "inputs": {"frost_sinew": 2, "steel_bar": 2}, "output": {"item": "ruin_stalker_quiver", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruin_stalker_cape": {
		"label": "Ruin Stalker shroud", "inputs": {"frost_sinew": 2, "steel_bar": 2}, "output": {"item": "ruin_stalker_cape", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"glacier_sovereign_helm": {
		"label": "Glacier Sovereign crown", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "glacier_sovereign_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"glacier_sovereign_body": {
		"label": "Glacier Sovereign jerkin", "inputs": {"frost_sinew": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "glacier_sovereign_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"glacier_sovereign_legs": {
		"label": "Glacier Sovereign kilt", "inputs": {"frost_sinew": 2, "steel_bar": 1}, "output": {"item": "glacier_sovereign_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"glacier_sovereign_bow": {
		"label": "Glacier Sovereign bow", "inputs": {"frost_sinew": 3, "steel_bar": 2, "logs": 3}, "output": {"item": "glacier_sovereign_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"glacier_sovereign_quiver": {
		"label": "Glacier Sovereign quiver", "inputs": {"frost_sinew": 2, "steel_bar": 2}, "output": {"item": "glacier_sovereign_quiver", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	# Magic top sets (aurora glass): the steel recipe of the slot and style plus the style's rare material.
	"hoarfrost_sovereign_helm": {
		"label": "Hoarfrost Sovereign crown", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "hoarfrost_sovereign_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hoarfrost_sovereign_body": {
		"label": "Hoarfrost Sovereign robe", "inputs": {"aurora_glass": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "hoarfrost_sovereign_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"hoarfrost_sovereign_legs": {
		"label": "Hoarfrost Sovereign skirt", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "hoarfrost_sovereign_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hoarfrost_sovereign_staff": {
		"label": "Hoarfrost Sovereign greatshard", "inputs": {"aurora_glass": 3, "steel_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "hoarfrost_sovereign_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"hoarfrost_sovereign_cape": {
		"label": "Hoarfrost Sovereign cloak", "inputs": {"aurora_glass": 2, "steel_bar": 2}, "output": {"item": "hoarfrost_sovereign_cape", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hearthfire_magus_helm": {
		"label": "Hearthfire Magus hood", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "hearthfire_magus_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hearthfire_magus_body": {
		"label": "Hearthfire Magus robe", "inputs": {"aurora_glass": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "hearthfire_magus_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"hearthfire_magus_legs": {
		"label": "Hearthfire Magus leggings", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "hearthfire_magus_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"hearthfire_magus_staff": {
		"label": "Hearthfire Magus brazier staff", "inputs": {"aurora_glass": 3, "steel_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "hearthfire_magus_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"hearthfire_magus_cape": {
		"label": "Hearthfire Magus cloak", "inputs": {"aurora_glass": 2, "steel_bar": 2}, "output": {"item": "hearthfire_magus_cape", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"aurora_shaman_helm": {
		"label": "Aurora Shaman antlers", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "aurora_shaman_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"aurora_shaman_body": {
		"label": "Aurora Shaman mantle", "inputs": {"aurora_glass": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "aurora_shaman_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"aurora_shaman_legs": {
		"label": "Aurora Shaman leggings", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "aurora_shaman_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"aurora_shaman_staff": {
		"label": "Aurora Shaman staff", "inputs": {"aurora_glass": 3, "steel_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "aurora_shaman_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"aurora_shaman_cape": {
		"label": "Aurora Shaman cloak", "inputs": {"aurora_glass": 2, "steel_bar": 2}, "output": {"item": "aurora_shaman_cape", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruinwarden_mage_helm": {
		"label": "Ruinwarden mask", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "ruinwarden_mage_helm", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruinwarden_mage_body": {
		"label": "Ruinwarden robe", "inputs": {"aurora_glass": 3, "steel_bar": 1, "troll_hide": 1}, "output": {"item": "ruinwarden_mage_body", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 40, "tier": "",
	},
	"ruinwarden_mage_legs": {
		"label": "Ruinwarden greaves", "inputs": {"aurora_glass": 2, "steel_bar": 1}, "output": {"item": "ruinwarden_mage_legs", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
	"ruinwarden_mage_staff": {
		"label": "Ruinwarden pillar", "inputs": {"aurora_glass": 3, "steel_bar": 2, "logs": 2, "ice_crystal": 1}, "output": {"item": "ruinwarden_mage_staff", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 50, "tier": "",
	},
	"ruinwarden_mage_cape": {
		"label": "Ruinwarden banner", "inputs": {"aurora_glass": 2, "steel_bar": 2}, "output": {"item": "ruinwarden_mage_cape", "count": 1},
		"skill": SkillTable.SMITHING, "level": 60, "upgrade": "ring_three_gate", "xp": 20, "tier": "",
	},
}

const COOKING := {
	"raw_fish": {"output": "cooked_fish", "level": 1, "xp": 10, "burn": 40},
	"raw_trout": {"output": "cooked_trout", "level": 3, "xp": 18, "burn": 50},
	"raw_char": {"output": "cooked_char", "level": 5, "xp": 26, "burn": 50},
}


static func has(id: String) -> bool:
	return RECIPES.has(id)


static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


static func ids() -> Array:
	return RECIPES.keys()


static func is_cookable(kind: String) -> bool:
	return COOKING.has(kind)


static func cooking(kind: String) -> Dictionary:
	return COOKING.get(kind, {})
