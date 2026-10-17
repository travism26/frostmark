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
const STATE_VERSION := 5

## The pack: a fixed number of slots, and a carried weight (pack plus equipment, in kg)
## above which walking slows to OVERWEIGHT_SPEED of normal.
const PACK_SLOTS := 12
const CARRY_LIMIT := 30
const OVERWEIGHT_SPEED := 0.6
## Stash slots a new character starts with; outpost upgrades raise it in a later slice.
const STASH_START_SLOTS := 8
const STARTING_TOOL := "wooden_axe"
## A new character's stash holds a bow, a quiver and food, so both combat styles and healing
## are there for the first fight. A slice-3 character gets the same kit on migration.
const STARTING_STASH := [
	{"item": "wooden_bow", "count": 1}, {"item": "arrows", "count": 30}, {"item": "cooked_fish", "count": 5},
]

## Warmth is whole points. Outside the outpost it drains WARMTH_DRAIN per tick, so a full
## gauge lasts WARMTH_MAX / WARMTH_DRAIN ticks (three minutes). Within FIRE_REACH metres of
## a fire it refills FIRE_WARMTH per tick and health refills FIRE_HEALTH per tick. At zero
## warmth, health drains COLD_DAMAGE per tick instead; at zero health the player dies.
const WARMTH_MAX := 360
const WARMTH_DRAIN := 1
const HEALTH_MAX := 100
const COLD_DAMAGE := 1
const FIRE_REACH := 3.0
const FIRE_WARMTH := 24
const FIRE_HEALTH := 2
## How close (metres from its footprint) the player must stand to use the workbench or a node.
const USE_REACH := 1.5
## A field fire burns FIELD_FIRE_LOGS logs from the pack and warms (and cooks) like the outpost
## fire for FIELD_FIRE_TICKS ticks (a minute) before it goes out.
const FIELD_FIRE_LOGS := 3
const FIELD_FIRE_TICKS := 120
## Field fire ids are this prefix and a number, so they never clash with placed objects.
const FIELD_FIRE_PREFIX := "campfire_"

## Gathering: one attempt takes `gather_ticks(level)` ticks and succeeds with
## `gather_chance(level)` percent. Both improve with the gathering skill's level.
const GATHER_BASE_TICKS := 4
const GATHER_MIN_TICKS := 2
const GATHER_LEVELS_PER_TICK := 4
const GATHER_BASE_CHANCE := 60
const GATHER_CHANCE_PER_LEVEL := 4
const GATHER_MAX_CHANCE := 95
## Each gear tier of the tool above wooden takes a tick off an attempt and adds to its chance.
const TOOL_TICKS_PER_TIER := 1
const TOOL_CHANCE_PER_TIER := 10

## Cooking: one item every COOK_TICKS ticks at any fire. Its burn chance is the raw item's
## `burn` percent at the level it needs, less BURN_DROP_PER_LEVEL for every level above.
const COOK_TICKS := 2
const BURN_DROP_PER_LEVEL := 5
## Smithing works no metal above this tier in the first playable: iron is found, not made.
const SMITHING_TIER_CAP := ItemTable.TIER_BRONZE

## Death keeps this many of the most valuable things carried or worn (a stack is one thing).
const DEATH_KEEPS := 3
## Ground loot lies this many ticks (five minutes) before the snow takes it.
const LOOT_TICKS := 600

## Enemy modes. Idle at home until it notices the player, engaged while fighting, returning
## home (deaf to the player) after the player reaches the outpost, dead until it respawns.
const MODE_IDLE := "idle"
const MODE_ENGAGED := "engaged"
const MODE_RETURNING := "returning"
const MODE_DEAD := "dead"
const ENEMY_MODES: Array[String] = [MODE_IDLE, MODE_ENGAGED, MODE_RETURNING, MODE_DEAD]

## Commands that change the inventory are queued and applied at the start of the next tick.
## That is what makes a weapon swap land on the next tick, and eating cost it.
const QUEUED_COMMANDS: Array[String] = [
	SimVocab.SMITH, SimVocab.EQUIP, SimVocab.EAT, SimVocab.DROP, SimVocab.DEPOSIT, SimVocab.WITHDRAW,
	SimVocab.BUILD, SimVocab.LIGHT_FIRE,
]

var world: WorldDef
var state: Dictionary = {}
var _events: Array[Dictionary] = []
## Why this tick reached a save point, or "" when it did not. Flushed as one `saved` event.
var _save_due := ""
## Within one tick only, reset by `step()`: whether the player ate (which costs the tick's
## step and swing), the radius of the loudest noise the player made, and what killed the
## player when a blow brought health to zero.
var _ate := false
var _noise := 0.0
var _dead_cause := ""


func _init(world_def: WorldDef = null) -> void:
	world = world_def if world_def != null else WorldDef.outpost()
	state = new_state()


## A fresh state for this world: a new character at the spawn point, idle, facing south,
## warm, with an empty pack, the starting axe in the tool slot, the starting kit in the stash,
## every node full and every enemy at home.
func new_state() -> Dictionary:
	var spawn := Vector2(world.spawn[0], world.spawn[1])
	var stash := Inventory.empty_slots(STASH_START_SLOTS)
	for kit in STARTING_STASH:
		Inventory.add(stash, kit["item"], kit["count"])
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
			"ready_tick": 0,
		},
		"warmth": WARMTH_MAX,
		"health": HEALTH_MAX,
		"healing": [],
		"inventory": {
			"pack": Inventory.empty_slots(PACK_SLOTS),
			"equipment": {
				ItemTable.SLOT_WEAPON: "", ItemTable.SLOT_ARMOUR: "", ItemTable.SLOT_TOOL: STARTING_TOOL,
			},
		},
		"stash": {"capacity": STASH_START_SLOTS, "slots": stash},
		"skills": SkillTable.new_table(),
		"nodes": _full_nodes(),
		"enemies": _fresh_enemies(),
		"loot": {},
		"loot_seq": 0,
		"fires": {},
		"fire_seq": 0,
		"bosses_defeated": [],
		"upgrades": [],
		"pending": [],
		"guide": {"on": true, "step": 0, "tips": {}},
	}


func _full_nodes() -> Dictionary:
	var out := {}
	for id in world.node_ids():
		out[id] = {"left": int(WorldDef.NODE_KINDS[world.objects[id]["kind"]]["yield"]), "respawn_tick": 0}
	return out


func _fresh_enemies() -> Dictionary:
	var out := {}
	for id in world.enemies:
		out[id] = _fresh_enemy(id)
	return out


## An enemy at home, unhurt and idle.
func _fresh_enemy(id: String) -> Dictionary:
	var placed: Dictionary = world.enemies[id]
	return {
		"kind": placed["kind"],
		"pos": [float(placed["home"][0]), float(placed["home"][1])],
		"facing": [0.0, -1.0],
		"health": int(CombatTable.enemy(placed["kind"])["health"]),
		"mode": MODE_IDLE,
		"next": {},
		"step": 0,
		"respawn_tick": 0,
	}


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
		SimVocab.ATTACK:
			return _cmd_attack(args)
		SimVocab.COOK:
			return _cmd_cook(args)
		SimVocab.EXPORT_SAVE:
			return {"ok": true, "reason": "", "code": export_code()}
		SimVocab.IMPORT_SAVE:
			return _cmd_import_save(args)
		SimVocab.SET_HINTS:
			return _cmd_set_hints(args)
		SimVocab.NEW_CHARACTER:
			return _cmd_new_character(args)
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
	if (state["loot"] as Dictionary).has(id):
		return _walk_to_loot(id, args)
	if (state["fires"] as Dictionary).has(id):
		return _walk_to_field_fire(id, args)
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


