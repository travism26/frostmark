## The test-mode code (docs/testing.md): the save code scenes/field_kit.gd builds imports into
## this build and gives the maxed character it promises. It is built here rather than read from
## a committed file, so it is always of this build. The short code and the page's query pair
## stand for the same save.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const SHORT_CODE := "PELTKEG7"
const QUERY_PAIR := "hearth=tallow"


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
	for slot in ItemTable.EQUIPMENT_SLOTS:
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


func test_the_short_code_expands_to_the_same_maxed_save() -> void:
	var full := FieldKit.code()
	assert_eq(FieldKit.expand(SHORT_CODE), full, "the short code is the test-mode code")
	assert_eq(FieldKit.expand("  peltkeg7\n"), full, "case and spacing do not matter")
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.expand(SHORT_CODE)})
	assert_true(result["ok"], "the short code imports: %s" % result["reason"])
	assert_eq(sim.snapshot(), _imported().snapshot(), "it loads the same character")
	assert_eq(sim.state["skills"][SkillTable.NAMES[0]]["level"], SkillTable.MAX_LEVEL)


func test_any_other_code_passes_through_untouched() -> void:
	for typed in ["", "peltkeg", "PELTKEG77", "test", "not a code"]:
		assert_eq(FieldKit.expand(typed), typed, "%s is left alone" % typed)


func test_the_query_pair_matches_its_hash() -> void:
	assert_eq(QUERY_PAIR.sha256_text(), FieldKit.QUERY_HASH)
	assert_eq(FieldKit.page_code(), "", "off the web no page asks for it")
	var full := FieldKit.code()
	assert_eq(FieldKit.for_query("?" + QUERY_PAIR), full, "the query pair asks for the test-mode code")
	assert_eq(FieldKit.for_query("?x=1&" + QUERY_PAIR), full, "beside other parameters too")
	assert_eq(FieldKit.for_query("?hearth=wax"), "", "any other query asks for nothing")


func test_the_ring_two_parameter_stands_the_same_character_in_ring_two() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.for_query("?" + QUERY_PAIR + "&ring=two")})
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
	assert_eq(FieldKit.for_query("?ring=two&" + QUERY_PAIR), FieldKit.for_query("?" + QUERY_PAIR + "&ring=two"), "in either order")


func test_the_ring_parameter_alone_or_unknown_changes_nothing() -> void:
	var full := FieldKit.code()
	assert_eq(FieldKit.for_query("?ring=two"), "", "without the query pair it asks for nothing")
	assert_eq(FieldKit.for_query("?" + QUERY_PAIR + "&ring=nine"), full, "an unknown ring is the outpost")
	assert_eq(FieldKit.for_query("?hearth=kindling&ring=two"), FieldKit.bare_code(), "the build-from-scratch link ignores it")
