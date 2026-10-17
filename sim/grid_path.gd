## A* path-finding over a WorldDef grid, plus line-of-sight smoothing.
##
## Pure functions over plain data so the simulation can route headless. Eight-connected,
## no corner cutting (a diagonal step needs both orthogonal neighbours free), octile heuristic.
## The search is the engine's native AStarGrid2D, built once per world and kept on it
## (`WorldDef.path_grid`), so a route across the whole world costs well under a frame.
class_name GridPath
extends RefCounted

## How close to a blocked cell a smoothed segment may pass, in metres.
const SMOOTH_MARGIN := 0.3


## Cells from `from` to `to` inclusive, or an empty array when no route exists.
static func find(world: WorldDef, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not world.is_walkable_cell(from) or not world.is_walkable_cell(to):
		return out
	if from == to:
		out.append(from)
		return out
	return _grid(world).get_id_path(from, to)


## The world's A* grid, built from its walkability on first use. Straight steps cost 1 and
## diagonal ones the square root of 2.
static func _grid(world: WorldDef) -> AStarGrid2D:
	if world.path_grid != null:
		return world.path_grid
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, world.cols, world.rows)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var blocked := world.blocked_cells()
	for i in blocked.size():
		if blocked[i] != 0:
			grid.set_point_solid(Vector2i(i % world.cols, i / world.cols))
	world.path_grid = grid
	return grid


## True when the straight segment a->b stays on walkable ground (with SMOOTH_MARGIN): every
## sample a quarter cell apart passes WorldDef.is_walkable_with_margin(). The check is inlined
## over the raw grid because smoothing and every chasing enemy call it in a loop.
static func has_line_of_sight(world: WorldDef, a: Vector2, b: Vector2) -> bool:
	var blocked := world.blocked_cells()
	var cols := world.cols
	var rows := world.rows
	var ox: float = world.origin[0]
	var oz: float = world.origin[1]
	var size := world.cell_size
	var steps := maxi(1, int(ceil(a.distance_to(b) / (size * 0.25))))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / steps)
		var cx := int(floor((p.x - ox) / size))
		var cz := int(floor((p.y - oz) / size))
		var lx := int(floor((p.x - SMOOTH_MARGIN - ox) / size))
		var hx := int(floor((p.x + SMOOTH_MARGIN - ox) / size))
		var lz := int(floor((p.y - SMOOTH_MARGIN - oz) / size))
		var hz := int(floor((p.y + SMOOTH_MARGIN - oz) / size))
		if lx < 0 or lz < 0 or hx >= cols or hz >= rows:
			return false
		var row := cz * cols
		if blocked[row + lx] != 0 or blocked[row + cx] != 0 or blocked[row + hx] != 0:
			return false
		if blocked[lz * cols + cx] != 0 or blocked[hz * cols + cx] != 0:
			return false
	return true


## String-pulling: from `start`, each hop goes to a far waypoint it can see. It tries the last
## waypoint first (open ground usually sees it), else gallops 1, 2, 4, 8 ... waypoints ahead
## until one is out of sight and halves back to the farthest one in sight, so a hop costs a
## handful of sight checks however long the path. `points` are the waypoints after `start`;
## the last point is always kept, and every segment of the result has line of sight.
static func smooth(world: WorldDef, start: Vector2, points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var last := points.size() - 1
	var from := start
	var i := 0
	while i <= last:
		# Neighbouring cells of the path always see each other, so points[i] is the fallback.
		var seen := i
		if i < last and has_line_of_sight(world, from, points[last]):
			seen = last
		else:
			var stride := 1
			var blind := -1
			while seen < last:
				var j := mini(seen + stride, last)
				if not has_line_of_sight(world, from, points[j]):
					blind = j
					break
				seen = j
				stride *= 2
			while blind - seen > 1:
				var mid := (seen + blind) / 2
				if has_line_of_sight(world, from, points[mid]):
					seen = mid
				else:
					blind = mid
		out.append(points[seen])
		from = points[seen]
		i = seen + 1
	return out
