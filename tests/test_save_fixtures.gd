## Every save version ever shipped still loads: one real save code per version under
## tests/fixtures/, each imported into the current build. A version bump adds its fixture
## (save_v<N>.txt, exported from the build that introduced it) and never edits an old one.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const FIXTURES := "res://tests/fixtures/save_v%d.txt"


func _fixture(version: int) -> String:
	return FileAccess.get_file_as_string(FIXTURES % version)


func test_every_version_has_a_fixture() -> void:
	for v in range(1, Sim.STATE_VERSION + 1):
		assert_true(FileAccess.file_exists(FIXTURES % v), "tests/fixtures/save_v%d.txt is missing: each version bump adds one" % v)


func test_each_fixture_is_the_version_it_claims() -> void:
	for v in range(1, Sim.STATE_VERSION + 1):
		var decoded := SaveCode.decode(_fixture(v), Sim.STATE_VERSION)
		assert_true(decoded["ok"], "save_v%d decodes: %s" % [v, decoded["reason"]])
		assert_eq(int(decoded["snapshot"].get("version", 0)), v, "save_v%d holds a version-%d snapshot" % [v, v])


func test_every_fixture_imports_into_the_current_version() -> void:
	for v in range(1, Sim.STATE_VERSION + 1):
		var old: Dictionary = SaveCode.decode(_fixture(v), Sim.STATE_VERSION)["snapshot"]
		var sim := SimScript.new()
		var result := sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(v)})
		assert_true(result["ok"], "save_v%d imports: %s" % [v, result["reason"]])
		assert_eq(sim.state["version"], Sim.STATE_VERSION, "save_v%d is migrated to the current version" % v)
		assert_eq(int(sim.state["tick"]), int(old["tick"]), "save_v%d keeps its tick" % v)
		assert_eq(sim.player_pos(), Vector2(old["player"]["pos"][0], old["player"]["pos"][1]), "save_v%d keeps where the player stood" % v)
		# The migrated character plays on and saves again in the current format.
		for i in 20:
			sim.step()
		var again := SimScript.new()
		assert_true(again.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"], "save_v%d re-exports" % v)
		assert_eq(again.snapshot(), sim.snapshot())


func test_the_version_4_fixture_keeps_its_fire_and_kit() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(4)})["ok"])
	assert_eq(sim.state["fires"].size(), 1, "the field fire it was saved beside still burns")
	assert_true(int(sim.state["skills"]["woodcutting"]["xp"]) > 0, "the woodcutting it did is kept")


func test_the_version_5_fixture_keeps_its_place_on_the_guide() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(5)})["ok"])
	assert_true(sim.hints_on(), "the guide it was saved with is still on")
	assert_eq(sim.hint(), "bank", "it cut a pine and is on its way home")


func test_a_save_made_mid_trip_keeps_its_pack_on_return() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(5)})["ok"])
	assert_false(sim.in_outpost(), "it was saved out in the snow")
	var pack: Array = sim.state["inventory"]["pack"].duplicate(true)
	var stash: Array = sim.state["stash"]["slots"].duplicate(true)
	assert_true(Inventory.count_of(pack, "logs") > 0, "carrying the logs it cut")
	assert_true(sim.command(Vocab.CROSS_GATE)["ok"])
	var returned: Array = []
	for i in 200:
		sim.step()
		for e in sim.drain_events():
			if e["kind"] == Vocab.EV_RETURNED:
				returned.append(e)
		if sim.in_outpost() and not sim.is_moving():
			break
	assert_eq(returned.size(), 1, "it walks home through the gate")
	assert_eq(sim.state["inventory"]["pack"], pack, "the old rule does not bank it")
	assert_eq(sim.state["stash"]["slots"], stash)


func test_the_version_6_fixture_keeps_its_magic_and_shards() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(6)})["ok"])
	assert_eq(sim.state["inventory"]["equipment"]["weapon"], "wooden_staff", "the staff it cast with is still in hand")
	assert_eq(sim.state["inventory"]["pack"][0], {"item": "frost_shards", "count": 9}, "the shards it had left")
	assert_true(int(sim.state["skills"]["magic"]["xp"]) > 0, "the magic it levelled is kept")


func test_the_version_7_fixture_is_in_ring_two_with_its_steel() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(7)})["ok"])
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO, "it was saved just through the gate")
	assert_eq(sim.state["rings_reached"], [WorldDef.REGION_RING_TWO], "its first walk in is not announced again")
	assert_eq(sim.state["inventory"]["equipment"]["weapon"], "steel_sword", "the steel sword it carried")
	assert_eq(sim.smithing_cap(), ItemTable.TIER_STEEL, "its blast furnace still smiths steel")


