## Drop marks and one-tick marks: an area blow can drop its mark where the player stands on the
## tick it is told, and a fight phase's cycle can carry one told a tick ahead instead of two.
## No enemy uses either yet, so the stand-in dropper (a drop mark) and quick phaser (one-tick
## drop and front marks in its phase) in tests/sim_helpers.gd carry the rules.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one (the first archer's spot, with nobody else in the arena), and a
## metre north of it: inside a stand-in's sight and its fangs' reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
const TOLD := 1


## A player beside a lone stand-in of `kind` with `health`, no step taken yet.
func _arena(kind: String, health := -1) -> Sim:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": kind, "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	if health >= 0:
		H.patch_enemy(sim, "foe", {"health": health})
	sim.drain_events()
	return sim


func _blows(events: Array[Dictionary], kind: String) -> Array[Dictionary]:
	return H.where(events, kind, "attacker", "foe")


func test_a_drop_mark_is_centred_where_the_player_stood_when_it_was_told() -> void:
	var sim := _arena("stand_in_dropper")
	var marked := H.where(H.run_stamped(sim, 1), Vocab.EV_GROUND_MARKED, "enemy_id", "foe")
	assert_eq(marked.size(), 1, "the ice fall is told as a ground mark")
	if marked.size() != 1:
		return
	var mark: Dictionary = marked[0]["mark"]
	assert_eq(mark["shape"], CombatTable.MARK_DROP)
	assert_eq(mark["centre"], BESIDE, "on the player, not the enemy")
	assert_almost_eq(float(mark["radius"]), 2.5)
	assert_false(mark.has("facing"), "a drop faces nowhere")
	assert_eq(marked[0]["at"], TOLD + CombatTable.MARK_TICKS, "two ticks of warning, like the other shapes")


func test_a_drop_mark_hits_a_player_who_stays_and_misses_one_who_moves_off() -> void:
	var stayed := _arena("stand_in_dropper")
	var hits := _blows(H.run_stamped(stayed, 3), Vocab.EV_HIT)
	assert_eq(hits.size(), 1, "standing still is inside the drop")
	if hits.size() == 1:
		assert_true(hits[0].get("area", false))
		assert_eq(hits[0]["tick"], 3)
		assert_eq(hits[0]["amount"], 14)
	var moved := _arena("stand_in_dropper")
	H.run_stamped(moved, 1)
	moved.command(Vocab.MOVE_TO, {"pos": [14.5, 24.5]})
	var events := H.run_stamped(moved, 2)
	assert_eq(_blows(events, Vocab.EV_HIT).size(), 0)
	var missed := _blows(events, Vocab.EV_MISSED)
	assert_eq(missed.size(), 1, "the ice falls on empty ground")
	if missed.size() == 1:
		assert_true(missed[0].get("area", false))
		assert_eq(missed[0]["tick"], 3)
	assert_eq(moved.state["health"], Sim.HEALTH_MAX)


func test_a_drop_mark_stays_where_it_was_told_when_the_player_moves() -> void:
	var sim := _arena("stand_in_dropper")
	H.run_stamped(sim, 1)
	var told: Dictionary = sim.state["enemies"]["foe"]["next"]["mark"].duplicate(true)
	sim.command(Vocab.MOVE_TO, {"pos": [14.5, 24.5]})
	H.run_stamped(sim, 1)
	assert_eq(sim.state["enemies"]["foe"]["next"]["mark"], told, "it does not follow the player")
	assert_eq(told["centre"], BESIDE)


func test_a_save_taken_mid_drop_lands_the_same_mark_on_the_same_tick() -> void:
	var sim := _arena("stand_in_dropper")
	H.run_stamped(sim, 1)
	var snap := sim.snapshot()
	var mark: Dictionary = snap["enemies"]["foe"]["next"]["mark"]
	var restored := H.arena({"foe": {"kind": "stand_in_dropper", "home": HOME}})
	assert_true(restored.restore(snap))
	assert_eq(restored.state["enemies"]["foe"]["next"]["mark"], mark)
	restored.command(Vocab.MOVE_TO, {"pos": [14.5, 24.5]})
	assert_eq(_blows(H.run_stamped(restored, 2), Vocab.EV_MISSED).size(), 1, "the restored drop lands where it was told")


