## Board-only, not shipped: prints the test-mode save code (docs/testing.md), a maxed
## character for checking the rings by hand: every skill at the top of the curve, steel gear
## worn and carried, a full stash, every upgrade built, the captain down and the ring-two gate
## open, both waystones attuned, full warmth and health and hints off. It is an ordinary save
## of the current version, built through restore() like the tests build their states.
##   godot --headless -s tools/test_mode_code.gd > /dev/null && cat tools/test_mode_code.txt
## Regenerate it whenever the save version changes; tests/test_test_mode.gd imports the file.
extends SceneTree

const CODE_PATH := "res://tools/test_mode_code.txt"

const EQUIPMENT := {"weapon": "steel_sword", "armour": "steel_armour", "tool": "steel_pickaxe"}
## A tool and a weapon for every skill and style, with ammunition and food, under the carry limit.
const PACK := [
	{"item": "steel_axe", "count": 1}, {"item": "fishing_rod", "count": 1},
	{"item": "steel_bow", "count": 1}, {"item": "steel_staff", "count": 1},
	{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100},
	{"item": "cooked_char", "count": 5},
]
## Full stacks of every material, so any recipe can be made at once.
const STASH := [
	{"item": "logs", "count": 10}, {"item": "logs", "count": 10},
	{"item": "bronze_bar", "count": 10}, {"item": "bronze_bar", "count": 10},
	{"item": "steel_bar", "count": 10}, {"item": "coal", "count": 10},
	{"item": "iron_ore", "count": 10}, {"item": "copper_ore", "count": 10},
	{"item": "tin_ore", "count": 10}, {"item": "wolf_pelt", "count": 5},
	{"item": "troll_hide", "count": 5}, {"item": "ice_crystal", "count": 10},
	{"item": "cooked_char", "count": 10}, {"item": "cooked_char", "count": 10},
	{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100},
]


func _init() -> void:
	var sim := Sim.new()
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	var snap := sim.snapshot()
	var skills := {}
	for name in SkillTable.NAMES:
		skills[name] = {"xp": SkillTable.xp_for_level(SkillTable.MAX_LEVEL), "level": SkillTable.MAX_LEVEL}
	snap["skills"] = skills
	var pack: Array = PACK.duplicate(true)
	pack.resize(Sim.PACK_SLOTS)
	snap["inventory"] = {"pack": pack, "equipment": EQUIPMENT.duplicate()}
	var capacity := Sim.STASH_START_SLOTS
	for id in UpgradeTable.ids():
		capacity += int(UpgradeTable.get_upgrade(id)["effects"].get("stash", 0))
	snap["stash"] = {"capacity": capacity, "slots": STASH.duplicate(true)}
	snap["upgrades"] = UpgradeTable.ids()
	snap["bosses_defeated"] = ["captain"]
	snap["enemies"]["captain"].merge({"mode": Sim.MODE_DEAD, "health": 0}, true)
	snap["rings_reached"] = [WorldDef.REGION_RING_TWO]
	snap["waystones"] = sim.world.objects_of_kind(WorldDef.KIND_WAYSTONE)
	snap["warmth"] = Sim.WARMTH_MAX
	snap["health"] = Sim.HEALTH_MAX
	if not sim.restore(snap):
		push_error("the maxed snapshot did not restore")
		quit(1)
		return
	var code := sim.export_code()
	var file := FileAccess.open(CODE_PATH, FileAccess.WRITE)
	file.store_string(code + "\n")
	file.close()
	print("CODE test_mode %s" % code)
	quit(0)
