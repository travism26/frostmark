## Tick combat: the style edge, telegraphs, swapping, eating, ammunition, noticing and
## disengaging, loot, and the death rule.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Five metres north of the bandit archer: inside its sight and its bow's reach, and well
## away from both wolf packs.
const NEAR_ARCHER := [14.5, 23.5]
## One metre north of the archer: close range.
const BESIDE_ARCHER := [14.5, 27.5]


func test_the_style_table_gives_the_edge_both_ways() -> void:
	var melee := CombatTable.STYLE_MELEE
	var ranged := CombatTable.STYLE_RANGED
	var close := 1.0
	var far := 5.0
	# Melee up close has the edge on a ranged defender, and takes less back.
	assert_eq(CombatTable.edge(melee, ranged, close), {"dealt": 1.5, "taken": 0.5})
	assert_eq(CombatTable.multiplier(melee, ranged, close), 1.5)
	assert_eq(CombatTable.multiplier(ranged, melee, close), 0.5)
	# Ranged at distance has the edge on a melee defender, and takes less back.
	assert_eq(CombatTable.edge(ranged, melee, far), {"dealt": 1.5, "taken": 0.5})
	assert_eq(CombatTable.multiplier(ranged, melee, far), 1.5)
	assert_eq(CombatTable.multiplier(melee, ranged, far), 0.5)
	# The edge only holds at its range.
	assert_eq(CombatTable.edge(melee, ranged, far), {"dealt": 1.0, "taken": 1.0})
	assert_eq(CombatTable.edge(ranged, melee, close), {"dealt": 1.0, "taken": 1.0})
	# The same style is neutral at any range.
	for d in [close, far]:
		assert_eq(CombatTable.multiplier(melee, melee, d), 1.0)
		assert_eq(CombatTable.multiplier(ranged, ranged, d), 1.0)
	assert_eq(CombatTable.damage(4, melee, ranged, close), 6)
	assert_eq(CombatTable.damage(4, ranged, melee, close), 2)
	assert_eq(CombatTable.damage(4, ranged, ranged, far, 2), 2, "armour comes off after the edge")
	assert_eq(CombatTable.damage(1, ranged, melee, close, 5), 1, "a real blow always lands for 1")


func test_a_club_beside_an_archer_has_the_edge() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_ARCHER)
	H.arm(sim, "wooden_club")
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})["ok"])
	var events := H.run_stamped(sim, 6)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	var theirs := H.where(events, Vocab.EV_HIT, "attacker", "archer_1")
	assert_true(mine.size() > 0 and theirs.size() > 0, "both sides land blows")
	assert_eq(mine[0]["style"], CombatTable.STYLE_MELEE)
	assert_eq(mine[0]["multiplier"], 1.5, "melee up close beats ranged")
	assert_eq(mine[0]["amount"], 8, "club power 5 x 1.5, rounded")
	assert_eq(theirs[0]["multiplier"], 0.5, "the archer shoots into the edge")


func test_a_bow_at_distance_has_the_edge_on_a_wolf() -> void:
	var sim := SimScript.new()
	H.place(sim, [-7.5, 23.5])  # five metres north of wolf_1
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 20}])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["ok"])
	var events := H.run_stamped(sim, 1)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(mine.size(), 1, "the bow reaches from where the player stands")
	assert_eq(mine[0]["multiplier"], 1.5, "ranged at distance beats melee")
	assert_eq(mine[0]["amount"], 6)