## Turns the first-outing guide off (the player dismissed it) or back on, where it left off.
func _cmd_set_hints(args: Dictionary) -> Dictionary:
	if not (args.get("on") is bool):
		return _reject(SimVocab.SET_HINTS, args, SimVocab.REASON_BAD_ARGS)
	state["guide"]["on"] = args["on"]
	_emit({"kind": SimVocab.EV_HINTS_SET, "on": args["on"]})
	return {"ok": true, "reason": ""}


## Replaces the state with a new character. The guide is for a player's first character
## only, so it starts off when `previous` holds the save code of a character before this one.
func _cmd_new_character(args: Dictionary) -> Dictionary:
	if not (args.get("previous", "") is String):
		return _reject(SimVocab.NEW_CHARACTER, args, SimVocab.REASON_BAD_ARGS)
	state = new_state()
	_save_due = ""
	state["guide"]["on"] = (args.get("previous", "") as String).strip_edges() == ""
	return {"ok": true, "reason": ""}


## Targets an enemy: the player closes to the weapon's reach and strikes on every ready tick
## until the enemy dies, the player walks away, or a ranged weapon runs out of ammunition.
func _cmd_attack(args: Dictionary) -> Dictionary:
	var id: String = str(args.get("enemy_id", ""))
	var enemies: Dictionary = state["enemies"]
	if not enemies.has(id):
		return _reject(SimVocab.ATTACK, args, SimVocab.REASON_UNKNOWN_ENEMY)
	if enemies[id]["mode"] == MODE_DEAD:
		return _reject(SimVocab.ATTACK, args, SimVocab.REASON_TARGET_DEAD)
	if in_outpost():
		return _reject(SimVocab.ATTACK, args, SimVocab.REASON_IN_OUTPOST)
	if not _has_ammo():
		return _reject(SimVocab.ATTACK, args, SimVocab.REASON_NO_AMMO)
	var player: Dictionary = state["player"]
	if player["activity"].get("object_id", "") != id:
		_stop_activity(SimVocab.REASON_MOVED)
	player["path"] = []
	player["target_object"] = ""
	player["activity"] = {"kind": SimVocab.ATTACK, "object_id": id}
	return {"ok": true, "reason": ""}


## Walks onto a loot pile; arriving picks up as much of it as the pack has room for.
func _walk_to_loot(id: String, args: Dictionary) -> Dictionary:
	var at := _pos(state["loot"][id])
	var cell: Variant = world.nearest_walkable_cell(at, SNAP_RADIUS_CELLS)
	if cell == null or not _set_path(cell, at if world.is_walkable(at) else world.cell_center(cell), id):
		return _reject(SimVocab.INTERACT, args, SimVocab.REASON_UNREACHABLE)
	return {"ok": true, "reason": ""}


## Walks to the side of a field fire nearest the player, a metre from its centre.
func _walk_to_field_fire(id: String, args: Dictionary) -> Dictionary:
	var at := _pos(state["fires"][id])
	var here := player_pos()
	var side := (here - at).normalized() if here.distance_to(at) > 0.01 else Vector2(0, 1)
	var spot := at + side
	var cell: Variant = world.nearest_walkable_cell(spot, SNAP_RADIUS_CELLS)
	if cell == null or not _set_path(cell, spot if world.is_walkable(spot) else world.cell_center(cell), id):
		return _reject(SimVocab.INTERACT, args, SimVocab.REASON_UNREACHABLE)
	return {"ok": true, "reason": ""}


## Starts cooking a pack slot's raw food at the fire the player stands by: one item every
## COOK_TICKS ticks until that kind runs out, the pack has no room, or the player walks off.
func _cmd_cook(args: Dictionary) -> Dictionary:
	var pack: Array = state["inventory"]["pack"]
	var i := _arg_index(args, pack)
	if i < 0:
		return _reject(SimVocab.COOK, args, SimVocab.REASON_BAD_ARGS)
	if pack[i] == null:
		return _reject(SimVocab.COOK, args, SimVocab.REASON_EMPTY_SLOT)
	var kind: String = pack[i]["item"]
	if not RecipeTable.is_cookable(kind):
		return _reject(SimVocab.COOK, args, SimVocab.REASON_NOT_COOKABLE)
	var reason := _cook_blocker(kind)
	if reason != "":
		return _reject(SimVocab.COOK, args, reason)
	var player: Dictionary = state["player"]
	if player["activity"].get("item", "") != kind:
		_stop_activity(SimVocab.REASON_MOVED)
	player["path"] = []
	player["target_object"] = ""
	player["activity"] = {"kind": SimVocab.COOK, "item": kind, "progress": 0}
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
	var plain := _route(here, goal_cell, destination)
	if plain.is_empty():
		return false
	var length := 0.0
	var prev := here
	for p in plain:
		var v := Vector2(p[0], p[1])
		length += prev.distance_to(v)
		prev = v
	_stop_activity(SimVocab.REASON_MOVED)
	state["player"]["path"] = plain
	state["player"]["target_object"] = object_id
	_emit({
		"kind": SimVocab.EV_PATH_SET, "from": _xz(here), "to": _xz(destination),
		"length": length, "object_id": object_id,
	})
	return true


## A smoothed route from `from` to `goal_cell` ending exactly at `destination`, as plain
## `[x, z]` waypoints after `from`. Empty when there is no route.
func _route(from: Vector2, goal_cell: Vector2i, destination: Vector2) -> Array:
	var cells := GridPath.find(world, world.cell_of(from), goal_cell)
	if cells.is_empty():
		return []
	var points: Array[Vector2] = []
	for i in range(1, cells.size()):
		points.append(world.cell_center(cells[i]))
	if points.is_empty() or points[points.size() - 1] != destination:
		points.append(destination)
	var plain: Array = []
	for p in GridPath.smooth(world, from, points):
		plain.append(_xz(p))
	return plain


func _reject(kind: String, args: Dictionary, reason: String) -> Dictionary:
	_emit({"kind": SimVocab.EV_COMMAND_REJECTED, "command": kind, "reason": reason, "args": args})
	return {"ok": false, "reason": reason}


# --- Ticking --------------------------------------------------------------------------

## Advances the world by exactly one tick: queued inventory commands (a swap, a meal, a
## build, a field fire), the player closing on an attack target, movement, gathering or
## cooking, combat (the player's swing, then every enemy), node regrowth, loot decay, field
## fires burning out, then warmth, health and healing. A save point reached during the tick
## is reported once, at its end, so the saved state is the whole tick.
func step() -> void:
	state["tick"] = int(state["tick"]) + 1
	_ate = false
	_noise = 0.0
	_dead_cause = ""
	_step_pending()
	_step_pursuit()
	_step_movement()
	_step_activity()
	_step_combat()
	_step_nodes()
	_step_loot()
	_step_fires()
	_step_survival()
	_step_guide()
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
	if path.is_empty() or _ate:
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
		if (state["loot"] as Dictionary).has(object_id):
			_emit({
				"kind": SimVocab.EV_INTERACTED, "object_id": object_id, "object_kind": "loot",
				"action": SimVocab.ACTION_PICK_UP,
			})
			_pick_up(object_id)
		elif (state["fires"] as Dictionary).has(object_id):
			_emit({
				"kind": SimVocab.EV_INTERACTED, "object_id": object_id, "object_kind": "campfire",
				"action": SimVocab.ACTION_WARM,
			})
		elif world.objects.has(object_id):
			var action := _action_for(object_id)
			_emit({
				"kind": SimVocab.EV_INTERACTED, "object_id": object_id,
				"object_kind": world.objects[object_id]["kind"], "action": action,
			})
			if action == SimVocab.ACTION_GATHER:
				_start_gathering(object_id)
			elif action == SimVocab.ACTION_RING_GATE and ring_gate_open(object_id):
				_reach_ring_two(object_id)


