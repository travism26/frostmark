## The ring dressing table against the world definition: one landmark per compass direction
## per ring that click-to-move can reach, camps where the sim's packs really live, a kit piece
## for every ruin solid, markers on the ring edges, scatter that thickens outward and cliffs
## capped in the snow of their ring. The meshes themselves are judged from screenshots; this
## checks the data they are built from, and the cliffs' vertex colours.
extends "res://tests/run.gd".TestCase

const WorldDefScript := preload("res://sim/world_def.gd")
const GridPathScript := preload("res://sim/grid_path.gd")
const RingLookScript := preload("res://scenes/ring_look.gd")
const RingDressingScript := preload("res://scenes/ring_dressing.gd")
const WorldDressingScript := preload("res://scenes/world_dressing.gd")

## A point deep inside each dressed ring to walk from.
const FROM := {
	WorldDef.REGION_INNER_RING: Vector2(0.5, 17.0),
	WorldDef.REGION_RING_ONE: Vector2(0.5, 42.0),
	WorldDef.REGION_RING_TWO: Vector2(0.5, 70.0),
	WorldDef.REGION_RING_THREE: Vector2(-40.5, 135.5),
}
const KINDS := [
	"fallen_pine", "split_rock", "cairn", "dead_giant", "frozen_waterfall", "caravan_wreck",
	"watch_post", "tower_base", "fallen_arch", "stone_ring", "ice_spire",
]


func test_every_ring_has_one_landmark_per_compass_direction() -> void:
	var w := WorldDefScript.outpost()
	for ring in RingDressingScript.rings():
		var centre := RingDressingScript.ring_centre(w, ring)
		var kinds := {}
		for direction in RingDressingScript.DIRECTIONS:
			var mark: Dictionary = RingDressingScript.landmark(ring, direction)
			assert_true(mark["kind"] in KINDS, "%s %s is a known piece (%s)" % [ring, direction, mark["kind"]])
			kinds[mark["kind"]] = true
			var at := Vector2(mark["at"][0], mark["at"][1])
			assert_eq(RingDressingScript.direction_of(centre, at), direction, "%s's %s landmark lies %s of the ring's centre" % [ring, mark["kind"], direction])
			var foot: Variant = w.nearest_walkable_cell(at, 4)
			assert_true(foot != null, "%s %s has walkable ground at its foot" % [ring, direction])
			if foot != null:
				assert_eq(w.region_at(w.cell_center(foot)), ring, "%s %s stands in its ring" % [ring, direction])
		assert_eq(kinds.size(), 4, "%s's four landmarks are four different things" % ring)


func test_click_to_move_reaches_every_landmark() -> void:
	var w := WorldDefScript.outpost()
	for ring in RingDressingScript.rings():
		var start := w.cell_of(FROM[ring])
		assert_eq(w.region_at(FROM[ring]), ring)
		for direction in RingDressingScript.DIRECTIONS:
			var mark: Dictionary = RingDressingScript.landmark(ring, direction)
			var at := Vector2(mark["at"][0], mark["at"][1])
			var foot: Variant = w.nearest_walkable_cell(at, 4)
			if foot == null:
				continue
			var path := GridPathScript.find(w, start, foot)
			assert_true(not path.is_empty(), "a route reaches the %s %s landmark (%s)" % [ring, direction, mark["kind"]])
			# Dressing never blocks: the landmark's own ground is walkable, except where a
			# piece hangs on a cliff or stands over a doorway on the wall ends.
			if mark["kind"] not in ["frozen_waterfall", "fallen_arch", "stone_ring"]:
				assert_true(w.is_walkable(at), "the %s %s landmark stands on open ground" % [ring, direction])


func test_the_gate_stones_and_road_posts_stand_clear_of_the_road() -> void:
	var w := WorldDefScript.outpost()
	for p in RingDressingScript.GATE_STONES:
		var at := Vector2(p[0], p[1])
		assert_eq(w.region_at(at), WorldDef.REGION_RING_TWO, "a gate stone stands past the gate")
		assert_true(w.is_walkable(at), "a gate stone is not in a footprint")
		assert_true(absf(at.x) > 2.5, "a gate stone leaves the road through the gate open")
	for p in RingDressingScript.ROAD_POSTS:
		var at := Vector2(p[0], p[1])
		assert_almost_eq(maxf(absf(at.x), absf(at.y)), 24.0, 0.01, "a road post stands on the safe ring's edge")
		assert_true(w.is_walkable(at))
	assert_true(RingDressingScript.BOUNDARY_SPACING > 2.0)