func test_a_swap_lands_on_the_next_tick() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_ARCHER)
	H.arm(sim, "wooden_bow", [{"item": "wooden_club", "count": 1}, {"item": "arrows", "count": 20}])
	sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})
	var events := H.run_stamped(sim, 1)
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)[0]["style"], CombatTable.STYLE_RANGED)
	# Wait for the tick before the next swing, then swap.
	for i in 4:
		if not (sim.combatant(Vocab.PLAYER)["next"] as Dictionary).is_empty():
			break
		H.run(sim, 1)
	assert_false((sim.combatant(Vocab.PLAYER)["next"] as Dictionary).is_empty(), "a swing is due next tick")
	assert_true(sim.command(Vocab.EQUIP, {"index": 0})["ok"])
	assert_eq(sim.player_weapon(), "wooden_bow", "nothing changes on the tick the swap is ordered")
	assert_eq(sim.player_style(), CombatTable.STYLE_RANGED)
	var tick := int(sim.state["tick"])
	events = H.run_stamped(sim, 1)
	var equipped := H.of_kind(events, Vocab.EV_EQUIPPED)
	assert_eq(equipped.size(), 1)
	assert_eq(equipped[0]["tick"], tick + 1, "the swap lands on the next tick")
	assert_eq(equipped[0]["item"], "wooden_club")
	assert_eq(sim.player_style(), CombatTable.STYLE_MELEE)
	var swing := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(swing.size(), 1, "the swing still comes that tick")
	assert_eq(swing[0]["style"], CombatTable.STYLE_MELEE, "and it is already a melee blow")
	assert_eq(swing[0]["multiplier"], 1.5)


func test_every_telegraph_comes_exactly_one_tick_before_its_blow() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_ARCHER)
	var events := H.run_stamped(sim, 15)
	var told := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "archer_1")
	var blows: Array[Dictionary] = []
	blows.append_array(H.where(events, Vocab.EV_HIT, "attacker", "archer_1"))
	blows.append_array(H.where(events, Vocab.EV_MISSED, "attacker", "archer_1"))
	assert_true(told.size() >= 4, "the archer keeps attacking")
	var resolved := 0
	for t in told:
		assert_eq(t["at"], t["tick"] + 1, "telegraphed for the next tick")
		assert_eq(t["style"], CombatTable.STYLE_RANGED)
		for b in blows:
			if b["tick"] == t["at"]:
				resolved += 1
	assert_eq(resolved, told.filter(func(t: Dictionary) -> bool: return t["at"] <= sim.state["tick"]).size(),
		"every telegraph due so far was followed by its blow on exactly that tick")
	for b in blows:
		var warned := told.filter(func(t: Dictionary) -> bool: return t["at"] == b["tick"])
		assert_eq(warned.size(), 1, "no blow without a telegraph the tick before")
	var heavy := told.filter(func(t: Dictionary) -> bool: return t["heavy"])
	assert_true(heavy.size() > 0, "the aimed shot is flagged heavy")
	assert_eq(heavy[0]["action"], "aimed_shot")


func test_stepping_out_of_reach_after_a_telegraph_makes_it_miss() -> void:
	var sim := SimScript.new()
	H.place(sim, [-7.5, 26.5])  # two metres from wolf_1: seen, but out of its bite
	var told: Array[Dictionary] = []
	for i in 10:
		var events := H.run_stamped(sim, 1)
		told = H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "wolf_1")
		if not told.is_empty():
			break
	assert_eq(told.size(), 1, "the wolf closes in and telegraphs")
	sim.command(Vocab.MOVE_TO, {"pos": [-7.5, 22.5]})
	var after := H.run_stamped(sim, 1)
	var missed := H.where(after, Vocab.EV_MISSED, "attacker", "wolf_1")
	assert_eq(missed.size(), 1, "the player stepped out of the bite")
	assert_eq(H.where(after, Vocab.EV_HIT, "attacker", "wolf_1").size(), 0)


func test_eating_heals_over_four_ticks() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.INSIDE_COLD_CORNER)
	H.set_pack(sim, [{"item": "cooked_fish", "count": 2}])
	H.patch(sim, {"health": 50})
	assert_true(sim.command(Vocab.EAT, {"index": 0})["ok"])
	assert_eq(int(sim.state["health"]), 50, "eating is queued for the next tick")
	assert_eq(H.pack_count(sim, "cooked_fish"), 2)
	var events := H.run_stamped(sim, 1)
	var ate := H.of_kind(events, Vocab.EV_ATE)
	assert_eq(ate.size(), 1)
	assert_eq(ate[0]["heal"], 24)
	assert_eq(ate[0]["ticks"], 4)
	assert_eq(H.pack_count(sim, "cooked_fish"), 1, "one fish eaten")
	assert_eq(int(sim.state["health"]), 56, "a quarter heals on the tick of the meal")
	for expected in [62, 68, 74]:
		H.run(sim, 1)
		assert_eq(int(sim.state["health"]), expected)
	events = H.run_stamped(sim, 3)
	assert_eq(int(sim.state["health"]), 74, "and then it is done")
	assert_eq(H.of_kind(events, Vocab.EV_HEALED).size(), 0)


