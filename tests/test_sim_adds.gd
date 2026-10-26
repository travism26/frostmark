## Adds: lesser enemies a boss calls into its fight once, as a fight phase starts. No game kind
## calls adds yet, so the stand-in caller in tests/sim_helpers.gd carries the rule: below half
## health it calls two wolves from 5 m either side of its home, announced a tick ahead, and
## below 30 % it calls nobody. Adds never respawn, drop their usual loot, and leave when the
## boss gives up the fight; its next fight calls them again.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one with nobody else in the arena, and a metre north of it: inside the
## caller's sight and its fangs' reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
const EAST := [19.5, 28.5]
const WEST := [9.5, 28.5]
const ADDS := ["foe_add_1", "foe_add_2"]
## The player is topped up below this, so a fight runs as long as a test needs.
const TOP_UP := 50


## A player standing beside a lone caller, before either has acted, not fighting back, with the
## caller at `health`.
func _caller(health := 100) -> Sim:
	H.add_stand_ins()
	var sim := _arena()
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	if health != 100:
		H.patch_enemy(sim, "foe", {"health": health})
	sim.drain_events()
	return sim


func _arena() -> Sim:
	return H.arena({"foe": {"kind": "stand_in_caller", "home": HOME}})


## Steps `ticks` ticks like H.run_stamped, topping the player's health and warmth up as it goes.
func _run(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		if int(sim.state["health"]) < TOP_UP or int(sim.state["warmth"]) < TOP_UP:
			H.patch(sim, {"health": Sim.HEALTH_MAX, "warmth": Sim.WARMTH_MAX})
		events.append_array(H.run_stamped(sim, 1))
	return events


func _adds_in(sim: Sim) -> Array:
	return sim.state["enemies"].keys().filter(func(id: String) -> bool: return sim.state["enemies"][id].has("called_by"))


func test_a_boss_below_its_mark_announces_each_add_a_tick_ahead_at_its_entry_point() -> void:
	var sim := _caller(49)
	assert_true(sim.world.is_walkable(Vector2(EAST[0], EAST[1])) and sim.world.is_walkable(Vector2(WEST[0], WEST[1])), "open ground")
	var told := _run(sim, 1)
	var called := H.of_kind(told, Vocab.EV_ADD_CALLED)
	assert_eq(called.size(), 2, "two adds called as the phase starts")
	assert_eq(H.where(told, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe").size(), 1, "with the phase's stance")
	for i in called.size():
		var e: Dictionary = called[i]
		assert_eq(e["enemy_id"], ADDS[i])
		assert_eq(e["enemy_kind"], "wolf")
		assert_eq(e["boss_id"], "foe")
		assert_eq(e["pos"], [EAST, WEST][i], "at its entry point")
		assert_eq(e["at"], 2, "coming in next tick")
		assert_eq(sim.state["enemies"][ADDS[i]]["mode"], Sim.MODE_CALLED, "announced, not there yet")
	var came := _run(sim, 1)
	for i in ADDS.size():
		var add: Dictionary = sim.state["enemies"][ADDS[i]]
		assert_eq(H.where(came, Vocab.EV_ENEMY_NOTICED, "enemy_id", ADDS[i]).size(), 1, "%s comes in" % ADDS[i])
		assert_eq(H.where(came, Vocab.EV_ENEMY_NOTICED, "enemy_id", ADDS[i])[0]["cause"], CombatTable.NOTICE_CALLED)
		assert_eq(add["mode"], Sim.MODE_ENGAGED, "and fights")
		assert_eq(add["pos"], [EAST, WEST][i], "from its entry point")
	var fight := _run(sim, 12)
	for id in ADDS:
		assert_true(H.where(fight, Vocab.EV_HIT, "attacker", id).size() > 0, "%s closes in and bites" % id)


func test_an_add_cannot_be_attacked_before_it_comes_in() -> void:
	var sim := _caller(49)
	_run(sim, 1)
	var answer := sim.command(Vocab.ATTACK, {"enemy_id": ADDS[0]})
	assert_false(answer["ok"])
	assert_eq(answer["reason"], Vocab.REASON_UNKNOWN_ENEMY)


func test_a_boss_above_its_mark_calls_nobody() -> void:
	var sim := _caller()
	assert_eq(H.of_kind(_run(sim, 20), Vocab.EV_ADD_CALLED).size(), 0)
	assert_eq(_adds_in(sim), [])


func test_a_boss_calls_its_adds_once_and_a_deeper_mark_without_adds_calls_none() -> void:
	var sim := _caller(49)
	var events := _run(sim, 6)
	H.patch_enemy(sim, "foe", {"health": 25})
	events.append_array(_run(sim, 20))
	assert_eq(H.of_kind(events, Vocab.EV_ADD_CALLED).size(), 2, "only the first mark's two")
	assert_eq(int(sim.state["enemies"]["foe"]["phase"]), 2, "though it is in its deeper phase")
	assert_eq(_adds_in(sim), ADDS)


func test_a_blow_across_both_marks_still_calls_the_first_mark_s_adds() -> void:
	var sim := _caller(25)
	var events := _run(sim, 3)
	assert_eq(H.of_kind(events, Vocab.EV_ADD_CALLED).size(), 2)
	assert_eq(int(sim.state["enemies"]["foe"]["phase"]), 2)


func test_a_killed_add_drops_its_usual_loot_and_does_not_come_back() -> void:
	var sim := _caller(49)
	_run(sim, 2)
	H.patch_enemy(sim, ADDS[0], {"health": 1})
	H.arm(sim, "iron_sword")
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": ADDS[0]})["ok"])
	var events := _run(sim, 12)
	var died := H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", ADDS[0])
	assert_eq(died.size(), 1, "the add falls")
	if died.is_empty():
		return
	var pelts := H.where(events, Vocab.EV_LOOT_DROPPED, "item", "wolf_pelt")
	assert_eq(pelts.size(), 1, "and drops a wolf's pelt")
	assert_eq(pelts[0]["pos"], died[0]["pos"], "where it fell")
	var later := _run(sim, int(CombatTable.enemy("wolf")["respawn_ticks"]) + 20)
	assert_eq(H.where(later, Vocab.EV_ENEMY_RESPAWNED, "enemy_id", ADDS[0]).size(), 0, "it never comes back")
	assert_eq(H.where(later, Vocab.EV_ADD_CALLED, "enemy_id", ADDS[0]).size(), 0, "nor is it called again")
	assert_eq(sim.state["enemies"][ADDS[0]]["mode"], Sim.MODE_DEAD)


func test_the_adds_leave_when_the_boss_disengages_and_come_again_in_its_next_fight() -> void:
	var sim := _caller(49)
	_run(sim, 3)
	var events := H.walk_to(sim, H.INSIDE_COLD_CORNER)
	events.append_array(_run(sim, 20))
	for id in ADDS:
		assert_eq(H.where(events, Vocab.EV_ADD_LEFT, "enemy_id", id).size(), 1, "%s leaves" % id)
	assert_eq(_adds_in(sim), [], "and is gone")
	var foe: Dictionary = sim.state["enemies"]["foe"]
	assert_eq(foe["mode"], Sim.MODE_IDLE, "the boss walked home")
	assert_eq(int(foe["health"]), 100, "and healed")
	H.place(sim, BESIDE)
	var again := _run(sim, 2)
	assert_eq(H.of_kind(again, Vocab.EV_ADD_CALLED).size(), 0, "from full health it calls nobody")
	H.patch_enemy(sim, "foe", {"health": 49})
	again = _run(sim, 6)
	assert_eq(H.of_kind(again, Vocab.EV_ADD_CALLED).size(), 2, "and at the mark calls them again")


func test_the_adds_leave_when_the_player_walks_out_of_the_boss_s_room() -> void:
	H.add_stand_ins()
	var boss := "ring_one_dungeon_boss"
	var sim := H.arena({boss: {"kind": "stand_in_caller", "home": [73.0, 44.0]}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, [74.2, 44.0])
	H.patch_enemy(sim, boss, {"health": 49})
	sim.drain_events()
	_run(sim, 3)
	assert_eq(_adds_in(sim).size(), 2, "the adds are in")
	H.place(sim, [88.0, 56.0])
	var events := _run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_ADD_LEFT).size(), 2, "and leave with the boss")
	assert_eq(sim.state["enemies"][boss]["mode"], Sim.MODE_RETURNING)
	assert_eq(_adds_in(sim), [])


func test_adds_still_to_come_leave_with_their_boss() -> void:
	var sim := _caller(49)
	_run(sim, 1)
	H.place(sim, H.INSIDE_COLD_CORNER)
	var events := _run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_ADD_LEFT).size(), 2)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED).size(), 0, "neither comes in")
	assert_eq(_adds_in(sim), [])


