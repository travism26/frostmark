## The great frost bear, the ring-one dungeon's boss: a melee kind whose claws swipe and maul,
## telegraphed and countered as usual, with a front smash and a ring stomp marked two ticks ahead,
## and one fight phase at half health that calls in two wolves from the edges of its room. It is
## fought here as the boss test code's character fights it, with a ring-one kit.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const RingCodes := preload("res://tools/ring_codes.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

const KIND := "great_frost_bear"
const BOSS := "ring_one_dungeon_boss"
const DUNGEON := "ring_one_dungeon"
const HOME := [73.0, 44.0]
## A metre and a bit south of the bear's home: inside its claws' reach.
const BESIDE := [73.0, 45.2]
## A staff's cast south of it, out of its claws' reach and off every mark it tells.
const AT_STAFF_RANGE := [73.0, 49.5]
const ADDS := ["ring_one_dungeon_boss_add_1", "ring_one_dungeon_boss_add_2"]


## The boss code's character in the real world, at `at` (beside the bear by default), with
## auto-retaliate set to `fights_back`.
func _bear(at := BESIDE, fights_back := true) -> Sim:
	var sim := RingCodes.boss_sim()
	H.place(sim, at)
	if not fights_back:
		sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	sim.drain_events()
	return sim


func _swap_to(sim: Sim, weapon: String) -> void:
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == weapon:
			assert_true(sim.command(Vocab.EQUIP, {"index": i})["ok"], "equip the %s" % weapon)
			return
	assert_true(false, "a %s in the pack" % weapon)


func _trout(sim: Sim) -> int:
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == "cooked_trout":
			return i
	return -1


## Where the player steps to get off `mark`: a ring is left straight outward, a metre past its
## edge; a front arc to the bear's side, square to where it faces and still beside it.
func _off(sim: Sim, mark: Dictionary) -> Vector2:
	var centre := Vector2(mark["centre"][0], mark["centre"][1])
	var here := sim.player_pos()
	if mark["shape"] == CombatTable.MARK_RING:
		var away := (here - centre).normalized() if here != centre else Vector2(0, 1)
		return centre + away * (float(mark["radius"]) + 1.0)
	var ahead := Vector2(mark["facing"][0], mark["facing"][1])
	for side in [Vector2(-ahead.y, ahead.x), Vector2(ahead.y, -ahead.x)]:
		var to: Vector2 = centre + side * 1.4
		if sim.world.is_walkable(to):
			return to
	return centre - ahead * 1.4


## Whichever living add is engaged, or "" when none is.
func _add_in_fight(sim: Sim) -> String:
	for id in ADDS:
		if sim.state["enemies"].has(id) and sim.state["enemies"][id]["mode"] == Sim.MODE_ENGAGED:
			return id
	return ""


## Fights the bear from beside it with the iron staff. The reader steps off every ground mark the
## tick it is told; the non-reader (`steps_off` false) stands its ground. Both strike whenever
## they can, the wolves first once they come in, and eat a trout below half health.
func _fight(steps_off: bool) -> Dictionary:
	var sim := _bear()
	sim.command(Vocab.ATTACK, {"enemy_id": BOSS})
	var ticks := 0
	var lowest := int(sim.state["health"])
	var marks := 0
	var struck := 0
	var died := false
	var called := 0
	while ticks < 400 and sim.state["enemies"][BOSS]["mode"] != Sim.MODE_DEAD and not died:
		H.patch(sim, {"warmth": Sim.WARMTH_MAX})
		if int(sim.state["health"]) < Sim.HEALTH_MAX / 2 and _trout(sim) >= 0:
			sim.command(Vocab.EAT, {"index": _trout(sim)})
		sim.step()
		ticks += 1
		for e in sim.drain_events():
			died = died or e["kind"] == Vocab.EV_DIED
			if e["kind"] == Vocab.EV_ADD_CALLED:
				called += 1
			if e["kind"] == Vocab.EV_HIT and e["attacker"] == BOSS and e.get("area", false):
				struck += 1
			if e["kind"] == Vocab.EV_GROUND_MARKED and e["enemy_id"] == BOSS:
				marks += 1
				if steps_off:
					var to := _off(sim, e["mark"])
					sim.command(Vocab.MOVE_TO, {"pos": [to.x, to.y]})
		if not sim.is_attacking() and not sim.is_moving():
			var add := _add_in_fight(sim)
			sim.command(Vocab.ATTACK, {"enemy_id": add if add != "" else BOSS})
		lowest = mini(lowest, int(sim.state["health"]))
	return {
		"ticks": ticks, "health": int(sim.state["health"]), "lowest": lowest, "died": died,
		"dead": sim.state["enemies"][BOSS]["mode"] == Sim.MODE_DEAD, "bear": int(sim.state["enemies"][BOSS]["health"]),
		"marks": marks, "struck": struck, "called": called, "trout": H.pack_count(sim, "cooked_trout"),
	}


