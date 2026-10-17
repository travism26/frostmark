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
const KIND_GATE := "gate"
const KIND_FIRE := "fire"
const KIND_STASH := "stash"
const KIND_WORKBENCH := "workbench"
const KIND_TREE := "tree"

const REGION_OUTPOST := "outpost"
const REGION_INNER_RING := "inner_ring"
const REGION_RING_ONE := "ring_one"

var cell_size := 1.0
var cols := 64
var rows := 64
var origin: Array = [-32.0, -32.0]
var spawn: Array = [0.5, 4.5]
## Where a player who collapses from the cold wakes: beside the outpost fire.
var rescue: Array = [0.5, 1.5]

## Gatherable node kinds: the skill they train, the tool they need, what one success yields,
## how many yields a node holds before it is depleted, the ticks until it regrows, and the
## experience per success. Placed objects of these kinds get a matching entry in the state.
const NODE_KINDS := {
	KIND_TREE: {
		"skill": "woodcutting", "level": 1, "tool": "axe", "item": "logs",
		"yield": 4, "respawn_ticks": 90, "xp": 10,
	},
}

## Blocking geometry: {id, kind, min: [x, z], max: [x, z], height}.
var solids: Array = []
## Interactable placements by id: {kind, label, min, max, height, blocks}.
var objects: Dictionary = {}
## Named regions in precedence order: {name, polygon: [[x, z], ...]}. First match wins.
var regions: Array = []
## Enemy placements by id: {kind, home: [x, z], pack}. The kind's stats are in CombatTable;
## enemies sharing a `pack` notice the player together. Every placement gets a state entry.
var enemies: Dictionary = {}

var _blocked := PackedByteArray()


## The outpost world: a walled outpost with one gate opening on its south side, placeholder
## blocks for the fire, stash and workbench, and a stand of trees in the inner ring south
## of the gate.
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
	]
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
	}
	# Pines, one metre square, between 4 m and 12 m south of the gate.
	var trees := [[-7.0, 14.0], [-3.0, 17.0], [3.0, 14.0], [6.0, 19.0], [-8.0, 20.0], [1.0, 21.0]]
	for i in trees.size():
		var at: Array = trees[i]
		w.objects["tree_%d" % (i + 1)] = {
			"kind": KIND_TREE, "label": "Pine", "blocks": true, "height": 3.0,
			"min": [at[0], at[1]], "max": [at[0] + 1.0, at[1] + 1.0],
		}
	# A small patch just past the trees, over the line into ring one: two wolves south-west of
	# the stand, a pack of three farther west, and a bandit archer to the south-east. Ring one
	# proper comes later; this is enough to find a fight. Chopping the south-western pine is
	# loud enough for the near pack to hear.
	var placements := [
		["wolf_1", "wolf", [-7.5, 28.5], "west_pack"],
		["wolf_2", "wolf", [-5.5, 29.5], "west_pack"],
		["wolf_3", "wolf", [-19.5, 27.5], "far_pack"],
		["wolf_4", "wolf", [-21.5, 28.5], "far_pack"],
		["wolf_5", "wolf", [-18.5, 29.5], "far_pack"],
		["archer_1", "bandit_archer", [8.5, 28.5], "archer_1"],
	]
	for p in placements:
		w.enemies[p[0]] = {"kind": p[1], "home": p[2], "pack": p[3]}
	w.regions = [
		{"name": REGION_OUTPOST, "polygon": _rect_polygon([-half, -half], [half, half])},
		{"name": REGION_INNER_RING, "polygon": _rect_polygon([-24.0, -24.0], [24.0, 24.0])},
		{"name": REGION_RING_ONE, "polygon": _rect_polygon([-32.0, -32.0], [32.0, 32.0])},
	]
	w.bake()
	return w


static func _solid(id: String, min_xz: Array, max_xz: Array, height := 2.5) -> Dictionary:
	return {"id": id, "kind": KIND_WALL, "min": min_xz, "max": max_xz, "height": height}


static func _rect_polygon(min_xz: Array, max_xz: Array) -> Array:
	return [
		[min_xz[0], min_xz[1]], [max_xz[0], min_xz[1]],
		[max_xz[0], max_xz[1]], [min_xz[0], max_xz[1]],
	]


## Rasterises solids and blocking objects into the walkability grid. Call after editing them.
func bake() -> void:
	_blocked = PackedByteArray()
	_blocked.resize(cols * rows)
	_blocked.fill(0)
	for s in solids:
		_block_rect(s["min"], s["max"])
	for id in objects:
		var o: Dictionary = objects[id]
		if o.get("blocks", true):
			_block_rect(o["min"], o["max"])


func _block_rect(min_xz: Array, max_xz: Array) -> void:
	for y in rows:
		for x in cols:
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
