## The outpost tech tree as data: what each upgrade costs, what it needs first, what it does.
##
## `cost` maps item kinds to counts taken from the stash when the upgrade is built (inside the
## outpost). `requires` lists upgrade ids that must be built first. `effects` says what the
## upgrade changes: `stash` adds that many stash slots, `recipes` names the workbench recipes
## it unlocks (RecipeTable entries whose `upgrade` is this id), `smithing_tier` raises the
## highest metal tier the workbench works, `ring_gate` names the ring gate it readies (it
## opens once that ring's guardian has fallen too), and `waystone` names a waystone. An upgrade with `locked` set is listed but cannot be built in this version;
## the text says why. Listed in the order the upgrades panel shows them. Engine-free.
class_name UpgradeTable
extends RefCounted

const UPGRADES := {
	"stash_shelves": {
		"label": "Stash shelves", "cost": {"logs": 8}, "requires": [],
		"effects": {"stash": 4}, "locked": "",
	},
	"forge": {
		"label": "Forge", "cost": {"logs": 6, "copper_ore": 3, "tin_ore": 3}, "requires": [],
		"effects": {"recipes": ["bronze_bar", "arrows", "bronze_axe", "bronze_pickaxe", "bronze_sword", "bronze_bow"]},
		"locked": "",
	},
	"stash_cellar": {
		"label": "Stash cellar", "cost": {"logs": 10, "bronze_bar": 2}, "requires": ["stash_shelves"],
		"effects": {"stash": 4}, "locked": "",
	},
	"armoury": {
		"label": "Armoury", "cost": {"logs": 6, "bronze_bar": 2, "wolf_pelt": 3}, "requires": ["forge"],
		"effects": {"recipes": ["bronze_armour"]}, "locked": "",
	},
	"ring_two_gate": {
		"label": "Ring-two gate winch", "cost": {"logs": 12, "iron_ore": 8, "bronze_bar": 3, "wolf_pelt": 3},
		"requires": ["armoury"], "effects": {"ring_gate": "ring_two_gate"}, "locked": "",
	},
	# Ring two's coal and troll hides build it; it lifts the smithing cap from bronze to steel.
	"blast_furnace": {
		"label": "Blast furnace", "cost": {"logs": 12, "bronze_bar": 4, "coal": 6, "troll_hide": 2},
		"requires": ["ring_two_gate"],
		"effects": {
			"recipes": ["steel_bar", "steel_axe", "steel_pickaxe", "steel_sword", "steel_bow", "steel_armour"],
			"smithing_tier": ItemTable.TIER_STEEL,
		},
		"locked": "",
	},
	"waystone": {
		"label": "Ring-one waystone", "cost": {"iron_ore": 10, "bronze_bar": 6, "logs": 10},
		"requires": ["ring_two_gate"], "effects": {"waystone": "ring_one"},
		"locked": "Waystones wake in a later slice.",
	},
}


static func has(id: String) -> bool:
	return UPGRADES.has(id)


static func get_upgrade(id: String) -> Dictionary:
	return UPGRADES.get(id, {})


static func ids() -> Array:
	return UPGRADES.keys()
