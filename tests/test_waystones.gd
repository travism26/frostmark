## Waystones: the upgrade wakes them, a first visit attunes each one, and travel from an awake,
## attuned stone channels for a few ticks and leaves the player outside the outpost gate with the
## pack unbanked. A blow taken while channelling breaks it.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground beside each waystone, within reach of it.
const BY_RING_ONE_STONE := [11.5, 54.5]
const BY_RING_TWO_STONE := [-0.5, 118.5]
const HAUL := [{"item": "iron_ore", "count": 4}, {"item": "logs", "count": 6}]
const WINCH := ["stash_shelves", "forge", "armoury", "ring_two_gate"]


## A character standing by `stone` carrying HAUL, with `upgrades` built and `attuned` visited.
func _by_stone(stone: String, at: Array, upgrades: Array, attuned: Array) -> Sim:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": upgrades, "waystones": attuned})
	H.set_pack(sim, HAUL)
	H.place(sim, at)
	sim.drain_events()
	assert_true(sim.world.distance_to_object(stone, sim.player_pos()) <= Sim.USE_REACH, "%s is in reach" % stone)
	return sim


func test_a_waystone_stands_in_ring_one_and_in_ring_two() -> void:
	var world := WorldDef.outpost()
	var stones := world.objects_of_kind(WorldDef.KIND_WAYSTONE)
	assert_eq(stones.size(), 2)
	assert_eq(world.region_at(world.object_center("ring_one_waystone")), WorldDef.REGION_RING_ONE)
	assert_eq(world.region_at(world.object_center("ring_two_waystone")), WorldDef.REGION_RING_TWO)
	var woken: Array = UpgradeTable.get_upgrade("waystone")["effects"]["waystones"]
	for id in stones:
		assert_true(woken.has(id), "the waystone upgrade wakes %s" % id)
		assert_false(world.approach_cells(id).is_empty(), "%s can be walked up to" % id)


func test_the_upgrade_is_built_like_any_other() -> void:
	var sim := SimScript.new()
	var slots: Array = []
	slots.resize(Sim.STASH_START_SLOTS)
	slots[0] = {"item": "iron_ore", "count": 10}
	slots[1] = {"item": "bronze_bar", "count": 6}
	slots[2] = {"item": "logs", "count": 10}
	H.patch(sim, {"stash": {"capacity": Sim.STASH_START_SLOTS, "slots": slots}, "upgrades": WINCH.duplicate()})
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "waystone"})["ok"])
	H.run(sim, 1)
	assert_true((sim.state["upgrades"] as Array).has("waystone"))
	assert_true(sim.waystone_awake("ring_one_waystone"))
	assert_true(sim.waystone_awake("ring_two_waystone"))
	assert_eq(H.stash_count(sim, "iron_ore"), 0, "paid from the stash")


func test_a_first_visit_attunes_the_stone_once() -> void:
	var sim := SimScript.new()
	H.place(sim, [11.5, 50.5])
	sim.drain_events()
	assert_true(sim.command(Vocab.INTERACT, {"object_id": "ring_one_waystone"})["ok"])
	var events := H.run_until_idle(sim, 40)
	var interacted := H.of_kind(events, Vocab.EV_INTERACTED)
	assert_eq(interacted.size(), 1)
	assert_eq(interacted[0]["action"], Vocab.ACTION_WAYSTONE)
	assert_eq(H.of_kind(events, Vocab.EV_WAYSTONE_ATTUNED).size(), 1)
	assert_eq(sim.state["waystones"], ["ring_one_waystone"], "attuned before the upgrade is built")
	assert_eq(H.where(events, Vocab.EV_SAVED, "reason", "waystone").size(), 1, "attuning is a save point")
	# A second visit changes nothing.
	H.place(sim, [11.5, 50.5])
	sim.command(Vocab.INTERACT, {"object_id": "ring_one_waystone"})
	events = H.run_until_idle(sim, 40)
	assert_eq(H.of_kind(events, Vocab.EV_WAYSTONE_ATTUNED).size(), 0)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED).size(), 0)
	assert_eq(sim.state["waystones"], ["ring_one_waystone"])


