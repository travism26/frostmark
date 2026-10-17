## The world as data: a walkability grid, named regions and typed object placements.
##
## A WorldDef is static authoring data. The simulation reads it for path-finding and region
## lookups; the presentation reads the same solids and objects to draw the grey-box world,
## so the two can never disagree about where a wall is. It has no Godot scene dependency.
##
## Coordinates are ground-plane metres as `[x, z]` arrays (plain data, JSON-safe). The grid
## has `cols` x `rows` square cells of `cell_size`, with cell (0, 0) at `origin`; cell
## centres therefore sit at origin + (i + 0.5) * cell_size.
class_name WorldDef
extends RefCounted

const KIND_WALL := "wall"
const KIND_CLIFF := "cliff"
const KIND_OUTCROP := "outcrop"
const KIND_DECOR := "decor"
const KIND_GATE := "gate"
const KIND_FIRE := "fire"
const KIND_STASH := "stash"
const KIND_WORKBENCH := "workbench"
const KIND_TREE := "tree"
const KIND_FROST_PINE := "frost_pine"
const KIND_COPPER_ROCK := "copper_rock"
const KIND_TIN_ROCK := "tin_rock"
const KIND_IRON_ROCK := "iron_rock"
const KIND_FISHING_HOLE := "fishing_hole"
const KIND_ICE_HOLE := "ice_hole"
const KIND_RING_GATE := "ring_gate"

const REGION_OUTPOST := "outpost"
const REGION_INNER_RING := "inner_ring"
const REGION_RING_ONE := "ring_one"
const REGION_RING_TWO := "ring_two"

var cell_size := 1.0
var cols := 128
var rows := 128
var origin: Array = [-64.0, -64.0]
var spawn: Array = [0.5, 4.5]
## Where a player wakes after dying: beside the outpost fire.
var rescue: Array = [0.5, 1.5]

## Gatherable node kinds: the skill they train and the level it needs, the tool they need (and
## the lowest tool tier that works, "" for any), what one success yields, how many yields a
## node holds before it is depleted, the ticks until it regrows, and the experience per
## success. `tier` 1 nodes are the inner ring's; `tier` 2 nodes grow in ring one, need more
## skill and pay more. Placed objects of these kinds get a matching entry in the state.
const NODE_KINDS := {
	KIND_TREE: {
		"tier": 1, "skill": "woodcutting", "level": 1, "tool": "axe", "tool_tier": "", "item": "logs",
		"yield": 4, "respawn_ticks": 90, "xp": 10,
	},
	KIND_COPPER_ROCK: {
		"tier": 1, "skill": "mining", "level": 1, "tool": "pickaxe", "tool_tier": "", "item": "copper_ore",
		"yield": 4, "respawn_ticks": 100, "xp": 10,
	},
	KIND_TIN_ROCK: {
		"tier": 1, "skill": "mining", "level": 1, "tool": "pickaxe", "tool_tier": "", "item": "tin_ore",
		"yield": 4, "respawn_ticks": 100, "xp": 10,
	},
	KIND_FISHING_HOLE: {
		"tier": 1, "skill": "fishing", "level": 1, "tool": "rod", "tool_tier": "", "item": "raw_fish",
		"yield": 6, "respawn_ticks": 80, "xp": 10,
	},
	KIND_FROST_PINE: {
		"tier": 2, "skill": "woodcutting", "level": 3, "tool": "axe", "tool_tier": "", "item": "logs",
		"yield": 6, "respawn_ticks": 120, "xp": 16,
	},
	KIND_IRON_ROCK: {
		"tier": 2, "skill": "mining", "level": 3, "tool": "pickaxe", "tool_tier": "bronze", "item": "iron_ore",
		"yield": 3, "respawn_ticks": 150, "xp": 18,
	},
	KIND_ICE_HOLE: {
		"tier": 2, "skill": "fishing", "level": 3, "tool": "rod", "tool_tier": "", "item": "raw_trout",
		"yield": 5, "respawn_ticks": 120, "xp": 16,
	},
}

