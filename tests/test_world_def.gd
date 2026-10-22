## The outpost world definition: grid, regions, objects and approach cells.
extends "res://tests/run.gd".TestCase

const WorldDefScript := preload("res://sim/world_def.gd")


func test_outpost_regions_nest_outward() -> void:
	var w := WorldDefScript.outpost()
	assert_eq(w.region_at(Vector2(0.5, 0.5)), WorldDef.REGION_OUTPOST)
	assert_eq(w.region_at(Vector2(0.5, 15.0)), WorldDef.REGION_INNER_RING)
	assert_eq(w.region_at(Vector2(0.5, 30.0)), WorldDef.REGION_RING_ONE)
	assert_eq(w.region_at(Vector2(100.0, 100.0)), "")


func test_outpost_has_the_four_markers() -> void:
	var w := WorldDefScript.outpost()
	for id in ["gate", "fire", "stash", "workbench"]:
		assert_true(w.objects.has(id), "has %s" % id)
	assert_eq(w.objects["gate"]["kind"], WorldDef.KIND_GATE)
	assert_eq(w.objects["fire"]["kind"], WorldDef.KIND_FIRE)
	assert_eq(w.objects["stash"]["kind"], WorldDef.KIND_STASH)
	assert_eq(w.objects["workbench"]["kind"], WorldDef.KIND_WORKBENCH)


func test_walls_block_and_the_gate_does_not() -> void:
	var w := WorldDefScript.outpost()
	assert_false(w.is_walkable(Vector2(0.5, -9.5)), "north wall")
	assert_false(w.is_walkable(Vector2(9.5, 0.5)), "east wall")
	assert_false(w.is_walkable(Vector2(-9.5, 0.5)), "west wall")
	assert_false(w.is_walkable(Vector2(-5.5, 9.5)), "south wall west of the gate")
	assert_true(w.is_walkable(Vector2(0.5, 9.5)), "gate opening")
	assert_true(w.is_walkable(Vector2(-1.5, 9.5)), "gate opening, west edge")
	assert_false(w.is_walkable(Vector2(0.5, 0.5)), "fire blocks")
	assert_true(w.is_walkable(Vector2(0.5, 20.5)), "ground outside")
	assert_false(w.is_walkable(Vector2(70.0, 0.0)), "off the grid")
	assert_true(w.is_walkable(Vector2(w.spawn[0], w.spawn[1])), "spawn is walkable")


func test_cells_round_trip() -> void:
	var w := WorldDefScript.outpost()
	var c := w.cell_of(Vector2(3.2, -4.7))
	assert_eq(w.cell_of(w.cell_center(c)), c)
	assert_eq(w.cell_of(Vector2(-64.0, -64.0)), Vector2i(0, 0))
	assert_false(w.in_bounds(w.cell_of(Vector2(64.0, 0.0))))


func test_approach_cells_ring_blocking_objects() -> void:
	var w := WorldDefScript.outpost()
	var cells := w.approach_cells("fire")
	assert_eq(cells.size(), 12, "a 2x2 block has 12 free neighbours")
	for c in cells:
		assert_true(w.is_walkable_cell(c))
		assert_true(w.cell_center(c).distance_to(Vector2.ZERO) < 2.2)
	var gate := w.approach_cells("gate")
	assert_eq(gate.size(), 4, "the gate's own threshold cells")
	assert_true(w.approach_cells("nothing").is_empty())


# Smithing reads the pack, so every craft is a walk from the stash to the workbench and back.
func test_the_workbench_stands_a_short_walk_from_the_stash() -> void:
	var w := WorldDefScript.outpost()
	var nearest := INF
	for s in w.approach_cells("stash"):
		for b in w.approach_cells("workbench"):
			nearest = minf(nearest, w.cell_center(s).distance_to(w.cell_center(b)))
	assert_true(nearest <= 4.0, "the workbench's approach cells are %.1f m from the stash's" % nearest)


func test_nearest_walkable_cell() -> void:
	var w := WorldDefScript.outpost()
	var free: Variant = w.nearest_walkable_cell(Vector2(0.5, 4.5), 2)
	assert_eq(free, w.cell_of(Vector2(0.5, 4.5)))
	var snapped: Variant = w.nearest_walkable_cell(Vector2(0.5, 0.9), 2)
	assert_true(snapped != null)
	assert_true(w.is_walkable_cell(snapped))
	assert_eq(snapped, w.cell_of(Vector2(0.5, 1.5)), "closest edge of the fire")
	assert_true(w.nearest_walkable_cell(Vector2(0.5, 0.5), 0) == null)