func _action_for(object_id: String) -> String:
	if is_node(object_id):
		return SimVocab.ACTION_GATHER
	match world.objects[object_id]["kind"]:
		WorldDef.KIND_RING_GATE:
			return SimVocab.ACTION_RING_GATE
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


# --- The ring gate ----------------------------------------------------------------------

## Whether a ring gate stands open: its guardian has fallen at least once and the outpost has
## built the upgrade that works it. Both stay true for good, so an open gate never closes.
func ring_gate_open(object_id: String) -> bool:
	if not world.objects.has(object_id) or world.objects[object_id]["kind"] != WorldDef.KIND_RING_GATE:
		return false
	var gate: Dictionary = world.objects[object_id]
	return (state["bosses_defeated"] as Array).has(gate["guardian"]) and (state["upgrades"] as Array).has(gate["upgrade"])


func _open_ring_gates() -> Array[String]:
	var out: Array[String] = []
	for id in world.objects_of_kind(WorldDef.KIND_RING_GATE):
		if ring_gate_open(id):
			out.append(id)
	return out


## Emits `ring_gate_opened` for every gate open now that was not open in `before`.
func _announce_ring_gates(before: Array[String]) -> void:
	for id in _open_ring_gates():
		if not before.has(id):
			_emit({"kind": SimVocab.EV_RING_GATE_OPENED, "object_id": id})


## The player walked through the open gate to ring two: the first playable ends here. The
## presentation shows the ending; the character comes home intact, beside the outpost fire,
## and what they carried is banked as if they had walked in through the outpost gate.
func _reach_ring_two(object_id: String) -> void:
	_emit({"kind": SimVocab.EV_RING_TWO_REACHED, "object_id": object_id})
	var player: Dictionary = state["player"]
	var to := Vector2(world.rescue[0], world.rescue[1])
	player["pos"] = _xz(to)
	player["path"] = []
	player["target_object"] = ""
	_stop_activity(SimVocab.REASON_MOVED)
	var region := world.region_at(to)
	if region != player["region"]:
		_emit({"kind": SimVocab.EV_REGION_CHANGED, "from": player["region"], "to": region})
		player["region"] = region
	_bank()
	_save_due = "ring_two"


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
	var rank := tool_rank(def["tool"])
	if rank < 0:
		return SimVocab.REASON_NO_TOOL
	if def["tool_tier"] != "" and rank < ItemTable.tier_rank(def["tool_tier"]):
		return SimVocab.REASON_TOOL_TOO_WEAK
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


## Ticks one gathering attempt takes at `level` with a tool `tool_tier` ranks above wooden.
static func gather_ticks(level: int, tool_tier := 0) -> int:
	return maxi(GATHER_MIN_TICKS, GATHER_BASE_TICKS - (level - 1) / GATHER_LEVELS_PER_TICK - tool_tier * TOOL_TICKS_PER_TIER)


## Percent chance that one gathering attempt at `level` yields an item, with a tool
## `tool_tier` ranks above wooden.
static func gather_chance(level: int, tool_tier := 0) -> int:
	return mini(GATHER_MAX_CHANCE, GATHER_BASE_CHANCE + GATHER_CHANCE_PER_LEVEL * (level - 1) + tool_tier * TOOL_CHANCE_PER_TIER)


## Percent chance that cooking one `raw` item at cooking `level` burns it.
static func burn_chance(raw: String, level: int) -> int:
	var c := RecipeTable.cooking(raw)
	return maxi(0, int(c["burn"]) - BURN_DROP_PER_LEVEL * (level - int(c["level"])))


func _step_activity() -> void:
	var activity: Dictionary = state["player"]["activity"]
	if activity.is_empty():
		return
	if activity["kind"] == SimVocab.COOK:
		_step_cooking(activity)
		return
	if activity["kind"] != SimVocab.GATHER:
		return
	var id: String = activity["object_id"]
	var blocker := _gather_blocker(id)
	if blocker != "":
		_stop_activity(blocker)
		return
	var def := _node_def(id)
	var skill: String = def["skill"]
	var power := tool_rank(def["tool"])
	activity["progress"] = int(activity["progress"]) + 1
	_noise = maxf(_noise, CombatTable.NOISE_GATHER)
	if int(activity["progress"]) < gather_ticks(skill_level(skill), power):
		return
	activity["progress"] = 0
	if not _roll(gather_chance(skill_level(skill), power)):
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


# --- Cooking --------------------------------------------------------------------------

## Why cooking `raw` cannot go on right now, or "" when it can.
func _cook_blocker(raw: String) -> String:
	if not near_fire():
		return SimVocab.REASON_NOT_AT_FIRE
	var pack: Array = state["inventory"]["pack"]
	if Inventory.count_of(pack, raw) <= 0:
		return SimVocab.REASON_NOTHING_LEFT
	var c := RecipeTable.cooking(raw)
	if skill_level(SkillTable.COOKING) < int(c["level"]):
		return SimVocab.REASON_LEVEL_TOO_LOW
	var after := pack.duplicate(true)
	Inventory.remove(after, raw, 1)
	if Inventory.room_for(after, c["output"]) <= 0:
		return SimVocab.REASON_PACK_FULL
	return ""


## One item every COOK_TICKS ticks: it either cooks (and trains cooking) or burns and is lost.
func _step_cooking(activity: Dictionary) -> void:
	var raw: String = activity["item"]
	var blocker := _cook_blocker(raw)
	if blocker != "":
		_stop_activity(blocker)
		return
	activity["progress"] = int(activity["progress"]) + 1
	if int(activity["progress"]) < COOK_TICKS:
		return
	activity["progress"] = 0
	var c := RecipeTable.cooking(raw)
	var pack: Array = state["inventory"]["pack"]
	Inventory.remove(pack, raw, 1)
	if _roll(burn_chance(raw, skill_level(SkillTable.COOKING))):
		_emit({"kind": SimVocab.EV_COOKED, "item": raw, "output": "", "burnt": true, "xp": 0})
	else:
		Inventory.add(pack, c["output"], 1)
		_emit({"kind": SimVocab.EV_COOKED, "item": raw, "output": c["output"], "burnt": false, "xp": int(c["xp"])})
		_grant_xp(SkillTable.COOKING, int(c["xp"]))
	if Inventory.count_of(pack, raw) <= 0:
		_stop_activity(SimVocab.REASON_NOTHING_LEFT)


func _step_nodes() -> void:
	var tick := int(state["tick"])
	for id in state["nodes"]:
		var node: Dictionary = state["nodes"][id]
		if int(node["left"]) <= 0 and tick >= int(node["respawn_tick"]):
			node["left"] = int(_node_def(id)["yield"])
			node["respawn_tick"] = 0
			_emit({"kind": SimVocab.EV_NODE_RESPAWNED, "object_id": id})


## A deterministic roll kept in the state: true with `percent` percent chance.
func _roll(percent: int) -> bool:
	return _rand(100) < percent


## The next draw of the generator kept in the state (a 31-bit LCG, exact through JSON), as a
## whole number from 0 to n - 1.
func _rand(n: int) -> int:
	var r := (int(state["rng"]) * 1103515245 + 12345) % 2147483648
	state["rng"] = r
	return (r >> 16) % n


