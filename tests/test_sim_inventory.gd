## The pack, equipment and stash: carry weight, deposit and withdraw, Deposit haul, drop and equip.
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
	H.patch(sim, {"stash": {"capacity": Sim.STASH_START_SLOTS, "slots": []}})  # without the starting kit
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


## A sim inside the outpost with an empty stash of `capacity` slots and `pack` in the pack.
func _haul_sim(pack: Array, stash: Array = [], capacity := Sim.STASH_START_SLOTS) -> Sim:
	var sim := SimScript.new()
	H.patch(sim, {"stash": {"capacity": capacity, "slots": stash}})
	H.set_pack(sim, pack)
	return sim


func test_deposit_haul_moves_materials_and_raw_food_into_the_stash() -> void:
	var sim := _haul_sim(
		[{"item": "logs", "count": 4}, {"item": "copper_ore", "count": 3}, {"item": "raw_fish", "count": 2}, {"item": "wolf_pelt", "count": 1}],
		[{"item": "logs", "count": 5}],
	)
	assert_true(sim.command(Vocab.DEPOSIT_HAUL)["ok"])
	var events := H.run(sim, 1)
	assert_eq(Inventory.contents(sim.state["inventory"]["pack"]), [], "the pack held only haul")
	assert_eq(sim.state["stash"]["slots"][0], {"item": "logs", "count": 9}, "logs merge into the stashed stack")
	assert_eq(H.stash_count(sim, "copper_ore"), 3)
	assert_eq(H.stash_count(sim, "raw_fish"), 2, "raw food is haul")
	assert_eq(H.stash_count(sim, "wolf_pelt"), 1)
	var deposited := H.of_kind(events, Vocab.EV_DEPOSITED_HAUL)
	assert_eq(deposited.size(), 1)
	assert_eq(deposited[0]["items"], [
		{"item": "logs", "count": 4}, {"item": "copper_ore", "count": 3},
		{"item": "raw_fish", "count": 2}, {"item": "wolf_pelt", "count": 1},
	])
	assert_eq(deposited[0]["stayed"], [])
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[0]["reason"], Vocab.DEPOSIT_HAUL)


func test_deposit_haul_leaves_kit_in_the_pack() -> void:
	var kit := [
		{"item": "steel_pickaxe", "count": 1}, {"item": "bronze_sword", "count": 1},
		{"item": "wooden_bow", "count": 1}, {"item": "iron_body", "count": 1},
		{"item": "arrows", "count": 40}, {"item": "frost_shards", "count": 20},
		{"item": "cooked_fish", "count": 3},
	]
	var sim := _haul_sim(kit + [{"item": "iron_ore", "count": 2}])
	sim.command(Vocab.DEPOSIT_HAUL)
	var events := H.run(sim, 1)
	assert_eq(Inventory.contents(sim.state["inventory"]["pack"]), kit, "tools, weapons, armour, ammo and cooked food stay")
	assert_eq(H.stash_count(sim, "iron_ore"), 2)
	assert_eq(H.of_kind(events, Vocab.EV_DEPOSITED_HAUL)[0]["items"], [{"item": "iron_ore", "count": 2}])
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "wooden_axe", "worn gear is untouched")


func test_a_looted_weapon_counts_as_kit() -> void:
	var sim := _haul_sim([{"item": "logs", "count": 2}])
	var at: Array = (sim.state["player"]["pos"] as Array).duplicate()
	at[0] += 1.0
	H.patch(sim, {"loot": {"loot_1": {"item": "iron_sword", "count": 1, "pos": at, "expires_tick": 600}}, "loot_seq": 1})
	sim.command(Vocab.INTERACT, {"object_id": "loot_1"})
	H.run_until_idle(sim, 20)
	assert_eq(H.pack_count(sim, "iron_sword"), 1, "picked up inside the walls")
	sim.command(Vocab.DEPOSIT_HAUL)
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "iron_sword"), 1, "the looted sword stays to be tried on")
	assert_eq(H.stash_count(sim, "iron_sword"), 0)
	assert_eq(H.stash_count(sim, "logs"), 2)


func test_deposit_haul_moves_what_fits_and_reports_what_stayed() -> void:
	# A full two-slot stash with room for 2 more logs and 1 more ore: the rest stays in the pack.
	var sim := _haul_sim(
		[{"item": "logs", "count": 5}, {"item": "copper_ore", "count": 4}, {"item": "raw_fish", "count": 3}, {"item": "arrows", "count": 10}],
		[{"item": "logs", "count": 8}, {"item": "copper_ore", "count": 9}], 2,
	)
	assert_true(sim.command(Vocab.DEPOSIT_HAUL)["ok"])
	var events := H.run(sim, 1)
	var deposited := H.of_kind(events, Vocab.EV_DEPOSITED_HAUL)[0]
	assert_eq(deposited["items"], [{"item": "logs", "count": 2}, {"item": "copper_ore", "count": 1}])
	assert_eq(deposited["stayed"], [
		{"item": "logs", "count": 3}, {"item": "copper_ore", "count": 3}, {"item": "raw_fish", "count": 3},
	], "kit is never in stayed")
	assert_eq(H.pack_count(sim, "logs"), 3)
	assert_eq(H.pack_count(sim, "copper_ore"), 3)
	assert_eq(H.pack_count(sim, "raw_fish"), 3)
	assert_eq(H.pack_count(sim, "arrows"), 10)
	assert_eq(H.stash_count(sim, "logs"), 10)
	assert_eq(H.stash_count(sim, "copper_ore"), 10)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[0]["reason"], Vocab.DEPOSIT_HAUL, "a partial deposit still saves")


func test_deposit_haul_is_refused_outside_the_outpost() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	assert_eq(sim.check(Vocab.DEPOSIT_HAUL, {}), Vocab.REASON_NOT_IN_OUTPOST)
	assert_eq(sim.command(Vocab.DEPOSIT_HAUL)["reason"], Vocab.REASON_NOT_IN_OUTPOST)
	assert_eq(H.pack_count(sim, "logs"), 6)


func test_deposit_haul_is_refused_with_no_haul() -> void:
	var sim := _haul_sim([{"item": "steel_axe", "count": 1}, {"item": "cooked_char", "count": 2}])
	assert_eq(sim.check(Vocab.DEPOSIT_HAUL, {}), Vocab.REASON_NO_HAUL)
	assert_eq(sim.command(Vocab.DEPOSIT_HAUL)["reason"], Vocab.REASON_NO_HAUL)
	var empty := _haul_sim([])
	assert_eq(empty.command(Vocab.DEPOSIT_HAUL)["reason"], Vocab.REASON_NO_HAUL, "an empty pack has no haul")


func test_deposit_haul_is_refused_when_none_of_it_fits() -> void:
	var sim := _haul_sim([{"item": "logs", "count": 3}, {"item": "arrows", "count": 5}], [{"item": "logs", "count": 10}], 1)
	assert_eq(sim.check(Vocab.DEPOSIT_HAUL, {}), Vocab.REASON_STASH_FULL)
	assert_eq(sim.command(Vocab.DEPOSIT_HAUL)["reason"], Vocab.REASON_STASH_FULL)
	var events := H.run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED).size(), 0, "a refusal does not save")
	assert_eq(H.pack_count(sim, "logs"), 3)


func test_per_item_deposit_still_moves_kit() -> void:
	var sim := _haul_sim([{"item": "cooked_fish", "count": 3}])
	assert_true(sim.command(Vocab.DEPOSIT, {"index": 0})["ok"])
	H.run(sim, 1)
	assert_eq(H.stash_count(sim, "cooked_fish"), 3, "a single deposit takes kit by hand")