## Blocking geometry: {id, kind, min: [x, z], max: [x, z], height}. `kind` is a wall (the
## outpost palisade), a cliff (ring one's outer edge), an outcrop (a rock in the field) or
## decor (the tent in the yard).
var solids: Array = []
## Interactable placements by id: {kind, label, min, max, height, blocks}.
var objects: Dictionary = {}
## Named regions in precedence order: {name, polygon: [[x, z], ...]}. First match wins.
var regions: Array = []
## Enemy placements by id: {kind, home: [x, z], pack}. The kind's stats are in CombatTable;
## enemies sharing a `pack` notice the player together. Every placement gets a state entry.
var enemies: Dictionary = {}

var _blocked := PackedByteArray()
## GridPath's native A* grid over `_blocked`, built on the first route and dropped by bake().
var path_grid: AStarGrid2D = null


## The first-playable world, as rings around the outpost. The walled outpost has one gate on
## its south side, the fire, the stash and the workbench. The inner ring (out to 24 m) is safe
## but cold: pines south and north of the walls, copper rocks to the east, tin to the west and
## one fishing hole to the north. Ring one (out to the cliffs at 60 m) holds the wolf packs and
## bandit archers, the better nodes (frost pines west, iron east, an ice hole north) and, at
## its far southern edge, the barred gate to ring two with the bandit captain standing at it.
## Ring one is only reached by walking through the inner ring.
static func outpost() -> WorldDef:
	var w := WorldDef.new()
	var half := 10.0
	var t := 1.0  # wall thickness in metres
	var gate_half_width := 2.0
	w.solids = [
		_solid("wall_north", [-half, -half], [half, -half + t]),
		_solid("wall_east", [half - t, -half], [half, half]),
		_solid("wall_west", [-half, -half], [-half + t, half]),
		_solid("wall_south_west", [-half, half - t], [-gate_half_width, half]),
		_solid("wall_south_east", [gate_half_width, half - t], [half, half]),
		# The keeper's tent in the south-east corner of the yard.
		_solid("tent", [6.0, 6.0], [9.0, 9.0], 1.6, KIND_DECOR),
	]
	# Ring one's outer edge: ice cliffs on all four sides out to the end of the grid, open only
	# at the ring-two gate, so no ground in the world is walkable but unreachable.
	var edge := 60.0
	var c := 4.0  # cliff thickness
	w.solids.append_array([
		_solid("cliff_north", [-edge - c, -edge - c], [edge + c, -edge], 3.0, KIND_CLIFF),
		_solid("cliff_east", [edge, -edge - c], [edge + c, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_west", [-edge - c, -edge - c], [-edge, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_south_west", [-edge - c, edge], [-gate_half_width, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_south_east", [gate_half_width, edge], [edge + c, edge + c], 3.0, KIND_CLIFF),
		_solid("cliff_beyond_gate", [-gate_half_width, edge + 2.0], [gate_half_width, edge + c], 3.0, KIND_CLIFF),
	])
	# Rock outcrops in ring one, so the walk out is a route and not a straight line.
	var outcrops := [
		[[-6.0, 34.0], [-2.0, 38.0]], [[5.0, 39.0], [9.0, 42.0]], [[-22.0, 32.0], [-18.0, 35.0]],
		[[21.0, 34.0], [26.0, 36.0]], [[-34.0, -32.0], [-30.0, -28.0]], [[28.0, -30.0], [33.0, -27.0]],
		[[-30.0, 48.0], [-25.0, 52.0]], [[26.0, 50.0], [30.0, 54.0]], [[-51.0, -10.0], [-47.0, -6.0]],
		[[48.0, -14.0], [52.0, -11.0]], [[-8.0, 48.0], [-4.0, 50.0]], [[33.0, 8.0], [36.0, 12.0]],
	]
	for i in outcrops.size():
		w.solids.append(_solid("outcrop_%d" % (i + 1), outcrops[i][0], outcrops[i][1], 1.8, KIND_OUTCROP))
	w.objects = {
		"gate": {
			"kind": KIND_GATE, "label": "Gate", "blocks": false, "height": 0.1,
			"min": [-gate_half_width, half - t], "max": [gate_half_width, half],
			"outward": [0.0, 1.0],
		},
		"fire": {
			"kind": KIND_FIRE, "label": "Fire", "blocks": true, "height": 0.6,
			"min": [-1.0, -1.0], "max": [1.0, 1.0],
		},
		"stash": {
			"kind": KIND_STASH, "label": "Stash", "blocks": true, "height": 1.0,
			"min": [-7.0, -7.0], "max": [-5.0, -6.0],
		},
		"workbench": {
			"kind": KIND_WORKBENCH, "label": "Workbench", "blocks": true, "height": 1.0,
			"min": [5.0, -7.0], "max": [7.0, -6.0],
		},
		# Barred until the captain has fallen and the outpost has built its winch.
		"ring_two_gate": {
			"kind": KIND_RING_GATE, "label": "Gate to ring two", "blocks": true, "height": 3.5,
			"min": [-gate_half_width, edge], "max": [gate_half_width, edge + 2.0],
			"guardian": "captain", "upgrade": "ring_two_gate",
		},
	}
	# Pines, one metre square: six between 4 m and 12 m south of the gate, four north of the walls.
	var trees := [
		[-7.0, 14.0], [-3.0, 17.0], [3.0, 14.0], [6.0, 19.0], [-8.0, 20.0], [1.0, 21.0],
		[-6.0, -15.0], [5.0, -14.0], [-13.0, -18.0], [12.0, -19.0],
	]
	for i in trees.size():
		_place(w, "tree_%d" % (i + 1), KIND_TREE, "Pine", trees[i], [1.0, 1.0], 3.0)
	var copper := [[13.0, -7.0], [17.0, -3.0], [13.0, 1.0]]
	for i in copper.size():
		_place(w, "copper_%d" % (i + 1), KIND_COPPER_ROCK, "Copper rock", copper[i], [2.0, 2.0], 1.0)
	var tin := [[-15.0, -7.0], [-19.0, -3.0], [-15.0, 1.0]]
	for i in tin.size():
		_place(w, "tin_%d" % (i + 1), KIND_TIN_ROCK, "Tin rock", tin[i], [2.0, 2.0], 1.0)
	_place(w, "fishing_hole", KIND_FISHING_HOLE, "Fishing hole", [-1.0, -19.0], [2.0, 2.0], 0.1)
	var frost := [[-42.0, 8.0], [-46.0, 13.0], [-39.0, 15.0], [-44.0, 3.0]]
	for i in frost.size():
		_place(w, "frost_pine_%d" % (i + 1), KIND_FROST_PINE, "Frost pine", frost[i], [1.0, 1.0], 4.0)
	var iron := [[40.0, 6.0], [45.0, 10.0], [41.0, 14.0]]
	for i in iron.size():
		_place(w, "iron_%d" % (i + 1), KIND_IRON_ROCK, "Iron rock", iron[i], [2.0, 2.0], 1.2)
	_place(w, "ice_hole", KIND_ICE_HOLE, "Ice hole", [-9.0, -43.0], [2.0, 2.0], 0.1)
	# Ring one's enemies. The near groups sit just past the southern pines: two wolves south-west,
	# a pack of three farther west, a bandit archer south-east. Chopping the south-western pine is
	# loud enough for the near pack to hear. Farther out: an archer camp by the iron, a pack among
	# the frost pines, a pack by the ice hole, two archers flanking the road south, and the
	# captain at the ring-two gate. Every group sits more than a fight's noise
	# (CombatTable.NOISE_FIGHT) from the next, so each is fought on its own.
	var placements := [
		["wolf_1", "wolf", [-7.5, 28.5], "west_pack"],
		["wolf_2", "wolf", [-5.5, 29.5], "west_pack"],
		["wolf_3", "wolf", [-25.5, 27.5], "far_pack"],
		["wolf_4", "wolf", [-27.5, 28.5], "far_pack"],
		["wolf_5", "wolf", [-24.5, 29.5], "far_pack"],
		["archer_1", "bandit_archer", [14.5, 28.5], "archer_1"],
		["archer_2", "bandit_archer", [37.5, 27.5], "east_camp"],
		["archer_3", "bandit_archer", [47.5, 24.5], "east_camp"],
		["wolf_6", "wolf", [-45.5, 25.5], "pine_pack"],
		["wolf_7", "wolf", [-47.5, 27.5], "pine_pack"],
		["wolf_8", "wolf", [10.5, -43.5], "north_pack"],
		["wolf_9", "wolf", [12.5, -41.5], "north_pack"],
		["wolf_10", "wolf", [8.5, -45.5], "north_pack"],
		["archer_4", "bandit_archer", [-15.5, 44.5], "archer_4"],
		["archer_5", "bandit_archer", [17.5, 45.5], "archer_5"],
		["captain", "bandit_captain", [0.5, 56.5], "captain"],
	]
	for p in placements:
		w.enemies[p[0]] = {"kind": p[1], "home": p[2], "pack": p[3]}
	w.regions = [
		{"name": REGION_OUTPOST, "polygon": _rect_polygon([-half, -half], [half, half])},
		{"name": REGION_INNER_RING, "polygon": _rect_polygon([-24.0, -24.0], [24.0, 24.0])},
		{"name": REGION_RING_ONE, "polygon": _rect_polygon([-edge, -edge], [edge, edge])},
		{"name": REGION_RING_TWO, "polygon": _rect_polygon([-64.0, -64.0], [64.0, 64.0])},
	]
	w.bake()
	return w


static func _place(w: WorldDef, id: String, kind: String, label: String, at: Array, size: Array, height: float) -> void:
	w.objects[id] = {
		"kind": kind, "label": label, "blocks": true, "height": height,
		"min": [at[0], at[1]], "max": [at[0] + size[0], at[1] + size[1]],
	}


static func _solid(id: String, min_xz: Array, max_xz: Array, height := 2.5, kind := KIND_WALL) -> Dictionary:
	return {"id": id, "kind": kind, "min": min_xz, "max": max_xz, "height": height}


static func _rect_polygon(min_xz: Array, max_xz: Array) -> Array:
	return [
		[min_xz[0], min_xz[1]], [max_xz[0], min_xz[1]],
		[max_xz[0], max_xz[1]], [min_xz[0], max_xz[1]],
	]


## Rasterises solids and blocking objects into the walkability grid. Call after editing them.
func bake() -> void:
	path_grid = null
	_blocked = PackedByteArray()
	_blocked.resize(cols * rows)
	_blocked.fill(0)
	for s in solids:
		_block_rect(s["min"], s["max"])
	for id in objects:
		var o: Dictionary = objects[id]
		if o.get("blocks", true):
			_block_rect(o["min"], o["max"])


## Blocks every cell whose centre lies inside the rectangle, visiting only the cells it spans.
func _block_rect(min_xz: Array, max_xz: Array) -> void:
	var lo := cell_of(Vector2(min_xz[0], min_xz[1]))
	var hi := cell_of(Vector2(max_xz[0], max_xz[1]))
	for y in range(maxi(0, lo.y), mini(rows, hi.y + 1)):
		for x in range(maxi(0, lo.x), mini(cols, hi.x + 1)):
			var c := cell_center(Vector2i(x, y))
			if c.x >= min_xz[0] and c.x < max_xz[0] and c.y >= min_xz[1] and c.y < max_xz[1]:
				_blocked[y * cols + x] = 1


# --- Grid queries ---------------------------------------------------------------------

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((pos.x - origin[0]) / cell_size)),
		int(floor((pos.y - origin[1]) / cell_size))
	)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		origin[0] + (cell.x + 0.5) * cell_size,
		origin[1] + (cell.y + 0.5) * cell_size
	)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func is_walkable_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and _blocked[cell.y * cols + cell.x] == 0