func test_every_ruin_solid_gets_a_kit_piece_in_its_own_footprint() -> void:
	var w := WorldDefScript.outpost()
	var pieces := {}
	for s in w.solids:
		if s["kind"] != WorldDef.KIND_RUIN:
			continue
		var piece := RingDressingScript.ruin_piece(s)
		assert_true(piece in ["wall", "pillar"], "%s is a kit piece" % s["id"])
		pieces[piece] = int(pieces.get(piece, 0)) + 1
		assert_eq(w.region_at(Vector2((s["min"][0] + s["max"][0]) * 0.5, (s["min"][1] + s["max"][1]) * 0.5)), WorldDef.REGION_RING_TWO, "%s is in ring two" % s["id"])
	assert_true(int(pieces.get("wall", 0)) >= 10, "the outer wall and the keep are broken walls")
	assert_eq(int(pieces.get("pillar", 0)), 4, "the four pillars east are pillars")


func test_every_cliff_is_capped_in_the_snow_of_its_ring() -> void:
	var w := WorldDefScript.outpost()
	var tones := {}  # ring -> every cliff snow luminance in it
	for s in w.solids:
		if s["kind"] != WorldDef.KIND_CLIFF:
			continue
		var centre := Vector2((s["min"][0] + s["max"][0]) * 0.5, (s["min"][1] + s["max"][1]) * 0.5)
		var snow: Color = WorldDressingScript.COLOR_SNOW_CAP * (RingLookScript.at(w, centre)["snow_tone"] as Color)
		# The mesh keeps its vertex colours at eight bits a channel, so they are matched to 1%.
		var colours: PackedColorArray = WorldDressingScript.solid_mesh(w, s).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var top := 0.0
		var capped := false
		for c in colours:
			top = maxf(top, c.get_luminance())
			capped = capped or (absf(c.r - snow.r) < 0.01 and absf(c.g - snow.g) < 0.01 and absf(c.b - snow.b) < 0.01)
		assert_true(capped, "%s carries its ring's snow" % s["id"])
		assert_true(top <= maxf(snow.get_luminance(), WorldDressingScript.COLOR_ICE_PALE.get_luminance()) + 0.001, "nothing on %s is brighter than its snow or pale ice" % s["id"])
		assert_true(snow.get_luminance() > WorldDressingScript.COLOR_ICE_DEEP.get_luminance(), "%s still reads as snow-capped over its deep ice" % s["id"])
		# Ring one's edge cliffs stand just past its polygon, where region_at already says ring
		# two, so a cliff's ring is the one it walls in: ring two's and three's are named for it.
		# A dungeon's walls stand in its own region, and the cliffs east of rings two and three
		# lie in no region and take the last ring's look.
		var ring := WorldDef.REGION_RING_ONE
		if (s["id"] as String).begins_with("cliff_ring_two"):
			ring = WorldDef.REGION_RING_TWO
		elif (s["id"] as String).begins_with("cliff_ring_three") or s["id"] == "cliff_far_east":
			ring = WorldDef.REGION_RING_THREE
		elif WorldDef.dungeon_of_region(w.region_at(centre)) != "":
			ring = w.region_at(centre)
		if not tones.has(ring):
			tones[ring] = []
		tones[ring].append(snow.get_luminance())
	assert_true(tones.has(WorldDef.REGION_RING_ONE) and tones.has(WorldDef.REGION_RING_TWO), "both rings have cliffs")
	assert_true(tones[WorldDef.REGION_RING_TWO].max() < tones[WorldDef.REGION_RING_ONE].min(), "ring two's cliffs are capped darker than ring one's")
	assert_true(tones[WorldDef.REGION_RING_THREE].min() > tones[WorldDef.REGION_RING_TWO].max(), "ring three's cliffs carry the glacier's paler ice")
	assert_true(tones[WorldDef.REGION_RING_ONE_DUNGEON].max() < tones[WorldDef.REGION_RING_ONE].min(), "the dungeon's walls are capped darker than ring one's cliffs")


