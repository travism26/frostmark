## Ring two: the open gate is walked through both ways and nothing follows; the first arrival is
## marked once; ice trolls wind up before they crush and ruin stalkers back away from anyone who
## closes in; coal, rich iron and deep holes gate on level; the blast furnace opens steel.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Ring one's side of the gate, out of the captain's sight, and ring two's, just through it.
const NORTH_OF_GATE := [0.5, 50.5]
const PAST_THE_GATE := [0.5, 65.5]
## Standing at the workbench, inside the outpost.
const AT_WORKBENCH := [6.0, -5.0]
const UPGRADES_TO_THE_WINCH := ["stash_shelves", "forge", "armoury", "ring_two_gate"]


## A character whose gate stands open: the captain fell (and is still down) and the winch is built.
func _gate_open() -> Sim:
	var sim := SimScript.new()
	H.patch(sim, {"bosses_defeated": ["captain"], "upgrades": UPGRADES_TO_THE_WINCH.duplicate()})
	H.patch_enemy(sim, "captain", {"mode": Sim.MODE_DEAD, "health": 0, "respawn_tick": 100000})
	return sim


func _sturdy(sim: Sim) -> void:
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["armour"] = "iron_armour"
	sim.restore(snap)


func _set_level(sim: Sim, skill: String, level: int) -> void:
	var snap := sim.snapshot()
	snap["skills"][skill] = {"xp": SkillTable.xp_for_level(level), "level": level}
	sim.restore(snap)


func _pass(sim: Sim) -> Array[Dictionary]:
	sim.drain_events()
	var result := sim.command(Vocab.INTERACT, {"object_id": "ring_two_gate"})
	assert_true(result["ok"], result["reason"])
	return H.run_until_idle(sim, 40)


## Cues an enemy gave (telegraphed blows and announced stances) as "action:style", in order.
static func _cues(events: Array[Dictionary], id: String) -> Array:
	var out: Array = []
	for e in events:
		if e.get("enemy_id", "") == id and e["kind"] in [Vocab.EV_ENEMY_TELEGRAPHED, Vocab.EV_ENEMY_STANCE]:
			out.append("%s:%s" % [e["action"], e["style"]])
	return out


# --- The gate ---------------------------------------------------------------------------

func test_the_open_gate_is_walked_through_both_ways() -> void:
	var sim := _gate_open()
	H.place(sim, NORTH_OF_GATE)
	H.set_pack(sim, [{"item": "iron_ore", "count": 2}])
	var into := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO, "through to ring two")
	assert_true(sim.player_pos().y > 62.0, "beyond the gate")
	assert_false(sim.is_moving(), "and standing there")
	assert_eq(H.pack_count(sim, "iron_ore"), 2, "the pack is not banked")
	var reached := H.of_kind(into, Vocab.EV_RING_TWO_REACHED)
	assert_eq(reached.size(), 1, "the first arrival is marked")
	assert_eq(H.of_kind(into, Vocab.EV_SAVED)[-1]["reason"], "ring_two", "and is a save point")
	assert_eq(sim.state["rings_reached"], [WorldDef.REGION_RING_TWO])
	var back := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE, "back through to ring one")
	assert_true(sim.player_pos().y < 60.0)
	assert_eq(H.of_kind(back, Vocab.EV_RING_TWO_REACHED).size(), 0)
	var again := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO)
	assert_eq(H.of_kind(again, Vocab.EV_RING_TWO_REACHED).size(), 0, "only the first arrival is marked")
	assert_eq(H.of_kind(again, Vocab.EV_SAVED).size(), 0)


