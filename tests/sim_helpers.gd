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
