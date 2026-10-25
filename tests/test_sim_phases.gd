## Fight phases: below a mark on its health an enemy changes into a quicker cycle. Only the
## Frostbound knight has a phase so far (its own fight is in tests/test_ring_three.gd), so the
## stand-in phaser in tests/sim_helpers.gd carries the rule: it winds up a tick before its
## crush, below half health it crushes with no wind-up, and below 45 % it draws a bow. A phase
## starts on the first declaration from the cycle after the mark is crossed, announced by a
## stance, never between a wind-up and its blow, and lasts the rest of that life.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one with nobody else in the arena, and a metre north of it: inside the
## phaser's sight and its club's reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## The player is topped up below this, so a fight runs as long as a test needs.
const TOP_UP := 50


## A player standing beside a lone phaser, before either has acted, not fighting back.
func _phaser() -> Sim:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": "stand_in_phaser", "home": HOME}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
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


## Steps until the foe declares `action`, at most `max_ticks` ticks.
func _until_declared(sim: Sim, action: String, max_ticks := 20) -> bool:
	for i in max_ticks:
		if _declared(_run(sim, 1)).any(func(e: Dictionary) -> bool: return e["action"] == action):
			return true
	return false


## How many of the foe's blows landed (hit or missed) on `tick` among `events`.
func _landed(events: Array[Dictionary], tick: int) -> int:
	var blows := H.where(events, Vocab.EV_HIT, "attacker", "foe") + H.where(events, Vocab.EV_MISSED, "attacker", "foe")
	return blows.filter(func(e: Dictionary) -> bool: return int(e["tick"]) == tick).size()


func _phase(sim: Sim) -> int:
	return int(sim.state["enemies"]["foe"]["phase"])


func test_only_the_frostbound_knight_has_a_phase_so_far() -> void:
	for kind in CombatTable.ENEMIES:
		assert_eq(CombatTable.phase_count(kind), 1 if kind == "frostbound_knight" else 0, "%s's phases" % kind)
		assert_eq(CombatTable.cycle(kind), CombatTable.ENEMIES[kind]["actions"], "%s keeps its own cycle" % kind)
	H.add_stand_ins()
	assert_eq(CombatTable.phase_count("stand_in_phaser"), 2)
	assert_eq(CombatTable.phase_problems(H.STAND_IN_KINDS["stand_in_phaser"]), [] as Array[String])
	assert_eq(CombatTable.cycle("stand_in_phaser", 1)[0], "quicken")
	assert_eq(CombatTable.stance_weapon("stand_in_phaser", 0, 1), "troll_club", "a phase with no stances holds the kind's weapon")
	assert_eq(CombatTable.stance_weapon("stand_in_phaser", 0, 2), "captain_bow")


func test_every_kind_has_well_shaped_phases() -> void:
	H.add_stand_ins()
	for kind in CombatTable.ENEMIES.keys() + H.STAND_IN_KINDS.keys():
		assert_eq(CombatTable.phase_problems(CombatTable.enemy(kind)), [] as Array[String], "%s's phases" % kind)


func test_the_shape_check_refuses_a_phase_that_is_not_announced_or_has_a_bad_mark() -> void:
	var good := {"below": 50, "actions": ["wind_up", "crush"]}
	assert_eq(CombatTable.phase_problems({"phases": [good]}), [] as Array[String])
	var unannounced := {"below": 50, "actions": ["crush", "wind_up"]}
	assert_eq(CombatTable.phase_problems({"phases": [unannounced]}).size(), 1, "a phase must begin with a stance")
	assert_eq(CombatTable.phase_problems({"phases": [{"below": 50, "actions": []}]}).size(), 1, "an empty cycle")
	for below: Variant in [0, 100, -5, 150, 50.5, "50", null]:
		var bad := {"below": below, "actions": ["wind_up", "crush"]}
		assert_eq(CombatTable.phase_problems({"phases": [bad]}).size(), 1, "below %s is refused" % [below])
	for below in [1, 99]:
		assert_eq(CombatTable.phase_problems({"phases": [{"below": below, "actions": ["draw_bow"]}]}), [] as Array[String], "below %d is allowed" % below)
	var deeper := {"below": 25, "actions": ["draw_bow"]}
	assert_eq(CombatTable.phase_problems({"phases": [good, deeper]}), [] as Array[String])
	assert_eq(CombatTable.phase_problems({"phases": [deeper, good]}).size(), 1, "a later phase has a lower mark")
	var odd := {"below": 50, "actions": ["draw_bow", "loose"], "stances": ["captain_bow"]}
	assert_eq(CombatTable.phase_problems({"phases": [odd]}).size(), 1, "one stance per action")