# --- Combat ---------------------------------------------------------------------------

## The player and every enemy as one combatant shape: {id, kind, pos, health, health_max,
## weapon, style, reach, defence, next}. The style comes from the weapon. `next` is the action
## declared for the coming tick as {action, at}, or {} when nothing is lined up. Every blow
## is resolved through this view, so the player and an enemy are hit by the same arithmetic.
func combatant(id: String) -> Dictionary:
	if id == SimVocab.PLAYER:
		var weapon := player_weapon()
		var stats := CombatTable.weapon(weapon)
		var tick := int(state["tick"])
		var next := {}
		if is_attacking() and int(state["player"]["ready_tick"]) <= tick + 1:
			next = {"action": SimVocab.ATTACK, "at": tick + 1}
		return {
			"id": id, "kind": SimVocab.PLAYER, "pos": player_pos(), "health": int(state["health"]),
			"health_max": HEALTH_MAX, "weapon": weapon, "style": stats["style"], "reach": stats["reach"],
			"defence": ItemTable.defence(state["inventory"]["equipment"][ItemTable.SLOT_ARMOUR]),
			"next": next,
		}
	var e: Dictionary = state["enemies"][id]
	var def := CombatTable.enemy(e["kind"])
	# The weapon of the action declared last: a captain holds his bow from "draws his bow" on.
	var held := CombatTable.stance_weapon(e["kind"], int(e["step"]) - 1)
	var enemy_stats := CombatTable.weapon(held)
	return {
		"id": id, "kind": e["kind"], "pos": _pos(e), "health": int(e["health"]),
		"health_max": int(def["health"]), "weapon": held, "style": enemy_stats["style"],
		"reach": enemy_stats["reach"], "defence": 0, "next": (e["next"] as Dictionary).duplicate(),
	}


## The weapon the player fights with: what is in the weapon slot, or fists when it is empty.
func player_weapon() -> String:
	var w: String = state["inventory"]["equipment"][ItemTable.SLOT_WEAPON]
	return w if w != "" else CombatTable.UNARMED


func player_style() -> String:
	return CombatTable.weapon(player_weapon())["style"]


## False only for a ranged weapon with no ammunition left in the pack.
func _has_ammo() -> bool:
	var ammo: String = CombatTable.weapon(player_weapon())["ammo"]
	return ammo == "" or Inventory.count_of(state["inventory"]["pack"], ammo) > 0


## The enemy the player is attacking, or "".
func _attack_target() -> String:
	var activity: Dictionary = state["player"]["activity"]
	return str(activity.get("object_id", "")) if activity.get("kind", "") == SimVocab.ATTACK else ""


## While attacking, walks the player to within the weapon's reach of the target, re-routing
## as the target moves, and stands still once in reach.
func _step_pursuit() -> void:
	var target := _attack_target()
	if target == "" or _ate:
		return
	var player: Dictionary = state["player"]
	var here := player_pos()
	var there := _pos(state["enemies"][target])
	var reach: float = CombatTable.weapon(player_weapon())["reach"]
	if here.distance_to(there) <= reach:
		player["path"] = []
		return
	var goal := there + (here - there).normalized() * reach * CombatTable.APPROACH_FRACTION
	var path: Array = player["path"]
	if not path.is_empty() and Vector2(path[-1][0], path[-1][1]).distance_to(goal) < 0.5:
		return
	var cell: Variant = world.nearest_walkable_cell(goal, SNAP_RADIUS_CELLS)
	if cell == null:
		return
	player["path"] = _route(here, cell, goal if world.is_walkable(goal) else world.cell_center(cell))


## The player's swing, then every enemy's turn. A player killed by a blow dies once, at the
## end, so the enemies' turns in between see the fight as over.
func _step_combat() -> void:
	_step_player_attack()
	for id in state["enemies"]:
		_step_enemy(id)
	if _dead_cause != "":
		_die(_dead_cause)


## The player strikes on a ready tick, outside the outpost, with the target in reach. A
## ranged weapon spends one arrow per shot and refuses to fire with none. Hits train the
## style's skill.
func _step_player_attack() -> void:
	var target := _attack_target()
	var tick := int(state["tick"])
	var player: Dictionary = state["player"]
	if target == "" or _ate or in_outpost() or tick < int(player["ready_tick"]):
		return
	var me := combatant(SimVocab.PLAYER)
	var foe := combatant(target)
	var toward: Vector2 = (foe["pos"] as Vector2) - (me["pos"] as Vector2)
	if toward.length() > float(me["reach"]):
		return
	if not _has_ammo():
		_stop_activity(SimVocab.REASON_NO_AMMO)
		return
	var stats := CombatTable.weapon(me["weapon"])
	if stats["ammo"] != "":
		Inventory.remove(state["inventory"]["pack"], stats["ammo"], 1)
	player["ready_tick"] = tick + int(stats["speed"])
	if toward != Vector2.ZERO:
		player["facing"] = _xz(toward.normalized())
	var skill: String = CombatTable.STYLE_SKILLS[me["style"]]
	var base := int(stats["power"]) + (skill_level(skill) - 1) / CombatTable.LEVELS_PER_POWER
	var amount := _strike(SimVocab.PLAYER, target, base)
	_grant_xp(skill, amount * CombatTable.XP_PER_DAMAGE)
	var e: Dictionary = state["enemies"][target]
	if int(e["health"]) <= 0:
		_kill_enemy(target)
	elif e["mode"] != MODE_ENGAGED:
		_engage(target, CombatTable.NOTICE_HIT)


## One blow from `attacker` on `defender` for `base` damage before the style edge and armour.
## Applies it, emits `hit` (and `took_damage` when the player is hit), makes fight noise and
## returns the damage dealt.
func _strike(attacker: String, defender: String, base: int) -> int:
	var a := combatant(attacker)
	var d := combatant(defender)
	var distance := (a["pos"] as Vector2).distance_to(d["pos"])
	var amount := CombatTable.damage(base, a["style"], d["style"], distance, int(d["defence"]))
	var health := maxi(0, int(d["health"]) - amount)
	if defender == SimVocab.PLAYER:
		state["health"] = health
	else:
		state["enemies"][defender]["health"] = health
	_emit({
		"kind": SimVocab.EV_HIT, "attacker": attacker, "target": defender, "amount": amount,
		"style": a["style"], "multiplier": CombatTable.multiplier(a["style"], d["style"], distance),
		"health": health,
	})
	if defender == SimVocab.PLAYER:
		_emit({"kind": SimVocab.EV_TOOK_DAMAGE, "amount": amount, "cause": a["kind"], "health": health})
	_noise = maxf(_noise, CombatTable.NOISE_FIGHT)
	return amount


func _step_enemy(id: String) -> void:
	var e: Dictionary = state["enemies"][id]
	var tick := int(state["tick"])
	match e["mode"]:
		MODE_DEAD:
			if tick >= int(e["respawn_tick"]):
				state["enemies"][id] = _fresh_enemy(id)
				_emit({"kind": SimVocab.EV_ENEMY_RESPAWNED, "enemy_id": id, "pos": _xz(_home(id))})
		MODE_IDLE:
			var cause := _notice_cause(id)
			if cause != "":
				_engage(id, cause)
		MODE_ENGAGED:
			if _dead_cause != "":
				return
			if in_outpost():
				_disengage(id)
				return
			# A pack mate that noticed earlier this tick has already declared its next action.
			if int(e["next"].get("at", 0)) > tick:
				return
			_enemy_act(id)
			_enemy_declare(id)
		MODE_RETURNING:
			var home := _home(id)
			_walk_enemy(id, home)
			if _pos(e).distance_to(home) < 0.01:
				e["mode"] = MODE_IDLE
				e["health"] = int(CombatTable.enemy(e["kind"])["health"])
				e["step"] = 0


