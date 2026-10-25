## The test-mode code (docs/testing.md): the save code scenes/field_kit.gd builds imports into
## this build and gives the maxed character it promises. It is built here rather than read from
## a committed file, so it is always of this build. The short code and the page's query pair
## stand for the same save; they are reached here through their stored hashes, never typed.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


## A new character that has imported the test-mode code.
func _imported() -> Sim:
	var sim := SimScript.new()
	var code := FieldKit.code()
	assert_false(code.is_empty(), "the maxed snapshot restores")
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": code})
	assert_true(result["ok"], "the test-mode code imports: %s" % result["reason"])
	return sim


func test_the_code_imports_as_a_save_of_this_version() -> void:
	var sim := _imported()
	var saved := H.of_kind(sim.drain_events(), Vocab.EV_SAVED)
	assert_eq(saved.size(), 1)
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST)


func test_every_skill_is_at_the_top_of_the_curve() -> void:
	var sim := _imported()
	for name in SkillTable.NAMES:
		assert_eq(sim.state["skills"][name]["level"], SkillTable.MAX_LEVEL, "%s level" % name)


func test_steel_is_worn_and_every_style_and_tool_is_carried_without_overweight() -> void:
	var sim := _imported()
	var worn: Dictionary = sim.state["inventory"]["equipment"]
	# Steel exists for five slots; no quiver or cape is steel, so the character leaves both empty.
	for slot in ItemTable.EQUIPMENT_SLOTS:
		if slot == ItemTable.SLOT_QUIVER or slot == ItemTable.SLOT_CAPE:
			assert_eq(worn[slot], "", "the %s slot is empty" % slot)
			continue
		assert_eq(ItemTable.tier(worn[slot]), ItemTable.TIER_STEEL, "the %s worn is steel" % slot)
	for kind in ["steel_axe", "steel_pickaxe", "fishing_rod", "steel_sword", "steel_bow", "steel_staff"]:
		var carried := H.pack_count(sim, kind) + (1 if worn.values().has(kind) else 0)
		assert_eq(carried, 1, "%s is worn or carried" % kind)
	assert_true(H.pack_count(sim, "arrows") > 0, "arrows for the bow")
	assert_true(H.pack_count(sim, "frost_shards") > 0, "frost shards for the staff")
	assert_eq(H.pack_count(sim, "logs"), Sim.FIELD_FIRE_LOGS, "logs for one field fire")
	assert_false(sim.is_overweight(), "the kit is within the carry limit")


func test_every_upgrade_is_built_and_the_stash_is_full() -> void:
	var sim := _imported()
	for id in UpgradeTable.ids():
		assert_true((sim.state["upgrades"] as Array).has(id), "%s is built" % id)
	assert_eq(sim.state["stash"]["capacity"], 20)
	for slot in sim.state["stash"]["slots"]:
		assert_true(slot != null, "no stash slot is empty")


func test_the_ring_two_gate_is_open_and_every_waystone_is_attuned_and_awake() -> void:
	var sim := _imported()
	assert_true(sim.ring_gate_open("ring_two_gate"), "the ring-two gate stands open")
	assert_true((sim.state["rings_reached"] as Array).has(WorldDef.REGION_RING_TWO))
	for id in sim.world.objects_of_kind(WorldDef.KIND_WAYSTONE):
		assert_true((sim.state["waystones"] as Array).has(id), "%s is attuned" % id)


func test_warmth_and_health_are_full_and_hints_are_off() -> void:
	var sim := _imported()
	assert_eq(sim.state["warmth"], Sim.WARMTH_MAX)
	assert_eq(sim.state["health"], Sim.HEALTH_MAX)
	assert_false(sim.state["guide"]["on"], "hints are off")


func test_nothing_is_left_to_build() -> void:
	var sim := _imported()
	var result := sim.command(Vocab.BUILD, {"upgrade": "forge"})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_ALREADY_BUILT)


func test_both_stored_hashes_stand_for_the_same_maxed_save() -> void:
	var full := FieldKit.code()
	assert_eq(FieldKit.for_digest(FieldKit.SHORT_HASH), full, "the short code is the test-mode code")
	assert_eq(FieldKit.for_digest(FieldKit.QUERY_HASH), full, "the link is the test-mode code")
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.for_digest(FieldKit.SHORT_HASH)})
	assert_true(result["ok"], "the short code imports: %s" % result["reason"])
	assert_eq(sim.snapshot(), _imported().snapshot(), "it loads the same character")
	assert_eq(sim.state["skills"][SkillTable.NAMES[0]]["level"], SkillTable.MAX_LEVEL)


func test_typed_text_is_matched_without_its_case_or_surrounding_whitespace() -> void:
	assert_eq(FieldKit.normalise("  Hoar Frost7\n"), "hoar frost7")
	assert_eq(FieldKit.normalise("\tABC "), FieldKit.normalise("abc"))
	assert_eq(FieldKit.normalise("abc"), "abc", "a code already lower-case stands as it is")


func test_any_other_code_passes_through_untouched() -> void:
	for typed in ["", "test", "not a code", "Rk18MTB8"]:
		assert_eq(FieldKit.expand(typed), typed, "%s is left alone" % typed)
	assert_eq(FieldKit.for_digest("".sha256_text()), "", "an unknown digest stands for nothing")
	assert_eq(FieldKit.for_digest(""), "")


func test_no_page_and_no_other_query_asks_for_a_save() -> void:
	assert_eq(FieldKit.page_code(), "", "off the web no page asks for it")
	assert_eq(FieldKit.for_query(""), "")
	assert_eq(FieldKit.for_query("?hearth=wax"), "", "any other query asks for nothing")
	assert_eq(FieldKit.for_query("?x=1&y=2"), "")


func test_the_ring_two_spot_stands_the_same_character_in_ring_two() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.for_digest(FieldKit.QUERY_HASH, null, FieldKit.RING_SPOTS["two"])})
	assert_true(result["ok"], "the ring-two link imports: %s" % result["reason"])
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO)
	assert_eq(sim.state["player"]["pos"], FieldKit.RING_SPOTS["two"])
	assert_true(sim.near_fire(), "the character stands within reach of the ring-two brazier")
	var spot: Array = FieldKit.RING_SPOTS["two"]
	assert_true(sim.world.is_walkable(Vector2(spot[0], spot[1])), "the spot is not in a footprint")
	var snap := sim.snapshot()
	var home := _imported().snapshot()
	snap.erase("player")
	home.erase("player")
	assert_eq(snap, home, "everything but where the character stands is the test-mode save")


func test_the_ring_parameter_alone_or_beside_another_character_changes_nothing() -> void:
	var spot: Array = FieldKit.RING_SPOTS["two"]
	assert_eq(FieldKit.for_query("?ring=two"), "", "without the query pair it asks for nothing")
	assert_eq(FieldKit.for_digest(FieldKit.BARE_QUERY_HASH, null, spot), FieldKit.bare_code(), "the build-from-scratch link ignores it")
	assert_eq(FieldKit.for_digest(FieldKit.GEAR_QUERY_HASH, null, spot), FieldKit.gear_code(), "the all-gear link ignores it")