func test_a_one_tick_mark_in_a_phase_is_told_a_tick_ahead_and_a_step_off_misses() -> void:
	var sim := _arena("stand_in_quick_phaser", 40)
	# Tick 1: the phase opens with its stance. Tick 2: the quick fall is told for tick 3.
	H.run_stamped(sim, 1)
	var events := H.run_stamped(sim, 1)
	var marked := H.where(events, Vocab.EV_GROUND_MARKED, "enemy_id", "foe")
	assert_eq(marked.size(), 1, "the quick fall is told as a ground mark")
	if marked.size() != 1:
		return
	assert_eq(marked[0]["action"], "quick_fall")
	assert_eq(marked[0]["at"], int(sim.state["tick"]) + 1, "it lands one tick on")
	assert_eq(marked[0]["mark"]["centre"], BESIDE)
	sim.command(Vocab.MOVE_TO, {"pos": [14.5, 25.5]})
	events = H.run_stamped(sim, 1)
	assert_eq(_blows(events, Vocab.EV_HIT).size(), 0, "a player who steps off on its telegraph is missed")
	var missed := _blows(events, Vocab.EV_MISSED)
	assert_eq(missed.size(), 1)
	if missed.size() == 1:
		assert_true(missed[0].get("area", false))
		assert_eq(missed[0]["tick"], marked[0]["at"])


func test_a_one_tick_mark_hits_a_player_who_stays() -> void:
	var sim := _arena("stand_in_quick_phaser", 40)
	H.run_stamped(sim, 2)
	var hits := _blows(H.run_stamped(sim, 1), Vocab.EV_HIT)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_eq(hits[0]["amount"], 12)


func test_the_enemy_is_rooted_for_the_single_tick_too() -> void:
	var sim := _arena("stand_in_quick_phaser", 40)
	H.run_stamped(sim, 2)
	var told: Dictionary = sim.snapshot()["enemies"]["foe"]
	sim.command(Vocab.MOVE_TO, {"pos": [14.5, 31.5]})
	var events := H.run_stamped(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_MOVED, "enemy_id", "foe").size(), 0)
	assert_eq(sim.snapshot()["enemies"]["foe"]["pos"], told["pos"])


func test_the_combat_table_refuses_a_one_tick_mark_out_of_a_phase_or_too_big() -> void:
	H.add_stand_ins()
	CombatTable.add_stand_ins({}, {
		"big_fall": {"label": "Fall", "damage": 12, "shape": CombatTable.MARK_DROP, "size": 2.5, "warn": 1},
		"big_stomp": {"label": "Stomp", "damage": 12, "shape": CombatTable.MARK_RING, "size": 2.5, "warn": 1},
		"huge_smash": {"label": "Smash", "damage": 12, "shape": CombatTable.MARK_FRONT, "size": 4.5, "warn": 1},
		"slow_fall": {"label": "Fall", "damage": 12, "shape": CombatTable.MARK_DROP, "size": 1.0, "warn": 3},
		"edge_fall": {"label": "Fall", "damage": 12, "shape": CombatTable.MARK_RING, "size": 2.0, "warn": 1},
	})
	var rest := CombatTable.ACTION_REST
	var own := CombatTable.area_problems({"actions": ["quick_fall", rest]})
	assert_eq(own.size(), 1, "a kind's own cycle refuses a one-tick mark")
	if own.size() == 1:
		assert_true(own[0].begins_with("the kind: quick_fall"), own[0])
	for bad in ["big_fall", "big_stomp", "huge_smash", "slow_fall"]:
		var problems := CombatTable.area_problems({"actions": [rest], "phases": [{"below": 50, "actions": [bad, rest]}]})
		assert_eq(problems.size(), 1, "%s is refused in a phase" % bad)
		if problems.size() == 1:
			assert_true(problems[0].begins_with("phase 1: %s" % bad), problems[0])
	for ok in ["quick_fall", "quick_smash", "edge_fall"]:
		var problems := CombatTable.area_problems({"actions": [rest], "phases": [{"below": 50, "actions": [ok, rest]}]})
		assert_eq(problems, [] as Array[String], "%s is small enough to step off in a tick" % ok)


func test_a_mark_fits_a_tick_when_every_point_is_within_a_walk_of_its_edge() -> void:
	assert_almost_eq(CombatTable.WALK_PER_TICK, Sim.WALK_PER_TICK, 0.0001, "the combat table's walk is the player's")
	assert_almost_eq(CombatTable.mark_depth(CombatTable.MARK_RING, 2.0), 2.0, 0.0001)
	assert_almost_eq(CombatTable.mark_depth(CombatTable.MARK_DROP, 1.5), 1.5, 0.0001)
	# A 120 degree sector's widest inscribed circle is about 0.46 of its radius.
	assert_almost_eq(CombatTable.mark_depth(CombatTable.MARK_FRONT, 4.0), 1.857, 0.001)


func test_the_game_table_has_no_one_tick_marks_and_no_problems() -> void:
	for kind in CombatTable.ENEMIES:
		assert_eq(CombatTable.area_problems(CombatTable.enemy(kind)), [] as Array[String], kind)
	for action in CombatTable.ACTIONS:
		assert_false(CombatTable.ACTIONS[action].has("warn"), "%s: no game blow is told early yet" % action)