func test_the_crush_is_seen_two_ticks_out_above_the_mark_and_one_below() -> void:
	var sim := _phaser()
	var above := _run(sim, 14)
	H.patch_enemy(sim, "foe", {"health": 48})
	var below := _run(sim, 14)
	assert_eq(_phase(sim), 1, "below half health it fights in its first phase")
	for part: Array[Dictionary] in [above, below]:
		var last := int(part[part.size() - 1]["tick"])
		var crushes := _declared(part).filter(func(e: Dictionary) -> bool: return e["action"] == "crush" and int(e["at"]) <= last)
		assert_true(crushes.size() >= 2, "it crushed in the fight (%d)" % crushes.size())
		var warning := 2 if part == above else 1
		for crush in crushes:
			var t := int(crush["at"])
			assert_eq(_landed(part, t), 1, "the crush told for tick %d landed then" % t)
			var before := _declared(part).filter(func(e: Dictionary) -> bool: return int(e["tick"]) == t - 2)
			var wound_up: bool = before.size() == 1 and before[0]["action"] == "wind_up"
			assert_eq(2 if wound_up else 1, warning, "the crush on tick %d is first seen %d ticks out" % [t, warning])


func test_a_blow_below_the_mark_starts_the_phase_on_the_next_declaration() -> void:
	var sim := _phaser()
	H.patch_enemy(sim, "foe", {"health": 55})
	H.arm(sim, "iron_sword")
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "foe"})["ok"])
	var events: Array[Dictionary] = []
	for i in 10:
		events.append_array(_run(sim, 1))
		if int(sim.state["enemies"]["foe"]["health"]) < 50:
			break
	# One blow took it below half health; the player stops there.
	H.place(sim, sim.state["player"]["pos"])
	assert_eq(int(sim.state["enemies"]["foe"]["health"]) >= 45, true, "one blow, above the second mark")
	var blow := events.size() - 1
	while blow >= 0 and not (events[blow]["kind"] == Vocab.EV_HIT and events[blow]["attacker"] == Vocab.PLAYER):
		blow -= 1
	assert_true(blow >= 0, "the player struck")
	events.append_array(_run(sim, 3))
	var after := _declared(events.slice(blow + 1))
	assert_true(after.size() >= 2)
	if after.size() < 2:
		return
	assert_eq(after[0]["kind"], Vocab.EV_ENEMY_STANCE, "the phase is announced with a stance")
	assert_eq(after[0]["action"], "quicken", "its first action is the phase's first")
	assert_eq(after[0]["at"], int(after[0]["tick"]) + 1, "a tick ahead")
	assert_eq(after[1]["action"], "smash", "then the phase's cycle runs on")
	assert_eq(_phase(sim), 1)


func test_a_blow_declared_before_the_mark_still_lands_as_declared() -> void:
	var sim := _phaser()
	assert_true(_until_declared(sim, "smash"), "it lines up a smash")
	H.patch_enemy(sim, "foe", {"health": 48})
	var events := _run(sim, 1)
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", "foe").size(), 1, "the smash lands")
	assert_eq(_declared(events).map(func(e: Dictionary) -> String: return e["action"]), ["quicken"], "then the phase starts")


func test_a_wind_up_commits_its_crush_before_the_phase_starts() -> void:
	var sim := _phaser()
	assert_true(_until_declared(sim, "wind_up"), "it winds up")
	H.patch_enemy(sim, "foe", {"health": 48})
	var events := _run(sim, 2)
	var declared := _declared(events).map(func(e: Dictionary) -> String: return e["action"])
	assert_eq(declared, ["crush", "quicken"], "the wound-up crush, then the phase")
	assert_eq(_landed(events, int(sim.state["tick"])), 1, "the crush lands as declared")
	assert_eq(_landed(events, int(sim.state["tick"]) - 1), 0, "after the wind-up, which strikes nothing")
	assert_eq(_phase(sim), 1)


