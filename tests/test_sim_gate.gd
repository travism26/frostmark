## The gate: walking in is a return. It moves nothing, announces what you carry and autosaves.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func _outside_with(entries: Array) -> Sim:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_INNER_RING, "walked out")
	H.set_pack(sim, entries)
	return sim


func test_crossing_inward_leaves_the_pack_and_stash_and_saves() -> void:
	var sim := _outside_with([{"item": "logs", "count": 7}, {"item": "wooden_club", "count": 1}, {"item": "logs", "count": 2}])
	var pack: Array = sim.state["inventory"]["pack"].duplicate(true)
	var stash: Array = sim.state["stash"]["slots"].duplicate(true)
	var events := H.walk_to(sim, [0.5, 6.5])
	var returned := H.of_kind(events, Vocab.EV_RETURNED)
	assert_eq(returned.size(), 1, "one returned event")
	assert_eq(returned[0]["items"], [{"item": "logs", "count": 9}, {"item": "wooden_club", "count": 1}], "the pack, merged")
	assert_eq(sim.state["inventory"]["pack"], pack, "the pack is exactly as it was")
	assert_eq(sim.state["stash"]["slots"], stash, "the stash is exactly as it was")
	var saved := H.of_kind(events, Vocab.EV_SAVED)
	assert_eq(saved.size(), 1, "one save point")
	assert_eq(saved[0]["reason"], "gate")
	assert_true(events.find(returned[0]) < events.find(saved[0]), "returned before saved")


func test_worn_equipment_is_untouched() -> void:
	var sim := _outside_with([{"item": "logs", "count": 2}])
	var worn: Dictionary = sim.state["inventory"]["equipment"].duplicate(true)
	H.walk_to(sim, [0.5, 6.5])
	assert_eq(sim.state["inventory"]["equipment"], worn, "worn gear stays worn")
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "wooden_axe", "the axe stays in hand")


func test_an_empty_pack_still_returns_and_saves() -> void:
	var sim := _outside_with([])
	var events := H.walk_to(sim, [0.5, 6.5])
	var returned := H.of_kind(events, Vocab.EV_RETURNED)
	assert_eq(returned.size(), 1)
	assert_eq(returned[0]["items"], [], "nothing carried")
	assert_eq(H.where(events, Vocab.EV_SAVED, "reason", "gate").size(), 1)


func test_a_full_stash_changes_nothing_at_the_gate() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["stash"] = {"capacity": 1, "slots": [{"item": "logs", "count": 8}]}
	sim.restore(snap)
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 5}, {"item": "wooden_club", "count": 1}])
	var events := H.walk_to(sim, [0.5, 6.5])
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED)[0]["items"], [{"item": "logs", "count": 5}, {"item": "wooden_club", "count": 1}])
	assert_eq(H.pack_count(sim, "logs"), 5)
	assert_eq(H.stash_count(sim, "logs"), 8, "the gate never tops up the stash")


func test_no_banked_event_is_ever_emitted() -> void:
	var sim := _outside_with([{"item": "logs", "count": 3}])
	var events := H.walk_to(sim, [0.5, 6.5])
	events.append_array(H.walk_to(sim, H.OUTSIDE))
	events.append_array(H.walk_to(sim, [0.5, 6.5]))
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 2, "one return per crossing")
	assert_eq(H.of_kind(events, "banked").size(), 0)


func test_the_pack_rides_out_on_the_next_trip() -> void:
	var sim := _outside_with([{"item": "logs", "count": 4}])
	H.walk_to(sim, [0.5, 6.5])
	H.walk_to(sim, H.OUTSIDE)
	assert_eq(H.pack_count(sim, "logs"), 4, "what stayed in the pack goes out again")


func test_crossing_outward_is_not_a_return() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	var events := H.walk_to(sim, H.OUTSIDE)
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 0)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED).size(), 0)
	assert_eq(H.pack_count(sim, "logs"), 3)
	var changed := H.of_kind(events, Vocab.EV_REGION_CHANGED)
	assert_eq(changed[0]["to"], WorldDef.REGION_INNER_RING)


func test_cross_gate_walks_through_either_way() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.CROSS_GATE)["ok"])
	H.run_until_idle(sim, 60)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_INNER_RING, "out through the gate")
	H.set_pack(sim, [{"item": "logs", "count": 2}])
	sim.drain_events()
	assert_true(sim.command(Vocab.CROSS_GATE)["ok"])
	var events := H.run_until_idle(sim, 60)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST, "back in")
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 1)
	assert_eq(H.pack_count(sim, "logs"), 2)
