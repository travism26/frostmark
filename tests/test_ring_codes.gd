## The ring codes tools/ring_codes.gd prints and tools/test_codes.gd maps: each imports as a
## save of this version, and the ring-one dungeon boss code stands a ring-one character with its
## kit just outside the great frost bear's room, one walk from the fight.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const RingCodes := preload("res://tools/ring_codes.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const BOSS := "ring_one_dungeon_boss"
const BOSS_CODE := "ring_one_dungeon_boss"


func _imported(code: String) -> Sim:
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": code})
	assert_true(result["ok"], "the code imports: %s" % result.get("reason", ""))
	return sim


func test_every_ring_code_imports_where_it_says() -> void:
	var codes := RingCodes.codes()
	for name in RingCodes.SPOTS:
		assert_eq(_imported(codes[name]).state["player"]["pos"], RingCodes.SPOTS[name], "%s stands on its spot" % name)
	assert_eq(_imported(codes["ring_one_cold"]).state["warmth"], RingCodes.COLD_WARMTH, "the cold code is cold")
	assert_true(codes.has(BOSS_CODE), "and there is a boss code")


func test_the_boss_code_stands_just_outside_the_bears_room_out_of_its_sight() -> void:
	var sim := _imported(RingCodes.codes()[BOSS_CODE])
	var at := sim.player_pos()
	var room: Array = WorldDef.DUNGEONS["ring_one_dungeon"]["reserved"]["boss_room"]
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE_DUNGEON, "inside the dungeon")
	assert_false(WorldDef.in_boss_room(BOSS, at), "outside the bear's room")
	var nearest := Vector2(clampf(at.x, room[0][0], room[1][0]), clampf(at.y, room[0][1], room[1][1]))
	assert_true(at.distance_to(nearest) < 5.0, "a few steps from it (%.1f m)" % at.distance_to(nearest))
	assert_eq(sim.state["dungeons_reached"], ["ring_one_dungeon"], "with the dungeon already reached")
	assert_eq(sim.state["enemies"][BOSS]["kind"], "great_frost_bear")
	var events := H.run(sim, 10)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED).size(), 0, "nothing notices it where it stands")


func test_the_boss_code_carries_the_ring_one_kit() -> void:
	var sim := _imported(RingCodes.codes()[BOSS_CODE])
	var worn: Dictionary = sim.state["inventory"]["equipment"]
	for slot in ItemTable.ARMOUR_SLOTS:
		assert_eq(ItemTable.tier(worn[slot]), ItemTable.TIER_IRON, "iron %s worn" % slot)
	assert_eq(worn["weapon"], "iron_staff", "a staff in hand")
	assert_eq(sim.player_style(), CombatTable.STYLE_MAGIC, "so it opens with the edge on the bear")
	assert_true(H.pack_count(sim, "frost_shards") > 0, "shards for the staff")
	assert_true(H.pack_count(sim, "cooked_trout") > 0, "food")
	for fur in ["fur_hood", "fur_coat", "fur_legs"]:
		assert_true(ItemTable.warmth(fur) > 0 and H.pack_count(sim, fur) == 1, "warm fur: a %s" % fur)
	for skill in [SkillTable.MELEE, SkillTable.RANGED, SkillTable.MAGIC]:
		assert_eq(sim.skill_level(skill), RingCodes.BOSS_LEVEL, "%s at a ring-one level" % skill)
	assert_true(sim.skill_level(SkillTable.MAGIC) < SkillTable.MAX_LEVEL, "not the maxed character")


func test_one_walk_into_the_room_starts_the_bear_fight() -> void:
	var sim := _imported(RingCodes.codes()[BOSS_CODE])
	var home: Array = sim.world.enemies[BOSS]["home"]
	sim.drain_events()
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [home[0] + 3.0, home[1] + 4.0]})["ok"], "the room is reached from the spot")
	var events := H.run(sim, 20)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", BOSS).size(), 1, "the bear turns to fight")
	assert_eq(sim.state["enemies"][BOSS]["mode"], Sim.MODE_ENGAGED)
