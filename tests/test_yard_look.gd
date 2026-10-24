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
## Upgrades whose yard looks land with a sibling ticket of #47 still open: the forge and the
## blast furnace (#51). Each comes off this list with its look.
const LOOKS_TO_COME := ["forge", "blast_furnace"]


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


func test_the_cellar_and_the_vault_yield_their_pieces() -> void:
	for id in ["stash_cellar", "stash_vault"]:
		var pieces := YardLookScript.pieces([id])
		assert_eq(pieces.size(), 1, "building %s draws one piece" % id)
		assert_eq(pieces[0]["upgrade"], id)
		assert_eq(pieces[0]["line"], "stash")
		assert_true(not (pieces[0]["parts"] as Array).is_empty(), "%s is made of something" % id)
	var cellar_parts: Array = YardLookScript.pieces(["stash_cellar"])[0]["parts"]
	assert_true(cellar_parts.any(func(p: Dictionary) -> bool: return p.get("mesh", "") == "hatch"), "the cellar has a hatch")
	assert_true(cellar_parts.filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("barrel.glb")).size() >= 3, "the cellar has a stack of casks")
	var vault_parts: Array = YardLookScript.pieces(["stash_vault"])[0]["parts"]
	assert_true(vault_parts.any(func(p: Dictionary) -> bool: return p.get("mesh", "") == "iron_chest"), "the vault is an iron-bound chest")


func test_the_steps_of_a_line_share_one_spot() -> void:
	var spots := {}  # line -> its spot
	for piece in YardLookScript.pieces(UpgradeTable.ids()):
		var line: String = piece["line"]
		if spots.has(line):
			assert_eq(piece["spot"], spots[line], "%s builds in the %s line's spot" % [piece["upgrade"], line])
		else:
			spots[line] = piece["spot"]


func test_the_stash_corner_grows_along_the_west_wall_one_step_beside_the_last() -> void:
	var line := YardLookScript.pieces(["stash_shelves", "stash_cellar", "stash_vault"])
	assert_eq(line.size(), 3, "all three steps of the stash line have a piece")
	var west_face := _yard_interior(WorldDefScript.outpost()).position.x
	for i in line.size():
		var piece := line[i]
		assert_eq(int(piece["step"]), i + 1, "the stash line's pieces come in step order")
		var here := _bounds(piece)
		assert_true(here.position.x - west_face < 0.2, "%s stands against the west wall" % piece["upgrade"])
		if i == 0:
			continue
		var before := _bounds(line[i - 1])
		assert_true(not here.intersects(before), "%s stands beside %s, not on it" % [piece["upgrade"], line[i - 1]["upgrade"]])
		assert_true(here.position.y > before.position.y, "%s stands south of %s" % [piece["upgrade"], line[i - 1]["upgrade"]])
		assert_true(here.position.y - before.end.y < 0.6, "%s stands close beside %s" % [piece["upgrade"], line[i - 1]["upgrade"]])


func test_no_two_pieces_overlap() -> void:
	var pieces := YardLookScript.pieces(UpgradeTable.ids())
	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			var a := YardLookScript.footprint(pieces[i])
			var b := YardLookScript.footprint(pieces[j])
			assert_true(Geometry2D.intersect_polygons(a, b).is_empty(), "%s and %s do not overlap" % [pieces[i]["upgrade"], pieces[j]["upgrade"]])


func test_every_upgrade_but_waystones_yields_a_piece_when_built() -> void:
	for id in UpgradeTable.ids():
		var pieces := YardLookScript.pieces([id])
		if id == "waystone":
			assert_true(pieces.is_empty(), "waystones show out in the rings, not in the yard")
		elif not (id in LOOKS_TO_COME and pieces.is_empty()):
			assert_true(not pieces.is_empty(), "building %s puts a piece in the yard" % id)


func test_the_armoury_stands_along_the_east_wall() -> void:
	var pieces := YardLookScript.pieces(["armoury"])
	assert_eq(pieces.size(), 1)
	var armoury := pieces[0]
	assert_eq(armoury["spot"], "east_wall")
	var east := _box(_solid(WorldDefScript.outpost(), "wall_east"))
	for c in YardLookScript.footprint(armoury):
		assert_true(east.position.x - c.x < 1.0, "the armoury's corner %s stands against the east wall" % c)


func test_the_pack_frame_adds_a_timber_rack_along_the_east_wall() -> void:
	assert_eq(YardLookScript.pieces(["armoury"]).size(), 1)
	var pieces := YardLookScript.pieces(["armoury", "pack_frame"])
	assert_eq(pieces.size(), 2, "building the Pack frame adds its piece")
	var frame := pieces[1]
	assert_eq(frame["upgrade"], "pack_frame")
	assert_eq(YardLookScript.material("pack_frame"), YardLookScript.TIMBER)
	assert_true((frame["parts"] as Array).any(func(p: Dictionary) -> bool: return p.get("mesh", "") == "shelf_rack"), "the frame is a timber rack")
	var east := _box(_solid(WorldDefScript.outpost(), "wall_east"))
	for c in YardLookScript.footprint(frame):
		assert_true(east.position.x - c.x < 1.0, "the frame's corner %s stands against the east wall" % c)


