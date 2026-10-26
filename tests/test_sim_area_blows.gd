## Area blows: a blow that strikes a ground mark rather than the player. No enemy uses one yet,
## so the stand-in smasher (a front mark) and stomper (a ring mark) in tests/sim_helpers.gd
## carry the rule: the mark is told two ticks before it lands, the enemy is rooted until then,
## and the blow hits a player inside the mark and misses one who stepped off it, for the same
## damage whatever style they hold, less their armour.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one (the first archer's spot, with nobody else in the arena), and a
## metre north of it: inside a stand-in's sight and its fangs' reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## The tick the first mark is told on (the enemy notices on the first tick), and the tick it lands.
const TOLD := 1
const LANDS := 3


## A player standing beside a lone stand-in of `kind`, with the first tick stepped: the enemy
## has noticed and told its first mark, an area blow landing on tick LANDS.
func _marked(kind := "stand_in_smasher", weapon := "") -> Sim:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": kind, "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	H.arm(sim, weapon)
	sim.drain_events()
	sim.step()
	return sim


## The events of stepping on to the landing tick from `sim`, which has just told its mark.
func _to_landing(sim: Sim) -> Array[Dictionary]:
	return H.run_stamped(sim, LANDS - int(sim.state["tick"]))


func _blows(events: Array[Dictionary], kind: String) -> Array[Dictionary]:
	return H.where(events, kind, "attacker", "foe")


func test_the_ground_mark_is_told_two_ticks_ahead_with_its_shape_and_geometry() -> void:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": "stand_in_smasher", "home": HOME}})
	H.place(sim, BESIDE)
	sim.drain_events()
	var events := H.run_stamped(sim, 1)
	var marked := H.where(events, Vocab.EV_GROUND_MARKED, "enemy_id", "foe")
	assert_eq(marked.size(), 1, "the smash is told as a ground mark")
	assert_eq(H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "foe").size(), 0, "and not as a telegraph")
	if marked.size() != 1:
		return
	var e := marked[0]
	assert_eq(e["tick"], TOLD)
	assert_eq(e["at"], TOLD + CombatTable.MARK_TICKS, "it lands two ticks later")
	assert_eq(CombatTable.MARK_TICKS, 2)
	assert_eq(e["action"], "ground_smash")
	assert_eq(e["mark"]["shape"], CombatTable.MARK_FRONT)
	assert_eq(e["mark"]["centre"], HOME, "centred on the smasher")
	assert_almost_eq(float(e["mark"]["radius"]), 3.0)
	assert_eq(e["mark"]["facing"], [0.0, -1.0], "facing the player, to the north")
	assert_almost_eq(float(e["mark"]["arc"]), CombatTable.FRONT_ARC)
	assert_eq(sim.combatant("foe")["next"]["at"], LANDS)


func test_a_ring_mark_is_a_circle_round_the_enemy() -> void:
	var sim := _marked("stand_in_stomper")
	var mark: Dictionary = sim.state["enemies"]["foe"]["next"]["mark"]
	assert_eq(mark["shape"], CombatTable.MARK_RING)
	assert_eq(mark["centre"], HOME)
	assert_false(mark.has("facing"), "a ring faces nowhere")


func test_a_front_mark_hits_a_player_who_stays_inside_its_arc() -> void:
	var sim := _marked()
	var events := _to_landing(sim)
	var hits := _blows(events, Vocab.EV_HIT)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_eq(hits[0]["tick"], LANDS, "on the landing tick")
		assert_true(hits[0].get("area", false), "marked as an area blow")
		assert_eq(hits[0]["amount"], 20)
	assert_eq(_blows(events, Vocab.EV_MISSED).size(), 0)
	assert_eq(sim.state["health"], Sim.HEALTH_MAX - 20)


