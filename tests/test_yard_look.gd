## The yard look: the pieces the built upgrades put in the outpost yard, from the built list
## alone. Nothing for nothing built, a piece for each built upgrade with a look, every piece
## inside the yard and clear of what the player walks to, and every model it names real. The
## meshes themselves are judged from screenshots; this checks the data they are built from.
extends "res://tests/run.gd".TestCase

const WorldDefScript := preload("res://sim/world_def.gd")
const YardLookScript := preload("res://scenes/yard_look.gd")

## How far a piece keeps from the palisade's inner face, and from a station, the tent and
## the gate path.
const WALL_GAP := 0.05
const CLEARANCE := 0.5


func test_nothing_built_draws_nothing() -> void:
	assert_true(YardLookScript.pieces([]).is_empty(), "no upgrades, no pieces")


func test_a_built_upgrade_yields_its_piece() -> void:
	var pieces := YardLookScript.pieces(["stash_shelves"])
	assert_eq(pieces.size(), 1)
	var shelves := pieces[0]
	assert_eq(shelves["upgrade"], "stash_shelves")
	assert_eq(shelves["line"], "stash")
	assert_eq(shelves["step"], 1)
	assert_eq(shelves["spot"], "stash_corner")
	assert_true(not (shelves["parts"] as Array).is_empty(), "the shelves are made of something")
	var stash := _box(WorldDefScript.outpost().objects["stash"])
	assert_true((shelves["at"] as Vector2).x < stash.get_center().x, "the shelves stand west of the stash, along the west wall")
	assert_true((shelves["at"] as Vector2).distance_to(stash.get_center()) < 4.0, "the shelves stand beside the stash")


func test_only_built_upgrades_draw() -> void:
	for id in UpgradeTable.ids():
		for piece in YardLookScript.pieces([id]):
			assert_eq(piece["upgrade"], id, "building %s draws only its own piece" % id)
	for piece in YardLookScript.pieces(["forge", "armoury", "not_an_upgrade"]):
		assert_true(piece["upgrade"] in ["forge", "armoury"], "%s was not built" % piece["upgrade"])


func test_every_piece_lies_inside_the_yard_clear_of_the_stations_the_tent_and_the_gate_path() -> void:
	var w := WorldDefScript.outpost()
	var yard := _yard_interior(w).grow(-WALL_GAP)
	var keep_clear := {}
	for id in w.objects:
		var o: Dictionary = w.objects[id]
		if o["kind"] in [WorldDef.KIND_STASH, WorldDef.KIND_WORKBENCH, WorldDef.KIND_FIRE, WorldDef.KIND_GATE]:
			keep_clear[id] = _box(o).grow(CLEARANCE)
	for s in w.solids:
		if s["kind"] == WorldDef.KIND_DECOR:
			keep_clear[s["id"]] = _box(s).grow(CLEARANCE)
	# The gate path: the gate's width, from the gate to the fire.
	var gate := _box(w.objects["gate"])
	var fire := _box(w.objects["fire"])
	keep_clear["gate path"] = Rect2(gate.position.x, fire.get_center().y, gate.size.x, gate.end.y - fire.get_center().y).grow(CLEARANCE)
	var pieces := YardLookScript.pieces(UpgradeTable.ids())
	assert_true(not pieces.is_empty(), "some upgrade has a look")
	for piece in pieces:
		var corners := YardLookScript.footprint(piece)
		for c in corners:
			assert_true(yard.has_point(c), "%s's corner %s lies inside the yard" % [piece["upgrade"], c])
		for what in keep_clear:
			var r: Rect2 = keep_clear[what]
			var area := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			assert_true(Geometry2D.intersect_polygons(corners, area).is_empty(), "%s keeps clear of the %s" % [piece["upgrade"], what])


func test_the_same_list_always_gives_the_same_pieces() -> void:
	var all := UpgradeTable.ids()
	assert_eq(YardLookScript.pieces(all), YardLookScript.pieces(all))
	var reversed := all.duplicate()
	reversed.reverse()
	assert_eq(YardLookScript.pieces(reversed), YardLookScript.pieces(all), "the order upgrades were built in does not matter")
	var first := YardLookScript.pieces(["stash_shelves"])
	(first[0]["parts"] as Array).clear()
	assert_eq(YardLookScript.pieces(["stash_shelves"])[0]["parts"].size(), (YardLookScript.LOOKS["stash_shelves"]["parts"] as Array).size(), "pieces are copies: changing one leaves the table alone")


func test_every_model_a_piece_names_exists() -> void:
	for piece in YardLookScript.pieces(UpgradeTable.ids()):
		for part in piece["parts"]:
			if part.has("model"):
				assert_true(ResourceLoader.exists(part["model"]), "%s names %s" % [piece["upgrade"], part["model"]])
				assert_true(float(part["height"]) > 0.0, "%s scales %s to a height" % [piece["upgrade"], part["model"]])
			else:
				assert_true(part.get("mesh", "") in YardLookScript.MESHES, "%s names the hand-made mesh %s" % [piece["upgrade"], part.get("mesh", "")])


func test_every_look_is_for_a_real_upgrade_in_a_real_spot() -> void:
	for id in YardLookScript.LOOKS:
		var look: Dictionary = YardLookScript.LOOKS[id]
		assert_true(UpgradeTable.has(id), "%s is an upgrade" % id)
		assert_true(YardLookScript.SPOTS.has(look["spot"]), "%s builds in a known spot" % id)
		assert_true(int(look["step"]) >= 1, "%s's step counts from 1" % id)


static func _box(thing: Dictionary) -> Rect2:
	var lo := Vector2(thing["min"][0], thing["min"][1])
	return Rect2(lo, Vector2(thing["max"][0], thing["max"][1]) - lo)


## The outpost's floor inside the palisade.
static func _yard_interior(w: WorldDef) -> Rect2:
	var yard := Rect2()
	for r in w.regions:
		if r["name"] == WorldDef.REGION_OUTPOST:
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for p in r["polygon"]:
				lo = lo.min(Vector2(p[0], p[1]))
				hi = hi.max(Vector2(p[0], p[1]))
			yard = Rect2(lo, hi - lo)
	for s in w.solids:
		if s["kind"] == WorldDef.KIND_WALL:
			var wall := _box(s)
			# Trim the yard back to each wall's inner face.
			if wall.size.x > wall.size.y:
				if wall.get_center().y < yard.get_center().y:
					yard = Rect2(yard.position.x, wall.end.y, yard.size.x, yard.end.y - wall.end.y)
				else:
					yard.size.y = wall.position.y - yard.position.y
			else:
				if wall.get_center().x < yard.get_center().x:
					yard = Rect2(wall.end.x, yard.position.y, yard.end.x - wall.end.x, yard.size.y)
				else:
					yard.size.x = wall.position.x - yard.position.x
	return yard
