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


func test_the_inner_ring_has_trees_rocks_and_two_fishing_holes() -> void:
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
			# The mine's copper and tin are ordinary rocks; it pays because six stand together.
			if kind not in [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK]:
				assert_eq(tier, 2, "%s in ring one is a better node" % id)
		else:
			assert_eq(region, WorldDef.REGION_RING_TWO, "%s is in a ring" % id)
			assert_eq(tier, 3, "%s in ring two is a third-tier node" % id)
	assert_true(int(inner.get(WorldDef.KIND_TREE, 0)) >= 6, "trees")
	assert_true(int(inner.get(WorldDef.KIND_COPPER_ROCK, 0)) >= 2, "copper rocks")
	assert_true(int(inner.get(WorldDef.KIND_TIN_ROCK, 0)) >= 2, "tin rocks")
	assert_eq(int(inner.get(WorldDef.KIND_FISHING_HOLE, 0)), 2, "two fishing holes")


## Ids of the inner ring's nodes of `kind`.
func _inner(w: WorldDef, kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in w.objects_of_kind(kind):
		if w.region_at(w.object_center(id)) == WorldDef.REGION_INNER_RING:
			out.append(id)
	return out


func test_the_inner_ring_has_a_copper_and_tin_spot_on_each_side() -> void:
	var w := WorldDefScript.outpost()
	var copper := _inner(w, WorldDef.KIND_COPPER_ROCK)
	var tin := _inner(w, WorldDef.KIND_TIN_ROCK)
	assert_eq(copper.size(), 4, "four copper rocks")
	assert_eq(tin.size(), 4, "four tin rocks")
	var sides := {}
	var paired := {}
	for id in copper:
		var at := w.object_center(id)
		# Its spot is the tin rock nearest it, a step away; every tin rock belongs to one spot.
		var nearest := ""
		for other in tin:
			if nearest == "" or at.distance_to(w.object_center(other)) < at.distance_to(w.object_center(nearest)):
				nearest = other
		assert_true(at.distance_to(w.object_center(nearest)) < 5.0, "%s stands in a spot with %s" % [id, nearest])
		assert_false(paired.has(nearest), "%s is in one spot only" % nearest)
		paired[nearest] = true
		var side := ""
		for rock in [id, nearest]:
			var reach := w.object_center(rock).length()
			assert_true(reach >= 15.0 and reach <= 22.0, "%s stands 15 to 22 m out (%.1f)" % [rock, reach])
			var d := w.object_center(rock)
			var rock_side := ("east" if d.x > 0.0 else "west") if absf(d.x) > absf(d.y) else ("south" if d.y > 0.0 else "north")
			assert_true(side == "" or side == rock_side, "%s's spot keeps to one side" % id)
			side = rock_side
		sides[side] = true
	assert_eq(sides.size(), 4, "one spot per compass side")


func test_no_copper_or_tin_stands_against_the_outpost_walls() -> void:
	var w := WorldDefScript.outpost()
	for id in _inner(w, WorldDef.KIND_COPPER_ROCK) + _inner(w, WorldDef.KIND_TIN_ROCK):
		var o: Dictionary = w.objects[id]
		for s in w.solids:
			if s["kind"] != WorldDef.KIND_WALL:
				continue
			# The gap between the two footprints, along whichever axis they are apart on.
			var gap := maxf(
				maxf(float(s["min"][0]) - float(o["max"][0]), float(o["min"][0]) - float(s["max"][0])),
				maxf(float(s["min"][1]) - float(o["max"][1]), float(o["min"][1]) - float(s["max"][1])))
			assert_true(gap >= 5.0, "%s keeps clear of %s (%.1f m)" % [id, s["id"], gap])


func test_the_inner_rings_ore_and_fish_are_out_of_earshot_of_every_enemy() -> void:
	var w := WorldDefScript.outpost()
	var ids := _inner(w, WorldDef.KIND_COPPER_ROCK) + _inner(w, WorldDef.KIND_TIN_ROCK) + _inner(w, WorldDef.KIND_FISHING_HOLE)
	for id in ids:
		for enemy in w.enemies:
			var home := Vector2(w.enemies[enemy]["home"][0], w.enemies[enemy]["home"][1])
			assert_true(w.distance_to_object(id, home) > CombatTable.NOISE_GATHER, "%s is out of %s's earshot" % [id, enemy])
			# Nor can it be heard from where the player stands to gather it.
			for cell in w.approach_cells(id):
				assert_true(w.cell_center(cell).distance_to(home) > CombatTable.NOISE_GATHER, "%s's every side is out of %s's earshot" % [id, enemy])


func test_the_inner_rings_fishing_holes_lie_together() -> void:
	var w := WorldDefScript.outpost()
	var holes := _inner(w, WorldDef.KIND_FISHING_HOLE)
	assert_eq(holes.size(), 2)
	assert_true(w.object_center(holes[0]).distance_to(w.object_center(holes[1])) < 5.0, "the two holes are one spot")


func test_mining_an_inner_ring_spot_wakes_no_enemy() -> void:
	var w := WorldDefScript.outpost()
	for id in _inner(w, WorldDef.KIND_COPPER_ROCK) + _inner(w, WorldDef.KIND_TIN_ROCK):
		var sim := SimScript.new()
		var snap := sim.snapshot()
		snap["inventory"]["equipment"]["tool"] = "wooden_pickaxe"
		sim.restore(snap)
		H.place(sim, [w.object_center(id).x + 1.5, w.object_center(id).y + 1.5])
		assert_true(sim.command(Vocab.GATHER, {"object_id": id})["ok"], "%s can be mined" % id)
		var events := H.run_until_idle(sim, 400)
		assert_eq(H.of_kind(events, Vocab.EV_NODE_DEPLETED).size(), 1, "%s is mined out" % id)
		assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED), [], "mining %s wakes nobody" % id)