func test_ring_threes_pressure_ridges_are_ice_in_their_own_footprint() -> void:
	var w := WorldDefScript.outpost()
	var count := 0
	for s in w.solids:
		if s["kind"] != WorldDef.KIND_RIDGE:
			continue
		count += 1
		var centre := Vector2((s["min"][0] + s["max"][0]) * 0.5, (s["min"][1] + s["max"][1]) * 0.5)
		assert_eq(w.region_at(centre), WorldDef.REGION_RING_THREE, "%s is in ring three" % s["id"])
		var mesh := WorldDressingScript.solid_mesh(w, s)
		assert_true(mesh != null, "%s has its own look" % s["id"])
		var box := mesh.get_aabb()
		var half := Vector2(s["max"][0] - s["min"][0], s["max"][1] - s["min"][1]) * 0.5
		assert_true(absf(box.position.x) <= half.x + 0.6 and absf(box.end.x) <= half.x + 0.6, "%s keeps to its footprint across x" % s["id"])
		assert_true(absf(box.position.z) <= half.y + 0.6 and absf(box.end.z) <= half.y + 0.6, "%s keeps to its footprint across z" % s["id"])
	assert_true(count >= 4, "a few ridges break up the ice")


func test_camps_mark_the_packs_the_sim_places() -> void:
	var w := WorldDefScript.outpost()
	var camps := RingDressingScript.camps(w)
	var by_pack := {}
	for c in camps:
		by_pack[c["pack"]] = c
	for id in w.enemies:
		var e: Dictionary = w.enemies[id]
		var home := Vector2(e["home"][0], e["home"][1])
		if e["kind"] == "wolf":
			assert_true(by_pack.has(e["pack"]) and by_pack[e["pack"]]["kind"] == "wolf_den", "%s has a den" % id)
		elif e["kind"] == "bandit_archer":
			assert_true(by_pack.has(e["pack"]) and by_pack[e["pack"]]["kind"] == "bandit_camp", "%s has a camp" % id)
		else:
			assert_false(by_pack.has(e["pack"]), "%s (%s) keeps no camp" % [id, e["kind"]])
		if by_pack.has(e["pack"]):
			assert_true((by_pack[e["pack"]]["at"] as Vector2).distance_to(home) < 6.0, "%s's camp sits by its home" % id)
			assert_eq(w.region_at(by_pack[e["pack"]]["at"]), w.region_at(home), "%s's camp is in its home's region" % id)
			assert_true(w.region_at(home) in [WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_ONE_DUNGEON], "%s's camp is in ring one or its dungeon" % id)
	assert_eq(camps.size(), 12, "six dens and six camps, two of each in the dungeon")


func test_scatter_thickens_outward_and_every_ring_has_a_table() -> void:
	var rings := RingDressingScript.rings()
	var previous := -1.0
	for ring in rings:
		var look := RingLookScript.entry(ring)
		assert_true(RingDressingScript.SCATTER.has(ring), "%s has scatter" % ring)
		if ring == WorldDef.REGION_RING_THREE:
			assert_true(float(look["density"]) < previous, "the glacier lies barer than the ruins")
		else:
			assert_true(float(look["density"]) > previous, "dressing is denser in %s" % ring)
		previous = look["density"]
		for entry in RingDressingScript.SCATTER[ring]:
			assert_true(RingDressingScript.scaled_count(entry, look["density"]) > 0, "%s lays down some %s" % [ring, entry["what"]])
			var band: Array = entry.get("band", [0.0, INF])
			assert_true(float(band[0]) < float(band[1]), "%s %s band is ordered" % [ring, entry["what"]])
	assert_true(float(RingLookScript.entry(WorldDef.REGION_RING_TWO)["drift"]) > float(RingLookScript.entry(WorldDef.REGION_INNER_RING)["drift"]), "drifts lie deeper out")


func test_scattered_dressing_keeps_clear_of_every_node() -> void:
	var w := WorldDefScript.outpost()
	var placer := WorldDressingScript.Placer.new(w, 7)
	for ring in RingDressingScript.rings():
		var spots := placer.scatter(ring, 400, 1.0, WorldDressingScript.DRESSING_MARGIN, WorldDressingScript.DRESSING_HOME_MARGIN)
		assert_true(spots.size() > 100, "%s gets scatter" % ring)
		for p in spots:
			for id in w.node_ids():
				assert_true(w.distance_to_object(id, p) >= WorldDressingScript.DRESSING_MARGIN, "dressing at %s keeps off %s" % [p, id])


