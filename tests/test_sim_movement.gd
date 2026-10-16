## Movement through the simulation's command interface: move_to, snapping, routing.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const WorldDefScript := preload("res://sim/world_def.gd")
const Vocab := preload("res://sim/vocab.gd")


func _events_of(sim: Sim, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.drain_events():
		if e["kind"] == kind:
			out.append(e)
	return out


## Steps until the player arrives or `max_ticks` pass; returns the ticks taken (-1 if never).
func _ticks_to_arrive(sim: Sim, max_ticks: int) -> int:
	for i in range(1, max_ticks + 1):
		sim.step()
		for e in sim.drain_events():
			if e["kind"] == Vocab.EV_ARRIVED:
				return i
	return -1


func test_move_reaches_target_in_expected_ticks() -> void:
	var sim := SimScript.new()
	var start := sim.player_pos()
	var target := start + Vector2(6.0, 0.0)  # open floor east of the spawn, inside the walls
	var result := sim.command(Vocab.MOVE_TO, {"pos": [target.x, target.y]})
	assert_true(result["ok"], "move_to accepted: %s" % result["reason"])
	assert_eq(_events_of(sim, Vocab.EV_PATH_SET).size(), 1, "path_set emitted")
	var expected := int(ceil(6.0 / Sim.WALK_PER_TICK))
	sim.step()
	assert_true(sim.is_moving(), "still walking after one tick")
	var remaining := _ticks_to_arrive(sim, 20)
	assert_eq(remaining + 1, expected, "arrives after %d ticks" % expected)
	assert_almost_eq(sim.player_pos().distance_to(target), 0.0, 0.001, "stops exactly on the click")
	assert_false(sim.is_moving(), "idle after arrival")
	assert_eq(sim.state["tick"], expected)


func test_moved_events_cover_the_whole_walk() -> void:
	var sim := SimScript.new()
	var target := sim.player_pos() + Vector2(0.0, -3.0)  # north, stopping short of the fire
	assert_true(sim.world.is_walkable(target))
	sim.command(Vocab.MOVE_TO, {"pos": [target.x, target.y]})
	var walked := 0.0
	var last := sim.player_pos()
	for i in 10:
		sim.step()
		for e in sim.drain_events():
			if e["kind"] == Vocab.EV_MOVED:
				assert_eq(e["from"], [last.x, last.y], "moved.from continues from the last position")
				var prev := Vector2(e["path"][0][0], e["path"][0][1])
				for p in e["path"].slice(1):
					var q := Vector2(p[0], p[1])
					walked += prev.distance_to(q)
					prev = q
				last = Vector2(e["to"][0], e["to"][1])
				assert_eq(e["path"][e["path"].size() - 1], e["to"], "path ends at moved.to")
	assert_almost_eq(walked, 3.0, 0.001, "moved events add up to the distance")
	assert_almost_eq(sim.player_facing().y, -1.0, 0.001, "faces north at the end")


func test_path_routes_around_a_wall() -> void:
	var sim := SimScript.new()
	var world: WorldDef = sim.world
	var start := sim.player_pos()
	var target := Vector2(start.x, 14.0)  # just outside the south wall, straight through it
	var result := sim.command(Vocab.MOVE_TO, {"pos": [target.x, target.y]})
	assert_true(result["ok"], "a point outside the walls is reachable through the gate")
	var path_set := _events_of(sim, Vocab.EV_PATH_SET)
	assert_eq(path_set.size(), 1)
	var straight := start.distance_to(target)
	assert_true(path_set[0]["length"] >= straight, "the route is at least the straight line")
	var ticks := 0
	var arrived := false
	var went_through_gate := false
	while ticks < 40 and not arrived:
		sim.step()
		ticks += 1
		for e in sim.drain_events():
			if e["kind"] == Vocab.EV_MOVED:
				for p in e["path"]:
					var q := Vector2(p[0], p[1])
					assert_true(world.is_walkable(q), "never stands inside a wall at %s" % q)
					if world.cell_of(q) == world.cell_of(Vector2(0.5, 9.5)):
						went_through_gate = true
			if e["kind"] == Vocab.EV_ARRIVED:
				arrived = true
	assert_true(arrived, "arrives outside the wall")
	assert_true(went_through_gate or sim.player_pos().distance_to(target) < 0.01, "left through the gate opening")
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_INNER_RING)


