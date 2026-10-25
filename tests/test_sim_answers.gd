## Answers: an enemy the player has just countered switches style in reply, early, instead of at
## its place in the cycle, announced a tick ahead like any change of weapon, and cannot switch in
## reply again for `answer_ticks`. That gap is the player's opening. No enemy answers yet, so the
## stand-in answerers in tests/sim_helpers.gd carry the rule: the answerer fights through sabre,
## bow and staff and answers a staff with its bow and a blade with its staff; the late answerer
## answers the same way, but only in its second phase.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one with nobody else in the arena, and a metre north of it: inside the
## answerer's sight and its sabre's reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## The player is topped up below this, so a fight runs as long as a test needs.
const TOP_UP := 50
## A sword in hand, and a bow and a staff in the pack to swap to.
const KIT := [
	{"item": "iron_bow", "count": 1}, {"item": "iron_staff", "count": 1},
	{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100},
]
const ANSWER_TICKS := 8


## A player with a sword standing beside a lone `kind`, which has noticed them and declared its
## first action, not fighting back.
func _beside(kind := "stand_in_answerer") -> Sim:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": kind, "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	H.arm(sim, "iron_sword", KIT)
	_run(sim, 1)
	sim.drain_events()
	return sim


## Steps `ticks` ticks like H.run_stamped, topping the player's health and warmth up as it goes.
func _run(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		if int(sim.state["health"]) < TOP_UP or int(sim.state["warmth"]) < TOP_UP:
			H.patch(sim, {"health": Sim.HEALTH_MAX, "warmth": Sim.WARMTH_MAX})
		events.append_array(H.run_stamped(sim, 1))
	return events


## The foe's declarations (stances and telegraphs) among `events`, in order.
func _declared(events: Array[Dictionary]) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool:
		return e.get("enemy_id") == "foe" and e["kind"] in [Vocab.EV_ENEMY_STANCE, Vocab.EV_ENEMY_TELEGRAPHED])


func _actions(events: Array[Dictionary]) -> Array:
	return _declared(events).map(func(e: Dictionary) -> String: return e["action"])


## Asks for the weapon of `style` from the pack; it is in hand from the next tick.
func _swap_to(sim: Sim, style: String) -> void:
	if sim.player_style() == style:
		return
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and ItemTable.ITEMS[pack[i]["item"]].get("style", "") == style:
			assert_true(sim.command(Vocab.EQUIP, {"index": i})["ok"], "equip the %s weapon" % style)
			return
	assert_true(false, "a %s weapon in the pack" % style)


func _answered(sim: Sim) -> int:
	return int(sim.state["enemies"]["foe"]["answered_tick"])


func _foe_style(sim: Sim) -> String:
	return sim.combatant("foe")["style"]


## Whether the player's style has the edge on the foe's where they stand.
func _player_has_edge(sim: Sim) -> bool:
	var distance := sim.player_pos().distance_to(sim.combatant("foe")["pos"])
	return CombatTable.multiplier(sim.player_style(), _foe_style(sim), distance) > 1.0


func test_only_the_aurora_seer_answers_yet() -> void:
	for kind in CombatTable.ENEMIES:
		for phase in CombatTable.phase_count(kind) + 1:
			var answers := {"ranged": 5, "magic": 10} if kind == "aurora_seer" else {}
			assert_eq(CombatTable.answers(kind, phase), answers, "%s's answers" % kind)
	H.add_stand_ins()
	assert_eq(CombatTable.answers("stand_in_answerer"), {"magic": 5, "melee": 10})
	assert_eq(CombatTable.answer_ticks("stand_in_answerer"), ANSWER_TICKS)
	assert_eq(CombatTable.answers("stand_in_late_answerer"), {}, "the late answerer answers nothing on its own cycle")
	assert_eq(CombatTable.answers("stand_in_late_answerer", 1), {"magic": 3, "melee": 6})