func test_the_gate_is_the_only_way_between_the_rings() -> void:
	var sim := _gate_open()
	H.place(sim, NORTH_OF_GATE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": PAST_THE_GATE})["reason"], Vocab.REASON_UNREACHABLE, "no route around it")
	H.place(sim, PAST_THE_GATE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": NORTH_OF_GATE})["reason"], Vocab.REASON_UNREACHABLE)
	assert_eq(sim.command(Vocab.CROSS_GATE)["reason"], Vocab.REASON_UNREACHABLE, "the outpost gate is back through it")


func test_a_barred_gate_is_not_walked_through() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": UPGRADES_TO_THE_WINCH.duplicate()})
	H.patch_enemy(sim, "captain", {"pos": [40.5, 40.5]})  # away from his post, so the walk is quiet
	H.place(sim, NORTH_OF_GATE)
	var events := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE)
	assert_eq(H.of_kind(events, Vocab.EV_RING_TWO_REACHED).size(), 0)


func test_the_captain_stays_down_once_his_gate_is_open() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": UPGRADES_TO_THE_WINCH.duplicate()})
	H.place(sim, [0.5, 55.5])
	H.arm(sim, "iron_sword")
	H.patch_enemy(sim, "captain", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "captain"})
	H.run(sim, 4)
	assert_true(sim.ring_gate_open("ring_two_gate"))
	H.place(sim, [0.5, 4.5])
	var events := H.run(sim, int(CombatTable.ENEMIES["bandit_captain"]["respawn_ticks"]) * 2)
	assert_eq(H.where(events, Vocab.EV_ENEMY_RESPAWNED, "enemy_id", "captain").size(), 0, "the way home stays clear")
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_DEAD)


func test_the_brazier_past_the_gate_warms() -> void:
	var sim := _gate_open()
	H.place(sim, PAST_THE_GATE)
	H.patch(sim, {"warmth": 100})
	assert_true(sim.command(Vocab.INTERACT, {"object_id": "brazier"})["ok"])
	var events := H.run_until_idle(sim, 20)
	assert_eq(H.of_kind(events, Vocab.EV_INTERACTED)[0]["action"], Vocab.ACTION_WARM)
	assert_true(sim.near_fire())
	H.run(sim, 3)
	assert_true(int(sim.state["warmth"]) > 100, "it warms like the outpost fire")


# --- Nothing crosses the gate -----------------------------------------------------------

func test_ring_two_does_not_notice_a_player_through_the_gate() -> void:
	var sim := _gate_open()
	H.patch_enemy(sim, "troll_1", {"pos": [0.5, 64.5]})
	H.place(sim, [0.5, 59.5])
	var events := H.run(sim, 3)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "troll_1").size(), 0, "deaf and blind through the gate")
	H.place(sim, [0.5, 62.5])
	events = H.run(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "troll_1").size(), 1, "but not on its own side")


func test_enemies_break_off_when_the_player_passes_the_gate() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	H.place(sim, [-32.5, 66.5])
	var events := H.run(sim, 2)
	assert_eq(sim.state["enemies"]["stalker_1"]["mode"], Sim.MODE_ENGAGED, "the stalker joins the fight")
	H.place(sim, NORTH_OF_GATE)
	events = H.run(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DISENGAGED, "enemy_id", "stalker_1").size(), 1, "and breaks off")
	assert_eq(sim.state["enemies"]["stalker_1"]["mode"], Sim.MODE_RETURNING)
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "stalker_1"})["reason"], Vocab.REASON_UNREACHABLE, "it can't be fought across")
	# The same the other way: the captain does not follow into ring two.
	H.patch_enemy(sim, "captain", {"mode": Sim.MODE_IDLE, "health": 240, "pos": [0.5, 56.5], "respawn_tick": 0})
	H.place(sim, [0.5, 58.5])
	H.run(sim, 1)
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_ENGAGED)
	H.place(sim, PAST_THE_GATE)
	events = H.run(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DISENGAGED, "enemy_id", "captain").size(), 1)


# --- The ice troll ------------------------------------------------------------------------