## One byte per cell, row-major from cell (0, 0), 1 where the cell is blocked. For hot loops
## that cannot afford a call per cell; everything else asks is_walkable_cell().
func blocked_cells() -> PackedByteArray:
	return _blocked


func is_walkable(pos: Vector2) -> bool:
	return is_walkable_cell(cell_of(pos))


## True when `pos` and the points `margin` metres to each side of it are all walkable,
## so a path can hug a wall without visually clipping into it.
func is_walkable_with_margin(pos: Vector2, margin: float) -> bool:
	return (
		is_walkable(pos)
		and is_walkable(pos + Vector2(margin, 0))
		and is_walkable(pos - Vector2(margin, 0))
		and is_walkable(pos + Vector2(0, margin))
		and is_walkable(pos - Vector2(0, margin))
	)


## The walkable cell nearest to `pos` within `max_radius` cells (Chebyshev), or null.
## The cell containing `pos` itself wins when it is walkable.
func nearest_walkable_cell(pos: Vector2, max_radius: int) -> Variant:
	var home := cell_of(pos)
	if is_walkable_cell(home):
		return home
	var best: Variant = null
	var best_d := INF
	for r in range(1, max_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := home + Vector2i(dx, dy)
				if not is_walkable_cell(c):
					continue
				var d := cell_center(c).distance_squared_to(pos)
				if d < best_d:
					best_d = d
					best = c
		if best != null:
			return best
	return best


## Cells that an actor may stand on to interact with an object: the object's own cells
## when it does not block, otherwise the walkable ring of cells around its footprint.
func approach_cells(object_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not objects.has(object_id):
		return out
	var o: Dictionary = objects[object_id]
	var lo := cell_of(Vector2(o["min"][0], o["min"][1]))
	var hi := cell_of(Vector2(o["max"][0] - 0.001, o["max"][1] - 0.001))
	var pad := 0 if not o.get("blocks", true) else 1
	for y in range(lo.y - pad, hi.y + pad + 1):
		for x in range(lo.x - pad, hi.x + pad + 1):
			var c := Vector2i(x, y)
			if is_walkable_cell(c):
				out.append(c)
	return out


## Ids of every placed object whose kind is a gatherable node, in placement order.
func node_ids() -> Array[String]:
	var out: Array[String] = []
	for id in objects:
		if NODE_KINDS.has(objects[id]["kind"]):
			out.append(id)
	return out


## Ids of every placed object of `kind`, in placement order.
func objects_of_kind(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in objects:
		if objects[id]["kind"] == kind:
			out.append(id)
	return out


## Distance from `pos` to the nearest point of the object's footprint (0 when inside it).
func distance_to_object(object_id: String, pos: Vector2) -> float:
	var o: Dictionary = objects[object_id]
	var nearest := Vector2(
		clampf(pos.x, o["min"][0], o["max"][0]),
		clampf(pos.y, o["min"][1], o["max"][1])
	)
	return nearest.distance_to(pos)


func object_center(object_id: String) -> Vector2:
	var o: Dictionary = objects[object_id]
	return Vector2((o["min"][0] + o["max"][0]) * 0.5, (o["min"][1] + o["max"][1]) * 0.5)


# --- Regions ------------------------------------------------------------------------

## Name of the first region whose polygon contains `pos`, or "" outside every region.
func region_at(pos: Vector2) -> String:
	for r in regions:
		var poly := PackedVector2Array()
		for p in r["polygon"]:
			poly.append(Vector2(p[0], p[1]))
		if Geometry2D.is_point_in_polygon(pos, poly):
			return r["name"]
	return ""