## Why an idle enemy notices the player this tick ("sight" or "noise"), or "" when it does not.
## Nothing outside notices a player inside the outpost.
func _notice_cause(id: String) -> String:
	if in_outpost() or _dead_cause != "":
		return ""
	var e: Dictionary = state["enemies"][id]
	var d := _pos(e).distance_to(player_pos())
	if d <= float(CombatTable.enemy(e["kind"])["sight"]):
		return CombatTable.NOTICE_SIGHT
	if d <= _noise:
		return CombatTable.NOTICE_NOISE
	return ""


## An enemy notices the player and joins the fight, and the rest of its pack with it.
func _engage(id: String, cause: String) -> void:
	_engage_one(id, cause)
	var pack: String = world.enemies[id]["pack"]
	for other in state["enemies"]:
		if other != id and world.enemies[other]["pack"] == pack and state["enemies"][other]["mode"] == MODE_IDLE:
			_engage_one(other, CombatTable.NOTICE_PACK)


func _engage_one(id: String, cause: String) -> void:
	state["enemies"][id]["mode"] = MODE_ENGAGED
	_emit({"kind": SimVocab.EV_ENEMY_NOTICED, "enemy_id": id, "cause": cause})
	_enemy_declare(id)


func _disengage(id: String) -> void:
	var e: Dictionary = state["enemies"][id]
	e["mode"] = MODE_RETURNING
	e["next"] = {}
	_emit({"kind": SimVocab.EV_ENEMY_DISENGAGED, "enemy_id": id})


## Carries out what the enemy declared last tick: closes in, rests, or strikes. A strike whose
## target has stepped out of reach since it was telegraphed is a miss.
func _enemy_act(id: String) -> void:
	var e: Dictionary = state["enemies"][id]
	var next: Dictionary = e["next"]
	var action := CombatTable.ACTION_MOVE
	if int(next.get("at", -1)) == int(state["tick"]):
		action = str(next["action"])
	e["next"] = {}
	if action == CombatTable.ACTION_MOVE:
		_chase(id)
		return
	if not CombatTable.is_attack(action):
		return
	var me := combatant(id)
	var toward := player_pos() - (me["pos"] as Vector2)
	if toward != Vector2.ZERO:
		e["facing"] = _xz(toward.normalized())
	if toward.length() > float(me["reach"]):
		_emit({"kind": SimVocab.EV_MISSED, "attacker": id, "target": SimVocab.PLAYER, "action": action})
		return
	_strike(id, SimVocab.PLAYER, CombatTable.action_damage(action))
	if int(state["health"]) <= 0:
		_dead_cause = e["kind"]


## Declares what the enemy does next tick: the next action of its cycle while the player is in
## its reach, else closing in. An attack is telegraphed now, exactly one tick before it lands.
func _enemy_declare(id: String) -> void:
	var e: Dictionary = state["enemies"][id]
	var me := combatant(id)
	var action := CombatTable.ACTION_MOVE
	var style: String = me["style"]
	if (me["pos"] as Vector2).distance_to(player_pos()) <= float(me["reach"]):
		var actions: Array = CombatTable.enemy(e["kind"])["actions"]
		var index := int(e["step"]) % actions.size()
		action = actions[index]
		style = CombatTable.weapon(CombatTable.stance_weapon(e["kind"], index))["style"]
		e["step"] = (index + 1) % actions.size()
	var at := int(state["tick"]) + 1
	e["next"] = {"action": action, "at": at}
	if CombatTable.is_attack(action):
		_emit({
			"kind": SimVocab.EV_ENEMY_TELEGRAPHED, "enemy_id": id, "action": action,
			"style": style, "damage": CombatTable.action_damage(action),
			"heavy": CombatTable.is_heavy(action), "at": at,
		})
	elif CombatTable.is_stance(action):
		_emit({"kind": SimVocab.EV_ENEMY_STANCE, "enemy_id": id, "action": action, "style": style, "at": at})


## Moves an engaged enemy toward a point just inside its reach of the player, on the side it
## comes from, fanned out a little per enemy so a pack does not stack on one spot.
func _chase(id: String) -> void:
	var me := combatant(id)
	var here: Vector2 = me["pos"]
	var target := player_pos()
	var away := (here - target).normalized()
	if away == Vector2.ZERO:
		away = Vector2(0, 1)
	away = away.rotated(float(world.enemies.keys().find(id) % 3 - 1) * 0.5)
	_walk_enemy(id, target + away * float(me["reach"]) * CombatTable.APPROACH_FRACTION)


## Walks an enemy up to its speed toward `goal`: straight when the ground between is open,
## else along a grid route. It never steps into the outpost. Emits `enemy_moved` if it moved.
func _walk_enemy(id: String, goal: Vector2) -> void:
	var e: Dictionary = state["enemies"][id]
	var start := _pos(e)
	if start.distance_to(goal) < 0.01:
		return
	var points: Array = []
	if GridPath.has_line_of_sight(world, start, goal):
		points = [_xz(goal)]
	else:
		var cell: Variant = world.nearest_walkable_cell(goal, SNAP_RADIUS_CELLS)
		if cell == null:
			return
		points = _route(start, cell, goal if world.is_walkable(goal) else world.cell_center(cell))
	var budget := float(CombatTable.enemy(e["kind"])["speed"])
	var pos := start
	var via: Array = [_xz(start)]
	for p in points:
		if budget <= 0.0:
			break
		var to := pos.move_toward(Vector2(p[0], p[1]), budget)
		if world.region_at(to) == WorldDef.REGION_OUTPOST:
			break
		budget -= pos.distance_to(to)
		pos = to
		via.append(_xz(pos))
	if pos == start:
		return
	var last := Vector2(via[via.size() - 2][0], via[via.size() - 2][1])
	e["pos"] = _xz(pos)
	e["facing"] = _xz((pos - last).normalized())
	_emit({
		"kind": SimVocab.EV_ENEMY_MOVED, "enemy_id": id, "from": _xz(start), "to": _xz(pos),
		"path": via, "facing": e["facing"],
	})


## An enemy's health ran out: its loot drops where it fell and it comes back home later.
func _kill_enemy(id: String) -> void:
	var e: Dictionary = state["enemies"][id]
	var def := CombatTable.enemy(e["kind"])
	var at := _pos(e)
	e["mode"] = MODE_DEAD
	e["next"] = {}
	e["respawn_tick"] = int(state["tick"]) + int(def["respawn_ticks"])
	_emit({"kind": SimVocab.EV_ENEMY_DIED, "enemy_id": id, "enemy_kind": e["kind"], "pos": _xz(at)})
	var drops: Array = (def["loot"] as Array).duplicate(true)
	var boss_loot: Array = def.get("boss_loot", [])
	if not boss_loot.is_empty():
		drops.append({"item": boss_loot[_rand(boss_loot.size())], "count": 1})
	if _roll(int(def["rare_percent"])):
		drops.append({"item": CombatTable.RARE_LOOT[_rand(CombatTable.RARE_LOOT.size())], "count": 1})
	for i in drops.size():
		_drop_loot(drops[i]["item"], int(drops[i]["count"]), at + Vector2(0.45 * i, 0.0))
	if _attack_target() == id:
		_stop_activity(SimVocab.REASON_TARGET_DEAD)
	var defeated: Array = state["bosses_defeated"]
	if def.get("boss", false) and not defeated.has(id):
		var before := _open_ring_gates()
		defeated.append(id)
		_announce_ring_gates(before)