func test_the_reader_steps_off_every_mark_and_beats_the_bear() -> void:
	var fight := _fight(true)
	print("  bear, the reader: %s" % fight)
	assert_true(fight["dead"] and not fight["died"], "the bear falls and the reader stands")
	assert_eq(fight["struck"], 0, "no smash or stomp lands on it")
	assert_true(fight["marks"] >= 4, "through %d marks" % fight["marks"])
	assert_eq(fight["called"], 2, "and the two wolves at half health")


func test_the_non_reader_standing_still_takes_the_smash_and_stomp_and_dies() -> void:
	var fight := _fight(false)
	print("  bear, the non-reader: %s" % fight)
	assert_true(fight["struck"] >= 2, "the smash and stomp land (%d)" % fight["struck"])
	assert_true(fight["died"], "it dies, the bear left on %d" % fight["bear"])


# --- The kind -----------------------------------------------------------------------------

func test_the_bear_is_the_dungeons_boss_and_the_placeholder_is_gone() -> void:
	var w := WorldDefScript.outpost()
	assert_eq(w.enemies[BOSS]["kind"], KIND, "the boss room's one placement")
	assert_eq(w.enemies[BOSS]["home"], HOME)
	assert_false(CombatTable.is_enemy_kind("great_wolf"), "the placeholder kind is gone")
	var bears := w.enemies.keys().filter(func(id: String) -> bool: return w.enemies[id]["kind"] == KIND)
	assert_eq(bears, [BOSS], "and the bear is in no other placement")


func test_it_fights_in_melee_with_a_smash_a_stomp_and_one_phase_and_nothing_more() -> void:
	var def := CombatTable.enemy(KIND)
	assert_eq(CombatTable.weapon(def["weapon"])["style"], CombatTable.STYLE_MELEE, "melee")
	assert_eq(CombatTable.multiplier(CombatTable.STYLE_MAGIC, CombatTable.STYLE_MELEE, 1.0), 1.5, "so magic has the edge on it")
	assert_true(def["boss"], "a boss")
	var shapes := {}
	for phase in CombatTable.phase_count(KIND) + 1:
		for action in CombatTable.cycle(KIND, phase):
			if CombatTable.is_area_blow(action):
				shapes[CombatTable.area_mark(action, Vector2.ZERO, Vector2(0, 1))["shape"]] = true
				assert_eq(CombatTable.mark_ticks(action), CombatTable.MARK_TICKS, "%s is told two ticks ahead" % action)
			assert_false(CombatTable.is_feint(action), "%s is no feint" % action)
	assert_eq(shapes.keys(), [CombatTable.MARK_FRONT, CombatTable.MARK_RING], "a front smash and a ring stomp, no drop mark")
	assert_eq(CombatTable.phase_count(KIND), 1, "one fight phase")
	assert_eq(int(def["phases"][0]["below"]), 50, "at half health")
	assert_true(CombatTable.is_stance(CombatTable.cycle(KIND, 1)[0]), "announced by a stance")
	assert_eq(CombatTable.answers(KIND, 0), {}, "no answers")
	assert_eq(CombatTable.answers(KIND, 1), {}, "in either cycle")
	for key in ["ward", "burn"]:
		assert_false(def.has(key) or def["phases"][0].has(key), "no %s" % key)
	for action in CombatTable.ACTIONS:
		if CombatTable.is_area_blow(action) and action.begins_with("bear_"):
			assert_false(CombatTable.ACTIONS[action].has("burn"), "%s leaves no burning ground" % action)
	assert_eq(CombatTable.phase_problems(def), [] as Array[String])
	assert_eq(CombatTable.area_problems(def), [] as Array[String])
	assert_eq(CombatTable.add_problems(def), [] as Array[String])
	assert_eq(CombatTable.answer_problems(def), [] as Array[String])


func test_its_two_wolves_come_in_from_the_west_and_east_edges_of_its_room() -> void:
	var w := WorldDefScript.outpost()
	var adds := CombatTable.adds(KIND, 1)
	assert_eq(adds.map(func(a: Dictionary) -> String: return a["kind"]), ["wolf", "wolf"], "two of ring one's wolves")
	var room: Array = WorldDef.DUNGEONS[DUNGEON]["reserved"]["boss_room"]
	var sides := []
	for add in adds:
		var at := Vector2(HOME[0] + add["entry"][0], HOME[1] + add["entry"][1])
		assert_true(w.is_walkable(at), "%s is open ground" % at)
		assert_true(WorldDef.in_boss_room(BOSS, at), "%s is in the room" % at)
		assert_eq(w.region_at(at), WorldDef.REGION_RING_ONE_DUNGEON)
		var edge := minf(at.x - room[0][0], room[1][0] - at.x)
		assert_true(edge < 1.0, "%s stands at the room's edge" % at)
		sides.append(signf(at.x - HOME[0]))
	assert_eq(sides, [-1.0, 1.0], "one each side of the bear")