func test_eating_costs_the_step_of_its_tick() -> void:
	var sim := SimScript.new()
	H.place(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "cooked_fish", "count": 2}])
	sim.command(Vocab.MOVE_TO, {"pos": [0.5, 22.5]})
	H.run(sim, 1)
	var before := sim.player_pos()
	assert_true(sim.command(Vocab.EAT, {"index": 0})["ok"])
	assert_eq(sim.command(Vocab.EAT, {"index": 0})["reason"], Vocab.REASON_ALREADY_EATING, "one meal a tick")
	var events := H.run_stamped(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_ATE).size(), 1)
	assert_eq(H.of_kind(events, Vocab.EV_MOVED).size(), 0, "no step on the tick of the meal")
	assert_eq(sim.player_pos(), before)
	assert_true(sim.is_moving(), "the walk is only paused")
	events = H.run_stamped(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_MOVED).size(), 1, "walking resumes the tick after")


func test_eating_costs_the_swing_of_its_tick() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_ARCHER)
	H.arm(sim, "wooden_club", [{"item": "cooked_fish", "count": 2}])
	sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})
	assert_false((sim.combatant(Vocab.PLAYER)["next"] as Dictionary).is_empty(), "a swing is due next tick")
	sim.command(Vocab.EAT, {"index": 0})
	var events := H.run_stamped(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_ATE).size(), 1)
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size(), 0, "no swing while eating")
	assert_true(sim.is_attacking(), "still on the attack")
	events = H.run_stamped(sim, 1)
	assert_eq(H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size(), 1, "the swing comes a tick late")


func test_food_only() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 2}])
	assert_eq(sim.command(Vocab.EAT, {"index": 0})["reason"], Vocab.REASON_NOT_FOOD)
	assert_eq(sim.command(Vocab.EAT, {"index": 3})["reason"], Vocab.REASON_EMPTY_SLOT)


func test_a_bow_without_arrows_will_not_fire() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_ARCHER)
	H.arm(sim, "wooden_bow")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})["reason"], Vocab.REASON_NO_AMMO)
	assert_false(sim.is_attacking())


func test_each_shot_spends_one_arrow_until_none_are_left() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_ARCHER)
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 3}])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})["ok"])
	var shots := 0
	var stopped: Array[Dictionary] = []
	for i in 12:
		var events := H.run_stamped(sim, 1)
		shots += H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size()
		assert_eq(H.pack_count(sim, "arrows"), 3 - shots, "one arrow per shot")
		stopped.append_array(H.of_kind(events, Vocab.EV_ACTIVITY_STOPPED))
	assert_eq(shots, 3)
	assert_eq(int(sim.state["enemies"]["archer_1"]["health"]), 20 - 3 * 4, "three neutral bow hits")
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0]["reason"], Vocab.REASON_NO_AMMO, "the attack stops when the quiver is empty")
	assert_false(sim.is_attacking())
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})["reason"], Vocab.REASON_NO_AMMO)


func test_hits_train_the_style_skill() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_ARCHER)
	H.arm(sim, "wooden_club")
	sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})
	H.run(sim, 1)
	assert_eq(int(sim.state["skills"][SkillTable.MELEE]["xp"]), 8 * CombatTable.XP_PER_DAMAGE)
	assert_eq(int(sim.state["skills"][SkillTable.RANGED]["xp"]), 0)


