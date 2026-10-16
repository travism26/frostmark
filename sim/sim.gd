## The Frostmark simulation: all game state, advanced one fixed tick at a time by `step()`,
## driven only by `command()` and read back through events and `snapshot()`.
##
## This file and everything under sim/ is engine-free on purpose: RefCounted only, no Node,
## no scene, no Input, no rendering, no autoload. The presentation (scenes/) is glue that
## turns clicks into commands and events into motion. Tests drive this class through
## `command()` and `step()` alone. See docs/simulation.md for the contract.
##
## `state` is one plain-data Dictionary (ints, floats, strings, arrays, dictionaries) so it
## can be snapshotted, restored and later saved as JSON without conversion.
class_name Sim
extends RefCounted

## Length of one simulation tick in seconds. The presentation accumulates frame time and
## calls `step()` once per TICK_SECONDS; nothing in the rules depends on wall-clock time.
const TICK_SECONDS := 0.5
## Walking speed in metres per second, so WALK_PER_TICK metres of path are consumed per tick.
const WALK_SPEED := 4.0
const WALK_PER_TICK := WALK_SPEED * TICK_SECONDS
## A click on a blocked cell snaps to the nearest walkable cell within this many cells.
const SNAP_RADIUS_CELLS := 2
## Bumped whenever the state shape changes; `restore()` refuses snapshots it cannot read.
const STATE_VERSION := 1

var world: WorldDef
var state: Dictionary = {}
var _events: Array[Dictionary] = []


func _init(world_def: WorldDef = null) -> void:
	world = world_def if world_def != null else WorldDef.outpost()
	state = new_state()


## A fresh state for this world: the player at the spawn point, idle, facing south.
func new_state() -> Dictionary:
	var spawn := Vector2(world.spawn[0], world.spawn[1])
	return {
		"version": STATE_VERSION,
		"tick": 0,
		"player": {
			"pos": _xz(spawn),
			"facing": [0.0, 1.0],
			"path": [],
			"target_object": "",
			"region": world.region_at(spawn),
		},
	}


# --- Commands -----------------------------------------------------------------------

## Issues a command. Returns {ok: bool, reason: String}. A rejected command also emits a
## `command_rejected` event so the presentation can show why. Commands only record intent;
## everything that moves or changes state happens inside `step()`.
func command(kind: String, args: Dictionary = {}) -> Dictionary:
	if not SimVocab.COMMANDS.has(kind):
		return _reject(kind, args, SimVocab.REASON_UNKNOWN_COMMAND)
	match kind:
		SimVocab.MOVE_TO:
			return _cmd_move_to(args)
		SimVocab.INTERACT:
			return _cmd_interact(args)
	return _reject(kind, args, SimVocab.REASON_NOT_IMPLEMENTED)


func _cmd_move_to(args: Dictionary) -> Dictionary:
	var target: Variant = _arg_pos(args, "pos")
	if target == null:
		return _reject(SimVocab.MOVE_TO, args, SimVocab.REASON_BAD_ARGS)
	var point: Vector2 = target
	if not world.in_bounds(world.cell_of(point)):
		return _reject(SimVocab.MOVE_TO, args, SimVocab.REASON_OUTSIDE_WORLD)
	var cell: Variant = world.nearest_walkable_cell(point, SNAP_RADIUS_CELLS)
	if cell == null:
		return _reject(SimVocab.MOVE_TO, args, SimVocab.REASON_NOT_WALKABLE)
	# Walk to the exact click when its own cell is walkable, else to the snapped cell's centre.
	var destination := point if world.is_walkable(point) else world.cell_center(cell)
	if not _set_path(cell, destination, ""):
		return _reject(SimVocab.MOVE_TO, args, SimVocab.REASON_UNREACHABLE)
	return {"ok": true, "reason": ""}


func _cmd_interact(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("object_id", ""))
	if not world.objects.has(id):
		return _reject(SimVocab.INTERACT, args, SimVocab.REASON_UNKNOWN_OBJECT)
	var here := player_pos()
	var cells := world.approach_cells(id)
	# Try approach cells nearest the player first; the first routable one wins.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return world.cell_center(a).distance_squared_to(here) < world.cell_center(b).distance_squared_to(here))
	for cell in cells:
		if _set_path(cell, world.cell_center(cell), id):
			return {"ok": true, "reason": ""}
	return _reject(SimVocab.INTERACT, args, SimVocab.REASON_UNREACHABLE)