# --- The fight ------------------------------------------------------------------------------

func test_the_smash_marks_the_ground_in_front_and_the_stomp_a_ring_two_ticks_before_they_land() -> void:
	var sim := _bear(BESIDE, false)
	var events := H.run_stamped(sim, 20)
	var marks := H.where(events, Vocab.EV_GROUND_MARKED, "enemy_id", BOSS).filter(func(e: Dictionary) -> bool: return int(e["at"]) <= 20)
	var told := marks.map(func(e: Dictionary) -> String: return "%s %s" % [e["action"], e["mark"]["shape"]])
	assert_eq(told.slice(0, 2), ["bear_smash front", "bear_stomp ring"], "a smash, then a stomp")
	for e in marks:
		assert_eq(int(e["at"]), int(e["tick"]) + CombatTable.MARK_TICKS, "%s lands two ticks after it is told" % e["action"])
		var landed := H.where(events, Vocab.EV_HIT, "attacker", BOSS).filter(func(h: Dictionary) -> bool: return h["tick"] == e["at"])
		assert_eq(landed.size(), 1, "the %s lands on the player standing in it" % e["action"])
		assert_true(landed.size() == 1 and landed[0].get("area", false), "as an area blow")
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_TELEGRAPHED).filter(func(e: Dictionary) -> bool: return CombatTable.is_area_blow(e["action"])).size(), 0, "never told as an aimed blow")


func test_it_is_rooted_from_the_mark_until_the_blow_lands() -> void:
	var sim := _bear(BESIDE, false)
	while H.where(H.run_stamped(sim, 1), Vocab.EV_GROUND_MARKED, "enemy_id", BOSS).is_empty():
		pass
	var pos: Array = sim.state["enemies"][BOSS]["pos"].duplicate()
	var facing: Array = sim.state["enemies"][BOSS]["facing"].duplicate()
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [HOME[0] + 3.5, HOME[1] + 3.0]})["ok"])
	for i in CombatTable.MARK_TICKS:
		H.run(sim, 1)
		assert_eq(sim.state["enemies"][BOSS]["pos"], pos, "it does not follow")
		assert_eq(sim.state["enemies"][BOSS]["facing"], facing, "or turn")
	H.run(sim, 2)
	assert_ne(sim.state["enemies"][BOSS]["pos"], pos, "until the blow has landed")


func test_stepping_off_the_smash_and_the_stomp_makes_both_miss() -> void:
	var sim := _bear(BESIDE, false)
	var missed := 0
	for i in 20:
		for e in H.run_stamped(sim, 1):
			if e["kind"] == Vocab.EV_GROUND_MARKED:
				var to := _off(sim, e["mark"])
				sim.command(Vocab.MOVE_TO, {"pos": [to.x, to.y]})
			if e["kind"] == Vocab.EV_MISSED and e.get("area", false):
				missed += 1
			if e["kind"] == Vocab.EV_HIT and e.get("area", false):
				assert_true(false, "the %s caught the player" % e["action"])
	assert_true(missed >= 2, "both the smash and the stomp miss (%d)" % missed)


## The damage of each of the bear's blows that hit a player standing beside it holding
## `weapon`, by action, over its first cycle and a half.
func _blows_on(weapon: String) -> Dictionary:
	var sim := _bear(BESIDE, false)
	H.arm(sim, weapon, [{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100}])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge(RingCodes.BOSS_EQUIPMENT.merged({"weapon": weapon}, true), true)
	sim.restore(snap)
	var events := H.run_stamped(sim, 16)
	var told := {}
	for e in events:
		if e["kind"] in [Vocab.EV_ENEMY_TELEGRAPHED, Vocab.EV_GROUND_MARKED]:
			told[int(e["at"])] = e["action"]
	var out := {}
	for e in H.where(events, Vocab.EV_HIT, "attacker", BOSS):
		out[told[int(e["tick"])]] = e["amount"]
	return out