func test_the_captain_keeps_his_cycle_whatever_the_player_swaps_to() -> void:
	var sim := H.arena({"foe": {"kind": "bandit_captain", "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	H.arm(sim, "iron_sword", KIT)
	var styles := [CombatTable.STYLE_MAGIC, CombatTable.STYLE_RANGED, CombatTable.STYLE_MELEE]
	var events: Array[Dictionary] = []
	for i in 45:
		_swap_to(sim, styles[i % 3])
		events.append_array(_run(sim, 1))
	# A rest is not declared aloud; everything else in his cycle is, in order, three times over.
	var cycle: Array = (CombatTable.ENEMIES["bandit_captain"]["actions"] as Array).filter(func(a: String) -> bool:
		return CombatTable.is_attack(a) or CombatTable.is_stance(a))
	var declared := _actions(events)
	assert_eq(declared, cycle + cycle + cycle, "he works through his cycle as ever")
	assert_eq(_answered(sim), -1, "he never answered")


func test_every_kind_has_well_shaped_answers() -> void:
	H.add_stand_ins()
	for kind in CombatTable.ENEMIES.keys() + H.STAND_IN_KINDS.keys():
		assert_eq(CombatTable.answer_problems(CombatTable.enemy(kind)), [] as Array[String], "%s's answers" % kind)


func test_the_shape_check_refuses_an_answer_that_is_not_a_stance_in_its_cycle() -> void:
	var actions := ["slash", "draw_bow", "loose", "draw_sabre"]
	var good := {"actions": actions, "answers": {"magic": 1, "ranged": 3}, "answer_ticks": 8}
	assert_eq(CombatTable.answer_problems(good), [] as Array[String])
	assert_eq(CombatTable.answer_problems({"actions": actions}), [] as Array[String], "no answers at all")
	for index: Variant in [0, 2, 4, -1, 1.0, "1", null]:
		var bad := {"actions": actions, "answers": {"magic": index}, "answer_ticks": 8}
		assert_eq(CombatTable.answer_problems(bad).size(), 1, "an answer at %s is refused" % [index])
	assert_eq(CombatTable.answer_problems({"actions": actions, "answers": {"fire": 1}, "answer_ticks": 8}).size(), 1, "an unknown style")
	for ticks: Variant in [null, 0, -3, 8.5, "8"]:
		var bad := {"actions": actions, "answers": {"magic": 1}}
		if ticks != null:
			bad["answer_ticks"] = ticks
		assert_eq(CombatTable.answer_problems(bad).size(), 1, "answer_ticks %s is refused" % [ticks])
	var phased := {"actions": ["slash"], "phases": [{"below": 50, "actions": ["draw_bow", "loose"], "answers": {"magic": 1}, "answer_ticks": 8}]}
	assert_eq(CombatTable.answer_problems(phased).size(), 1, "a phase's answer is checked against the phase's cycle")
	phased["phases"][0]["answers"] = {"magic": 0}
	assert_eq(CombatTable.answer_problems(phased), [] as Array[String])


func test_a_counter_swap_is_answered_on_the_next_declaration() -> void:
	var sim := _beside()
	assert_eq(_foe_style(sim), CombatTable.STYLE_MELEE, "it holds its sabre")
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	var events := _run(sim, 1)
	var tick := int(sim.state["tick"])
	var declared := _declared(events)
	assert_eq(declared.size(), 1)
	assert_eq(declared[0]["kind"], Vocab.EV_ENEMY_STANCE, "the answer is announced with a stance")
	assert_eq(declared[0]["action"], "draw_bow", "it draws the bow that beats a staff")
	assert_eq(declared[0]["style"], CombatTable.STYLE_RANGED, "in the bow's colour")
	assert_eq(int(declared[0]["at"]), tick + 1, "a tick ahead")
	assert_eq(_answered(sim), tick + 1, "the answer is recorded for the tick it lands")
	var landing := _run(sim, 1)
	assert_eq(_foe_style(sim), CombatTable.STYLE_RANGED, "from the tick it lands, it holds the bow")
	assert_eq(_actions(landing), ["loose"], "and its cycle carries on from the answer")


func test_no_second_answer_comes_inside_the_cooldown_whatever_the_player_swaps_to() -> void:
	var sim := _beside()
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	_run(sim, 1)
	var first := _answered(sim)
	assert_true(first > 0, "it answered")
	var styles := [CombatTable.STYLE_MELEE, CombatTable.STYLE_RANGED, CombatTable.STYLE_MAGIC]
	var t := 0
	# Each tick's declaration is for the tick after it, so the cooldown holds while that is
	# fewer than ANSWER_TICKS after the first answer.
	while int(sim.state["tick"]) + 2 < first + ANSWER_TICKS:
		_swap_to(sim, styles[t % 3])
		_run(sim, 1)
		assert_eq(_answered(sim), first, "no answer on tick %d, inside the cooldown" % sim.state["tick"])
		t += 1
	assert_true(t >= ANSWER_TICKS - 2, "the player swapped through the cooldown (%d ticks)" % t)
	var again := -1
	for i in 30:
		for style in CombatTable.answers("stand_in_answerer"):
			if _counters(sim, style):
				_swap_to(sim, style)
				break
		_run(sim, 1)
		if _answered(sim) != first:
			again = _answered(sim)
			break
	assert_true(again >= first + ANSWER_TICKS, "once the cooldown has passed, a counter is answered again (on %d)" % again)


## Whether swapping to `style` now would counter the foe: an edge on its style, with an answer
## that changes its weapon.
func _counters(sim: Sim, style: String) -> bool:
	var foe := sim.combatant("foe")
	var distance := sim.player_pos().distance_to(foe["pos"])
	var index := int(CombatTable.answers("stand_in_answerer")[style])
	return CombatTable.multiplier(style, foe["style"], distance) > 1.0 and CombatTable.stance_weapon("stand_in_answerer", index) != foe["weapon"]


func test_the_bait_opens_a_window_with_the_edge_and_no_answer() -> void:
	var sim := _beside()
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	_run(sim, 1)
	var answered := _answered(sim)
	_run(sim, 1)
	assert_eq(_foe_style(sim), CombatTable.STYLE_RANGED, "it answered the staff with its bow")
	_swap_to(sim, CombatTable.STYLE_MELEE)
	var opening := 0
	for i in ANSWER_TICKS:
		_run(sim, 1)
		var tick := int(sim.state["tick"])
		if _player_has_edge(sim) and tick + 1 - answered < ANSWER_TICKS:
			opening += 1
			assert_eq(_answered(sim), answered, "tick %d: the blade has the edge and no answer comes" % tick)
	assert_true(opening >= 1, "the player held the edge with no answer coming for %d ticks" % opening)


func test_no_answer_comes_straight_after_a_wind_up() -> void:
	var sim := _beside()
	var wound := false
	for i in 20:
		if _actions(_run(sim, 1)) == ["wind_up"]:
			wound = true
			break
	assert_true(wound, "it winds up")
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	var events := _run(sim, 2)
	assert_eq(_actions(events), ["cleave", "draw_bow"], "the committed cleave, then the answer")
	assert_eq(_answered(sim), int(sim.state["tick"]) + 1)


func test_a_swap_without_the_edge_or_without_an_answer_sets_off_nothing() -> void:
	var sim := _beside()
	# A sword on its sabre is even; a bow up close walks into the sabre's edge.
	for style in [CombatTable.STYLE_MELEE, CombatTable.STYLE_RANGED]:
		_swap_to(sim, style)
		_run(sim, 1)
		assert_false(_player_has_edge(sim), "%s has no edge on the sabre up close" % style)
		assert_eq(_answered(sim), -1, "a swap to %s is not answered" % style)
	# A bow has the edge on its staff, but it has no answer to a bow.
	var staff := _beside()
	H.patch_enemy(staff, "foe", {"step": 11})
	assert_eq(_foe_style(staff), CombatTable.STYLE_MAGIC, "it holds its staff")
	_swap_to(staff, CombatTable.STYLE_RANGED)
	var events := _run(staff, 1)
	assert_true(_player_has_edge(staff), "the bow has the edge on the staff")
	assert_eq(_actions(events), ["rime_bolt"], "it carries on with its cycle")
	assert_eq(_answered(staff), -1, "a style it has no answer for is not answered")


func test_the_cooldown_is_cleared_at_respawn() -> void:
	var sim := _beside()
	H.patch_enemy(sim, "foe", {"health": 1, "answered_tick": int(sim.state["tick"])})
	sim.command(Vocab.ATTACK, {"enemy_id": "foe"})
	var events := _run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "foe").size(), 1, "it dies")
	for i in int(H.STAND_IN_KINDS["stand_in_answerer"]["respawn_ticks"]) + 1:
		if H.where(_run(sim, 1), Vocab.EV_ENEMY_RESPAWNED, "enemy_id", "foe").size() > 0:
			break
	assert_eq(sim.state["enemies"]["foe"]["mode"], Sim.MODE_IDLE, "it comes back")
	assert_eq(_answered(sim), -1, "with no answer behind it")


func test_the_cooldown_is_cleared_when_it_walks_home_and_heals() -> void:
	var sim := _beside()
	H.patch_enemy(sim, "foe", {"health": 400, "answered_tick": int(sim.state["tick"])})
	H.walk_to(sim, H.INSIDE_COLD_CORNER)
	_run(sim, 20)
	var foe: Dictionary = sim.state["enemies"]["foe"]
	assert_eq(foe["mode"], Sim.MODE_IDLE, "it walked home")
	assert_eq(int(foe["health"]), 500, "and healed")
	assert_eq(_answered(sim), -1, "with no answer behind it")


func test_a_save_taken_inside_the_cooldown_keeps_it() -> void:
	var sim := _beside()
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	_run(sim, 3)
	var answered := _answered(sim)
	assert_true(answered > 0, "it answered")
	var snap := sim.snapshot()
	var restored := H.arena({"foe": {"kind": "stand_in_answerer", "home": HOME}})
	assert_true(restored.restore(snap))
	var imported := H.arena({"foe": {"kind": "stand_in_answerer", "home": HOME}})
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	var ahead := _bait(sim)
	for copy: Sim in [restored, imported]:
		copy.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
		copy.drain_events()
		assert_eq(_answered(copy), answered, "the same last answer")
		assert_eq(_declared(_bait(copy)), _declared(ahead), "and the same cooldown: it fights on exactly as the original")


## Swaps to the blade, which has the edge on the bow, and fights on past the cooldown.
func _bait(sim: Sim) -> Array[Dictionary]:
	_swap_to(sim, CombatTable.STYLE_MELEE)
	return _run(sim, ANSWER_TICKS + 4)


func test_restore_puts_a_missing_or_bad_answer_tick_back_to_none() -> void:
	var sim := _beside()
	for answered: Variant in [null, -5, "seven", [3]]:
		var snap := sim.snapshot()
		if answered == null:
			snap["enemies"]["foe"].erase("answered_tick")
		else:
			snap["enemies"]["foe"]["answered_tick"] = answered
		assert_true(sim.restore(snap))
		assert_eq(_answered(sim), -1, "answered_tick %s loads as -1" % [answered])
	var snap := sim.snapshot()
	snap["enemies"]["foe"]["answered_tick"] = 3.0
	assert_true(sim.restore(snap))
	assert_eq(_answered(sim), 3, "a tick it has is kept")


func test_a_phased_kind_answers_with_its_current_phases_answers() -> void:
	var sim := _beside("stand_in_late_answerer")
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	var before := _run(sim, 4)
	assert_true(_player_has_edge(sim), "the staff has the edge on its sabre")
	assert_eq(_answered(sim), -1, "on its own cycle it has no answer")
	assert_false(_actions(before).has("draw_bow"))
	_swap_to(sim, CombatTable.STYLE_MELEE)
	H.patch_enemy(sim, "foe", {"health": 48})
	var opening := _run(sim, 2)
	assert_eq(int(sim.state["enemies"]["foe"]["phase"]), 1, "below half health it fights in its second phase")
	assert_true(_actions(opening).has("draw_sabre"), "which opens with its sabre")
	_swap_to(sim, CombatTable.STYLE_MAGIC)
	var events := _run(sim, 1)
	assert_eq(_actions(events), ["draw_bow"], "and there answers the staff with its bow")
	assert_eq(_answered(sim), int(sim.state["tick"]) + 1)
