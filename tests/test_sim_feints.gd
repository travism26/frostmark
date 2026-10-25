## Feints: a telegraphed blow that never lands. Only ring three's Snowveil archer, Frostbound knight and Frost tyrant feint so far, so the
## stand-in kinds in tests/sim_helpers.gd carry the rule: a feint is telegraphed exactly as the blow it pretends
## to be, strikes nothing on its tick (no hit, no miss, no noise, no fight back, no broken
## channel), and the enemy's next blow is telegraphed on that tick as usual.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one (the first archer's spot, with nobody else in the arena), and a
## metre north of it: inside a feinter's sight and its lunge's reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## The feints in the table, and the one kind that plays each.
const FEINTS := {
	"feint_pierce": "snowveil_archer", "feint_cleave": "frostbound_knight",
	"feint_volley": "frost_tyrant", "feint_tyrant_cleave": "frost_tyrant", "feint_storm": "frost_tyrant",
}
const WINCH := ["stash_shelves", "forge", "armoury", "ring_two_gate"]


## A player standing at `at` beside a lone stand-in of `kind`, before either has acted.
func _feinter(kind := "stand_in_feinter", at := BESIDE) -> Sim:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": kind, "home": HOME}})
	H.place(sim, at)
	sim.drain_events()
	return sim


func test_only_the_snowveil_archer_the_frostbound_knight_and_the_frost_tyrant_feint_so_far() -> void:
	for action in CombatTable.ACTIONS:
		if FEINTS.has(action):
			continue
		assert_false(CombatTable.is_feint(action), "%s is no feint" % action)
		assert_eq(CombatTable.shown_action(action), action, "%s shows itself" % action)
	for kind in CombatTable.ENEMIES:
		for action in CombatTable.ENEMIES[kind]["actions"]:
			assert_eq(CombatTable.is_feint(action), FEINTS.get(action) == kind, "%s: %s" % [kind, action])
	H.add_stand_ins()
	assert_true(CombatTable.is_feint("feint_lunge"))
	assert_eq(CombatTable.shown_action("feint_lunge"), "lunge", "it shows the blow it pretends to be")
	assert_false(CombatTable.is_attack("feint_lunge"), "and deals nothing itself")


func test_a_feint_is_telegraphed_exactly_as_the_blow_it_pretends_to_be() -> void:
	var sim := _feinter()
	var events := H.run_stamped(sim, 3)
	var told := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "foe")
	var feinted := H.where(events, Vocab.EV_ENEMY_FEINTED, "enemy_id", "foe")
	var hits := H.where(events, Vocab.EV_HIT, "attacker", "foe")
	assert_eq(told.size(), 2, "the feint, then the real lunge")
	assert_eq(feinted.size(), 1)
	assert_eq(hits.size(), 1)
	if told.size() != 2 or feinted.size() != 1 or hits.size() != 1:
		return
	assert_eq(feinted[0]["tick"], told[0]["at"], "the first telegraph was the feint")
	assert_eq(hits[0]["tick"], told[1]["at"], "the second was the real lunge")
	for field in ["action", "style", "damage", "heavy"]:
		assert_eq(told[0][field], told[1][field], "the same %s" % field)
	assert_eq(told[0]["action"], "lunge")
	assert_eq(told[0]["damage"], CombatTable.action_damage("lunge"))
	assert_true(told[0]["heavy"])


func test_next_shows_the_pretended_blow_and_a_save_keeps_the_feint() -> void:
	var sim := _feinter()
	H.run(sim, 1)
	var tick := int(sim.state["tick"])
	assert_eq(sim.combatant("foe")["next"], {"action": "lunge", "at": tick + 1}, "it looks like a lunge")
	var snap := sim.snapshot()
	assert_eq(snap["enemies"]["foe"]["next"]["action"], "feint_lunge", "the saved next is the feint")
	var restored := H.arena({"foe": {"kind": "stand_in_feinter", "home": HOME}})
	assert_true(restored.restore(snap))
	var imported := H.arena({"foe": {"kind": "stand_in_feinter", "home": HOME}})
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	for copy: Sim in [restored, imported]:
		copy.drain_events()
		var events := H.run_stamped(copy, 1)
		assert_eq(H.where(events, Vocab.EV_ENEMY_FEINTED, "enemy_id", "foe").size(), 1, "it still feints")
		assert_eq(H.where(events, Vocab.EV_HIT, "attacker", "foe").size(), 0)


func test_the_feint_tick_strikes_nothing() -> void:
	var sim := _feinter()
	H.run(sim, 1)
	var before := sim.snapshot()
	var events := H.run_stamped(sim, 1)
	var tick := int(sim.state["tick"])
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", "foe").size(), 0, "no hit")
	assert_eq(H.where(events, Vocab.EV_MISSED, "attacker", "foe").size(), 0, "and no miss")
	assert_eq(H.of_kind(events, Vocab.EV_TOOK_DAMAGE).size(), 0)
	assert_eq(sim.state["health"], before["health"], "the player's health is untouched")
	assert_eq(sim.snapshot()["skills"], before["skills"], "nobody learnt anything")
	var feinted := H.where(events, Vocab.EV_ENEMY_FEINTED, "enemy_id", "foe")
	assert_eq(feinted.size(), 1)
	if feinted.size() == 1:
		assert_eq(feinted[0]["action"], "lunge", "it names the blow it pretended to be")
		assert_eq(feinted[0]["style"], CombatTable.STYLE_MELEE)
		assert_eq(feinted[0]["at"], tick)


