## The workbench recipes as data: what goes in, what comes out, and what unlocks it.
##
## `inputs` maps item kinds to counts consumed from the pack. `skill` and `level` are the
## skill level required; `upgrade` is an outpost upgrade id that must be built first, or ""
## when none is needed. `xp` is experience granted to `skill` per craft. Engine-free.
class_name RecipeTable
extends RefCounted

const RECIPES := {
	"wooden_club": {
		"label": "Wooden club",
		"inputs": {"logs": 4},
		"output": {"item": "wooden_club", "count": 1},
		"skill": SkillTable.SMITHING,
		"level": 1,
		"upgrade": "",
		"xp": 0,
	},
}


static func has(id: String) -> bool:
	return RECIPES.has(id)


static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


static func ids() -> Array:
	return RECIPES.keys()
