## The test-mode character (docs/testing.md): a maxed save for checking the rings by hand,
## every skill at the top of the curve, steel gear worn and carried, a full stash, every
## upgrade built, the captain down and the ring-two gate open, both waystones attuned, full
## warmth and health and hints off. It is an ordinary save of the current version, built
## through restore() like the tests build their states, so no rule bends for it.
##
## Beside it, the build-from-scratch character: a new character with nothing built and the
## stash holding the summed cost of every upgrade in the table, for building the yard up by hand.
##
## A short code typed into Import code, or a query parameter on the page, stands for each full
## save code. Only their hashes live here; the repo is public, so this is obscurity, not a lock.
class_name FieldKit
extends RefCounted

## sha256 of the short code, lower-cased.
const SHORT_HASH := "7003ccbc9780afdf403fcf5fd8c26786a604a35105625f00059f0ae4c76bec71"
## sha256 of the query pair, `name=value`, as it appears in the page's query string.
const QUERY_HASH := "3b56c406c45b0c8a43371bdeda47567153511ba1521c1d895ce31d94d84fdee1"
## The same two hashes for the build-from-scratch character.
const BARE_SHORT_HASH := "b17b2820c6322457ba8198b77384821ace5a35a605b42c418ea23194d9d70053"
const BARE_QUERY_HASH := "fd4d2de984044370d48fd4dbd8d7211f4794441f55d6c268e446755046e43309"

const EQUIPMENT := {
	"weapon": "steel_sword", "helm": "steel_helm", "body": "steel_body", "legs": "steel_legs", "tool": "steel_pickaxe",
}
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
	{"item": "iron_ore", "count": 10}, {"item": "coal", "count": 10},
	{"item": "steel_bar", "count": 10}, {"item": "logs", "count": 10},
]


## The full save code when `typed` is a short code, otherwise `typed` unchanged.
static func expand(typed: String, world: WorldDef = null) -> String:
	var digest := typed.strip_edges().to_lower().sha256_text()
	if digest == SHORT_HASH:
		return code(world)
	if digest == BARE_SHORT_HASH:
		return bare_code(world)
	return typed


## The full save code the web page's query string asks for, or "" when it asks for none.
## Always "" off the web.
static func page_code(world: WorldDef = null) -> String:
	if not OS.has_feature("web"):
		return ""
	var search: Variant = JavaScriptBridge.eval("location.search", true)
	if not (search is String):
		return ""
	return for_query(search as String, world)


## The full save code a query string such as `?a=b&c=d` asks for, or "" when it asks for none.
static func for_query(search: String, world: WorldDef = null) -> String:
	for pair in search.trim_prefix("?").split("&", false):
		match pair.sha256_text():
			QUERY_HASH:
				return code(world)
			BARE_QUERY_HASH:
				return bare_code(world)
	return ""


## The maxed character as a save code, or "" if this version would not restore it.
static func code(world: WorldDef = null) -> String:
	var sim := Sim.new(world)
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
		return ""
	return sim.export_code()


## Every upgrade's cost summed, item kind to count, in the table's order.
static func all_costs() -> Dictionary:
	var total := {}
	for id in UpgradeTable.ids():
		var cost: Dictionary = UpgradeTable.get_upgrade(id)["cost"]
		for kind in cost:
			total[kind] = int(total.get(kind, 0)) + int(cost[kind])
	return total


## The build-from-scratch character as a save code, or "" if this version would not restore it:
## a new character with nothing built, its starting kit still in the stash beside every
## upgrade's cost. The summed cost outgrows the starting stash, so this save alone starts with
## as many slots as it fills; the stash upgrades still add theirs on top when built.
static func bare_code(world: WorldDef = null) -> String:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	var snap := sim.snapshot()
	var slots: Array = Inventory.contents(snap["stash"]["slots"])
	var costs := all_costs()
	for kind in costs:
		var left: int = costs[kind]
		while left > 0:
			var n := mini(left, ItemTable.stack_size(kind))
			slots.append({"item": kind, "count": n})
			left -= n
	snap["stash"] = {"capacity": maxi(Sim.STASH_START_SLOTS, slots.size()), "slots": slots}
	if not sim.restore(snap):
		return ""
	return sim.export_code()
