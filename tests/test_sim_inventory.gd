## The pack, equipment and stash: carry weight, deposit and withdraw, drop and equip.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func _walked_after(sim: Sim, ticks: int) -> float:
	var start := sim.player_pos()
	H.run(sim, ticks)
	return start.distance_to(sim.player_pos())


func test_carry_weight_slows_movement() -> void:
	var light := SimScript.new()
	var heavy := SimScript.new()
	var load: Array = []
	for i in 3:
		load.append({"item": "logs", "count": 10})
	H.set_pack(heavy, load)
	assert_false(light.is_overweight())
	assert_true(heavy.carry_weight() > Sim.CARRY_LIMIT, "thirty logs and an axe are over the limit")
	assert_true(heavy.is_overweight())
	for sim in [light, heavy]:
		sim.command(Vocab.MOVE_TO, {"pos": [6.5, 4.5]})
	var normal := _walked_after(light, 1)
	var slowed := _walked_after(heavy, 1)
	assert_almost_eq(normal, Sim.WALK_PER_TICK, 0.001)
	assert_almost_eq(slowed, Sim.WALK_PER_TICK * Sim.OVERWEIGHT_SPEED, 0.001)


func test_carry_weight_counts_pack_and_equipment() -> void:
	var sim := SimScript.new()
	assert_eq(sim.carry_weight(), ItemTable.weight("wooden_axe"))
	H.set_pack(sim, [{"item": "logs", "count": 5}])
	assert_eq(sim.carry_weight(), ItemTable.weight("wooden_axe") + 5 * ItemTable.weight("logs"))


func test_deposit_and_withdraw_inside_the_outpost() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	assert_true(sim.command(Vocab.DEPOSIT, {"index": 0, "count": 4})["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.pack_count(sim, "logs"), 2)
	assert_eq(H.stash_count(sim, "logs"), 4)
	assert_eq(H.of_kind(events, Vocab.EV_DEPOSITED)[0]["count"], 4)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[0]["reason"], Vocab.DEPOSIT, "an outpost action saves")
	assert_true(sim.command(Vocab.WITHDRAW, {"index": 0})["ok"])
	events = H.run(sim, 1)
	assert_eq(H.pack_count(sim, "logs"), 6, "withdraw takes the whole stack by default")
	assert_eq(H.stash_count(sim, "logs"), 0)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[0]["reason"], Vocab.WITHDRAW)


func test_stash_actions_are_refused_outside() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	assert_eq(sim.command(Vocab.DEPOSIT, {"index": 0})["reason"], Vocab.REASON_NOT_IN_OUTPOST)
	assert_eq(sim.command(Vocab.WITHDRAW, {"index": 0})["reason"], Vocab.REASON_NOT_IN_OUTPOST)


func test_stash_capacity_is_visible_and_enforced() -> void:
	var sim := SimScript.new()
	assert_eq(sim.state["stash"]["capacity"], Sim.STASH_START_SLOTS)
	assert_eq(sim.state["stash"]["slots"].size(), Sim.STASH_START_SLOTS)
	var snap := sim.snapshot()
	snap["stash"] = {"capacity": 1, "slots": [{"item": "logs", "count": 10}]}
	sim.restore(snap)
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	assert_eq(sim.command(Vocab.DEPOSIT, {"index": 0})["reason"], Vocab.REASON_STASH_FULL)


func test_withdraw_refuses_into_a_full_pack() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["stash"]["slots"][0] = {"item": "wooden_club", "count": 1}
	sim.restore(snap)
	var full: Array = []
	for i in Sim.PACK_SLOTS:
		full.append({"item": "logs", "count": 10})
	H.set_pack(sim, full)
	assert_eq(sim.command(Vocab.WITHDRAW, {"index": 0})["reason"], Vocab.REASON_PACK_FULL)


func test_drop_frees_a_slot_anywhere() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	assert_true(sim.command(Vocab.DROP, {"index": 0, "count": 2})["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.pack_count(sim, "logs"), 4)
	assert_eq(H.of_kind(events, Vocab.EV_DROPPED)[0], {"kind": Vocab.EV_DROPPED, "item": "logs", "count": 2})
	assert_eq(sim.command(Vocab.DROP, {"index": 5})["reason"], Vocab.REASON_EMPTY_SLOT)
	assert_eq(sim.command(Vocab.DROP, {"index": 99})["reason"], Vocab.REASON_BAD_ARGS)


func test_equip_swaps_with_the_slot() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "wooden_club", "count": 1}, {"item": "logs", "count": 2}])
	assert_true(sim.command(Vocab.EQUIP, {"index": 0})["ok"])
	var events := H.run(sim, 1)
	assert_eq(sim.state["inventory"]["equipment"]["weapon"], "wooden_club")
	assert_eq(sim.state["inventory"]["pack"][0], null, "the club left the pack")
	assert_eq(H.of_kind(events, Vocab.EV_EQUIPPED)[0]["slot"], "weapon")
	assert_eq(sim.command(Vocab.EQUIP, {"index": 1})["reason"], Vocab.REASON_NOT_EQUIPPABLE, "logs are not gear")
	assert_true(sim.command(Vocab.EQUIP, {"unequip": "tool"})["ok"])
	H.run(sim, 1)
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "")
	assert_eq(H.pack_count(sim, "wooden_axe"), 1, "the axe went into the pack")
	assert_true(sim.has_tool(ItemTable.TOOL_AXE), "still counts for gathering from the pack")


func test_queued_commands_apply_on_the_next_tick() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	sim.command(Vocab.DEPOSIT, {"index": 0})
	assert_eq(H.pack_count(sim, "logs"), 6, "nothing moves until step()")
	sim.step()
	assert_eq(H.pack_count(sim, "logs"), 0)
