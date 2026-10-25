## Shared arrangement helpers for the simulation tests. Not a test file itself (the runner
## only discovers test_*.gd). Everything here goes through Sim's public interface:
## `command()`, `step()`, `drain_events()`, `snapshot()` and `restore()`.
extends RefCounted

const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## A point on open ground in the inner ring, just south of the gate.
const OUTSIDE := [0.5, 12.5]
## A point on open floor inside the outpost, clear of the fire's warmth.
const INSIDE_COLD_CORNER := [-7.5, 7.5]


static func run(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events


## Steps until the player is idle (not walking, not gathering) or `max_ticks` pass.
static func run_until_idle(sim: Sim, max_ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in max_ticks:
		sim.step()
		events.append_array(sim.drain_events())
		if not sim.is_moving() and not sim.is_gathering():
			break
	return events


static func of_kind(events: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["kind"] == kind:
			out.append(e)
	return out


## Walks to `pos` and returns the events of the walk.
static func walk_to(sim: Sim, pos: Array) -> Array[Dictionary]:
	sim.drain_events()
	var result := sim.command(Vocab.MOVE_TO, {"pos": pos})
	assert(result["ok"], "walk_to %s rejected: %s" % [pos, result["reason"]])
	return run_until_idle(sim, 200)


## Replaces the pack with `entries` ({item, count} in slot order) through restore().
static func set_pack(sim: Sim, entries: Array) -> void:
	var snap := sim.snapshot()
	var pack: Array = []
	pack.resize(Sim.PACK_SLOTS)
	for i in entries.size():
		pack[i] = entries[i]
	snap["inventory"]["pack"] = pack
	sim.restore(snap)


## Overrides top-level or nested state keys through restore(), e.g. {"warmth": 3}.
static func patch(sim: Sim, changes: Dictionary) -> void:
	var snap := sim.snapshot()
	snap.merge(changes, true)
	sim.restore(snap)


static func pack_count(sim: Sim, kind: String) -> int:
	return Inventory.count_of(sim.state["inventory"]["pack"], kind)


static func stash_count(sim: Sim, kind: String) -> int:
	return Inventory.count_of(sim.state["stash"]["slots"], kind)


## Puts the player at `pos` through restore(), standing still with nothing to do.
static func place(sim: Sim, pos: Array) -> void:
	var snap := sim.snapshot()
	snap["player"]["pos"] = pos
	snap["player"]["path"] = []
	snap["player"]["target_object"] = ""
	snap["player"]["activity"] = {}
	sim.restore(snap)


## Puts `weapon` in the weapon slot ("" for bare hands) and `entries` in the pack, through
## restore(), so a fight can start this tick without waiting for a queued equip.
static func arm(sim: Sim, weapon: String, entries: Array = []) -> void:
	set_pack(sim, entries)
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["weapon"] = weapon
	sim.restore(snap)


## Overrides fields of one enemy's state through restore(), e.g. {"health": 1}.
static func patch_enemy(sim: Sim, id: String, changes: Dictionary) -> void:
	var snap := sim.snapshot()
	snap["enemies"][id].merge(changes, true)
	sim.restore(snap)


## Steps one tick at a time for `ticks` ticks, stamping every event with the `tick` it
## happened on.
static func run_stamped(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		sim.step()
		for e in sim.drain_events():
			e["tick"] = int(sim.state["tick"])
			events.append(e)
	return events


## Events of `kind` whose `field` equals `value`.
static func where(events: Array[Dictionary], kind: String, field: String, value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in of_kind(events, kind):
		if e.get(field) == value:
			out.append(e)
	return out


## Stand-in kinds for the feint rule, which no enemy uses yet. A feint pretends to be a lunge
## (or, for the kiting kind, a dart); `add_stand_ins()` puts them in CombatTable for a test.
const STAND_IN_ACTIONS := {
	"feint_lunge": {"label": "Lunge", "damage": 0, "feint": "lunge"},
	"feint_dart": {"label": "Dart", "damage": 0, "feint": "dart"},
}
const STAND_IN_KINDS := {
	# Feints a lunge, then lunges for real, rests, winds up into another feint, and rests.
	"stand_in_feinter": {
		"label": "Feinter", "health": 500, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["feint_lunge", "lunge", CombatTable.ACTION_REST, "wind_up", "feint_lunge", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Backs away inside 4 m like a ruin stalker, and feints its first dart.
	"stand_in_kiting_feinter": {
		"label": "Kiting feinter", "health": 500, "weapon": "stalker_bow", "speed": 1.5, "sight": 10.0,
		"kite": 4.0, "actions": ["feint_dart", CombatTable.ACTION_REST, "dart", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
}


static func add_stand_ins() -> void:
	CombatTable.add_stand_ins(STAND_IN_KINDS, STAND_IN_ACTIONS)


## A sim of the real world with only `enemies` in it (id -> {kind, home}), each its own pack,
## in the order given.
static func arena(enemies: Dictionary) -> Sim:
	var world := WorldDef.outpost()
	world.enemies = {}
	for id in enemies:
		world.enemies[id] = {"kind": enemies[id]["kind"], "home": enemies[id]["home"], "pack": id}
	return SimScript.new(world)