func test_swapping_style_changes_its_claws_by_the_triangle_but_never_its_smash_or_stomp() -> void:
	var staff := _blows_on("iron_staff")
	var sword := _blows_on("iron_sword")
	var bow := _blows_on("iron_bow")
	print("  bear's blows on a staff %s, a sword %s, a bow %s" % [staff, sword, bow])
	for action in ["bear_swipe", "bear_maul", "bear_smash", "bear_stomp"]:
		assert_true(staff.has(action) and sword.has(action) and bow.has(action), "the %s lands on all three" % action)
	for action in ["bear_swipe", "bear_maul"]:
		assert_true(int(staff.get(action, 0)) < int(sword.get(action, 0)), "a staff takes its %s at a discount" % action)
		assert_true(int(sword.get(action, 0)) < int(bow.get(action, 0)), "a bow up close takes it in full and more")
	for action in ["bear_smash", "bear_stomp"]:
		assert_eq([sword.get(action), bow.get(action)], [staff.get(action), staff.get(action)], "no swap changes its %s" % action)
		assert_eq(int(staff.get(action, 0)), CombatTable.action_damage(action) - 3, "only the iron armour cuts it")


func test_below_half_health_it_rears_and_two_wolves_come_in_at_the_rooms_edge_and_engage() -> void:
	var sim := _bear(BESIDE, false)
	H.patch_enemy(sim, BOSS, {"health": 299})
	var told := H.run_stamped(sim, 1)
	var stance := H.where(told, Vocab.EV_ENEMY_STANCE, "enemy_id", BOSS)
	assert_eq(stance.size(), 1, "the phase is announced")
	assert_eq(stance[0]["action"] if stance.size() == 1 else "", "bear_rears", "by a stance")
	var called := H.of_kind(told, Vocab.EV_ADD_CALLED)
	assert_eq(called.map(func(e: Dictionary) -> String: return e["enemy_id"]), ADDS, "two adds called")
	for i in called.size():
		var entry: Array = CombatTable.adds(KIND, 1)[i]["entry"]
		assert_eq(called[i]["pos"], [HOME[0] + entry[0], HOME[1] + entry[1]], "at its entry point")
		assert_eq(called[i]["enemy_kind"], "wolf")
	var came := H.run_stamped(sim, 1)
	for id in ADDS:
		assert_eq(H.where(came, Vocab.EV_ENEMY_NOTICED, "enemy_id", id).size(), 1, "%s comes in" % id)
		assert_eq(sim.state["enemies"][id]["mode"], Sim.MODE_ENGAGED, "and fights")
	var fight := H.run_stamped(sim, 10)
	for id in ADDS:
		assert_true(H.where(fight, Vocab.EV_HIT, "attacker", id).size() > 0, "%s closes in and bites" % id)
	assert_eq(H.of_kind(fight, Vocab.EV_ADD_CALLED).size(), 0, "they come only once")


func test_a_dead_bear_drops_its_fixed_pile_of_iron_ore_and_wolf_pelts_and_nothing_else() -> void:
	for i in 5:
		var sim := _bear()
		H.patch_enemy(sim, BOSS, {"health": 1})
		sim.command(Vocab.ATTACK, {"enemy_id": BOSS})
		var drops := H.of_kind(H.run(sim, 3), Vocab.EV_LOOT_DROPPED).map(func(e: Dictionary) -> String: return "%d %s" % [e["count"], e["item"]])
		drops.sort()
		assert_eq(drops, ["4 wolf_pelt", "6 iron_ore"], "kill %d: the same pile, and nothing else" % i)


## Fells the bear from beside it and steps back outside its room. Returns the tick it fell on.
func _fell(sim: Sim) -> int:
	H.place(sim, BESIDE)
	H.patch_enemy(sim, BOSS, {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": BOSS})
	var died := H.where(H.run_stamped(sim, 3), Vocab.EV_ENEMY_DIED, "enemy_id", BOSS)
	assert_eq(died.size(), 1, "the bear falls")
	H.place(sim, RingCodes.BOSS_SPOT)
	return int(died[0]["tick"]) if not died.is_empty() else -1


func test_its_first_fall_is_kept_for_good_it_comes_back_600_ticks_later_and_the_way_out_shuts() -> void:
	var sim := _bear()
	var way_out: String = WorldDef.DUNGEONS[DUNGEON]["way_out"]
	var fell := _fell(sim)
	assert_eq(sim.state["bosses_defeated"], [BOSS], "its first fall is recorded")
	assert_true(sim.way_out_open(way_out), "the way out opens")
	var back := H.where(H.run_stamped(sim, 605), Vocab.EV_ENEMY_RESPAWNED, "enemy_id", BOSS)
	assert_eq(int(back[0]["tick"]) if back.size() == 1 else -1, fell + 600, "back 600 ticks after it fell")
	assert_eq(int(sim.state["enemies"][BOSS]["health"]), int(CombatTable.enemy(KIND)["health"]), "whole again")
	assert_false(sim.way_out_open(way_out), "and the way out shut")
	_fell(sim)
	assert_eq(sim.state["bosses_defeated"], [BOSS], "a later fall is not recorded again")
