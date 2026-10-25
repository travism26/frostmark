## The readability floor: whatever the player does, every enemy blow is telegraphed exactly one
## tick ahead, every change of an enemy's style is announced, and a feint deals no damage.
## Every kind in CombatTable.ENEMIES, and the stand-in feinting, phased and answering kinds,
## fights a long seeded fight against a player who swaps style and steps in and out of reach,
## strikes a kind with fight phases so it comes to them, and swaps to the counter of a kind that
## answers so it answers. It reads the table, so a kind added later is covered without editing
## this file.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Open ground in ring one, with nobody else in the arena.
const HOME := Vector2(14.5, 28.5)
const TICKS := 400
## The player is topped up below this, so no blow (the heaviest, 48 with the edge) kills them,
## and kept warm, so the cold never takes a bite.
const TOP_UP := 50
## A sword in hand, a bow and a staff in the pack to swap to, and ammunition for both.
const KIT := [
	{"item": "iron_bow", "count": 1}, {"item": "iron_staff", "count": 1},
	{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100},
]


func test_every_kind_keeps_the_readability_floor() -> void:
	H.add_stand_ins()
	var kinds: Array = CombatTable.ENEMIES.keys() + H.STAND_IN_KINDS.keys()
	for i in kinds.size():
		_fight(kinds[i], 174 + i)


## One fight against a lone `kind`, the player's moves picked by a generator seeded `seed`.
func _fight(kind: String, seed: int) -> void:
	var sim := H.arena({"foe": {"kind": kind, "home": [HOME.x, HOME.y]}})
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	H.place(sim, [HOME.x, HOME.y - 4.0])
	H.arm(sim, "iron_sword", KIT)
	sim.drain_events()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var told := {}  # tick -> the telegraph naming it
	var style: String = sim.combatant("foe")["style"]
	var blows := 0
	var changes := 0
	var feints := 0
	var phases := CombatTable.phase_count(kind)
	var deepest := 0
	var answering := range(phases + 1).any(func(p: int) -> bool: return not CombatTable.answers(kind, p).is_empty())
	var answered := -1
	var answers := 0
	for t in TICKS:
		if int(sim.state["health"]) < TOP_UP or int(sim.state["warmth"]) < TOP_UP:
			H.patch(sim, {"health": Sim.HEALTH_MAX, "warmth": Sim.WARMTH_MAX})
		_player_turn(sim, rng, phases > 0, answering)
		sim.step()
		var tick := int(sim.state["tick"])
		var events := sim.drain_events()
		var mine := events.filter(func(e: Dictionary) -> bool: return e.get("enemy_id", e.get("attacker", "")) == "foe")
		var stanced := false
		var feinted := false
		for e in mine:
			match e["kind"]:
				Vocab.EV_ENEMY_TELEGRAPHED:
					assert_eq(e["at"], tick + 1, "%s: a telegraph is for the next tick" % kind)
					told[int(e["at"])] = e
				Vocab.EV_ENEMY_STANCE:
					stanced = true
				Vocab.EV_ENEMY_RESPAWNED:
					# A new life starts on the kind's own cycle, in its own weapon.
					style = sim.combatant("foe")["style"]
				Vocab.EV_ENEMY_FEINTED:
					feinted = true
					feints += 1
					assert_true(told.has(tick), "%s: the feint on tick %d was telegraphed" % [kind, tick])
				Vocab.EV_HIT, Vocab.EV_MISSED:
					blows += 1
					assert_true(told.has(tick), "%s: the blow on tick %d was telegraphed a tick earlier" % [kind, tick])
					if e["kind"] == Vocab.EV_HIT and told.has(tick):
						assert_eq(e["style"], told[tick]["style"], "%s: it lands in the style it was told in" % kind)
		if feinted:
			assert_eq(H.where(events, Vocab.EV_TOOK_DAMAGE, "cause", kind).size(), 0, "%s: no damage on the feint tick %d" % [kind, tick])
		var now: String = sim.combatant("foe")["style"]
		if now != style:
			changes += 1
			# The held weapon follows the declared action, so the change shows on the tick of
			# its announcement, a tick before the stance and two before any blow in it.
			assert_true(stanced, "%s: the change to %s on tick %d was announced" % [kind, now, tick])
			style = now
		deepest = maxi(deepest, int(sim.state["enemies"]["foe"]["phase"]))
		var last := int(sim.state["enemies"]["foe"]["answered_tick"])
		if last != answered and last >= 0:
			answers += 1
		answered = last
	assert_true(blows > 10, "%s: the fight came to blows (%d)" % [kind, blows])
	if (CombatTable.enemy(kind).get("stances", []) as Array).size() > 0:
		assert_true(changes > 0, "%s: it changed style in the fight" % kind)
	if (CombatTable.enemy(kind)["actions"] as Array).any(CombatTable.is_feint):
		assert_true(feints > 0, "%s: it feinted in the fight" % kind)
	assert_eq(deepest, phases, "%s: it fought into its last phase" % kind)
	if answering:
		assert_true(answers > 0, "%s: it answered in the fight" % kind)


## The player's move this tick: stay, swap to another weapon (to the style with the edge on the
## foe's, when `counters`), step up close, step back out, or, when `strikes`, attack.
func _player_turn(sim: Sim, rng: RandomNumberGenerator, strikes: bool, counters: bool) -> void:
	var foe: Vector2 = sim.combatant("foe")["pos"]
	match rng.randi_range(0, 5):
		0:
			var counter := _counter(sim) if counters else -1
			sim.command(Vocab.EQUIP, {"index": counter if counter >= 0 else rng.randi_range(0, 1)})
		1:
			_walk(sim, foe + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
		2:
			var away := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(5.0, 10.0)
			_walk(sim, HOME + away)
		3:
			if strikes:
				sim.command(Vocab.ATTACK, {"enemy_id": "foe"})


## The pack slot of a weapon whose style has the edge on the foe's where they stand, or -1.
func _counter(sim: Sim) -> int:
	var foe := sim.combatant("foe")
	var distance := sim.player_pos().distance_to(foe["pos"])
	var pack: Array = sim.state["inventory"]["pack"]
	for i in 2:
		var style: String = CombatTable.weapon(pack[i]["item"] if pack[i] != null else "")["style"]
		if CombatTable.multiplier(style, foe["style"], distance) > 1.0:
			return i
	return -1


func _walk(sim: Sim, to: Vector2) -> void:
	sim.command(Vocab.MOVE_TO, {"pos": [to.x, to.y]})
