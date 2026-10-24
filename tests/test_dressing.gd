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
	var brightest := {}
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
		brightest[w.region_at(centre)] = snow.get_luminance()
	assert_true(brightest[WorldDef.REGION_RING_TWO] < brightest[WorldDef.REGION_RING_ONE], "ring two's cliffs are capped darker than ring one's")


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
			assert_eq(w.region_at(by_pack[e["pack"]]["at"]), WorldDef.REGION_RING_ONE, "%s's camp is in ring one" % id)
	assert_eq(camps.size(), 8, "four dens and four camps")


func test_scatter_thickens_outward_and_every_ring_has_a_table() -> void:
	var rings := RingDressingScript.rings()
	var previous := -1.0
	for ring in rings:
		var look := RingLookScript.entry(ring)
		assert_true(RingDressingScript.SCATTER.has(ring), "%s has scatter" % ring)
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