func test_a_save_from_the_old_layout_loads_into_the_new_one() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	# copper_1 stood against the east wall before the spots; the north fishing hole stayed put.
	snap["nodes"]["copper_1"] = {"left": 1, "respawn_tick": 0}
	snap["nodes"].erase("copper_4")
	snap["nodes"].erase("fishing_hole_2")
	snap["nodes"]["fishing_hole"] = {"left": 2, "respawn_tick": 0}
	assert_true(sim.restore(snap))
	assert_false(sim.state["nodes"].has("copper_1"), "a node the layout no longer has is dropped")
	assert_eq(sim.state["nodes"]["fishing_hole"], {"left": 2, "respawn_tick": 0}, "a node that stayed keeps its count")
	assert_eq(sim.state["nodes"].size(), sim.world.node_ids().size(), "every placed node has state")
	for id in sim.world.node_ids():
		if id != "fishing_hole":
			var full := int(WorldDef.NODE_KINDS[sim.world.objects[id]["kind"]]["yield"])
			assert_eq(int(sim.state["nodes"][id]["left"]), full, "%s starts full" % id)


## Ids of ring one's nodes of `kind`.
func _ring_one(w: WorldDef, kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in w.objects_of_kind(kind):
		if w.region_at(w.object_center(id)) == WorldDef.REGION_RING_ONE:
			out.append(id)
	return out


## `ids` grouped into spots: nodes a step apart (under 5 m) stand in the same spot, and a node
## a step from two spots joins them.
func _spots(w: WorldDef, ids: Array[String]) -> Array:
	var spots: Array = []
	for id in ids:
		var joined: Array = [id]
		for spot in spots.duplicate():
			for other in spot:
				if w.object_center(id).distance_to(w.object_center(other)) < 5.0:
					joined.append_array(spot)
					spots.erase(spot)
					break
		spots.append(joined)
	return spots


func _centre(w: WorldDef, spot: Array) -> Vector2:
	var sum := Vector2.ZERO
	for id in spot:
		sum += w.object_center(id)
	return sum / spot.size()


## The compass side of the world's centre `at` lies on.
func _side(at: Vector2) -> String:
	return ("east" if at.x > 0.0 else "west") if absf(at.x) > absf(at.y) else ("south" if at.y > 0.0 else "north")


## How far `at` is from the road south, which runs from the inner ring's edge down to the
## ring-two gate along x = 0.
func _off_road(at: Vector2) -> float:
	return at.distance_to(Vector2(0.0, clampf(at.y, 24.0, 60.0)))


func test_ring_one_has_two_iron_spots_of_two_far_apart() -> void:
	var w := WorldDefScript.outpost()
	var iron := _ring_one(w, WorldDef.KIND_IRON_ROCK)
	assert_eq(iron.size(), 4, "four iron rocks")
	var spots := _spots(w, iron)
	assert_eq(spots.size(), 2, "in two spots")
	var sides := {}
	for spot in spots:
		assert_eq(spot.size(), 2, "%s is a spot of two" % [spot])
		var at := _centre(w, spot)
		var side := _side(at)
		if at.x < 0.0 and at.y > 0.0:
			side = "south-west"
		sides[side] = true
		assert_true(_off_road(at) > 15.0, "%s keeps off the road south" % [spot])
		for id in spot:
			var o: Dictionary = w.objects[id]
			for s in w.solids:
				if s["kind"] != WorldDef.KIND_CLIFF:
					continue
				# The gap between the two footprints, along whichever axis they are apart on.
				var gap := maxf(
					maxf(float(s["min"][0]) - float(o["max"][0]), float(o["min"][0]) - float(s["max"][0])),
					maxf(float(s["min"][1]) - float(o["max"][1]), float(o["min"][1]) - float(s["max"][1])))
				assert_true(gap >= 10.0, "%s keeps clear of %s (%.1f m)" % [id, s["id"], gap])
	assert_eq(sides, {"east": true, "south-west": true}, "one spot east and one south-west")
	assert_true(_centre(w, spots[0]).distance_to(_centre(w, spots[1])) > 40.0, "the two spots are far apart")
	# One sweep of both spots is the winch's iron.
	var ore := 0
	for id in iron:
		ore += int(WorldDef.NODE_KINDS[WorldDef.KIND_IRON_ROCK]["yield"])
	assert_eq(ore, int(UpgradeTable.get_upgrade("ring_two_gate")["cost"]["iron_ore"]), "a sweep of both spots pays for the winch")


func test_ring_one_has_three_ice_hole_spots_of_two_off_the_road() -> void:
	var w := WorldDefScript.outpost()
	var holes := _ring_one(w, WorldDef.KIND_ICE_HOLE)
	assert_eq(holes.size(), 6, "six ice holes")
	var spots := _spots(w, holes)
	assert_eq(spots.size(), 3, "in three spots")
	var sides := {}
	for spot in spots:
		assert_eq(spot.size(), 2, "%s is a spot of two" % [spot])
		var at := _centre(w, spot)
		sides[_side(at)] = true
		assert_true(_off_road(at) > 20.0, "%s keeps well off the road south" % [spot])
		if "ice_hole" in spot:
			assert_eq(_side(at), "north", "the old hole is in the north spot")
	assert_eq(sides, {"north": true, "east": true, "west": true}, "one spot north, east and west")


## Ring one's copper and tin rocks: the mine's.
func _mine(w: WorldDef) -> Array[String]:
	return _ring_one(w, WorldDef.KIND_COPPER_ROCK) + _ring_one(w, WorldDef.KIND_TIN_ROCK)


func test_ring_one_has_a_mine_of_copper_and_tin_against_the_west_cliff() -> void:
	var w := WorldDefScript.outpost()
	assert_eq(_ring_one(w, WorldDef.KIND_COPPER_ROCK).size(), 3, "three copper rocks")
	assert_eq(_ring_one(w, WorldDef.KIND_TIN_ROCK).size(), 3, "three tin rocks")
	var spots := _spots(w, _mine(w))
	assert_eq(spots.size(), 1, "ring one's copper and tin stand together, and nowhere else")
	assert_eq(_side(_centre(w, spots[0])), "west", "the mine is on the west side")
	var cliff: Dictionary = {}
	for s in w.solids:
		if s["id"] == "cliff_west":
			cliff = s
	for id in _mine(w):
		var gap := float(w.objects[id]["min"][0]) - float(cliff["max"][0])
		assert_true(gap <= 8.0, "%s stands against the west cliff (%.1f m)" % [id, gap])
	# One visit empties it: twelve of each ore.
	for kind in [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK]:
		assert_eq(3 * int(WorldDef.NODE_KINDS[kind]["yield"]), 12, "a visit brings back 12 %s ore" % kind)


func test_witch_2_hears_anyone_mining_the_mine() -> void:
	var w := WorldDefScript.outpost()
	var home := Vector2(w.enemies["witch_2"]["home"][0], w.enemies["witch_2"]["home"][1])
	for id in _mine(w):
		assert_true(w.distance_to_object(id, home) <= CombatTable.NOISE_GATHER, "%s is within witch 2's earshot" % id)
		# Whichever side the player mines it from.
		for cell in w.approach_cells(id):
			assert_true(w.cell_center(cell).distance_to(home) <= CombatTable.NOISE_GATHER, "%s's every side is within witch 2's earshot" % id)


func test_every_ring_one_group_sits_out_of_earshot_of_the_next() -> void:
	var w := WorldDefScript.outpost()
	for a in w.enemies:
		for b in w.enemies:
			if w.enemies[a]["pack"] == w.enemies[b]["pack"]:
				continue
			var ha: Array = w.enemies[a]["home"]
			var hb: Array = w.enemies[b]["home"]
			if w.region_at(Vector2(ha[0], ha[1])) != WorldDef.REGION_RING_ONE or w.region_at(Vector2(hb[0], hb[1])) != WorldDef.REGION_RING_ONE:
				continue
			var d := Vector2(ha[0], ha[1]).distance_to(Vector2(hb[0], hb[1]))
			assert_true(d > CombatTable.NOISE_FIGHT, "%s and %s are %.1f m apart" % [a, b, d])


func test_mining_a_mine_rock_wakes_witch_2() -> void:
	var w := WorldDefScript.outpost()
	var home := Vector2(w.enemies["witch_2"]["home"][0], w.enemies["witch_2"]["home"][1])
	var heard := 0
	for id in _mine(w):
		var sim := SimScript.new()
		var snap := sim.snapshot()
		snap["inventory"]["equipment"]["tool"] = "wooden_pickaxe"
		sim.restore(snap)
		# From the rock's side farthest from her. Close in she sees the miner first; past her
		# sight she hears the pick.
		var stand := home
		for cell in w.approach_cells(id):
			if w.cell_center(cell).distance_to(home) > stand.distance_to(home):
				stand = w.cell_center(cell)
		H.place(sim, [stand.x, stand.y])
		var events := H.run(sim, 2)
		sim.command(Vocab.GATHER, {"object_id": id})
		events.append_array(H.run(sim, 6))
		var noticed := H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "witch_2")
		assert_eq(noticed.size(), 1, "mining %s wakes witch 2" % id)
		if not noticed.is_empty() and noticed[0]["cause"] == CombatTable.NOTICE_NOISE:
			heard += 1
	assert_true(heard > 0, "some of the mine is out of her sight, and she still hears it")


