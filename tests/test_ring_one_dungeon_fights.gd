## What lies between the ring-one dungeon's mouth and its boss: one fire just inside the mouth,
## four groups of ring-one enemy kinds each on their own, and two iron rocks reached only past a
## fight. Everything stands on the layout the dungeon table reserved.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

const DUNGEON := "ring_one_dungeon"
const INSIDE := [66.5, -47.0]


func _spot(at: Array) -> Vector2:
	return Vector2(at[0], at[1])


func _dungeon_enemies() -> Array:
	var ids := []
	for id in WorldDefScript.outpost().enemies:
		if id.begins_with("dungeon_"):
			ids.append(id)
	return ids


func _home(w: WorldDef, id: String) -> Vector2:
	return _spot(w.enemies[id]["home"])


## The longest sight of any ring-one kind, or a fight's noise if that is farther.
func _apart() -> float:
	var apart := CombatTable.NOISE_FIGHT
	for kind in ["wolf", "bandit_archer", "frost_witch"]:
		apart = maxf(apart, float(CombatTable.enemy(kind)["sight"]))
	return apart


# --- The fire -----------------------------------------------------------------------------

func test_the_dungeons_fire_stands_just_inside_the_mouth_and_is_the_only_one() -> void:
	var w := WorldDefScript.outpost()
	var fire_id: String = WorldDef.DUNGEONS[DUNGEON]["fire"]
	assert_eq(w.objects[fire_id]["kind"], WorldDef.KIND_FIRE, "an ordinary fire")
	assert_true(w.distance_to_object(WorldDef.DUNGEONS[DUNGEON]["mouth"], _spot(WorldDef.DUNGEONS[DUNGEON]["reserved"]["fire"])) < 10.0, "a few metres in")
	var inside := []
	for id in w.objects:
		var o: Dictionary = w.objects[id]
		var mid := Vector2((o["min"][0] + o["max"][0]) / 2.0, (o["min"][1] + o["max"][1]) / 2.0)
		if o["kind"] == WorldDef.KIND_FIRE and w.region_at(mid) == WorldDef.REGION_RING_ONE_DUNGEON:
			inside.append(id)
	assert_eq(inside, [fire_id], "no other fire in the dungeon")


func test_the_fire_warms_and_heals_within_reach() -> void:
	var sim := SimScript.new()
	var at: Array = WorldDef.DUNGEONS[DUNGEON]["reserved"]["fire"]
	H.place(sim, [at[0], at[1] + 2.0])
	H.patch(sim, {"warmth": 100, "health": 5})
	assert_true(sim.near_fire(), "within the usual reach")
	H.run(sim, 3)
	assert_true(int(sim.state["warmth"]) > 100, "it warms")
	assert_true(int(sim.state["health"]) > 5, "and heals")
	H.place(sim, [at[0] + Sim.FIRE_REACH + 2.0, at[1] + 2.0])
	assert_false(sim.near_fire(), "but not beyond it")


func test_the_cold_warning_fires_inside() -> void:
	var sim := SimScript.new()
	H.place(sim, [86.5, -19.5])
	H.patch(sim, {"warmth": GuideTable.COLD_WARMTH + 2})
	var tips := 0
	for e in H.run(sim, 4):
		if e["kind"] == Vocab.EV_TIP and e["tip"] == "cold":
			tips += 1
	assert_eq(tips, 1, "the cold tip fires as in a ring")


# --- The fights ---------------------------------------------------------------------------

func test_three_or_four_groups_of_ring_one_kinds_stand_inside() -> void:
	var w := WorldDefScript.outpost()
	var ids := _dungeon_enemies()
	assert_true(ids.size() >= 3, "enemies stand inside")
	var packs := {}
	for id in ids:
		assert_true(["wolf", "bandit_archer"].has(w.enemies[id]["kind"]), "%s is a ring-one kind" % id)
		assert_eq(w.region_at(_home(w, id)), WorldDef.REGION_RING_ONE_DUNGEON, "%s is at home inside" % id)
		packs[w.enemies[id]["pack"]] = true
	assert_true(packs.size() >= 3 and packs.size() <= 4, "three or four groups")


func test_every_group_is_out_of_sight_and_earshot_of_every_other_and_of_the_fire() -> void:
	var w := WorldDefScript.outpost()
	var fire := _spot(WorldDef.DUNGEONS[DUNGEON]["reserved"]["fire"])
	var ids := _dungeon_enemies()
	for i in ids.size():
		assert_true(_home(w, ids[i]).distance_to(fire) > _apart(), "%s is out of the fire's sight" % ids[i])
		for j in range(i + 1, ids.size()):
			if w.enemies[ids[i]]["pack"] != w.enemies[ids[j]]["pack"]:
				assert_true(_home(w, ids[i]).distance_to(_home(w, ids[j])) > _apart(), "%s and %s are apart" % [ids[i], ids[j]])


func test_every_enemy_home_is_reached_from_inside() -> void:
	var w := WorldDefScript.outpost()
	var from := w.cell_of(_spot(INSIDE))
	for id in _dungeon_enemies():
		assert_true(w.is_walkable_with_margin(_home(w, id), 1.0), "%s has open ground round it" % id)
		assert_true(GridPath.find(w, from, w.cell_of(_home(w, id))).size() > 0, "%s is reached" % id)


func test_a_dungeon_enemy_comes_back_as_ring_ones_do() -> void:
	var sim := SimScript.new()
	var id: String = _dungeon_enemies()[0]
	var kind: String = sim.world.enemies[id]["kind"]
	H.place(sim, [80.5, -19.5])
	H.patch_enemy(sim, id, {"mode": Sim.MODE_DEAD, "health": 0, "respawn_in": int(CombatTable.enemy(kind)["respawn_ticks"])})
	var events := H.run(sim, int(CombatTable.enemy(kind)["respawn_ticks"]) + 2)
	assert_eq(H.where(events, Vocab.EV_ENEMY_RESPAWNED, "enemy_id", id).size(), 1, "back at home")


# --- The nodes ----------------------------------------------------------------------------

func test_one_or_two_tier_two_nodes_stand_inside_each_reached_only_past_a_fight() -> void:
	var w := WorldDefScript.outpost()
	var nodes := []
	for id in w.objects:
		var o: Dictionary = w.objects[id]
		var mid := Vector2((o["min"][0] + o["max"][0]) / 2.0, (o["min"][1] + o["max"][1]) / 2.0)
		if WorldDef.NODE_KINDS.has(o["kind"]) and w.region_at(mid) == WorldDef.REGION_RING_ONE_DUNGEON:
			assert_eq(int(WorldDef.NODE_KINDS[o["kind"]]["tier"]), 2, "%s is tier two" % id)
			nodes.append(id)
	assert_true(nodes.size() >= 1 and nodes.size() <= 2, "one or two nodes")
	var from := w.cell_of(_spot(INSIDE))
	for id in nodes:
		var o: Dictionary = w.objects[id]
		var mid := Vector2((o["min"][0] + o["max"][0]) / 2.0, (o["min"][1] + o["max"][1]) / 2.0)
		var path := GridPath.find(w, w.cell_of(_spot(INSIDE)), w.cell_of(mid + Vector2(0.0, 1.6)))
		assert_true(path.size() > 0, "%s is reached from inside" % id)
		var passed := false
		for c in path:
			for eid in _dungeon_enemies():
				if w.cell_center(c).distance_to(_home(w, eid)) <= float(CombatTable.enemy(w.enemies[eid]["kind"])["sight"]):
					passed = true
		assert_true(passed, "the way to %s passes a fight" % id)