func test_the_ice_troll_winds_up_two_ticks_before_its_crush() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	H.place(sim, [-44.5, 93.5])
	var events := H.run_stamped(sim, 13)
	assert_eq(_cues(events, "troll_1").slice(0, 4), ["smash:melee", "wind_up:melee", "crush:melee", "smash:melee"])
	var wind_up := H.where(events, Vocab.EV_ENEMY_STANCE, "action", "wind_up")[0]
	var crush := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "action", "crush")[0]
	assert_eq(int(crush["tick"]), int(wind_up["tick"]) + 1, "the crush is telegraphed the tick after the wind-up")
	assert_eq(int(crush["at"]), int(wind_up["tick"]) + 2, "so it lands two ticks after the first warning")
	assert_true(crush["heavy"])
	for action in CombatTable.ACTIONS:
		assert_true(int(crush["damage"]) >= CombatTable.action_damage(action), "the hardest blow there is (vs %s)" % action)
	assert_eq(sim.combatant("troll_1")["style"], CombatTable.STYLE_MELEE)


func test_stepping_back_from_the_wind_up_makes_the_crush_miss() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	H.place(sim, [-44.5, 93.5])
	var winding := false
	for i in 12:
		sim.step()
		for e in sim.drain_events():
			winding = winding or (e["kind"] == Vocab.EV_ENEMY_STANCE and e["action"] == "wind_up")
		if winding:
			break
	assert_true(winding, "the troll winds up")
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [-44.5, 88.5]})["ok"])
	var events := H.run(sim, 2)
	var missed := H.where(events, Vocab.EV_MISSED, "attacker", "troll_1")
	assert_eq(missed.size(), 1, "the crush finds nobody there")
	assert_eq(missed[0]["action"], "crush")


func test_a_bow_at_distance_has_the_edge_on_a_troll() -> void:
	var sim := _gate_open()
	H.place(sim, [-44.5, 88.5])
	H.arm(sim, "iron_bow", [{"item": "arrows", "count": 10}])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "troll_1"})["ok"])
	var hits := H.where(H.run(sim, 2), Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(hits.size(), 1)
	assert_eq(float(hits[0]["multiplier"]), 1.5, "ranged at distance beats melee")


func test_the_troll_drops_a_hide() -> void:
	var sim := _gate_open()
	H.place(sim, [-44.5, 93.5])
	H.arm(sim, "iron_sword")
	H.patch_enemy(sim, "troll_1", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "troll_1"})
	var events := H.run(sim, 3)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "troll_1").size(), 1)
	assert_eq(H.where(events, Vocab.EV_LOOT_DROPPED, "item", "troll_hide").size(), 1)


# --- The ruin stalker -----------------------------------------------------------------------

func test_the_ruin_stalker_shoots_on_its_pattern() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	H.place(sim, [-32.5, 66.5])
	var events := H.run_stamped(sim, 9)
	assert_eq(_cues(events, "stalker_1").slice(0, 4), ["dart:ranged", "dart:ranged", "barbed_volley:ranged", "dart:ranged"])
	assert_true(H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "action", "barbed_volley")[0]["heavy"])
	assert_eq(sim.combatant("stalker_1")["style"], CombatTable.STYLE_RANGED)


func test_the_ruin_stalker_backs_away_from_anyone_who_closes_in() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})  # the player stands still throughout
	H.place(sim, [-32.5, 69.5])  # 3 m off, inside its kiting distance
	var before := Vector2(-32.5, 72.5)
	H.run(sim, 2)
	var after: Vector2 = sim.combatant("stalker_1")["pos"]
	assert_true(after.distance_to(sim.player_pos()) > before.distance_to(sim.player_pos()), "it opened the distance")
	var facing := Vector2(sim.state["enemies"]["stalker_1"]["facing"][0], sim.state["enemies"]["stalker_1"]["facing"][1])
	assert_true(facing.dot((sim.player_pos() - after).normalized()) > 0.99, "still facing the player")
	# Far enough off, it stands and shoots.
	H.patch_enemy(sim, "stalker_1", {"pos": [-32.5, 72.5]})
	H.place(sim, [-32.5, 66.5])
	sim.drain_events()
	var events := H.run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_MOVED, "enemy_id", "stalker_1").size(), 0, "at 6 m it holds its ground")


