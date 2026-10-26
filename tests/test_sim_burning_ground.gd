## Burning ground: an area blow may leave a burning patch where it landed, which hurts the player
## on each tick they stand on it and never an enemy, goes out on its last tick, and clears when
## its enemy gives up the fight. No enemy leaves any yet, so the stand-in scorcher (a ring) and
## searer (a front mark) in tests/sim_helpers.gd carry the rule.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one (the first archer's spot, with nobody else in the arena), and a
## metre north of it: inside a stand-in's sight and its fangs' reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## Told on tick 1, the blow lands on tick 3; the scorch burns 3 ticks for 5 each, so it burns on
## ticks 4, 5 and 6 and goes out on 6.
const LANDS := 3
const OUT := 6
const BURN := 5


## A player beside a lone stand-in of `kind` with auto-retaliate off, the first tick stepped.
func _arena(kind := "stand_in_scorcher", extra := {}) -> Sim:
	H.add_stand_ins()
	var enemies := {"foe": {"kind": kind, "home": HOME}}
	enemies.merge(extra)
	var sim := H.arena(enemies)
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	sim.drain_events()
	sim.step()
	return sim


## The events of stepping on to tick `tick`.
func _to(sim: Sim, tick: int) -> Array[Dictionary]:
	return H.run_stamped(sim, tick - int(sim.state["tick"]))


func _burns(events: Array[Dictionary]) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["kind"] == Vocab.EV_HIT and e.get("burning", false))


func test_a_patch_matching_the_mark_is_left_on_the_landing_tick_when_the_blow_hits() -> void:
	var sim := _arena()
	var mark: Dictionary = sim.state["enemies"]["foe"]["next"]["mark"].duplicate(true)
	var events := _to(sim, LANDS)
	var started := H.where(events, Vocab.EV_BURNING_STARTED, "enemy_id", "foe")
	assert_eq(started.size(), 1)
	if started.size() != 1:
		return
	assert_eq(started[0]["tick"], LANDS)
	assert_eq(started[0]["mark"], mark, "on the mark that was told")
	assert_eq(started[0]["damage"], BURN)
	assert_eq(started[0]["until"], OUT)
	var patch: Dictionary = sim.state["burning"][started[0]["patch_id"]]
	assert_eq(patch["mark"], mark, "the patch keeps its geometry in the state")
	assert_eq(patch["until"], OUT, "and the tick it goes out")
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", "foe").size(), 1, "the blow itself hit")
	assert_eq(_burns(events).size(), 0, "the patch hurts no one on the tick it is laid")


func test_a_patch_is_left_even_when_the_blow_missed() -> void:
	var sim := _arena()
	sim.command(Vocab.MOVE_TO, {"pos": [14.5, 24.5]})
	var events := _to(sim, LANDS)
	assert_eq(H.where(events, Vocab.EV_MISSED, "attacker", "foe").size(), 1, "the blow missed")
	assert_eq(H.of_kind(events, Vocab.EV_BURNING_STARTED).size(), 1, "the ground burns all the same")
	assert_eq((sim.state["burning"] as Dictionary).size(), 1)


func test_a_front_mark_leaves_a_front_patch() -> void:
	var sim := _arena("stand_in_searer")
	var mark: Dictionary = sim.state["enemies"]["foe"]["next"]["mark"].duplicate(true)
	var started := H.of_kind(_to(sim, LANDS), Vocab.EV_BURNING_STARTED)
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0]["mark"], mark)
		assert_eq(started[0]["until"], LANDS + 4)
		assert_eq(started[0]["damage"], 4)


func test_a_player_on_the_patch_burns_on_each_tick_they_stand_on_it() -> void:
	var sim := _arena()
	_to(sim, LANDS)
	var health := int(sim.state["health"])
	var burns := _burns(H.run_stamped(sim, 3))
	assert_eq(burns.size(), 3, "one burn on each tick on the patch")
	for i in burns.size():
		assert_eq(burns[i]["tick"], LANDS + 1 + i)
		assert_eq(burns[i]["amount"], BURN)
		assert_true(burns[i].get("area", false))
		assert_eq(burns[i]["attacker"], "foe")
	assert_true(int(sim.state["health"]) <= health - 3 * BURN)


func test_a_player_off_the_patch_takes_nothing_and_one_walking_off_it_stops_burning() -> void:
	var sim := _arena()
	_to(sim, LANDS)
	var patch: Dictionary = (sim.state["burning"] as Dictionary).values()[0]
	sim.command(Vocab.MOVE_TO, {"pos": [14.5, 20.5]})
	var burned := 0
	var clear := 0
	for i in 3:
		var events := H.run_stamped(sim, 1)
		var on := CombatTable.in_mark(patch["mark"], sim.player_pos())
		var burns := _burns(events).size()
		assert_eq(burns, 1 if on else 0, "tick %d: %s the patch" % [sim.state["tick"], "on" if on else "off"])
		burned += burns
		clear += 0 if on else 1
	assert_true(burned > 0 and clear > 0, "the walk took them from on the patch to off it")


func test_the_patch_goes_out_on_its_last_tick_with_an_event_and_hurts_no_one_after() -> void:
	var sim := _arena()
	var events := _to(sim, OUT)
	var out := H.of_kind(events, Vocab.EV_BURNING_OUT)
	assert_eq(out.size(), 1)
	if out.size() == 1:
		assert_eq(out[0]["tick"], OUT)
		assert_eq(out[0]["patch_id"], H.of_kind(events, Vocab.EV_BURNING_STARTED)[0]["patch_id"])
	assert_eq(_burns(events).size(), 3, "it burned on its last tick before it went out")
	assert_true((sim.state["burning"] as Dictionary).is_empty())
	# The scorcher lays its next patch on tick 7, which burns no one on the tick it is laid, so
	# nothing hurts on the tick after the first goes out.
	assert_eq(_burns(H.run_stamped(sim, 1)).size(), 0, "the old patch hurts no one after")


