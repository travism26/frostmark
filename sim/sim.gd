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
## Bumped whenever the state shape changes. `restore()` migrates older snapshots forward
## (SaveCode.migrate) and refuses ones it cannot read.
const STATE_VERSION := 2

## The pack: a fixed number of slots, and a carried weight (pack plus equipment, in kg)
## above which walking slows to OVERWEIGHT_SPEED of normal.
const PACK_SLOTS := 12
const CARRY_LIMIT := 20
const OVERWEIGHT_SPEED := 0.6
## Stash slots a new character starts with; outpost upgrades raise it in a later slice.
const STASH_START_SLOTS := 8
const STARTING_TOOL := "wooden_axe"

## Warmth is whole points. Outside the outpost it drains WARMTH_DRAIN per tick, so a full
## gauge lasts WARMTH_MAX / WARMTH_DRAIN ticks (three minutes). Within FIRE_REACH metres of
## a fire it refills FIRE_WARMTH per tick and health refills FIRE_HEALTH per tick. At zero
## warmth, health drains COLD_DAMAGE per tick instead; at zero health the player collapses
## and wakes by the outpost fire with full health and the pack intact.
const WARMTH_MAX := 360
const WARMTH_DRAIN := 1
const HEALTH_MAX := 100
const COLD_DAMAGE := 1
const FIRE_REACH := 3.0
const FIRE_WARMTH := 24
const FIRE_HEALTH := 2
## How close (metres from its footprint) the player must stand to use the workbench or a node.
const USE_REACH := 1.5

## Gathering: one attempt takes `gather_ticks(level)` ticks and succeeds with
## `gather_chance(level)` percent. Both improve with the gathering skill's level.
const GATHER_BASE_TICKS := 4
const GATHER_MIN_TICKS := 2
const GATHER_LEVELS_PER_TICK := 4
const GATHER_BASE_CHANCE := 60
const GATHER_CHANCE_PER_LEVEL := 4
const GATHER_MAX_CHANCE := 95

## Commands that change the inventory are queued and applied at the start of the next tick.
const QUEUED_COMMANDS: Array[String] = [
	SimVocab.SMITH, SimVocab.EQUIP, SimVocab.DROP, SimVocab.DEPOSIT, SimVocab.WITHDRAW,
]

var world: WorldDef
var state: Dictionary = {}
var _events: Array[Dictionary] = []
## Why this tick reached a save point, or "" when it did not. Flushed as one `saved` event.
var _save_due := ""


func _init(world_def: WorldDef = null) -> void:
	world = world_def if world_def != null else WorldDef.outpost()
	state = new_state()


## A fresh state for this world: a new character at the spawn point, idle, facing south,
## warm, with an empty pack, the starting axe in the tool slot and every node full.
func new_state() -> Dictionary:
	var spawn := Vector2(world.spawn[0], world.spawn[1])
	return {
		"version": STATE_VERSION,
		"tick": 0,
		"rng": 1,
		"player": {
			"pos": _xz(spawn),
			"facing": [0.0, 1.0],
			"path": [],
			"target_object": "",
			"region": world.region_at(spawn),
			"activity": {},
		},
		"warmth": WARMTH_MAX,
		"health": HEALTH_MAX,
		"inventory": {
			"pack": Inventory.empty_slots(PACK_SLOTS),
			"equipment": {
				ItemTable.SLOT_WEAPON: "", ItemTable.SLOT_ARMOUR: "", ItemTable.SLOT_TOOL: STARTING_TOOL,
			},
		},
		"stash": {"capacity": STASH_START_SLOTS, "slots": Inventory.empty_slots(STASH_START_SLOTS)},
		"skills": SkillTable.new_table(),
		"nodes": _full_nodes(),
		"upgrades": [],
		"pending": [],
	}


func _full_nodes() -> Dictionary:
	var out := {}
	for id in world.node_ids():
		out[id] = {"left": int(WorldDef.NODE_KINDS[world.objects[id]["kind"]]["yield"]), "respawn_tick": 0}
	return out


# --- Commands -----------------------------------------------------------------------