func test_a_stalker_backed_against_a_wall_is_cornered() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	H.patch_enemy(sim, "stalker_1", {"pos": [-20.5, 77.5]})  # the outer wall is right behind it
	H.place(sim, [-20.5, 75.0])
	var events := H.run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_MOVED, "enemy_id", "stalker_1").size(), 0, "no room to back away")
	assert_eq(sim.combatant("stalker_1")["pos"], Vector2(-20.5, 77.5))


func test_a_sword_caught_up_close_has_the_edge_on_a_stalker() -> void:
	var sim := _gate_open()
	H.patch_enemy(sim, "stalker_1", {"pos": [-20.5, 77.5]})
	H.place(sim, [-20.5, 76.5])
	H.arm(sim, "iron_sword")
	sim.command(Vocab.ATTACK, {"enemy_id": "stalker_1"})
	var hits := H.where(H.run(sim, 2), Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(hits.size(), 1)
	assert_eq(float(hits[0]["multiplier"]), 1.5, "melee up close beats ranged")


# --- Nodes ---------------------------------------------------------------------------------

func test_ring_two_nodes_need_their_levels_and_tools() -> void:
	var sim := _gate_open()
	H.place(sim, PAST_THE_GATE)
	H.set_pack(sim, [{"item": "bronze_pickaxe", "count": 1}, {"item": "fishing_rod", "count": 1}])
	var gates := [
		["coal_1", SkillTable.MINING, WorldDef.KIND_COAL_ROCK],
		["rich_iron_1", SkillTable.MINING, WorldDef.KIND_RICH_IRON_ROCK],
		["deep_hole_1", SkillTable.FISHING, WorldDef.KIND_DEEP_HOLE],
	]
	for g in gates:
		var level := int(WorldDef.NODE_KINDS[g[2]]["level"])
		_set_level(sim, g[1], level - 1)
		assert_eq(sim.command(Vocab.GATHER, {"object_id": g[0]})["reason"], Vocab.REASON_LEVEL_TOO_LOW, "%s below level %d" % [g[0], level])
		_set_level(sim, g[1], level)
		assert_true(sim.command(Vocab.GATHER, {"object_id": g[0]})["ok"], "%s at level %d" % [g[0], level])
	H.set_pack(sim, [{"item": "wooden_pickaxe", "count": 1}])
	_set_level(sim, SkillTable.MINING, 20)
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "coal_1"})["reason"], Vocab.REASON_TOOL_TOO_WEAK, "wood won't bite coal")


func test_coal_is_mined_in_ring_two() -> void:
	var sim := _gate_open()
	H.place(sim, [37.5, 87.5])
	H.set_pack(sim, [{"item": "bronze_pickaxe", "count": 1}])
	_set_level(sim, SkillTable.MINING, 5)
	H.patch_enemy(sim, "stalker_3", {"pos": [56.5, 120.5]})  # out of earshot
	H.patch_enemy(sim, "stalker_4", {"pos": [56.5, 121.5]})
	sim.command(Vocab.GATHER, {"object_id": "coal_1"})
	H.run_until_idle(sim, 200)
	assert_eq(H.pack_count(sim, "coal"), int(WorldDef.NODE_KINDS[WorldDef.KIND_COAL_ROCK]["yield"]))


func test_char_cooks_at_cooking_five() -> void:
	var sim := _gate_open()
	H.place(sim, [5.5, 67.0])  # by the brazier
	H.set_pack(sim, [{"item": "raw_char", "count": 2}])
	_set_level(sim, SkillTable.COOKING, 4)
	assert_eq(sim.command(Vocab.COOK, {"index": 0})["reason"], Vocab.REASON_LEVEL_TOO_LOW)
	_set_level(sim, SkillTable.COOKING, 20)
	assert_true(sim.command(Vocab.COOK, {"index": 0})["ok"])
	H.run_until_idle(sim, 10)
	H.run(sim, 4)
	assert_eq(H.pack_count(sim, "cooked_char"), 2, "no burns this far above its level")
	assert_true(ItemTable.heal("cooked_char") > ItemTable.heal("cooked_trout"), "better fishing feeds better")


# --- Steel ---------------------------------------------------------------------------------

