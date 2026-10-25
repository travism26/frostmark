## The all-gear code (docs/testing.md): its short code and the page's query pair load the
## test-mode character with a stash of one of every gear item in the item table and a full
## stack of each ammunition, for trying gear on in game (scenes/field_kit.gd). Both are reached
## here through their stored hashes, never typed.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


## A new character that has imported the all-gear short code.
func _imported() -> Sim:
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.for_digest(FieldKit.GEAR_SHORT_HASH)})
	assert_true(result["ok"], "the all-gear code imports: %s" % result["reason"])
	return sim


## The stash the item table calls for: every item with an equipment slot once, in table order,
## then a full stack of every ammunition a weapon names.
func _expected_stash() -> Array:
	var gear: Array = []
	var ammo: Array = []
	for kind in ItemTable.ITEMS:
		if ItemTable.ITEMS[kind]["slot"] != "":
			gear.append({"item": kind, "count": 1})
			var shot: String = ItemTable.ITEMS[kind].get("ammo", "")
			if shot != "" and not ammo.has(shot):
				ammo.append(shot)
	for kind in ammo:
		gear.append({"item": kind, "count": ItemTable.ITEMS[kind]["stack"]})
	return gear


func test_both_stored_hashes_import_as_a_save_of_this_version_in_the_outpost() -> void:
	var full := FieldKit.gear_code()
	assert_false(full.is_empty(), "the all-gear save restores in this version")
	assert_eq(FieldKit.for_digest(FieldKit.GEAR_SHORT_HASH), full, "the short code is the all-gear code")
	assert_eq(FieldKit.for_digest(FieldKit.GEAR_QUERY_HASH), full, "the link is the all-gear code")
	assert_true(full != FieldKit.code(), "it is not the test-mode save")
	var sim := _imported()
	assert_eq(H.of_kind(sim.drain_events(), Vocab.EV_SAVED).size(), 1)
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST)


func test_everything_but_the_stash_is_the_test_mode_save() -> void:
	var sim := _imported()
	var maxed := SimScript.new()
	maxed.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code()})
	var snap := sim.snapshot()
	var home := maxed.snapshot()
	snap.erase("stash")
	home.erase("stash")
	assert_eq(snap, home, "skills, upgrades, captain, rings, waystones, warmth, health and hints match")
	for name in SkillTable.NAMES:
		assert_eq(sim.state["skills"][name]["level"], SkillTable.MAX_LEVEL, "%s level" % name)
	assert_eq((sim.state["upgrades"] as Array).size(), UpgradeTable.ids().size(), "every upgrade built")
	assert_true((sim.state["bosses_defeated"] as Array).has("captain"), "the captain is down")
	assert_true((sim.state["rings_reached"] as Array).has(WorldDef.REGION_RING_TWO), "ring two reached")
	assert_eq(sim.state["waystones"], sim.world.objects_of_kind(WorldDef.KIND_WAYSTONE), "both waystones attuned")
	assert_eq(sim.state["warmth"], Sim.WARMTH_MAX)
	assert_eq(sim.state["health"], Sim.HEALTH_MAX)
	assert_false(sim.state["guide"]["on"], "hints are off")


func test_the_stash_holds_one_of_every_gear_item_from_the_table_and_full_ammunition() -> void:
	var sim := _imported()
	var expected := _expected_stash()
	var filled: Array = (sim.state["stash"]["slots"] as Array).filter(func(slot: Variant) -> bool: return slot != null)
	assert_eq(filled, expected, "the table's gear in its order, then a full stack of each ammunition")
	for kind in ItemTable.ITEMS:
		if ItemTable.ITEMS[kind]["slot"] != "":
			assert_eq(Inventory.count_of(sim.state["stash"]["slots"], kind), 1, "one %s" % kind)
	assert_true(Inventory.count_of(sim.state["stash"]["slots"], "arrows") > 0, "arrows for every bow")
	assert_true(Inventory.count_of(sim.state["stash"]["slots"], "frost_shards") > 0, "frost shards for every staff")


func test_the_stash_grows_to_fit_what_it_holds() -> void:
	var sim := _imported()
	var capacity: int = sim.state["stash"]["capacity"]
	assert_true(capacity >= _expected_stash().size(), "every filled slot fits")
	assert_true(capacity >= FieldKit.built_capacity(), "never fewer slots than the built stash has")
	assert_eq((sim.state["stash"]["slots"] as Array).size(), capacity)