## Issues a command. Returns {ok: bool, reason: String}. A rejected command also emits a
## `command_rejected` event so the presentation can show why. Commands only record intent;
## everything that moves or changes state happens inside `step()`.
func command(kind: String, args: Dictionary = {}) -> Dictionary:
	if not SimVocab.COMMANDS.has(kind):
		return _reject(kind, args, SimVocab.REASON_UNKNOWN_COMMAND)
	if QUEUED_COMMANDS.has(kind):
		var reason := _apply(kind, args, false)
		if reason != "":
			return _reject(kind, args, reason)
		(state["pending"] as Array).append({"kind": kind, "args": args.duplicate(true)})
		return {"ok": true, "reason": ""}
	match kind:
		SimVocab.MOVE_TO:
			return _cmd_move_to(args)
		SimVocab.INTERACT:
			return _cmd_interact(args)
		SimVocab.GATHER:
			return _cmd_gather(args)
		SimVocab.CROSS_GATE:
			return _cmd_cross_gate(args)
		SimVocab.EXPORT_SAVE:
			return {"ok": true, "reason": "", "code": export_code()}
		SimVocab.IMPORT_SAVE:
			return _cmd_import_save(args)
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
	if is_node(id):
		var reason := _gather_blocker(id)
		if reason != "":
			return _reject(SimVocab.INTERACT, args, reason)
	return _walk_to_object(SimVocab.INTERACT, id, args)


## `gather` is `interact` restricted to gatherable nodes: walk there, then gather on arrival.
func _cmd_gather(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("object_id", ""))
	if not world.objects.has(id):
		return _reject(SimVocab.GATHER, args, SimVocab.REASON_UNKNOWN_OBJECT)
	if not is_node(id):
		return _reject(SimVocab.GATHER, args, SimVocab.REASON_NOT_GATHERABLE)
	var reason := _gather_blocker(id)
	if reason != "":
		return _reject(SimVocab.GATHER, args, reason)
	return _walk_to_object(SimVocab.GATHER, id, args)


## Walks through the nearest gate to a point GATE_STEP metres beyond it on the other side.
func _cmd_cross_gate(args: Dictionary) -> Dictionary:
	var gates := world.objects_of_kind(WorldDef.KIND_GATE)
	if gates.is_empty():
		return _reject(SimVocab.CROSS_GATE, args, SimVocab.REASON_UNKNOWN_OBJECT)
	var here := player_pos()
	gates.sort_custom(func(a: String, b: String) -> bool:
		return world.object_center(a).distance_squared_to(here) < world.object_center(b).distance_squared_to(here))
	var gate: Dictionary = world.objects[gates[0]]
	var outward := Vector2(gate["outward"][0], gate["outward"][1])
	var side := 1.0 if in_outpost() else -1.0
	var target := world.object_center(gates[0]) + outward * side * 2.5
	var cell: Variant = world.nearest_walkable_cell(target, SNAP_RADIUS_CELLS)
	if cell == null or not _set_path(cell, world.cell_center(cell), ""):
		return _reject(SimVocab.CROSS_GATE, args, SimVocab.REASON_UNREACHABLE)
	return {"ok": true, "reason": ""}


func _cmd_import_save(args: Dictionary) -> Dictionary:
	var decoded := SaveCode.decode(str(args.get("code", "")), STATE_VERSION)
	var reason: String = decoded["reason"]
	if decoded["ok"] and not restore(decoded["snapshot"]):
		reason = SimVocab.REASON_BAD_SNAPSHOT
	if reason != "":
		_emit({"kind": SimVocab.EV_SAVE_REJECTED, "reason": reason})
		return _reject(SimVocab.IMPORT_SAVE, {}, reason)
	_emit({"kind": SimVocab.EV_SAVED, "reason": SimVocab.IMPORT_SAVE, "tick": state["tick"]})
	return {"ok": true, "reason": ""}


func _walk_to_object(kind: String, id: String, args: Dictionary) -> Dictionary:
	var here := player_pos()
	var cells := world.approach_cells(id)
	# Try approach cells nearest the player first; the first routable one wins.
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return world.cell_center(a).distance_squared_to(here) < world.cell_center(b).distance_squared_to(here))
	for cell in cells:
		if _set_path(cell, world.cell_center(cell), id):
			return {"ok": true, "reason": ""}
	return _reject(kind, args, SimVocab.REASON_UNREACHABLE)


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
	_stop_activity(SimVocab.REASON_MOVED)
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

