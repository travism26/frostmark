## The world as rings: a safe inner ring, ring one's enemies and better nodes, the ring-two
## gate at the far edge with the captain at it, ring two's ruins beyond it, and field fires.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")


func test_the_inner_ring_has_no_enemies() -> void:
	var w := WorldDefScript.outpost()
	var count := {}
	for id in w.enemies:
		var home: Array = w.enemies[id]["home"]
		var region := w.region_at(Vector2(home[0], home[1]))
		assert_true(region in [WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_TWO], "%s lives out in a ring" % id)
		count[region] = int(count.get(region, 0)) + 1
	assert_true(int(count.get(WorldDef.REGION_RING_ONE, 0)) >= 10, "ring one is populated")
	assert_true(int(count.get(WorldDef.REGION_RING_TWO, 0)) >= 6, "ring two is populated")


func test_the_inner_ring_has_trees_rocks_and_one_fishing_hole() -> void:
	var w := WorldDefScript.outpost()
	var inner := {}
	for id in w.node_ids():
		var kind: String = w.objects[id]["kind"]
		var region := w.region_at(w.object_center(id))
		var tier := int(WorldDef.NODE_KINDS[kind]["tier"])
		if region == WorldDef.REGION_INNER_RING:
			inner[kind] = int(inner.get(kind, 0)) + 1
			assert_eq(tier, 1, "%s in the inner ring is a first-tier node" % id)
		elif region == WorldDef.REGION_RING_ONE:
			assert_eq(tier, 2, "%s in ring one is a better node" % id)
		else:
			assert_eq(region, WorldDef.REGION_RING_TWO, "%s is in a ring" % id)
			assert_eq(tier, 3, "%s in ring two is a third-tier node" % id)
	assert_true(int(inner.get(WorldDef.KIND_TREE, 0)) >= 6, "trees")
	assert_true(int(inner.get(WorldDef.KIND_COPPER_ROCK, 0)) >= 2, "copper rocks")
	assert_true(int(inner.get(WorldDef.KIND_TIN_ROCK, 0)) >= 2, "tin rocks")
	assert_eq(int(inner.get(WorldDef.KIND_FISHING_HOLE, 0)), 1, "one fishing hole")


func test_better_nodes_need_more_skill_and_pay_more() -> void:
	var pairs := [
		[WorldDef.KIND_TREE, WorldDef.KIND_FROST_PINE],
		[WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_IRON_ROCK],
		[WorldDef.KIND_FISHING_HOLE, WorldDef.KIND_ICE_HOLE],
		[WorldDef.KIND_IRON_ROCK, WorldDef.KIND_COAL_ROCK],
		[WorldDef.KIND_IRON_ROCK, WorldDef.KIND_RICH_IRON_ROCK],
		[WorldDef.KIND_ICE_HOLE, WorldDef.KIND_DEEP_HOLE],
	]
	for pair in pairs:
		var basic: Dictionary = WorldDef.NODE_KINDS[pair[0]]
		var better: Dictionary = WorldDef.NODE_KINDS[pair[1]]
		assert_eq(basic["skill"], better["skill"])
		assert_true(int(better["level"]) > int(basic["level"]), "%s needs a higher level" % pair[1])
		assert_true(int(better["xp"]) > int(basic["xp"]), "%s pays more experience" % pair[1])


func test_the_ring_two_gate_is_at_the_far_edge_with_the_captain() -> void:
	var w := WorldDefScript.outpost()
	var gate: Dictionary = w.objects["ring_two_gate"]
	assert_eq(gate["kind"], WorldDef.KIND_RING_GATE)
	assert_true(gate["blocks"], "barred: nothing walks through it")
	var at := w.object_center("ring_two_gate")
	assert_true(at.length() > 55.0, "at ring one's far edge")
	assert_eq(w.enemies[gate["guardian"]]["kind"], "bandit_captain")
	var home: Array = w.enemies[gate["guardian"]]["home"]
	assert_true(Vector2(home[0], home[1]).distance_to(at) < 6.0, "the captain stands at the gate")