func test_travel_is_refused_before_the_upgrade() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH.duplicate(), ["ring_one_waystone"])
	var result := sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	assert_eq(result["reason"], Vocab.REASON_UPGRADE_MISSING)
	assert_false(sim.is_travelling())
	assert_eq(H.of_kind(sim.drain_events(), Vocab.EV_COMMAND_REJECTED).size(), 1)


func test_travel_is_refused_before_the_stone_is_visited() -> void:
	var sim := _by_stone("ring_two_waystone", BY_RING_TWO_STONE, WINCH + ["waystone"], ["ring_one_waystone"])
	assert_eq(sim.command(Vocab.TRAVEL, {"object_id": "ring_two_waystone"})["reason"], Vocab.REASON_NOT_ATTUNED)
	assert_false(sim.is_travelling())


func test_travel_needs_a_waystone_in_reach() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH + ["waystone"], ["ring_one_waystone", "ring_two_waystone"])
	assert_eq(sim.command(Vocab.TRAVEL, {"object_id": "ring_two_waystone"})["reason"], Vocab.REASON_NOT_AT_WAYSTONE)
	assert_eq(sim.command(Vocab.TRAVEL, {"object_id": "tree_1"})["reason"], Vocab.REASON_NOT_WAYSTONE)
	assert_eq(sim.command(Vocab.TRAVEL, {"object_id": "nowhere"})["reason"], Vocab.REASON_UNKNOWN_OBJECT)
	assert_eq(sim.travel_check("ring_one_waystone"), "", "the one at hand would go")


func test_travel_channels_then_stands_outside_the_gate_without_banking() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH + ["waystone"], ["ring_one_waystone"])
	var stash_before: Array = sim.state["stash"]["slots"].duplicate(true)
	var result := sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	assert_true(result["ok"], result["reason"])
	var started := H.of_kind(sim.drain_events(), Vocab.EV_TRAVEL_STARTED)
	assert_eq(started.size(), 1)
	assert_eq(int(started[0]["ticks"]), Sim.TRAVEL_TICKS)
	var events := H.run_stamped(sim, Sim.TRAVEL_TICKS - 1)
	assert_eq(H.of_kind(events, Vocab.EV_TRAVELLED).size(), 0, "still channelling")
	assert_eq(sim.player_pos(), Vector2(BY_RING_ONE_STONE[0], BY_RING_ONE_STONE[1]), "standing still at the stone")
	events = H.run_stamped(sim, 1)
	var travelled := H.of_kind(events, Vocab.EV_TRAVELLED)
	assert_eq(travelled.size(), 1, "home on tick %d" % Sim.TRAVEL_TICKS)
	assert_false(sim.is_travelling())
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_INNER_RING, "outside the walls, not in them")
	var gate := sim.world.object_center("gate")
	assert_true(sim.player_pos().distance_to(gate) < 4.0, "on the outpost's doorstep")
	assert_true(sim.player_pos().y > gate.y, "on the outside of the gate")
	assert_eq(H.where(events, Vocab.EV_REGION_CHANGED, "to", WorldDef.REGION_INNER_RING).size(), 1)
	# Travel never banks: the pack is as it was and the stash untouched.
	assert_eq(H.of_kind(events, Vocab.EV_BANKED).size(), 0)
	assert_eq(H.pack_count(sim, "iron_ore"), 4)
	assert_eq(H.pack_count(sim, "logs"), 6)
	assert_eq(sim.state["stash"]["slots"], stash_before)
	assert_eq(H.where(events, Vocab.EV_SAVED, "reason", "waystone").size(), 1, "arriving is a save point")
	# The last step through the gate is the player's, and that banks.
	assert_true(sim.command(Vocab.CROSS_GATE)["ok"])
	events = H.run_until_idle(sim, 20)
	assert_eq(H.of_kind(events, Vocab.EV_BANKED).size(), 1)
	assert_eq(H.stash_count(sim, "iron_ore"), 4)