func _home(id: String) -> Vector2:
	var home: Array = world.enemies[id]["home"]
	return Vector2(home[0], home[1])


# --- Loot -----------------------------------------------------------------------------

func _drop_loot(item: String, count: int, at: Vector2) -> void:
	state["loot_seq"] = int(state["loot_seq"]) + 1
	var id := "loot_%d" % int(state["loot_seq"])
	state["loot"][id] = {
		"item": item, "count": count, "pos": _xz(at), "expires_tick": int(state["tick"]) + LOOT_TICKS,
	}
	_emit({"kind": SimVocab.EV_LOOT_DROPPED, "loot_id": id, "item": item, "count": count, "pos": _xz(at)})


## Picks up as much of a loot pile as the pack has room for; the rest stays on the ground.
func _pick_up(id: String) -> void:
	var pile: Dictionary = state["loot"][id]
	var kind: String = pile["item"]
	var pack: Array = state["inventory"]["pack"]
	var n := mini(int(pile["count"]), Inventory.room_for(pack, kind))
	if n <= 0:
		_reject(SimVocab.INTERACT, {"object_id": id}, SimVocab.REASON_PACK_FULL)
		return
	Inventory.add(pack, kind, n)
	pile["count"] = int(pile["count"]) - n
	if int(pile["count"]) <= 0:
		(state["loot"] as Dictionary).erase(id)
	_emit({"kind": SimVocab.EV_PICKED_UP, "loot_id": id, "item": kind, "count": n})


func _step_loot() -> void:
	var tick := int(state["tick"])
	var loot: Dictionary = state["loot"]
	for id in loot.keys():
		if tick >= int(loot[id]["expires_tick"]):
			loot.erase(id)
			_emit({"kind": SimVocab.EV_LOOT_GONE, "loot_id": id})


# --- Field fires ----------------------------------------------------------------------

func _step_fires() -> void:
	var tick := int(state["tick"])
	var fires: Dictionary = state["fires"]
	for id in fires.keys():
		if tick >= int(fires[id]["expires_tick"]):
			fires.erase(id)
			_emit({"kind": SimVocab.EV_FIRE_OUT, "fire_id": id})


## Burns FIELD_FIRE_LOGS logs from the pack into a fire where the player stands. Not inside
## the outpost, which has its own fire.
func _light_fire(_args: Dictionary, commit: bool) -> String:
	if in_outpost():
		return SimVocab.REASON_IN_OUTPOST
	var pack: Array = state["inventory"]["pack"]
	if Inventory.count_of(pack, "logs") < FIELD_FIRE_LOGS:
		return SimVocab.REASON_MISSING_INPUTS
	if commit:
		Inventory.remove(pack, "logs", FIELD_FIRE_LOGS)
		state["fire_seq"] = int(state["fire_seq"]) + 1
		var id := FIELD_FIRE_PREFIX + str(int(state["fire_seq"]))
		var expires := int(state["tick"]) + FIELD_FIRE_TICKS
		state["fires"][id] = {"pos": _xz(player_pos()), "expires_tick": expires}
		_emit({"kind": SimVocab.EV_FIRE_LIT, "fire_id": id, "pos": _xz(player_pos()), "expires_tick": expires})
	return ""


# --- Outpost upgrades -----------------------------------------------------------------

## Builds an outpost upgrade, paying its cost out of the stash. Inside the outpost only, once,
## after the upgrades it requires; a locked upgrade is listed but cannot be built yet.
func _build(args: Dictionary, commit: bool) -> String:
	var id := str(args.get("upgrade", ""))
	if not UpgradeTable.has(id):
		return SimVocab.REASON_UNKNOWN_UPGRADE
	var upgrades: Array = state["upgrades"]
	if upgrades.has(id):
		return SimVocab.REASON_ALREADY_BUILT
	var u := UpgradeTable.get_upgrade(id)
	if u["locked"] != "":
		return SimVocab.REASON_UPGRADE_LOCKED
	for need in u["requires"]:
		if not upgrades.has(need):
			return SimVocab.REASON_UPGRADE_MISSING
	if not in_outpost():
		return SimVocab.REASON_NOT_IN_OUTPOST
	var slots: Array = state["stash"]["slots"]
	var cost: Dictionary = u["cost"]
	for kind in cost:
		if Inventory.count_of(slots, kind) < int(cost[kind]):
			return SimVocab.REASON_MISSING_INPUTS
	if commit:
		var before := _open_ring_gates()
		for kind in cost:
			Inventory.remove(slots, kind, int(cost[kind]))
		upgrades.append(id)
		var effects: Dictionary = u["effects"]
		var more := int(effects.get("stash", 0))
		if more > 0:
			state["stash"]["capacity"] = int(state["stash"]["capacity"]) + more
			slots.resize(slots.size() + more)
		_emit({"kind": SimVocab.EV_BUILT, "upgrade": id, "effects": effects.duplicate(true)})
		_announce_ring_gates(before)
		_save_due = "build"
	return ""


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
	var healing: Array = state["healing"]
	if not healing.is_empty():
		var healed := mini(HEALTH_MAX, health + int(healing.pop_front())) - health
		if healed > 0:
			health += healed
			_emit({"kind": SimVocab.EV_HEALED, "amount": healed, "health": health})
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
		_die("cold")


## Health ran out, to a blow or to the cold. Everything carried or worn is lost for good except
## the DEATH_KEEPS most valuable, which stay where they were: a stack counts as one thing,
## valued at its whole count, and ties go to what is worn, then to the earlier pack slot. The
## player wakes beside the outpost fire, warm and healed; skills, stash and upgrades are
## untouched, every enemy breaks off, and a spare axe waits if the last one was lost. Always a
## save point.
func _die(cause: String) -> void:
	var player: Dictionary = state["player"]
	var inventory: Dictionary = state["inventory"]
	_stop_activity(SimVocab.REASON_DIED)
	var held := _held_by_value()
	var kept: Array = []
	var lost: Array = []
	for i in held.size():
		var h: Dictionary = held[i]
		var entry := {"item": h["item"], "count": h["count"]}
		if i < DEATH_KEEPS:
			kept.append(entry)
			continue
		lost.append(entry)
		if h["slot"] is String:
			inventory["equipment"][h["slot"]] = ""
		else:
			inventory["pack"][h["slot"]] = null
	var spare := _spare_axe()
	var to := Vector2(world.rescue[0], world.rescue[1])
	player["pos"] = _xz(to)
	player["path"] = []
	player["target_object"] = ""
	player["ready_tick"] = 0
	state["health"] = HEALTH_MAX
	state["warmth"] = WARMTH_MAX
	state["healing"] = []
	state["pending"] = []
	_emit({
		"kind": SimVocab.EV_DIED, "cause": cause, "kept": kept, "lost": lost, "spare": spare, "pos": _xz(to),
	})
	var region := world.region_at(to)
	if region != player["region"]:
		_emit({"kind": SimVocab.EV_REGION_CHANGED, "from": player["region"], "to": region})
		player["region"] = region
	for id in state["enemies"]:
		if state["enemies"][id]["mode"] == MODE_ENGAGED:
			_disengage(id)
	_save_due = "death"


