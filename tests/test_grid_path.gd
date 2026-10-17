## Routing on the first-playable world: A* routes step cell to cell without cutting corners,
## smoothed routes keep line of sight, the same click always gives the same route, re-baking
## the grid re-routes, and a click across the whole world is cheap enough for one frame.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const WorldDefScript := preload("res://sim/world_def.gd")
const Vocab := preload("res://sim/vocab.gd")

## Random walkable start and goal pairs checked per world, from a fixed seed.
const PAIRS := 150
## A click must route inside a frame at 60 Hz with room to spare. Headless desktop routes
## take 1 to 3 ms; the old GDScript A* with farthest-first smoothing took up to 100 ms.
const CLICK_BUDGET_MS := 16.0
## Far ring-one points on the other side of the outpost walls from the spawn.
const FAR_CLICKS := [[-55.0, -55.0], [55.0, -55.0], [-55.0, 55.0], [55.0, 55.0], [-30.0, -50.0]]


func _pairs(w: WorldDef) -> Array:
	var walkable: Array[Vector2i] = []
	for y in w.rows:
		for x in w.cols:
			if w.is_walkable_cell(Vector2i(x, y)):
				walkable.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var out := []
	for i in PAIRS:
		out.append([walkable[rng.randi() % walkable.size()], walkable[rng.randi() % walkable.size()]])
	return out


func test_routes_step_cell_to_cell_without_cutting_corners() -> void:
	var w := WorldDefScript.outpost()
	for pair in _pairs(w):
		var from: Vector2i = pair[0]
		var to: Vector2i = pair[1]
		var cells := GridPath.find(w, from, to)
		assert_false(cells.is_empty(), "%s to %s routes (all walkable ground is connected)" % [from, to])
		if cells.is_empty():
			continue
		assert_eq(cells[0], from, "starts on its own cell")
		assert_eq(cells[cells.size() - 1], to, "ends on the goal cell")
		for i in range(1, cells.size()):
			var d := cells[i] - cells[i - 1]
			assert_true(maxi(absi(d.x), absi(d.y)) == 1, "one step at a time at %s" % cells[i])
			assert_true(w.is_walkable_cell(cells[i]), "never steps into a blocked cell at %s" % cells[i])
			if d.x != 0 and d.y != 0:
				var corners := w.is_walkable_cell(cells[i - 1] + Vector2i(d.x, 0)) and w.is_walkable_cell(cells[i - 1] + Vector2i(0, d.y))
				assert_true(corners, "a diagonal step at %s cuts no corner" % cells[i])


func test_smoothed_routes_keep_line_of_sight_and_end_on_the_goal() -> void:
	var w := WorldDefScript.outpost()
	for pair in _pairs(w):
		var cells := GridPath.find(w, pair[0], pair[1])
		if cells.size() < 2:
			continue
		var points: Array[Vector2] = []
		for i in range(1, cells.size()):
			points.append(w.cell_center(cells[i]))
		var start := w.cell_center(cells[0])
		var smoothed := GridPath.smooth(w, start, points)
		assert_eq(smoothed[smoothed.size() - 1], points[points.size() - 1], "keeps the goal")
		assert_true(smoothed.size() <= points.size(), "never adds waypoints")
		var prev := start
		for p in smoothed:
			assert_true(GridPath.has_line_of_sight(w, prev, p), "%s sees %s" % [prev, p])
			prev = p


func test_the_same_click_gives_the_same_route() -> void:
	for target in FAR_CLICKS:
		var a := SimScript.new()
		var b := SimScript.new()
		assert_true(a.command(Vocab.MOVE_TO, {"pos": target})["ok"], "%s is reachable" % [target])
		b.command(Vocab.MOVE_TO, {"pos": target})
		assert_eq(a.state["player"]["path"], b.state["player"]["path"], "a fresh world routes %s identically" % [target])
		a.state["player"]["path"] = []
		a.command(Vocab.MOVE_TO, {"pos": target})
		assert_eq(a.state["player"]["path"], b.state["player"]["path"], "a second route on the same world matches")


func test_rebaking_the_grid_reroutes_around_new_solids() -> void:
	var w := WorldDefScript.new()
	w.cols = 12
	w.rows = 12
	w.origin = [0.0, 0.0]
	w.bake()
	var straight := GridPath.find(w, Vector2i(1, 5), Vector2i(10, 5))
	assert_eq(straight.size(), 10, "open ground: a straight row of cells")
	w.solids.append({"id": "wall", "kind": WorldDef.KIND_WALL, "min": [5.0, 0.0], "max": [6.0, 10.0], "height": 2.0})
	w.bake()
	var around := GridPath.find(w, Vector2i(1, 5), Vector2i(10, 5))
	assert_false(around.is_empty(), "still reachable round the wall's end")
	for cell in around:
		assert_true(w.is_walkable_cell(cell), "the new route avoids the wall at %s" % cell)
	assert_eq(around[around.size() - 1], Vector2i(10, 5))


func test_a_click_across_the_world_routes_inside_a_frame() -> void:
	var worst := 0.0
	for target in FAR_CLICKS:
		var sim := SimScript.new()  # a fresh world, so the time includes building its grid
		var t0 := Time.get_ticks_usec()
		var result := sim.command(Vocab.MOVE_TO, {"pos": target})
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
		assert_true(result["ok"], "%s is reachable from the spawn" % [target])
	assert_true(worst < CLICK_BUDGET_MS, "the slowest far click took %.1f ms" % worst)