func test_the_blow_after_a_feint_is_telegraphed_on_the_feint_tick() -> void:
	var sim := _feinter()
	H.run(sim, 1)
	var events := H.run_stamped(sim, 1)
	var tick := int(sim.state["tick"])
	var told := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "foe")
	assert_eq(told.size(), 1, "the real lunge is told on the feint tick")
	if told.size() == 1:
		assert_eq(told[0]["action"], "lunge")
		assert_eq(told[0]["at"], tick + 1, "for the next tick")
	assert_eq(H.where(H.run_stamped(sim, 1), Vocab.EV_HIT, "attacker", "foe").size(), 1, "where it lands")


func test_a_feint_makes_no_noise() -> void:
	H.add_stand_ins()
	# A wolf ten metres off: out of its sight, inside a blow's noise.
	var sim := H.arena({
		"foe": {"kind": "stand_in_feinter", "home": HOME}, "sleeper": {"kind": "wolf", "home": [14.5, 37.5]},
	})
	H.place(sim, BESIDE)
	sim.drain_events()
	var events := H.run_stamped(sim, 2)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_FEINTED).size(), 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "sleeper").size(), 0, "the feint woke nothing")
	var woken := H.where(H.run_stamped(sim, 1), Vocab.EV_ENEMY_NOTICED, "enemy_id", "sleeper")
	assert_eq(woken.size(), 1, "where the real lunge does")
	if woken.size() == 1:
		assert_eq(woken[0]["cause"], CombatTable.NOTICE_NOISE)


func test_a_feint_does_not_set_off_auto_retaliate() -> void:
	var sim := _feinter()
	H.run(sim, 2)
	assert_false(sim.is_attacking(), "an idle player does not fight back at a feint")
	H.run(sim, 1)
	assert_true(sim.is_attacking(), "but does at the real lunge")


func test_a_feint_does_not_break_a_waystone_channel() -> void:
	H.add_stand_ins()
	var sim := H.arena({"foe": {"kind": "stand_in_feinter", "home": [10.5, 54.5]}})
	H.patch(sim, {"upgrades": WINCH + ["waystone"], "waystones": ["ring_one_waystone"]})
	H.place(sim, [11.5, 54.5])
	sim.drain_events()
	assert_true(sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})["ok"])
	var events := H.run_stamped(sim, 2)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_FEINTED).size(), 1)
	assert_eq(H.of_kind(events, Vocab.EV_ACTIVITY_STOPPED).size(), 0, "the feint did not break it")
	assert_true(sim.is_travelling())
	var stopped := H.where(H.run_stamped(sim, 1), Vocab.EV_ACTIVITY_STOPPED, "reason", Vocab.REASON_INTERRUPTED)
	assert_eq(stopped.size(), 1, "the real lunge does")


func test_a_feint_after_a_wind_up_is_committed_and_lands_nothing() -> void:
	var sim := _feinter()
	var winding := false
	for i in 12:
		winding = not H.where(H.run_stamped(sim, 1), Vocab.EV_ENEMY_STANCE, "action", "wind_up").is_empty()
		if winding:
			break
	assert_true(winding, "the feinter winds up")
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [14.5, 22.5]})["ok"])
	var told := H.where(H.run_stamped(sim, 1), Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "foe")
	assert_eq(told.size(), 1, "the wound-up feint is declared anyway")
	assert_true(sim.player_pos().distance_to(sim.combatant("foe")["pos"]) > float(sim.combatant("foe")["reach"]),
		"with the player out of reach")
	var events := H.run_stamped(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_FEINTED, "enemy_id", "foe").size(), 1, "and feints")
	assert_eq(H.where(events, Vocab.EV_MISSED, "attacker", "foe").size(), 0, "without a miss")
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", "foe").size(), 0)


func test_a_kiting_kind_backs_off_after_a_feint() -> void:
	var sim := _feinter("stand_in_kiting_feinter", [14.5, 26.5])
	var events := H.run_stamped(sim, 2)
	var feinted := H.where(events, Vocab.EV_ENEMY_FEINTED, "enemy_id", "foe")
	assert_eq(feinted.size(), 1)
	if feinted.size() != 1:
		return
	var moved := H.where(events, Vocab.EV_ENEMY_MOVED, "enemy_id", "foe").filter(
		func(e: Dictionary) -> bool: return e["tick"] == feinted[0]["tick"])
	assert_eq(moved.size(), 1, "it backs a step on the feint tick")
	assert_true(sim.player_pos().distance_to(sim.combatant("foe")["pos"]) > 2.0, "away from the player")


func test_the_telegraph_tip_fires_on_a_feints_telegraph() -> void:
	var sim := _feinter()
	var events := H.run_stamped(sim, 1)
	assert_eq(sim.snapshot()["enemies"]["foe"]["next"]["action"], "feint_lunge", "the first telegraph is the feint")
	assert_eq(H.where(events, Vocab.EV_TIP, "tip", "telegraph").size(), 1)