## Routes the player to `goal_cell`, ending exactly at `destination`. False when unreachable.
func _set_path(goal_cell: Vector2i, destination: Vector2, object_id: String) -> bool:
	var here := player_pos()
	var cells := GridPath.find(world, world.cell_of(here), goal_cell)
	if cells.is_empty():
		return false
	var points: Array[Vector2] = []
	for i in range(1, cells.size()):
		points.append(world.cell_center(cells[i]))
	if points.is_empty() or points[points.size() - 1] != destination:
		points.append(destination)
	var path := GridPath.smooth(world, here, points)
	var plain: Array = []
	var length := 0.0
	var prev := here
	for p in path:
		plain.append(_xz(p))
		length += prev.distance_to(p)
		prev = p
	state["player"]["path"] = plain
	state["player"]["target_object"] = object_id
	_emit({
		"kind": SimVocab.EV_PATH_SET, "from": _xz(here), "to": _xz(destination),
		"length": length, "object_id": object_id,
	})
	return true


func _reject(kind: String, args: Dictionary, reason: String) -> Dictionary:
	_emit({"kind": SimVocab.EV_COMMAND_REJECTED, "command": kind, "reason": reason, "args": args})
	return {"ok": false, "reason": reason}


# --- Ticking --------------------------------------------------------------------------

## Advances the world by exactly one tick.
func step() -> void:
	state["tick"] = int(state["tick"]) + 1
	_step_movement()


func _step_movement() -> void:
	var player: Dictionary = state["player"]
	var path: Array = player["path"]
	if path.is_empty():
		return
	var start := player_pos()
	var pos := start
	var budget := WALK_PER_TICK
	var via: Array = [_xz(start)]
	while budget > 0.0 and not path.is_empty():
		var next := Vector2(path[0][0], path[0][1])
		var d := pos.distance_to(next)
		if d <= budget:
			pos = next
			path.pop_front()
			budget -= d
		else:
			pos = pos.move_toward(next, budget)
			budget = 0.0
		if pos != start or via.size() > 1:
			via.append(_xz(pos))
	if pos != start:
		var last := Vector2(via[via.size() - 2][0], via[via.size() - 2][1])
		var dir := (pos - last).normalized()
		player["facing"] = _xz(dir)
	player["pos"] = _xz(pos)
	_emit({
		"kind": SimVocab.EV_MOVED, "from": _xz(start), "to": _xz(pos), "path": via,
		"facing": player["facing"],
	})
	var region := world.region_at(pos)
	if region != player["region"]:
		_emit({"kind": SimVocab.EV_REGION_CHANGED, "from": player["region"], "to": region})
		player["region"] = region
	if path.is_empty():
		var object_id: String = player["target_object"]
		player["target_object"] = ""
		_emit({"kind": SimVocab.EV_ARRIVED, "pos": _xz(pos), "object_id": object_id})
		if object_id != "":
			_emit({
				"kind": SimVocab.EV_INTERACTED, "object_id": object_id,
				"object_kind": world.objects[object_id]["kind"], "action": "none",
			})


# --- Events ---------------------------------------------------------------------------

## Returns every event emitted since the last drain, oldest first, and clears the list.
func drain_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func _emit(event: Dictionary) -> void:
	_events.append(event)


# --- Snapshot -------------------------------------------------------------------------

## A deep copy of the whole state as plain data. Safe to JSON.stringify.
func snapshot() -> Dictionary:
	return state.duplicate(true)


## Replaces the state with `snap` (deep-copied). Returns false, leaving the state untouched,
## when the snapshot is not one this version can read.
func restore(snap: Dictionary) -> bool:
	if not snap.has("version") or int(snap["version"]) != STATE_VERSION:
		return false
	if not snap.has("player") or not snap.has("tick"):
		return false
	var copy := snap.duplicate(true)
	copy["version"] = STATE_VERSION
	copy["tick"] = int(copy["tick"])
	var player: Dictionary = copy["player"]
	player["pos"] = _xz(Vector2(player["pos"][0], player["pos"][1]))
	player["facing"] = _xz(Vector2(player["facing"][0], player["facing"][1]))
	var path: Array = []
	for p in player.get("path", []):
		path.append(_xz(Vector2(p[0], p[1])))
	player["path"] = path
	player["target_object"] = str(player.get("target_object", ""))
	player["region"] = str(player.get("region", world.region_at(player_pos_of(player))))
	state = copy
	return true


# --- Read helpers ---------------------------------------------------------------------

func player_pos() -> Vector2:
	return player_pos_of(state["player"])


static func player_pos_of(player: Dictionary) -> Vector2:
	return Vector2(player["pos"][0], player["pos"][1])


func player_facing() -> Vector2:
	return Vector2(state["player"]["facing"][0], state["player"]["facing"][1])


func is_moving() -> bool:
	return not (state["player"]["path"] as Array).is_empty()


func _arg_pos(args: Dictionary, key: String) -> Variant:
	var v: Variant = args.get(key)
	if v is Vector2:
		return v
	if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
		return Vector2(v[0], v[1])
	return null


static func _xz(v: Vector2) -> Array:
	return [float(v.x), float(v.y)]