## The workbench makes an axe only from logs, which need an axe, so a death that took the last
## one would end woodcutting for good.
## When no axe is worn, carried or stashed, a spare wooden axe waits by the fire: in the tool
## slot when it is empty, else in the pack. Returns the item given, or "" when none was needed.
func _spare_axe() -> String:
	if has_tool("axe"):
		return ""
	for s in state["stash"]["slots"]:
		if s != null and ItemTable.tool(s["item"]) == "axe":
			return ""
	var inventory: Dictionary = state["inventory"]
	if inventory["equipment"][ItemTable.SLOT_TOOL] == "":
		inventory["equipment"][ItemTable.SLOT_TOOL] = STARTING_TOOL
	else:
		Inventory.add(inventory["pack"], STARTING_TOOL, 1)
	return STARTING_TOOL


## Everything carried or worn, most valuable first: {item, count, value, slot}, where `slot`
## is the equipment slot name or the pack index. Worn things come before the pack on a tie.
func _held_by_value() -> Array:
	var inventory: Dictionary = state["inventory"]
	var held: Array = []
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = inventory["equipment"][slot]
		if item != "":
			held.append({"item": item, "count": 1, "value": ItemTable.value(item), "slot": slot, "order": held.size()})
	var pack: Array = inventory["pack"]
	for i in pack.size():
		if pack[i] != null:
			var kind: String = pack[i]["item"]
			var count := int(pack[i]["count"])
			held.append({"item": kind, "count": count, "value": ItemTable.value(kind) * count, "slot": i, "order": held.size()})
	held.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["value"] > b["value"] or (a["value"] == b["value"] and a["order"] < b["order"]))
	return held


# --- Inventory and outpost actions ----------------------------------------------------

## Why a queued command (deposit, withdraw, drop, equip, eat, smith) would be refused right now,
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
		SimVocab.EAT:
			return _eat(args, commit)
		SimVocab.SMITH:
			return _smith(args, commit)
		SimVocab.BUILD:
			return _build(args, commit)
		SimVocab.LIGHT_FIRE:
			return _light_fire(args, commit)
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


## Eats one item of food from a pack slot. The meal costs the tick it lands on (the player
## neither steps nor swings) and heals the food's `heal` spread evenly over its `heal_ticks`,
## starting that tick; meals overlap by adding up. One meal per tick.
func _eat(args: Dictionary, commit: bool) -> String:
	var pack: Array = state["inventory"]["pack"]
	var i := _arg_index(args, pack)
	if i < 0:
		return SimVocab.REASON_BAD_ARGS
	if pack[i] == null:
		return SimVocab.REASON_EMPTY_SLOT
	var kind: String = pack[i]["item"]
	var heal := ItemTable.heal(kind)
	if heal <= 0:
		return SimVocab.REASON_NOT_FOOD
	if (_ate if commit else _eat_pending()):
		return SimVocab.REASON_ALREADY_EATING
	if commit:
		Inventory.take(pack, i, 1)
		var ticks := maxi(1, int(ItemTable.ITEMS[kind]["heal_ticks"]))
		var healing: Array = state["healing"]
		for t in ticks:
			var share := heal / ticks + (1 if t < heal % ticks else 0)
			if t < healing.size():
				healing[t] = int(healing[t]) + share
			else:
				healing.append(share)
		_ate = true
		_emit({"kind": SimVocab.EV_ATE, "item": kind, "heal": heal, "ticks": ticks})
	return ""


func _eat_pending() -> bool:
	for p in state["pending"]:
		if p["kind"] == SimVocab.EAT:
			return true
	return false


## Crafts a recipe at the workbench: consumes its inputs from the pack, adds its output.
func _smith(args: Dictionary, commit: bool) -> String:
	var id := str(args.get("recipe", ""))
	if not RecipeTable.has(id):
		return SimVocab.REASON_UNKNOWN_RECIPE
	var recipe := RecipeTable.get_recipe(id)
	if ItemTable.tier_rank(recipe["tier"]) > ItemTable.tier_rank(SMITHING_TIER_CAP):
		return SimVocab.REASON_TIER_CAPPED
	if not in_outpost() or not near_kind(WorldDef.KIND_WORKBENCH, USE_REACH):
		return SimVocab.REASON_NOT_AT_WORKBENCH
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
	_guide_observe(event)


# --- The first-outing guide -----------------------------------------------------------

## The current hint step's GuideTable id, or "" when the guide is off or its path is walked.
func hint() -> String:
	return GuideTable.step_id(int(state["guide"]["step"])) if hints_on() else ""


func hints_on() -> bool:
	return state["guide"]["on"]


## Advances the hint path and fires event-triggered tips. Sees every event as it is emitted,
## so a rejected command counts the moment it is answered.
func _guide_observe(event: Dictionary) -> void:
	var kind: String = event["kind"]
	if not hints_on() or kind == SimVocab.EV_HINT or kind == SimVocab.EV_TIP:
		return
	var guide: Dictionary = state["guide"]
	var step := int(guide["step"])
	if step < GuideTable.step_count() and GuideTable.matches(GuideTable.STEPS[step]["trigger"], event):
		guide["step"] = step + 1
		_emit({"kind": SimVocab.EV_HINT, "hint": GuideTable.step_id(step + 1)})
	for id in GuideTable.TIPS:
		for trigger in GuideTable.TIPS[id].get("triggers", []):
			if GuideTable.matches(trigger, event):
				_fire_tip(id)
				break


## Fires condition tips once the tick's rules have run.
func _step_guide() -> void:
	if not hints_on():
		return
	for id in GuideTable.TIPS:
		match GuideTable.TIPS[id].get("condition", ""):
			GuideTable.CONDITION_COLD:
				if int(state["warmth"]) <= GuideTable.COLD_WARMTH and not in_outpost() and not near_fire():
					_fire_tip(id)


## Emits a tip unless it fired within its cooldown.
func _fire_tip(id: String) -> void:
	var tips: Dictionary = state["guide"]["tips"]
	var tick := int(state["tick"])
	if tick < int(tips.get(id, 0)):
		return
	tips[id] = tick + int(GuideTable.TIPS[id]["cooldown"])
	_emit({"kind": SimVocab.EV_TIP, "tip": id})


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
	copy["enemies"] = _restored_enemies(copy.get("enemies"))
	copy["loot"] = _restored_loot(copy.get("loot"))
	copy["loot_seq"] = maxi(0, int(copy["loot_seq"])) if _is_number(copy.get("loot_seq")) else 0
	copy["fires"] = _restored_fires(copy.get("fires"))
	copy["fire_seq"] = maxi(0, int(copy["fire_seq"])) if _is_number(copy.get("fire_seq")) else 0
	var defeated: Array = []
	if copy.get("bosses_defeated") is Array:
		for id in copy["bosses_defeated"]:
			if world.enemies.has(str(id)) and not defeated.has(str(id)):
				defeated.append(str(id))
	copy["bosses_defeated"] = defeated
	var target := str(player.get("target_object", ""))
	var known_target: bool = world.objects.has(target) or copy["loot"].has(target) or copy["fires"].has(target)
	player["target_object"] = target if known_target else ""
	player["region"] = world.region_at(player_pos_of(player))
	player["activity"] = _restored_activity(player.get("activity"), copy["enemies"])
	player["ready_tick"] = int(player["ready_tick"]) if _is_number(player.get("ready_tick")) else 0
	copy["warmth"] = clampi(int(copy["warmth"]) if _is_number(copy.get("warmth")) else WARMTH_MAX, 0, WARMTH_MAX)
	copy["health"] = clampi(int(copy["health"]) if _is_number(copy.get("health")) else HEALTH_MAX, 1, HEALTH_MAX)
	var healing: Array = []
	if copy.get("healing") is Array:
		for h in copy["healing"]:
			healing.append(maxi(0, int(h)) if _is_number(h) else 0)
	copy["healing"] = healing

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
	copy["guide"] = _restored_guide(copy.get("guide"))
	state = copy
	_save_due = ""
	return true