func test_a_save_from_before_ring_ones_spots_loads() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	# iron_3 stood apart from the east spot and is gone; the old ice hole stayed put.
	snap["nodes"]["iron_3"] = {"left": 1, "respawn_tick": 0}
	snap["nodes"].erase("iron_4")
	snap["nodes"].erase("ice_hole_2")
	snap["nodes"]["ice_hole"] = {"left": 2, "respawn_tick": 0}
	assert_true(sim.restore(snap))
	assert_false(sim.state["nodes"].has("iron_3"), "a node the layout no longer has is dropped")
	assert_eq(sim.state["nodes"]["ice_hole"], {"left": 2, "respawn_tick": 0}, "a node that stayed keeps its count")
	for id in ["iron_4", "ice_hole_2"]:
		var full := int(WorldDef.NODE_KINDS[sim.world.objects[id]["kind"]]["yield"])
		assert_eq(int(sim.state["nodes"][id]["left"]), full, "%s starts full" % id)


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
## from just past its gate, and everything in ring three from just past the ring-three gate.
func test_everything_placed_can_be_reached_from_its_side_of_the_gate() -> void:
	var w := WorldDefScript.outpost()
	var start_of := {
		WorldDef.REGION_RING_TWO: w.cell_of(Vector2(0.5, 64.5)),
		WorldDef.REGION_RING_THREE: w.cell_of(Vector2(-39.5, 130.5)),
	}
	var outpost := w.cell_of(Vector2(w.spawn[0], w.spawn[1]))
	for id in w.objects:
		var from: Vector2i = start_of.get(w.region_at(w.object_center(id)), outpost)
		var reachable := false
		for cell in w.approach_cells(id):
			if not GridPath.find(w, from, cell).is_empty():
				reachable = true
				break
		assert_true(reachable, "%s can be walked to" % id)
	for id in w.enemies:
		var at: Array = w.enemies[id]["home"]
		var home := Vector2(at[0], at[1])
		var from: Vector2i = start_of.get(w.region_at(home), outpost)
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
