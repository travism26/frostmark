## The test-mode character (docs/testing.md): a maxed save for checking the rings by hand,
## every skill at the top of the curve, steel gear worn and carried, a full stash, every
## upgrade built, the captain down and the ring-two gate open, both waystones attuned, full
## warmth and health and hints off. It is an ordinary save of the current version, built
## through restore() like the tests build their states, so no rule bends for it.
##
## A short code typed into Import code, or a query parameter on the page, stands for the full
## save code. Only their hashes live here; the repo is public, so this is obscurity, not a lock.
class_name FieldKit
extends RefCounted

## sha256 of the short code, lower-cased.
const SHORT_HASH := "7003ccbc9780afdf403fcf5fd8c26786a604a35105625f00059f0ae4c76bec71"
## sha256 of the query pair, `name=value`, as it appears in the page's query string.
const QUERY_HASH := "3b56c406c45b0c8a43371bdeda47567153511ba1521c1d895ce31d94d84fdee1"

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


## The full save code when `typed` is the short code, otherwise `typed` unchanged.
static func expand(typed: String, world: WorldDef = null) -> String:
	if typed.strip_edges().to_lower().sha256_text() == SHORT_HASH:
		return code(world)
	return typed


## True when the web page was opened with the query pair. Always false off the web.
static func asked_by_page() -> bool:
	if not OS.has_feature("web"):
		return false
	var search: Variant = JavaScriptBridge.eval("location.search", true)
	if not (search is String):
		return false
	for pair in (search as String).trim_prefix("?").split("&", false):
		if pair.sha256_text() == QUERY_HASH:
			return true
	return false


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