## Advances the world by exactly one tick: queued inventory commands, then movement, then
## gathering, node regrowth and the cold. A save point reached during the tick is reported
## once, at its end, so the saved state is the whole tick.
func step() -> void:
	state["tick"] = int(state["tick"]) + 1
	_step_pending()
	_step_movement()
	_step_activity()
	_step_nodes()
	_step_survival()
	if _save_due != "":
		_emit({"kind": SimVocab.EV_SAVED, "reason": _save_due, "tick": state["tick"]})
		_save_due = ""


func _step_pending() -> void:
	var pending: Array = state["pending"]
	state["pending"] = []
	for p in pending:
		var reason := _apply(p["kind"], p["args"], true)
		if reason != "":
			_reject(p["kind"], p["args"], reason)


func _step_movement() -> void:
	var player: Dictionary = state["player"]
	var path: Array = player["path"]
	if path.is_empty():
		return
	var start := player_pos()
	var pos := start
	var budget := WALK_PER_TICK * (OVERWEIGHT_SPEED if is_overweight() else 1.0)
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
		var from: String = player["region"]
		_emit({"kind": SimVocab.EV_REGION_CHANGED, "from": from, "to": region})
		player["region"] = region
		# Walls leave the gate as the only way in, so walking into the outpost is crossing it.
		if region == WorldDef.REGION_OUTPOST:
			_bank()
	if path.is_empty():
		var object_id: String = player["target_object"]
		player["target_object"] = ""
		_emit({"kind": SimVocab.EV_ARRIVED, "pos": _xz(pos), "object_id": object_id})
		if object_id != "":
			var action := _action_for(object_id)
			_emit({
				"kind": SimVocab.EV_INTERACTED, "object_id": object_id,
				"object_kind": world.objects[object_id]["kind"], "action": action,
			})
			if action == SimVocab.ACTION_GATHER:
				_start_gathering(object_id)


func _action_for(object_id: String) -> String:
	match world.objects[object_id]["kind"]:
		WorldDef.KIND_TREE:
			return SimVocab.ACTION_GATHER
		WorldDef.KIND_FIRE:
			return SimVocab.ACTION_WARM
		WorldDef.KIND_STASH:
			return SimVocab.ACTION_STASH
		WorldDef.KIND_WORKBENCH:
			return SimVocab.ACTION_CRAFT
	return SimVocab.ACTION_NONE


# --- Banking --------------------------------------------------------------------------

## Moves the whole pack into the stash. What does not fit stays in the pack and is
## reported as overflow. Always a save point, even with an empty pack.
func _bank() -> void:
	var pack: Array = state["inventory"]["pack"]
	var stash: Array = state["stash"]["slots"]
	var banked: Array = []
	var overflow: Array = []
	for i in pack.size():
		var s: Variant = pack[i]
		if s == null:
			continue
		var kind: String = s["item"]
		var count := int(s["count"])
		var left := Inventory.add(stash, kind, count)
		if left < count:
			banked.append({"item": kind, "count": count - left})
		if left > 0:
			overflow.append({"item": kind, "count": left})
			s["count"] = left
		else:
			pack[i] = null
	_emit({"kind": SimVocab.EV_BANKED, "items": _merged(banked), "overflow": _merged(overflow)})
	_save_due = "gate"