func test_the_winch_stands_inside_the_south_gate_to_one_side_of_the_path() -> void:
	var pieces := YardLookScript.pieces(["ring_two_gate"])
	assert_eq(pieces.size(), 1)
	var winch := pieces[0]
	assert_eq(winch["spot"], "south_gate")
	var gate := _box(WorldDefScript.outpost().objects["gate"])
	var corners := YardLookScript.footprint(winch)
	var west := corners[0].x < gate.position.x
	for c in corners:
		assert_true(gate.position.y - c.y > 0.0 and gate.position.y - c.y < 3.5, "the winch's corner %s stands just inside the gate" % c)
		assert_true((c.x < gate.position.x) == west and (west or c.x > gate.end.x), "the winch's corner %s keeps to one side of the gate path" % c)
		assert_true(absf(c.x - gate.get_center().x) < 7.0, "the winch's corner %s stands near the gate" % c)


func test_the_smithing_line_builds_up_one_spot_beside_the_workbench() -> void:
	var w := WorldDefScript.outpost()
	var forge := YardLookScript.pieces(["forge"])
	assert_eq(forge.size(), 1)
	var line := YardLookScript.pieces(["blast_furnace", "bloomery", "forge"])
	assert_eq(line.size(), 3)
	assert_eq(line[0]["upgrade"], "forge")
	assert_eq(line[1]["upgrade"], "bloomery")
	assert_eq(line[2]["upgrade"], "blast_furnace")
	assert_eq(line[0], forge[0], "the later steps add to the forge and leave it where it was")
	for i in line.size():
		assert_eq(line[i]["line"], "smithing")
		assert_eq(line[i]["step"], i + 1)
		assert_eq(line[i]["spot"], "smithy", "%s builds in the smithy" % line[i]["upgrade"])
		for j in range(i + 1, line.size()):
			assert_true(Geometry2D.intersect_polygons(YardLookScript.footprint(line[i]), YardLookScript.footprint(line[j])).is_empty(), "%s leaves %s its ground" % [line[j]["upgrade"], line[i]["upgrade"]])
	var bench := _box(w.objects["workbench"])
	var forge_at: Vector2 = line[0]["at"]
	var bloomery_at: Vector2 = line[1]["at"]
	var furnace_at: Vector2 = line[2]["at"]
	assert_true(forge_at.distance_to(bench.get_center()) < 3.5, "the forge stands beside the workbench")
	assert_true(bloomery_at.x > forge_at.x and absf(bloomery_at.y - forge_at.y) < 1.0, "the bloomery stands beside the forge, away from the workbench")
	assert_true(bloomery_at.distance_to(forge_at) < 3.0, "the bloomery stands close by the forge")
	assert_true(furnace_at.y < forge_at.y and absf(furnace_at.x - forge_at.x) < 0.5, "the furnace stands behind the forge")
	# Against the north wall: nothing the player can stand on lies north of the tower.
	var north_face := _yard_interior(w).position.y
	var deepest := INF
	for c in YardLookScript.footprint(line[2]):
		deepest = minf(deepest, c.y)
	assert_true(deepest - north_face < 0.2, "the furnace's back is at the wall: %s" % deepest)


func test_the_blast_furnace_is_the_tallest_thing_in_the_yard() -> void:
	var furnace := 0.0
	var others := 0.0
	for piece in YardLookScript.pieces(UpgradeTable.ids()):
		for part in piece["parts"]:
			var top: float = part.get("y", 0.0) + (part["height"] if part.has("model") else part["size"][1])
			if piece["upgrade"] == "blast_furnace":
				furnace = maxf(furnace, top)
			else:
				others = maxf(others, top)
	for s in WorldDefScript.outpost().solids:
		if s["kind"] in [WorldDef.KIND_WALL, WorldDef.KIND_DECOR]:
			others = maxf(others, s["height"])
	# The banners on the north wall hang to 3 m.
	others = maxf(others, 3.0)
	assert_true(furnace > others + 0.5, "the furnace (%.2f m) stands well above everything else (%.2f m)" % [furnace, others])


func test_the_smithy_glows_with_emissive_materials_and_no_lights() -> void:
	for piece in YardLookScript.pieces(["forge", "bloomery", "blast_furnace"]):
		var node := WorldDressing.yard_piece(piece)
		assert_true(node.find_children("*", "Light3D", true, false).is_empty(), "%s adds no light" % piece["upgrade"])
		var glows := false
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
				glows = glows or (m != null and m.emission_enabled)
		assert_true(glows, "%s glows" % piece["upgrade"])
		node.free()


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


static func _solid(w: WorldDef, id: String) -> Dictionary:
	for s in w.solids:
		if s["id"] == id:
			return s
	return {}


static func _box(thing: Dictionary) -> Rect2:
	var lo := Vector2(thing["min"][0], thing["min"][1])
	return Rect2(lo, Vector2(thing["max"][0], thing["max"][1]) - lo)


## A piece's footprint as a box on the ground.
static func _bounds(piece: Dictionary) -> Rect2:
	var corners := YardLookScript.footprint(piece)
	var r := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		r = r.expand(c)
	return r


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
