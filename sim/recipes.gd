## The workbench recipes and the cooking table as data: what goes in, what comes out, and
## what unlocks it.
##
## A workbench recipe's `inputs` maps item kinds to counts consumed from the pack. `skill`
## and `level` are the skill level required; `upgrade` is an outpost upgrade id that must be
## built first, or "" when none is needed. `xp` is experience granted to `skill` per craft.
## `tier` is the metal tier the recipe works; the simulation refuses any recipe above its
## smithing cap (bronze until the blast furnace raises it to steel). No recipe works iron:
## iron stays a thing found, not made.
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
	"wooden_armour": {
		"label": "Wooden armour", "inputs": {"logs": 8}, "output": {"item": "wooden_armour", "count": 1},
		"skill": SkillTable.SMITHING, "level": 2, "upgrade": "", "xp": 20, "tier": ItemTable.TIER_WOODEN,
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
	"bronze_armour": {
		"label": "Bronze armour", "inputs": {"bronze_bar": 4}, "output": {"item": "bronze_armour", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 40, "tier": ItemTable.TIER_BRONZE,
	},
	# Steel: iron ore from both rings and coal from ring two, once the blast furnace is built.
	"steel_bar": {
		"label": "Steel bar", "inputs": {"iron_ore": 1, "coal": 2}, "output": {"item": "steel_bar", "count": 1},
		"skill": SkillTable.SMITHING, "level": 4, "upgrade": "blast_furnace", "xp": 20, "tier": ItemTable.TIER_STEEL,
	},
	"steel_axe": {
		"label": "Steel axe", "inputs": {"steel_bar": 1, "logs": 2}, "output": {"item": "steel_axe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 30, "tier": ItemTable.TIER_STEEL,
	},
	"steel_pickaxe": {
		"label": "Steel pickaxe", "inputs": {"steel_bar": 1, "logs": 2}, "output": {"item": "steel_pickaxe", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 30, "tier": ItemTable.TIER_STEEL,
	},
	"steel_sword": {
		"label": "Steel sword", "inputs": {"steel_bar": 2, "logs": 1}, "output": {"item": "steel_sword", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 50, "tier": ItemTable.TIER_STEEL,
	},
	"steel_bow": {
		"label": "Steel bow", "inputs": {"steel_bar": 2, "logs": 3}, "output": {"item": "steel_bow", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "blast_furnace", "xp": 50, "tier": ItemTable.TIER_STEEL,
	},
	"steel_armour": {
		"label": "Steel armour", "inputs": {"steel_bar": 3, "troll_hide": 1}, "output": {"item": "steel_armour", "count": 1},
		"skill": SkillTable.SMITHING, "level": 6, "upgrade": "blast_furnace", "xp": 80, "tier": ItemTable.TIER_STEEL,
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
