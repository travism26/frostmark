## The build-from-scratch code (docs/testing.md): its short code and the page's query pair load
## a new character with nothing built and a stash holding every upgrade's cost, summed from the
## upgrade table (scenes/field_kit.gd), so the whole yard can be built up from it by hand.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const SHORT_CODE := "RIMEKNOT"
const QUERY_PAIR := "hearth=kindling"


## A new character that has imported the build-from-scratch short code.
func _imported() -> Sim:
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.expand(SHORT_CODE)})
	assert_true(result["ok"], "the short code imports: %s" % result["reason"])
	sim.drain_events()
	return sim


## Upgrade ids in an order that builds each after everything it requires.
func _build_order() -> Array:
	var order: Array = []
	var left: Array = UpgradeTable.ids()
	while not left.is_empty():
		var progressed := false
		for id in left.duplicate():
			var ready := true
			for need in UpgradeTable.get_upgrade(id)["requires"]:
				ready = ready and order.has(need)
			if ready:
				order.append(id)
				left.erase(id)
				progressed = true
		assert_true(progressed, "the upgrade table has no requirement loop")
		if not progressed:
			break
	return order


func test_the_short_code_loads_a_new_character_in_the_outpost_of_this_version() -> void:
	var sim := _imported()
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST)
	assert_true(sim.in_outpost(), "standing in the outpost")
	var fresh := SimScript.new()
	assert_eq(sim.state["skills"], fresh.state["skills"], "every skill at its starting level")
	assert_eq(sim.state["inventory"], fresh.state["inventory"], "the starting pack and tool")
	assert_eq(sim.state["warmth"], Sim.WARMTH_MAX)
	assert_eq(sim.state["health"], Sim.HEALTH_MAX)


func test_nothing_is_built_and_nothing_is_reached() -> void:
	var sim := _imported()
	assert_eq(sim.state["upgrades"], [], "no upgrade built")
	assert_eq(sim.state["bosses_defeated"], [], "the captain still stands")
	assert_false(sim.ring_gate_open("ring_two_gate"), "the ring-two gate is shut")
	assert_eq(sim.state["waystones"], [], "no waystone attuned")


func test_the_stash_holds_every_upgrades_cost_beside_the_starting_kit() -> void:
	var sim := _imported()
	var slots: Array = sim.state["stash"]["slots"]
	var costs := FieldKit.all_costs()
	for kind in costs:
		assert_eq(Inventory.count_of(slots, kind), costs[kind], "the stash holds exactly the %s every upgrade needs" % kind)
	for kit in Sim.STARTING_STASH:
		if not costs.has(kit["item"]):
			assert_eq(Inventory.count_of(slots, kit["item"]), kit["count"], "the starting %s is kept" % kit["item"])
	for id in UpgradeTable.ids():
		var cost: Dictionary = UpgradeTable.get_upgrade(id)["cost"]
		for kind in cost:
			assert_true(Inventory.count_of(slots, kind) >= int(cost[kind]), "%s's %s is covered" % [id, kind])


func test_the_summed_cost_follows_the_upgrade_table() -> void:
	var expected := {}
	for id in UpgradeTable.UPGRADES:
		for kind in UpgradeTable.UPGRADES[id]["cost"]:
			expected[kind] = int(expected.get(kind, 0)) + int(UpgradeTable.UPGRADES[id]["cost"][kind])
	assert_eq(FieldKit.all_costs(), expected)


func test_every_upgrade_builds_in_order_from_the_save() -> void:
	var sim := _imported()
	var order := _build_order()
	assert_eq(order.size(), UpgradeTable.ids().size(), "every upgrade has a place in the order")
	var slots_added := 0
	for id in order:
		var result := sim.command(Vocab.BUILD, {"upgrade": id})
		assert_true(result["ok"], "%s builds: %s" % [id, result["reason"]])
		slots_added += int(UpgradeTable.get_upgrade(id)["effects"].get("stash", 0))
		var built := H.of_kind(H.run(sim, 1), Vocab.EV_BUILT)
		assert_eq(built.size(), 1, "%s announces its build" % id)
	assert_eq((sim.state["upgrades"] as Array).size(), UpgradeTable.ids().size(), "everything is built")
	for kind in FieldKit.all_costs():
		assert_eq(Inventory.count_of(sim.state["stash"]["slots"], kind), 0, "every %s is spent" % kind)
	var fresh := _imported()
	assert_eq(sim.state["stash"]["capacity"], int(fresh.state["stash"]["capacity"]) + slots_added, "the stash upgrades add their slots")


func test_the_short_code_ignores_case_and_spacing_and_is_new_each_load() -> void:
	var full := FieldKit.bare_code()
	assert_false(full.is_empty(), "the save restores in this version")
	assert_eq(FieldKit.expand(SHORT_CODE), full)
	assert_eq(FieldKit.expand("  rimeknot\n"), full, "case and spacing do not matter")
	assert_true(FieldKit.expand(SHORT_CODE) != FieldKit.code(), "it is not the maxed save")
	for typed in ["rimeknots", "rimekno", "kindling"]:
		assert_eq(FieldKit.expand(typed), typed, "%s is left alone" % typed)


func test_the_query_pair_matches_its_hash_and_asks_for_the_same_save() -> void:
	assert_eq(QUERY_PAIR.sha256_text(), FieldKit.BARE_QUERY_HASH)
	assert_eq(FieldKit.for_query("?" + QUERY_PAIR), FieldKit.bare_code())
	assert_eq(FieldKit.for_query("?a=b&" + QUERY_PAIR), FieldKit.bare_code(), "beside other parameters too")