func test_a_front_mark_misses_a_player_who_steps_to_the_side_or_behind() -> void:
	# East of the smasher, inside the mark's radius but square to its side; and south of it, behind.
	for spot: Array in [[17.0, 28.5], [14.5, 30.0]]:
		var sim := _marked()
		sim.command(Vocab.MOVE_TO, {"pos": spot})
		var events := _to_landing(sim)
		var pos := sim.player_pos()
		assert_true(pos.distance_to(Vector2(HOME[0], HOME[1])) <= 3.0, "%s: still inside the radius" % [spot])
		var missed := _blows(events, Vocab.EV_MISSED)
		assert_eq(missed.size(), 1, "%s: the smash misses" % [spot])
		if missed.size() == 1:
			assert_eq(missed[0]["tick"], LANDS)
			assert_true(missed[0].get("area", false), "marked as an area blow")
			assert_eq(missed[0]["action"], "ground_smash")
		assert_eq(_blows(events, Vocab.EV_HIT).size(), 0)
		assert_eq(sim.state["health"], Sim.HEALTH_MAX)


func test_a_ring_mark_hits_inside_its_circle_and_misses_a_player_who_backs_out() -> void:
	var stayed := _marked("stand_in_stomper")
	var hits := _blows(_to_landing(stayed), Vocab.EV_HIT)
	assert_eq(hits.size(), 1, "standing still is inside the ring")
	if hits.size() == 1:
		assert_true(hits[0].get("area", false))
		assert_eq(hits[0]["amount"], 16)
	# To the side, and behind: a ring has no blind side.
	for spot: Array in [[16.5, 28.5], [14.5, 30.0]]:
		var sim := _marked("stand_in_stomper")
		sim.command(Vocab.MOVE_TO, {"pos": spot})
		assert_eq(_blows(_to_landing(sim), Vocab.EV_HIT).size(), 1, "%s is inside the ring" % [spot])
	var backed := _marked("stand_in_stomper")
	backed.command(Vocab.MOVE_TO, {"pos": [14.5, 24.5]})
	var events := _to_landing(backed)
	assert_true(backed.player_pos().distance_to(Vector2(HOME[0], HOME[1])) > 3.0, "out of the ring")
	assert_eq(_blows(events, Vocab.EV_HIT).size(), 0)
	var missed := _blows(events, Vocab.EV_MISSED)
	assert_eq(missed.size(), 1, "the stomp misses")
	if missed.size() == 1:
		assert_true(missed[0].get("area", false))


func test_the_enemy_is_rooted_from_the_mark_until_it_lands() -> void:
	var sim := _marked()
	var told: Dictionary = sim.snapshot()["enemies"]["foe"]
	# Round behind it and out of its reach, where it would turn and close in on any other tick.
	sim.command(Vocab.MOVE_TO, {"pos": [14.5, 31.5]})
	for tick in range(TOLD + 1, LANDS + 1):
		var events := H.run_stamped(sim, 1)
		var e: Dictionary = sim.snapshot()["enemies"]["foe"]
		assert_eq(H.where(events, Vocab.EV_ENEMY_MOVED, "enemy_id", "foe").size(), 0, "tick %d: it does not move" % tick)
		assert_eq(e["pos"], told["pos"], "tick %d: it stands where it told the mark" % tick)
		assert_eq(e["facing"], told["facing"], "tick %d: it does not turn" % tick)
	var moved := H.where(H.run_stamped(sim, 1), Vocab.EV_ENEMY_MOVED, "enemy_id", "foe")
	assert_eq(moved.size(), 1, "once the blow has landed it closes in again")