func test_the_version_8_fixture_is_attuned_by_ring_ones_waystone() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(8)})["ok"])
	assert_eq(sim.state["waystones"], ["ring_one_waystone"], "the stone it visited")
	assert_true(sim.waystone_awake("ring_one_waystone"), "its waystone upgrade is built")
	assert_eq(sim.travel_check("ring_one_waystone"), "", "it can travel home from where it stands")
	assert_eq(sim.state["inventory"]["pack"][0], {"item": "iron_ore", "count": 3}, "with its haul")


func test_the_version_8_fixture_imports_with_the_same_upgrades_and_nothing_added() -> void:
	var old: Dictionary = SaveCode.decode(_fixture(8), Sim.STATE_VERSION)["snapshot"]
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(8)})["ok"])
	assert_eq(sim.state["upgrades"], old["upgrades"], "the upgrades it was saved with, and no others")
	assert_false((sim.state["upgrades"] as Array).has("stash_vault"), "no vault appears")
	assert_eq(int(sim.state["stash"]["capacity"]), int(old["stash"]["capacity"]), "the stash keeps its size")


func test_the_version_9_fixture_has_its_vault() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(9)})["ok"])
	assert_true((sim.state["upgrades"] as Array).has("stash_vault"), "the vault it built")
	assert_eq(int(sim.state["stash"]["capacity"]), 20, "the stash it grew to 20")
	assert_eq(sim.state["stash"]["slots"][19], {"item": "iron_ore", "count": 4}, "with its last slot in use")


func test_the_version_10_fixture_wears_the_wooden_set_it_made() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(10)})["ok"])
	var worn: Dictionary = sim.state["inventory"]["equipment"]
	assert_eq([worn["helm"], worn["body"], worn["legs"]], ["wooden_helm", "wooden_body", "wooden_legs"], "the helm, body and legs it made")
	assert_eq(sim.state["inventory"]["pack"][0], {"item": "logs", "count": 2}, "with the logs it had left")


func test_every_fixture_loads_with_an_empty_quiver_and_cape() -> void:
	for v in range(1, Sim.STATE_VERSION + 1):
		var sim := SimScript.new()
		assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(v)})["ok"], "save_v%d imports" % v)
		var worn: Dictionary = sim.state["inventory"]["equipment"]
		assert_eq(worn.keys(), Array(ItemTable.EQUIPMENT_SLOTS), "save_v%d has every equipment slot" % v)
		assert_eq(worn[ItemTable.SLOT_QUIVER], "", "save_v%d has an empty quiver slot" % v)
		assert_eq(worn[ItemTable.SLOT_CAPE], "", "save_v%d has an empty cape slot" % v)


func test_the_version_11_fixture_still_wears_its_wooden_set() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(11)})["ok"])
	var worn: Dictionary = sim.state["inventory"]["equipment"]
	assert_eq([worn["helm"], worn["body"], worn["legs"]], ["wooden_helm", "wooden_body", "wooden_legs"], "the helm, body and legs it wore")


func test_every_fixture_loads_with_every_enemy_on_its_own_cycle() -> void:
	for v in range(1, Sim.STATE_VERSION + 1):
		var sim := SimScript.new()
		assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(v)})["ok"], "save_v%d imports" % v)
		for id in sim.state["enemies"]:
			assert_eq(sim.state["enemies"][id]["phase"], 0, "save_v%d: %s is in no phase" % [v, id])


func test_the_version_12_fixture_is_saved_mid_fight_with_a_wolf() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(12)})["ok"])
	var wolf: Dictionary = sim.state["enemies"]["wolf_1"]
	assert_eq(wolf["mode"], Sim.MODE_ENGAGED, "the wolf it was fighting")
	assert_true(int(wolf["health"]) < int(CombatTable.ENEMIES["wolf"]["health"]), "is hurt")


func test_every_fixture_loads_with_no_enemy_having_answered() -> void:
	for v in range(1, Sim.STATE_VERSION + 1):
		var sim := SimScript.new()
		assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(v)})["ok"], "save_v%d imports" % v)
		for id in sim.state["enemies"]:
			assert_eq(sim.state["enemies"][id]["answered_tick"], -1, "save_v%d: %s has not answered" % [v, id])


func test_the_version_13_fixture_is_saved_mid_fight_with_the_captain_holding_his_bow() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": _fixture(13)})["ok"])
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_ENGAGED, "the captain it was fighting")
	assert_eq(sim.combatant("captain")["weapon"], "captain_bow", "holds his bow")
