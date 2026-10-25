## The outpost tech tree as data: what each upgrade costs, what it needs first, what it does.
##
## `cost` maps item kinds to counts taken from the stash when the upgrade is built (inside the
## outpost). `requires` lists upgrade ids that must be built first. `effects` says what the
## upgrade changes: `stash` adds that many stash slots, `carry` adds that many kilograms to the
## carry limit, `recipes` names the workbench recipes it unlocks (RecipeTable entries whose
## `upgrade` is this id), `smithing_tier` raises the highest metal tier the workbench works, `ring_gate` names the ring gate it readies (a
## gate with a guardian opens once that guardian has fallen too), and `waystones` lists the waystone objects it
## wakes (each still has to be visited once before it carries anyone home). An upgrade with
## `locked` set is listed but cannot be built in this version; the text says why. Listed in the
## order the upgrades panel shows them. Engine-free.
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
		"effects": {"recipes": ["bronze_helm", "bronze_body", "bronze_legs", "fur_hood", "fur_coat", "fur_legs"]}, "locked": "",
	},
	# Optional: a frame to lash a heavier load to, so every trip out carries more. Nothing
	# else needs it.
	"pack_frame": {
		"label": "Pack frame", "cost": {"logs": 10, "wolf_pelt": 4}, "requires": ["armoury"],
		"effects": {"carry": 15}, "locked": "",
	},
	# Optional: it lifts the smithing cap from bronze to iron, and nothing else needs it.
	"bloomery": {
		"label": "Bloomery", "cost": {"logs": 8, "bronze_bar": 2, "iron_ore": 4}, "requires": ["armoury"],
		"effects": {
			"recipes": ["iron_bar", "iron_axe", "iron_pickaxe", "iron_sword", "iron_bow", "iron_staff", "iron_helm", "iron_body", "iron_legs"],
			"smithing_tier": ItemTable.TIER_IRON,
		},
		"locked": "",
	},
	"ring_two_gate": {
		"label": "Ring-two gate winch", "cost": {"logs": 12, "iron_ore": 12, "bronze_bar": 3, "wolf_pelt": 5},
		"requires": ["armoury"], "effects": {"ring_gate": "ring_two_gate"}, "locked": "",
	},
	# Ring two's coal and troll hides build it; it lifts the smithing cap from bronze to steel.
	"blast_furnace": {
		"label": "Blast furnace", "cost": {"logs": 12, "bronze_bar": 4, "coal": 6, "troll_hide": 2},
		"requires": ["ring_two_gate"],
		"effects": {
			"recipes": ["steel_bar", "steel_axe", "steel_pickaxe", "steel_sword", "steel_bow", "steel_staff", "steel_helm", "steel_body", "steel_legs"],
			"smithing_tier": ItemTable.TIER_STEEL,
		},
		"locked": "",
	},
	# Iron and troll hide hoist the gate in ring two's southern cliffs: it has no guardian, so
	# building this opens it.
	"ring_three_gate": {
		"label": "Ring-three gate hoist", "cost": {"steel_bar": 8, "troll_hide": 4, "coal": 12, "logs": 16},
		"requires": ["blast_furnace"], "locked": "",
		"effects": {
			"ring_gate": "ring_three_gate",
			# The top-set pieces (#184): ring three's rare materials at the workbench.
			"recipes": [
				"emberheart_helm", "emberheart_body", "emberheart_legs", "emberheart_hammer", "hoarfrost_helm", "hoarfrost_body",
				"hoarfrost_legs", "hoarfrost_greatsword", "auroral_helm", "auroral_body", "auroral_legs", "auroral_glaive",
				"trollbone_helm", "trollbone_body", "trollbone_legs", "trollbone_cleaver", "ember_hawk_helm", "ember_hawk_body",
				"ember_hawk_legs", "ember_hawk_bow", "ember_hawk_quiver", "auroral_warden_helm", "auroral_warden_body", "auroral_warden_legs",
				"auroral_warden_bow", "auroral_warden_quiver", "auroral_warden_cape", "ruin_stalker_helm", "ruin_stalker_body", "ruin_stalker_legs",
				"ruin_stalker_bow", "ruin_stalker_quiver", "ruin_stalker_cape", "glacier_sovereign_helm", "glacier_sovereign_body", "glacier_sovereign_legs",
				"glacier_sovereign_bow", "glacier_sovereign_quiver", "hoarfrost_sovereign_helm", "hoarfrost_sovereign_body", "hoarfrost_sovereign_legs", "hoarfrost_sovereign_staff",
				"hoarfrost_sovereign_cape", "hearthfire_magus_helm", "hearthfire_magus_body", "hearthfire_magus_legs", "hearthfire_magus_staff", "hearthfire_magus_cape",
				"aurora_shaman_helm", "aurora_shaman_body", "aurora_shaman_legs", "aurora_shaman_staff", "aurora_shaman_cape", "ruinwarden_mage_helm",
				"ruinwarden_mage_body", "ruinwarden_mage_legs", "ruinwarden_mage_staff", "ruinwarden_mage_cape",
			],
		},
	},
	# Shortcuts home from deep in the rings. Travel is not a return: the walk through the gate is.
	"waystone": {
		"label": "Waystones", "cost": {"iron_ore": 10, "bronze_bar": 6, "logs": 10},
		"requires": ["ring_two_gate"], "effects": {"waystones": ["ring_one_waystone", "ring_two_waystone"]},
		"locked": "",
	},
	# The stash line's last step, a reward for ring two: it needs the winch and ring two's coal.
	"stash_vault": {
		"label": "Stash vault", "cost": {"logs": 12, "iron_ore": 10, "coal": 4},
		"requires": ["stash_cellar", "ring_two_gate"], "effects": {"stash": 4}, "locked": "",
	},
}


static func has(id: String) -> bool:
	return UPGRADES.has(id)


static func get_upgrade(id: String) -> Dictionary:
	return UPGRADES.get(id, {})


static func ids() -> Array:
	return UPGRADES.keys()