func test_armour_cuts_burning_ground() -> void:
	var sim := _arena()
	var snap := sim.snapshot()
	var worn: Dictionary = snap["inventory"]["equipment"]
	worn["helm"] = "iron_helm"
	worn["body"] = "iron_body"
	worn["legs"] = "iron_legs"
	assert_true(sim.restore(snap))
	var defence := int(sim.combatant(Vocab.PLAYER)["defence"])
	assert_true(defence > 0)
	_to(sim, LANDS)
	var burns := _burns(H.run_stamped(sim, 1))
	assert_eq(burns.size(), 1)
	if burns.size() == 1:
		assert_eq(burns[0]["amount"], maxi(1, BURN - defence))


func test_burning_ground_never_hurts_the_boss_an_add_or_any_other_enemy() -> void:
	var sim := _arena("stand_in_scorcher", {"bystander": {"kind": "stand_in_smasher", "home": [14.5, 29.5]}})
	var before := {}
	for id in ["foe", "bystander"]:
		H.patch_enemy(sim, id, {"health": 100})
		before[id] = 100
	var events := _to(sim, OUT)
	assert_eq(H.of_kind(events, Vocab.EV_BURNING_STARTED).size(), 1)
	for id in ["foe", "bystander"]:
		assert_eq(sim.state["enemies"][id]["health"], before[id], "%s is unhurt" % id)
		assert_eq(H.where(_burns(events), Vocab.EV_HIT, "target", id).size(), 0)


func test_the_patch_goes_out_when_its_enemy_disengages() -> void:
	var sim := _arena()
	_to(sim, LANDS)
	assert_eq((sim.state["burning"] as Dictionary).size(), 1)
	var outpost: Vector2 = Vector2(sim.world.spawn[0], sim.world.spawn[1])
	H.place(sim, [outpost.x, outpost.y])
	var events := H.run_stamped(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_DISENGAGED).size(), 1)
	assert_eq(H.of_kind(events, Vocab.EV_BURNING_OUT).size(), 1, "the fire goes out with the fight")
	assert_true((sim.state["burning"] as Dictionary).is_empty())


func test_the_patch_goes_out_when_the_player_dies() -> void:
	var sim := _arena()
	_to(sim, LANDS)
	var snap := sim.snapshot()
	snap["health"] = 1
	assert_true(sim.restore(snap))
	var events := H.run_stamped(sim, 1)
	var died := H.of_kind(events, Vocab.EV_DIED)
	assert_eq(died.size(), 1, "the fire killed them")
	if died.size() == 1:
		assert_eq(died[0]["cause"], "stand_in_scorcher")
	assert_eq(H.of_kind(events, Vocab.EV_BURNING_OUT).size(), 1)
	assert_true((sim.state["burning"] as Dictionary).is_empty())


func test_a_snapshot_taken_while_a_patch_burns_restores_it_with_the_same_ticks_left() -> void:
	var sim := _arena()
	_to(sim, LANDS + 1)
	var saved := sim.snapshot()
	var json: Variant = JSON.parse_string(JSON.stringify(saved))
	var copy := _arena()
	assert_true(copy.restore(json))
	assert_eq(copy.state["burning"], sim.state["burning"], "the same patch, through JSON")
	var ours := H.run_stamped(sim, 4)
	var theirs := H.run_stamped(copy, 4)
	assert_eq(H.of_kind(theirs, Vocab.EV_BURNING_OUT).size(), 1)
	assert_eq(H.of_kind(theirs, Vocab.EV_BURNING_OUT)[0]["tick"], OUT)
	assert_eq(_burns(theirs).size(), _burns(ours).size())
	assert_eq(copy.state["health"], sim.state["health"])


func test_a_saved_patch_that_cannot_be_read_is_dropped() -> void:
	var sim := _arena()
	_to(sim, LANDS)
	var snap := sim.snapshot()
	var id: String = (snap["burning"] as Dictionary).keys()[0]
	snap["burning"][id]["mark"] = {"shape": "blob"}
	assert_true(sim.restore(snap))
	assert_true((sim.state["burning"] as Dictionary).is_empty())


func test_the_combat_table_refuses_burning_ground_with_no_duration_or_no_damage() -> void:
	var rest := CombatTable.ACTION_REST
	var ring := {"label": "Bad", "damage": 10, "shape": CombatTable.MARK_RING, "size": 3.0}
	var cases := {
		"no duration": {"burn_damage": 4},
		"no damage": {"burn_ticks": 3},
		"zero duration": {"burn_ticks": 0, "burn_damage": 4},
		"zero damage": {"burn_ticks": 3, "burn_damage": 0},
		"fractional duration": {"burn_ticks": 2.5, "burn_damage": 4},
	}
	for name: String in cases:
		var action: Dictionary = ring.duplicate()
		action.merge(cases[name])
		CombatTable.add_stand_ins({}, {"bad_burn": action})
		var problems := CombatTable.area_problems({"actions": ["bad_burn", rest]})
		assert_eq(problems.size(), 1, "%s: %s" % [name, problems])
		assert_true(problems.size() == 1 and "burning ground" in problems[0], name)
		CombatTable.clear_stand_ins()
	H.add_stand_ins()
	assert_eq(CombatTable.area_problems({"actions": ["ground_scorch", rest, "ground_sear"]}), [] as Array[String])


func test_the_game_table_has_no_burning_ground_problems() -> void:
	for kind in CombatTable.ENEMIES:
		assert_eq(CombatTable.area_problems(CombatTable.enemy(kind)), [] as Array[String], kind)