func test_no_phase_change_comes_between_the_mark_and_its_blow() -> void:
	var sim := _marked("stand_in_area_phaser")
	H.patch_enemy(sim, "foe", {"health": 40})
	var events := H.run_stamped(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe").size(), 0, "nothing on the rooted tick")
	assert_eq(sim.state["enemies"]["foe"]["phase"], 0)
	events = H.run_stamped(sim, 1)
	assert_eq(_blows(events, Vocab.EV_HIT).size(), 1, "the smash lands as told")
	var stances := H.where(events, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe")
	assert_eq(stances.size(), 1, "and only then does the phase start")
	if stances.size() == 1:
		assert_eq(stances[0]["action"], "quicken")
		assert_eq(stances[0]["at"], LANDS + 1)


func test_no_answer_comes_between_the_mark_and_its_blow() -> void:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": "stand_in_area_answerer", "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	H.arm(sim, "iron_sword", [{"item": "iron_staff", "count": 1}, {"item": "frost_shards", "count": 50}])
	sim.drain_events()
	var events := H.run_stamped(sim, 1)
	assert_eq(H.where(events, Vocab.EV_GROUND_MARKED, "enemy_id", "foe").size(), 1, "a sword draws no answer")
	# The staff has the edge on its sabre from the rooted tick on.
	sim.command(Vocab.EQUIP, {"index": 0})
	events = H.run_stamped(sim, 1)
	assert_eq(sim.player_style(), CombatTable.STYLE_MAGIC)
	assert_eq(H.where(events, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe").size(), 0, "no answer on the rooted tick")
	events = H.run_stamped(sim, 1)
	assert_eq(_blows(events, Vocab.EV_HIT).size(), 1, "the smash lands as told")
	var stances := H.where(events, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe")
	assert_eq(stances.size(), 1, "and then it answers")
	if stances.size() == 1:
		assert_eq(stances[0]["action"], "draw_bow")


func test_area_damage_is_the_same_whatever_style_the_player_holds() -> void:
	for weapon in ["", "iron_sword", "iron_bow", "iron_staff"]:
		var sim := _marked("stand_in_smasher", weapon)
		var hits := _blows(_to_landing(sim), Vocab.EV_HIT)
		assert_eq(hits.size(), 1, "%s: hit" % weapon)
		if hits.size() == 1:
			assert_eq(hits[0]["amount"], 20, "%s: no edge either way" % weapon)
			assert_almost_eq(float(hits[0]["multiplier"]), 1.0)


func test_armour_cuts_an_area_blow() -> void:
	var sim := _marked()
	var snap := sim.snapshot()
	var worn: Dictionary = snap["inventory"]["equipment"]
	worn["helm"] = "iron_helm"
	worn["body"] = "iron_body"
	worn["legs"] = "iron_legs"
	assert_true(sim.restore(snap))
	var defence := int(sim.combatant(Vocab.PLAYER)["defence"])
	assert_true(defence > 0, "the iron set has defence")
	var hits := _blows(_to_landing(sim), Vocab.EV_HIT)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_eq(hits[0]["amount"], 20 - defence)


func test_the_player_can_strike_a_rooted_enemy() -> void:
	var sim := _marked("stand_in_smasher", "iron_sword")
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "foe"})["ok"])
	var events := H.run_stamped(sim, 1)
	var struck := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(struck.size(), 1, "a blow on the rooted tick")
	if struck.size() == 1:
		assert_eq(struck[0]["target"], "foe")
	assert_true(int(sim.state["enemies"]["foe"]["health"]) < 500)


func test_a_save_taken_mid_mark_lands_the_same_mark_on_the_same_tick() -> void:
	var sim := _marked()
	H.run(sim, 1)
	var snap := sim.snapshot()
	var mark: Dictionary = snap["enemies"]["foe"]["next"]["mark"]
	var restored := H.arena({"foe": {"kind": "stand_in_smasher", "home": HOME}})
	assert_true(restored.restore(snap))
	var imported := H.arena({"foe": {"kind": "stand_in_smasher", "home": HOME}})
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	for copy: Sim in [restored, imported]:
		copy.drain_events()
		var next: Dictionary = copy.state["enemies"]["foe"]["next"]
		assert_eq(next["at"], LANDS, "still landing on the same tick")
		assert_eq(next["mark"], mark, "on the same mark")
		# Off the mark, behind the smasher: the restored mark is where it was, not re-aimed.
		copy.command(Vocab.MOVE_TO, {"pos": [14.5, 30.0]})
		var events := H.run_stamped(copy, 1)
		assert_eq(_blows(events, Vocab.EV_MISSED).size(), 1, "it lands on tick %d" % LANDS)
		assert_eq(int(copy.state["tick"]), LANDS)


func test_an_unreadable_saved_mark_drops_the_blow() -> void:
	var sim := _marked()
	var snap := sim.snapshot()
	snap["enemies"]["foe"]["next"]["mark"] = {"shape": "square", "centre": HOME, "radius": 3.0}
	assert_true(sim.restore(snap))
	assert_eq(sim.state["enemies"]["foe"]["next"], {}, "an area blow is never restored without its mark")


func test_the_combat_table_refuses_a_badly_formed_area_blow() -> void:
	H.add_stand_ins()
	CombatTable.add_stand_ins({}, {
		"feint_smash": {"label": "Smash", "damage": 0, "feint": "ground_smash"},
		"square_smash": {"label": "Smash", "damage": 20, "shape": "square", "size": 3.0},
		"sizeless_smash": {"label": "Smash", "damage": 20, "shape": CombatTable.MARK_RING},
		"flat_smash": {"label": "Smash", "damage": 20, "shape": CombatTable.MARK_FRONT, "size": 0.0},
	})
	var rest := CombatTable.ACTION_REST
	assert_eq(CombatTable.area_problems({"actions": ["ground_smash", rest, "ground_stomp"]}), [] as Array[String])
	for bad in ["feint_smash", "square_smash", "sizeless_smash", "flat_smash"]:
		var problems := CombatTable.area_problems({"actions": [bad, rest]})
		assert_eq(problems.size(), 1, "%s is refused" % bad)
		if problems.size() == 1:
			assert_true(problems[0].begins_with("the kind: %s" % bad), problems[0])
	var phased := CombatTable.area_problems({
		"actions": [rest], "phases": [{"below": 50, "actions": ["quicken", "square_smash"]}],
	})
	assert_eq(phased.size(), 1, "a phase's cycle is checked too")
	if phased.size() == 1:
		assert_true(phased[0].begins_with("phase 1:"), phased[0])


func test_the_game_table_and_the_stand_ins_have_no_area_problems() -> void:
	H.add_stand_ins()
	for kind in CombatTable.ENEMIES.keys() + H.STAND_IN_KINDS.keys():
		assert_eq(CombatTable.area_problems(CombatTable.enemy(kind)), [] as Array[String], "%s's area blows" % kind)
	for action in CombatTable.ACTIONS:
		assert_false(CombatTable.is_area_blow(action), "no game kind strikes a ground mark yet: %s" % action)


func test_in_mark_reads_the_arc_and_the_radius() -> void:
	var front := {"shape": CombatTable.MARK_FRONT, "centre": [0.0, 0.0], "radius": 3.0, "facing": [0.0, 1.0], "arc": 120.0}
	assert_true(CombatTable.in_mark(front, Vector2(0, 2.9)), "straight ahead")
	assert_true(CombatTable.in_mark(front, Vector2(1.0, 1.0)), "45 degrees off")
	assert_false(CombatTable.in_mark(front, Vector2(0, 3.1)), "past the radius")
	assert_false(CombatTable.in_mark(front, Vector2(2.0, 0.0)), "square to the side")
	assert_false(CombatTable.in_mark(front, Vector2(0, -1.0)), "behind")
	var ring := {"shape": CombatTable.MARK_RING, "centre": [1.0, 1.0], "radius": 2.0}
	assert_true(CombatTable.in_mark(ring, Vector2(1.0, -0.9)), "behind is inside a ring")
	assert_false(CombatTable.in_mark(ring, Vector2(3.5, 1.0)))


func test_the_ground_mark_tip_fires_on_the_first_mark_and_never_again() -> void:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": "stand_in_smasher", "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	sim.drain_events()
	assert_true(sim.hints_on())
	var events := H.run_stamped(sim, 1)
	var tips := H.where(events, Vocab.EV_TIP, "tip", "ground_mark")
	assert_eq(tips.size(), 1, "on the first mark")
	assert_eq(GuideTable.tip_text("ground_mark"), "Step off the red.")
	# Long past any cooldown, and through a save.
	events = _stand_in_the_marks(sim, 300)
	assert_true(H.of_kind(events, Vocab.EV_GROUND_MARKED).size() > 10, "it kept smashing")
	var copy := H.arena({"foe": {"kind": "stand_in_smasher", "home": HOME}})
	assert_true(copy.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	copy.drain_events()
	events.append_array(_stand_in_the_marks(copy, 1000))
	assert_true(H.of_kind(events, Vocab.EV_GROUND_MARKED).size() > 100)
	assert_eq(H.where(events, Vocab.EV_TIP, "tip", "ground_mark").size(), 0, "and never again")


## Steps `ticks` ticks with the player standing in every mark, topped up so no blow kills them.
func _stand_in_the_marks(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		if int(sim.state["health"]) < 50:
			H.patch(sim, {"health": Sim.HEALTH_MAX, "warmth": Sim.WARMTH_MAX})
		events.append_array(H.run_stamped(sim, 1))
	return events
