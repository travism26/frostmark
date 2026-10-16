## A* path-finding over a WorldDef grid, plus line-of-sight smoothing.
##
## Pure functions over plain data so the simulation can route headless. Eight-connected,
## no corner cutting (a diagonal step needs both orthogonal neighbours free), octile heuristic.
class_name GridPath
extends RefCounted

const COST_STRAIGHT := 10
const COST_DIAGONAL := 14
## How close to a blocked cell a smoothed segment may pass, in metres.
const SMOOTH_MARGIN := 0.3

const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## Cells from `from` to `to` inclusive, or an empty array when no route exists.
static func find(world: WorldDef, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not world.is_walkable_cell(from) or not world.is_walkable_cell(to):
		return out
	if from == to:
		out.append(from)
		return out

	var cols := world.cols
	var n := cols * world.rows
	var g := PackedInt32Array()
	g.resize(n)
	g.fill(0x7fffffff)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	closed.fill(0)

	var start := from.y * cols + from.x
	var goal := to.y * cols + to.x
	g[start] = 0
	var heap := _Heap.new()
	heap.push(_heuristic(from, to), start)

	while not heap.is_empty():
		var cur: int = heap.pop()
		if cur == goal:
			break
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		var cc := Vector2i(cur % cols, cur / cols)
		for d in _DIRS:
			var nc := cc + d
			if not world.is_walkable_cell(nc):
				continue
			var diagonal := d.x != 0 and d.y != 0
			if diagonal:
				if not world.is_walkable_cell(cc + Vector2i(d.x, 0)):
					continue
				if not world.is_walkable_cell(cc + Vector2i(0, d.y)):
					continue
			var ni := nc.y * cols + nc.x
			if closed[ni] == 1:
				continue
			var ng: int = g[cur] + (COST_DIAGONAL if diagonal else COST_STRAIGHT)
			if ng < g[ni]:
				g[ni] = ng
				came[ni] = cur
				heap.push(ng + _heuristic(nc, to), ni)

	if came[goal] == -1:
		return out
	var i := goal
	while i != -1:
		out.append(Vector2i(i % cols, i / cols))
		i = came[i]
	out.reverse()
	return out


static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return COST_STRAIGHT * (dx + dy) + (COST_DIAGONAL - 2 * COST_STRAIGHT) * mini(dx, dy)


## True when the straight segment a->b stays on walkable ground (with SMOOTH_MARGIN).
static func has_line_of_sight(world: WorldDef, a: Vector2, b: Vector2) -> bool:
	var length := a.distance_to(b)
	var step := world.cell_size * 0.25
	var steps := maxi(1, int(ceil(length / step)))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if not world.is_walkable_with_margin(p, SMOOTH_MARGIN):
			return false
	return true


## Greedy string-pulling: from `start`, keep only the farthest waypoint each hop can see.
## `points` are the waypoints after `start`; the last point is always kept.
static func smooth(world: WorldDef, start: Vector2, points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var from := start
	var i := 0
	while i < points.size():
		var far := i
		for j in range(points.size() - 1, i, -1):
			if has_line_of_sight(world, from, points[j]):
				far = j
				break
		out.append(points[far])
		from = points[far]
		i = far + 1
	return out


## Binary min-heap of (priority, cell index) pairs.
class _Heap:
	extends RefCounted
	var _keys := PackedInt32Array()
	var _vals := PackedInt32Array()

	func is_empty() -> bool:
		return _keys.is_empty()

	func push(key: int, val: int) -> void:
		_keys.append(key)
		_vals.append(val)
		var i := _keys.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if _keys[parent] <= _keys[i]:
				break
			_swap(i, parent)
			i = parent

	func pop() -> int:
		var top := _vals[0]
		var last := _keys.size() - 1
		_swap(0, last)
		_keys.remove_at(last)
		_vals.remove_at(last)
		var i := 0
		var n := _keys.size()
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < n and _keys[l] < _keys[m]:
				m = l
			if r < n and _keys[r] < _keys[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var k := _keys[a]
		_keys[a] = _keys[b]
		_keys[b] = k
		var v := _vals[a]
		_vals[a] = _vals[b]
		_vals[b] = v