func test_each_inner_ring_ore_spot_lies_by_its_sides_landmark() -> void:
	var w := WorldDefScript.outpost()
	var ring := WorldDef.REGION_INNER_RING
	var centre := RingDressingScript.ring_centre(w, ring)
	for kind in [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK]:
		for id in w.objects_of_kind(kind):
			var at := w.object_center(id)
			if w.region_at(at) != ring:
				continue
			var side := RingDressingScript.direction_of(centre, at)
			var nearest := ""
			for direction in RingDressingScript.DIRECTIONS:
				var mark: Dictionary = RingDressingScript.landmark(ring, direction)
				var best: Dictionary = RingDressingScript.landmark(ring, nearest) if nearest != "" else {}
				if nearest == "" or at.distance_to(Vector2(mark["at"][0], mark["at"][1])) < at.distance_to(Vector2(best["at"][0], best["at"][1])):
					nearest = direction
			assert_eq(nearest, side, "%s, on the %s side, lies nearest that side's landmark" % [id, side])


func test_ring_ones_mine_lies_by_the_watch_post_and_clear_of_its_ground() -> void:
	var w := WorldDefScript.outpost()
	var mark: Dictionary = RingDressingScript.landmark(WorldDef.REGION_RING_ONE, "west")
	assert_eq(mark["kind"], "watch_post")
	var at := Vector2(mark["at"][0], mark["at"][1])
	# The ground the scatter pass keeps clear for a landmark.
	var half := float(mark["size"]) * 0.6
	var mine := 0
	for kind in [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK]:
		for id in w.objects_of_kind(kind):
			if w.region_at(w.object_center(id)) != WorldDef.REGION_RING_ONE:
				continue
			mine += 1
			assert_true(w.object_center(id).distance_to(at) < 16.0, "%s lies near the watch post" % id)
			var o: Dictionary = w.objects[id]
			var gap := maxf(
				maxf(at.x - half - float(o["max"][0]), float(o["min"][0]) - at.x - half),
				maxf(at.y - half - float(o["max"][1]), float(o["min"][1]) - at.y - half))
			assert_true(gap >= WorldDressingScript.DRESSING_MARGIN, "%s keeps off the watch post's ground (%.1f m)" % [id, gap])
	assert_eq(mine, 6, "the mine's six rocks")


## The ring-one copper and tin rocks: the mine's.
func _mine_rocks(w: WorldDef) -> Array[String]:
	var out: Array[String] = []
	for kind in [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK]:
		for id in w.objects_of_kind(kind):
			if w.region_at(w.object_center(id)) == WorldDef.REGION_RING_ONE:
				out.append(id)
	return out


## How far apart two [min, max] rectangles are (negative when they overlap).
func _rect_gap(a: Array, b_min: Vector2, b_max: Vector2) -> float:
	return maxf(maxf(b_min.x - a[1].x, a[0].x - b_max.x), maxf(b_min.y - a[1].y, a[0].y - b_max.y))


func test_ring_ones_mine_has_its_own_dressing_clear_of_every_rock() -> void:
	var w := WorldDefScript.outpost()
	var rocks := _mine_rocks(w)
	assert_eq(rocks.size(), 6)
	var mouth := Vector2.ZERO
	for id in rocks:
		mouth += w.object_center(id) / rocks.size()
	var mine: Dictionary = RingDressingScript.MINES[WorldDef.REGION_RING_ONE]
	assert_eq(mine["ores"], [WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK], "the veins are the rocks' own ores")
	var kinds := {}
	for piece in RingDressingScript.mine_pieces():
		kinds[piece["kind"]] = int(kinds.get(piece["kind"], 0)) + 1
		var at := Vector2(piece["at"][0], piece["at"][1])
		var ground := RingDressingScript.piece_ground(piece)
		assert_true(at.distance_to(mouth) < 14.0, "the %s at %s dresses the mine" % [piece["kind"], at])
		for id in w.node_ids():
			var o: Dictionary = w.objects[id]
			var gap := _rect_gap(ground, Vector2(o["min"][0], o["min"][1]), Vector2(o["max"][0], o["max"][1]))
			assert_true(gap >= WorldDressingScript.DRESSING_MARGIN - 0.001, "the %s at %s keeps off %s (%.2f m)" % [piece["kind"], at, id, gap])
		# The mesh itself, turned and set in place, never reaches a rock.
		var basis := Basis(Vector3.UP, piece["turn"])
		var vertices: PackedVector3Array = WorldDressingScript.mine_mesh(w, piece).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var nearest := INF
		for v in vertices:
			var p := basis * v
			var flat := at + Vector2(p.x, p.z)
			for id in rocks:
				nearest = minf(nearest, w.distance_to_object(id, flat))
			if piece["kind"] == "mine_face":
				assert_true(flat.x <= ground[1].x + 0.001 and flat.x >= ground[0].x - 0.001 and flat.y <= ground[1].y + 0.001 and flat.y >= ground[0].y - 0.001, "the rock face stays on its ground (%s)" % flat)
		assert_true(nearest > 0.5, "the %s at %s stands clear of every rock (%.2f m)" % [piece["kind"], at, nearest])
	assert_eq(int(kinds.get("mine_face", 0)), 1, "a rock face behind the rocks")
	assert_true(int(kinds.get("ore_boulder", 0)) >= 2, "ore-streaked boulders")
	assert_true(int(kinds.get("spoil_heap", 0)) >= 2, "spoil heaps")