## The guide from saved data: off, with its path walked, when unreadable, since a character
## old enough to have lost it is past its first outing.
static func _restored_guide(saved: Variant) -> Dictionary:
	var guide := {"on": false, "step": GuideTable.step_count(), "tips": {}}
	if not (saved is Dictionary):
		return guide
	guide["on"] = saved.get("on") is bool and saved["on"]
	if _is_number(saved.get("step")):
		guide["step"] = clampi(int(saved["step"]), 0, GuideTable.step_count())
	if saved.get("tips") is Dictionary:
		for id in saved["tips"]:
			if GuideTable.TIPS.has(str(id)) and _is_number(saved["tips"][id]):
				guide["tips"][str(id)] = int(saved["tips"][id])
	return guide


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


func _restored_activity(saved: Variant, enemies: Dictionary) -> Dictionary:
	if not (saved is Dictionary):
		return {}
	var id := str(saved.get("object_id", ""))
	match str(saved.get("kind", "")):
		SimVocab.GATHER:
			if is_node(id) and _is_number(saved.get("progress")):
				return {"kind": SimVocab.GATHER, "object_id": id, "progress": int(saved["progress"])}
		SimVocab.ATTACK:
			if enemies.has(id) and enemies[id]["mode"] != MODE_DEAD:
				return {"kind": SimVocab.ATTACK, "object_id": id}
		SimVocab.COOK:
			var item := str(saved.get("item", ""))
			if RecipeTable.is_cookable(item) and _is_number(saved.get("progress")):
				return {"kind": SimVocab.COOK, "item": item, "progress": int(saved["progress"])}
	return {}


## Every placed enemy, from saved data where it is readable and at home, unhurt and idle
## where it is not (which is also how a save from before combat loads).
func _restored_enemies(saved: Variant) -> Dictionary:
	var out := _fresh_enemies()
	for id in out:
		var entry: Variant = saved.get(id) if saved is Dictionary else null
		if not (entry is Dictionary) or not _is_xz(entry.get("pos")) or not _is_number(entry.get("health")):
			continue
		var mode := str(entry.get("mode", ""))
		if not ENEMY_MODES.has(mode):
			continue
		var e: Dictionary = out[id]
		var facing: Variant = entry.get("facing")
		var next: Variant = entry.get("next")
		e["pos"] = _xz(Vector2(entry["pos"][0], entry["pos"][1]))
		e["facing"] = _xz(Vector2(facing[0], facing[1])) if _is_xz(facing) else e["facing"]
		e["health"] = clampi(int(entry["health"]), 0, int(CombatTable.enemy(e["kind"])["health"]))
		e["mode"] = mode
		if next is Dictionary and CombatTable.ACTIONS.has(str(next.get("action", ""))) and _is_number(next.get("at")):
			e["next"] = {"action": str(next["action"]), "at": int(next["at"])}
		var cycle: int = (CombatTable.enemy(e["kind"])["actions"] as Array).size()
		e["step"] = posmod(int(entry["step"]), cycle) if _is_number(entry.get("step")) else 0
		e["respawn_tick"] = int(entry["respawn_tick"]) if _is_number(entry.get("respawn_tick")) else 0
	return out


## Loot piles from saved data: known items, counts within a stack, readable positions.
func _restored_loot(saved: Variant) -> Dictionary:
	var out := {}
	if not (saved is Dictionary):
		return out
	for id in saved:
		var pile: Variant = saved[id]
		if not (pile is Dictionary) or not ItemTable.has(str(pile.get("item", ""))):
			continue
		if not _is_number(pile.get("count")) or not _is_xz(pile.get("pos")) or not _is_number(pile.get("expires_tick")):
			continue
		var kind := str(pile["item"])
		var count := clampi(int(pile["count"]), 0, ItemTable.stack_size(kind))
		if count > 0:
			out[str(id)] = {
				"item": kind, "count": count, "pos": _xz(Vector2(pile["pos"][0], pile["pos"][1])),
				"expires_tick": int(pile["expires_tick"]),
			}
	return out


## Field fires from saved data: readable positions and burn-out ticks under the fire prefix.
func _restored_fires(saved: Variant) -> Dictionary:
	var out := {}
	if not (saved is Dictionary):
		return out
	for id in saved:
		var fire: Variant = saved[id]
		if str(id).begins_with(FIELD_FIRE_PREFIX) and fire is Dictionary and _is_xz(fire.get("pos")) and _is_number(fire.get("expires_tick")):
			out[str(id)] = {"pos": _xz(Vector2(fire["pos"][0], fire["pos"][1])), "expires_tick": int(fire["expires_tick"])}
	return out


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _is_xz(v: Variant) -> bool:
	return v is Array and v.size() == 2 and _is_number(v[0]) and _is_number(v[1])


# --- Read helpers ---------------------------------------------------------------------

func player_pos() -> Vector2:
	return player_pos_of(state["player"])


static func player_pos_of(player: Dictionary) -> Vector2:
	return Vector2(player["pos"][0], player["pos"][1])


## The position of anything stored with a `pos` of [x, z]: an enemy, a loot pile.
static func _pos(entry: Dictionary) -> Vector2:
	return Vector2(entry["pos"][0], entry["pos"][1])


func player_facing() -> Vector2:
	return Vector2(state["player"]["facing"][0], state["player"]["facing"][1])


func is_moving() -> bool:
	return not (state["player"]["path"] as Array).is_empty()


func is_gathering() -> bool:
	return state["player"]["activity"].get("kind", "") == SimVocab.GATHER


func is_attacking() -> bool:
	return state["player"]["activity"].get("kind", "") == SimVocab.ATTACK


func is_cooking() -> bool:
	return state["player"]["activity"].get("kind", "") == SimVocab.COOK


func in_outpost() -> bool:
	return state["player"]["region"] == WorldDef.REGION_OUTPOST


## True when the player stands within `reach` metres of any object of `kind`.
func near_kind(kind: String, reach: float) -> bool:
	var here := player_pos()
	for id in world.objects_of_kind(kind):
		if world.distance_to_object(id, here) <= reach:
			return true
	return false


## True when the player stands within FIRE_REACH of the outpost fire or a burning field fire.
func near_fire() -> bool:
	if near_kind(WorldDef.KIND_FIRE, FIRE_REACH):
		return true
	var here := player_pos()
	for id in state["fires"]:
		if _pos(state["fires"][id]).distance_to(here) <= FIRE_REACH:
			return true
	return false


## The best tier rank (wooden 0, bronze 1, iron 2) among the tools of `tool_kind` worn or
## carried, or -1 when there is none.
func tool_rank(tool_kind: String) -> int:
	var inventory: Dictionary = state["inventory"]
	var best := -1
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = inventory["equipment"][slot]
		if item != "" and ItemTable.tool(item) == tool_kind:
			best = maxi(best, ItemTable.tier_rank(ItemTable.tier(item)))
	for s in inventory["pack"]:
		if s != null and ItemTable.tool(s["item"]) == tool_kind:
			best = maxi(best, ItemTable.tier_rank(ItemTable.tier(s["item"])))
	return best


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