func test_region_changed_event_fires_at_the_gate() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.MOVE_TO, {"pos": [0.5, 14.0]})
	var changes: Array[Dictionary] = []
	for i in 30:
		sim.step()
		changes.append_array(_events_of(sim, Vocab.EV_REGION_CHANGED))
		if not sim.is_moving():
			break
	assert_eq(changes.size(), 1, "one region change on the way out")
	assert_eq(changes[0]["from"], WorldDef.REGION_OUTPOST)
	assert_eq(changes[0]["to"], WorldDef.REGION_INNER_RING)


func test_enclosed_target_is_unreachable() -> void:
	var world := WorldDefScript.new()
	world.cols = 16
	world.rows = 16
	world.origin = [0.0, 0.0]
	world.spawn = [1.5, 1.5]
	world.solids = [{"id": "box", "kind": "wall", "min": [8.0, 8.0], "max": [12.0, 12.0], "height": 1.0}]
	# A hollow box: walls around (9..11, 9..11) with the inside unblocked.
	world.solids.append({"id": "hole", "kind": "wall", "min": [9.0, 9.0], "max": [11.0, 11.0], "height": 1.0})
	world.bake()
	# Unblock the interior by hand to make an enclosed pocket.
	for y in range(9, 11):
		for x in range(9, 11):
			world._blocked[y * world.cols + x] = 0
	var sim := SimScript.new(world)
	var result := sim.command(Vocab.MOVE_TO, {"pos": [9.5, 9.5]})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_UNREACHABLE)
	var rejected := _events_of(sim, Vocab.EV_COMMAND_REJECTED)
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0]["reason"], Vocab.REASON_UNREACHABLE)
	assert_false(sim.is_moving())


func test_click_on_a_wall_snaps_to_the_nearest_walkable_cell() -> void:
	var sim := SimScript.new()
	var world: WorldDef = sim.world
	var on_wall := Vector2(4.5, -9.5)  # inside the north wall
	assert_false(world.is_walkable(on_wall), "test target really is blocked")
	var result := sim.command(Vocab.MOVE_TO, {"pos": [on_wall.x, on_wall.y]})
	assert_true(result["ok"], "snapped rather than rejected")
	var path_set := _events_of(sim, Vocab.EV_PATH_SET)[0]
	var dest := Vector2(path_set["to"][0], path_set["to"][1])
	assert_true(world.is_walkable(dest), "destination is walkable")
	assert_true(dest.distance_to(on_wall) <= Sim.SNAP_RADIUS_CELLS * world.cell_size * 1.5, "snapped nearby")
	assert_true(_ticks_to_arrive(sim, 40) > 0, "walks to the snapped cell")


func test_click_in_the_fire_snaps_to_its_edge() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.MOVE_TO, {"pos": [0.0, 0.0]})
	assert_true(result["ok"])
	assert_true(_ticks_to_arrive(sim, 40) > 0)
	assert_true(sim.world.is_walkable(sim.player_pos()))
	assert_true(sim.player_pos().distance_to(Vector2.ZERO) < 2.5, "stands next to the fire")


func test_click_outside_the_world_is_rejected() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.MOVE_TO, {"pos": [500.0, 0.0]})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_OUTSIDE_WORLD)
	assert_eq(_events_of(sim, Vocab.EV_COMMAND_REJECTED).size(), 1)
	assert_false(sim.is_moving())


func test_deep_inside_a_wide_wall_is_not_walkable() -> void:
	var world := WorldDefScript.new()
	world.cols = 20
	world.rows = 20
	world.origin = [0.0, 0.0]
	world.spawn = [1.5, 1.5]
	world.solids = [{"id": "slab", "kind": "wall", "min": [5.0, 5.0], "max": [15.0, 15.0], "height": 1.0}]
	world.bake()
	var sim := SimScript.new(world)
	var result := sim.command(Vocab.MOVE_TO, {"pos": [10.0, 10.0]})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_NOT_WALKABLE)


func test_new_move_replaces_the_current_path() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.MOVE_TO, {"pos": [6.5, 4.5]})
	sim.step()
	sim.command(Vocab.MOVE_TO, {"pos": [-6.5, 4.5]})
	var ticks := _ticks_to_arrive(sim, 40)
	assert_true(ticks > 0)
	assert_almost_eq(sim.player_pos().x, -6.5, 0.001, "ends at the second click")


func test_bad_args_are_rejected() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.MOVE_TO, {})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_BAD_ARGS)
	assert_false(sim.command(Vocab.MOVE_TO, {"pos": "here"})["ok"])
