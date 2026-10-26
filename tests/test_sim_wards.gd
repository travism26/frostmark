## Wards: from a health mark to the end of that phase, a boss is guarded against every style but
## one. No boss is warded until ring two, so the stand-in warder in tests/sim_helpers.gd carries
## the rule: below half health it raises a ward only magic gets through, and below 20 % it
## quickens and the ward is gone. A warded blow lands for 0, says it was warded and trains
## nothing; a blow in the unwarded style does its full damage.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one with nobody else in the arena, and a metre north of it: inside the
## warder's sight and its fangs' reach.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## The warder's health just under its warded mark (50 % of 500), and under its unwarded one.
const WARDED := 240
const PAST_THE_WARD := 90
## The player is topped up below this, so a fight runs as long as a test needs.
const TOP_UP := 50
const SHARDS := [{"item": "frost_shards", "count": 40}]
const ARROWS := [{"item": "arrows", "count": 40}]


## A player standing beside a lone warder at `health`, before either has acted, not fighting back.
func _warder(health := 500) -> Sim:
	H.add_stand_ins()
	var sim := _arena()
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, BESIDE)
	if health != 500:
		H.patch_enemy(sim, "foe", {"health": health})
	sim.drain_events()
	return sim


func _arena() -> Sim:
	return H.arena({"foe": {"kind": "stand_in_warder", "home": HOME}})


## Steps `ticks` ticks like H.run_stamped, topping the player's health and warmth up as it goes.
func _run(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		if int(sim.state["health"]) < TOP_UP or int(sim.state["warmth"]) < TOP_UP:
			H.patch(sim, {"health": Sim.HEALTH_MAX, "warmth": Sim.WARMTH_MAX})
		events.append_array(H.run_stamped(sim, 1))
	return events


## The player's blows on the foe in `ticks` ticks with `weapon` (and `pack`), from where they stand.
func _blows(sim: Sim, weapon: String, pack: Array = [], ticks := 6) -> Array[Dictionary]:
	H.arm(sim, weapon, pack)
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "foe"})["ok"], "the player attacks")
	var events := _run(sim, ticks)
	H.place(sim, BESIDE)
	return H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)


func _xp(sim: Sim, skill: String) -> int:
	return int(sim.state["skills"][skill]["xp"])


func test_only_stand_ins_are_warded_and_no_kind_has_ward_problems() -> void:
	H.add_stand_ins()
	for kind in CombatTable.ENEMIES:
		for phase in CombatTable.phase_count(kind) + 1:
			assert_eq(CombatTable.ward(kind, phase), "", "%s is unwarded in phase %d" % [kind, phase])
		assert_eq(CombatTable.ward_problems(CombatTable.ENEMIES[kind]), [] as Array[String], "%s's wards" % kind)
	for kind in H.STAND_IN_KINDS:
		assert_eq(CombatTable.ward_problems(H.STAND_IN_KINDS[kind]), [] as Array[String], "%s's wards" % kind)
		assert_eq(CombatTable.phase_problems(H.STAND_IN_KINDS[kind]), [] as Array[String], "%s's phases" % kind)
	assert_eq(CombatTable.ward("stand_in_warder", 0), "")
	assert_eq(CombatTable.ward("stand_in_warder", 1), CombatTable.STYLE_MAGIC)
	assert_eq(CombatTable.ward("stand_in_warder", 2), "", "the next phase carries no ward")


func test_below_the_mark_the_phase_s_opening_stance_names_the_ward() -> void:
	var above := _warder()
	var calm := _run(above, 8)
	assert_eq(H.of_kind(calm, Vocab.EV_ENEMY_STANCE).size(), 0, "above the mark it takes no stance")
	var sim := _warder(WARDED)
	var events := _run(sim, 8)
	var stances := H.where(events, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe")
	assert_true(stances.size() >= 2, "the cycle came round again")
	if stances.is_empty():
		return
	assert_eq(stances[0]["action"], "raise_ward", "the phase opens with its stance")
	assert_eq(stances[0]["at"], int(stances[0]["tick"]) + 1, "a tick ahead")
	assert_eq(stances[0].get("ward"), CombatTable.STYLE_MAGIC, "naming the one style that hurts it")
	for stance in stances:
		assert_eq(stance.get("ward"), CombatTable.STYLE_MAGIC, "each time the cycle opens, the same style: it never rotates")


func test_while_the_ward_holds_other_styles_land_for_nothing_and_train_nothing() -> void:
	for armed: Array in [["iron_sword", [], SkillTable.MELEE], ["iron_bow", ARROWS, SkillTable.RANGED]]:
		var sim := _warder(WARDED)
		_run(sim, 1)
		var xp := _xp(sim, armed[2])
		var blows := _blows(sim, armed[0], armed[1])
		assert_true(blows.size() >= 2, "%s: the blows land" % armed[0])
		for blow in blows:
			assert_eq(blow["amount"], 0, "%s: for 0" % armed[0])
			assert_eq(blow.get("warded"), CombatTable.STYLE_MAGIC, "%s: warded, and naming what gets through" % armed[0])
		assert_eq(int(sim.state["enemies"]["foe"]["health"]), WARDED, "%s: it takes no harm" % armed[0])
		assert_eq(_xp(sim, armed[2]), xp, "%s: and no experience for damage done" % armed[0])


func test_the_unwarded_style_does_its_full_damage() -> void:
	var calm := _warder()
	var unwarded := _blows(calm, "iron_staff", SHARDS)
	var sim := _warder(WARDED)
	_run(sim, 1)
	var xp := _xp(sim, SkillTable.MAGIC)
	var warded := _blows(sim, "iron_staff", SHARDS)
	assert_true(warded.size() >= 2, "the casts land")
	assert_eq(warded.size(), unwarded.size())
	for i in mini(warded.size(), unwarded.size()):
		assert_false(warded[i].has("warded"), "a cast in the unwarded style is not warded")
		assert_true(int(warded[i]["amount"]) > 0, "it does damage")
		assert_eq(warded[i]["amount"], unwarded[i]["amount"], "the same as above the mark")
	assert_true(_xp(sim, SkillTable.MAGIC) > xp, "and trains magic")


func test_a_blow_before_the_phase_opens_is_not_warded() -> void:
	var sim := _warder(WARDED)
	H.arm(sim, "iron_sword")
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "foe"})["ok"])
	var events := _run(sim, 1)
	var stances := H.where(events, Vocab.EV_ENEMY_STANCE, "enemy_id", "foe")
	var blows := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(blows.size(), 1, "the player strikes on the tick the warder notices them")
	assert_eq(stances.size(), 1, "and the ward is told after that blow, on the same tick")
	if blows.size() == 1:
		assert_true(int(blows[0]["amount"]) > 0, "so that blow is not warded")
		assert_false(blows[0].has("warded"))