func test_attack_is_refused_in_the_outpost_and_on_the_dead() -> void:
	var sim := SimScript.new()
	assert_true(sim.in_outpost())
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["reason"], Vocab.REASON_IN_OUTPOST)
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "nobody"})["reason"], Vocab.REASON_UNKNOWN_ENEMY)
	H.place(sim, NEAR_ARCHER)
	H.patch_enemy(sim, "archer_1", {"mode": Sim.MODE_DEAD, "health": 0, "respawn_tick": 999})
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})["reason"], Vocab.REASON_TARGET_DEAD)


func test_an_enemy_notices_by_sight() -> void:
	var sim := SimScript.new()
	H.place(sim, [14.5, 18.0])  # 10.5 m from the archer: just out of its sight
	var events := H.run(sim, 5)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED).size(), 0, "too far to be seen")
	H.place(sim, [14.5, 20.5])  # 8 m: inside its 9 m sight
	events = H.run(sim, 1)
	var noticed := H.of_kind(events, Vocab.EV_ENEMY_NOTICED)
	assert_eq(noticed.size(), 1)
	assert_eq(noticed[0]["enemy_id"], "archer_1")
	assert_eq(noticed[0]["cause"], CombatTable.NOTICE_SIGHT)
	assert_eq(sim.state["enemies"]["archer_1"]["mode"], Sim.MODE_ENGAGED)


func test_an_enemy_notices_by_noise_and_brings_its_pack() -> void:
	var sim := SimScript.new()
	# South of the south-western pine: 7 m from wolf_1, outside its 6 m sight but inside the
	# 9 m a woodcutter can be heard.
	H.place(sim, [-7.5, 21.5])
	var events := H.run(sim, 5)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED).size(), 0, "standing still is quiet")
	assert_true(sim.command(Vocab.GATHER, {"object_id": "tree_5"})["ok"])
	events = H.run(sim, 3)
	var noticed := H.of_kind(events, Vocab.EV_ENEMY_NOTICED)
	assert_eq(noticed.size(), 2, "the near pack, and no one else")
	assert_eq(noticed[0]["enemy_id"], "wolf_1")
	assert_eq(noticed[0]["cause"], CombatTable.NOTICE_NOISE)
	assert_eq(noticed[1]["enemy_id"], "wolf_2")
	assert_eq(noticed[1]["cause"], CombatTable.NOTICE_PACK)
	assert_eq(sim.state["enemies"]["wolf_3"]["mode"], Sim.MODE_IDLE, "the far pack heard nothing")


func test_enemies_break_off_at_the_outpost() -> void:
	var sim := SimScript.new()
	H.place(sim, [-7.5, 23.5])
	H.run(sim, 1)
	assert_eq(sim.state["enemies"]["wolf_1"]["mode"], Sim.MODE_ENGAGED)
	assert_eq(sim.state["enemies"]["wolf_2"]["mode"], Sim.MODE_ENGAGED, "the pack comes too")
	sim.command(Vocab.MOVE_TO, {"pos": H.INSIDE_COLD_CORNER})
	var events := H.run_until_idle(sim, 60)
	assert_true(sim.in_outpost())
	var off := H.of_kind(events, Vocab.EV_ENEMY_DISENGAGED)
	assert_eq(off.size(), 2, "both wolves break off")
	for e in H.of_kind(events, Vocab.EV_ENEMY_MOVED):
		assert_ne(sim.world.region_at(Vector2(e["to"][0], e["to"][1])), WorldDef.REGION_OUTPOST, "never inside")
	events = H.run(sim, 40)
	assert_eq(H.of_kind(events, Vocab.EV_HIT).size(), 0, "nothing reaches the player inside")
	for id in ["wolf_1", "wolf_2"]:
		var e: Dictionary = sim.state["enemies"][id]
		assert_eq(e["mode"], Sim.MODE_IDLE, "%s is back at home" % id)
		assert_eq(Vector2(e["pos"][0], e["pos"][1]), Vector2(sim.world.enemies[id]["home"][0], sim.world.enemies[id]["home"][1]))
		assert_eq(int(e["health"]), 15, "and healed")


