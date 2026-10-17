## The workbench recipes and the cooking table as data: what goes in, what comes out, and
## what unlocks it.
##
## A workbench recipe's `inputs` maps item kinds to counts consumed from the pack. `skill`
## and `level` are the skill level required; `upgrade` is an outpost upgrade id that must be
## built first, or "" when none is needed. `xp` is experience granted to `skill` per craft.
## `tier` is the metal tier the recipe works; the simulation refuses any recipe above its
## smithing cap (bronze in the first playable), so iron stays a thing found, not made.
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
	"bronze_armour": {
		"label": "Bronze armour", "inputs": {"bronze_bar": 4}, "output": {"item": "bronze_armour", "count": 1},
		"skill": SkillTable.SMITHING, "level": 3, "upgrade": "armoury", "xp": 40, "tier": ItemTable.TIER_BRONZE,
	},
	# Listed so the workbench shows where the cap is: iron is found in ring one, never smelted.
	"iron_bar": {
		"label": "Iron bar", "inputs": {"iron_ore": 2}, "output": {"item": "iron_bar", "count": 1},
		"skill": SkillTable.SMITHING, "level": 5, "upgrade": "forge", "xp": 0, "tier": ItemTable.TIER_IRON,
	},
}

const COOKING := {
	"raw_fish": {"output": "cooked_fish", "level": 1, "xp": 10, "burn": 40},
	"raw_trout": {"output": "cooked_trout", "level": 3, "xp": 18, "burn": 50},
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