func _furnace_ready(sim: Sim) -> void:
	var slots := Inventory.empty_slots(12)
	var cost: Dictionary = UpgradeTable.get_upgrade("blast_furnace")["cost"]
	for kind in cost:
		Inventory.add(slots, kind, int(cost[kind]))
	H.patch(sim, {"stash": {"capacity": 12, "slots": slots}})
	H.place(sim, AT_WORKBENCH)


func test_steel_is_refused_before_the_blast_furnace_and_made_after() -> void:
	var sim := _gate_open()
	_furnace_ready(sim)
	_set_level(sim, SkillTable.SMITHING, 10)
	H.set_pack(sim, [{"item": "iron_ore", "count": 4}, {"item": "coal", "count": 8}, {"item": "logs", "count": 4}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "steel_bar"})["reason"], Vocab.REASON_TIER_CAPPED, "bronze is the cap")
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "blast_furnace"})["ok"])
	var built := H.of_kind(H.run(sim, 1), Vocab.EV_BUILT)
	assert_eq(built[0]["upgrade"], "blast_furnace")
	assert_eq(sim.smithing_cap(), ItemTable.TIER_STEEL)
	for i in 4:
		assert_true(sim.command(Vocab.SMITH, {"recipe": "steel_bar"})["ok"], "steel bar %d" % i)
		H.run(sim, 1)
	assert_eq(H.pack_count(sim, "steel_bar"), 4)
	assert_eq(H.pack_count(sim, "coal"), 0, "two coal a bar")
	assert_true(sim.command(Vocab.SMITH, {"recipe": "steel_sword"})["ok"])
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "steel_sword"), 1)


func test_the_blast_furnace_needs_the_winch_and_ring_two() -> void:
	var sim := SimScript.new()
	_furnace_ready(sim)
	H.patch(sim, {"upgrades": ["stash_shelves", "forge", "armoury"]})
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "blast_furnace"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	var cost: Dictionary = UpgradeTable.get_upgrade("blast_furnace")["cost"]
	assert_true(cost.has("coal") and cost.has("troll_hide"), "paid for with what ring two gives")


func test_steel_gear_steps_above_iron() -> void:
	var lines := [
		["iron_sword", "steel_sword"], ["iron_bow", "steel_bow"], ["iron_staff", "steel_staff"],
		["iron_armour", "steel_armour"],
		["iron_axe", "steel_axe"], ["iron_pickaxe", "steel_pickaxe"],
	]
	for line in lines:
		var lo: Dictionary = ItemTable.ITEMS[line[0]]
		var hi: Dictionary = ItemTable.ITEMS[line[1]]
		assert_eq(hi["tier"], ItemTable.TIER_STEEL)
		assert_eq(ItemTable.tier_rank(hi["tier"]), ItemTable.tier_rank(lo["tier"]) + 1, "%s is the next tier" % line[1])
		assert_true(int(hi.get("power", hi.get("defence", 0))) >= int(lo.get("power", lo.get("defence", 0))), "%s is no weaker" % line[1])
		assert_true(int(hi["value"]) > int(lo["value"]), "%s is worth more" % line[1])
		var made := false
		for id in RecipeTable.ids():
			made = made or RecipeTable.get_recipe(id)["output"]["item"] == line[1]
		assert_true(made, "%s is smithed" % line[1])
	assert_true(Sim.gather_chance(1, 3) > Sim.gather_chance(1, 2), "a steel tool gathers surer than iron")


# --- The layout ----------------------------------------------------------------------------

func test_every_group_sits_out_of_earshot_of_the_next() -> void:
	var w := WorldDef.outpost()
	for a in w.enemies:
		for b in w.enemies:
			if w.enemies[a]["pack"] == w.enemies[b]["pack"]:
				continue
			var ha: Array = w.enemies[a]["home"]
			var hb: Array = w.enemies[b]["home"]
			var d := Vector2(ha[0], ha[1]).distance_to(Vector2(hb[0], hb[1]))
			assert_true(d > CombatTable.NOISE_FIGHT, "%s and %s are %.1f m apart" % [a, b, d])
