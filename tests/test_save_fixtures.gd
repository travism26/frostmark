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
	assert_eq(sim.hint(), "bank", "it cut a pine and is on its way home to bank")


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