func test_adds_fight_on_when_their_boss_falls_and_leave_when_it_comes_back() -> void:
	var sim := _caller(49)
	_run(sim, 2)
	H.patch_enemy(sim, "foe", {"health": 1})
	H.arm(sim, "iron_sword")
	sim.command(Vocab.ATTACK, {"enemy_id": "foe"})
	var events := _run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "foe").size(), 1, "the boss falls")
	assert_eq(H.of_kind(events, Vocab.EV_ADD_LEFT).size(), 0, "its adds stay")
	for id in ADDS:
		assert_eq(sim.state["enemies"][id]["mode"], Sim.MODE_ENGAGED, "%s fights on" % id)
	events = _run(sim, int(H.STAND_IN_KINDS["stand_in_caller"]["respawn_ticks"]) + 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_RESPAWNED, "enemy_id", "foe").size(), 1, "the boss comes back")
	assert_eq(H.of_kind(events, Vocab.EV_ADD_LEFT).size(), 2, "and its old adds go")
	assert_false(sim.state["enemies"].has(ADDS[0]))


func test_a_save_with_adds_in_the_fight_restores_them_as_they_were() -> void:
	for ticks in [1, 4]:
		var sim := _caller(49)
		_run(sim, ticks)
		var snap := sim.snapshot()
		var restored := _arena()
		assert_true(restored.restore(snap))
		var imported := _arena()
		assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
		var ahead := _run(sim, 10)
		for copy: Sim in [restored, imported]:
			copy.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
			copy.drain_events()
			for id in ADDS:
				assert_eq(copy.state["enemies"][id], snap["enemies"][id], "tick %d: %s as it was" % [ticks, id])
			assert_eq(_run(copy, 10), ahead, "tick %d: and the fight goes on exactly as the original" % ticks)


