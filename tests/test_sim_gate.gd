## The gate: walking in banks the whole pack into the stash, celebrates and autosaves.
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


func test_crossing_inward_banks_the_pack_and_saves() -> void:
	var sim := _outside_with([{"item": "logs", "count": 7}, {"item": "wooden_club", "count": 1}])
	var events := H.walk_to(sim, [0.5, 6.5])
	var banked := H.of_kind(events, Vocab.EV_BANKED)
	assert_eq(banked.size(), 1, "one banked event")
	assert_eq(banked[0]["items"], [{"item": "logs", "count": 7}, {"item": "wooden_club", "count": 1}])
	assert_eq(banked[0]["overflow"], [])
	assert_eq(Inventory.contents(sim.state["inventory"]["pack"]), [], "the pack is empty")
	assert_eq(H.stash_count(sim, "logs"), 7)
	assert_eq(H.stash_count(sim, "wooden_club"), 1)
	var saved := H.of_kind(events, Vocab.EV_SAVED)
	assert_eq(saved.size(), 1, "one save point")
	assert_eq(saved[0]["reason"], "gate")
	assert_true(events.find(banked[0]) < events.find(saved[0]), "banked before saved")


func test_equipment_is_not_banked() -> void:
	var sim := _outside_with([])
	H.walk_to(sim, [0.5, 6.5])
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "wooden_axe", "the axe stays in hand")


func test_an_empty_pack_still_banks_and_saves() -> void:
	var sim := _outside_with([])
	var events := H.walk_to(sim, [0.5, 6.5])
	assert_eq(H.of_kind(events, Vocab.EV_BANKED).size(), 1)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED).size(), 1)


func test_overflow_stays_in_the_pack_and_is_reported() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["stash"] = {"capacity": 1, "slots": [{"item": "logs", "count": 8}]}
	sim.restore(snap)
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 5}, {"item": "wooden_club", "count": 1}])
	var events := H.walk_to(sim, [0.5, 6.5])
	var banked := H.of_kind(events, Vocab.EV_BANKED)[0]
	assert_eq(banked["items"], [{"item": "logs", "count": 2}], "tops up the stash's last stack")
	assert_eq(banked["overflow"], [{"item": "logs", "count": 3}, {"item": "wooden_club", "count": 1}])
	assert_eq(H.pack_count(sim, "logs"), 3)
	assert_eq(H.pack_count(sim, "wooden_club"), 1)
	assert_eq(H.stash_count(sim, "logs"), 10)


func test_crossing_outward_does_not_bank() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	var events := H.walk_to(sim, H.OUTSIDE)
	assert_eq(H.of_kind(events, Vocab.EV_BANKED).size(), 0)
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
	assert_eq(H.of_kind(events, Vocab.EV_BANKED).size(), 1)
	assert_eq(H.stash_count(sim, "logs"), 2)