func test_death_keeps_the_three_most_valuable_things() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["skills"]["woodcutting"] = {"xp": 500, "level": SkillTable.level_for_xp(500)}
	snap["upgrades"] = ["test_upgrade"]
	sim.restore(snap)
	H.place(sim, NEAR_ARCHER)
	H.arm(sim, "wooden_club", [
		{"item": "iron_sword", "count": 1},     # 80
		{"item": "logs", "count": 3},           # 6
		{"item": "arrows", "count": 30},        # 30, one stack is one thing
		{"item": "cooked_fish", "count": 2},    # 12, ties with the worn club
	])
	snap = sim.snapshot()
	snap["inventory"]["equipment"]["armour"] = "iron_armour"  # 90
	snap["health"] = 1
	sim.restore(snap)
	var stash_before: Array = sim.state["stash"]["slots"].duplicate(true)
	var skills_before: Dictionary = sim.state["skills"].duplicate(true)
	var events := H.run_stamped(sim, 10)
	var died := H.of_kind(events, Vocab.EV_DIED)
	assert_eq(died.size(), 1)
	assert_eq(died[0]["cause"], "bandit_archer")
	assert_eq(died[0]["kept"], [
		{"item": "iron_armour", "count": 1}, {"item": "iron_sword", "count": 1}, {"item": "arrows", "count": 30},
	])
	assert_eq(died[0]["lost"], [
		{"item": "wooden_club", "count": 1}, {"item": "cooked_fish", "count": 2},
		{"item": "logs", "count": 3}, {"item": "wooden_axe", "count": 1},
	], "worn beats the pack on a tie")
	var equipment: Dictionary = sim.state["inventory"]["equipment"]
	assert_eq(equipment["armour"], "iron_armour", "kept things stay where they were")
	assert_eq(equipment["weapon"], "")
	assert_eq(H.pack_count(sim, "iron_sword"), 1)
	assert_eq(H.pack_count(sim, "arrows"), 30)
	assert_eq(H.pack_count(sim, "logs"), 0, "lost for good")
	assert_eq(H.pack_count(sim, "cooked_fish"), 0)
	# The axe was lost and none is stashed, so a spare waits by the fire.
	assert_eq(died[0]["spare"], "wooden_axe")
	assert_eq(equipment["tool"], "wooden_axe")
	assert_true(sim.near_fire(), "wakes beside the fire")
	assert_true(sim.in_outpost())
	assert_eq(int(sim.state["health"]), Sim.HEALTH_MAX)
	assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX)
	assert_eq(sim.state["stash"]["slots"], stash_before, "the stash is untouched")
	assert_eq(sim.state["skills"], skills_before, "skills are untouched")
	assert_eq(sim.state["upgrades"], ["test_upgrade"], "upgrades are untouched")
	var off := H.where(events, Vocab.EV_ENEMY_DISENGAGED, "enemy_id", "archer_1")
	assert_eq(off.size(), 1, "the archer breaks off")
	assert_eq(off[0]["tick"], died[0]["tick"])
	var saved := H.of_kind(events, Vocab.EV_SAVED)
	assert_eq(saved.size(), 1)
	assert_eq(saved[0]["reason"], "death", "a death is a save point")
	assert_eq(saved[0]["tick"], died[0]["tick"])


func test_no_spare_axe_when_one_is_stashed() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["stash"]["slots"][5] = {"item": "wooden_axe", "count": 1}
	sim.restore(snap)
	H.place(sim, H.OUTSIDE)
	H.arm(sim, "", [{"item": "logs", "count": 4}, {"item": "cooked_fish", "count": 1}, {"item": "arrows", "count": 9}])
	H.patch(sim, {"warmth": 0, "health": 1})
	var died := H.of_kind(H.run(sim, 2), Vocab.EV_DIED)
	assert_eq(died.size(), 1)
	assert_eq(died[0]["lost"], [{"item": "wooden_axe", "count": 1}], "the cheapest of four things")
	assert_eq(died[0]["spare"], "")
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "")