## Everything nearer than the ring-two gate is walked to from the outpost; everything in ring two
## from just past the gate.
func test_everything_placed_can_be_reached_from_its_side_of_the_gate() -> void:
	var w := WorldDefScript.outpost()
	var outpost := w.cell_of(Vector2(w.spawn[0], w.spawn[1]))
	var beyond := w.cell_of(Vector2(0.5, 64.5))
	for id in w.objects:
		var from := beyond if w.region_at(w.object_center(id)) == WorldDef.REGION_RING_TWO else outpost
		var reachable := false
		for cell in w.approach_cells(id):
			if not GridPath.find(w, from, cell).is_empty():
				reachable = true
				break
		assert_true(reachable, "%s can be walked to" % id)
	for id in w.enemies:
		var at: Array = w.enemies[id]["home"]
		var home := Vector2(at[0], at[1])
		var from := beyond if w.region_at(home) == WorldDef.REGION_RING_TWO else outpost
		assert_false(GridPath.find(w, from, w.cell_of(home)).is_empty(), "%s's home can be walked to" % id)


func test_ring_one_is_reached_through_the_inner_ring() -> void:
	var sim := SimScript.new()
	var events := H.walk_to(sim, [-30.5, 40.5])
	var regions: Array = []
	for e in H.of_kind(events, Vocab.EV_REGION_CHANGED):
		regions.append(e["to"])
	assert_eq(regions, [WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE])


func test_warmth_drains_in_both_rings() -> void:
	for spot in [H.OUTSIDE, [30.5, 30.5]]:
		var sim := SimScript.new()
		H.place(sim, spot)
		H.run(sim, 5)
		assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX - 5 * Sim.WARMTH_DRAIN, "cold at %s" % [spot])


# --- Field fires ------------------------------------------------------------------------

func test_a_field_fire_burns_logs_restores_warmth_and_goes_out() -> void:
	var sim := SimScript.new()
	H.place(sim, [30.5, -10.5])
	H.set_pack(sim, [{"item": "logs", "count": 5}])
	H.patch(sim, {"warmth": 50})
	assert_false(sim.near_fire())
	assert_true(sim.command(Vocab.LIGHT_FIRE)["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.pack_count(sim, "logs"), 5 - Sim.FIELD_FIRE_LOGS, "the logs are burnt")
	var lit := H.of_kind(events, Vocab.EV_FIRE_LIT)
	assert_eq(lit.size(), 1)
	assert_eq(sim.state["fires"].size(), 1)
	assert_true(sim.near_fire(), "standing by it")
	assert_eq(int(sim.state["warmth"]), 50 + Sim.FIRE_WARMTH, "it warms the tick it is lit")
	H.run(sim, 20)
	assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX, "full again")
	var rest := H.run(sim, Sim.FIELD_FIRE_TICKS)
	var out := H.of_kind(rest, Vocab.EV_FIRE_OUT)
	assert_eq(out.size(), 1, "it goes out")
	assert_eq(out[0]["fire_id"], lit[0]["fire_id"])
	assert_eq(sim.state["fires"].size(), 0)
	assert_false(sim.near_fire())
	var before := int(sim.state["warmth"])
	H.run(sim, 3)
	assert_eq(int(sim.state["warmth"]), before - 3 * Sim.WARMTH_DRAIN, "the cold is back")


func test_a_field_fire_needs_logs_and_the_open_wild() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 9}])
	assert_eq(sim.command(Vocab.LIGHT_FIRE)["reason"], Vocab.REASON_IN_OUTPOST, "the outpost has its own fire")
	H.place(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": Sim.FIELD_FIRE_LOGS - 1}])
	assert_eq(sim.command(Vocab.LIGHT_FIRE)["reason"], Vocab.REASON_MISSING_INPUTS)


func test_clicking_a_field_fire_walks_to_it() -> void:
	var sim := SimScript.new()
	H.place(sim, [30.5, -10.5])
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	sim.command(Vocab.LIGHT_FIRE)
	var lit := H.of_kind(H.run(sim, 1), Vocab.EV_FIRE_LIT)
	H.walk_to(sim, [38.5, -10.5])
	assert_false(sim.near_fire())
	assert_true(sim.command(Vocab.INTERACT, {"object_id": lit[0]["fire_id"]})["ok"])
	var events := H.run_until_idle(sim, 20)
	var interacted := H.of_kind(events, Vocab.EV_INTERACTED)
	assert_eq(interacted.size(), 1)
	assert_eq(interacted[0]["action"], Vocab.ACTION_WARM)
	assert_true(sim.near_fire())


func test_field_fires_survive_a_save() -> void:
	var sim := SimScript.new()
	H.place(sim, [30.5, -10.5])
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	sim.command(Vocab.LIGHT_FIRE)
	H.run(sim, 1)
	var other := SimScript.new()
	assert_true(other.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_eq(other.state["fires"], sim.state["fires"])
	assert_true(other.near_fire())