func test_the_mines_dressing_never_blocks_and_every_rock_stays_reachable() -> void:
	var w := WorldDefScript.outpost()
	var mines := WorldDressingScript.mines(w)
	assert_eq(mines.find_children("*", "CollisionObject3D", true, false).size(), 0, "nothing in the mine's dressing has a body")
	mines.free()
	var west: Dictionary = {}
	for s in w.solids:
		if s["id"] == "cliff_west":
			west = s
	var from := w.cell_of(FROM[WorldDef.REGION_RING_ONE])
	var landmark: Dictionary = RingDressingScript.landmark(WorldDef.REGION_RING_ONE, "west")
	var post := Vector2(landmark["at"][0], landmark["at"][1])
	var post_half := float(landmark["size"]) * 0.6
	for piece in RingDressingScript.mine_pieces():
		var at := Vector2(piece["at"][0], piece["at"][1])
		var ground := RingDressingScript.piece_ground(piece)
		assert_true(_rect_gap(ground, post - Vector2.ONE * post_half, post + Vector2.ONE * post_half) > 0.0, "the %s at %s keeps off the watch post's ground" % [piece["kind"], at])
		if piece["kind"] == "mine_face":
			# The face stands on the cliff, not on the snowfield.
			assert_true(ground[0].x >= float(west["min"][0]) and ground[1].x <= float(west["max"][0]) and ground[0].y >= float(west["min"][1]) and ground[1].y <= float(west["max"][1]), "the rock face lies on the west cliff")
			continue
		assert_true(w.is_walkable(at), "the %s at %s stands on open ground" % [piece["kind"], at])
		assert_eq(w.region_at(at), WorldDef.REGION_RING_ONE, "the %s at %s is in ring one" % [piece["kind"], at])
	for id in _mine_rocks(w):
		var reachable := false
		for cell in w.approach_cells(id):
			var stand := w.cell_center(cell)
			for piece in RingDressingScript.mine_pieces():
				var ground := RingDressingScript.piece_ground(piece)
				assert_false(stand.x > ground[0].x and stand.x < ground[1].x and stand.y > ground[0].y and stand.y < ground[1].y, "%s's approach at %s is clear of the %s" % [id, stand, piece["kind"]])
			if not GridPathScript.find(w, from, cell).is_empty():
				reachable = true
		assert_true(reachable, "click-to-move reaches %s" % id)


func test_scattered_dressing_keeps_clear_of_the_mine() -> void:
	var w := WorldDefScript.outpost()
	var placer := WorldDressingScript.Placer.new(w, 7)
	var spots := placer.scatter(WorldDef.REGION_RING_ONE, 400, 1.0, WorldDressingScript.DRESSING_MARGIN, WorldDressingScript.DRESSING_HOME_MARGIN)
	assert_true(spots.size() > 100, "ring one gets scatter")
	for p in spots:
		for piece in RingDressingScript.mine_pieces():
			var ground := RingDressingScript.piece_ground(piece)
			var gap := _rect_gap(ground, p, p)
			assert_true(gap >= WorldDressingScript.DRESSING_MARGIN - 0.001, "dressing at %s keeps off the mine's %s" % [p, piece["kind"]])