func test_the_ward_ends_with_its_phase() -> void:
	var sim := _warder(WARDED)
	_run(sim, 1)
	H.patch_enemy(sim, "foe", {"health": PAST_THE_WARD})
	var events := _run(sim, 3)
	assert_true(H.where(events, Vocab.EV_ENEMY_STANCE, "action", "quicken").size() == 1, "the next phase starts")
	assert_false(H.of_kind(events, Vocab.EV_ENEMY_STANCE).any(func(e: Dictionary) -> bool: return e.has("ward")), "with no ward")
	for blow in _blows(sim, "iron_sword"):
		assert_true(int(blow["amount"]) > 0, "a blade hurts it again")
		assert_false(blow.has("warded"))


func test_the_ward_is_gone_at_respawn() -> void:
	var sim := _warder(WARDED)
	_run(sim, 1)
	H.patch_enemy(sim, "foe", {"health": 1})
	H.arm(sim, "iron_staff", SHARDS)
	sim.command(Vocab.ATTACK, {"enemy_id": "foe"})
	var events := _run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "foe").size(), 1, "it dies")
	for i in int(H.STAND_IN_KINDS["stand_in_warder"]["respawn_ticks"]) + 1:
		if H.where(_run(sim, 1), Vocab.EV_ENEMY_RESPAWNED, "enemy_id", "foe").size() > 0:
			break
	assert_eq(sim.state["enemies"]["foe"]["mode"], Sim.MODE_IDLE, "it comes back")
	H.place(sim, BESIDE)
	for blow in _blows(sim, "iron_sword"):
		assert_true(int(blow["amount"]) > 0, "unwarded")


func test_the_ward_is_gone_when_it_walks_home_and_heals() -> void:
	var sim := _warder(WARDED)
	_run(sim, 2)
	H.walk_to(sim, H.INSIDE_COLD_CORNER)
	_run(sim, 20)
	var foe: Dictionary = sim.state["enemies"]["foe"]
	assert_eq(foe["mode"], Sim.MODE_IDLE, "it walked home")
	assert_eq(int(foe["health"]), 500, "and healed")
	H.place(sim, BESIDE)
	for blow in _blows(sim, "iron_sword"):
		assert_true(int(blow["amount"]) > 0, "unwarded")


func test_a_save_taken_mid_ward_restores_with_the_ward_holding() -> void:
	var sim := _warder(WARDED)
	_run(sim, 2)
	var snap := sim.snapshot()
	var restored := _arena()
	assert_true(restored.restore(JSON.parse_string(JSON.stringify(snap))))
	var imported := _arena()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	for copy: Sim in [sim, restored, imported]:
		copy.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
		copy.drain_events()
		var blows := _blows(copy, "iron_sword")
		assert_true(blows.size() >= 2, "the blows land")
		for blow in blows:
			assert_eq(blow["amount"], 0, "the ward holds")
			assert_eq(blow.get("warded"), CombatTable.STYLE_MAGIC)
		assert_eq(int(copy.state["enemies"]["foe"]["health"]), WARDED)


func test_the_combat_table_refuses_a_ward_with_an_unknown_style_or_on_a_kind_that_answers() -> void:
	var rest := CombatTable.ACTION_REST
	var good := {"actions": ["bite", rest], "phases": [{"below": 50, "actions": ["quicken", rest], "ward": CombatTable.STYLE_RANGED}]}
	assert_eq(CombatTable.ward_problems(good), [] as Array[String])
	for style: Variant in ["fire", "", null, 2]:
		var bad := good.duplicate(true)
		bad["phases"][0]["ward"] = style
		var problems := CombatTable.ward_problems(bad)
		assert_eq(problems.size(), 1, "ward %s is refused" % [style])
		if problems.size() == 1:
			assert_true(problems[0].contains("not a style"), problems[0])
	var answering := good.duplicate(true)
	answering["answers"] = {CombatTable.STYLE_MAGIC: 0}
	answering["actions"] = ["quicken", rest]
	answering["answer_ticks"] = 8
	var late := good.duplicate(true)
	late["phases"].append({"below": 20, "actions": ["quicken", rest], "answers": {CombatTable.STYLE_MAGIC: 0}, "answer_ticks": 8})
	for bad: Dictionary in [answering, late]:
		var problems := CombatTable.ward_problems(bad)
		assert_eq(problems.size(), 1, "a ward on a kind that answers is refused")
		if problems.size() == 1:
			assert_true(problems[0].contains("answers"), problems[0])
	var own := {"actions": ["bite", rest], "ward": CombatTable.STYLE_MAGIC}
	assert_eq(CombatTable.ward_problems(own).size(), 1, "a ward comes only with a fight phase")