func test_restore_drops_an_add_it_cannot_read() -> void:
	var sim := _caller(49)
	_run(sim, 3)
	var bad := {
		"no boss": {"called_by": "nobody"}, "unknown kind": {"kind": "dragon"}, "no entry": {"entry": null},
		"walking home": {"mode": Sim.MODE_RETURNING}, "idle": {"mode": Sim.MODE_IDLE},
	}
	for why in bad:
		var snap := sim.snapshot()
		snap["enemies"][ADDS[0]].merge(bad[why], true)
		var copy := _arena()
		assert_true(copy.restore(snap))
		assert_false(copy.state["enemies"].has(ADDS[0]), "%s: dropped" % why)
		assert_true(copy.state["enemies"].has(ADDS[1]), "%s: the other add stays" % why)


func test_the_combat_table_refuses_an_add_of_an_unknown_kind_or_with_no_entry_point() -> void:
	var phase := {"below": 50, "actions": ["draw_bow"]}
	var good := phase.merged({"adds": [{"kind": "wolf", "entry": [5, 0]}, {"kind": "bandit_archer", "entry": [-4.5, 2.0]}]})
	assert_eq(CombatTable.add_problems({"phases": [good]}), [] as Array[String])
	assert_eq(CombatTable.add_problems({"phases": [phase]}), [] as Array[String], "a phase need not call anyone")
	for add: Variant in [{"kind": "dragon", "entry": [5, 0]}, {"entry": [5, 0]}, "wolf"]:
		var problems := CombatTable.add_problems({"phases": [phase.merged({"adds": [add]})]})
		assert_true(problems.size() >= 1, "%s is refused" % [add])
		assert_true(problems[0].contains("not an enemy kind"), problems[0])
	for entry: Variant in [null, [], [5], [5, "north"], "edge"]:
		var add := {"kind": "wolf", "entry": entry} if entry != null else {"kind": "wolf"}
		var problems := CombatTable.add_problems({"phases": [phase.merged({"adds": [add]})]})
		assert_eq(problems.size(), 1, "entry %s is refused" % [entry])
		if problems.size() == 1:
			assert_true(problems[0].contains("no entry point"), problems[0])
	assert_eq(CombatTable.add_problems({"phases": [phase.merged({"adds": "wolf"})]}).size(), 1, "adds must be a list")
	assert_eq(CombatTable.add_problems({"adds": [{"kind": "wolf", "entry": [5, 0]}]}).size(), 1, "adds come with a phase")


func test_the_game_table_and_the_stand_ins_have_no_add_problems() -> void:
	H.add_stand_ins()
	for kind in CombatTable.ENEMIES.keys() + H.STAND_IN_KINDS.keys():
		assert_eq(CombatTable.add_problems(CombatTable.enemy(kind)), [] as Array[String], "%s's adds" % kind)
	assert_eq(CombatTable.adds("stand_in_caller", 0), [], "the kind's own cycle calls nobody")
	assert_eq(CombatTable.adds("stand_in_caller", 1).size(), 2)
	assert_eq(CombatTable.adds("stand_in_caller", 2), [])


func test_no_game_kind_calls_adds_yet() -> void:
	for kind in CombatTable.ENEMIES:
		for phase in range(1, CombatTable.phase_count(kind) + 1):
			assert_eq(CombatTable.adds(kind, phase), [], "%s's phase %d" % [kind, phase])