func test_travel_from_ring_two_comes_home_too() -> void:
	var sim := _by_stone("ring_two_waystone", BY_RING_TWO_STONE, WINCH + ["waystone"], ["ring_two_waystone"])
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO)
	assert_true(sim.command(Vocab.TRAVEL, {"object_id": "ring_two_waystone"})["ok"])
	var events := H.run(sim, Sim.TRAVEL_TICKS)
	assert_eq(H.of_kind(events, Vocab.EV_TRAVELLED).size(), 1)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_INNER_RING)
	assert_eq(H.pack_count(sim, "iron_ore"), 4, "the haul still in the pack")


func test_a_blow_breaks_the_channel() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH + ["waystone"], ["ring_one_waystone"])
	# A wolf a metre away: it notices, telegraphs and bites inside the channel.
	H.patch_enemy(sim, "wolf_1", {"pos": [10.5, 54.5]})
	sim.drain_events()
	assert_true(sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})["ok"])
	var events := H.run_stamped(sim, Sim.TRAVEL_TICKS + 2)
	var hits := H.where(events, Vocab.EV_HIT, "target", Vocab.PLAYER)
	assert_true(hits.size() > 0, "the wolf landed a bite")
	var stopped := H.where(events, Vocab.EV_ACTIVITY_STOPPED, "reason", Vocab.REASON_INTERRUPTED)
	assert_eq(stopped.size(), 1, "the bite broke the channel")
	assert_eq(stopped[0]["activity"], Vocab.TRAVEL)
	assert_eq(stopped[0]["tick"], hits[0]["tick"], "on the tick of the blow")
	assert_eq(H.of_kind(events, Vocab.EV_TRAVELLED).size(), 0, "no escape mid-fight")
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE)
	assert_false(sim.is_travelling())


func test_walking_off_breaks_the_channel() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH + ["waystone"], ["ring_one_waystone"])
	sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	H.run(sim, 2)
	sim.drain_events()
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [11.5, 50.5]})["ok"])
	var stopped := H.where(sim.drain_events(), Vocab.EV_ACTIVITY_STOPPED, "reason", Vocab.REASON_MOVED)
	assert_eq(stopped.size(), 1)
	assert_eq(H.of_kind(H.run(sim, Sim.TRAVEL_TICKS), Vocab.EV_TRAVELLED).size(), 0)


func test_the_fight_left_behind_breaks_off() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH + ["waystone"], ["ring_one_waystone"])
	# An archer engaged from well out of its reach: it closes in but cannot shoot in time.
	H.patch_enemy(sim, "archer_5", {"pos": [11.5, 30.5], "mode": Sim.MODE_ENGAGED})
	sim.drain_events()
	sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	var events := H.run(sim, Sim.TRAVEL_TICKS)
	assert_eq(H.of_kind(events, Vocab.EV_TRAVELLED).size(), 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DISENGAGED, "enemy_id", "archer_5").size(), 1)
	assert_eq(sim.state["enemies"]["archer_5"]["mode"], Sim.MODE_RETURNING)


func test_a_channel_in_progress_survives_a_save() -> void:
	var sim := _by_stone("ring_one_waystone", BY_RING_ONE_STONE, WINCH + ["waystone"], ["ring_one_waystone"])
	sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	H.run(sim, 2)
	var loaded := SimScript.new()
	assert_true(loaded.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_eq(loaded.snapshot(), sim.snapshot())
	assert_true(loaded.is_travelling())
	assert_eq(H.of_kind(H.run(loaded, Sim.TRAVEL_TICKS - 2), Vocab.EV_TRAVELLED).size(), 1)


func test_restore_keeps_only_real_attuned_waystones() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"waystones": ["ring_two_waystone", "tree_1", "nowhere", "ring_two_waystone", 7]})
	assert_eq(sim.state["waystones"], ["ring_two_waystone"])
	H.patch(sim, {"waystones": "junk"})
	assert_eq(sim.state["waystones"], [])