static func _merged(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		var found := false
		for o in out:
			if o["item"] == e["item"]:
				o["count"] += e["count"]
				found = true
				break
		if not found:
			out.append(e.duplicate())
	return out


# --- Gathering ------------------------------------------------------------------------

func is_node(object_id: String) -> bool:
	return world.objects.has(object_id) and WorldDef.NODE_KINDS.has(world.objects[object_id]["kind"])


func _node_def(object_id: String) -> Dictionary:
	return WorldDef.NODE_KINDS[world.objects[object_id]["kind"]]


## Why gathering `object_id` cannot happen right now, or "" when it can.
func _gather_blocker(object_id: String) -> String:
	var def := _node_def(object_id)
	if int(state["nodes"][object_id]["left"]) <= 0:
		return SimVocab.REASON_DEPLETED
	if not has_tool(def["tool"]):
		return SimVocab.REASON_NO_TOOL
	if skill_level(def["skill"]) < int(def["level"]):
		return SimVocab.REASON_LEVEL_TOO_LOW
	if Inventory.is_full_for(state["inventory"]["pack"], def["item"]):
		return SimVocab.REASON_PACK_FULL
	return ""


func _start_gathering(object_id: String) -> void:
	var reason := _gather_blocker(object_id)
	if reason != "":
		_emit({
			"kind": SimVocab.EV_ACTIVITY_STOPPED, "activity": SimVocab.GATHER,
			"object_id": object_id, "reason": reason,
		})
		return
	state["player"]["activity"] = {"kind": SimVocab.GATHER, "object_id": object_id, "progress": 0}


func _stop_activity(reason: String) -> void:
	var activity: Dictionary = state["player"]["activity"]
	if activity.is_empty():
		return
	state["player"]["activity"] = {}
	_emit({
		"kind": SimVocab.EV_ACTIVITY_STOPPED, "activity": activity["kind"],
		"object_id": activity.get("object_id", ""), "reason": reason,
	})


## Ticks one gathering attempt takes at `level`.
static func gather_ticks(level: int) -> int:
	return maxi(GATHER_MIN_TICKS, GATHER_BASE_TICKS - (level - 1) / GATHER_LEVELS_PER_TICK)


## Percent chance that one gathering attempt at `level` yields an item.
static func gather_chance(level: int) -> int:
	return mini(GATHER_MAX_CHANCE, GATHER_BASE_CHANCE + GATHER_CHANCE_PER_LEVEL * (level - 1))


func _step_activity() -> void:
	var activity: Dictionary = state["player"]["activity"]
	if activity.is_empty() or activity["kind"] != SimVocab.GATHER:
		return
	var id: String = activity["object_id"]
	var blocker := _gather_blocker(id)
	if blocker != "":
		_stop_activity(blocker)
		return
	var def := _node_def(id)
	var skill: String = def["skill"]
	activity["progress"] = int(activity["progress"]) + 1
	if int(activity["progress"]) < gather_ticks(skill_level(skill)):
		return
	activity["progress"] = 0
	if not _roll(gather_chance(skill_level(skill))):
		return
	var item: String = def["item"]
	Inventory.add(state["inventory"]["pack"], item, 1)
	var node: Dictionary = state["nodes"][id]
	node["left"] = int(node["left"]) - 1
	_emit({
		"kind": SimVocab.EV_GATHERED, "object_id": id, "skill": skill, "item": item,
		"count": 1, "xp": int(def["xp"]),
	})
	_grant_xp(skill, int(def["xp"]))
	if int(node["left"]) <= 0:
		node["respawn_tick"] = int(state["tick"]) + int(def["respawn_ticks"])
		_emit({"kind": SimVocab.EV_NODE_DEPLETED, "object_id": id, "respawn_tick": node["respawn_tick"]})
		_stop_activity(SimVocab.REASON_DEPLETED)
	elif Inventory.is_full_for(state["inventory"]["pack"], item):
		_stop_activity(SimVocab.REASON_PACK_FULL)


func _step_nodes() -> void:
	var tick := int(state["tick"])
	for id in state["nodes"]:
		var node: Dictionary = state["nodes"][id]
		if int(node["left"]) <= 0 and tick >= int(node["respawn_tick"]):
			node["left"] = int(_node_def(id)["yield"])
			node["respawn_tick"] = 0
			_emit({"kind": SimVocab.EV_NODE_RESPAWNED, "object_id": id})


## A deterministic roll kept in the state (a 31-bit LCG, exact through JSON).
func _roll(percent: int) -> bool:
	var r := (int(state["rng"]) * 1103515245 + 12345) % 2147483648
	state["rng"] = r
	return (r >> 16) % 100 < percent


# --- Skills ---------------------------------------------------------------------------

func _grant_xp(skill: String, amount: int) -> void:
	if amount <= 0:
		return
	var entry: Dictionary = state["skills"][skill]
	entry["xp"] = int(entry["xp"]) + amount
	var level := SkillTable.level_for_xp(int(entry["xp"]))
	if level > int(entry["level"]):
		entry["level"] = level
		_emit({"kind": SimVocab.EV_LEVELLED, "skill": skill, "level": level})


# --- Warmth and health ----------------------------------------------------------------

func _step_survival() -> void:
	var warmth := int(state["warmth"])
	var health := int(state["health"])
	if near_fire():
		warmth = mini(WARMTH_MAX, warmth + FIRE_WARMTH)
		health = mini(HEALTH_MAX, health + FIRE_HEALTH)
	elif not in_outpost():
		if warmth > 0:
			warmth = maxi(0, warmth - WARMTH_DRAIN)
		else:
			health = maxi(0, health - COLD_DAMAGE)
			_emit({"kind": SimVocab.EV_TOOK_DAMAGE, "amount": COLD_DAMAGE, "cause": "cold", "health": health})
	if warmth != int(state["warmth"]):
		_emit({"kind": SimVocab.EV_WARMTH_CHANGED, "warmth": warmth, "max": WARMTH_MAX})
	state["warmth"] = warmth
	state["health"] = health
	if health <= 0:
		_collapse("cold")


## Health ran out. In this slice that wakes the player beside the outpost fire with the pack
## intact and full health; the real death rule arrives with combat.
func _collapse(cause: String) -> void:
	var player: Dictionary = state["player"]
	_stop_activity(SimVocab.REASON_COLLAPSED)
	var to := Vector2(world.rescue[0], world.rescue[1])
	player["pos"] = _xz(to)
	player["path"] = []
	player["target_object"] = ""
	state["health"] = HEALTH_MAX
	_emit({"kind": SimVocab.EV_COLLAPSED, "cause": cause, "pos": _xz(to)})
	var region := world.region_at(to)
	if region != player["region"]:
		_emit({"kind": SimVocab.EV_REGION_CHANGED, "from": player["region"], "to": region})
		player["region"] = region


# --- Inventory and outpost actions ----------------------------------------------------

## Why a queued command (deposit, withdraw, drop, equip, smith) would be refused right now,
## or "" when it would be accepted. Read-only: the presentation uses it to grey out buttons.
func check(kind: String, args: Dictionary) -> String:
	if not QUEUED_COMMANDS.has(kind):
		return SimVocab.REASON_NOT_IMPLEMENTED
	return _apply(kind, args, false)


## Validates a queued command and, when `commit` is true, carries it out. Returns the
## rejection reason, or "" when the command is (or was) valid.
func _apply(kind: String, args: Dictionary, commit: bool) -> String:
	match kind:
		SimVocab.DEPOSIT:
			return _move_between(args, commit, true)
		SimVocab.WITHDRAW:
			return _move_between(args, commit, false)
		SimVocab.DROP:
			return _drop(args, commit)
		SimVocab.EQUIP:
			return _equip(args, commit)
		SimVocab.SMITH:
			return _smith(args, commit)
	return SimVocab.REASON_NOT_IMPLEMENTED


## Slot index from args, or -1 when missing or out of range for `slots`.
static func _arg_index(args: Dictionary, slots: Array) -> int:
	var v: Variant = args.get("index")
	if not (v is int or v is float):
		return -1
	var i := int(v)
	return i if i >= 0 and i < slots.size() else -1


static func _arg_count(args: Dictionary, available: int) -> int:
	var v: Variant = args.get("count")
	if v is int or v is float:
		return clampi(int(v), 0, available)
	return available


## Deposit (pack to stash) or withdraw (stash to pack). Moves as many as fit.
func _move_between(args: Dictionary, commit: bool, deposit: bool) -> String:
	if not in_outpost():
		return SimVocab.REASON_NOT_IN_OUTPOST
	var from: Array = state["inventory"]["pack"] if deposit else state["stash"]["slots"]
	var to: Array = state["stash"]["slots"] if deposit else state["inventory"]["pack"]
	var i := _arg_index(args, from)
	if i < 0:
		return SimVocab.REASON_BAD_ARGS
	if from[i] == null:
		return SimVocab.REASON_EMPTY_SLOT
	var kind: String = from[i]["item"]
	var count := mini(_arg_count(args, int(from[i]["count"])), Inventory.room_for(to, kind))
	if count <= 0:
		return SimVocab.REASON_STASH_FULL if deposit else SimVocab.REASON_PACK_FULL
	if commit:
		Inventory.take(from, i, count)
		Inventory.add(to, kind, count)
		_emit({
			"kind": SimVocab.EV_DEPOSITED if deposit else SimVocab.EV_WITHDREW,
			"item": kind, "count": count,
		})
		_save_due = SimVocab.DEPOSIT if deposit else SimVocab.WITHDRAW
	return ""


## Drops from a pack slot. Dropped items are left behind in the snow and are gone.
func _drop(args: Dictionary, commit: bool) -> String:
	var pack: Array = state["inventory"]["pack"]
	var i := _arg_index(args, pack)
	if i < 0:
		return SimVocab.REASON_BAD_ARGS
	if pack[i] == null:
		return SimVocab.REASON_EMPTY_SLOT
	var count := _arg_count(args, int(pack[i]["count"]))
	if count <= 0:
		return SimVocab.REASON_BAD_ARGS
	if commit:
		var taken := Inventory.take(pack, i, count)
		_emit({"kind": SimVocab.EV_DROPPED, "item": taken["item"], "count": taken["count"]})
	return ""


## `{index}` equips a pack item, swapping whatever was in its slot into that pack slot.
## `{unequip: slot}` moves the equipped item into the first free pack slot.
func _equip(args: Dictionary, commit: bool) -> String:
	var pack: Array = state["inventory"]["pack"]
	var equipment: Dictionary = state["inventory"]["equipment"]
	if args.has("unequip"):
		var slot := str(args["unequip"])
		if not equipment.has(slot):
			return SimVocab.REASON_BAD_ARGS
		var item: String = equipment[slot]
		if item == "":
			return SimVocab.REASON_EMPTY_SLOT
		if Inventory.is_full_for(pack, item):
			return SimVocab.REASON_PACK_FULL
		if commit:
			Inventory.add(pack, item, 1)
			equipment[slot] = ""
			_emit({"kind": SimVocab.EV_EQUIPPED, "slot": slot, "item": "", "previous": item})
		return ""
	var i := _arg_index(args, pack)
	if i < 0:
		return SimVocab.REASON_BAD_ARGS
	if pack[i] == null:
		return SimVocab.REASON_EMPTY_SLOT
	var kind: String = pack[i]["item"]
	var slot := ItemTable.slot(kind)
	if slot == "":
		return SimVocab.REASON_NOT_EQUIPPABLE
	if commit:
		var previous: String = equipment[slot]
		Inventory.take(pack, i, 1)
		if previous != "":
			if pack[i] == null:
				pack[i] = {"item": previous, "count": 1}
			else:
				Inventory.add(pack, previous, 1)
		equipment[slot] = kind
		_emit({"kind": SimVocab.EV_EQUIPPED, "slot": slot, "item": kind, "previous": previous})
	return ""


## Crafts a recipe at the workbench: consumes its inputs from the pack, adds its output.
func _smith(args: Dictionary, commit: bool) -> String:
	var id := str(args.get("recipe", ""))
	if not RecipeTable.has(id):
		return SimVocab.REASON_UNKNOWN_RECIPE
	if not in_outpost() or not near_kind(WorldDef.KIND_WORKBENCH, USE_REACH):
		return SimVocab.REASON_NOT_AT_WORKBENCH
	var recipe := RecipeTable.get_recipe(id)
	if skill_level(recipe["skill"]) < int(recipe["level"]):
		return SimVocab.REASON_LEVEL_TOO_LOW
	if recipe["upgrade"] != "" and not (state["upgrades"] as Array).has(recipe["upgrade"]):
		return SimVocab.REASON_UPGRADE_MISSING
	var pack: Array = state["inventory"]["pack"]
	var inputs: Dictionary = recipe["inputs"]
	for kind in inputs:
		if Inventory.count_of(pack, kind) < int(inputs[kind]):
			return SimVocab.REASON_MISSING_INPUTS
	var after := pack.duplicate(true)
	for kind in inputs:
		Inventory.remove(after, kind, int(inputs[kind]))
	var output: Dictionary = recipe["output"]
	if Inventory.room_for(after, output["item"]) < int(output["count"]):
		return SimVocab.REASON_PACK_FULL
	if commit:
		Inventory.add(after, output["item"], int(output["count"]))
		state["inventory"]["pack"] = after
		_emit({"kind": SimVocab.EV_CRAFTED, "recipe": id, "item": output["item"], "count": output["count"]})
		_grant_xp(recipe["skill"], int(recipe["xp"]))
		_save_due = "craft"
	return ""


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


## The whole state as a save code (see SaveCode). The same text is what autosave stores.
func export_code() -> String:
	return SaveCode.encode(snapshot())


## Replaces the state with `snap` (deep-copied), migrating it forward from an older version
## first. Numbers that JSON turned into floats come back as ints, unknown item kinds are
## dropped, and missing pieces get a new character's defaults. Returns false, leaving the
## state untouched, when the snapshot is not one this version can read.
func restore(snap: Dictionary) -> bool:
	var migrated: Variant = SaveCode.migrate(snap, STATE_VERSION)
	if migrated == null:
		return false
	var copy: Dictionary = migrated
	if not (copy.get("player") is Dictionary) or not _is_number(copy.get("tick")):
		return false
	var player: Dictionary = copy["player"]
	if not _is_xz(player.get("pos")):
		return false
	var fresh := new_state()
	copy["version"] = STATE_VERSION
	copy["tick"] = int(copy["tick"])
	copy["rng"] = int(copy["rng"]) if _is_number(copy.get("rng")) else int(fresh["rng"])
	player["pos"] = _xz(Vector2(player["pos"][0], player["pos"][1]))
	var facing: Variant = player.get("facing")
	player["facing"] = _xz(Vector2(facing[0], facing[1])) if _is_xz(facing) else [0.0, 1.0]
	var path: Array = []
	for p in player.get("path", []):
		if _is_xz(p):
			path.append(_xz(Vector2(p[0], p[1])))
	player["path"] = path
	var target := str(player.get("target_object", ""))
	player["target_object"] = target if world.objects.has(target) else ""
	player["region"] = world.region_at(player_pos_of(player))
	player["activity"] = _restored_activity(player.get("activity"))
	copy["warmth"] = clampi(int(copy["warmth"]) if _is_number(copy.get("warmth")) else WARMTH_MAX, 0, WARMTH_MAX)
	copy["health"] = clampi(int(copy["health"]) if _is_number(copy.get("health")) else HEALTH_MAX, 1, HEALTH_MAX)

	var inventory: Variant = copy.get("inventory")
	if not (inventory is Dictionary):
		inventory = fresh["inventory"]
	var equipment := {}
	var worn: Variant = inventory.get("equipment")
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item := str(worn.get(slot, "")) if worn is Dictionary else ""
		equipment[slot] = item if ItemTable.has(item) and ItemTable.slot(item) == slot else ""
	copy["inventory"] = {"pack": _restored_slots(inventory.get("pack"), PACK_SLOTS), "equipment": equipment}

	var stash: Variant = copy.get("stash")
	var capacity := STASH_START_SLOTS
	if stash is Dictionary and _is_number(stash.get("capacity")):
		capacity = maxi(1, int(stash["capacity"]))
	var stash_slots: Variant = stash.get("slots") if stash is Dictionary else null
	copy["stash"] = {"capacity": capacity, "slots": _restored_slots(stash_slots, capacity)}

	var skills := SkillTable.new_table()
	var saved_skills: Variant = copy.get("skills")
	for name in SkillTable.NAMES:
		var entry: Variant = saved_skills.get(name) if saved_skills is Dictionary else null
		if entry is Dictionary and _is_number(entry.get("xp")):
			var xp := maxi(0, int(entry["xp"]))
			var level := int(entry["level"]) if _is_number(entry.get("level")) else 1
			skills[name] = {"xp": xp, "level": clampi(maxi(level, SkillTable.level_for_xp(xp)), 1, SkillTable.MAX_LEVEL)}
	copy["skills"] = skills

	var nodes := _full_nodes()
	var saved_nodes: Variant = copy.get("nodes")
	for id in nodes:
		var entry: Variant = saved_nodes.get(id) if saved_nodes is Dictionary else null
		if entry is Dictionary and _is_number(entry.get("left")) and _is_number(entry.get("respawn_tick")):
			nodes[id] = {
				"left": clampi(int(entry["left"]), 0, int(_node_def(id)["yield"])),
				"respawn_tick": int(entry["respawn_tick"]),
			}
	copy["nodes"] = nodes

	var upgrades: Array = []
	if copy.get("upgrades") is Array:
		for u in copy["upgrades"]:
			upgrades.append(str(u))
	copy["upgrades"] = upgrades
	var pending: Array = []
	if copy.get("pending") is Array:
		for p in copy["pending"]:
			if p is Dictionary and QUEUED_COMMANDS.has(str(p.get("kind", ""))) and p.get("args") is Dictionary:
				pending.append({"kind": str(p["kind"]), "args": p["args"]})
	copy["pending"] = pending
	state = copy
	_save_due = ""
	return true


## A slot array of exactly `size` entries from saved data: known items only, counts clamped
## to the stack size, everything unreadable left empty.
func _restored_slots(saved: Variant, size: int) -> Array:
	var out := Inventory.empty_slots(size)
	if not (saved is Array):
		return out
	for i in mini(size, saved.size()):
		var s: Variant = saved[i]
		if s is Dictionary and ItemTable.has(str(s.get("item", ""))) and _is_number(s.get("count")):
			var kind := str(s["item"])
			var count := clampi(int(s["count"]), 0, ItemTable.stack_size(kind))
			if count > 0:
				out[i] = {"item": kind, "count": count}
	return out


func _restored_activity(saved: Variant) -> Dictionary:
	if saved is Dictionary and str(saved.get("kind", "")) == SimVocab.GATHER:
		var id := str(saved.get("object_id", ""))
		if is_node(id) and _is_number(saved.get("progress")):
			return {"kind": SimVocab.GATHER, "object_id": id, "progress": int(saved["progress"])}
	return {}


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _is_xz(v: Variant) -> bool:
	return v is Array and v.size() == 2 and _is_number(v[0]) and _is_number(v[1])


# --- Read helpers ---------------------------------------------------------------------

func player_pos() -> Vector2:
	return player_pos_of(state["player"])


static func player_pos_of(player: Dictionary) -> Vector2:
	return Vector2(player["pos"][0], player["pos"][1])


func player_facing() -> Vector2:
	return Vector2(state["player"]["facing"][0], state["player"]["facing"][1])


func is_moving() -> bool:
	return not (state["player"]["path"] as Array).is_empty()


func is_gathering() -> bool:
	return not (state["player"]["activity"] as Dictionary).is_empty()


func in_outpost() -> bool:
	return state["player"]["region"] == WorldDef.REGION_OUTPOST


## True when the player stands within `reach` metres of any object of `kind`.
func near_kind(kind: String, reach: float) -> bool:
	var here := player_pos()
	for id in world.objects_of_kind(kind):
		if world.distance_to_object(id, here) <= reach:
			return true
	return false


func near_fire() -> bool:
	return near_kind(WorldDef.KIND_FIRE, FIRE_REACH)


## Whether the pack or the tool slot holds a tool of kind `tool_kind` (for example "axe").
func has_tool(tool_kind: String) -> bool:
	var inventory: Dictionary = state["inventory"]
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = inventory["equipment"][slot]
		if item != "" and ItemTable.tool(item) == tool_kind:
			return true
	for s in inventory["pack"]:
		if s != null and ItemTable.tool(s["item"]) == tool_kind:
			return true
	return false


## Kilograms carried: the pack plus everything equipped.
func carry_weight() -> int:
	var inventory: Dictionary = state["inventory"]
	var w := Inventory.weight(inventory["pack"])
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = inventory["equipment"][slot]
		if item != "":
			w += ItemTable.weight(item)
	return w


func is_overweight() -> bool:
	return carry_weight() > CARRY_LIMIT


func skill_level(skill: String) -> int:
	return int(state["skills"][skill]["level"])


## Progress within the current level: {level, xp, into, span}. `into` of `span` experience
## has been earned toward the next level; span is 0 at the level cap.
func skill_progress(skill: String) -> Dictionary:
	var entry: Dictionary = state["skills"][skill]
	var level := int(entry["level"])
	var xp := int(entry["xp"])
	var floor_xp := SkillTable.xp_for_level(level)
	var span := 0 if level >= SkillTable.MAX_LEVEL else SkillTable.xp_for_level(level + 1) - floor_xp
	return {"level": level, "xp": xp, "into": xp - floor_xp, "span": span}


func _arg_pos(args: Dictionary, key: String) -> Variant:
	var v: Variant = args.get(key)
	if v is Vector2:
		return v
	if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
		return Vector2(v[0], v[1])
	return null


static func _xz(v: Vector2) -> Array:
	return [float(v.x), float(v.y)]
