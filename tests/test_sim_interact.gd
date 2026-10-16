## The interact command: walk to an object and begin its (for now, no-op) action.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func _run_until_idle(sim: Sim, max_ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in max_ticks:
		sim.step()
		events.append_array(sim.drain_events())
		if not sim.is_moving():
			break
	return events


func test_interact_walks_to_the_marker_and_emits_arrival() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	assert_true(result["ok"], result["reason"])
	var path_set := sim.drain_events()[0]
	assert_eq(path_set["kind"], Vocab.EV_PATH_SET)
	assert_eq(path_set["object_id"], "workbench")
	var events := _run_until_idle(sim, 40)
	var arrived: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_ARRIVED)
	var interacted: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_INTERACTED)
	assert_eq(arrived.size(), 1, "one arrival")
	assert_eq(arrived[0]["object_id"], "workbench")
	assert_eq(interacted.size(), 1, "one interaction on arrival")
	assert_eq(interacted[0]["object_kind"], WorldDef.KIND_WORKBENCH)
	assert_eq(interacted[0]["action"], Vocab.ACTION_CRAFT, "the workbench opens crafting")
	assert_true(sim.player_pos().distance_to(sim.world.object_center("workbench")) < 2.5, "stands beside it")
	assert_true(sim.world.is_walkable(sim.player_pos()))
	assert_eq(sim.state["player"]["target_object"], "", "target cleared after arrival")


func test_interact_with_the_gate_stands_on_the_threshold() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.INTERACT, {"object_id": "gate"})["ok"])
	_run_until_idle(sim, 40)
	var o: Dictionary = sim.world.objects["gate"]
	var p := sim.player_pos()
	assert_true(p.x >= o["min"][0] and p.x < o["max"][0] and p.y >= o["min"][1] and p.y < o["max"][1], "inside the gate footprint")


func test_plain_move_arrival_has_no_object() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.MOVE_TO, {"pos": [3.5, 4.5]})
	var events := _run_until_idle(sim, 40)
	var arrived: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_ARRIVED)
	assert_eq(arrived.size(), 1)
	assert_eq(arrived[0]["object_id"], "")
	assert_true(events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_INTERACTED).is_empty())


func test_unknown_object_is_rejected() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.INTERACT, {"object_id": "dragon"})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_UNKNOWN_OBJECT)
	assert_false(sim.is_moving())


func test_move_cancels_a_pending_interaction() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.INTERACT, {"object_id": "stash"})
	sim.step()
	sim.command(Vocab.MOVE_TO, {"pos": [0.5, 6.5]})
	sim.drain_events()
	var events := _run_until_idle(sim, 40)
	assert_true(events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_INTERACTED).is_empty(), "no interaction")
	var arrived: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_ARRIVED)
	assert_eq(arrived.size(), 1)
	assert_eq(arrived[0]["object_id"], "")