func test_a_dead_enemy_drops_loot_that_can_be_picked_up() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_ARCHER)
	H.arm(sim, "iron_sword")
	H.patch_enemy(sim, "archer_1", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})
	var events := H.run(sim, 1)
	var died := H.of_kind(events, Vocab.EV_ENEMY_DIED)
	assert_eq(died.size(), 1)
	assert_eq(died[0]["enemy_id"], "archer_1")
	assert_false(sim.is_attacking(), "the attack ends with the target")
	var drops := H.of_kind(events, Vocab.EV_LOOT_DROPPED)
	assert_true(drops.size() >= 1)
	assert_eq(drops[0]["item"], "arrows", "archers always drop arrows")
	assert_eq(drops[0]["count"], 8)
	var id: String = drops[0]["loot_id"]
	assert_true(sim.command(Vocab.INTERACT, {"object_id": id})["ok"])
	events = H.run_until_idle(sim, 20)
	var picked := H.of_kind(events, Vocab.EV_PICKED_UP)
	assert_eq(picked.size(), 1)
	assert_eq(picked[0]["loot_id"], id)
	assert_eq(H.pack_count(sim, "arrows"), 8)
	assert_false(sim.state["loot"].has(id), "the pile is gone")
	# The archer comes back home later.
	events = H.run(sim, CombatTable.enemy("bandit_archer")["respawn_ticks"])
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_RESPAWNED).size(), 1)
	assert_eq(int(sim.state["enemies"]["archer_1"]["health"]), 20)


func test_loot_left_lying_is_taken_by_the_snow() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_ARCHER)
	H.arm(sim, "iron_sword")
	H.patch_enemy(sim, "archer_1", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})
	var drops := H.of_kind(H.run(sim, 1), Vocab.EV_LOOT_DROPPED)
	H.place(sim, H.INSIDE_COLD_CORNER)
	var events := H.run(sim, Sim.LOOT_TICKS)
	assert_eq(H.of_kind(events, Vocab.EV_LOOT_GONE).size(), drops.size())
	assert_true(sim.state["loot"].is_empty())


func test_a_fight_is_deterministic() -> void:
	var a := SimScript.new()
	var b := SimScript.new()
	for sim in [a, b]:
		H.place(sim, [-7.5, 23.5])
		H.arm(sim, "wooden_club", [{"item": "cooked_fish", "count": 3}])
		sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})
	H.run(a, 40)
	H.run(b, 40)
	assert_eq(a.snapshot(), b.snapshot())


func test_fighting_one_pack_does_not_wake_the_other() -> void:
	var sim := SimScript.new()
	H.place(sim, [-7.5, 23.5])
	H.arm(sim, "wooden_club")
	for id in ["wolf_1", "wolf_2"]:
		sim.command(Vocab.ATTACK, {"enemy_id": id})
		for i in 40:
			H.run(sim, 1)
			if sim.state["enemies"][id]["mode"] == Sim.MODE_DEAD:
				break
	assert_eq(sim.state["enemies"]["wolf_1"]["mode"], Sim.MODE_DEAD)
	assert_eq(sim.state["enemies"]["wolf_2"]["mode"], Sim.MODE_DEAD, "a club wins against the near pack")
	for id in ["wolf_3", "wolf_4", "wolf_5", "archer_1"]:
		assert_eq(sim.state["enemies"][id]["mode"], Sim.MODE_IDLE, "%s heard nothing" % id)


func test_shooting_the_archer_from_the_west_does_not_wake_the_wolves() -> void:
	var sim := SimScript.new()
	H.place(sim, [7.0, 26.0])  # just inside bow reach of the archer, on the wolves' side
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 30}])
	sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})
	for i in 40:
		H.run(sim, 1)
		if sim.state["enemies"]["archer_1"]["mode"] == Sim.MODE_DEAD:
			break
	assert_eq(sim.state["enemies"]["archer_1"]["mode"], Sim.MODE_DEAD, "a bow duel with the archer is winnable")
	for id in ["wolf_1", "wolf_2", "wolf_3"]:
		assert_eq(sim.state["enemies"][id]["mode"], Sim.MODE_IDLE, "%s heard nothing" % id)