func test_one_blow_across_both_marks_starts_the_deeper_phase() -> void:
	var sim := _phaser()
	H.patch_enemy(sim, "foe", {"health": 50})
	H.arm(sim, "iron_sword")
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "foe"})["ok"])
	var events: Array[Dictionary] = []
	for i in 10:
		events.append_array(_run(sim, 1))
		if int(sim.state["enemies"]["foe"]["health"]) < 50:
			break
	H.place(sim, sim.state["player"]["pos"])
	assert_true(int(sim.state["enemies"]["foe"]["health"]) < 45, "one blow took it past both marks")
	var blows := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(blows.size(), 1, "in one blow")
	events.append_array(_run(sim, 2))
	var after := _declared(events.slice(events.find(blows[0]) + 1))
	assert_eq(after[0]["action"], "draw_bow", "the deeper phase starts")
	assert_eq(_phase(sim), 2)
	assert_eq(sim.combatant("foe")["style"], CombatTable.STYLE_RANGED)


func test_a_phase_is_never_left_for_a_shallower_one() -> void:
	var sim := _phaser()
	H.patch_enemy(sim, "foe", {"health": 40, "phase": 2, "step": 1})
	H.patch_enemy(sim, "foe", {"health": 48})
	_run(sim, 6)
	assert_eq(_phase(sim), 2, "a phase is entered at most once a life")


func test_the_phase_is_cleared_at_respawn() -> void:
	var sim := _phaser()
	H.patch_enemy(sim, "foe", {"health": 1, "phase": 2, "step": 1})
	H.arm(sim, "iron_sword")
	sim.command(Vocab.ATTACK, {"enemy_id": "foe"})
	var events := _run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "foe").size(), 1, "it dies")
	for i in int(H.STAND_IN_KINDS["stand_in_phaser"]["respawn_ticks"]) + 1:
		if H.where(_run(sim, 1), Vocab.EV_ENEMY_RESPAWNED, "enemy_id", "foe").size() > 0:
			break
	assert_eq(sim.state["enemies"]["foe"]["mode"], Sim.MODE_IDLE, "it comes back")
	assert_eq(_phase(sim), 0, "on its own cycle")
	assert_eq(int(sim.state["enemies"]["foe"]["step"]), 0)


func test_the_phase_is_cleared_when_it_walks_home_and_heals() -> void:
	var sim := _phaser()
	_run(sim, 2)
	H.patch_enemy(sim, "foe", {"health": 40, "phase": 2, "step": 3})
	H.walk_to(sim, H.INSIDE_COLD_CORNER)
	_run(sim, 20)
	var foe: Dictionary = sim.state["enemies"]["foe"]
	assert_eq(foe["mode"], Sim.MODE_IDLE, "it walked home")
	assert_eq(int(foe["health"]), 100, "and healed")
	assert_eq(_phase(sim), 0, "on its own cycle again")
	assert_eq(int(foe["step"]), 0)


func test_a_save_taken_mid_phase_carries_on_in_that_phase() -> void:
	var sim := _phaser()
	H.patch_enemy(sim, "foe", {"health": 48})
	_run(sim, 3)
	assert_eq(_phase(sim), 1)
	var snap := sim.snapshot()
	var restored := H.arena({"foe": {"kind": "stand_in_phaser", "home": HOME}})
	assert_true(restored.restore(snap))
	var imported := H.arena({"foe": {"kind": "stand_in_phaser", "home": HOME}})
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	var ahead := _run(sim, 8)
	for copy: Sim in [restored, imported]:
		copy.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
		copy.drain_events()
		assert_eq(copy.state["enemies"]["foe"]["phase"], 1, "the same phase")
		assert_eq(copy.state["enemies"]["foe"]["step"], snap["enemies"]["foe"]["step"], "at the same step")
		assert_eq(_declared(_run(copy, 8)), _declared(ahead), "and fights on exactly as the original")


func test_restore_puts_a_missing_or_unknown_phase_back_to_the_kinds_own_cycle() -> void:
	var sim := _phaser()
	for phase: Variant in [null, -1, 3, 9, "two"]:
		var snap := sim.snapshot()
		snap["enemies"]["foe"]["step"] = 2
		if phase == null:
			snap["enemies"]["foe"].erase("phase")
		else:
			snap["enemies"]["foe"]["phase"] = phase
		assert_true(sim.restore(snap))
		assert_eq(_phase(sim), 0, "phase %s loads as 0" % [phase])
		assert_eq(int(sim.state["enemies"]["foe"]["step"]), 2, "and keeps its step")
	var deep := sim.snapshot()
	deep["enemies"]["foe"]["phase"] = 2.0
	deep["enemies"]["foe"]["step"] = 7
	assert_true(sim.restore(deep))
	assert_eq(_phase(sim), 2, "a phase it has is kept")
	assert_eq(int(sim.state["enemies"]["foe"]["step"]), 2, "its step wraps on that phase's cycle")
